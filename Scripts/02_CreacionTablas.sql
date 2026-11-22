/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: Creación de todas las tablas y restricciones del sistema
             Mundial2026, validando existencia previa con OBJECT_ID.
========================================================================= */

USE Mundial2026;
GO

-- 1. Países, Sedes y Clubes
IF OBJECT_ID('op.Pais', 'U') IS NULL
CREATE TABLE op.Pais (
    IdPais INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    HorarioUTC VARCHAR(10) NULL,
    OffsetUTC INT NOT NULL DEFAULT 0,
    PbiPerCapita DECIMAL(12,2) NULL
);

IF OBJECT_ID('op.Sede', 'U') IS NULL
CREATE TABLE op.Sede (
    IdSede INT IDENTITY(1,1) PRIMARY KEY,
    IdPais INT NOT NULL FOREIGN KEY REFERENCES op.Pais(IdPais),
    NombreEstadio VARCHAR(100) NOT NULL,
    Ciudad VARCHAR(100) NOT NULL,
    UsoHorario VARCHAR(10) NOT NULL,
    Capacidad INT NOT NULL
);

IF OBJECT_ID('op.Club', 'U') IS NULL
CREATE TABLE op.Club (
    IdClub INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL
);

-- 2. Confederaciones, Selecciones, Partidos, Planteles y Jugadores
IF OBJECT_ID('cfg.Confederacion', 'U') IS NULL
CREATE TABLE cfg.Confederacion (
    IdConfederacion INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Continente VARCHAR(100) NOT NULL
);

IF OBJECT_ID('op.Seleccion', 'U') IS NULL
CREATE TABLE op.Seleccion (
    IdSeleccion INT IDENTITY(1,1) PRIMARY KEY,
    IdPais INT NOT NULL FOREIGN KEY REFERENCES op.Pais(IdPais),
    IdConfederacion INT NOT NULL FOREIGN KEY REFERENCES cfg.Confederacion(IdConfederacion),
    Grupo CHAR(1) NULL
);

IF OBJECT_ID('op.Partido', 'U') IS NULL
CREATE TABLE op.Partido (
    IdPartido INT IDENTITY(1,1) PRIMARY KEY,
    IdSede INT NOT NULL FOREIGN KEY REFERENCES op.Sede(IdSede),
    IdSeleccionLocal INT NOT NULL FOREIGN KEY REFERENCES op.Seleccion(IdSeleccion),
    IdSeleccionVisitante INT NOT NULL FOREIGN KEY REFERENCES op.Seleccion(IdSeleccion),
    Fecha DATE NOT NULL,
    HoraLocal TIME NOT NULL,
    HoraUTC TIME NOT NULL,
    Fase VARCHAR(50) NOT NULL,
    PublicoAsistente INT NULL,
    Resultado VARCHAR(20) NULL,
    TuvoAlargue BIT NOT NULL DEFAULT 0
);

IF OBJECT_ID('op.Plantel', 'U') IS NULL
CREATE TABLE op.Plantel (
    IdPlantel INT IDENTITY(1,1) PRIMARY KEY,
    IdSeleccion INT NOT NULL FOREIGN KEY REFERENCES op.Seleccion(IdSeleccion)
);

IF OBJECT_ID('op.Jugador', 'U') IS NULL
CREATE TABLE op.Jugador (
    IdJugador INT IDENTITY(1,1) PRIMARY KEY,
    IdPlantel INT NOT NULL FOREIGN KEY REFERENCES op.Plantel(IdPlantel),
    IdClub INT NOT NULL FOREIGN KEY REFERENCES op.Club(IdClub),
    Nombre VARCHAR(100) NOT NULL,
    Apellido VARCHAR(100) NOT NULL,
    Nacionalidad VARCHAR(50) NOT NULL,
    Documento VARCHAR(30) NULL,
    FechaNacimiento DATE NULL,
    PosicionHabitual VARCHAR(50) NULL,
    Dorsal INT NULL
);

-- 3. Convocatorias y Modificaciones (Altas/Bajas)
IF OBJECT_ID('op.Convocado', 'U') IS NULL
CREATE TABLE op.Convocado (
    IdConvocado INT IDENTITY(1,1) PRIMARY KEY,
    IdSeleccion INT NOT NULL FOREIGN KEY REFERENCES op.Seleccion(IdSeleccion),
    IdJugador INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador)
);

IF OBJECT_ID('op.Modificacion_Convocatoria', 'U') IS NULL
CREATE TABLE op.Modificacion_Convocatoria (
    IdModificacion INT IDENTITY(1,1) PRIMARY KEY,
    IdConvocado INT NOT NULL FOREIGN KEY REFERENCES op.Convocado(IdConvocado),
    Tipo VARCHAR(10) NOT NULL CHECK (Tipo IN ('Alta', 'Baja')),
    Motivo VARCHAR(255) NOT NULL,
    Fecha DATE NOT NULL
);

