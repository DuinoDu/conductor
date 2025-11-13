abstract class AuthStorage {
  Future<String?> readToken();
}

class InMemoryAuthStorage implements AuthStorage {
  InMemoryAuthStorage({String? initialToken}) : _token = initialToken;

  String? _token;

  void writeToken(String? token) {
    _token = token;
  }

  @override
  Future<String?> readToken() async => _token;
}

class EnvAuthStorage implements AuthStorage {
  static const _envToken = String.fromEnvironment('AUTH_TOKEN', defaultValue: '');

  @override
  Future<String?> readToken() async => _envToken.isEmpty ? null : _envToken;
}
