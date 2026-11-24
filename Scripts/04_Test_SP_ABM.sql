/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli, Agustín Nicolás Mussi Pulcini
   Explicación: Script de testing para 03_SP_ABM.sql.
========================================================================= */

USE Mundial2026;
GO

PRINT '================ Ejemplos de ingresos correctos ================';

-- Alta de Países, Confederación, Sede, Selecciones, Partidos, Planteles y Clubes
-- Resultado esperado: Se insertan correctamente sin errores usando exclusivamente SPs ABM.
EXEC op.usp_AltaPais 'Argentina', 'UTC-3', -3, 13700.00;
EXEC op.usp_AltaPais 'Brasil', 'UTC-3', -3, 10400.00;
EXEC op.usp_AltaPais 'Estados Unidos', 'UTC-5', -5, 81600.00;
EXEC op.usp_AltaPais 'Italia', 'UTC+1', 1, 38300.00;

EXEC cfg.usp_AltaConfederacion 'CONMEBOL', 'América del Sur';
EXEC op.usp_AltaSede 1, 'Estadio Monumental', 'Buenos Aires', 'UTC-3', 85000;
EXEC op.usp_AltaSeleccion 1, 1, 'A';
EXEC op.usp_AltaSeleccion 2, 1, 'A';
EXEC op.usp_AltaPartido 1, 1, 2, '2026-06-15', '16:00:00', '19:00:00', 'Grupos', 82000, NULL, 0;
EXEC op.usp_AltaPartido 1, 1, 2, '2026-06-20', '20:00:00', '23:00:00', 'Grupos', 84000, NULL, 0;
EXEC op.usp_AltaPlantel 1;
EXEC op.usp_AltaPlantel 2;
EXEC op.usp_AltaClub 'Inter Miami';
EXEC op.usp_AltaClub 'Flamengo';

-- Alta, Modificación y Baja de Jugador (ABM completo)
-- Resultado esperado: Se dan de alta 3 jugadores, se modifica dorsal del 1ro y se da de baja el 3ro.
EXEC op.usp_AltaJugador 1, 1, 'Lionel', 'Messi', 'Argentina', '33016244', '1987-06-24', 'Delantero', 10;
EXEC op.usp_AltaJugador 1, 1, 'Ángel', 'Di María', 'Argentina', '33500111', '1988-02-14', 'Mediocampista', 11;
EXEC op.usp_AltaJugador 1, 1, 'Jugador', 'Temporal', 'Argentina', '99999999', '2000-01-01', 'Defensor', 99;

EXEC op.usp_ModificarJugador @IdJugador = 1, @IdPlantel = 1, @IdClub = 1, @PosicionHabitual = 'Extremo', @Dorsal = 10;
EXEC op.usp_BajaJugador @IdJugador = 3;

-- Evidencia de datos manipulados
SELECT * FROM op.Pais;
SELECT * FROM op.Sede;
SELECT * FROM op.Partido;
SELECT * FROM op.Jugador;

-- Alta de catálogos necesarios para tests de negocio
-- Resultado esperado: Se cargan reglas, tipos de tarjeta, jugadas, períodos, árbitros y publicidad.
EXEC cfg.usp_AltaRegla_Suspencion 2, 1, 'Semifinal';
EXEC cfg.usp_AltaTipo_Tarjeta 1, 1, 'Amarilla';
EXEC cfg.usp_AltaTipo_Tarjeta 2, NULL, 'Doble Amarilla';
EXEC cfg.usp_AltaTipo_Tarjeta 3, NULL, 'Roja Directa';
EXEC cfg.usp_AltaTipo_Jugada 1, 'Jugada';
EXEC cfg.usp_AltaTipo_Jugada 2, 'En contra';
EXEC cfg.usp_AltaPeriodo 1, 'Primer Tiempo', 0, 45;
EXEC cfg.usp_AltaPeriodo 2, 'Segundo Tiempo', 46, 90;

EXEC op.usp_AltaArbitro 'Nestor', 'Pitana', 'Argentina', 'FIFA', '25111222', '1975-06-17';
EXEC op.usp_AltaArbitro 'Pierluigi', 'Collina', 'Italia', 'FIFA', 'IT1001', '1960-02-13';
EXEC op.usp_AltaArbitro 'Daniele', 'Orsato', 'Italia', 'FIFA', 'IT1002', '1975-11-23';
EXEC op.usp_AltaArbitro 'Marco', 'Guida', 'Italia', 'FIFA', 'IT1003', '1981-06-07';
EXEC op.usp_AltaArbitro 'Maurizio', 'Mariani', 'Italia', 'FIFA', 'IT1004', '1982-02-25';
EXEC op.usp_AltaArbitro 'Massimiliano', 'Irrati', 'Italia', 'FIFA', 'IT1005', '1979-06-27';

