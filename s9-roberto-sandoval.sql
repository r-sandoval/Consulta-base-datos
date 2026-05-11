/* -----------------------------------------------------------------------------
   CASO 1: ADMINISTRACIÓN DE USUARIOS, ROLES Y PRIVILEGIOS
   ----------------------------------------------------------------------------- */

-- Requerimiento 1.1: Limpieza de entorno (Drops)
DROP USER PRY2205_EFT CASCADE;
DROP USER PRY2205_EFT_DES CASCADE;
DROP USER PRY2205_EFT_CON CASCADE;
DROP ROLE PRY2205_ROL_D;
DROP ROLE PRY2205_ROL_C;

-- Requerimiento 1.2: Creación de Roles (Tabla 2)
CREATE ROLE PRY2205_ROL_D;
CREATE ROLE PRY2205_ROL_C;

-- Requerimiento 1.3: Creación de Usuarios (Tabla 1)
CREATE USER PRY2205_EFT IDENTIFIED BY "A12b.Cloud.34M" DEFAULT TABLESPACE DATA QUOTA 10 M ON DATA;
CREATE USER PRY2205_EFT_DES IDENTIFIED BY "C56d.Cloud.78P" DEFAULT TABLESPACE DATA QUOTA 10 M ON DATA;
CREATE USER PRY2205_EFT_CON IDENTIFIED BY "E90f.Cloud.12Z" DEFAULT TABLESPACE DATA QUOTA 10 M ON DATA;

-- Requerimiento 1.4: Asignación de Privilegios Sistémicos (Tabla 2)
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, 
      CREATE PUBLIC SYNONYM, CREATE SYNONYM, CREATE ANY INDEX TO PRY2205_EFT;

GRANT CREATE SESSION, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE TO PRY2205_EFT_DES;

GRANT CREATE SESSION TO PRY2205_EFT_CON;

-- Requerimiento 1.5: Asignación de Roles a Usuarios correspondientes
GRANT PRY2205_ROL_D TO PRY2205_EFT_DES;
GRANT PRY2205_ROL_C TO PRY2205_EFT_CON;


GRANT SELECT ON PRY2205_EFT.DEUDOR TO PRY2205_EFT_DES WITH GRANT OPTION;
GRANT SELECT ON PRY2205_EFT.TARJETA_DEUDOR TO PRY2205_EFT_DES WITH GRANT OPTION;
GRANT SELECT ON PRY2205_EFT.CUOTA_TARJETAS TO PRY2205_EFT_DES WITH GRANT OPTION;
GRANT SELECT ON PRY2205_EFT.OCUPACION TO PRY2205_EFT_DES WITH GRANT OPTION;






GRANT CREATE SYNONYM TO PRY2205_EFT_DES;


/* -----------------------------------------------------------------------------
   CASO 2: ABSTRACCIÓN Y SEGURIDAD DE DATOS
   ----------------------------------------------------------------------------- */

-- 1. Creación/Actualización de Sinónimos Privados
CREATE OR REPLACE SYNONYM SYN_DEUDOR FOR PRY2205_EFT.DEUDOR;
CREATE OR REPLACE SYNONYM SYN_TARJETA FOR PRY2205_EFT.TARJETA_DEUDOR;
CREATE OR REPLACE SYNONYM SYN_CUOTA FOR PRY2205_EFT.CUOTA_TARJETAS;
CREATE OR REPLACE SYNONYM SYN_OCUPACION FOR PRY2205_EFT.OCUPACION;


