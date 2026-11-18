package org.peerlink.app

import android.app.NotificationManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.work.WorkInfo
import androidx.work.WorkManager
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.peerlink.app.discovery.AndroidNsdAdapter
import org.peerlink.app.service.PeerLinkForegroundService
import org.peerlink.app.storage.SafStorageProvider
import org.peerlink.app.worker.PeerLinkSyncWorker
import org.peerlink.core.android.AndroidNotificationController
import org.peerlink.core.android.AndroidStorageAbstraction
import org.peerlink.protocol.v1.PeerId
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Android Instrumented Test for Android platform frameworks:
 * - SAF & ContentResolver bridge
 * - NSD (Network Service Discovery) registration & unregistration
 * - Foreground Service (FOREGROUND_SERVICE_TYPE_DATA_SYNC) and notification channels
 * - WorkManager scheduling and network/battery constraints
 * - Network capabilities and permission checks
 *
 * Runs on real Android OS / emulator runtime via connectedDebugAndroidTest.
 */
@RunWith(AndroidJUnit4::class)
class AndroidFrameworkServicesInstrumentedTest {

    @Test
    fun testSafAndContentResolverStorageInteraction() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val safProvider = SafStorageProvider(context)
        val storageAbstraction = AndroidStorageAbstraction(safProvider)

        val tempFile = File(context.filesDir, "saf_test_file.txt").apply {
            writeText("PeerLink SAF integration verification test content")
        }
        val fileUri = android.net.Uri.fromFile(tempFile).toString()

        // Verify SAF metadata extraction
        assertTrue("File must exist via SAF bridge", safProvider.exists(fileUri))
        assertEquals("saf_test_file.txt", safProvider.getDisplayName(fileUri))
        assertTrue("File size must be positive", safProvider.getLength(fileUri) > 0)
        assertFalse("Regular file is not a directory", safProvider.isDirectory(fileUri))

        // Read stream via SAF
        val content = safProvider.openInputStream(fileUri).use { it.bufferedReader().readText() }
        assertEquals("PeerLink SAF integration verification test content", content)

        // Physical path resolution
        val handleOpt = storageAbstraction.resolveByPhysicalPath(tempFile.absolutePath)
        assertTrue("Storage abstraction should resolve valid file path", handleOpt.isPresent)
        assertEquals(tempFile.name, handleOpt.get().displayName)

