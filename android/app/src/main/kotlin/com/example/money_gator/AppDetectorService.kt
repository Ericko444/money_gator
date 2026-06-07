package com.example.money_gator

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.content.Intent
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log

class AppDetectorService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var isTimerRunning = false
    private var lastPackageName = ""

    // LIMIT: 15 Seconds
    private val SESSION_LIMIT_MS = 7200000L

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("Gatekeeper", "SERVICE STARTED SUCCESSFULLY")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.packageName == null) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val currentPackage = event.packageName.toString()

            // Filter out system UI events (notification shade, volume, etc)
            if (currentPackage == "com.android.systemui") return

            // If we are still in the same app, ignore (don't reset timer)
            if (currentPackage == lastPackageName) return

            lastPackageName = currentPackage
            Log.d("Gatekeeper", "Switched to: $currentPackage")

            // 1. Kill any existing timer from previous app
            cancelTimer()

            // 2. If it's one of the tracked apps, start the bomb
            val trackedApps = setOf(
                "com.facebook.orca",        // Messenger
                "com.facebook.katana",      // Facebook
                "com.instagram.android"     // Instagram
            )

            if (currentPackage in trackedApps) {
                checkPaymentAndStartTimer()
            }
        }
    }

    private fun checkPaymentAndStartTimer() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val lastPaid = prefs.getLong("flutter.last_paid_timestamp", 0L)
            val currentTime = System.currentTimeMillis()
            val timeSincePayment = currentTime - lastPaid

            Log.d("Gatekeeper", "Checking: Time since paid = ${timeSincePayment}ms")

            if (timeSincePayment > SESSION_LIMIT_MS) {
                Log.d("Gatekeeper", "EXPIRED IMMEDIATELY. Blocking.")
                launchBlocker()
            } else {
                val timeRemaining = SESSION_LIMIT_MS - timeSincePayment
                Log.d("Gatekeeper", "ALLOWED. Timer started for ${timeRemaining}ms")
                startKickOutTimer(timeRemaining)
            }
        } catch (e: Exception) {
            Log.e("Gatekeeper", "CRITICAL ERROR: ${e.message}")
        }
    }

    private fun startKickOutTimer(duration: Long) {
        isTimerRunning = true
        handler.postDelayed({
            // Check one last time if we are still on YouTube
            if (lastPackageName == "com.google.android.youtube") {
                Log.d("Gatekeeper", "BOOM! Timer finished. Blocking now.")
                launchBlocker()
            } else {
                Log.d("Gatekeeper", "Timer finished, but user left YouTube. Safe.")
            }
            isTimerRunning = false
        }, duration)
    }

    private fun cancelTimer() {
        if (isTimerRunning) {
            handler.removeCallbacksAndMessages(null)
            isTimerRunning = false
            Log.d("Gatekeeper", "Timer Cancelled")
        }
    }

    private fun launchBlocker() {
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(intent)
    }

    override fun onInterrupt() {}
}