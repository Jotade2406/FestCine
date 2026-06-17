-- ============================================================================
--  FESTCINE - Script 05: Módulo de calificación del jurado (migración)
--  Motor: MySQL 8.0+ / 9.x  |  Ejecutar como root SOBRE una base ya creada.
--
--  Para qué sirve: agrega el procedimiento y las vistas que necesita la nueva
--  pantalla "Calificar" del perfil Administrador SIN borrar los datos actuales.
--  En una reconstrucción limpia (01 -> 02 -> 03) estos mismos objetos ya
--  vienen incluidos en 02_programacion.sql, así que este script solo hace
--  falta para actualizar una base que ya estaba cargada.
--
--  Es re-ejecutable: primero elimina los objetos si existen y los vuelve a crear.
-- ============================================================================

USE festcine;

DROP PROCEDURE IF EXISTS sp_registrar_evaluacion;
DROP VIEW IF EXISTS v_categorias;
DROP VIEW IF EXISTS v_competidoras;
DROP VIEW IF EXISTS v_jurados;
DROP VIEW IF EXISTS v_evaluaciones;

-- ----------------------------------------------------------------------------
--  PROCEDIMIENTO: Registrar la calificación de un jurado
-- ----------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE sp_registrar_evaluacion(
    IN  p_categoria_id INT UNSIGNED,
    IN  p_pelicula_id  INT UNSIGNED,
    IN  p_persona_id   INT UNSIGNED,
    IN  p_puntuacion   TINYINT,
    IN  p_comentario   VARCHAR(500),
    OUT p_resultado    VARCHAR(255)    -- resultado de la operación (rúbrica)
)
BEGIN
    DECLARE v_categoria VARCHAR(100);
    DECLARE v_pelicula  VARCHAR(200);
    DECLARE v_jurado    VARCHAR(161);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Validaciones de negocio (mensajes amigables antes de tocar las FK)
    IF p_puntuacion IS NULL OR p_puntuacion < 1 OR p_puntuacion > 10 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La puntuacion debe estar entre 1 y 10';
    END IF;

    SELECT nombre INTO v_categoria FROM categoria WHERE categoria_id = p_categoria_id;
    IF v_categoria IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoria indicada no existe';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pelicula_categoria
                   WHERE categoria_id = p_categoria_id AND pelicula_id = p_pelicula_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La pelicula no compite en esa categoria';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM categoria_jurado
                   WHERE categoria_id = p_categoria_id AND persona_id = p_persona_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La persona indicada no es jurado de esa categoria';
    END IF;

    IF EXISTS (SELECT 1 FROM evaluacion
               WHERE categoria_id = p_categoria_id
                 AND pelicula_id  = p_pelicula_id
                 AND persona_id   = p_persona_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ese jurado ya califico esta pelicula en esta categoria';
    END IF;

    START TRANSACTION;

    INSERT INTO evaluacion (categoria_id, pelicula_id, persona_id, puntuacion, comentario)
    VALUES (p_categoria_id, p_pelicula_id, p_persona_id, p_puntuacion,
            NULLIF(TRIM(p_comentario), ''));

    COMMIT;

    SELECT titulo INTO v_pelicula FROM pelicula WHERE pelicula_id = p_pelicula_id;
    SELECT CONCAT(nombre, ' ', apellidos) INTO v_jurado FROM persona WHERE persona_id = p_persona_id;

    SET p_resultado = CONCAT('OK: ', v_jurado, ' califico "', v_pelicula, '" con ',
                             p_puntuacion, '/10 en ', v_categoria);

    SELECT LAST_INSERT_ID() AS evaluacion_id;
END$$

DELIMITER ;

-- ----------------------------------------------------------------------------
--  VISTAS (edición vigente)
-- ----------------------------------------------------------------------------
CREATE VIEW v_categorias AS
SELECT  c.categoria_id,
        c.nombre AS categoria,
        c.descripcion,
        e.anio   AS edicion
FROM categoria c
JOIN edicion e ON e.edicion_id = c.edicion_id
WHERE e.anio = (SELECT MAX(anio) FROM edicion)
ORDER BY c.nombre;

CREATE VIEW v_competidoras AS
SELECT  pc.categoria_id,
        pc.pelicula_id,
        p.titulo,
        p.pais_origen
FROM pelicula_categoria pc
JOIN pelicula p  ON p.pelicula_id  = pc.pelicula_id
JOIN categoria c ON c.categoria_id = pc.categoria_id
JOIN edicion e   ON e.edicion_id   = c.edicion_id
WHERE e.anio = (SELECT MAX(anio) FROM edicion)
ORDER BY p.titulo;

CREATE VIEW v_jurados AS
SELECT  cj.categoria_id,
        cj.persona_id,
        CONCAT(pe.nombre, ' ', pe.apellidos) AS jurado,
        pe.nacionalidad
FROM categoria_jurado cj
JOIN persona pe  ON pe.persona_id  = cj.persona_id
JOIN categoria c ON c.categoria_id = cj.categoria_id
JOIN edicion e   ON e.edicion_id   = c.edicion_id
WHERE e.anio = (SELECT MAX(anio) FROM edicion)
ORDER BY jurado;

CREATE VIEW v_evaluaciones AS
SELECT  ev.evaluacion_id,
        c.nombre AS categoria,
        p.titulo AS pelicula,
        CONCAT(pe.nombre, ' ', pe.apellidos) AS jurado,
        ev.puntuacion,
        ev.comentario,
        ev.fecha_evaluacion
FROM evaluacion ev
JOIN categoria c ON c.categoria_id = ev.categoria_id
JOIN edicion e   ON e.edicion_id   = c.edicion_id
JOIN pelicula p  ON p.pelicula_id  = ev.pelicula_id
JOIN persona pe  ON pe.persona_id  = ev.persona_id
WHERE e.anio = (SELECT MAX(anio) FROM edicion)
ORDER BY ev.fecha_evaluacion DESC, ev.evaluacion_id DESC;

-- El usuario festcine_app ya tiene GRANT SELECT, EXECUTE ON festcine.* ,
-- así que puede leer las nuevas vistas y ejecutar el procedimiento sin más.
