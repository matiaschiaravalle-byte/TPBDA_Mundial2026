/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli, Agustín Nicolás Mussi Pulcini
   Resumen: Script de testing para 10_SP_FinalizarPartido_E7.sql.
             Usa dos selecciones de prueba propias (sin grupo, para no alterar
             la tabla de posiciones) y al final borra todos los datos que creó.
========================================================================= */

USE Mundial2026;
GO

SET NOCOUNT ON;

--Preparación

DECLARE @IdConf INT = (SELECT MIN(IdConfederacion) FROM cfg.Confederacion);
DECLARE @IdClub INT = (SELECT MIN(IdClub) FROM op.Club);
DECLARE @IdSede INT = (SELECT IdSede FROM op.Sede WHERE NombreEstadio = 'BC Place');
DECLARE @IdPaisA INT, @IdPaisB INT, @IdSelA INT, @IdSelB INT, @IdPlA INT, @IdPlB INT;
DECLARE @IdPartido1 INT, @IdPartido2 INT, @IdAl INT, @IdJ INT, @IdSusp INT, @IdSuplenteA INT, @IdGoleador INT;
DECLARE @Lado INT, @k INT, @IdPl INT, @Nom VARCHAR(100), @Pos VARCHAR(50), @Tit BIT, @IdPartidoX INT;
DECLARE @IdJugada INT = (SELECT IdTipoJugada FROM cfg.Tipo_Jugada WHERE Descripcion = 'Jugada');
DECLARE @IdAlargue INT = (SELECT MIN(IdPeriodo) FROM cfg.Periodo WHERE Descripcion = 'Alargue');

INSERT INTO op.Pais (Nombre, HorarioUTC, OffsetUTC) VALUES ('País Test E7 A', 'UTC-7', -7);
SET @IdPaisA = SCOPE_IDENTITY();
INSERT INTO op.Pais (Nombre, HorarioUTC, OffsetUTC) VALUES ('País Test E7 B', 'UTC-7', -7);
SET @IdPaisB = SCOPE_IDENTITY();
INSERT INTO op.Seleccion (IdPais, IdConfederacion, Grupo) VALUES (@IdPaisA, @IdConf, NULL);
SET @IdSelA = SCOPE_IDENTITY();
INSERT INTO op.Seleccion (IdPais, IdConfederacion, Grupo) VALUES (@IdPaisB, @IdConf, NULL);
SET @IdSelB = SCOPE_IDENTITY();
INSERT INTO op.Plantel (IdSeleccion) VALUES (@IdSelA);
SET @IdPlA = SCOPE_IDENTITY();
INSERT INTO op.Plantel (IdSeleccion) VALUES (@IdSelB);
SET @IdPlB = SCOPE_IDENTITY();

-- 13 jugadores por selección (dorsal 1 arquero, 13 suplente)
SET @Lado = 1;
WHILE @Lado <= 2
BEGIN
    SET @IdPl = CASE @Lado WHEN 1 THEN @IdPlA ELSE @IdPlB END;
    SET @k = 1;
    WHILE @k <= 13
    BEGIN
        SET @Nom = CONCAT('TestE7-', @Lado, '-', @k);
        SET @Pos = CASE WHEN @k = 1 THEN 'Arquero' WHEN @k <= 5 THEN 'Defensor' WHEN @k <= 8 THEN 'Mediocampista' ELSE 'Delantero' END;
        EXEC op.usp_AltaJugador @IdPlantel = @IdPl, @IdClub = @IdClub, @Nombre = @Nom, @Apellido = 'Prueba',
             @Nacionalidad = 'Test', @PosicionHabitual = @Pos, @Dorsal = @k;
        SET @k += 1;
    END;
    SET @Lado += 1;
END;
SELECT @IdSuplenteA = IdJugador FROM op.Jugador WHERE IdPlantel = @IdPlA AND Dorsal = 13;
SELECT @IdGoleador = IdJugador FROM op.Jugador WHERE IdPlantel = @IdPlA AND Dorsal = 9;

-- Partido 1 (grupos, sin alineaciones todavía) y partido 2 (cuartos)
INSERT INTO op.Partido (IdSede, IdSeleccionLocal, IdSeleccionVisitante, Fecha, HoraLocal, HoraUTC, Fase)
VALUES (@IdSede, @IdSelA, @IdSelB, '2026-08-01', '12:00', '19:00', 'Grupos');
SET @IdPartido1 = SCOPE_IDENTITY();
INSERT INTO op.Partido (IdSede, IdSeleccionLocal, IdSeleccionVisitante, Fecha, HoraLocal, HoraUTC, Fase)
VALUES (@IdSede, @IdSelA, @IdSelB, '2026-08-05', '12:00', '19:00', 'Cuartos');
SET @IdPartido2 = SCOPE_IDENTITY();


-- Casos de validación
PRINT '--- FinalizarPartido | Partido inexistente y público negativo';
-- Resultado esperado: ERROR con un único mensaje: el partido no existe y el público no puede ser negativo.
BEGIN TRY
    EXEC op.usp_FinalizarPartido @IdPartido = 999999, @PublicoAsistente = -10;
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- FinalizarPartido | Público mayor a la capacidad, alargue en grupos y sin alineaciones';
-- Resultado esperado: ERROR: el público supera la capacidad de BC Place (54000), un partido de grupos no tiene
-- alargue y faltan las alineaciones de ambas selecciones.
BEGIN TRY
    EXEC op.usp_FinalizarPartido @IdPartido = @IdPartido1, @PublicoAsistente = 99999, @TuvoAlargue = 1;
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- FinalizarPartido | Partido ya finalizado (uno de la carga de datos)';
-- Resultado esperado: ERROR 'El partido ya fue finalizado'.
BEGIN TRY
    SET @IdPartidoX = (SELECT MIN(IdPartido) FROM op.Partido WHERE PublicoAsistente IS NOT NULL);
    EXEC op.usp_FinalizarPartido @IdPartido = @IdPartidoX, @PublicoAsistente = 1000;
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;

