/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: Procedimientos Almacenados de ABM (Alta, Modificar, Baja) para
             todas las tablas del sistema Mundial2026 (33 tablas x 3 = 99 SPs).
             Convención: <esquema>.usp_<Alta|Modificar|Baja><Tabla>.
========================================================================= */

USE Mundial2026;
GO

-- =========================================================================
-- 1. op.Pais
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaPais
    @Nombre VARCHAR(100), @HorarioUTC VARCHAR(10) = NULL, @OffsetUTC INT = 0, @PbiPerCapita DECIMAL(12,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = '' SET @Err += 'El nombre del país es obligatorio. | ';
    IF @OffsetUTC < -12 OR @OffsetUTC > 14 SET @Err += 'OffsetUTC fuera de rango (-12 a 14). | ';
    IF LEN(@Err) > 0 THROW 50101, @Err, 1;

    INSERT INTO op.Pais (Nombre, HorarioUTC, OffsetUTC, PbiPerCapita)
    VALUES (@Nombre, @HorarioUTC, @OffsetUTC, @PbiPerCapita);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarPais
    @IdPais INT, @Nombre VARCHAR(100), @HorarioUTC VARCHAR(10) = NULL, @OffsetUTC INT = 0, @PbiPerCapita DECIMAL(12,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Pais WHERE IdPais = @IdPais) THROW 50102, 'El país no existe.', 1;
    UPDATE op.Pais SET Nombre = @Nombre, HorarioUTC = @HorarioUTC, OffsetUTC = @OffsetUTC, PbiPerCapita = @PbiPerCapita
    WHERE IdPais = @IdPais;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaPais
    @IdPais INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Pais WHERE IdPais = @IdPais) THROW 50103, 'El país no existe.', 1;
    DELETE FROM op.Pais WHERE IdPais = @IdPais;
END;
GO

-- =========================================================================
-- 2. op.Sede
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaSede
    @IdPais INT, @NombreEstadio VARCHAR(100), @Ciudad VARCHAR(100), @UsoHorario VARCHAR(10), @Capacidad INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF NOT EXISTS (SELECT 1 FROM op.Pais WHERE IdPais = @IdPais) SET @Err += 'El país no existe. | ';
    IF @NombreEstadio IS NULL OR LTRIM(RTRIM(@NombreEstadio)) = '' SET @Err += 'El nombre del estadio es obligatorio. | ';
    IF @Capacidad <= 0 SET @Err += 'La capacidad debe ser mayor a cero. | ';
    IF LEN(@Err) > 0 THROW 50104, @Err, 1;

    INSERT INTO op.Sede (IdPais, NombreEstadio, Ciudad, UsoHorario, Capacidad)
    VALUES (@IdPais, @NombreEstadio, @Ciudad, @UsoHorario, @Capacidad);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarSede
    @IdSede INT, @IdPais INT, @NombreEstadio VARCHAR(100), @Ciudad VARCHAR(100), @UsoHorario VARCHAR(10), @Capacidad INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Sede WHERE IdSede = @IdSede) THROW 50105, 'La sede no existe.', 1;
    IF @Capacidad <= 0 THROW 50105, 'La capacidad debe ser mayor a cero.', 1;
    UPDATE op.Sede SET IdPais = @IdPais, NombreEstadio = @NombreEstadio, Ciudad = @Ciudad, UsoHorario = @UsoHorario, Capacidad = @Capacidad
    WHERE IdSede = @IdSede;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaSede
    @IdSede INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Sede WHERE IdSede = @IdSede) THROW 50106, 'La sede no existe.', 1;
    DELETE FROM op.Sede WHERE IdSede = @IdSede;
END;
GO

-- =========================================================================
-- 3. op.Club
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaClub
    @Nombre VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = '' THROW 50107, 'El nombre del club es obligatorio.', 1;
    INSERT INTO op.Club (Nombre) VALUES (@Nombre);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarClub
    @IdClub INT, @Nombre VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Club WHERE IdClub = @IdClub) THROW 50108, 'El club no existe.', 1;
    UPDATE op.Club SET Nombre = @Nombre WHERE IdClub = @IdClub;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaClub
    @IdClub INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Club WHERE IdClub = @IdClub) THROW 50109, 'El club no existe.', 1;
    DELETE FROM op.Club WHERE IdClub = @IdClub;
END;
GO

-- =========================================================================
-- 4. cfg.Confederacion
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaConfederacion
    @Nombre VARCHAR(100), @Continente VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = '' THROW 50110, 'El nombre de la confederación es obligatorio.', 1;
    INSERT INTO cfg.Confederacion (Nombre, Continente) VALUES (@Nombre, @Continente);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarConfederacion
    @IdConfederacion INT, @Nombre VARCHAR(100), @Continente VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Confederacion WHERE IdConfederacion = @IdConfederacion) THROW 50111, 'La confederación no existe.', 1;
    UPDATE cfg.Confederacion SET Nombre = @Nombre, Continente = @Continente WHERE IdConfederacion = @IdConfederacion;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaConfederacion
    @IdConfederacion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Confederacion WHERE IdConfederacion = @IdConfederacion) THROW 50112, 'La confederación no existe.', 1;
    DELETE FROM cfg.Confederacion WHERE IdConfederacion = @IdConfederacion;
END;
GO

