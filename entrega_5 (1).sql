/* =========================================================================
   Fecha: Octubre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli, Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Descripción: ENTREGA 5 COMPLETA - CORREGIDA SEGÚN DER FINAL
   Incluye:
   - DDL (Creación de todas las tablas según DER).
   - SPs ABM (Altas encapsuladas).
   - Lógica de Negocio (Tarjetas, Suspensiones, Goles, Árbitros, Publicidad, Cambios, Convocatorias).
   - Importación de datos (Simulada).
   - Testing 1:1.
========================================================================= */


-- PARTE 1: DDL (CREACIÓN DE BASE DE DATOS Y TABLAS CORREGIDAS)

USE master;
GO
IF DB_ID('Mundial2026') IS NOT NULL
BEGIN
    ALTER DATABASE Mundial2026 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Mundial2026;
END
GO
CREATE DATABASE Mundial2026;
GO
USE Mundial2026;
GO

CREATE SCHEMA cfg; 
GO
CREATE SCHEMA op;  
GO

-- 1. Países, Sedes y Partidos
CREATE TABLE op.Pais (
    IdPais INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    HorarioUTC VARCHAR(10) NULL 
);

CREATE TABLE op.Sede (
    IdSede INT IDENTITY(1,1) PRIMARY KEY,
    NombreEstadio VARCHAR(100) NOT NULL,
    Ciudad VARCHAR(100) NOT NULL,
    UsoHorario VARCHAR(10) NOT NULL,
    Capacidad INT NOT NULL
);

CREATE TABLE op.Partido (
    IdPartido INT IDENTITY(1,1) PRIMARY KEY,
    IdSede INT NOT NULL FOREIGN KEY REFERENCES op.Sede(IdSede),
    Fecha DATE NOT NULL,
    Hora TIME NOT NULL,
    Fase VARCHAR(50) NOT NULL,
    PublicoAsistente INT NULL,
    Resultado VARCHAR(20) NULL
);

CREATE TABLE op.Club (
    IdClub INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL
);

-- 2. Selecciones, Planteles y Jugadores
CREATE TABLE cfg.Confederacion (
    IdConfederacion INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Continente VARCHAR(100) NOT NULL
);

CREATE TABLE op.Seleccion (
    IdSeleccion INT IDENTITY(1,1) PRIMARY KEY,
    IdPais INT NOT NULL FOREIGN KEY REFERENCES op.Pais(IdPais),
    IdConfederacion INT NOT NULL FOREIGN KEY REFERENCES cfg.Confederacion(IdConfederacion)
);

CREATE TABLE op.Plantel (
    IdPlantel INT IDENTITY(1,1) PRIMARY KEY,
    IdSeleccion INT NOT NULL FOREIGN KEY REFERENCES op.Seleccion(IdSeleccion)
);

CREATE TABLE op.Jugador (
    IdJugador INT IDENTITY(1,1) PRIMARY KEY,
    IdPlantel INT NOT NULL FOREIGN KEY REFERENCES op.Plantel(IdPlantel), 
    IdClub INT NOT NULL FOREIGN KEY REFERENCES op.Club(IdClub),
    Nombre VARCHAR(100) NOT NULL,
    Apellido VARCHAR(100) NOT NULL,
    Nacionalidad VARCHAR(50) NOT NULL
);

-- 3. Convocatorias y Modificaciones (Altas/Bajas) - [NUEVO REQUERIMIENTO]
CREATE TABLE op.Convocado (
    IdConvocado INT IDENTITY(1,1) PRIMARY KEY,
    IdSeleccion INT NOT NULL FOREIGN KEY REFERENCES op.Seleccion(IdSeleccion),
    IdJugador INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador)
);

CREATE TABLE op.Modificacion_Convocatoria (
    IdModificacion INT IDENTITY(1,1) PRIMARY KEY,
    IdConvocado INT NOT NULL FOREIGN KEY REFERENCES op.Convocado(IdConvocado),
    Tipo VARCHAR(10) NOT NULL CHECK (Tipo IN ('Alta', 'Baja')),
    Motivo VARCHAR(255) NOT NULL,
    Fecha DATE NOT NULL
);

