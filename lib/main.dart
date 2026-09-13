import 'package:flutter/material.dart';
import 'debug_config.dart';
import 'models/app_settings.dart';
import 'models/app_user.dart';
import 'screens/ajustes/ajustes_home_screen.dart';
import 'screens/clone_voice_screen.dart';
import 'screens/frases_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lip_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/text_screen.dart';
import 'services/api_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'screens/app_router.dart';
import 'screens/trabajo_screen.dart';
import 'widgets/mouth_icon.dart';
import 'widgets/voz_bottom_nav.dart';

// Los flags y credenciales del bypass temporal de login viven ahora en
// `lib/debug_config.dart` (fuera de git, ver .gitignore) para que la
// contraseña de prueba nunca llegue al repositorio. Si ese archivo no
// existe, cópialo desde `lib/debug_config.example.dart`.

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RecuperaTuVozApp());
}

class RecuperaTuVozApp extends StatefulWidget {
  const RecuperaTuVozApp({super.key});

  @override
  State<RecuperaTuVozApp> createState() => _RecuperaTuVozAppState();

  static _RecuperaTuVozAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_RecuperaTuVozAppState>()!;
}

class _RecuperaTuVozAppState extends State<RecuperaTuVozApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void setTheme(bool oscuro) {
    setState(() {
      _themeMode = oscuro ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recupera tu voz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: const AppRoot(),
    );
  }
}

