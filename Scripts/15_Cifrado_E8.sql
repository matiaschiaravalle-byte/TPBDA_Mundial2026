/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: ENTREGA 8 - Cifrado de datos sensibles (AES_256) mediante
             Master Key, Certificado y Clave Simétrica.
             Aplica cifrado a la columna Documento de op.Jugador,
             op.CuerpoTecnico y op.Arbitro, elimina el texto plano y
             actualiza los SPs afectados.
             Ejecutar después de 01 a 14.
========================================================================= */

USE Mundial2026;
GO

-- =========================================================================
-- 1. INFRAESTRUCTURA DE CIFRADO (Master Key -> Certificado -> Clave AES_256)
-- =========================================================================
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Mundial2026#MasterKey!Strong';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'Cert_Mundial2026')
BEGIN
    CREATE CERTIFICATE Cert_Mundial2026
    WITH SUBJECT = 'Certificado para cifrado de datos sensibles - Mundial 2026';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'Key_DatosSensibles')
BEGIN
    CREATE SYMMETRIC KEY Key_DatosSensibles
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE Cert_Mundial2026;
END
GO

-- =========================================================================
-- 2. AGREGAR COLUMNAS CIFRADAS (VARBINARY) EN TABLAS CON DATOS SENSIBLES
-- =========================================================================
IF COL_LENGTH('op.Jugador', 'DocumentoCifrado') IS NULL
    ALTER TABLE op.Jugador ADD DocumentoCifrado VARBINARY(256) NULL;

IF COL_LENGTH('op.CuerpoTecnico', 'DocumentoCifrado') IS NULL
    ALTER TABLE op.CuerpoTecnico ADD DocumentoCifrado VARBINARY(256) NULL;

IF COL_LENGTH('op.Arbitro', 'DocumentoCifrado') IS NULL
    ALTER TABLE op.Arbitro ADD DocumentoCifrado VARBINARY(256) NULL;
GO

-- =========================================================================
-- 3. SP PARA CIFRAR DATOS EXISTENTES Y ELIMINAR COLUMNAS EN TEXTO PLANO
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_MigrarYCifrarDatosSensibles
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY Key_DatosSensibles DECRYPTION BY CERTIFICATE Cert_Mundial2026;

    -- Migrar texto plano a binario cifrado (sólo si todavía existe la columna Documento)
    IF COL_LENGTH('op.Jugador', 'Documento') IS NOT NULL
    BEGIN
        EXEC('UPDATE op.Jugador SET DocumentoCifrado = ENCRYPTBYKEY(KEY_GUID(''Key_DatosSensibles''), Documento) WHERE Documento IS NOT NULL AND DocumentoCifrado IS NULL;');
        ALTER TABLE op.Jugador DROP COLUMN Documento;
    END

    IF COL_LENGTH('op.CuerpoTecnico', 'Documento') IS NOT NULL
    BEGIN
        EXEC('UPDATE op.CuerpoTecnico SET DocumentoCifrado = ENCRYPTBYKEY(KEY_GUID(''Key_DatosSensibles''), Documento) WHERE Documento IS NOT NULL AND DocumentoCifrado IS NULL;');
        ALTER TABLE op.CuerpoTecnico DROP COLUMN Documento;
    END

    IF COL_LENGTH('op.Arbitro', 'Documento') IS NOT NULL
    BEGIN
        EXEC('UPDATE op.Arbitro SET DocumentoCifrado = ENCRYPTBYKEY(KEY_GUID(''Key_DatosSensibles''), Documento) WHERE Documento IS NOT NULL AND DocumentoCifrado IS NULL;');
        ALTER TABLE op.Arbitro DROP COLUMN Documento;
    END

    CLOSE SYMMETRIC KEY Key_DatosSensibles;
END;
GO

-- Ejecutar la migración de cifrado sobre los datos existentes
EXEC cfg.usp_MigrarYCifrarDatosSensibles;
GO