-- 4. Cuerpo Técnico - [NUEVO SEGÚN DER]
CREATE TABLE op.CuerpoTecnico (
    IdCuerpoTecnico INT IDENTITY(1,1) PRIMARY KEY,
    IdSeleccion INT NOT NULL FOREIGN KEY REFERENCES op.Seleccion(IdSeleccion),
    IdPlantel INT NOT NULL FOREIGN KEY REFERENCES op.Plantel(IdPlantel),
    Nombre VARCHAR(100) NOT NULL,
    Tipo VARCHAR(50) NOT NULL CHECK (Tipo IN ('DT', 'Ayudante'))
);

-- 5. Alineación y Cambios
CREATE TABLE op.Alineacion (
    IdAlineacion INT IDENTITY(1,1) PRIMARY KEY,
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    IdPlantel INT NOT NULL FOREIGN KEY REFERENCES op.Plantel(IdPlantel),
    EsquemaTactico VARCHAR(20) NULL
);

CREATE TABLE op.Alineacion_Jugador (
    IdAlineacion INT NOT NULL FOREIGN KEY REFERENCES op.Alineacion(IdAlineacion),
    IdJugador INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador),
    Posicion VARCHAR(50) NOT NULL,
    PRIMARY KEY (IdAlineacion, IdJugador)
);

-- Cambios durante el partido - [NUEVO REQUERIMIENTO]
CREATE TABLE op.Cambios (
    IdCambio INT IDENTITY(1,1) PRIMARY KEY,
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    IdJugadorSaliente INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador),
    IdJugadorIngresante INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador),
    Minuto INT NOT NULL,
    Motivo VARCHAR(255) NULL
);

-- 6. Tarjetas, Reglas y Goles (Anotaciones)
CREATE TABLE cfg.Regla_Suspencion (
    IdRegla INT IDENTITY(1,1) PRIMARY KEY,
    Canti_requerida INT NOT NULL,
    Partidos_suspension INT NOT NULL,
    Fase_Limpieza VARCHAR(50) NULL
);

CREATE TABLE cfg.Tipo_Tarjeta (
    IdTipoTarjeta INT PRIMARY KEY,
    IdRegla INT NULL FOREIGN KEY REFERENCES cfg.Regla_Suspencion(IdRegla), 
    Descripcion VARCHAR(50) NOT NULL
);

CREATE TABLE op.Tarjeta (
    IdTarjeta INT IDENTITY(1,1) PRIMARY KEY,
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido), 
    IdJugador INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador), 
    IdTipoTarjeta INT NOT NULL FOREIGN KEY REFERENCES cfg.Tipo_Tarjeta(IdTipoTarjeta),
    Minuto INT NOT NULL,
    Motivo VARCHAR(255) NOT NULL
);

CREATE TABLE cfg.Tipo_Jugada (
    IdTipoJugada INT PRIMARY KEY,
    Descripcion VARCHAR(50) NOT NULL
);

CREATE TABLE cfg.Periodo (
    IdPeriodo INT PRIMARY KEY,
    Descripcion VARCHAR(50) NOT NULL,
    MinutoInicio INT NOT NULL,
    MinutoFin INT NOT NULL
);

CREATE TABLE op.Anotacion (
    IdAnotacion INT IDENTITY(1,1) PRIMARY KEY,
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    IdJugadorAnotador INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador),
    IdJugadorAsistidor INT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador), 
    IdTipoJugada INT NOT NULL FOREIGN KEY REFERENCES cfg.Tipo_Jugada(IdTipoJugada),
    IdPeriodo INT NOT NULL FOREIGN KEY REFERENCES cfg.Periodo(IdPeriodo),
    Minuto INT NOT NULL
);

-- 7. Árbitros
CREATE TABLE op.Arbitro (
    IdArbitro INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellido VARCHAR(100) NOT NULL,
    Nacionalidad VARCHAR(50) NOT NULL,
    Categoria VARCHAR(50) NOT NULL
);

