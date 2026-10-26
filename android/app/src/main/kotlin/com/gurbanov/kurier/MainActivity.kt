package com.gurbanov.kurier

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.net.Uri
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val usageChannel = "a7_tagam_kurier/usage"
    private val navigationChannel = "a7_tagam_kurier/navigation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, usageChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "trafficStats" -> result.success(trafficStats())
                    "networkType" -> result.success(networkType())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, navigationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openInPackage" -> result.success(
                        openInPackage(call.argument("uri"), call.argument("package")),
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Opens [uri] in one named application rather than letting Android ask
     * which app should handle it.
     *
     * A `geo:` link is claimed by every map on the phone, so `url_launcher`
     * alone puts a chooser in front of a courier who already pressed a button
     * that names the app. Pinning the package skips that. Returns false when
     * the application is not installed, which is the caller's cue to offer
     * the store page instead of failing silently.
     */
    private fun openInPackage(uri: String?, packageName: String?): Boolean {
        if (uri == null || packageName == null) return false
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).apply {
            setPackage(packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    /**
     * Bytes carried by this application's UID since the phone was booted.
     * Unsupported devices return [TrafficStats.UNSUPPORTED]; Flutter receives
     * null in that case and presents an honest unavailable state.
     */
    private fun trafficStats(): Map<String, Any?> {
        val uid = Process.myUid()
        val rx = TrafficStats.getUidRxBytes(uid)
        val tx = TrafficStats.getUidTxBytes(uid)
        return mapOf(
            "rx" to if (rx == TrafficStats.UNSUPPORTED.toLong()) null else rx,
            "tx" to if (tx == TrafficStats.UNSUPPORTED.toLong()) null else tx,
        )
    }

    /**
     * TrafficStats does not separate mobile and Wi-Fi per UID. We classify
     * each sampled difference by the active connection at that moment.
     */
    private fun networkType(): String {
        val manager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return "none"
        val network = manager.activeNetwork ?: return "none"
        val capabilities = manager.getNetworkCapabilities(network) ?: return "none"
        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "mobile"
            else -> "other"
        }
    }
}
