package org.peerlink.app.share

import android.content.Context
import android.content.Intent
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import org.peerlink.core.security.TrustStore
import org.peerlink.peerlink.MainActivity
import org.peerlink.peerlink.R
import org.slf4j.LoggerFactory

/**
 * Manages native Android Direct Share targets for verified, trusted peers.
 * Registers dynamic shortcuts with ShortcutManagerCompat so trusted devices
 * appear directly in the top row of the system Share Sheet.
 * Invariant: Discovery does NOT establish trust. Only explicitly verified peers are shared.
 */
object DirectShareManager {
    private val log = LoggerFactory.getLogger(DirectShareManager::class.java)

    const val CATEGORY_DIRECT_SHARE = "org.peerlink.directshare.CATEGORY_PEER"
    const val EXTRA_TARGET_PEER_ID = "TARGET_PEER_ID"
    const val EXTRA_PEER_NAME = "PEER_NAME"

    data class ShareTargetPeer(val peerId: String, val displayName: String)

    fun updateShareTargets(context: Context, trustedPeers: List<ShareTargetPeer>) {
        try {
            val topPeers = trustedPeers.take(4)
            val shortcuts = topPeers.map { peer ->
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_SEND
                    putExtra(EXTRA_TARGET_PEER_ID, peer.peerId)
                    putExtra(EXTRA_PEER_NAME, peer.displayName)
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }

                ShortcutInfoCompat.Builder(context, "peer_${peer.peerId}")
                    .setShortLabel(peer.displayName)
                    .setLongLabel("Send to ${peer.displayName}")
                    .setIcon(IconCompat.createWithResource(context, R.mipmap.ic_launcher))
                    .setCategories(setOf(CATEGORY_DIRECT_SHARE, Intent.CATEGORY_DEFAULT))
                    .setIntent(intent)
                    .build()
            }

            ShortcutManagerCompat.setDynamicShortcuts(context, shortcuts)
            log.info("Updated {} dynamic Direct Share targets", shortcuts.size)
        } catch (e: Exception) {
            log.warn("Failed to update Direct Share shortcuts", e)
        }
    }

    fun updateShareTargetsFromTrustStore(context: Context, trustStore: TrustStore?) {
        if (trustStore == null) return
        try {
            val peers = trustStore.allPeers
                .filter { trustStore.isTrusted(it.peerId.value) && !trustStore.isRevoked(it.peerId.value) }
                .map { peer ->
                    val name = if (peer.displayName.isNotBlank()) peer.displayName else peer.peerId.value.take(8)
                    ShareTargetPeer(peer.peerId.value, name)
                }
            updateShareTargets(context, peers)
        } catch (e: Exception) {
            log.warn("Failed to extract peers from TrustStore for Direct Share", e)
        }
    }
}
