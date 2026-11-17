/* =========================================================================
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli, 
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Descripción: ENTREGA 6 - Procesos de Importación Masiva
   Incluye:
   - Tablas de Staging (crudo), Históricos y Log de Errores.
   - Tabla y Función Auxiliar de Conversión de Moneda en T-SQL.
   - SP de Importación de Jugadores (Upsert + reutilización de op.usp_AltaJugador).
   - SP de Importación de Publicidad (Upsert + Conversión de Moneda + Histórico).
   - Testing 1:1 con evidencia de Upsert, Históricos y Tolerancia a Fallos.
========================================================================= */

USE Mundial2026;
GO

-- PARTE 1: TABLAS AUXILIARES (STAGING, HISTÓRICOS, COTIZACIONES Y LOG)

-- 1.1 Tablas Staging (donde vuelca el BULK INSERT tal cual viene el archivo)
CREATE TABLE op.STG_Jugadores (
    Nombre VARCHAR(100),
    Apellido VARCHAR(100),
    Nacionalidad VARCHAR(50),
    NombreClub VARCHAR(100),
    PaisSeleccion VARCHAR(100)
);

CREATE TABLE op.STG_Exhibiciones (
    IdEspacio INT,
    IdPartido INT,
    IdPieza INT,
    Tarifa VARCHAR(50),  
    Moneda VARCHAR(10)
);

-- 1.2 Tablas Históricas (para conservar trazabilidad ante actualizaciones)
CREATE TABLE op.Jugador_Historico (
    IdHistorico INT IDENTITY(1,1) PRIMARY KEY,
    IdJugador INT NOT NULL,
    IdClubAnterior INT NOT NULL,
    IdClubNuevo INT NOT NULL,
    IdPlantelAnterior INT NOT NULL,
    IdPlantelNuevo INT NOT NULL,
    FechaCambio DATETIME DEFAULT GETDATE()
);

CREATE TABLE op.Exhibicion_Historico (
    IdHistorico INT IDENTITY(1,1) PRIMARY KEY,
    IdExhibicion INT NOT NULL,
    TarifaAnterior DECIMAL(10,2) NOT NULL,
    TarifaNueva DECIMAL(10,2) NOT NULL,
    FechaModificacion DATETIME DEFAULT GETDATE()
);

-- 1.3 Tabla Paramétrica de Cotizaciones y Log de Importación
CREATE TABLE cfg.Cotizacion_Moneda (
    CodigoMoneda VARCHAR(10) PRIMARY KEY,
    ValorEnARS DECIMAL(18,4) NOT NULL,
    FechaActualizacion DATETIME DEFAULT GETDATE()
);

INSERT INTO cfg.Cotizacion_Moneda (CodigoMoneda, ValorEnARS)
VALUES ('ARS', 1.0000), ('USD', 1200.0000), ('EUR', 1300.0000);

CREATE TABLE cfg.Log_Importacion (
    IdLog INT IDENTITY(1,1) PRIMARY KEY,
    FechaHora DATETIME DEFAULT GETDATE(),
    Proceso VARCHAR(100) NOT NULL,
    ArchivoOrigen VARCHAR(255) NOT NULL,
    DetalleFila VARCHAR(500) NULL,
    MensajeError NVARCHAR(MAX) NOT NULL
);
GO

-- PARTE 2: OBJETO AUXILIAR DE TRANSFORMACIÓN DE MONEDA