CREATE TABLE op.Lista_Arbitros (
    IdLista INT IDENTITY(1,1) PRIMARY KEY,
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    IdArbitroPrincipal INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro),
    IdArbitroAsistente INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro),
    IdCuartoArbitro INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro),
    IdArbitroVAR INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro)
);

-- 8. Publicidad e Idiomas
CREATE TABLE cfg.Idioma (
    IdIdioma INT IDENTITY(1,1) PRIMARY KEY,
    Descripcion VARCHAR(50) NOT NULL
);

CREATE TABLE cfg.Pais_Idioma (
    IdPais INT NOT NULL FOREIGN KEY REFERENCES op.Pais(IdPais),
    IdIdioma INT NOT NULL FOREIGN KEY REFERENCES cfg.Idioma(IdIdioma),
    PRIMARY KEY (IdPais, IdIdioma)
);

CREATE TABLE cfg.Arbitro_Idioma (
    IdArbitro INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro),
    IdIdioma INT NOT NULL FOREIGN KEY REFERENCES cfg.Idioma(IdIdioma),
    PRIMARY KEY (IdArbitro, IdIdioma)
);

CREATE TABLE cfg.Anunciante (
    IdAnunciante INT IDENTITY(1,1) PRIMARY KEY,
    RazonSocial VARCHAR(100) NOT NULL
);

CREATE TABLE cfg.Campania (
    IdCampania INT IDENTITY(1,1) PRIMARY KEY,
    IdAnunciante INT NOT NULL FOREIGN KEY REFERENCES cfg.Anunciante(IdAnunciante),
    Nombre VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(255) NULL
);

CREATE TABLE cfg.Pieza_Contenido (
    IdPieza INT IDENTITY(1,1) PRIMARY KEY,
    IdCampania INT NOT NULL FOREIGN KEY REFERENCES cfg.Campania(IdCampania),
    IdIdioma INT NOT NULL FOREIGN KEY REFERENCES cfg.Idioma(IdIdioma),
    Duracion INT NOT NULL
);

CREATE TABLE cfg.Pieza_Pais (
    IdPieza INT NOT NULL FOREIGN KEY REFERENCES cfg.Pieza_Contenido(IdPieza),
    IdPais INT NOT NULL FOREIGN KEY REFERENCES op.Pais(IdPais),
    PRIMARY KEY (IdPieza, IdPais)
);

CREATE TABLE op.EspacioPublicitario (
    IdEspacio INT IDENTITY(1,1) PRIMARY KEY,
    IdSede INT NOT NULL FOREIGN KEY REFERENCES op.Sede(IdSede),
    Motivo VARCHAR(100) NOT NULL
);

CREATE TABLE op.Exhibicion (
    IdExhibicion INT IDENTITY(1,1) PRIMARY KEY,
    IdEspacio INT NOT NULL FOREIGN KEY REFERENCES op.EspacioPublicitario(IdEspacio),
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    IdPieza INT NOT NULL FOREIGN KEY REFERENCES cfg.Pieza_Contenido(IdPieza),
    Tarifa DECIMAL(10,2) NOT NULL
);
GO


-- PARTE 2: PROCEDIMIENTOS ALMACENADOS (ABM JUGADOR ADAPTADO Y CAMBIOS)

CREATE OR ALTER PROCEDURE op.usp_AltaJugador
    @IdPlantel INT,
    @IdClub INT,
    @Nombre VARCHAR(100),
    @Apellido VARCHAR(100),
    @Nacionalidad VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM op.Plantel WHERE IdPlantel = @IdPlantel) SET @MensajeErrores += 'El plantel no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Club WHERE IdClub = @IdClub) SET @MensajeErrores += 'El club no existe. | ';
    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = '' SET @MensajeErrores += 'El nombre no puede estar vacío. | ';
    IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = '' SET @MensajeErrores += 'El apellido no puede estar vacío. | ';
    IF @Nacionalidad IS NULL OR LTRIM(RTRIM(@Nacionalidad)) = '' SET @MensajeErrores += 'La nacionalidad es obligatoria. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS: ' + @MensajeErrores;
        THROW 50001, @ErrorThrow, 1;
    END

    INSERT INTO op.Jugador (IdPlantel, IdClub, Nombre, Apellido, Nacionalidad)
    VALUES (@IdPlantel, @IdClub, @Nombre, @Apellido, @Nacionalidad);
