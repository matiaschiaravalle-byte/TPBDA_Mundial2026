/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli, Agustín Nicolás Mussi Pulcini
   Explicación: SPs de Reportes.
          Contiene:
             1. rpt.usp_Goleadores              (por torneo, selección o fase)
             2. rpt.usp_Tarjetas                (por selección, jugador y suspensiones)
             3. rpt.usp_DesignacionesArbitrales (XML: partidos, tarjetas e informes)
             4. rpt.usp_OcupacionPublicitaria   (por partido y sede, con moneda)
             5. rpt.usp_MatrizPrimeTime         (PIVOT dinámico partido x mercado)
             6. rpt.usp_SeleccionesPlantillas   (XML: selecciones y convocados)
             7. rpt.usp_Resultados              (TABLA + posiciones, o XML)
========================================================================= */

USE Mundial2026;
GO

IF SCHEMA_ID('rpt') IS NULL EXEC('CREATE SCHEMA rpt');
GO


--GOLEADORES por torneo, selección o fase
CREATE OR ALTER PROCEDURE rpt.usp_Goleadores
    @Agrupacion VARCHAR(10) = 'Torneo',
    @IdSeleccion INT = NULL,
    @Fase VARCHAR(50) = NULL,
    @Top INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF @Agrupacion IS NULL OR @Agrupacion NOT IN ('Torneo', 'Seleccion', 'Fase') SET @Err += 'La agrupación debe ser Torneo, Seleccion o Fase. | ';
    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion) SET @Err += 'La selección no existe. | ';
    IF @Fase IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE Fase = @Fase) SET @Err += 'No hay partidos de la fase indicada. | ';
    IF @Top IS NOT NULL AND @Top <= 0 SET @Err += 'El Top debe ser mayor a cero. | ';
    IF LEN(@Err) > 0 BEGIN SET @Err = 'VALIDACIONES FALLIDAS (Goleadores): ' + @Err; THROW 50711, @Err, 1; END

    ;WITH Ranking AS (
        SELECT CASE @Agrupacion WHEN 'Seleccion' THEN pa.Nombre WHEN 'Fase' THEN p.Fase ELSE 'Torneo' END AS Agrupacion,
               j.IdJugador,
               CONCAT(j.Nombre, ' ', j.Apellido) AS Jugador,
               pa.Nombre AS Seleccion,
               j.PosicionHabitual AS Posicion,
               COUNT(*) AS Goles,
               SUM(CASE WHEN tj.Descripcion = 'Penal' THEN 1 ELSE 0 END) AS DePenal,
               COUNT(DISTINCT a.IdPartido) AS PartidosConGol,
               DENSE_RANK() OVER (
                   PARTITION BY CASE @Agrupacion WHEN 'Seleccion' THEN pa.Nombre WHEN 'Fase' THEN p.Fase ELSE 'Torneo' END
                   ORDER BY COUNT(*) DESC
               ) AS Puesto
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
        GROUP BY CASE @Agrupacion WHEN 'Seleccion' THEN pa.Nombre WHEN 'Fase' THEN p.Fase ELSE 'Torneo' END,
                 j.IdJugador, j.Nombre, j.Apellido, pa.Nombre, j.PosicionHabitual
    ),
    Asist AS (
        SELECT a.IdJugadorAsistidor AS IdJugador, COUNT(*) AS Asistencias
        FROM op.Anotacion a
        INNER JOIN op.Partido p ON p.IdPartido = a.IdPartido
        WHERE a.IdJugadorAsistidor IS NOT NULL AND (@Fase IS NULL OR p.Fase = @Fase)
        GROUP BY a.IdJugadorAsistidor
    )
    SELECT r.Agrupacion, r.Puesto, r.Jugador, r.Seleccion, r.Posicion,
           r.Goles, r.DePenal, r.PartidosConGol, ISNULL(a.Asistencias, 0) AS Asistencias
    FROM Ranking r
    LEFT JOIN Asist a ON a.IdJugador = r.IdJugador
    WHERE @Top IS NULL OR r.Puesto <= @Top
    ORDER BY r.Agrupacion, r.Puesto, r.Jugador;
END;
GO