CREATE OR ALTER FUNCTION cfg.fn_ConvertirMoneda (
    @Monto DECIMAL(18,2),
    @MonedaOrigen VARCHAR(10)
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @Factor DECIMAL(18,4);

    SELECT @Factor = ValorEnARS 
    FROM cfg.Cotizacion_Moneda 
    WHERE CodigoMoneda = UPPER(LTRIM(RTRIM(@MonedaOrigen)));

    IF @Factor IS NULL
        RETURN NULL; 

    RETURN ROUND(@Monto * @Factor, 2);
END;
GO

-- PARTE 3: STORED PROCEDURES DE IMPORTACIÓN (UPSERT + REUTILIZACIÓN E5)

CREATE OR ALTER PROCEDURE cfg.usp_ImportarJugadores_CSV
    @RutaArchivo VARCHAR(255),
    @Delimitador VARCHAR(5) = ';'
AS
BEGIN
    SET NOCOUNT ON;

    IF @RutaArchivo IS NULL OR LTRIM(RTRIM(@RutaArchivo)) = ''
        THROW 50020, 'Debe especificar la ruta del archivo CSV.', 1;

    TRUNCATE TABLE op.STG_Jugadores;

    -- Carga masiva dinámica sin tocar el archivo externo
    DECLARE @SQL NVARCHAR(MAX) = N'
    BULK INSERT op.STG_Jugadores
    FROM ''' + REPLACE(@RutaArchivo, '''', '''''') + N'''
    WITH (
        FORMAT = ''CSV'',
        FIELDTERMINATOR = ''' + @Delimitador + N''',
        ROWTERMINATOR = ''\n'',
        FIRSTROW = 2,
        CODEPAGE = ''65001''
    );';

    BEGIN TRY
        EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        DECLARE @ErrCarga NVARCHAR(MAX) = ERROR_MESSAGE();
        INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
        VALUES ('ImportarJugadores', @RutaArchivo, 'Lectura de archivo', @ErrCarga);
        THROW;
    END CATCH

    -- Variables del cursor
    DECLARE @Nombre VARCHAR(100), @Apellido VARCHAR(100), @Nacionalidad VARCHAR(50);
    DECLARE @NombreClub VARCHAR(100), @PaisSeleccion VARCHAR(100);
    DECLARE @IdClub INT, @IdPlantel INT, @IdJugadorExistente INT;
    DECLARE @IdClubActual INT, @IdPlantelActual INT;

    DECLARE cursor_jugadores CURSOR FOR
        SELECT LTRIM(RTRIM(Nombre)), LTRIM(RTRIM(Apellido)), LTRIM(RTRIM(Nacionalidad)),
               LTRIM(RTRIM(NombreClub)), LTRIM(RTRIM(PaisSeleccion))
        FROM op.STG_Jugadores;

    OPEN cursor_jugadores;
    FETCH NEXT FROM cursor_jugadores INTO @Nombre, @Apellido, @Nacionalidad, @NombreClub, @PaisSeleccion;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- 1. Resolver IdPlantel a partir del País de la Selección
            SELECT TOP 1 @IdPlantel = pl.IdPlantel
            FROM op.Plantel pl
            INNER JOIN op.Seleccion s ON pl.IdSeleccion = s.IdSeleccion
            INNER JOIN op.Pais p ON s.IdPais = p.IdPais
            WHERE p.Nombre = @PaisSeleccion;

            IF @IdPlantel IS NULL
                THROW 50021, 'No existe selección/plantel registrado para el país indicado.', 1;

            -- 2. Resolver IdClub (si el club es nuevo, se da de alta)
            SELECT @IdClub = IdClub FROM op.Club WHERE Nombre = @NombreClub;
            IF @IdClub IS NULL
            BEGIN
                IF @NombreClub IS NULL OR @NombreClub = ''
                    THROW 50022, 'El nombre del club no puede estar vacío.', 1;

                INSERT INTO op.Club (Nombre) VALUES (@NombreClub);
                SET @IdClub = SCOPE_IDENTITY();
            END

            -- 3. Lógica UPSERT sin MERGE (Evita duplicados por Nombre + Apellido + Nacionalidad)
            SELECT @IdJugadorExistente = IdJugador, 
                   @IdClubActual = IdClub, 
                   @IdPlantelActual = IdPlantel
            FROM op.Jugador
            WHERE Nombre = @Nombre AND Apellido = @Apellido AND Nacionalidad = @Nacionalidad;

            IF @IdJugadorExistente IS NOT NULL
            BEGIN
                -- UPDATE + Resguardo de Histórico si cambió de club o plantel
                IF @IdClubActual <> @IdClub OR @IdPlantelActual <> @IdPlantel
                BEGIN
                    INSERT INTO op.Jugador_Historico (IdJugador, IdClubAnterior, IdClubNuevo, IdPlantelAnterior, IdPlantelNuevo)
                    VALUES (@IdJugadorExistente, @IdClubActual, @IdClub, @IdPlantelActual, @IdPlantel);

                    UPDATE op.Jugador
                    SET IdClub = @IdClub, IdPlantel = @IdPlantel
                    WHERE IdJugador = @IdJugadorExistente;
                END
            END
            ELSE
            BEGIN
                -- INSERT reutilizando estrictamente el SP de la Entrega 5
                EXEC op.usp_AltaJugador 
                    @IdPlantel = @IdPlantel,
                    @IdClub = @IdClub,
                    @Nombre = @Nombre,
                    @Apellido = @Apellido,
                    @Nacionalidad = @Nacionalidad;
            END

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

            DECLARE @ErrFila NVARCHAR(MAX) = ERROR_MESSAGE();
            DECLARE @InfoFila VARCHAR(500) = CONCAT('Jugador: ', ISNULL(@Nombre,'NULL'), ' ', ISNULL(@Apellido,'NULL'), ' | País: ', ISNULL(@PaisSeleccion,'NULL'));

            INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
            VALUES ('ImportarJugadores', @RutaArchivo, @InfoFila, @ErrFila);
        END CATCH

        -- Reset de variables antes de la siguiente fila
        SET @IdPlantel = NULL;
        SET @IdClub = NULL;
        SET @IdJugadorExistente = NULL;

        FETCH NEXT FROM cursor_jugadores INTO @Nombre, @Apellido, @Nacionalidad, @NombreClub, @PaisSeleccion;
    END

    CLOSE cursor_jugadores;
    DEALLOCATE cursor_jugadores;
END;
GO

-- 3.2 Importación Masiva de Publicidad (Transformación de Moneda + Upsert + Histórico)
CREATE OR ALTER PROCEDURE cfg.usp_ImportarExhibiciones_CSV
    @RutaArchivo VARCHAR(255),
    @Delimitador VARCHAR(5) = ';'
AS
BEGIN
    SET NOCOUNT ON;

    IF @RutaArchivo IS NULL OR LTRIM(RTRIM(@RutaArchivo)) = ''
        THROW 50030, 'Debe especificar la ruta del archivo CSV.', 1;

    TRUNCATE TABLE op.STG_Exhibiciones;

    DECLARE @SQL NVARCHAR(MAX) = N'
    BULK INSERT op.STG_Exhibiciones
    FROM ''' + REPLACE(@RutaArchivo, '''', '''''') + N'''
    WITH (
        FORMAT = ''CSV'',
        FIELDTERMINATOR = ''' + @Delimitador + N''',
        ROWTERMINATOR = ''\n'',
        FIRSTROW = 2,
        CODEPAGE = ''65001''
    );';

    BEGIN TRY
        EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        DECLARE @ErrCarga NVARCHAR(MAX) = ERROR_MESSAGE();
        INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
        VALUES ('ImportarExhibiciones', @RutaArchivo, 'Lectura de archivo', @ErrCarga);
        THROW;
    END CATCH

    DECLARE @IdEspacio INT, @IdPartido INT, @IdPieza INT, @TarifaTxt VARCHAR(50), @Moneda VARCHAR(10);
    DECLARE @TarifaNumerica DECIMAL(18,2), @TarifaARS DECIMAL(10,2);
    DECLARE @IdExhibicionExistente INT, @TarifaAnterior DECIMAL(10,2);

    DECLARE cursor_exhibiciones CURSOR FOR
        SELECT IdEspacio, IdPartido, IdPieza, LTRIM(RTRIM(Tarifa)), LTRIM(RTRIM(Moneda))
        FROM op.STG_Exhibiciones;

    OPEN cursor_exhibiciones;
    FETCH NEXT FROM cursor_exhibiciones INTO @IdEspacio, @IdPartido, @IdPieza, @TarifaTxt, @Moneda;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- 1. Validaciones de integridad referencial y formato numérico
            IF NOT EXISTS (SELECT 1 FROM op.EspacioPublicitario WHERE IdEspacio = @IdEspacio)
                THROW 50031, 'El espacio publicitario no existe.', 1;
            IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido)
                THROW 50032, 'El partido no existe.', 1;
            IF NOT EXISTS (SELECT 1 FROM cfg.Pieza_Contenido WHERE IdPieza = @IdPieza)
                THROW 50033, 'La pieza de contenido no existe.', 1;

            SET @TarifaNumerica = TRY_CAST(REPLACE(@TarifaTxt, ',', '.') AS DECIMAL(18,2));
            IF @TarifaNumerica IS NULL OR @TarifaNumerica <= 0
                THROW 50034, 'El monto de tarifa es inválido o menor/igual a cero.', 1;

            -- 2. Transformación de moneda mediante función auxiliar
            SET @TarifaARS = cfg.fn_ConvertirMoneda(@TarifaNumerica, @Moneda);
            IF @TarifaARS IS NULL
                THROW 50035, 'Código de moneda no soportado en cfg.Cotizacion_Moneda.', 1;

            -- 3. Lógica UPSERT sin MERGE + Histórico de tarifas
            SELECT @IdExhibicionExistente = IdExhibicion, @TarifaAnterior = Tarifa
            FROM op.Exhibicion
            WHERE IdEspacio = @IdEspacio AND IdPartido = @IdPartido AND IdPieza = @IdPieza;

            IF @IdExhibicionExistente IS NOT NULL
            BEGIN
                IF @TarifaAnterior <> @TarifaARS
                BEGIN
                    INSERT INTO op.Exhibicion_Historico (IdExhibicion, TarifaAnterior, TarifaNueva)
                    VALUES (@IdExhibicionExistente, @TarifaAnterior, @TarifaARS);

                    UPDATE op.Exhibicion
                    SET Tarifa = @TarifaARS
                    WHERE IdExhibicion = @IdExhibicionExistente;
                END
            END
            ELSE
            BEGIN
                INSERT INTO op.Exhibicion (IdEspacio, IdPartido, IdPieza, Tarifa)
                VALUES (@IdEspacio, @IdPartido, @IdPieza, @TarifaARS);
            END

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

            DECLARE @ErrFila NVARCHAR(MAX) = ERROR_MESSAGE();
            DECLARE @InfoFila VARCHAR(500) = CONCAT('Espacio:', ISNULL(CAST(@IdEspacio AS VARCHAR),'NULL'), ' | Partido:', ISNULL(CAST(@IdPartido AS VARCHAR),'NULL'), ' | Pieza:', ISNULL(CAST(@IdPieza AS VARCHAR),'NULL'));

            INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
            VALUES ('ImportarExhibiciones', @RutaArchivo, @InfoFila, @ErrFila);
        END CATCH

        SET @IdExhibicionExistente = NULL;
        FETCH NEXT FROM cursor_exhibiciones INTO @IdEspacio, @IdPartido, @IdPieza, @TarifaTxt, @Moneda;
    END

    CLOSE cursor_exhibiciones;
    DEALLOCATE cursor_exhibiciones;
END;
GO