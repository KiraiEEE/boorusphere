package io.chaldeaprjkt.boorusphere

import StorageUtil
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Environment
import androidx.core.content.FileProvider
import java.io.File

class AndroidStorageUtil(private val context: Context) : StorageUtil {
    override fun getStoragePath(): String {
        return Environment.getExternalStorageDirectory().absolutePath
    }

    override fun getDownloadPath(): String {
        return Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).absolutePath
    }

    override fun open(filePath: String) {
        val uri = uriOfPath(filePath)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, context.contentResolver.getType(uri))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        context.startActivity(intent)
    }

    override fun scanMedia(path: String) {
        val target = File(path)
        val files = if (target.isDirectory) {
            target.walkTopDown()
                .onEnter { !it.name.startsWith(".") || it == target }
                .filter { it.isFile && !it.name.startsWith(".") }
                .map { it.absolutePath }
                .toList()
        } else {
            listOf(target.absolutePath)
        }
        if (files.isEmpty()) return
        MediaScannerConnection.scanFile(context.applicationContext, files.toTypedArray(), null, null)
    }

    private fun uriOfPath(path: String): Uri {
        return FileProvider.getUriForFile(
            context,
            context.applicationContext.packageName + ".flutter_downloader.provider",
            File(path)
        )
    }
}
