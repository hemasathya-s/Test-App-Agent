package `in`.itfixer199.agent

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
    private val CHANNEL_ID = "modification_alert_channel"

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("ALARM_SERVICE_DEBUG", "🔥 [onStartCommand] AlarmService triggered!")

        val title = intent?.getStringExtra("title") ?: "New Order"
        val body = intent?.getStringExtra("body") ?: "You received a new order"
        val modificationId = intent?.getStringExtra("modification_id") ?: ""
        val orderId = intent?.getStringExtra("order_id") ?: ""
        val type = intent?.getStringExtra("type") ?: ""

        // 🎵 Determine sound based on keyword "new order assigned"
        val isNewOrder = title.contains("new order assigned", ignoreCase = true) ||
                body.contains("new order assigned", ignoreCase = true)
        val soundToPlay = if (isNewOrder) "notification" else "notification1"

        Log.d("ALARM_SERVICE_DEBUG", "🔔 Received Data - Title: $title, Body: $body, Selected Sound: $soundToPlay (Keyword Match: $isNewOrder), ModID: $modificationId, OrderID: $orderId, Type: $type")

        try {
            createNotificationChannel()

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
                .setFullScreenIntent(pendingIntent, true)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setAutoCancel(false)
                .build()

            startForeground(1001, notification)

            // 🎵 Sound Logic: Release existing player and start fresh for every notification
            stopAndReleaseMediaPlayer()

            var resId = resources.getIdentifier(soundToPlay, "raw", packageName)
            if (resId == 0) {
                Log.w("ALARM_SERVICE_DEBUG", "⚠️ Sound '$soundToPlay' not found. Falling back to 'notification'.")
                resId = resources.getIdentifier("notification", "raw", packageName)
            }

            if (resId != 0) {
                Log.d("ALARM_SERVICE_DEBUG", "🎵 Initializing MediaPlayer with ID: $resId")
                mediaPlayer = MediaPlayer.create(this, resId)
                mediaPlayer?.isLooping = false
                mediaPlayer?.setOnCompletionListener {
                    Log.d("ALARM_SERVICE_DEBUG", "🎵 Sound finished. Waiting for next trigger.")
                    // Note: We don't stop the service here so the notification stays visible
                }
                mediaPlayer?.start()
            }

        } catch (e: Exception) {
            Log.e("ALARM_SERVICE_DEBUG", "💥 Error in AlarmService: ${e.message}")
        }

        return START_STICKY
    }

    private fun stopAndReleaseMediaPlayer() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
                mediaPlayer = null
                Log.d("ALARM_SERVICE_DEBUG", "🗑️ Previous MediaPlayer released.")
            }
        } catch (e: Exception) {
            Log.e("ALARM_SERVICE_DEBUG", "💥 Error releasing MediaPlayer: ${e.message}")
        }
    }

    override fun onDestroy() {
        Log.d("ALARM_SERVICE_DEBUG", "🗑️ [onDestroy] Releasing resources...")
        stopAndReleaseMediaPlayer()
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