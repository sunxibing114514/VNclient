import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/vndb_client.dart';
import '../constants/app_constants.dart';
import '../models/user_info.dart';
import 'client_provider.dart';

/// Riverpod provider for [AuthNotifier].
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(vndbClientProvider);
  return AuthNotifier(client);
});

/// Persisted authentication state for the current session.
class AuthState {
  const AuthState({
    this.token,
    this.user,
    this.status = AuthStatus.unknown,
    this.error,
  });

  final String? token;
  final UserInfo? user;
  final AuthStatus status;
  final String? error;

  bool get isAuthenticated => user != null && token != null;
  bool get canWriteList => user?.canWriteList ?? false;

  AuthState copyWith({
    String? token,
    UserInfo? user,
    AuthStatus? status,
    String? error,
    bool clearToken = false,
    bool clearUser = false,
  }) {
    return AuthState(
      token: clearToken ? null : (token ?? this.token),
      user: clearUser ? null : (user ?? this.user),
      status: status ?? this.status,
      error: error,
    );
  }
}

enum AuthStatus { unknown, authenticated, unauthenticated, loading, error }

/// Notifier that owns the API token, validates it against `/authinfo`
/// and persists it through [FlutterSecureStorage].
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._client)
      : super(const AuthState(status: AuthStatus.unknown)) {
    // Wire the HTTP layer's 401 callback back to this notifier.
    _client.onAuthInvalid = () {
      Future.microtask(() => handleAuthInvalid());
    };
    _bootstrap();
  }

  final VndbClient _client;
  static const _storage = FlutterSecureStorage();

  Future<void> _bootstrap() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    await _applyToken(token);
  }

  Future<void> _applyToken(String token) async {
    _client.setToken(token);
    state = AuthState(
      token: token,
      status: AuthStatus.loading,
    );
    try {
      final json = await _client.get('/authinfo');
      final user = UserInfo.fromJson(json);
      await _storage.write(key: AppConstants.tokenKey, value: token);
      await _storage.write(key: AppConstants.userIdKey, value: user.id);
      await _storage.write(key: AppConstants.usernameKey, value: user.username);
      state = AuthState(
        token: token,
        user: user,
        status: AuthStatus.authenticated,
      );
    } on VndbApiException catch (e) {
      if (e.isUnauthorized) {
        await _clearStorage();
        _client.setToken(null);
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        state = AuthState(
          token: token,
          status: AuthStatus.error,
          error: e.message,
        );
      }
    } catch (e) {
      state = AuthState(
        token: token,
        status: AuthStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Validates and stores the given token.
  Future<bool> login(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Token cannot be empty',
      );
      return false;
    }
    await _applyToken(trimmed);
    return state.status == AuthStatus.authenticated;
  }

  /// Clears the stored token and signs the user out.
  Future<void> logout() async {
    await _clearStorage();
    _client.setToken(null);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Called by the HTTP layer when a 401 is observed.
  Future<void> handleAuthInvalid() async {
    await _clearStorage();
    _client.setToken(null);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _clearStorage() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.userIdKey);
    await _storage.delete(key: AppConstants.usernameKey);
  }
}
