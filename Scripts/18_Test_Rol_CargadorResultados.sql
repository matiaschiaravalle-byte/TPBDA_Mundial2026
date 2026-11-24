/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli, Agustín Nicolás Mussi Pulcini
   Resumen: Script de testing para usr_cargador (rol_cargador_resultados).
             Demuestra qué permisos TIENE (partidos, resultados, goles) y qué
             permisos NO TIENE (publicidad, datos sensibles, DELETE directo).
========================================================================= */

USE Mundial2026;
GO

PRINT '================ TEST 18: usr_cargador (rol_cargador_resultados) ================';

EXECUTE AS USER = 'usr_cargador';

-- PERMITIDO Ejecutar SP de alta de partido (con ROLLBACK para no ensuciar datos)
-- Resultado esperado: Éxito, tiene permiso EXECUTE en op.usp_AltaPartido.
BEGIN TRY
    BEGIN TRANSACTION;
        EXEC op.usp_AltaPartido @IdSede = 1, @IdSeleccionLocal = 1, @IdSeleccionVisitante = 2,
             @Fecha = '2026-07-20', @HoraLocal = '18:00', @HoraUTC = '21:00', @Fase = 'Grupos';
    ROLLBACK TRANSACTION;
    PRINT 'OK [Cargador]: Pudo ejecutar op.usp_AltaPartido.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'ERROR INESPERADO [Cargador - AltaPartido]: ' + ERROR_MESSAGE();
END CATCH;

-- PERMITIDO Consultar reporte de resultados
-- Resultado esperado: Éxito, tiene permiso EXECUTE en rpt.usp_Resultados.
BEGIN TRY
    EXEC rpt.usp_Resultados @Fase = 'Final', @Formato = 'TABLA';
    PRINT 'OK [Cargador]: Pudo consultar rpt.usp_Resultados.';
END TRY
BEGIN CATCH
    PRINT 'ERROR INESPERADO [Cargador - Resultados]: ' + ERROR_MESSAGE();
END CATCH;

-- DENEGADO Intentar gestionar publicidad
-- Resultado esperado: ERROR de permiso denegado (EXECUTE denied en cfg.usp_AltaAnunciante).
BEGIN TRY
    EXEC cfg.usp_AltaAnunciante @IdPais = 1, @RazonSocial = 'No Autorizado S.A.';
    PRINT 'FALLA DEL TEST: usr_cargador NO debería poder crear anunciantes.';
END TRY
BEGIN CATCH
    PRINT 'OK [Cargador - Denegado Publicidad]: ' + ERROR_MESSAGE();
END CATCH;

-- DENEGADO Intentar ver datos sensibles descifrados
-- Resultado esperado: ERROR de permiso denegado (EXECUTE denied en op.usp_ConsultarDatosSensibles).
BEGIN TRY
    EXEC op.usp_ConsultarDatosSensibles @Entidad = 'Jugador';
    PRINT 'FALLA DEL TEST: usr_cargador NO debería ver datos sensibles.';
END TRY
BEGIN CATCH
    PRINT 'OK [Cargador - Denegado Datos Sensibles]: ' + ERROR_MESSAGE();
END CATCH;

-- DENEGADO Intentar acceso directo DELETE sobre una tabla
-- Resultado esperado: ERROR de permiso denegado (DELETE denied en op.Jugador).
BEGIN TRY
    DELETE FROM op.Jugador WHERE IdJugador = -1;
    PRINT 'FALLA DEL TEST: usr_cargador NO debería tener acceso directo a tablas.';
END TRY
BEGIN CATCH
    PRINT 'OK [Cargador - Denegado DELETE directo]: ' + ERROR_MESSAGE();
END CATCH;

REVERT;
PRINT '================ FIN TEST ================';
GO
