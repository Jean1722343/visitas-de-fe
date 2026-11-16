package com.visitasdefe.visitas_de_fe

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Abre el instalador de Android con el APK que descargó la app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "visitasdefe/instalador")
            .setMethodCallHandler { llamada, resultado ->
                if (llamada.method == "puedeInstalar") {
                    resultado.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls(),
                    )
                    return@setMethodCallHandler
                }
                if (llamada.method == "abrirPermiso") {
                    // Pantalla de Ajustes: "instalar apps desconocidas" de esta app.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    }
                    resultado.success(null)
                    return@setMethodCallHandler
                }
                if (llamada.method != "instalar") {
                    resultado.notImplemented()
                    return@setMethodCallHandler
                }
                val ruta = llamada.argument<String>("ruta")
                if (ruta == null) {
                    resultado.error("sin_ruta", "Falta el archivo", null)
                    return@setMethodCallHandler
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        // La app explica primero; "abrirPermiso" abre Ajustes.
                        resultado.success("sin_permiso")
                        return@setMethodCallHandler
                    }
                    val uri = FileProvider.getUriForFile(
                        this,
                        "$packageName.instalador",
                        File(ruta),
                    )
                    val intento = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intento)
                    resultado.success("ok")
                } catch (e: Exception) {
                    resultado.error("fallo", e.message, null)
                }
            }
    }
}
