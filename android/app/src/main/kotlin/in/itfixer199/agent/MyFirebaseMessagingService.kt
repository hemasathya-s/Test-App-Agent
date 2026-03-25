package `in`.itfixer199.agent

import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        Log.d("FCM_DEBUG", "============== MESSAGE RECEIVED ==============")
        Log.d("FCM_DEBUG", "Data: ${message.data}")

        val playSound = message.data["playSound"]
        val type = message.data["type"]

        // Trigger if playSound is true OR if it's a modification (even if type is empty, we check playSound)
        val shouldTriggerAlarm =
            playSound.equals("true", ignoreCase = true) ||
                    type.equals("modification", ignoreCase = true) ||
                    message.data.containsKey("modification_id")
        if (shouldTriggerAlarm) {
            Log.d("FCM_DEBUG", "Alarm criteria met. Starting AlarmService...")

            val title = message.data["title"] ?: "Service Update"
            val body = message.data["body"] ?: "A change was proposed for your order."
            val soundName = message.data["sound"]?.replace(".mp3", "") ?: "notification"
            val modificationId = message.data["modification_id"] ?: ""
            val orderId = message.data["order_id"] ?: ""

            val intent = Intent(this, AlarmService::class.java).apply {
                putExtra("title", title)
                putExtra("body", body)
                putExtra("sound", soundName)
                putExtra("modification_id", modificationId)
                putExtra("order_id", orderId)
                putExtra("type", type)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(this, intent)
            } else {
                startService(intent)
            }
        } else {
            Log.d("FCM_DEBUG", "Message received but alarm criteria not met (playSound=$playSound, type=$type)")
        }
    }
}