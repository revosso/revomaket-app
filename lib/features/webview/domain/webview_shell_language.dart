/// Supported UI languages — mirrors `revo-maket/src/lib/i18n/language.ts`.
class WebviewShellLanguage {
  const WebviewShellLanguage({
    required this.code,
    required this.flag,
    required this.label,
  });

  final String code;
  final String flag;
  final String label;

  static const supported = <WebviewShellLanguage>[
    WebviewShellLanguage(code: 'ht', flag: '🇭🇹', label: 'Kreyòl'),
    WebviewShellLanguage(code: 'fr', flag: '🇫🇷', label: 'Français'),
    WebviewShellLanguage(code: 'en', flag: '🇺🇸', label: 'English'),
    WebviewShellLanguage(code: 'es', flag: '🇪🇸', label: 'Español'),
    WebviewShellLanguage(
        code: 'pt-BR', flag: '🇧🇷', label: 'Português (Brasil)'),
  ];

  static WebviewShellLanguage? findByCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final lang in supported) {
      if (lang.code == code) return lang;
    }
    final base = code.split('-').first;
    for (final lang in supported) {
      if (lang.code.split('-').first == base) return lang;
    }
    return null;
  }
}
