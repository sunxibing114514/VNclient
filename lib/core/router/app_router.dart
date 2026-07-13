import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../../features/about/about_page.dart';
import '../../features/characters/character_detail_page.dart';
import '../../features/characters/character_list_page.dart';
import '../../features/home/home_page.dart';
import '../../features/lists/user_list_page.dart';
import '../../features/login/login_page.dart';
import '../../features/producers/producer_detail_page.dart';
import '../../features/producers/producer_list_page.dart';
import '../../features/quotes/quotes_page.dart';
import '../../features/releases/release_detail_page.dart';
import '../../features/releases/release_list_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/staff/staff_detail_page.dart';
import '../../features/staff/staff_list_page.dart';
import '../../features/tags/tag_detail_page.dart';
import '../../features/tags/tag_list_page.dart';
import '../../features/traits/trait_detail_page.dart';
import '../../features/traits/trait_list_page.dart';
import '../../features/users/user_search_page.dart';
import '../../features/vn_detail/vn_detail_page.dart';
import '../../features/webview/webview_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHome = GlobalKey<NavigatorState>();
final _shellNavigatorSearch = GlobalKey<NavigatorState>();
final _shellNavigatorList = GlobalKey<NavigatorState>();
final _shellNavigatorProfile = GlobalKey<NavigatorState>();

/// Routes that require an authenticated user.
const _protectedPrefixes = <String>['/list', '/profile'];

/// The application router.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final goingToLogin = state.matchedLocation == '/login';
      final isProtected =
          _protectedPrefixes.any((p) => state.matchedLocation.startsWith(p));

      if (isProtected && !loggedIn) {
        return '/login?from=${state.matchedLocation}';
      }
      if (goingToLogin && loggedIn) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHome,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSearch,
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorList,
            routes: [
              GoRoute(
                path: '/list',
                builder: (context, state) {
                  final tab = state.uri.queryParameters['tab'];
                  return UserListPage(initialTab: tab);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorProfile,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/vn/:id',
        builder: (context, state) =>
            VnDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/release/:id',
        builder: (context, state) =>
            ReleaseDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/character/:id',
        builder: (context, state) =>
            CharacterDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/staff/:id',
        builder: (context, state) =>
            StaffDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/producer/:id',
        builder: (context, state) =>
            ProducerDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tag/:id',
        builder: (context, state) =>
            TagDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tags',
        builder: (context, state) => const TagListPage(),
      ),
      GoRoute(
        path: '/releases',
        builder: (context, state) => const ReleaseListPage(),
      ),
      GoRoute(
        path: '/producers',
        builder: (context, state) => const ProducerListPage(),
      ),
      GoRoute(
        path: '/staff',
        builder: (context, state) => const StaffListPage(),
      ),
      GoRoute(
        path: '/characters',
        builder: (context, state) => const CharacterListPage(),
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => const UserSearchPage(),
      ),
      GoRoute(
        path: '/trait/:id',
        builder: (context, state) =>
            TraitDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/traits',
        builder: (context, state) => const TraitListPage(),
      ),
      GoRoute(
        path: '/quotes',
        builder: (context, state) => const QuotesPage(),
      ),
      GoRoute(
        path: '/user/:id',
        builder: (context, state) => ProfilePage(
          userId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/webview',
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? AppConstants.siteBaseUrl;
          final title = state.uri.queryParameters['title'];
          return WebViewPage(url: url, title: title);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面未找到')),
      body: Center(child: Text(state.error?.toString() ?? '404')),
    ),
  );
});

/// Convenience helper: navigate to the in-app WebView.
void openWebView(BuildContext context, String url, {String? title}) {
  final encoded = Uri.encodeComponent(url);
  final t = title == null ? '' : '&title=${Uri.encodeComponent(title)}';
  context.push('/webview?url=$encoded$t');
}

/// Convenience helper for opening a user profile webview.
void openUserProfile(BuildContext context, String userId) {
  openWebView(context, 'https://vndb.org/$userId', title: 'User');
}
