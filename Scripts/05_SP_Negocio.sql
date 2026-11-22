/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: Procedimientos Almacenados de Lógica de Negocio (transaccionales,
             set-based): Alineaciones, Cambios (con tope de cambios y
             ventanas), Convocatorias, Tarjetas/Suspensiones, Goles/Resultado,
             Árbitros (conflicto ético + advertencia) y Publicidad priorizada.
========================================================================= */

USE Mundial2026;
GO

-- 1. Registrar Cabecera de Alineación (Formación y Esquema Táctico)
CREATE OR ALTER PROCEDURE op.usp_RegistrarAlineacion
    @IdPartido INT,
    @IdPlantel INT,
    @EsquemaTactico VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido) SET @MensajeErrores += 'El partido no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Plantel WHERE IdPlantel = @IdPlantel) SET @MensajeErrores += 'El plantel no existe. | ';
    IF @EsquemaTactico IS NULL OR LTRIM(RTRIM(@EsquemaTactico)) = '' SET @MensajeErrores += 'El esquema táctico es obligatorio. | ';

    IF LEN(@MensajeErrores) > 0
        THROW 50201, @MensajeErrores, 1;

    INSERT INTO op.Alineacion (IdPartido, IdPlantel, EsquemaTactico)
    VALUES (@IdPartido, @IdPlantel, @EsquemaTactico);
END;
GO

-- 2. Registrar Jugador en Alineación (Titular o Banco de Suplentes, validando suspensión activa)
CREATE OR ALTER PROCEDURE op.usp_RegistrarAlineacionJugador
    @IdAlineacion INT,
    @IdJugador INT,
    @Posicion VARCHAR(50),
    @EsTitular BIT = 1,
    @Dorsal INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM op.Alineacion WHERE IdAlineacion = @IdAlineacion) SET @MensajeErrores += 'La alineación no existe. | ';
    IF NOT EXISTS (SELECT 1 FROM op.Jugador WHERE IdJugador = @IdJugador) SET @MensajeErrores += 'El jugador no existe. | ';
    IF @EsTitular = 1 AND EXISTS (SELECT 1 FROM op.Suspension WHERE IdJugador = @IdJugador AND Activa = 1 AND PartidosRestantes > 0)
        SET @MensajeErrores += 'El jugador tiene una suspensión activa y no puede ser titular. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Alineación): ' + @MensajeErrores;
        THROW 50008, @ErrorThrow, 1;
    END

    INSERT INTO op.Alineacion_Jugador (IdAlineacion, IdJugador, Posicion, EsTitular, Dorsal)
    VALUES (@IdAlineacion, @IdJugador, @Posicion, @EsTitular, @Dorsal);
END;
GO

-- 3. Registrar Cambio de Jugador (valida máximo de cambios: 5/6 y máximo de ventanas: 3/4)
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

    DECLARE @IdPlantel INT = (SELECT IdPlantel FROM op.Jugador WHERE IdJugador = @IdJugadorSaliente);
    DECLARE @TuvoAlargue BIT = ISNULL((SELECT TuvoAlargue FROM op.Partido WHERE IdPartido = @IdPartido), 0);
    DECLARE @MaxCambios INT = CASE WHEN @TuvoAlargue = 1 THEN 6 ELSE 5 END;
    DECLARE @MaxVentanas INT = CASE WHEN @TuvoAlargue = 1 THEN 4 ELSE 3 END;

    -- Contar cambios ya realizados por ese equipo en el partido
    DECLARE @CambiosRealizados INT = (
        SELECT COUNT(*)
        FROM op.Cambios c
        INNER JOIN op.Jugador j ON c.IdJugadorSaliente = j.IdJugador
        WHERE c.IdPartido = @IdPartido AND j.IdPlantel = @IdPlantel
    );

    IF @CambiosRealizados >= @MaxCambios
        SET @MensajeErrores += 'El equipo alcanzó el máximo de cambios permitidos para este partido. | ';

    -- Contar ventanas de cambio distintas (minuto 45 = entretiempo no consume ventana; cambios simultáneos comparten ventana)
    IF @Minuto <> 45 AND NOT EXISTS (
        SELECT 1
        FROM op.Cambios c
        INNER JOIN op.Jugador j ON c.IdJugadorSaliente = j.IdJugador
        WHERE c.IdPartido = @IdPartido AND j.IdPlantel = @IdPlantel AND c.Minuto = @Minuto
    )
    BEGIN
        DECLARE @VentanasUsadas INT = (
            SELECT COUNT(DISTINCT c.Minuto)
            FROM op.Cambios c
            INNER JOIN op.Jugador j ON c.IdJugadorSaliente = j.IdJugador
            WHERE c.IdPartido = @IdPartido AND j.IdPlantel = @IdPlantel AND c.Minuto <> 45
        );

        IF @VentanasUsadas >= @MaxVentanas
            SET @MensajeErrores += 'El equipo alcanzó el máximo de ventanas de sustitución permitidas. | ';
    END

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Cambios): ' + @MensajeErrores;
        THROW 50006, @ErrorThrow, 1;
    END

    INSERT INTO op.Cambios (IdPartido, IdJugadorSaliente, IdJugadorIngresante, Minuto, Motivo)
    VALUES (@IdPartido, @IdJugadorSaliente, @IdJugadorIngresante, @Minuto, @Motivo);