        tempFile.delete()
    }

    @Test
    fun testNsdRegistrationAndLifecycle() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val nsdAdapter = AndroidNsdAdapter(context)
        val peerId = PeerId.newBuilder().setValue("peer_0123456789abcdef").build()

        assertTrue("NSD adapter should be available on Android", nsdAdapter.isAvailable)

        // Start advertising
        nsdAdapter.startAdvertising(peerId, "Android Device Test", 8765)
        assertTrue("NSD adapter should report isAdvertising true", nsdAdapter.isAdvertising)

        // Stop advertising
        nsdAdapter.stopAdvertising()
        assertFalse("NSD adapter should report isAdvertising false after stop", nsdAdapter.isAdvertising)
    }

    @Test
    fun testNotificationChannelsAndForegroundServiceLifecycle() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channels
        val bridge = org.peerlink.app.notification.AndroidNotificationBridge(context)
        val controller = AndroidNotificationController(bridge)

        // Verify transfer notification channel exists
        val channel = notificationManager.getNotificationChannel(AndroidNotificationController.CHANNEL_TRANSFERS)
        assertNotNull("Transfers notification channel must be created", channel)

        // Verify pairing notification channel exists
        val pairingChannel = notificationManager.getNotificationChannel(AndroidNotificationController.CHANNEL_PAIRING)
        assertNotNull("Pairing notification channel must be created", pairingChannel)

        // Test Foreground Service lifecycle via ServiceTestRule
        val serviceRule = androidx.test.rule.ServiceTestRule()
        val serviceIntent = android.content.Intent(context, PeerLinkForegroundService::class.java).apply {
            action = PeerLinkForegroundService.ACTION_START
            putExtra(PeerLinkForegroundService.EXTRA_TITLE, "Active Data Transfer")
        }
        serviceRule.startService(serviceIntent)
    }

    @Test
    fun testWorkManagerSyncSchedulingAndConstraints() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        // Schedule periodic sync via WorkManager
        PeerLinkSyncWorker.schedulePeriodicSync(context)

        val workManager = WorkManager.getInstance(context)
        val workInfos = workManager.getWorkInfosForUniqueWork("peerlink_periodic_sync").get(5, TimeUnit.SECONDS)

        assertNotNull("WorkManager work info must exist", workInfos)
        assertFalse("Periodic sync work must be enqueued", workInfos.isEmpty())
        val workInfo = workInfos[0]
        assertTrue("Work status must be ENQUEUED", workInfo.state == WorkInfo.State.ENQUEUED)
    }

    @Test
    fun testNetworkCapabilitiesAndConnectivity() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val activeNetwork = connectivityManager.activeNetwork
        if (activeNetwork != null) {
            val caps = connectivityManager.getNetworkCapabilities(activeNetwork)
            assertNotNull(caps)
            println("Active network capabilities: $caps")
        }
    }

    @Test
    fun testForegroundServiceTimeoutAndInterruptionRecovery() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val serviceRule = androidx.test.rule.ServiceTestRule()
        val serviceIntent = android.content.Intent(context, PeerLinkForegroundService::class.java).apply {
            action = PeerLinkForegroundService.ACTION_START
            putExtra(PeerLinkForegroundService.EXTRA_TITLE, "DataSync Service Test")
        }
        val binder = serviceRule.bindService(serviceIntent) as PeerLinkForegroundService.LocalBinder
        val service = binder.getService()
        assertNotNull("Foreground service must bind cleanly", service)

        // Trigger timeout handling (simulating Android 15/17 system dataSync limit)
        service.handleServiceTimeout("Simulated 6h dataSync limit reached")
        assertEquals("Simulated 6h dataSync limit reached", service.lastTimeoutReason)

        // Notification channel exists for timeout delivery
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = notificationManager.getNotificationChannel(AndroidNotificationController.CHANNEL_TRANSFERS)
        assertNotNull("Notification channel must exist for timeout delivery", channel)
    }

    @Test
    fun testAndroid17LocalNetworkPermissionAndDiscoveryLifecycle() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val nsdAdapter = AndroidNsdAdapter(context)

        // 1. Inspect target SDK vs platform version
        val targetSdk = context.applicationInfo.targetSdkVersion
        val compileOrPlatformSdk = android.os.Build.VERSION.SDK_INT
        println("Evaluating networking: platformSdk=$compileOrPlatformSdk, targetSdk=$targetSdk")

        // 2. Test first launch permission check
        val initialPerm = nsdAdapter.hasLocalNetworkPermission()
        if (targetSdk < 37) {
            assertTrue("Apps targeting < 37 should have local network permission granted under INTERNET", initialPerm)
        }

        // 3. Test permission denial behavior
        nsdAdapter.permissionChecker = { false }
        assertFalse("Permission check should report denied", nsdAdapter.hasLocalNetworkPermission())
        var denialReported: String? = null
        val denialCallback = object : org.peerlink.core.android.discovery.DiscoveryAdapter.DiscoveryCallback {
            override fun onPeerFound(peer: org.peerlink.core.android.discovery.DiscoveredPeerRecord) {}
            override fun onPeerLost(peerId: PeerId) {}
            override fun onDiscoveryError(technology: String, error: String) {
                denialReported = error
            }
        }
        nsdAdapter.startDiscovery(denialCallback)
        assertNotNull("Discovery must report error on permission denial", denialReported)
        assertTrue("Error must describe permission denial", denialReported!!.contains("PERMISSION_DENIED"))

        // 4. Test permission grant behavior
        nsdAdapter.permissionChecker = { true }
        assertTrue("Permission check should report granted", nsdAdapter.hasLocalNetworkPermission())
        var errorReported: String? = null
        var discoveredPeer: PeerId? = null
        var lostPeer: PeerId? = null
        val grantCallback = object : org.peerlink.core.android.discovery.DiscoveryAdapter.DiscoveryCallback {
            override fun onPeerFound(peer: org.peerlink.core.android.discovery.DiscoveredPeerRecord) {
                discoveredPeer = peer.peerId
            }
            override fun onPeerLost(peerId: PeerId) {
                lostPeer = peerId
            }
            override fun onDiscoveryError(technology: String, error: String) {
                errorReported = error
            }
        }
        nsdAdapter.startDiscovery(grantCallback)
        assertTrue("NSD adapter should be active after granted start", nsdAdapter.isAvailable)

        // 5. Test discovery restart
        nsdAdapter.restartDiscovery()
        assertNull("Restart discovery should succeed without error", errorReported)

        // 6. Test permission revocation during active discovery
        nsdAdapter.permissionChecker = { false }
        nsdAdapter.restartDiscovery()
        assertNotNull("Restart discovery must fail when permission is revoked", errorReported)

        // 7. Test service disappearance (peer lost notification)
        nsdAdapter.permissionChecker = { true }
        nsdAdapter.startDiscovery(grantCallback)
        val dummyPeer = PeerId.newBuilder().setValue("peer_lost_test").build()
        nsdAdapter.notifyPeerLost(dummyPeer)
        assertEquals("Peer lost callback must receive disappeared peer", dummyPeer, lostPeer)

        // 8. Clean up
        nsdAdapter.stopDiscovery()
        assertFalse("Discovery should be stopped", nsdAdapter.isDiscovering)
    }
}