-- =========================================================================
-- 5. op.Seleccion
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaSeleccion
    @IdPais INT, @IdConfederacion INT, @Grupo CHAR(1) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF NOT EXISTS (SELECT 1 FROM op.Pais WHERE IdPais = @IdPais) SET @Err += 'El país no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM cfg.Confederacion WHERE IdConfederacion = @IdConfederacion) SET @Err += 'La confederación no existe. | ';
    IF LEN(@Err) > 0 THROW 50113, @Err, 1;

    INSERT INTO op.Seleccion (IdPais, IdConfederacion, Grupo) VALUES (@IdPais, @IdConfederacion, @Grupo);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarSeleccion
    @IdSeleccion INT, @IdPais INT, @IdConfederacion INT, @Grupo CHAR(1) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion) THROW 50114, 'La selección no existe.', 1;
    UPDATE op.Seleccion SET IdPais = @IdPais, IdConfederacion = @IdConfederacion, Grupo = @Grupo WHERE IdSeleccion = @IdSeleccion;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaSeleccion
    @IdSeleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion) THROW 50115, 'La selección no existe.', 1;
    DELETE FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion;
END;
GO

-- =========================================================================
-- 6. op.Partido
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaPartido
    @IdSede INT, @IdSeleccionLocal INT, @IdSeleccionVisitante INT, @Fecha DATE,
    @HoraLocal TIME, @HoraUTC TIME, @Fase VARCHAR(50), @PublicoAsistente INT = NULL,
    @Resultado VARCHAR(20) = NULL, @TuvoAlargue BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF NOT EXISTS (SELECT 1 FROM op.Sede WHERE IdSede = @IdSede) SET @Err += 'La sede no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccionLocal) SET @Err += 'La selección local no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccionVisitante) SET @Err += 'La selección visitante no existe. | ';
    IF @IdSeleccionLocal = @IdSeleccionVisitante SET @Err += 'Local y visitante no pueden ser la misma selección. | ';
    IF LEN(@Err) > 0 THROW 50116, @Err, 1;

    INSERT INTO op.Partido (IdSede, IdSeleccionLocal, IdSeleccionVisitante, Fecha, HoraLocal, HoraUTC, Fase, PublicoAsistente, Resultado, TuvoAlargue)
    VALUES (@IdSede, @IdSeleccionLocal, @IdSeleccionVisitante, @Fecha, @HoraLocal, @HoraUTC, @Fase, @PublicoAsistente, @Resultado, @TuvoAlargue);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarPartido
    @IdPartido INT, @IdSede INT, @Fecha DATE, @HoraLocal TIME, @HoraUTC TIME,
    @Fase VARCHAR(50), @PublicoAsistente INT = NULL, @Resultado VARCHAR(20) = NULL, @TuvoAlargue BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido) THROW 50117, 'El partido no existe.', 1;
    UPDATE op.Partido
    SET IdSede = @IdSede, Fecha = @Fecha, HoraLocal = @HoraLocal, HoraUTC = @HoraUTC,
        Fase = @Fase, PublicoAsistente = @PublicoAsistente, Resultado = @Resultado, TuvoAlargue = @TuvoAlargue
    WHERE IdPartido = @IdPartido;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaPartido
    @IdPartido INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido) THROW 50118, 'El partido no existe.', 1;
    DELETE FROM op.Partido WHERE IdPartido = @IdPartido;
END;
GO

-- =========================================================================
-- 7. op.Plantel
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaPlantel
    @IdSeleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion) THROW 50119, 'La selección no existe.', 1;
    INSERT INTO op.Plantel (IdSeleccion) VALUES (@IdSeleccion);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarPlantel
    @IdPlantel INT, @IdSeleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Plantel WHERE IdPlantel = @IdPlantel) THROW 50120, 'El plantel no existe.', 1;
    UPDATE op.Plantel SET IdSeleccion = @IdSeleccion WHERE IdPlantel = @IdPlantel;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaPlantel
    @IdPlantel INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Plantel WHERE IdPlantel = @IdPlantel) THROW 50121, 'El plantel no existe.', 1;
    DELETE FROM op.Plantel WHERE IdPlantel = @IdPlantel;
END;
GO

-- =========================================================================
-- 8. op.Jugador
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

    INSERT INTO op.Jugador (IdPlantel, IdClub, Nombre, Apellido, Nacionalidad, Documento, FechaNacimiento, PosicionHabitual, Dorsal)
    VALUES (@IdPlantel, @IdClub, @Nombre, @Apellido, @Nacionalidad, @Documento, @FechaNacimiento, @PosicionHabitual, @Dorsal);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarJugador
    @IdJugador INT, @IdPlantel INT, @IdClub INT, @PosicionHabitual VARCHAR(50) = NULL, @Dorsal INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF NOT EXISTS (SELECT 1 FROM op.Jugador WHERE IdJugador = @IdJugador) SET @Err += 'El jugador no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Plantel WHERE IdPlantel = @IdPlantel) SET @Err += 'El plantel no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Club WHERE IdClub = @IdClub) SET @Err += 'El club no existe. | ';
    IF LEN(@Err) > 0 THROW 50002, @Err, 1;

    UPDATE op.Jugador
    SET IdPlantel = @IdPlantel, IdClub = @IdClub,
        PosicionHabitual = ISNULL(@PosicionHabitual, PosicionHabitual),
        Dorsal = ISNULL(@Dorsal, Dorsal)
    WHERE IdJugador = @IdJugador;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaJugador
    @IdJugador INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Jugador WHERE IdJugador = @IdJugador) THROW 50004, 'El jugador no existe.', 1;
    DELETE FROM op.Jugador WHERE IdJugador = @IdJugador;
