-- ============================================================================
--  FESTCINE - Script 02: Programación en la base de datos - Fase 4
--  Funciones, Procedimientos almacenados, Triggers y Vistas
--  Motor: MySQL 8.0+ / 9.x  |  Ejecutar DESPUÉS de 01_esquema.sql
-- ============================================================================

USE festcine;

-- ============================================================================
--  F1. FUNCIÓN: precio final según tarifa
--  Aplica el porcentaje de descuento de la tarifa sobre un precio base.
-- ============================================================================
DELIMITER $$

CREATE FUNCTION f_precio_final(p_precio_base DECIMAL(10,2), p_tarifa_id INT UNSIGNED)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_descuento DECIMAL(5,2);

    SELECT descuento_pct INTO v_descuento
    FROM tarifa
    WHERE tarifa_id = p_tarifa_id;

    IF v_descuento IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La tarifa indicada no existe';
    END IF;

    RETURN ROUND(p_precio_base * (1 - v_descuento / 100), 2);
END$$

-- ============================================================================
--  TR1. TRIGGER: Control de Agenda (BEFORE INSERT en proyeccion)
--  Impide programar una película en una sala ocupada en ese rango horario.
--  Rango ocupado = [inicio, inicio + duración de la película + 30 min limpieza]
--  Además inicializa el aforo disponible con la capacidad de la sala.
-- ============================================================================
CREATE TRIGGER trg_proyeccion_bi
BEFORE INSERT ON proyeccion
FOR EACH ROW
BEGIN
    DECLARE v_duracion   INT;
    DECLARE v_fin        DATETIME;
    DECLARE v_conflictos INT;
    DECLARE v_capacidad  INT;

    SELECT duracion_min INTO v_duracion
    FROM pelicula
    WHERE pelicula_id = NEW.pelicula_id;

    SET v_fin = DATE_ADD(NEW.fecha_hora, INTERVAL v_duracion + 30 MINUTE);

    -- Dos rangos [a1,a2] y [b1,b2] se cruzan si a1 < b2 y b1 < a2
    SELECT COUNT(*) INTO v_conflictos
    FROM proyeccion pr
    JOIN pelicula pe ON pe.pelicula_id = pr.pelicula_id
    WHERE pr.sala_id = NEW.sala_id
      AND NEW.fecha_hora < DATE_ADD(pr.fecha_hora, INTERVAL pe.duracion_min + 30 MINUTE)
      AND pr.fecha_hora  < v_fin;

    IF v_conflictos > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Control de agenda: la sala ya esta ocupada por otra proyeccion en ese rango horario (incluye 30 min de limpieza)';
    END IF;

    -- Inicializar el contador desnormalizado de aforo
    IF NEW.aforo_disponible IS NULL THEN
        SELECT capacidad INTO v_capacidad FROM sala WHERE sala_id = NEW.sala_id;
        SET NEW.aforo_disponible = v_capacidad;
    END IF;
END$$

-- Variante BEFORE UPDATE: protege la agenda también ante reprogramaciones.
-- Solo valida si cambió la sala, la fecha o la película (no en cada venta,
-- que únicamente descuenta aforo_disponible).
CREATE TRIGGER trg_proyeccion_bu
BEFORE UPDATE ON proyeccion
FOR EACH ROW
BEGIN
    DECLARE v_duracion   INT;
    DECLARE v_fin        DATETIME;
    DECLARE v_conflictos INT;

    IF NOT (NEW.sala_id = OLD.sala_id
            AND NEW.fecha_hora = OLD.fecha_hora
            AND NEW.pelicula_id = OLD.pelicula_id) THEN

        SELECT duracion_min INTO v_duracion
        FROM pelicula
        WHERE pelicula_id = NEW.pelicula_id;

        SET v_fin = DATE_ADD(NEW.fecha_hora, INTERVAL v_duracion + 30 MINUTE);

        SELECT COUNT(*) INTO v_conflictos
        FROM proyeccion pr
        JOIN pelicula pe ON pe.pelicula_id = pr.pelicula_id
        WHERE pr.sala_id = NEW.sala_id
          AND pr.proyeccion_id <> NEW.proyeccion_id
          AND NEW.fecha_hora < DATE_ADD(pr.fecha_hora, INTERVAL pe.duracion_min + 30 MINUTE)
          AND pr.fecha_hora  < v_fin;

        IF v_conflictos > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Control de agenda: la sala ya esta ocupada por otra proyeccion en ese rango horario (incluye 30 min de limpieza)';
        END IF;
    END IF;
