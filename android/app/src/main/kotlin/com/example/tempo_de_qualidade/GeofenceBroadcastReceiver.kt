package com.example.tempo_de_qualidade

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null) return

        val geofencingEvent = GeofencingEvent.fromIntent(intent) ?: return
        if (geofencingEvent.hasError()) {
            Log.e(TAG, "Geofencing error: ${geofencingEvent.errorCode}")
            return
        }

        when (geofencingEvent.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> {
                Log.i(TAG, "Entered geofence: ${geofencingEvent.triggeringGeofences.map { it.requestId }}")
            }

            Geofence.GEOFENCE_TRANSITION_EXIT -> {
                Log.i(TAG, "Exited geofence: ${geofencingEvent.triggeringGeofences.map { it.requestId }}")
            }

            else -> Log.w(TAG, "Unhandled geofence transition: ${geofencingEvent.geofenceTransition}")
        }
    }

    companion object {
        private const val TAG = "GeofenceReceiver"
        const val ACTION_GEOFENCE_EVENT = "com.example.tempo_de_qualidade.GEOFENCE_EVENT"
    }
}
