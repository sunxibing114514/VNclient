import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/locale_provider.dart';

/// A minimal string-translation layer keyed by language code.
///
/// Strings default to Chinese (`zh`); English (`en`) and Japanese (`ja`)
/// translations are provided for the primary UI surfaces. Untranslated keys
/// fall back to Chinese.
class L10n {
  L10n(this.locale);

  final Locale locale;
  String get code => locale.languageCode;

  static const _strings = <String, Map<String, String>>{
    'home': {'zh': '首页', 'en': 'Home', 'ja': 'ホーム'},
    'search': {'zh': '搜索', 'en': 'Search', 'ja': '検索'},
    'list': {'zh': '列表', 'en': 'List', 'ja': 'リスト'},
    'profile': {'zh': '我的', 'en': 'Profile', 'ja': 'プロフィール'},
    'settings': {'zh': '设置', 'en': 'Settings', 'ja': '設定'},
    'randomVn': {'zh': '随机 VN', 'en': 'Random VN', 'ja': 'ランダム VN'},
    'dbStats': {
      'zh': '数据库统计',
      'en': 'Database Stats',
      'ja': 'データベース統計'
    },
    'recentChanges': {
      'zh': '最近更改',
      'en': 'Recent Changes',
      'ja': '最近の変更'
    },
    'upcoming': {'zh': '即将发售', 'en': 'Upcoming', 'ja': '発売予定'},
    'justReleased': {
      'zh': '刚刚发售',
      'en': 'Just Released',
      'ja': '最近発売'
    },
    'siteAndCommunity': {
      'zh': '站点与社区',
      'en': 'Site & Community',
      'ja': 'サイトとコミュニティ'
    },
    'myMenu': {'zh': '我的菜单', 'en': 'My Menu', 'ja': 'マイメニュー'},
    'myProfile': {'zh': '我的资料', 'en': 'My Profile', 'ja': 'マイプロフィール'},
    'myVnList': {
      'zh': '我的 VN 列表',
      'en': 'My VN List',
      'ja': 'マイ VN リスト'
    },
    'myVotes': {'zh': '我的投票', 'en': 'My Votes', 'ja': 'マイ投票'},
    'myWishlist': {'zh': '我的愿望单', 'en': 'My Wishlist', 'ja': 'マイウィッシュリスト'},
    'myRecentChanges': {
      'zh': '我的最近更改',
      'en': 'My Recent Changes',
      'ja': 'マイ最近の変更'
    },
    'myTags': {'zh': '我的标签', 'en': 'My Tags', 'ja': 'マイタグ'},
    'editorTools': {'zh': '编辑工具', 'en': 'Editor Tools', 'ja': '編集ツール'},
    'signInPrompt': {
      'zh': '登录以管理你的列表',
      'en': 'Sign in to manage your lists',
      'ja': 'リストを管理するにはログイン'
    },
    'signInPromptDesc': {
      'zh': '使用 API Token 登录后可访问你的个人列表、投票与愿望单。',
      'en': 'Sign in with an API token to access your lists, votes and wishlist.',
      'ja': 'APIトークンでログインすると、個人リスト・投票・ウィッシュリストにアクセスできます。'
    },
    'signIn': {'zh': '登录', 'en': 'Sign In', 'ja': 'ログイン'},
    'about': {'zh': '关于', 'en': 'About', 'ja': 'について'},
    'privacyPolicy': {'zh': '隐私政策', 'en': 'Privacy Policy', 'ja': 'プライバシーポリシー'},
    'dataSource': {
      'zh': '数据来源: vndb.org · 非官方客户端',
      'en': 'Data source: vndb.org · Unofficial client',
      'ja': 'データ元: vndb.org · 非公式クライアント'
    },
    'all': {'zh': '全部', 'en': 'All', 'ja': '全て'},
    'votes': {'zh': '投票', 'en': 'Votes', 'ja': '投票'},
    'wishlist': {'zh': '愿望单', 'en': 'Wishlist', 'ja': 'ウィッシュリスト'},
    'myList': {'zh': '我的列表', 'en': 'My List', 'ja': 'マイリスト'},
    'pleaseLogin': {
      'zh': '请先登录',
      'en': 'Please sign in first',
      'ja': '先にログインしてください'
    },
    'listEmpty': {'zh': '列表为空', 'en': 'List is empty', 'ja': 'リストは空です'},
    'retry': {'zh': '重试', 'en': 'Retry', 'ja': '再試行'},
    'remove': {'zh': '移除', 'en': 'Remove', 'ja': '削除'},
    'cancel': {'zh': '取消', 'en': 'Cancel', 'ja': 'キャンセル'},
    'save': {'zh': '保存', 'en': 'Save', 'ja': '保存'},
    'confirm': {'zh': '确定', 'en': 'Confirm', 'ja': '確認'},
    'removeConfirm': {
      'zh': '从列表移除 %{title} 吗？',
      'en': 'Remove %{title} from list?',
      'ja': 'リストから %{title} を削除しますか？'
    },
    'account': {'zh': '账户', 'en': 'Account', 'ja': 'アカウント'},
    'apiToken': {'zh': 'API Token', 'en': 'API Token', 'ja': 'APIトークン'},
    'loggedIn': {'zh': '已登录', 'en': 'Signed in', 'ja': 'ログイン済み'},
    'notLoggedIn': {'zh': '未登录', 'en': 'Not signed in', 'ja': '未ログイン'},
    'logout': {'zh': '退出', 'en': 'Logout', 'ja': 'ログアウト'},
    'webViewLogin': {
      'zh': '网页登录 (WebView)',
      'en': 'WebView Login',
      'ja': 'ウェブログイン (WebView)'
    },
    'webViewLoginDesc': {
      'zh': '可选: 输入 VNDB 用户名与密码，用于在内嵌浏览器中快速登录。凭据仅保存在本地安全存储中。',
      'en': 'Optional: enter VNDB username and password for quick login in the embedded browser. Credentials are stored only in local secure storage.',
      'ja': 'オプション: 内蔵ブラウザで素早くログインするための VNDB ユーザー名とパスワード。認証情報はローカルのセキュアストレージにのみ保存されます。'
    },
    'username': {'zh': '用户名', 'en': 'Username', 'ja': 'ユーザー名'},
    'password': {'zh': '密码', 'en': 'Password', 'ja': 'パスワード'},
    'saveCredentials': {
      'zh': '保存凭据',
      'en': 'Save Credentials',
      'ja': '認証情報を保存'
    },
    'openWebLogin': {
      'zh': '打开网页登录',
      'en': 'Open Web Login',
      'ja': 'ウェブログインを開く'
    },
    'savedCredentials': {
      'zh': '已保存网页登录凭据',
      'en': 'Web login credentials saved',
      'ja': 'ウェブログイン情報を保存しました'
    },
    'aboutClient': {
      'zh': '关于本客户端',
      'en': 'About this client',
      'ja': 'このクライアントについて'
    },
    'apiDocs': {'zh': 'API 文档', 'en': 'API Docs', 'ja': 'APIドキュメント'},
    'appearance': {'zh': '外观', 'en': 'Appearance', 'ja': '外観'},
    'seedColor': {'zh': '主题色', 'en': 'Seed Color', 'ja': 'テーマカラー'},
    'themeMode': {'zh': '主题模式', 'en': 'Theme Mode', 'ja': 'テーマモード'},
    'dark': {'zh': '深色', 'en': 'Dark', 'ja': 'ダーク'},
    'light': {'zh': '浅色', 'en': 'Light', 'ja': 'ライト'},
    'system': {'zh': '跟随系统', 'en': 'System', 'ja': 'システムに従う'},
    'language': {'zh': '语言', 'en': 'Language', 'ja': '言語'},
    'chinese': {'zh': '中文', 'en': 'Chinese', 'ja': '中国語'},
    'english': {'zh': '英文', 'en': 'English', 'ja': '英語'},
    'japanese': {'zh': '日文', 'en': 'Japanese', 'ja': '日本語'},
    'searchReleases': {
      'zh': '搜索发售…',
      'en': 'Search releases…',
      'ja': 'リリースを検索…'
    },
    'searchProducers': {
      'zh': '搜索制作商…',
      'en': 'Search producers…',
      'ja': '制作元を検索…'
    },
    'searchStaff': {
      'zh': '搜索 Staff…',
      'en': 'Search staff…',
      'ja': 'スタッフを検索…'
    },
    'searchCharacters': {
      'zh': '搜索角色…',
      'en': 'Search characters…',
      'ja': 'キャラクターを検索…'
    },
    'searchTags': {'zh': '搜索标签…', 'en': 'Search tags…', 'ja': 'タグを検索…'},
    'searchTraits': {
      'zh': '搜索特质…',
      'en': 'Search traits…',
      'ja': '特徴を検索…'
    },
    'searchUsers': {
      'zh': '输入用户名或 ID (如 yorhel)',
      'en': 'Enter username or ID (e.g. yorhel)',
      'ja': 'ユーザー名または ID を入力 (例: yorhel)'
    },
    'notFound': {'zh': '未找到', 'en': 'Not found', 'ja': '見つかりません'},
    'noResultsReleases': {
      'zh': '未找到发售',
      'en': 'No releases found',
      'ja': 'リリースが見つかりません'
    },
    'noResultsProducers': {
      'zh': '未找到制作商',
      'en': 'No producers found',
      'ja': '制作元が見つかりません'
    },
    'noResultsStaff': {
      'zh': '未找到 Staff',
      'en': 'No staff found',
      'ja': 'スタッフが見つかりません'
    },
    'noResultsCharacters': {
      'zh': '未找到角色',
      'en': 'No characters found',
      'ja': 'キャラクターが見つかりません'
    },
    'noResultsTags': {
      'zh': '未找到标签',
      'en': 'No tags found',
      'ja': 'タグが見つかりません'
    },
    'userNotFound': {
      'zh': '未找到该用户',
      'en': 'User not found',
      'ja': 'ユーザーが見つかりません'
    },
    'findUserPrompt': {
      'zh': '输入用户名或 ID 查找用户',
      'en': 'Enter username or ID to find a user',
      'ja': 'ユーザー名または ID でユーザーを検索'
    },
    'none': {'zh': '暂无', 'en': 'None', 'ja': 'なし'},
    'more': {'zh': '更多', 'en': 'More', 'ja': 'もっと見る'},
    'pageNotFound': {
      'zh': '页面未找到',
      'en': 'Page not found',
      'ja': 'ページが見つかりません'
    },
    'characters': {'zh': '角色', 'en': 'Characters', 'ja': 'キャラクター'},
    'notLogin': {'zh': '未登录', 'en': 'Not signed in', 'ja': '未ログイン'},
    'logoutConfirm': {'zh': '退出登录', 'en': 'Sign out', 'ja': 'ログアウト'},
    'logoutConfirmDesc': {
      'zh': '确定退出登录吗？',
      'en': 'Are you sure you want to sign out?',
      'ja': 'ログアウトしますか？'
    },
    'confirmLogout': {'zh': '退出', 'en': 'Sign out', 'ja': 'ログアウト'},
    'viewOnWeb': {'zh': '在网页查看', 'en': 'View on Web', 'ja': 'ウェブで見る'},
    'userProfile': {'zh': '用户资料', 'en': 'User Profile', 'ja': 'ユーザープロフィール'},
    'imageReview': {'zh': '图片审核', 'en': 'Image Flagging', 'ja': '画像審査'},
    'addVn': {
      'zh': '添加 Visual Novel',
      'en': 'Add Visual Novel',
      'ja': 'Visual Novel を追加'
    },
    'addProducer': {
      'zh': '添加 Producer',
      'en': 'Add Producer',
      'ja': 'Producer を追加'
    },
    'addStaff': {
      'zh': '添加 Staff',
      'en': 'Add Staff',
      'ja': 'Staff を追加'
    },
    'discussionBoard': {
      'zh': '讨论版',
      'en': 'Discussion Board',
      'ja': '掲示板'
    },
    'faq': {'zh': 'FAQ', 'en': 'FAQ', 'ja': 'よくある質問'},
    'dbDiscussions': {
      'zh': '数据库讨论',
      'en': 'DB Discussions',
      'ja': 'DB議論'
    },
    'vnDiscussions': {
      'zh': 'VN 讨论',
      'en': 'VN Discussions',
      'ja': 'VN議論'
    },
    'reviews': {'zh': '最新评测', 'en': 'Latest Reviews', 'ja': '最新レビュー'},
    // ---- 额外键 (今日生日 / 高级筛选 / 加入列表 等) ----
    'todayBirthdays': {
      'zh': '今日生日',
      'en': 'Today\'s Birthdays',
      'ja': '今日誕生日'
    },
    'advancedFilters': {
      'zh': '高级筛选',
      'en': 'Advanced Filters',
      'ja': '詳細フィルター'
    },
    'reset': {'zh': '重置', 'en': 'Reset', 'ja': 'リセット'},
    'language_label': {'zh': '语言', 'en': 'Language', 'ja': '言語'},
    'platform': {'zh': '平台', 'en': 'Platform', 'ja': 'プラットフォーム'},
    'releasedFrom': {
      'zh': '发行起 (YYYY)',
      'en': 'Released from (YYYY)',
      'ja': '発売日から (YYYY)'
    },
    'releasedTo': {
      'zh': '发行止 (YYYY)',
      'en': 'Released to (YYYY)',
      'ja': '発売日まで (YYYY)'
    },
    'minBayesianRating': {
      'zh': '最低贝叶斯评分',
      'en': 'Min Bayesian Rating',
      'ja': '最低ベイズ評価'
    },
    'tagId': {'zh': '标签 ID (如 g1)', 'en': 'Tag ID (e.g. g1)', 'ja': 'タグ ID (例: g1)'},
    'developerId': {
      'zh': '开发商 ID 或名称 (如 p1)',
      'en': 'Developer ID or name (e.g. p1)',
      'ja': '開発者 ID または名前 (例: p1)'
    },
    'sort': {'zh': '排序', 'en': 'Sort', 'ja': 'ソート'},
    'reverse': {'zh': '倒序', 'en': 'Reverse', 'ja': '降順'},
    'apply': {'zh': '应用筛选', 'en': 'Apply', 'ja': '適用'},
    'addToList': {'zh': '加入列表', 'en': 'Add to List', 'ja': 'リストに追加'},
    'editListEntry': {
      'zh': '编辑列表条目',
      'en': 'Edit List Entry',
      'ja': 'リストエントリを編集'
    },
    'inList': {'zh': '已在列表中', 'en': 'Already in list', 'ja': 'リストに登録済み'},
    'yourVote': {'zh': '你的评分', 'en': 'Your vote', 'ja': 'あなたの評価'},
    'yourLabels': {'zh': '你的标签', 'en': 'Your labels', 'ja': 'あなたのラベル'},
    'notes': {'zh': '备注', 'en': 'Notes', 'ja': 'メモ'},
    'startedAt': {'zh': '开始于', 'en': 'Started', 'ja': '開始日'},
    'finishedAt': {'zh': '完成于', 'en': 'Finished', 'ja': '完了日'},
    'removeFromList': {
      'zh': '从列表移除',
      'en': 'Remove from list',
      'ja': 'リストから削除'
    },
    'removeConfirmTitle': {
      'zh': '移除',
      'en': 'Remove',
      'ja': '削除'
    },
    'removeConfirmMsg': {
      'zh': '确定从列表中移除这个 VN 吗？',
      'en': 'Remove this VN from your list?',
      'ja': 'この VN をリストから削除しますか？'
    },
    'saveFailed': {
      'zh': '保存失败',
      'en': 'Save failed',
      'ja': '保存に失敗しました'
    },
    'deleteFailed': {
      'zh': '删除失败',
      'en': 'Delete failed',
      'ja': '削除に失敗しました'
    },
    'searchRelated': {
      'zh': '搜索相关度',
      'en': 'Search relevance',
      'ja': '検索関連度'
    },
    'bayesianRating': {
      'zh': '贝叶斯评分',
      'en': 'Bayesian rating',
      'ja': 'ベイズ評価'
    },
    'voteCount': {'zh': '投票数', 'en': 'Vote count', 'ja': '投票数'},
    'releasedDate': {'zh': '发行日期', 'en': 'Released', 'ja': '発売日'},
    'titleField': {'zh': '标题', 'en': 'Title', 'ja': 'タイトル'},
    'myVote': {'zh': '我的评分', 'en': 'My vote', 'ja': 'マイ評価'},
    'addedAt': {'zh': '添加时间', 'en': 'Added', 'ja': '追加日時'},
    'lastModified': {'zh': '修改时间', 'en': 'Last modified', 'ja': '最終更新'},
    'startedDate': {'zh': '开始日期', 'en': 'Started', 'ja': '開始日'},
    'finishedDate': {'zh': '完成日期', 'en': 'Finished', 'ja': '完了日'},
    'searchVnHint': {
      'zh': '搜索 VN 标题、别名、发行版本…',
      'en': 'Search VN titles, aliases, releases…',
      'ja': 'VN タイトル・別名・リリースを検索…'
    },
    'searchCharHint': {
      'zh': '搜索角色名、别名…',
      'en': 'Search character names, aliases…',
      'ja': 'キャラクター名・別名を検索…'
    },
    'searchProducerHint': {
      'zh': '搜索制作商名称…',
      'en': 'Search producer names…',
      'ja': '制作元名を検索…'
    },
    'searchStaffHint': {
      'zh': '搜索制作人员名、别名…',
      'en': 'Search staff names, aliases…',
      'ja': 'スタッフ名・別名を検索…'
    },
    'searchReleaseHint': {
      'zh': '搜索发行版本标题…',
      'en': 'Search release titles…',
      'ja': 'リリースタイトルを検索…'
    },
    'searchTagHint': {
      'zh': '搜索标签名、别名…',
      'en': 'Search tag names, aliases…',
      'ja': 'タグ名・別名を検索…'
    },
    'searchTraitHint': {
      'zh': '搜索特质名、别名…',
      'en': 'Search trait names, aliases…',
      'ja': '特徴名・別名を検索…'
    },
    'startSearchPrompt': {
      'zh': '输入关键词开始搜索',
      'en': 'Enter a keyword to start searching',
      'ja': 'キーワードを入力して検索を開始'
    },
    'compactFilterHint': {
      'zh': '或粘贴 compact filter 字符串',
      'en': 'Or paste a compact filter string',
      'ja': 'compact filter 文字列を貼り付け'
    },
    'noMatchingWorks': {
      'zh': '未找到匹配的作品',
      'en': 'No matching works',
      'ja': '一致する作品はありません'
    },
    'browsingHistory': {
      'zh': '浏览历史',
      'en': 'Browsing History',
      'ja': '閲覧履歴'
    },
    'historyEmpty': {
      'zh': '暂无浏览历史',
      'en': 'No browsing history',
      'ja': '閲覧履歴はありません'
    },
    'followedProducers': {
      'zh': '关注列表',
      'en': 'Followed Producers',
      'ja': 'フォローリスト'
    },
    'recommendations': {
      'zh': '猜你喜欢',
      'en': 'Recommendations',
      'ja': 'おすすめ'
    },
    'shuffle': {'zh': '换一批', 'en': 'Shuffle', 'ja': 'シャッフル'},
    'message': {'zh': '消息', 'en': 'Messages', 'ja': 'メッセージ'},
    'checkUpdate': {
      'zh': '检查更新',
      'en': 'Check for updates',
      'ja': 'アップデートを確認'
    },
    'currentVersion': {
      'zh': '当前版本',
      'en': 'Current version',
      'ja': '現在のバージョン'
    },
    'newVersionAvailable': {
      'zh': '发现新版本',
      'en': 'New version available',
      'ja': '新バージョンがあります'
    },
    'latestVersion': {
      'zh': '最新版本',
      'en': 'Latest version',
      'ja': '最新バージョン'
    },
    'updateContent': {
      'zh': '更新内容',
      'en': 'Release notes',
      'ja': '更新内容'
    },
    'later': {'zh': '稍后再说', 'en': 'Later', 'ja': '後で'},
    'download': {'zh': '前往下载', 'en': 'Download', 'ja': 'ダウンロードへ'},
    'alreadyLatest': {
      'zh': '已是最新版本',
      'en': 'Already up to date',
      'ja': '最新です'
    },
    'backgroundTheme': {
      'zh': '背景主题',
      'en': 'Background theme',
      'ja': '背景テーマ'
    },
    'titleDisplay': {
      'zh': '作品名显示',
      'en': 'Title display',
      'ja': 'タイトル表示'
    },
    'romanized': {'zh': '罗马音', 'en': 'Romanized', 'ja': 'ローマ字'},
    'japaneseOriginal': {
      'zh': '日文/原名',
      'en': 'Japanese/Original',
      'ja': '日本語/原名'
    },
    'blurNsfw': {
      'zh': '模糊色情图片',
      'en': 'Blur NSFW images',
      'ja': 'NSFW画像をぼかす'
    },
    'blurNsfwDesc': {
      'zh': '默认对色情/暴力图片进行模糊处理',
      'en': 'Blur sexual/violent images by default',
      'ja': '性的/暴力的な画像をデフォルトでぼかします'
    },
    'overview': {'zh': '概况', 'en': 'Overview', 'ja': '概要'},
    'releases': {'zh': '版本', 'en': 'Releases', 'ja': 'リリース'},
    'staff': {'zh': '人员', 'en': 'Staff', 'ja': 'スタッフ'},
    'votesLabel': {'zh': '投票', 'en': 'Votes', 'ja': '投票'},
    'rating': {'zh': '评分', 'en': 'Rating', 'ja': '評価'},
    'bayesianRank': {
      'zh': '贝叶斯排名',
      'en': 'Bayesian rank',
      'ja': 'ベイズ順位'
    },
    'duration': {'zh': '时长', 'en': 'Duration', 'ja': 'プレイ時間'},
    'pleaseLoginToVote': {
      'zh': '请先登录并在 VNDB 获取 listwrite 权限的 Token 以投票',
      'en': 'Please sign in with a listwrite-enabled token to vote',
      'ja': '投票するには listwrite 権限のあるトークンでログインしてください'
    },
    'linkCopied': {
      'zh': '已复制链接',
      'en': 'Link copied',
      'ja': 'リンクをコピーしました'
    },
    'translateDescription': {
      'zh': '翻译简介',
      'en': 'Translate description',
      'ja': 'あらすじを翻訳'
    },
    'translating': {'zh': '翻译中…', 'en': 'Translating…', 'ja': '翻訳中…'},
    'translationFailed': {
      'zh': '翻译失败',
      'en': 'Translation failed',
      'ja': '翻訳に失敗しました'
    },
    'originalDescription': {
      'zh': '原文',
      'en': 'Original',
      'ja': '原文'
    },
    'showOriginal': {
      'zh': '显示原文',
      'en': 'Show original',
      'ja': '原文を表示'
    },
    'showTranslation': {
      'zh': '显示翻译',
      'en': 'Show translation',
      'ja': '翻訳を表示'
    },
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
