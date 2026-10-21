# Recupera tu voz — Checklist de prioridades y análisis de arquitectura

_Fecha: 29 julio 2026_

## 1. Checklist de prioridades

> **Contexto actualizado**: el desarrollo se centra en Android. El ngrok es un túnel temporal hacia un servidor propio (comprado con presupuesto de Dualiza) que ya aloja los audios clonados y una base de datos Postgres — no es un backend de pruebas desechable. Esto reordena las prioridades por debajo: se retira el bloqueante de iOS y el foco del punto de "backend" pasa de "no hay infraestructura real" a "exponer el servidor ya existente sin depender de ngrok".

### 🔴 Crítico (bloquea producción / riesgo real)

- [ ] **Dejar de depender del túnel ngrok para llegar al servidor propio** (`api_service.dart:9`, `kServerUrl`). Ya tenéis servidor con Postgres: apuntad `kServerUrl` directamente a su IP/dominio con HTTPS (Let's Encrypt es gratis) en vez de pasar por ngrok. Motivos: las URLs de ngrok gratuito rotan/caducan (cualquier reinicio del túnel rompe la app instalada sin nueva build), añade un intermediario de terceros a datos biométricos de voz, y agrega latencia extra a un flujo (síntesis de voz) que ya es lento. Sacar además la URL a configuración por entorno (`--dart-define` o flavors) en vez de constante hardcodeada repetida en 6 archivos.
- [ ] **Timeout de 90s en la síntesis con voz clonada** (`VoiceApiService.synthesize`, `api_service.dart:220`). Para una app AAC, 90 segundos de espera para poder "hablar" es inutilizable, especialmente en frases de urgencia ("necesito ayuda para llegar al hospital"). Ver sección de arquitectura.
- [ ] **Release de Android firmado con la keystore de debug** (`android/app/build.gradle.kts`). Generar una keystore de release real; sin esto no se puede publicar en Play Store ni actualizar la app de forma segura.
- [ ] **`applicationId`/`namespace` siguen en `com.example.recupera_tu_voz`**. Play Store rechaza este paquete. Cambiar antes de cualquier build de distribución (aunque sea beta cerrada).
- [ ] **Sin gestión de token caducado/401**: ninguna pantalla detecta un token expirado de forma centralizada; cada una falla por su cuenta. Un paciente puede quedarse sin voz funcional sin saber por qué.
- [ ] **Backup y cifrado en reposo de Postgres**: confirmar que el servidor propio tiene backups automáticos y que los audios de referencia (dato biométrico) están cifrados en disco, no solo protegidos por el acceso a la API. Es la única copia de la voz del paciente — perderla no es recuperable.

### 🟠 Alto

- [ ] Eliminar `lib.zip`, `voz.zip`, `ss` del repositorio (basura/backups accidentales) y añadir `*.zip` a `.gitignore`.
- [ ] `_FrasesScreenState` no libera `TtsService` en `dispose()` → fuga de `AudioPlayer` nativo cada vez que se reconstruye el árbol (logout/login).
- [ ] Consolidar las 4 implementaciones paralelas de llamadas HTTP fuera de `services/` (`trabajo_screen.dart`, `lip_screen.dart`, `logopeda_fichas_screen.dart`, `logopeda_resumen_screen.dart`) en servicios dedicados.
- [ ] Añadir tests reales mínimos: hoy solo existe el test de plantilla (`test/widget_test.dart`, contador que ya no existe en la app). Priorizar tests de `VoiceApiService`, `TtsService` y parsing de modelos — es la parte más crítica funcionalmente.
- [ ] Revisar consentimiento/RGPD explícito antes de subir audio de voz del paciente (dato biométrico/de salud) — no se ha encontrado pantalla de consentimiento en el flujo de clonación. Al tratarse de datos de salud alojados en vuestro propio servidor (no un tercero cloud con certificaciones), esto pesa más, no menos.

### 🟡 Media

- [ ] Unificar la caché duplicada de "frases por defecto" (`settings_service.dart` y `api_service.dart`, mismas claves, misma lógica de TTL 24h implementada dos veces).
- [ ] Consolidar los 3 widgets de "botón grande" casi idénticos (`_PrimaryButton`, `_BigButton`, `PrimaryButton`) en uno solo reutilizable en `shared_widgets.dart`.
- [ ] Homogeneizar el manejo de errores mostrado al usuario (patrón `_parseError` de `login_screen.dart` debería aplicarse también en `register_screen.dart` y demás pantallas).
- [ ] Migrar el parsing JSON manual (casts `as`) a `json_serializable`/`freezed` para evitar `TypeError` en tiempo de ejecución ante cambios de contrato del backend/Postgres.
- [ ] Quitar el `print()` de `login_screen.dart:118`; revisar los `catch (_) {}` silenciosos.
- [ ] Dividir `trabajo_screen.dart` (860 líneas, 4 responsabilidades) y `logopeda_fichas_screen.dart` (>1000 líneas) en varios archivos.

### 🟢 Baja / mejora continua

- [ ] Sustituir los temporizadores manuales por recursión (`Future.delayed` en bucle) por `Timer.periodic` en `record_voice_screen.dart` y `lip_screen.dart`.
- [ ] Evaluar `go_router`/rutas nombradas en vez de navegación por banderas booleanas (`_showRegister`, `_showRecorder`, `_showCloneVoice`).
- [ ] Introducir gestión de estado (Riverpod/Provider) para evitar prop drilling multinivel del `AppUser`/`AppSettings`.

### ⏸️ Pospuesto (no bloquea, retomar si se libera build para iOS)

- [ ] Permisos de cámara/micrófono ausentes en `ios/Runner/Info.plist` (`NSCameraUsageDescription`, `NSMicrophoneUsageDescription`). No urge mientras el desarrollo sea Android-first, pero cualquier intento de build iOS fallará hasta corregirlo.

---

## 2. Arquitectura actual — resumen

```
AppRoot (sesión: AppUser, AppSettings)
  └─ AppRouter (decide rol/onboarding)
       ├─ AppShell (paciente, 6 tabs)
       │    ├─ HomeScreen
       │    ├─ TextScreen ──────┐
       │    ├─ FrasesScreen ────┼──> TtsService ──> VoiceApiService.synthesize ──> backend (ngrok)
       │    ├─ TrabajoScreen ───┘         │                                              │
       │    ├─ LipScreen                  └─ fallback: flutter_tts (motor del sistema)   │
       │    └─ ProfileScreen ──> CloneVoiceScreen ──> RecordVoiceScreen                   │
       │                              └─ VoiceApiService.uploadReplaceAudios/Add ─────────┘
       └─ LogopedaShell (logopeda, 5 tabs) ── RolesService (independiente de VoiceApiService)
```

Sin gestión de estado global: `AppUser`/`AppSettings` viajan por constructor en cascada. Cada pantalla instancia sus propios servicios (`VoiceApiService()`, `TtsService()`) sin inyección de dependencias.

## 3. Arquitectura del flujo de clonación de voz (foco principal)

Es el corazón funcional de la app, así que merece atención aparte.

**Flujo actual:**
1. `RecordVoiceScreen` graba WAV local (22050Hz, mono) con `record`, guiado por frases de texto fijo, mínimo 10s / máximo 120s por muestra, hasta 3 muestras.
2. `CloneVoiceScreen` sube los bytes con `VoiceApiService.uploadReplaceAudios` (reemplaza todo, primero hace `deleteVoice` y luego re-sube) o `uploadAddAudios` (añade una a una, secuencial, no en paralelo).
3. Backend entrena/registra la voz (proceso no visible desde el cliente — caja negra).
4. Para hablar, `TtsService.speak()` llama a `VoiceApiService.synthesize`, que hace un POST síncrono con timeout de 90s, espera el WAV completo, y solo entonces empieza a reproducirlo con `just_audio`.

**Problemas de diseño específicos a este flujo:**

- **Latencia end-to-end inaceptable para AAC**: la app está pensada para que alguien sin voz "hable" en tiempo real (incluso frases de emergencia: "necesito ayuda para llegar al hospital"). Un timeout de 90s implica que, en el peor caso, el usuario espera minuto y medio para oír una frase. No hay streaming ni feedback de progreso ("generando audio…") visible en `tts_service.dart`; la UI se queda bloqueada por `_isSpeaking` sin indicar cuánto falta.
  - **Mejora**: si el backend puede exponerlo, migrar a streaming (chunks de audio reproducidos según llegan, no esperar el WAV completo) o WebSocket. Como mínimo, mostrar un indicador de progreso/tiempo estimado en la UI mientras se sintetiza.

- **Sin caché de audio sintetizado**: cada vez que se reproduce la misma frase rápida (las de `FrasesScreen`, que son fijas y repetidas — "sí", "no", "tengo hambre", etc.) se vuelve a llamar al backend y a esperar la síntesis completa desde cero. Para un paciente que usa las mismas 20-30 frases el 90% del tiempo, esto es una oportunidad enorme de mejora.
  - **Mejora**: pre-generar y cachear localmente (o en el backend, servido como estático) el audio con voz clonada de las frases más usadas, invalidando la caché solo cuando el usuario cambia/regraba su voz. Reduciría la latencia de "instantáneo tras el primer uso" a "instantáneo siempre".

- **Sin manejo de offline/mala conectividad**: si no hay red, `synthesize` falla y el único fallback es el TTS del sistema con la voz genérica (no la del paciente) — funcionalmente correcto pero deja al usuario sin su voz real justo cuando más la necesita (fuera de casa, en el hospital, con wifi débil). No hay cola de reintentos ni modo degradado explícito comunicado en la UI.
  - **Mejora**: detectar conectividad de forma proactiva y comunicar claramente "usando voz del sistema temporalmente" en vez de fallar en silencio caso por caso.

- **Subida de referencias de voz sin resiliencia**: `uploadAddAudios` sube los ficheros uno a uno de forma secuencial y síncrona (`for` con `await` dentro); si falla el segundo de tres, no hay reintento automático ni cola persistente — el usuario tiene que volver a intentarlo manualmente y podría perder tiempo de grabación ya hecho. Dado que estas grabaciones son la entrada del modelo de voz (dato más valioso de la app), merece más robustez que una subida "best effort".
  - **Mejora**: cola de subida persistente (guardar localmente el WAV hasta confirmar upload exitoso), reintentos con backoff, subida en paralelo donde el backend lo permita.

- **Acoplamiento directo pantalla↔servicio sin capa de dominio**: `CloneVoiceScreen`, `RecordVoiceScreen` y `TtsService` llaman todos directamente a `VoiceApiService`, duplicando lógica de manejo de error y sin punto único que gestione el "estado de la voz" (`hasVoice`, `numRefs`) de forma reactiva. Hoy ese estado se recalcula y se pasa a mano entre `ProfileScreen`, `CloneVoiceScreen`, `HomeScreen` y `TextScreen`.
  - **Mejora**: introducir un `VoiceRepository` (o `VoiceController` con Riverpod/ChangeNotifier) que encapsule caché, reintentos, y estado reactivo de la voz clonada, consumido por todas las pantallas relevantes sin prop drilling.

- **Caja negra del proceso de clonación**: el cliente no sabe si el backend está "entrenando" la voz tras subir audios, ni cuánto tarda, ni si puede fallar de forma asíncrona (p. ej., audio de mala calidad rechazado después de subido). `checkVoiceStatusFull` solo informa `has_voice`/`num_references`, no un estado intermedio tipo `processing`.
  - **Mejora**: si el backend soporta un estado de "procesando/entrenando", reflejarlo en la UI en vez de asumir que subida = voz lista al instante.

- **Dato biométrico sin cifrado adicional en tránsito/reposo más allá de HTTPS**: los audios de voz (y los vídeos faciales de `lip_screen.dart`) son datos de salud/biométricos sensibles, y al estar alojados en un servidor propio (no en un proveedor cloud con certificaciones tipo AWS/GCP), la responsabilidad de cifrado, backups y control de acceso recae enteramente en vosotros. No se ha visto ninguna medida adicional desde el cliente (cifrado en el propio payload, políticas de retención, borrado confirmado en cascada al eliminar cuenta).
  - **Mejora**: en el servidor, cifrar en reposo la tabla/columna de Postgres o el volumen donde se guardan los audios, tener backups automáticos verificados, y definir una política de retención/borrado (RGPD, dato de categoría especial de salud). Desde el cliente, asegurar que "eliminar voz" (`VoiceApiService.deleteVoice`) borra también el fichero físico en el servidor y no solo la referencia en Postgres.

- **Servidor propio expuesto vía ngrok en vez de directamente**: al tener ya un servidor comprado con Postgres, pasar por un túnel ngrok gratuito añade un salto de red innecesario (latencia extra en un flujo ya lento) y un punto de fallo de un tercero fuera de vuestro control, sin aportar nada a cambio ahora que no es un backend de pruebas.
  - **Mejora**: exponer el servidor directamente con IP/dominio propio + HTTPS (Let's Encrypt) y firewall restringido a los puertos necesarios; reservar ngrok como mucho para depuración puntual en desarrollo local.

## 4. Resumen de recomendaciones de arquitectura (orden sugerido)

1. Resolver los bloqueantes de producción (iOS, firma Android, backend estable) — sin esto no tiene sentido optimizar lo demás.
2. Introducir un `VoiceRepository`/controlador de estado único para la voz clonada, eliminando la duplicación actual entre pantallas.
3. Cachear localmente el audio sintetizado de las frases más usadas — mayor impacto en UX real percibido por el paciente.
4. Añadir resiliencia (reintentos, cola persistente) a la subida de muestras de voz.
5. Evaluar streaming de síntesis o al menos feedback de progreso visible durante la espera.
6. Centralizar las llamadas HTTP en `services/` y homogeneizar manejo de errores/estado de sesión (401).
7. Consolidar duplicaciones menores de UI (botones) y de caché de frases.
