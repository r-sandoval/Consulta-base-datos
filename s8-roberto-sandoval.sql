-- =========================================================
-- CASO 1: ESTRATEGIA DE SEGURIDAD (ADMINISTRACIÓN)
-- =========================================================

-- Limpieza de ambiente
DROP USER PRY2205_USER1 CASCADE;
DROP USER PRY2205_USER2 CASCADE;
DROP ROLE PRY2205_ROL_D;
DROP ROLE PRY2205_ROL_P;

-- Creación de Roles
CREATE ROLE PRY2205_ROL_D; 
CREATE ROLE PRY2205_ROL_P; 

-- Creación de Usuarios
CREATE USER PRY2205_USER1 IDENTIFIED BY "Duoc.2026.Proyecto"
DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;

CREATE USER PRY2205_USER2 IDENTIFIED BY "Duoc.2026.Proyecto"
DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;

-- Privilegios de Sistema
GRANT CONNECT, RESOURCE TO PRY2205_ROL_D;
GRANT CREATE VIEW, CREATE PUBLIC SYNONYM TO PRY2205_ROL_D;

GRANT CONNECT TO PRY2205_ROL_P;
GRANT CREATE VIEW, CREATE ANY VIEW TO PRY2205_ROL_P;

-- Asignación de Roles
GRANT PRY2205_ROL_D TO PRY2205_USER1;
GRANT PRY2205_ROL_P TO PRY2205_USER2;

-- Privilegios directos necesarios para el Usuario 2
GRANT CREATE VIEW TO PRY2205_USER2;
GRANT SELECT ANY TABLE TO PRY2205_USER2;

-- =========================================================
-- CASO 3.2: CREACIÓN DE ÍNDICES (OPTIMIZACIÓN - EJECUTAR COMO USER1)
-- =========================================================
-- Nota: En un script único, se asume que las tablas ya existen.
CREATE INDEX PRY2205_USER1.IDX_MEDICO_CARGO ON PRY2205_USER1.MEDICO(car_id);
CREATE INDEX PRY2205_USER1.IDX_CARGO_NOMBRE ON PRY2205_USER1.CARGO(nombre);
CREATE INDEX PRY2205_USER1.IDX_PACIENTE_SALUD ON PRY2205_USER1.PACIENTE(sal_id);

-- =========================================================
-- CASO 3: CONTROL DE ACCESO INDIRECTO (SINÓNIMOS)
-- =========================================================
CREATE OR REPLACE PUBLIC SYNONYM SYN_PACIENTE FOR PRY2205_USER1.PACIENTE;
CREATE OR REPLACE PUBLIC SYNONYM SYN_SALUD FOR PRY2205_USER1.SALUD;
CREATE OR REPLACE PUBLIC SYNONYM SYN_BONO_CONSULTA FOR PRY2205_USER1.BONO_CONSULTA;
CREATE OR REPLACE PUBLIC SYNONYM SYN_SISTEMA_SALUD FOR PRY2205_USER1.SISTEMA_SALUD;

-- Permisos de objeto para el desarrollador
GRANT SELECT ON PRY2205_USER1.PACIENTE TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.BONO_CONSULTA TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.SALUD TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.SISTEMA_SALUD TO PRY2205_USER2;

-- =========================================================
-- CASO 3.1: VISTA GESTIÓN DE MÉDICOS (USUARIO 1)
-- =========================================================
CREATE OR REPLACE VIEW PRY2205_USER1.VW_AUM_MEDICO_X_CARGO AS
SELECT 
    TO_CHAR(m.rut_med, '99G999G999') || '-' || m.dv_run AS "RUT MEDICO",
    c.nombre AS "CARGO",
    '$' || TO_CHAR(m.sueldo_base, '99G999G999') AS "SUELDO ACTUAL",
    '$' || TO_CHAR(ROUND(m.sueldo_base * 1.15), '99G999G999') AS "SUELDO AUMENTADO"
FROM PRY2205_USER1.MEDICO m
JOIN PRY2205_USER1.CARGO c ON m.car_id = c.car_id
WHERE LOWER(c.nombre) LIKE '%atención%'
ORDER BY "SUELDO AUMENTADO" DESC;

-- =========================================================
-- CASO 2: VISTA RECÁLCULO DE COSTOS (USUARIO 2)
-- =========================================================
CREATE OR REPLACE VIEW PRY2205_USER2.VW_RECALCULO_COSTOS AS
SELECT 
    TO_CHAR(p.pac_run, '99G999G999') || '-' || p.dv_run AS "RUT PACIENTE",
    p.pnombre || ' ' || p.apaterno || ' ' || p.amaterno AS "NOMBRE PACIENTE",
    s.descripcion AS "SISTEMA SALUD",
    '$' || TO_CHAR(b.costo, '99G999G999') AS "COSTO",
    b.hr_consulta AS "HORARIO_ATENCION",
    TO_CHAR(b.fecha_bono, 'MM-YYYY') AS "FECHA CONSULTA",
    '$' || TO_CHAR(
        CASE 
            WHEN b.costo BETWEEN 15000 AND 25000 THEN ROUND(b.costo * 1.15)
            WHEN b.costo > 25000 THEN ROUND(b.costo * 1.20)
            ELSE b.costo
        END, '99G999G999') AS "REAJUSTE"
FROM SYN_PACIENTE p
JOIN SYN_BONO_CONSULTA b ON p.pac_run = b.pac_run
JOIN SYN_SALUD s ON p.sal_id = s.sal_id
JOIN SYN_SISTEMA_SALUD ss ON s.tipo_sal_id = ss.tipo_sal_id
WHERE b.hr_consulta > '17:15'
  AND EXTRACT(YEAR FROM b.fecha_bono) = 2025 
  AND ss.tipo_sal_id IN ('I', 'F')
WITH READ ONLY;

COMMIT;