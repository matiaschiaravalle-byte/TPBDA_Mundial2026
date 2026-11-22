/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: Script de TESTING 1:1 para 07_Importacion_E6.sql.
             Demuestra:
             - Importación de 3 formatos distintos (CSV, XML, JSON).
             - Importación de dataset scrapeado de Wikipedia (Árbitros).
             - Consumo de 2 APIs (Frankfurter y Banco Mundial).
             - Upsert sin duplicados al reimportar el mismo dataset.
             - Errores parciales (filas válidas entran; inválidas van al Log).
========================================================================= */

USE Mundial2026;
GO

DECLARE @CarpetaDatos VARCHAR(255) = 'D:\Proyectos Antigravity\Proyecto mundial BDA\Datos\';
DECLARE @RutaJugadores VARCHAR(255) = @CarpetaDatos + 'jugadores.csv';
DECLARE @RutaExhibiciones VARCHAR(255) = @CarpetaDatos + 'exhibiciones.csv';
DECLARE @RutaSedesXML VARCHAR(255) = @CarpetaDatos + 'sedes.xml';
DECLARE @RutaArbitrosScraping VARCHAR(255) = @CarpetaDatos + 'arbitros_scraping.csv';
DECLARE @RutaApiFrankfurter VARCHAR(255) = @CarpetaDatos + 'api_frankfurter.json';
DECLARE @RutaApiWorldBank VARCHAR(255) = @CarpetaDatos + 'api_worldbank_pbi.json';

PRINT '================ TEST 08: IMPORTACIÓN MASIVA (E6) ================';

-- [TEST 1 - API 1: FRANKFURTER JSON] Actualización de cotizaciones de moneda
-- Resultado esperado: Se actualizan/insertan EUR, BRL, MXN en cfg.Cotizacion_Moneda.
EXEC cfg.usp_ImportarCotizaciones_API_JSON @RutaArchivoJSON = @RutaApiFrankfurter, @ValorUsdEnARS = 1200.0000;
SELECT * FROM cfg.Cotizacion_Moneda;

-- [TEST 2 - API 2: BANCO MUNDIAL JSON] Actualización de PBI per cápita por país
-- Resultado esperado: Se actualiza PbiPerCapita en op.Pais (y si hay un país nuevo, se inserta).
EXEC cfg.usp_ImportarPbi_API_JSON @RutaArchivoJSON = @RutaApiWorldBank;
SELECT IdPais, Nombre, PbiPerCapita FROM op.Pais;

-- [TEST 3 - FORMATO 1: CSV + ERRORES PARCIALES] Importación de Jugadores
-- Resultado esperado: Entran los jugadores válidos (ej. Julián Álvarez, Vinícius Júnior),
-- se actualiza Messi si cambió de club (guardando op.Jugador_Historico) y la fila con país
-- inexistente queda en cfg.Log_Importacion sin abortar la carga.
EXEC cfg.usp_ImportarJugadores_CSV @RutaArchivo = @RutaJugadores, @Delimitador = ';';
SELECT COUNT(*) AS TotalJugadores_PrimeraCarga FROM op.Jugador;
SELECT * FROM op.Jugador;
SELECT * FROM op.Jugador_Historico;

-- [TEST 4 - UPSERT SIN DUPLICADOS] Reimportar exactamente el mismo CSV de Jugadores
-- Resultado esperado: TotalJugadores_SegundaCarga debe ser IGUAL a TotalJugadores_PrimeraCarga (0 duplicados).
EXEC cfg.usp_ImportarJugadores_CSV @RutaArchivo = @RutaJugadores, @Delimitador = ';';
SELECT COUNT(*) AS TotalJugadores_SegundaCarga FROM op.Jugador;

-- [TEST 5 - FORMATO 1: CSV + CONVERSIÓN DE MONEDA + ERRORES PARCIALES] Importación de Exhibiciones
-- Resultado esperado: Entran las exhibiciones válidas convertidas a ARS; la fila con texto 'ABC' en IdEspacio
-- y la fila con moneda desconocida 'ZZZ' se registran en cfg.Log_Importacion.
EXEC cfg.usp_ImportarExhibiciones_CSV @RutaArchivo = @RutaExhibiciones, @Delimitador = ';';
SELECT * FROM op.Exhibicion;
SELECT * FROM op.Exhibicion_Historico;

-- [TEST 6 - FORMATO 2: XML + ERRORES PARCIALES + UPSERT] Importación de Sedes desde XML
-- Resultado esperado: Entran las sedes válidas del XML; la sede con país inexistente va al Log.
-- Al reejecutar, no genera duplicados (hace UPDATE).
EXEC cfg.usp_ImportarSedes_XML @RutaArchivo = @RutaSedesXML;
EXEC cfg.usp_ImportarSedes_XML @RutaArchivo = @RutaSedesXML;
SELECT * FROM op.Sede;

-- [TEST 7 - SCRAPING WIKIPEDIA + ERRORES PARCIALES + UPSERT] Importación de Árbitros scrapeados
-- Resultado esperado: Entran los árbitros válidos; la fila con nombre vacío va al Log.
-- Al reejecutar, no genera duplicados.
EXEC cfg.usp_ImportarArbitros_Scraping_CSV @RutaArchivo = @RutaArbitrosScraping, @Delimitador = ';';
EXEC cfg.usp_ImportarArbitros_Scraping_CSV @RutaArchivo = @RutaArbitrosScraping, @Delimitador = ';';
SELECT * FROM op.Arbitro;

-- [EVIDENCIA FINAL DE ERRORES PARCIALES]
-- Resultado esperado: Se ven registradas únicamente las filas defectuosas de cada archivo,
-- mientras todas las filas válidas fueron importadas correctamente.
SELECT * FROM cfg.Log_Importacion ORDER BY IdLog DESC;

-- [TEST ERROR] Archivo inexistente (debe lanzar THROW y registrar el fallo en Log_Importacion)
-- Resultado esperado: Atrapado en CATCH; queda registrado en cfg.Log_Importacion.
BEGIN TRY
    EXEC cfg.usp_ImportarJugadores_CSV @RutaArchivo = 'C:\ruta_que_no_existe\fake.csv';
END TRY
BEGIN CATCH
    PRINT 'OK Error archivo inexistente: ' + ERROR_MESSAGE();
END CATCH

PRINT '================ FIN TEST 08 ================';
GO