END;
GO

-- =========================================================================
-- 9. op.Convocado
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaConvocado
    @IdSeleccion INT, @IdJugador INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion) SET @Err += 'La selección no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Jugador WHERE IdJugador = @IdJugador) SET @Err += 'El jugador no existe. | ';
    IF LEN(@Err) > 0 THROW 50122, @Err, 1;
    INSERT INTO op.Convocado (IdSeleccion, IdJugador) VALUES (@IdSeleccion, @IdJugador);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarConvocado
    @IdConvocado INT, @IdSeleccion INT, @IdJugador INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Convocado WHERE IdConvocado = @IdConvocado) THROW 50123, 'El convocado no existe.', 1;
    UPDATE op.Convocado SET IdSeleccion = @IdSeleccion, IdJugador = @IdJugador WHERE IdConvocado = @IdConvocado;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaConvocado
    @IdConvocado INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Convocado WHERE IdConvocado = @IdConvocado) THROW 50124, 'El convocado no existe.', 1;
    DELETE FROM op.Convocado WHERE IdConvocado = @IdConvocado;
END;
GO

-- =========================================================================
-- 10. op.Modificacion_Convocatoria
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaModificacion_Convocatoria
    @IdConvocado INT, @Tipo VARCHAR(10), @Motivo VARCHAR(255), @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF NOT EXISTS (SELECT 1 FROM op.Convocado WHERE IdConvocado = @IdConvocado) SET @Err += 'El convocado no existe. | ';
    IF @Tipo NOT IN ('Alta', 'Baja') SET @Err += 'El tipo debe ser Alta o Baja. | ';
    IF @Motivo IS NULL OR LTRIM(RTRIM(@Motivo)) = '' SET @Err += 'El motivo es obligatorio. | ';
    IF LEN(@Err) > 0 THROW 50125, @Err, 1;
    INSERT INTO op.Modificacion_Convocatoria (IdConvocado, Tipo, Motivo, Fecha) VALUES (@IdConvocado, @Tipo, @Motivo, @Fecha);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarModificacion_Convocatoria
    @IdModificacion INT, @Tipo VARCHAR(10), @Motivo VARCHAR(255), @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Modificacion_Convocatoria WHERE IdModificacion = @IdModificacion) THROW 50126, 'La modificación no existe.', 1;
    UPDATE op.Modificacion_Convocatoria SET Tipo = @Tipo, Motivo = @Motivo, Fecha = @Fecha WHERE IdModificacion = @IdModificacion;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaModificacion_Convocatoria
    @IdModificacion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Modificacion_Convocatoria WHERE IdModificacion = @IdModificacion) THROW 50127, 'La modificación no existe.', 1;
    DELETE FROM op.Modificacion_Convocatoria WHERE IdModificacion = @IdModificacion;
END;
GO

-- =========================================================================
-- 11. op.CuerpoTecnico
-- =========================================================================
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
    INSERT INTO op.CuerpoTecnico (IdSeleccion, IdPlantel, Nombre, Tipo, Documento, FechaNacimiento)
    VALUES (@IdSeleccion, @IdPlantel, @Nombre, @Tipo, @Documento, @FechaNacimiento);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarCuerpoTecnico
    @IdCuerpoTecnico INT, @Nombre VARCHAR(100), @Tipo VARCHAR(50), @Documento VARCHAR(30) = NULL, @FechaNacimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.CuerpoTecnico WHERE IdCuerpoTecnico = @IdCuerpoTecnico) THROW 50129, 'El integrante de cuerpo técnico no existe.', 1;
    UPDATE op.CuerpoTecnico SET Nombre = @Nombre, Tipo = @Tipo, Documento = @Documento, FechaNacimiento = @FechaNacimiento WHERE IdCuerpoTecnico = @IdCuerpoTecnico;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaCuerpoTecnico
    @IdCuerpoTecnico INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.CuerpoTecnico WHERE IdCuerpoTecnico = @IdCuerpoTecnico) THROW 50130, 'El integrante de cuerpo técnico no existe.', 1;
    DELETE FROM op.CuerpoTecnico WHERE IdCuerpoTecnico = @IdCuerpoTecnico;
END;
GO

-- =========================================================================
-- 12. op.Alineacion
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaAlineacion
    @IdPartido INT, @IdPlantel INT, @EsquemaTactico VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido) SET @Err += 'El partido no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Plantel WHERE IdPlantel = @IdPlantel) SET @Err += 'El plantel no existe. | ';
    IF LEN(@Err) > 0 THROW 50131, @Err, 1;
    INSERT INTO op.Alineacion (IdPartido, IdPlantel, EsquemaTactico) VALUES (@IdPartido, @IdPlantel, @EsquemaTactico);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarAlineacion
    @IdAlineacion INT, @EsquemaTactico VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Alineacion WHERE IdAlineacion = @IdAlineacion) THROW 50132, 'La alineación no existe.', 1;
    UPDATE op.Alineacion SET EsquemaTactico = @EsquemaTactico WHERE IdAlineacion = @IdAlineacion;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaAlineacion
    @IdAlineacion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Alineacion WHERE IdAlineacion = @IdAlineacion) THROW 50133, 'La alineación no existe.', 1;
    DELETE FROM op.Alineacion WHERE IdAlineacion = @IdAlineacion;