END;
GO

-- Procedimiento para Registrar un Cambio de Jugador [NUEVO]
CREATE OR ALTER PROCEDURE op.usp_RegistrarCambioJugador
    @IdPartido INT,
    @IdJugadorSaliente INT,
    @IdJugadorIngresante INT,
    @Minuto INT,
    @Motivo VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido) SET @MensajeErrores += 'El partido no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Jugador WHERE IdJugador = @IdJugadorSaliente) SET @MensajeErrores += 'El jugador saliente no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Jugador WHERE IdJugador = @IdJugadorIngresante) SET @MensajeErrores += 'El jugador ingresante no existe. | ';
    IF @IdJugadorSaliente = @IdJugadorIngresante SET @MensajeErrores += 'El jugador saliente e ingresante no pueden ser el mismo. | ';
    IF @Minuto < 0 OR @Minuto > 130 SET @MensajeErrores += 'El minuto es inválido. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Cambios): ' + @MensajeErrores;
        THROW 50006, @ErrorThrow, 1;
    END

    INSERT INTO op.Cambios (IdPartido, IdJugadorSaliente, IdJugadorIngresante, Minuto, Motivo)
    VALUES (@IdPartido, @IdJugadorSaliente, @IdJugadorIngresante, @Minuto, @Motivo);
END;
GO

-- Procedimiento para Altas/Bajas de Último Momento (Convocatorias) [NUEVO]
CREATE OR ALTER PROCEDURE op.usp_ModificarConvocatoria
    @IdConvocado INT,
    @Tipo VARCHAR(10),
    @Motivo VARCHAR(255),
    @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM op.Convocado WHERE IdConvocado = @IdConvocado) SET @MensajeErrores += 'El convocado no existe. | ';
    IF @Tipo NOT IN ('Alta', 'Baja') SET @MensajeErrores += 'El tipo debe ser Alta o Baja. | ';
    IF @Motivo IS NULL OR LTRIM(RTRIM(@Motivo)) = '' SET @MensajeErrores += 'El motivo es obligatorio. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Modificación Convocatoria): ' + @MensajeErrores;
        THROW 50007, @ErrorThrow, 1;
    END

    INSERT INTO op.Modificacion_Convocatoria (IdConvocado, Tipo, Motivo, Fecha)
    VALUES (@IdConvocado, @Tipo, @Motivo, @Fecha);
END;
GO

-- Procedimiento para Simular Importación de Datos [NUEVO]
CREATE OR ALTER PROCEDURE cfg.usp_ImportarDatosExternos
AS
BEGIN
    -- Lógica simulada de importación
    PRINT 'Simulando importación de datos masiva desde fuentes externas (JSON/CSV)...';
    PRINT 'Datos importados correctamente.';
END;
GO


-- PARTE 3: LÓGICA DE NEGOCIO COMPLEJA (TARJETAS, ÁRBITROS, GOLES, PUBLICIDAD)

