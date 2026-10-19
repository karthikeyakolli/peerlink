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

            val requestsChannel = NotificationChannel(
                AndroidNotificationController.CHANNEL_REQUESTS,
                "Incoming Transfer Requests",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Authorizes incoming file transfer requests from nearby peers"
                enableVibration(true)
            }

            val resultsChannel = NotificationChannel(
                AndroidNotificationController.CHANNEL_RESULTS,
                "Transfer Results",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Completion and failure alerts for transfers"
            }

            val sysManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            sysManager.createNotificationChannels(listOf(transferChannel, pairingChannel, syncChannel, requestsChannel, resultsChannel))
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
            .setContentText("$progressPercent% (${formatBytes(bytesTransferred)} / ${formatBytes(totalBytes)})")
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

    override fun showIncomingTransferPrompt(
        transferId: String,
        senderPeer: PeerId,
        peerName: String,
        fileName: String,
        totalBytes: Long,
        itemCount: Int
    ) {
        val summaryText = if (itemCount > 1) {
            "$fileName and ${itemCount - 1} other file(s) (${formatBytes(totalBytes)})"
        } else {
            "$fileName (${formatBytes(totalBytes)})"
        }

        // Tap notification to view incoming request in PeerLink UI
        val contentIntent = Intent(context, org.peerlink.peerlink.MainActivity::class.java).apply {
            action = "ACTION_VIEW_INCOMING_TRANSFER"
            putExtra("TRANSFER_ID", transferId)
            putExtra("PEER_ID", senderPeer.value)
            putExtra("PEER_NAME", peerName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val contentPendingIntent = PendingIntent.getActivity(
            context,
            transferId.hashCode(),
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Action: Accept transfer directly from notification shade
        val acceptIntent = Intent(context, InboundTransferActionReceiver::class.java).apply {
            action = InboundTransferActionReceiver.ACTION_ACCEPT_TRANSFER
            putExtra(InboundTransferActionReceiver.EXTRA_TRANSFER_ID, transferId)
        }
        val acceptPendingIntent = PendingIntent.getBroadcast(
            context,
            (transferId + "_accept").hashCode(),
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Action: Decline transfer directly from notification shade
        val declineIntent = Intent(context, InboundTransferActionReceiver::class.java).apply {
            action = InboundTransferActionReceiver.ACTION_DECLINE_TRANSFER
            putExtra(InboundTransferActionReceiver.EXTRA_TRANSFER_ID, transferId)
        }
        val declinePendingIntent = PendingIntent.getBroadcast(
            context,
            (transferId + "_decline").hashCode(),
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, AndroidNotificationController.CHANNEL_REQUESTS)
            .setContentTitle("Incoming share from $peerName")
            .setContentText(summaryText)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(contentPendingIntent)
            .setAutoCancel(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", declinePendingIntent)
            .addAction(android.R.drawable.stat_sys_download, "Accept", acceptPendingIntent)
            .build()

        try {
            notificationManager.notify(transferId.hashCode(), notification)
        } catch (ignored: SecurityException) {}
    }

    override fun dismissIncomingTransferPrompt(transferId: String) {
        try {
            notificationManager.cancel(transferId.hashCode())
        } catch (ignored: Exception) {}
    }

    override fun showStatusNotification(title: String, message: String) {
        val notification = NotificationCompat.Builder(context, AndroidNotificationController.CHANNEL_RESULTS)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setAutoCancel(true)
            .build()

        try {
            notificationManager.notify((title + message).hashCode(), notification)
        } catch (ignored: SecurityException) {}
    }

    private fun formatBytes(bytes: Long): String {
        if (bytes <= 0) return "Unknown size"
        if (bytes < 1024) return "$bytes B"
        if (bytes < 1024 * 1024) return "${bytes / 1024} KB"
        if (bytes < 1024 * 1024 * 1024) return String.format(java.util.Locale.US, "%.1f MB", bytes.toDouble() / (1024 * 1024))
        return String.format(java.util.Locale.US, "%.2f GB", bytes.toDouble() / (1024 * 1024 * 1024))
    }
}
