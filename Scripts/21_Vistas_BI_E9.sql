/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: ENTREGA 9 - Vistas planas de soporte para conectar Metabase (BI)
             y armar gráficos directos sobre los reportes de la Entrega 7:
             1. rpt.vw_BI_Goleadores
             2. rpt.vw_BI_IngresosPublicidad_Sede
             3. rpt.vw_BI_Tarjetas_Seleccion
             Ejecutar después de 01 a 14 (o 20).
========================================================================= */

USE Mundial2026;
GO

-- 1. Goleadores del torneo (sin goles en contra) -> ideal para Gráfico de Barras
CREATE OR ALTER VIEW rpt.vw_BI_Goleadores
AS
SELECT CONCAT(j.Nombre, ' ', j.Apellido) AS Jugador,
       pa.Nombre AS Seleccion,
       COUNT(*) AS Goles,
       SUM(CASE WHEN tj.Descripcion = 'Penal' THEN 1 ELSE 0 END) AS GolesPenal
FROM op.Anotacion a
INNER JOIN cfg.Tipo_Jugada tj ON tj.IdTipoJugada = a.IdTipoJugada
INNER JOIN op.Jugador j ON j.IdJugador = a.IdJugadorAnotador
INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
INNER JOIN op.Seleccion s ON s.IdSeleccion = pl.IdSeleccion
INNER JOIN op.Pais pa ON pa.IdPais = s.IdPais
WHERE tj.Descripcion <> 'En contra'
GROUP BY j.IdJugador, j.Nombre, j.Apellido, pa.Nombre;
GO

-- 2. Ingresos y ocupación publicitaria por sede (ARS y USD) -> ideal para Gráfico de Torta / Barras
CREATE OR ALTER VIEW rpt.vw_BI_IngresosPublicidad_Sede
AS
SELECT s.NombreEstadio AS Sede,
       s.Ciudad,
       COUNT(DISTINCT p.IdPartido) AS Partidos,
       COUNT(x.IdExhibicion) AS Exhibiciones,
       ISNULL(SUM(x.Tarifa), 0) AS IngresosARS,
       CAST(ROUND(ISNULL(SUM(x.Tarifa), 0) / NULLIF((SELECT ValorEnARS FROM cfg.Cotizacion_Moneda WHERE CodigoMoneda = 'USD'), 0), 2) AS DECIMAL(18,2)) AS IngresosUSD
FROM op.Sede s
INNER JOIN op.Partido p ON p.IdSede = s.IdSede
LEFT JOIN op.Exhibicion x ON x.IdPartido = p.IdPartido
GROUP BY s.IdSede, s.NombreEstadio, s.Ciudad;
GO

-- 3. Tarjetas por selección -> ideal para Gráfico de Barras Apiladas
CREATE OR ALTER VIEW rpt.vw_BI_Tarjetas_Seleccion
AS
SELECT pa.Nombre AS Seleccion,
       SUM(CASE WHEN tt.Descripcion = 'Amarilla' THEN 1 ELSE 0 END) AS Amarillas,
       SUM(CASE WHEN tt.Descripcion = 'Doble Amarilla' THEN 1 ELSE 0 END) AS DobleAmarilla,
       SUM(CASE WHEN tt.Descripcion = 'Roja Directa' THEN 1 ELSE 0 END) AS RojasDirectas,
       COUNT(*) AS TotalTarjetas
FROM op.Tarjeta t
INNER JOIN cfg.Tipo_Tarjeta tt ON tt.IdTipoTarjeta = t.IdTipoTarjeta
INNER JOIN op.Jugador j ON j.IdJugador = t.IdJugador
INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
INNER JOIN op.Seleccion s ON s.IdSeleccion = pl.IdSeleccion
INNER JOIN op.Pais pa ON pa.IdPais = s.IdPais
GROUP BY pa.Nombre;
GO