-- SP: Calcular Suspensión por Tarjetas (Cursor)
CREATE OR ALTER PROCEDURE op.usp_RegistrarTarjeta_Y_CalcularSuspension
    @IdPartido INT,
    @IdJugador INT,
    @IdTipoTarjeta INT,
    @Minuto INT,
    @Motivo VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido) SET @MensajeErrores += 'El partido no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Jugador WHERE IdJugador = @IdJugador) SET @MensajeErrores += 'El jugador no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM cfg.Tipo_Tarjeta WHERE IdTipoTarjeta = @IdTipoTarjeta) SET @MensajeErrores += 'El tipo de tarjeta no existe. | ';
    IF @Minuto < 0 OR @Minuto > 130 SET @MensajeErrores += 'El minuto debe estar entre 0 y 130. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS: ' + @MensajeErrores;
        THROW 50003, @ErrorThrow, 1;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
 
        INSERT INTO op.Tarjeta (IdPartido, IdJugador, IdTipoTarjeta, Minuto, Motivo)
        VALUES (@IdPartido, @IdJugador, @IdTipoTarjeta, @Minuto, @Motivo);

        DECLARE @TarjetasAcumuladas INT = 0;
        DECLARE @ReglaRequerida INT = 0;
        DECLARE @PartidosDeSancion INT = 0;

        SELECT @ReglaRequerida = rs.Canti_requerida, @PartidosDeSancion = rs.Partidos_suspension
        FROM cfg.Tipo_Tarjeta tt
        INNER JOIN cfg.Regla_Suspencion rs ON tt.IdRegla = rs.IdRegla
        WHERE tt.IdTipoTarjeta = @IdTipoTarjeta;

        DECLARE cursor_tarjetas CURSOR FOR
            SELECT IdTarjeta FROM op.Tarjeta WHERE IdJugador = @IdJugador AND IdTipoTarjeta = @IdTipoTarjeta;

        DECLARE @IdTarjetaRecorrida INT;
        OPEN cursor_tarjetas;
        FETCH NEXT FROM cursor_tarjetas INTO @IdTarjetaRecorrida;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @TarjetasAcumuladas = @TarjetasAcumuladas + 1;
            FETCH NEXT FROM cursor_tarjetas INTO @IdTarjetaRecorrida;
        END
        CLOSE cursor_tarjetas;
        DEALLOCATE cursor_tarjetas;

        IF @ReglaRequerida > 0 AND @TarjetasAcumuladas >= @ReglaRequerida
        BEGIN
            PRINT '>>> ATENCIÓN: El Jugador ID ' + CAST(@IdJugador AS VARCHAR) + ' debe ser SUSPENDIDO por ' + CAST(@PartidosDeSancion AS VARCHAR) + ' partido(s). <<<';
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- SP: Registrar Gol y Actualizar Resultado (Cursor)
CREATE OR ALTER PROCEDURE op.usp_RegistrarGol_Y_ActualizarResultado
    @IdPartido INT,
    @IdJugadorAnotador INT,
    @IdJugadorAsistidor INT, 
    @IdTipoJugada INT,
    @IdPeriodo INT,
    @Minuto INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO op.Anotacion (IdPartido, IdJugadorAnotador, IdJugadorAsistidor, IdTipoJugada, IdPeriodo, Minuto)
        VALUES (@IdPartido, @IdJugadorAnotador, @IdJugadorAsistidor, @IdTipoJugada, @IdPeriodo, @Minuto);

        DECLARE @TotalGolesPartido INT = 0;
        DECLARE @TextoResultado VARCHAR(20);
        
        DECLARE cursor_goles CURSOR FOR
            SELECT IdAnotacion FROM op.Anotacion WHERE IdPartido = @IdPartido;

        DECLARE @IdGolRecorrido INT;
        OPEN cursor_goles;
        FETCH NEXT FROM cursor_goles INTO @IdGolRecorrido;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @TotalGolesPartido = @TotalGolesPartido + 1;
            FETCH NEXT FROM cursor_goles INTO @IdGolRecorrido;
        END
        CLOSE cursor_goles;
        DEALLOCATE cursor_goles;

        SET @TextoResultado = CAST(@TotalGolesPartido AS VARCHAR) + ' Goles';
        UPDATE op.Partido SET Resultado = @TextoResultado WHERE IdPartido = @IdPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- SP: Designación de Árbitros (Validación Ética con Cursor)
