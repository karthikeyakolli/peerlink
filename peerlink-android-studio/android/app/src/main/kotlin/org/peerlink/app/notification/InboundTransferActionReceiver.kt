package org.peerlink.app.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.peerlink.app.PeerLinkApplication
import org.slf4j.LoggerFactory

/**
 * Handles explicit Accept or Decline actions from the system notification shade.
 * Routes directly through the authoritative AndroidNodeFacade respondIncomingTransfer
 * ensuring idempotency and trust verification.
 */
class InboundTransferActionReceiver : BroadcastReceiver() {

    companion object {
        private val log = LoggerFactory.getLogger(InboundTransferActionReceiver::class.java)
        const val ACTION_ACCEPT_TRANSFER = "org.peerlink.action.ACCEPT_TRANSFER"
        const val ACTION_DECLINE_TRANSFER = "org.peerlink.action.DECLINE_TRANSFER"
        const val EXTRA_TRANSFER_ID = "TRANSFER_ID"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val transferId = intent.getStringExtra(EXTRA_TRANSFER_ID) ?: return
        val action = intent.action ?: return
        val app = context.applicationContext as? PeerLinkApplication
        val nodeFacade = app?.nodeFacade

        if (nodeFacade == null) {
            log.warn("InboundTransferActionReceiver: nodeFacade is null on application, unable to route action {}", action)
            return
        }

        when (action) {
            ACTION_ACCEPT_TRANSFER -> {
                log.info("Notification Accept action triggered for transfer: {}", transferId)
                nodeFacade.respondIncomingTransfer(transferId, true)
            }
            ACTION_DECLINE_TRANSFER -> {
                log.info("Notification Decline action triggered for transfer: {}", transferId)
                nodeFacade.respondIncomingTransfer(transferId, false)
            }
        }
    }
}
