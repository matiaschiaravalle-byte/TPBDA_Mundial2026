/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli, Agustín Nicolás Mussi Pulcini
   Objetivo: Carga de datos para los reportes:
             - 16 selecciones en 4 grupos, cada una con 24 convocados y CT.
             - 9 sedes en 3 países y 4 husos horarios distintos, con 4 espacios.
             - Fase de grupos completa + cuartos, semifinales, 3er puesto y final.
             - 18 árbitros, 8 anunciantes de 7 países con campañas y piezas.
========================================================================= */

USE Mundial2026;
GO

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM op.Sede WHERE NombreEstadio = 'BC Place')
BEGIN
    PRINT 'Los datos de la entrega 7 ya estaban cargados. No se hizo nada.';
    RETURN;
END;

DECLARE @IdBase INT = ISNULL((SELECT MAX(IdPartido) FROM op.Partido), 0);
DECLARE @i INT, @n INT, @k INT, @d INT, @s INT, @Cant INT;

-- 1. CATÁLOGOS
IF NOT EXISTS (SELECT 1 FROM cfg.Regla_Suspencion)
    INSERT INTO cfg.Regla_Suspencion (Canti_requerida, Partidos_suspension, Fase_Limpieza) VALUES (2, 1, 'Semifinal');

IF NOT EXISTS (SELECT 1 FROM cfg.Tipo_Tarjeta WHERE Descripcion = 'Amarilla')
    INSERT INTO cfg.Tipo_Tarjeta (IdTipoTarjeta, IdRegla, Descripcion)
    SELECT ISNULL(MAX(IdTipoTarjeta), 0) + 1, (SELECT MIN(IdRegla) FROM cfg.Regla_Suspencion), 'Amarilla' FROM cfg.Tipo_Tarjeta;
IF NOT EXISTS (SELECT 1 FROM cfg.Tipo_Tarjeta WHERE Descripcion = 'Doble Amarilla')
    INSERT INTO cfg.Tipo_Tarjeta (IdTipoTarjeta, IdRegla, Descripcion)
    SELECT ISNULL(MAX(IdTipoTarjeta), 0) + 1, NULL, 'Doble Amarilla' FROM cfg.Tipo_Tarjeta;
IF NOT EXISTS (SELECT 1 FROM cfg.Tipo_Tarjeta WHERE Descripcion = 'Roja Directa')
    INSERT INTO cfg.Tipo_Tarjeta (IdTipoTarjeta, IdRegla, Descripcion)
    SELECT ISNULL(MAX(IdTipoTarjeta), 0) + 1, NULL, 'Roja Directa' FROM cfg.Tipo_Tarjeta;

DECLARE @TiposJugada TABLE (Nro INT IDENTITY(1,1), Descripcion VARCHAR(50));
INSERT INTO @TiposJugada (Descripcion) VALUES ('Jugada'), ('En contra'), ('Penal'), ('Cabezazo'), ('Tiro libre');
INSERT INTO cfg.Tipo_Jugada (IdTipoJugada, Descripcion)
SELECT (SELECT ISNULL(MAX(IdTipoJugada), 0) FROM cfg.Tipo_Jugada) + ROW_NUMBER() OVER (ORDER BY t.Nro), t.Descripcion
FROM @TiposJugada t
WHERE NOT EXISTS (SELECT 1 FROM cfg.Tipo_Jugada x WHERE x.Descripcion = t.Descripcion);

DECLARE @Periodos TABLE (Nro INT IDENTITY(1,1), Descripcion VARCHAR(50), Inicio INT, Fin INT);
INSERT INTO @Periodos (Descripcion, Inicio, Fin) VALUES ('Primer Tiempo', 0, 45), ('Segundo Tiempo', 46, 90), ('Alargue', 91, 120);
INSERT INTO cfg.Periodo (IdPeriodo, Descripcion, MinutoInicio, MinutoFin)
SELECT (SELECT ISNULL(MAX(IdPeriodo), 0) FROM cfg.Periodo) + ROW_NUMBER() OVER (ORDER BY p.Nro), p.Descripcion, p.Inicio, p.Fin
FROM @Periodos p
WHERE NOT EXISTS (SELECT 1 FROM cfg.Periodo x WHERE x.Descripcion = p.Descripcion);

DECLARE @IdAmarilla INT = (SELECT IdTipoTarjeta FROM cfg.Tipo_Tarjeta WHERE Descripcion = 'Amarilla');
DECLARE @IdDobleAmarilla INT = (SELECT IdTipoTarjeta FROM cfg.Tipo_Tarjeta WHERE Descripcion = 'Doble Amarilla');
DECLARE @IdRojaDirecta INT = (SELECT IdTipoTarjeta FROM cfg.Tipo_Tarjeta WHERE Descripcion = 'Roja Directa');
DECLARE @IdJugada INT = (SELECT IdTipoJugada FROM cfg.Tipo_Jugada WHERE Descripcion = 'Jugada');
DECLARE @IdEnContra INT = (SELECT IdTipoJugada FROM cfg.Tipo_Jugada WHERE Descripcion = 'En contra');
DECLARE @IdPenal INT = (SELECT IdTipoJugada FROM cfg.Tipo_Jugada WHERE Descripcion = 'Penal');
DECLARE @IdCabezazo INT = (SELECT IdTipoJugada FROM cfg.Tipo_Jugada WHERE Descripcion = 'Cabezazo');
DECLARE @IdPT INT = (SELECT MIN(IdPeriodo) FROM cfg.Periodo WHERE Descripcion = 'Primer Tiempo');
DECLARE @IdST INT = (SELECT MIN(IdPeriodo) FROM cfg.Periodo WHERE Descripcion = 'Segundo Tiempo');
DECLARE @IdAl INT = (SELECT MIN(IdPeriodo) FROM cfg.Periodo WHERE Descripcion = 'Alargue');

INSERT INTO cfg.Idioma (Descripcion)
SELECT v.Descripcion
FROM (VALUES ('Español'), ('Inglés'), ('Portugués'), ('Francés'), ('Alemán'), ('Japonés'), ('Árabe'),
             ('Neerlandés'), ('Italiano'), ('Chino'), ('Hindi'), ('Coreano')) v(Descripcion)
WHERE NOT EXISTS (SELECT 1 FROM cfg.Idioma i WHERE i.Descripcion = v.Descripcion);

INSERT INTO cfg.Confederacion (Nombre, Continente)
SELECT v.Nombre, v.Continente
FROM (VALUES ('CONMEBOL', 'América del Sur'), ('UEFA', 'Europa'), ('CONCACAF', 'América del Norte y Central'),
             ('CAF', 'África'), ('AFC', 'Asia')) v(Nombre, Continente)
WHERE NOT EXISTS (SELECT 1 FROM cfg.Confederacion c WHERE c.Nombre = v.Nombre);

/*
   2. PAÍSES (selecciones + mercados publicitarios)
   OffsetUTC: huso vigente en junio-julio. PbiPerCapita: valores de referencia
   aproximados en USD (los existentes de la entrega 5 no se modifican).
*/
DECLARE @Paises TABLE (Nombre VARCHAR(100), OffsetUTC INT, Pbi DECIMAL(12,2), Idioma VARCHAR(50),
                       Confederacion VARCHAR(100) NULL, Grupo CHAR(1) NULL, Pos INT NULL);
