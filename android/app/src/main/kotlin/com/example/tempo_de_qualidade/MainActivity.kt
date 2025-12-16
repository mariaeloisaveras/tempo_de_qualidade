package com.example.tempo_de_qualidade

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

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
                "getStoredGeofences" -> handleGetStoredGeofences(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        reRegisterStoredGeofences()
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
            .addOnSuccessListener {
                saveGeofence(StoredGeofence(id, latitude, longitude, radius.toFloat()))
                Log.i(TAG, "Registered geofence $id at ($latitude,$longitude)")
                result.success(null)
            }
            .addOnFailureListener { error ->
                Log.e(TAG, "Failed to register geofence $id", error)
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
            .addOnSuccessListener {
                removeStoredGeofence(id)
                Log.i(TAG, "Removed geofence $id")
                result.success(null)
            }
            .addOnFailureListener { error ->
                Log.e(TAG, "Failed to remove geofence $id", error)
                result.error("REMOVE_FAILED", error.localizedMessage, null)
            }
    }

    private fun handleGetStoredGeofences(result: MethodChannel.Result) {
        val stored = loadStoredGeofences().map {
            mapOf(
                "id" to it.id,
                "lat" to it.latitude,
                "lng" to it.longitude,
                "radiusMeters" to it.radiusMeters.toDouble()
            )
        }

        result.success(stored)
    }

    private fun reRegisterStoredGeofences() {
        val stored = loadStoredGeofences()
        if (stored.isEmpty()) return

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .apply { stored.forEach { addGeofence(it.asGeofence()) } }
            .build()

        geofencingClient.addGeofences(request, pendingIntent)
            .addOnSuccessListener {
                Log.i(TAG, "Re-registered ${stored.size} stored geofences")
            }
            .addOnFailureListener { error ->
                Log.e(TAG, "Failed to re-register stored geofences", error)
            }
    }

    private fun saveGeofence(geofence: StoredGeofence) {
        val geofences = loadStoredGeofences().toMutableList()
        val existingIndex = geofences.indexOfFirst { it.id == geofence.id }
        if (existingIndex >= 0) {
            geofences[existingIndex] = geofence
        } else {
            geofences.add(geofence)
        }

        persistGeofences(geofences)
    }

    private fun removeStoredGeofence(id: String) {
        val geofences = loadStoredGeofences().filterNot { it.id == id }
        persistGeofences(geofences)
    }

    private fun loadStoredGeofences(): List<StoredGeofence> {
        val sharedPrefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val serialized = sharedPrefs.getString(KEY_SAVED_GEOFENCES, "[]") ?: "[]"
        val jsonArray = JSONArray(serialized)
        val geofences = mutableListOf<StoredGeofence>()

        for (i in 0 until jsonArray.length()) {
            val obj = jsonArray.getJSONObject(i)
            geofences.add(
                StoredGeofence(
                    obj.getString("id"),
                    obj.getDouble("lat"),
                    obj.getDouble("lng"),
                    obj.getDouble("radiusMeters").toFloat()
                )
            )
        }

        return geofences
    }

    private fun persistGeofences(geofences: List<StoredGeofence>) {
        val jsonArray = JSONArray()
        geofences.forEach { geofence ->
            jsonArray.put(
                JSONObject().apply {
                    put("id", geofence.id)
                    put("lat", geofence.latitude)
                    put("lng", geofence.longitude)
                    put("radiusMeters", geofence.radiusMeters)
                }
            )
        }

        val sharedPrefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        sharedPrefs.edit().putString(KEY_SAVED_GEOFENCES, jsonArray.toString()).apply()
    }

    private data class StoredGeofence(
        val id: String,
        val latitude: Double,
        val longitude: Double,
        val radiusMeters: Float
    ) {
        fun asGeofence(): Geofence = Geofence.Builder()
            .setRequestId(id)
            .setCircularRegion(latitude, longitude, radiusMeters)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()
    }

    companion object {
        private const val CHANNEL = "com.example.tempo_de_qualidade/geofencing"
        private const val PREFS_NAME = "geofence_prefs"
        private const val KEY_SAVED_GEOFENCES = "saved_geofences"
        private const val TAG = "MainActivity"
    }
}
