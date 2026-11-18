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
    private val directoryPicker: ((MethodChannel.Result) -> Unit)? = null,
    private val permissionRequester: ((List<String>, MethodChannel.Result) -> Unit)? = null,
    private val appStorageDirectoryProvider: (() -> String)? = null,
    private val context: android.content.Context? = null,
    private val pendingShareIntentConsumer: (() -> Map<String, Any>?)? = null
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "org.peerlink/android_node_methods"
        const val EVENT_CHANNEL = "org.peerlink/android_node_events"
        private const val PROGRESS_THROTTLE_MS = 150L
    }

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val hotspotManager = org.peerlink.core.platform.hotspot.LocalHotspotManager()
    private val activeTransfers = java.util.concurrent.ConcurrentHashMap<String, String>()
    private val lastProgressEmitMs = java.util.concurrent.ConcurrentHashMap<String, Long>()
    private var audioPlayer: android.media.MediaPlayer? = null
    private var audioPlayerPath: String? = null

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

        // Listen for transfer progress & keep Foreground Service + Wi-Fi/WakeLock active
        nodeFacade.addTransferListener(object : AndroidNodeFacade.TransferEventListener {
            override fun onTransferStarted(transferId: String, remotePeer: PeerId, fileName: String, totalBytes: Long) {
                activeTransfers[transferId] = fileName
                lastProgressEmitMs[transferId] = 0L
                context?.let { ctx ->
                    org.peerlink.app.service.PeerLinkForegroundService.start(ctx, "Transferring $fileName")
                }
                sendEvent(mapOf(
                    "type" to "transferStarted",
                    "transferId" to transferId,
                    "remotePeer" to remotePeer.value,
                    "fileName" to fileName,
                    "totalBytes" to totalBytes
                ))
            }

            override fun onTransferProgress(transferId: String, percent: Int, transferredBytes: Long, totalBytes: Long) {
                val now = System.currentTimeMillis()
                val lastEmit = lastProgressEmitMs[transferId] ?: 0L
                if (percent in 1..99 && (now - lastEmit) < PROGRESS_THROTTLE_MS) {
                    return
                }
                lastProgressEmitMs[transferId] = now
                val label = activeTransfers[transferId] ?: "files"
                context?.let { ctx ->
                    org.peerlink.app.service.PeerLinkForegroundService.updateProgress(ctx, "$label ($percent%)", percent)
                }
                sendEvent(mapOf(
                    "type" to "transferProgress",
                    "transferId" to transferId,
                    "percent" to percent,
                    "transferredBytes" to transferredBytes,
                    "totalBytes" to totalBytes
                ))
            }

            override fun onTransferCompleted(transferId: String, success: Boolean, errorMessage: String?) {
                activeTransfers.remove(transferId)
                lastProgressEmitMs.remove(transferId)
                val ctx = context
                if (ctx != null) {
                    if (activeTransfers.isEmpty()) {
                        org.peerlink.app.service.PeerLinkForegroundService.stop(ctx)
                    }
                    if (success) {
                        try {
                            val pubDl = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS)
                            val peerLinkDir = java.io.File(pubDl, "PeerLink")
                            if (peerLinkDir.exists()) {
                                val files = peerLinkDir.listFiles()
                                if (files != null && files.isNotEmpty()) {
                                    val paths = files.map { it.absolutePath }.toTypedArray()
                                    android.media.MediaScannerConnection.scanFile(ctx, paths, null, null)
                                }
                            }
                        } catch (_: Exception) {}
                    }
                }
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
                val rawTarget = (call.argument<String>("targetPeerId") ?: "").trim()
                val uris = call.argument<List<String>>("contentUris") ?: emptyList()
                try {
                    var targetPeerStr = rawTarget
                    if (targetPeerStr.startsWith("{") && targetPeerStr.contains("\"peerId\"")) {
                        val m = java.util.regex.Pattern.compile("\"peerId\"\\s*:\\s*\"([^\"]+)\"").matcher(targetPeerStr)
                        if (m.find()) {
                            targetPeerStr = m.group(1) ?: rawTarget
                        }
                    }
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
            "pickDirectoryUri" -> {
                if (directoryPicker != null) {
                    directoryPicker.invoke(result)
                } else {
                    result.success(null)
                }
            }
            "getAppStorageDirectory" -> {
                val dir = appStorageDirectoryProvider?.invoke()
                    ?: (nodeFacade.destinationRoot?.parent?.toAbsolutePath()?.toString() ?: "")
                result.success(dir)
            }
            "getReceivedDirectory" -> {
                val dir = nodeFacade.destinationRoot?.toAbsolutePath()?.toString() ?: ""
                result.success(dir)
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
                val host = call.argument<String>("host") ?: ""
                val port = call.argument<Int>("port") ?: 8765
                val name = call.argument<String>("name") ?: (if (host.isNotBlank()) host else peerId)
                try {
                    if (host.isNotBlank()) {
                        val pid = PeerId.newBuilder().setValue(peerId).build()
                        nodeFacade.discoveryEngine.addManualPeer(pid, name, host, port)
                    }
                    nodeFacade.trustStore.addTrustedPeer(peerId, fingerprint, ByteArray(0))
                    context?.let { ctx ->
                        org.peerlink.app.share.DirectShareManager.updateShareTargetsFromTrustStore(ctx, nodeFacade.trustStore)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("TRUST_ERROR", e.message, null)
                }
            }
            "revokeTrustedPeer" -> {
                val peerId = call.argument<String>("peerId") ?: ""
                try {
                    nodeFacade.trustStore.revokeTrust(peerId)
                    context?.let { ctx ->
                        org.peerlink.app.share.DirectShareManager.updateShareTargetsFromTrustStore(ctx, nodeFacade.trustStore)
                    }
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
            "startLocalHotspot" -> {
                try {
                    val profile = hotspotManager.startHotspot()
                    result.success(mapOf(
                        "ssid" to profile.ssid(),
                        "passphrase" to profile.passphrase(),
                        "gatewayIp" to profile.gatewayIp(),
                        "listenPort" to profile.listenPort(),
                        "wifiQr" to profile.toWifiQrPayload(),
                        "peerlinkUri" to profile.toPeerLinkConnectionUri()
                    ))
                } catch (e: Exception) {
                    result.error("HOTSPOT_ERROR", e.message, null)
                }
            }
            "stopLocalHotspot" -> {
                try {
                    hotspotManager.stopHotspot()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("HOTSPOT_ERROR", e.message, null)
                }
            }
            "isHotspotActive" -> {
                result.success(hotspotManager.isHotspotActive)
            }
            "openFile" -> {
                val path = call.argument<String>("path") ?: ""
                if (context != null && path.isNotBlank()) {
                    try {
                        val file = java.io.File(path)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
                            return
                        }
                        val ext = file.extension.lowercase()
                        val mimeType = android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "*/*"
                        val contentUri = androidx.core.content.FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, mimeType)
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        val chooser = android.content.Intent.createChooser(intent, "Open file with...").apply {
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_FAILED", e.message, null)
                    }
                } else {
                    result.error("INVALID_CONTEXT", "Context or path invalid", null)
                }
            }
            "revealInFolder" -> {
                val path = call.argument<String>("path") ?: ""
                if (context != null) {
                    try {
                        val file = if (path.isNotBlank()) java.io.File(path) else null
                        val targetDir = if (file != null && file.isDirectory) file else file?.parentFile
                        if (targetDir != null && targetDir.exists()) {
                            try {
                                val contentUri = androidx.core.content.FileProvider.getUriForFile(
                                    context,
                                    "${context.packageName}.fileprovider",
                                    targetDir
                                )
                                val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                                    setDataAndType(contentUri, "resource/folder")
                                    addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                context.startActivity(intent)
                                result.success(true)
                                return
                            } catch (_: Exception) {}
                        }
                        val dlIntent = android.content.Intent(android.app.DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(dlIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("REVEAL_FAILED", e.message, null)
                    }
                } else {
                    result.error("INVALID_CONTEXT", "Context is null", null)
                }
            }
            "shareFile" -> {
                val path = call.argument<String>("path") ?: ""
                if (context != null && path.isNotBlank()) {
                    try {
                        val file = java.io.File(path)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
                            return
                        }
                        val ext = file.extension.lowercase()
                        val mimeType = android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "*/*"
                        val contentUri = androidx.core.content.FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )
                        val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                            type = mimeType
                            putExtra(android.content.Intent.EXTRA_STREAM, contentUri)
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        val chooser = android.content.Intent.createChooser(intent, "Share file via...").apply {
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_FAILED", e.message, null)
                    }
                } else {
                    result.error("INVALID_CONTEXT", "Context or path invalid", null)
                }
            }
            "scanMediaFile" -> {
                val path = call.argument<String>("path") ?: ""
                if (context != null && path.isNotBlank()) {
                    android.media.MediaScannerConnection.scanFile(
                        context,
                        arrayOf(path),
                        null
                    ) { scannedPath, uri ->
                        android.util.Log.i("PeerLink", "MediaScanner indexed: $scannedPath -> $uri")
                    }
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "getStorageSpaceInfo" -> {
                try {
                    val dataDir = android.os.Environment.getDataDirectory()
                    val total = dataDir.totalSpace
                    val free = dataDir.freeSpace
                    result.success(mapOf(
                        "totalBytes" to total,
                        "freeBytes" to free,
                        "usedBytes" to (total - free)
                    ))
                } catch (e: Exception) {
                    result.success(mapOf(
                        "totalBytes" to 0L,
                        "freeBytes" to 0L,
                        "usedBytes" to 0L
                    ))
                }
            }
            "resolveContentUriToCacheFile" -> {
                val uriStr = call.argument<String>("uri") ?: ""
                val ctx = context
                if (ctx == null || uriStr.isEmpty() || !uriStr.startsWith("content://")) {
                    result.success(null)
                    return
                }
                Thread {
                    try {
                        val uri = android.net.Uri.parse(uriStr)
                        var displayName = "shared_file"
                        ctx.contentResolver.query(
                            uri,
                            arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
                            null,
                            null,
                            null
                        )?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                val idx = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                                if (idx >= 0) {
                                    val candidate = cursor.getString(idx)
                                    if (!candidate.isNullOrBlank()) {
                                        displayName = candidate
                                    }
                                }
                            }
                        }
                        val safeName = displayName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
                        val cacheDir = java.io.File(ctx.cacheDir, "web_beam_cache")
                        if (!cacheDir.exists()) cacheDir.mkdirs()
                        val outFile = java.io.File(cacheDir, "${System.currentTimeMillis()}_$safeName")
                        ctx.contentResolver.openInputStream(uri)?.use { input ->
                            java.io.FileOutputStream(outFile).use { output ->
                                input.copyTo(output, 65536)
                            }
                        } ?: throw java.io.IOException("Unable to open input stream for URI")
                        mainHandler.post {
                            result.success(mapOf(
                                "path" to outFile.absolutePath,
                                "name" to safeName,
                                "sizeBytes" to outFile.length()
                            ))
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.success(null)
                        }
                    }
                }.start()
            }
            "hasAllFilesAccess" -> {
                val granted = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                    android.os.Environment.isExternalStorageManager()
                } else {
                    true
                }
                result.success(granted)
            }
            "requestAllFilesAccess" -> {
                val ctx = context
                if (ctx == null) {
                    result.success(false)
                    return
                }
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                    try {
                        val intent = android.content.Intent(
                            android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                            android.net.Uri.parse("package:${ctx.packageName}")
                        ).apply {
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        ctx.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallback = android.content.Intent(
                                android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION
                            ).apply {
                                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            ctx.startActivity(fallback)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                } else {
                    result.success(true)
                }
            }
            "consumePendingShareIntent" -> {
                result.success(pendingShareIntentConsumer?.invoke())
            }
            "audioPlay" -> {
                val path = call.argument<String>("path") ?: ""
                val ctx = context
                if (ctx == null || path.isBlank()) {
                    result.success(mapOf("playing" to false, "error" to "Invalid audio path"))
                    return
                }
                try {
                    if (audioPlayer != null && audioPlayerPath == path) {
                        audioPlayer?.start()
                    } else {
                        try {
                            audioPlayer?.stop()
                            audioPlayer?.release()
                        } catch (_: Exception) {}
                        val mp = android.media.MediaPlayer()
                        if (path.startsWith("content://")) {
                            mp.setDataSource(ctx, android.net.Uri.parse(path))
                        } else {
                            mp.setDataSource(path)
                        }
                        mp.prepare()
                        mp.start()
                        audioPlayer = mp
                        audioPlayerPath = path
                    }
                    result.success(mapOf(
                        "playing" to (audioPlayer?.isPlaying == true),
                        "positionMs" to (audioPlayer?.currentPosition ?: 0),
                        "durationMs" to (audioPlayer?.duration ?: 0)
                    ))
                } catch (e: Exception) {
                    result.success(mapOf("playing" to false, "error" to (e.message ?: "Playback error")))
                }
            }
            "audioPause" -> {
                try {
                    if (audioPlayer?.isPlaying == true) audioPlayer?.pause()
                    result.success(mapOf(
                        "playing" to false,
                        "positionMs" to (audioPlayer?.currentPosition ?: 0),
                        "durationMs" to (audioPlayer?.duration ?: 0)
                    ))
                } catch (_: Exception) {
                    result.success(mapOf("playing" to false, "positionMs" to 0, "durationMs" to 0))
                }
            }
            "audioSeek" -> {
                val posMs = call.argument<Int>("positionMs") ?: 0
                try {
                    audioPlayer?.seekTo(posMs.coerceAtLeast(0))
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }
            "audioStop" -> {
                try {
                    audioPlayer?.stop()
                    audioPlayer?.release()
                } catch (_: Exception) {}
                audioPlayer = null
                audioPlayerPath = null
                result.success(true)
            }
            "audioGetStatus" -> {
                try {
                    val mp = audioPlayer
                    result.success(mapOf(
                        "playing" to (mp?.isPlaying == true),
                        "positionMs" to (mp?.currentPosition ?: 0),
                        "durationMs" to (mp?.duration ?: 0),
                        "path" to (audioPlayerPath ?: "")
                    ))
                } catch (_: Exception) {
                    result.success(mapOf("playing" to false, "positionMs" to 0, "durationMs" to 0, "path" to ""))
                }
            }
            "getPdfPageCount" -> {
                val path = call.argument<String>("path") ?: ""
                if (path.isBlank()) {
                    result.success(0)
                    return
                }
                Thread {
                    var count = 0
                    try {
                        val pfd = android.os.ParcelFileDescriptor.open(
                            java.io.File(path),
                            android.os.ParcelFileDescriptor.MODE_READ_ONLY
                        )
                        pfd.use { fd ->
                            android.graphics.pdf.PdfRenderer(fd).use { renderer ->
                                count = renderer.pageCount
                            }
                        }
                    } catch (_: Exception) {}
                    mainHandler.post { result.success(count) }
                }.start()
            }
            "renderPdfPage" -> {
                val path = call.argument<String>("path") ?: ""
                val pageIndex = call.argument<Int>("pageIndex") ?: 0
                val targetWidth = (call.argument<Int>("width") ?: 900).coerceIn(240, 1800)
                if (path.isBlank()) {
                    result.success(null)
                    return
                }
                Thread {
                    var pngBytes: ByteArray? = null
                    try {
                        val pfd = android.os.ParcelFileDescriptor.open(
                            java.io.File(path),
                            android.os.ParcelFileDescriptor.MODE_READ_ONLY
                        )
                        pfd.use { fd ->
                            android.graphics.pdf.PdfRenderer(fd).use { renderer ->
                                if (pageIndex in 0 until renderer.pageCount) {
                                    renderer.openPage(pageIndex).use { page ->
                                        val scale = targetWidth.toFloat() / page.width.coerceAtLeast(1).toFloat()
                                        val h = (page.height * scale).toInt().coerceIn(240, 2400)
                                        val bmp = android.graphics.Bitmap.createBitmap(
                                            targetWidth, h, android.graphics.Bitmap.Config.ARGB_8888
                                        )
                                        bmp.eraseColor(android.graphics.Color.WHITE)
                                        page.render(bmp, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                        val baos = java.io.ByteArrayOutputStream()
                                        bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 92, baos)
                                        bmp.recycle()
                                        pngBytes = baos.toByteArray()
                                    }
                                }
                            }
                        }
                    } catch (_: Exception) {}
                    mainHandler.post { result.success(pngBytes) }
                }.start()
            }
            "getVideoThumbnail" -> {
                val path = call.argument<String>("path") ?: ""
                if (path.isBlank()) {
                    result.success(null)
                    return
                }
                Thread {
                    var jpgBytes: ByteArray? = null
                    val retriever = android.media.MediaMetadataRetriever()
                    try {
                        if (path.startsWith("content://") && context != null) {
                            retriever.setDataSource(context, android.net.Uri.parse(path))
                        } else {
                            retriever.setDataSource(path)
                        }
                        val frame = retriever.getFrameAtTime(1_000_000L, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                            ?: retriever.frameAtTime
                        if (frame != null) {
                            val baos = java.io.ByteArrayOutputStream()
                            frame.compress(android.graphics.Bitmap.CompressFormat.JPEG, 78, baos)
                            frame.recycle()
                            jpgBytes = baos.toByteArray()
                        }
                    } catch (_: Exception) {
                    } finally {
                        try { retriever.release() } catch (_: Exception) {}
                    }
                    mainHandler.post { result.success(jpgBytes) }
                }.start()
            }
            "queryDeviceMediaByCategory" -> {
                val category = (call.argument<String>("category") ?: "photos").lowercase()
                val limit = (call.argument<Int>("limit") ?: 250).coerceIn(1, 500)
                val ctx = context
                if (ctx == null) {
                    result.success(emptyList<Map<String, Any>>())
                    return
                }
                Thread {
                    val items = mutableListOf<Map<String, Any>>()
                    try {
                        val contentUri = when (category) {
                            "photos" -> android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                            "videos" -> android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                            "audio" -> android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                            "downloads" -> if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                                android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI
                            } else {
                                android.provider.MediaStore.Files.getContentUri("external")
                            }
                            else -> android.provider.MediaStore.Files.getContentUri("external")
                        }
                        val projection = arrayOf(
                            android.provider.MediaStore.MediaColumns._ID,
                            android.provider.MediaStore.MediaColumns.DISPLAY_NAME,
                            android.provider.MediaStore.MediaColumns.SIZE,
                            android.provider.MediaStore.MediaColumns.DATE_MODIFIED,
                            android.provider.MediaStore.MediaColumns.DATA
                        )
                        val selection: String? = when (category) {
                            "documents" -> "${android.provider.MediaStore.MediaColumns.MIME_TYPE} IN ('application/pdf','text/plain','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation')"
                            "archives" -> "${android.provider.MediaStore.MediaColumns.MIME_TYPE} IN ('application/zip','application/x-rar-compressed','application/x-7z-compressed','application/gzip','application/x-tar')"
                            "apps" -> "${android.provider.MediaStore.MediaColumns.DISPLAY_NAME} LIKE '%.apk'"
                            else -> null
                        }
                        ctx.contentResolver.query(
                            contentUri,
                            projection,
                            selection,
                            null,
                            "${android.provider.MediaStore.MediaColumns.DATE_MODIFIED} DESC"
                        )?.use { cursor ->
                            val idCol = cursor.getColumnIndex(android.provider.MediaStore.MediaColumns._ID)
                            val nameCol = cursor.getColumnIndex(android.provider.MediaStore.MediaColumns.DISPLAY_NAME)
                            val sizeCol = cursor.getColumnIndex(android.provider.MediaStore.MediaColumns.SIZE)
                            val modCol = cursor.getColumnIndex(android.provider.MediaStore.MediaColumns.DATE_MODIFIED)
                            val dataCol = cursor.getColumnIndex(android.provider.MediaStore.MediaColumns.DATA)

                            while (cursor.moveToNext() && items.size < limit) {
                                val dataPath = if (dataCol >= 0) cursor.getString(dataCol) else null
                                val id = if (idCol >= 0) cursor.getLong(idCol) else -1L
                                val name = (if (nameCol >= 0) cursor.getString(nameCol) else null)
                                    ?: dataPath?.substringAfterLast('/')
                                    ?: "item_$id"
                                val size = if (sizeCol >= 0) cursor.getLong(sizeCol) else 0L
                                val modSec = if (modCol >= 0) cursor.getLong(modCol) else 0L
                                if (size <= 0L && dataPath.isNullOrBlank()) continue
                                val resolvedPath = if (!dataPath.isNullOrBlank() && java.io.File(dataPath).exists()) {
                                    dataPath
                                } else if (id >= 0) {
                                    android.content.ContentUris.withAppendedId(contentUri, id).toString()
                                } else {
                                    continue
                                }
                                items.add(mapOf(
                                    "path" to resolvedPath,
                                    "name" to name,
                                    "sizeBytes" to size,
                                    "modifiedMs" to (modSec * 1000L)
                                ))
                            }
                        }
                    } catch (_: Exception) {}
                    mainHandler.post {
                        result.success(items)
                    }
                }.start()
            }
            "shareFiles" -> {
                val paths = call.argument<List<String>>("paths") ?: emptyList()
                val title = call.argument<String>("title") ?: "Share via..."
                val ctx = context
                if (ctx == null || paths.isEmpty()) {
                    result.error("INVALID_SHARE", "Context or paths invalid", null)
                    return
                }
                try {
                    val shareIntent = buildMultiShareIntent(ctx, paths)
                    if (shareIntent == null) {
                        result.error("NO_FILES", "No readable files found to share", null)
                        return
                    }
                    val chooser = android.content.Intent.createChooser(shareIntent, title).apply {
                        addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    ctx.startActivity(chooser)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SHARE_FAILED", e.message, null)
                }
            }
            "shareViaQuickShare" -> {
                val paths = call.argument<List<String>>("paths") ?: emptyList()
                val ctx = context
                if (ctx == null || paths.isEmpty()) {
                    result.error("INVALID_SHARE", "Context or paths invalid", null)
                    return
                }
                try {
                    val shareIntent = buildMultiShareIntent(ctx, paths)
                    if (shareIntent == null) {
                        result.error("NO_FILES", "No readable files found to share", null)
                        return
                    }
                    // Attempt direct launch of Google Play Services Quick Share / Nearby Share target
                    val candidates = ctx.packageManager.queryIntentActivities(shareIntent, 0)
                    val quickShareTarget = candidates.firstOrNull { info ->
                        val pkg = info.activityInfo.packageName.lowercase()
                        val cls = info.activityInfo.name.lowercase()
                        (pkg == "com.google.android.gms" && (cls.contains("nearby") || cls.contains("share"))) ||
                            pkg.contains("quickshare") ||
                            cls.contains("quickshare")
                    }
                    if (quickShareTarget != null) {
                        shareIntent.setClassName(
                            quickShareTarget.activityInfo.packageName,
                            quickShareTarget.activityInfo.name
                        )
                        ctx.startActivity(shareIntent)
                        result.success("quick_share_direct")
                    } else {
                        // Clean fallback to Android System Share Sheet (where Quick Share is pinned at top)
                        val chooser = android.content.Intent.createChooser(shareIntent, "Share via Quick Share or Apps").apply {
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        ctx.startActivity(chooser)
                        result.success("system_chooser")
                    }
                } catch (e: Exception) {
                    result.error("QUICK_SHARE_FAILED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun buildMultiShareIntent(ctx: android.content.Context, paths: List<String>): android.content.Intent? {
        val uris = ArrayList<android.net.Uri>()
        val mimeTypes = HashSet<String>()
        for (raw in paths) {
            if (raw.startsWith("content://")) {
                val uri = android.net.Uri.parse(raw)
                uris.add(uri)
                val mime = ctx.contentResolver.getType(uri) ?: "*/*"
                mimeTypes.add(mime)
            } else {
                val file = java.io.File(raw)
                if (file.exists() && file.isFile) {
                    val uri = androidx.core.content.FileProvider.getUriForFile(
                        ctx,
                        "${ctx.packageName}.fileprovider",
                        file
                    )
                    uris.add(uri)
                    val ext = file.extension.lowercase()
                    val mime = android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "*/*"
                    mimeTypes.add(mime)
                }
            }
        }
        if (uris.isEmpty()) return null

        val commonMime = when {
            mimeTypes.size == 1 -> mimeTypes.first()
            mimeTypes.all { it.startsWith("image/") } -> "image/*"
            mimeTypes.all { it.startsWith("video/") } -> "video/*"
            mimeTypes.all { it.startsWith("audio/") } -> "audio/*"
            else -> "*/*"
        }

        val intent = if (uris.size == 1) {
            android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                type = commonMime
                putExtra(android.content.Intent.EXTRA_STREAM, uris.first())
                clipData = android.content.ClipData.newRawUri("PeerLink Share", uris.first())
            }
        } else {
            android.content.Intent(android.content.Intent.ACTION_SEND_MULTIPLE).apply {
                type = commonMime
                putParcelableArrayListExtra(android.content.Intent.EXTRA_STREAM, uris)
                val clip = android.content.ClipData.newRawUri("PeerLink Share", uris.first())
                for (i in 1 until uris.size) {
                    clip.addItem(android.content.ClipData.Item(uris[i]))
                }
                clipData = clip
            }
        }
        intent.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        return intent
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
