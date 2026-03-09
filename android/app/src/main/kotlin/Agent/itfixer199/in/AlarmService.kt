package Agent.itfixer199.`in`

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class AlarmService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private val CHANNEL_ID = "modification_alert_channel" // Fixed: Matches main.dart

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("ALARM_SERVICE_DEBUG", "🔥 [onStartCommand] AlarmService triggered!")

        val title = intent?.getStringExtra("title") ?: "New Order"
        val body = intent?.getStringExtra("body") ?: "You received a new order"
        val soundName = intent?.getStringExtra("sound") ?: "notification"
        val modificationId = intent?.getStringExtra("modification_id") ?: ""
        val orderId = intent?.getStringExtra("order_id") ?: ""
        val type = intent?.getStringExtra("type") ?: ""

        Log.d("ALARM_SERVICE_DEBUG", "🔔 Received Data - Title: $title, Body: $body, Sound: $soundName, ModID: $modificationId, OrderID: $orderId, Type: $type")

        try {
            // 1. Create the channel first
            createNotificationChannel()

            // 2. Build the notification
            val notificationIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("title", title)
                putExtra("body", body)
                putExtra("modification_id", modificationId)
                putExtra("order_id", orderId)
                putExtra("type", type)
                putExtra("from_notification", true)
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )

            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setAutoCancel(false)
                .build()

            // 3. Start foreground IMMEDIATELY
            startForeground(1001, notification)

            // 4. Start Media Player with dynamic sound
            if (mediaPlayer == null) {
                var resId = resources.getIdentifier(soundName, "raw", packageName)

                if (resId == 0) {
                    Log.w("ALARM_SERVICE_DEBUG", "⚠️ Sound '$soundName' not found. Falling back to 'notification'.")
                    resId = resources.getIdentifier("notification", "raw", packageName)
                }

                if (resId != 0) {
                    Log.d("ALARM_SERVICE_DEBUG", "🎵 Initializing MediaPlayer with ID: $resId")
                    mediaPlayer = MediaPlayer.create(this, resId)
                    mediaPlayer?.isLooping = false
                    mediaPlayer?.start()
                }
            }

        } catch (e: Exception) {
            Log.e("ALARM_SERVICE_DEBUG", "💥 Error in AlarmService: ${e.message}")
        }

        return START_STICKY
    }

    override fun onDestroy() {
        Log.d("ALARM_SERVICE_DEBUG", "🗑️ [onDestroy] Releasing resources...")
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Modification Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Used for service modification notifications"
                    enableVibration(true)
                    setSound(null, null)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                manager.createNotificationChannel(channel)
            }
        }
    }
}