package org.peerlink.app.ui

import android.app.Activity
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.peerlink.app.PeerLinkApplication

/**
 * Native Android Dialog Activity for SAS confirmation code authorization.
 */
class PairingConfirmationActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val sessionId = intent.getStringExtra("SESSION_ID") ?: ""
        val peerId = intent.getStringExtra("PEER_ID") ?: ""
        val peerName = intent.getStringExtra("PEER_NAME") ?: "Remote Device"
        val sasPin = intent.getStringExtra("SAS_PIN") ?: "0000"

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(50, 50, 50, 50)
        }

        val titleView = TextView(this).apply {
            text = "Authorize Pairing Request"
            textSize = 20f
        }

        val descView = TextView(this).apply {
            text = "Device '$peerName' ($peerId) wishes to establish a trusted connection."
            textSize = 14f
            setPadding(0, 20, 0, 20)
        }

        val sasView = TextView(this).apply {
            text = "Security SAS Code: $sasPin"
            textSize = 24f
            textAlignment = TextView.TEXT_ALIGNMENT_CENTER
            setPadding(0, 20, 0, 30)
        }

        val buttonLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }

        val rejectBtn = Button(this).apply {
            text = "Reject"
            setOnClickListener {
                val app = application as? PeerLinkApplication
                app?.nodeFacade?.confirmPairing(sessionId, false)
                finish()
            }
        }

        val acceptBtn = Button(this).apply {
            text = "Accept"
            setOnClickListener {
                val app = application as? PeerLinkApplication
                app?.nodeFacade?.confirmPairing(sessionId, true)
                finish()
            }
        }

        buttonLayout.addView(rejectBtn)
        buttonLayout.addView(acceptBtn)

        layout.addView(titleView)
        layout.addView(descView)
        layout.addView(sasView)
        layout.addView(buttonLayout)

        setContentView(layout)
    }
}
