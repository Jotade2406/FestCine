-- ============================================================================
--  FESTCINE - Script 04: Consultas avanzadas (DQL) - Fase 3
--  Estas consultas también están publicadas como vistas (v_ranking_peliculas,
--  v_acta_premiacion, v_informe_financiero) para consumo de la aplicación.
-- ============================================================================

USE festcine;

-- ============================================================================
--  C1. RANKING DE PELÍCULAS — Edición vigente
--  Películas más vistas calculando el % de ocupación de las salas:
--  asistentes reales (entradas individuales + códigos de abono canjeados)
--  contra la capacidad total de las salas donde se proyectó.
-- ============================================================================
SELECT  p.titulo                                AS pelicula,
        COUNT(DISTINCT pr.proyeccion_id)        AS funciones,
        COALESCE(SUM(oc.asistentes), 0)         AS asistentes_reales,
        SUM(s.capacidad)                        AS capacidad_total,
        CONCAT(ROUND(COALESCE(SUM(oc.asistentes), 0) * 100.0 / SUM(s.capacidad), 1), ' %')
                                                AS ocupacion
FROM pelicula p
JOIN edicion  e  ON e.edicion_id  = p.edicion_id
JOIN proyeccion pr ON pr.pelicula_id = p.pelicula_id
JOIN sala     s  ON s.sala_id     = pr.sala_id
LEFT JOIN (
        -- Asistencia real por proyección: entradas + canjes de abono
        SELECT t.proyeccion_id, COUNT(*) AS asistentes
        FROM (
            SELECT proyeccion_id FROM entrada       WHERE proyeccion_id IS NOT NULL
            UNION ALL
            SELECT proyeccion_id FROM codigo_acceso WHERE usado = 1 AND proyeccion_id IS NOT NULL
        ) t
        GROUP BY t.proyeccion_id
     ) oc ON oc.proyeccion_id = pr.proyeccion_id
WHERE e.anio = (SELECT MAX(anio) FROM edicion)      -- edición vigente
GROUP BY p.pelicula_id, p.titulo
ORDER BY asistentes_reales DESC, ocupacion DESC;

-- ============================================================================
--  C2. ACTA DE PREMIACIÓN
--  Películas ganadoras por categoría con el promedio de votación del jurado.
-- ============================================================================
SELECT  e.anio                          AS edicion,
        c.nombre                        AS categoria,
        p.titulo                        AS pelicula_ganadora,
        p.pais_origen                   AS pais,
        ROUND(AVG(ev.puntuacion), 2)    AS promedio_jurado,
        COUNT(ev.evaluacion_id)         AS votos_emitidos,
        pr.fecha_otorgamiento
FROM premio pr
JOIN categoria c ON c.categoria_id = pr.categoria_id
JOIN edicion   e ON e.edicion_id   = c.edicion_id
JOIN pelicula  p ON p.pelicula_id  = pr.pelicula_id
LEFT JOIN evaluacion ev ON ev.categoria_id = pr.categoria_id
                       AND ev.pelicula_id  = pr.pelicula_id
GROUP BY e.anio, c.nombre, p.titulo, p.pais_origen, pr.fecha_otorgamiento
ORDER BY e.anio DESC, c.nombre;

-- ============================================================================
--  C3. INFORME FINANCIERO
--  Total recaudado desglosado por tipo de venta (Entradas vs Abonos)
--  y por tipo de tarifa. WITH ROLLUP agrega subtotales y total general.
-- ============================================================================
SELECT  COALESCE(v.tipo_venta, 'TOTAL GENERAL') AS tipo_venta,
        COALESCE(t.nombre,
                 IF(v.tipo_venta IS NULL, '', 'Subtotal')) AS tarifa,
        COUNT(d.precio_pagado)       AS unidades,
        SUM(d.precio_pagado)         AS total_recaudado
FROM (
        SELECT venta_id, tarifa_id, precio_pagado FROM entrada
        UNION ALL
        SELECT venta_id, tarifa_id, precio_pagado FROM abono
     ) d
JOIN venta  v ON v.venta_id  = d.venta_id
JOIN tarifa t ON t.tarifa_id = d.tarifa_id
GROUP BY v.tipo_venta, t.nombre WITH ROLLUP
ORDER BY GROUPING(v.tipo_venta), v.tipo_venta, GROUPING(t.nombre), total_recaudado DESC;

-- ============================================================================
--  CONSULTAS COMPLEMENTARIAS (apoyo a la demostración)
-- ============================================================================

-- C4. Ocupación detallada por función (apoya al ranking C1)
SELECT  pr.proyeccion_id,
        p.titulo,
        s.nombre                            AS sala,
        pr.fecha_hora,
        s.capacidad,
        s.capacidad - pr.aforo_disponible   AS asistentes,
        CONCAT(ROUND((s.capacidad - pr.aforo_disponible) * 100.0 / s.capacidad, 1), ' %')
                                            AS ocupacion
FROM proyeccion pr
JOIN pelicula p ON p.pelicula_id = pr.pelicula_id
JOIN sala     s ON s.sala_id     = pr.sala_id
ORDER BY pr.fecha_hora;

-- C5. Promedios completos de la competición (no solo ganadoras):
--     tabla de posiciones por categoría de la edición vigente
SELECT  c.nombre                        AS categoria,
        p.titulo                        AS pelicula,
        ROUND(AVG(ev.puntuacion), 2)    AS promedio,
        COUNT(ev.evaluacion_id)         AS votos,
        RANK() OVER (PARTITION BY c.categoria_id ORDER BY AVG(ev.puntuacion) DESC) AS posicion
FROM evaluacion ev
JOIN categoria c ON c.categoria_id = ev.categoria_id
JOIN pelicula  p ON p.pelicula_id  = ev.pelicula_id
JOIN edicion   e ON e.edicion_id   = c.edicion_id
WHERE e.anio = (SELECT MAX(anio) FROM edicion)
GROUP BY c.categoria_id, c.nombre, p.pelicula_id, p.titulo
ORDER BY categoria, posicion;

-- C6. Recaudo histórico por edición (ventas + patrocinios económicos)
SELECT  e.anio,
        (SELECT COALESCE(SUM(pa.monto), 0)
           FROM patrocinio pa
          WHERE pa.edicion_id = e.edicion_id
            AND pa.tipo_aporte = 'Economica')   AS patrocinio_economico,
        COUNT(DISTINCT pe.pelicula_id)          AS peliculas_postuladas
FROM edicion e
LEFT JOIN pelicula pe ON pe.edicion_id = e.edicion_id
GROUP BY e.edicion_id, e.anio
ORDER BY e.anio DESC;
