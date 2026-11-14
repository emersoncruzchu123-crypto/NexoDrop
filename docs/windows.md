# Adaptación Windows 10 y 11 x64 — 14 de noviembre de 2026

Estado: adaptación de código preparada; pendiente de compilación y prueba en
Windows. No existe todavía un ejecutable Windows generado. No se instalaron
máquinas virtuales ni herramientas Windows en Fedora.

## Incluido

- Misma aplicación Flutter compartida con Fedora: diseño oscuro, Wi-Fi,
  Detalles, QR ampliable, roles de envío/recepción, progreso, cancelación,
  cifrado, verificación de integridad, guardado e historial.
- Logo actual como icono multirresolución del ejecutable y metadatos de NexoDrop.
- Nombre de salida: NexoDrop.exe. Manifiesto compatible con Windows 10/11.
- Abrir desde el historial usa ShellExecuteExW y la asociación de archivos de
  Windows. Las rutas se convierten de UTF-8 a UTF-16, sin construir comandos.
- Recepción protege nombres reservados de Windows (CON, NUL, COM1, etc.),
  espacios/puntos finales y truncamiento de nombres Unicode. Esta adaptación
  de nombres solo se aplica al guardar en Windows.
- Descargas/NexoDrop y almacenamiento local de historial mediante los proveedores
  de Flutter que ya declara el proyecto. No hay un servicio Android en Windows.
- Empaquetado portable con ejecutable, DLL, data, licencia y notas. CMake incorpora
  las bibliotecas de ejecución de Visual C++ que detecte el entorno compilador.

## Compilar en Windows

Requisitos: Windows x64, Flutter 3.44.5 (versión utilizada en Fedora) y Visual
Studio con «Desarrollo para el escritorio con C++» y Windows SDK.
No basta Visual Studio Code. El script no instala estos requisitos.

1. Copiar o extraer el proyecto completo en una carpeta del usuario.
2. Ejecutar COMPILAR-WINDOWS.cmd. Alternativamente:
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-windows.ps1`
3. La salida será `dist/NexoDrop-1.0.3-6-Windows-x64.zip` y su SHA-256.
4. Extraer todo el ZIP en el equipo de pruebas y abrir NexoDrop.exe.

El script prepara dependencias y ejecuta `flutter build windows --release`. Solo empaqueta si el proceso termina correctamente
y existen el ejecutable y los recursos esenciales. No lanza pruebas, no abre
la app, no cambia el firewall ni instala máquinas virtuales. La conexión a
internet se necesita para preparar herramientas/dependencias, no para transferir.

## Comprobación realizada

Una única prueba automatizada en Fedora: `flutter test
test/windows_compatibility_test.dart` dentro de shared. Comprueba la presentación
con plataforma Windows y el tratamiento de nombres de archivo. No ejecuta
Win32, no compila C++ y no reemplaza probar las transferencias en Windows.

Pendiente: compilar el código nativo, abrir la app en Windows 10/11, transferir
con Android en ambos sentidos, abrir recibidos, comprobar el firewall y validar
la distribución portable en una máquina sin herramientas de desarrollo.

## Referencias

- Flutter: https://docs.flutter.dev/platform-integration/windows/setup
- Microsoft, apertura nativa: https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-shellexecuteexw
- Microsoft, nombres reservados: https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file


## Revisión previa a GitHub — 14 de noviembre de 2026

Corregido el script: Flutter 3.44.5 selecciona la arquitectura del equipo y no
admite --target-platform para build windows. El script ahora exige un equipo
x64 y utiliza flutter build windows --release.

La dependencia transitiva JNI se mantiene para Android, pero la configuración
Windows desactiva su detección de Java: Windows usa Win32 para archivos y no
utiliza el escáner Android. Se evita enlazar la app a la JVM del constructor.
No se modificaron las dependencias ni la configuración Android/Linux.

Revisados canal nativo del historial, icono, manifiesto 10/11, nombres de archivo,
rutas de recursos y paquete portable. La verificación local no compila el código
C++ ni ejecuta PowerShell; esa validación sigue pendiente del constructor Windows.
No se subió código ni se inició ninguna compilación en GitHub.
