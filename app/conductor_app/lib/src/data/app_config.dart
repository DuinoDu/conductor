class AppConfig {
  const AppConfig({required this.baseUrl, required this.wsUrl});

  factory AppConfig.fromEnv() {
    const apiBase = String.fromEnvironment('API_BASE_URL',
        defaultValue: 'http://localhost:4000');
    const wsBase = String.fromEnvironment('WS_URL', defaultValue: '');
    final resolvedWs =
        wsBase.isNotEmpty ? _normalizeWsUrl(wsBase) : _deriveWsUrl(apiBase);
    assert(() {
      // Helpful during device debugging
      // ignore: avoid_print
      print('AppConfig: baseUrl=' + apiBase + ' wsUrl=' + resolvedWs);
      return true;
    }());
    return AppConfig(baseUrl: apiBase, wsUrl: resolvedWs);
  }

  final String baseUrl;
  final String wsUrl;

  static String _deriveWsUrl(String apiBase) {
    final normalizedBase =
        apiBase.contains('://') ? apiBase : 'http://$apiBase';
    final apiUri = Uri.parse(normalizedBase);
    if (!apiUri.hasAuthority) {
      return 'ws://localhost:4000/ws/app';
    }
    final wsScheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    return apiUri
        .replace(
          scheme: wsScheme,
          path: '/ws/app',
          query: null,
          fragment: null,
        )
        .toString();
  }

  static String _normalizeWsUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final candidate = trimmed.contains('://') ? trimmed : 'ws://$trimmed';
    final uri = Uri.parse(candidate);
    final scheme = uri.scheme;
    if (scheme == 'http') {
      return uri.replace(scheme: 'ws').toString();
    }
    if (scheme == 'https') {
      return uri.replace(scheme: 'wss').toString();
    }
    if (scheme != 'ws' && scheme != 'wss') {
      return uri.replace(scheme: 'ws').toString();
    }
    return uri.toString();
  }
}