CREATE OR ALTER PROCEDURE op.usp_DesignarArbitros
    @IdPartido INT,
    @IdArbitroPrincipal INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';
    DECLARE @PaisA VARCHAR(100), @PaisB VARCHAR(100);
    
    DECLARE cursor_paises CURSOR FOR 
        SELECT p.Nombre FROM op.Alineacion a
        INNER JOIN op.Plantel pl ON a.IdPlantel = pl.IdPlantel
        INNER JOIN op.Seleccion s ON pl.IdSeleccion = s.IdSeleccion
        INNER JOIN op.Pais p ON s.IdPais = p.IdPais
        WHERE a.IdPartido = @IdPartido;
        
    OPEN cursor_paises;
    FETCH NEXT FROM cursor_paises INTO @PaisA;
    FETCH NEXT FROM cursor_paises INTO @PaisB;
    CLOSE cursor_paises;
    DEALLOCATE cursor_paises;

    DECLARE @NacPrincipal VARCHAR(50) = (SELECT Nacionalidad FROM op.Arbitro WHERE IdArbitro = @IdArbitroPrincipal);

    IF @NacPrincipal IN (@PaisA, @PaisB) 
        SET @MensajeErrores += 'CONFLICTO ÉTICO: El árbitro principal tiene la misma nacionalidad que uno de los equipos. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS: ' + @MensajeErrores;
        THROW 50005, @ErrorThrow, 1;
    END

    -- Se asigna si pasa la validación
    INSERT INTO op.Lista_Arbitros (IdPartido, IdArbitroPrincipal, IdArbitroAsistente, IdCuartoArbitro, IdArbitroVAR)
    VALUES (@IdPartido, @IdArbitroPrincipal, @IdArbitroPrincipal, @IdArbitroPrincipal, @IdArbitroPrincipal);
END;
GO

-- SP: Asignar Publicidad (Cursores Paralelos)
CREATE OR ALTER PROCEDURE op.usp_AsignarPublicidadPartido
    @IdPartido INT,
    @IdSede INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @IdEspacioActual INT;
        DECLARE cursor_espacios CURSOR FOR 
            SELECT TOP 4 IdEspacio FROM op.EspacioPublicitario WHERE IdSede = @IdSede;
            
        DECLARE @IdPiezaSeleccionada INT;
        DECLARE cursor_piezas CURSOR FOR 
            SELECT TOP 4 IdPieza FROM cfg.Pieza_Contenido ORDER BY NEWID(); 

        OPEN cursor_espacios;
        OPEN cursor_piezas;
        FETCH NEXT FROM cursor_espacios INTO @IdEspacioActual;
        FETCH NEXT FROM cursor_piezas INTO @IdPiezaSeleccionada;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT INTO op.Exhibicion (IdEspacio, IdPartido, IdPieza, Tarifa)
            VALUES (@IdEspacioActual, @IdPartido, @IdPiezaSeleccionada, 15000.00);
            FETCH NEXT FROM cursor_espacios INTO @IdEspacioActual;
            FETCH NEXT FROM cursor_piezas INTO @IdPiezaSeleccionada;
        END

        CLOSE cursor_piezas; DEALLOCATE cursor_piezas;
        CLOSE cursor_espacios; DEALLOCATE cursor_espacios;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- PARTE 4: TESTING (Ejecuta TODOS los requerimientos)

PRINT '================ INICIANDO TESTING INTEGRAL ================';

-- Setup Básico
INSERT INTO op.Pais (Nombre, HorarioUTC) VALUES ('Argentina', 'UTC-3'), ('Brasil', 'UTC-3');
INSERT INTO cfg.Confederacion (Nombre, Continente) VALUES ('CONMEBOL', 'América del Sur');
INSERT INTO op.Sede (NombreEstadio, Ciudad, UsoHorario, Capacidad) VALUES ('Monumental', 'BsAs', 'UTC-3', 85000);
INSERT INTO op.Partido (IdSede, Fecha, Hora, Fase) VALUES (1, '2026-06-15', '16:00:00', 'Grupos');
INSERT INTO op.Seleccion (IdPais, IdConfederacion) VALUES (1, 1), (2, 1);
INSERT INTO op.Plantel (IdSeleccion) VALUES (1), (2);
INSERT INTO op.Club (Nombre) VALUES ('Inter Miami'), ('Flamengo');

-- 1. Test Altas de Jugador (Convocatoria)
EXEC op.usp_AltaJugador @IdPlantel = 1, @IdClub = 1, @Nombre = 'Lionel', @Apellido = 'Messi', @Nacionalidad = 'Argentina';
EXEC op.usp_AltaJugador @IdPlantel = 1, @IdClub = 1, @Nombre = 'Ángel', @Apellido = 'Di María', @Nacionalidad = 'Argentina';