-- =========================================================================
-- 4. ACTUALIZAR SPs AFECTADOS PARA GUARDAR SIEMPRE CIFRADO
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaJugador
    @IdPlantel INT, @IdClub INT, @Nombre VARCHAR(100), @Apellido VARCHAR(100), @Nacionalidad VARCHAR(50),
    @Documento VARCHAR(30) = NULL, @FechaNacimiento DATE = NULL, @PosicionHabitual VARCHAR(50) = NULL, @Dorsal INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF NOT EXISTS (SELECT 1 FROM op.Plantel WHERE IdPlantel = @IdPlantel) SET @Err += 'El plantel no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Club WHERE IdClub = @IdClub) SET @Err += 'El club no existe. | ';
    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = '' SET @Err += 'El nombre no puede estar vacío. | ';
    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = '' SET @Err += 'El apellido no puede estar vacío. | ';
    IF @Nacionalidad IS NULL OR LTRIM(RTRIM(@Nacionalidad)) = '' SET @Err += 'La nacionalidad es obligatoria. | ';
    IF LEN(@Err) > 0 THROW 50001, @Err, 1;

    OPEN SYMMETRIC KEY Key_DatosSensibles DECRYPTION BY CERTIFICATE Cert_Mundial2026;

    INSERT INTO op.Jugador (IdPlantel, IdClub, Nombre, Apellido, Nacionalidad, DocumentoCifrado, FechaNacimiento, PosicionHabitual, Dorsal)
    VALUES (@IdPlantel, @IdClub, @Nombre, @Apellido, @Nacionalidad,
            CASE WHEN @Documento IS NOT NULL THEN ENCRYPTBYKEY(KEY_GUID('Key_DatosSensibles'), @Documento) END,
            @FechaNacimiento, @PosicionHabitual, @Dorsal);

    CLOSE SYMMETRIC KEY Key_DatosSensibles;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_AltaCuerpoTecnico
    @IdSeleccion INT, @IdPlantel INT, @Nombre VARCHAR(100), @Tipo VARCHAR(50),
    @Documento VARCHAR(30) = NULL, @FechaNacimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion) SET @Err += 'La selección no existe. | ';
    IF @Tipo NOT IN ('DT', 'Ayudante') SET @Err += 'El tipo debe ser DT o Ayudante. | ';
    IF LEN(@Err) > 0 THROW 50128, @Err, 1;

    OPEN SYMMETRIC KEY Key_DatosSensibles DECRYPTION BY CERTIFICATE Cert_Mundial2026;

    INSERT INTO op.CuerpoTecnico (IdSeleccion, IdPlantel, Nombre, Tipo, DocumentoCifrado, FechaNacimiento)
    VALUES (@IdSeleccion, @IdPlantel, @Nombre, @Tipo,
            CASE WHEN @Documento IS NOT NULL THEN ENCRYPTBYKEY(KEY_GUID('Key_DatosSensibles'), @Documento) END,
            @FechaNacimiento);

    CLOSE SYMMETRIC KEY Key_DatosSensibles;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarCuerpoTecnico
    @IdCuerpoTecnico INT, @Nombre VARCHAR(100), @Tipo VARCHAR(50), @Documento VARCHAR(30) = NULL, @FechaNacimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.CuerpoTecnico WHERE IdCuerpoTecnico = @IdCuerpoTecnico) THROW 50129, 'El integrante de cuerpo técnico no existe.', 1;

    OPEN SYMMETRIC KEY Key_DatosSensibles DECRYPTION BY CERTIFICATE Cert_Mundial2026;

    UPDATE op.CuerpoTecnico
    SET Nombre = @Nombre,
        Tipo = @Tipo,
        DocumentoCifrado = CASE WHEN @Documento IS NOT NULL THEN ENCRYPTBYKEY(KEY_GUID('Key_DatosSensibles'), @Documento) ELSE DocumentoCifrado END,
        FechaNacimiento = @FechaNacimiento
    WHERE IdCuerpoTecnico = @IdCuerpoTecnico;

    CLOSE SYMMETRIC KEY Key_DatosSensibles;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_AltaArbitro
    @Nombre VARCHAR(100), @Apellido VARCHAR(100), @Nacionalidad VARCHAR(50), @Categoria VARCHAR(50),
    @Documento VARCHAR(30) = NULL, @FechaNacimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = '' SET @Err += 'El nombre es obligatorio. | ';
    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = '' SET @Err += 'El apellido es obligatorio. | ';
    IF @Nacionalidad IS NULL OR LTRIM(RTRIM(@Nacionalidad)) = '' SET @Err += 'La nacionalidad es obligatoria. | ';
    IF LEN(@Err) > 0 THROW 50161, @Err, 1;

    OPEN SYMMETRIC KEY Key_DatosSensibles DECRYPTION BY CERTIFICATE Cert_Mundial2026;

    INSERT INTO op.Arbitro (Nombre, Apellido, Nacionalidad, Categoria, DocumentoCifrado, FechaNacimiento)
    VALUES (@Nombre, @Apellido, @Nacionalidad, @Categoria,
            CASE WHEN @Documento IS NOT NULL THEN ENCRYPTBYKEY(KEY_GUID('Key_DatosSensibles'), @Documento) END,
            @FechaNacimiento);

    CLOSE SYMMETRIC KEY Key_DatosSensibles;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarArbitro
    @IdArbitro INT, @Nacionalidad VARCHAR(50), @Categoria VARCHAR(50), @Documento VARCHAR(30) = NULL, @FechaNacimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Arbitro WHERE IdArbitro = @IdArbitro) THROW 50162, 'El árbitro no existe.', 1;

    OPEN SYMMETRIC KEY Key_DatosSensibles DECRYPTION BY CERTIFICATE Cert_Mundial2026;

    UPDATE op.Arbitro
    SET Nacionalidad = @Nacionalidad,
        Categoria = @Categoria,
        DocumentoCifrado = CASE WHEN @Documento IS NOT NULL THEN ENCRYPTBYKEY(KEY_GUID('Key_DatosSensibles'), @Documento) ELSE DocumentoCifrado END,
        FechaNacimiento = @FechaNacimiento
    WHERE IdArbitro = @IdArbitro;

    CLOSE SYMMETRIC KEY Key_DatosSensibles;
