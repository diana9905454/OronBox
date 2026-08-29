package org.zxor.oronbox

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.app.Dialog
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.MediaScannerConnection
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.ViewGroup
import android.view.Window
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.PrintWriter
import java.io.StringWriter
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

class MainActivity : FlutterActivity() {
    @Volatile
    private var sppSocket: BluetoothSocket? = null
    @Volatile
    private var readThread: Thread? = null
    private var eventSink: EventChannel.EventSink? = null
    private var scanEventSink: EventChannel.EventSink? = null
    private val scanResults = linkedMapOf<String, Map<String, Any?>>()
    private var scanReceiver: BroadcastReceiver? = null
    private var scanStopRunnable: Runnable? = null
    private var scanGeneration: Long = 0
    private val mainHandler = Handler(Looper.getMainLooper())
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")
    private val sendLock = Object()
    private val sppStateLock = Any()
    private val activeConnectingSockets = mutableSetOf<BluetoothSocket>()
    private val sendExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val connectGeneration = AtomicLong(0)
    private val backgroundTaskIds = mutableSetOf<Int>()
    private var nextBackgroundTaskId = 0
    private var connectionLabel: String? = null
    private var connectionBattery: Int? = null
    private var lastTaskLabel: String? = null
    private var zeppSettingsContainer: ViewGroup? = null
    private var zeppSettingsWebView: WebView? = null
    private var zeppSettingsAppId: Long? = null
    private var zeppSettingsChannel: MethodChannel? = null
    private var xmsWearableChannel: MethodChannel? = null
    private var fileOpenChannel: MethodChannel? = null
    private var pendingOpenFilePath: String? = null
    private var pendingWearableLogResult: MethodChannel.Result? = null
    private var pendingScreenshotSave: PendingScreenshotSave? = null
    private var pendingBluetoothPermissionResult: MethodChannel.Result? = null
    private var pendingBluetoothPermissionContinuation: (() -> Unit)? = null
    @Volatile
    private var phoneFinderPlayer: MediaPlayer? = null
    @Volatile
    private var phoneFinderVibrator: Vibrator? = null
    private val wearableLogExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var sessionMarker: File? = null

    private data class PendingScreenshotSave(
        val bytes: ByteArray,
        val fileName: String,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 0x5A12
        private const val SCREENSHOT_STORAGE_PERMISSION_REQUEST = 0x5A13
        private const val BLUETOOTH_PERMISSION_REQUEST = 0x5A10
        private const val WEARABLE_LOG_DIRECTORY_REQUEST = 0x5A11
        private const val WEARABLE_LOG_DIRECTORY_PREF = "wearable_log_directory"
        private const val MAX_WEARABLE_LOG_BYTES = 64 * 1024 * 1024
        @Volatile
        private var nativeCrashHandlerInstalled = false
        private var previousUncaughtExceptionHandler: Thread.UncaughtExceptionHandler? = null
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        installNativeCrashLogging()
        super.onCreate(savedInstanceState)
    }

    private fun installNativeCrashLogging() {
        val logDirectory = File(filesDir, "logs")
        recoverUnexpectedSessions(logDirectory)
        val marker = File(
            logDirectory,
            "oronbox-session-${Process.myPid()}-${UUID.randomUUID()}.running",
        )
        writeNativeLog(
            marker,
            "OronBox process ${Process.myPid()} started at ${System.currentTimeMillis()}\n",
        )
        sessionMarker = marker

        synchronized(MainActivity::class.java) {
            if (nativeCrashHandlerInstalled) return
            previousUncaughtExceptionHandler =
                Thread.getDefaultUncaughtExceptionHandler()
            Thread.setDefaultUncaughtExceptionHandler { thread, error ->
                val stack = StringWriter().also { writer ->
                    error.printStackTrace(PrintWriter(writer))
                }
                val report = File(
                    logDirectory,
                    "oronbox-native-crash-${System.currentTimeMillis()}-${Process.myPid()}.log",
                )
                writeNativeLog(
                    report,
                    buildString {
                        appendLine("OronBox native uncaught exception")
                        appendLine("time: ${System.currentTimeMillis()}")
                        appendLine("process: ${Process.myPid()}")
                        appendLine("thread: ${thread.name}")
                        appendLine()
                        append(stack.toString())
                    },
                )
                val previous = previousUncaughtExceptionHandler
                if (previous != null) {
                    previous.uncaughtException(thread, error)
                } else {
                    Process.killProcess(Process.myPid())
                    Runtime.getRuntime().exit(10)
                }
            }
            nativeCrashHandlerInstalled = true
        }
    }

    private fun recoverUnexpectedSessions(logDirectory: File) {
        try {
            if (!logDirectory.exists()) logDirectory.mkdirs()
            val currentProcessMarker = "oronbox-session-${Process.myPid()}"
            logDirectory.listFiles()
                ?.filter {
                    it.isFile && it.name.startsWith("oronbox-session-") &&
                        it.name.endsWith(".running") &&
                        it.name != "$currentProcessMarker.running" &&
                        !it.name.startsWith("$currentProcessMarker-")
                }
                ?.forEach { marker ->
                    val report = File(
                        logDirectory,
                        "oronbox-unexpected-exit-${marker.nameWithoutExtension}-" +
                            "${System.currentTimeMillis()}.log",
                    )
                    writeNativeLog(
                        report,
                        buildString {
                            appendLine("OronBox previous process ended unexpectedly")
                            appendLine("detected: ${System.currentTimeMillis()}")
                            appendLine("session marker: ${marker.name}")
                            appendLine(
                                "possible causes: native crash, ANR, force-stop, or system kill",
                            )
                        },
                    )
                    marker.delete()
                }
        } catch (_: Exception) {
            // Crash reporting must never prevent the application from starting.
        }
    }

    private fun writeNativeLog(file: File, content: String) {
        try {
            file.parentFile?.mkdirs()
            FileOutputStream(file, false).use { output ->
                output.write(content.toByteArray(Charsets.UTF_8))
                output.fd.sync()
            }
        } catch (_: Exception) {
            // The process may be in a failing state; do not throw from logging.
        }
    }

