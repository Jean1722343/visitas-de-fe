# Visitas de Fe

App Android para iglesias que visitan hospitales: registran a las personas con las que hablan (nombre, teléfono, domicilio, de qué padecen, por quién piden oración) para orar por ellas y darles seguimiento. Sustituye las hojas de papel que se pierden o se llenan mal.

> «Estuve enfermo, y me visitasteis» — Mateo 25:36

## Qué hace

| | |
|---|---|
| **Registrar persona** | Lo único que hace el servidor: nombre completo, edad, teléfono, domicilio, si se ora por la persona o por un familiar internado (nombre y parentesco), padecimiento, área/cuarto/cama, petición, si quiere seguimiento y notas, con hospital y fecha. *Guardar y registrar otra* para capturar rápido; recuerda el último hospital. |
| **Sin internet** | Todo se guarda en el teléfono y se sube solo al volver la señal. Cada registro pendiente muestra una nube tachada y el inicio avisa cuántos faltan. |
| **Listas de oración en PDF** | El administrador saca la lista con todo lo registrado desde la última vez: hoja de resumen (por hospital, por servidor, por estado y por día) y la tabla completa, con el logo de la iglesia. Al **archivarla**, esos registros ya no salen en la siguiente lista ni en la pestaña Registros; las listas anteriores quedan en «Archivadas» para volver a descargarlas (y se puede deshacer). También en Excel. |
| **Hospitales** | Cada iglesia define los hospitales que visita. Solo los administradores los dan de alta. |
| **Oración** | *Oré por esta petición* (queda quién oró) y estados *Por orar → En oración → Respondida* con testimonio. |
| **Tabla de registros** | Búsqueda sin acentos y filtros. Llamar, WhatsApp y mapa desde el registro. |
| **Personalización** | Logo, color (toda la app se pinta de ese color), nombre, ciudad y versículo de cada iglesia; nombre y foto de cada usuario. |
| **Se actualiza sola** | Al abrir la app y cada vez que se vuelve a ella revisa GitHub Releases. Si hay versión nueva la descarga sola (sigue donde se quedó si se corta la señal) y abre el instalador. La primera vez Android pide permitir «instalar apps de esta fuente»; la app lo explica y continúa sola al regresar. |

## Unirse por código

1. Alguien de la iglesia toca **Iglesia → Invitar** y obtiene un código de 6 caracteres (vale 7 días). Lo comparte por WhatsApp; el mensaje incluye el enlace de descarga.
2. La persona instala la app, inicia sesión (Google o correo) y toca **Tengo un código**.

## Cómo está hecha

- **Flutter** (Android) con Riverpod. Misma arquitectura que *Embajadores del Rey*.
- **Firebase, plan gratuito (Spark)**: Auth y Cloud Firestore con caché local ilimitada. No usa Storage ni Cloud Functions: el logo y las fotos de perfil se reducen en el teléfono y se guardan dentro de Firestore.
- Para no gastar lecturas del plan gratuito, la app sincroniza los 300 registros más recientes; *Cargar registros anteriores* trae más.
- Fuentes Bricolage Grotesque y Figtree incluidas en la app.

```
lib/
  core/       tema (color por iglesia), comparación de versiones
  models/     iglesia, miembro, invitación, hospital, registro
  services/   Firebase (repo), estado (proveedores), fotos, Excel, actualizaciones
  features/   pantallas
  widgets/    componentes compartidos y la «línea de vida»
firestore.rules   quién puede leer y escribir cada cosa
android/app/src/main/kotlin/.../MainActivity.kt   abre el instalador del APK descargado
test/             versiones, releases, búsqueda
```

## Ponerla a funcionar

Proyecto de Firebase: `visitas-de-fe-iglesia` (ya creado, con Firestore y reglas publicadas).

1. Authentication ya está activo (correo y Google).
2. Corre o compila:
   ```
   flutter run
   flutter build apk --release
   ```
3. Si cambias las reglas: `firebase deploy --only firestore:rules`.

En otra computadora: `flutterfire configure --project=visitas-de-fe-iglesia --platforms=android` genera `lib/firebase_options.dart` y `google-services.json`, y hay que registrar la SHA-1 de esa llave de firma para entrar con Google.

## Publicar una versión nueva (se instala sola en todos los teléfonos)

```
.\publicar.ps1 1.0.1 "Qué cambió"
```

El script sube la versión en `pubspec.yaml`, corre las pruebas, compila el APK firmado, sube los cambios a GitHub y crea el release `v1.0.1` con el APK. Al abrir la app, cada teléfono lo descarga y abre el instalador (Android siempre pide tocar «Actualizar»).

Repositorio: [Jean1722343/visitas-de-fe](https://github.com/Jean1722343/visitas-de-fe). Descarga directa de la última versión: `https://github.com/Jean1722343/visitas-de-fe/releases/latest`.

### La llave de firma (¡respáldala!)

Android solo instala una actualización si está firmada con la misma llave que la versión instalada. La llave está en `android/app/visitas-de-fe.jks` y su contraseña en `android/key.properties`; ninguno de los dos se sube a GitHub. **Guarda una copia de ambos archivos** (por ejemplo en Google Drive). Si se pierden, los teléfonos tendrían que desinstalar e instalar la app de nuevo.

## Privacidad

Se guardan datos de salud y de contacto de personas vulnerables. El formulario exige confirmar que la persona aceptó que se guardaran sus datos, solo los miembros de la iglesia los ven, y el administrador puede borrar registros. Úsense solo para orar y dar seguimiento pastoral.
