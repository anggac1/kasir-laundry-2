package id.laundry.laundry_pos

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Satu-satunya kode Android buatan sendiri di proyek ini.
//
// Gunanya membuka layar Setelan Bluetooth langsung dari aplikasi, supaya
// pengguna tidak perlu keluar dan mencari menunya sendiri. Flutter tidak
// bisa melakukan ini tanpa bantuan sisi Android.
class MainActivity : FlutterActivity() {
    private val saluran = "kasir_laundry/setelan"

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        MethodChannel(engine.dartExecutor.binaryMessenger, saluran)
            .setMethodCallHandler { panggilan, hasil ->
                when (panggilan.method) {
                    "bukaSetelanBluetooth" -> {
                        try {
                            val niat = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                            niat.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(niat)
                            hasil.success(true)
                        } catch (e: Exception) {
                            // Sebagian HP menyembunyikan layar itu. Dicoba
                            // Setelan umum sebagai gantinya.
                            try {
                                val cadangan = Intent(Settings.ACTION_SETTINGS)
                                cadangan.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(cadangan)
                                hasil.success(true)
                            } catch (e2: Exception) {
                                hasil.error("GAGAL", e2.message, null)
                            }
                        }
                    }
                    else -> hasil.notImplemented()
                }
            }
    }
}