    private fun startBackgroundService(label: String, mode: String, battery: Int? = null) {
        val intent = Intent(this, BackgroundTaskService::class.java).apply {
            putExtra(BackgroundTaskService.EXTRA_LABEL, label)
            putExtra(BackgroundTaskService.EXTRA_MODE, mode)
            battery?.let { putExtra(BackgroundTaskService.EXTRA_BATTERY, it) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopBackgroundServiceIfIdle() {
        if (backgroundTaskIds.isEmpty() && connectionLabel == null) {
            stopService(Intent(this, BackgroundTaskService::class.java))
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        fileOpenChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.FILE_OPEN,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialFile" -> result.success(pendingOpenFilePath)
                    else -> result.notImplemented()
                }
            }
            resolveOpenIntent(intent)?.let { path ->
                pendingOpenFilePath = path
                channel.invokeMethod("openFile", path)
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.WEARABLE_LOG,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanLatest" -> scanLatestWearableLog(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.FIND_PHONE,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    try {
                        startPhoneFinder()
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("PHONE_FINDER_START_FAILED", error.message, null)
                    }
                }
                "stop" -> {
                    stopPhoneFinder()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.XIAOMI_SCREENSHOT,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "save" -> saveXiaomiScreenshot(call, result)
                else -> result.notImplemented()
            }
        }
        xmsWearableChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.XMS_WEARABLE,
        ).also(XmsWearableBridge::attach)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.BACKGROUND_TASKS,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "begin" -> {
                    val id = ++nextBackgroundTaskId
                    backgroundTaskIds.add(id)
                    lastTaskLabel = call.argument<String>("label") ?: "Installing resources"
                    startBackgroundService(
                        lastTaskLabel!!,
                        BackgroundTaskService.MODE_TASK,
                    )
                    result.success(id)
                }
                "end" -> {
                    call.argument<Int>("id")?.let(backgroundTaskIds::remove)
                    if (backgroundTaskIds.isEmpty()) {
                        lastTaskLabel = null
                        connectionLabel?.let {
                            startBackgroundService(
                                it,
                                BackgroundTaskService.MODE_CONNECTION,
                                connectionBattery,
                            )
                        }
                    }
                    stopBackgroundServiceIfIdle()
                    result.success(null)
                }
                // Keeps the process (and the BLE link) alive while a device
                // is connected; task labels take precedence while both run.
                "beginConnection" -> {
                    connectionLabel = call.argument<String>("label") ?: "Device connected"
                    connectionBattery = call.argument<Int>("battery")
                    startBackgroundService(
                        lastTaskLabel ?: connectionLabel!!,
                        if (lastTaskLabel == null) {
                            BackgroundTaskService.MODE_CONNECTION
                        } else {
                            BackgroundTaskService.MODE_TASK
                        },
                        call.argument<Int>("battery"),
                    )
                    result.success(null)
                }
                "updateConnection" -> {
                    connectionLabel = call.argument<String>("label") ?: "Device connected"
                    connectionBattery = call.argument<Int>("battery")
                    if (lastTaskLabel == null) {
                        startBackgroundService(
                            connectionLabel!!,
                            BackgroundTaskService.MODE_CONNECTION,
                            call.argument<Int>("battery"),
                        )
                    }
                    result.success(null)
                }
                "endConnection" -> {
                    connectionLabel = null
                    connectionBattery = null
                    lastTaskLabel?.let {
                        startBackgroundService(it, BackgroundTaskService.MODE_TASK)
                    }
                    stopBackgroundServiceIfIdle()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.STATUS_SURFACES,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateDeviceStatus" -> {
                    val values = call.arguments as? Map<*, *>
                    if (values == null) {
                        result.error("INVALID_ARGUMENT", "Device status is required", null)
                    } else {
                        StatusWidgetDataStore.saveDevice(this, values)
                        StatusWidgetUpdater.updateDevice(this)
                        result.success(null)
                    }
                }
                "updateHealthStatus" -> {
                    val values = call.arguments as? Map<*, *>
                    if (values == null) {
                        result.error("INVALID_ARGUMENT", "Health status is required", null)
                    } else {
                        StatusWidgetDataStore.saveHealth(this, values)
                        StatusWidgetUpdater.updateHealth(this)
                        result.success(null)
                    }
                }
                "updateQueueActivity" -> {
                    val values = call.arguments as? Map<*, *>
                    if (values == null) {
                        result.error("INVALID_ARGUMENT", "Queue status is required", null)
                    } else {
                        requestNotificationPermissionIfNeeded()
                        QueueActivityNotification.update(this, values)
                        result.success(null)
                    }
                }
                "clearQueueActivity" -> {
                    QueueActivityNotification.clear(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.LOGS,
        ).setMethodCallHandler { call, result ->
            val authority = "${applicationContext.packageName}.logs"
            when (call.method) {
                "open" -> {
                    val rootUri = android.provider.DocumentsContract.buildRootUri(authority, "logs")
                    val browse = Intent("android.provider.action.BROWSE").apply {
                        setDataAndType(rootUri, android.provider.DocumentsContract.Root.MIME_TYPE_ITEM)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    try {
                        startActivity(browse)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, rootUri))
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("OPEN_LOGS_FAILED", error.message, null)
                        }
                    }
                }
                "share" -> {
                    val name = call.argument<String>("name")
                    val file = name?.takeIf {
                        !it.contains('/') && !it.contains('\\') &&
                            (it.endsWith(".log") || it.endsWith(".zip"))
                    }?.let { java.io.File(filesDir, "logs/$it") }
                    if (file == null || !file.isFile) {
                        result.error("LOG_NOT_FOUND", name, null)
                    } else {
                        val uri = android.provider.DocumentsContract.buildDocumentUri(authority, file.name)
                        val share = Intent(Intent.ACTION_SEND).apply {
                            type = if (file.extension == "zip") "application/zip" else "text/plain"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            clipData = ClipData.newRawUri(file.name, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        try {
                            startActivity(Intent.createChooser(share, file.name))
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("SHARE_LOG_FAILED", error.message, null)
                        }
                    }
                }
                "export" -> {
                    val name = call.argument<String>("name")
                    val source = name?.takeIf {
                        !it.contains('/') && !it.contains('\\') && it.endsWith(".zip")
                    }?.let { java.io.File(filesDir, "logs/$it") }
                    if (source == null || !source.isFile) {
                        result.error("LOG_EXPORT_NOT_FOUND", name, null)
                    } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        result.error("LOG_EXPORT_UNSUPPORTED", "Android 10 or newer is required", null)
                    } else {
                        val values = ContentValues().apply {
                            put(MediaStore.MediaColumns.DISPLAY_NAME, source.name)
                            put(MediaStore.MediaColumns.MIME_TYPE, "application/zip")
                            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOCUMENTS)
                            put(MediaStore.MediaColumns.IS_PENDING, 1)
                        }
                        var uri: android.net.Uri? = null
                        try {
                            uri = contentResolver.insert(
                                MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                                values,
                            ) ?: throw java.io.IOException("Unable to create exported log file")
                            contentResolver.openOutputStream(uri, "w").use { output ->
                                if (output == null) throw java.io.IOException("Unable to open exported log file")
                                source.inputStream().use { input -> input.copyTo(output) }
                            }
                            values.clear()
                            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                            contentResolver.update(uri, values, null, null)
                            result.success("${Environment.getExternalStorageDirectory().path}/${Environment.DIRECTORY_DOCUMENTS}/${source.name}")
                        } catch (error: Exception) {
                            if (uri != null) contentResolver.delete(uri, null, null)
                            result.error("LOG_EXPORT_FAILED", error.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.INSTALLER,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSupportedAbi" -> {
                    result.success(Build.SUPPORTED_ABIS.firstOrNull())
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGUMENT", "path is required", null)
                        return@setMethodCallHandler
                    }
                    val file = File(path)
                    if (!file.isFile) {
                        result.error("APK_NOT_FOUND", path, null)
                        return@setMethodCallHandler
                    }
                    val uri = FileProvider.getUriForFile(
                        this,
                        "${packageName}.apk",
                        file,
                    )
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.CLASSIC_SPP,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermissions" -> {
                    requestBluetoothPermissions(result)
                }
                "startScan" -> startSppScan(call, result)
                "stopScan" -> {
                    val results = stopSppScan()
                    result.success(results)
                }
                "connect" -> connect(call, result)
                "send" -> send(call, result)
                "disconnect" -> {
                    disconnect()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.CLASSIC_SPP_EVENTS,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.CLASSIC_SPP_SCAN_EVENTS,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                scanEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                scanEventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.MI_ACCOUNT_2FA,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "resolve" -> resolveMiAccountTwoFactor(call, result)
                else -> result.notImplemented()
            }
        }
        zeppSettingsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlatformChannelNames.ZEPPOS_APP_SETTINGS,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> openZeppSettings(call, result)
                    "close" -> {
                        closeZeppSettings(notify = false)
                        result.success(null)
                    }
                    "settingsChanged" -> {
                        val appId = call.argument<Number>("appId")?.toLong()
                        val settingsJson = call.argument<String>("settingsJson")
                        if (appId == zeppSettingsAppId && settingsJson != null) {
                            zeppSettingsWebView?.evaluateJavascript(
                                "globalThis.__oronboxSettingsChanged($settingsJson)",
                                null,
                            )
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun saveXiaomiScreenshot(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val requestedName = call.argument<String>("fileName")
        if (bytes == null || bytes.isEmpty() || requestedName.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "screenshot bytes and fileName are required", null)
            return
        }
        val fileName = requestedName
            .substringAfterLast('/')
            .substringAfterLast('\\')
            .let { if (it.endsWith(".png", ignoreCase = true)) it else "$it.png" }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingScreenshotSave != null) {
                result.error(
                    "PERMISSION_REQUEST_PENDING",
                    "A screenshot permission request is already pending",
                    null,
                )
                return
            }
            pendingScreenshotSave = PendingScreenshotSave(bytes, fileName, result)
            requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                SCREENSHOT_STORAGE_PERMISSION_REQUEST,
            )
            return
        }

        writeXiaomiScreenshot(bytes, fileName, result)
    }

