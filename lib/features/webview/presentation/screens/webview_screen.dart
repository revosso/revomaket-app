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
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/loading_progress_bar.dart';

/// Full-screen WebView that wraps `https://revomaket.com/`.
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

  @override
  void initState() {
    super.initState();
    _launcher = const UrlLauncherService();
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: AppColors.primary),
      onRefresh: _onPullToRefresh,
    );
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
      if (!UrlUtils.isSecureHttp(uri)) {
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
            child: Stack(
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ),
              ],
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
        AppLogger.d('JS: ${message.messageLevel} ${message.message}');
      },
    );
  }
}

