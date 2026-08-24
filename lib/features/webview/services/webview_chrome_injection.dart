/// Injects CSS/JS into the SPA so Flutter can own the native chrome without
/// changing revo-maket.
class WebviewChromeInjection {
  const WebviewChromeInjection._();

  /// Hide the React WebView top/bottom bars and drop their content insets.
  static const hideWebChromeCss = '''
.webview-topbar-h,
header.webview-topbar-h {
  display: none !important;
  visibility: hidden !important;
  pointer-events: none !important;
  height: 0 !important;
  min-height: 0 !important;
  overflow: hidden !important;
}
.webview-bottomnav-h,
nav.webview-bottomnav-h {
  display: none !important;
  visibility: hidden !important;
  pointer-events: none !important;
  height: 0 !important;
  min-height: 0 !important;
  overflow: hidden !important;
}
.webview-content-pt {
  padding-top: 0 !important;
}
.webview-content-pb {
  padding-bottom: 0 !important;
}
''';

  /// Runs on every document; idempotent.
  static String get bootstrapScript => '''
(function () {
  if (window.__revomaketNativeShellV1) return;
  window.__revomaketNativeShellV1 = true;

  var STYLE_ID = 'revomaket-native-shell-style';
  if (!document.getElementById(STYLE_ID)) {
    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = ${_jsString(hideWebChromeCss)};
    (document.head || document.documentElement).appendChild(style);
  }

  function shellState() {
    var sellerKey = 'nuvann_active_seller_business_id';
    var sellerSession = false;
    try {
      sellerSession = !!window.sessionStorage.getItem(sellerKey);
    } catch (e) {}

    return {
      path: window.location.pathname || '/',
      sellerSession: sellerSession
    };
  }

  function notifyRoute() {
    var bridge = window.flutter_inappwebview;
    if (!bridge || !bridge.callHandler) return;
    bridge.callHandler('routeChanged', shellState());
  }

  function patchHistory(method) {
    var original = history[method];
    if (typeof original !== 'function') return;
    history[method] = function () {
      var result = original.apply(this, arguments);
      notifyRoute();
      return result;
    };
  }

  patchHistory('pushState');
  patchHistory('replaceState');
  window.addEventListener('popstate', notifyRoute);
  window.addEventListener('hashchange', notifyRoute);

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', notifyRoute);
  } else {
    notifyRoute();
  }
})();
''';

  static String _jsString(String value) {
    final escaped = value
        .replaceAll('\\', r'\\')
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n')
        .replaceAll("'", r"\'");
    return "'$escaped'";
  }

  /// Persists the locale and reloads so i18next picks up the new language.
  static String setLanguageScript(String code) {
    final escaped = code.replaceAll('\\', r'\\').replaceAll("'", r"\'");
    return '''
(function () {
  var code = '$escaped';
  try {
    localStorage.setItem('nuvann_language_manual', '1');
    localStorage.setItem('nuvann_language', code);
  } catch (e) {}
  window.location.reload();
})();
''';
  }

  /// Reads the active locale from SPA localStorage (defaults to `en`).
  static const readLanguageScript = '''
(function () {
  try {
    var stored = localStorage.getItem('nuvann_language');
    if (stored) return stored;
  } catch (e) {}
  return 'en';
})();
''';
}