--TARJETAS por selección y jugador + suspensiones activas por acumulación
CREATE OR ALTER PROCEDURE rpt.usp_Tarjetas
    @IdSeleccion INT = NULL,
    @IdJugador INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion) SET @Err += 'La selección no existe. | ';
    IF @IdJugador IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Jugador WHERE IdJugador = @IdJugador) SET @Err += 'El jugador no existe. | ';
    IF @IdSeleccion IS NOT NULL AND @IdJugador IS NOT NULL
       AND EXISTS (SELECT 1 FROM op.Jugador j INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel WHERE j.IdJugador = @IdJugador AND pl.IdSeleccion <> @IdSeleccion)
        SET @Err += 'El jugador no pertenece a la selección indicada. | ';
    IF LEN(@Err) > 0 BEGIN SET @Err = 'VALIDACIONES FALLIDAS (Tarjetas): ' + @Err; THROW 50712, @Err, 1; END

    SELECT t.IdPartido, t.IdJugador, CONCAT(j.Nombre, ' ', j.Apellido) AS Jugador, j.Dorsal,
           tt.Descripcion AS Tipo, pl.IdSeleccion, pa.Nombre AS Seleccion
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
    SELECT Seleccion,
           SUM(CASE WHEN Tipo = 'Amarilla' THEN 1 ELSE 0 END) AS Amarillas,
           SUM(CASE WHEN Tipo = 'Doble Amarilla' THEN 1 ELSE 0 END) AS ExpulsionesDobleAmarilla,
           SUM(CASE WHEN Tipo = 'Roja Directa' THEN 1 ELSE 0 END) AS RojasDirectas,
           COUNT(*) AS TotalTarjetas
    FROM #Tarjetas
    GROUP BY IdSeleccion, Seleccion
    ORDER BY TotalTarjetas DESC, Seleccion;

    -- 2) Detalle por jugador con su suspensión activa (si tiene)
    SELECT t.Seleccion, t.Jugador, t.Dorsal,
           SUM(CASE WHEN t.Tipo = 'Amarilla' THEN 1 ELSE 0 END) AS Amarillas,
           SUM(CASE WHEN t.Tipo = 'Doble Amarilla' THEN 1 ELSE 0 END) AS ExpulsionesDobleAmarilla,
           SUM(CASE WHEN t.Tipo = 'Roja Directa' THEN 1 ELSE 0 END) AS RojasDirectas,
           CASE WHEN su.IdSuspension IS NOT NULL THEN 'Sí' ELSE 'No' END AS SuspendidoActualmente,
           su.Motivo AS MotivoSuspension,
           su.PartidosRestantes
    FROM #Tarjetas t
    LEFT JOIN op.Suspension su ON su.IdJugador = t.IdJugador AND su.Activa = 1
    GROUP BY t.Seleccion, t.IdJugador, t.Jugador, t.Dorsal, su.IdSuspension, su.Motivo, su.PartidosRestantes
    ORDER BY t.Seleccion, t.Jugador;

    -- 3) Suspensiones activas por acumulación de amarillas
    SELECT pa.Nombre AS Seleccion, CONCAT(j.Nombre, ' ', j.Apellido) AS Jugador, j.Dorsal,
           su.PartidosRestantes, po.Fecha AS FechaPartidoOrigen, su.Motivo
    FROM op.Suspension su
    INNER JOIN op.Jugador j ON j.IdJugador = su.IdJugador
    INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
    INNER JOIN op.Seleccion s ON s.IdSeleccion = pl.IdSeleccion
    INNER JOIN op.Pais pa ON pa.IdPais = s.IdPais
    INNER JOIN op.Partido po ON po.IdPartido = su.IdPartidoOrigen
    WHERE su.Activa = 1 AND su.Motivo = 'Acumulación de amarillas'
      AND (@IdSeleccion IS NULL OR pl.IdSeleccion = @IdSeleccion)
      AND (@IdJugador IS NULL OR su.IdJugador = @IdJugador)
    ORDER BY pa.Nombre, Jugador;

    DROP TABLE IF EXISTS #Tarjetas;
END;
GO


