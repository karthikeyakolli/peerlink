package org.peerlink.app.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.peerlink.app.ui.PairingConfirmationActivity
import org.peerlink.core.android.AndroidNotificationController
import org.peerlink.protocol.v1.PeerId

/**
 * Android Notification system implementation bridging to AndroidNotificationController.
 */
class AndroidNotificationBridge(private val context: Context) :
    AndroidNotificationController.PlatformNotificationBridge {

    private val notificationManager = NotificationManagerCompat.from(context)

    init {
        createChannels()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val transferChannel = NotificationChannel(
                AndroidNotificationController.CHANNEL_TRANSFERS,
                "File Transfers",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Ongoing file transfer progress"
            }

            val pairingChannel = NotificationChannel(
                AndroidNotificationController.CHANNEL_PAIRING,
                "Device Pairing Requests",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Authorizes pairing with remote devices"
                enableVibration(true)
            }

            val syncChannel = NotificationChannel(
                AndroidNotificationController.CHANNEL_SYNC,
                "Sync & Backup",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Background sync and backup notifications"
            }

            val sysManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            sysManager.createNotificationChannels(listOf(transferChannel, pairingChannel, syncChannel))
        }
    }

    override fun showTransferProgress(
        transferId: String,
        title: String,
        progressPercent: Int,
        bytesTransferred: Long,
        totalBytes: Long
    ) {
        val notification = NotificationCompat.Builder(context, AndroidNotificationController.CHANNEL_TRANSFERS)
            .setContentTitle(title)
            .setContentText("$progressPercent% (${bytesTransferred / 1024} KB / ${totalBytes / 1024} KB)")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setProgress(100, progressPercent, progressPercent == 0)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()

        try {
            notificationManager.notify(transferId.hashCode(), notification)
        } catch (ignored: SecurityException) {}
    }

    override fun dismissTransferProgress(transferId: String) {
        try {
            notificationManager.cancel(transferId.hashCode())
        } catch (ignored: Exception) {}
    }

    override fun showPairingPrompt(sessionId: String, peerId: PeerId, peerName: String, sasPin: String) {
        val intent = Intent(context, PairingConfirmationActivity::class.java).apply {
            putExtra("SESSION_ID", sessionId)
            putExtra("PEER_ID", peerId.value)
            putExtra("PEER_NAME", peerName)
            putExtra("SAS_PIN", sasPin)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            sessionId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, AndroidNotificationController.CHANNEL_PAIRING)
            .setContentTitle("Pairing Request from $peerName")
            .setContentText("Verify security SAS code: $sasPin")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        try {
            notificationManager.notify(sessionId.hashCode(), notification)
        } catch (ignored: SecurityException) {}
    }

    override fun dismissPairingPrompt(sessionId: String) {
        try {
            notificationManager.cancel(sessionId.hashCode())
        } catch (ignored: Exception) {}
    }

    override fun showStatusNotification(title: String, message: String) {
        val notification = NotificationCompat.Builder(context, AndroidNotificationController.CHANNEL_TRANSFERS)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setAutoCancel(true)
            .build()

        try {
            notificationManager.notify((title + message).hashCode(), notification)
        } catch (ignored: SecurityException) {}
    }
}