END;
GO

-- 4. Modificación de Convocatoria (Altas/Bajas de último momento)
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

-- 5. Registrar Tarjeta y Calcular Suspensión (persiste en op.Suspension)
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

        DECLARE @DescTipo VARCHAR(50);
        DECLARE @ReglaRequerida INT = 0;
        DECLARE @PartidosDeSancion INT = 1;

        SELECT @DescTipo = tt.Descripcion,
               @ReglaRequerida = ISNULL(rs.Canti_requerida, 0),
               @PartidosDeSancion = ISNULL(rs.Partidos_suspension, 1)
        FROM cfg.Tipo_Tarjeta tt
        LEFT JOIN cfg.Regla_Suspencion rs ON tt.IdRegla = rs.IdRegla
        WHERE tt.IdTipoTarjeta = @IdTipoTarjeta;

        IF @DescTipo IN ('Doble Amarilla', 'Roja Directa')
        BEGIN
            INSERT INTO op.Suspension (IdJugador, IdPartidoOrigen, PartidosRestantes, Motivo, Activa)
            VALUES (@IdJugador, @IdPartido, @PartidosDeSancion, @DescTipo, 1);

            PRINT '>>> ATENCIÓN: El Jugador ID ' + CAST(@IdJugador AS VARCHAR) + ' fue SUSPENDIDO por ' + @DescTipo + ' (' + CAST(@PartidosDeSancion AS VARCHAR) + ' partido/s). <<<';
        END
        ELSE IF @ReglaRequerida > 0
        BEGIN
            DECLARE @PartidosConAmarilla INT = (
                SELECT COUNT(DISTINCT IdPartido)
                FROM op.Tarjeta
                WHERE IdJugador = @IdJugador AND IdTipoTarjeta = @IdTipoTarjeta
            );

            IF @PartidosConAmarilla >= @ReglaRequerida
            BEGIN
                INSERT INTO op.Suspension (IdJugador, IdPartidoOrigen, PartidosRestantes, Motivo, Activa)
                VALUES (@IdJugador, @IdPartido, @PartidosDeSancion, 'Acumulación de amarillas', 1);

                PRINT '>>> ATENCIÓN: El Jugador ID ' + CAST(@IdJugador AS VARCHAR) + ' fue SUSPENDIDO por acumulación (' + CAST(@PartidosDeSancion AS VARCHAR) + ' partido/s). <<<';
            END
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 6. Registrar Gol y Actualizar Resultado (marcador Local - Visitante)
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

        DECLARE @GolesLocal INT = 0, @GolesVisitante INT = 0;

        SELECT
            @GolesLocal = SUM(CASE
                WHEN (pl.IdSeleccion = p.IdSeleccionLocal AND tj.Descripcion <> 'En contra')
                  OR (pl.IdSeleccion = p.IdSeleccionVisitante AND tj.Descripcion = 'En contra')
                THEN 1 ELSE 0 END),
            @GolesVisitante = SUM(CASE
                WHEN (pl.IdSeleccion = p.IdSeleccionVisitante AND tj.Descripcion <> 'En contra')
                  OR (pl.IdSeleccion = p.IdSeleccionLocal AND tj.Descripcion = 'En contra')
                THEN 1 ELSE 0 END)
        FROM op.Anotacion a
        INNER JOIN op.Partido p ON a.IdPartido = p.IdPartido
        INNER JOIN op.Jugador j ON a.IdJugadorAnotador = j.IdJugador
        INNER JOIN op.Plantel pl ON j.IdPlantel = pl.IdPlantel
        INNER JOIN cfg.Tipo_Jugada tj ON a.IdTipoJugada = tj.IdTipoJugada
        WHERE a.IdPartido = @IdPartido;

        UPDATE op.Partido
        SET Resultado = CONCAT(ISNULL(@GolesLocal, 0), ' - ', ISNULL(@GolesVisitante, 0))
        WHERE IdPartido = @IdPartido;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 7. Designación de Árbitros (5 roles + Validación Ética + Advertencia desde Dieciseisavos)
