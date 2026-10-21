# Guía — continuar el trabajo en otro ordenador

_Preparado: 30 agosto 2026 · repo: `Recupera_Tu_Voz`, rama `accesoservidor`_

## 0. Lo importante primero: qué NO viaja solo

Tu repo tiene remoto configurado (`origin` → `https://github.com/L-amoros/Recupera_Tu_Voz.git`) y todo lo que ya está **comiteado** en `accesoservidor` está sincronizado con GitHub — eso lo recuperas en cualquier ordenador con un simple `git clone`/`git pull`, sin hacer nada especial.

El problema es que ahora mismo hay **trabajo sin commitear** en este ordenador que un `git pull` en el otro equipo no traerá:

- **Archivos nuevos sin trackear** (de esta sesión y de sesiones anteriores):
  `PROTOTIPO_LECTURA_LABIOS.md`, `asesoria-lectura-labios.md`, `checklist-prioridades-arquitectura.md`, `despliegue-local-docker.md`, `voz.zip`, `lib/main_lip_prototype.dart`, `lib/screens/lip_capture_prototype_screen.dart`, `lib/services/face_framing_service.dart`, `lib/widgets/mouth_frame_overlay.dart`.
- **`pubspec.yaml` modificado de verdad**: tiene las 2 dependencias nuevas (`google_mlkit_face_detection`, `google_mlkit_commons`) que añadí para el prototipo.

Si cambias de ordenador sin subir esto, en el equipo nuevo **no tendrás el prototipo de lectura de labios ni los informes** — solo lo último que hay en GitHub.

## 1. Un aviso aparte: el resto de "modificados" es ruido, no trabajo real

`git status` marca casi todo el árbol del proyecto como modificado (Android, iOS, Windows, Linux, macOS...). Lo he comprobado con `git diff` y **no es contenido cambiado** — es una conversión de fin de línea (LF↔CRLF), típica de trabajar en Windows sin `core.autocrlf` configurado. Por eso, en el paso siguiente, **no uses `git add -A`**: subiría un commit gigante de 18.000 líneas que no cambia nada real y ensucia el historial. Añade solo los archivos concretos que sí importan.

## 2. Antes de cambiar de ordenador — hazlo desde este equipo

Abre una terminal en `C:\Users\mcomd\desarrollo\flutter\Recupera_Tu_Voz` y ejecuta:

```bash
git add pubspec.yaml
git add PROTOTIPO_LECTURA_LABIOS.md asesoria-lectura-labios.md checklist-prioridades-arquitectura.md despliegue-local-docker.md
git add lib/main_lip_prototype.dart lib/screens/lip_capture_prototype_screen.dart lib/services/face_framing_service.dart lib/widgets/mouth_frame_overlay.dart

git commit -m "Prototipo de lectura de labios con encuadre facial + informes de arquitectura y modelos VSR"
git push origin accesoservidor
```

`pubspec.lock` no hace falta tocarlo a mano: se regenerará solo cuando ejecutes `flutter pub get` en el ordenador nuevo.

Si prefieres no tocar git todavía (por ejemplo, para revisar antes los cambios), la alternativa es copiar la carpeta completa `Recupera_Tu_Voz` a un USB/nube y llevarla tal cual al otro ordenador — pero entonces el repo remoto se queda desactualizado hasta que hagas el `push` desde donde sea.

## 3. En el ordenador nuevo

1. **Clonar (o si ya existe, actualizar) el repo:**
   ```bash
   git clone https://github.com/L-amoros/Recupera_Tu_Voz.git
   cd Recupera_Tu_Voz
   git checkout accesoservidor
   ```
2. **Instalar Flutter.** Revisa `FLUTTER_REVISION.md` en la raíz del proyecto para usar la misma versión que en este equipo y evitar sorpresas de compatibilidad.
3. **Resolver dependencias:**
   ```bash
   flutter pub get
   ```
   Esto es lo que descarga `google_mlkit_face_detection` y `google_mlkit_commons` a partir del `pubspec.yaml` ya actualizado.
4. **Requisitos nativos de ML Kit** (ya anotados en `PROTOTIPO_LECTURA_LABIOS.md`, que estará en el repo): `minSdkVersion 21` en Android, `platform :ios, '13.0'` en el `Podfile` de iOS.
5. **Probar el prototipo:**
   ```bash
   flutter run -t lib/main_lip_prototype.dart
   ```

## 4. Vincular Claude al ordenador nuevo

Esta conversación no depende de este ordenador — el historial y lo que hemos hablado están en tu cuenta y los ves desde cualquier dispositivo. Lo que sí es local a este equipo es **el puente a los archivos** (la carpeta `Recupera_Tu_Voz` que edito directamente). Para seguir editando archivos en el ordenador nuevo desde esta misma conversación:

1. Abre la app de escritorio de Claude en el ordenador nuevo.
2. Abre esta misma tarea/conversación.
3. Elige la opción **"Vincular a este ordenador"** (si no aparece para esta tarea, inicia una tarea nueva desde ese ordenador y selecciónalo como dispositivo).

Si solo quieres consultar el informe de modelos VSR (el que publiqué como página), no depende de ningún ordenador: está guardado en tu galería de artefactos de tu cuenta de Claude, entras con tu sesión desde cualquier equipo.

## 5. Qué falta según lo ya documentado (recordatorio, no nuevo)

Esto no cambia por mudarte de ordenador, pero conviene tenerlo presente al retomar: `checklist-prioridades-arquitectura.md` sigue teniendo como bloqueantes críticos el túnel ngrok temporal, el timeout de 90s en la síntesis de voz, y la firma de release de Android — ninguno afecta al prototipo de lectura de labios, pero sí a cuándo tiene sentido conectar `/lipreading/speak` de verdad en el backend.
