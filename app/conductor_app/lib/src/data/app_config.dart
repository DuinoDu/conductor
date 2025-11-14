class AppConfig {
  const AppConfig({required this.baseUrl, required this.wsUrl});

  factory AppConfig.fromEnv() {
    const apiBase =
        String.fromEnvironment('API_BASE_URL', defaultValue: 'http://100.72.232.210:4000');
    const wsBase = String.fromEnvironment('WS_URL', defaultValue: '');
    final resolvedWs = wsBase.isNotEmpty ? wsBase : _deriveWsUrl(apiBase);
    return AppConfig(baseUrl: apiBase, wsUrl: resolvedWs);
  }

  final String baseUrl;
  final String wsUrl;

  static String _deriveWsUrl(String apiBase) {
    final normalizedBase = apiBase.contains('://') ? apiBase : 'http://$apiBase';
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
}
