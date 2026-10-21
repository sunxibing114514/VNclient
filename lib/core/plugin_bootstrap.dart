import 'dart:io';

import 'package:flutter_inappwebview_android/flutter_inappwebview_android.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:path_provider_android/path_provider_android.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';
import 'package:sqflite_android/sqflite_android.dart';
import 'package:url_launcher_android/url_launcher_android.dart';

void registerAndroidPlugins() {
  if (!Platform.isAndroid) return;
  try {
    PathProviderAndroid.registerWith();
  } catch (_) {}
  try {
    SharedPreferencesAndroid.registerWith();
  } catch (_) {}
  try {
    UrlLauncherAndroid.registerWith();
  } catch (_) {}
  try {
    SqfliteAndroid.registerWith();
  } catch (_) {}
  try {
    ImagePickerAndroid.registerWith();
  } catch (_) {}
  try {
    AndroidInAppWebViewPlatform.registerWith();
  } catch (_) {}
}
