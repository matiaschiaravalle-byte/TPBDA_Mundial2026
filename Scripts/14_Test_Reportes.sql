/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli, Agustín Nicolás Mussi Pulcini
   Resumen: Script de testing para 11_SP_Reportes_E7.sql para cada uno de los 7 reportes.
========================================================================= */

USE Mundial2026;
GO

SET NOCOUNT ON;

DECLARE @IdArgentina INT = (SELECT s.IdSeleccion FROM op.Seleccion s INNER JOIN op.Pais p ON p.IdPais = s.IdPais WHERE p.Nombre = 'Argentina');
DECLARE @IdMexico INT = (SELECT s.IdSeleccion FROM op.Seleccion s INNER JOIN op.Pais p ON p.IdPais = s.IdPais WHERE p.Nombre = 'México');
DECLARE @IdMexico8 INT = (SELECT j.IdJugador FROM op.Jugador j INNER JOIN op.Plantel pl ON pl.IdPlantel = j.IdPlantel
                          WHERE pl.IdSeleccion = @IdMexico AND j.Dorsal = 8);
DECLARE @IdMessi INT = (SELECT TOP (1) IdJugador FROM op.Jugador WHERE Apellido = 'Messi');
DECLARE @IdMetLife INT = (SELECT IdSede FROM op.Sede WHERE NombreEstadio = 'MetLife Stadium');
DECLARE @IdFinal INT = (SELECT MAX(IdPartido) FROM op.Partido WHERE Fase = 'Final');
DECLARE @IdArbitro INT = (SELECT TOP (1) IdArbitroPrincipal FROM op.Lista_Arbitros ORDER BY IdPartido);

/* =====================================================================
   rpt.usp_Goleadores
   ===================================================================== */
PRINT '--- Goleadores | Torneo (top 5)';
-- Resultado esperado: ranking general con los jugadores de los 5 primeros puestos (empates comparten puesto).
-- Los goles en contra no suman al goleador. Control: la suma de goles por selección (siguiente caso)
-- coincide con la cantidad de anotaciones que no son en contra.
BEGIN TRY
    EXEC rpt.usp_Goleadores @Agrupacion = 'Torneo', @Top = 5;
    SELECT 'Control: goles que no son en contra' AS Evidencia, COUNT(*) AS Goles
    FROM op.Anotacion a INNER JOIN cfg.Tipo_Jugada tj ON tj.IdTipoJugada = a.IdTipoJugada WHERE tj.Descripcion <> 'En contra';
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Goleadores | Por selección (Argentina) y por fase (Grupos, top 3)';
-- Resultado esperado: goleadores de Argentina ordenados por goles; luego el top 3 de la fase de grupos.
BEGIN TRY
    EXEC rpt.usp_Goleadores @Agrupacion = 'Seleccion', @IdSeleccion = @IdArgentina;
    EXEC rpt.usp_Goleadores @Agrupacion = 'Fase', @Fase = 'Grupos', @Top = 3;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Goleadores | Validaciones fallidas';
-- Resultado esperado: ERROR con un único mensaje: agrupación inválida, selección inexistente, fase inexistente y Top menor a 1.
BEGIN TRY
    EXEC rpt.usp_Goleadores @Agrupacion = 'Continente', @IdSeleccion = 999999, @Fase = 'Repechaje', @Top = 0;
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;

/* =====================================================================
   rpt.usp_Tarjetas
   ===================================================================== */
PRINT '--- Tarjetas | Todas las selecciones';
-- Resultado esperado: 3 grillas. (1) totales por selección: hay al menos una expulsión por doble amarilla y una
-- por roja directa; (2) detalle por jugador con su suspensión vigente; (3) suspensiones activas por acumulación.
BEGIN TRY
    EXEC rpt.usp_Tarjetas;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Tarjetas | Jugador suspendido por acumulación (México, dorsal 8)';
