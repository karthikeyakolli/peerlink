package org.peerlink.app.service

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.peerlink.core.android.AndroidNotificationController

/**
 * Android Foreground Service (FOREGROUND_SERVICE_TYPE_DATA_SYNC)
 * keeps socket connections and active file transfers alive when UI is backgrounded.
 */
class PeerLinkForegroundService : Service() {

    companion object {
        const val ACTION_START = "org.peerlink.app.service.START"
        const val ACTION_STOP = "org.peerlink.app.service.STOP"
        const val EXTRA_TITLE = "EXTRA_TITLE"
        const val NOTIFICATION_ID = 9001
        const val NOTIFICATION_ID_TIMEOUT = 9002

        fun start(context: Context, title: String) {
            val intent = Intent(context, PeerLinkForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, PeerLinkForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.stopService(intent)
        }
    }

    var lastTimeoutReason: String? = null
        private set

    inner class LocalBinder : android.os.Binder() {
        fun getService(): PeerLinkForegroundService = this@PeerLinkForegroundService
    }
    private val binder = LocalBinder()

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        val notification = createNotification("PeerLink Service Active")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "PeerLink Transfer Active"
        val notification = createNotification(title)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)

        return START_STICKY
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        handleServiceTimeout("DataSync foreground service timeout reached (startId=$startId, fgsType=$fgsType)")
    }

    /**
     * Handles service timeout and shutdown deterministically.
     * Persists active transfer operations into durable storage and updates notification.
     */
    fun handleServiceTimeout(reason: String) {
        lastTimeoutReason = reason
        val app = application as? org.peerlink.app.PeerLinkApplication
        app?.nodeFacade?.pauseAllActiveTransfers(reason)

        try {
            stopForeground(STOP_FOREGROUND_DETACH)
        } catch (ignored: Exception) {}

        val notification = NotificationCompat.Builder(this, AndroidNotificationController.CHANNEL_TRANSFERS)
            .setContentTitle("PeerLink Transfer Paused")
            .setContentText("Transfer paused due to system foreground service time limits")
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setOngoing(false)
            .build()
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.notify(NOTIFICATION_ID_TIMEOUT, notification)

        stopSelf()
    }

    override fun onDestroy() {
        val app = application as? org.peerlink.app.PeerLinkApplication
        app?.nodeFacade?.pauseAllActiveTransfers("Foreground service destroyed")
        super.onDestroy()
    }

    private fun createNotification(title: String): Notification {
        return NotificationCompat.Builder(this, AndroidNotificationController.CHANNEL_TRANSFERS)
            .setContentTitle("PeerLink Data Sync")
            .setContentText(title)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .build()
    }
}