END;
GO

-- =========================================================================
-- 5. SP DE CONSULTA DESCIFRADA (SÓLO PARA ROLES AUTORIZADOS)
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_ConsultarDatosSensibles
    @Entidad VARCHAR(20) = 'Jugador'
AS
BEGIN
    SET NOCOUNT ON;

    IF @Entidad NOT IN ('Jugador', 'CuerpoTecnico', 'Arbitro')
        THROW 50801, 'La entidad debe ser Jugador, CuerpoTecnico o Arbitro.', 1;

    OPEN SYMMETRIC KEY Key_DatosSensibles DECRYPTION BY CERTIFICATE Cert_Mundial2026;

    IF @Entidad = 'Jugador'
        SELECT TOP (10) IdJugador, Nombre, Apellido, DocumentoCifrado,
               CONVERT(VARCHAR(30), DECRYPTBYKEY(DocumentoCifrado)) AS DocumentoDescifrado
        FROM op.Jugador
        WHERE DocumentoCifrado IS NOT NULL
        ORDER BY IdJugador;

    ELSE IF @Entidad = 'CuerpoTecnico'
        SELECT TOP (10) IdCuerpoTecnico, Nombre, Tipo, DocumentoCifrado,
               CONVERT(VARCHAR(30), DECRYPTBYKEY(DocumentoCifrado)) AS DocumentoDescifrado
        FROM op.CuerpoTecnico
        WHERE DocumentoCifrado IS NOT NULL
        ORDER BY IdCuerpoTecnico;

    ELSE IF @Entidad = 'Arbitro'
        SELECT TOP (10) IdArbitro, Nombre, Apellido, DocumentoCifrado,
               CONVERT(VARCHAR(30), DECRYPTBYKEY(DocumentoCifrado)) AS DocumentoDescifrado
        FROM op.Arbitro
        WHERE DocumentoCifrado IS NOT NULL
        ORDER BY IdArbitro;

    CLOSE SYMMETRIC KEY Key_DatosSensibles;
END;
GO
