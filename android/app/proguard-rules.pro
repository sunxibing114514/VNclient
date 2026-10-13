# R8 rules for the VNDB client release builds.
#
# The Flutter engine and the AOT-compiled Dart code live outside the dex
# (libapp.so / libflutter.so) and are unaffected by R8; these keeps guard
# the plugin bridge classes that the generated plugin registrant and the
# method channels instantiate by name.

# Flutter embedding and generated plugin registrant.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Bundled plugins with native code (method channels + platform views).
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.baseflow.** { *; }
-keep class com.mr.flutter.** { *; }

# AndroidX security (flutter_secure_storage backend) uses reflection for
# some key management paths.
-keep class androidx.security.** { *; }
-keep class com.google.crypto.tink.** { *; }

# Kotlin metadata / annotations referenced reflectively.
-dontwarn javax.annotation.**
-dontwarn org.jetbrains.annotations.**

# The Flutter engine references Google Play Core classes (deferred
# components / Play Feature Delivery). The app does not use deferred
# components, so the classes are not bundled — silence the R8 warnings.
# Covers splitinstall / splitcompat / tasks / deferred / etc.
-dontwarn com.google.android.play.core.**
