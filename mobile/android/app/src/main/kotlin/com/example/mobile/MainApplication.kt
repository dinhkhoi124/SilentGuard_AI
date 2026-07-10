package com.example.mobile

import io.flutter.app.FlutterApplication

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        // No plugin registrant needed for firebase_messaging 16.x
        // The background executor uses its own mechanism
    }
}
