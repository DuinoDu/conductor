import 'package:conductor_app/src/data/app_config.dart';
import 'package:conductor_app/src/data/auth_storage.dart';
import 'package:conductor_app/src/data/http_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  group('ApiClient', () {
    late Dio dio;
    late DioAdapter adapter;
    late ApiClient client;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.local'));
      adapter = DioAdapter(dio: dio);
      client = ApiClient(
        config: const AppConfig(baseUrl: 'https://api.local'),
        authStorage: InMemoryAuthStorage(initialToken: 'abc'),
        dio: dio,
      );
    });

    test('attaches bearer token headers on requests', () async {
      adapter.onGet(
        '/health',
        (server) => server.reply(200, {'ok': true}),
        headers: {'Authorization': 'Bearer abc'},
      );

      final response = await client.get<dynamic>('/health');
      expect(response.data, {'ok': true});
    });

    test('throws ApiException on dio errors', () async {
      adapter.onPost(
        '/tasks',
        (server) => server.reply(500, {'message': 'server error'}),
      );

      expect(
        () => client.post('/tasks', data: {'title': 'X'}),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