EXEC cfg.usp_AltaIdioma 'Español';
EXEC cfg.usp_AltaAnunciante 3, 'Coca Cola';
EXEC cfg.usp_AltaCampania 1, 'Mundial 2026', 'Campaña Global';
EXEC cfg.usp_AltaPieza_Contenido 1, 1, 30, 20000.00;
EXEC cfg.usp_AltaPieza_Contenido 1, 1, 15, 15000.00;
EXEC cfg.usp_AltaPieza_Contenido 1, 1, 30, 25000.00;
EXEC cfg.usp_AltaPieza_Contenido 1, 1, 20, 18000.00;
EXEC cfg.usp_AltaPieza_Pais 1, 1;
EXEC cfg.usp_AltaPieza_Pais 2, 2;
EXEC cfg.usp_AltaPieza_Pais 3, 3;
EXEC cfg.usp_AltaPieza_Pais 4, 4;

EXEC op.usp_AltaEspacioPublicitario 1, 'Panel Norte';
EXEC op.usp_AltaEspacioPublicitario 1, 'Panel Sur';
EXEC op.usp_AltaEspacioPublicitario 1, 'Panel Este';
EXEC op.usp_AltaEspacioPublicitario 1, 'Panel Oeste';

PRINT '================ Ejemplos de ingresos incorrectos ================';

-- País con nombre vacío y OffsetUTC fuera de rango
-- Resultado esperado: THROW 50101 agrupando ambos mensajes de error.
BEGIN TRY EXEC op.usp_AltaPais '', 'UTC+99', 99, 1000; END TRY BEGIN CATCH PRINT 'OK Error 1: ' + ERROR_MESSAGE(); END CATCH

-- Sede con capacidad <= 0 y país inexistente
-- Resultado esperado: THROW 50104 indicando país inexistente y capacidad inválida.
BEGIN TRY EXEC op.usp_AltaSede 999, 'Estadio Fantasma', 'X', 'UTC', -100; END TRY BEGIN CATCH PRINT 'OK Error 2: ' + ERROR_MESSAGE(); END CATCH

-- Partido con misma selección como local y visitante
-- Resultado esperado: THROW 50116 indicando que local y visitante no pueden ser iguales.
BEGIN TRY EXEC op.usp_AltaPartido 1, 1, 1, '2026-06-25', '15:00', '18:00', 'Grupos'; END TRY BEGIN CATCH PRINT 'OK Error 3: ' + ERROR_MESSAGE(); END CATCH

-- Jugador con nombre vacío y club inexistente
-- Resultado esperado: THROW 50001 agrupando errores de club y nombre.
BEGIN TRY EXEC op.usp_AltaJugador 1, 999, '', 'Test', 'Argentina'; END TRY BEGIN CATCH PRINT 'OK Error 4: ' + ERROR_MESSAGE(); END CATCH

-- Baja de jugador inexistente
-- Resultado esperado: THROW 50004 indicando que el jugador no existe.
BEGIN TRY EXEC op.usp_BajaJugador 9999; END TRY BEGIN CATCH PRINT 'OK Error 5: ' + ERROR_MESSAGE(); END CATCH

-- Cuerpo técnico con tipo inválido
-- Resultado esperado: THROW 50128 indicando que debe ser DT o Ayudante.
BEGIN TRY EXEC op.usp_AltaCuerpoTecnico 1, 1, 'Lionel Scaloni', 'Presidente'; END TRY BEGIN CATCH PRINT 'OK Error 6: ' + ERROR_MESSAGE(); END CATCH

-- Modificación de convocatoria con tipo inválido
-- Resultado esperado: THROW 50125 indicando que debe ser Alta o Baja.
BEGIN TRY EXEC op.usp_AltaModificacion_Convocatoria 999, 'Cambio', '', '2026-06-01'; END TRY BEGIN CATCH PRINT 'OK Error 7: ' + ERROR_MESSAGE(); END CATCH

-- Cambio con minuto inválido y mismo jugador
-- Resultado esperado: THROW 50137 agrupando minuto inválido y mismo jugador.
BEGIN TRY EXEC op.usp_AltaCambios 1, 1, 1, 200, 'Error'; END TRY BEGIN CATCH PRINT 'OK Error 8: ' + ERROR_MESSAGE(); END CATCH

-- Quinto espacio publicitario en la misma sede (máximo 4)
-- Resultado esperado: THROW 50185 impidiendo superar los 4 espacios por sede.
BEGIN TRY EXEC op.usp_AltaEspacioPublicitario 1, 'Panel Extra'; END TRY BEGIN CATCH PRINT 'OK Error 9: ' + ERROR_MESSAGE(); END CATCH

-- Pieza de contenido con tarifa negativa
-- Resultado esperado: THROW 50181 indicando que duración y tarifa deben ser > 0.
BEGIN TRY EXEC cfg.usp_AltaPieza_Contenido 1, 1, 30, -500; END TRY BEGIN CATCH PRINT 'OK Error 10: ' + ERROR_MESSAGE(); END CATCH

PRINT '================ FIN TEST ================';
GO
