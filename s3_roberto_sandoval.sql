SELECT nro_propiedad "PROPIEDAD",UPPER(direccion_propiedad) "DIRECCION", TO_CHAR(valor_arriendo, '$999G999G999') "ARRIENDO", TO_CHAR(valor_gasto_comun, '$999G999G999') "GGCC_ACTUAL",
TO_CHAR(valor_gasto_comun * 1.1, '$999G999G999') "GGCC_AJUSTADO", ('Propiedad ubicada en comuna ' || id_comuna) "UBICACION"
FROM propiedad
WHERE id_comuna IN (82, 84, 87) AND nro_dormitorios IS NOT NULL AND valor_arriendo < &VALOR_MAXIMO
ORDER BY "GGCC_ACTUAL" ASC NULLS LAST, "ARRIENDO" DESC;


SELECT nro_propiedad "Propiedad", numrut_cli "Codigo Arrendatario", TO_CHAR(fecini_arriendo, 'DD. mon. YYYY') "Fecha Inicio Arriendo",
NVL(TO_CHAR(fecter_arriendo,'DD. mon. YYYY'), 'PROPIEDAD ACTUALMENTE ARRENDAD') "Fecha Termino Arriendo",
TO_CHAR(ROUND(NVL(fecter_arriendo, SYSDATE) - fecini_arriendo), '99G999') "Dias Arriendo",
ROUND(MONTHS_BETWEEN(NVL(fecter_arriendo, SYSDATE), fecini_arriendo) / 12) "Años Arriendo",
CASE
    WHEN (NVL(fecter_arriendo, SYSDATE) - fecini_arriendo) / 365 >= 10 THEN 'COMPROMISO DE VENTA'
    WHEN (NVL(fecter_arriendo, SYSDATE) - fecini_arriendo) / 365 >= 5  THEN 'CLIENTE ANTIGUO'
    ELSE 'CLIENTE NUEVO'
END "Clasificacion Estado" 
FROM arriendo_propiedad
WHERE (NVL(fecter_arriendo, SYSDATE) - fecini_arriendo) >= &MINIMO_DIAS
ORDER BY (NVL(fecter_arriendo, SYSDATE) - fecini_arriendo) DESC;  

SELECT 
nro_propiedad "Propiedad", numrut_cli "Codigo Arrendatario", TO_CHAR(fecini_arriendo, 'dd.mon.yyyy') "Fecha Inicio Arriendo",
NVL(TO_CHAR(fecter_arriendo, 'dd.mon.yyyy'), 'PROPIEDAD ACTUALMENTE ARRENDADA') "Fecha Termino Arriendo", 
TO_CHAR(ROUND(NVL(fecter_arriendo, TO_DATE('07-10-2026', 'DD-MM-YYYY')) - fecini_arriendo), '9G999') "Dias Arriendo",
ROUND((NVL(fecter_arriendo, TO_DATE('07-10-2026', 'DD-MM-YYYY')) - fecini_arriendo) / 365) "Años Arriendo",
CASE
    WHEN (NVL(fecter_arriendo, TO_DATE('07-10-2026', 'DD-MM-YYYY')) - fecini_arriendo) / 365 >= 10 THEN 'COMPROMISO DE VENTA'
    WHEN (NVL(fecter_arriendo, TO_DATE('07-10-2026', 'DD-MM-YYYY')) - fecini_arriendo) / 365 >= 5  THEN 'CLIENTE ANTIGUO'
    ELSE 'CLIENTE NUEVO'
END "Clasificacion Estado"      
FROM arriendo_propiedad
WHERE (NVL(fecter_arriendo, TO_DATE('07-10-2026', 'DD-MM-YYYY')) - fecini_arriendo) >= &MINIMO_DIAS
ORDER BY "Dias Arriendo" DESC;


SELECT id_tipo_propiedad "TIPO PROPIEDAD",
CASE id_tipo_propiedad
    WHEN 'A' THEN 'Casa'
    WHEN 'B' THEN 'Departamento'
    WHEN 'C' THEN 'Local'
    WHEN 'D' THEN 'Parcela sin casa'
    WHEN 'E' THEN 'Parcela con casa'
END "DESCRIPCION",
LPAD(TO_CHAR(AVG(valor_gasto_comun), '$999G999G999'), 20) "PRMEDIO GASTO COMUN", COUNT(id_tipo_propiedad) "CANTIDAD PROPIEDADES",
LPAD(TO_CHAR(AVG(valor_arriendo), '$999G999G999'), 23) "PROMEDIO VALOR ARRIENDO"
FROM propiedad
HAVING AVG(valor_arriendo) >= &MINIMO_PROMEDIO_ARRIENDO
GROUP BY id_tipo_propiedad 
ORDER BY "TIPO PROPIEDAD";