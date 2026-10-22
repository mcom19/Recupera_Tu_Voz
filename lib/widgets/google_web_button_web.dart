import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Botón oficial de Google (GIS). Al pulsarlo, el usuario llega por
/// GoogleSignIn.onCurrentUserChanged con un idToken válido.
Widget buildGoogleWebButton() => web.renderButton();
