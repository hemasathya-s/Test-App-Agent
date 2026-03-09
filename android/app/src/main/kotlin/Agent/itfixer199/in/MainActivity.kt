package Agent.itfixer199.`in`

import android.os.Bundle
import android.os.Build
import android.content.Intent
import android.content.pm.PackageManager
import android.Manifest
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(){
    private val CHANNEL = "Agent.itfixer199.in/notifications"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 🔥 Request notification permission for Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    1001
                )
            }
        }

        // Handle notification if app was closed
        intent?.let { handleNotificationIntent(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent) {
        if (intent.getBooleanExtra("from_notification", false)) {
            val title = intent.getStringExtra("title") ?: ""
            val body = intent.getStringExtra("body") ?: ""
            val modificationId = intent.getStringExtra("modification_id") ?: ""
            val orderId = intent.getStringExtra("order_id") ?: ""
            val type = intent.getStringExtra("type") ?: ""

            val data = mapOf(
                "title" to title,
                "body" to body,
                "modification_id" to modificationId,
                "order_id" to orderId,
                "type" to type
            )

            // Send to Flutter
            methodChannel?.invokeMethod("onNotificationTapped", data)
        }
    }

    override fun onResume() {
        super.onResume()

        // 🔥 Stop alarm sound when app opens
        stopService(Intent(this, AlarmService::class.java))
    }
}
