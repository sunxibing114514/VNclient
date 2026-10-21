import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/plugin_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerAndroidPlugins();
  runApp(
    const ProviderScope(
      child: VndbApp(),
    ),
  );
}
