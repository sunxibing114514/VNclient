import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/locale_provider.dart';

/// A minimal string-translation layer keyed by language code.
///
/// Strings default to Chinese (`zh`); English (`en`) translations are provided
/// for the primary UI surfaces. Untranslated keys fall back to Chinese.
class L10n {
  L10n(this.locale);

  final Locale locale;
  String get code => locale.languageCode;

  static const _strings = <String, Map<String, String>>{
    'home': {'zh': '首页', 'en': 'Home'},
    'search': {'zh': '搜索', 'en': 'Search'},
    'list': {'zh': '列表', 'en': 'List'},
    'profile': {'zh': '我的', 'en': 'Profile'},
    'settings': {'zh': '设置', 'en': 'Settings'},
    'randomVn': {'zh': '随机 VN', 'en': 'Random VN'},
    'dbStats': {'zh': '数据库统计', 'en': 'Database Stats'},
    'recentChanges': {'zh': '最近更改', 'en': 'Recent Changes'},
    'upcoming': {'zh': '即将发售', 'en': 'Upcoming'},
    'justReleased': {'zh': '刚刚发售', 'en': 'Just Released'},
    'siteAndCommunity': {'zh': '站点与社区', 'en': 'Site & Community'},
    'myMenu': {'zh': '我的菜单', 'en': 'My Menu'},
    'myProfile': {'zh': '我的资料', 'en': 'My Profile'},
    'myVnList': {'zh': '我的 VN 列表', 'en': 'My VN List'},
    'myVotes': {'zh': '我的投票', 'en': 'My Votes'},
    'myWishlist': {'zh': '我的愿望单', 'en': 'My Wishlist'},
    'myRecentChanges': {'zh': '我的最近更改', 'en': 'My Recent Changes'},
    'myTags': {'zh': '我的标签', 'en': 'My Tags'},
    'editorTools': {'zh': '编辑工具', 'en': 'Editor Tools'},
    'signInPrompt': {'zh': '登录以管理你的列表', 'en': 'Sign in to manage your lists'},
    'signInPromptDesc': {
      'zh': '使用 API Token 登录后可访问你的个人列表、投票与愿望单。',
      'en': 'Sign in with an API token to access your lists, votes and wishlist.'
    },
    'signIn': {'zh': '登录', 'en': 'Sign In'},
    'about': {'zh': '关于', 'en': 'About'},
    'privacyPolicy': {'zh': '隐私政策', 'en': 'Privacy Policy'},
    'dataSource': {
      'zh': '数据来源: vndb.org · 非官方客户端',
      'en': 'Data source: vndb.org · Unofficial client'
    },
    'all': {'zh': '全部', 'en': 'All'},
    'votes': {'zh': '投票', 'en': 'Votes'},
    'wishlist': {'zh': '愿望单', 'en': 'Wishlist'},
    'myList': {'zh': '我的列表', 'en': 'My List'},
    'pleaseLogin': {'zh': '请先登录', 'en': 'Please sign in first'},
    'listEmpty': {'zh': '列表为空', 'en': 'List is empty'},
    'retry': {'zh': '重试', 'en': 'Retry'},
    'remove': {'zh': '移除', 'en': 'Remove'},
    'cancel': {'zh': '取消', 'en': 'Cancel'},
    'save': {'zh': '保存', 'en': 'Save'},
    'confirm': {'zh': '确定', 'en': 'Confirm'},
    'removeConfirm': {
      'zh': '从列表移除 %{title} 吗？',
      'en': 'Remove %{title} from list?'
    },
    'account': {'zh': '账户', 'en': 'Account'},
    'apiToken': {'zh': 'API Token', 'en': 'API Token'},
    'loggedIn': {'zh': '已登录', 'en': 'Signed in'},
    'notLoggedIn': {'zh': '未登录', 'en': 'Not signed in'},
    'logout': {'zh': '退出', 'en': 'Logout'},
    'webViewLogin': {'zh': '网页登录 (WebView)', 'en': 'WebView Login'},
    'webViewLoginDesc': {
      'zh': '可选: 输入 VNDB 用户名与密码，用于在内嵌浏览器中快速登录。凭据仅保存在本地安全存储中。',
      'en': 'Optional: enter VNDB username and password for quick login in the embedded browser. Credentials are stored only in local secure storage.'
    },
    'username': {'zh': '用户名', 'en': 'Username'},
    'password': {'zh': '密码', 'en': 'Password'},
    'saveCredentials': {'zh': '保存凭据', 'en': 'Save Credentials'},
    'openWebLogin': {'zh': '打开网页登录', 'en': 'Open Web Login'},
    'savedCredentials': {'zh': '已保存网页登录凭据', 'en': 'Web login credentials saved'},
    'aboutClient': {'zh': '关于本客户端', 'en': 'About this client'},
    'apiDocs': {'zh': 'API 文档', 'en': 'API Docs'},
    'appearance': {'zh': '外观', 'en': 'Appearance'},
    'seedColor': {'zh': '主题色', 'en': 'Seed Color'},
    'themeMode': {'zh': '主题模式', 'en': 'Theme Mode'},
    'dark': {'zh': '深色', 'en': 'Dark'},
    'light': {'zh': '浅色', 'en': 'Light'},
    'system': {'zh': '跟随系统', 'en': 'System'},
    'language': {'zh': '语言', 'en': 'Language'},
    'chinese': {'zh': '中文', 'en': 'Chinese'},
    'english': {'zh': '英文', 'en': 'English'},
    'searchReleases': {'zh': '搜索发售…', 'en': 'Search releases…'},
    'searchProducers': {'zh': '搜索制作商…', 'en': 'Search producers…'},
    'searchStaff': {'zh': '搜索 Staff…', 'en': 'Search staff…'},
    'searchCharacters': {'zh': '搜索角色…', 'en': 'Search characters…'},
    'searchTags': {'zh': '搜索标签…', 'en': 'Search tags…'},
    'searchTraits': {'zh': '搜索特质…', 'en': 'Search traits…'},
    'searchUsers': {'zh': '输入用户名或 ID (如 yorhel)', 'en': 'Enter username or ID (e.g. yorhel)'},
    'notFound': {'zh': '未找到', 'en': 'Not found'},
    'noResultsReleases': {'zh': '未找到发售', 'en': 'No releases found'},
    'noResultsProducers': {'zh': '未找到制作商', 'en': 'No producers found'},
    'noResultsStaff': {'zh': '未找到 Staff', 'en': 'No staff found'},
    'noResultsCharacters': {'zh': '未找到角色', 'en': 'No characters found'},
    'noResultsTags': {'zh': '未找到标签', 'en': 'No tags found'},
    'userNotFound': {'zh': '未找到该用户', 'en': 'User not found'},
    'findUserPrompt': {'zh': '输入用户名或 ID 查找用户', 'en': 'Enter username or ID to find a user'},
    'none': {'zh': '暂无', 'en': 'None'},
    'more': {'zh': '更多', 'en': 'More'},
    'pageNotFound': {'zh': '页面未找到', 'en': 'Page not found'},
    'characters': {'zh': '角色', 'en': 'Characters'},
    'notLogin': {'zh': '未登录', 'en': 'Not signed in'},
    'logoutConfirm': {'zh': '退出登录', 'en': 'Sign out'},
    'logoutConfirmDesc': {'zh': '确定退出登录吗？', 'en': 'Are you sure you want to sign out?'},
    'confirmLogout': {'zh': '退出', 'en': 'Sign out'},
    'viewOnWeb': {'zh': '在网页查看', 'en': 'View on Web'},
    'userProfile': {'zh': '用户资料', 'en': 'User Profile'},
    'imageReview': {'zh': '图片审核', 'en': 'Image Flagging'},
    'addVn': {'zh': '添加 Visual Novel', 'en': 'Add Visual Novel'},
    'addProducer': {'zh': '添加 Producer', 'en': 'Add Producer'},
    'addStaff': {'zh': '添加 Staff', 'en': 'Add Staff'},
    'discussionBoard': {'zh': '讨论版', 'en': 'Discussion Board'},
    'faq': {'zh': 'FAQ', 'en': 'FAQ'},
    'dbDiscussions': {'zh': '数据库讨论', 'en': 'DB Discussions'},
    'vnDiscussions': {'zh': 'VN 讨论', 'en': 'VN Discussions'},
    'reviews': {'zh': '最新评测', 'en': 'Latest Reviews'},
  };

  /// Translates [key], substituting `%{name}` placeholders from [params].
  String tr(String key, {Map<String, String>? params}) {
    var value = _strings[key]?[code] ?? _strings[key]?['zh'] ?? key;
    if (params != null) {
      params.forEach((name, replacement) {
        value = value.replaceAll('%{$name}', replacement);
      });
    }
    return value;
  }
}

/// Provides the current [L10n] based on the selected locale.
final l10nProvider = Provider<L10n>((ref) {
  final locale = ref.watch(localeNotifierProvider);
  return L10n(locale);
});

/// Extension for convenient `context.tr` access.
extension L10nContext on BuildContext {
  String tr(String key, {Map<String, String>? params}) {
    return _tr(key, params);
  }
}

/// Standalone translator used by widgets without a ref. Defaults to Chinese.
String _tr(String key, Map<String, String>? params) {
  var value = L10n._strings[key]?['zh'] ?? key;
  if (params != null) {
    params.forEach((name, replacement) {
      value = value.replaceAll('%{$name}', replacement);
    });
  }
  return value;
}