END$$

-- ============================================================================
--  P1. PROCEDIMIENTO: Proceso de Compra de Entrada
--  Verifica aforo de la proyección; si hay cupo registra venta + pago +
--  entrada y descuenta el aforo; si no, lanza un error.
-- ============================================================================
CREATE PROCEDURE sp_comprar_entrada(
    IN  p_asistente_id  INT UNSIGNED,
    IN  p_proyeccion_id INT UNSIGNED,
    IN  p_tarifa_id     INT UNSIGNED,
    OUT p_resultado     VARCHAR(255)    -- resultado de la operación (rúbrica)
)
BEGIN
    DECLARE v_aforo       INT;
    DECLARE v_precio_base DECIMAL(10,2);
    DECLARE v_precio      DECIMAL(10,2);
    DECLARE v_venta_id    INT UNSIGNED;
    DECLARE v_codigo      VARCHAR(20);
    DECLARE v_subtotal    DECIMAL(10,2);
    DECLARE v_factura     VARCHAR(20);

    -- Ante cualquier error: deshacer todo y propagar el error al cliente
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM asistente WHERE asistente_id = p_asistente_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El asistente indicado no existe';
    END IF;

    START TRANSACTION;

    -- Bloqueo de la fila para evitar sobreventa con compras concurrentes
    SELECT aforo_disponible, precio_base INTO v_aforo, v_precio_base
    FROM proyeccion
    WHERE proyeccion_id = p_proyeccion_id
    FOR UPDATE;

    IF v_aforo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La proyeccion indicada no existe';
    END IF;

    IF v_aforo <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay aforo disponible para esta funcion';
    END IF;

    SET v_precio = f_precio_final(v_precio_base, p_tarifa_id);

    INSERT INTO venta (asistente_id, tipo_venta, total)
    VALUES (p_asistente_id, 'Entrada', v_precio);
    SET v_venta_id = LAST_INSERT_ID();

    -- Asunción: la venta en taquilla se registra como pago en efectivo aprobado
    INSERT INTO pago (venta_id, metodo, monto, estado)
    VALUES (v_venta_id, 'Efectivo', v_precio, 'Aprobado');

    SET v_codigo = CONCAT('ENT-', LPAD(v_venta_id, 8, '0'));

    INSERT INTO entrada (venta_id, proyeccion_id, tarifa_id, precio_pagado, codigo)
    VALUES (v_venta_id, p_proyeccion_id, p_tarifa_id, v_precio, v_codigo);

    UPDATE proyeccion
    SET aforo_disponible = aforo_disponible - 1
    WHERE proyeccion_id = p_proyeccion_id;

    -- Emitir la factura de la venta (IVA 19% incluido en el precio)
    SET v_subtotal = ROUND(v_precio / 1.19, 2);
    SET v_factura  = CONCAT('F-', YEAR(CURDATE()), '-', LPAD(v_venta_id, 6, '0'));
    INSERT INTO factura (venta_id, numero_factura, subtotal, impuestos, total)
    VALUES (v_venta_id, v_factura, v_subtotal, v_precio - v_subtotal, v_precio);

    COMMIT;

    SET p_resultado = CONCAT('OK: entrada ', v_codigo, ' emitida con factura ',
                             v_factura, '. Total pagado: $', FORMAT(v_precio, 0));

    -- Resultado para la aplicación cliente
    SELECT v_venta_id AS venta_id,
           v_codigo   AS codigo_entrada,
           v_factura  AS numero_factura,
           v_precio   AS precio_pagado;
END$$