END;
GO

-- =========================================================================
-- 13. op.Alineacion_Jugador
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaAlineacion_Jugador
    @IdAlineacion INT, @IdJugador INT, @Posicion VARCHAR(50), @EsTitular BIT = 1, @Dorsal INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF NOT EXISTS (SELECT 1 FROM op.Alineacion WHERE IdAlineacion = @IdAlineacion) SET @Err += 'La alineación no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Jugador WHERE IdJugador = @IdJugador) SET @Err += 'El jugador no existe. | ';
    IF @EsTitular = 1 AND EXISTS (SELECT 1 FROM op.Suspension WHERE IdJugador = @IdJugador AND Activa = 1 AND PartidosRestantes > 0)
        SET @Err += 'El jugador está suspendido y no puede ser titular. | ';
    IF LEN(@Err) > 0 THROW 50134, @Err, 1;
    INSERT INTO op.Alineacion_Jugador (IdAlineacion, IdJugador, Posicion, EsTitular, Dorsal)
    VALUES (@IdAlineacion, @IdJugador, @Posicion, @EsTitular, @Dorsal);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarAlineacion_Jugador
    @IdAlineacion INT, @IdJugador INT, @Posicion VARCHAR(50), @EsTitular BIT, @Dorsal INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Alineacion_Jugador WHERE IdAlineacion = @IdAlineacion AND IdJugador = @IdJugador)
        THROW 50135, 'El jugador no figura en esa alineación.', 1;
    UPDATE op.Alineacion_Jugador SET Posicion = @Posicion, EsTitular = @EsTitular, Dorsal = @Dorsal
    WHERE IdAlineacion = @IdAlineacion AND IdJugador = @IdJugador;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaAlineacion_Jugador
    @IdAlineacion INT, @IdJugador INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Alineacion_Jugador WHERE IdAlineacion = @IdAlineacion AND IdJugador = @IdJugador)
        THROW 50136, 'El jugador no figura en esa alineación.', 1;
    DELETE FROM op.Alineacion_Jugador WHERE IdAlineacion = @IdAlineacion AND IdJugador = @IdJugador;
END;
GO

-- =========================================================================
-- 14. op.Cambios
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaCambios
    @IdPartido INT, @IdJugadorSaliente INT, @IdJugadorIngresante INT, @Minuto INT, @Motivo VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido) SET @Err += 'El partido no existe. | ';
    IF @IdJugadorSaliente = @IdJugadorIngresante SET @Err += 'Saliente e ingresante no pueden ser el mismo jugador. | ';
    IF @Minuto < 0 OR @Minuto > 130 SET @Err += 'Minuto inválido. | ';
    IF LEN(@Err) > 0 THROW 50137, @Err, 1;
    INSERT INTO op.Cambios (IdPartido, IdJugadorSaliente, IdJugadorIngresante, Minuto, Motivo)
    VALUES (@IdPartido, @IdJugadorSaliente, @IdJugadorIngresante, @Minuto, @Motivo);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarCambios
    @IdCambio INT, @Minuto INT, @Motivo VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Cambios WHERE IdCambio = @IdCambio) THROW 50138, 'El cambio no existe.', 1;
    UPDATE op.Cambios SET Minuto = @Minuto, Motivo = @Motivo WHERE IdCambio = @IdCambio;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaCambios
    @IdCambio INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Cambios WHERE IdCambio = @IdCambio) THROW 50139, 'El cambio no existe.', 1;
    DELETE FROM op.Cambios WHERE IdCambio = @IdCambio;
END;
GO

-- =========================================================================
-- 15. cfg.Regla_Suspencion
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaRegla_Suspencion
    @Canti_requerida INT, @Partidos_suspension INT, @Fase_Limpieza VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Canti_requerida <= 0 OR @Partidos_suspension <= 0 THROW 50140, 'Cantidades deben ser mayores a cero.', 1;
    INSERT INTO cfg.Regla_Suspencion (Canti_requerida, Partidos_suspension, Fase_Limpieza)
    VALUES (@Canti_requerida, @Partidos_suspension, @Fase_Limpieza);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarRegla_Suspencion
    @IdRegla INT, @Canti_requerida INT, @Partidos_suspension INT, @Fase_Limpieza VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Regla_Suspencion WHERE IdRegla = @IdRegla) THROW 50141, 'La regla no existe.', 1;
    UPDATE cfg.Regla_Suspencion SET Canti_requerida = @Canti_requerida, Partidos_suspension = @Partidos_suspension, Fase_Limpieza = @Fase_Limpieza
    WHERE IdRegla = @IdRegla;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaRegla_Suspencion
    @IdRegla INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Regla_Suspencion WHERE IdRegla = @IdRegla) THROW 50142, 'La regla no existe.', 1;
    DELETE FROM cfg.Regla_Suspencion WHERE IdRegla = @IdRegla;
END;
GO

