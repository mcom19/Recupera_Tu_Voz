# Revisión Flutter — clonación de voz y trabajo con el logopeda

Alcance: los dos flujos que se quieren "cerrar" antes de pasar a lipreading. Lectura de `lib/` completa para ambos módulos (voz: `clone_voice_screen.dart`, `record_voice_screen.dart`, `text_screen.dart`, `tts_service.dart`, `api_service.dart`; logopeda: `roles_service.dart`, `trabajo_screen.dart`, `panel/logopeda_*.dart`, `onboarding/*`).

## Veredicto general

Ambos flujos están completos y bien conectados de extremo a extremo:

- **Clonación de voz**: grabar o subir hasta 3 audios de referencia, añadir/reemplazar/eliminar, indicador de progreso (X/3 muestras), síntesis vía `/voice/tts` y opción de compartir el audio generado. `main.dart` sincroniza el estado (`has_voice`, `num_references`) al arrancar la app.
- **Trabajo con el logopeda**: vinculación paciente↔logopeda por código (`roles_service.dart`), el logopeda crea fichas de palabras y las asigna individualmente o por nivel (`logopeda_fichas_screen.dart`), el paciente las ve en "Mi trabajo" (`trabajo_screen.dart`), practica grabando cada palabra, recibe una puntuación (`whisper_score`) por intento y al terminar la ficha se marca completada con su mejor score. Bien encadenado con sesiones de ejercicio (`/exercises/sesiones`).

No hay huecos estructurales: cada pantalla tiene su service, cada acción de UI llama al endpoint correcto y el estado se propaga bien entre pantallas (`copyWith` con centinela para nulos en `AppUser`, por ejemplo, está bien resuelto).

## Hallazgo principal: aquí está el bug de conexión que viste en la captura

`api_service.dart` línea 9:

```dart
const String kServerUrl = 'https://mirian-eriophyllous-serriedly.ngrok-free.dev';
```

Es una URL fija de un túnel ngrok, no vuestro dominio. Y el mensaje exacto de la pantalla que capturaste ("No se pudo conectar con el servidor" + botón "Reintentar") sale literalmente de `app_router.dart`, en el catch de `_fetchRole()` cuando falla `GET $kServerUrl/roles/me`:

```dart
} catch (e) {
  setState(() { _loading = false; _error = 'Sin conexión al servidor'; });
}
```

**Confirmado y con causa exacta.** El proceso ngrok sí está vivo en el servidor (`ps aux` lo muestra corriendo desde el 12 de junio, reenviando el puerto 8880). El problema no es que el túnel esté caído: es que **ngrok gratis muestra una página de aviso intermedia ("interstitial") a cualquier petición que llegue con cabeceras de navegador**, en vez de pasar la petición directamente a vuestra API. Lo he comprobado pidiendo la URL:

```
GET https://mirian-eriophyllous-serriedly.ngrok-free.dev/
Content-Type: text/html
<meta name="description" content="ngrok is the fastest way to put anything on the internet...">
```

En vez de la respuesta JSON de FastAPI (`{"status": "online", ...}`), devuelve el HTML de aviso de ngrok. La app Flutter Web (Chrome, que es donde saliste con `localhost:56522`) hace sus peticiones `http` como fetch de navegador, así que le llega ese HTML en vez de JSON, `jsonDecode` falla, y eso es lo que se captura como "Sin conexión al servidor". En apps nativas (Android/iOS) probablemente no pasa, porque ese aviso solo se activa para tráfico con pinta de navegador.

**Arreglo aplicado.** Añadida la constante `kNgrokHeaders` en `api_service.dart` y aplicada en las 17 peticiones HTTP de los 6 ficheros que la necesitaban (`api_service.dart`, `roles_service.dart`, `trabajo_screen.dart`, `logopeda_fichas_screen.dart`, `logopeda_resumen_screen.dart`, `lip_screen.dart`). Falta que reconstruyas/reinicies la app (hot restart no basta si cambiaron imports/const top-level; mejor `flutter run` de nuevo o rebuild del build web) para que se recojan los cambios — esto es en tu máquina, no requiere tocar el servidor.

**Arreglo de fondo** (relacionado con el aviso de seguridad de `voice_backend/DESPLIEGUE.md`): dejar de depender de ngrok gratuito como URL fija de producción y montar un dominio propio con reverse proxy (nginx/Caddy + HTTPS). De paso, sacar `kServerUrl` de una constante hardcodeada a `--dart-define=SERVER_URL=...`, y crear un único cliente HTTP compartido en vez de repetir headers en 6 ficheros.

**Aviso de seguridad aparte:** el authtoken de ngrok salió en texto plano en el `ps aux` que pegaste (`--authtoken=39uWW8Qkp2P1iNc5xw2wmv03Lrf_7ZvKH8sT6dTfQLEi6YeNF`), visible para cualquier usuario del servidor y ahora también en este chat. Trátalo como comprometido: revócalo/rótalo en el panel de ngrok y arranca el túnel con `ngrok config add-authtoken ...` (queda en `~/.config/ngrok/ngrok.yml`) o la variable de entorno `NGROK_AUTHTOKEN`, no como flag `--authtoken=` en el comando.

## Hallazgo secundario: el selector de "Emoción" no hace nada con voz clonada

En `text_screen.dart` el usuario puede elegir una emoción (`VozEmocion`) que se ve y es seleccionable siempre. Pero en `tts_service.dart`, `emocion` solo se usa en la rama del TTS del sistema (voz por defecto del teléfono, vía `browserTtsParams`):

```dart
if (userToken != null && hasVoice) {
  final bytes = await _api.synthesize(token: userToken, text: text, speed: ...); // sin emoción
  ...
} else {
  final (pitch, rate) = emocion.browserTtsParams; // solo aquí se usa
  ...
}
```

Cuando el usuario tiene voz clonada (el caso principal de la app), cambiar la emoción no tiene ningún efecto audible — puede confundir a alguien que dependa de la app para comunicarse. Dos opciones: ocultar/deshabilitar el selector de emoción cuando `usingClonedVoice` es true, o extender el endpoint `/voice/tts` en el backend para aceptar un parámetro de emoción y que de verdad se aplique.

## Menores / limpieza

- `lib/` tiene ficheros sueltos que no son Dart: `planificador.html`, `roi_vision.html`, `renombrar_boletines.sh`, `tutorial_pytorch.ipynb`. No rompen la compilación pero no pintan nada ahí; moverlos fuera de `lib/` o a una carpeta `tools/`/`docs/`.
- Hay un `lib.zip` (83KB, del 22 jun) suelto en la raíz del proyecto — probablemente un backup antiguo; confirmar si se puede borrar.
- `login_screen.dart` usa `print('GOOGLE LOGIN ERROR: $e')` en vez de `debugPrint`/logger — queda en release builds, cambio trivial.

## Nota de consistencia con el backend

Igual que se documentó en `voice_backend/DESPLIEGUE.md`: estas pantallas llaman a rutas (`/roles/*`, `/fichas/*`, `/exercises/*`, `/videos/*`, `/auth/google`) que no existen en el `voice_backend.zip` que se revisó antes — confirma que ese zip está desactualizado frente al código real del servidor. No es un problema del Flutter, es que falta traer el backend actualizado para poder revisarlo también a fondo.
