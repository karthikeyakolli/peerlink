package org.peerlink.app.bridge

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.peerlink.core.android.AndroidNodeFacade
import org.peerlink.core.android.AndroidNodeState
import org.peerlink.core.android.AndroidSqliteOperationJournal
import org.peerlink.core.android.discovery.AndroidDiscoveryEngine
import org.peerlink.core.android.discovery.DiscoveredPeerRecord
import org.peerlink.protocol.v1.PeerId

/**
 * Platform bridge connecting Flutter UI to the native Android PeerLink Node.
 */
class AndroidPigeonBridge(
    private val nodeFacade: AndroidNodeFacade,
    private val filePicker: ((MethodChannel.Result, String?) -> Unit)? = null,
    private val permissionRequester: ((List<String>, MethodChannel.Result) -> Unit)? = null
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
                    "technology" to peer.discoveryTechnology,
                    "technologies" to peer.discoveryTechnologies.toList(),
                    "transports" to peer.supportedTransports,
                    "connectionState" to peer.connectionState.name,
                    "routes" to peer.availableRoutes.map { it.toMap() }
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

        // Listen for lifecycle transitions
        nodeFacade.addLifecycleListener { oldState, newState, reason ->
            sendEvent(mapOf(
                "type" to "nodeLifecycleChanged",
                "oldState" to oldState.name,
                "newState" to newState.name,
                "reason" to reason
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

        // Listen for incoming transfer offers for receiver consent
        nodeFacade.addIncomingOfferListener { transferId, senderPeer, fileName, totalBytes, itemCount ->
            sendEvent(mapOf(
                "type" to "incomingTransferOffer",
                "transferId" to transferId,
                "senderPeer" to senderPeer.value,
                "fileName" to fileName,
                "totalBytes" to totalBytes,
                "itemCount" to itemCount
            ))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getNodeState" -> {
                result.success(nodeFacade.currentState.name)
            }
            "getLifecycleState" -> {
                result.success(nodeFacade.lifecycleState.name)
            }
            "getNodeCapabilities" -> {
                result.success(nodeFacade.nodeCapabilities.toMap())
            }
            "startNode" -> {
                try {
                    nodeFacade.start()
                    result.success(nodeFacade.lifecycleState.name)
                } catch (e: Exception) {
                    result.error("START_FAILED", e.message, null)
                }
            }
            "stopNode" -> {
                try {
                    nodeFacade.stop()
                    result.success(nodeFacade.lifecycleState.name)
                } catch (e: Exception) {
                    result.error("STOP_FAILED", e.message, null)
                }
            }
            "getLocalPeerId" -> {
                result.success(nodeFacade.localPeerId.value)
            }
            "getFingerprint" -> {
                result.success(nodeFacade.keystoreManager.fingerprintHex)
            }
            "getSecurityLevel" -> {
                result.success(nodeFacade.keystoreManager.securityLevelDescription)
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
            "respondIncomingTransfer" -> {
                val transferId = call.argument<String>("transferId") ?: ""
                val accept = call.argument<Boolean>("accept") ?: false
                val res = nodeFacade.respondIncomingTransfer(transferId, accept)
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
            "pickContentUris" -> {
                val category = call.argument<String>("category")
                if (filePicker != null) {
                    filePicker.invoke(result, category)
                } else {
                    result.success(emptyList<String>())
                }
            }
            "checkPermissions" -> {
                val ctx = nodeFacade.currentContext
                result.success(mapOf(
                    "storage" to ctx.isStoragePermissionGranted,
                    "notifications" to ctx.isNotificationPermissionGranted,
                    "nearbyDevices" to ctx.isNearbyDevicesPermissionGranted,
                    "localNetwork" to ctx.isLocalNetworkPermissionGranted,
                    "camera" to ctx.isCameraPermissionGranted
                ))
            }
            "requestPermissions" -> {
                val requested = call.argument<List<String>>("permissions") ?: emptyList()
                if (permissionRequester != null) {
                    permissionRequester.invoke(requested, result)
                } else {
                    result.success(emptyMap<String, Boolean>())
                }
            }
            "getDiscoveredPeers" -> {
                try {
                    val peers = nodeFacade.discoveryEngine.discoveredPeers.map { it.toMap() }
                    result.success(peers)
                } catch (e: Exception) {
                    result.error("DISCOVERY_ERROR", e.message, null)
                }
            }
            "addManualPeer" -> {
                try {
                    val peerIdStr = call.argument<String>("peerId") ?: ""
                    val name = call.argument<String>("name") ?: ""
                    val host = call.argument<String>("host") ?: ""
                    val port = call.argument<Int>("port") ?: 8765
                    val peerId = PeerId.newBuilder().setValue(peerIdStr).build()
                    val record = nodeFacade.discoveryEngine.addManualPeer(peerId, name, host, port)
                    result.success(record.toMap())
                } catch (e: Exception) {
                    result.error("MANUAL_PEER_ERROR", e.message, null)
                }
            }
            "refreshDiscovery" -> {
                try {
                    nodeFacade.discoveryEngine.sweepStalePeers(0)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("REFRESH_ERROR", e.message, null)
                }
            }
            "setReceiverConsentMode" -> {
                val modeStr = call.argument<String>("mode") ?: "AUTO_ACCEPT_PAIRED_TRUSTED"
                try {
                    val mode = org.peerlink.core.transfer.TransferSessionReceiver.ReceiverConsentMode.valueOf(modeStr)
                    nodeFacade.setReceiverConsentMode(mode)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INVALID_MODE", e.message, null)
                }
            }
            "addTrustedPeer" -> {
                val peerId = call.argument<String>("peerId") ?: ""
                val fingerprint = call.argument<String>("fingerprint") ?: ""
                try {
                    nodeFacade.trustStore.addTrustedPeer(peerId, fingerprint, ByteArray(32))
                    result.success(true)
                } catch (e: Exception) {
                    result.error("TRUST_ERROR", e.message, null)
                }
            }
            "revokeTrustedPeer" -> {
                val peerId = call.argument<String>("peerId") ?: ""
                try {
                    nodeFacade.trustStore.revokeTrust(peerId)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("REVOKE_ERROR", e.message, null)
                }
            }
            "isPeerTrusted" -> {
                val peerId = call.argument<String>("peerId") ?: ""
                result.success(nodeFacade.trustStore.isTrusted(peerId))
            }
            "isPeerRevoked" -> {
                val peerId = call.argument<String>("peerId") ?: ""
                result.success(nodeFacade.trustStore.isRevoked(peerId))
            }
            "getJournalOperations" -> {
                try {
                    val journal = nodeFacade.operationJournal
                    if (journal is AndroidSqliteOperationJournal) {
                        result.success(journal.listAllOperationsDetailed())
                    } else {
                        result.success(emptyList<Map<String, Any>>())
                    }
                } catch (e: Exception) {
                    result.error("JOURNAL_ERROR", e.message, null)
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