-- =========================================================================
-- 16. cfg.Tipo_Tarjeta
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaTipo_Tarjeta
    @IdTipoTarjeta INT, @IdRegla INT = NULL, @Descripcion VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM cfg.Tipo_Tarjeta WHERE IdTipoTarjeta = @IdTipoTarjeta) THROW 50143, 'El tipo de tarjeta ya existe.', 1;
    INSERT INTO cfg.Tipo_Tarjeta (IdTipoTarjeta, IdRegla, Descripcion) VALUES (@IdTipoTarjeta, @IdRegla, @Descripcion);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarTipo_Tarjeta
    @IdTipoTarjeta INT, @IdRegla INT = NULL, @Descripcion VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Tipo_Tarjeta WHERE IdTipoTarjeta = @IdTipoTarjeta) THROW 50144, 'El tipo de tarjeta no existe.', 1;
    UPDATE cfg.Tipo_Tarjeta SET IdRegla = @IdRegla, Descripcion = @Descripcion WHERE IdTipoTarjeta = @IdTipoTarjeta;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaTipo_Tarjeta
    @IdTipoTarjeta INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Tipo_Tarjeta WHERE IdTipoTarjeta = @IdTipoTarjeta) THROW 50145, 'El tipo de tarjeta no existe.', 1;
    DELETE FROM cfg.Tipo_Tarjeta WHERE IdTipoTarjeta = @IdTipoTarjeta;
END;
GO

-- =========================================================================
-- 17. op.Tarjeta
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaTarjeta
    @IdPartido INT, @IdJugador INT, @IdTipoTarjeta INT, @Minuto INT, @Motivo VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Minuto < 0 OR @Minuto > 130 THROW 50146, 'Minuto inválido.', 1;
    INSERT INTO op.Tarjeta (IdPartido, IdJugador, IdTipoTarjeta, Minuto, Motivo)
    VALUES (@IdPartido, @IdJugador, @IdTipoTarjeta, @Minuto, @Motivo);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarTarjeta
    @IdTarjeta INT, @Minuto INT, @Motivo VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Tarjeta WHERE IdTarjeta = @IdTarjeta) THROW 50147, 'La tarjeta no existe.', 1;
    UPDATE op.Tarjeta SET Minuto = @Minuto, Motivo = @Motivo WHERE IdTarjeta = @IdTarjeta;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaTarjeta
    @IdTarjeta INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Tarjeta WHERE IdTarjeta = @IdTarjeta) THROW 50148, 'La tarjeta no existe.', 1;
    DELETE FROM op.Tarjeta WHERE IdTarjeta = @IdTarjeta;
END;
GO

-- =========================================================================
-- 18. op.Suspension
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaSuspension
    @IdJugador INT, @IdPartidoOrigen INT, @PartidosRestantes INT, @Motivo VARCHAR(100), @Activa BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @PartidosRestantes <= 0 THROW 50149, 'PartidosRestantes debe ser mayor a cero.', 1;
    INSERT INTO op.Suspension (IdJugador, IdPartidoOrigen, PartidosRestantes, Motivo, Activa)
    VALUES (@IdJugador, @IdPartidoOrigen, @PartidosRestantes, @Motivo, @Activa);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarSuspension
    @IdSuspension INT, @PartidosRestantes INT, @Activa BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Suspension WHERE IdSuspension = @IdSuspension) THROW 50150, 'La suspensión no existe.', 1;
    UPDATE op.Suspension SET PartidosRestantes = @PartidosRestantes, Activa = @Activa WHERE IdSuspension = @IdSuspension;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaSuspension
    @IdSuspension INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Suspension WHERE IdSuspension = @IdSuspension) THROW 50151, 'La suspensión no existe.', 1;
    DELETE FROM op.Suspension WHERE IdSuspension = @IdSuspension;
END;
GO

-- =========================================================================
-- 19. cfg.Tipo_Jugada
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaTipo_Jugada
    @IdTipoJugada INT, @Descripcion VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM cfg.Tipo_Jugada WHERE IdTipoJugada = @IdTipoJugada) THROW 50152, 'El tipo de jugada ya existe.', 1;
    INSERT INTO cfg.Tipo_Jugada (IdTipoJugada, Descripcion) VALUES (@IdTipoJugada, @Descripcion);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarTipo_Jugada
    @IdTipoJugada INT, @Descripcion VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Tipo_Jugada WHERE IdTipoJugada = @IdTipoJugada) THROW 50153, 'El tipo de jugada no existe.', 1;
    UPDATE cfg.Tipo_Jugada SET Descripcion = @Descripcion WHERE IdTipoJugada = @IdTipoJugada;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaTipo_Jugada
    @IdTipoJugada INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Tipo_Jugada WHERE IdTipoJugada = @IdTipoJugada) THROW 50154, 'El tipo de jugada no existe.', 1;
    DELETE FROM cfg.Tipo_Jugada WHERE IdTipoJugada = @IdTipoJugada;
END;
GO

-- =========================================================================
-- 20. cfg.Periodo
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaPeriodo
    @IdPeriodo INT, @Descripcion VARCHAR(50), @MinutoInicio INT, @MinutoFin INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @MinutoFin < @MinutoInicio THROW 50155, 'MinutoFin no puede ser menor a MinutoInicio.', 1;
    INSERT INTO cfg.Periodo (IdPeriodo, Descripcion, MinutoInicio, MinutoFin) VALUES (@IdPeriodo, @Descripcion, @MinutoInicio, @MinutoFin);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarPeriodo
    @IdPeriodo INT, @Descripcion VARCHAR(50), @MinutoInicio INT, @MinutoFin INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Periodo WHERE IdPeriodo = @IdPeriodo) THROW 50156, 'El período no existe.', 1;
    UPDATE cfg.Periodo SET Descripcion = @Descripcion, MinutoInicio = @MinutoInicio, MinutoFin = @MinutoFin WHERE IdPeriodo = @IdPeriodo;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaPeriodo
    @IdPeriodo INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Periodo WHERE IdPeriodo = @IdPeriodo) THROW 50157, 'El período no existe.', 1;
    DELETE FROM cfg.Periodo WHERE IdPeriodo = @IdPeriodo;
