package com.codeharbor.quickmandi

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

private const val APP_ICON_CHANNEL = "com.quickmandi/app_icon"
private const val UPI_CHANNEL = "com.quickmandi/upi"
private const val UPI_PAY_REQUEST = 4721

/// Component names for the primary launcher activity and every occasion
/// alternate-icon alias declared in AndroidManifest.xml — exactly one is
/// ever enabled at a time. Keyed by the same "festiveGold"/"festiveRed"
/// strings the Dart side (`app_icon_channel.dart`) and iOS's
/// `CFBundleAlternateIcons` keys both use, so there's one canonical key
/// across the whole feature, not a per-platform lookup table.
class MainActivity : FlutterActivity() {
    /// The Dart `pay` call waiting on the UPI app to finish — answered from
    /// [onActivityResult]. Only one payment can be in flight at a time.
    private var pendingUpiResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_ICON_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "setIcon") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                setLauncherIcon(name)
                result.success(null)
            }

        // UPI intent payments (`upi_service.dart`): list the installed UPI
        // apps, and open one with a `upi://pay` link, returning the app's
        // response string (txnId=...&Status=SUCCESS&...) when it closes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPI_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getUpiApps" -> result.success(getUpiApps())
                    "pay" -> startUpiPayment(
                        call.argument<String>("uri")!!,
                        call.argument<String>("packageName"),
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun getUpiApps(): List<Map<String, Any?>> {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay"))
        val pm = packageManager
        return pm.queryIntentActivities(intent, 0)
            .distinctBy { it.activityInfo.packageName }
            .map {
                mapOf(
                    "packageName" to it.activityInfo.packageName,
                    "name" to it.loadLabel(pm).toString(),
                    "icon" to drawableToPng(it.loadIcon(pm)),
                )
            }
    }

    private fun startUpiPayment(uri: String, packageName: String?, result: MethodChannel.Result) {
        if (pendingUpiResult != null) {
            result.error("busy", "A UPI payment is already in progress", null)
            return
        }
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
        if (packageName != null) intent.setPackage(packageName)
        try {
            pendingUpiResult = result
            startActivityForResult(intent, UPI_PAY_REQUEST)
        } catch (e: ActivityNotFoundException) {
            pendingUpiResult = null
            result.error("no_app", "No UPI app found", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != UPI_PAY_REQUEST) return
        val result = pendingUpiResult ?: return
        pendingUpiResult = null
        // Most UPI apps put their result in "response"; a few older ones
        // only fill "Status". Null means the user backed out.
        val response = data?.getStringExtra("response")
            ?: data?.getStringExtra("Status")?.let { "Status=$it" }
        result.success(if (resultCode == Activity.RESULT_CANCELED && response == null) null else response)
    }

    private fun drawableToPng(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val size = 96
            val b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(b)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            b
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    private fun setLauncherIcon(iconKey: String?) {
        // Empty for now — the old festiveGold/festiveRed/Dasara icon assets
        // and their AndroidManifest.xml <activity-alias> entries were
        // removed along with the app icon refresh. `aliases[iconKey] ?:
        // primary` below means any iconKey (stale Firestore data included)
        // just falls back to the primary icon rather than crashing. Add an
        // entry here (matching a real <activity-alias> in
        // AndroidManifest.xml) once a new occasion icon is generated.
        val aliases = mapOf<String, ComponentName>()
        val primary = ComponentName(this, "$packageName.MainActivity")
        val toEnable = aliases[iconKey] ?: primary

        val pm = packageManager
        // Enable the requested one first, then disable every other
        // component — never a moment with zero enabled launcher entries.
        pm.setComponentEnabledSetting(
            toEnable,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        (aliases.values + primary).filter { it != toEnable }.forEach {
            pm.setComponentEnabledSetting(
                it,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
