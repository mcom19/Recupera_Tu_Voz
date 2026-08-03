# Revisión completa — camino hacia "conversación en tiempo real" (labios + voz clonada)

Objetivo declarado: una persona laringectomizada usa el móvil para mantener una conversación real con otra persona, mediante lectura de labios (ella no puede vocalizar) que se convierte en texto y se reproduce con su voz clonada.

Esta revisión cubre todo el código Flutter y lo que se conoce del backend (parcial, ver `voice_backend/DESPLIEGUE.md`). Está ordenada por impacto sobre ese objetivo concreto, no por módulo.

## 1. El banco de voz es pre-operatorio (confirmado) — pero la app no lo dice en ningún sitio

`record_voice_screen.dart` pide grabar 30s–2min **leyendo en voz alta** una de las frases guiadas. Confirmado: el flujo clínico real es que el equipo médico enseña la app al paciente antes de operar, precisamente para que clone su voz mientras todavía puede. Esto tiene todo el sentido y no es un fallo de diseño — el hueco está en que **la propia app no lo comunica**: ni el onboarding, ni la pantalla de "Clonar mi voz", ni la de grabación mencionan en ningún momento que esto hay que hacerlo *antes* de la operación. Si un paciente abre la app por su cuenta después de la cirugía (o un familiar se la instala más tarde sin saber el porqué), no hay ningún aviso que le explique por qué ya no puede grabar, ni qué alternativas tiene.

Recomendaría dos cosas de bajo esfuerzo y alto valor: (1) un mensaje explícito en el onboarding y en "Clonar mi voz" del tipo "Es importante grabar tu voz antes de cualquier intervención que pueda afectarla — coméntaselo a tu equipo médico si aún no lo has hecho", y (2) confirmar con el equipo clínico si existe algún protocolo para el caso de quien llega ya operado sin haber grabado (voz de un familiar con consentimiento, voz sintética "parecida", etc.), aunque sea un caso menos frecuente si el proceso pre-operatorio funciona bien.

## 2. La latencia de todo el pipeline es incompatible con "tiempo real"

Una conversación real no tolera esperas de varios segundos por turno. Así es el camino actual, de principio a fin:

- **Lectura de labios** (`lip_screen.dart`): no es streaming. El paciente mantiene pulsado hasta 8 segundos, se detiene la grabación, se sube el **vídeo completo** por HTTP (`POST /lipreading/speak`, multipart) y se espera la respuesta entera antes de mostrar nada. No hay resultado parcial ni feedback mientras se procesa.
- **Reconocimiento en el servidor**: el contenedor de lipreading está caído en producción ahora mismo (`ModuleNotFoundError: No module named 'pipelines'`, ver `voice_backend/DESPLIEGUE.md`) — con lo cual esta ruta ni siquiera funciona hoy.
- **Síntesis con voz clonada** (`voice_backend/services/tts_service.py`): por cada frase se genera audio con MeloTTS y luego se convierte el timbre completo con OpenVoice (`tau=0.7`). Es una conversión de audio a audio de principio a fin, no streaming ni incremental. El propio texto de `text_screen.dart` ya avisa: *"Sintetizando con tu voz... puede tardar hasta 60s"*. Un minuto de espera por frase hace imposible cualquier conversación natural.
- Sumando grabar (hasta 8s) + subir el vídeo + inferencia de labios + síntesis de voz (hasta 60s) + descarga y reproducción, el ciclo completo por turno puede irse a más de un minuto. Para una conversación real hace falta pensar en menos de 1–2 segundos de principio a fin.

La causa de que la síntesis sea tan lenta puede estar agravada por un bug que ya documenté en `voice_backend/REVISION.md`: el `Dockerfile` instala `torch` con CUDA, pero `requirements.txt` lo reinstala en versión CPU y pisa esa build — es posible que la síntesis esté corriendo en CPU en vez de GPU ahora mismo, lo cual explicaría tiempos tan altos.

**Para que esto llegue a sentirse como "tiempo real" hace falta repensar la arquitectura, no solo optimizar:**
- Lectura de labios en streaming (frames continuos por WebSocket, resultados parciales) en vez de "graba y sube el vídeo entero".
- Un motor de síntesis de voz con streaming o de baja latencia para la conversación en vivo, dejando el pipeline actual (MeloTTS + OpenVoice, alta calidad pero lento) para la fase de banco de voz, no para cada frase dicha en directo.
- Precalcular/cachear audio para lo predecible: ver punto 4.

