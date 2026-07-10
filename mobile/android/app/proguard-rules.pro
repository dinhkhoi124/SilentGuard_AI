# Keep Flutter plugin entry points and native bridge classes reachable after R8.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Play Store Split (Deferred Components) - app does not use this
# feature, but the Flutter engine still references Play Core classes.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# media_kit and mobile_scanner rely on platform/plugin registration.
-keep class com.alexmercerind.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Firebase SDKs publish most rules themselves; keep public model members used
# reflectively by messaging/crash reporting integrations.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
