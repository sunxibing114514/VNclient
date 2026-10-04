import 'dart:convert';

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

/// A stored (remembered) account, kept so the user can switch between
/// multiple VNDB accounts from the settings page without re-entering tokens.
class StoredAccount {
  const StoredAccount({
    required this.token,
    required this.id,
    required this.username,
  });

  /// The VNDB API token.
  final String token;

  /// The VNDB user id, e.g. "u12345".
  final String id;

  /// The VNDB username.
  final String username;

  Map<String, dynamic> toJson() => {
        'token': token,
        'id': id,
        'username': username,
      };

  factory StoredAccount.fromJson(Map<String, dynamic> json) => StoredAccount(
        token: json['token'] as String? ?? '',
        id: json['id'] as String? ?? '',
        username: json['username'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is StoredAccount && other.token == token;

  @override
  int get hashCode => token.hashCode;
}

/// Persisted authentication state for the current session.
class AuthState {
  const AuthState({
    this.token,
    this.user,
    this.status = AuthStatus.unknown,
    this.error,
    this.accounts = const [],
  });

  final String? token;
  final UserInfo? user;
  final AuthStatus status;
  final String? error;

  /// All remembered accounts (including the currently active one).
  final List<StoredAccount> accounts;

  bool get isAuthenticated => user != null && token != null;
  bool get canWriteList => user?.canWriteList ?? false;

  StoredAccount? get currentAccount {
    if (token == null) return null;
    for (final a in accounts) {
      if (a.token == token) return a;
    }
    return null;
  }

  AuthState copyWith({
    String? token,
    UserInfo? user,
    AuthStatus? status,
    String? error,
    List<StoredAccount>? accounts,
    bool clearToken = false,
    bool clearUser = false,
  }) {
    return AuthState(
      token: clearToken ? null : (token ?? this.token),
      user: clearUser ? null : (user ?? this.user),
      status: status ?? this.status,
      error: error,
      accounts: accounts ?? this.accounts,
    );
  }
}

enum AuthStatus { unknown, authenticated, unauthenticated, loading, error }

/// Notifier that owns the API token, validates it against `/authinfo`
/// and persists it through [FlutterSecureStorage].
///
/// Supports multiple remembered accounts: [login] adds the validated account
/// to the stored list, [switchAccount] switches the active account and
/// [removeAccount] forgets one. [logout] only signs out to guest mode and
/// keeps all remembered accounts.
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
    final accounts = await _loadAccounts();
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token == null || token.isEmpty) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        accounts: accounts,
      );
      return;
    }
    await _applyToken(token);
  }

  Future<List<StoredAccount>> _loadAccounts() async {
    try {
      final raw = await _storage.read(key: AppConstants.accountsKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => StoredAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveAccounts(List<StoredAccount> accounts) async {
    await _storage.write(
      key: AppConstants.accountsKey,
      value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  Future<void> _applyToken(String token) async {
    _client.setToken(token);
    state = state.copyWith(
      token: token,
      status: AuthStatus.loading,
    );
    try {
      final json = await _client.get('/authinfo');
      final user = UserInfo.fromJson(json);
      await _storage.write(key: AppConstants.tokenKey, value: token);
      await _storage.write(key: AppConstants.userIdKey, value: user.id);
      await _storage.write(key: AppConstants.usernameKey, value: user.username);
      state = state.copyWith(
        token: token,
        user: user,
        status: AuthStatus.authenticated,
      );
    } on VndbApiException catch (e) {
      if (e.isUnauthorized) {
        await _clearSession();
        _client.setToken(null);
        state = state.copyWith(
          clearToken: true,
          clearUser: true,
          status: AuthStatus.unauthenticated,
        );
      } else {
        state = state.copyWith(
          token: token,
          status: AuthStatus.error,
          error: e.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        token: token,
        status: AuthStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Validates and stores the given token, remembers the account and makes
  /// it the active one.
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
    if (state.status == AuthStatus.authenticated) {
      await _rememberAccount(StoredAccount(
        token: trimmed,
        id: state.user?.id ?? '',
        username: state.user?.username ?? '',
      ));
      return true;
    }
    return false;
  }

  /// Adds or updates an account in the remembered list (deduplicated by
  /// token; a re-login by the same user updates the stored token).
  Future<void> _rememberAccount(StoredAccount account) async {
    if (account.token.isEmpty) return;
    final accounts = List<StoredAccount>.from(state.accounts)
      ..removeWhere((a) =>
          a.token == account.token ||
          (account.id.isNotEmpty && a.id == account.id))
      ..insert(0, account);
    await _saveAccounts(accounts);
    state = state.copyWith(accounts: accounts);
  }

  /// Switches the active account to the one holding [token] and re-validates
  /// it against the API.
  Future<bool> switchAccount(String token) async {
    final account = state.accounts.where((a) => a.token == token).firstOrNull;
    if (account == null) return false;
    await _applyToken(account.token);
    return state.status == AuthStatus.authenticated;
  }

  /// Forgets a remembered account. When it is the currently active one, the
  /// session is signed out as well.
  Future<void> removeAccount(String token) async {
    final accounts = List<StoredAccount>.from(state.accounts)
      ..removeWhere((a) => a.token == token);
    await _saveAccounts(accounts);
    if (state.token == token) {
      await _clearSession();
      _client.setToken(null);
      state = state.copyWith(
        clearToken: true,
        clearUser: true,
        status: AuthStatus.unauthenticated,
        accounts: accounts,
      );
    } else {
      state = state.copyWith(accounts: accounts);
    }
  }

  /// Signs out to guest mode while keeping all remembered accounts so the
  /// user can switch back later.
  Future<void> logout() async {
    await _clearSession();
    _client.setToken(null);
    state = state.copyWith(
      clearToken: true,
      clearUser: true,
      status: AuthStatus.unauthenticated,
    );
  }

  /// Called by the HTTP layer when a 401 is observed.
  Future<void> handleAuthInvalid() async {
    await _clearSession();
    _client.setToken(null);
    state = state.copyWith(
      clearToken: true,
      clearUser: true,
      status: AuthStatus.unauthenticated,
    );
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.userIdKey);
    await _storage.delete(key: AppConstants.usernameKey);
  }
}
