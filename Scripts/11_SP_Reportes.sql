/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: ENTREGA 7 - Stored Procedures de Reportes (esquema rpt).
             Incluye los 7 reportes solicitados (3 devuelven XML):
             1. rpt.usp_Goleadores              (por torneo, selección o fase)
             2. rpt.usp_Tarjetas                (por selección, jugador y suspensiones activas)
             3. rpt.usp_DesignacionesArbitrales (XML: partidos por árbitro, tarjetas e informes)
             4. rpt.usp_OcupacionPublicitaria   (por sede y partido, con conversión de moneda)
             5. rpt.usp_MatrizPrimeTime         (PIVOT dinámico partido x mercado)
             6. rpt.usp_SeleccionesPlantillas   (XML: selecciones con convocados anidados)
             7. rpt.usp_Resultados              (TABLA + posiciones, o XML con goles anidados)
========================================================================= */

USE Mundial2026;
GO

IF SCHEMA_ID('rpt') IS NULL
    EXEC('CREATE SCHEMA rpt');
GO

-- =========================================================================
-- 1. GOLEADORES por torneo, selección o fase
-- =========================================================================
CREATE OR ALTER PROCEDURE rpt.usp_Goleadores
    @Agrupacion VARCHAR(10) = 'Torneo',
    @IdSeleccion INT = NULL,
    @Fase VARCHAR(50) = NULL,
    @Top INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF @Agrupacion IS NULL OR @Agrupacion NOT IN ('Torneo', 'Seleccion', 'Fase')
        SET @MensajeErrores += 'La agrupación debe ser Torneo, Seleccion o Fase. | ';
    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @MensajeErrores += 'La selección no existe. | ';
    IF @Fase IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE Fase = @Fase)
        SET @MensajeErrores += 'No hay partidos de la fase indicada. | ';
    IF @Top IS NOT NULL AND @Top <= 0
        SET @MensajeErrores += 'El Top debe ser mayor a cero. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Goleadores): ' + @MensajeErrores;
        THROW 50711, @ErrorThrow, 1;
    END

    ;WITH Goles AS (
        SELECT CASE @Agrupacion WHEN 'Seleccion' THEN pa.Nombre
                                WHEN 'Fase' THEN p.Fase
                                ELSE 'Torneo' END AS Grupo,
               a.IdJugadorAnotador AS IdJugador,
               pa.Nombre AS Seleccion,
               a.IdPartido,
               tj.Descripcion AS TipoJugada
        FROM op.Anotacion a
        INNER JOIN op.Partido p ON p.IdPartido = a.IdPartido
        INNER JOIN cfg.Tipo_Jugada tj ON tj.IdTipoJugada = a.IdTipoJugada
        INNER JOIN op.Jugador j ON j.IdJugador = a.IdJugadorAnotador
        INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
        INNER JOIN op.Seleccion s ON s.IdSeleccion = pl.IdSeleccion
        INNER JOIN op.Pais pa ON pa.IdPais = s.IdPais
        WHERE tj.Descripcion <> 'En contra'
          AND (@IdSeleccion IS NULL OR s.IdSeleccion = @IdSeleccion)
          AND (@Fase IS NULL OR p.Fase = @Fase)
    ),
    Ranking AS (
        SELECT g.Grupo,
               g.IdJugador,
               g.Seleccion,
               COUNT(*) AS Goles,
               SUM(CASE WHEN g.TipoJugada = 'Penal' THEN 1 ELSE 0 END) AS DePenal,
               COUNT(DISTINCT g.IdPartido) AS PartidosConGol,
               DENSE_RANK() OVER (PARTITION BY g.Grupo ORDER BY COUNT(*) DESC) AS Puesto
        FROM Goles g
        GROUP BY g.Grupo, g.IdJugador, g.Seleccion
    ),
    Asistencias AS (
        SELECT asi.IdJugadorAsistidor AS IdJugador, COUNT(*) AS CantAsistencias
        FROM op.Anotacion asi
        INNER JOIN op.Partido pa2 ON pa2.IdPartido = asi.IdPartido
        WHERE asi.IdJugadorAsistidor IS NOT NULL
          AND (@Fase IS NULL OR pa2.Fase = @Fase)
        GROUP BY asi.IdJugadorAsistidor
    )
    SELECT r.Grupo AS Agrupacion,
           r.Puesto,
           CONCAT(j.Nombre, ' ', j.Apellido) AS Jugador,
           r.Seleccion,
           j.PosicionHabitual AS Posicion,
           r.Goles,
           r.DePenal,
           r.PartidosConGol,
           ISNULL(a.CantAsistencias, 0) AS Asistencias
    FROM Ranking r
    INNER JOIN op.Jugador j ON j.IdJugador = r.IdJugador
    LEFT JOIN Asistencias a ON a.IdJugador = r.IdJugador
    WHERE @Top IS NULL OR r.Puesto <= @Top
    ORDER BY r.Grupo, r.Puesto, j.Apellido;
END;
GO

