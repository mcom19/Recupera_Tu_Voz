# Asesoría técnica — sección de lectura de labios en "Recupera tu voz"

_Fecha: 28 agosto 2026_

## 0. Punto de partida (lo que ya existe en el repo)

Antes de comparar modelos, esto es relevante porque cambia la recomendación:

- **El cliente Flutter ya está construido**: `lib/screens/lip_screen.dart` graba hasta 8s de vídeo con la cámara frontal, lo sube como `multipart/form-data` a `POST $kServerUrl/lipreading/speak`, espera de vuelta un WAV en el body y el texto reconocido en la cabecera `x-recognized-text`, y reproduce el audio automáticamente (reutilizando la voz clonada del paciente vía el pipeline de TTS existente). La UI, permisos de cámara/micrófono y guía visual de labios ya están hechos.
- **El backend NO tiene ese endpoint**: `voice_backend/routers` solo contiene `auth_router.py` y `voice_router.py`. No existe `lipreading_router`, ni `mediapipe`/`opencv`/`tensorflow` en `requirements.txt`. Es decir: **falta por completo la pieza de reconocimiento visual del habla (VSR)** — el resto ya está listo esperándola.
- **El servidor es CPU-only** (`torch==2.1.0+cpu`, sin GPU declarada) y ya arrastra un problema crítico de latencia documentado en `checklist-prioridades-arquitectura.md` (timeout de 90s en la síntesis de voz). Cualquier modelo VSR añadido debe ser consciente de esto: no se puede permitir sumar varios segundos más de espera a un flujo ya lento para una app AAC de uso urgente.
- **El paciente objetivo es laringectomizado total**: no hay pliegues vocales, pero la articulación oral (labios, mandíbula, lengua) suele estar intacta salvo resecciones/disecciones asociadas. Esto hace que el **VSR visual-only** (sin pista de audio) sea exactamente la modalidad correcta — el paciente puede vocalizar/articular en silencio y no hay señal de audio útil que combinar (a diferencia del AVSR clásico, pensado para gente que sí tiene voz pero en entornos ruidosos).

## 1. Los cuatro elementos que mencionas — qué son realmente

| Elemento | Qué es | Rol correcto |
|---|---|---|
| **Auto-AVSR** (`mpc001/auto_avsr`) | Framework de entrenamiento/inferencia end-to-end (Transformer/Conformer, ~250M parámetros), estado del arte en inglés (WER visual-only ≈20% en LRS3). Apache-2.0. Sin MediaPipe integrado (pipeline propio de recorte de boca). | Backbone a **fine-tunear** para español; no sirve out-of-the-box. |
| **VSR-ML** (`mpc001/Visual_Speech_Recognition_for_Multiple_Languages`) | El repo "hermano" de Auto-AVSR, con checkpoints ya entrenados en 6 idiomas, **incluido español vía CMU-MOSEAS** (WER visual-only ≈44.5%). Incluye **MediaPipe como detector opcional** (`detector=mediapipe`). Modelo visual-only ≈186-195MB. | El único de los cuatro con **español listo para probar hoy**. Pero licencia **"solo comparación/benchmarking, no comercial"** — ver aviso legal abajo. |
| **CMU-MOSEAS** | No es un modelo, es un **dataset** (español, portugués, alemán, francés — 40.000 frases etiquetadas, pensado originalmente para sentimiento/emoción, reutilizado como corpus audio-visual). Es la fuente de datos que hace posible el español en VSR-ML. | Útil como **corpus de fine-tuning/evaluación** si entrenáis vuestro propio modelo en español; no es algo que se "despliegue". |
| **"Whisper Visual" (Prajwal)** | Probablemente te refieres a la línea de K.R. Prajwal (Oxford VGG): "Sub-word Level Lip Reading" (VTP) o "Scaling Multilingual Visual Speech Recognition" (MultiVSR, 2025). MultiVSR cubre 13 idiomas (inglés, italiano, francés, alemán, portugués...) pero **el español no aparece confirmado** en los idiomas soportados, y no usa Whisper internamente pese al nombre. | Investigación puntera pero **no confirma español**; no lo priorizaría sin verificar directamente con los autores/checkpoints. |
| **LiteVSR** | Método de *knowledge distillation* desde un modelo de ASR (Conformer) hacia un VSR ligero, entrenado con datos audio-visuales **sin etiquetar**. Objetivo explícito: **tiempo real en hardware modesto** (una sola GPU de consumo, "dated hardware"). WER en inglés: 47.4% (LRS2) sin fine-tune / 35% con fine-tune. | El más alineado con vuestra restricción de **latencia y servidor CPU-only**, pero sin cobertura de español publicada — es una **receta de entrenamiento**, no un checkpoint listo. |