INSERT INTO @Paises VALUES
    ('Argentina',      -3, 13700, 'Español',    'CONMEBOL', 'A', 1),
    ('Brasil',         -3, 10400, 'Portugués',  'CONMEBOL', 'A', 2),
    ('Japón',           9, 32500, 'Japonés',    'AFC',      'A', 3),
    ('Senegal',         0,  1700, 'Francés',    'CAF',      'A', 4),
    ('México',         -6, 13900, 'Español',    'CONCACAF', 'B', 1),
    ('Uruguay',        -3, 22800, 'Español',    'CONMEBOL', 'B', 2),
    ('Inglaterra',      1, 49500, 'Inglés',     'UEFA',     'B', 3),
    ('Marruecos',       1,  3800, 'Árabe',      'CAF',      'B', 4),
    ('Estados Unidos', -5, 81600, 'Inglés',     'CONCACAF', 'C', 1),
    ('España',          2, 34000, 'Español',    'UEFA',     'C', 2),
    ('Colombia',       -5,  7000, 'Español',    'CONMEBOL', 'C', 3),
    ('Países Bajos',    2, 64000, 'Neerlandés', 'UEFA',     'C', 4),
    ('Canadá',         -4, 53500, 'Inglés',     'CONCACAF', 'D', 1),
    ('Francia',         2, 46000, 'Francés',    'UEFA',     'D', 2),
    ('Alemania',        2, 54300, 'Alemán',     'UEFA',     'D', 3),
    ('Portugal',        1, 28000, 'Portugués',  'UEFA',     'D', 4),
    ('Italia',          1, 38300, 'Italiano',   NULL, NULL, NULL),
    ('China',           8, 12600, 'Chino',      NULL, NULL, NULL),
    ('India',           5,  2500, 'Hindi',      NULL, NULL, NULL),
    ('Chile',          -4, 16800, 'Español',    NULL, NULL, NULL),
    ('Corea del Sur',   9, 33100, 'Coreano',    NULL, NULL, NULL),
    ('Arabia Saudita',  3, 31000, 'Árabe',      NULL, NULL, NULL);

INSERT INTO op.Pais (Nombre, HorarioUTC, OffsetUTC, PbiPerCapita)
SELECT p.Nombre, CONCAT('UTC', CASE WHEN p.OffsetUTC >= 0 THEN '+' END, p.OffsetUTC), p.OffsetUTC, p.Pbi
FROM @Paises p
WHERE NOT EXISTS (SELECT 1 FROM op.Pais x WHERE x.Nombre = p.Nombre);

INSERT INTO cfg.Pais_Idioma (IdPais, IdIdioma)
SELECT pa.IdPais, i.IdIdioma
FROM @Paises p
INNER JOIN op.Pais pa ON pa.Nombre = p.Nombre
INNER JOIN cfg.Idioma i ON i.Descripcion = p.Idioma
WHERE NOT EXISTS (SELECT 1 FROM cfg.Pais_Idioma x WHERE x.IdPais = pa.IdPais AND x.IdIdioma = i.IdIdioma);

/*
   SELECCIONES, PLANTELES Y CLUBES
*/
INSERT INTO op.Seleccion (IdPais, IdConfederacion, Grupo)
SELECT pa.IdPais, c.IdConfederacion, p.Grupo
FROM @Paises p
INNER JOIN op.Pais pa ON pa.Nombre = p.Nombre
INNER JOIN cfg.Confederacion c ON c.Nombre = p.Confederacion
WHERE p.Grupo IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM op.Seleccion s WHERE s.IdPais = pa.IdPais);

UPDATE s SET Grupo = p.Grupo
FROM op.Seleccion s
INNER JOIN op.Pais pa ON pa.IdPais = s.IdPais
INNER JOIN @Paises p ON p.Nombre = pa.Nombre
WHERE p.Grupo IS NOT NULL AND ISNULL(s.Grupo, '') <> p.Grupo;

INSERT INTO op.Plantel (IdSeleccion)
SELECT s.IdSeleccion FROM op.Seleccion s
WHERE NOT EXISTS (SELECT 1 FROM op.Plantel pl WHERE pl.IdSeleccion = s.IdSeleccion);

INSERT INTO op.Club (Nombre)
SELECT v.Nombre
FROM (VALUES ('River Plate'), ('Boca Juniors'), ('Palmeiras'), ('Real Madrid'), ('FC Barcelona'), ('Manchester City'),
             ('Liverpool'), ('Bayern Múnich'), ('Paris Saint-Germain'), ('Juventus'), ('Inter de Milán'), ('Ajax'),
             ('Benfica'), ('Porto'), ('América'), ('Monterrey'), ('LA Galaxy'), ('Toronto FC'), ('Al Hilal'),
             ('Kashima Antlers')) v(Nombre)
WHERE NOT EXISTS (SELECT 1 FROM op.Club c WHERE c.Nombre = v.Nombre);

DECLARE @Clubes TABLE (Nro INT PRIMARY KEY, IdClub INT);
INSERT INTO @Clubes (Nro, IdClub) SELECT ROW_NUMBER() OVER (ORDER BY IdClub) - 1, IdClub FROM op.Club;
DECLARE @CantClubes INT = (SELECT COUNT(*) FROM @Clubes);

/*
   JUGADORES (24 por selección) con op.usp_AltaJugador
   Dorsales 1, 12 y 23: arqueros. Se respetan los jugadores ya cargados.
*/
DECLARE @Nombres TABLE (Idx INT PRIMARY KEY, Nombre VARCHAR(100));
INSERT INTO @Nombres VALUES (0,'Mateo'),(1,'Santiago'),(2,'Lucas'),(3,'Tomás'),(4,'Martín'),(5,'Nicolás'),(6,'Diego'),
    (7,'Gabriel'),(8,'Andrés'),(9,'Pablo'),(10,'Hugo'),(11,'Leo'),(12,'Daniel'),(13,'Adrián'),(14,'Bruno'),(15,'Iván'),
    (16,'Julián'),(17,'Kevin'),(18,'Marco'),(19,'Rafael');
DECLARE @Apellidos TABLE (Idx INT PRIMARY KEY, Apellido VARCHAR(100));
INSERT INTO @Apellidos VALUES (0,'García'),(1,'Silva'),(2,'Müller'),(3,'Dubois'),(4,'Smith'),(5,'Rossi'),(6,'Santos'),
    (7,'Kim'),(8,'Tanaka'),(9,'Diallo'),(10,'Benali'),(11,'Hernández'),(12,'Pérez'),(13,'Costa'),(14,'De Jong'),
    (15,'Moreau'),(16,'Schmidt'),(17,'Walker'),(18,'López'),(19,'Torres'),(20,'Ndiaye'),(21,'Suzuki'),(22,'Ferreira'),(23,'Jansen');

DECLARE @Selecciones TABLE (Nro INT PRIMARY KEY, IdSeleccion INT, IdPlantel INT, Pais VARCHAR(100));
INSERT INTO @Selecciones (Nro, IdSeleccion, IdPlantel, Pais)
SELECT ROW_NUMBER() OVER (ORDER BY p.Grupo, p.Pos), s.IdSeleccion,
       (SELECT MIN(pl.IdPlantel) FROM op.Plantel pl WHERE pl.IdSeleccion = s.IdSeleccion), p.Nombre
FROM @Paises p
INNER JOIN op.Pais pa ON pa.Nombre = p.Nombre
INNER JOIN op.Seleccion s ON s.IdPais = pa.IdPais
WHERE p.Grupo IS NOT NULL;

DECLARE @IdPlantel INT, @IdSeleccion INT, @Pais VARCHAR(100), @NomJ VARCHAR(100), @ApeJ VARCHAR(100),
        @Posicion VARCHAR(50), @Doc VARCHAR(30), @FechaNac DATE, @IdClub INT, @IdJ INT;

