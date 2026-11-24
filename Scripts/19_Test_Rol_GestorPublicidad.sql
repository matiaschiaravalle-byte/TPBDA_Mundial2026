/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli, Agustín Nicolás Mussi Pulcini
   Resumen: Script de testing para usr_publicidad (rol_gestor_publicidad).
             Demuestra qué permisos tiene (anunciantes, reportes de publicidad y
             matriz prime time) y qué permisos NO tiene (goles/resultados, datos
             sensibles, DELETE directo).
========================================================================= */

USE Mundial2026;
GO

PRINT '================ TEST usr_publicidad (rol_gestor_publicidad) ================';

EXECUTE AS USER = 'usr_publicidad';

-- PERMITIDO Alta de anunciante (con ROLLBACK para no ensuciar datos)
-- Resultado esperado: Éxito, tiene permiso EXECUTE en cfg.usp_AltaAnunciante.
BEGIN TRY
    BEGIN TRANSACTION;
        EXEC cfg.usp_AltaAnunciante @IdPais = 1, @RazonSocial = 'Sponsor Test E8 S.A.';
    ROLLBACK TRANSACTION;
    PRINT 'OK [Publicidad]: Pudo ejecutar cfg.usp_AltaAnunciante.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'ERROR INESPERADO [Publicidad - AltaAnunciante]: ' + ERROR_MESSAGE();
END CATCH;

-- PERMITIDO Ejecutar reportes de ocupación publicitaria y matriz prime time
-- Resultado esperado: Éxito en ambos reportes.
BEGIN TRY
    EXEC rpt.usp_OcupacionPublicitaria @Moneda = 'USD';
    EXEC rpt.usp_MatrizPrimeTime @Fase = 'Final';
    PRINT 'OK [Publicidad]: Pudo ejecutar reportes de publicidad y prime time.';
END TRY
BEGIN CATCH
    PRINT 'ERROR INESPERADO [Publicidad - Reportes]: ' + ERROR_MESSAGE();
END CATCH;

-- DENEGADO Intentar registrar un gol / modificar resultado de partido
-- Resultado esperado: ERROR de permiso denegado (EXECUTE denied en op.usp_RegistrarGol_Y_ActualizarResultado).
BEGIN TRY
    EXEC op.usp_RegistrarGol_Y_ActualizarResultado 1, 1, NULL, 1, 1, 10;
    PRINT 'FALLA DEL TEST: usr_publicidad NO debería poder cargar goles.';
END TRY
BEGIN CATCH
    PRINT 'OK [Publicidad - Denegado Goles]: ' + ERROR_MESSAGE();
END CATCH;

-- DENEGADO Intentar ver datos sensibles descifrados
-- Resultado esperado: ERROR de permiso denegado.
BEGIN TRY
    EXEC op.usp_ConsultarDatosSensibles @Entidad = 'Arbitro';
    PRINT 'FALLA DEL TEST: usr_publicidad NO debería ver datos sensibles.';
END TRY
BEGIN CATCH
    PRINT 'OK [Publicidad - Denegado Datos Sensibles]: ' + ERROR_MESSAGE();
END CATCH;

-- DENEGADO Intentar borrar exhibiciones directamente en la tabla
-- Resultado esperado: ERROR de permiso denegado (DELETE denied en op.Exhibicion).
BEGIN TRY
    DELETE FROM op.Exhibicion WHERE IdExhibicion = -1;
    PRINT 'FALLA DEL TEST: usr_publicidad NO debería poder hacer DELETE directo.';
END TRY
BEGIN CATCH
    PRINT 'OK [Publicidad - Denegado DELETE directo]: ' + ERROR_MESSAGE();
END CATCH;

REVERT;
PRINT '================ FIN TEST ================';
GO
