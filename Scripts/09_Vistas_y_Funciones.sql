/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: ENTREGA 7 - Función y vistas de soporte para los reportes:
             - op.fn_EsPrimeTime: indica si una hora UTC cae en prime time (19-23 hs locales).
             - op.vw_ConvocadoActivo: convocados vigentes (sin baja de último momento).
             - op.vw_ResultadoPartido: marcador calculado desde op.Anotacion (incluye "En contra").
             - op.vw_TablaPosiciones: tabla de posiciones de la fase de grupos.
========================================================================= */

USE Mundial2026;
GO

-- 1. Función: Prime time (19 a 23 hs locales a partir de HoraUTC y OffsetUTC)
CREATE OR ALTER FUNCTION op.fn_EsPrimeTime (@HoraUTC TIME, @OffsetUTC INT)
RETURNS BIT
AS
BEGIN
    IF @HoraUTC IS NULL OR @OffsetUTC IS NULL
        RETURN 0;
    RETURN CASE WHEN (DATEPART(HOUR, @HoraUTC) + @OffsetUTC + 24) % 24 BETWEEN 19 AND 23 THEN 1 ELSE 0 END;
END;
GO

-- 2. Vista: Convocados vigentes (sin movimientos o cuyo último movimiento fue Alta)
CREATE OR ALTER VIEW op.vw_ConvocadoActivo
AS
SELECT c.IdConvocado, c.IdSeleccion, c.IdJugador
FROM op.Convocado c
OUTER APPLY (
    SELECT TOP (1) m.Tipo
    FROM op.Modificacion_Convocatoria m
    WHERE m.IdConvocado = c.IdConvocado
    ORDER BY m.Fecha DESC, m.IdModificacion DESC
) ult
WHERE ISNULL(ult.Tipo, 'Alta') = 'Alta';
GO

-- 3. Vista: Resultado de cada partido calculado desde op.Anotacion
--    Contempla goles "En contra" (suman para el rival) e indica si fue jugado y quién ganó.
CREATE OR ALTER VIEW op.vw_ResultadoPartido
AS
SELECT p.IdPartido,
       p.IdSede,
       p.Fecha,
       p.HoraLocal,
       p.HoraUTC,
       p.Fase,
       p.IdSeleccionLocal,
       p.IdSeleccionVisitante,
       ISNULL(g.GolesLocal, 0) AS GolesLocal,
       ISNULL(g.GolesVisitante, 0) AS GolesVisitante,
       p.TuvoAlargue,
       p.PublicoAsistente,
       CAST(CASE WHEN p.PublicoAsistente IS NOT NULL OR ISNULL(g.Total, 0) > 0 THEN 1 ELSE 0 END AS BIT) AS Jugado,
       CASE WHEN p.PublicoAsistente IS NULL AND ISNULL(g.Total, 0) = 0 THEN NULL
            WHEN ISNULL(g.GolesLocal, 0) > ISNULL(g.GolesVisitante, 0) THEN p.IdSeleccionLocal
            WHEN ISNULL(g.GolesVisitante, 0) > ISNULL(g.GolesLocal, 0) THEN p.IdSeleccionVisitante
       END AS IdSeleccionGanadora
FROM op.Partido p
LEFT JOIN (
    SELECT a.IdPartido,
           SUM(CASE WHEN (pl.IdSeleccion = p2.IdSeleccionLocal AND tj.Descripcion <> 'En contra')
                      OR (pl.IdSeleccion = p2.IdSeleccionVisitante AND tj.Descripcion = 'En contra') THEN 1 ELSE 0 END) AS GolesLocal,
           SUM(CASE WHEN (pl.IdSeleccion = p2.IdSeleccionVisitante AND tj.Descripcion <> 'En contra')
                      OR (pl.IdSeleccion = p2.IdSeleccionLocal AND tj.Descripcion = 'En contra') THEN 1 ELSE 0 END) AS GolesVisitante,
           COUNT(*) AS Total
    FROM op.Anotacion a
    INNER JOIN op.Partido p2 ON p2.IdPartido = a.IdPartido
    INNER JOIN op.Jugador j ON j.IdJugador = a.IdJugadorAnotador
    INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
    INNER JOIN cfg.Tipo_Jugada tj ON tj.IdTipoJugada = a.IdTipoJugada
    GROUP BY a.IdPartido
) g ON g.IdPartido = p.IdPartido;
GO

-- 4. Vista: Tabla de posiciones de la fase de grupos (sólo partidos jugados)
CREATE OR ALTER VIEW op.vw_TablaPosiciones
AS
WITH Lineas AS (
    SELECT r.IdSeleccionLocal AS IdSeleccion, r.GolesLocal AS GF, r.GolesVisitante AS GC
    FROM op.vw_ResultadoPartido r
    WHERE r.Fase = 'Grupos' AND r.Jugado = 1
    UNION ALL
    SELECT r.IdSeleccionVisitante, r.GolesVisitante, r.GolesLocal
    FROM op.vw_ResultadoPartido r
    WHERE r.Fase = 'Grupos' AND r.Jugado = 1
),
Totales AS (
    SELECT s.IdSeleccion,
           s.Grupo,
           pa.Nombre AS Seleccion,
           COUNT(l.IdSeleccion) AS PJ,
           SUM(CASE WHEN l.GF > l.GC THEN 1 ELSE 0 END) AS PG,
           SUM(CASE WHEN l.GF = l.GC THEN 1 ELSE 0 END) AS PE,
           SUM(CASE WHEN l.GF < l.GC THEN 1 ELSE 0 END) AS PP,
           ISNULL(SUM(l.GF), 0) AS GF,
           ISNULL(SUM(l.GC), 0) AS GC
    FROM op.Seleccion s
    INNER JOIN op.Pais pa ON pa.IdPais = s.IdPais
    LEFT JOIN Lineas l ON l.IdSeleccion = s.IdSeleccion
    WHERE s.Grupo IS NOT NULL
    GROUP BY s.IdSeleccion, s.Grupo, pa.Nombre
)
SELECT Grupo,
       ROW_NUMBER() OVER (PARTITION BY Grupo ORDER BY PG * 3 + PE DESC, GF - GC DESC, GF DESC, Seleccion) AS Posicion,
       IdSeleccion,
       Seleccion,
       PJ, PG, PE, PP, GF, GC,
       GF - GC AS DG,
       PG * 3 + PE AS Pts
FROM Totales;
GO
