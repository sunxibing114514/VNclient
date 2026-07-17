import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/vndb_client.dart';

/// Provides a single shared [VndbClient] for the whole app.
///
/// The 401 callback is wired up by [AuthNotifier] once it is constructed.
final vndbClientProvider = Provider<VndbClient>((ref) {
  final client = VndbClient(token: null);
  ref.onDispose(client.close);
  return client;
});