    private fun writeXiaomiScreenshot(
        bytes: ByteArray,
        fileName: String,
        result: MethodChannel.Result,
    ) {

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(
                        MediaStore.Images.Media.RELATIVE_PATH,
                        Environment.DIRECTORY_PICTURES + "/WatchScreenshots",
                    )
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(
                    MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                    values,
                ) ?: throw IOException("Unable to create screenshot media entry")
                try {
                    contentResolver.openOutputStream(uri, "w").use { output ->
                        if (output == null) throw IOException("Unable to open screenshot media entry")
                        output.write(bytes)
                    }
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                    result.success(
                        Environment.getExternalStorageDirectory().path +
                            "/Pictures/WatchScreenshots/$fileName",
                    )
                } catch (error: Exception) {
                    contentResolver.delete(uri, null, null)
                    throw error
                }
            } else {
                @Suppress("DEPRECATION")
                val directory = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                    "WatchScreenshots",
                )
                if (!directory.exists() && !directory.mkdirs()) {
                    throw IOException("Unable to create screenshot directory")
                }
                val file = File(directory, fileName)
                file.writeBytes(bytes)
                MediaScannerConnection.scanFile(
                    this,
                    arrayOf(file.absolutePath),
                    arrayOf("image/png"),
                    null,
                )
                result.success(file.absolutePath)
            }
        } catch (error: Exception) {
            result.error("SCREENSHOT_SAVE_FAILED", error.message, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == BLUETOOTH_PERMISSION_REQUEST) {
            val pending = pendingBluetoothPermissionResult ?: return
            val continuation = pendingBluetoothPermissionContinuation
            pendingBluetoothPermissionResult = null
            pendingBluetoothPermissionContinuation = null
            val granted = grantResults.isNotEmpty() && grantResults.all {
                it == PackageManager.PERMISSION_GRANTED
            }
            if (granted) {
                continuation?.invoke()
            } else {
                pending.error(
                    "BLUETOOTH_PERMISSION_DENIED",
                    "Bluetooth permission is required",
                    null,
                )
            }
            return
        }
        if (requestCode != SCREENSHOT_STORAGE_PERMISSION_REQUEST) return

        val pending = pendingScreenshotSave ?: return
        pendingScreenshotSave = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            writeXiaomiScreenshot(pending.bytes, pending.fileName, pending.result)
        } else {
            pending.result.error(
                "SCREENSHOT_PERMISSION_DENIED",
                "Storage permission is required to save screenshots",
                null,
            )
        }
    }

    private fun scanLatestWearableLog(result: MethodChannel.Result) {
        val saved = getPreferences(Context.MODE_PRIVATE)
            .getString(WEARABLE_LOG_DIRECTORY_PREF, null)
        if (saved == null) {
            requestWearableLogDirectory(result)
            return
        }
        readLatestWearableLog(Uri.parse(saved), result, retryPermission = true)
    }

    private fun requestWearableLogDirectory(result: MethodChannel.Result) {
        if (pendingWearableLogResult != null) {
            result.error("BUSY", "A wearable log scan is already running", null)
            return
        }
        pendingWearableLogResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(
                    DocumentsContract.EXTRA_INITIAL_URI,
                    Uri.parse(
                        "content://com.android.externalstorage.documents/document/" +
                            "primary%3ADownload%2Fwearablelog",
                    ),
                )
            }
        }
        startActivityForResult(intent, WEARABLE_LOG_DIRECTORY_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != WEARABLE_LOG_DIRECTORY_REQUEST) return
        val result = pendingWearableLogResult ?: return
        pendingWearableLogResult = null
        val treeUri = data?.data
        if (resultCode != RESULT_OK || treeUri == null) {
            result.error("CANCELLED", "Wearable log directory selection cancelled", null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
            getPreferences(Context.MODE_PRIVATE)
                .edit()
                .putString(WEARABLE_LOG_DIRECTORY_PREF, treeUri.toString())
                .apply()
            readLatestWearableLog(treeUri, result, retryPermission = false)
        } catch (error: Exception) {
            result.error("READ_FAILED", error.message, null)
        }
    }

    private fun readLatestWearableLog(
        treeUri: Uri,
        result: MethodChannel.Result,
        retryPermission: Boolean,
    ) {
        wearableLogExecutor.execute {
            try {
                val documentId = DocumentsContract.getTreeDocumentId(treeUri)
                val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                    treeUri,
                    documentId,
                )
                var latestId: String? = null
                var latestName: String? = null
                var latestModified = Long.MIN_VALUE
                val projection = arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                    DocumentsContract.Document.COLUMN_SIZE,
                )
                contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                    val idColumn = cursor.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    )
                    val nameColumn = cursor.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    )
                    val modifiedColumn = cursor.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                    )
                    val sizeColumn = cursor.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_SIZE,
                    )
                    while (cursor.moveToNext()) {
                        val name = cursor.getString(nameColumn) ?: continue
                        if (!name.lowercase().endsWith("log.zip")) continue
                        val size = if (cursor.isNull(sizeColumn)) 0 else cursor.getLong(sizeColumn)
                        if (size > MAX_WEARABLE_LOG_BYTES) continue
                        val modified = if (cursor.isNull(modifiedColumn)) 0 else {
                            cursor.getLong(modifiedColumn)
                        }
                        if (
                            latestId == null ||
                            modified > latestModified ||
                            modified == latestModified && name > (latestName ?: "")
                        ) {
                            latestId = cursor.getString(idColumn)
                            latestName = name
                            latestModified = modified
                        }
                    }
                }
                val id = latestId
                    ?: throw IOException("No wearable log ZIP was found")
                val fileUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, id)
                val bytes = contentResolver.openInputStream(fileUri)?.use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(64 * 1024)
                    var total = 0
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        if (total > MAX_WEARABLE_LOG_BYTES) {
                            throw IOException("Wearable log ZIP is too large")
                        }
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                } ?: throw IOException("Unable to open wearable log ZIP")
                mainHandler.post {
                    result.success(mapOf("name" to latestName, "bytes" to bytes))
                }
            } catch (error: SecurityException) {
                mainHandler.post {
                    if (retryPermission) {
                        getPreferences(Context.MODE_PRIVATE)
                            .edit()
                            .remove(WEARABLE_LOG_DIRECTORY_PREF)
                            .apply()
                        requestWearableLogDirectory(result)
                    } else {
                        result.error("READ_FAILED", error.message, null)
                    }
                }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("READ_FAILED", error.message, null)
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val path = resolveOpenIntent(intent) ?: return
        pendingOpenFilePath = path
        // Warm start: the Dart handler is already listening; push directly.
        fileOpenChannel?.invokeMethod("openFile", path)
    }

    /** Copies an "open with" content/file URI into the cache and returns the
     *  local path, or null when the intent carries no openable file. */
    private fun resolveOpenIntent(intent: Intent?): String? {
        val uri = intent?.data ?: return null
        val scheme = uri.scheme
        if (scheme != "content" && scheme != "file") return null
        return try {
            val name = uri.lastPathSegment?.takeIf { it.isNotBlank() } ?: "opened-file"
            val dir = java.io.File(cacheDir, "file_open").apply { mkdirs() }
            val target = java.io.File(dir, name)
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
            target.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun openZeppSettings(call: MethodCall, result: MethodChannel.Result) {
        val appId = call.argument<Number>("appId")?.toLong()
        val html = call.argument<String>("html")
        val contentTop = call.argument<Number>("contentTop")?.toFloat() ?: 0f
        if (appId == null || html == null) {
            result.error("INVALID_ARGUMENT", "appId and html are required", null)
            return
        }
        mainHandler.post {
            closeZeppSettings(notify = false)
            val density = resources.displayMetrics.density
            val container = FrameLayout(this).apply {
                isClickable = true
                isFocusable = true
                elevation = 1f * density
            }
            val webView = WebView(this)
            webView.settings.javaScriptEnabled = true
            webView.settings.domStorageEnabled = false
            webView.settings.allowFileAccess = false
            webView.settings.allowContentAccess = false
            webView.webChromeClient = WebChromeClient()
            webView.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                    if (url == null || url == "about:blank") return false
                    runCatching { startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url))) }
                    return true
                }
            }
            webView.addJavascriptInterface(object {
                @JavascriptInterface
                fun postMessage(message: String) {
                    val value = runCatching { org.json.JSONObject(message) }.getOrNull() ?: return
                    val type = value.optString("type")
                    val args = mutableMapOf<String, Any?>("appId" to appId)
                    value.keys().forEach { key -> if (key != "type") args[key] = value.opt(key) }
                    mainHandler.post { zeppSettingsChannel?.invokeMethod(type, args) }
                }
            }, "ZeppSettingsBridge")
            container.addView(
                webView,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            findViewById<ViewGroup>(android.R.id.content).addView(
                container,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ).apply { topMargin = (contentTop * density).toInt() },
            )
            zeppSettingsContainer = container
            zeppSettingsWebView = webView
            zeppSettingsAppId = appId
            webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
            result.success(null)
        }
    }

    private fun closeZeppSettings(notify: Boolean = true) {
        val appId = zeppSettingsAppId
        val webView = zeppSettingsWebView
        val container = zeppSettingsContainer
        zeppSettingsContainer = null
        zeppSettingsWebView = null
        zeppSettingsAppId = null
        (container?.parent as? ViewGroup)?.removeView(container)
        webView?.removeJavascriptInterface("ZeppSettingsBridge")
        webView?.stopLoading()
        webView?.loadUrl("about:blank")
        webView?.destroy()
        if (notify && appId != null) {
            zeppSettingsChannel?.invokeMethod("closed", mapOf("appId" to appId))
        }
    }

    @SuppressLint("MissingPermission")
    private fun startSppScan(call: MethodCall, result: MethodChannel.Result) {
        if (!hasBluetoothScanPermission() || !hasBluetoothConnectPermission()) {
            withBluetoothPermissions(result) { startSppScan(call, result) }
            return
        }
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("ADAPTER_UNAVAILABLE", "BluetoothAdapter is unavailable", null)
            return
        }

        stopSppScan()
        val generation = ++scanGeneration
        scanResults.clear()

        adapter.bondedDevices?.forEach { device ->
            emitSppScanDevice(device)
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(
                                BluetoothDevice.EXTRA_DEVICE,
                                BluetoothDevice::class.java,
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        }
                        if (device != null) emitSppScanDevice(device)
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        mainHandler.postDelayed({
                            if (scanReceiver != null) {
                                runCatching { adapter.startDiscovery() }
                            }
                        }, 800)
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
        scanReceiver = receiver
        if (adapter.isDiscovering) adapter.cancelDiscovery()
        if (!adapter.startDiscovery()) {
            stopSppScan()
            result.error("SCAN_FAILED", "startDiscovery() failed", null)
            return
        }

        val timeoutMs = call.argument<Int>("timeoutMs") ?: 15_000
        val stopRunnable = Runnable {
            if (scanGeneration == generation) {
                stopSppScan()
            }
        }
        scanStopRunnable = stopRunnable
        mainHandler.postDelayed(stopRunnable, timeoutMs.toLong())
        result.success(null)
    }

    @SuppressLint("MissingPermission")
    private fun emitSppScanDevice(device: BluetoothDevice) {
        val addr = device.address ?: return
        val item = mapOf(
            "name" to (device.name ?: "Unknown device"),
            "addr" to addr,
            "connectType" to "spp",
        )
        if (scanResults.containsKey(addr)) return
        scanResults[addr] = item
        mainHandler.post { scanEventSink?.success(item) }
    }

    @SuppressLint("MissingPermission")
    private fun stopSppScan(): List<Map<String, Any?>> {
        scanStopRunnable?.let { mainHandler.removeCallbacks(it) }
        scanStopRunnable = null
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter?.isDiscovering == true) {
            adapter.cancelDiscovery()
        }
        scanReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        scanReceiver = null
        return scanResults.values.toList()
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun resolveMiAccountTwoFactor(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "url is required", null)
            return
        }

        mainHandler.post {
            val dialog = Dialog(this)
            dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
            val webView = WebView(this)
            var completed = false
            val cookieManager = CookieManager.getInstance()
            cookieManager.setAcceptCookie(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                cookieManager.setAcceptThirdPartyCookies(webView, true)
            }

            fun cookieHeaderFor(currentUrl: String?): String {
                val values = linkedMapOf<String, String>()
                listOf(
                    currentUrl,
                    "https://account.xiaomi.com",
                    "https://mi.com",
                    "https://xiaomi.com",
                ).filterNotNull().forEach { cookieUrl ->
                    cookieManager.getCookie(cookieUrl)
                        ?.split(";")
                        ?.map { it.trim() }
                        ?.filter { it.contains("=") }
                        ?.forEach { pair ->
                            val index = pair.indexOf("=")
                            val name = pair.substring(0, index).trim()
                            val value = pair.substring(index + 1).trim()
                            if (name.isNotEmpty() && value.isNotEmpty()) {
                                values[name] = value
                            }
                        }
                }
                return values.entries.joinToString("; ") { "${it.key}=${it.value}" }
            }

            fun hasSessionCookie(header: String): Boolean {
                val names = header.split(";")
                    .mapNotNull { pair ->
                        val index = pair.indexOf("=")
                        if (index <= 0) null else pair.substring(0, index).trim()
                    }
                    .toSet()
                return names.contains("passToken") ||
                    names.contains("cUserId") ||
                    names.contains("userId")
            }

            fun completeIfReady(currentUrl: String?) {
                if (completed) return
                val header = cookieHeaderFor(currentUrl)
                if (!hasSessionCookie(header)) return
                completed = true
                cookieManager.flush()
                dialog.dismiss()
                result.success(header)
            }

            fun failIfOpen(code: String, message: String) {
                if (completed) return
                completed = true
                dialog.dismiss()
                result.error(code, message, null)
            }

            val poller = object : Runnable {
                override fun run() {
                    if (completed) return
                    completeIfReady(webView.url)
                    mainHandler.postDelayed(this, 750)
                }
            }

            webView.settings.javaScriptEnabled = true
            webView.settings.domStorageEnabled = true
            webView.webChromeClient = WebChromeClient()
            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, finishedUrl: String?) {
                    super.onPageFinished(view, finishedUrl)
                    val currentUrl = finishedUrl ?: view?.url
                    completeIfReady(currentUrl)
                    view?.evaluateJavascript(
                        "(document.body && document.body.innerText || '').trim()",
                        ValueCallback { body ->
                            val text = body
                                ?.trim()
                                ?.trim('"')
                                ?.replace("\\n", "\n")
                                ?.trim()
                                ?.lowercase()
                            if (text == "ok" || text?.endsWith("\nok") == true) {
                                completeIfReady(currentUrl)
                            }
                        },
                    )
                }
            }

            dialog.setContentView(
                webView,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            dialog.window?.setLayout(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            dialog.setOnCancelListener {
                failIfOpen("CANCELLED", "Xiaomi 2FA WebView was cancelled")
            }
            dialog.setOnDismissListener {
                mainHandler.removeCallbacks(poller)
                webView.stopLoading()
                webView.destroy()
                if (!completed) {
                    completed = true
                    result.error("CANCELLED", "Xiaomi 2FA WebView was closed", null)
                }
            }
            dialog.show()
            dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            dialog.window?.setLayout(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            // Android's CookieManager is process-global and otherwise keeps
            // the previous Xiaomi account between two-factor sessions.  A
            // fresh login must start without the old account's cookies.
            webView.clearHistory()
            webView.clearCache(true)
            cookieManager.removeAllCookies {
                if (completed) return@removeAllCookies
                cookieManager.flush()
                webView.loadUrl(url)
                mainHandler.postDelayed(poller, 750)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        val addr = call.argument<String>("addr")
        if (addr.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "addr is required", null)
            return
        }
        val serviceUuid = call.argument<String>("serviceUuid")
            ?.takeIf { it.isNotBlank() }
            ?.let { runCatching { UUID.fromString(it) }.getOrNull() }
        val fallbackChannels = call.argument<List<Int>>("fallbackChannels")
            ?.mapNotNull { it.takeIf { channel -> channel in 1..30 } }
            ?.distinct()
            ?: listOf(5, 1)
        val removeBond = call.argument<Boolean>("removeBond") ?: false
        if (!hasBluetoothConnectPermission()) {
            withBluetoothPermissions(result) { connect(call, result) }
            return
        }

        Thread {
            // Invalidate and close the previous attempt before starting a new
            // one.  The UI can issue a second connect while the first socket
            // is still blocked in BluetoothSocket.connect().
            val generation = connectGeneration.incrementAndGet()
            closeSppTransport()
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                    ?: throw IOException("BluetoothAdapter is unavailable")
                val device = adapter.getRemoteDevice(addr)

                if (adapter.isDiscovering) adapter.cancelDiscovery()
                if (removeBond) resetBond(device)
                ensureBonded(device)
                if (generation != connectGeneration.get()) {
                    throw IOException("SPP connect was cancelled")
                }

                val failures = mutableListOf<String>()
                val connected = serviceUuid?.let {
                    tryUuid(device, it, generation, failures, "configured UUID")
                }
                    ?: fallbackChannels.firstNotNullOfOrNull { channel ->
                        tryChannel(device, channel, generation, failures)
                    }
                    ?: if (serviceUuid == null) {
                        tryUuid(
                            device,
                            sppUuid,
                            generation,
                            failures,
                            "standard SPP UUID",
                        )
                    } else {
                        null
                    }
                    ?: trySdpUuid(device, serviceUuid, generation, failures)
                    ?: throw IOException(
                        buildString {
                            append("No SPP channel/UUID available")
                            if (failures.isNotEmpty()) {
                                append(": ")
                                append(failures.joinToString("; "))
                            }
                        },
                    )

                if (generation != connectGeneration.get()) {
                    connected.socket.close()
                    throw IOException("SPP connect was cancelled")
                }
                synchronized(sppStateLock) {
                    if (generation != connectGeneration.get()) {
                        connected.socket.close()
                        throw IOException("SPP connect was cancelled")
                    }
                    sppSocket = connected.socket
                }
                if (!startReadThread(connected.socket, generation)) {
                    throw IOException("SPP connect was cancelled")
                }
                mainHandler.post {
                    result.success(mapOf("channel" to connected.channel))
                }
            } catch (e: Exception) {
                // A stale attempt must never tear down the socket established
                // by a newer attempt.
                if (generation == connectGeneration.get()) {
                    closeSppTransport()
                }
                mainHandler.post {
                    result.error(
                        if (generation == connectGeneration.get()) {
                            "CONNECT_FAILED"
                        } else {
                            "CONNECT_CANCELLED"
                        },
                        e.message ?: e.toString(),
                        null,
                    )
                }
            }
        }.start()
    }

    private fun send(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("data")
        if (data == null) {
            result.error("INVALID_ARGUMENT", "data is required", null)
            return
        }
        val socket = sppSocket
        if (socket == null || !socket.isConnected) {
            result.error("NOT_CONNECTED", "SPP socket is not connected", null)
            return
        }

        sendExecutor.execute {
            try {
                if (sppSocket !== socket || !socket.isConnected) {
                    throw IOException("SPP socket is no longer connected")
                }
                val out = socket.outputStream
                synchronized(sendLock) {
                    var offset = 0
                    while (offset < data.size) {
                        val length = minOf(512, data.size - offset)
                        out.write(data, offset, length)
                        offset += length
                    }
                    out.flush()
                }
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SEND_FAILED", e.message ?: e.toString(), null)
                }
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun resetBond(device: BluetoothDevice) {
        if (device.bondState == BluetoothDevice.BOND_NONE) return

        val latch = CountDownLatch(1)
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return
                val changed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(
                        BluetoothDevice.EXTRA_DEVICE,
                        BluetoothDevice::class.java,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }
                if (changed?.address == device.address &&
                    changed.bondState == BluetoothDevice.BOND_NONE
                ) {
                    latch.countDown()
                }
            }
        }

        val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
        try {
            val removed = runCatching {
                val method = device.javaClass.getMethod("removeBond")
                method.invoke(device) as? Boolean ?: false
            }.getOrDefault(false)
            if (!removed && device.bondState != BluetoothDevice.BOND_NONE) {
                throw IOException("removeBond() failed")
            }
            if (device.bondState == BluetoothDevice.BOND_NONE) {
                latch.countDown()
            }
            if (!latch.await(10, TimeUnit.SECONDS)) {
                throw IOException("Unpairing timed out")
            }
        } finally {
            try {
                unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun ensureBonded(device: BluetoothDevice) {
        if (device.bondState == BluetoothDevice.BOND_BONDED) return
        val latch = CountDownLatch(1)
        val error = AtomicReference<Exception?>()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return
                val changed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(
                        BluetoothDevice.EXTRA_DEVICE,
                        BluetoothDevice::class.java,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }
                if (changed?.address != device.address) return
                when (changed.bondState) {
                    BluetoothDevice.BOND_BONDED -> latch.countDown()
                    BluetoothDevice.BOND_NONE -> {
                        error.set(IOException("Bonding failed"))
                        latch.countDown()
                    }
                }
            }
        }

        val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
        try {
            if (device.bondState != BluetoothDevice.BOND_BONDING &&
                !device.createBond() &&
                device.bondState != BluetoothDevice.BOND_BONDED
            ) {
                throw IOException("createBond() failed")
            }
            if (device.bondState == BluetoothDevice.BOND_BONDED) {
                latch.countDown()
            }
            if (!latch.await(15, TimeUnit.SECONDS)) {
                throw IOException("Bonding timed out")
            }
            error.get()?.let { throw it }
        } finally {
            try {
                unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun tryUuid(
        device: BluetoothDevice,
        uuid: UUID,
        generation: Long,
        failures: MutableList<String>,
        label: String,
    ): ConnectedSocket? {
        try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(uuid)
            if (connectSocket(socket, 6_000, generation)) {
                return ConnectedSocket(socket, -1)
            }
        } catch (error: Exception) {
            failures += "$label insecure: ${describeBluetoothError(error)}"
        }
        try {
            val socket = device.createRfcommSocketToServiceRecord(uuid)
            if (connectSocket(socket, 6_000, generation)) {
                return ConnectedSocket(socket, -1)
            }
        } catch (error: Exception) {
            failures += "$label secure: ${describeBluetoothError(error)}"
        }
        return null
    }

    @SuppressLint("MissingPermission")
    private fun tryChannel(
        device: BluetoothDevice,
        channel: Int,
        generation: Long,
        failures: MutableList<String>,
    ): ConnectedSocket? {
        val methods = listOf("createInsecureRfcommSocket", "createRfcommSocket")
        for (name in methods) {
            val socket = try {
                val method = device.javaClass.getMethod(name, Int::class.javaPrimitiveType)
                method.invoke(device, channel) as BluetoothSocket
            } catch (error: Exception) {
                failures += "channel $channel $name: ${describeBluetoothError(error)}"
                continue
            }
            try {
                if (connectSocket(socket, 3_000, generation)) {
                    return ConnectedSocket(socket, channel)
                }
            } catch (error: Exception) {
                failures += "channel $channel $name: ${describeBluetoothError(error)}"
            }
        }
        return null
    }

    @SuppressLint("MissingPermission")
    private fun trySdpUuid(
        device: BluetoothDevice,
        preferredUuid: UUID?,
        generation: Long,
        failures: MutableList<String>,
    ): ConnectedSocket? {
        val latch = CountDownLatch(1)
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != BluetoothDevice.ACTION_UUID) return
                val changed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(
                        BluetoothDevice.EXTRA_DEVICE,
                        BluetoothDevice::class.java,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }
                if (changed?.address == device.address) latch.countDown()
            }
        }
        val filter = IntentFilter(BluetoothDevice.ACTION_UUID)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
        try {
            val started = try {
                device.fetchUuidsWithSdp()
            } catch (error: Exception) {
                failures += "SDP start: ${describeBluetoothError(error)}"
                false
            }
            if (!started) {
                failures += "SDP start returned false"
                return null
            }
            if (generation != connectGeneration.get()) return null
            if (!latch.await(8, TimeUnit.SECONDS)) {
                failures += "SDP discovery timed out after 8s"
            }
            if (generation != connectGeneration.get()) return null
            val parcel = device.uuids
                ?.firstOrNull {
                    if (preferredUuid != null) {
                        it.uuid == preferredUuid
                    } else {
                        it.uuid.toString().startsWith("00001101", ignoreCase = true)
                    }
                }
            if (parcel == null) {
                failures += "matching SDP UUID not found"
                return null
            }
            return tryUuid(
                device,
                parcel.uuid,
                generation,
                failures,
                "SDP UUID ${parcel.uuid}",
            )
        } finally {
            try {
                unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
            }
        }
    }

    private fun describeBluetoothError(error: Throwable): String {
        val cause = if (error is java.lang.reflect.InvocationTargetException) {
            error.targetException ?: error
        } else {
            error
        }
        val message = cause.message?.replace('\n', ' ')?.trim()
        return if (message.isNullOrEmpty()) {
            cause.javaClass.simpleName
        } else {
            "${cause.javaClass.simpleName}: $message"
        }
    }

    private fun connectSocket(
        socket: BluetoothSocket,
        timeoutMs: Long,
        generation: Long,
    ): Boolean {
        synchronized(sppStateLock) {
            if (generation != connectGeneration.get()) {
                socket.close()
                return false
            }
            activeConnectingSockets += socket
        }
        val latch = CountDownLatch(1)
        val connected = AtomicReference(false)
        val failure = AtomicReference<Exception?>()
        val connector = Thread {
            try {
                socket.connect()
                connected.set(true)
            } catch (error: Exception) {
                failure.set(error)
            } finally {
                latch.countDown()
            }
        }
        connector.start()
        return try {
            val completed = latch.await(timeoutMs, TimeUnit.MILLISECONDS)
            if (!completed) {
                throw IOException("connection timed out after ${timeoutMs}ms")
            }
            failure.get()?.let { throw it }
            val valid = connected.get() && generation == connectGeneration.get()
            if (!valid) socket.close()
            valid
        } catch (error: Exception) {
            runCatching { socket.close() }
            throw error
        } finally {
            synchronized(sppStateLock) {
                activeConnectingSockets.remove(socket)
            }
        }
    }

    private fun startReadThread(socket: BluetoothSocket, generation: Long): Boolean {
        val thread = Thread {
            val buffer = ByteArray(1024)
            try {
                val input = socket.inputStream
                while (!Thread.currentThread().isInterrupted) {
                    val length = input.read(buffer)
                    if (length <= 0) break
                    val packet = buffer.copyOf(length)
                    mainHandler.post { eventSink?.success(packet) }
                }
            } catch (e: IOException) {
                mainHandler.post { eventSink?.error("READ_FAILED", e.message, null) }
            } finally {
                val isCurrent = readThread == Thread.currentThread() &&
                    sppSocket === socket &&
                    generation == connectGeneration.get()
                if (isCurrent) {
                    closeSppTransport()
                    mainHandler.post {
                        eventSink?.success(mapOf("event" to "disconnected"))
                    }
                }
            }
        }
        synchronized(sppStateLock) {
            if (sppSocket !== socket || generation != connectGeneration.get()) {
                socket.close()
                return false
            }
            readThread = thread
        }
        thread.start()
        return true
    }

    private fun disconnect(cancelConnect: Boolean = true) {
        if (cancelConnect) {
            connectGeneration.incrementAndGet()
        }
        closeSppTransport()
    }

    private fun closeSppTransport() {
        val (thread, socket, sockets) = synchronized(sppStateLock) {
            val currentThread = readThread
            readThread = null
            val currentSocket = sppSocket
            sppSocket = null
            val pending = activeConnectingSockets.toList()
            activeConnectingSockets.clear()
            Triple(currentThread, currentSocket, pending)
        }
        if (thread != null && thread != Thread.currentThread()) {
            thread.interrupt()
        }
        for (socket in sockets) {
            try {
                socket.close()
            } catch (_: IOException) {
            }
        }
        try {
            socket?.close()
        } catch (_: IOException) {
        }
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestBluetoothPermissions(result: MethodChannel.Result) {
        withBluetoothPermissions(result) { result.success(null) }
    }

    private fun withBluetoothPermissions(
        result: MethodChannel.Result,
        continuation: () -> Unit,
    ) {
        val required = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
            )
        } else {
            listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        val missing = required.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            continuation()
            return
        }
        if (pendingBluetoothPermissionResult != null) {
            result.error(
                "PERMISSION_REQUEST_PENDING",
                "A Bluetooth permission request is already pending",
                null,
            )
            return
        }
        pendingBluetoothPermissionResult = result
        pendingBluetoothPermissionContinuation = continuation
        requestPermissions(missing.toTypedArray(), BLUETOOTH_PERMISSION_REQUEST)
    }

    private fun hasBluetoothScanPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun startPhoneFinder() {
        stopPhoneFinder()
        val ringtoneUri = RingtoneManager.getActualDefaultRingtoneUri(
            this,
            RingtoneManager.TYPE_ALARM,
        ) ?: RingtoneManager.getActualDefaultRingtoneUri(
            this,
            RingtoneManager.TYPE_RINGTONE,
        ) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: throw IOException("No default alarm sound is available")
        val player = MediaPlayer()
        try {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            player.setDataSource(this, ringtoneUri)
            player.isLooping = true
            player.setOnErrorListener { _, what, extra ->
                writeNativeLog(
                    File(filesDir, "logs/phone-finder.log"),
                    "phone finder playback error what=$what extra=$extra\\n",
                )
                stopPhoneFinder()
                true
            }
            phoneFinderPlayer = player
            player.prepare()
            player.setVolume(1f, 1f)
            player.start()
        } catch (error: Exception) {
            phoneFinderPlayer = null
            runCatching { player.release() }
            throw error
        }

        val vibrator = getSystemService(Vibrator::class.java)
        if (vibrator?.hasVibrator() == true) {
            val pattern = longArrayOf(0, 500, 500)
            vibrator.vibrate(
                VibrationEffect.createWaveform(pattern, 0),
            )
            phoneFinderVibrator = vibrator
        }
    }

    private fun stopPhoneFinder() {
        phoneFinderPlayer?.let { player ->
            try {
                if (player.isPlaying) player.stop()
            } catch (_: IllegalStateException) {
                // The native callback can race with an audio error callback.
            } finally {
                try {
                    player.reset()
                } catch (_: IllegalStateException) {
                    // Already released by the competing callback.
                }
                try {
                    player.release()
                } catch (_: IllegalStateException) {
                    // Nothing left to release.
                }
            }
        }
        phoneFinderPlayer = null
        phoneFinderVibrator?.cancel()
        phoneFinderVibrator = null
    }

    private data class ConnectedSocket(
        val socket: BluetoothSocket,
        val channel: Int,
    )

    override fun onDestroy() {
        stopPhoneFinder()
        disconnect()
        sessionMarker?.let { marker ->
            if (isFinishing || isChangingConfigurations) marker.delete()
        }
        sessionMarker = null
        XmsWearableBridge.detach(xmsWearableChannel)
        xmsWearableChannel = null
        closeZeppSettings(notify = false)
        stopSppScan()
        sendExecutor.shutdownNow()
        wearableLogExecutor.shutdownNow()
        pendingWearableLogResult?.error("CANCELLED", "Activity destroyed", null)
        pendingWearableLogResult = null
        pendingBluetoothPermissionResult?.error(
            "CANCELLED",
            "Activity destroyed while requesting Bluetooth permission",
            null,
        )
        pendingBluetoothPermissionResult = null
        pendingBluetoothPermissionContinuation = null
        super.onDestroy()
    }
}
