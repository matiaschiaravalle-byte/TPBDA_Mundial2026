/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: ENTREGA 8 - Creación de Roles de Seguridad, Usuarios y Permisos
             Granulares mediante SP (cfg.usp_ConfigurarSeguridadRoles).
             Roles creados (4):
             1. rol_administrador       (usr_admin)
             2. rol_cargador_resultados (usr_cargador)
             3. rol_gestor_publicidad   (usr_publicidad)
             4. rol_consulta            (usr_consulta)
             Ejecutar después de 15_Cifrado_E8.sql.
========================================================================= */

USE Mundial2026;
GO

CREATE OR ALTER PROCEDURE cfg.usp_ConfigurarSeguridadRoles
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Crear Roles (validando existencia)
    IF DATABASE_PRINCIPAL_ID('rol_administrador') IS NULL       CREATE ROLE rol_administrador;
    IF DATABASE_PRINCIPAL_ID('rol_cargador_resultados') IS NULL CREATE ROLE rol_cargador_resultados;
    IF DATABASE_PRINCIPAL_ID('rol_gestor_publicidad') IS NULL   CREATE ROLE rol_gestor_publicidad;
    IF DATABASE_PRINCIPAL_ID('rol_consulta') IS NULL            CREATE ROLE rol_consulta;

    -- 2. Crear Usuarios de prueba (WITHOUT LOGIN para testear con EXECUTE AS USER)
    IF DATABASE_PRINCIPAL_ID('usr_admin') IS NULL      CREATE USER usr_admin WITHOUT LOGIN;
    IF DATABASE_PRINCIPAL_ID('usr_cargador') IS NULL   CREATE USER usr_cargador WITHOUT LOGIN;
    IF DATABASE_PRINCIPAL_ID('usr_publicidad') IS NULL CREATE USER usr_publicidad WITHOUT LOGIN;
    IF DATABASE_PRINCIPAL_ID('usr_consulta') IS NULL   CREATE USER usr_consulta WITHOUT LOGIN;

    -- 3. Asignar Usuarios a sus Roles
    ALTER ROLE rol_administrador       ADD MEMBER usr_admin;
    ALTER ROLE rol_cargador_resultados ADD MEMBER usr_cargador;
    ALTER ROLE rol_gestor_publicidad   ADD MEMBER usr_publicidad;
    ALTER ROLE rol_consulta            ADD MEMBER usr_consulta;

    -- =====================================================================
    -- 4. PERMISOS GRANULARES POR ROL
    -- =====================================================================

    -- 4.1 rol_administrador: control total sobre los esquemas y claves de cifrado
    GRANT CONTROL ON SCHEMA::op  TO rol_administrador;
    GRANT CONTROL ON SCHEMA::cfg TO rol_administrador;
    GRANT CONTROL ON SCHEMA::rpt TO rol_administrador;
    GRANT CONTROL ON CERTIFICATE::Cert_Mundial2026 TO rol_administrador;
    GRANT CONTROL ON SYMMETRIC KEY::Key_DatosSensibles TO rol_administrador;

    -- 4.2 rol_cargador_resultados: sólo SPs operativos de partidos y resultados
    GRANT EXECUTE ON op.usp_AltaPartido TO rol_cargador_resultados;
    GRANT EXECUTE ON op.usp_ModificarPartido TO rol_cargador_resultados;
    GRANT EXECUTE ON op.usp_RegistrarAlineacion TO rol_cargador_resultados;
    GRANT EXECUTE ON op.usp_RegistrarAlineacionJugador TO rol_cargador_resultados;
    GRANT EXECUTE ON op.usp_RegistrarCambioJugador TO rol_cargador_resultados;
    GRANT EXECUTE ON op.usp_RegistrarTarjeta_Y_CalcularSuspension TO rol_cargador_resultados;
    GRANT EXECUTE ON op.usp_RegistrarGol_Y_ActualizarResultado TO rol_cargador_resultados;
    GRANT EXECUTE ON op.usp_DesignarArbitros TO rol_cargador_resultados;
    GRANT EXECUTE ON op.usp_FinalizarPartido TO rol_cargador_resultados;
    GRANT EXECUTE ON rpt.usp_Resultados TO rol_cargador_resultados;

    -- 4.3 rol_gestor_publicidad: sólo SPs y reportes de publicidad
    GRANT EXECUTE ON cfg.usp_AltaAnunciante TO rol_gestor_publicidad;
    GRANT EXECUTE ON cfg.usp_ModificarAnunciante TO rol_gestor_publicidad;
    GRANT EXECUTE ON cfg.usp_AltaCampania TO rol_gestor_publicidad;
    GRANT EXECUTE ON cfg.usp_AltaPieza_Contenido TO rol_gestor_publicidad;
    GRANT EXECUTE ON cfg.usp_AltaPieza_Pais TO rol_gestor_publicidad;
    GRANT EXECUTE ON op.usp_AltaExhibicion TO rol_gestor_publicidad;
    GRANT EXECUTE ON op.usp_AsignarPublicidadPartido TO rol_gestor_publicidad;
    GRANT EXECUTE ON rpt.usp_OcupacionPublicitaria TO rol_gestor_publicidad;
    GRANT EXECUTE ON rpt.usp_MatrizPrimeTime TO rol_gestor_publicidad;
    -- Permisos mínimos de lectura requeridos por el PIVOT dinámico de rpt.usp_MatrizPrimeTime
    GRANT SELECT ON op.Partido TO rol_gestor_publicidad;
    GRANT SELECT ON op.Seleccion TO rol_gestor_publicidad;
    GRANT SELECT ON op.Pais TO rol_gestor_publicidad;
    GRANT SELECT ON cfg.Pieza_Pais TO rol_gestor_publicidad;
    GRANT EXECUTE ON op.fn_EsPrimeTime TO rol_gestor_publicidad;

    -- 4.4 rol_consulta: sólo ejecución de reportes (esquema rpt)
    GRANT EXECUTE ON SCHEMA::rpt TO rol_consulta;
    -- Permisos mínimos de lectura requeridos por el PIVOT dinámico de rpt.usp_MatrizPrimeTime
    GRANT SELECT ON op.Partido TO rol_consulta;
    GRANT SELECT ON op.Seleccion TO rol_consulta;
    GRANT SELECT ON op.Pais TO rol_consulta;
    GRANT SELECT ON cfg.Pieza_Pais TO rol_consulta;
    GRANT EXECUTE ON op.fn_EsPrimeTime TO rol_consulta;

    PRINT 'Roles, usuarios y permisos configurados correctamente.';
END;
GO

EXEC cfg.usp_ConfigurarSeguridadRoles;
GO