-- 4. Cuerpo Técnico
IF OBJECT_ID('op.CuerpoTecnico', 'U') IS NULL
CREATE TABLE op.CuerpoTecnico (
    IdCuerpoTecnico INT IDENTITY(1,1) PRIMARY KEY,
    IdSeleccion INT NOT NULL FOREIGN KEY REFERENCES op.Seleccion(IdSeleccion),
    IdPlantel INT NOT NULL FOREIGN KEY REFERENCES op.Plantel(IdPlantel),
    Nombre VARCHAR(100) NOT NULL,
    Tipo VARCHAR(50) NOT NULL CHECK (Tipo IN ('DT', 'Ayudante')),
    Documento VARCHAR(30) NULL,
    FechaNacimiento DATE NULL
);

-- 5. Alineación y Cambios
IF OBJECT_ID('op.Alineacion', 'U') IS NULL
CREATE TABLE op.Alineacion (
    IdAlineacion INT IDENTITY(1,1) PRIMARY KEY,
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    IdPlantel INT NOT NULL FOREIGN KEY REFERENCES op.Plantel(IdPlantel),
    EsquemaTactico VARCHAR(20) NULL
);

IF OBJECT_ID('op.Alineacion_Jugador', 'U') IS NULL
CREATE TABLE op.Alineacion_Jugador (
    IdAlineacion INT NOT NULL FOREIGN KEY REFERENCES op.Alineacion(IdAlineacion),
    IdJugador INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador),
    Posicion VARCHAR(50) NOT NULL,
    EsTitular BIT NOT NULL DEFAULT 1,
    Dorsal INT NULL,
    PRIMARY KEY (IdAlineacion, IdJugador)
);

IF OBJECT_ID('op.Cambios', 'U') IS NULL
CREATE TABLE op.Cambios (
    IdCambio INT IDENTITY(1,1) PRIMARY KEY,
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    IdJugadorSaliente INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador),
    IdJugadorIngresante INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador),
    Minuto INT NOT NULL,
    Motivo VARCHAR(255) NULL
);

-- 6. Tarjetas, Reglas, Suspensiones y Goles (Anotaciones)
IF OBJECT_ID('cfg.Regla_Suspencion', 'U') IS NULL
CREATE TABLE cfg.Regla_Suspencion (
    IdRegla INT IDENTITY(1,1) PRIMARY KEY,
    Canti_requerida INT NOT NULL,
    Partidos_suspension INT NOT NULL,
    Fase_Limpieza VARCHAR(50) NULL
);

IF OBJECT_ID('cfg.Tipo_Tarjeta', 'U') IS NULL
CREATE TABLE cfg.Tipo_Tarjeta (
    IdTipoTarjeta INT PRIMARY KEY,
    IdRegla INT NULL FOREIGN KEY REFERENCES cfg.Regla_Suspencion(IdRegla),
    Descripcion VARCHAR(50) NOT NULL
);

IF OBJECT_ID('op.Tarjeta', 'U') IS NULL
CREATE TABLE op.Tarjeta (
    IdTarjeta INT IDENTITY(1,1) PRIMARY KEY,
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    IdJugador INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador),
    IdTipoTarjeta INT NOT NULL FOREIGN KEY REFERENCES cfg.Tipo_Tarjeta(IdTipoTarjeta),
    Minuto INT NOT NULL,
    Motivo VARCHAR(255) NOT NULL
);

IF OBJECT_ID('op.Suspension', 'U') IS NULL
CREATE TABLE op.Suspension (
    IdSuspension INT IDENTITY(1,1) PRIMARY KEY,
    IdJugador INT NOT NULL FOREIGN KEY REFERENCES op.Jugador(IdJugador),
    IdPartidoOrigen INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    PartidosRestantes INT NOT NULL,
    Motivo VARCHAR(100) NOT NULL,
    Activa BIT NOT NULL DEFAULT 1
);

IF OBJECT_ID('cfg.Tipo_Jugada', 'U') IS NULL
CREATE TABLE cfg.Tipo_Jugada (
    IdTipoJugada INT PRIMARY KEY,
    Descripcion VARCHAR(50) NOT NULL
);

IF OBJECT_ID('cfg.Periodo', 'U') IS NULL
CREATE TABLE cfg.Periodo (
    IdPeriodo INT PRIMARY KEY,
    Descripcion VARCHAR(50) NOT NULL,
    MinutoInicio INT NOT NULL,
    MinutoFin INT NOT NULL
);

IF OBJECT_ID('op.Anotacion', 'U') IS NULL
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
IF OBJECT_ID('op.Arbitro', 'U') IS NULL
CREATE TABLE op.Arbitro (
    IdArbitro INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellido VARCHAR(100) NOT NULL,
    Nacionalidad VARCHAR(50) NOT NULL,
    Categoria VARCHAR(50) NOT NULL,
    Documento VARCHAR(30) NULL,
    FechaNacimiento DATE NULL
);

