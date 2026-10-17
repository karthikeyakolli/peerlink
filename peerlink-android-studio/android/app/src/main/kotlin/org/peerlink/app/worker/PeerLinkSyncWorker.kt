package org.peerlink.app.worker

import android.content.Context
import androidx.work.*
import org.peerlink.app.PeerLinkApplication
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker executing periodic opportunistic sync and backup participation
 * under battery and unmetered network constraints.
 */
class PeerLinkSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        private const val SYNC_WORK_NAME = "peerlink_periodic_sync"

        fun schedulePeriodicSync(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.UNMETERED)
                .setRequiresBatteryNotLow(true)
                .build()

            val syncRequest = PeriodicWorkRequestBuilder<PeerLinkSyncWorker>(
                1, TimeUnit.HOURS,
                15, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                SYNC_WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                syncRequest
            )
        }
    }

    override suspend fun doWork(): Result {
        val app = applicationContext as? PeerLinkApplication ?: return Result.failure()
        val node = app.nodeFacade ?: return Result.retry()

        return try {
            val syncSuccess = node.performOpportunisticSync()
            val backupSuccess = node.performOpportunisticBackup()

            if (syncSuccess || backupSuccess) {
                Result.success()
            } else {
                Result.retry()
            }
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