// ─────────────────────────────────────────
// ROOT APP (LOGIN / SESSION)
// ─────────────────────────────────────────

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final AuthService _auth = AuthService();
  final SettingsService _settingsSvc = SettingsService();
  final VoiceApiService _voiceApi = VoiceApiService();

  AppUser? _user;
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  bool _showRegister = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final user = await _auth.loadUser();
    final settings = await _settingsSvc.loadSettings();

    AppUser? syncedUser = user;

    if (user != null && user.token.isNotEmpty) {
      try {
        final status = await _voiceApi.checkVoiceStatusFull(user.token);
        syncedUser = user.copyWith(
          hasVoice: status['has_voice'] ?? user.hasVoice,
          numReferences: status['num_references'] ?? user.numReferences,
        );
        await _auth.saveUser(syncedUser);
      } catch (_) {}
    }

    // ── BYPASS TEMPORAL DE LOGIN (ver aviso arriba) ────────────────
    if (syncedUser == null && kAutoLoginForReview) {
      try {
        syncedUser = await _auth.login(
          email: kReviewEmail,
          password: kReviewPassword,
        );
        await _auth.saveUser(syncedUser);
      } catch (e) {
        // Si falla (backend caído, credenciales incorrectas, etc.)
        // simplemente se cae a la pantalla de login normal.
      }
    }

    if (mounted) {
      setState(() {
        _user = syncedUser;
        _settings = settings;
        _loading = false;
      });
    }
  }

  Future<void> _login(String email, String password) async {
    final user = await _auth.login(email: email, password: password);
    await _auth.saveUser(user);
    if (mounted) setState(() => _user = user);
  }

  Future<void> _loginWithGoogle(String idToken) async {
    final user = await _auth.loginWithGoogle(idToken);
    await _auth.saveUser(user);
    if (mounted) setState(() => _user = user);
  }

  Future<void> _register(String name, String email, String password) async {
    final user =
    await _auth.register(name: name, email: email, password: password);
    await _auth.saveUser(user);

    if (mounted) {
      setState(() {
        _user = user;
        _showRegister = false;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    // ── BYPASS OFFLINE (ver aviso arriba) ───────────────────────────
    // Se comprueba antes que nada: ni loading, ni login, ni llamadas
    // de red — entra directo con el usuario ficticio.
    if (kOfflineBypass) {
      return AppShell(
        user: kOfflineDebugUser,
        settings: _settings,
        onSettingsChanged: (s) {
          setState(() => _settings = s);
          RecuperaTuVozApp.of(context).setTheme(s.temaOscuro);
        },
        onUserChanged: (_) {}, // no-op: no hay sesión real que guardar
        onLogout: () {},       // no-op: no hay sesión real que cerrar
      );
    }

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      if (_showRegister) {
        return RegisterScreen(
          onRegister: _register,
          onGoLogin: () => setState(() => _showRegister = false),
        );
      }

      return LoginScreen(
        onLogin: _login,
        onGoogleLogin: _loginWithGoogle,
        onGoRegister: () => setState(() => _showRegister = true),
      );
    }

    return AppRouter(
      user: _user!,
      settings: _settings,
      onSettingsChanged: (s) {
        setState(() => _settings = s);
        RecuperaTuVozApp.of(context).setTheme(s.temaOscuro);
      },
      onUserChanged: (u) async {
        await _auth.saveUser(u);
        if (mounted) setState(() => _user = u);
      },
      onLogout: _logout,
    );
  }
}

// ─────────────────────────────────────────
// APP SHELL (NAVEGACIÓN)
// ─────────────────────────────────────────

class AppShell extends StatefulWidget {
  final AppUser user;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final ValueChanged<AppUser> onUserChanged;
  final VoidCallback onLogout;

  const AppShell({
    super.key,
    required this.user,
    required this.settings,
    required this.onSettingsChanged,
    required this.onUserChanged,
    required this.onLogout,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Arranca en Escribir (índice 1): Frases ocupa la posición 0 en la
  // barra por ser la de alcance más rápido, pero el aterrizaje por
  // defecto al abrir la app es Escribir.
  int _tabIndex = 1;
  bool _showCloneVoice = false;

  // null mientras se comprueba; true = mostrar bienvenida (primera
  // vez); false = ya vista, ir directo a las pestañas.
  bool? _showWelcome;

  late AppUser _user;

  final VoiceApiService _voiceApi = VoiceApiService();
  final SettingsService _settingsSvc = SettingsService();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _checkWelcome();
  }

  Future<void> _checkWelcome() async {
    final seen = await _settingsSvc.hasSeenWelcome();
    if (mounted) setState(() => _showWelcome = !seen);
  }

  Future<void> _dismissWelcome() async {
    await _settingsSvc.markWelcomeSeen();
    if (mounted) {
      setState(() {
        _showWelcome = false;
        _tabIndex = 1; // Escribir, tras pulsar "Empezar"
      });
    }
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el padre actualiza el user (p.ej. tras guardar), sincronizamos
    if (oldWidget.user != widget.user) {
      setState(() => _user = widget.user);
    }
  }

  void _updateUser(AppUser updated) {
    setState(() => _user = updated);
    widget.onUserChanged(updated);
  }

  void _goToTab(int i) => setState(() => _tabIndex = i);

  // Accesos directos compartidos por la AppBar de todas las pantallas.
  void _openCloneVoice() => setState(() => _showCloneVoice = true);
  void _goToClases() => _goToTab(3);

  @override
  Widget build(BuildContext context) {
    // ── Bienvenida: solo la primera vez que se entra a la app ──────
    if (_showWelcome == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_showWelcome == true) {
      return HomeScreen(onEmpezar: _dismissWelcome);
    }

    if (_showCloneVoice) {
      return CloneVoiceScreen(
        token: _user.token,
        alreadyHasVoice: _user.hasVoice,
        initialNumReferences: _user.numReferences,
        onUploadReplace: (files) async {
          final saved = await _voiceApi.uploadReplaceAudios(
            token: _user.token,
            files: files,
          );
          _updateUser(_user.copyWith(hasVoice: true, numReferences: saved));
          return saved;
        },
        onUploadAdd: (files) async {
          final saved = await _voiceApi.uploadAddAudios(
            token: _user.token,
            files: files,
          );
          _updateUser(_user.copyWith(hasVoice: true, numReferences: saved));
          return saved;
        },
        onDelete: () async {
          await _voiceApi.deleteVoice(_user.token);
          _updateUser(_user.copyWith(hasVoice: false, numReferences: 0));
        },
        onDone: () => setState(() => _showCloneVoice = false),
        onGoToClases: () => setState(() {
          _showCloneVoice = false;
          _tabIndex = 3;
        }),
      );
    }

    // ── Las 5 pantallas de navegación ──────────────────────────
    // Orden pensado para uso a una mano: Frases primero (necesidades
    // más urgentes al alcance más rápido del pulgar), luego Escribir
    // (antes "Texto"), Labios y Práctica (antes "Trabajo") —los tres
    // canales/actividades de uso diario— y Ajustes al final (antes
    // "Perfil", uso esporádico).
    final screens = [
      FrasesScreen(
        settings: widget.settings,
        user: _user,
        active: _tabIndex == 0,
        onVozTap: _openCloneVoice,
        onClasesTap: _goToClases,
      ),
      TextScreen(
        settings: widget.settings,
        user: _user,
        onVozTap: _openCloneVoice,
        onClasesTap: _goToClases,
      ),
      LipScreen(
        user: _user,
        onVozTap: _openCloneVoice,
        onClasesTap: _goToClases,
      ),
      TrabajoScreen(
        user: _user,
        onVozTap: _openCloneVoice,
      ),
      AjustesHomeScreen(
        settings: widget.settings,
        user: _user,
        onSettingsChanged: widget.onSettingsChanged,
        onCloneVoice: _openCloneVoice,
        onGoToClases: _goToClases,
        onLogout: widget.onLogout,
        onUserChanged: _updateUser,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: screens),
      bottomNavigationBar: VozBottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: _goToTab,
        items: const [
          VozBottomNavItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view),
              label: 'Frases'),
          VozBottomNavItem(
              icon: Icon(Icons.keyboard_outlined),
              activeIcon: Icon(Icons.keyboard),
              label: 'Escribir'),
          VozBottomNavItem(
              icon: MouthIcon(),
              activeIcon: MouthIcon(filled: true),
              label: 'Labios'),
          VozBottomNavItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment_rounded),
              label: 'Práctica'),
          VozBottomNavItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Ajustes'),
        ],
      ),
    );
  }
}