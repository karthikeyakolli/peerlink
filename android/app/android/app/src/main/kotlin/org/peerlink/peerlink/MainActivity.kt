package org.peerlink.peerlink

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.peerlink.app.PeerLinkApplication
import org.peerlink.app.bridge.AndroidPigeonBridge

class MainActivity : FlutterActivity() {

    private var pigeonBridge: AndroidPigeonBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val app = application as? PeerLinkApplication
        val nodeFacade = app?.nodeFacade
        if (nodeFacade != null) {
            pigeonBridge = AndroidPigeonBridge(nodeFacade)
            pigeonBridge?.register(flutterEngine)
        }
        handleShareIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        (application as? PeerLinkApplication)?.updateEnvironmentalState(inForeground = true)
    }

    override fun onPause() {
        super.onPause()
        (application as? PeerLinkApplication)?.updateEnvironmentalState(inForeground = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type ?: return

        val sharedUris = mutableListOf<String>()

        if (Intent.ACTION_SEND == action) {
            (intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))?.let { uri ->
                sharedUris.add(uri.toString())
            }
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.forEach { uri ->
                sharedUris.add(uri.toString())
            }
        }

        if (sharedUris.isNotEmpty()) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, AndroidPigeonBridge.METHOD_CHANNEL)
                    .invokeMethod("onFilesSharedViaIntent", mapOf("uris" to sharedUris, "mimeType" to type))
            }
        }
    }
}
