/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: ENTREGA 8 - Script de TESTING para usr_consulta (rol_consulta).
             Demuestra qué permisos TIENE (reportes del esquema rpt) y qué
             permisos NO TIENE (cualquier ABM, lógica de negocio, datos
             sensibles o acceso directo de escritura a tablas).
========================================================================= */

USE Mundial2026;
GO

PRINT '================ TEST 20: usr_consulta (rol_consulta) ================';

EXECUTE AS USER = 'usr_consulta';

-- [PERMITIDO 1] Ejecutar reportes del esquema rpt (incluyendo PIVOT dinámico)
-- Resultado esperado: Éxito en Goleadores y Matriz de Prime Time.
BEGIN TRY
    EXEC rpt.usp_Goleadores @Agrupacion = 'Torneo', @Top = 5;
    EXEC rpt.usp_MatrizPrimeTime @Fase = 'Final';
    PRINT 'OK [Consulta]: Pudo ejecutar reportes del esquema rpt.';
END TRY
BEGIN CATCH
    PRINT 'ERROR INESPERADO [Consulta - Reportes]: ' + ERROR_MESSAGE();
END CATCH;

-- [DENEGADO 1] Intentar dar de alta un club (operación ABM)
-- Resultado esperado: ERROR de permiso denegado (EXECUTE denied en op.usp_AltaClub).
BEGIN TRY
    EXEC op.usp_AltaClub @Nombre = 'Club No Autorizado';
    PRINT 'FALLA DEL TEST: usr_consulta NO debería poder insertar datos.';
END TRY
BEGIN CATCH
    PRINT 'OK [Consulta - Denegado ABM]: ' + ERROR_MESSAGE();
END CATCH;

-- [DENEGADO 2] Intentar finalizar un partido (lógica de negocio)
-- Resultado esperado: ERROR de permiso denegado.
BEGIN TRY
    EXEC op.usp_FinalizarPartido @IdPartido = 1, @PublicoAsistente = 50000;
    PRINT 'FALLA DEL TEST: usr_consulta NO debería poder finalizar partidos.';
END TRY
BEGIN CATCH
    PRINT 'OK [Consulta - Denegado Negocio]: ' + ERROR_MESSAGE();
END CATCH;

-- [DENEGADO 3] Intentar consultar datos sensibles descifrados
-- Resultado esperado: ERROR de permiso denegado.
BEGIN TRY
    EXEC op.usp_ConsultarDatosSensibles @Entidad = 'Jugador';
    PRINT 'FALLA DEL TEST: usr_consulta NO debería ver datos sensibles.';
END TRY
BEGIN CATCH
    PRINT 'OK [Consulta - Denegado Datos Sensibles]: ' + ERROR_MESSAGE();
END CATCH;

-- [DENEGADO 4] Intentar acceso directo UPDATE sobre una tabla
-- Resultado esperado: ERROR de permiso denegado (UPDATE denied en op.Pais).
BEGIN TRY
    UPDATE op.Pais SET Nombre = 'Hack' WHERE IdPais = -1;
    PRINT 'FALLA DEL TEST: usr_consulta NO debería poder modificar tablas.';
END TRY
BEGIN CATCH
    PRINT 'OK [Consulta - Denegado UPDATE directo]: ' + ERROR_MESSAGE();
END CATCH;

REVERT;
PRINT '================ FIN TEST 20 ================';
GO
