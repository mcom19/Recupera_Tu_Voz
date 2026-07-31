class AppUser {
  final String  token;
  final String  userId;
  final String  name;
  final String  email;
  final String? picture;
  final bool    hasVoice;
  final int     numReferences;
  final String? role;
  final bool    roleSet;
  final String? logopedaId;
  final String? logopedaName;
  /// Local, no viene del backend: el paciente eligió "Más tarde" en vez de
  /// vincularse con un logopeda al entrar. Evita que se le vuelva a forzar
  /// la pantalla de vinculación; puede vincularse cuando quiera desde el perfil.
  final bool logopedaSkipped;

  const AppUser({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
    this.picture,
    required this.hasVoice,
    this.numReferences = 0,
    this.role,
    this.roleSet = false,
    this.logopedaId,
    this.logopedaName,
    this.logopedaSkipped = false,
  });

  bool get isLogopeda => role == 'logopeda';
  bool get isPatient  => role == 'patient';

  // ── Serialización ──────────────────────────────────────────────

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    token:         j['token']          as String,
    userId:        j['user_id']        as String,
    name:          j['name']           as String? ?? '',
    email:         j['email']          as String,
    picture:       j['picture']        as String?,
    hasVoice:      j['has_voice']      as bool?   ?? false,
    numReferences: j['num_references'] as int?    ?? 0,
    role:          j['role']           as String?,
    roleSet:       j['role_set']       as bool?   ?? false,
    logopedaId:    j['logopeda_id']    as String?,
    logopedaName:  j['logopeda_name']  as String?,
    logopedaSkipped: j['logopeda_skipped'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'token':          token,
    'user_id':        userId,
    'name':           name,
    'email':          email,
    'picture':        picture,
    'has_voice':      hasVoice,
    'num_references': numReferences,
    'role':           role,
    'role_set':       roleSet,
    'logopeda_id':    logopedaId,
    'logopeda_name':  logopedaName,
    'logopeda_skipped': logopedaSkipped,
  };

  Map<String, dynamic> toJsonWithoutToken() => {
    'user_id':        userId,
    'name':           name,
    'email':          email,
    'picture':        picture,
    'has_voice':      hasVoice,
    'num_references': numReferences,
    'role':           role,
    'role_set':       roleSet,
    'logopeda_id':    logopedaId,
    'logopeda_name':  logopedaName,
    'logopeda_skipped': logopedaSkipped,
  };

  // ── copyWith ───────────────────────────────────────────────────

  static const _clear = Object();

  AppUser copyWith({
    bool?   hasVoice,
    String? name,
    int?    numReferences,
    String? role,
    bool?   roleSet,
    Object? logopedaId   = _clear,
    Object? logopedaName = _clear,
    bool?   logopedaSkipped,
  }) => AppUser(
    token:         token,
    userId:        userId,
    name:          name          ?? this.name,
    email:         email,
    picture:       picture,
    hasVoice:      hasVoice      ?? this.hasVoice,
    numReferences: numReferences ?? this.numReferences,
    role:          role          ?? this.role,
    roleSet:       roleSet       ?? this.roleSet,
    logopedaId:    identical(logopedaId,   _clear) ? this.logopedaId   : logopedaId   as String?,
    logopedaName:  identical(logopedaName, _clear) ? this.logopedaName : logopedaName as String?,
    logopedaSkipped: logopedaSkipped ?? this.logopedaSkipped,
  );
}