## 2. Recomendación

**No hay un "listo para producción en español" entre los cuatro.** La decisión real es en qué eje priorizáis:

1. **Prototipo rápido (semanas)**: usar el checkpoint español de **VSR-ML** (con `detector=mediapipe`) directamente en el nuevo endpoint `/lipreading/speak`, para validar el flujo completo end-to-end (grabación → VSR → texto → TTS con voz clonada) y medir la latencia real en vuestro servidor CPU. Tratar la licencia no-comercial como un bloqueante para producción: contactar a los autores para permiso explícito (proyecto de salud/educativo sin ánimo de lucro puede calificar) o presupuestar el fine-tuning propio en Fase 2.
2. **Producción a medio plazo**: fine-tunear el backbone de **Auto-AVSR** (Apache-2.0, sin restricciones) sobre CMU-MOSEAS-español +, idealmente, vídeos reales de pacientes laringectomizados. Esto importa especialmente aquí: la articulación de un paciente laringectomizado (fibrosis por radioterapia, disección cervical, movilidad oral alterada) no es la de un hablante general, y ningún modelo entrenado con hablantes sanos va a generalizar igual de bien — el propio estudio clínico "Utility of a Novel Mobile Lip-Reading Application for Patients After Total Laryngectomy" (Fassler et al., 2026) es la referencia más directa a vuestro caso de uso y merece leerse antes de fijar expectativas de precisión con el equipo clínico.
3. **Optimización de latencia**, una vez tengáis datos españoles propios: aplicar la receta de **LiteVSR** (destilar desde un ASR español, ej. un Whisper español que ya usáis parcialmente vía `ctranslate2`) para conseguir un modelo pequeño y rápido en CPU, coherente con la urgencia de la app.
4. **MediaPipe** no compite con los otros tres — es la etapa de **preprocesado** (landmarks faciales/recorte de labios) que usan tanto VSR-ML como (potencialmente) vuestro propio pipeline. Tiene sentido usarlo en los dos lados: en el cliente Flutter para dar feedback en vivo ("labios no detectados", encuadre) sin depender del servidor, y en el backend como paso previo a cualquier modelo VSR.

## 3. Recomendación de producto (la que más impacto tiene)

El WER visual-only en español (~44-45% en la literatura) es alto para transcripción abierta — mucho peor que el ASR de audio habitual. La app ya tiene el patrón correcto para mitigar esto: `FrasesScreen` usa un conjunto **cerrado** de frases frecuentes. Yo plantearía la primera versión de lectura de labios como **clasificación de vocabulario cerrado** (las mismas 20-30 frases/palabras clave del paciente: "agua", "dolor", "ayuda", "sí", "no", etc.) en lugar de transcripción de vocabulario abierto. Convierte un problema muy difícil (WER 44%) en uno mucho más tratable (clasificación entre N clases conocidas), y es compatible con cualquiera de los tres backbones VSR como extractor de características.

## 4. Avisos que no debéis pasar por alto

- **Licencia de VSR-ML**: "solo para comparación/benchmarking, no comercial" — igual que con datos de voz, tratad esto como bloqueante legal antes de cualquier despliegue a pacientes reales, no solo como detalle técnico.
- **Vídeo facial = dato biométrico/de salud**, igual o más sensible que el audio de voz que ya señalabais en el checklist de arquitectura (cifrado en reposo, backups, consentimiento RGPD, borrado en cascada). Aplican las mismas medidas que pedisteis para los audios de clonación de voz.
- **Ninguno de los cuatro modelos está pensado para correr dentro de Flutter/on-device** (son modelos PyTorch de 186MB-1.5GB+). La arquitectura correcta, coherente con lo que ya tenéis (clonación de voz también es server-side), es mantener el VSR en el backend FastAPI, no en el cliente.
