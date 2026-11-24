/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli, Agustín Nicolás Mussi Pulcini
   Explicación: El script lleva a cabo los procesos de importación.
             - Se crearon tablas auxiliares.
             - Se implementó una funcion de conversión de moneda.
             - Formato 1 (CSV): Jugadores y Exhibiciones.
             - Formato 2 (XML): Sedes (OPENROWSET + .nodes(), Upsert + Errores parciales).
             - Scraping (CSV de Wikipedia): Árbitros.
             - API 1 (Frankfurter JSON): Cotizaciones de moneda.
             - API 2 (Banco Mundial JSON): PBI per cápita por país.
========================================================================= */

USE Mundial2026;
GO


--TABLAS AUXILIARES
IF OBJECT_ID('op.STG_Jugadores', 'U') IS NULL
CREATE TABLE op.STG_Jugadores (
    Nombre VARCHAR(100),
    Apellido VARCHAR(100),
    Nacionalidad VARCHAR(50),
    NombreClub VARCHAR(100),
    PaisSeleccion VARCHAR(100)
);

IF OBJECT_ID('op.STG_Exhibiciones', 'U') IS NULL
CREATE TABLE op.STG_Exhibiciones (
    IdEspacio VARCHAR(50),
    IdPartido VARCHAR(50),
    IdPieza VARCHAR(50),
    Tarifa VARCHAR(50),
    Moneda VARCHAR(10)
);

IF OBJECT_ID('op.STG_Arbitros_Scraping', 'U') IS NULL
CREATE TABLE op.STG_Arbitros_Scraping (
    Nombre VARCHAR(100),
    Apellido VARCHAR(100),
    Nacionalidad VARCHAR(50),
    Categoria VARCHAR(50)
);

IF OBJECT_ID('op.Jugador_Historico', 'U') IS NULL
CREATE TABLE op.Jugador_Historico (
    IdHistorico INT IDENTITY(1,1) PRIMARY KEY,
    IdJugador INT NOT NULL,
    IdClubAnterior INT NOT NULL,
    IdClubNuevo INT NOT NULL,
    IdPlantelAnterior INT NOT NULL,
    IdPlantelNuevo INT NOT NULL,
    FechaCambio DATETIME DEFAULT GETDATE()
);

IF OBJECT_ID('op.Exhibicion_Historico', 'U') IS NULL
CREATE TABLE op.Exhibicion_Historico (
    IdHistorico INT IDENTITY(1,1) PRIMARY KEY,
    IdExhibicion INT NOT NULL,
    TarifaAnterior DECIMAL(10,2) NOT NULL,
    TarifaNueva DECIMAL(10,2) NOT NULL,
    FechaModificacion DATETIME DEFAULT GETDATE()
);

IF OBJECT_ID('cfg.Cotizacion_Moneda', 'U') IS NULL
CREATE TABLE cfg.Cotizacion_Moneda (
    CodigoMoneda VARCHAR(10) PRIMARY KEY,
    ValorEnARS DECIMAL(18,4) NOT NULL,
    FechaActualizacion DATETIME DEFAULT GETDATE()
);

IF NOT EXISTS (SELECT 1 FROM cfg.Cotizacion_Moneda WHERE CodigoMoneda = 'ARS')
    INSERT INTO cfg.Cotizacion_Moneda (CodigoMoneda, ValorEnARS) VALUES ('ARS', 1.0000);
IF NOT EXISTS (SELECT 1 FROM cfg.Cotizacion_Moneda WHERE CodigoMoneda = 'USD')
    INSERT INTO cfg.Cotizacion_Moneda (CodigoMoneda, ValorEnARS) VALUES ('USD', 1200.0000);
IF NOT EXISTS (SELECT 1 FROM cfg.Cotizacion_Moneda WHERE CodigoMoneda = 'EUR')
    INSERT INTO cfg.Cotizacion_Moneda (CodigoMoneda, ValorEnARS) VALUES ('EUR', 1300.0000);

