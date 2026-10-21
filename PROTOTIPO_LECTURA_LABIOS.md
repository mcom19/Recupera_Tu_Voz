# Prototipo — encuadre + captura para lectura de labios

Añade encuadre facial en tiempo real (Google ML Kit) a la captura de vídeo
para lectura de labios, sin tocar `lip_screen.dart` ni la navegación
existente. Pensado para poder probarse hoy y sustituir a `lip_screen.dart`
el día que el backend tenga listo `/lipreading/speak`.

## Archivos que se añaden

| Archivo | Qué hace |
|---|---|
| `lib/services/face_framing_service.dart` | Envuelve `google_mlkit_face_detection`: convierte cada frame de la cámara, detecta la cara y devuelve un veredicto de encuadre (`sinRostro` / `muyLejos` / `muyCerca` / `descentrada` / `buena`) calculado sobre el rectángulo de los labios. |
| `lib/widgets/mouth_frame_overlay.dart` | El óvalo-guía sobre el `CameraPreview`, coloreado según el veredicto de arriba. |
| `lib/screens/lip_capture_prototype_screen.dart` | La pantalla del prototipo: cámara + encuadre en vivo + grabación (igual patrón que `lip_screen.dart`) + llamada a `/lipreading/speak` con **fallback automático a modo demo local** si el backend aún no responde. |
| `lib/main_lip_prototype.dart` | Punto de entrada aislado para lanzar solo esta pantalla sin pasar por el login/router de la app real. |

Ningún archivo existente se modifica. Solo hace falta añadir dos
dependencias a `pubspec.yaml`.

## 1. Añadir dependencias

```bash
cd Recupera_Tu_Voz
flutter pub add google_mlkit_face_detection google_mlkit_commons
```

Esto añade algo como esto a `pubspec.yaml` (las versiones exactas las
resuelve `pub`; no las fijes a mano):

```yaml
dependencies:
  google_mlkit_face_detection: ^0.13.1
  google_mlkit_commons: ^0.11.0
```

Requisitos nativos mínimos de ML Kit (habituales, revisar si el
proyecto ya los cumple):
- Android: `minSdkVersion 21` en `android/app/build.gradle.kts`.
- iOS: `platform :ios, '13.0'` en `ios/Podfile`, y (pendiente ya en el
  checklist de arquitectura) añadir `NSCameraUsageDescription` /
  `NSMicrophoneUsageDescription` en `Info.plist`.

## 2. Probar el prototipo de forma aislada

```bash
flutter run -t lib/main_lip_prototype.dart
```

Se abre directamente la pantalla de captura, sin login. Como no hay
`AppUser`, el intento de subida a `/lipreading/speak` fallará y caerá
solo en **modo demo**: graba, guarda el vídeo en un directorio temporal
del dispositivo y muestra la ruta en pantalla — sirve para validar el
encuadre y la UX de grabación sin depender del backend.

También puede forzarse el modo demo manualmente con el icono de nube
tachada en la barra superior (útil para probar la UX sin red aunque el
backend sí exista, o al revés).

## 3. Integrarlo en la app final (cuando el backend tenga `/lipreading/speak`)

En `lib/screens/app_router.dart`, donde hoy se instancia `LipScreen`,
sustituir (o añadir como alternativa detrás de un flag mientras se
compara) por:

```dart
LipCapturePrototypeScreen(user: appUser)
```

Mismo constructor `{AppUser? user}`, mismo contrato de red
(`POST $kServerUrl/lipreading/speak`, multipart con campo `video`,
respuesta con audio en el body y texto en la cabecera
`x-recognized-text`) que ya usa `lip_screen.dart` — la integración es
un cambio de una línea en el router, no una reescritura.

## 4. Qué NO hace (todavía) este prototipo

- **No recorta el vídeo a la región de la boca.** Solo usa la detección
  facial para dar *feedback* de encuadre en pantalla; sigue enviando el
  fotograma completo, igual que `lip_screen.dart`. Recortar de verdad
  antes de subir (ahorra ancho de banda y estandariza la entrada del
  modelo VSR) requeriría procesar el vídeo grabado con algo como
  `ffmpeg_kit_flutter` o hacerlo en el propio backend — se ha dejado
  fuera para no acoplar este prototipo a una librería de vídeo nueva.
- **Los umbrales de "bien encuadrado" son heurísticos de partida**
  (`_minMouthWidthRatio`, `_maxMouthWidthRatio`,
  `_maxCenterOffsetRatio` en `face_framing_service.dart`) — hay que
  calibrarlos probando en el móvil real de destino, no están medidos.
- **No exige encuadre estable antes de dejar grabar.** El botón de
  grabar siempre está activo; el color del óvalo es solo una guía. Si
  se quiere impedir grabar hasta llevar, por ejemplo, 500ms seguidos en
  verde, es un añadido pequeño sobre `_framingState` en
  `lip_capture_prototype_screen.dart`.
- **No implementa vocabulario cerrado** (la recomendación de mayor
  impacto del informe de modelos VSR) — esta pantalla es solo la
  captura; la clasificación/reconocimiento sigue viviendo en el
  backend, sea cual sea el modelo VSR que se elija allí.
