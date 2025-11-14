class AppConfig {
  const AppConfig({required this.baseUrl, this.wsUrl});

  factory AppConfig.fromEnv() {
    const apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://100.72.232.210:4000');
    const wsBase = String.fromEnvironment('WS_URL', defaultValue: '');
    return AppConfig(baseUrl: apiBase, wsUrl: wsBase.isEmpty ? null : wsBase);
  }

  final String baseUrl;
  final String? wsUrl;
}