END;
GO

-- =========================================================================
-- 21. op.Anotacion
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaAnotacion
    @IdPartido INT, @IdJugadorAnotador INT, @IdJugadorAsistidor INT = NULL, @IdTipoJugada INT, @IdPeriodo INT, @Minuto INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Minuto < 0 OR @Minuto > 130 THROW 50158, 'Minuto inválido.', 1;
    INSERT INTO op.Anotacion (IdPartido, IdJugadorAnotador, IdJugadorAsistidor, IdTipoJugada, IdPeriodo, Minuto)
    VALUES (@IdPartido, @IdJugadorAnotador, @IdJugadorAsistidor, @IdTipoJugada, @IdPeriodo, @Minuto);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarAnotacion
    @IdAnotacion INT, @IdJugadorAsistidor INT = NULL, @IdTipoJugada INT, @IdPeriodo INT, @Minuto INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Anotacion WHERE IdAnotacion = @IdAnotacion) THROW 50159, 'La anotación no existe.', 1;
    UPDATE op.Anotacion SET IdJugadorAsistidor = @IdJugadorAsistidor, IdTipoJugada = @IdTipoJugada, IdPeriodo = @IdPeriodo, Minuto = @Minuto
    WHERE IdAnotacion = @IdAnotacion;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaAnotacion
    @IdAnotacion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Anotacion WHERE IdAnotacion = @IdAnotacion) THROW 50160, 'La anotación no existe.', 1;
    DELETE FROM op.Anotacion WHERE IdAnotacion = @IdAnotacion;
END;
GO

-- =========================================================================
-- 22. op.Arbitro
-- =========================================================================
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
    INSERT INTO op.Arbitro (Nombre, Apellido, Nacionalidad, Categoria, Documento, FechaNacimiento)
    VALUES (@Nombre, @Apellido, @Nacionalidad, @Categoria, @Documento, @FechaNacimiento);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarArbitro
    @IdArbitro INT, @Nacionalidad VARCHAR(50), @Categoria VARCHAR(50), @Documento VARCHAR(30) = NULL, @FechaNacimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Arbitro WHERE IdArbitro = @IdArbitro) THROW 50162, 'El árbitro no existe.', 1;
    UPDATE op.Arbitro SET Nacionalidad = @Nacionalidad, Categoria = @Categoria, Documento = @Documento, FechaNacimiento = @FechaNacimiento
    WHERE IdArbitro = @IdArbitro;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaArbitro
    @IdArbitro INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Arbitro WHERE IdArbitro = @IdArbitro) THROW 50163, 'El árbitro no existe.', 1;
    DELETE FROM op.Arbitro WHERE IdArbitro = @IdArbitro;
END;
GO

-- =========================================================================
-- 23. op.Lista_Arbitros
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaLista_Arbitros
    @IdPartido INT, @IdArbitroPrincipal INT, @IdArbitroAsistente1 INT, @IdArbitroAsistente2 INT, @IdCuartoArbitro INT, @IdArbitroVAR INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido) THROW 50164, 'El partido no existe.', 1;
    INSERT INTO op.Lista_Arbitros (IdPartido, IdArbitroPrincipal, IdArbitroAsistente1, IdArbitroAsistente2, IdCuartoArbitro, IdArbitroVAR)
    VALUES (@IdPartido, @IdArbitroPrincipal, @IdArbitroAsistente1, @IdArbitroAsistente2, @IdCuartoArbitro, @IdArbitroVAR);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarLista_Arbitros
    @IdLista INT, @IdArbitroPrincipal INT, @IdArbitroAsistente1 INT, @IdArbitroAsistente2 INT, @IdCuartoArbitro INT, @IdArbitroVAR INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Lista_Arbitros WHERE IdLista = @IdLista) THROW 50165, 'La lista arbitral no existe.', 1;
    UPDATE op.Lista_Arbitros
    SET IdArbitroPrincipal = @IdArbitroPrincipal, IdArbitroAsistente1 = @IdArbitroAsistente1,
        IdArbitroAsistente2 = @IdArbitroAsistente2, IdCuartoArbitro = @IdCuartoArbitro, IdArbitroVAR = @IdArbitroVAR
    WHERE IdLista = @IdLista;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaLista_Arbitros
    @IdLista INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Lista_Arbitros WHERE IdLista = @IdLista) THROW 50166, 'La lista arbitral no existe.', 1;
    DELETE FROM op.Lista_Arbitros WHERE IdLista = @IdLista;
END;
GO