IF OBJECT_ID('cfg.Log_Importacion', 'U') IS NULL
CREATE TABLE cfg.Log_Importacion (
    IdLog INT IDENTITY(1,1) PRIMARY KEY,
    FechaHora DATETIME DEFAULT GETDATE(),
    Proceso VARCHAR(100) NOT NULL,
    ArchivoOrigen VARCHAR(255) NOT NULL,
    DetalleFila VARCHAR(500) NULL,
    MensajeError NVARCHAR(MAX) NOT NULL
);
GO

--FUNCIÓN DE CONVERSIÓN DE MONEDA
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

    IF @Factor IS NULL RETURN NULL;
    RETURN ROUND(@Monto * @Factor, 2);
END;
GO


--SP 1 (CSV) - IMPORTACIÓN DE JUGADORES
CREATE OR ALTER PROCEDURE cfg.usp_ImportarJugadores_CSV
    @RutaArchivo VARCHAR(255),
    @Delimitador VARCHAR(5) = ';'
AS
BEGIN
    SET NOCOUNT ON;

    IF @RutaArchivo IS NULL OR LTRIM(RTRIM(@RutaArchivo)) = ''
        THROW 50020, 'Falta la ruta del archivo CSV.', 1;

    TRUNCATE TABLE op.STG_Jugadores;

    DECLARE @SQL NVARCHAR(MAX) = N'
    BULK INSERT op.STG_Jugadores
    FROM ''' + REPLACE(@RutaArchivo, '''', '''''') + N'''
    WITH (FORMAT = ''CSV'', FIELDTERMINATOR = ''' + @Delimitador + N''', ROWTERMINATOR = ''0x0a'', FIRSTROW = 2, CODEPAGE = ''65001'');';

    BEGIN TRY
        EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
        VALUES ('ImportarJugadores_CSV', @RutaArchivo, 'Lectura de archivo', ERROR_MESSAGE());
        THROW;
    END CATCH

    DECLARE @Cola TABLE (
        IdFila INT IDENTITY(1,1) PRIMARY KEY,
        Nombre VARCHAR(100), Apellido VARCHAR(100), Nacionalidad VARCHAR(50),
        NombreClub VARCHAR(100), PaisSeleccion VARCHAR(100)
    );

    INSERT INTO @Cola (Nombre, Apellido, Nacionalidad, NombreClub, PaisSeleccion)
    SELECT LTRIM(RTRIM(REPLACE(Nombre, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(Apellido, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(Nacionalidad, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(NombreClub, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(PaisSeleccion, CHAR(13), '')))
    FROM op.STG_Jugadores;

    DECLARE @i INT = 1, @Total INT = @@ROWCOUNT;
    DECLARE @Nombre VARCHAR(100), @Apellido VARCHAR(100), @Nacionalidad VARCHAR(50), @NombreClub VARCHAR(100), @PaisSeleccion VARCHAR(100);
    DECLARE @IdClub INT, @IdPlantel INT, @IdJugadorExistente INT, @IdClubActual INT, @IdPlantelActual INT;

    WHILE @i <= @Total
    BEGIN
        SELECT @Nombre = Nombre, @Apellido = Apellido, @Nacionalidad = Nacionalidad,
               @NombreClub = NombreClub, @PaisSeleccion = PaisSeleccion
        FROM @Cola WHERE IdFila = @i;

        SET @IdPlantel = NULL; SET @IdClub = NULL; SET @IdJugadorExistente = NULL;

        BEGIN TRY
            BEGIN TRANSACTION;

            SELECT TOP 1 @IdPlantel = pl.IdPlantel
            FROM op.Plantel pl
            INNER JOIN op.Seleccion s ON pl.IdSeleccion = s.IdSeleccion
            INNER JOIN op.Pais p ON s.IdPais = p.IdPais
            WHERE p.Nombre = @PaisSeleccion;

            IF @IdPlantel IS NULL
                THROW 50021, 'No existe selección/plantel registrado para el país indicado.', 1;

            SELECT @IdClub = IdClub FROM op.Club WHERE Nombre = @NombreClub;
            IF @IdClub IS NULL
            BEGIN
                IF @NombreClub IS NULL OR @NombreClub = ''
                    THROW 50022, 'El nombre del club no puede estar vacío.', 1;
                EXEC op.usp_AltaClub @Nombre = @NombreClub;
                SELECT @IdClub = IdClub FROM op.Club WHERE Nombre = @NombreClub;
            END

            SELECT @IdJugadorExistente = IdJugador, @IdClubActual = IdClub, @IdPlantelActual = IdPlantel
            FROM op.Jugador
            WHERE Nombre = @Nombre AND Apellido = @Apellido AND Nacionalidad = @Nacionalidad;

            IF @IdJugadorExistente IS NOT NULL
            BEGIN
                IF @IdClubActual <> @IdClub OR @IdPlantelActual <> @IdPlantel
                BEGIN
                    INSERT INTO op.Jugador_Historico (IdJugador, IdClubAnterior, IdClubNuevo, IdPlantelAnterior, IdPlantelNuevo)
                    VALUES (@IdJugadorExistente, @IdClubActual, @IdClub, @IdPlantelActual, @IdPlantel);

                    EXEC op.usp_ModificarJugador @IdJugador = @IdJugadorExistente, @IdPlantel = @IdPlantel, @IdClub = @IdClub;
                END
            END
            ELSE
            BEGIN
                EXEC op.usp_AltaJugador @IdPlantel = @IdPlantel, @IdClub = @IdClub,
                     @Nombre = @Nombre, @Apellido = @Apellido, @Nacionalidad = @Nacionalidad;
            END

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
            VALUES ('ImportarJugadores_CSV', @RutaArchivo,
                    CONCAT('Jugador: ', ISNULL(@Nombre,'NULL'), ' ', ISNULL(@Apellido,'NULL'), ' | País: ', ISNULL(@PaisSeleccion,'NULL')),
                    ERROR_MESSAGE());
        END CATCH

        SET @i += 1;
    END
END;
GO

--SP 2 (CSV) - IMPORTACIÓN DE EXHIBICIONES (CONVERSIÓN DE MONEDA)
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
    WITH (FORMAT = ''CSV'', FIELDTERMINATOR = ''' + @Delimitador + N''', ROWTERMINATOR = ''0x0a'', FIRSTROW = 2, CODEPAGE = ''65001'');';

    BEGIN TRY
        EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
        VALUES ('ImportarExhibiciones_CSV', @RutaArchivo, 'Lectura de archivo', ERROR_MESSAGE());
        THROW;
    END CATCH

    DECLARE @Cola TABLE (
        IdFila INT IDENTITY(1,1) PRIMARY KEY,
        IdEspacio VARCHAR(50), IdPartido VARCHAR(50), IdPieza VARCHAR(50), Tarifa VARCHAR(50), Moneda VARCHAR(10)
    );

    INSERT INTO @Cola (IdEspacio, IdPartido, IdPieza, Tarifa, Moneda)
    SELECT LTRIM(RTRIM(REPLACE(IdEspacio, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(IdPartido, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(IdPieza, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(Tarifa, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(Moneda, CHAR(13), '')))
    FROM op.STG_Exhibiciones;

    DECLARE @i INT = 1, @Total INT = @@ROWCOUNT;
    DECLARE @IdEspacioTxt VARCHAR(50), @IdPartidoTxt VARCHAR(50), @IdPiezaTxt VARCHAR(50), @TarifaTxt VARCHAR(50), @Moneda VARCHAR(10);
    DECLARE @IdEspacio INT, @IdPartido INT, @IdPieza INT, @TarifaNumerica DECIMAL(18,2), @TarifaARS DECIMAL(10,2);
    DECLARE @IdExhibicionExistente INT, @TarifaAnterior DECIMAL(10,2);

    WHILE @i <= @Total
    BEGIN
        SELECT @IdEspacioTxt = IdEspacio, @IdPartidoTxt = IdPartido, @IdPiezaTxt = IdPieza,
               @TarifaTxt = Tarifa, @Moneda = Moneda
        FROM @Cola WHERE IdFila = @i;

        SET @IdEspacio = TRY_CAST(@IdEspacioTxt AS INT);
        SET @IdPartido = TRY_CAST(@IdPartidoTxt AS INT);
        SET @IdPieza = TRY_CAST(@IdPiezaTxt AS INT);
        SET @IdExhibicionExistente = NULL;

        BEGIN TRY
            BEGIN TRANSACTION;

            IF @IdEspacio IS NULL OR NOT EXISTS (SELECT 1 FROM op.EspacioPublicitario WHERE IdEspacio = @IdEspacio)
                THROW 50031, 'El espacio publicitario es inválido o no existe.', 1;
            IF @IdPartido IS NULL OR NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido)
                THROW 50032, 'El partido es inválido o no existe.', 1;
            IF @IdPieza IS NULL OR NOT EXISTS (SELECT 1 FROM cfg.Pieza_Contenido WHERE IdPieza = @IdPieza)
                THROW 50033, 'La pieza de contenido es inválida o no existe.', 1;

            SET @TarifaNumerica = TRY_CAST(REPLACE(@TarifaTxt, ',', '.') AS DECIMAL(18,2));
            IF @TarifaNumerica IS NULL OR @TarifaNumerica <= 0
                THROW 50034, 'El monto de tarifa es inválido o menor/igual a cero.', 1;

            SET @TarifaARS = cfg.fn_ConvertirMoneda(@TarifaNumerica, @Moneda);
            IF @TarifaARS IS NULL
                THROW 50035, 'Código de moneda no soportado en cfg.Cotizacion_Moneda.', 1;

            SELECT @IdExhibicionExistente = IdExhibicion, @TarifaAnterior = Tarifa
            FROM op.Exhibicion
            WHERE IdEspacio = @IdEspacio AND IdPartido = @IdPartido AND IdPieza = @IdPieza;

            IF @IdExhibicionExistente IS NOT NULL
            BEGIN
                IF @TarifaAnterior <> @TarifaARS
                BEGIN
                    INSERT INTO op.Exhibicion_Historico (IdExhibicion, TarifaAnterior, TarifaNueva)
                    VALUES (@IdExhibicionExistente, @TarifaAnterior, @TarifaARS);

                    EXEC op.usp_ModificarExhibicion @IdExhibicion = @IdExhibicionExistente, @Tarifa = @TarifaARS;
                END
            END
            ELSE
            BEGIN
                EXEC op.usp_AltaExhibicion @IdEspacio = @IdEspacio, @IdPartido = @IdPartido, @IdPieza = @IdPieza, @Tarifa = @TarifaARS;
            END

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
            VALUES ('ImportarExhibiciones_CSV', @RutaArchivo,
                    CONCAT('Espacio:', ISNULL(@IdEspacioTxt,'NULL'), ' | Partido:', ISNULL(@IdPartidoTxt,'NULL'), ' | Pieza:', ISNULL(@IdPiezaTxt,'NULL')),
                    ERROR_MESSAGE());
        END CATCH

        SET @i += 1;
    END
END;
GO


--SP 3 (FORMATO 2: XML) - IMPORTACIÓN DE SEDES DESDE XML
CREATE OR ALTER PROCEDURE cfg.usp_ImportarSedes_XML
    @RutaArchivo VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    IF @RutaArchivo IS NULL OR LTRIM(RTRIM(@RutaArchivo)) = ''
        THROW 50040, 'Debe especificar la ruta del archivo XML.', 1;

    DECLARE @XmlData XML;
    DECLARE @SQL NVARCHAR(MAX) = N'SELECT @XmlOut = CAST(BulkColumn AS XML) FROM OPENROWSET(BULK ''' + REPLACE(@RutaArchivo, '''', '''''') + N''', SINGLE_BLOB) AS x;';

    BEGIN TRY
        EXEC sp_executesql @SQL, N'@XmlOut XML OUTPUT', @XmlOut = @XmlData OUTPUT;
    END TRY
    BEGIN CATCH
        INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
        VALUES ('ImportarSedes_XML', @RutaArchivo, 'Lectura de XML', ERROR_MESSAGE());
        THROW;
    END CATCH

    DECLARE @Cola TABLE (
        IdFila INT IDENTITY(1,1) PRIMARY KEY,
        NombreEstadio VARCHAR(100), Ciudad VARCHAR(100), Pais VARCHAR(100), UsoHorario VARCHAR(10), CapacidadTxt VARCHAR(50)
    );

    INSERT INTO @Cola (NombreEstadio, Ciudad, Pais, UsoHorario, CapacidadTxt)
    SELECT
        LTRIM(RTRIM(T.c.value('(NombreEstadio/text())[1]', 'VARCHAR(100)'))),
        LTRIM(RTRIM(T.c.value('(Ciudad/text())[1]', 'VARCHAR(100)'))),
        LTRIM(RTRIM(T.c.value('(Pais/text())[1]', 'VARCHAR(100)'))),
        LTRIM(RTRIM(T.c.value('(UsoHorario/text())[1]', 'VARCHAR(10)'))),
        LTRIM(RTRIM(T.c.value('(Capacidad/text())[1]', 'VARCHAR(50)')))
    FROM @XmlData.nodes('/Sedes/Sede') AS T(c);

    DECLARE @i INT = 1, @Total INT = @@ROWCOUNT;
    DECLARE @NombreEstadio VARCHAR(100), @Ciudad VARCHAR(100), @Pais VARCHAR(100), @UsoHorario VARCHAR(10), @CapacidadTxt VARCHAR(50);
    DECLARE @IdPais INT, @Capacidad INT, @IdSedeExistente INT;

    WHILE @i <= @Total
    BEGIN
        SELECT @NombreEstadio = NombreEstadio, @Ciudad = Ciudad, @Pais = Pais,
               @UsoHorario = UsoHorario, @CapacidadTxt = CapacidadTxt
        FROM @Cola WHERE IdFila = @i;

        SET @IdPais = NULL; SET @IdSedeExistente = NULL;
        SET @Capacidad = TRY_CAST(@CapacidadTxt AS INT);

        BEGIN TRY
            BEGIN TRANSACTION;

            SELECT @IdPais = IdPais FROM op.Pais WHERE Nombre = @Pais;
            IF @IdPais IS NULL THROW 50041, 'El país indicado en el XML no existe en op.Pais.', 1;
            IF @Capacidad IS NULL OR @Capacidad <= 0 THROW 50042, 'La capacidad en el XML es inválida.', 1;

            SELECT @IdSedeExistente = IdSede FROM op.Sede WHERE NombreEstadio = @NombreEstadio AND Ciudad = @Ciudad;
            IF @IdSedeExistente IS NOT NULL
                EXEC op.usp_ModificarSede @IdSede = @IdSedeExistente, @IdPais = @IdPais, @NombreEstadio = @NombreEstadio,
                     @Ciudad = @Ciudad, @UsoHorario = @UsoHorario, @Capacidad = @Capacidad;
            ELSE
                EXEC op.usp_AltaSede @IdPais = @IdPais, @NombreEstadio = @NombreEstadio,
                     @Ciudad = @Ciudad, @UsoHorario = @UsoHorario, @Capacidad = @Capacidad;

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
            VALUES ('ImportarSedes_XML', @RutaArchivo,
                    CONCAT('Estadio: ', ISNULL(@NombreEstadio,'NULL'), ' | País: ', ISNULL(@Pais,'NULL')),
                    ERROR_MESSAGE());
        END CATCH

        SET @i += 1;
    END
END;
GO


--SP 4 (SCRAPING WIKIPEDIA) - IMPORTACIÓN DE ÁRBITROS
-- Origen: https://en.wikipedia.org/wiki/List_of_FIFA_World_Cup_referees
-- Scraping HTML con PowerShell (Invoke-WebRequest + Regex de tablas)
--          mediante Datos/Obtener_Datos_Externos.ps1 -> arbitros_scraping.csv

CREATE OR ALTER PROCEDURE cfg.usp_ImportarArbitros_Scraping_CSV
    @RutaArchivo VARCHAR(255),
    @Delimitador VARCHAR(5) = ';'
AS
BEGIN
    SET NOCOUNT ON;
    IF @RutaArchivo IS NULL OR LTRIM(RTRIM(@RutaArchivo)) = ''
        THROW 50050, 'Debe especificar la ruta del archivo CSV scrapeado.', 1;

    TRUNCATE TABLE op.STG_Arbitros_Scraping;

    DECLARE @SQL NVARCHAR(MAX) = N'
    BULK INSERT op.STG_Arbitros_Scraping
    FROM ''' + REPLACE(@RutaArchivo, '''', '''''') + N'''
    WITH (FORMAT = ''CSV'', FIELDTERMINATOR = ''' + @Delimitador + N''', ROWTERMINATOR = ''0x0a'', FIRSTROW = 2, CODEPAGE = ''65001'');';

    BEGIN TRY
        EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
        VALUES ('ImportarArbitros_Scraping', @RutaArchivo, 'Lectura de archivo', ERROR_MESSAGE());
        THROW;
    END CATCH

    DECLARE @Cola TABLE (
        IdFila INT IDENTITY(1,1) PRIMARY KEY,
        Nombre VARCHAR(100), Apellido VARCHAR(100), Nacionalidad VARCHAR(50), Categoria VARCHAR(50)
    );

    INSERT INTO @Cola (Nombre, Apellido, Nacionalidad, Categoria)
    SELECT LTRIM(RTRIM(REPLACE(Nombre, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(Apellido, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(Nacionalidad, CHAR(13), ''))),
           LTRIM(RTRIM(REPLACE(Categoria, CHAR(13), '')))
    FROM op.STG_Arbitros_Scraping;

    DECLARE @i INT = 1, @Total INT = @@ROWCOUNT;
    DECLARE @Nombre VARCHAR(100), @Apellido VARCHAR(100), @Nacionalidad VARCHAR(50), @Categoria VARCHAR(50), @IdArbitroExistente INT;

    WHILE @i <= @Total
    BEGIN
        SELECT @Nombre = Nombre, @Apellido = Apellido, @Nacionalidad = Nacionalidad, @Categoria = Categoria
        FROM @Cola WHERE IdFila = @i;
        SET @IdArbitroExistente = NULL;

        BEGIN TRY
            BEGIN TRANSACTION;

            SELECT @IdArbitroExistente = IdArbitro
            FROM op.Arbitro
            WHERE Nombre = @Nombre AND Apellido = @Apellido AND Nacionalidad = @Nacionalidad;

            IF @IdArbitroExistente IS NOT NULL
                EXEC op.usp_ModificarArbitro @IdArbitro = @IdArbitroExistente, @Nacionalidad = @Nacionalidad, @Categoria = @Categoria;
            ELSE
                EXEC op.usp_AltaArbitro @Nombre = @Nombre, @Apellido = @Apellido, @Nacionalidad = @Nacionalidad, @Categoria = @Categoria;

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
            VALUES ('ImportarArbitros_Scraping', @RutaArchivo,
                    CONCAT('Árbitro: ', ISNULL(@Nombre,'NULL'), ' ', ISNULL(@Apellido,'NULL')),
                    ERROR_MESSAGE());
        END CATCH

        SET @i += 1;
    END
END;
GO


-- SP 5 (API 1: FRANKFURTER JSON) - COTIZACIONES DE MONEDA
-- Fuente: https://api.frankfurter.app/latest?from=USD&to=EUR,BRL,MXN
-- mo necesita API key, y tampoco tiene un rate limit estricto.

CREATE OR ALTER PROCEDURE cfg.usp_ImportarCotizaciones_API_JSON
    @RutaArchivoJSON VARCHAR(255),
    @ValorUsdEnARS DECIMAL(18,4) = 1200.0000
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Json NVARCHAR(MAX);
    DECLARE @SQL NVARCHAR(MAX) = N'SELECT @JsonOut = BulkColumn FROM OPENROWSET(BULK ''' + REPLACE(@RutaArchivoJSON, '''', '''''') + N''', SINGLE_CLOB) AS j;';

    BEGIN TRY
        EXEC sp_executesql @SQL, N'@JsonOut NVARCHAR(MAX) OUTPUT', @JsonOut = @Json OUTPUT;
    END TRY
    BEGIN CATCH
        INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
        VALUES ('ImportarCotizaciones_API', @RutaArchivoJSON, 'Lectura JSON Frankfurter', ERROR_MESSAGE());
        THROW;
    END CATCH

    IF ISJSON(@Json) <> 1
        THROW 50060, 'El archivo no contiene un JSON válido de Frankfurter API.', 1;

    -- Frankfurter devuelve: {"base":"USD","date":"...","rates":{"EUR":0.92,"BRL":5.75,...}}
    -- Si 1 USD = R unidades de moneda X, entonces 1 unidad de moneda X = @ValorUsdEnARS / R ARS.
    DECLARE @Cola TABLE (IdFila INT IDENTITY(1,1) PRIMARY KEY, CodigoMoneda VARCHAR(10), RateTxt VARCHAR(50));

    INSERT INTO @Cola (CodigoMoneda, RateTxt)
    SELECT [key], [value]
    FROM OPENJSON(@Json, '$.rates');

    DECLARE @i INT = 1, @Total INT = @@ROWCOUNT;
    DECLARE @Cod VARCHAR(10), @RateTxt VARCHAR(50), @Rate DECIMAL(18,6), @ValorARS DECIMAL(18,4);

    WHILE @i <= @Total
    BEGIN
        SELECT @Cod = UPPER(LTRIM(RTRIM(CodigoMoneda))), @RateTxt = RateTxt FROM @Cola WHERE IdFila = @i;
        SET @Rate = TRY_CAST(@RateTxt AS DECIMAL(18,6));

        BEGIN TRY
            IF @Rate IS NULL OR @Rate <= 0 THROW 50061, 'Tasa de cambio inválida en JSON.', 1;
            SET @ValorARS = ROUND(@ValorUsdEnARS / @Rate, 4);

            IF EXISTS (SELECT 1 FROM cfg.Cotizacion_Moneda WHERE CodigoMoneda = @Cod)
                UPDATE cfg.Cotizacion_Moneda SET ValorEnARS = @ValorARS, FechaActualizacion = GETDATE() WHERE CodigoMoneda = @Cod;
            ELSE
                INSERT INTO cfg.Cotizacion_Moneda (CodigoMoneda, ValorEnARS) VALUES (@Cod, @ValorARS);
        END TRY
        BEGIN CATCH
            INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
            VALUES ('ImportarCotizaciones_API', @RutaArchivoJSON, CONCAT('Moneda: ', ISNULL(@Cod,'NULL')), ERROR_MESSAGE());
        END CATCH

        SET @i += 1;
    END
END;
GO


-- PARTE 8: SP 6 (API 2: BANCO MUNDIAL JSON) - PBI PER CÁPITA POR PAÍS
-- Fuente: https://api.worldbank.org/v2/country/ARG;BRA;USA;ITA/indicator/NY.GDP.PCAP.CD?format=json&date=2023
-- No requiere api key, y es de acceso público.

CREATE OR ALTER PROCEDURE cfg.usp_ImportarPbi_API_JSON
    @RutaArchivoJSON VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Json NVARCHAR(MAX);
    DECLARE @SQL NVARCHAR(MAX) = N'SELECT @JsonOut = BulkColumn FROM OPENROWSET(BULK ''' + REPLACE(@RutaArchivoJSON, '''', '''''') + N''', SINGLE_CLOB) AS j;';

    BEGIN TRY
        EXEC sp_executesql @SQL, N'@JsonOut NVARCHAR(MAX) OUTPUT', @JsonOut = @Json OUTPUT;
    END TRY
    BEGIN CATCH
        INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
        VALUES ('ImportarPbi_API', @RutaArchivoJSON, 'Lectura JSON Banco Mundial', ERROR_MESSAGE());
        THROW;
    END CATCH

    IF ISJSON(@Json) <> 1
        THROW 50070, 'El archivo no contiene un JSON válido de World Bank API.', 1;

    -- World Bank devuelve un array de 2 elementos: [metadata, [ { "country": {"value":"Argentina"}, "value": 13709.04 }, ... ]]
    DECLARE @Cola TABLE (IdFila INT IDENTITY(1,1) PRIMARY KEY, PaisNombre VARCHAR(100), PbiTxt VARCHAR(50));

    INSERT INTO @Cola (PaisNombre, PbiTxt)
    SELECT
        JSON_VALUE([value], '$.country.value'),
        JSON_VALUE([value], '$.value')
    FROM OPENJSON(@Json, '$[1]');

    DECLARE @i INT = 1, @Total INT = @@ROWCOUNT;
    DECLARE @PaisNombre VARCHAR(100), @PbiTxt VARCHAR(50), @Pbi DECIMAL(12,2);

    WHILE @i <= @Total
    BEGIN
        SELECT @PaisNombre = LTRIM(RTRIM(PaisNombre)), @PbiTxt = PbiTxt FROM @Cola WHERE IdFila = @i;
        SET @Pbi = TRY_CAST(@PbiTxt AS DECIMAL(12,2));

        BEGIN TRY
            IF @Pbi IS NULL OR @Pbi <= 0 THROW 50071, 'Valor de PBI inválido o nulo.', 1;

            -- Mapeo simple de nombres en inglés del Banco Mundial a español si corresponde
            DECLARE @PaisLocal VARCHAR(100) = CASE @PaisNombre
                WHEN 'Brazil' THEN 'Brasil'
                WHEN 'United States' THEN 'Estados Unidos'
                WHEN 'Italy' THEN 'Italia'
                ELSE @PaisNombre
            END;

            IF EXISTS (SELECT 1 FROM op.Pais WHERE Nombre = @PaisLocal)
                UPDATE op.Pais SET PbiPerCapita = @Pbi WHERE Nombre = @PaisLocal;
            ELSE
                EXEC op.usp_AltaPais @Nombre = @PaisLocal, @HorarioUTC = 'UTC+0', @OffsetUTC = 0, @PbiPerCapita = @Pbi;
        END TRY
        BEGIN CATCH
            INSERT INTO cfg.Log_Importacion (Proceso, ArchivoOrigen, DetalleFila, MensajeError)
            VALUES ('ImportarPbi_API', @RutaArchivoJSON, CONCAT('País: ', ISNULL(@PaisNombre,'NULL')), ERROR_MESSAGE());
        END CATCH

        SET @i += 1;
    END
END;
GO
