package com.aifaceattendance.mobile_app

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val FILE_SAVER_CHANNEL = "com.aifaceattendance.mobile_app/file_saver"

    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val savedTheme = prefs.getString("flutter.pref_theme_mode", null)
            if (savedTheme == "dark") {
                window.setBackgroundDrawable(ColorDrawable(Color.parseColor("#04050A")))
                window.statusBarColor = Color.parseColor("#04050A")
                window.navigationBarColor = Color.parseColor("#04050A")
            } else {
                window.setBackgroundDrawable(ColorDrawable(Color.parseColor("#FFFFFF")))
                window.statusBarColor = Color.parseColor("#FFFFFF")
                window.navigationBarColor = Color.parseColor("#FFFFFF")
            }
        } catch (_: Exception) {
            window.setBackgroundDrawable(ColorDrawable(Color.parseColor("#FFFFFF")))
        }

        // On Android 12+ (API 31+), dismiss the native splash screen immediately when Flutter draws
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
            }
        }

        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_SAVER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"

                    if (bytes == null || fileName == null) {
                        result.error("INVALID_ARGS", "bytes and fileName are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val saveResult = saveFileToPublicDownloads(bytes, fileName, mimeType)
                        result.success(saveResult)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.localizedMessage ?: "Failed to save file to Downloads", null)
                    }
                }
                "openFile" -> {
                    val uriString = call.argument<String>("uri")
                    val filePath = call.argument<String>("filePath")
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"

                    try {
                        val opened = openDownloadedFile(uriString, filePath, mimeType)
                        result.success(opened)
                    } catch (e: Exception) {
                        result.error("OPEN_FAILED", e.localizedMessage ?: "Failed to open file", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveFileToPublicDownloads(bytes: ByteArray, fileName: String, mimeType: String): Map<String, Any?> {
        val resolver = applicationContext.contentResolver

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw IllegalStateException("Could not create MediaStore entry for Downloads")

            resolver.openOutputStream(uri)?.use { os ->
                os.write(bytes)
                os.flush()
            } ?: throw IllegalStateException("Could not open output stream for $uri")

            contentValues.clear()
            contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            val finalDisplayName = try {
                resolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        cursor.getString(0)
                    } else {
                        fileName
                    }
                } ?: fileName
            } catch (_: Exception) {
                fileName
            }

            return mapOf(
                "success" to true,
                "uri" to uri.toString(),
                "path" to "Downloads/$finalDisplayName",
                "fileName" to finalDisplayName
            )
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }
            val targetFile = File(downloadsDir, fileName)
            FileOutputStream(targetFile).use { fos ->
                fos.write(bytes)
                fos.flush()
            }

            android.media.MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(targetFile.absolutePath),
                arrayOf(mimeType),
                null
            )

            return mapOf(
                "success" to true,
                "path" to targetFile.absolutePath,
                "fileName" to fileName
            )
        }
    }

    private fun openDownloadedFile(uriString: String?, filePath: String?, mimeType: String): Boolean {
        val uri = when {
            !uriString.isNullOrEmpty() -> Uri.parse(uriString)
            !filePath.isNullOrEmpty() -> {
                val file = File(filePath)
                if (!file.exists()) return false
                Uri.fromFile(file)
            }
            else -> return false
        }

        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        return try {
            val chooser = Intent.createChooser(viewIntent, "Open Attendance Report")
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooser)
            true
        } catch (e: Exception) {
            false
        }
    }
}
