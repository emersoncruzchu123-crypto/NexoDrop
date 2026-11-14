# NexoDrop

## Instalación Linux desde GitHub

Clona el repositorio y ejecuta el instalador:

```sh
git clone https://github.com/emersoncruzchu123-crypto/NexoDrop.git
cd NexoDrop
bash instalar-linux.sh
```

El script prepara las dependencias que falten, compila la versión release y crea
la entrada en el menú de aplicaciones. Más información: [docs/linux.md](docs/linux.md).
Fedora es la plataforma usada durante el desarrollo; RHEL está pendiente de prueba.

## Compilación Windows en GitHub

El flujo `.github/workflows/windows.yml` compila en Windows x64 al subir cambios
a `main`/`master` o al iniciarlo manualmente. El resultado se descarga desde
Actions como `NexoDrop-Windows-x64`; contiene el ZIP portable y su SHA-256.
Consulta el estado de cada compilación en la pestaña Actions. Las compilaciones correctas generan un paquete descargable; los fallos quedan visibles en sus registros.


Primera implementación para transferir un archivo por red local entre Android y
Linux. Código de escritorio generado también para Windows, pendiente de compilar
y probar allí. Flutter se utiliza en ambas aplicaciones y `shared` concentra la
interfaz y el protocolo.

## Ejecutar

Desde la raíz del proyecto, abre dos terminales en VS Code.

Terminal de escritorio:

```sh
cd desktop
flutter pub get
flutter run -d linux
```

Terminal de Android (con un celular conectado y depuración USB autorizada):

```sh
cd mobile
flutter pub get
flutter devices
flutter run -d ID_DEL_CELULAR
```

Sustituye `ID_DEL_CELULAR` por el identificador que muestre `flutter devices`.
La depuración USB instala y ejecuta la aplicación: esta transferencia usa la red.
Las dependencias y compilaciones iniciales pueden necesitar internet. El envío
entre aplicaciones no utiliza servicios de internet.

## Conectar y compartir (versión 1.0 en progreso)

1. Abre la misma versión de NexoDrop en ambos dispositivos y entra en **Wi-Fi / red local**.
2. La computadora muestra automáticamente su QR. Android tiene **Escanear QR** y
   su propio QR para conectar también otro Android.
3. Escanea una vez. Ambos mostrarán **Dispositivo conectado** y las opciones
   **Enviar** y **Recibir**.
4. Elige **Enviar** en uno; el otro cambia a **Recibir**. Selecciona el archivo,
   pulsa **Enviar archivo** y acepta su recepción en el otro dispositivo.
5. Revisa barra, porcentaje, velocidad media y resultado. Puedes cancelar.
6. Para invertir la dirección, pulsa **Enviar** en el otro dispositivo. La sesión
   se conserva: no vuelvas a escanear mientras siga conectada.

Ambos equipos deben compartir red local, zona Wi-Fi o Ethernet. No hace falta
internet. El intercambio por QR vincula a un solo dispositivo por sesión. Si se
cierra la app o se pierde la conexión, vuelve a vincular con el QR actual.
El protocolo de vinculación requiere actualizar ambos extremos; las versiones
anteriores solo tenían recepción directa y no establecen esta sesión.

En escritorio, los archivos se guardan por defecto en **Descargas/NexoDrop**
(o Documentos/NexoDrop si el sistema no proporciona Descargas). En Android también se guardan automáticamente en la carpeta pública
**Descargas/NexoDrop**, visible desde el administrador de archivos. No hay
botón «Guardar como»: la recepción confirma que el archivo ya quedó guardado.
Todos los archivos completos se guardan directamente en NexoDrop. Los nombres
repetidos reciben sufijos: foto.jpg, foto (1).jpg, etc. Las subcarpetas de
versiones antiguas creadas por NexoDrop se reorganizan al abrir esta versión,
sin sobrescribir archivos ni modificar carpetas ajenas.

El menú tiene solo **Wi-Fi** y **Detalles**. Bluetooth y Cable se retiraron
del diseño; el alcance del producto es compartir por Wi-Fi o zona Wi-Fi.
**Detalles** muestra: desarrollado por EMERSON CRUZ CHUQUIPOMA,
versión 1.0 en progreso y créditos Codex. Incluye el logo del proyecto y términos de uso desplegables.

## Estado y límites

- Tema oscuro y menú inferior en móvil; navegación lateral en pantallas anchas.
- Sesión cifrada, intercambio de roles y transferencias en ambos sentidos.
- Selección de un archivo, aceptación/rechazo, progreso, porcentaje, velocidad
  media, cancelación, AES-256-GCM y comprobación SHA-256.
