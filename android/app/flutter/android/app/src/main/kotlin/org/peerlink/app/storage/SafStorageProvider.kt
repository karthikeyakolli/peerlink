package org.peerlink.app.storage

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import androidx.documentfile.provider.DocumentFile
import org.peerlink.core.android.AndroidStorageAbstraction
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

/**
 * Storage Access Framework (SAF), ContentResolver, and MediaStore bridge
 * implementing AndroidStorageAbstraction.ContentResolverBridge.
 */
class SafStorageProvider(private val context: Context) : AndroidStorageAbstraction.ContentResolverBridge {

    private val contentResolver: ContentResolver = context.contentResolver

    override fun openInputStream(uriString: String): InputStream {
        val uri = Uri.parse(uriString)
        return contentResolver.openInputStream(uri)
            ?: throw FileNotFoundException("Could not open input stream for SAF uri: $uriString")
    }

    override fun openOutputStream(uriString: String): OutputStream {
        val uri = Uri.parse(uriString)
        return contentResolver.openOutputStream(uri)
            ?: throw FileNotFoundException("Could not open output stream for SAF uri: $uriString")
    }

    override fun delete(uriString: String): Boolean {
        return try {
            val uri = Uri.parse(uriString)
            DocumentsContract.deleteDocument(contentResolver, uri)
        } catch (e: Exception) {
            try {
                contentResolver.delete(Uri.parse(uriString), null, null) > 0
            } catch (ignored: Exception) {
                false
            }
        }
    }

    override fun exists(uriString: String): Boolean {
        return try {
            val uri = Uri.parse(uriString)
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                cursor.moveToFirst()
            } ?: false
        } catch (e: Exception) {
            false
        }
    }

    override fun getLength(uriString: String): Long {
        val uri = Uri.parse(uriString)
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIndex != -1 && !cursor.isNull(sizeIndex)) {
                        return cursor.getLong(sizeIndex)
                    }
                }
            }
        } catch (ignored: Exception) {}
        return 0L
    }

    override fun getDisplayName(uriString: String): String {
        val uri = Uri.parse(uriString)
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1 && !cursor.isNull(nameIndex)) {
                        return cursor.getString(nameIndex)
                    }
                }
            }
        } catch (ignored: Exception) {}
        return uri.lastPathSegment ?: "unknown_file"
    }

    override fun getLastModified(uriString: String): Long {
        val uri = Uri.parse(uriString)
        try {
            contentResolver.query(uri, arrayOf(DocumentsContract.Document.COLUMN_LAST_MODIFIED), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val modIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                    if (modIndex != -1 && !cursor.isNull(modIndex)) {
                        return cursor.getLong(modIndex)
                    }
                }
            }
        } catch (ignored: Exception) {}
        return System.currentTimeMillis()
    }

    override fun isDirectory(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        return try {
            val doc = DocumentFile.fromTreeUri(context, uri)
            doc?.isDirectory == true
        } catch (e: Exception) {
            false
        }
    }

    override fun listChildren(treeUriString: String): List<String> {
        val results = mutableListOf<String>()
        val uri = Uri.parse(treeUriString)
        val dir = DocumentFile.fromTreeUri(context, uri) ?: return emptyList()

        for (file in dir.listFiles()) {
            results.add(file.uri.toString())
        }
        return results
    }

    override fun checkReadPermission(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        return context.checkCallingOrSelfUriPermission(
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED || exists(uriString)
    }

    override fun checkWritePermission(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        return context.checkCallingOrSelfUriPermission(
            uri,
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    /**
     * Persists URI permissions so PeerLink can access user-selected folders across device reboots.
     */
    fun takePersistablePermission(treeUri: Uri) {
        val takeFlags: Int = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        contentResolver.takePersistableUriPermission(treeUri, takeFlags)
    }
}
