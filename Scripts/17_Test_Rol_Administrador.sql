/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: ENTREGA 8 - Script de TESTING para usr_admin (rol_administrador).
             Verifica que el administrador puede:
             - Ejecutar ABM y cifrar un nuevo jugador al darlo de alta.
             - Consultar datos sensibles descifrados (op.usp_ConsultarDatosSensibles).
             - Ejecutar reportes del esquema rpt.
========================================================================= */

USE Mundial2026;
GO

PRINT '================ TEST 17: usr_admin (rol_administrador) ================';

EXECUTE AS USER = 'usr_admin';

-- [PERMITIDO 1] Consultar datos sensibles descifrados (evidencia de cifrado + descifrado)
-- Resultado esperado: Muestra DocumentoCifrado (binario 0x...) y DocumentoDescifrado legible.
BEGIN TRY
    EXEC op.usp_ConsultarDatosSensibles @Entidad = 'Jugador';
    EXEC op.usp_ConsultarDatosSensibles @Entidad = 'Arbitro';
    PRINT 'OK [Admin]: Pudo consultar datos sensibles descifrados.';
END TRY
BEGIN CATCH
    PRINT 'ERROR INESPERADO [Admin - Cifrado]: ' + ERROR_MESSAGE();
END CATCH;

-- [PERMITIDO 2] Alta de jugador con documento (se guarda cifrado automáticamente)
-- Resultado esperado: Éxito (se hace ROLLBACK al final para no ensuciar los datos del torneo).
BEGIN TRY
    BEGIN TRANSACTION;
        EXEC op.usp_AltaJugador @IdPlantel = 1, @IdClub = 1, @Nombre = 'Test', @Apellido = 'Cifrado',
             @Nacionalidad = 'Argentina', @Documento = '40123456', @PosicionHabitual = 'Defensor', @Dorsal = 99;
        SELECT TOP (1) IdJugador, Nombre, Apellido, DocumentoCifrado
        FROM op.Jugador WHERE Apellido = 'Cifrado';
    ROLLBACK TRANSACTION;
    PRINT 'OK [Admin]: Pudo dar de alta jugador con documento cifrado.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'ERROR INESPERADO [Admin - AltaJugador]: ' + ERROR_MESSAGE();
END CATCH;

-- [PERMITIDO 3] Ejecutar reportes
-- Resultado esperado: Devuelve el top 3 de goleadores sin error.
BEGIN TRY
    EXEC rpt.usp_Goleadores @Agrupacion = 'Torneo', @Top = 3;
    PRINT 'OK [Admin]: Pudo ejecutar reportes.';
END TRY
BEGIN CATCH
    PRINT 'ERROR INESPERADO [Admin - Reporte]: ' + ERROR_MESSAGE();
END CATCH;

REVERT;
PRINT '================ FIN TEST 17 ================';
GO
