package com.example.adams_mobile

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val guardianAlertChannel = "adams/guardian_alerts"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            guardianAlertChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrateAlert" -> {
                    try {
                        vibrateAlert()
                        result.success(null)
                    } catch (error: Exception) {
                        result.error(
                            "VIBRATION_FAILED",
                            error.message,
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrateAlert() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (!vibrator.hasVibrator()) {
            return
        }

        val pattern = longArrayOf(0, 220, 120, 320, 120, 420)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createWaveform(pattern, -1)
            )
        } else {
            vibrator.vibrate(pattern, -1)
        }
    }
}