-- 2. Creación de Vista
CREATE OR REPLACE VIEW VW_ANALISIS_DEUDORES_PERIODO AS
SELECT 
    -- RUT_DEUDOR
    TRIM(TO_CHAR(D.NUMRUN, '99G999G999')) || '-' || D.DVRUN AS "RUT_DEUDOR",
    
    -- NOMBRE DEUDOR
    UPPER(D.PNOMBRE || ' ' || D.APPATERNO || ' ' || D.APMATERNO) AS "NOMBRE DEUDOR",
    
    -- TOTAL_CUOTAS
    COUNT(C.NRO_CUOTA) AS "TOTAL_CUOTAS",
    
    -- PROMEDIO_VALOR_CUOTAS: Valor promedio redondeado
    ROUND(AVG(C.VALOR_CUOTA)) AS "PROMEDIO_VALOR_CUOTAS",
    
    -- FECHA_MAS_ANTIGUA
    TO_CHAR(MIN(C.FECHA_VENC_CUOTA), 'DD-MM-YYYY') AS "FECHA_MAS_ANTIGUA",
    
    -- TELEFONO
    'SIN INFORMACION' AS "TELEFONO",
    
    -- OCUPACION
    UPPER(O.NOMBRE_PROF_OFIC) AS "OCUPACION",
    
    -- CUPO_DISP_COMPRA: Cálculo de cupo disponible
    (TD.CUPO_COMPRA - SUM(C.VALOR_CUOTA)) AS "CUPO_DISP_COMPRA"

FROM SYN_DEUDOR D 
JOIN SYN_TARJETA TD ON D.NUMRUN = TD.NUMRUN 
JOIN SYN_CUOTA C ON TD.NRO_TARJETA = C.NRO_TARJETA
JOIN SYN_OCUPACION O ON D.COD_OCUPACION = O.COD_OCUPACION
WHERE UPPER(O.NOMBRE_PROF_OFIC) NOT LIKE '%INGENIERO%'
GROUP BY 
    D.NUMRUN, 
    D.DVRUN, 
    D.PNOMBRE, 
    D.APPATERNO, 
    D.APMATERNO, 
    TD.CUPO_COMPRA, 
    O.NOMBRE_PROF_OFIC
ORDER BY "CUPO_DISP_COMPRA" ASC;


-- 3. Otorgar privilegios de lectura al Rol de Consultoría
GRANT SELECT ON VW_ANALISIS_DEUDORES_PERIODO TO PRY2205_ROL_C;


/* -----------------------------------------------------------------------------
   CONSULTA DE VALIDACIÓN FINAL
   ----------------------------------------------------------------------------- */
SELECT * FROM VW_ANALISIS_DEUDORES_PERIODO;
SELECT * FROM VW_ANALISIS_DEUDORES_PERIODO;
/* -----------------------------------------------------------------------------
   FIN DE HOJA DE CÓDIGO - DES_CONEXION
   ----------------------------------------------------------------------------- */



   /* -----------------------------------------------------------------------------
   CASO 3.1: CREACIÓN DE INFORME 
   ----------------------------------------------------------------------------- */

-- 1. Limpieza de objetos previos para ejecución limpia
DROP TABLE T_ANALISIS_TARJETAS CASCADE CONSTRAINTS;
DROP SEQUENCE SEQ_T_ANALISIS;

-- 2. Creación de la tabla física para el informe de transacciones
CREATE TABLE T_ANALISIS_TARJETAS (
    NUM_ANALISIS          NUMBER PRIMARY KEY,
    NRO_TARJETA           NUMBER(15) NOT NULL,
    TOTAL_CUOTAS          NUMBER(3),
    MONTO_TOTAL_TRANSA    NUMBER(12),
    FECHA_TRANSACCION     DATE,
    DIRECCION             VARCHAR2(200),
    MONTO_REAJUSTADO      NUMBER(12)
);

-- 3. Creación de secuencia para el identificador del análisis
CREATE SEQUENCE SEQ_T_ANALISIS 
START WITH 1 
INCREMENT BY 1;

