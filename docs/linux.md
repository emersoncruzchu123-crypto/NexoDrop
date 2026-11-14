# Instalar en Fedora y sistemas de la familia Red Hat

Instalación desde el repositorio:

```sh
git clone https://github.com/emersoncruzchu123-crypto/NexoDrop.git
cd NexoDrop
bash instalar-linux.sh
```

El instalador compila una versión release para Linux x86_64 y la registra en el
menú de aplicaciones del usuario. Si faltan dependencias, usa dnf y solicita
la contraseña de sudo. Si Flutter no está instalado, descarga Flutter 3.44.5
oficial en la caché del usuario. La primera instalación necesita internet,
espacio para el SDK y tiempo de compilación. Las transferencias no usan internet.

El bundle completo se copia a ~/.local/share/nexodrop/releases (o XDG_DATA_HOME)
y no depende de que conserves el checkout de GitHub. No modifica los archivos
recibidos ni el historial. Conserva instalaciones anteriores para no romper una
instancia abierta durante la actualización.

Fedora es el sistema usado durante el desarrollo. En RHEL/Rocky/AlmaLinux el
procedimiento depende de que los repositorios habilitados proporcionen GTK 3,
Clang, CMake, Ninja y una biblioteca C++ compatible con Flutter. Aún no se ha
validado en una instalación real de RHEL; no se afirma compatibilidad universal
con todas sus versiones. El script muestra cualquier error de compilación y
no registra una instalación si no se pudo construir.

Ejecutable actual de desarrollo en esta laptop:
`desktop/build/linux/x64/debug/bundle/nexodrop_desktop`.
Debe conservarse junto a `lib` y `data`.


Instalación verificada el 14 de noviembre de 2026 desde un clon recién preparado:
compilación release correcta y registro en el menú del usuario. La instalación
verificada está en Fedora; no se ha realizado esta prueba en RHEL.