SET @s = 1;
WHILE @s <= (SELECT COUNT(*) FROM @Selecciones)
BEGIN
    SELECT @IdPlantel = IdPlantel, @Pais = Pais FROM @Selecciones WHERE Nro = @s;
    SET @d = 1;
    WHILE @d <= 26 AND (SELECT COUNT(*) FROM op.Jugador WHERE IdPlantel = @IdPlantel) < 24
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM op.Jugador WHERE IdPlantel = @IdPlantel AND Dorsal = @d)
        BEGIN
            SELECT @NomJ = Nombre FROM @Nombres WHERE Idx = (@d + @s * 3) % 20;
            SELECT @ApeJ = Apellido FROM @Apellidos WHERE Idx = (@d * 7 + @s * 5) % 24;
            SELECT @IdClub = IdClub FROM @Clubes WHERE Nro = (@d + @s * 2) % @CantClubes;
            SET @Posicion = CASE WHEN @d IN (1, 12, 23) THEN 'Arquero'
                                 WHEN @d IN (2, 3, 4, 5, 6, 13, 14, 15, 16) THEN 'Defensor'
                                 WHEN @d IN (7, 8, 10, 17, 18, 19, 20) THEN 'Mediocampista'
                                 ELSE 'Delantero' END;
            SET @Doc = CONCAT('PAS-', @s * 100 + @d);
            SET @FechaNac = DATEADD(DAY, -((@d * 397 + @s * 131) % 4300), CAST('2004-06-01' AS DATE));
            EXEC op.usp_AltaJugador @IdPlantel = @IdPlantel, @IdClub = @IdClub, @Nombre = @NomJ, @Apellido = @ApeJ,
                 @Nacionalidad = @Pais, @Documento = @Doc, @FechaNacimiento = @FechaNac,
                 @PosicionHabitual = @Posicion, @Dorsal = @d;
        END;
        SET @d += 1;
    END;
    SET @s += 1;
END;

-- Convocatoria: todos los jugadores del plantel que todavía no figuran como convocados
INSERT INTO op.Convocado (IdSeleccion, IdJugador)
SELECT pl.IdSeleccion, j.IdJugador
FROM op.Jugador j
INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
WHERE NOT EXISTS (SELECT 1 FROM op.Convocado c WHERE c.IdJugador = j.IdJugador);

-- Cuerpo técnico: DT y un ayudante por selección
INSERT INTO op.CuerpoTecnico (IdSeleccion, IdPlantel, Nombre, Tipo)
SELECT s.IdSeleccion, s.IdPlantel, CONCAT(n.Nombre, ' ', a.Apellido), t.Tipo
FROM @Selecciones s
CROSS JOIN (VALUES ('DT', 0), ('Ayudante', 1)) t(Tipo, Desfase)
INNER JOIN @Nombres n ON n.Idx = (s.Nro * 7 + t.Desfase * 3) % 20
INNER JOIN @Apellidos a ON a.Idx = (s.Nro * 11 + t.Desfase * 5) % 24
WHERE NOT EXISTS (SELECT 1 FROM op.CuerpoTecnico ct WHERE ct.IdSeleccion = s.IdSeleccion AND ct.Tipo = t.Tipo);

/* 
   ALTAS Y BAJAS DE ÚLTIMO MOMENTO (op.usp_ModificarConvocatoria)
   - Brasil: baja del dorsal 20 por lesión y alta de un reemplazo (dorsal 25).
   - Japón: baja del dorsal 18 sin reemplazo (queda con 23).
*/
DECLARE @IdConvocado INT, @IdPlBrasil INT, @IdSelBrasil INT, @IdPlJapon INT;
SELECT @IdPlBrasil = IdPlantel, @IdSelBrasil = IdSeleccion FROM @Selecciones WHERE Pais = 'Brasil';
SELECT @IdPlJapon = IdPlantel FROM @Selecciones WHERE Pais = 'Japón';

SELECT @IdConvocado = c.IdConvocado FROM op.Convocado c INNER JOIN op.Jugador j ON j.IdJugador = c.IdJugador
WHERE j.IdPlantel = @IdPlBrasil AND j.Dorsal = 20;
IF @IdConvocado IS NOT NULL
    EXEC op.usp_ModificarConvocatoria @IdConvocado = @IdConvocado, @Tipo = 'Baja', @Motivo = 'Lesión muscular en el último entrenamiento', @Fecha = '2026-06-08';

SELECT @IdClub = IdClub FROM @Clubes WHERE Nro = 2;
EXEC op.usp_AltaJugador @IdPlantel = @IdPlBrasil, @IdClub = @IdClub, @Nombre = 'Rafael', @Apellido = 'Moraes',
     @Nacionalidad = 'Brasil', @Documento = 'PAS-9925', @FechaNacimiento = '2000-03-14', @PosicionHabitual = 'Mediocampista', @Dorsal = 25;
SET @IdJ = (SELECT MAX(IdJugador) FROM op.Jugador WHERE IdPlantel = @IdPlBrasil AND Dorsal = 25);
INSERT INTO op.Convocado (IdSeleccion, IdJugador) VALUES (@IdSelBrasil, @IdJ);
SET @IdConvocado = SCOPE_IDENTITY();
EXEC op.usp_ModificarConvocatoria @IdConvocado = @IdConvocado, @Tipo = 'Alta', @Motivo = 'Reemplazo del dorsal 20 (lesión)', @Fecha = '2026-06-08';

SET @IdConvocado = NULL;
SELECT @IdConvocado = c.IdConvocado FROM op.Convocado c INNER JOIN op.Jugador j ON j.IdJugador = c.IdJugador
WHERE j.IdPlantel = @IdPlJapon AND j.Dorsal = 18;
IF @IdConvocado IS NOT NULL
    EXEC op.usp_ModificarConvocatoria @IdConvocado = @IdConvocado, @Tipo = 'Baja', @Motivo = 'Desgarro', @Fecha = '2026-06-09';

/*
    SEDES Y ESPACIOS PUBLICITARIOS
*/
DECLARE @Sedes TABLE (Orden INT PRIMARY KEY, Estadio VARCHAR(100), Ciudad VARCHAR(100), Pais VARCHAR(100),
                      OffsetUTC INT, Capacidad INT, IdSede INT NULL);
INSERT INTO @Sedes (Orden, Estadio, Ciudad, Pais, OffsetUTC, Capacidad) VALUES
    (1, 'MetLife Stadium',   'Nueva York / Nueva Jersey', 'Estados Unidos', -4, 82500),
    (2, 'SoFi Stadium',      'Los Ángeles',               'Estados Unidos', -7, 70000),
    (3, 'AT&T Stadium',      'Dallas',                    'Estados Unidos', -5, 94000),
    (4, 'Hard Rock Stadium', 'Miami',                     'Estados Unidos', -4, 65000),
    (5, 'Lumen Field',       'Seattle',                   'Estados Unidos', -7, 69000),
    (6, 'Estadio Azteca',    'Ciudad de México',          'México',         -6, 83000),
    (7, 'Estadio Akron',     'Guadalajara',               'México',         -6, 48000),
    (8, 'BMO Field',         'Toronto',                   'Canadá',         -4, 45000),
    (9, 'BC Place',          'Vancouver',                 'Canadá',         -7, 54000);

INSERT INTO op.Sede (IdPais, NombreEstadio, Ciudad, UsoHorario, Capacidad)
SELECT pa.IdPais, s.Estadio, s.Ciudad, CONCAT('UTC', s.OffsetUTC), s.Capacidad
FROM @Sedes s
INNER JOIN op.Pais pa ON pa.Nombre = s.Pais
WHERE NOT EXISTS (SELECT 1 FROM op.Sede x WHERE x.NombreEstadio = s.Estadio)
ORDER BY s.Orden;

UPDATE s SET IdSede = x.IdSede FROM @Sedes s INNER JOIN op.Sede x ON x.NombreEstadio = s.Estadio;

