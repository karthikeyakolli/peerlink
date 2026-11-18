package org.peerlink.app

import org.junit.Assert.*
import org.junit.Test
import org.peerlink.core.android.AndroidNotificationController
import org.peerlink.protocol.v1.PeerId

class AndroidNotificationControllerTest {

    private class RecordingNotificationBridge : AndroidNotificationController.PlatformNotificationBridge {
        var lastTransferProgress: String? = null
        var dismissedTransferId: String? = null
        var lastStatusTitle: String? = null
        var lastStatusMessage: String? = null
        var lastPromptTransferId: String? = null
        var lastPromptSenderPeer: PeerId? = null
        var lastPromptPeerName: String? = null
        var lastPromptFileName: String? = null
        var lastPromptTotalBytes: Long = 0
        var lastPromptItemCount: Int = 0
        var dismissedPromptTransferId: String? = null

        override fun showTransferProgress(
            transferId: String,
            title: String,
            progressPercent: Int,
            bytesTransferred: Long,
            totalBytes: Long
        ) {
            lastTransferProgress = "$transferId: $title ($progressPercent%)"
        }

        override fun dismissTransferProgress(transferId: String) {
            dismissedTransferId = transferId
        }

        override fun showPairingPrompt(sessionId: String, peerId: PeerId, peerName: String, sasPin: String) {}

        override fun dismissPairingPrompt(sessionId: String) {}

        override fun showStatusNotification(title: String, message: String) {
            lastStatusTitle = title
            lastStatusMessage = message
        }

        override fun showIncomingTransferPrompt(
            transferId: String,
            senderPeer: PeerId,
            peerName: String,
            fileName: String,
            totalBytes: Long,
            itemCount: Int
        ) {
            lastPromptTransferId = transferId
            lastPromptSenderPeer = senderPeer
            lastPromptPeerName = peerName
            lastPromptFileName = fileName
            lastPromptTotalBytes = totalBytes
            lastPromptItemCount = itemCount
        }

        override fun dismissIncomingTransferPrompt(transferId: String) {
            dismissedPromptTransferId = transferId
        }
    }

    @Test
    fun testNotificationChannelsConstants() {
        assertEquals("peerlink_requests", AndroidNotificationController.CHANNEL_REQUESTS)
        assertEquals("peerlink_transfers", AndroidNotificationController.CHANNEL_TRANSFERS)
        assertEquals("peerlink_pairing", AndroidNotificationController.CHANNEL_PAIRING)
        assertEquals("peerlink_sync", AndroidNotificationController.CHANNEL_SYNC)
        assertEquals("peerlink_results", AndroidNotificationController.CHANNEL_RESULTS)
    }

    @Test
    fun testShowIncomingTransferRequestRoutesCorrectly() {
        val bridge = RecordingNotificationBridge()
        val controller = AndroidNotificationController(bridge)

        val peerId = PeerId.newBuilder().setValue("peer-alpha-123").build()
        controller.showIncomingTransferRequest(
            "xfer-42",
            peerId,
            "Laptop Alice",
            "vacation.zip",
            10485760L,
            3
        )

        assertEquals("xfer-42", bridge.lastPromptTransferId)
        assertEquals(peerId, bridge.lastPromptSenderPeer)
        assertEquals("Laptop Alice", bridge.lastPromptPeerName)
        assertEquals("vacation.zip", bridge.lastPromptFileName)
        assertEquals(10485760L, bridge.lastPromptTotalBytes)
        assertEquals(3, bridge.lastPromptItemCount)
    }

    @Test
    fun testShowIncomingTransferRequestFallsBackToPeerIdWhenNameEmpty() {
        val bridge = RecordingNotificationBridge()
        val controller = AndroidNotificationController(bridge)

        val peerId = PeerId.newBuilder().setValue("peer-fallback-99").build()
        controller.showIncomingTransferRequest(
            "xfer-43",
            peerId,
            "",
            "notes.txt",
            1024L,
            1
        )

        assertEquals("peer-fallback-99", bridge.lastPromptPeerName)
    }

    @Test
    fun testDismissIncomingTransferRequest() {
        val bridge = RecordingNotificationBridge()
        val controller = AndroidNotificationController(bridge)

        controller.dismissIncomingTransferRequest("xfer-42")
        assertEquals("xfer-42", bridge.dismissedPromptTransferId)
    }

    @Test
    fun testTransferProgressAndCompletion() {
        val bridge = RecordingNotificationBridge()
        val controller = AndroidNotificationController(bridge)

        controller.updateTransferProgress("xfer-50", "photo.jpg", 50, 500, 1000)
        assertEquals("xfer-50: Transferring photo.jpg (50%)", bridge.lastTransferProgress)

        controller.completeTransfer("xfer-50", "photo.jpg", true)
        assertEquals("xfer-50", bridge.dismissedTransferId)
        assertEquals("Transfer Complete", bridge.lastStatusTitle)
        assertTrue(bridge.lastStatusMessage!!.contains("photo.jpg received successfully"))

        controller.completeTransfer("xfer-51", "broken.bin", false)
        assertEquals("xfer-51", bridge.dismissedTransferId)
        assertEquals("Transfer Failed", bridge.lastStatusTitle)
        assertTrue(bridge.lastStatusMessage!!.contains("Failed to transfer broken.bin"))
    }
}
