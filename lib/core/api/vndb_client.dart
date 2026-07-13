import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// Thrown when the VNDB API rejects a request with an HTTP error.
class VndbApiException implements Exception {
  VndbApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isThrottled => statusCode == 429;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'VndbApiException($statusCode): $message';
}

/// Callback used to notify the auth layer that the current token is invalid.
typedef OnAuthInvalid = void Function();

/// A thin HTTP client for the VNDB Kana API.
///
/// Handles:
///  - token injection via the `Authorization: Token <token>` header,
///  - 401/429/500 mapping to [VndbApiException],
///  - a simple in-memory rate-limit guard (200 req / 5 min).
class VndbClient {
  VndbClient({String? token, this.onAuthInvalid}) : _token = token {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (_token != null) 'Authorization': 'Token $_token',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) {
          final response = e.response;
          if (response != null) {
            final code = response.statusCode ?? 0;
            String msg = '';
            try {
              msg = response.data is String
                  ? response.data as String
                  : response.data.toString();
            } catch (_) {
              msg = e.message ?? '';
            }
            final apiError = VndbApiException(code, msg);
            if (apiError.isUnauthorized) {
              onAuthInvalid?.call();
            }
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                error: apiError,
                type: e.type,
                response: response,
              ),
            );
          }
          handler.next(e);
        },
      ),
    );
  }

  String? _token;
  OnAuthInvalid? onAuthInvalid;

  late final Dio _dio;

  // Simple sliding-window rate limit bookkeeping.
  final List<DateTime> _requestTimes = [];

  /// Updates the auth token and rebuilds the auth header.
  void setToken(String? token) {
    _token = token;
    _dio.options.headers['Authorization'] =
        token == null ? null : 'Token $token';
  }

  String? get token => _token;

  /// Releases underlying HTTP resources.
  void close() => _dio.close(force: true);

  bool _rateLimitAllows() {
    final now = DateTime.now();
    final cutoff = now.subtract(
      const Duration(seconds: AppConstants.rateLimitWindowSeconds),
    );
    _requestTimes.removeWhere((t) => t.isBefore(cutoff));
    return _requestTimes.length < AppConstants.rateLimitRequests;
  }

  void _recordRequest() {
    _requestTimes.add(DateTime.now());
  }

  /// Performs a GET request and returns the decoded JSON body.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (!_rateLimitAllows()) {
      throw VndbApiException(
        429,
        'Client-side rate limit reached. Please slow down.',
      );
    }
    _recordRequest();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return response.data ?? const {};
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Performs a POST query against a database endpoint (e.g. `/vn`).
  ///
  /// [body] should follow the Kana query format documented at
  /// https://api.vndb.org/kana.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    if (!_rateLimitAllows()) {
      throw VndbApiException(
        429,
        'Client-side rate limit reached. Please slow down.',
      );
    }
    _recordRequest();
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return response.data ?? const {};
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Performs a PATCH request (e.g. updating a user list entry).
  Future<void> patch(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    if (!_rateLimitAllows()) {
      throw VndbApiException(429, 'Client-side rate limit reached.');
    }
    _recordRequest();
    try {
      await _dio.patch<void>(path, data: body);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Performs a DELETE request (e.g. removing a user list entry).
  Future<void> delete(String path) async {
    if (!_rateLimitAllows()) {
      throw VndbApiException(429, 'Client-side rate limit reached.');
    }
    _recordRequest();
    try {
      await _dio.delete<void>(path);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  Exception _translate(DioException e) {
    if (e.error is VndbApiException) return e.error as VndbApiException;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return VndbApiException(0, 'Network error: ${e.message}');
    }
    return VndbApiException(
      e.response?.statusCode ?? 0,
      e.message ?? 'Unknown error',
    );
  }
}