-- =========================================================================
-- 2. TARJETAS por selección y jugador, con suspensiones activas por acumulación
-- =========================================================================
CREATE OR ALTER PROCEDURE rpt.usp_Tarjetas
    @IdSeleccion INT = NULL,
    @IdJugador INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @MensajeErrores += 'La selección no existe. | ';
    IF @IdJugador IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Jugador WHERE IdJugador = @IdJugador)
        SET @MensajeErrores += 'El jugador no existe. | ';
    IF @IdSeleccion IS NOT NULL AND @IdJugador IS NOT NULL
       AND EXISTS (SELECT 1 FROM op.Jugador j INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
                   WHERE j.IdJugador = @IdJugador AND pl.IdSeleccion <> @IdSeleccion)
        SET @MensajeErrores += 'El jugador no pertenece a la selección indicada. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Tarjetas): ' + @MensajeErrores;
        THROW 50712, @ErrorThrow, 1;
    END

    SELECT t.IdTarjeta, t.IdPartido, t.IdJugador, t.Minuto, tt.Descripcion AS Tipo,
           pl.IdSeleccion, pa.Nombre AS Seleccion
    INTO #Tarjetas
    FROM op.Tarjeta t
    INNER JOIN cfg.Tipo_Tarjeta tt ON tt.IdTipoTarjeta = t.IdTipoTarjeta
    INNER JOIN op.Jugador j ON j.IdJugador = t.IdJugador
    INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
    INNER JOIN op.Seleccion s ON s.IdSeleccion = pl.IdSeleccion
    INNER JOIN op.Pais pa ON pa.IdPais = s.IdPais
    WHERE (@IdSeleccion IS NULL OR pl.IdSeleccion = @IdSeleccion)
      AND (@IdJugador IS NULL OR t.IdJugador = @IdJugador);

    -- 1) Totales por selección
    SELECT t.Seleccion,
           SUM(CASE WHEN t.Tipo = 'Amarilla' THEN 1 ELSE 0 END) AS Amarillas,
           SUM(CASE WHEN t.Tipo = 'Doble Amarilla' THEN 1 ELSE 0 END) AS ExpulsionesDobleAmarilla,
           SUM(CASE WHEN t.Tipo = 'Roja Directa' THEN 1 ELSE 0 END) AS RojasDirectas,
           SUM(CASE WHEN t.Tipo IN ('Doble Amarilla', 'Roja Directa') THEN 1 ELSE 0 END) AS TotalExpulsiones,
           COUNT(*) AS TotalTarjetas,
           (SELECT COUNT(*) FROM op.Suspension su
            INNER JOIN op.Jugador j2 ON j2.IdJugador = su.IdJugador
            INNER JOIN op.Plantel pl2 ON pl2.IdPlantel = j2.IdPlantel
            WHERE pl2.IdSeleccion = t.IdSeleccion AND su.Activa = 1) AS SuspendidosActivos
    FROM #Tarjetas t
    GROUP BY t.IdSeleccion, t.Seleccion
    ORDER BY TotalExpulsiones DESC, Amarillas DESC, t.Seleccion;

    -- 2) Detalle por jugador
    SELECT t.Seleccion,
           CONCAT(j.Nombre, ' ', j.Apellido) AS Jugador,
           j.Dorsal,
           SUM(CASE WHEN t.Tipo = 'Amarilla' THEN 1 ELSE 0 END) AS Amarillas,
           COUNT(DISTINCT CASE WHEN t.Tipo = 'Amarilla' THEN t.IdPartido END) AS PartidosConAmarilla,
           SUM(CASE WHEN t.Tipo = 'Doble Amarilla' THEN 1 ELSE 0 END) AS ExpulsionesDobleAmarilla,
           SUM(CASE WHEN t.Tipo = 'Roja Directa' THEN 1 ELSE 0 END) AS RojasDirectas,
           CASE WHEN su.IdSuspension IS NOT NULL THEN 'Sí' ELSE 'No' END AS SuspendidoActualmente,
           su.Motivo AS MotivoSuspension,
           su.PartidosRestantes
    FROM #Tarjetas t
    INNER JOIN op.Jugador j ON j.IdJugador = t.IdJugador
    OUTER APPLY (
        SELECT TOP (1) s.IdSuspension, s.Motivo, s.PartidosRestantes
        FROM op.Suspension s
        WHERE s.IdJugador = t.IdJugador AND s.Activa = 1
        ORDER BY s.IdSuspension DESC
    ) su
    GROUP BY t.Seleccion, t.IdJugador, j.Nombre, j.Apellido, j.Dorsal, su.IdSuspension, su.Motivo, su.PartidosRestantes
    ORDER BY t.Seleccion, SUM(CASE WHEN t.Tipo IN ('Doble Amarilla', 'Roja Directa') THEN 1 ELSE 0 END) DESC, Amarillas DESC, Jugador;

    -- 3) Suspensiones activas por acumulación de amarillas
    SELECT pa.Nombre AS Seleccion,
           CONCAT(j.Nombre, ' ', j.Apellido) AS Jugador,
           j.Dorsal,
           su.PartidosRestantes,
           CONCAT(CONVERT(VARCHAR(10), po.Fecha, 103), ' ', plo.Nombre, ' vs ', pvo.Nombre) AS PartidoOrigen,
           (SELECT STRING_AGG(CONCAT(CONVERT(VARCHAR(10), p2.Fecha, 103), ' min ', t2.Minuto), ' | ')
                   WITHIN GROUP (ORDER BY p2.Fecha)
            FROM op.Tarjeta t2
            INNER JOIN cfg.Tipo_Tarjeta tt2 ON tt2.IdTipoTarjeta = t2.IdTipoTarjeta
            INNER JOIN op.Partido p2 ON p2.IdPartido = t2.IdPartido
            WHERE t2.IdJugador = su.IdJugador AND tt2.Descripcion = 'Amarilla') AS AmarillasRecibidas
    FROM op.Suspension su
    INNER JOIN op.Jugador j ON j.IdJugador = su.IdJugador
    INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
    INNER JOIN op.Seleccion s ON s.IdSeleccion = pl.IdSeleccion
    INNER JOIN op.Pais pa ON pa.IdPais = s.IdPais
    INNER JOIN op.Partido po ON po.IdPartido = su.IdPartidoOrigen
    INNER JOIN op.Seleccion slo ON slo.IdSeleccion = po.IdSeleccionLocal
    INNER JOIN op.Pais plo ON plo.IdPais = slo.IdPais
    INNER JOIN op.Seleccion svo ON svo.IdSeleccion = po.IdSeleccionVisitante
    INNER JOIN op.Pais pvo ON pvo.IdPais = svo.IdPais
    WHERE su.Activa = 1
      AND su.Motivo = 'Acumulación de amarillas'
      AND (@IdSeleccion IS NULL OR pl.IdSeleccion = @IdSeleccion)
      AND (@IdJugador IS NULL OR su.IdJugador = @IdJugador)
    ORDER BY pa.Nombre, Jugador;

    DROP TABLE IF EXISTS #Tarjetas;
