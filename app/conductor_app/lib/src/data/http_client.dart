import 'package:dio/dio.dart';

import 'app_config.dart';
import 'auth_storage.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final dynamic details;

  factory ApiException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final errorMessage =
        data is Map && data['message'] is String ? data['message'] as String : error.message;
    return ApiException(errorMessage ?? 'Request failed',
        statusCode: status, details: data);
  }

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  ApiClient({
    required AppConfig config,
    required AuthStorage authStorage,
    Dio? dio,
  })  : _config = config,
        _authStorage = authStorage,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: config.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                responseType: ResponseType.json,
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  final AppConfig _config;
  final AuthStorage _authStorage;
  final Dio _dio;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _wrap(() => _dio.get<T>(path, queryParameters: query));
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
  }) async {
    return _wrap(() => _dio.post<T>(path, data: data));
  }

  Future<Response<T>> _wrap<T>(
      Future<Response<T>> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
