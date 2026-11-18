package org.peerlink.app.service

import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import org.peerlink.app.PeerLinkApplication
import org.slf4j.LoggerFactory

/**
 * Android Quick Settings Tile allowing users to toggle PeerLink peer discovery
 * broadcast visibility directly from the Android System UI pull-down shade.
 * Keeps background services and active file transfers running without interruption.
 */
@RequiresApi(Build.VERSION_CODES.N)
class PeerLinkTileService : TileService() {

    companion object {
        private val log = LoggerFactory.getLogger(PeerLinkTileService::class.java)
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
    }

    override fun onClick() {
        super.onClick()
        val app = applicationContext as? PeerLinkApplication
        val nodeFacade = app?.nodeFacade
        if (nodeFacade != null) {
            val newState = nodeFacade.toggleDiscoveryVisible()
            log.info("PeerLink Quick Settings Tile toggled. Visible: {}", newState)
            updateTileState()
        }
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        val app = applicationContext as? PeerLinkApplication
        val nodeFacade = app?.nodeFacade

        val isVisible = nodeFacade?.isDiscoveryVisible ?: false

        if (isVisible) {
            tile.state = Tile.STATE_ACTIVE
            tile.label = "PeerLink Visible"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                tile.subtitle = "Discoverable to peers"
            }
        } else {
            tile.state = Tile.STATE_INACTIVE
            tile.label = "PeerLink Hidden"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                tile.subtitle = "Discovery broadcast paused"
            }
        }
        tile.updateTile()
    }
}
