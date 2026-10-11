package org.peerlink.app.bridge

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.peerlink.core.android.AndroidNodeFacade
import org.peerlink.core.android.AndroidNodeState
import org.peerlink.core.android.discovery.AndroidDiscoveryEngine
import org.peerlink.core.android.discovery.DiscoveredPeerRecord
import org.peerlink.protocol.v1.PeerId

/**
 * Platform bridge connecting Flutter UI to the native Android PeerLink Node.
 */
class AndroidPigeonBridge(
    private val nodeFacade: AndroidNodeFacade
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "org.peerlink/android_node_methods"
        const val EVENT_CHANNEL = "org.peerlink/android_node_events"
    }

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(this)

        // Listen for discovery events
        nodeFacade.discoveryEngine.addListener(object : AndroidDiscoveryEngine.EngineListener {
            override fun onPeerDiscovered(peer: DiscoveredPeerRecord) {
                sendEvent(mapOf(
                    "type" to "peerDiscovered",
                    "peerId" to peer.peerId.value,
                    "name" to peer.displayName,
                    "host" to peer.hostAddress,
                    "port" to peer.port,
                    "technology" to peer.discoveryTechnology
                ))
            }

            override fun onPeerLost(peerId: PeerId) {
                sendEvent(mapOf(
                    "type" to "peerLost",
                    "peerId" to peerId.value
                ))
            }
        })

        // Listen for state transitions
        nodeFacade.stateMachine.addListener { oldState, newState, ctx ->
            sendEvent(mapOf(
                "type" to "nodeStateChanged",
                "oldState" to oldState.name,
                "newState" to newState.name,
                "isForeground" to ctx.isAppInForeground,
                "networkType" to ctx.networkType.name,
                "batteryPercent" to ctx.batteryLevelPercent
            ))
        }

        // Listen for transfer progress
        nodeFacade.addTransferListener(object : AndroidNodeFacade.TransferEventListener {
            override fun onTransferStarted(transferId: String, remotePeer: PeerId, fileName: String, totalBytes: Long) {
                sendEvent(mapOf(
                    "type" to "transferStarted",
                    "transferId" to transferId,
                    "remotePeer" to remotePeer.value,
                    "fileName" to fileName,
                    "totalBytes" to totalBytes
                ))
            }

            override fun onTransferProgress(transferId: String, percent: Int, transferredBytes: Long, totalBytes: Long) {
                sendEvent(mapOf(
                    "type" to "transferProgress",
                    "transferId" to transferId,
                    "percent" to percent,
                    "transferredBytes" to transferredBytes,
                    "totalBytes" to totalBytes
                ))
            }

            override fun onTransferCompleted(transferId: String, success: Boolean, errorMessage: String?) {
                sendEvent(mapOf(
                    "type" to "transferCompleted",
                    "transferId" to transferId,
                    "success" to success,
                    "errorMessage" to (errorMessage ?: "")
                ))
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getNodeState" -> {
                result.success(nodeFacade.currentState.name)
            }
            "getLocalPeerId" -> {
                result.success(nodeFacade.localPeerId.value)
            }
            "initiateSend" -> {
                val targetPeerStr = call.argument<String>("targetPeerId") ?: ""
                val uris = call.argument<List<String>>("contentUris") ?: emptyList()
                try {
                    val peerId = PeerId.newBuilder().setValue(targetPeerStr).build()
                    val transferId = nodeFacade.initiateSend(peerId, uris)
                    result.success(transferId)
                } catch (e: Exception) {
                    result.error("TRANSFER_ERROR", e.message, null)
                }
            }
            "confirmPairing" -> {
                val sessionId = call.argument<String>("sessionId") ?: ""
                val accept = call.argument<Boolean>("accept") ?: false
                val res = nodeFacade.confirmPairing(sessionId, accept)
                result.success(res)
            }
            "syncClipboard" -> {
                try {
                    val itemOpt = nodeFacade.syncClipboardOutbound()
                    if (itemOpt.isPresent) {
                        result.success(itemOpt.get().itemId)
                    } else {
                        result.success(null)
                    }
                } catch (e: Exception) {
                    result.error("CLIPBOARD_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }

    private fun sendEvent(event: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(event)
        }
    }
}