## 3. La ruta "Frases" es la oportunidad más barata de acercarse a tiempo real ya mismo

`frases_screen.dart` reutiliza el mismo `TtsService.speak()` que la pantalla de texto libre — es decir, cada vez que se toca una frase predefinida (incluidas las típicas de conversación: saludos, "sí", "no", "gracias", peticiones frecuentes) se vuelve a sintetizar con el mismo pipeline lento, sin ningún caché. Aquí hay una mejora de bajo esfuerzo y alto impacto: generar el audio de las frases fijas **una vez** (al vincular la voz, o la primera vez que se usan) y guardarlo localmente, para que la reproducción posterior sea instantánea. Para una conversación real, tener 15–20 frases de uso constante con audio ya listo puede cubrir una parte importante de los turnos de conversación mientras el resto del pipeline (labios en streaming, síntesis rápida) madura.

## 4. UX de la pantalla "Labios" no está pensada para una conversación fluida

- Hay que **mantener pulsado** un botón mientras se mira a la cámara y se articula en silencio — eso significa que el paciente no puede mirar a la persona con la que habla mientras "habla" con el móvil, y necesita al menos una mano libre y ocupada todo el rato. En una conversación real (mirando a los ojos, gesticulando) esto es un obstáculo importante.
- No hay ninguna guía visual de "estás bien encuadrado / se te ve la boca", solo un óvalo estático de referencia; si el encuadre falla, el paciente no se entera hasta que llega el resultado (o el error) muchos segundos después.
- El audio se reproduce automáticamente al terminar, lo cual está bien, pero no hay ninguna forma de "seguir hablando" fluido: cada frase es un ciclo completo de grabar→procesar→reproducir→(pulsar otra vez), no una conversación continua.

Antes de invertir en streaming real, valdría la pena prototipar el flujo de interacción (¿modo manos libres con activación por proximidad de la cara? ¿confirmación visual antes de enviar? ¿corrección rápida si el texto reconocido está mal, sin tener que regrabar entero?).

## 5. Seguridad y privacidad, ahora con más peso

Ya señalé en `voice_backend/DESPLIEGUE.md` que el servidor parece expuesto directamente a internet sin reverse proxy, con un `SECRET_KEY` por defecto si no se configura, y que llegan escaneos de bots. Para esta función en concreto el riesgo sube un nivel: cada turno de conversación implica subir un **vídeo de la cara del paciente** (dato biométrico) a ese mismo servidor. Antes de usar esto en el día a día de una persona vulnerable, cerraría primero ese acceso (proxy + HTTPS + firewall) y revisaría cuánto tiempo se retienen esos vídeos en el servidor (`voice_backend/routers` no muestra ningún borrado automático de los vídeos de lipreading, a diferencia de los audios de voz que sí se pueden eliminar desde `/voice/`).

## 6. Otros hallazgos menores, ya detectados antes, que siguen pendientes

- El selector de "Emoción" en Texto no afecta a la voz clonada (`FLUTTER_REVISION.md`).
- El backend real en producción va muy por delante del zip que tengo para revisar (rutas `/exercises`, `/roles`, `/fichas`, `/videos`, `/lipreading` no están en el código que me pasaste) — no he podido auditar a fondo ni el lipreading ni el motor de ejercicios porque no tengo ese código fuente.
- Ficheros sueltos no-Dart dentro de `lib/` y un `lib.zip` residual (limpieza, sin urgencia).

## Prioridades, de mayor a menor impacto sobre el objetivo final

1. Comunicar dentro de la propia app que la grabación debe hacerse antes de operarse (onboarding + pantalla de clonación) — es un cambio pequeño con impacto directo en que el flujo clínico real funcione.
2. Arreglar el contenedor de lipreading (roto ahora mismo) y conseguir el código fuente completo de `backendlip` para poder auditar de verdad esa pieza.
3. Medir la latencia real de síntesis en el servidor (¿está corriendo en CPU por el bug de `requirements.txt`?) y decidir si el pipeline actual (MeloTTS + OpenVoice) puede servir para "casi tiempo real" o si hace falta un motor distinto para la conversación en vivo.
4. Cachear localmente el audio de las frases fijas (quick win, ya explicado en el punto 3).
5. Rediseñar la interacción de la pantalla de labios pensando en manos libres y feedback inmediato, una vez el backend soporte algo más cercano a streaming.
6. Cerrar el acceso del servidor (proxy/HTTPS/firewall) antes de manejar vídeo facial en producción.
