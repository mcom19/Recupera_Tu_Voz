import 'models/app_user.dart';

// ─────────────────────────────────────────────────────────────────
// PLANTILLA — copia este archivo como `lib/debug_config.dart` (ese sí
// está en .gitignore) y ajusta los valores si necesitas el bypass de
// login para revisión interna. Ver los comentarios de
// `debug_config.dart` para el detalle de cada flag.
//
// Con los valores de abajo (ambos flags en `false`) la app se
// comporta con normalidad: pantalla de login real, sin atajos.
// ─────────────────────────────────────────────────────────────────
const bool kAutoLoginForReview = false;
const String kReviewEmail = '';
const String kReviewPassword = '';

const bool kOfflineBypass = false;

const AppUser kOfflineDebugUser = AppUser(
  token: 'debug-token',
  userId: 'debug-user',
  name: 'Usuario de revisión',
  email: 'debug@local.test',
  hasVoice: false,
  numReferences: 0,
  role: 'patient',
  roleSet: true,
  logopedaId: 'debug-logopeda',
  logopedaName: 'Modo revisión (sin servidor)',
);
