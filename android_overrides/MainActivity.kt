package id.laundry.laundry_pos

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Satu-satunya kode Android buatan sendiri di proyek ini.
//
// Gunanya dua: membuka layar Setelan Bluetooth, dan membuka tautan di
// peramban. Keduanya tidak bisa dilakukan Flutter tanpa bantuan sisi
// Android.
//
// Membuka tautan di sini TIDAK membutuhkan izin INTERNET. Aplikasi hanya
// menyerahkan alamatnya ke Android, lalu peramban yang mengunduhnya
// dengan izinnya sendiri. Aplikasi ini tetap tidak bisa berkirim data.
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
                    "bukaTautan" -> {
                        val alamat = panggilan.argument<String>("alamat")
                        if (alamat.isNullOrBlank()) {
                            hasil.error("KOSONG", "Alamat tidak diisi", null)
                        } else {
                            try {
                                val niat = Intent(Intent.ACTION_VIEW, Uri.parse(alamat))
                                niat.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(niat)
                                hasil.success(true)
                            } catch (e: Exception) {
                                // Tidak ada peramban terpasang, atau
                                // alamatnya ditolak sistem.
                                hasil.error("GAGAL", e.message, null)
                            }
                        }
                    }
                    else -> hasil.notImplemented()
                }
            }
    }
}
