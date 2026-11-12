package com.farmaconsult.farma_auth

import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.util.Consumer
import androidx.window.java.layout.WindowInfoTrackerCallbackAdapter
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import androidx.window.layout.WindowLayoutInfo
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

/**
 * Implementazione Android dei canali del pacchetto `foldable` (che registra
 * il plugin solo su iOS): stesso protocollo e stesso formato, così
 * FoldableProvider / FoldAwareBuilder funzionano senza toccare il Dart.
 *
 * - Postura e posizione della piega: Jetpack WindowManager (FoldingFeature),
 *   presente solo quando la finestra sta sullo schermo interno.
 * - Chiuso / aperto: sensore angolo cerniera (API 30+), che c'è anche quando
 *   l'app è sullo schermo esterno e la FoldingFeature non viene riportata.
 */
class FoldableBridge(private val activity: Activity, messenger: BinaryMessenger) : SensorEventListener {

    companion object {
        private const val TAG = "FarmaFold"
        private const val METHODS = "foldable/methods"
        private const val EVENTS = "foldable/events"

        // Soglie in gradi per dedurre lo stato dall'angolo quando la piega non
        // è riportata da WindowManager. Da verificare sul dispositivo (Logcat).
        private const val CLOSED_BELOW = 30f
        private const val FULLY_OPEN_FROM = 150f
    }

    private val sensorManager = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val hingeSensor: Sensor? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) sensorManager.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE) else null
    private val windowTracker = WindowInfoTrackerCallbackAdapter(WindowInfoTracker.getOrCreate(activity))
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mainExecutor = Executor { mainHandler.post(it) }
    private val layoutListener = Consumer<WindowLayoutInfo> { onLayoutChanged(it) }

    private var angle: Float? = null
    private var folding: FoldingFeature? = null
    private var sink: EventChannel.EventSink? = null
    private var started = false

    init {
        MethodChannel(messenger, METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSnapshot" -> result.success(snapshot())
                "debugDumpNativeApi" -> result.success(mapOf("hingeSensor" to (hingeSensor?.name ?: "none"), "folding" to folding?.toString()))
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, EVENTS).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
                events?.success(snapshot())
            }

            override fun onCancel(arguments: Any?) {
                sink = null
            }
        })
        Log.d(TAG, "hinge sensor: ${hingeSensor?.name ?: "assente"}")
    }

    /** Da chiamare in onStart dell'activity. */
    fun start() {
        if (started) return
        started = true
        windowTracker.addWindowLayoutInfoListener(activity, mainExecutor, layoutListener)
        hingeSensor?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
    }

    /** Da chiamare in onStop dell'activity. */
    fun stop() {
        if (!started) return
        started = false
        windowTracker.removeWindowLayoutInfoListener(layoutListener)
        sensorManager.unregisterListener(this)
    }

    private fun onLayoutChanged(info: WindowLayoutInfo) {
        folding = info.displayFeatures.filterIsInstance<FoldingFeature>().firstOrNull()
        Log.d(TAG, "layout: folding=$folding")
        emit()
    }

    override fun onSensorChanged(event: SensorEvent) {
        val next = event.values.firstOrNull() ?: return
        // Il sensore manda molti valori ravvicinati: si emette solo quando
        // cambia lo stato o l'angolo di almeno un grado.
        val previousStatus = status()
        val previousAngle = angle
        angle = next
        if (previousAngle != null && status() == previousStatus && kotlin.math.abs(next - previousAngle) < 1f) return
        Log.d(TAG, "angolo cerniera: $next -> ${status()}")
        emit()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun emit() {
        sink?.success(snapshot())
    }

    private fun isFoldable(): Boolean = hingeSensor != null || folding != null

    private fun status(): String {
        // La postura di WindowManager vince: c'è solo con la finestra sulla piega.
        folding?.let { return if (it.state == FoldingFeature.State.HALF_OPENED) "partiallyOpen" else "fullyOpen" }
        val a = angle ?: return "unknown"
        return when {
            a < CLOSED_BELOW -> "closed"
            a < FULLY_OPEN_FROM -> "partiallyOpen"
            else -> "fullyOpen"
        }
    }

    private fun supportLevel(): String = when {
        isFoldable() && angle == null && folding == null -> "unknown"
        isFoldable() -> "available"
        else -> "unsupported"
    }

    private fun regions(): List<Map<String, Any>> {
        val feature = folding ?: return emptyList()
        // FoldingFeature è in pixel fisici della finestra, Flutter in pixel logici.
        val density = activity.resources.displayMetrics.density
        val b = feature.bounds
        return listOf(mapOf("kind" to "division", "left" to b.left / density, "top" to b.top / density, "width" to b.width() / density, "height" to b.height() / density, "active" to true))
    }

    // Su Android non ci sono size class: il layout decide con la larghezza.
    private fun snapshot(): Map<String, Any?> = mapOf("wireVersion" to 1, "supportLevel" to supportLevel(), "isFoldable" to isFoldable(), "hingeApiPresent" to (hingeSensor != null), "regionApiPresent" to true,
        "angleUnitVerified" to (hingeSensor != null), "strategy" to (if (hingeSensor != null) "hingeSensor" else "windowManager"), "status" to status(), "angleDegrees" to angle?.toDouble(), "regions" to regions(),
        "horizontalSizeClass" to "unspecified", "verticalSizeClass" to "unspecified")
}