-- Resultado esperado: el jugador tiene amarillas en 2 partidos distintos de grupos. Control: no figura en la
-- alineación del partido de grupos siguiente a su segunda amarilla.
BEGIN TRY
    EXEC rpt.usp_Tarjetas @IdSeleccion = @IdMexico, @IdJugador = @IdMexico8;
    SELECT 'Control: partidos de grupos de México y si el dorsal 8 estuvo en la alineación' AS Evidencia,
           p.IdPartido, p.Fecha,
           CASE WHEN EXISTS (SELECT 1 FROM op.Alineacion a INNER JOIN op.Alineacion_Jugador aj ON aj.IdAlineacion = a.IdAlineacion
                             WHERE a.IdPartido = p.IdPartido AND aj.IdJugador = @IdMexico8) THEN 'Sí' ELSE 'No (suspendido)' END AS Alineado,
           (SELECT COUNT(*) FROM op.Tarjeta t WHERE t.IdPartido = p.IdPartido AND t.IdJugador = @IdMexico8) AS TarjetasEnElPartido
    FROM op.Partido p
    WHERE p.Fase = 'Grupos' AND @IdMexico IN (p.IdSeleccionLocal, p.IdSeleccionVisitante)
    ORDER BY p.Fecha;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Tarjetas | Validaciones fallidas';
-- Resultado esperado: ERROR: Messi no pertenece a la selección de México.
BEGIN TRY
    EXEC rpt.usp_Tarjetas @IdSeleccion = @IdMexico, @IdJugador = @IdMessi;
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;
-- Resultado esperado: ERROR: la selección y el jugador no existen.
BEGIN TRY
    EXEC rpt.usp_Tarjetas @IdSeleccion = 999999, @IdJugador = 999999;
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;

/* =====================================================================
   rpt.usp_DesignacionesArbitrales (XML)
   ===================================================================== */
PRINT '--- Designaciones arbitrales | Todos los árbitros designados (XML)';
-- Resultado esperado: un XML <DesignacionesArbitrales> con un <Arbitro> por árbitro designado, sus <Partido> con el
-- rol, y en los partidos que dirigió como principal el detalle <TarjetasSenaladas>; también los <Informes> recibidos.
BEGIN TRY
    EXEC rpt.usp_DesignacionesArbitrales;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Designaciones arbitrales | Un árbitro';
-- Resultado esperado: XML con un único <Arbitro> (el principal del primer partido designado).
BEGIN TRY
    EXEC rpt.usp_DesignacionesArbitrales @IdArbitro = @IdArbitro;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Designaciones arbitrales | Validaciones fallidas';
-- Resultado esperado: ERROR: el árbitro no existe y el parámetro SoloConDesignaciones es obligatorio.
BEGIN TRY
    EXEC rpt.usp_DesignacionesArbitrales @IdArbitro = 999999, @SoloConDesignaciones = NULL;
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;

/* =====================================================================
   rpt.usp_OcupacionPublicitaria
   ===================================================================== */
PRINT '--- Ocupación publicitaria | Todas las sedes';
-- Resultado esperado: 3 grillas: detalle de los 4 espacios por partido, resumen por partido (100% de ocupación en los
-- partidos simulados) y resumen por sede con los ingresos en ARS.
BEGIN TRY
    EXEC rpt.usp_OcupacionPublicitaria;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Ocupación publicitaria | MetLife Stadium con ingresos convertidos a USD';
-- Resultado esperado: sólo los partidos de MetLife (incluye la final) con la columna IngresosEnMoneda = ingresos / cotización USD.
BEGIN TRY
    EXEC rpt.usp_OcupacionPublicitaria @IdSede = @IdMetLife, @Moneda = 'USD';
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Ocupación publicitaria | Validaciones fallidas';
-- Resultado esperado: ERROR: la sede no existe, el partido no existe y la moneda XYZ no tiene cotización.
BEGIN TRY
    EXEC rpt.usp_OcupacionPublicitaria @IdSede = 999999, @IdPartido = 999999, @Moneda = 'XYZ';
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;
-- Resultado esperado: ERROR: la final no se juega en la sede indicada (se pasa otra sede).
BEGIN TRY
    DECLARE @OtraSede INT = (SELECT MIN(IdSede) FROM op.Sede WHERE IdSede <> @IdMetLife);
    EXEC rpt.usp_OcupacionPublicitaria @IdSede = @OtraSede, @IdPartido = @IdFinal;
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;

