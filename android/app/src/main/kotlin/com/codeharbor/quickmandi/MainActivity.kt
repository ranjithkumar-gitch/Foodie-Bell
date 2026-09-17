package com.codeharbor.quickmandi

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val APP_ICON_CHANNEL = "com.quickmandi/app_icon"

/// Component names for the primary launcher activity and every occasion
/// alternate-icon alias declared in AndroidManifest.xml — exactly one is
/// ever enabled at a time. Keyed by the same "festiveGold"/"festiveRed"
/// strings the Dart side (`app_icon_channel.dart`) and iOS's
/// `CFBundleAlternateIcons` keys both use, so there's one canonical key
/// across the whole feature, not a per-platform lookup table.
class MainActivity : FlutterActivity() {
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