-- =========================================================================
-- 24. op.Informe_Arbitro
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaInforme_Arbitro
    @IdPartido INT, @IdArbitro INT, @Tipo VARCHAR(30), @Descripcion VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Tipo NOT IN ('Informe', 'Sancion') THROW 50167, 'El tipo debe ser Informe o Sancion.', 1;
    INSERT INTO op.Informe_Arbitro (IdPartido, IdArbitro, Tipo, Descripcion) VALUES (@IdPartido, @IdArbitro, @Tipo, @Descripcion);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarInforme_Arbitro
    @IdInforme INT, @Tipo VARCHAR(30), @Descripcion VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Informe_Arbitro WHERE IdInforme = @IdInforme) THROW 50168, 'El informe no existe.', 1;
    UPDATE op.Informe_Arbitro SET Tipo = @Tipo, Descripcion = @Descripcion WHERE IdInforme = @IdInforme;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaInforme_Arbitro
    @IdInforme INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Informe_Arbitro WHERE IdInforme = @IdInforme) THROW 50169, 'El informe no existe.', 1;
    DELETE FROM op.Informe_Arbitro WHERE IdInforme = @IdInforme;
END;
GO

-- =========================================================================
-- 25. cfg.Idioma
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaIdioma
    @Descripcion VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Descripcion IS NULL OR LTRIM(RTRIM(@Descripcion)) = '' THROW 50170, 'La descripción del idioma es obligatoria.', 1;
    INSERT INTO cfg.Idioma (Descripcion) VALUES (@Descripcion);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarIdioma
    @IdIdioma INT, @Descripcion VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Idioma WHERE IdIdioma = @IdIdioma) THROW 50171, 'El idioma no existe.', 1;
    UPDATE cfg.Idioma SET Descripcion = @Descripcion WHERE IdIdioma = @IdIdioma;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaIdioma
    @IdIdioma INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Idioma WHERE IdIdioma = @IdIdioma) THROW 50172, 'El idioma no existe.', 1;
    DELETE FROM cfg.Idioma WHERE IdIdioma = @IdIdioma;
END;
GO

-- =========================================================================
-- 26. cfg.Pais_Idioma
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaPais_Idioma
    @IdPais INT, @IdIdioma INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO cfg.Pais_Idioma (IdPais, IdIdioma) VALUES (@IdPais, @IdIdioma);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarPais_Idioma
    @IdPais INT, @IdIdiomaAnterior INT, @IdIdiomaNuevo INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Pais_Idioma WHERE IdPais = @IdPais AND IdIdioma = @IdIdiomaAnterior)
        THROW 50173, 'La relación País-Idioma no existe.', 1;
    UPDATE cfg.Pais_Idioma SET IdIdioma = @IdIdiomaNuevo WHERE IdPais = @IdPais AND IdIdioma = @IdIdiomaAnterior;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaPais_Idioma
    @IdPais INT, @IdIdioma INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM cfg.Pais_Idioma WHERE IdPais = @IdPais AND IdIdioma = @IdIdioma;
END;
GO

-- =========================================================================
-- 27. cfg.Arbitro_Idioma
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaArbitro_Idioma
    @IdArbitro INT, @IdIdioma INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO cfg.Arbitro_Idioma (IdArbitro, IdIdioma) VALUES (@IdArbitro, @IdIdioma);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarArbitro_Idioma
    @IdArbitro INT, @IdIdiomaAnterior INT, @IdIdiomaNuevo INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Arbitro_Idioma WHERE IdArbitro = @IdArbitro AND IdIdioma = @IdIdiomaAnterior)
        THROW 50174, 'La relación Árbitro-Idioma no existe.', 1;
    UPDATE cfg.Arbitro_Idioma SET IdIdioma = @IdIdiomaNuevo WHERE IdArbitro = @IdArbitro AND IdIdioma = @IdIdiomaAnterior;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaArbitro_Idioma
    @IdArbitro INT, @IdIdioma INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM cfg.Arbitro_Idioma WHERE IdArbitro = @IdArbitro AND IdIdioma = @IdIdioma;
END;
GO

-- =========================================================================
-- 28. cfg.Anunciante
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaAnunciante
    @IdPais INT, @RazonSocial VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF @RazonSocial IS NULL OR LTRIM(RTRIM(@RazonSocial)) = '' THROW 50175, 'La razón social es obligatoria.', 1;
    INSERT INTO cfg.Anunciante (IdPais, RazonSocial) VALUES (@IdPais, @RazonSocial);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarAnunciante
    @IdAnunciante INT, @IdPais INT, @RazonSocial VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Anunciante WHERE IdAnunciante = @IdAnunciante) THROW 50176, 'El anunciante no existe.', 1;
    UPDATE cfg.Anunciante SET IdPais = @IdPais, RazonSocial = @RazonSocial WHERE IdAnunciante = @IdAnunciante;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaAnunciante
    @IdAnunciante INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Anunciante WHERE IdAnunciante = @IdAnunciante) THROW 50177, 'El anunciante no existe.', 1;
    DELETE FROM cfg.Anunciante WHERE IdAnunciante = @IdAnunciante;
END;
GO