INSERT INTO op.EspacioPublicitario (IdSede, Motivo)
SELECT s.IdSede, CONCAT('Panel perimetral LED ', e.Nro)
FROM @Sedes s
CROSS JOIN (VALUES (1), (2), (3), (4)) e(Nro)
WHERE NOT EXISTS (SELECT 1 FROM op.EspacioPublicitario ep WHERE ep.IdSede = s.IdSede)
ORDER BY s.Orden, e.Nro;

/*
    ÁRBITROS
*/
INSERT INTO op.Arbitro (Nombre, Apellido, Nacionalidad, Categoria, Documento, FechaNacimiento)
SELECT v.Nombre, v.Apellido, v.Nacionalidad, 'FIFA', CONCAT('ARB-', v.Nro), DATEADD(YEAR, -(36 + v.Nro % 9), CAST('2026-01-01' AS DATE))
FROM (VALUES (1, 'Rodrigo', 'Almada', 'Uruguay'), (2, 'Sérgio', 'Castanheira', 'Brasil'), (3, 'Laurent', 'Bessière', 'Francia'),
             (4, 'Oliver', 'Whitcombe', 'Inglaterra'), (5, 'Héctor', 'Villaseñor', 'México'), (6, 'Jason', 'McKinley', 'Estados Unidos'),
             (7, 'Tomasz', 'Wierzbicki', 'Polonia'), (8, 'Khalid', 'Al-Mansouri', 'Catar'), (9, 'Wei', 'Zhang', 'China'),
             (10, 'Karim', 'Benhaddou', 'Argelia'), (11, 'Gustavo', 'Ledezma', 'Venezuela'), (12, 'Liam', 'Hargreaves', 'Australia'))
     v(Nro, Nombre, Apellido, Nacionalidad)
WHERE NOT EXISTS (SELECT 1 FROM op.Arbitro a WHERE a.Nombre = v.Nombre AND a.Apellido = v.Apellido);

INSERT INTO cfg.Arbitro_Idioma (IdArbitro, IdIdioma)
SELECT a.IdArbitro, i.IdIdioma
FROM op.Arbitro a
INNER JOIN cfg.Idioma i ON i.Descripcion IN ('Inglés',
       CASE WHEN a.Nacionalidad IN ('Argentina', 'Uruguay', 'México', 'Venezuela') THEN 'Español'
            WHEN a.Nacionalidad = 'Brasil' THEN 'Portugués'
            WHEN a.Nacionalidad IN ('Francia', 'Argelia') THEN 'Francés'
            WHEN a.Nacionalidad = 'Italia' THEN 'Italiano'
            WHEN a.Nacionalidad = 'China' THEN 'Chino'
            WHEN a.Nacionalidad = 'Catar' THEN 'Árabe' ELSE 'Inglés' END)
WHERE NOT EXISTS (SELECT 1 FROM cfg.Arbitro_Idioma x WHERE x.IdArbitro = a.IdArbitro AND x.IdIdioma = i.IdIdioma);

/*
   PUBLICIDAD: anunciantes de 7 países, campañas, piezas y mercados
   Tarifas por franja en ARS (moneda base de cfg.Cotizacion_Moneda).
*/
DECLARE @Anunciantes TABLE (Nro INT PRIMARY KEY, RazonSocial VARCHAR(100), Pais VARCHAR(100), Campania VARCHAR(100), IdCampania INT NULL);
INSERT INTO @Anunciantes (Nro, RazonSocial, Pais, Campania) VALUES
    (1, 'Bebidas Andinas S.A.',        'Argentina',      'Mundial 2026 - Brindá con tu selección'),
    (2, 'Banco Austral S.A.',          'Brasil',         'Mundial 2026 - Tu cuenta, tu hinchada'),
    (3, 'Motores del Pacífico Corp.',  'Japón',          'Mundial 2026 - Rumbo a la final'),
    (4, 'Telecom Norte Inc.',          'Estados Unidos', 'Mundial 2026 - Every goal, live'),
    (5, 'Deportes Europa GmbH',        'Alemania',       'Mundial 2026 - Jugá como un campeón'),
    (6, 'Aerolíneas Sol S.A.',         'España',         'Mundial 2026 - Volá a ver a tu equipo'),
    (7, 'Electro Asia Ltd.',           'China',          'Mundial 2026 - Mirá cada jugada en 8K'),
    (8, 'Snacks Aztecas S.A. de C.V.', 'México',         'Mundial 2026 - El snack del partido');

INSERT INTO cfg.Anunciante (IdPais, RazonSocial)
SELECT pa.IdPais, a.RazonSocial
FROM @Anunciantes a INNER JOIN op.Pais pa ON pa.Nombre = a.Pais
ORDER BY a.Nro;

INSERT INTO cfg.Campania (IdAnunciante, Nombre, Descripcion)
SELECT an.IdAnunciante, a.Campania, CONCAT('Campaña del anunciante ', a.RazonSocial, ' para la Copa del Mundo 2026')
FROM @Anunciantes a INNER JOIN cfg.Anunciante an ON an.RazonSocial = a.RazonSocial
ORDER BY a.Nro;

UPDATE a SET IdCampania = c.IdCampania
FROM @Anunciantes a
INNER JOIN cfg.Anunciante an ON an.RazonSocial = a.RazonSocial
INNER JOIN cfg.Campania c ON c.IdAnunciante = an.IdAnunciante AND c.Nombre = a.Campania;

DECLARE @Piezas TABLE (Nro INT PRIMARY KEY, NroAnunciante INT, Idioma VARCHAR(50), Duracion INT, Tarifa DECIMAL(10,2), IdPieza INT NULL);
INSERT INTO @Piezas (Nro, NroAnunciante, Idioma, Duracion, Tarifa) VALUES
    (1, 1, 'Español', 30, 4500000), (2, 1, 'Español', 20, 3200000),
    (3, 2, 'Portugués', 30, 5200000), (4, 2, 'Español', 15, 2100000),
    (5, 3, 'Japonés', 30, 6800000), (6, 3, 'Inglés', 20, 4000000),
    (7, 4, 'Inglés', 30, 7500000), (8, 4, 'Español', 20, 3900000),
    (9, 5, 'Alemán', 30, 6200000), (10, 5, 'Francés', 20, 4800000),
    (11, 6, 'Español', 30, 5500000), (12, 6, 'Inglés', 15, 2800000),
    (13, 7, 'Chino', 30, 6000000), (14, 7, 'Árabe', 20, 3500000),
    (15, 8, 'Español', 20, 2600000), (16, 8, 'Español', 15, 1900000);

DECLARE @PiezaMercados TABLE (NroPieza INT, Pais VARCHAR(100));
INSERT INTO @PiezaMercados (NroPieza, Pais) VALUES
    (1, 'Argentina'), (1, 'Chile'), (1, 'Uruguay'), (2, 'Argentina'),
    (3, 'Brasil'), (3, 'Portugal'), (4, 'Colombia'), (4, 'México'),
    (5, 'Japón'), (5, 'Corea del Sur'), (6, 'Estados Unidos'), (6, 'Canadá'),
    (7, 'Estados Unidos'), (7, 'Inglaterra'), (8, 'México'), (8, 'Estados Unidos'),
    (9, 'Alemania'), (9, 'Países Bajos'), (10, 'Francia'), (10, 'Senegal'), (10, 'Marruecos'),
    (11, 'España'), (11, 'Argentina'), (11, 'México'), (12, 'Inglaterra'), (12, 'Italia'),
    (13, 'China'), (13, 'India'), (14, 'Arabia Saudita'), (14, 'Marruecos'),
    (15, 'México'), (15, 'Estados Unidos'), (15, 'Canadá'), (16, 'Uruguay'), (16, 'Chile'), (16, 'Colombia');

