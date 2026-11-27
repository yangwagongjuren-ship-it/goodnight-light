package com.yangwagongjuren.ambernight

import android.graphics.Color
import android.content.Intent
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var originalBrightness: Float? = null
    private var active = false
    private var foreground = false
    private var shield: View? = null
    private val preferences by lazy { getSharedPreferences("amber_night", MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "amber_night/light")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "openPrivacyPolicy" -> {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://yangwagongjuren-ship-it.github.io/amber-night-support/privacy.html")))
                            result.success(true)
                        }
                        "clock" -> result.success(SystemClock.elapsedRealtime())
                        "loadSettings" -> result.success(mapOf(
                            "seconds" to preferences.getLong("seconds", preferences.getInt("minutes", 15).toLong() * 60),
                            "brightness" to preferences.getFloat("brightness", 0.2f).toDouble(),
                            "language" to preferences.getString("language", "system"),
                            "introSeen" to preferences.getBoolean("introSeen", false)
                        ))
                        "saveSettings" -> {
                            val seconds = call.argument<Number>("seconds")?.toLong() ?: 900L
                            val brightness = call.argument<Number>("brightness")?.toFloat() ?: 0.2f
                            require(seconds in 1L..9223372036854L && brightness.isFinite() && brightness in 0.02f..1f)
                            val language = call.argument<String>("language") ?: "system"
                            require(language in listOf("system", "en", "zh"))
                            check(preferences.edit().putLong("seconds", seconds)
                                .putFloat("brightness", brightness).putString("language", language)
                                .putBoolean("introSeen", call.argument<Boolean>("introSeen") == true).commit())
                            result.success(null)
                        }
                        "begin" -> {
                            check(foreground) { "Activity is not foreground" }
                            val level = call.argument<Number>("brightness")?.toFloat() ?: error("Missing brightness")
                            captureBrightness()
                            applyBrightness(level)
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            active = true
                            removeShield()
                            result.success(null)
                        }
                        "preview" -> {
                            if (foreground) {
                                val level = call.argument<Number>("brightness")?.toFloat() ?: error("Missing brightness")
                                captureBrightness()
                                applyBrightness(level)
                                removeShield()
                            }
                            result.success(null)
                        }
                        "suspend" -> {
                            active = false
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            restoreBrightness()
                            result.success(null)
                        }
                        "setBrightness" -> {
                            if (active && foreground) applyBrightness(call.argument<Number>("brightness")?.toFloat() ?: error("Missing brightness"))
                            result.success(null)
                        }
                        "release" -> {
                            active = false
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            if (call.argument<Boolean>("keepDark") == true) {
                                if (foreground) {
                                    captureBrightness()
                                    applyBrightness(0.01f)
                                    removeShield()
                                }
                            } else {
                                restoreBrightness()
                                if (foreground) removeShield()
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    active = false
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    restoreBrightness()
                    result.error("LIGHT_CONTROL", e.message, null)
                }
            }
    }
    private fun captureBrightness() {
        if (originalBrightness == null) originalBrightness = window.attributes.screenBrightness
    }
    private fun applyBrightness(value: Float) {
        require(value.isFinite() && value in 0f..1f)
        window.attributes = window.attributes.apply { screenBrightness = value }
    }
    private fun restoreBrightness() {
        originalBrightness?.let { value -> window.attributes = window.attributes.apply { screenBrightness = value } }
        originalBrightness = null
    }
    private fun addShield() {
        if (shield != null) return
        val view = View(this).apply { setBackgroundColor(Color.BLACK); isClickable = true }
        (window.decorView as ViewGroup).addView(view, ViewGroup.LayoutParams(-1, -1))
        shield = view
    }
    private fun removeShield() {
        shield?.let { (it.parent as? ViewGroup)?.removeView(it) }
        shield = null
    }
    override fun onResume() {
        super.onResume()
        foreground = true
    }
    override fun onPause() {
        if (active || originalBrightness != null) addShield()
        active = false
        foreground = false
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        restoreBrightness()
        super.onPause()
    }
    override fun onStop() { restoreBrightness(); super.onStop() }
    override fun onDestroy() {
        active = false
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        restoreBrightness()
        removeShield()
        super.onDestroy()
    }
}
