# NexoDrop

Comparte archivos entre Android y computadoras por Wi-Fi o por la zona Wi-Fi
del celular, sin necesitar internet durante la transferencia.

Proyecto de código abierto **GNU GPLv3**, desarrollado por **EMERSON CRUZ
CHUQUIPOMA**, con créditos a **Codex**. Versión **1.0.3 · En progreso**.

## Descargar

[Descargas de la versión 1.0.3](https://github.com/emersoncruzchu123-crypto/NexoDrop/releases/tag/v1.0.3)

- **Android:** `NexoDrop-1.0.3-Android.apk`. Versión de prueba, firmada con la
  misma clave de desarrollo utilizada en el Redmi de prueba.
- **Windows 10/11 x64:** `NexoDrop-1.0.3-6-Windows-x64.zip`. Extrae el ZIP completo
  y abre `NexoDrop.exe`. Conserva las DLL y la carpeta `data` junto al ejecutable.
  No necesitas Flutter ni Visual Studio para usar el paquete compilado.
- **Fedora / familia Red Hat:** instala desde el código con los pasos siguientes.

Las descargas incluyen archivos SHA-256. La versión Windows no está firmada
digitalmente. Estas son versiones preliminares, no una entrega final.

## Instalar en Linux

```sh
git clone https://github.com/emersoncruzchu123-crypto/NexoDrop.git
cd NexoDrop
bash instalar-linux.sh
```

El instalador prepara las dependencias de compilación mediante `dnf` si faltan,
descarga Flutter oficial si es necesario, compila y añade NexoDrop al menú del
usuario. La primera instalación necesita internet y espacio para las herramientas.
La app se instala en una carpeta propia del usuario y después no depende de
conservar el repositorio clonado.

**Comprobado en Fedora x86_64.** RHEL/Rocky/AlmaLinux aún requieren pruebas reales;
no se garantiza compatibilidad con todas sus versiones o repositorios.
Más detalles en [docs/linux.md](docs/linux.md).

## Compartir un archivo

1. Conecta ambos dispositivos a la misma red Wi-Fi o a la zona Wi-Fi del celular.
2. Abre NexoDrop y escanea el QR con la cámara de la app Android.
3. Elige **Enviar** en un dispositivo y **Recibir** en el otro.
4. Selecciona el archivo y acepta la transferencia en el receptor.
5. Consulta el progreso y el resultado de la verificación.

Los archivos se guardan automáticamente en **Descargas/NexoDrop**. Borrar el
historial solo limpia la lista: no elimina archivos. Puedes quitar la selección
antes de enviar o cancelar una transferencia.

NexoDrop usa una sesión cifrada, aceptación del receptor y comprobación de
integridad. No envía tus archivos a servidores externos. El QR contiene la clave
de vinculación: compártelo solo con el dispositivo que deseas conectar.

Si la conexión no funciona, verifica que ambos equipos estén en la misma red,
que no haya aislamiento de clientes y que el firewall permita la app en la red
privada. Se utilizan TCP **45873** y **45874**; la app no cambia el firewall.

## Estado de las plataformas

| Plataforma | Estado |
| --- | --- |
| Android | Compilada, instalada y probada en Redmi con Android 15. |
| Fedora | Compilación release e instalación desde un clon comprobadas. |
| Windows x64 | Compilación release y empaquetado correctos en GitHub Actions; falta probar uso y transferencias en Windows 10/11. |
| RHEL y derivados | Instalador preparado; pruebas de compatibilidad pendientes. |

## Código y compilación

- `mobile/`: aplicación Android e integración nativa.
- `desktop/`: aplicación de escritorio y runners Linux/Windows.
- `shared/`: diseño, conexión, transferencias, historial y pruebas compartidos.
- `scripts/`: compilación, iconos y lanzador.
- `docs/`: documentación y estado del proyecto.

Para desarrollar se utiliza Flutter **3.44.5**. En Windows, con Flutter y
Visual Studio C++ instalados, ejecuta `COMPILAR-WINDOWS.cmd`. En GitHub, el flujo
[Compilar NexoDrop para Windows](https://github.com/emersoncruzchu123-crypto/NexoDrop/actions/workflows/windows.yml)
genera el ZIP portable y su checksum. No instala máquinas virtuales en tu PC.

Consulta [docs/windows.md](docs/windows.md) y [docs/windows-uso.txt](docs/windows-uso.txt).
Los archivos generados, claves y cachés no se incluyen en el repositorio.

## Licencia

El código original se distribuye bajo **GNU GPLv3 (GPL-3.0-only)**.
Consulta [LICENSE](LICENSE) y [NOTICE](NOTICE). Las dependencias mantienen
sus licencias y avisos. El logo original está en `shared/assets/branding`.