/*
   Preparación del caso exitoso: alineaciones (11 titulares, el dorsal 13 de A
   queda fuera) y una suspensión del dorsal 13 de A originada en un partido anterior.
*/
SET @Lado = 1;
WHILE @Lado <= 4
BEGIN
    SET @IdPl = CASE WHEN @Lado IN (1, 3) THEN @IdPlA ELSE @IdPlB END;
    INSERT INTO op.Alineacion (IdPartido, IdPlantel, EsquemaTactico)
    VALUES (CASE WHEN @Lado <= 2 THEN @IdPartido1 ELSE @IdPartido2 END, @IdPl, '4-3-3');
    SET @IdAl = SCOPE_IDENTITY();
    SET @k = 1;
    WHILE @k <= 12
    BEGIN
        SELECT @IdJ = IdJugador, @Pos = PosicionHabitual FROM op.Jugador WHERE IdPlantel = @IdPl AND Dorsal = @k;
        SET @Tit = CASE WHEN @k <= 11 THEN 1 ELSE 0 END;
        EXEC op.usp_RegistrarAlineacionJugador @IdAlineacion = @IdAl, @IdJugador = @IdJ, @Posicion = @Pos, @EsTitular = @Tit, @Dorsal = @k;
        SET @k += 1;
    END;
    SET @Lado += 1;
END;

SET @IdPartidoX = (SELECT MIN(IdPartido) FROM op.Partido WHERE Fecha < '2026-08-01');
INSERT INTO op.Suspension (IdJugador, IdPartidoOrigen, PartidosRestantes, Motivo, Activa)
VALUES (@IdSuplenteA, @IdPartidoX, 1, 'Roja Directa', 1);
SET @IdSusp = SCOPE_IDENTITY();

PRINT '--- FinalizarPartido | Cierre exitoso de un partido de grupos 0 a 0';
-- Resultado esperado: el partido queda con público 30000, sin alargue y Resultado '0 - 0'.
-- La suspensión del dorsal 13 de A (originada en un partido anterior) pasa de 1 a 0 partidos restantes y queda inactiva.
BEGIN TRY
    SELECT 'Suspensión antes' AS Evidencia, * FROM op.Suspension WHERE IdSuspension = @IdSusp;
    EXEC op.usp_FinalizarPartido @IdPartido = @IdPartido1, @PublicoAsistente = 30000;
    SELECT 'Partido después' AS Evidencia, IdPartido, Fase, PublicoAsistente, TuvoAlargue, Resultado FROM op.Partido WHERE IdPartido = @IdPartido1;
    SELECT 'Suspensión después' AS Evidencia, * FROM op.Suspension WHERE IdSuspension = @IdSusp;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- FinalizarPartido | Partido de eliminación directa empatado';
-- Resultado esperado: ERROR 'Un partido de eliminación directa no puede terminar empatado'.
BEGIN TRY
    EXEC op.usp_FinalizarPartido @IdPartido = @IdPartido2, @PublicoAsistente = 40000;
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- FinalizarPartido | Partido de eliminación directa definido en el alargue';
-- Resultado esperado: con un gol del dorsal 9 de A en el minuto 110 el partido se cierra 1 - 0 con alargue.
BEGIN TRY
    EXEC op.usp_RegistrarGol_Y_ActualizarResultado @IdPartido = @IdPartido2, @IdJugadorAnotador = @IdGoleador,
         @IdJugadorAsistidor = NULL, @IdTipoJugada = @IdJugada, @IdPeriodo = @IdAlargue, @Minuto = 110;
    EXEC op.usp_FinalizarPartido @IdPartido = @IdPartido2, @PublicoAsistente = 40000, @TuvoAlargue = 1;
    SELECT 'Partido después' AS Evidencia, IdPartido, Fase, PublicoAsistente, TuvoAlargue, Resultado FROM op.Partido WHERE IdPartido = @IdPartido2;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

/*
   se borran los datos de prueba para no alterar los reportes
*/
DELETE FROM op.Anotacion WHERE IdPartido IN (@IdPartido1, @IdPartido2);
DELETE FROM op.Alineacion_Jugador WHERE IdAlineacion IN (SELECT IdAlineacion FROM op.Alineacion WHERE IdPartido IN (@IdPartido1, @IdPartido2));
DELETE FROM op.Alineacion WHERE IdPartido IN (@IdPartido1, @IdPartido2);
DELETE FROM op.Suspension WHERE IdSuspension = @IdSusp;
DELETE FROM op.Partido WHERE IdPartido IN (@IdPartido1, @IdPartido2);
DELETE FROM op.Jugador WHERE IdPlantel IN (@IdPlA, @IdPlB);
DELETE FROM op.Plantel WHERE IdPlantel IN (@IdPlA, @IdPlB);
DELETE FROM op.Seleccion WHERE IdSeleccion IN (@IdSelA, @IdSelB);
DELETE FROM op.Pais WHERE IdPais IN (@IdPaisA, @IdPaisB);
PRINT '=== Fin del testing de 02_E7_SP_FinalizarPartido (datos de prueba eliminados) ===';
GO
