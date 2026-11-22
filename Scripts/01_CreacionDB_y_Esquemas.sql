/* =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: Creación de la base de datos Mundial2026 y esquemas cfg y op,
             validando la existencia de objetos antes de crearlos.
========================================================================= */

USE master;
GO

IF DB_ID('Mundial2026') IS NULL
BEGIN
    CREATE DATABASE Mundial2026;
END
GO

USE Mundial2026;
GO

IF SCHEMA_ID('cfg') IS NULL
BEGIN
    EXEC('CREATE SCHEMA cfg');
END
GO

IF SCHEMA_ID('op') IS NULL
BEGIN
    EXEC('CREATE SCHEMA op');
END
GO

IF SCHEMA_ID('rpt') IS NULL
BEGIN
    EXEC('CREATE SCHEMA rpt');
END
GO
