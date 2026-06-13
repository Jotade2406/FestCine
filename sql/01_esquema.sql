-- ============================================================================
--  FESTCINE - Sistema de Gestión del Festival Internacional de Cine
--  Script 01: Creación del esquema (DDL) - Fase 2
--  Motor: MySQL 8.0+ / 9.x
--
--  Ejecutar como usuario administrador (root).
--  ADVERTENCIA: este script ELIMINA la base de datos 'festcine' si existe,
--  para permitir re-ejecuciones limpias durante el desarrollo.
-- ============================================================================

DROP DATABASE IF EXISTS festcine;
CREATE DATABASE festcine CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE festcine;

-- ============================================================================
--  MÓDULO: EDICIONES DEL FESTIVAL (soporte histórico)
-- ============================================================================

CREATE TABLE edicion (
    edicion_id      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(100)    NOT NULL,
    anio            SMALLINT        NOT NULL,
    fecha_inicio    DATE            NOT NULL,
    fecha_fin       DATE            NOT NULL,
    PRIMARY KEY (edicion_id),
    UNIQUE KEY uq_edicion_anio (anio),
    CONSTRAINT chk_edicion_fechas CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT chk_edicion_anio   CHECK (anio BETWEEN 1990 AND 2100)
) ENGINE=InnoDB;

-- ============================================================================
--  MÓDULO A: CATÁLOGO CINEMATOGRÁFICO Y PERSONAL
-- ============================================================================

CREATE TABLE genero (
    genero_id   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(50)     NOT NULL,
    PRIMARY KEY (genero_id),
    UNIQUE KEY uq_genero_nombre (nombre)
) ENGINE=InnoDB;

-- Personal cinematográfico centralizado: directores, actores, guionistas,
-- productores, miembros de jurado y expositores de eventos.
CREATE TABLE persona (
    persona_id      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(80)     NOT NULL,
    apellidos       VARCHAR(80)     NOT NULL,
    nacionalidad    VARCHAR(60)     NULL,
    biografia       TEXT            NULL,
    email           VARCHAR(120)    NULL,
    telefono        VARCHAR(30)     NULL,
    PRIMARY KEY (persona_id),
    UNIQUE KEY uq_persona_email (email)
) ENGINE=InnoDB;