--DESIGNACIONES ARBITRALES (XML)
CREATE OR ALTER PROCEDURE rpt.usp_DesignacionesArbitrales
    @IdArbitro INT = NULL,
    @SoloConDesignaciones BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF @IdArbitro IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Arbitro WHERE IdArbitro = @IdArbitro) SET @Err += 'El árbitro no existe. | ';
    IF @SoloConDesignaciones IS NULL SET @Err += 'El parámetro SoloConDesignaciones es obligatorio. | ';
    IF LEN(@Err) > 0 BEGIN SET @Err = 'VALIDACIONES FALLIDAS (Designaciones arbitrales): ' + @Err; THROW 50713, @Err, 1; END

    SELECT la.IdPartido, r.Rol, r.IdArbitro
    INTO #Designaciones
    FROM op.Lista_Arbitros la
    CROSS APPLY (VALUES ('Principal', la.IdArbitroPrincipal), ('Asistente 1', la.IdArbitroAsistente1),
                        ('Asistente 2', la.IdArbitroAsistente2), ('Cuarto árbitro', la.IdCuartoArbitro),
                        ('VAR', la.IdArbitroVAR)) r(Rol, IdArbitro);

    SELECT (
        SELECT a.IdArbitro AS '@id',
               CONCAT(a.Nombre, ' ', a.Apellido) AS '@nombre',
               a.Nacionalidad AS '@nacionalidad',
               a.Categoria AS '@categoria',
               (SELECT p.IdPartido AS '@id',
                       CONVERT(VARCHAR(10), p.Fecha, 23) AS '@fecha',
                       p.Fase AS '@fase',
                       d.Rol AS '@rol',
                       pl.Nombre AS '@local',
                       pv.Nombre AS '@visitante',
                       CONCAT(r.GolesLocal, ' - ', r.GolesVisitante) AS '@resultado',
                       (SELECT t.Minuto AS '@minuto', tt.Descripcion AS '@tipo', CONCAT(j.Nombre, ' ', j.Apellido) AS '@jugador', t.Motivo AS '@motivo'
                        FROM op.Tarjeta t
                        INNER JOIN cfg.Tipo_Tarjeta tt ON tt.IdTipoTarjeta = t.IdTipoTarjeta
                        INNER JOIN op.Jugador j ON j.IdJugador = t.IdJugador
                        WHERE t.IdPartido = p.IdPartido AND d.Rol = 'Principal'
                        ORDER BY t.Minuto
                        FOR XML PATH('Tarjeta'), TYPE) AS 'TarjetasSenaladas',
                       (SELECT i.Tipo AS '@tipo', i.Descripcion AS 'text()'
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
                ORDER BY p.Fecha
                FOR XML PATH('Partido'), TYPE) AS 'Partidos'
        FROM op.Arbitro a
        WHERE (@IdArbitro IS NULL OR a.IdArbitro = @IdArbitro)
          AND (@SoloConDesignaciones = 0 OR EXISTS (SELECT 1 FROM #Designaciones d WHERE d.IdArbitro = a.IdArbitro))
        ORDER BY a.Apellido, a.Nombre
        FOR XML PATH('Arbitro'), ROOT('DesignacionesArbitrales'), TYPE
    ) AS ReporteDesignacionesArbitrales;

    DROP TABLE IF EXISTS #Designaciones;
END;
GO


--OCUPACIÓN PUBLICITARIA por sede y partido (con conversión de moneda)
CREATE OR ALTER PROCEDURE rpt.usp_OcupacionPublicitaria
    @IdSede INT = NULL,
    @IdPartido INT = NULL,
    @Moneda VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '', @Factor DECIMAL(18,4) = 1;
    IF @Moneda IS NOT NULL SELECT @Factor = ValorEnARS FROM cfg.Cotizacion_Moneda WHERE CodigoMoneda = UPPER(@Moneda);

    IF @IdSede IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Sede WHERE IdSede = @IdSede) SET @Err += 'La sede no existe. | ';
    IF @IdPartido IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido) SET @Err += 'El partido no existe. | ';
    IF @IdSede IS NOT NULL AND @IdPartido IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido AND IdSede = @IdSede)
        SET @Err += 'El partido no se juega en la sede indicada. | ';
    IF @Moneda IS NOT NULL AND NOT EXISTS (SELECT 1 FROM cfg.Cotizacion_Moneda WHERE CodigoMoneda = UPPER(@Moneda))
        SET @Err += 'La moneda no tiene cotización en cfg.Cotizacion_Moneda. | ';
    IF LEN(@Err) > 0 BEGIN SET @Err = 'VALIDACIONES FALLIDAS (Ocupación publicitaria): ' + @Err; THROW 50714, @Err, 1; END

    SELECT p.IdPartido, p.IdSede, s.NombreEstadio AS Sede, s.Ciudad, p.Fecha, p.Fase,
           CONCAT(pl.Nombre, ' vs ', pv.Nombre) AS Partido,
           e.Motivo AS Espacio, an.RazonSocial AS Anunciante, x.IdEspacio, x.Tarifa
    INTO #Detalle
    FROM op.Partido p
    INNER JOIN op.Sede s ON s.IdSede = p.IdSede
    INNER JOIN op.Seleccion sl ON sl.IdSeleccion = p.IdSeleccionLocal
    INNER JOIN op.Pais pl ON pl.IdPais = sl.IdPais
    INNER JOIN op.Seleccion sv ON sv.IdSeleccion = p.IdSeleccionVisitante
    INNER JOIN op.Pais pv ON pv.IdPais = sv.IdPais
    LEFT JOIN op.Exhibicion x ON x.IdPartido = p.IdPartido
    LEFT JOIN op.EspacioPublicitario e ON e.IdEspacio = x.IdEspacio
    LEFT JOIN cfg.Pieza_Contenido pc ON pc.IdPieza = x.IdPieza
    LEFT JOIN cfg.Campania c ON c.IdCampania = pc.IdCampania
    LEFT JOIN cfg.Anunciante an ON an.IdAnunciante = c.IdAnunciante
    WHERE (@IdSede IS NULL OR p.IdSede = @IdSede)
      AND (@IdPartido IS NULL OR p.IdPartido = @IdPartido);

    -- 1) Detalle por partido y espacio
    SELECT Sede, Fecha, Partido, Espacio, Anunciante, Tarifa AS TarifaARS,
           CASE WHEN @Moneda IS NULL THEN NULL ELSE CAST(ROUND(Tarifa / @Factor, 2) AS DECIMAL(18,2)) END AS TarifaEnMoneda,
           UPPER(@Moneda) AS Moneda
    FROM #Detalle
    WHERE IdEspacio IS NOT NULL
    ORDER BY Sede, Fecha, IdPartido, IdEspacio;

    -- 2) Resumen por partido
    SELECT Sede, IdPartido, Fecha, Fase, Partido,
           COUNT(DISTINCT IdEspacio) AS EspaciosOcupados,
           CAST(COUNT(DISTINCT IdEspacio) * 25.0 AS DECIMAL(5,1)) AS PorcentajeOcupacion,
           ISNULL(SUM(Tarifa), 0) AS IngresosARS,
           CASE WHEN @Moneda IS NULL THEN NULL ELSE CAST(ROUND(ISNULL(SUM(Tarifa), 0) / @Factor, 2) AS DECIMAL(18,2)) END AS IngresosEnMoneda
    FROM #Detalle
    GROUP BY Sede, IdPartido, Fecha, Fase, Partido
    ORDER BY Sede, Fecha, IdPartido;

    -- 3) Resumen por sede
    SELECT Sede, Ciudad,
           COUNT(DISTINCT IdPartido) AS Partidos,
           COUNT(IdEspacio) AS TotalExhibiciones,
           ISNULL(SUM(Tarifa), 0) AS IngresosARS,
           CASE WHEN @Moneda IS NULL THEN NULL ELSE CAST(ROUND(ISNULL(SUM(Tarifa), 0) / @Factor, 2) AS DECIMAL(18,2)) END AS IngresosEnMoneda
    FROM #Detalle
    GROUP BY IdSede, Sede, Ciudad
    ORDER BY IngresosARS DESC;

    DROP TABLE IF EXISTS #Detalle;