IF OBJECT_ID('op.Lista_Arbitros', 'U') IS NULL
CREATE TABLE op.Lista_Arbitros (
    IdLista INT IDENTITY(1,1) PRIMARY KEY,
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    IdArbitroPrincipal INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro),
    IdArbitroAsistente1 INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro),
    IdArbitroAsistente2 INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro),
    IdCuartoArbitro INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro),
    IdArbitroVAR INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro)
);

IF OBJECT_ID('op.Informe_Arbitro', 'U') IS NULL
CREATE TABLE op.Informe_Arbitro (
    IdInforme INT IDENTITY(1,1) PRIMARY KEY,
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    IdArbitro INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro),
    Tipo VARCHAR(30) NOT NULL CHECK (Tipo IN ('Informe', 'Sancion')),
    Descripcion VARCHAR(255) NOT NULL,
    Fecha DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE)
);

-- 8. Publicidad e Idiomas
IF OBJECT_ID('cfg.Idioma', 'U') IS NULL
CREATE TABLE cfg.Idioma (
    IdIdioma INT IDENTITY(1,1) PRIMARY KEY,
    Descripcion VARCHAR(50) NOT NULL
);

IF OBJECT_ID('cfg.Pais_Idioma', 'U') IS NULL
CREATE TABLE cfg.Pais_Idioma (
    IdPais INT NOT NULL FOREIGN KEY REFERENCES op.Pais(IdPais),
    IdIdioma INT NOT NULL FOREIGN KEY REFERENCES cfg.Idioma(IdIdioma),
    PRIMARY KEY (IdPais, IdIdioma)
);

IF OBJECT_ID('cfg.Arbitro_Idioma', 'U') IS NULL
CREATE TABLE cfg.Arbitro_Idioma (
    IdArbitro INT NOT NULL FOREIGN KEY REFERENCES op.Arbitro(IdArbitro),
    IdIdioma INT NOT NULL FOREIGN KEY REFERENCES cfg.Idioma(IdIdioma),
    PRIMARY KEY (IdArbitro, IdIdioma)
);

IF OBJECT_ID('cfg.Anunciante', 'U') IS NULL
CREATE TABLE cfg.Anunciante (
    IdAnunciante INT IDENTITY(1,1) PRIMARY KEY,
    IdPais INT NOT NULL FOREIGN KEY REFERENCES op.Pais(IdPais),
    RazonSocial VARCHAR(100) NOT NULL
);

IF OBJECT_ID('cfg.Campania', 'U') IS NULL
CREATE TABLE cfg.Campania (
    IdCampania INT IDENTITY(1,1) PRIMARY KEY,
    IdAnunciante INT NOT NULL FOREIGN KEY REFERENCES cfg.Anunciante(IdAnunciante),
    Nombre VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(255) NULL
);

IF OBJECT_ID('cfg.Pieza_Contenido', 'U') IS NULL
CREATE TABLE cfg.Pieza_Contenido (
    IdPieza INT IDENTITY(1,1) PRIMARY KEY,
    IdCampania INT NOT NULL FOREIGN KEY REFERENCES cfg.Campania(IdCampania),
    IdIdioma INT NOT NULL FOREIGN KEY REFERENCES cfg.Idioma(IdIdioma),
    Duracion INT NOT NULL,
    Tarifa DECIMAL(10,2) NOT NULL DEFAULT 15000.00
);

IF OBJECT_ID('cfg.Pieza_Pais', 'U') IS NULL
CREATE TABLE cfg.Pieza_Pais (
    IdPieza INT NOT NULL FOREIGN KEY REFERENCES cfg.Pieza_Contenido(IdPieza),
    IdPais INT NOT NULL FOREIGN KEY REFERENCES op.Pais(IdPais),
    PRIMARY KEY (IdPieza, IdPais)
);

IF OBJECT_ID('op.EspacioPublicitario', 'U') IS NULL
CREATE TABLE op.EspacioPublicitario (
    IdEspacio INT IDENTITY(1,1) PRIMARY KEY,
    IdSede INT NOT NULL FOREIGN KEY REFERENCES op.Sede(IdSede),
    Motivo VARCHAR(100) NOT NULL
);

IF OBJECT_ID('op.Exhibicion', 'U') IS NULL
CREATE TABLE op.Exhibicion (
    IdExhibicion INT IDENTITY(1,1) PRIMARY KEY,
    IdEspacio INT NOT NULL FOREIGN KEY REFERENCES op.EspacioPublicitario(IdEspacio),
    IdPartido INT NOT NULL FOREIGN KEY REFERENCES op.Partido(IdPartido),
    IdPieza INT NOT NULL FOREIGN KEY REFERENCES cfg.Pieza_Contenido(IdPieza),
    Tarifa DECIMAL(10,2) NOT NULL
);
GO