-- 2. Test Convocatorias (Altas/Bajas último momento)
INSERT INTO op.Convocado (IdSeleccion, IdJugador) VALUES (1, 2);
EXEC op.usp_ModificarConvocatoria @IdConvocado = 1, @Tipo = 'Baja', @Motivo = 'Lesión', @Fecha = '2026-06-01';

-- 3. Test Alineaciones y Cambios
INSERT INTO op.Alineacion (IdPartido, IdPlantel, EsquemaTactico) VALUES (1, 1, '4-3-3');
INSERT INTO op.Alineacion_Jugador (IdAlineacion, IdJugador, Posicion) VALUES (1, 1, 'Delantero');
EXEC op.usp_RegistrarCambioJugador @IdPartido = 1, @IdJugadorSaliente = 2, @IdJugadorIngresante = 1, @Minuto = 75, @Motivo = 'Táctico';

-- 4. Test Tarjetas y Suspensiones
INSERT INTO cfg.Regla_Suspencion (Canti_requerida, Partidos_suspension, Fase_Limpieza) VALUES (2, 1, 'Semifinal');
INSERT INTO cfg.Tipo_Tarjeta (IdTipoTarjeta, IdRegla, Descripcion) VALUES (1, 1, 'Amarilla');
EXEC op.usp_RegistrarTarjeta_Y_CalcularSuspension @IdPartido = 1, @IdJugador = 1, @IdTipoTarjeta = 1, @Minuto = 45, @Motivo = 'Falta';
EXEC op.usp_RegistrarTarjeta_Y_CalcularSuspension @IdPartido = 1, @IdJugador = 1, @IdTipoTarjeta = 1, @Minuto = 88, @Motivo = 'Protesta';

-- 5. Test Goles
INSERT INTO cfg.Tipo_Jugada (IdTipoJugada, Descripcion) VALUES (1, 'Jugada');
INSERT INTO cfg.Periodo (IdPeriodo, Descripcion, MinutoInicio, MinutoFin) VALUES (1, 'Primer Tiempo', 0, 45);
EXEC op.usp_RegistrarGol_Y_ActualizarResultado @IdPartido = 1, @IdJugadorAnotador = 1, @IdJugadorAsistidor = NULL, @IdTipoJugada = 1, @IdPeriodo = 1, @Minuto = 15;

-- 6. Test Árbitros
INSERT INTO op.Arbitro (Nombre, Apellido, Nacionalidad, Categoria) VALUES ('Nestor', 'Pitana', 'Argentina', 'FIFA'), ('Pierluigi', 'Collina', 'Italia', 'FIFA');
PRINT 'Probando Conflicto Ético de Árbitro (Debe Fallar)...';
BEGIN TRY EXEC op.usp_DesignarArbitros @IdPartido = 1, @IdArbitroPrincipal = 1; END TRY BEGIN CATCH PRINT ERROR_MESSAGE(); END CATCH
PRINT 'Probando Árbitro válido...';
EXEC op.usp_DesignarArbitros @IdPartido = 1, @IdArbitroPrincipal = 2;

-- 7. Test Publicidad
INSERT INTO cfg.Idioma (Descripcion) VALUES ('Español');
INSERT INTO cfg.Anunciante (RazonSocial) VALUES ('Coca Cola');
INSERT INTO cfg.Campania (IdAnunciante, Nombre) VALUES (1, 'Mundial');
INSERT INTO cfg.Pieza_Contenido (IdCampania, IdIdioma, Duracion) VALUES (1, 1, 30), (1, 1, 15), (1, 1, 30), (1, 1, 20);
INSERT INTO op.EspacioPublicitario (IdSede, Motivo) VALUES (1, 'Panel Norte'), (1, 'Panel Sur'), (1, 'Panel Este'), (1, 'Panel Oeste');
EXEC op.usp_AsignarPublicidadPartido @IdPartido = 1, @IdSede = 1;

-- 8. Importación Externa
EXEC cfg.usp_ImportarDatosExternos;

PRINT '================ TESTING COMPLETADO CON ÉXITO ================';
GO
