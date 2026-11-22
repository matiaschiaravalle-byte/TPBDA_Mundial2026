/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: Script de TESTING 1:1 para 05_SP_Negocio.sql.
             Ejecutar después de 04_Test_SP_ABM.sql.
             Incluye casos exitosos (con SELECT de evidencia) y casos de
             validaciones fallidas con resultado esperado en comentarios.
========================================================================= */

USE Mundial2026;
GO

PRINT '================ TEST 06: SPs DE NEGOCIO (EXITOSOS) ================';

-- [TEST 1 - ÉXITO] Convocatoria y baja por lesión
-- Resultado esperado: Se registra convocado y modificación 'Baja' por lesión.
EXEC op.usp_AltaConvocado 1, 2;
EXEC op.usp_ModificarConvocatoria @IdConvocado = 1, @Tipo = 'Baja', @Motivo = 'Lesión', @Fecha = '2026-06-01';
SELECT * FROM op.Modificacion_Convocatoria;

-- [TEST 2 - ÉXITO] Alineación (cabecera + titular + suplente) y cambios dentro de ventanas válidas
-- Resultado esperado: Se crea formación 4-3-3, se cargan titular/suplente y 3 ventanas de cambio válidas.
EXEC op.usp_RegistrarAlineacion @IdPartido = 1, @IdPlantel = 1, @EsquemaTactico = '4-3-3';
EXEC op.usp_RegistrarAlineacionJugador @IdAlineacion = 1, @IdJugador = 1, @Posicion = 'Delantero', @EsTitular = 1, @Dorsal = 10;
EXEC op.usp_RegistrarAlineacionJugador @IdAlineacion = 1, @IdJugador = 2, @Posicion = 'Mediocampista', @EsTitular = 0, @Dorsal = 11;

-- 3 ventanas distintas (minutos 60, 75, 85) + 1 cambio en entretiempo (minuto 45, no consume ventana)
EXEC op.usp_RegistrarCambioJugador @IdPartido = 1, @IdJugadorSaliente = 2, @IdJugadorIngresante = 1, @Minuto = 45, @Motivo = 'Táctico entretiempo';
EXEC op.usp_RegistrarCambioJugador @IdPartido = 1, @IdJugadorSaliente = 2, @IdJugadorIngresante = 1, @Minuto = 60, @Motivo = 'Táctico';
EXEC op.usp_RegistrarCambioJugador @IdPartido = 1, @IdJugadorSaliente = 2, @IdJugadorIngresante = 1, @Minuto = 75, @Motivo = 'Lesión';
EXEC op.usp_RegistrarCambioJugador @IdPartido = 1, @IdJugadorSaliente = 2, @IdJugadorIngresante = 1, @Minuto = 85, @Motivo = 'Precaución';
SELECT * FROM op.Cambios WHERE IdPartido = 1;

-- [TEST 3 - ÉXITO] Tarjetas y suspensión por acumulación en 2 partidos distintos
-- Resultado esperado: La 2da amarilla en el partido 2 dispara una suspensión activa en op.Suspension.
EXEC op.usp_RegistrarTarjeta_Y_CalcularSuspension @IdPartido = 1, @IdJugador = 1, @IdTipoTarjeta = 1, @Minuto = 40, @Motivo = 'Falta táctica';
EXEC op.usp_RegistrarTarjeta_Y_CalcularSuspension @IdPartido = 2, @IdJugador = 1, @IdTipoTarjeta = 1, @Minuto = 88, @Motivo = 'Protesta';
SELECT * FROM op.Suspension;

-- [TEST 4 - ÉXITO] Gol y actualización automática del marcador
-- Resultado esperado: op.Partido.Resultado del partido 1 queda en '1 - 0'.
EXEC op.usp_RegistrarGol_Y_ActualizarResultado @IdPartido = 1, @IdJugadorAnotador = 1, @IdJugadorAsistidor = NULL, @IdTipoJugada = 1, @IdPeriodo = 1, @Minuto = 15;
SELECT IdPartido, Resultado FROM op.Partido WHERE IdPartido = 1;

-- [TEST 5 - ÉXITO] Designación de terna arbitral completa (5 árbitros italianos en Argentina vs Brasil)
-- Resultado esperado: Se inserta la terna en op.Lista_Arbitros sin conflicto ético.
EXEC op.usp_DesignarArbitros @IdPartido = 1, @IdArbitroPrincipal = 2, @IdArbitroAsistente1 = 3, @IdArbitroAsistente2 = 4, @IdCuartoArbitro = 5, @IdArbitroVAR = 6;
SELECT * FROM op.Lista_Arbitros;

-- [TEST 6 - ÉXITO] Asignación publicitaria priorizada (países del partido -> PBI -> prime time)
-- Resultado esperado: Se asignan las 4 piezas a los 4 paneles de la sede 1 con su tarifa real.
EXEC op.usp_AsignarPublicidadPartido @IdPartido = 1, @IdSede = 1;
SELECT * FROM op.Exhibicion WHERE IdPartido = 1;

PRINT '================ TEST 06: VALIDACIONES FALLIDAS ================';

-- [TEST ERROR 1] Intentar poner en 4ta ventana de cambio (supera el tope de 3 ventanas en tiempo reglamentario)
-- Resultado esperado: THROW 50006 indicando que alcanzó el máximo de ventanas de sustitución.
BEGIN TRY
    EXEC op.usp_RegistrarCambioJugador @IdPartido = 1, @IdJugadorSaliente = 2, @IdJugadorIngresante = 1, @Minuto = 89, @Motivo = 'Exceso ventana';
END TRY
BEGIN CATCH
    PRINT 'OK Error Ventanas: ' + ERROR_MESSAGE();
END CATCH

-- [TEST ERROR 2] Intentar poner como titular al Jugador 1 que tiene suspensión activa
-- Resultado esperado: THROW 50008 impidiendo incluir a un jugador suspendido como titular.
EXEC op.usp_RegistrarAlineacion @IdPartido = 2, @IdPlantel = 1, @EsquemaTactico = '4-4-2';
BEGIN TRY
    EXEC op.usp_RegistrarAlineacionJugador @IdAlineacion = 2, @IdJugador = 1, @Posicion = 'Delantero', @EsTitular = 1, @Dorsal = 10;
END TRY
BEGIN CATCH
    PRINT 'OK Error Suspendido: ' + ERROR_MESSAGE();
END CATCH

-- [TEST ERROR 3] Conflicto ético de árbitro (árbitro argentino en partido de Argentina)
-- Resultado esperado: THROW 50005 indicando conflicto ético por nacionalidad.
BEGIN TRY
    EXEC op.usp_DesignarArbitros @IdPartido = 2, @IdArbitroPrincipal = 1, @IdArbitroAsistente1 = 2, @IdArbitroAsistente2 = 3, @IdCuartoArbitro = 4, @IdArbitroVAR = 5;
END TRY
BEGIN CATCH
    PRINT 'OK Error Conflicto Ético: ' + ERROR_MESSAGE();
END CATCH

-- [TEST ERROR 4] Tarjeta con minuto inválido (150) y partido inexistente (999)
-- Resultado esperado: THROW 50003 agrupando ambos errores en un solo mensaje.
BEGIN TRY
    EXEC op.usp_RegistrarTarjeta_Y_CalcularSuspension @IdPartido = 999, @IdJugador = 1, @IdTipoTarjeta = 1, @Minuto = 150, @Motivo = 'Error';
END TRY
BEGIN CATCH
    PRINT 'OK Error Tarjeta: ' + ERROR_MESSAGE();
END CATCH

PRINT '================ FIN TEST 06 ================';
GO