CREATE TABLE rol (
    rol_id  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre  VARCHAR(50)     NOT NULL,           -- Director, Actor, Guionista, Productor
    PRIMARY KEY (rol_id),
    UNIQUE KEY uq_rol_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE pelicula (
    pelicula_id     INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    edicion_id      INT UNSIGNED    NOT NULL,   -- edición a la que se postula
    titulo          VARCHAR(200)    NOT NULL,
    anio_produccion SMALLINT        NOT NULL,
    duracion_min    SMALLINT        NOT NULL,
    pais_origen     VARCHAR(60)     NOT NULL,
    sinopsis        TEXT            NULL,
    clasificacion   ENUM('TP','7+','12+','16+','18+')               NOT NULL DEFAULT 'TP',
    formato         ENUM('Digital','35mm','IMAX')                   NOT NULL DEFAULT 'Digital',
    estado          ENUM('Postulada','Seleccionada','Rechazada','Premiada')
                                                                    NOT NULL DEFAULT 'Postulada',
    poster          VARCHAR(120)    NULL,   -- archivo de imagen del póster (app/static/posters)
    PRIMARY KEY (pelicula_id),
    CONSTRAINT fk_pelicula_edicion FOREIGN KEY (edicion_id) REFERENCES edicion (edicion_id),
    CONSTRAINT chk_pelicula_duracion CHECK (duracion_min > 0),
    CONSTRAINT chk_pelicula_anio     CHECK (anio_produccion BETWEEN 1890 AND 2100)
) ENGINE=InnoDB;

-- N:M película - género
CREATE TABLE pelicula_genero (
    pelicula_id INT UNSIGNED NOT NULL,
    genero_id   INT UNSIGNED NOT NULL,
    PRIMARY KEY (pelicula_id, genero_id),
    CONSTRAINT fk_pg_pelicula FOREIGN KEY (pelicula_id) REFERENCES pelicula (pelicula_id) ON DELETE CASCADE,
    CONSTRAINT fk_pg_genero   FOREIGN KEY (genero_id)   REFERENCES genero (genero_id)
) ENGINE=InnoDB;

-- N:M:M película - persona - rol (una persona puede tener varios roles en la misma obra)
CREATE TABLE pelicula_persona (
    pelicula_id INT UNSIGNED NOT NULL,
    persona_id  INT UNSIGNED NOT NULL,
    rol_id      INT UNSIGNED NOT NULL,
    PRIMARY KEY (pelicula_id, persona_id, rol_id),
    CONSTRAINT fk_pp_pelicula FOREIGN KEY (pelicula_id) REFERENCES pelicula (pelicula_id) ON DELETE CASCADE,
    CONSTRAINT fk_pp_persona  FOREIGN KEY (persona_id)  REFERENCES persona (persona_id),
    CONSTRAINT fk_pp_rol      FOREIGN KEY (rol_id)      REFERENCES rol (rol_id)
) ENGINE=InnoDB;

-- ============================================================================
--  MÓDULO B: SEDES, SALAS, PROYECCIONES Y EVENTOS PARALELOS
-- ============================================================================

CREATE TABLE sede (
    sede_id     INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(100)    NOT NULL,
    direccion   VARCHAR(200)    NOT NULL,
    ciudad      VARCHAR(80)     NOT NULL,
    PRIMARY KEY (sede_id),
    UNIQUE KEY uq_sede_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE sala (
    sala_id     INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    sede_id     INT UNSIGNED    NOT NULL,
    nombre      VARCHAR(80)     NOT NULL,
    capacidad   INT UNSIGNED    NOT NULL,
    PRIMARY KEY (sala_id),
    UNIQUE KEY uq_sala_sede_nombre (sede_id, nombre),
    CONSTRAINT fk_sala_sede FOREIGN KEY (sede_id) REFERENCES sede (sede_id),
    CONSTRAINT chk_sala_capacidad CHECK (capacidad > 0)
) ENGINE=InnoDB;

CREATE TABLE proyeccion (
    proyeccion_id    INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    pelicula_id      INT UNSIGNED   NOT NULL,
    sala_id          INT UNSIGNED   NOT NULL,
    fecha_hora       DATETIME       NOT NULL,
    precio_base      DECIMAL(10,2)  NOT NULL,
    tiene_qa         TINYINT(1)     NOT NULL DEFAULT 0,  -- sesión de preguntas y respuestas
    -- Columna DESNORMALIZADA (contador). Justificación en docs/Fase1_Modelado.md:
    -- evita contar entradas vendidas en cada compra. La inicializa el trigger
    -- trg_proyeccion_bi con la capacidad de la sala y solo la modifican los
    -- procedimientos almacenados.
    aforo_disponible INT            NULL,
    PRIMARY KEY (proyeccion_id),
    KEY idx_proyeccion_sala_fecha (sala_id, fecha_hora),
    CONSTRAINT fk_proy_pelicula FOREIGN KEY (pelicula_id) REFERENCES pelicula (pelicula_id),
    CONSTRAINT fk_proy_sala     FOREIGN KEY (sala_id)     REFERENCES sala (sala_id),
    CONSTRAINT chk_proy_precio  CHECK (precio_base >= 0),
    CONSTRAINT chk_proy_aforo   CHECK (aforo_disponible IS NULL OR aforo_disponible >= 0)
) ENGINE=InnoDB;

CREATE TABLE evento (
    evento_id           INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    edicion_id          INT UNSIGNED    NOT NULL,
    tipo                ENUM('Masterclass','Taller','Coctel') NOT NULL,
    nombre              VARCHAR(150)    NOT NULL,
    descripcion         TEXT            NULL,
    sede_id             INT UNSIGNED    NOT NULL,
    fecha_hora          DATETIME        NOT NULL,
    duracion_min        SMALLINT        NOT NULL DEFAULT 120,
    aforo_maximo        INT UNSIGNED    NOT NULL,
    aforo_disponible    INT UNSIGNED    NOT NULL,
    costo_inscripcion   DECIMAL(10,2)   NOT NULL DEFAULT 0,  -- 0 = gratuito
    PRIMARY KEY (evento_id),
    CONSTRAINT fk_evento_edicion FOREIGN KEY (edicion_id) REFERENCES edicion (edicion_id),
    CONSTRAINT fk_evento_sede    FOREIGN KEY (sede_id)    REFERENCES sede (sede_id),
    CONSTRAINT chk_evento_costo  CHECK (costo_inscripcion >= 0),
    CONSTRAINT chk_evento_aforo  CHECK (aforo_disponible <= aforo_maximo)
) ENGINE=InnoDB;

-- N:M evento - expositores invitados
CREATE TABLE evento_expositor (
    evento_id   INT UNSIGNED NOT NULL,
    persona_id  INT UNSIGNED NOT NULL,
    PRIMARY KEY (evento_id, persona_id),
    CONSTRAINT fk_ee_evento  FOREIGN KEY (evento_id)  REFERENCES evento (evento_id) ON DELETE CASCADE,
    CONSTRAINT fk_ee_persona FOREIGN KEY (persona_id) REFERENCES persona (persona_id)
) ENGINE=InnoDB;

-- ============================================================================
--  MÓDULO C: COMPETICIÓN, JURADOS Y PREMIOS
-- ============================================================================

CREATE TABLE categoria (
    categoria_id    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    edicion_id      INT UNSIGNED    NOT NULL,
    nombre          VARCHAR(100)    NOT NULL,
    descripcion     VARCHAR(300)    NULL,
    PRIMARY KEY (categoria_id),
    UNIQUE KEY uq_categoria_edicion (edicion_id, nombre),
    CONSTRAINT fk_categoria_edicion FOREIGN KEY (edicion_id) REFERENCES edicion (edicion_id)
) ENGINE=InnoDB;

-- Miembros del jurado por categoría (una persona puede estar en varias categorías)
CREATE TABLE categoria_jurado (
    categoria_id    INT UNSIGNED NOT NULL,
    persona_id      INT UNSIGNED NOT NULL,
    PRIMARY KEY (categoria_id, persona_id),
    CONSTRAINT fk_cj_categoria FOREIGN KEY (categoria_id) REFERENCES categoria (categoria_id),
    CONSTRAINT fk_cj_persona   FOREIGN KEY (persona_id)   REFERENCES persona (persona_id)
) ENGINE=InnoDB;

-- Películas que compiten en cada categoría
CREATE TABLE pelicula_categoria (
    pelicula_id     INT UNSIGNED NOT NULL,
    categoria_id    INT UNSIGNED NOT NULL,
    PRIMARY KEY (pelicula_id, categoria_id),
    CONSTRAINT fk_pc_pelicula  FOREIGN KEY (pelicula_id)  REFERENCES pelicula (pelicula_id),
    CONSTRAINT fk_pc_categoria FOREIGN KEY (categoria_id) REFERENCES categoria (categoria_id)
) ENGINE=InnoDB;

-- Evaluación de un jurado a una película dentro de una categoría.
-- Las FK compuestas garantizan que: (a) la película compite en esa categoría
-- y (b) el evaluador es miembro del jurado de esa categoría.
CREATE TABLE evaluacion (
    evaluacion_id   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    categoria_id    INT UNSIGNED    NOT NULL,
    pelicula_id     INT UNSIGNED    NOT NULL,
    persona_id      INT UNSIGNED    NOT NULL,
    puntuacion      TINYINT         NOT NULL,
    comentario      VARCHAR(500)    NULL,
    fecha_evaluacion DATETIME       NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    PRIMARY KEY (evaluacion_id),
    UNIQUE KEY uq_evaluacion (categoria_id, pelicula_id, persona_id),
    CONSTRAINT fk_eval_competidor FOREIGN KEY (pelicula_id, categoria_id)
        REFERENCES pelicula_categoria (pelicula_id, categoria_id),
    CONSTRAINT fk_eval_jurado FOREIGN KEY (categoria_id, persona_id)
        REFERENCES categoria_jurado (categoria_id, persona_id),
    CONSTRAINT chk_eval_puntuacion CHECK (puntuacion BETWEEN 1 AND 10)
) ENGINE=InnoDB;

-- Premio otorgado: una única película ganadora por categoría
CREATE TABLE premio (
    premio_id           INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    categoria_id        INT UNSIGNED    NOT NULL,
    pelicula_id         INT UNSIGNED    NOT NULL,
    fecha_otorgamiento  DATE            NOT NULL,
    PRIMARY KEY (premio_id),
    UNIQUE KEY uq_premio_categoria (categoria_id),   -- solo un ganador por categoría
    CONSTRAINT fk_premio_competidor FOREIGN KEY (pelicula_id, categoria_id)
        REFERENCES pelicula_categoria (pelicula_id, categoria_id)
) ENGINE=InnoDB;

-- ============================================================================
--  MÓDULO D: ASISTENTES, ACREDITACIONES Y VENTAS
-- ============================================================================

CREATE TABLE asistente (
    asistente_id    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(80)     NOT NULL,
    apellidos       VARCHAR(80)     NOT NULL,
    email           VARCHAR(120)    NOT NULL,
    telefono        VARCHAR(30)     NULL,
    fecha_nacimiento DATE           NULL,
    -- Credenciales de acceso a la aplicación (asunción 14):
    -- la clave se guarda como hash SHA-256 (lo calcula sp_registrar_asistente)
    usuario         VARCHAR(30)     NULL,
    clave_hash      CHAR(64)        NULL,
    PRIMARY KEY (asistente_id),
    UNIQUE KEY uq_asistente_email (email),
    UNIQUE KEY uq_asistente_usuario (usuario)
) ENGINE=InnoDB;

-- Asistente sin fila aquí = Público General
CREATE TABLE acreditacion (
    acreditacion_id INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    asistente_id    INT UNSIGNED    NOT NULL,
    edicion_id      INT UNSIGNED    NOT NULL,
    tipo            ENUM('Prensa','Industria','VIP','Jurado') NOT NULL,
    fecha_emision   DATE            NOT NULL,
    PRIMARY KEY (acreditacion_id),
    UNIQUE KEY uq_acreditacion (asistente_id, edicion_id),  -- una por edición
    CONSTRAINT fk_acred_asistente FOREIGN KEY (asistente_id) REFERENCES asistente (asistente_id),
    CONSTRAINT fk_acred_edicion   FOREIGN KEY (edicion_id)   REFERENCES edicion (edicion_id)
) ENGINE=InnoDB;

CREATE TABLE tarifa (
    tarifa_id       INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(50)     NOT NULL,       -- General, Estudiante, Jubilado, ...
    descuento_pct   DECIMAL(5,2)    NOT NULL,       -- 0 = precio pleno, 100 = gratis (VIP)
    PRIMARY KEY (tarifa_id),
    UNIQUE KEY uq_tarifa_nombre (nombre),
    CONSTRAINT chk_tarifa_descuento CHECK (descuento_pct BETWEEN 0 AND 100)
) ENGINE=InnoDB;

CREATE TABLE venta (
    venta_id    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    asistente_id INT UNSIGNED   NOT NULL,
    tipo_venta  ENUM('Entrada','Abono') NOT NULL,
    fecha_venta DATETIME        NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    total       DECIMAL(10,2)   NOT NULL,
    PRIMARY KEY (venta_id),
    CONSTRAINT fk_venta_asistente FOREIGN KEY (asistente_id) REFERENCES asistente (asistente_id),
    CONSTRAINT chk_venta_total CHECK (total >= 0)
) ENGINE=InnoDB;

CREATE TABLE pago (
    pago_id     INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    venta_id    INT UNSIGNED    NOT NULL,
    metodo      ENUM('Efectivo','Tarjeta','Online') NOT NULL,
    monto       DECIMAL(10,2)   NOT NULL,
    estado      ENUM('Aprobado','Rechazado') NOT NULL,
    fecha_pago  DATETIME        NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    PRIMARY KEY (pago_id),
    CONSTRAINT fk_pago_venta FOREIGN KEY (venta_id) REFERENCES venta (venta_id),
    CONSTRAINT chk_pago_monto CHECK (monto >= 0)
) ENGINE=InnoDB;

CREATE TABLE factura (
    factura_id      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    venta_id        INT UNSIGNED    NOT NULL,
    numero_factura  VARCHAR(20)     NOT NULL,
    fecha_emision   DATETIME        NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    subtotal        DECIMAL(10,2)   NOT NULL,
    impuestos       DECIMAL(10,2)   NOT NULL,
    total           DECIMAL(10,2)   NOT NULL,
    PRIMARY KEY (factura_id),
    UNIQUE KEY uq_factura_venta  (venta_id),
    UNIQUE KEY uq_factura_numero (numero_factura),
    CONSTRAINT fk_factura_venta FOREIGN KEY (venta_id) REFERENCES venta (venta_id)
) ENGINE=InnoDB;

-- Entrada individual: válida para UNA proyección o UN evento paralelo (XOR)
CREATE TABLE entrada (
    entrada_id      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    venta_id        INT UNSIGNED    NOT NULL,
    proyeccion_id   INT UNSIGNED    NULL,
    evento_id       INT UNSIGNED    NULL,
    tarifa_id       INT UNSIGNED    NOT NULL,
    precio_pagado   DECIMAL(10,2)   NOT NULL,   -- snapshot histórico del precio
    codigo          VARCHAR(20)     NOT NULL,
    PRIMARY KEY (entrada_id),
    UNIQUE KEY uq_entrada_codigo (codigo),
    CONSTRAINT fk_entrada_venta      FOREIGN KEY (venta_id)      REFERENCES venta (venta_id),
    CONSTRAINT fk_entrada_proyeccion FOREIGN KEY (proyeccion_id) REFERENCES proyeccion (proyeccion_id),
    CONSTRAINT fk_entrada_evento     FOREIGN KEY (evento_id)     REFERENCES evento (evento_id),
    CONSTRAINT fk_entrada_tarifa     FOREIGN KEY (tarifa_id)     REFERENCES tarifa (tarifa_id),
    CONSTRAINT chk_entrada_destino CHECK ((proyeccion_id IS NULL) XOR (evento_id IS NULL)),
    CONSTRAINT chk_entrada_precio  CHECK (precio_pagado >= 0)
) ENGINE=InnoDB;

CREATE TABLE tipo_abono (
    tipo_abono_id   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(80)     NOT NULL,       -- "Abono Fin de Semana", "Abono Total"
    descripcion     VARCHAR(300)    NULL,
    precio_base     DECIMAL(10,2)   NOT NULL,
    num_accesos     SMALLINT UNSIGNED NOT NULL,     -- cantidad de códigos de acceso que otorga
    PRIMARY KEY (tipo_abono_id),
    UNIQUE KEY uq_tipo_abono_nombre (nombre),
    CONSTRAINT chk_tabono_precio  CHECK (precio_base >= 0),
    CONSTRAINT chk_tabono_accesos CHECK (num_accesos > 0)
) ENGINE=InnoDB;

CREATE TABLE abono (
    abono_id        INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    venta_id        INT UNSIGNED    NOT NULL,
    tipo_abono_id   INT UNSIGNED    NOT NULL,
    tarifa_id       INT UNSIGNED    NOT NULL,
    precio_pagado   DECIMAL(10,2)   NOT NULL,
    codigo          VARCHAR(20)     NOT NULL,
    estado          ENUM('Activo','Anulado') NOT NULL DEFAULT 'Activo',
    PRIMARY KEY (abono_id),
    UNIQUE KEY uq_abono_codigo (codigo),
    UNIQUE KEY uq_abono_venta  (venta_id),
    CONSTRAINT fk_abono_venta  FOREIGN KEY (venta_id)      REFERENCES venta (venta_id),
    CONSTRAINT fk_abono_tipo   FOREIGN KEY (tipo_abono_id) REFERENCES tipo_abono (tipo_abono_id),
    CONSTRAINT fk_abono_tarifa FOREIGN KEY (tarifa_id)     REFERENCES tarifa (tarifa_id)
) ENGINE=InnoDB;

-- Códigos de acceso generados al vender un abono (transacción T1).
-- Al canjearse quedan ligados a la proyección a la que se asistió.
CREATE TABLE codigo_acceso (
    codigo_acceso_id INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    abono_id        INT UNSIGNED    NOT NULL,
    codigo          VARCHAR(20)     NOT NULL,
    usado           TINYINT(1)      NOT NULL DEFAULT 0,
    proyeccion_id   INT UNSIGNED    NULL,
    fecha_uso       DATETIME        NULL,
    PRIMARY KEY (codigo_acceso_id),
    UNIQUE KEY uq_codigo_acceso (codigo),
    CONSTRAINT fk_ca_abono      FOREIGN KEY (abono_id)      REFERENCES abono (abono_id),
    CONSTRAINT fk_ca_proyeccion FOREIGN KEY (proyeccion_id) REFERENCES proyeccion (proyeccion_id),
    CONSTRAINT chk_ca_uso CHECK (usado = 1 OR proyeccion_id IS NULL)
) ENGINE=InnoDB;

-- ============================================================================
--  MÓDULO E: LOGÍSTICA DE INVITADOS Y PATROCINIOS
-- ============================================================================

CREATE TABLE hotel (
    hotel_id    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(100)    NOT NULL,
    direccion   VARCHAR(200)    NULL,
    telefono    VARCHAR(30)     NULL,
    PRIMARY KEY (hotel_id),
    UNIQUE KEY uq_hotel_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE alojamiento (
    alojamiento_id  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    persona_id      INT UNSIGNED    NOT NULL,
    hotel_id        INT UNSIGNED    NOT NULL,
    edicion_id      INT UNSIGNED    NOT NULL,
    habitacion      VARCHAR(20)     NOT NULL,
    fecha_checkin   DATE            NOT NULL,
    fecha_checkout  DATE            NOT NULL,
    PRIMARY KEY (alojamiento_id),
    CONSTRAINT fk_aloj_persona FOREIGN KEY (persona_id) REFERENCES persona (persona_id),
    CONSTRAINT fk_aloj_hotel   FOREIGN KEY (hotel_id)   REFERENCES hotel (hotel_id),
    CONSTRAINT fk_aloj_edicion FOREIGN KEY (edicion_id) REFERENCES edicion (edicion_id),
    CONSTRAINT chk_aloj_fechas CHECK (fecha_checkout > fecha_checkin)
) ENGINE=InnoDB;

CREATE TABLE traslado (
    traslado_id INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    persona_id  INT UNSIGNED    NOT NULL,
    edicion_id  INT UNSIGNED    NOT NULL,
    tipo        ENUM('Vuelo','Terrestre') NOT NULL,
    origen      VARCHAR(100)    NOT NULL,
    destino     VARCHAR(100)    NOT NULL,
    fecha_hora  DATETIME        NOT NULL,
    referencia  VARCHAR(40)     NULL,   -- nº de vuelo, placa del vehículo, etc.
    notas       VARCHAR(300)    NULL,
    PRIMARY KEY (traslado_id),
    CONSTRAINT fk_tras_persona FOREIGN KEY (persona_id) REFERENCES persona (persona_id),
    CONSTRAINT fk_tras_edicion FOREIGN KEY (edicion_id) REFERENCES edicion (edicion_id)
) ENGINE=InnoDB;

CREATE TABLE patrocinador (
    patrocinador_id INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(120)    NOT NULL,
    contacto_nombre VARCHAR(120)    NULL,
    contacto_email  VARCHAR(120)    NULL,
    PRIMARY KEY (patrocinador_id),
    UNIQUE KEY uq_patrocinador_nombre (nombre)
) ENGINE=InnoDB;

-- Aportación de un patrocinador a una edición concreta (histórico)
CREATE TABLE patrocinio (
    patrocinio_id   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    patrocinador_id INT UNSIGNED    NOT NULL,
    edicion_id      INT UNSIGNED    NOT NULL,
    tipo_aporte     ENUM('Economica','Especie') NOT NULL,
    monto           DECIMAL(12,2)   NULL,   -- obligatorio si el aporte es económico
    descripcion     VARCHAR(300)    NULL,
    PRIMARY KEY (patrocinio_id),
    CONSTRAINT fk_patroc_patrocinador FOREIGN KEY (patrocinador_id) REFERENCES patrocinador (patrocinador_id),
    CONSTRAINT fk_patroc_edicion      FOREIGN KEY (edicion_id)      REFERENCES edicion (edicion_id),
    CONSTRAINT chk_patroc_monto CHECK (tipo_aporte = 'Especie' OR monto IS NOT NULL)
) ENGINE=InnoDB;
