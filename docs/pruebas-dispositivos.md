# Validación pendiente con dispositivos reales

Registrar modelo de Android, versión del sistema, versión de NexoDrop y sistema
de escritorio. Tener internet para instalar/compilar no demuestra que se use
internet para transferir: deshabilitar el acceso a internet en las pruebas.

| Conexión | Android → Linux | Linux → Android | Windows |
| --- | --- | --- | --- |
| Misma Wi-Fi sin salida a internet | Pendiente | Pendiente | Pendiente |
| PC por Ethernet, celular en la misma LAN | Pendiente | Pendiente | Pendiente |
| Zona Wi-Fi del celular, datos móviles apagados | Pendiente | Pendiente | Pendiente |
| Cable de datos + anclaje USB, datos móviles apagados | Pendiente | Pendiente | Pendiente |
| Bluetooth | No implementado | No implementado | No implementado |

Para cada conexión:

1. Enviar un archivo pequeño y uno de varios cientos de MB.
2. Confirmar progreso, velocidad media y mensajes de verificación en ambos extremos.
3. Abrir el archivo recibido; en Android exportarlo con **Guardar como…**.
4. Rechazar una solicitud y comprobar que no aparece un archivo recibido.
5. Cancelar desde cada extremo y desconectar la red durante otro envío.
6. Repetir un nombre y comprobar que se conservan ambos archivos.
7. Probar un código anterior después de reiniciar recepción: debe fallar.
8. Reiniciar Android y comprobar que el archivo recibido sigue en la lista.

Anotar errores, duración y tamaño. El teléfono y el equipo deben compartir una
red IP; la depuración USB por sí sola no crea el transporte de anclaje USB.
Bluetooth exige investigar APIs, permisos y compatibilidad antes de implementarlo.
