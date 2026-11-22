### Entrega Nro.4

### Instalación y configuración de SQL server

### 

### 

### Materia: Bases de datos aplicadas

### Año lectivo: 2026

### Integrantes del grupo:

### 

| Nombre y apellido | Mail institucional |
| :---- | :---- |
| Battistelli, Nahuel |  |
| Chiaravalle, Matias Ezequiel |  |
| Mussi Pulcini, Agustín Nicolás |  |
| Ruiz, Alex Uriel |  |

### 

### Requisitos de hardware y software

Como aclaración, se seleccionó el motor Microsoft SQL Server 2022 (edición standard).

* **Sistema operativo**: Windows server 2022 o Windows 10/11 (64 bits en ambos casos).  
* **Procesador**: Mínimo 4 núcleos, pero se recomiendan 8 para poder soportar los picos de escritura durante los partidos.  
* **RAM**: Se recomienda un mínimo de 16 GB de RAM.  
* **Almacenamiento**: Es recomendable usar discos del tipo SSD y NVMe.

### Ubicación de Archivos y Estructura de Discos

Para un entorno de producción o un despliegue profesional, nunca debe dejar todo en la partición por defecto del sistema operativo (por ejemplo, C:\\). Si se llena el disco, se cae el motor entero.

* **Directorio Raíz de Instalación (Binarios del Motor)**:  
  * Ruta por defecto: C:\\Program Files\\Microsoft SQL Server\\MSSQL16.MSSQLSERVER\\MSSQL\\ (o la versión correspondiente del año del motor).  
* **Buenas prácticas de separación en discos**:  
  * Disco de Datos de Usuario (.mdf): Ubicarlo en una unidad dedicada y rápida (ej: D:\\SQLData\\).  
  * Disco de Logs de Transacciones (.ldf): Ubicarlo en otra unidad independiente (ej: E:\\SQLLogs\\). Separar los logs de los datos mejora drásticamente el rendimiento de escritura (I/O) y asegura la recuperación ante desastres.  
  * Base Temporal (tempdb): Ubicarla en el almacenamiento más rápido disponible (ej: F:\\SQLTempdb\\), ya que soporta todas las operaciones temporales y ordenamientos masivos del sistema.  
  * Unidad de Backups: Ubicarla en un disco de gran capacidad o almacenamiento secundario (ej: G:\\SQLBackups\\).

### Configuración de Memoria

Por defecto, SQL Server intentará consumir toda la memoria RAM disponible en el sistema operativo a medida que la necesite, lo cual puede colgar el servidor si cohabita con otros servicios.

* **Parámetros a configurar**:  
  * Memoria Mínima del Servidor (min server memory): Se suele dejar en 0 o en un valor base si se quiere garantizar una reserva fija.  
  * Memoria Máxima del Servidor (max server memory): Es el parámetro crítico que se debe configurar obligatoriamente. Para calcularlo, se le resta al total de RAM la memoria que necesita el Sistema Operativo (generalmente se dejan libres entre 2 GB y 4 GB o un 10-20% del total de la RAM del servidor para Windows). Por ejemplo, si el servidor tiene 16 GB de RAM, se configura un max server memory de aproximadamente 12288 MB (12 GB) para evitar que el motor ahogue al SO.

### Seguridad

* **Modo de Autenticación**:  
  * Se debe configurar la Autenticación Mixta (SQL Server and Windows Authentication mode). Esto permite mantener la seguridad integrada de Windows pero habilita la creación de usuarios propios del motor SQL para las aplicaciones cliente que lo requieran.  
* **Cuenta de Servicio**:  
  * Se recomienda el uso de cuentas de servicio dedicadas de Windows con privilegios mínimos (Principle of Least Privilege) en lugar de usar cuentas de administrador o Local System para correr los servicios de SQL Server.  
* **Contraseña segura**:   
  * Se debe asignar una contraseña que cumpla los estándares de seguridad, y una vez que se cree un usuario administrativo, es recomendable deshabilitar la cuenta sa (sysadmin) que SQL crea por defecto al seleccionar el modo de Autenticación Mixta.  
* **Roles y cifrado**:  
  * Los usuarios deberían acceder solamente mediante roles asignados, sin acceso directo a las tablas.

### Aspectos Adicionales Clave

* **Intercalación (Collation)**: Se debe seleccionar el estándar adecuado para la región (por ejemplo, SQL\_Latin1\_General\_CP1\_CI\_AS o Modern\_Spanish\_CI\_AS), el cual define cómo se ordenan y comparan las cadenas de texto sin distinción de mayúsculas/minúsculas (Case-Insensitive).  
* **Red y Puertos**: Ell motor escucha en el puerto TCP predeterminado (1433) y se deben configurar las reglas correspondientes en el Firewall de Windows para permitir las conexiones de los clientes de forma segura.

