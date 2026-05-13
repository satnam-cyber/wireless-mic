package com.mymic.wireless_mic

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.mymic.AudioStreamPlugin

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the audio stream plugin
        flutterEngine.plugins.add(AudioStreamPlugin())
    }
}
