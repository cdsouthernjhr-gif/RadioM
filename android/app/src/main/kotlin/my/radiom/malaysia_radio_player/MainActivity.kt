package my.radiom.malaysia_radio_player

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManagerFactory

/**
 * AudioServiceActivity keeps the FlutterEngine shared with the background
 * audio service so playback continues when the user switches apps.
 */
class MainActivity : AudioServiceActivity() {
    private val channelName = "my.radiom/platform"
    private val notificationRequestCode = 4201
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        installExtraTrustAnchorsIfNeeded()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTv" -> result.success(isTelevision())
                "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                "requestNotificationPermission" -> requestNotificationPermission(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun isTelevision(): Boolean {
        val uiMode = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        if (uiMode?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) return true
        val pm = packageManager
        // FEATURE_LEANBACK exists since API 21; many cheap TV boxes report no touchscreen.
        return pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            !pm.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
    }

    /** POST_NOTIFICATIONS is a runtime permission only on Android 13 (API 33)+. */
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33) {
            result.success(true)
            return
        }
        val permission = "android.permission.POST_NOTIFICATIONS"
        if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        requestPermissions(arrayOf(permission), notificationRequestCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationRequestCode) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    /**
     * Android 6.0 / 7.0 (API 23-24) do not include the ISRG Root X1/X2
     * certificates used by Let's Encrypt, so HTTPS streams served with those
     * certificates fail in ExoPlayer (HttpURLConnection). Instead of disabling
     * validation, we build a trust store = system CAs + the two official ISRG
     * roots (res/raw) and install it as the default for HttpsURLConnection.
     * Hostname verification and chain validation remain fully enabled.
     * Android 7.1.1+ (API 25+) already trusts ISRG, so nothing is changed there.
     */
    private fun installExtraTrustAnchorsIfNeeded() {
        if (Build.VERSION.SDK_INT >= 25) return
        try {
            val trustStore = KeyStore.getInstance(KeyStore.getDefaultType())
            trustStore.load(null, null)
            val system = KeyStore.getInstance("AndroidCAStore")
            system.load(null, null)
            for (alias in system.aliases()) {
                trustStore.setCertificateEntry(alias, system.getCertificate(alias))
            }
            val cf = CertificateFactory.getInstance("X.509")
            for ((name, res) in listOf("isrg_root_x1" to R.raw.isrg_root_x1, "isrg_root_x2" to R.raw.isrg_root_x2)) {
                resources.openRawResource(res).use { input ->
                    val cert = cf.generateCertificate(input) as X509Certificate
                    trustStore.setCertificateEntry("extra-$name", cert)
                }
            }
            val tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm())
            tmf.init(trustStore)
            val ctx = SSLContext.getInstance("TLS")
            ctx.init(null, tmf.trustManagers, null)
            HttpsURLConnection.setDefaultSSLSocketFactory(ctx.socketFactory)
        } catch (e: Exception) {
            Log.w("MalaysiaRadio", "Could not install extra trust anchors", e)
        }
    }
}
