/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli, Agustín Nicolás Mussi Pulcini
   Objetivo: SP transaccional op.usp_FinalizarPartido.
             Registra público y alargue, carga el resultado final en
             op.Partido y descuenta 1 partido de las suspensiones activas de ambas selecciones.
========================================================================= */

USE Mundial2026;
GO

CREATE OR ALTER PROCEDURE op.usp_FinalizarPartido
    @IdPartido INT,
    @PublicoAsistente INT,
    @TuvoAlargue BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MensajeErrores NVARCHAR(MAX) = '';
    DECLARE @IdLocal INT, @IdVisitante INT, @Fecha DATE, @HoraUTC TIME, @Fase VARCHAR(50),
            @PublicoActual INT, @Capacidad INT, @GolesLocal INT, @GolesVisitante INT, @Alineaciones INT;

    SELECT @IdLocal = p.IdSeleccionLocal, @IdVisitante = p.IdSeleccionVisitante, @Fecha = p.Fecha,
           @HoraUTC = p.HoraUTC, @Fase = p.Fase, @PublicoActual = p.PublicoAsistente, @Capacidad = s.Capacidad
    FROM op.Partido p
    INNER JOIN op.Sede s ON s.IdSede = p.IdSede
    WHERE p.IdPartido = @IdPartido;

    SELECT @GolesLocal = GolesLocal, @GolesVisitante = GolesVisitante
    FROM op.vw_ResultadoPartido
    WHERE IdPartido = @IdPartido;

    SELECT @Alineaciones = COUNT(DISTINCT pl.IdSeleccion)
    FROM op.Alineacion a
    INNER JOIN op.Plantel pl ON pl.IdPlantel = a.IdPlantel
    WHERE a.IdPartido = @IdPartido AND pl.IdSeleccion IN (@IdLocal, @IdVisitante);

    IF @Fase IS NULL
        SET @MensajeErrores += 'El partido no existe. | ';
    IF @PublicoActual IS NOT NULL
        SET @MensajeErrores += 'El partido ya fue finalizado. | ';
    IF @PublicoAsistente IS NULL OR @PublicoAsistente < 0
        SET @MensajeErrores += 'El público asistente es obligatorio y no puede ser negativo. | ';
    IF @PublicoAsistente > @Capacidad
        SET @MensajeErrores += 'El público asistente supera la capacidad de la sede (' + CAST(@Capacidad AS VARCHAR(10)) + '). | ';
    IF @Fase IS NOT NULL AND ISNULL(@Alineaciones, 0) < 2
        SET @MensajeErrores += 'Deben estar cargadas las alineaciones de ambas selecciones. | ';
    IF @Fase = 'Grupos' AND @TuvoAlargue = 1
        SET @MensajeErrores += 'Un partido de fase de grupos no tiene alargue. | ';
    IF @Fase IS NOT NULL AND @Fase <> 'Grupos' AND @GolesLocal = @GolesVisitante
        SET @MensajeErrores += 'Un partido de eliminación directa no puede terminar empatado: registre el gol del alargue. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Finalizar partido): ' + @MensajeErrores;
        THROW 50701, @ErrorThrow, 1;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE op.Partido
        SET PublicoAsistente = @PublicoAsistente,
            TuvoAlargue = @TuvoAlargue,
            Resultado = CONCAT(@GolesLocal, ' - ', @GolesVisitante)
        WHERE IdPartido = @IdPartido;

        -- Cumplimiento de suspensiones originadas en partidos anteriores
        UPDATE su
        SET PartidosRestantes = su.PartidosRestantes - 1,
            Activa = CASE WHEN su.PartidosRestantes - 1 <= 0 THEN 0 ELSE 1 END
        FROM op.Suspension su
        INNER JOIN op.Jugador j ON j.IdJugador = su.IdJugador
        INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
        INNER JOIN op.Partido po ON po.IdPartido = su.IdPartidoOrigen
        WHERE su.Activa = 1
          AND su.PartidosRestantes > 0
          AND pl.IdSeleccion IN (@IdLocal, @IdVisitante)
          AND (po.Fecha < @Fecha OR (po.Fecha = @Fecha AND po.HoraUTC < @HoraUTC));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
