package com.example.tempo_de_qualidade

import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceTransitionsService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        handleGeofenceIntent(intent)
        stopSelf(startId)
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun handleGeofenceIntent(intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent) ?: return
        if (geofencingEvent.hasError()) {
            Log.e(TAG, "Geofencing error: ${geofencingEvent.errorCode}")
            return
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!notificationManager.isNotificationPolicyAccessGranted) {
            Log.w(TAG, "Notification policy access not granted; skipping DND update.")
            return
        }

        when (geofencingEvent.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                Log.i(TAG, "Entered geofence: ${geofencingEvent.triggeringGeofences.map { it.requestId }}")
            }

            Geofence.GEOFENCE_TRANSITION_EXIT -> {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                Log.i(TAG, "Exited geofence: ${geofencingEvent.triggeringGeofences.map { it.requestId }}")
            }

            else -> Log.w(TAG, "Unhandled geofence transition: ${geofencingEvent.geofenceTransition}")
        }
    }

    companion object {
        private const val TAG = "GeofenceService"
        const val ACTION_GEOFENCE_EVENT = "com.example.tempo_de_qualidade.GEOFENCE_EVENT"
    }
}
