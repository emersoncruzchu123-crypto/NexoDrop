# Protocolo experimental de transferencia local, v1

TCP, puerto predeterminado 45873; una transferencia activa por instancia.
El receptor genera una clave aleatoria de 256 bits por sesión de recepción.
El usuario comunica esa clave y la dirección mediante un URI `nexodrop` fuera
del canal de transferencia. No se transmite la clave por el socket.

Cada mensaje tiene un prefijo big-endian de cuatro bytes con su longitud,
seguido de nonce de 12 bytes, contenido cifrado AES-256-GCM y etiqueta de 16 bytes.
Se rechazan mensajes mayores de 100000 bytes antes de reservar el contenido.
`package:cryptography` genera los nonces. El JSON interno contiene metadatos o
un bloque de hasta 64 KiB codificado en base64. La memoria del transporte no
crece con el tamaño completo del archivo; base64 sí añade coste y tráfico.

Secuencia:

1. Oferta cifrada: ID aleatorio, nombre, tamaño y SHA-256 calculado del archivo.
2. Aceptación explícita del receptor, con vencimiento de 60 segundos.
3. Bloques cifrados con ID y número de secuencia en los datos autenticados (AAD).
4. Fin explícito autenticado, incluso para archivos vacíos.
5. El receptor verifica tamaño y SHA-256, renombra el archivo parcial y confirma.

Las respuestas, datos y fin utilizan contextos AAD separados. El receptor
rechaza IDs de oferta repetidos durante la sesión. Tras 1000 ofertas autenticadas
se debe reiniciar recepción para renovar la clave y el registro de repeticiones.
Una clave incorrecta, modificación del mensaje o secuencia incorrecta falla la
autenticación. No se guarda un archivo final si falla su integridad. Los nombres
se normalizan y se utiliza una carpeta única, sin sobreescritura de destinos.

Cancelación o desconexión elimina el parcial cuando termina el manejador. Un
cierre forzado del proceso puede dejar un `.part` (no aparece como recibido).
Si se pierde la confirmación después del guardado, el receptor puede conservar
el archivo y el emisor informar fallo: no se promete entrega exactamente una vez.

## Límites de seguridad

Diseño experimental con pruebas automatizadas, sin auditoría independiente.
Quien posea el código de conexión puede solicitar una transferencia; todavía
se requiere aceptación en pantalla. No hay identidad persistente del dispositivo
ni secreto hacia adelante. El código debe intercambiarse por un medio confiable.
Las direcciones IP, tamaños aproximados y tiempos de tráfico no se ocultan.

Los tiempos de espera y límites de tamaño reducen uso descontrolado de recursos,
pero no impiden que un equipo en la LAN ocupe temporalmente el único receptor.
No hay cuota de disco ni reanudación automática. Error de disco aborta recepción.
No se abren puertos del router ni se modifica el firewall del sistema.


## Sesión de usuario (1.0 en progreso)

El QR ahora anuncia el servidor de control TCP 45874. La clave de 256 bits protege
el saludo, un desafío aleatorio de cada extremo, confirmación y mensajes de
control. Los extremos intercambian cifradas las claves y puertos del transporte
de archivos; la IP utilizada siempre se obtiene del socket, no de datos enviados
por el otro dispositivo. Los mensajes de control autentican sesión, dirección y
secuencia, y se serializan para evitar escrituras simultáneas entre latidos y roles.

Un extremo coordina los roles para que ambos no queden enviando al mismo tiempo.
Los mensajes de ocupación bloquean cambios de rol durante una transferencia.
Hay latidos cada 20 segundos y un tiempo de lectura máximo de 90 segundos. La
interfaz genera una nueva vinculación al desconectarse; no persiste las claves.
El transporte de archivos exige el identificador secreto de la sesión vigente
y el rol Recibir antes de mostrar la confirmación de recepción.


### Revisión 1.0.1

El canal de control autenticado ya no caduca por inactividad entre mensajes.
Los latidos se siguen enviando; el cierre del socket termina la sesión. Antes
de cada envío se intercambia ping/pong autenticado con un identificador
aleatorio y un límite de 15 segundos. La falta de respuesta cierra la sesión.
Se mantiene el límite de 90 segundos para completar una trama ya iniciada y
para las operaciones del transporte de archivos.

Los datos se escriben en un archivo oculto .nexodrop-<id>.part en la carpeta
de destino. Solo después de comprobar SHA-256 se reserva un nombre único
(exclusivo) y se publica el archivo. Al fallar se elimina el parcial. Los
archivos finales se guardan todos en la carpeta NexoDrop.


### Guardado Android 1.0.2

Después de verificar SHA-256, el receptor Android publica la copia en la carpeta
pública Descargas/NexoDrop mediante MediaStore. Solo después de publicar y
persistir el historial responde con la confirmación de éxito. Un fallo conserva
la copia privada y no confirma el envío. El emisor espera la confirmación sin
caducar por inactividad durante la copia final, y conserva la opción Cancelar.
El historial es metadato independiente: vaciarlo no borra archivos públicos.
