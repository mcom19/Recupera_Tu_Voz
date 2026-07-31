# Arquitectura de despliegue en servidor — notas de reconstrucción

Los alumnos que montaron el servidor ya no están y no había documentación. Esto es lo reconstruido a partir de `docker ps -a`, `docker inspect` y logs, para no perder este conocimiento otra vez.

## Servidor: ubuntu-servidor (acceso por SSH/VS Code Remote)

4 contenedores, dos proyectos docker-compose distintos:

**Proyecto `voice_backend`** (`/home/ubuntu/voice_backend/docker-compose.yml`), 3 servicios definidos: `api`, `lipreading`, `db` (el compose declara que `api` depende de `db` y de `lipreading`):

| Contenedor | Servicio | Puerto | Estado real |
| --- | --- | --- | --- |
| `recupera_voz_api` | `api` | 8880 | Funcionando bien (login, roles, fichas de pacientes, voz — ver logs) |
| `recupera_voz_lipreading` | `lipreading` | 8881 | **Roto** — ver bug abajo |
| `recupera_voz_db` | `db` (postgres:16-alpine) | 5432 (interno) | OK, healthy |

**Proyecto aparte, sin compose visible:**

| Contenedor | Puerto | Función (por el nombre) |
| --- | --- | --- |
| `pvoz-dataset` | 8001 | Servidor de grabación/recolección de dataset de voz (`grabar-server-pvoz-dataset`) |

## Bug activo: lipreading caído en la práctica (aunque `docker ps` lo marca "Up")

`recupera_voz_lipreading` arranca uvicorn correctamente pero falla al cargar el modelo:

```
Traceback (most recent call last):
  File "/app/pipeline.py", line 26, in load_pipeline
    from pipelines.pipeline import InferencePipeline
ModuleNotFoundError: No module named 'pipelines'
[LIPREADING] Error cargando modelo: No module named 'pipelines'
```

Consecuencia: el contenedor sale como "Up" en `docker ps` (el proceso uvicorn vive), pero cualquier `POST /infer` responde `503 Service Unavailable`. Esto explica la sensación de "se ha caído" sin que docker lo refleje.

Causa probable: el paquete `pipelines/` (código del modelo de lectura de labios) no se copió a la imagen Docker — o existe en el repo pero el `Dockerfile`/`COPY` de ese servicio no lo incluye, o falta un `__init__.py` / el paquete no está en el `PYTHONPATH`. Pendiente de confirmar con el contenido de `backendlip.zip` (llegó truncado, hay que resubirlo) o inspeccionando directamente en el servidor:

```bash
docker exec recupera_voz_lipreading ls /app
docker exec recupera_voz_lipreading python -c "import pipelines"
find /home/ubuntu -iname "pipeline*.py"
```

## Importante: el código del servidor va MUY por delante del zip que se subió aquí

`voice_backend.zip` que se analizó (ver `REVISION.md`) solo tenía `/auth/register` y `/auth/login`. Pero los logs reales de `recupera_voz_api` en producción muestran endpoints que no existen en ese zip: `/auth/google`, `/roles/me`, `/roles/mis-pacientes`, `/roles/vincular-paciente`, `/roles/generar-codigo`, `/fichas`, `/fichas/mis-fichas`, `/fichas/stats`, `/frases/default`, además de `/voice/status`.

Conclusión: el zip que tenemos es una versión antigua/parcial. El código real y actualizado vive en `/home/ubuntu/voice_backend` en el servidor. Antes de seguir revisando o documentando el backend, conviene traer una copia fresca de ahí (`scp`/`rsync` o zip nuevo desde el servidor) en vez de seguir trabajando sobre el zip desactualizado.

## Aviso de seguridad — datos de pacientes expuestos sin protección aparente

Los logs de `pvoz-dataset` muestran tráfico constante de bots/escáneres de internet contra el puerto 8001 (`GET /api/.env`, `POST /v1/chat/completions`, `GET /mcp`, etc.), lo que indica que el servidor está expuesto directamente a internet sin firewall ni reverse proxy delante. El servicio `api` (8880) maneja datos de pacientes (`/fichas`, `/roles/mis-pacientes`) — si también está expuesto igual de directo, es un riesgo serio de privacidad de datos de salud. Recomendado con urgencia:

- Poner los servicios detrás de un reverse proxy (nginx/Caddy) con HTTPS, y no exponer los puertos 8880/8881/8001 directamente a internet.
- Restringir por firewall (ufw / security group) el acceso a esos puertos solo a IPs necesarias.
- Revisar si esto conecta con el hallazgo ya documentado del `SECRET_KEY` por defecto en `REVISION.md` — con el servidor abierto al público, ese fallo es explotable ahora mismo, no solo en teoría.

## Pendiente

- [ ] Confirmar causa exacta del `ModuleNotFoundError: No module named 'pipelines'` y arreglarlo.
- [ ] Volver a subir `backendlip.zip` sin truncar (o regenerarlo en el servidor: `cd /home/ubuntu && zip -r backendlip_fix.zip backendlip`).
- [ ] Traer una copia actualizada de `/home/ubuntu/voice_backend` (el de verdad, no el zip antiguo).
- [ ] Verificar si 8880/8881/8001 están expuestos directamente a internet o hay algo delante.
- [ ] Averiguar por qué la app Flutter local (`localhost:56522`, "No se pudo conectar con el servidor") no conecta — probablemente apunta a una URL/puerto de API que no coincide con 8880, o el propio `flutter run` local perdió la conexión; no es el mismo problema que el de lipreading.