END;
GO

-- =========================================================================
-- 3. DESIGNACIONES ARBITRALES (XML)
-- =========================================================================
CREATE OR ALTER PROCEDURE rpt.usp_DesignacionesArbitrales
    @IdArbitro INT = NULL,
    @SoloConDesignaciones BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF @IdArbitro IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Arbitro WHERE IdArbitro = @IdArbitro)
        SET @MensajeErrores += 'El árbitro no existe. | ';
    IF @SoloConDesignaciones IS NULL
        SET @MensajeErrores += 'El parámetro SoloConDesignaciones es obligatorio. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Designaciones arbitrales): ' + @MensajeErrores;
        THROW 50713, @ErrorThrow, 1;
    END

    SELECT la.IdPartido, r.Rol, r.IdArbitro
    INTO #Designaciones
    FROM op.Lista_Arbitros la
    CROSS APPLY (VALUES ('Principal', la.IdArbitroPrincipal), ('Asistente 1', la.IdArbitroAsistente1),
                        ('Asistente 2', la.IdArbitroAsistente2), ('Cuarto árbitro', la.IdCuartoArbitro),
                        ('VAR', la.IdArbitroVAR)) r(Rol, IdArbitro);

    DECLARE @Xml XML = (
        SELECT a.IdArbitro AS '@id',
               CONCAT(a.Nombre, ' ', a.Apellido) AS '@nombre',
               a.Nacionalidad AS '@nacionalidad',
               a.Categoria AS '@categoria',
               (SELECT COUNT(*) FROM #Designaciones d WHERE d.IdArbitro = a.IdArbitro) AS '@partidosDesignado',
               (SELECT COUNT(*) FROM #Designaciones d WHERE d.IdArbitro = a.IdArbitro AND d.Rol = 'Principal') AS '@partidosDirigidos',
               (SELECT COUNT(*) FROM #Designaciones d
                INNER JOIN op.Tarjeta t ON t.IdPartido = d.IdPartido
                INNER JOIN cfg.Tipo_Tarjeta tt ON tt.IdTipoTarjeta = t.IdTipoTarjeta
                WHERE d.IdArbitro = a.IdArbitro AND d.Rol = 'Principal' AND tt.Descripcion = 'Amarilla') AS '@amonestaciones',
               (SELECT COUNT(*) FROM #Designaciones d
                INNER JOIN op.Tarjeta t ON t.IdPartido = d.IdPartido
                INNER JOIN cfg.Tipo_Tarjeta tt ON tt.IdTipoTarjeta = t.IdTipoTarjeta
                WHERE d.IdArbitro = a.IdArbitro AND d.Rol = 'Principal' AND tt.Descripcion <> 'Amarilla') AS '@expulsiones',
               (SELECT p.IdPartido AS '@id',
                       CONVERT(VARCHAR(10), p.Fecha, 23) AS '@fecha',
                       p.Fase AS '@fase',
                       d.Rol AS '@rol',
                       pl.Nombre AS '@local',
                       pv.Nombre AS '@visitante',
                       CONCAT(r.GolesLocal, ' - ', r.GolesVisitante) AS '@resultado',
                       (SELECT t.Minuto AS '@minuto',
                               tt.Descripcion AS '@tipo',
                               CONCAT(j.Nombre, ' ', j.Apellido) AS '@jugador',
                               pj.Nombre AS '@seleccion',
                               t.Motivo AS '@motivo'
                        FROM op.Tarjeta t
                        INNER JOIN cfg.Tipo_Tarjeta tt ON tt.IdTipoTarjeta = t.IdTipoTarjeta
                        INNER JOIN op.Jugador j ON j.IdJugador = t.IdJugador
                        INNER JOIN op.Plantel plj ON plj.IdPlantel = j.IdPlantel
                        INNER JOIN op.Seleccion sj ON sj.IdSeleccion = plj.IdSeleccion
                        INNER JOIN op.Pais pj ON pj.IdPais = sj.IdPais
                        WHERE t.IdPartido = p.IdPartido AND d.Rol = 'Principal'
                        ORDER BY t.Minuto
                        FOR XML PATH('Tarjeta'), TYPE) AS 'TarjetasSenaladas',
                       (SELECT i.Tipo AS '@tipo',
                               CONVERT(VARCHAR(10), i.Fecha, 23) AS '@fecha',
                               i.Descripcion AS 'text()'
                        FROM op.Informe_Arbitro i
                        WHERE i.IdPartido = p.IdPartido AND i.IdArbitro = a.IdArbitro
                        FOR XML PATH('Informe'), TYPE) AS 'Informes'
                FROM #Designaciones d
                INNER JOIN op.Partido p ON p.IdPartido = d.IdPartido
                INNER JOIN op.vw_ResultadoPartido r ON r.IdPartido = p.IdPartido
                INNER JOIN op.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
                INNER JOIN op.Pais pl ON pl.IdPais = sl.IdPais
                INNER JOIN op.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
                INNER JOIN op.Pais pv ON pv.IdPais = sv.IdPais
                WHERE d.IdArbitro = a.IdArbitro
                ORDER BY p.Fecha, p.HoraUTC
                FOR XML PATH('Partido'), TYPE) AS 'Partidos'
        FROM op.Arbitro a
        WHERE (@IdArbitro IS NULL OR a.IdArbitro = @IdArbitro)
          AND (@SoloConDesignaciones = 0 OR EXISTS (SELECT 1 FROM #Designaciones d WHERE d.IdArbitro = a.IdArbitro))
        ORDER BY a.Apellido, a.Nombre
        FOR XML PATH('Arbitro'), ROOT('DesignacionesArbitrales'), TYPE
    );

    SELECT @Xml AS ReporteDesignacionesArbitrales;
    DROP TABLE IF EXISTS #Designaciones;
END;
GO

-- =========================================================================
-- 4. OCUPACIÓN PUBLICITARIA por sede y partido (con conversión de moneda)
-- =========================================================================
CREATE OR ALTER PROCEDURE rpt.usp_OcupacionPublicitaria
    @IdSede INT = NULL,
    @IdPartido INT = NULL,
    @Moneda VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';
    DECLARE @ValorEnARS DECIMAL(18,4) = 1;

    IF @Moneda IS NOT NULL
        SELECT @ValorEnARS = ValorEnARS FROM cfg.Cotizacion_Moneda WHERE CodigoMoneda = UPPER(@Moneda);

    IF @IdSede IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Sede WHERE IdSede = @IdSede)
        SET @MensajeErrores += 'La sede no existe. | ';
    IF @IdPartido IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido)
        SET @MensajeErrores += 'El partido no existe. | ';
    IF @IdSede IS NOT NULL AND @IdPartido IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido AND IdSede = @IdSede)
        SET @MensajeErrores += 'El partido no se juega en la sede indicada. | ';
    IF @Moneda IS NOT NULL AND NOT EXISTS (SELECT 1 FROM cfg.Cotizacion_Moneda WHERE CodigoMoneda = UPPER(@Moneda))
        SET @MensajeErrores += 'La moneda no tiene cotización en cfg.Cotizacion_Moneda. | ';
    IF @Moneda IS NOT NULL AND @ValorEnARS <= 0
        SET @MensajeErrores += 'La cotización de la moneda debe ser mayor a cero. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Ocupación publicitaria): ' + @MensajeErrores;
        THROW 50714, @ErrorThrow, 1;
    END

    SELECT p.IdPartido, p.IdSede, p.Fecha, p.HoraLocal, p.Fase,
           CONCAT(pl.Nombre, ' vs ', pv.Nombre) AS Partido,
           s.NombreEstadio, s.Ciudad,
           (SELECT CASE WHEN COUNT(*) > 4 THEN 4 ELSE COUNT(*) END FROM op.EspacioPublicitario e WHERE e.IdSede = p.IdSede) AS EspaciosDisponibles
    INTO #Partidos
    FROM op.Partido p
    INNER JOIN op.Sede s ON s.IdSede = p.IdSede
    INNER JOIN op.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
    INNER JOIN op.Pais pl ON pl.IdPais = sl.IdPais
    INNER JOIN op.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    INNER JOIN op.Pais pv ON pv.IdPais = sv.IdPais
    WHERE (@IdSede IS NULL OR p.IdSede = @IdSede)
      AND (@IdPartido IS NULL OR p.IdPartido = @IdPartido);

    SELECT x.IdPartido, x.IdEspacio, e.Motivo AS Espacio, an.RazonSocial AS Anunciante, pan.Nombre AS PaisAnunciante,
           c.Nombre AS Campania, x.IdPieza, x.Tarifa
    INTO #Exhibiciones
    FROM op.Exhibicion x
    INNER JOIN #Partidos p ON p.IdPartido = x.IdPartido
    INNER JOIN op.EspacioPublicitario e ON e.IdEspacio = x.IdEspacio
    INNER JOIN cfg.Pieza_Contenido pc ON pc.IdPieza = x.IdPieza
    INNER JOIN cfg.Campania c ON c.IdCampania = pc.IdCampania
    INNER JOIN cfg.Anunciante an ON an.IdAnunciante = c.IdAnunciante
    INNER JOIN op.Pais pan ON pan.IdPais = an.IdPais;

    -- 1) Detalle por partido y espacio
    SELECT p.NombreEstadio AS Sede, p.Fecha, p.Partido, x.Espacio, x.Anunciante, x.PaisAnunciante, x.Campania,
           x.IdPieza, x.Tarifa AS TarifaARS,
           CASE WHEN @Moneda IS NULL THEN NULL ELSE CAST(ROUND(x.Tarifa / @ValorEnARS, 2) AS DECIMAL(18,2)) END AS TarifaEnMoneda,
           UPPER(@Moneda) AS Moneda
    FROM #Exhibiciones x
    INNER JOIN #Partidos p ON p.IdPartido = x.IdPartido
    ORDER BY p.NombreEstadio, p.Fecha, p.IdPartido, x.IdEspacio;

    -- 2) Resumen por partido
    SELECT p.NombreEstadio AS Sede, p.IdPartido, p.Fecha, p.Fase, p.Partido,
           p.EspaciosDisponibles,
           COUNT(DISTINCT x.IdEspacio) AS EspaciosOcupados,
           CAST(CASE WHEN p.EspaciosDisponibles = 0 THEN 0
                     ELSE 100.0 * COUNT(DISTINCT x.IdEspacio) / p.EspaciosDisponibles END AS DECIMAL(5,1)) AS PorcentajeOcupacion,
           (SELECT STRING_AGG(d.Anunciante, ', ')
            FROM (SELECT DISTINCT x2.Anunciante FROM #Exhibiciones x2 WHERE x2.IdPartido = p.IdPartido) d) AS Anunciantes,
           ISNULL(SUM(x.Tarifa), 0) AS IngresosARS,
           CASE WHEN @Moneda IS NULL THEN NULL ELSE CAST(ROUND(ISNULL(SUM(x.Tarifa), 0) / @ValorEnARS, 2) AS DECIMAL(18,2)) END AS IngresosEnMoneda
    FROM #Partidos p
    LEFT JOIN #Exhibiciones x ON x.IdPartido = p.IdPartido
    GROUP BY p.NombreEstadio, p.IdPartido, p.Fecha, p.Fase, p.Partido, p.EspaciosDisponibles
    ORDER BY p.NombreEstadio, p.Fecha, p.IdPartido;

    -- 3) Resumen por sede (simplificado con CTE)
    ;WITH ResumenPartido AS (
        SELECT p.IdSede, p.NombreEstadio, p.Ciudad, p.EspaciosDisponibles AS Disponibles,
               COUNT(DISTINCT x.IdEspacio) AS Ocupados,
               ISNULL(SUM(x.Tarifa), 0) AS Ingresos
        FROM #Partidos p
        LEFT JOIN #Exhibiciones x ON x.IdPartido = p.IdPartido
        GROUP BY p.IdSede, p.NombreEstadio, p.Ciudad, p.IdPartido, p.EspaciosDisponibles
    )
    SELECT NombreEstadio AS Sede,
           Ciudad,
           COUNT(*) AS Partidos,
           SUM(CASE WHEN Ocupados > 0 THEN 1 ELSE 0 END) AS PartidosConPublicidad,
           CAST(AVG(CASE WHEN Disponibles = 0 THEN 0 ELSE 100.0 * Ocupados / Disponibles END) AS DECIMAL(5,1)) AS OcupacionPromedio,
           SUM(Ingresos) AS IngresosARS,
           CASE WHEN @Moneda IS NULL THEN NULL ELSE CAST(ROUND(SUM(Ingresos) / @ValorEnARS, 2) AS DECIMAL(18,2)) END AS IngresosEnMoneda
    FROM ResumenPartido
    GROUP BY IdSede, NombreEstadio, Ciudad
    ORDER BY IngresosARS DESC;

    DROP TABLE IF EXISTS #Exhibiciones;
    DROP TABLE IF EXISTS #Partidos;
END;
GO

-- =========================================================================
-- 5. MATRIZ DE PRIME TIME (PIVOT dinámico partido x mercados)
--    SQL dinámico estrictamente necesario porque las columnas dependen de los países.
-- =========================================================================
CREATE OR ALTER PROCEDURE rpt.usp_MatrizPrimeTime
    @IdPartido INT = NULL,
    @Fase VARCHAR(50) = NULL,
    @SoloMercadosPublicitarios BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF @IdPartido IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido)
        SET @MensajeErrores += 'El partido no existe. | ';
    IF @Fase IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE Fase = @Fase)
        SET @MensajeErrores += 'No hay partidos de la fase indicada. | ';
    IF @SoloMercadosPublicitarios IS NULL
        SET @MensajeErrores += 'El parámetro SoloMercadosPublicitarios es obligatorio. | ';

    CREATE TABLE #Mercados (IdPais INT PRIMARY KEY, Nombre VARCHAR(100) NOT NULL, OffsetUTC INT NOT NULL);
    INSERT INTO #Mercados (IdPais, Nombre, OffsetUTC)
    SELECT pa.IdPais, pa.Nombre, pa.OffsetUTC
    FROM op.Pais pa
    WHERE @SoloMercadosPublicitarios = 0
       OR EXISTS (SELECT 1 FROM cfg.Pieza_Pais pp WHERE pp.IdPais = pa.IdPais);

    IF @SoloMercadosPublicitarios IS NOT NULL AND NOT EXISTS (SELECT 1 FROM #Mercados)
        SET @MensajeErrores += 'No hay mercados para mostrar (ninguna pieza tiene países de interés cargados). | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DROP TABLE IF EXISTS #Mercados;
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Matriz prime time): ' + @MensajeErrores;
        THROW 50715, @ErrorThrow, 1;
    END

    DECLARE @Columnas NVARCHAR(MAX) = (
        SELECT STRING_AGG(CAST(QUOTENAME(Nombre) AS NVARCHAR(MAX)), ', ') WITHIN GROUP (ORDER BY OffsetUTC, Nombre)
        FROM #Mercados
    );

    DECLARE @Sql NVARCHAR(MAX) = N'
    SELECT IdPartido, Fecha, Fase, HoraUTC, Partido, ' + @Columnas + N', MercadosEnPrimeTime
    FROM (
        SELECT p.IdPartido,
               p.Fecha,
               p.Fase,
               CONVERT(VARCHAR(5), p.HoraUTC, 108) AS HoraUTC,
               CONCAT(pl.Nombre, '' vs '', pv.Nombre) AS Partido,
               m.Nombre AS Mercado,
               CASE WHEN op.fn_EsPrimeTime(p.HoraUTC, m.OffsetUTC) = 1 THEN ''Sí'' ELSE ''-'' END AS EnPrimeTime,
               SUM(CAST(op.fn_EsPrimeTime(p.HoraUTC, m.OffsetUTC) AS INT)) OVER (PARTITION BY p.IdPartido) AS MercadosEnPrimeTime
        FROM op.Partido p
        INNER JOIN op.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
        INNER JOIN op.Pais pl ON pl.IdPais = sl.IdPais
        INNER JOIN op.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
        INNER JOIN op.Pais pv ON pv.IdPais = sv.IdPais
        CROSS JOIN #Mercados m
        WHERE (@IdPartido IS NULL OR p.IdPartido = @IdPartido)
          AND (@Fase IS NULL OR p.Fase = @Fase)
    ) AS Origen
    PIVOT (MAX(EnPrimeTime) FOR Mercado IN (' + @Columnas + N')) AS Matriz
    ORDER BY Fecha, HoraUTC, IdPartido;';

    EXEC sp_executesql @Sql, N'@IdPartido INT, @Fase VARCHAR(50)', @IdPartido = @IdPartido, @Fase = @Fase;
    DROP TABLE IF EXISTS #Mercados;
