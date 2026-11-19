Necesito un script bash para diagnosticar 504 intermitentes en Apigee Edge Private Cloud 4.52 (RHEL8). Lo ejecutaré como root en cada uno de los tres nodos Router+MP: scgp1airvmll-apicor-11, -12 y -13. Accedo por AWS SSM Session Manager.

CONTEXTO
- Flujo: AWS ALB → Router Edge (nginx) → Message Processor (puerto 8998) → targets en EKS.
- Un incidente reporta respuestas cortadas a ~60 s exactos (504 "Gateway Time-out" de nginx) aunque el backend respondió en milisegundos.
- Logs del Router: /opt/apigee/var/log/edge-router/nginx/
  - Access logs: <org>~<env>.<puerto>_access_log (p. ej. scger~core.9004_access_log, scger~intranet-client.9008_access_log). Pueden pesar varios cientos de MB.
  - Error logs: <org>~<env>.<puerto>_error_log
  - Puede haber ficheros rotados (.gz) o no.
- Logs del MP: /opt/apigee/var/log/edge-message-processor/logs/system.log
- Configuración nginx: /opt/nginx/conf.d/*.conf
- Overrides: /opt/apigee/customer/application/router.properties y message-processor.properties
- Los timestamps del access log están en hora local CET, formato 2026-11-19T06:26:40+01:00.
- Formato observado del access log, separado por espacios. Verifícalo con una línea real antes de fijar posiciones de campo:
  timestamp, host del router, IP:puerto del cliente (ALB), IP:puerto del upstream (MP:8998), upstream_response_time, -, -, status del router, status del upstream, bytes, bytes, request line ("GET /ruta?query HTTP/1.1"), message-id de Apigee (p. ej. scgp1airvmll-apicor-11.sceu.corp-10258-16440062-813), user-agent, host virtual (p. ej. scger-core.apis.sceu.corp), X-Forwarded-For, ..., ruta del proxy (/organizations/scger/environments/core/apiproxies/<proxy>/revisions/<n>), basepath, ..., request_time como último campo numérico.
- El x-amzn-trace-id NO se registra.

QUÉ DEBE HACER EL SCRIPT
1. Mostrar el hostname, la zona horaria, y la primera y última fecha de cada access log de scger (para saber qué periodo cubren).
2. Buscar un caso concreto: petición GET a /applications/v1/75792/participants entre 2026-11-10T13:24 y 13:26 (hora local) en scger~core. Mostrar la línea completa.
3. Para los días 2026-10-29, 2026-10-30 y 2026-11-10, en los entornos core e intranet-client:
   - Contar las respuestas con status 502, 503 y 504, agrupadas por día y por IP del upstream (MP).
   - Listar las peticiones con request_time entre 55 y 61 s: timestamp, status del router, status del upstream, upstream_response_time, MP, proxy y message-id.
   - Agruparlas por hora y por proxy.
4. En los error logs de esas fechas, contar y mostrar ejemplos de "upstream timed out", "upstream prematurely closed", "Connection reset" y "no live upstreams", agrupados por upstream.
5. Para los message-id encontrados en el punto 3 cuyo MP sea el nodo local, buscarlos en el system.log del MP y mostrar las líneas relacionadas.
6. Extraer los valores de timeout y keep-alive configurados: proxy_read_timeout, proxy_connect_timeout, proxy_send_timeout, keepalive y keepalive_timeout de los .conf de scger_core e scger_intranet-client, y cualquier propiedad con "timeout" o "keepalive" en los .properties de customer.

REQUISITOS
- Solo lectura: no modificar, mover ni reiniciar nada.
- Bajo impacto: usar nice/ionice, filtrar por fecha antes de procesar y usar zgrep o zcat para los .gz. Nunca hacer cat de ficheros enteros por pantalla.
- Solo bash, grep, awk y sed, sin instalar paquetes.
- Enmascarar las query strings de las URLs, que contienen IDs de clientes (sustituir lo que va detrás de "?" por "?<redacted>").
- Guardar la salida en /tmp/apigee_504_diag_<hostname>_<fecha>.txt y un CSV con las peticiones de ~60 s. Al final, imprimir un resumen corto.
- Parametrizar al principio las fechas, los entornos y el umbral de segundos para poder reutilizarlo.
- Opcional: un segundo script que lo lance en los tres nodos con "aws ssm send-command" y recoja los resultados. Dejar los instance IDs como variables.

Explica brevemente cada bloque del script y cómo interpretar los resultados.
