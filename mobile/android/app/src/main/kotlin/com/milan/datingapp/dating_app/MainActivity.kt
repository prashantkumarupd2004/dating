package com.milan.datingapp.dating_app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

/**
 * MainActivity — bridges Android intents to Flutter via MethodChannels.
 *
 * Channels:
 *  1. [CALL_FOREGROUND_CHANNEL] — start/stop foreground service (existing)
 *  2. [CALL_NAV_CHANNEL]        — informs Flutter of a pending navigation action
 *     • getPendingCallAction() → String? ("OPEN_ACTIVE_CALL" | "END_CALL" | null)
 *     • clearPendingCallAction() → void
 *
 * When the user taps the ongoing-call notification (ACTION_OPEN_ACTIVE_CALL)
 * or "End Call" notification button (ACTION_END_CALL), Android delivers the
 * intent here via onCreate() or onNewIntent(). We store the action so Flutter
 * can query it after initialisation.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val CALL_FOREGROUND_CHANNEL = "com.milan.datingapp/call_foreground"
        private const val CALL_NAV_CHANNEL        = "com.milan.datingapp/call_navigation"
    }

    // The action we want to pass to Flutter once the engine is ready.
    // Guarded by @Volatile so it is safely readable from any thread.
    @Volatile private var _pendingCallAction: String? = null

    // ── Activity lifecycle ────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        readIntentAction(intent)
    }

    /**
     * Called when a new Intent is delivered to an already-running Activity
     * (e.g. notification tap while the app is backgrounded).
     * launchMode="singleTop" in the manifest ensures this fires instead of
     * creating a second Activity instance.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readIntentAction(intent)
        Log.d(TAG, "[NOTIFICATION_CLICKED] onNewIntent: action=${intent.action}")

        // If Flutter engine is already running, push the action immediately
        // via the event channel / method channel instead of waiting for a query.
        flutterEngine?.dartExecutor?.let { executor ->
            MethodChannel(executor.binaryMessenger, CALL_NAV_CHANNEL)
                .invokeMethod("onNewIntent", _pendingCallAction)
        }
    }

    // ── Flutter engine configuration ──────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Channel 1: Foreground service control (existing) ─────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_FOREGROUND_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCallForeground" -> {
                    val callerName = call.argument<String>("callerName") ?: "Call"
                    val callType   = call.argument<String>("callType")   ?: "audio"
                    Log.d(TAG, "[MIC_START] startCallForeground callerName=$callerName")
                    CallForegroundService.startCallService(this, callerName, callType)
                    result.success(null)
                }
                "stopCallForeground" -> {
                    Log.d(TAG, "[MIC_STOP] stopCallForeground")
                    CallForegroundService.stopCallService(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── Channel 2: Call navigation / intent bridge ────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_NAV_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Flutter queries this on startup (cold + warm) to know whether
                // it should navigate to the Call Screen or end the call.
                "getPendingCallAction" -> {
                    Log.d(TAG, "[NOTIFICATION_CLICKED] getPendingCallAction → $_pendingCallAction")
                    result.success(_pendingCallAction)
                }
                // Flutter calls this once it has handled the pending action.
                "clearPendingCallAction" -> {
                    Log.d(TAG, "[NOTIFICATION_CLICKED] clearPendingCallAction")
                    _pendingCallAction = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun readIntentAction(intent: Intent?) {
        when (intent?.action) {
            CallForegroundService.ACTION_OPEN_ACTIVE_CALL -> {
                _pendingCallAction = "OPEN_ACTIVE_CALL"
                Log.d(TAG, "[NOTIFICATION_CLICKED] Pending action set: OPEN_ACTIVE_CALL")
            }
            CallForegroundService.ACTION_END_CALL -> {
                _pendingCallAction = "END_CALL"
                Log.d(TAG, "[NOTIFICATION_END_CALL] Pending action set: END_CALL")
            }
            else -> {
                // Normal launch — no pending call action.
            }
        }
    }
}