DECLARE @IdCampania INT, @IdIdioma INT, @Duracion INT, @Tarifa DECIMAL(10,2);
SET @i = 1;
WHILE @i <= (SELECT COUNT(*) FROM @Piezas)
BEGIN
    SELECT @IdCampania = a.IdCampania, @IdIdioma = i.IdIdioma, @Duracion = p.Duracion, @Tarifa = p.Tarifa
    FROM @Piezas p
    INNER JOIN @Anunciantes a ON a.Nro = p.NroAnunciante
    INNER JOIN cfg.Idioma i ON i.Descripcion = p.Idioma
    WHERE p.Nro = @i;

    INSERT INTO cfg.Pieza_Contenido (IdCampania, IdIdioma, Duracion, Tarifa) VALUES (@IdCampania, @IdIdioma, @Duracion, @Tarifa);
    UPDATE @Piezas SET IdPieza = SCOPE_IDENTITY() WHERE Nro = @i;
    SET @i += 1;
END;

INSERT INTO cfg.Pieza_Pais (IdPieza, IdPais)
SELECT p.IdPieza, pa.IdPais
FROM @PiezaMercados m
INNER JOIN @Piezas p ON p.Nro = m.NroPieza
INNER JOIN op.Pais pa ON pa.Nombre = m.Pais;

/*
   FIXTURE DE LA FASE DE GRUPOS
   Dos partidos por día: 19:00 y 23:00 UTC. Las sedes rotan.
   Si un cruce de grupo ya existía no se duplica.
*/
INSERT INTO op.Partido (IdSede, IdSeleccionLocal, IdSeleccionVisitante, Fecha, HoraLocal, HoraUTC, Fase)
SELECT ss.IdSede, f.IdLocal, f.IdVisitante, f.Fecha, DATEADD(HOUR, ss.OffsetUTC, f.HoraUTC), f.HoraUTC, 'Grupos'
FROM (
    SELECT sl.IdSeleccion AS IdLocal,
           sv.IdSeleccion AS IdVisitante,
           DATEADD(DAY, (t.Fecha - 1) * 5 + ASCII(gl.Grupo) - ASCII('A'), CAST('2026-06-11' AS DATE)) AS Fecha,
           CAST(CASE t.Turno WHEN 1 THEN '19:00' ELSE '23:00' END AS TIME) AS HoraUTC,
           ROW_NUMBER() OVER (ORDER BY t.Fecha, gl.Grupo, t.Turno) AS Nro
    FROM (VALUES (1, 1, 2, 1), (1, 3, 4, 2), (2, 1, 3, 1), (2, 4, 2, 2), (3, 4, 1, 1), (3, 2, 3, 2)) t(Fecha, PosLocal, PosVisitante, Turno)
    INNER JOIN @Paises gl ON gl.Pos = t.PosLocal AND gl.Grupo IS NOT NULL
    INNER JOIN @Paises gv ON gv.Grupo = gl.Grupo AND gv.Pos = t.PosVisitante
    INNER JOIN op.Pais pl ON pl.Nombre = gl.Nombre
    INNER JOIN op.Seleccion sl ON sl.IdPais = pl.IdPais
    INNER JOIN op.Pais pv ON pv.Nombre = gv.Nombre
    INNER JOIN op.Seleccion sv ON sv.IdPais = pv.IdPais
    WHERE NOT EXISTS (SELECT 1 FROM op.Partido x
                      WHERE x.Fase = 'Grupos'
                        AND ((x.IdSeleccionLocal = sl.IdSeleccion AND x.IdSeleccionVisitante = sv.IdSeleccion)
                          OR (x.IdSeleccionLocal = sv.IdSeleccion AND x.IdSeleccionVisitante = sl.IdSeleccion)))
) f
INNER JOIN @Sedes ss ON ss.Orden = (f.Nro - 1) % 9 + 1
ORDER BY f.Fecha, f.HoraUTC;

/*
   SIMULACIÓN DE LOS PARTIDOS
   Se procesan en orden cronológico los partidos sin alineación ni cierre.
   Cuando no quedan partidos pendientes se arma la fase siguiente a partir de
   los resultados (cuartos -> semifinales -> tercer puesto y final).
   Los valores (goles, tarjetas, árbitros) se derivan del Id del partido, de
   modo que la carga es reproducible.
*/
DECLARE @IdP INT, @IdSede INT, @IdLoc INT, @IdVis INT, @Fase VARCHAR(50), @Fecha DATE, @HoraUTC TIME, @Capacidad INT;
DECLARE @Seq INT = 0, @Lado INT, @IdSelX INT, @IdPl INT, @IdAlineacion INT, @AlLoc INT, @AlVis INT;
DECLARE @Tit BIT, @Dorsal INT, @Goles INT, @GL INT, @GV INT, @Alargue BIT, @Minuto INT, @Periodo INT, @Tipo INT;
DECLARE @Autor INT, @Asist INT, @Rn INT, @Sale INT, @Entra INT, @Motivo VARCHAR(255), @Publico INT;
DECLARE @A1 INT, @A2 INT, @A3 INT, @A4 INT, @A5 INT, @IdConflicto INT, @ConflictoProbado BIT = 0;
DECLARE @IdMexico8 INT = (SELECT j.IdJugador FROM op.Jugador j INNER JOIN @Selecciones s ON s.IdPlantel = j.IdPlantel
                          WHERE s.Pais = 'México' AND j.Dorsal = 8);
DECLARE @Lista TABLE (Orden INT PRIMARY KEY, IdJugador INT, EsTitular BIT, Posicion VARCHAR(50), Dorsal INT);
DECLARE @Campo TABLE (Lado INT, Rn INT, IdJugador INT, PRIMARY KEY (Lado, Rn));   -- titulares de campo por dorsal
DECLARE @Ataque TABLE (Lado INT, Rn INT, IdJugador INT, PRIMARY KEY (Lado, Rn));  -- titulares de campo, delanteros primero
DECLARE @Banco TABLE (Lado INT, Rn INT, IdJugador INT, PRIMARY KEY (Lado, Rn));   -- suplentes de campo por dorsal
DECLARE @Arbitros TABLE (Rn INT PRIMARY KEY, IdArbitro INT);
DECLARE @Clasificados TABLE (Nro INT PRIMARY KEY, IdSeleccion INT);

