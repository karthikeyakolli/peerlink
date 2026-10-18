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

    companion object {
        const val REQUEST_CODE_PICK_DOCUMENT = 4210
    }

    private var pigeonBridge: AndroidPigeonBridge? = null
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val app = application as? PeerLinkApplication
        val nodeFacade = app?.nodeFacade
        if (nodeFacade != null) {
            pigeonBridge = AndroidPigeonBridge(nodeFacade) { result ->
                pickContentUris(result)
            }
            pigeonBridge?.register(flutterEngine)
        }
        handleShareIntent(intent)
    }

    fun pickContentUris(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("BUSY", "File selection already in progress", null)
            return
        }
        pendingPickResult = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
            startActivityForResult(intent, REQUEST_CODE_PICK_DOCUMENT)
        } catch (e: Exception) {
            pendingPickResult = null
            result.error("PICK_ERROR", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_DOCUMENT) {
            val result = pendingPickResult
            pendingPickResult = null
            if (result == null) return

            if (resultCode != RESULT_OK || data == null) {
                result.success(emptyList<String>())
                return
            }

            val uris = mutableListOf<String>()
            val clipData = data.clipData
            if (clipData != null) {
                for (i in 0 until clipData.itemCount) {
                    val uri = clipData.getItemAt(i).uri
                    takePersistablePermission(uri)
                    uris.add(uri.toString())
                }
            } else {
                data.data?.let { uri ->
                    takePersistablePermission(uri)
                    uris.add(uri.toString())
                }
            }
            result.success(uris)
        }
    }

    private fun takePersistablePermission(uri: Uri) {
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (ignored: Exception) {}
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
