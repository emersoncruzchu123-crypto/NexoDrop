# Estado de la primera entrega — 8 de noviembre de 2026

## Implementado

- Proyectos Flutter para Android y escritorio Linux/Windows.
- Interfaz y transporte compartidos en `shared`.
- Selección de un archivo, código de conexión privado y aceptación/rechazo.
- Cifrado AES-256-GCM, SHA-256, progreso, velocidad media y cancelación.
- Guardado sin sobreescrituras y eliminación de archivos parciales al abortar.
- Exportación Android mediante el selector de documentos del sistema.
- Configuraciones de depuración para VS Code.

## Comprobado en este entorno

- `flutter analyze` sin incidencias en `shared`, `mobile` y `desktop`.
- Once pruebas del protocolo aprobadas: transferencias vacías y por varios bloques,
  rechazo, clave incorrecta, hash incorrecto, cancelación, límite del encabezado,
  secuencia incorrecta, nombres repetidos y normalización de nombres.
- Una prueba de pantalla aprobada en cada aplicación.
- `flutter build linux --debug` genera el ejecutable en
  `desktop/build/linux/x64/debug/bundle/nexodrop_desktop`.
- `flutter build apk --debug` completado: APK disponible en
  `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- La compilación instaló Android SDK Platform 35, requerido por una dependencia.

No se ha ejecutado la interfaz Linux de forma interactiva ni se han instalado
estas aplicaciones en un teléfono durante esta sesión. Las pruebas de transporte
utilizan sockets TCP reales en loopback, dentro de la misma computadora.

## Pendiente para completar la versión uno

Prueba Android ↔ Linux con dispositivos reales, compilación/prueba en Windows,
Bluetooth y permisos, pruebas de Ethernet/zona Wi-Fi/anclaje USB sin internet.
Ver `pruebas-dispositivos.md`. La conexión inicial es manual; no hay búsqueda
automática, QR, envío múltiple, reanudación ni servicio en segundo plano.

El selector `file_picker` 10.3.10 genera una advertencia sobre la migración futura
a Kotlin integrado en Android Gradle Plugin. Revisar esa dependencia antes de
actualizar Flutter. La firma de Android sigue siendo de depuración.


## Actualización QR — 9 de noviembre de 2026

Versión 0.1.1+2. El receptor muestra un QR con la conexión completa y permite
seleccionar la dirección cuando existen varias interfaces. El enlace largo está
plegado bajo una opción manual. Android incorpora escáner con permiso de cámara,
validación del contenido y cierre explícito de la cámara al salir. Leer el QR
solo prepara el receptor; el usuario todavía selecciona y envía el archivo.
El modelo de lectura está incluido en el APK para funcionar sin internet.

Cinco pruebas adicionales cubren el contenido del código, decodificación de la
imagen QR real al cambiar de red, pantalla estrecha, códigos ajenos, detección
duplicada, liberación de cámara y permiso denegado. La cámara en esas pruebas es
simulada; la decodificación de la imagen QR utiliza un lector independiente.

Cruz confirmó la transferencia real Android → Fedora de la versión anterior y
el uso de la zona Wi-Fi. La prueba completa del nuevo QR con cámara del Redmi
queda pendiente de su confirmación. Bluetooth, cable y cambios estéticos no se
implementan en esta entrega. Windows aún no ha sido compilado ni probado.

Verificación final de esta actualización: 16 pruebas en `shared` y una prueba
de pantalla en cada aplicación (18 en total), todas aprobadas. Análisis de
`shared` sin incidencias. Linux y APK Android compilados correctamente.


## Diseño y sesión bidireccional — 9 de noviembre de 2026

Versión 1.0.0+3 (pantalla: «1.0 · En progreso»). Tema negro, iconos y acentos
turquesa. Cuatro menús adaptables: Wi-Fi/red local, Bluetooth, Cable, Información.
Bluetooth y Cable quedan vacíos; Información contiene los créditos solicitados.

La vinculación ocurre antes de seleccionar archivos. Hay un enlace de control
cifrado persistente con confirmación de desafío y latidos. Los roles se coordinan
por ese enlace: elegir Enviar asigna Recibir al otro dispositivo. Se conserva la
sesión entre archivos y se puede invertir el sentido sin volver a escanear.

El transporte de archivos existente sigue usando conexiones independientes por
archivo, autorizadas por el identificador de la sesión actual y el rol receptor.
La sesión de usuario es única; no se promete un único socket TCP para todo.
Puertos locales: 45873 para archivos y 45874 para control. Ambos requieren
actualización; los QR anteriores no abren este flujo de vinculación.

Pruebas nuevas: transferencia en ambos sentidos con una vinculación, protección
por sesión y rol, clave incorrecta, desconexión, bloqueo de roles durante envío,
menús vacíos, créditos y adaptación móvil/escritorio. Windows sigue pendiente.

Comprobación de esta entrega: 23 pruebas compartidas y una prueba de pantalla
en cada proyecto (25 en total), aprobadas. Análisis sin incidencias. APK
instalado en el Redmi y aplicación nueva abierta en Fedora. El teléfono dejó
de aparecer en ADB después de instalar, por lo que el arranque móvil queda
a cargo de Cruz. La nueva sesión está probada en loopback; falta la prueba
en ambos sentidos con teléfono y computadora. Cruz había confirmado que
el escaneo QR de la entrega anterior funcionaba correctamente.


## Correcciones de conexión, selección y almacenamiento — 14 de noviembre de 2026

Versión 1.0.1+4 para Android y Linux. No se ha compilado Windows.

Se encontró un límite de 90 segundos en la lectura del canal de control. Se
retiró el vencimiento por inactividad de ese canal, manteniendo los límites del
saludo inicial, las tramas incompletas y el transporte de archivos. Los latidos
continúan; antes de enviar se solicita una respuesta autenticada al otro equipo
(con límite de 15 segundos) para no enviar a una sesión que ya no responde.

Android añade un servicio de primer plano de tipo connectedDevice y una
notificación durante la sesión. Mantiene un bloqueo parcial de CPU hasta
desconectar/cerrar para que el proceso continúe mientras se usa el selector.
No se reclama supervivencia a una detención forzada ni a políticas específicas
del fabricante. Falta confirmar el comportamiento del selector real del Redmi.

La selección tiene una X para quitarla. Solo se limpia automáticamente después
de recibir la confirmación del archivo; un fallo o cancelación la conserva.
Los archivos se publican directamente en NexoDrop usando reserva exclusiva del
nombre y sufijos numéricos si ya existe. Los parciales no se presentan como
completos. La migración conserva duplicados, no sigue enlaces simbólicos y
solo elimina subcarpetas reconocidas cuando quedan vacías.

Validación: 34 pruebas compartidas aprobadas, incluida una espera real de 95
segundos sin latidos del emisor seguida de un cambio de rol en la misma sesión.
Pruebas adicionales de disponibilidad, almacenamiento y selección aprobadas.
Análisis sin incidencias y compilaciones Android/Linux completadas.


## Publicación automática en Descargas e historial — 14 de noviembre de 2026

Versión 1.0.2+5. Android publica el archivo verificado en MediaStore.Downloads,
con ruta relativa Download/NexoDrop y estado pendiente hasta terminar la copia.
La confirmación al emisor se envía después de publicar y persistir el historial.
En Android anterior a API 29 se utiliza Descargas con permiso de escritura.
El nuevo guardado sustituye al antiguo selector manual «Guardar como…».

La copia privada solo se elimina después de guardar públicamente y registrar
el historial. Un registro nativo de publicación permite reintentar sin duplicar
el mismo archivo privado después de un cierre. Los archivos privados anteriores
se publican al iniciar. Si falla el guardado, se conserva la copia recuperable.

El historial tiene almacenamiento propio y botón para vaciarlo sin eliminar
archivos. No se reconstruye explorando Descargas al volver a abrir. Las
recepciones nuevas sí se incorporan después de vaciarlo.


Validación de 1.0.2: pruebas de historial, publicación antes de confirmar,
fallo de almacenamiento, sesiones y pantallas aprobadas. Análisis sin incidencias.
Prueba nativa directa en el Redmi (Android 15) aprobada: ruta pública correcta,
contenido de dos archivos homónimos conservado, no duplicación al reintentar y
estado público al finalizar. Los archivos temporales de esa prueba se eliminaron.

Incidencia de pruebas: connectedDebugAndroidTest rechazó instalar el APK auxiliar
(INSTALL_FAILED_USER_RESTRICTED) y su limpieza desinstaló la aplicación principal.
Se informó a Cruz del posible borrado del historial y copias privadas anteriores.
Se reinstaló NexoDrop y se ejecutó la prueba con adb am instrument directamente,
sin limpieza automática de Gradle. Se añadió
android.injected.androidTest.leaveApksInstalledAfterRun=true para impedir esa
limpieza en futuras ejecuciones. No se afirma recuperar datos privados borrados.

## Diseño compacto Wi-Fi — 14 de noviembre de 2026

Pantalla principal con fondo #0A0F0E, tarjetas #171F1D, borde #2A3532,
acento #6FE7C5 y texto secundario #A8B8B2. Conexión y QR comparten una tarjeta;
el QR se amplía al pulsarlo y la conexión manual queda plegada. En Android
se conserva la cámara; Fedora muestra el QR para escanear desde el celular.
La dirección mostrada es la real, no la IP de ejemplo del diseño.

Actividad muestra los recibidos presentes en el historial y los envíos
confirmados desde que se abrió la app (contador de presentación, no persistente).
El historial tiene desplazamiento propio, tamaño y fecha, icono según extensión
y botón Abrir. Android abre con una aplicación compatible y permiso temporal
de lectura; Linux usa xdg-open. Estas acciones no cambian el almacenamiento.

La vista vacía completa se verificó en 390 × 844 con fuentes reales; también
se revisaron 360 × 800 y 1280 × 800 sin desbordes. Se permite desplazamiento
cuando se expande la conexión manual o aumenta el contenido. Se conserva el
scroll para pantallas pequeñas y accesibilidad.

Compilaciones locales Android y Linux correctas, análisis sin incidencias.
Pruebas de pantalla, QR ampliado, metadatos e historial y regresión del transporte
comprobadas; incluida sesión inactiva de 95 segundos. Los manejadores existentes
de conexión, envío, recepción y guardado se compararon con la versión anterior.
No se instaló ni se ejecutó esta actualización en el celular. La apertura nativa
de archivos requiere comprobación posterior en el Redmi. Windows no se compiló
ni se modificó su integración nativa; su futura compilación usa la UI compartida.

## Identidad, términos y limpieza — 14 de noviembre de 2026

Android y Fedora actualizados a 1.0.3+6. Créditos: Codex. Nombre del autor
más pequeño y atenuado; términos desplegables y licencia GPLv3 elegida por Cruz.
Logo original conservado en shared/assets/branding, con tamaños Android/Linux
reproducibles mediante scripts/generate-icons.sh. Lanzador Fedora registrado
con scripts/install-linux-launcher.sh; usa la ruta del icono del proyecto.
Las pruebas de navegación pasaron y ambas compilaciones se completaron.
Android instalado con adb install -r; Fedora actualizado y abierto.

Tras la confirmación de Cruz se eliminaron cachés de pruebas, recursos de
pruebas, APK auxiliar Android, resultados/intermedios de instrumentación y
capturas/copias temporales de esta sesión. Se conservaron las compilaciones
actuales, recursos, fuentes, pruebas fuente y los datos recibidos del usuario.
No había una colección de versiones anteriores de la app para eliminar;
los APK de app/outputs/apk/debug y flutter-apk son salidas de la compilación
actual. Se conserva la caché de compilación útil para continuar desarrollando.

Revisión Windows detallada en windows.md. Existe la base nativa y la interfaz
compartida, pero no un ejecutable Windows validado. Pendientes: identidad del
runner, apertura de archivos, nombres reservados y compilación/pruebas reales.

## Adaptación Windows — 14 de noviembre de 2026

Preparados icono, metadatos, apertura nativa del historial, nombres reservados
Windows y script de compilación/empaquetado. Se reutilizan interfaz y transporte
compartidos, sin duplicar la app de Fedora. Ver windows.md.
Cruz indicó que no se instalen máquinas virtuales; no se instaló ninguna.
No hay entorno Windows disponible, por lo que no se generó un .exe y no se
considera validada la integración nativa. Se realizó una única prueba local
con plataforma visual Windows y casos de nombres compatibles.
