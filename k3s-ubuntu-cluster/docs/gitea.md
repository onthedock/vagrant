# Gitea

Desplegamos Gitea a través de la Helm Chart oficial y un fichero de configuración.

## *Secret* con la contraseña del administrador

Especificando una contraseña de administrador en el fichero de configuración de Helm, el *password* queda expuesto y potencialmente publicado al subir el fichero a GitHub.

Para evitarlo, desplegamos un *secret* con la contraseña inicial (`tempPassword`). Tras la instalación, usamos la API de Gitea para cambiar la contraseña del administrador y actualizar el contenido del *secret*.

De esta forma, sólo es posible acceder a Gitea mediante las credenciales almacenadas en el *secret* en Kubernetes, al que un usuario legítimo tiene acceso.

El *script* se puede ejecutar múltiples veces, actaulizando la contraseña en cada ejecuciín (aunque el *script*) también guarda la contraseña anterior a la actual en el *secret*.

## Usuario no administrador

El *script* de despliegue también permite crear un usuario no administrador.
