# Desplegar el backend en local con Docker (mientras se recupera el servidor)

Guía para levantar el backend (FastAPI/Flask + Postgres + modelo de clonación autoalojado) en tu propio ordenador con Docker, y que la app Flutter (en el móvil Android) hable con él. Válido para pruebas y para terminar funcionalidad mientras se resuelve el servidor caído.

## 1. Recuperar la base de datos desde el backup

Si el backup es un dump de Postgres (`.sql` o `.dump`):

```bash
# Arrancar solo Postgres primero
docker run -d --name pg-local -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=recupera_tu_voz -p 5432:5432 postgres:16

# Restaurar un dump en texto plano (pg_dump -F p)
cat backup.sql | docker exec -i pg-local psql -U postgres -d recupera_tu_voz

# O si es un dump binario (pg_dump -F c)
docker cp backup.dump pg-local:/tmp/backup.dump
docker exec pg-local pg_restore -U postgres -d recupera_tu_voz /tmp/backup.dump
```

Si el backup son solo los ficheros de audio (no la base de datos), asegúrate de que las rutas/nombres que espera el backend coinciden con la carpeta donde los restaures (revisa la variable de entorno tipo `AUDIO_STORAGE_PATH` o similar en el backend).

## 2. docker-compose para backend + Postgres

Plantilla a adaptar con el `Dockerfile` real del backend (lo tendrá si ya lo desplegasteis dockerizado en el servidor):

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: recupera_tu_voz
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  api:
    build: .            # carpeta donde está el Dockerfile del backend
    environment:
      DATABASE_URL: postgresql://postgres:postgres@db:5432/recupera_tu_voz
      # resto de variables que use vuestro backend (secret keys, rutas de storage, etc.)
    volumes:
      - ./storage:/app/storage   # donde se guardan los audios/vídeos subidos
    ports:
      - "8000:8000"
    depends_on:
      - db
    # Si el modelo (XTTS/RVC) usa GPU y tienes NVIDIA en tu equipo + nvidia-container-toolkit instalado:
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia
    #           count: 1
    #           capabilities: [gpu]

volumes:
  pgdata:
```

```bash
docker compose up --build
```

Sin GPU local funcionará igual sobre CPU — más lento por síntesis, pero suficiente para pruebas funcionales (no para medir latencia real).

## 3. Que la app Android llegue a tu Docker local

Este es el paso que más falla. Dos escenarios:

**A) Emulador Android** (Android Studio): `localhost` del PC se ve como `10.0.2.2` desde el emulador. En `lib/services/api_service.dart`:

```dart
const String kServerUrl = 'http://10.0.2.2:8000';
```

**B) Móvil físico por WiFi**: el móvil y el PC deben estar en la misma red. Averigua la IP local del PC:

```bash
# Linux/Mac
ip addr show | grep "inet "
# Windows
ipconfig
```

Y usa esa IP (ej. `http://192.168.1.50:8000`) en `kServerUrl`.

**Importante — Android bloquea HTTP en claro por defecto (API 28+).** Al no tener HTTPS en local, hay que permitir cleartext explícitamente solo para pruebas. En `android/app/src/main/AndroidManifest.xml`, dentro de `<application>`:

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
```

Y crear `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">192.168.1.50</domain> <!-- tu IP local -->
    </domain-config>
</network-security-config>
```

Recuerda quitar/restringir esto antes de cualquier build de distribución — es solo para pruebas locales.

## 4. Recomendación mientras dure esta situación

- Saca `kServerUrl` a una constante fácil de cambiar (o mejor, a `--dart-define=SERVER_URL=...` al compilar) para no tener que tocar código cada vez que cambies entre local/servidor real.
- Cuando el servidor de producción vuelva, no olvides revertir `kServerUrl` antes de generar cualquier build que vaya a un paciente/logopeda real.

---

Cuando encuentres el backup y el código del backend, si conectas esa carpeta puedo adaptar el `docker-compose.yml` y el `Dockerfile` a vuestro caso concreto en vez de esta plantilla genérica.