WHILE 1 = 1
BEGIN
    SET @IdP = NULL;
    SELECT TOP (1) @IdP = p.IdPartido, @IdSede = p.IdSede, @IdLoc = p.IdSeleccionLocal, @IdVis = p.IdSeleccionVisitante,
                   @Fase = p.Fase, @Fecha = p.Fecha, @HoraUTC = p.HoraUTC, @Capacidad = s.Capacidad
    FROM op.Partido p
    INNER JOIN op.Sede s ON s.IdSede = p.IdSede
    WHERE p.PublicoAsistente IS NULL
      AND NOT EXISTS (SELECT 1 FROM op.Alineacion a WHERE a.IdPartido = p.IdPartido)
    ORDER BY p.Fecha, p.HoraUTC, p.IdPartido;

    -- Sin partidos pendientes: se arma la fase siguiente o se termina
    IF @IdP IS NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE Fase = 'Cuartos' AND IdPartido > @IdBase)
        BEGIN
            INSERT INTO op.Partido (IdSede, IdSeleccionLocal, IdSeleccionVisitante, Fecha, HoraLocal, HoraUTC, Fase)
            SELECT ss.IdSede, tl.IdSeleccion, tv.IdSeleccion, v.Fecha, DATEADD(HOUR, ss.OffsetUTC, v.HoraUTC), v.HoraUTC, 'Cuartos'
            FROM (VALUES (1, 'A', 1, 'B', 2, CAST('2026-07-03' AS DATE), CAST('19:00' AS TIME), 3),
                         (2, 'B', 1, 'A', 2, CAST('2026-07-03' AS DATE), CAST('23:00' AS TIME), 2),
                         (3, 'C', 1, 'D', 2, CAST('2026-07-04' AS DATE), CAST('19:00' AS TIME), 6),
                         (4, 'D', 1, 'C', 2, CAST('2026-07-04' AS DATE), CAST('23:00' AS TIME), 4))
                 v(Nro, GrupoL, PosL, GrupoV, PosV, Fecha, HoraUTC, Sede)
            INNER JOIN op.vw_TablaPosiciones tl ON tl.Grupo = v.GrupoL AND tl.Posicion = v.PosL
            INNER JOIN op.vw_TablaPosiciones tv ON tv.Grupo = v.GrupoV AND tv.Posicion = v.PosV
            INNER JOIN @Sedes ss ON ss.Orden = v.Sede
            ORDER BY v.Nro;
            PRINT 'Fase de grupos terminada: se programaron los cuartos de final.';
            CONTINUE;
        END;

        IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE Fase = 'Semifinal' AND IdPartido > @IdBase)
        BEGIN
            DELETE FROM @Clasificados;
            INSERT INTO @Clasificados (Nro, IdSeleccion)
            SELECT ROW_NUMBER() OVER (ORDER BY IdPartido), IdSeleccionGanadora
            FROM op.vw_ResultadoPartido WHERE Fase = 'Cuartos' AND IdPartido > @IdBase;

            INSERT INTO op.Partido (IdSede, IdSeleccionLocal, IdSeleccionVisitante, Fecha, HoraLocal, HoraUTC, Fase)
            SELECT ss.IdSede, cl.IdSeleccion, cv.IdSeleccion, v.Fecha, DATEADD(HOUR, ss.OffsetUTC, v.HoraUTC), v.HoraUTC, 'Semifinal'
            FROM (VALUES (1, 1, 3, CAST('2026-07-08' AS DATE), CAST('23:00' AS TIME), 1),
                         (2, 2, 4, CAST('2026-07-09' AS DATE), CAST('23:00' AS TIME), 3)) v(Nro, L, V, Fecha, HoraUTC, Sede)
            INNER JOIN @Clasificados cl ON cl.Nro = v.L
            INNER JOIN @Clasificados cv ON cv.Nro = v.V
            INNER JOIN @Sedes ss ON ss.Orden = v.Sede
            ORDER BY v.Nro;
            PRINT 'Cuartos de final terminados: se programaron las semifinales.';
            CONTINUE;
        END;

        IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE Fase = 'Final' AND IdPartido > @IdBase)
        BEGIN
            DELETE FROM @Clasificados;
            -- 1 y 2: ganadores de las semifinales; 3 y 4: perdedores
            INSERT INTO @Clasificados (Nro, IdSeleccion)
            SELECT ROW_NUMBER() OVER (ORDER BY IdPartido), IdSeleccionGanadora
            FROM op.vw_ResultadoPartido WHERE Fase = 'Semifinal' AND IdPartido > @IdBase;
            INSERT INTO @Clasificados (Nro, IdSeleccion)
            SELECT 2 + ROW_NUMBER() OVER (ORDER BY IdPartido),
                   CASE WHEN IdSeleccionGanadora = IdSeleccionLocal THEN IdSeleccionVisitante ELSE IdSeleccionLocal END
            FROM op.vw_ResultadoPartido WHERE Fase = 'Semifinal' AND IdPartido > @IdBase;

            INSERT INTO op.Partido (IdSede, IdSeleccionLocal, IdSeleccionVisitante, Fecha, HoraLocal, HoraUTC, Fase)
            SELECT ss.IdSede, cl.IdSeleccion, cv.IdSeleccion, v.Fecha, DATEADD(HOUR, ss.OffsetUTC, v.HoraUTC), v.HoraUTC, v.Fase
            FROM (VALUES (1, 3, 4, CAST('2026-07-11' AS DATE), CAST('19:00' AS TIME), 4, 'Tercer Puesto'),
                         (2, 1, 2, CAST('2026-07-12' AS DATE), CAST('19:00' AS TIME), 1, 'Final')) v(Nro, L, V, Fecha, HoraUTC, Sede, Fase)
            INNER JOIN @Clasificados cl ON cl.Nro = v.L
            INNER JOIN @Clasificados cv ON cv.Nro = v.V
            INNER JOIN @Sedes ss ON ss.Orden = v.Sede
            ORDER BY v.Nro;
            PRINT 'Semifinales terminadas: se programaron el tercer puesto y la final.';
            CONTINUE;
        END;

        BREAK;
    END;

    SET @Seq += 1;

    BEGIN TRY
        DELETE FROM @Campo; DELETE FROM @Ataque; DELETE FROM @Banco;

        /* ---------- Alineaciones (titulares y suplentes, sin suspendidos) ---------- */
        SET @Lado = 1;
        WHILE @Lado <= 2
        BEGIN
            SET @IdSelX = CASE @Lado WHEN 1 THEN @IdLoc ELSE @IdVis END;
            SET @IdPl = (SELECT MIN(IdPlantel) FROM op.Plantel WHERE IdSeleccion = @IdSelX);

            INSERT INTO op.Alineacion (IdPartido, IdPlantel, EsquemaTactico)
            VALUES (@IdP, @IdPl, CHOOSE((@IdP + @Lado) % 4 + 1, '4-3-3', '4-4-2', '3-5-2', '4-2-3-1'));
            SET @IdAlineacion = SCOPE_IDENTITY();
            IF @Lado = 1 SET @AlLoc = @IdAlineacion ELSE SET @AlVis = @IdAlineacion;

            DELETE FROM @Lista;
            ;WITH Disponibles AS (
                SELECT j.IdJugador, j.Dorsal,
                       ISNULL(j.PosicionHabitual, 'Delantero') AS PosicionHabitual,
                       CASE WHEN j.PosicionHabitual = 'Arquero' THEN 1 ELSE 0 END AS EsArquero
                FROM op.Jugador j
                INNER JOIN op.vw_ConvocadoActivo c ON c.IdJugador = j.IdJugador AND c.IdSeleccion = @IdSelX
                WHERE j.IdPlantel = @IdPl
                  AND NOT EXISTS (SELECT 1 FROM op.Suspension su
                                  WHERE su.IdJugador = j.IdJugador AND su.Activa = 1 AND su.PartidosRestantes > 0)
            ),
            Ordenados AS (
                SELECT *, ROW_NUMBER() OVER (PARTITION BY EsArquero
                                             ORDER BY CASE WHEN EsArquero = 0 AND Dorsal BETWEEN 2 AND 11 THEN 0 ELSE 1 END, Dorsal) AS Rn
                FROM Disponibles
            )
            INSERT INTO @Lista (Orden, IdJugador, EsTitular, Posicion, Dorsal)
            SELECT ROW_NUMBER() OVER (ORDER BY CASE WHEN (EsArquero = 1 AND Rn = 1) OR (EsArquero = 0 AND Rn <= 10) THEN 0 ELSE 1 END,
                                               EsArquero DESC, Rn),
                   IdJugador,
                   CASE WHEN (EsArquero = 1 AND Rn = 1) OR (EsArquero = 0 AND Rn <= 10) THEN 1 ELSE 0 END,
                   PosicionHabitual,
                   Dorsal
            FROM Ordenados;
            DELETE FROM @Lista WHERE Orden > 23;   -- 11 titulares + 12 suplentes

            SET @k = 1;
            SET @n = (SELECT COUNT(*) FROM @Lista);
            WHILE @k <= @n
            BEGIN
                SELECT @IdJ = IdJugador, @Tit = EsTitular, @Posicion = Posicion, @Dorsal = Dorsal FROM @Lista WHERE Orden = @k;
                EXEC op.usp_RegistrarAlineacionJugador @IdAlineacion = @IdAlineacion, @IdJugador = @IdJ, @Posicion = @Posicion,
                     @EsTitular = @Tit, @Dorsal = @Dorsal;
                SET @k += 1;
            END;

            INSERT INTO @Campo (Lado, Rn, IdJugador)
            SELECT @Lado, ROW_NUMBER() OVER (ORDER BY Dorsal), IdJugador FROM @Lista WHERE EsTitular = 1 AND Posicion <> 'Arquero';
            INSERT INTO @Ataque (Lado, Rn, IdJugador)
            SELECT @Lado, ROW_NUMBER() OVER (ORDER BY CASE Posicion WHEN 'Delantero' THEN 0 WHEN 'Mediocampista' THEN 1 ELSE 2 END, Dorsal), IdJugador
            FROM @Lista WHERE EsTitular = 1 AND Posicion <> 'Arquero';
            INSERT INTO @Banco (Lado, Rn, IdJugador)
            SELECT @Lado, ROW_NUMBER() OVER (ORDER BY Dorsal), IdJugador FROM @Lista WHERE EsTitular = 0 AND Posicion <> 'Arquero';

            SET @Lado += 1;
        END;

        /* ---------- Designación arbitral (5 roles, sin conflicto de nacionalidad) ---------- */
        IF NOT EXISTS (SELECT 1 FROM op.Lista_Arbitros WHERE IdPartido = @IdP)
        BEGIN
            DELETE FROM @Arbitros;
            INSERT INTO @Arbitros (Rn, IdArbitro)
            SELECT TOP (5) ROW_NUMBER() OVER (ORDER BY (a.IdArbitro * 7 + @Seq * 5) % 31, a.IdArbitro), a.IdArbitro
            FROM op.Arbitro a
            WHERE a.Nacionalidad NOT IN (SELECT pa.Nombre FROM op.Seleccion s INNER JOIN op.Pais pa ON pa.IdPais = s.IdPais
                                         WHERE s.IdSeleccion IN (@IdLoc, @IdVis))
            ORDER BY (a.IdArbitro * 7 + @Seq * 5) % 31, a.IdArbitro;

            SELECT @A1 = IdArbitro FROM @Arbitros WHERE Rn = 1;
            SELECT @A2 = IdArbitro FROM @Arbitros WHERE Rn = 2;
            SELECT @A3 = IdArbitro FROM @Arbitros WHERE Rn = 3;
            SELECT @A4 = IdArbitro FROM @Arbitros WHERE Rn = 4;
            SELECT @A5 = IdArbitro FROM @Arbitros WHERE Rn = 5;

            -- Caso obligatorio: una designación descartada por conflicto de nacionalidad
            IF @ConflictoProbado = 0
            BEGIN
                SET @IdConflicto = (SELECT TOP (1) a.IdArbitro FROM op.Arbitro a
                                    INNER JOIN op.Pais pa ON pa.Nombre = a.Nacionalidad
                                    INNER JOIN op.Seleccion s ON s.IdPais = pa.IdPais
                                    WHERE s.IdSeleccion IN (@IdLoc, @IdVis) ORDER BY a.IdArbitro);
                IF @IdConflicto IS NOT NULL
                BEGIN
                    BEGIN TRY
                        EXEC op.usp_DesignarArbitros @IdPartido = @IdP, @IdArbitroPrincipal = @IdConflicto,
                             @IdArbitroAsistente1 = @A2, @IdArbitroAsistente2 = @A3, @IdCuartoArbitro = @A4, @IdArbitroVAR = @A5;
                    END TRY
                    BEGIN CATCH
                        PRINT CONCAT('Partido ', @IdP, ' - designación descartada (caso esperado): ', ERROR_MESSAGE());
                        SET @ConflictoProbado = 1;
                    END CATCH;
                END;
            END;

            EXEC op.usp_DesignarArbitros @IdPartido = @IdP, @IdArbitroPrincipal = @A1, @IdArbitroAsistente1 = @A2,
                 @IdArbitroAsistente2 = @A3, @IdCuartoArbitro = @A4, @IdArbitroVAR = @A5;
        END;

        /* ---------- Goles ---------- */
        SET @GL = (@IdP * 7 + 2) % 4;
        SET @GV = (@IdP * 3 + 1) % 3;
        SET @Alargue = 0;
        IF @Fase <> 'Grupos' AND @GL = @GV
        BEGIN
            SET @GL += 1;          -- en eliminación directa se define en el alargue
            SET @Alargue = 1;
        END;

        SET @Lado = 1;
        WHILE @Lado <= 2
        BEGIN
            SET @Goles = CASE @Lado WHEN 1 THEN @GL ELSE @GV END;
            SET @k = 1;
            WHILE @k <= @Goles
            BEGIN
                SET @Minuto = CASE WHEN @Alargue = 1 AND @Lado = 1 AND @k = @Goles THEN 105
                                   ELSE 5 + ((@IdP * 11 + @k * 23 + @Lado * 7) % 85) END;
                SET @Periodo = CASE WHEN @Minuto <= 45 THEN @IdPT WHEN @Minuto <= 90 THEN @IdST ELSE @IdAl END;

                IF @Lado = 2 AND @k = 1 AND @IdP % 9 = 4
                BEGIN
                    -- Gol en contra: lo convierte un defensor local y se acredita al visitante
                    SELECT @Autor = IdJugador FROM @Campo WHERE Lado = 1 AND Rn = 1;
                    SET @Asist = NULL;
                    SET @Tipo = @IdEnContra;
                END
                ELSE
                BEGIN
                    SET @Rn = (@IdP + @k * 3) % 5 + 1;
                    SELECT @Autor = IdJugador FROM @Ataque WHERE Lado = @Lado AND Rn = @Rn;
                    SET @Asist = NULL;
                    IF @k % 2 = 1
                        SELECT @Asist = IdJugador FROM @Ataque WHERE Lado = @Lado AND Rn = (@IdP + @k * 3 + 2) % 5 + 1;
                    SET @Tipo = CASE WHEN (@IdP + @k) % 7 = 0 THEN @IdPenal
                                     WHEN (@IdP + @k) % 5 = 0 THEN @IdCabezazo
                                     ELSE @IdJugada END;
                    IF @Tipo = @IdPenal SET @Asist = NULL;
                END;

                EXEC op.usp_RegistrarGol_Y_ActualizarResultado @IdPartido = @IdP, @IdJugadorAnotador = @Autor,
                     @IdJugadorAsistidor = @Asist, @IdTipoJugada = @Tipo, @IdPeriodo = @Periodo, @Minuto = @Minuto;
                SET @k += 1;
            END;
            SET @Lado += 1;
        END;

        /* ---------- Tarjetas ---------- */
        SET @Lado = 1;
        WHILE @Lado <= 2
        BEGIN
            SET @n = (@IdP + @Lado) % 3;   -- 0 a 2 amarillas por equipo
            SET @k = 1;
            WHILE @k <= @n
            BEGIN
                SELECT @IdJ = IdJugador FROM @Campo WHERE Lado = @Lado AND Rn = (@IdP * 5 + @Lado * 3 + @k * 4) % 10 + 1;
                SET @Minuto = 15 + (@IdP * 13 + @k * 29 + @Lado * 7) % 75;
                SET @Motivo = CHOOSE((@IdP + @k) % 4 + 1, 'Falta táctica', 'Protesta', 'Demora en el reinicio', 'Juego brusco');
                EXEC op.usp_RegistrarTarjeta_Y_CalcularSuspension @IdPartido = @IdP, @IdJugador = @IdJ,
                     @IdTipoTarjeta = @IdAmarilla, @Minuto = @Minuto, @Motivo = @Motivo;
                SET @k += 1;
            END;
            SET @Lado += 1;
        END;

        -- Caso obligatorio: acumulación de amarillas (México, dorsal 8, en cada partido de grupos que juega)
        IF @Fase = 'Grupos' AND EXISTS (SELECT 1 FROM op.Alineacion_Jugador
                                        WHERE IdAlineacion IN (@AlLoc, @AlVis) AND IdJugador = @IdMexico8 AND EsTitular = 1)
            EXEC op.usp_RegistrarTarjeta_Y_CalcularSuspension @IdPartido = @IdP, @IdJugador = @IdMexico8,
                 @IdTipoTarjeta = @IdAmarilla, @Minuto = 33, @Motivo = 'Falta táctica';

        -- Casos obligatorios: expulsión por doble amarilla y por roja directa
        IF @Seq = 3 OR @IdP % 11 = 5
        BEGIN
            SELECT @IdJ = IdJugador FROM @Campo WHERE Lado = 2 AND Rn = 6;
            EXEC op.usp_RegistrarTarjeta_Y_CalcularSuspension @IdPartido = @IdP, @IdJugador = @IdJ,
                 @IdTipoTarjeta = @IdDobleAmarilla, @Minuto = 74, @Motivo = 'Segunda amonestación';
        END;
        IF @Seq = 5 OR @IdP % 13 = 7
        BEGIN
            SELECT @IdJ = IdJugador FROM @Campo WHERE Lado = 1 AND Rn = 3;
            EXEC op.usp_RegistrarTarjeta_Y_CalcularSuspension @IdPartido = @IdP, @IdJugador = @IdJ,
                 @IdTipoTarjeta = @IdRojaDirecta, @Minuto = 61, @Motivo = 'Juego brusco grave';
        END;

        /* ---------- Cambios (3 por equipo; en el primer partido, uno por lesión al minuto 15) ---------- */
        SET @Lado = 1;
        WHILE @Lado <= 2
        BEGIN
            SET @k = 1;
            WHILE @k <= 3
            BEGIN
                SELECT @Sale = IdJugador FROM @Campo WHERE Lado = @Lado AND Rn = 11 - @k;
                SELECT @Entra = IdJugador FROM @Banco WHERE Lado = @Lado AND Rn = @k;
                IF @Seq = 1 AND @Lado = 1 AND @k = 1
                BEGIN
                    SET @Minuto = 15;
                    SET @Motivo = 'Lesión';
                END
                ELSE
                BEGIN
                    SET @Minuto = 55 + @k * 9;
                    SET @Motivo = 'Táctico';
                END;
                EXEC op.usp_RegistrarCambioJugador @IdPartido = @IdP, @IdJugadorSaliente = @Sale, @IdJugadorIngresante = @Entra,
                     @Minuto = @Minuto, @Motivo = @Motivo;
                SET @k += 1;
            END;
            SET @Lado += 1;
        END;

        /* ---------- Publicidad (criterio de op.usp_AsignarPublicidadPartido) ---------- */
        IF NOT EXISTS (SELECT 1 FROM op.Exhibicion WHERE IdPartido = @IdP)
            EXEC op.usp_AsignarPublicidadPartido @IdPartido = @IdP, @IdSede = @IdSede;

        /* ---------- Informes post-partido de los árbitros ---------- */
        IF @Seq % 4 = 0
            INSERT INTO op.Informe_Arbitro (IdPartido, IdArbitro, Tipo, Descripcion, Fecha)
            SELECT @IdP, IdArbitroPrincipal, 'Informe', 'Partido sin incidentes de gravedad. Se adjunta el detalle de las amonestaciones.', DATEADD(DAY, 1, @Fecha)
            FROM op.Lista_Arbitros WHERE IdPartido = @IdP;
        IF @Seq % 10 = 7
            INSERT INTO op.Informe_Arbitro (IdPartido, IdArbitro, Tipo, Descripcion, Fecha)
            SELECT @IdP, IdArbitroVAR, 'Sancion', 'Error de protocolo en una revisión del VAR: no será designado en la próxima fecha.', DATEADD(DAY, 2, @Fecha)
            FROM op.Lista_Arbitros WHERE IdPartido = @IdP;

        /* ---------- Cierre del partido ---------- */
        SET @Publico = CAST(@Capacidad * (0.72 + ((@IdP * 7) % 25) / 100.0) AS INT);
        EXEC op.usp_FinalizarPartido @IdPartido = @IdP, @PublicoAsistente = @Publico, @TuvoAlargue = @Alargue;
    END TRY
    BEGIN CATCH
        PRINT CONCAT('ERROR al simular el partido ', @IdP, ': ', ERROR_MESSAGE());
    END CATCH;
