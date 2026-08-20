package com.milan.datingapp.dating_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps the call alive when the app is backgrounded.
 *
 * Key lifecycle events handled:
 *  - onTaskRemoved : user swiped the app from Recent Apps → end call, stop service
 *  - ACTION_END_CALL intent action  : user tapped "End Call" in notification
 *  - ACTION_OPEN_ACTIVE_CALL intent : user tapped "Return to Call" in notification
 *                                     or the notification body itself
 *
 * Notification contains two action buttons:
 *  1. "Return to Call" — brings the app to foreground; Flutter reads the intent
 *     action and routes to the active Call Screen.
 *  2. "End Call" — sends ACTION_END_CALL back to this service which then tells
 *     Flutter to terminate the call cleanly.
 */
class CallForegroundService : Service() {

    companion object {
        private const val TAG = "CallForegroundService"
        private const val CHANNEL_ID      = "milan_call_channel"
        private const val NOTIFICATION_ID = 1001

        // Intent actions
        const val ACTION_START_CALL        = "com.milan.datingapp.START_CALL"
        const val ACTION_STOP_CALL         = "com.milan.datingapp.STOP_CALL"
        const val ACTION_END_CALL          = "com.milan.datingapp.END_CALL"
        const val ACTION_OPEN_ACTIVE_CALL  = "com.milan.datingapp.OPEN_ACTIVE_CALL"

        // Intent extras
        const val EXTRA_CALLER_NAME = "caller_name"
        const val EXTRA_CALL_TYPE   = "call_type"

        // ── Public helpers ────────────────────────────────────────────────

        fun startCallService(context: Context, callerName: String, callType: String) {
            Log.d(TAG, "[SERVICE_START] callerName=$callerName callType=$callType")
            val intent = Intent(context, CallForegroundService::class.java).apply {
                action = ACTION_START_CALL
                putExtra(EXTRA_CALLER_NAME, callerName)
                putExtra(EXTRA_CALL_TYPE, callType)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopCallService(context: Context) {
            Log.d(TAG, "[SERVICE_STOP] Stopping call service")
            val intent = Intent(context, CallForegroundService::class.java).apply {
                action = ACTION_STOP_CALL
            }
            context.startService(intent)
        }
    }

    // ── Service lifecycle ─────────────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "[SERVICE_START] Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {

            ACTION_START_CALL -> {
                val callerName = intent.getStringExtra(EXTRA_CALLER_NAME) ?: "Call"
                val callType   = intent.getStringExtra(EXTRA_CALL_TYPE)   ?: "audio"
                val notification = createNotification(callerName, callType)

                // Android 10+: declare foreground service type = microphone
                // This matches the manifest declaration and is required for Android 14+.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID, notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                Log.d(TAG, "[SERVICE_START] Foreground started for call with $callerName")
            }

            ACTION_STOP_CALL -> {
                Log.d(TAG, "[SERVICE_STOP] Received ACTION_STOP_CALL")
                stopForegroundCompat()
                stopSelf()
            }

            ACTION_END_CALL -> {
                // User tapped "End Call" in the notification.
                // Tell Flutter to end the call via the navigation channel.
                Log.d(TAG, "[NOTIFICATION_END_CALL] User ended call from notification")
                // Bring the app to the foreground and pass the END_CALL action
                // so Flutter can perform full cleanup (leaveChannel, API call, etc.)
                val launchIntent = packageManager
                    .getLaunchIntentForPackage(packageName)
                    ?.apply {
                        action   = ACTION_END_CALL
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                if (launchIntent != null) startActivity(launchIntent)

                // Stop the service immediately — Flutter cleanup will also
                // call stopCallForeground, but stopping here ensures the
                // notification is removed even if the app is slow to respond.
                stopForegroundCompat()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    /**
     * Called when the user swipes the app away from the Recent Apps screen.
     *
     * PRODUCT DECISION: swipe = end call.
     * Rationale: leaving an invisible microphone session running after the user
     * explicitly removed the app is a privacy violation and bad UX.
     *
     * We end the call by:
     * 1. Stopping the foreground service and notification immediately.
     * 2. Sending a broadcast/intent to the Flutter engine if it is still alive
     *    (it may not be — the Activity is destroyed at this point).
     * 3. The CallStateStore clear() happens in Flutter _endCall; if Flutter is
     *    already dead, the stale SharedPreferences will be cleaned on next launch
     *    by checking backend status.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "[TASK_REMOVED] App swiped from Recents — ending call")

        // Remove the notification and stop the service.
        stopForegroundCompat()
        stopSelf()

        // Attempt to notify Flutter (best-effort; Flutter engine may be dead).
        // We launch the app with ACTION_END_CALL. If the Flutter engine is alive,
        // MainActivity will route this to Flutter's endCallFromNotification handler.
        // If it is dead, the service is already stopped so the mic will stop.
        try {
            val intent = packageManager
                .getLaunchIntentForPackage(packageName)
                ?.apply {
                    action   = ACTION_END_CALL
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK       or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP     or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION
                    )
                }
            if (intent != null) startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "[TASK_REMOVED] Could not launch cleanup intent: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "[SERVICE_STOP] Service destroyed")
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Active Calls",
                NotificationManager.IMPORTANCE_LOW   // low = no sound while ongoing
            ).apply {
                description  = "Shows ongoing-call notification during active calls"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun createNotification(callerName: String, callType: String): Notification {
        val icon = if (callType == "video") android.R.drawable.ic_menu_camera
                   else                     android.R.drawable.ic_menu_call

        // ── "Return to Call" pending intent ───────────────────────────────
        val returnIntent = packageManager
            .getLaunchIntentForPackage(packageName)
            ?.apply {
                action   = ACTION_OPEN_ACTIVE_CALL
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
        val returnPendingIntent = PendingIntent.getActivity(
            this, 100, returnIntent ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── "End Call" pending intent → sends ACTION_END_CALL to this service
        val endCallIntent = Intent(this, CallForegroundService::class.java).apply {
            action = ACTION_END_CALL
        }
        val endCallPendingIntent = PendingIntent.getService(
            this, 200, endCallIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ongoing ${if (callType == "video") "Video" else "Voice"} Call")
            .setContentText("In call with $callerName")
            .setSmallIcon(icon)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            // Tap the notification body → Return to Call
            .setContentIntent(returnPendingIntent)
            // Action 1: Return to Call
            .addAction(
                android.R.drawable.ic_menu_call,
                "Return to Call",
                returnPendingIntent
            )
            // Action 2: End Call
            .addAction(
                android.R.drawable.ic_delete,
                "End Call",
                endCallPendingIntent
            )
            .build()
    }

    // ── Compat helper ─────────────────────────────────────────────────────────

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        Log.d(TAG, "[SERVICE_STOP] Foreground stopped, notification removed")
    }
}