CREATE OR ALTER PROCEDURE op.usp_DesignarArbitros
    @IdPartido INT,
    @IdArbitroPrincipal INT,
    @IdArbitroAsistente1 INT,
    @IdArbitroAsistente2 INT,
    @IdCuartoArbitro INT,
    @IdArbitroVAR INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF EXISTS (
        SELECT 1
        FROM op.Partido p
        INNER JOIN op.Seleccion s ON s.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
        INNER JOIN op.Pais pa ON s.IdPais = pa.IdPais
        INNER JOIN op.Arbitro a ON a.Nacionalidad = pa.Nombre
        WHERE p.IdPartido = @IdPartido
          AND a.IdArbitro IN (@IdArbitroPrincipal, @IdArbitroAsistente1, @IdArbitroAsistente2, @IdCuartoArbitro, @IdArbitroVAR)
    )
        SET @MensajeErrores += 'CONFLICTO ÉTICO: Uno de los árbitros tiene la misma nacionalidad que uno de los equipos del partido. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS: ' + @MensajeErrores;
        THROW 50005, @ErrorThrow, 1;
    END

    DECLARE @Fase VARCHAR(50) = (SELECT Fase FROM op.Partido WHERE IdPartido = @IdPartido);
    IF @Fase IN ('Dieciseisavos', 'Octavos', 'Cuartos', 'Semifinal', 'Tercer Puesto', 'Final')
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM op.Partido p
            INNER JOIN op.Seleccion s ON s.IdSeleccion IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
            INNER JOIN op.Pais pa ON s.IdPais = pa.IdPais
            INNER JOIN op.Arbitro a ON a.Nacionalidad = pa.Nombre
            WHERE p.Fase = @Fase
              AND p.IdPartido <> @IdPartido
              AND a.IdArbitro IN (@IdArbitroPrincipal, @IdArbitroAsistente1, @IdArbitroAsistente2, @IdCuartoArbitro, @IdArbitroVAR)
        )
            PRINT '>>> ADVERTENCIA: Al menos un árbitro pertenece a un país que sigue en competencia en fase ' + @Fase + ' y podría cruzarse. <<<';
    END

    INSERT INTO op.Lista_Arbitros (IdPartido, IdArbitroPrincipal, IdArbitroAsistente1, IdArbitroAsistente2, IdCuartoArbitro, IdArbitroVAR)
    VALUES (@IdPartido, @IdArbitroPrincipal, @IdArbitroAsistente1, @IdArbitroAsistente2, @IdCuartoArbitro, @IdArbitroVAR);
END;
GO

-- 8. Asignar Publicidad (Priorización: Países del partido -> Mayor PBI -> Prime Time)
CREATE OR ALTER PROCEDURE op.usp_AsignarPublicidadPartido
    @IdPartido INT,
    @IdSede INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @HoraUTC TIME, @PaisLocal INT, @PaisVisitante INT;

        SELECT @HoraUTC = p.HoraUTC,
               @PaisLocal = sl.IdPais,
               @PaisVisitante = sv.IdPais
        FROM op.Partido p
        INNER JOIN op.Seleccion sl ON p.IdSeleccionLocal = sl.IdSeleccion
        INNER JOIN op.Seleccion sv ON p.IdSeleccionVisitante = sv.IdSeleccion
        WHERE p.IdPartido = @IdPartido;

        ;WITH Espacios AS (
            SELECT TOP 4
                IdEspacio,
                ROW_NUMBER() OVER (ORDER BY IdEspacio) AS Fila
            FROM op.EspacioPublicitario
            WHERE IdSede = @IdSede
            ORDER BY IdEspacio
        ),
        PiezasEvaluadas AS (
            SELECT
                pc.IdPieza,
                pc.Tarifa,
                MAX(CASE WHEN pp.IdPais IN (@PaisLocal, @PaisVisitante) THEN 1 ELSE 0 END) AS EsPaisPartido,
                ISNULL(MAX(pa.PbiPerCapita), 0) AS MaxPbi,
                MAX(CASE WHEN (DATEPART(HOUR, @HoraUTC) + pa.OffsetUTC + 24) % 24 BETWEEN 19 AND 23 THEN 1 ELSE 0 END) AS EsPrimeTime
            FROM cfg.Pieza_Contenido pc
            LEFT JOIN cfg.Pieza_Pais pp ON pc.IdPieza = pp.IdPieza
            LEFT JOIN op.Pais pa ON pp.IdPais = pa.IdPais
            GROUP BY pc.IdPieza, pc.Tarifa
        ),
        PiezasTop4 AS (
            SELECT TOP 4
                IdPieza,
                Tarifa,
                ROW_NUMBER() OVER (ORDER BY EsPaisPartido DESC, MaxPbi DESC, EsPrimeTime DESC, IdPieza ASC) AS Fila
            FROM PiezasEvaluadas
            ORDER BY EsPaisPartido DESC, MaxPbi DESC, EsPrimeTime DESC, IdPieza ASC
        )
        INSERT INTO op.Exhibicion (IdEspacio, IdPartido, IdPieza, Tarifa)
        SELECT e.IdEspacio, @IdPartido, p.IdPieza, p.Tarifa
        FROM Espacios e
        INNER JOIN PiezasTop4 p ON e.Fila = p.Fila;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