END;

/*
    RESUMEN DE LA CARGA
*/
SELECT 'Sedes' AS Dato, COUNT(*) AS Cantidad FROM op.Sede
UNION ALL SELECT 'Husos horarios distintos de sedes', COUNT(DISTINCT UsoHorario) FROM op.Sede
UNION ALL SELECT 'Selecciones', COUNT(*) FROM op.Seleccion
UNION ALL SELECT 'Selecciones con 23 o más convocados vigentes',
                 COUNT(*) FROM (SELECT IdSeleccion FROM op.vw_ConvocadoActivo GROUP BY IdSeleccion HAVING COUNT(*) >= 23) x
UNION ALL SELECT 'Partidos', COUNT(*) FROM op.Partido
UNION ALL SELECT 'Partidos con alineación de ambos equipos',
                 COUNT(*) FROM (SELECT IdPartido FROM op.Alineacion GROUP BY IdPartido HAVING COUNT(*) = 2) x
UNION ALL SELECT 'Árbitros', COUNT(*) FROM op.Arbitro
UNION ALL SELECT 'Partidos con terna completa', COUNT(*) FROM op.Lista_Arbitros
UNION ALL SELECT 'Países de anunciantes', COUNT(DISTINCT IdPais) FROM cfg.Anunciante
UNION ALL SELECT 'Expulsiones por doble amarilla', COUNT(*) FROM op.Tarjeta WHERE IdTipoTarjeta = @IdDobleAmarilla
UNION ALL SELECT 'Expulsiones por roja directa', COUNT(*) FROM op.Tarjeta WHERE IdTipoTarjeta = @IdRojaDirecta
UNION ALL SELECT 'Suspensiones por acumulación', COUNT(*) FROM op.Suspension WHERE Motivo = 'Acumulación de amarillas'
UNION ALL SELECT 'Cambios por lesión antes del minuto 20', COUNT(*) FROM op.Cambios WHERE Motivo = 'Lesión' AND Minuto <= 20
UNION ALL SELECT 'Partidos en prime time en más de 4 mercados',
                 COUNT(*) FROM (SELECT p.IdPartido FROM op.Partido p CROSS JOIN op.Pais m
                                WHERE op.fn_EsPrimeTime(p.HoraUTC, m.OffsetUTC) = 1
                                  AND EXISTS (SELECT 1 FROM cfg.Pieza_Pais pp WHERE pp.IdPais = m.IdPais)
                                GROUP BY p.IdPartido HAVING COUNT(*) > 4) x
UNION ALL SELECT 'Exhibiciones publicitarias', COUNT(*) FROM op.Exhibicion;
GO
