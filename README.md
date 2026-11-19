# Localizador de Puntos de Interés

Aplicación móvil en **Flutter** que muestra un mapa de Google, obtiene tu ubicación en tiempo real, permite marcar puntos tocando el mapa, mide la distancia entre dos puntos y muestra la dirección de cada uno mediante geocodificación inversa.

Práctica de la **Semana 10: Geolocalización y Mapas en Flutter**, materia Desarrollo Móvil Integral, IDGS 10°, Universidad Tecnológica de Xicotepec de Juárez (UTXJ).

## Funcionalidades

- **Ubicación en tiempo real:** muestra latitud y longitud actualizadas con el GPS (solo se actualiza cada 10 metros para ahorrar batería).
- **Mapa interactivo:** `GoogleMap` centrado en tu ubicación al iniciar.
- **Marcadores interactivos:** cada toque en el mapa crea un punto nuevo. Al tocar un marcador se elige como destino.
- **Distancia entre dos puntos:** se elige un origen (tu ubicación o cualquier punto) y un destino, y se calcula con `Geolocator.distanceBetween`. Se dibuja una línea entre ambos.
- **Dirección por geocodificación inversa:** muestra calle y colonia de cada punto cuando están disponibles.

## Tecnologías

| Herramienta | Versión |
|---|---|
| Flutter | 3.47.8 (stable) |
| Dart | 3.13.7 |
| `google_maps_flutter` | ^2.19.0 |
| `geolocator` | ^14.1.2 |
| `geocoding` | ^5.0.1 |

> Con `geocoding` 5.x la geocodificación inversa se hace desde una instancia: `Geocoding().placemarkFromCoordinates(...)`.

## Estructura del proyecto

```
lib/
├── main.dart                     # Punto de entrada y tema de la app
├── screens/
│   └── mapa_screen.dart          # Pantalla del mapa, marcadores, distancia y direcciones
└── services/
    └── location_service.dart     # Permisos y lectura de la ubicación
```

## Requisitos

- Flutter instalado y configurado (`flutter doctor` con Flutter y Android toolchain en verde).
- Un dispositivo Android (se recomienda un celular físico con GPS activo) o un emulador con Google Play Services.
- Una **API Key de Google Maps** propia (ver la siguiente sección). La llave de la autora **no** está en este repositorio.

## Cómo ejecutarlo

**1. Clona el repositorio y entra a la rama de la práctica**

```bash
git clone https://github.com/Esther-Gonzalez04/maps_geolocation.git
cd maps_geolocation
git checkout feature/maps-geolocation
```

**2. Instala las dependencias**

```bash
flutter pub get
```

**3. Agrega tu API Key**

Abre (o crea) el archivo `android/local.properties` y agrega esta línea, sin comillas ni espacios:

```properties
maps.apikey=TU_API_KEY_AQUI
```

Este archivo está en `.gitignore`, así que **no se sube a Git**.

**4. Ejecuta la app**

```bash
flutter devices
flutter run -d ID_DE_TU_DISPOSITIVO
```

Si cambias la llave, cierra la app y vuelve a compilar (el hot reload no basta).

## Configuración de la API Key de Google Maps

1. En [Google Cloud Console](https://console.cloud.google.com) crea un proyecto con la facturación habilitada.
2. Habilita **Maps SDK for Android** y **Geocoding API**.
3. Crea una API Key y **restríngela**:
   - **Restricción de aplicación:** Apps para Android, con el nombre de paquete `com.utxj.maps_geolocation` y la huella **SHA-1** de tu certificado.
   - **Restricción de API:** solo Maps SDK for Android y Geocoding API.

Para obtener la SHA-1 del certificado de depuración de tu equipo:

```bash
# Windows (PowerShell)
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# macOS / Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Copia la línea que empieza con `SHA1:`. Esa huella depende del equipo donde se compila la app: quien ejecute el proyecto desde otra computadora debe registrar su propia SHA-1.

## Seguridad de la API Key

La llave nunca se escribe en el código. El flujo es:

1. La llave vive en `android/local.properties` (archivo ignorado por Git).
2. `android/app/build.gradle.kts` lee `maps.apikey` y crea el `manifestPlaceholders["MAPS_API_KEY"]`.
3. `AndroidManifest.xml` usa `${MAPS_API_KEY}` en la etiqueta `com.google.android.geo.API_KEY`.

Si `local.properties` no tiene la llave, la app usa el valor `PENDIENTE` y el mapa no se mostrará.

## Permisos de Android

- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `INTERNET`

La app solicita el permiso de ubicación en el primer uso. Si el GPS está apagado o el permiso se niega, muestra un mensaje en pantalla.

## Estado

- Probada en un celular Android físico (Android 16).
- La configuración de la API Key está hecha solo para **Android**; iOS no está configurado.


## Autora

**Esther González Peralta**, IDGS, UTXJ.
