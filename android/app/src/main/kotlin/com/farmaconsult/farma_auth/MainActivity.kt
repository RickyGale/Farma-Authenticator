package com.farmaconsult.farma_auth

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var foldable: FoldableBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        foldable = FoldableBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onStart() {
        super.onStart()
        foldable?.start()
    }

    override fun onStop() {
        foldable?.stop()
        super.onStop()
    }
}
