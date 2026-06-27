package com.example.mobile

import io.flutter.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var mediaKitRegistered = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        registerPluginsExceptMediaKit(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_KIT_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "registerMediaKit") {
                registerMediaKitPlugins(flutterEngine)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun registerPluginsExceptMediaKit(flutterEngine: FlutterEngine) {
        addPlugin(
            flutterEngine,
            io.flutter.plugins.firebase.auth.FlutterFirebaseAuthPlugin(),
            "firebase_auth"
        )
        addPlugin(
            flutterEngine,
            io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin(),
            "firebase_core"
        )
        addPlugin(
            flutterEngine,
            io.flutter.plugins.firebase.crashlytics.FlutterFirebaseCrashlyticsPlugin(),
            "firebase_crashlytics"
        )
        addPlugin(
            flutterEngine,
            io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingPlugin(),
            "firebase_messaging"
        )
        addPlugin(
            flutterEngine,
            com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin(),
            "flutter_local_notifications"
        )
        addPlugin(
            flutterEngine,
            io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin(),
            "flutter_plugin_android_lifecycle"
        )
        addPlugin(
            flutterEngine,
            io.flutter.plugins.googlesignin.GoogleSignInPlugin(),
            "google_sign_in_android"
        )
        addPlugin(
            flutterEngine,
            io.flutter.plugins.imagepicker.ImagePickerPlugin(),
            "image_picker_android"
        )
        addPlugin(
            flutterEngine,
            dev.steenbakker.mobile_scanner.MobileScannerPlugin(),
            "mobile_scanner"
        )
        addPlugin(
            flutterEngine,
            dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin(),
            "package_info_plus"
        )
        addPlugin(
            flutterEngine,
            com.baseflow.permissionhandler.PermissionHandlerPlugin(),
            "permission_handler_android"
        )
        addPlugin(
            flutterEngine,
            com.aaassseee.screen_brightness_android.ScreenBrightnessAndroidPlugin(),
            "screen_brightness_android"
        )
        addPlugin(
            flutterEngine,
            io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin(),
            "shared_preferences_android"
        )
        addPlugin(
            flutterEngine,
            com.kurenai7968.volume_controller.VolumeControllerPlugin(),
            "volume_controller"
        )
        addPlugin(
            flutterEngine,
            dev.fluttercommunity.plus.wakelock.WakelockPlusPlugin(),
            "wakelock_plus"
        )
    }

    private fun registerMediaKitPlugins(flutterEngine: FlutterEngine) {
        if (mediaKitRegistered) return
        mediaKitRegistered = true
        addPlugin(
            flutterEngine,
            com.alexmercerind.media_kit_libs_android_video.MediaKitLibsAndroidVideoPlugin(),
            "media_kit_libs_android_video"
        )
        addPlugin(
            flutterEngine,
            com.alexmercerind.media_kit_video.MediaKitVideoPlugin(),
            "media_kit_video"
        )
    }

    private fun addPlugin(
        flutterEngine: FlutterEngine,
        plugin: FlutterPlugin,
        name: String
    ) {
        try {
            flutterEngine.plugins.add(plugin)
        } catch (exception: Exception) {
            Log.e(TAG, "Error registering plugin $name", exception)
        }
    }

    private companion object {
        const val TAG = "MainActivity"
        const val MEDIA_KIT_CHANNEL = "SlientGuard/media_kit"
    }
}