-- ============================================================================
--  T1. TRANSACCIÓN CRÍTICA: Venta de Abono
--  Registra el pago, genera los códigos de acceso y emite la factura de
--  forma ATÓMICA. Si la pasarela de pago falla (p_pago_aprobado = 0) o los
--  datos son inconsistentes, se aplica ROLLBACK de toda la operación.
--  Asunción: IVA del 19% incluido en el precio (se desglosa en la factura).
-- ============================================================================
CREATE PROCEDURE sp_vender_abono(
    IN  p_asistente_id   INT UNSIGNED,
    IN  p_tipo_abono_id  INT UNSIGNED,
    IN  p_tarifa_id      INT UNSIGNED,
    IN  p_pago_aprobado  TINYINT,        -- 1 = pasarela aprueba, 0 = pasarela rechaza
    OUT p_resultado      VARCHAR(255)    -- resultado de la operación (rúbrica)
)
BEGIN
    DECLARE v_precio_base DECIMAL(10,2);
    DECLARE v_num_accesos SMALLINT;
    DECLARE v_precio      DECIMAL(10,2);
    DECLARE v_subtotal    DECIMAL(10,2);
    DECLARE v_venta_id    INT UNSIGNED;
    DECLARE v_abono_id    INT UNSIGNED;
    DECLARE v_codigo      VARCHAR(20);
    DECLARE v_factura     VARCHAR(20);
    DECLARE v_i           SMALLINT DEFAULT 1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM asistente WHERE asistente_id = p_asistente_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El asistente indicado no existe';
    END IF;

    SELECT precio_base, num_accesos INTO v_precio_base, v_num_accesos
    FROM tipo_abono
    WHERE tipo_abono_id = p_tipo_abono_id;

    IF v_precio_base IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de abono indicado no existe';
    END IF;

    START TRANSACTION;

    SET v_precio = f_precio_final(v_precio_base, p_tarifa_id);

    -- 1) Registrar la venta y el pago
    INSERT INTO venta (asistente_id, tipo_venta, total)
    VALUES (p_asistente_id, 'Abono', v_precio);
    SET v_venta_id = LAST_INSERT_ID();

    INSERT INTO pago (venta_id, metodo, monto, estado)
    VALUES (v_venta_id, 'Online', v_precio, IF(p_pago_aprobado = 1, 'Aprobado', 'Rechazado'));

    -- Simulación de la pasarela de pago: si rechaza, se deshace TODO
    IF p_pago_aprobado <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La pasarela de pago rechazo la transaccion. Operacion cancelada (ROLLBACK)';
    END IF;

    -- 2) Crear el abono y generar sus códigos de acceso
    INSERT INTO abono (venta_id, tipo_abono_id, tarifa_id, precio_pagado, codigo)
    VALUES (v_venta_id, p_tipo_abono_id, p_tarifa_id, v_precio, 'PENDIENTE');
    SET v_abono_id = LAST_INSERT_ID();

    SET v_codigo = CONCAT('ABO-', LPAD(v_abono_id, 6, '0'));
    UPDATE abono SET codigo = v_codigo WHERE abono_id = v_abono_id;

    WHILE v_i <= v_num_accesos DO
        INSERT INTO codigo_acceso (abono_id, codigo)
        VALUES (v_abono_id, CONCAT('ACC-', LPAD(v_abono_id, 4, '0'), '-', LPAD(v_i, 3, '0')));
        SET v_i = v_i + 1;
    END WHILE;

    -- 3) Emitir la factura (IVA 19% incluido en el precio)
    SET v_subtotal = ROUND(v_precio / 1.19, 2);
    SET v_factura  = CONCAT('F-', YEAR(CURDATE()), '-', LPAD(v_venta_id, 6, '0'));

    INSERT INTO factura (venta_id, numero_factura, subtotal, impuestos, total)
    VALUES (v_venta_id, v_factura, v_subtotal, v_precio - v_subtotal, v_precio);

    COMMIT;

    SET p_resultado = CONCAT('OK: abono ', v_codigo, ' emitido con ', v_num_accesos,
                             ' codigos de acceso y factura ', v_factura,
                             '. Total: $', FORMAT(v_precio, 0));

    SELECT v_venta_id   AS venta_id,
           v_codigo     AS codigo_abono,
           v_num_accesos AS codigos_generados,
           v_factura    AS numero_factura,
           v_precio     AS total_pagado;
