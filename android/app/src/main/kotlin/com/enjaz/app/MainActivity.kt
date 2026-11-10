package com.enjaz.app

import android.view.WindowManager
import android.os.Build
import android.os.Bundle
import android.content.Intent
import android.provider.Settings
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val privacyChannel = "com.enjaz.app/privacy"
    private var assistantChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureLockScreenFlags()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        configureLockScreenFlags()
        if (intent.action == "com.enjaz.app.VOICE") assistantChannel?.invokeMethod("voiceShortcut", null)
    }

    private fun configureLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(KEYGUARD_SERVICE) as? android.app.KeyguardManager
            km?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        assistantChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.enjaz.app/assistant")
        assistantChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeShortcut" -> {
                    val voice = intent?.action == "com.enjaz.app.VOICE"
                    if (voice) intent.action = Intent.ACTION_MAIN
                    result.success(voice)
                }
                "timezone" -> result.success(java.util.TimeZone.getDefault().id)
                "alarmUri" -> {
                    try {
                        val uri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
                        result.success(uri?.toString() ?: "content://settings/system/alarm_alert")
                    } catch (e: Exception) {
                        result.success("content://settings/system/alarm_alert")
                    }
                }
                "turnScreenOn" -> {
                    configureLockScreenFlags()
                    result.success(true)
                }
                "openXiaomiOtherPermissions" -> {
                    try {
                        val miuiIntent = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                            setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
                            putExtra("extra_pkgname", packageName)
                        }
                        startActivity(miuiIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val appDetailsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = android.net.Uri.parse("package:$packageName")
                            }
                            startActivity(appDetailsIntent)
                            result.success(true)
                        } catch (ex: Exception) {
                            result.error("settings_unavailable", ex.message, null)
                        }
                    }
                }
                "isXiaomiDevice" -> {
                    val m = (android.os.Build.MANUFACTURER ?: "").lowercase()
                    val b = (android.os.Build.BRAND ?: "").lowercase()
                    val isXiaomi = m.contains("xiaomi") || m.contains("redmi") || m.contains("poco") ||
                                   b.contains("xiaomi") || b.contains("redmi") || b.contains("poco")
                    result.success(isXiaomi)
                }
                "exactAlarmSettings" -> {
                    try {
                        val settingsIntent = if (android.os.Build.VERSION.SDK_INT >= 31)
                            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, android.net.Uri.parse("package:$packageName"))
                        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:$packageName"))
                        startActivity(settingsIntent)
                        result.success(true)
                    } catch (e: Exception) { result.error("settings_unavailable", null, null) }
                }
                "networkState" -> {
                    val manager = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
                    val caps = manager.getNetworkCapabilities(manager.activeNetwork)
                    result.success(mapOf("airplane" to (Settings.Global.getInt(contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) != 0), "connected" to (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true)))
                }
                "speechSettings" -> {
                    try { startActivity(Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)); result.success(true) }
                    catch (e: Exception) { result.success(false) }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, privacyChannel).setMethodCallHandler { call, result ->
            if (call.method == "setSecure") {
                val secure = call.argument<Boolean>("secure") ?: false
                if (secure) {
                    window.setFlags(
                        WindowManager.LayoutParams.FLAG_SECURE,
                        WindowManager.LayoutParams.FLAG_SECURE
                    )
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
