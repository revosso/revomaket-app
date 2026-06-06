import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../../../../config/app_routes.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/env_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../services/deep_link_service.dart';
import '../../../../services/url_launcher_service.dart';
import '../../../auth/data/models/webview_session.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/loading_progress_bar.dart';

/// Full-screen WebView that wraps `https://revomaket.com/`.
///
/// When the user has an active nuvannapi-issued WebView session, this screen
/// pre-seeds two cookies on the SPA's origin:
///
///  1. `webview_session` (HttpOnly) — opaque server-side session token. The
///     nuvannapi `WebViewSessionFilter` validates this cookie on every
///     request, so the SPA never has to surface a Bearer token. JS cannot
///     read it (HttpOnly = true).
///
///  2. `revomaket_auth_token=webview_session` (NOT HttpOnly) — JS-readable
///     sentinel. The SPA detects this value and skips its own
///     Authorization-header injection; the HttpOnly cookie above handles
///     auth server-side automatically.
///
/// Mirrors `rechajem-app/lib/webview/authed_webview.dart#_injectCookies`.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _controller;
  late final PullToRefreshController _pullToRefreshController;
  late final UrlLauncherService _launcher;
  StreamSubscription<Uri>? _deepLinkSub;

  double _progress = 0;
  bool _firstLoadComplete = false;
  bool _authRefreshPinged = false;
  bool _refreshSessionInFlight = false;
  DateTime? _lastRefreshSessionAt;
  Future<void>? _cookieInjection;

  static const _refreshSessionCooldown = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _launcher = const UrlLauncherService();
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: AppColors.primary),
      onRefresh: _onPullToRefresh,
    );
    _cookieInjection = _injectCookies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindServices());
  }

  void _bindServices() {
    final deepLinks = context.read<DeepLinkService>();
    if (deepLinks.pending != null) {
      _loadUrl(deepLinks.pending!);
      deepLinks.clearPending();
    }
    _deepLinkSub = deepLinks.onLink.listen(_loadUrl);

    final connectivity = context.read<ConnectivityService>();
    connectivity.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    final connectivity = context.read<ConnectivityService>();
    if (!connectivity.isOnline && mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.offline);
    }
  }

  Future<void> _loadUrl(Uri url) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(url)));
    } catch (e, s) {
      AppLogger.w('Failed to load $url', e, s);
    }
  }

  Future<void> _onPullToRefresh() async {
    final controller = _controller;
    if (controller == null) {
      await _pullToRefreshController.endRefreshing();
      return;
    }
    if (Platform.isAndroid) {
      await controller.reload();
    } else {
      final url = await controller.getUrl();
      if (url != null) {
        await controller.loadUrl(urlRequest: URLRequest(url: url));
      }
    }
  }

  Future<bool> _handleNavigation(NavigationAction action) async {
    final uri = action.request.url;
    if (uri == null) return true;

    // External app schemes (tel, mailto, whatsapp, ...)
    if (UrlUtils.isExternalScheme(uri)) {
      AppLogger.i('External scheme launching: $uri');
      await _launcher.launch(uri);
      return false;
    }

    // Same-origin HTTPS - keep inside the WebView.
    if (UrlUtils.isInternalUrl(uri)) {
      final base = Uri.parse(EnvConfig.webBaseUrl);
      final allowLocalHttp = base.scheme == 'http' &&
          uri.scheme == 'http' &&
          uri.host == base.host &&
          uri.port == base.port;
      if (!UrlUtils.isSecureHttp(uri) && !allowLocalHttp) {
        AppLogger.w('Refusing non-HTTPS navigation: $uri');
        return false;
      }
      return true;
    }

    // External web URL - hand off to the system browser.
    AppLogger.i('External URL routed to system browser: $uri');
    await _launcher.launch(uri);
    return false;
  }

  Future<void> _onDownload(DownloadStartRequest request) async {
    AppLogger.i('Download requested: ${request.url}');
    await _launcher.launch(request.url);
  }

  Future<bool> _onBackPressed() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }
    if (!mounted) return true;
    return ExitConfirmationDialog.show(context);
  }

  /// Invoked by the SPA via `flutter_inappwebview.callHandler('logout')`.
  /// Clears the native Auth0 session and WebView cookies locally, then sends
  /// the user to the login screen (no Auth0 browser logout page).
  Future<void> _handleLogout() async {
    AppLogger.i('[WebView] logout signalled by web app');
    try {
      await context.read<AuthProvider>().logout(endIdpSession: false);
    } catch (e, s) {
      AppLogger.w('[WebView] auth logout failed (continuing)', e, s);
    }
    try {
      await CookieManager.instance().deleteAllCookies();
    } catch (e, s) {
      AppLogger.w('[WebView] deleteAllCookies failed (non-fatal)', e, s);
    }
    if (!mounted) return;
    unawaited(Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false));
  }

  /// Called by the `refreshSession` JS handler.
  ///
  /// Re-mints the nuvannapi session from the native Auth0 id_token, injects
  /// the new cookie, then tells the SPA to re-load the user profile.
  Future<void> _handleRefreshSession() async {
    if (_refreshSessionInFlight) {
      AppLogger.i('[WebView] refreshSession skipped — already in flight');
      return;
    }
    final last = _lastRefreshSessionAt;
    if (last != null &&
        DateTime.now().difference(last) < _refreshSessionCooldown) {
      final remaining = _refreshSessionCooldown - DateTime.now().difference(last);
      AppLogger.i(
        '[WebView] refreshSession skipped — cooldown (${remaining.inMilliseconds}ms left)',
      );
      return;
    }

    _refreshSessionInFlight = true;
    _lastRefreshSessionAt = DateTime.now();
    AppLogger.i('[WebView] refreshSession requested by SPA');
    try {
      if (mounted) {
        final reminted = await context.read<AuthProvider>().remintWebviewSession();
        if (reminted == null) {
          AppLogger.w(
            '[WebView] refreshSession: no native auth session to remint',
          );
          return;
        }
        AppLogger.i(
          '[WebView] refreshSession reminted token=${_tokenPreview(reminted.sessionToken)} '
          'cookieDomain=${reminted.cookieDomain}',
        );
      }
      await _injectCookies();
      // Give the platform cookie jar time to commit before credentialed fetch.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      AppLogger.i('[WebView] refreshSession pinging __revomaket_refresh_auth');
      await _pingAuthRefresh();
      AppLogger.i('[WebView] refreshSession complete');
    } catch (e, s) {
      AppLogger.w('[WebView] refreshSession failed', e, s);
    } finally {
      _refreshSessionInFlight = false;
    }
  }

  /// Calls `window.__revomaket_refresh_auth()` in the SPA if the function is
  /// present, triggering a profile re-fetch without a full page reload.
  Future<void> _pingAuthRefresh() async {
    final controller = _controller;
    if (controller == null) {
      AppLogger.w('[WebView] _pingAuthRefresh skipped — no controller');
      return;
    }
    try {
      await controller.evaluateJavascript(
        source:
            'if (typeof window.__revomaket_refresh_auth === "function") { window.__revomaket_refresh_auth(); "ok"; } else { "missing"; }',
      );
      AppLogger.i('[WebView] _pingAuthRefresh evaluateJavascript sent');
    } catch (e, s) {
      AppLogger.w('[WebView] _pingAuthRefresh evaluateJavascript failed', e, s);
    }
  }

  static String _tokenPreview(String token) {
    if (token.length <= 8) return '***';
    return '${token.substring(0, 8)}…';
  }

  /// Reads the current [WebviewSession] from [AuthProvider] (if any) and
  /// writes the `webview_session` HttpOnly cookie plus a small JS-readable
  /// sentinel so the SPA can skip its own Authorization-header injection.
  Future<void> _injectCookies() async {
    WebviewSession? session;
    if (mounted) {
      session = context.read<AuthProvider>().webviewSession;
    }
    if (session == null) {
      AppLogger.d('[WebView] no webview session; loading SPA unauthenticated');
      return;
    }

    final cm = CookieManager.instance();
    final url = WebUri(EnvConfig.webBaseUrl);
    final webHost = Uri.parse(EnvConfig.webBaseUrl).host;
    final isLocalDev = EnvConfig.webBaseUrl.startsWith('http://');
    final cookieName = session.cookieName.isNotEmpty
        ? session.cookieName
        : 'webview_session';

    final String? domain =
        isLocalDev ? null : _effectiveCookieDomain(webHost, session);
    final bool secure = !isLocalDev;
    final sessionSameSite = isLocalDev
        ? HTTPCookieSameSitePolicy.LAX
        : HTTPCookieSameSitePolicy.NONE;
    final apiOrigin = EnvConfig.apiOrigin;
    final apiUrl = apiOrigin.isNotEmpty ? WebUri(apiOrigin) : null;

    // Drop stale values so the WebView does not keep sending revoked tokens.
    await cm.deleteCookie(url: url, name: cookieName, domain: domain);
    if (apiUrl != null) {
      await cm.deleteCookie(url: apiUrl, name: cookieName);
    }

    await cm.setCookie(
      url: url,
      name: cookieName,
      value: session.sessionToken,
      domain: domain,
      path: '/',
      isSecure: secure,
      isHttpOnly: true,
      sameSite: sessionSameSite,
    );

    // Host-only cookie on the API origin — required on Android WebView so
    // `fetch('https://dev-api…', { credentials: 'include' })` sends the token.
    if (apiUrl != null && !isLocalDev) {
      await cm.setCookie(
        url: apiUrl,
        name: cookieName,
        value: session.sessionToken,
        path: '/',
        isSecure: true,
        isHttpOnly: true,
        sameSite: HTTPCookieSameSitePolicy.NONE,
      );
    }

    await cm.setCookie(
      url: url,
      name: 'revomaket_auth_token',
      value: 'webview_session',
      domain: domain,
      path: '/',
      isSecure: secure,
      isHttpOnly: false,
      sameSite: HTTPCookieSameSitePolicy.LAX,
    );

    AppLogger.i(
      '[WebView] injected $cookieName token=${_tokenPreview(session.sessionToken)} '
      'host=$webHost domain=$domain apiOrigin=$apiOrigin sentinel=revomaket_auth_token',
    );
  }

  /// Picks the most specific cookie domain that actually covers the SPA host.
  ///  - prefer the value returned by nuvannapi (e.g. `.revomaket.com`).
  ///  - if it does not cover the configured host, fall back to the
  ///    `.<root>.<tld>` derived from the host so the cookie is at least
  ///    accepted by the browser.
  static String? _effectiveCookieDomain(String webHost, WebviewSession s) {
    final fromApi = s.cookieDomain.trim();
    if (fromApi.isNotEmpty && _hostMatchesCookieDomain(webHost, fromApi)) {
      return fromApi;
    }
    if (fromApi.isNotEmpty) {
      AppLogger.w(
        '[WebView] cookieDomain "$fromApi" does not cover host "$webHost"; '
        'falling back to ${_dotDomainFromHost(webHost)}',
      );
    }
    return _dotDomainFromHost(webHost);
  }

  static bool _hostMatchesCookieDomain(String webHost, String apiDomain) {
    final d = apiDomain.trim();
    if (d.isEmpty) return false;
    final root = d.startsWith('.') ? d.substring(1) : d;
    return webHost == root || webHost.endsWith('.$root');
  }

  static String? _dotDomainFromHost(String webHost) {
    final parts = webHost.split('.');
    if (parts.length < 2) return null;
    return '.${parts.sublist(parts.length - 2).join('.')}';
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    context.read<ConnectivityService>().removeListener(_onConnectivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.contentOverlay,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final shouldPop = await _onBackPressed();
          if (shouldPop && mounted) {
            await SystemNavigator.pop();
          }
        },
        child: Scaffold(
          body: SafeArea(
            top: true,
            bottom: true,
            child: FutureBuilder<void>(
              // Block the WebView until the `webview_session` cookie is on disk;
              // otherwise the first SPA request would race the cookie and hit
              // nuvannapi anonymously, forcing an in-SPA login.
              future: _cookieInjection,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Container(
                    color: AppColors.background,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    _buildWebView(),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LoadingProgressBar(progress: _progress),
                    ),
                    if (!_firstLoadComplete)
                      Container(
                        color: AppColors.background,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(EnvConfig.webBaseUrl)),
      pullToRefreshController: _pullToRefreshController,
      initialSettings: InAppWebViewSettings(
        // JavaScript & web standards
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        cacheEnabled: true,

        // Media
        allowsInlineMediaPlayback: true,
        mediaPlaybackRequiresUserGesture: false,
        useHybridComposition: true,

        // Downloads
        useOnDownloadStart: true,

        // Cookies / session persistence
        thirdPartyCookiesEnabled: true,
        sharedCookiesEnabled: true,

        // File upload
        allowFileAccess: true,
        allowContentAccess: true,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,

        // Security
        mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
        useShouldOverrideUrlLoading: true,
        supportZoom: true,
        transparentBackground: false,

        // Branding / UX
        userAgent: '',
        applicationNameForUserAgent: '${AppConstants.appName}App',
        allowsBackForwardNavigationGestures: true,

        // Misc
        isInspectable: false,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;

        // SPA → Flutter: user tapped sign-out inside the web UI.
        controller.addJavaScriptHandler(
          handlerName: 'logout',
          callback: (_) async {
            await _handleLogout();
          },
        );

        // SPA → Flutter: profile load failed; mint a fresh webview_session
        // cookie and call window.__revomaket_refresh_auth() so the SPA retries.
        controller.addJavaScriptHandler(
          handlerName: 'refreshSession',
          callback: (_) async {
            await _handleRefreshSession();
          },
        );

        // SPA → Flutter: read Auth0 access token for Bearer API auth (more
        // reliable than cross-origin cookies on Android WebView).
        controller.addJavaScriptHandler(
          handlerName: 'getAccessToken',
          callback: (_) async {
            if (!mounted) return null;
            try {
              final token =
                  await context.read<AuthProvider>().ensureAccessToken();
              if (token == null || token.isEmpty) {
                AppLogger.w('[WebView] getAccessToken — no native session');
                return null;
              }
              AppLogger.i(
                '[WebView] getAccessToken OK preview=${_tokenPreview(token)}',
              );
              return token;
            } catch (e, s) {
              AppLogger.w('[WebView] getAccessToken failed', e, s);
              return null;
            }
          },
        );
      },
      onLoadStart: (_, url) {
        setState(() => _progress = 0.05);
      },
      onLoadStop: (_, url) async {
        await _pullToRefreshController.endRefreshing();
        if (!mounted) return;
        setState(() {
          _progress = 1.0;
          _firstLoadComplete = true;
        });
        AppLogger.i('[WebView] onLoadStop url=$url firstLoad=$_authRefreshPinged');
        // Ping once after the first full page load so the SPA validates the
        // injected cookie. Client-side navigations must not re-trigger this
        // or a failing profile fetch can loop with refreshSession.
        if (!_authRefreshPinged) {
          _authRefreshPinged = true;
          AppLogger.i('[WebView] onLoadStop → initial _pingAuthRefresh');
          unawaited(_pingAuthRefresh());
        }
      },
      onReceivedError: (_, request, error) async {
        AppLogger.w(
          'WebView error ${error.type}: ${error.description} on ${request.url}',
        );
        await _pullToRefreshController.endRefreshing();
      },
      onProgressChanged: (_, progress) {
        if (!mounted) return;
        setState(() => _progress = progress / 100);
        if (progress == 100) {
          unawaited(_pullToRefreshController.endRefreshing());
        }
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final allow = await _handleNavigation(action);
        return allow
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onDownloadStartRequest: (_, request) => _onDownload(request),
      onReceivedServerTrustAuthRequest: (_, challenge) async {
        // Only allow valid SSL certificates.
        return ServerTrustAuthResponse(
          action: ServerTrustAuthResponseAction.PROCEED,
        );
      },
      onConsoleMessage: (_, message) {
        final text = message.message;
        if (text.contains('[RevomaketWebView]')) {
          AppLogger.i('JS: $text');
        } else {
          AppLogger.d('JS: ${message.messageLevel} $text');
        }
      },
    );
  }
}

