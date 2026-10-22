// Botón oficial de Google para la versión web.
// En web, GoogleSignIn.signIn() no devuelve idToken: hay que usar el botón de
// Google Identity Services y escuchar onCurrentUserChanged.
export 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart';
