package com.otamanagement.app

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        checkpoint("activity_on_create")
        super.onCreate(savedInstanceState)
        checkpoint("activity_created")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        checkpoint("flutter_engine_configure_start")
        super.configureFlutterEngine(flutterEngine)
        checkpoint("flutter_engine_configure_complete")
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        checkpoint("flutter_first_frame_displayed")
    }

    private fun checkpoint(name: String) {
        Log.i(startupLogTag, "checkpoint=$name")
    }

    companion object {
        private const val startupLogTag = "OTAStartup"
    }
}