END$$

-- ============================================================================
--  P2. PROCEDIMIENTO: Programar Proyección (usado por el Módulo 2 de la app)
--  Realiza el INSERT en proyeccion; el trigger TR1 valida el cruce de
--  horarios y, si lo hay, el error se propaga hasta la aplicación cliente.
-- ============================================================================
CREATE PROCEDURE sp_programar_proyeccion(
    IN  p_pelicula_id INT UNSIGNED,
    IN  p_sala_id     INT UNSIGNED,
    IN  p_fecha_hora  DATETIME,
    IN  p_precio_base DECIMAL(10,2),
    IN  p_tiene_qa    TINYINT,
    OUT p_resultado   VARCHAR(255)    -- resultado de la operación (rúbrica)
)
BEGIN
    DECLARE v_estado VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT estado INTO v_estado FROM pelicula WHERE pelicula_id = p_pelicula_id;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La pelicula indicada no existe';
    END IF;

    IF v_estado NOT IN ('Seleccionada', 'Premiada') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se pueden programar peliculas en estado Seleccionada o Premiada';
    END IF;

    START TRANSACTION;

    INSERT INTO proyeccion (pelicula_id, sala_id, fecha_hora, precio_base, tiene_qa)
    VALUES (p_pelicula_id, p_sala_id, p_fecha_hora, p_precio_base, IF(p_tiene_qa = 1, 1, 0));

    COMMIT;

    SET p_resultado = CONCAT('OK: proyeccion #', LAST_INSERT_ID(),
                             ' programada para el ', DATE_FORMAT(p_fecha_hora, '%d/%m/%Y %H:%i'));

    SELECT LAST_INSERT_ID() AS proyeccion_id;
END$$

-- ============================================================================
--  P3. PROCEDIMIENTO: Canjear código de acceso de un abono en una proyección
--  Controla el aforo igual que una entrada individual.
-- ============================================================================
CREATE PROCEDURE sp_usar_codigo_abono(
    IN p_codigo        VARCHAR(20),
    IN p_proyeccion_id INT UNSIGNED
)
BEGIN
    DECLARE v_codigo_id INT UNSIGNED;
    DECLARE v_usado     TINYINT;
    DECLARE v_aforo     INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT codigo_acceso_id, usado INTO v_codigo_id, v_usado
    FROM codigo_acceso
    WHERE codigo = p_codigo
    FOR UPDATE;

    IF v_codigo_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El codigo de acceso no existe';
    END IF;

    IF v_usado = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El codigo de acceso ya fue utilizado';
    END IF;

    SELECT aforo_disponible INTO v_aforo
    FROM proyeccion
    WHERE proyeccion_id = p_proyeccion_id
    FOR UPDATE;

    IF v_aforo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La proyeccion indicada no existe';
    END IF;

    IF v_aforo <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay aforo disponible para esta funcion';
    END IF;

    UPDATE codigo_acceso
    SET usado = 1, proyeccion_id = p_proyeccion_id, fecha_uso = NOW()
    WHERE codigo_acceso_id = v_codigo_id;

    UPDATE proyeccion
    SET aforo_disponible = aforo_disponible - 1
    WHERE proyeccion_id = p_proyeccion_id;

    COMMIT;

    SELECT 'OK' AS resultado, p_codigo AS codigo, p_proyeccion_id AS proyeccion_id;
END$$