END;
GO

-- =========================================================================
-- 6. SELECCIONES Y PLANTILLAS (XML con vector anidado de convocados)
-- =========================================================================
CREATE OR ALTER PROCEDURE rpt.usp_SeleccionesPlantillas
    @IdSeleccion INT = NULL,
    @IncluirBajas BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @MensajeErrores += 'La selección no existe. | ';
    IF @IncluirBajas IS NULL
        SET @MensajeErrores += 'El parámetro IncluirBajas es obligatorio. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Selecciones y plantillas): ' + @MensajeErrores;
        THROW 50716, @ErrorThrow, 1;
    END

    SELECT c.IdSeleccion, c.IdJugador,
           CASE WHEN a.IdConvocado IS NULL THEN 'Baja' ELSE 'Activo' END AS Estado
    INTO #Convocados
    FROM op.Convocado c
    LEFT JOIN op.vw_ConvocadoActivo a ON a.IdConvocado = c.IdConvocado
    WHERE @IncluirBajas = 1 OR a.IdConvocado IS NOT NULL;

    DECLARE @Xml XML = (
        SELECT pa.Nombre AS '@pais',
               s.Grupo AS '@grupo',
               cf.Nombre AS '@confederacion',
               (SELECT COUNT(*) FROM #Convocados cv WHERE cv.IdSeleccion = s.IdSeleccion AND cv.Estado = 'Activo') AS '@cantidadConvocados',
               (SELECT ct.Tipo AS '@rol', ct.Nombre AS 'text()'
                FROM op.CuerpoTecnico ct
                WHERE ct.IdSeleccion = s.IdSeleccion
                ORDER BY CASE ct.Tipo WHEN 'DT' THEN 0 ELSE 1 END, ct.Nombre
                FOR XML PATH('Integrante'), TYPE) AS 'CuerpoTecnico',
               (SELECT j.Dorsal AS '@dorsal',
                       j.PosicionHabitual AS '@posicion',
                       cl.Nombre AS '@club',
                       cv.Estado AS '@estado',
                       j.Nombre AS 'Nombre',
                       j.Apellido AS 'Apellido',
                       CONVERT(VARCHAR(10), j.FechaNacimiento, 23) AS 'FechaNacimiento'
                FROM #Convocados cv
                INNER JOIN op.Jugador j ON j.IdJugador = cv.IdJugador
                LEFT JOIN op.Club cl ON cl.IdClub = j.IdClub
                WHERE cv.IdSeleccion = s.IdSeleccion
                ORDER BY j.Dorsal, j.Apellido
                FOR XML PATH('Jugador'), TYPE) AS 'Convocados'
        FROM op.Seleccion s
        INNER JOIN op.Pais pa ON pa.IdPais = s.IdPais
        INNER JOIN cfg.Confederacion cf ON cf.IdConfederacion = s.IdConfederacion
        WHERE @IdSeleccion IS NULL OR s.IdSeleccion = @IdSeleccion
        ORDER BY s.Grupo, pa.Nombre
        FOR XML PATH('Seleccion'), ROOT('Selecciones'), TYPE
    );

    SELECT @Xml AS ReporteSeleccionesPlantillas;
    DROP TABLE IF EXISTS #Convocados;
END;
GO

-- =========================================================================
-- 7. RESULTADOS DE LOS ENCUENTROS (TABLA + Posiciones, o XML con goles)
-- =========================================================================
CREATE OR ALTER PROCEDURE rpt.usp_Resultados
    @Fase VARCHAR(50) = NULL,
    @IdSeleccion INT = NULL,
    @Formato VARCHAR(5) = 'TABLA'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MensajeErrores NVARCHAR(MAX) = '';

    IF @Fase IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE Fase = @Fase)
        SET @MensajeErrores += 'No hay partidos de la fase indicada. | ';
    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion)
        SET @MensajeErrores += 'La selección no existe. | ';
    IF @Formato IS NULL OR @Formato NOT IN ('TABLA', 'XML')
        SET @MensajeErrores += 'El formato debe ser TABLA o XML. | ';

    IF LEN(@MensajeErrores) > 0
    BEGIN
        DECLARE @ErrorThrow NVARCHAR(2048) = 'VALIDACIONES FALLIDAS (Resultados): ' + @MensajeErrores;
        THROW 50717, @ErrorThrow, 1;
    END

    SELECT r.IdPartido, r.Fecha, r.HoraLocal, r.Fase, CASE WHEN r.Fase = 'Grupos' THEN sl.Grupo END AS Grupo, s.NombreEstadio AS Sede, s.Ciudad,
           r.IdSeleccionLocal, pl.Nombre AS Local, r.GolesLocal,
           r.IdSeleccionVisitante, pv.Nombre AS Visitante, r.GolesVisitante,
           r.TuvoAlargue, r.PublicoAsistente, r.Jugado, r.IdSeleccionGanadora
    INTO #Partidos
    FROM op.vw_ResultadoPartido r
    INNER JOIN op.Sede s ON s.IdSede = r.IdSede
    INNER JOIN op.Seleccion sl ON sl.IdSeleccion = r.IdSeleccionLocal
    INNER JOIN op.Pais pl ON pl.IdPais = sl.IdPais
    INNER JOIN op.Seleccion sv ON sv.IdSeleccion = r.IdSeleccionVisitante
    INNER JOIN op.Pais pv ON pv.IdPais = sv.IdPais
    WHERE (@Fase IS NULL OR r.Fase = @Fase)
      AND (@IdSeleccion IS NULL OR @IdSeleccion IN (r.IdSeleccionLocal, r.IdSeleccionVisitante));

    SELECT a.IdPartido, a.Minuto, pe.Descripcion AS Periodo, tj.Descripcion AS Tipo,
           CONCAT(j.Nombre, ' ', j.Apellido) AS Autor, j.Apellido AS ApellidoAutor,
           CONCAT(ja.Nombre, ' ', ja.Apellido) AS Asistencia, a.IdJugadorAsistidor,
           CASE WHEN tj.Descripcion = 'En contra'
                THEN CASE WHEN pl.IdSeleccion = p.IdSeleccionLocal THEN p.Visitante ELSE p.Local END
                ELSE CASE WHEN pl.IdSeleccion = p.IdSeleccionLocal THEN p.Local ELSE p.Visitante END
           END AS AcreditadoA
    INTO #Goles
    FROM op.Anotacion a
    INNER JOIN #Partidos p ON p.IdPartido = a.IdPartido
    INNER JOIN op.Jugador j ON j.IdJugador = a.IdJugadorAnotador
    INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
    INNER JOIN cfg.Tipo_Jugada tj ON tj.IdTipoJugada = a.IdTipoJugada
    INNER JOIN cfg.Periodo pe ON pe.IdPeriodo = a.IdPeriodo
    LEFT JOIN op.Jugador ja ON ja.IdJugador = a.IdJugadorAsistidor;

    IF @Formato = 'XML'
    BEGIN
        DECLARE @Xml XML = (
            SELECT p.IdPartido AS '@id',
                   CONVERT(VARCHAR(10), p.Fecha, 23) AS '@fecha',
                   CONVERT(VARCHAR(5), p.HoraLocal, 108) AS '@horaLocal',
                   p.Fase AS '@fase',
                   p.Grupo AS '@grupo',
                   p.Sede AS '@sede',
                   CASE WHEN p.Jugado = 1 THEN 'Jugado' ELSE 'Pendiente' END AS '@estado',
                   CASE WHEN p.TuvoAlargue = 1 THEN 'Sí' END AS '@alargue',
                   p.PublicoAsistente AS '@publico',
                   p.Local AS 'Local/@nombre',
                   p.GolesLocal AS 'Local/@goles',
                   p.Visitante AS 'Visitante/@nombre',
                   p.GolesVisitante AS 'Visitante/@goles',
                   (SELECT g.Minuto AS '@minuto', g.Periodo AS '@periodo', g.Tipo AS '@tipo',
                           g.AcreditadoA AS '@seleccion', g.Autor AS '@autor',
                           CASE WHEN g.IdJugadorAsistidor IS NOT NULL THEN g.Asistencia END AS '@asistencia'
                    FROM #Goles g
                    WHERE g.IdPartido = p.IdPartido
                    ORDER BY g.Minuto
                    FOR XML PATH('Gol'), TYPE) AS 'Goles'
            FROM #Partidos p
            ORDER BY p.Fecha, p.HoraLocal, p.IdPartido
            FOR XML PATH('Partido'), ROOT('Resultados'), TYPE
        );
        SELECT @Xml AS ReporteResultados;
        DROP TABLE IF EXISTS #Goles;
        DROP TABLE IF EXISTS #Partidos;
        RETURN;
    END

    -- 1) Resultados
    SELECT p.Fecha,
           CONVERT(VARCHAR(5), p.HoraLocal, 108) AS HoraLocal,
           p.Fase,
           p.Grupo,
           p.Sede,
           p.Local,
           CASE WHEN p.Jugado = 1 THEN CONCAT(p.GolesLocal, ' - ', p.GolesVisitante,
                                              CASE WHEN p.TuvoAlargue = 1 THEN ' (alargue)' END)
                ELSE 'Pendiente' END AS Resultado,
           p.Visitante,
           CASE WHEN p.Jugado = 0 THEN NULL
                WHEN p.IdSeleccionGanadora IS NULL THEN 'Empate'
                WHEN p.IdSeleccionGanadora = p.IdSeleccionLocal THEN p.Local
                ELSE p.Visitante END AS Ganador,
           (SELECT STRING_AGG(CONCAT(g.ApellidoAutor, ' ', g.Minuto, '''',
                                     CASE WHEN g.Tipo = 'En contra' THEN ' (e.c.)' WHEN g.Tipo = 'Penal' THEN ' (p)' END), ', ')
                   WITHIN GROUP (ORDER BY g.Minuto)
            FROM #Goles g WHERE g.IdPartido = p.IdPartido) AS Goles,
           p.PublicoAsistente
    FROM #Partidos p
    ORDER BY p.Fecha, p.HoraLocal, p.IdPartido;

    -- 2) Tabla de posiciones (sólo si incluye fase de grupos)
    IF @Fase IS NULL OR @Fase = 'Grupos'
        SELECT t.Grupo, t.Posicion, t.Seleccion, t.PJ, t.PG, t.PE, t.PP, t.GF, t.GC, t.DG, t.Pts
        FROM op.vw_TablaPosiciones t
        WHERE @IdSeleccion IS NULL
           OR t.Grupo = (SELECT Grupo FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion)
        ORDER BY t.Grupo, t.Posicion;

    DROP TABLE IF EXISTS #Goles;
    DROP TABLE IF EXISTS #Partidos;
END;
GO
