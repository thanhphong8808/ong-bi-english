// android/app/src/main/kotlin/vn/ongbi/english/MainActivity.kt
package vn.ongbi.english

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Hosts the Flutter UI and wires the Kotlin bridges. */
class MainActivity : FlutterActivity() {
    private var filesBridge: FilesBridge? = null
    private var llmBridge: LlmBridge? = null
    private var reminderBridge: ReminderBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        DeviceBridge(applicationContext, messenger)
        filesBridge = FilesBridge(this, messenger)
        llmBridge = LlmBridge(applicationContext, messenger)
        reminderBridge = ReminderBridge(this, messenger)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        filesBridge?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        reminderBridge?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        llmBridge?.dispose()
        filesBridge?.dispose()
        super.onDestroy()
    }
}