END;
GO


--MATRIZ DE PRIME TIME (PIVOT dinámico partido x mercados)
CREATE OR ALTER PROCEDURE rpt.usp_MatrizPrimeTime
    @IdPartido INT = NULL,
    @Fase VARCHAR(50) = NULL,
    @SoloMercadosPublicitarios BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF @IdPartido IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE IdPartido = @IdPartido) SET @Err += 'El partido no existe. | ';
    IF @Fase IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE Fase = @Fase) SET @Err += 'No hay partidos de la fase indicada. | ';
    IF @SoloMercadosPublicitarios IS NULL SET @Err += 'El parámetro SoloMercadosPublicitarios es obligatorio. | ';

    SELECT pa.IdPais, pa.Nombre, pa.OffsetUTC
    INTO #Mercados
    FROM op.Pais pa
    WHERE @SoloMercadosPublicitarios = 0 OR EXISTS (SELECT 1 FROM cfg.Pieza_Pais pp WHERE pp.IdPais = pa.IdPais);

    IF @SoloMercadosPublicitarios IS NOT NULL AND NOT EXISTS (SELECT 1 FROM #Mercados)
        SET @Err += 'No hay mercados para mostrar. | ';
    IF LEN(@Err) > 0 BEGIN DROP TABLE IF EXISTS #Mercados; SET @Err = 'VALIDACIONES FALLIDAS (Matriz prime time): ' + @Err; THROW 50715, @Err, 1; END

    DECLARE @Cols NVARCHAR(MAX) = (
        SELECT STRING_AGG(CAST(QUOTENAME(Nombre) AS NVARCHAR(MAX)), ', ') WITHIN GROUP (ORDER BY OffsetUTC, Nombre)
        FROM #Mercados
    );

    DECLARE @Sql NVARCHAR(MAX) = N'
    SELECT IdPartido, Fecha, Fase, HoraUTC, Partido, ' + @Cols + N', MercadosEnPrimeTime
    FROM (
        SELECT p.IdPartido, p.Fecha, p.Fase, CONVERT(VARCHAR(5), p.HoraUTC, 108) AS HoraUTC,
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
        WHERE (@IdPartido IS NULL OR p.IdPartido = @IdPartido) AND (@Fase IS NULL OR p.Fase = @Fase)
    ) AS Origen
    PIVOT (MAX(EnPrimeTime) FOR Mercado IN (' + @Cols + N')) AS Matriz
    ORDER BY Fecha, HoraUTC, IdPartido;';

    EXEC sp_executesql @Sql, N'@IdPartido INT, @Fase VARCHAR(50)', @IdPartido = @IdPartido, @Fase = @Fase;
    DROP TABLE IF EXISTS #Mercados;
END;
GO


--SELECCIONES Y PLANTILLAS (XML con vector anidado de convocados)
CREATE OR ALTER PROCEDURE rpt.usp_SeleccionesPlantillas
    @IdSeleccion INT = NULL,
    @IncluirBajas BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion) SET @Err += 'La selección no existe. | ';
    IF @IncluirBajas IS NULL SET @Err += 'El parámetro IncluirBajas es obligatorio. | ';
    IF LEN(@Err) > 0 BEGIN SET @Err = 'VALIDACIONES FALLIDAS (Selecciones y plantillas): ' + @Err; THROW 50716, @Err, 1; END

    SELECT (
        SELECT pa.Nombre AS '@pais',
               s.Grupo AS '@grupo',
               cf.Nombre AS '@confederacion',
               (SELECT ct.Tipo AS '@rol', ct.Nombre AS 'text()'
                FROM op.CuerpoTecnico ct WHERE ct.IdSeleccion = s.IdSeleccion
                ORDER BY ct.Tipo DESC FOR XML PATH('Integrante'), TYPE) AS 'CuerpoTecnico',
               (SELECT j.Dorsal AS '@dorsal',
                       j.PosicionHabitual AS '@posicion',
                       cl.Nombre AS '@club',
                       CASE WHEN a.IdConvocado IS NULL THEN 'Baja' ELSE 'Activo' END AS '@estado',
                       j.Nombre AS 'Nombre',
                       j.Apellido AS 'Apellido'
                FROM op.Convocado c
                INNER JOIN op.Jugador j ON j.IdJugador = c.IdJugador
                LEFT JOIN op.Club cl ON cl.IdClub = j.IdClub
                LEFT JOIN op.vw_ConvocadoActivo a ON a.IdConvocado = c.IdConvocado
                WHERE c.IdSeleccion = s.IdSeleccion AND (@IncluirBajas = 1 OR a.IdConvocado IS NOT NULL)
                ORDER BY j.Dorsal, j.Apellido
                FOR XML PATH('Jugador'), TYPE) AS 'Convocados'
        FROM op.Seleccion s
        INNER JOIN op.Pais pa ON pa.IdPais = s.IdPais
        INNER JOIN cfg.Confederacion cf ON cf.IdConfederacion = s.IdConfederacion
        WHERE @IdSeleccion IS NULL OR s.IdSeleccion = @IdSeleccion
        ORDER BY s.Grupo, pa.Nombre
        FOR XML PATH('Seleccion'), ROOT('Selecciones'), TYPE
    ) AS ReporteSeleccionesPlantillas;
