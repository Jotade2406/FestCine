-- ============================================================================
--  FESTCINE - Script 06: Opinión del público (reseñas con estrellas) - migración
--  Motor: MySQL 8.0+ / 9.x  |  Ejecutar como root SOBRE una base ya creada.
--
--  Agrega la tabla 'resena', su procedimiento y vistas, y unas reseñas de
--  ejemplo, SIN borrar los datos actuales. En una reconstrucción limpia
--  (01 -> 02 -> 03) estos objetos ya vienen incluidos, así que este script
--  solo hace falta para actualizar una base que ya estaba cargada.
--
--  Es re-ejecutable (CREATE TABLE IF NOT EXISTS / DROP IF EXISTS / INSERT IGNORE).
-- ============================================================================

USE festcine;

-- ----------------------------------------------------------------------------
--  TABLA
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS resena (
    resena_id    INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    asistente_id INT UNSIGNED   NOT NULL,
    pelicula_id  INT UNSIGNED   NOT NULL,
    estrellas    TINYINT        NOT NULL,
    comentario   VARCHAR(500)   NULL,
    fecha_resena DATETIME       NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    PRIMARY KEY (resena_id),
    UNIQUE KEY uq_resena_asistente_pelicula (asistente_id, pelicula_id),
    CONSTRAINT fk_resena_asistente FOREIGN KEY (asistente_id) REFERENCES asistente (asistente_id),
    CONSTRAINT fk_resena_pelicula  FOREIGN KEY (pelicula_id)  REFERENCES pelicula (pelicula_id),
    CONSTRAINT chk_resena_estrellas CHECK (estrellas BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
--  PROCEDIMIENTO
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_calificar_pelicula;

DELIMITER $$

CREATE PROCEDURE sp_calificar_pelicula(
    IN  p_asistente_id INT UNSIGNED,
    IN  p_pelicula_id  INT UNSIGNED,
    IN  p_estrellas    TINYINT,
    IN  p_comentario   VARCHAR(500),
    OUT p_resultado    VARCHAR(255)    -- resultado de la operación (rúbrica)
)
BEGIN
    DECLARE v_titulo VARCHAR(200);
    DECLARE v_existe TINYINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_estrellas IS NULL OR p_estrellas < 1 OR p_estrellas > 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La calificacion debe estar entre 1 y 5 estrellas';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM asistente WHERE asistente_id = p_asistente_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El asistente indicado no existe';
    END IF;

    SELECT titulo INTO v_titulo FROM pelicula WHERE pelicula_id = p_pelicula_id;
    IF v_titulo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La pelicula indicada no existe';
    END IF;

    SET v_existe = EXISTS (SELECT 1 FROM resena
                           WHERE asistente_id = p_asistente_id AND pelicula_id = p_pelicula_id);

    START TRANSACTION;

    INSERT INTO resena (asistente_id, pelicula_id, estrellas, comentario)
    VALUES (p_asistente_id, p_pelicula_id, p_estrellas, NULLIF(TRIM(p_comentario), '')) AS nueva
    ON DUPLICATE KEY UPDATE estrellas    = nueva.estrellas,
                            comentario   = nueva.comentario,
                            fecha_resena = CURRENT_TIMESTAMP;

    COMMIT;

    SET p_resultado = CONCAT(IF(v_existe, 'Actualizaste tu resena de "', 'Gracias por tu resena de "'),
                             v_titulo, '": ', p_estrellas, ' de 5 estrellas');

    SELECT p_pelicula_id AS pelicula_id, p_estrellas AS estrellas;
END$$

DELIMITER ;

-- ----------------------------------------------------------------------------
--  VISTAS
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_resenas_pelicula;
DROP VIEW IF EXISTS v_resenas;

CREATE VIEW v_resenas_pelicula AS
SELECT  r.pelicula_id,
        COUNT(*)                   AS num_resenas,
        ROUND(AVG(r.estrellas), 1) AS promedio
FROM resena r
GROUP BY r.pelicula_id;

CREATE VIEW v_resenas AS
SELECT  r.resena_id,
        r.pelicula_id,
        r.asistente_id,
        CONCAT(a.nombre, ' ', a.apellidos) AS asistente,
        r.estrellas,
        r.comentario,
        r.fecha_resena
FROM resena r
JOIN asistente a ON a.asistente_id = r.asistente_id
ORDER BY r.fecha_resena DESC, r.resena_id DESC;

-- ----------------------------------------------------------------------------
--  DATOS DE EJEMPLO (no se duplican gracias al UNIQUE + INSERT IGNORE)
-- ----------------------------------------------------------------------------
INSERT IGNORE INTO resena (asistente_id, pelicula_id, estrellas, comentario) VALUES
( 5,  5, 5, 'Obra maestra, me dejó sin palabras.'),
( 6,  5, 5, 'La mejor del festival, sin duda.'),
( 7,  5, 4, 'Intensa y muy bien actuada.'),
( 8,  5, 5, 'Spielberg en estado puro.'),
(15,  5, 4, 'Larga, pero valió cada minuto.'),
( 9,  3, 4, 'Grogu se roba la película.'),
(10,  3, 5, 'Nostalgia y acción de la buena.'),
(11,  3, 3, 'Entretenida, aunque predecible.'),
(12,  3, 4, 'Para fans es imperdible.'),
(13,  2, 4, 'Terror con clase, la muñeca aterra.'),
(14,  2, 3, 'Buen ambiente, final flojo.'),
(16,  2, 4, 'Me hizo saltar varias veces.'),
(17, 10, 5, 'Lloré como un niño, hermosa.'),
(18, 10, 4, 'Pixar sigue tocando el corazón.'),
(19, 10, 4, 'Divertida para toda la familia.'),
(20,  4, 5, 'Animación desbordante y original.'),
(21,  4, 4, 'Un viaje visual alucinante.'),
(22,  6, 3, 'Risas garantizadas, humor absurdo.'),
( 5,  6, 2, 'Algunos chistes no envejecieron bien.'),
( 9, 13, 4, 'Biopic emotivo y muy musical.');

-- El usuario festcine_app ya tiene GRANT SELECT, EXECUTE ON festcine.*
