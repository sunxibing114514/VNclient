/// Application-wide constants for the VNDB client.
class AppConstants {
  AppConstants._();

  /// Base URL for the VNDB Kana API.
  static const String apiBaseUrl = 'https://api.vndb.org/kana';

  /// Base URL for the VNDB website (used for WebView and external links).
  static const String siteBaseUrl = 'https://vndb.org';

  /// Current app version (keep in sync with pubspec.yaml).
  static const String appVersion = '1.4.0';

  /// GitHub releases API endpoint for update checking.
  ///
  /// Points at the public VNclient mirror so the check works without any
  /// authentication (the development repo is private and would 404, making
  /// the app bounce "尚未发布任何 Release" on every tap).
  static const String githubReleasesApi =
      'https://api.github.com/repos/sunxibing114514/VNclient/releases/latest';

  /// Secure storage key for the API auth token.
  static const String tokenKey = 'vndb_api_token';

  /// Secure storage key for the cached user id.
  static const String userIdKey = 'vndb_user_id';

  /// Secure storage key for the cached username.
  static const String usernameKey = 'vndb_username';

  /// Secure storage key for the remembered-accounts JSON list
  /// (multi-account login support).
  static const String accountsKey = 'vndb_accounts';

  /// SharedPreferences key for the game download directory
  /// (freem! downloads, Android only). Either a subfolder name of the
  /// public Download directory (e.g. "VNclient") or an absolute path.
  static const String downloadDirKey = 'vndb_download_dir';

  /// Default page size for paginated queries.
  static const int defaultPageSize = 20;

  /// Maximum page size allowed by the API.
  static const int maxPageSize = 100;

  /// Rate limit: 200 requests per 5 minutes (300 seconds).
  static const int rateLimitRequests = 200;
  static const int rateLimitWindowSeconds = 300;

  /// Pre-defined ulist label ids.
  static const int labelVoted = 7;
  static const int labelWishlist = 5;
  static const int labelPlaying = 1;
  static const int labelFinished = 2;
  static const int labelStalled = 3;
  static const int labelDropped = 4;

  /// SharedPreferences key for the list of followed producers (JSON).
  static const String followedProducersKey = 'vndb_followed_producers';

  /// SharedPreferences key for producer new-work notifications (JSON).
  static const String producerNotificationsKey = 'vndb_producer_notifications';

  /// SharedPreferences key for the browsing history (JSON array of VN ids).
  static const String browsingHistoryKey = 'vndb_browsing_history';

  /// Maximum number of browsing history entries to keep.
  static const int browsingHistoryLimit = 100;
}

/// External links displayed on the home page.
class AppLinks {
  AppLinks._();

  static const String patreon = 'https://www.patreon.com/vndb';
  static const String subscribestar = 'https://subscribestar.adult/vndb';
  /// The public repository of this client. All in-app GitHub links point
  /// here (the development repository is private and 404s for everyone
  /// else).
  static const String github = 'https://github.com/sunxibing114514/VNclient';

  static const String recentChanges = 'https://vndb.org/t/ge';
  static const String discussionBoard = 'https://vndb.org/t';
  static const String faq = 'https://vndb.org/faq';
  static const String apiDocs = 'https://api.vndb.org/kana';
  static const String dumps = 'https://vndb.org/d14';
  static const String dbDiscussions = 'https://vndb.org/t/db';
  static const String vnDiscussions = 'https://vndb.org/t/v';
  static const String reviews = 'https://vndb.org/w?t=review';
  static const String imageFlagging = 'https://vndb.org/img/list';
  static const String addVn = 'https://vndb.org/v/add';
  static const String addProducer = 'https://vndb.org/p/add';
  static const String addStaff = 'https://vndb.org/s/add';
  static const String tokens = 'https://vndb.org/u/tokens';
  static const String privacy = 'https://vndb.org/d7';

  /// Community human-translation project for VN descriptions.
  static const String translationProject =
      'https://github.com/sunxibing114514/translate-vndb-description';

  /// Online query mirror of the community translations.
  static const String translationMirror = 'https://vndbtran.hjymoon.bbroot.com/';

  /// Latest release HTML page (for "view on GitHub" button).
  static const String latestReleaseUrl =
      'https://github.com/sunxibing114514/VNclient/releases/latest';
}
