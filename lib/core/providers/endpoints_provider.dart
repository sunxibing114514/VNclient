import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/endpoints/character_endpoint.dart';
import '../api/endpoints/list_endpoint.dart';
import '../api/endpoints/producer_endpoint.dart';
import '../api/endpoints/quote_endpoint.dart';
import '../api/endpoints/release_endpoint.dart';
import '../api/endpoints/staff_endpoint.dart';
import '../api/endpoints/stats_endpoint.dart';
import '../api/endpoints/tag_endpoint.dart';
import '../api/endpoints/trait_endpoint.dart';
import '../api/endpoints/user_endpoint.dart';
import '../api/endpoints/vn_endpoint.dart';
import 'client_provider.dart';

/// Convenience providers for each API endpoint, all backed by the shared
/// [VndbClient].
final vnEndpointProvider = Provider<VnEndpoint>(
  (ref) => VnEndpoint(ref.watch(vndbClientProvider)),
);

final releaseEndpointProvider = Provider<ReleaseEndpoint>(
  (ref) => ReleaseEndpoint(ref.watch(vndbClientProvider)),
);

final characterEndpointProvider = Provider<CharacterEndpoint>(
  (ref) => CharacterEndpoint(ref.watch(vndbClientProvider)),
);

final staffEndpointProvider = Provider<StaffEndpoint>(
  (ref) => StaffEndpoint(ref.watch(vndbClientProvider)),
);

final producerEndpointProvider = Provider<ProducerEndpoint>(
  (ref) => ProducerEndpoint(ref.watch(vndbClientProvider)),
);

final tagEndpointProvider = Provider<TagEndpoint>(
  (ref) => TagEndpoint(ref.watch(vndbClientProvider)),
);

final traitEndpointProvider = Provider<TraitEndpoint>(
  (ref) => TraitEndpoint(ref.watch(vndbClientProvider)),
);

final quoteEndpointProvider = Provider<QuoteEndpoint>(
  (ref) => QuoteEndpoint(ref.watch(vndbClientProvider)),
);

final userEndpointProvider = Provider<UserEndpoint>(
  (ref) => UserEndpoint(ref.watch(vndbClientProvider)),
);

final listEndpointProvider = Provider<ListEndpoint>(
  (ref) => ListEndpoint(ref.watch(vndbClientProvider)),
);

final statsEndpointProvider = Provider<StatsEndpoint>(
  (ref) => StatsEndpoint(ref.watch(vndbClientProvider)),
);
