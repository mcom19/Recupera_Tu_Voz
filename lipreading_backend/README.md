# Lipreading backend — stub local

Servidor mínimo en Docker para probar el pipeline completo de la
pantalla "Labios" (grabar vídeo → subirlo → recibir audio + texto)
**sin** un modelo VSR real todavía. Pensado para levantarse en tu
ordenador mientras el servidor oficial (túnel ngrok) está caído, y
poder sustituirse más adelante por el modelo real sin tocar el
contrato con la app.

## 1. Levantar el contenedor

Desde esta carpeta:

```bash
docker compose up --build
```

Esto expone el servidor en `http://localhost:8010`. Compruébalo con:

```bash
curl http://localhost:8010/
# {"status":"online","mode":"demo-stub","endpoint":"/lipreading/speak"}
```

Para pararlo: `docker compose down` (o Ctrl+C si lo dejaste en primer
plano).

## 2. Qué hace (y qué no hace) ahora mismo

`POST /lipreading/speak` acepta el mismo multipart (`video`, campo
`video`) que ya usa `lip_screen.dart`, pero **no analiza el vídeo**:
lo lee, lo descarta, y devuelve siempre un tono de prueba generado en
memoria como audio, más una frase aleatoria de una lista fija en la
cabecera `x-recognized-text`. Sirve para validar que el vídeo sale de
la app, llega al backend, y que la respuesta (audio + texto) vuelve y
se reproduce bien — no para probar reconocimiento real.

Cuando haya un modelo VSR listo para integrar, la inferencia real va
en `lipreading_speak()` dentro de `main.py`; el resto (CORS, forma de
la respuesta) no debería tener que cambiar.

## 3. Cómo apunta la app aquí

En `lib/services/api_service.dart`, `kServerUrl` se cambió
temporalmente a `http://localhost:8010` mientras el servidor real
(túnel ngrok) está caído. Esa constante la usan TODAS las llamadas al
backend (auth, voice, frases, videos, lipreading), así que con esto
apuntado aquí solo `/lipreading/speak` responderá de verdad — el resto
de pantallas que dependan del servidor real darán error de red (las
frases caen a su catálogo básico embebido; el login ya está
baipaseado por `kOfflineBypass` en `debug_config.dart`, así que no
hace falta que el login funcione para llegar a "Labios").

Cuando el servidor real (o este backend con el modelo de verdad) esté
listo, revierte `kServerUrl` — hay un comentario justo al lado en
`api_service.dart` con la URL a restaurar.

## 4. Probarlo desde la app en Chrome

La pantalla "Labios" (`lip_screen.dart`) se adaptó en este mismo
cambio para funcionar también en Flutter Web (antes dependía de
`dart:io`, que no existe en el navegador, para guardar el vídeo
grabado y el audio de respuesta). Con el contenedor levantado y
`flutter run -d chrome` corriendo, deberías poder:

1. Abrir la pestaña "Labios".
2. Aceptar el permiso de cámara que pida el propio navegador.
3. Mantener pulsado el botón para grabar unos segundos.
4. Al soltar, se sube el vídeo a `http://localhost:8010/lipreading/speak`
   y debería sonar el tono de prueba con un texto reconocido "de
   mentira" debajo.

Si el navegador bloquea la petición (error de red/CORS en la consola),
confirma que el contenedor sigue levantado y que `kServerUrl` apunta
al puerto 8010.

## 5. Siguiente paso: llevarlo al servidor oficial

Esta carpeta es autocontenida (Dockerfile + requirements + código) y
no depende de nada de `voice_backend/`, así que se puede desplegar
igual en el servidor oficial cuando se recupere — solo cambia el host
al que apunta `kServerUrl` (y aquí sí hará falta HTTPS real, no
`localhost`). El día que haya un modelo VSR real, decide entonces si
vive en este mismo contenedor o en uno aparte con GPU (como
`voice_backend/Dockerfile`, que usa una imagen base CUDA) según lo
pesado que sea el modelo.