-- ============================================================================
--  P4. PROCEDIMIENTO: Registro de asistente (cuenta de la aplicación)
--  La clave se almacena como hash SHA-256 calculado en el servidor.
-- ============================================================================
CREATE PROCEDURE sp_registrar_asistente(
    IN p_nombre    VARCHAR(80),
    IN p_apellidos VARCHAR(80),
    IN p_email     VARCHAR(120),
    IN p_usuario   VARCHAR(30),
    IN p_clave     VARCHAR(100),
    IN p_telefono  VARCHAR(30)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF CHAR_LENGTH(TRIM(p_clave)) < 6 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La contrasena debe tener al menos 6 caracteres';
    END IF;

    IF CHAR_LENGTH(TRIM(p_usuario)) < 3 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre de usuario debe tener al menos 3 caracteres';
    END IF;

    IF EXISTS (SELECT 1 FROM asistente WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe una cuenta registrada con ese correo';
    END IF;

    IF EXISTS (SELECT 1 FROM asistente WHERE usuario = p_usuario) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese nombre de usuario ya esta en uso';
    END IF;

    START TRANSACTION;

    INSERT INTO asistente (nombre, apellidos, email, telefono, usuario, clave_hash)
    VALUES (TRIM(p_nombre), TRIM(p_apellidos), LOWER(TRIM(p_email)),
            NULLIF(TRIM(p_telefono), ''), TRIM(p_usuario), SHA2(p_clave, 256));

    COMMIT;

    SELECT LAST_INSERT_ID() AS asistente_id,
           CONCAT(TRIM(p_nombre), ' ', TRIM(p_apellidos)) AS nombre_completo;
END$$

-- ============================================================================
--  P5. PROCEDIMIENTO: Inicio de sesión de asistente
--  Acepta el correo O el nombre de usuario más la contraseña.
-- ============================================================================
CREATE PROCEDURE sp_login_asistente(
    IN p_login VARCHAR(120),
    IN p_clave VARCHAR(100)
)
BEGIN
    DECLARE v_id INT UNSIGNED;

    SELECT asistente_id INTO v_id
    FROM asistente
    WHERE (email = LOWER(TRIM(p_login)) OR usuario = TRIM(p_login))
      AND clave_hash = SHA2(p_clave, 256)
    LIMIT 1;

    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Correo/usuario o contrasena incorrectos';
    END IF;

    SELECT a.asistente_id,
           CONCAT(a.nombre, ' ', a.apellidos) AS nombre_completo,
           a.email,
           a.usuario
    FROM asistente a
    WHERE a.asistente_id = v_id;
END$$

-- ============================================================================
--  P6. PROCEDIMIENTO: Generador de datos para reportes (Fase 3 / rúbrica)
--  Devuelve el conjunto de datos del reporte solicitado:
--    'ranking'    -> películas más vistas con % de ocupación de salas
--    'acta'       -> acta de premiación con promedio del jurado
--    'financiero' -> recaudo por tipo de venta y tarifa
-- ============================================================================
CREATE PROCEDURE sp_generar_reporte(
    IN p_tipo VARCHAR(20)
)
BEGIN
    CASE LOWER(TRIM(p_tipo))
        WHEN 'ranking' THEN
            SELECT * FROM v_ranking_peliculas;
        WHEN 'acta' THEN
            SELECT * FROM v_acta_premiacion;
        WHEN 'financiero' THEN
            SELECT * FROM v_informe_financiero;
        ELSE
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Tipo de reporte no valido: use ranking, acta o financiero';
    END CASE;
END$$

-- ============================================================================
--  P7. PROCEDIMIENTO: Registrar la calificación de un jurado (Módulo Jurado)
--  Un miembro del jurado puntúa (1-10) una película dentro de una categoría.
--  Valida con mensajes amigables que: la categoría exista, la película compita
--  en ella, la persona sea jurado de esa categoría y no haya calificado ya esa
--  película (lo que el UNIQUE/las FK compuestas garantizan a nivel de motor).
-- ============================================================================
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

-- ============================================================================
--  P8. PROCEDIMIENTO: Calificación del público (reseña con estrellas 1-5)
--  Cualquier asistente puntúa una película desde la app. Si ya la había
--  reseñado, actualiza su nota (un voto por persona y película: UNIQUE).
-- ============================================================================
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

    -- Inserta o, si ya existía la reseña de ese asistente, la actualiza
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

-- ============================================================================
--  VISTAS OPERATIVAS (consumidas por la aplicación cliente - Fase 5)
-- ============================================================================

-- Cartelera: películas exhibibles de la edición vigente con sus géneros
CREATE VIEW v_cartelera AS
SELECT  p.pelicula_id,
        p.titulo,
        p.anio_produccion,
        p.duracion_min,
        p.pais_origen,
        p.sinopsis,
        p.clasificacion,
        p.formato,
        p.estado,
        p.poster,
        e.anio AS edicion,
        (SELECT GROUP_CONCAT(g.nombre ORDER BY g.nombre SEPARATOR ', ')
           FROM pelicula_genero pg
           JOIN genero g ON g.genero_id = pg.genero_id
          WHERE pg.pelicula_id = p.pelicula_id) AS generos
FROM pelicula p
JOIN edicion e ON e.edicion_id = p.edicion_id
WHERE p.estado IN ('Seleccionada', 'Premiada')
  AND e.anio = (SELECT MAX(anio) FROM edicion);

-- Agenda completa de proyecciones con sala, sede y ocupación
CREATE VIEW v_proyecciones AS
SELECT  pr.proyeccion_id,
        pr.pelicula_id,
        p.titulo,
        p.duracion_min,
        pr.fecha_hora,
        DATE_ADD(pr.fecha_hora, INTERVAL p.duracion_min MINUTE) AS fecha_hora_fin,
        DATE_ADD(pr.fecha_hora, INTERVAL p.duracion_min + 30 MINUTE) AS fecha_hora_libre,
        s.sala_id,
        s.nombre  AS sala,
        sd.nombre AS sede,
        sd.direccion AS sede_direccion,
        s.capacidad,
        pr.aforo_disponible,
        s.capacidad - pr.aforo_disponible AS asistentes,
        pr.precio_base,
        pr.tiene_qa
FROM proyeccion pr
JOIN pelicula p ON p.pelicula_id = pr.pelicula_id
JOIN sala s     ON s.sala_id     = pr.sala_id
JOIN sede sd    ON sd.sede_id    = s.sede_id;

CREATE VIEW v_salas AS
SELECT s.sala_id, s.nombre AS sala, sd.nombre AS sede, s.capacidad
FROM sala s
JOIN sede sd ON sd.sede_id = s.sede_id;

CREATE VIEW v_tarifas AS
SELECT tarifa_id, nombre, descuento_pct
FROM tarifa;

CREATE VIEW v_tipos_abono AS
SELECT tipo_abono_id, nombre, descripcion, precio_base, num_accesos
FROM tipo_abono;

CREATE VIEW v_asistentes AS
SELECT  a.asistente_id,
        CONCAT(a.nombre, ' ', a.apellidos) AS nombre_completo,
        a.email,
        COALESCE(ac.tipo, 'Público General') AS acreditacion
FROM asistente a
LEFT JOIN acreditacion ac
       ON ac.asistente_id = a.asistente_id
      AND ac.edicion_id = (SELECT edicion_id FROM edicion
                           WHERE anio = (SELECT MAX(anio) FROM edicion));

-- ============================================================================
--  VISTAS DE COMPETICIÓN / JURADO (módulo "Calificar" del perfil Administrador)
--  Todas se limitan a la edición vigente (mismo criterio que v_cartelera).
-- ============================================================================

-- Categorías en competición de la edición vigente
CREATE VIEW v_categorias AS
SELECT  c.categoria_id,
        c.nombre AS categoria,
        c.descripcion,
        e.anio   AS edicion
FROM categoria c
JOIN edicion e ON e.edicion_id = c.edicion_id
WHERE e.anio = (SELECT MAX(anio) FROM edicion)
ORDER BY c.nombre;

-- Películas que compiten en cada categoría (poblar el desplegable de película)
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

-- Jurados asignados a cada categoría (poblar el desplegable de jurado)
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

-- Evaluaciones ya registradas (tabla de seguimiento del panel de jurado)
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

-- ============================================================================
--  VISTAS DE OPINIÓN DEL PÚBLICO (reseñas con estrellas en la ficha de película)
-- ============================================================================

-- Valoración agregada por película: promedio de estrellas y nº de reseñas
CREATE VIEW v_resenas_pelicula AS
SELECT  r.pelicula_id,
        COUNT(*)                   AS num_resenas,
        ROUND(AVG(r.estrellas), 1) AS promedio
FROM resena r
GROUP BY r.pelicula_id;

-- Reseñas individuales (listado bajo la ficha de la película)
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

-- ============================================================================
--  VISTAS DE REPORTE (Fase 3; las consultas documentadas están en
--  04_consultas.sql, estas vistas exponen el mismo resultado a la app)
-- ============================================================================

-- R1. Ranking de películas más vistas (edición vigente) con % de ocupación.
-- "Asistentes reales" = entradas individuales vendidas + códigos de abono canjeados.
CREATE VIEW v_ranking_peliculas AS
SELECT  p.pelicula_id,
        p.titulo,
        COUNT(DISTINCT pr.proyeccion_id)        AS proyecciones,
        COALESCE(SUM(oc.asistentes), 0)         AS total_asistentes,
        SUM(s.capacidad)                        AS capacidad_total,
        ROUND(COALESCE(SUM(oc.asistentes), 0) * 100.0 / SUM(s.capacidad), 1)
                                                AS pct_ocupacion
FROM pelicula p
JOIN edicion e   ON e.edicion_id = p.edicion_id
JOIN proyeccion pr ON pr.pelicula_id = p.pelicula_id
JOIN sala s      ON s.sala_id = pr.sala_id
LEFT JOIN (
        SELECT t.proyeccion_id, COUNT(*) AS asistentes
        FROM (
            SELECT proyeccion_id FROM entrada      WHERE proyeccion_id IS NOT NULL
            UNION ALL
            SELECT proyeccion_id FROM codigo_acceso WHERE usado = 1 AND proyeccion_id IS NOT NULL
        ) t
        GROUP BY t.proyeccion_id
     ) oc ON oc.proyeccion_id = pr.proyeccion_id
WHERE e.anio = (SELECT MAX(anio) FROM edicion)
GROUP BY p.pelicula_id, p.titulo
ORDER BY total_asistentes DESC, pct_ocupacion DESC;

-- R2. Acta de premiación: ganadoras por categoría con su promedio de jurado
CREATE VIEW v_acta_premiacion AS
SELECT  e.anio                       AS edicion,
        c.nombre                     AS categoria,
        p.titulo                     AS pelicula_ganadora,
        p.pais_origen,
        ROUND(AVG(ev.puntuacion), 2) AS promedio_jurado,
        COUNT(ev.evaluacion_id)      AS votos_emitidos,
        pr.fecha_otorgamiento
FROM premio pr
JOIN categoria c  ON c.categoria_id = pr.categoria_id
JOIN edicion e    ON e.edicion_id   = c.edicion_id
JOIN pelicula p   ON p.pelicula_id  = pr.pelicula_id
LEFT JOIN evaluacion ev ON ev.categoria_id = pr.categoria_id
                       AND ev.pelicula_id  = pr.pelicula_id
GROUP BY e.anio, c.nombre, p.titulo, p.pais_origen, pr.fecha_otorgamiento
ORDER BY e.anio DESC, c.nombre;

-- R3. Informe financiero: recaudo por tipo de venta y tarifa
CREATE VIEW v_informe_financiero AS
SELECT  v.tipo_venta,
        t.nombre            AS tarifa,
        COUNT(*)            AS unidades_vendidas,
        SUM(d.precio_pagado) AS total_recaudado
FROM (
        SELECT venta_id, tarifa_id, precio_pagado FROM entrada
        UNION ALL
        SELECT venta_id, tarifa_id, precio_pagado FROM abono
     ) d
JOIN venta v  ON v.venta_id  = d.venta_id
JOIN tarifa t ON t.tarifa_id = d.tarifa_id
GROUP BY v.tipo_venta, t.nombre
ORDER BY v.tipo_venta, total_recaudado DESC;

-- Listado administrativo de ventas (módulo "Ventas" del perfil Administrador)
CREATE VIEW v_ventas AS
SELECT  v.venta_id,
        v.fecha_venta,
        CONCAT(a.nombre, ' ', a.apellidos) AS asistente,
        v.tipo_venta,
        p.metodo  AS metodo_pago,
        p.estado  AS estado_pago,
        v.total
FROM venta v
JOIN asistente a ON a.asistente_id = v.asistente_id
LEFT JOIN pago p ON p.venta_id = v.venta_id
ORDER BY v.fecha_venta DESC, v.venta_id DESC;

-- Compras de cada asistente (módulo "Mis compras" del perfil Cliente)
CREATE VIEW v_compras AS
SELECT  v.asistente_id,
        v.venta_id,
        v.fecha_venta,
        'Entrada'                       AS tipo,
        COALESCE(pe.titulo, ev.nombre)  AS concepto,
        pr.fecha_hora                   AS funcion,
        en.codigo,
        t.nombre                        AS tarifa,
        en.precio_pagado
FROM venta v
JOIN entrada en ON en.venta_id = v.venta_id
LEFT JOIN proyeccion pr ON pr.proyeccion_id = en.proyeccion_id
LEFT JOIN pelicula pe   ON pe.pelicula_id   = pr.pelicula_id
LEFT JOIN evento ev     ON ev.evento_id     = en.evento_id
JOIN tarifa t ON t.tarifa_id = en.tarifa_id
UNION ALL
SELECT  v.asistente_id,
        v.venta_id,
        v.fecha_venta,
        'Abono',
        CONCAT(ta.nombre, ' · ', ta.num_accesos, ' accesos'),
        NULL,
        ab.codigo,
        t.nombre,
        ab.precio_pagado
FROM venta v
JOIN abono ab ON ab.venta_id = v.venta_id
JOIN tipo_abono ta ON ta.tipo_abono_id = ab.tipo_abono_id
JOIN tarifa t ON t.tarifa_id = ab.tarifa_id;

-- Detalle completo de una factura (página de confirmación y PDF descargable)
CREATE VIEW v_factura_detalle AS
SELECT  f.factura_id,
        f.numero_factura,
        f.fecha_emision,
        f.subtotal,
        f.impuestos,
        f.total,
        v.venta_id,
        v.tipo_venta,
        v.asistente_id,
        CONCAT(a.nombre, ' ', a.apellidos)  AS asistente,
        a.email,
        COALESCE(en.codigo, ab.codigo)      AS codigo,
        COALESCE(pe.titulo, ev.nombre,
                 CONCAT(ta.nombre, ' · ', ta.num_accesos, ' accesos')) AS concepto,
        pe.poster,
        pe.clasificacion,
        pe.duracion_min,
        pr.fecha_hora                       AS funcion,
        s.nombre                            AS sala,
        sd.nombre                           AS sede,
        t.nombre                            AS tarifa,
        pg.metodo                           AS metodo_pago
FROM factura f
JOIN venta v          ON v.venta_id = f.venta_id
JOIN asistente a      ON a.asistente_id = v.asistente_id
LEFT JOIN entrada en  ON en.venta_id = v.venta_id
LEFT JOIN proyeccion pr ON pr.proyeccion_id = en.proyeccion_id
LEFT JOIN pelicula pe ON pe.pelicula_id = pr.pelicula_id
LEFT JOIN evento ev   ON ev.evento_id = en.evento_id
LEFT JOIN sala s      ON s.sala_id = pr.sala_id
LEFT JOIN sede sd     ON sd.sede_id = s.sede_id
LEFT JOIN abono ab    ON ab.venta_id = v.venta_id
LEFT JOIN tipo_abono ta ON ta.tipo_abono_id = ab.tipo_abono_id
LEFT JOIN tarifa t    ON t.tarifa_id = COALESCE(en.tarifa_id, ab.tarifa_id)
LEFT JOIN pago pg     ON pg.venta_id = v.venta_id;

-- ============================================================================
--  USUARIO DE LA APLICACIÓN CLIENTE (Fase 5)
--  Solo puede LEER vistas/tablas y EJECUTAR procedimientos: la app no puede
--  hacer INSERT/UPDATE/DELETE directo sobre las tablas.
-- ============================================================================
CREATE USER IF NOT EXISTS 'festcine_app'@'localhost' IDENTIFIED BY 'festcine123';
GRANT SELECT, EXECUTE ON festcine.* TO 'festcine_app'@'localhost';
FLUSH PRIVILEGES;