-- =========================================================================
-- 29. cfg.Campania
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaCampania
    @IdAnunciante INT, @Nombre VARCHAR(100), @Descripcion VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = '' THROW 50178, 'El nombre de la campaña es obligatorio.', 1;
    INSERT INTO cfg.Campania (IdAnunciante, Nombre, Descripcion) VALUES (@IdAnunciante, @Nombre, @Descripcion);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarCampania
    @IdCampania INT, @Nombre VARCHAR(100), @Descripcion VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Campania WHERE IdCampania = @IdCampania) THROW 50179, 'La campaña no existe.', 1;
    UPDATE cfg.Campania SET Nombre = @Nombre, Descripcion = @Descripcion WHERE IdCampania = @IdCampania;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaCampania
    @IdCampania INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Campania WHERE IdCampania = @IdCampania) THROW 50180, 'La campaña no existe.', 1;
    DELETE FROM cfg.Campania WHERE IdCampania = @IdCampania;
END;
GO

-- =========================================================================
-- 30. cfg.Pieza_Contenido
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaPieza_Contenido
    @IdCampania INT, @IdIdioma INT, @Duracion INT, @Tarifa DECIMAL(10,2) = 15000.00
AS
BEGIN
    SET NOCOUNT ON;
    IF @Duracion <= 0 OR @Tarifa <= 0 THROW 50181, 'Duración y tarifa deben ser mayores a cero.', 1;
    INSERT INTO cfg.Pieza_Contenido (IdCampania, IdIdioma, Duracion, Tarifa) VALUES (@IdCampania, @IdIdioma, @Duracion, @Tarifa);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarPieza_Contenido
    @IdPieza INT, @IdIdioma INT, @Duracion INT, @Tarifa DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Pieza_Contenido WHERE IdPieza = @IdPieza) THROW 50182, 'La pieza no existe.', 1;
    UPDATE cfg.Pieza_Contenido SET IdIdioma = @IdIdioma, Duracion = @Duracion, Tarifa = @Tarifa WHERE IdPieza = @IdPieza;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaPieza_Contenido
    @IdPieza INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Pieza_Contenido WHERE IdPieza = @IdPieza) THROW 50183, 'La pieza no existe.', 1;
    DELETE FROM cfg.Pieza_Contenido WHERE IdPieza = @IdPieza;
END;
GO

-- =========================================================================
-- 31. cfg.Pieza_Pais
-- =========================================================================
CREATE OR ALTER PROCEDURE cfg.usp_AltaPieza_Pais
    @IdPieza INT, @IdPais INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO cfg.Pieza_Pais (IdPieza, IdPais) VALUES (@IdPieza, @IdPais);
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ModificarPieza_Pais
    @IdPieza INT, @IdPaisAnterior INT, @IdPaisNuevo INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cfg.Pieza_Pais WHERE IdPieza = @IdPieza AND IdPais = @IdPaisAnterior)
        THROW 50184, 'La relación Pieza-País no existe.', 1;
    UPDATE cfg.Pieza_Pais SET IdPais = @IdPaisNuevo WHERE IdPieza = @IdPieza AND IdPais = @IdPaisAnterior;
END;
GO

CREATE OR ALTER PROCEDURE cfg.usp_BajaPieza_Pais
    @IdPieza INT, @IdPais INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM cfg.Pieza_Pais WHERE IdPieza = @IdPieza AND IdPais = @IdPais;
END;
GO

-- =========================================================================
-- 32. op.EspacioPublicitario
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaEspacioPublicitario
    @IdSede INT, @Motivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF (SELECT COUNT(*) FROM op.EspacioPublicitario WHERE IdSede = @IdSede) >= 4
        THROW 50185, 'Cada sede admite exactamente cuatro (4) espacios publicitarios.', 1;
    INSERT INTO op.EspacioPublicitario (IdSede, Motivo) VALUES (@IdSede, @Motivo);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarEspacioPublicitario
    @IdEspacio INT, @Motivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.EspacioPublicitario WHERE IdEspacio = @IdEspacio) THROW 50186, 'El espacio publicitario no existe.', 1;
    UPDATE op.EspacioPublicitario SET Motivo = @Motivo WHERE IdEspacio = @IdEspacio;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaEspacioPublicitario
    @IdEspacio INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.EspacioPublicitario WHERE IdEspacio = @IdEspacio) THROW 50187, 'El espacio publicitario no existe.', 1;
    DELETE FROM op.EspacioPublicitario WHERE IdEspacio = @IdEspacio;
END;
GO

-- =========================================================================
-- 33. op.Exhibicion
-- =========================================================================
CREATE OR ALTER PROCEDURE op.usp_AltaExhibicion
    @IdEspacio INT, @IdPartido INT, @IdPieza INT, @Tarifa DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Tarifa <= 0 THROW 50188, 'La tarifa debe ser mayor a cero.', 1;
    INSERT INTO op.Exhibicion (IdEspacio, IdPartido, IdPieza, Tarifa) VALUES (@IdEspacio, @IdPartido, @IdPieza, @Tarifa);
END;
GO

CREATE OR ALTER PROCEDURE op.usp_ModificarExhibicion
    @IdExhibicion INT, @Tarifa DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Exhibicion WHERE IdExhibicion = @IdExhibicion) THROW 50189, 'La exhibición no existe.', 1;
    UPDATE op.Exhibicion SET Tarifa = @Tarifa WHERE IdExhibicion = @IdExhibicion;
END;
GO

CREATE OR ALTER PROCEDURE op.usp_BajaExhibicion
    @IdExhibicion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM op.Exhibicion WHERE IdExhibicion = @IdExhibicion) THROW 50190, 'La exhibición no existe.', 1;
    DELETE FROM op.Exhibicion WHERE IdExhibicion = @IdExhibicion;
END;
GO