- Conexión manual opcional cuando el equipo emisor no tiene lector QR.
- Android mantiene un servicio mientras hay una sesión conectada, con una
  notificación «NexoDrop conectado». Puedes cambiar al selector de archivos.
  Desconecta al terminar para detener el servicio y liberar los recursos.
  Cerrar la aplicación, forzar su detención o perder la red sí puede cerrar la sesión.
- Linux y Android compilados y probados automáticamente. Windows tiene el mismo
  código de interfaz, pero todavía no se ha compilado ni probado allí.
- Pendiente: descubrimiento automático, envío múltiple y reanudación.
- Si la red bloquea conexiones, revisar aislamiento de clientes y permitir TCP
  **45873** (archivos) y **45874** (sesión) en la red local. La aplicación no modifica
  el firewall. Esto aplica en ambos extremos para transferir en ambas direcciones.
- El QR es privado e incluye la clave completa. El lector Android viene incluido
  en el APK para funcionar sin internet desde el primer uso.

## Verificar

```sh
cd shared
flutter pub get
flutter analyze
flutter test
```

Las aplicaciones tienen además pruebas de pantalla con `flutter test` desde
`mobile` o `desktop`. No hay publicación ni instalador de producción; el APK es
de depuración. FTP y otras integraciones USB quedan fuera de esta entrega.

El QR conserva la clave completa del enlace. Compártelo solo con el emisor.
El lector Android incluye el modelo de escaneo dentro del APK y no necesita
descargarlo en su primer uso. Si bloqueas el permiso de cámara, puedes habilitarlo
en Ajustes → Aplicaciones → NexoDrop → Permisos, o utilizar el enlace manual.

## Correcciones 1.0.1

- La sesión no expira por estar esperando la selección de un archivo. El envío
  comprueba que el otro dispositivo responde antes de transferir; los bloques
  de datos incompletos conservan límites de espera. Actualiza ambos extremos.
- La X junto al archivo quita la selección sin borrar el archivo original.
- Un envío confirmado elimina la selección. Un error, rechazo o cancelación la
  conserva para reintentar o quitarla manualmente.
- Los parciales se crean como archivos temporales ocultos dentro de NexoDrop y
  se eliminan al abortar. Solo un archivo verificado recibe su nombre definitivo.
- Android puede pedir permiso de notificaciones al conectar por primera vez.
  El servicio se detiene al desconectar o cerrar la tarea; no reinicia la app
  automáticamente ni pretende sobrevivir a una detención forzada del sistema.


## Guardado automático e historial (1.0.2)

Android publica cada archivo verificado en **Descargas/NexoDrop** usando el
almacenamiento compartido del sistema. La carpeta se reutiliza y los archivos
con el mismo nombre se conservan como copias distintas. Si la publicación falla,
no se confirma el envío y se conserva la copia privada para recuperarla.
Los archivos de versiones anteriores que aún estén dentro de la aplicación se
publican automáticamente al abrir esta actualización.

El **Historial de recibidos** se conserva al cerrar y abrir NexoDrop. El botón
**Borrar todo el historial** elimina la lista, no los archivos guardados; la lista
permanece vacía hasta nuevas recepciones. En Android 10 o posterior no se pide
permiso general de almacenamiento. En Android anterior puede solicitarse ese
permiso una vez para guardar automáticamente en Descargas.


## Identidad y licencia

El código original de NexoDrop está bajo **GNU GPLv3** (GPL-3.0-only).
Consulta [LICENSE](LICENSE) y [NOTICE](NOTICE). Las dependencias mantienen
sus licencias. La licencia completa también se puede leer en Detalles.

- Original del logo: `shared/assets/branding/logo-original.jpg`.
- Regenerar tamaños de iconos: `bash scripts/generate-icons.sh` (ImageMagick).
- Tras compilar Linux, registrar icono y lanzador en Fedora:
  `bash scripts/install-linux-launcher.sh`.
- APK actual: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Ejecutable Fedora: `desktop/build/linux/x64/debug/bundle/nexodrop_desktop`.

Los directorios `build` son generados. El bundle Linux debe conservarse completo
para ejecutar la app. No confundir el historial o los archivos recibidos con
los resultados temporales de compilación y pruebas.


## Windows 10 y 11 (x64)

Adaptación preparada en `desktop/windows`. Para compilar en Windows con Flutter
 y Visual Studio C++, ejecutar `COMPILAR-WINDOWS.cmd`. Genera un ZIP portable en
`dist` con `NexoDrop.exe`, DLL y recursos. El script no instala herramientas.
No se ha generado ni probado el ejecutable desde Fedora. Consulta
[docs/windows.md](docs/windows.md) para el estado y los pasos exactos.
