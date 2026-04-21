ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ',.';

/* =============================================================================
   CASO 1: RECAUDACIÓN BONOS MÉDICOS
   ============================================================================= */

-- Eliminación de tabla si existe
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE RECAUDACION_BONOS_MEDICOS';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE RECAUDACION_BONOS_MEDICOS AS
    SELECT
        
        TO_CHAR(m.rut_med, '09G999G999') || '-' || m.dv_run AS RUT_MÉDICO,
        UPPER(m.pnombre || ' ' || m.apaterno || ' ' || m.amaterno) AS "NOMBRE MÉDICO",
        TO_CHAR(SUM(b.costo), '$99G999G999') AS TOTAL_RECAUDADO,
        
        
        INITCAP(u.nombre) AS UNIDAD_MÉDICA
    FROM MEDICO m
    INNER JOIN BONO_CONSULTA b
        ON m.rut_med = b.rut_med
    INNER JOIN UNIDAD_CONSULTA u
        ON m.uni_id = u.uni_id
    WHERE 
        EXTRACT(YEAR FROM b.fecha_bono) = EXTRACT(YEAR FROM SYSDATE) - 1
        AND m.car_id NOT IN (100, 500, 600)
    GROUP BY
        m.rut_med, 
        m.dv_run, 
        m.pnombre, 
        m.apaterno, 
        m.amaterno, 
        u.nombre
    ORDER BY 
        SUM(b.costo) ASC;

-- Verificación Caso 1
SELECT * FROM RECAUDACION_BONOS_MEDICOS;


/* =============================================================================
   CASO 2: PÉRDIDAS POR ESPECIALIDAD 
   ============================================================================= */

SELECT
    UPPER(e.nombre) AS "ESPECIALIDAD MÉDICA",
    COUNT(b.id_bono) AS "CANTIDAD BONOS",
    TO_CHAR(SUM(b.costo), '$999G999G999') AS "MONTO PÉRDIDA",
    TO_CHAR(MIN(b.fecha_bono), 'DD-MM-YYYY') AS "FECHA BONO",
    CASE 
        WHEN EXTRACT(YEAR FROM MIN(b.fecha_bono)) >= EXTRACT(YEAR FROM SYSDATE) - 1 
        THEN 'COBRABLE'
        ELSE 'INCOBRABLE'
    END AS "ESTADO DE COBRO"
FROM BONO_CONSULTA b
INNER JOIN DET_ESPECIALIDAD_MED dem 
    ON b.rut_med = dem.rut_med
INNER JOIN ESPECIALIDAD_MEDICA e 
    ON dem.esp_id = e.esp_id
WHERE b.id_bono IN (
    SELECT id_bono FROM BONO_CONSULTA 
    MINUS 
    SELECT id_bono FROM PAGOS
)
GROUP BY e.nombre
ORDER BY "CANTIDAD BONOS" ASC, SUM(b.costo) DESC;


/* =============================================================================
   CASO 3: PROYECCIÓN PRESUPUESTARIA
   ============================================================================= */

TRUNCATE TABLE CANT_BONOS_PACIENTES_ANNIO;

INSERT INTO CANT_BONOS_PACIENTES_ANNIO 
    (ANNIO_CALCULO, PAC_RUN, DV_RUN, EDAD, CANTIDAD_BONOS, MONTO_TOTAL_BONOS, SISTEMA_SALUD)
SELECT
    EXTRACT(YEAR FROM SYSDATE),
    p.pac_run,
    p.dv_run,
    TRUNC(MONTHS_BETWEEN(SYSDATE, p.fecha_nacimiento) / 12),
    COUNT(b.id_bono),
    NVL(SUM(b.costo), 0),
    s.descripcion
FROM PACIENTE p
INNER JOIN SALUD sal 
    ON p.sal_id = sal.sal_id
INNER JOIN SISTEMA_SALUD s 
    ON sal.tipo_sal_id = s.tipo_sal_id
LEFT JOIN BONO_CONSULTA b 
    ON p.pac_run = b.pac_run 
    AND EXTRACT(YEAR FROM b.fecha_bono) = EXTRACT(YEAR FROM SYSDATE) - 1
GROUP BY 
    p.pac_run, 
    p.dv_run, 
    p.fecha_nacimiento, 
    s.descripcion
HAVING COUNT(b.id_bono) <= (
    SELECT ROUND(AVG(COUNT(id_bono)))
    FROM BONO_CONSULTA
    WHERE EXTRACT(YEAR FROM fecha_bono) = EXTRACT(YEAR FROM SYSDATE) - 1
    GROUP BY pac_run
)
ORDER BY 6 ASC, 4 DESC;

COMMIT;

-- Verificación Caso 3
SELECT * FROM CANT_BONOS_PACIENTES_ANNIO;