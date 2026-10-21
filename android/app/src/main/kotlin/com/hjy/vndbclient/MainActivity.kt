package com.hjy.vndbclient

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "vnclient/media"
    private val permissionRequestCode = 4711

    // Pending operation while the legacy storage permission dialog is
    // showing (only used on Android 9 and below): either a gallery save
    // or a game-download save.
    private var pendingAction: (() -> Unit)? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareImage" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGS", "missing path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            shareImage(path, call.argument<String>("title") ?: "")
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SHARE_FAILED", e.message, null)
                        }
                    }
                    "saveImage" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGS", "missing path", null)
                            return@setMethodCallHandler
                        }
                        runWithLegacyStoragePermission(result) {
                            try {
                                if (saveImageToGallery(path)) {
                                    result.success("已保存到相册 (Pictures/VNclient)")
                                } else {
                                    result.error("SAVE_FAILED", "保存失败", null)
                                }
                            } catch (e: Exception) {
                                result.error("SAVE_FAILED", e.message, null)
                            }
                        }
                    }
                    "saveDownload" -> {
                        val path = call.argument<String>("path")
                        val filename = call.argument<String>("filename")
                        val dir = call.argument<String>("dir") ?: "VNclient"
                        if (path == null || filename == null) {
                            result.error("INVALID_ARGS", "missing path/filename", null)
                            return@setMethodCallHandler
                        }
                        runWithLegacyStoragePermission(result) {
                            try {
                                val saved = saveDownloadedFile(path, filename, dir)
                                result.success(saved)
                            } catch (e: Exception) {
                                result.error("SAVE_FAILED", e.message, null)
                            }
                        }
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGS", "missing path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            openFileWithViewer(path)
                            result.success("已请求系统打开")
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Runs [action] immediately, or defers it until the legacy
    /// (Android 9 and below) storage permission has been granted.
    private fun runWithLegacyStoragePermission(
        result: MethodChannel.Result,
        action: () -> Unit
    ) {
        if (needsLegacyStoragePermission() &&
            ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingAction = action
            pendingResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE),
                permissionRequestCode
            )
        } else {
            action()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        val action = pendingAction
        val result = pendingResult
        pendingAction = null
        pendingResult = null
        if (result == null) return
        if (grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            action?.invoke()
        } else {
            result.error("PERMISSION_DENIED", "未授予存储权限, 无法保存", null)
        }
    }

    // The legacy write permission is only relevant below Android 10.
    private fun needsLegacyStoragePermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    /// Hands a local image file to the system share sheet via a
    /// FileProvider content URI.
    private fun shareImage(path: String, title: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("file not found: $path")
        }
        val uri: Uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/*"
            putExtra(Intent.EXTRA_STREAM, uri)
            if (title.isNotEmpty()) putExtra(Intent.EXTRA_SUBJECT, title)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "分享图片"))
    }

    /// Saves a local image file into the system gallery:
    ///  - Android 10+ (API 29): inserted through MediaStore, no permission
    ///    required, placed in Pictures/VNclient;
    ///  - older versions: copied into the public Pictures/VNclient dir and
    ///    media-scanned (legacy storage rules apply).
    private fun saveImageToGallery(path: String): Boolean {
        val source = File(path)
        if (!source.exists()) {
            throw IllegalArgumentException("file not found: $path")
        }
        val name = "VNclient_${System.currentTimeMillis()}_" + source.name

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, mimeTypeFor(source.name))
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/VNclient"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri =
                resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                    ?: return false
            try {
                resolver.openOutputStream(uri)?.use { out ->
                    source.inputStream().use { it.copyTo(out) }
                } ?: return false
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                return true
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
        } else {
            @Suppress("DEPRECATION")
            val picturesDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                "VNclient"
            )
            if (!picturesDir.exists() && !picturesDir.mkdirs()) {
                return false
            }
            val dest = File(picturesDir, name)
            source.copyTo(dest, overwrite = true)
            val intent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
            intent.data = Uri.fromFile(dest)
            sendBroadcast(intent)
            return true
        }
    }

    /// Saves a downloaded (freem!) game archive into the user-configured
    /// destination and returns the final on-disk path.
    ///
    ///  - [dir] starting with "/" is an absolute path (app-specific
    ///    directories work without permissions; arbitrary public paths may
    ///    be denied on Android 10+) — the file is copied there directly.
    ///  - otherwise [dir] is a subfolder of the public Download
    ///    collection:
    ///      - Android 10+: inserted through MediaStore.Downloads, no
    ///        permission needed;
    ///      - Android 9 and below: copied into the legacy public
    ///        Download/<dir> directory.
    private fun saveDownloadedFile(path: String, filename: String, dir: String): String {
        val source = File(path)
        if (!source.exists()) {
            throw IllegalArgumentException("file not found: $path")
        }
        val safeName = filename.replace(Regex("[\\\\/:*?\"<>|]"), "_")

        if (dir.startsWith("/")) {
            val destDir = File(dir)
            if (!destDir.exists() && !destDir.mkdirs()) {
                throw IllegalStateException("无法创建目录: $dir")
            }
            val dest = File(destDir, safeName)
            source.copyTo(dest, overwrite = true)
            return dest.absolutePath
        }

        val safeDir = dir.replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .trim('/')

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, safeName)
                put(MediaStore.Downloads.MIME_TYPE, mimeTypeForFile(safeName))
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    if (safeDir.isEmpty()) Environment.DIRECTORY_DOWNLOADS
                    else Environment.DIRECTORY_DOWNLOADS + "/" + safeDir
                )
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("无法写入 Download 目录")
            try {
                resolver.openOutputStream(uri)?.use { out ->
                    source.inputStream().use { it.copyTo(out) }
                } ?: run {
                    resolver.delete(uri, null, null)
                    throw IllegalStateException("无法写入 Download 文件")
                }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            @Suppress("DEPRECATION")
            val displayBase = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                safeDir
            )
            return File(displayBase, safeName).absolutePath
        }

        @Suppress("DEPRECATION")
        val downloadsDir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            safeDir
        )
        if (!downloadsDir.exists() && !downloadsDir.mkdirs()) {
            throw IllegalStateException("无法创建目录: ${downloadsDir.absolutePath}")
        }
        val dest = File(downloadsDir, safeName)
        source.copyTo(dest, overwrite = true)
        return dest.absolutePath
    }

    /// Opens a local file with the system viewer through a FileProvider
    /// content URI (best-effort; fails when no app can handle the type).
    private fun openFileWithViewer(path: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("file not found: $path")
        }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeTypeForFile(file.name))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "打开文件"))
    }

    private fun mimeTypeFor(name: String): String {
        val lower = name.lowercase()
        return when {
            lower.endsWith(".png") -> "image/png"
            lower.endsWith(".webp") -> "image/webp"
            lower.endsWith(".gif") -> "image/gif"
            else -> "image/jpeg"
        }
    }

    /// MIME type for downloaded game archives / apps / images.
    private fun mimeTypeForFile(name: String): String {
        val ext = name.substringAfterLast('.', "").lowercase()
        val mapped = when (ext) {
            "zip" -> "application/zip"
            "rar" -> "application/vnd.rar"
            "7z" -> "application/x-7z-compressed"
            "lzh", "lha" -> "application/x-lzh"
            "apk" -> "application/vnd.android.package-archive"
            "exe" -> "application/vnd.microsoft.portable-executable"
            "tar" -> "application/x-tar"
            "gz" -> "application/gzip"
            "pdf" -> "application/pdf"
            "mp3" -> "audio/mpeg"
            "mp4" -> "video/mp4"
            "txt" -> "text/plain"
            else -> null
        }
        return mapped
            ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            ?: "application/octet-stream"
    }
}