END;
GO


--RESULTADOS DE LOS ENCUENTROS (TABLA + Posiciones, o XML)
CREATE OR ALTER PROCEDURE rpt.usp_Resultados
    @Fase VARCHAR(50) = NULL,
    @IdSeleccion INT = NULL,
    @Formato VARCHAR(5) = 'TABLA'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Err NVARCHAR(MAX) = '';
    IF @Fase IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Partido WHERE Fase = @Fase) SET @Err += 'No hay partidos de la fase indicada. | ';
    IF @IdSeleccion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion) SET @Err += 'La selección no existe. | ';
    IF @Formato IS NULL OR @Formato NOT IN ('TABLA', 'XML') SET @Err += 'El formato debe ser TABLA o XML. | ';
    IF LEN(@Err) > 0 BEGIN SET @Err = 'VALIDACIONES FALLIDAS (Resultados): ' + @Err; THROW 50717, @Err, 1; END

    SELECT r.IdPartido, r.Fecha, CONVERT(VARCHAR(5), r.HoraLocal, 108) AS HoraLocal, r.Fase,
           CASE WHEN r.Fase = 'Grupos' THEN sl.Grupo END AS Grupo, s.NombreEstadio AS Sede,
           pl.Nombre AS Local, r.GolesLocal, pv.Nombre AS Visitante, r.GolesVisitante,
           r.TuvoAlargue, r.PublicoAsistente, r.Jugado,
           CASE WHEN r.Jugado = 0 THEN NULL
                WHEN r.IdSeleccionGanadora IS NULL THEN 'Empate'
                WHEN r.IdSeleccionGanadora = r.IdSeleccionLocal THEN pl.Nombre
                ELSE pv.Nombre END AS Ganador
    INTO #Partidos
    FROM op.vw_ResultadoPartido r
    INNER JOIN op.Sede s ON s.IdSede = r.IdSede
    INNER JOIN op.Seleccion sl ON sl.IdSeleccion = r.IdSeleccionLocal
    INNER JOIN op.Pais pl ON pl.IdPais = sl.IdPais
    INNER JOIN op.Seleccion sv ON sv.IdSeleccion = r.IdSeleccionVisitante
    INNER JOIN op.Pais pv ON pv.IdPais = sv.IdPais
    WHERE (@Fase IS NULL OR r.Fase = @Fase)
      AND (@IdSeleccion IS NULL OR @IdSeleccion IN (r.IdSeleccionLocal, r.IdSeleccionVisitante));

    IF @Formato = 'XML'
    BEGIN
        SELECT (
            SELECT p.IdPartido AS '@id', CONVERT(VARCHAR(10), p.Fecha, 23) AS '@fecha', p.Fase AS '@fase', p.Sede AS '@sede',
                   p.Local AS 'Local/@nombre', p.GolesLocal AS 'Local/@goles',
                   p.Visitante AS 'Visitante/@nombre', p.GolesVisitante AS 'Visitante/@goles',
                   (SELECT a.Minuto AS '@minuto', tj.Descripcion AS '@tipo', CONCAT(j.Nombre, ' ', j.Apellido) AS '@autor'
                    FROM op.Anotacion a
                    INNER JOIN op.Jugador j ON j.IdJugador = a.IdJugadorAnotador
                    INNER JOIN cfg.Tipo_Jugada tj ON tj.IdTipoJugada = a.IdTipoJugada
                    WHERE a.IdPartido = p.IdPartido
                    ORDER BY a.Minuto
                    FOR XML PATH('Gol'), TYPE) AS 'Goles'
            FROM #Partidos p
            ORDER BY p.Fecha, p.HoraLocal, p.IdPartido
            FOR XML PATH('Partido'), ROOT('Resultados'), TYPE
        ) AS ReporteResultados;
        DROP TABLE IF EXISTS #Partidos;
        RETURN;
    END

    -- 1) Resultados
    SELECT Fecha, HoraLocal, Fase, Grupo, Sede, Local,
           CASE WHEN Jugado = 1 THEN CONCAT(GolesLocal, ' - ', GolesVisitante, CASE WHEN TuvoAlargue = 1 THEN ' (alargue)' END) ELSE 'Pendiente' END AS Resultado,
           Visitante, Ganador, PublicoAsistente
    FROM #Partidos
    ORDER BY Fecha, HoraLocal, IdPartido;

    -- 2) Tabla de posiciones (sólo si incluye fase de grupos)
    IF @Fase IS NULL OR @Fase = 'Grupos'
        SELECT Grupo, Posicion, Seleccion, PJ, PG, PE, PP, GF, GC, DG, Pts
        FROM op.vw_TablaPosiciones
        WHERE @IdSeleccion IS NULL OR Grupo = (SELECT Grupo FROM op.Seleccion WHERE IdSeleccion = @IdSeleccion)
        ORDER BY Grupo, Posicion;

    DROP TABLE IF EXISTS #Partidos;
END;
GO
