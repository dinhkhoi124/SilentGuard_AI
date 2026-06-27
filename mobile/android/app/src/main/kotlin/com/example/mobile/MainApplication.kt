package com.example.mobile

import io.flutter.app.FlutterApplication

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        // Keep Application startup empty so native media plugins are not
        // intentionally initialized before the UI FlutterEngine is ready.
    }
}
