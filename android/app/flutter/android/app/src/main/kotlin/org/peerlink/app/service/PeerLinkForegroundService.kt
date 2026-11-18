package org.peerlink.app.service

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import org.peerlink.core.android.AndroidNotificationController

/**
 * Android Foreground Service (FOREGROUND_SERVICE_TYPE_DATA_SYNC)
 * keeps socket connections, Wi-Fi high-performance radio, and active file transfers
 * alive without throttling when the screen turns off or the app is backgrounded.
 */
class PeerLinkForegroundService : Service() {

    companion object {
        const val ACTION_START = "org.peerlink.app.service.START"
        const val ACTION_UPDATE_PROGRESS = "org.peerlink.app.service.UPDATE_PROGRESS"
        const val ACTION_STOP = "org.peerlink.app.service.STOP"
        const val EXTRA_TITLE = "EXTRA_TITLE"
        const val EXTRA_PROGRESS = "EXTRA_PROGRESS"
        const val NOTIFICATION_ID = 9001
        const val NOTIFICATION_ID_TIMEOUT = 9002
        private const val MAX_WAKELOCK_MS = 30L * 60L * 1000L // 30 min bounded safety lock

        fun start(context: Context, title: String) {
            try {
                val intent = Intent(context, PeerLinkForegroundService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_TITLE, title)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Exception) {}
        }

        fun updateProgress(context: Context, title: String, percent: Int) {
            try {
                val intent = Intent(context, PeerLinkForegroundService::class.java).apply {
                    action = ACTION_UPDATE_PROGRESS
                    putExtra(EXTRA_TITLE, title)
                    putExtra(EXTRA_PROGRESS, percent.coerceIn(0, 100))
                }
                context.startService(intent)
            } catch (_: Exception) {}
        }

        fun stop(context: Context) {
            try {
                val intent = Intent(context, PeerLinkForegroundService::class.java).apply {
                    action = ACTION_STOP
                }
                context.stopService(intent)
            } catch (_: Exception) {}
        }
    }

    var lastTimeoutReason: String? = null
        private set

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    inner class LocalBinder : android.os.Binder() {
        fun getService(): PeerLinkForegroundService = this@PeerLinkForegroundService
    }
    private val binder = LocalBinder()

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        acquireTransferLocks()
        val notification = createNotification("PeerLink Transfer Service Active", -1)
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
            releaseTransferLocks()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        acquireTransferLocks()
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "PeerLink Transfer Active"
        val progress = if (intent?.action == ACTION_UPDATE_PROGRESS) {
            intent.getIntExtra(EXTRA_PROGRESS, -1)
        } else {
            -1
        }
        val notification = createNotification(title, progress)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)

        return START_STICKY
    }

    private fun acquireTransferLocks() {
        try {
            if (wakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "PeerLink:ActiveTransfer")?.apply {
                    setReferenceCounted(false)
                }
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(MAX_WAKELOCK_MS)
            }
        } catch (_: Exception) {}

        try {
            if (wifiLock == null) {
                val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                val lockMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    WifiManager.WIFI_MODE_FULL_LOW_LATENCY
                } else {
                    @Suppress("DEPRECATION")
                    WifiManager.WIFI_MODE_FULL_HIGH_PERF
                }
                wifiLock = wm?.createWifiLock(lockMode, "PeerLink:WifiTransfer")?.apply {
                    setReferenceCounted(false)
                }
            }
            if (wifiLock?.isHeld == false) {
                wifiLock?.acquire()
            }
        } catch (_: Exception) {}
    }

    private fun releaseTransferLocks() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        try {
            if (wifiLock?.isHeld == true) {
                wifiLock?.release()
            }
        } catch (_: Exception) {}
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
        releaseTransferLocks()
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
        releaseTransferLocks()
        val app = application as? org.peerlink.app.PeerLinkApplication
        app?.nodeFacade?.pauseAllActiveTransfers("Foreground service destroyed")
        super.onDestroy()
    }

    private fun createNotification(title: String, progressPercent: Int): Notification {
        val builder = NotificationCompat.Builder(this, AndroidNotificationController.CHANNEL_TRANSFERS)
            .setContentTitle("PeerLink Transfer")
            .setContentText(title)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
        if (progressPercent in 0..100) {
            builder.setProgress(100, progressPercent, false)
        }
        return builder.build()
    }
}
