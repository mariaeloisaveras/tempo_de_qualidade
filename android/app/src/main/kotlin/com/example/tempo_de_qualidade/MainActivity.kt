package com.example.tempo_de_qualidade

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val geofencingClient by lazy { LocationServices.getGeofencingClient(this) }
    private val pendingIntent: PendingIntent by lazy {
        val intent = Intent(this, GeofenceBroadcastReceiver::class.java).apply {
            action = GeofenceBroadcastReceiver.ACTION_GEOFENCE_EVENT
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        PendingIntent.getBroadcast(this, 0, intent, flags)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "registerGeofence" -> handleRegisterGeofence(call, result)
                "removeGeofence" -> handleRemoveGeofence(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleRegisterGeofence(call: MethodCall, result: MethodChannel.Result) {
        val latitude = call.argument<Double>("lat")
        val longitude = call.argument<Double>("lng")
        val radius = call.argument<Double>("radiusMeters")
        val id = call.argument<String>("id")

        if (latitude == null || longitude == null || radius == null || id.isNullOrBlank()) {
            result.error("ARGUMENT_ERROR", "Missing or invalid geofence arguments", null)
            return
        }

        val geofence = Geofence.Builder()
            .setRequestId(id)
            .setCircularRegion(latitude, longitude, radius.toFloat())
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()

        geofencingClient.addGeofences(request, pendingIntent)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { error ->
                result.error("ADD_FAILED", error.localizedMessage, null)
            }
    }

    private fun handleRemoveGeofence(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("ARGUMENT_ERROR", "Geofence id is required", null)
            return
        }

        geofencingClient.removeGeofences(listOf(id))
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { error ->
                result.error("REMOVE_FAILED", error.localizedMessage, null)
            }
    }

    companion object {
        private const val CHANNEL = "com.example.tempo_de_qualidade/geofencing"
    }
}