/* =====================================================================
   rpt.usp_MatrizPrimeTime
   ===================================================================== */
PRINT '--- Matriz de prime time | Todos los partidos, mercados con publicidad';
-- Resultado esperado: una fila por partido y una columna por mercado con "Sí" cuando el partido cae entre las 19 y
-- las 23 hs locales. Los partidos de las 23:00 UTC tienen más de 4 mercados en prime time (columna MercadosEnPrimeTime).
BEGIN TRY
    EXEC rpt.usp_MatrizPrimeTime;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Matriz de prime time | Fase final con todos los países';
-- Resultado esperado: sólo los partidos de la final, con una columna por cada país registrado.
BEGIN TRY
    EXEC rpt.usp_MatrizPrimeTime @Fase = 'Final', @SoloMercadosPublicitarios = 0;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Matriz de prime time | Validaciones fallidas';
-- Resultado esperado: ERROR: el partido no existe, la fase no existe y SoloMercadosPublicitarios es obligatorio.
BEGIN TRY
    EXEC rpt.usp_MatrizPrimeTime @IdPartido = 999999, @Fase = 'Repechaje', @SoloMercadosPublicitarios = NULL;
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;

/* =====================================================================
   rpt.usp_SeleccionesPlantillas (XML)
   ===================================================================== */
PRINT '--- Selecciones y plantillas | Todas (XML)';
-- Resultado esperado: XML <Selecciones> con 16 <Seleccion> (grupo, confederación, cantidad de convocados vigentes),
-- su <CuerpoTecnico> y el vector <Convocados> de <Jugador> con dorsal, posición, club, nombre y apellido.
BEGIN TRY
    EXEC rpt.usp_SeleccionesPlantillas;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Selecciones y plantillas | Argentina incluyendo bajas';
-- Resultado esperado: XML de Argentina; Di María aparece con estado="Baja" (baja de último momento de la entrega 5).
BEGIN TRY
    EXEC rpt.usp_SeleccionesPlantillas @IdSeleccion = @IdArgentina, @IncluirBajas = 1;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Selecciones y plantillas | Validaciones fallidas';
-- Resultado esperado: ERROR: la selección no existe e IncluirBajas es obligatorio.
BEGIN TRY
    EXEC rpt.usp_SeleccionesPlantillas @IdSeleccion = 999999, @IncluirBajas = NULL;
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;

/* =====================================================================
   rpt.usp_Resultados
   ===================================================================== */
PRINT '--- Resultados | Todos los partidos (tabla) y posiciones';
-- Resultado esperado: (1) todos los partidos con resultado, ganador y goleadores (los no jugados figuran "Pendiente");
-- (2) tabla de posiciones de los 4 grupos (PJ, PG, PE, PP, GF, GC, DG, Pts).
BEGIN TRY
    EXEC rpt.usp_Resultados;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Resultados | Fase final en XML y partidos de Argentina en tabla';
-- Resultado esperado: XML <Resultados> con la final y sus <Gol> anidados; luego los partidos de Argentina y la
-- tabla de posiciones de su grupo.
BEGIN TRY
    EXEC rpt.usp_Resultados @Fase = 'Final', @Formato = 'XML';
    EXEC rpt.usp_Resultados @IdSeleccion = @IdArgentina;
END TRY
BEGIN CATCH
    PRINT '   >> ERROR INESPERADO: ' + ERROR_MESSAGE();
END CATCH;

PRINT '--- Resultados | Validaciones fallidas';
-- Resultado esperado: ERROR: fase inexistente, selección inexistente y formato inválido.
BEGIN TRY
    EXEC rpt.usp_Resultados @Fase = 'Repechaje', @IdSeleccion = 999999, @Formato = 'JSON';
    PRINT '   >> FALLA DEL TEST: se esperaba un error.';
END TRY
BEGIN CATCH
    PRINT '   >> OK, error esperado: ' + ERROR_MESSAGE();
END CATCH;

PRINT '=== Fin del test===';
GO