-- 4. Carga de datos con lógica de reajuste y ORDEN CORREGIDO
-- Se asegura que NUM_ANALISIS vaya de menor a mayor según NRO_TARJETA
INSERT INTO T_ANALISIS_TARJETAS (
    NUM_ANALISIS,
    NRO_TARJETA,
    TOTAL_CUOTAS,
    MONTO_TOTAL_TRANSA,
    FECHA_TRANSACCION,
    DIRECCION,
    MONTO_REAJUSTADO
)
SELECT 
    SEQ_T_ANALISIS.NEXTVAL,
    SUB.NRO_TARJETA,
    SUB.TOTAL_CUOTAS_TRANSACCION,
    SUB.MONTO_TOTAL_TRANSACCION,
    SUB.FECHA_TRANSACCION,
    SUB.DIRECCION_FORMATO,
    ROUND(SUB.MONTO_TOTAL_TRANSACCION * (1 + 
        CASE 
            WHEN SUB.MONTO_TOTAL_TRANSACCION BETWEEN 200000 AND 300000 THEN 0.05
            WHEN SUB.MONTO_TOTAL_TRANSACCION BETWEEN 300001 AND 500000 THEN 0.07
            ELSE 0 
        END
    )) AS MONTO_REAJUSTADO
FROM (
    SELECT 
        TT.NRO_TARJETA,
        TT.TOTAL_CUOTAS_TRANSACCION,
        TT.MONTO_TOTAL_TRANSACCION,
        TT.FECHA_TRANSACCION,
        INITCAP(S.DIRECCION) AS DIRECCION_FORMATO
    FROM TRANSACCION_TARJETA_DEUDOR TT
    JOIN SUCURSAL S ON TT.ID_SUCURSAL = S.ID_SUCURSAL
    WHERE UPPER(S.DIRECCION) LIKE 'A%'
      AND TT.MONTO_TOTAL_TRANSACCION >= 200000
    ORDER BY TT.NRO_TARJETA ASC -- Garantiza orden correlativo del ID
) SUB;

-- 5. Configuración de Acceso
CREATE OR REPLACE PUBLIC SYNONYM SYN_T_ANALISIS FOR T_ANALISIS_TARJETAS;
GRANT SELECT ON T_ANALISIS_TARJETAS TO PRY2205_ROL_C;

COMMIT;


/* -----------------------------------------------------------------------------
   CASO 3.2: OPTIMIZACIÓN (CREACIÓN Y VISUALIZACIÓN DE ÍNDICES)
   ----------------------------------------------------------------------------- */

-- Intento de creación de índices (si ya existen, el bloque capturará el error)
BEGIN
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_PROF_DESC ON OCUPACION(UPPER(NOMBRE_PROF_OFIC))';
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('IDX_PROF_DESC ya existe.');
END;
/

BEGIN
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TARJETA_RUN ON TARJETA_DEUDOR(NUMRUN)';
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('IDX_TARJETA_RUN ya existe.');
END;
/

BEGIN
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_CUOTA_TAR_NRO ON CUOTA_TARJETAS(NRO_TARJETA)';
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('IDX_CUOTA_TAR_NRO ya existe.');
END;
/


/* -----------------------------------------------------------------------------
   CONSULTAS DE VALIDACIÓN FINAL
   ----------------------------------------------------------------------------- */

-- 1. Ver el informe generado ordenado por el ID correlativo
SELECT * FROM T_ANALISIS_TARJETAS 
ORDER BY NUM_ANALISIS ASC;

-- 2. Ver el estado y tipo de los índices para el informe de optimización
SELECT 
    index_name AS "NOMBRE_INDICE", 
    table_name AS "TABLA", 
    status     AS "ESTADO",
    index_type AS "TIPO"
FROM user_indexes 
WHERE index_name IN ('IDX_PROF_DESC', 'IDX_TARJETA_RUN', 'IDX_CUOTA_TAR_NRO', 'IDX_PROF_MAYUS', 'IDX_TARJ_DEUDOR_RUN')
   OR table_name IN ('OCUPACION', 'TARJETA_DEUDOR', 'CUOTA_TARJETAS');

/* -----------------------------------------------------------------------------
   FIN DE HOJA DE CÓDIGO
   ----------------------------------------------------------------------------- */


   /* -----------------------------------------------------------------------------
   CASO 3.1.4: VALIDACIÓN CONSULTOR
   ----------------------------------------------------------------------------- */
SELECT * FROM SYN_VW_CASO2;
SELECT * FROM SYN_T_ANALISIS;