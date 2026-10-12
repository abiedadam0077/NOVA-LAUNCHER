package com.nova.launcher

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.opengl.EGL14
import android.os.Build
import android.os.Environment
import android.os.StatFs
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * NOVA Launcher native bridge.
 *
 * Channels:
 *  - nova/device : legal, read-only device capabilities (CPU/RAM/GPU/storage/screen).
 *  - nova/app    : runtime bridge helpers (installed runtimes, launch, APK install).
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceInfo" -> result.success(collectDeviceInfo())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/app")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledRuntimes" -> result.success(getInstalledRuntimes())
                    "launchRuntime" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg == null) {
                            result.error("ARG", "package missing", null)
                        } else {
                            result.success(launchRuntime(pkg, call.argument<String>("versionId"),
                                call.argument<String>("gameDir")))
                        }
                    }
                    "canInstallPackages" ->
                        result.success(packageManager.canRequestPackageInstalls())
                    "requestInstallPermission" -> {
                        openInstallPermissionSettings()
                        result.success(true)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("ARG", "path missing", null)
                        } else {
                            try {
                                result.success(installApk(path))
                            } catch (e: Exception) {
                                result.error("INSTALL_FAILED", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ---------------------------------------------------------------- device

    private fun collectDeviceInfo(): Map<String, Any?> {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        am.getMemoryInfo(memInfo)

        val stat = StatFs(Environment.getDataDirectory().path)
        val dm = resources.displayMetrics

        return mapOf(
            "cpuName" to cpuName(),
            "abis" to Build.SUPPORTED_ABIS.toList(),
            "totalRamBytes" to memInfo.totalMem,
            "availableRamBytes" to memInfo.availMem,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "screenWidthPx" to dm.widthPixels,
            "screenHeightPx" to dm.heightPixels,
            "screenDensity" to dm.density,
            "internalStorageFreeBytes" to stat.availableBytes,
            "internalStorageTotalBytes" to stat.totalBytes,
            "gpuRenderer" to gpuRenderer(),
            "gpuVendor" to gpuVendor(),
            "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}"
        )
    }

    private fun cpuName(): String {
        return if (Build.VERSION.SDK_INT >= 31) {
            Build.SOC_MODEL
        } else {
            try {
                File("/proc/cpuinfo").readLines()
                    .firstOrNull { it.startsWith("Hardware") }
                    ?.substringAfter(":")?.trim()
                    ?: Build.HARDWARE
            } catch (e: Exception) {
                Build.HARDWARE
            }
        }
    }

    private fun gpuRenderer(): String? = eglString(EGL14.EGL_EXTENSIONS)
    private fun gpuVendor(): String? = eglString(EGL14.EGL_VENDOR)

    private fun eglString(which: Int): String? {
        return try {
            val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            EGL14.eglQueryString(display, which)
        } catch (e: Exception) {
            null
        }
    }

    // ---------------------------------------------------------------- runtimes

    /**
     * Known Minecraft: Java Edition runtimes for Android that NOVA can bridge to.
     * Only actually-installed packages are reported (no fake data).
     */
    private fun getInstalledRuntimes(): List<Map<String, String>> {
        val candidates = listOf(
            "net.kdt.pojavlaunch" to "PojavLauncher",
            "net.kdt.pojavlaunch.debug" to "PojavLauncher (debug)",
            "com.movtery.zalithlauncher" to "Zalith Launcher",
            "com.fcl.team" to "Fold Craft Launcher"
        )
        val found = mutableListOf<Map<String, String>>()
        for ((pkg, fallbackName) in candidates) {
            try {
                val info = packageManager.getApplicationInfo(pkg, 0)
                val label = packageManager.getApplicationLabel(info).toString()
                var version = ""
                try {
                    version = packageManager.getPackageInfo(pkg, 0).versionName ?: ""
                } catch (ignored: Exception) {
                }
                found.add(mapOf("package" to pkg, "name" to label.ifEmpty { fallbackName },
                    "version" to version))
            } catch (ignored: PackageManager.NameNotFoundException) {
                // Not installed - honestly skipped.
            }
        }
        return found
    }

    /**
     * Starts a compatible runtime app. NOVA passes the prepared version id and
     * game directory as extras; runtimes that support external configuration
     * will pick them up, others simply open their own UI.
     */
    private fun launchRuntime(pkg: String, versionId: String?, gameDir: String?): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
        if (versionId != null) intent.putExtra("nova_version", versionId)
        if (gameDir != null) intent.putExtra("nova_gamedir", gameDir)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
    }

    // ---------------------------------------------------------------- install

    private fun openInstallPermissionSettings() {
        try {
            val intent = Intent(
                android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        } catch (ignored: Exception) {
        }
    }

    private fun installApk(path: String): Boolean {
        if (!packageManager.canRequestPackageInstalls()) {
            openInstallPermissionSettings()
            return false
        }
        val file = File(path)
        if (!file.exists()) return false
        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.provider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        return true
    }
}
