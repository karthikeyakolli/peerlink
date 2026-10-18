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
        const val REQUEST_CODE_PERMISSIONS = 4211
    }

    private var pigeonBridge: AndroidPigeonBridge? = null
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val app = application as? PeerLinkApplication
        val nodeFacade = app?.nodeFacade
        if (nodeFacade != null) {
            pigeonBridge = AndroidPigeonBridge(
                nodeFacade = nodeFacade,
                filePicker = { result, category -> pickContentUris(result, category) },
                permissionRequester = { requested, result -> requestRequiredPermissions(requested, result) }
            )
            pigeonBridge?.register(flutterEngine)
        }
        handleShareIntent(intent)
        handleIncomingTransferIntent(intent)
    }

    fun pickContentUris(result: MethodChannel.Result, category: String? = null) {
        if (pendingPickResult != null) {
            result.error("BUSY", "File selection already in progress", null)
            return
        }
        pendingPickResult = result
        try {
            val intent = if ((category == "photos" || category == "videos") &&
                android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                Intent(android.provider.MediaStore.ACTION_PICK_IMAGES).apply {
                    if (category == "photos") {
                        type = "image/*"
                    } else if (category == "videos") {
                        type = "video/*"
                    }
                    putExtra(android.provider.MediaStore.EXTRA_PICK_IMAGES_MAX, 100)
                }
            } else {
                Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    when (category) {
                        "photos" -> type = "image/*"
                        "videos" -> type = "video/*"
                        "audio" -> type = "audio/*"
                        "documents" -> {
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                                "application/pdf",
                                "text/*",
                                "application/msword",
                                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                                "application/vnd.ms-excel",
                                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                                "application/vnd.ms-powerpoint",
                                "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                                "application/rtf",
                                "text/plain"
                            ))
                        }
                        "archives" -> {
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                                "application/zip",
                                "application/x-tar",
                                "application/x-gzip",
                                "application/x-7z-compressed",
                                "application/x-bzip2",
                                "application/x-rar-compressed",
                                "application/octet-stream"
                            ))
                        }
                        else -> type = "*/*"
                    }
                }
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

    fun requestRequiredPermissions(requested: List<String>, result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error("BUSY", "Permission request already in progress", null)
            return
        }
        val permsToRequest = mutableListOf<String>()
        for (item in requested) {
            when (item) {
                "notifications" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                        permsToRequest.add(android.Manifest.permission.POST_NOTIFICATIONS)
                    }
                }
                "nearby", "nearbyDevices" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                        permsToRequest.add(android.Manifest.permission.NEARBY_WIFI_DEVICES)
                    } else if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        permsToRequest.add(android.Manifest.permission.ACCESS_FINE_LOCATION)
                    }
                }
                "camera" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        permsToRequest.add(android.Manifest.permission.CAMERA)
                    }
                }
                "localNetwork" -> {
                    if (android.os.Build.VERSION.SDK_INT >= 37 && applicationInfo.targetSdkVersion >= 37) {
                        permsToRequest.add("android.permission.ACCESS_LOCAL_NETWORK")
                    }
                }
            }
        }

        val needed = permsToRequest.filter {
            checkSelfPermission(it) != android.content.pm.PackageManager.PERMISSION_GRANTED
        }

        if (needed.isEmpty()) {
            (application as? PeerLinkApplication)?.updateEnvironmentalState()
            result.success(emptyMap<String, Boolean>())
            return
        }

        pendingPermissionResult = result
        requestPermissions(needed.toTypedArray(), REQUEST_CODE_PERMISSIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            (application as? PeerLinkApplication)?.updateEnvironmentalState()
            val resultMap = mutableMapOf<String, Boolean>()
            for (i in permissions.indices) {
                resultMap[permissions[i]] = grantResults[i] == android.content.pm.PackageManager.PERMISSION_GRANTED
            }
            pendingPermissionResult?.success(resultMap)
            pendingPermissionResult = null
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
        handleIncomingTransferIntent(intent)
    }

    private fun handleIncomingTransferIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.action == "ACTION_VIEW_INCOMING_TRANSFER") {
            val transferId = intent.getStringExtra("TRANSFER_ID") ?: return
            val peerId = intent.getStringExtra("PEER_ID") ?: ""
            val peerName = intent.getStringExtra("PEER_NAME") ?: ""
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, AndroidPigeonBridge.METHOD_CHANNEL)
                    .invokeMethod("onIncomingTransferIntent", mapOf(
                        "transferId" to transferId,
                        "peerId" to peerId,
                        "peerName" to peerName
                    ))
            }
        }
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type ?: return

        val sharedUris = mutableListOf<String>()

        if (Intent.ACTION_SEND == action) {
            val uri = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            uri?.let { sharedUris.add(it.toString()) }
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            val uris = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }
            uris?.forEach { uri -> sharedUris.add(uri.toString()) }
        }

        if (sharedUris.isNotEmpty()) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, AndroidPigeonBridge.METHOD_CHANNEL)
                    .invokeMethod("onFilesSharedViaIntent", mapOf("uris" to sharedUris, "mimeType" to type))
            }
        }
    }
}
