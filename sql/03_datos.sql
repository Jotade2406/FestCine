-- ============================================================================
--  FESTCINE - Script 03: Datos de prueba (DML) - Fase 2
--  Ejecutar DESPUÉS de 01_esquema.sql y 02_programacion.sql.
--
--  Las proyecciones se insertan con el trigger TR1 activo (valida la agenda)
--  y todas las ventas se registran a través de los procedimientos P1 y T1,
--  de modo que los contadores de aforo quedan 100% consistentes.
-- ============================================================================

USE festcine;

-- ----------------------------------------------------------------------------
-- Ediciones: 2025 (histórica) y 2026 (edición vigente)
-- ----------------------------------------------------------------------------
INSERT INTO edicion (nombre, anio, fecha_inicio, fecha_fin) VALUES
('FestCine 2025', 2025, '2025-06-11', '2025-06-21'),   -- id 1
('FestCine 2026', 2026, '2026-06-10', '2026-06-20');   -- id 2

-- ----------------------------------------------------------------------------
-- Catálogo: géneros, roles y personal cinematográfico
-- ----------------------------------------------------------------------------
INSERT INTO genero (nombre) VALUES
('Drama'),          -- 1
('Sci-Fi'),         -- 2
('Documental'),     -- 3
('Comedia'),        -- 4
('Animación'),      -- 5
('Suspenso'),       -- 6
('Terror'),         -- 7
('Fantasía'),       -- 8
('Musical');        -- 9

INSERT INTO rol (nombre) VALUES
('Director'),       -- 1
('Actor'),          -- 2
('Guionista'),      -- 3
('Productor');      -- 4

INSERT INTO persona (nombre, apellidos, nacionalidad, biografia, email, telefono) VALUES
('Steven',  'Spielberg', 'EE. UU.',     'Director ganador del Óscar; leyenda viva del cine contemporáneo.',                 's.spielberg@cinemail.com',   '+1 310 111 0001'),   -- 1
('David',   'Koepp',     'EE. UU.',     'Guionista de éxitos como Jurassic Park y Misión Imposible.',                       'd.koepp@cinemail.com',       '+1 310 111 0002'),   -- 2
('Emily',   'Blunt',     'Reino Unido', 'Actriz nominada al Óscar; protagonista de Oppenheimer y Un lugar en silencio.',    'e.blunt@cinemail.com',       '+44 20 111 0003'),   -- 3
('Jon',     'Favreau',   'EE. UU.',     'Director, guionista y productor; creador de The Mandalorian.',                     'j.favreau@cinemail.com',     '+1 310 111 0004'),   -- 4
('Pedro',   'Pascal',    'Chile',       'Actor protagonista de The Mandalorian y The Last of Us.',                          'p.pascal@cinemail.com',      '+1 310 111 0005'),   -- 5
('Goose',   'Worx',      'Australia',   'Animadora, compositora y creadora de The Amazing Digital Circus.',                 'gooseworx@cinemail.com',     '+61 4 111 0006'),    -- 6
('Rod',     'Blackhurst','EE. UU.',     'Director de cine de terror y documental; nominado al Emmy.',                       'r.blackhurst@cinemail.com',  '+1 310 111 0007'),   -- 7
('Michael', 'Tiddes',    'EE. UU.',     'Director de comedia; colaborador habitual de los hermanos Wayans.',                'm.tiddes@cinemail.com',      '+1 310 111 0008'),   -- 8
('Anna',    'Faris',     'EE. UU.',     'Actriz y comediante; protagonista histórica de la saga Scary Movie.',              'a.faris@cinemail.com',       '+1 310 111 0009'),   -- 9
('Marlon',  'Wayans',    'EE. UU.',     'Actor, productor y comediante; cocreador de la saga Scary Movie.',                 'm.wayans@cinemail.com',      '+1 310 111 0010'),   -- 10
('Sofía',   'Lindgren',  'Suecia',      'Crítica de cine de la revista Nordisk Film; jurado internacional.',                's.lindgren@jurymail.com',    '+46 70 888 0011'),   -- 11
('Marco',   'Antonelli', 'Italia',      'Director veterano; tres veces nominado en Venecia. Jurado internacional.',         'm.antonelli@jurymail.com',   '+39 33 999 0012'),   -- 12
('Helena',  'Brandt',    'Alemania',    'Productora de cine independiente europeo; jurado internacional.',                  'h.brandt@jurymail.com',      '+49 15 101 0013'),   -- 13
('Ricardo', 'Salcedo',   'Bolivia',     'Crítico de cine y profesor universitario; jurado local.',                          'r.salcedo@jurymail.com',     '+591 700 111 0014'),  -- 14
('Isabel',  'Quintero',  'Bolivia',     'Directora; ganadora de FestCine 2025 con Sombras de Sal.',                         'i.quintero@cinemail.com',    '+591 700 111 0015'),  -- 15
('Paulo',   'Mendes',    'Brasil',      'Guionista; tallerista invitado de escritura audiovisual.',                         'p.mendes@cinemail.com',      '+55 11 121 0016'),   -- 16
('Travis',  'Knight',    'EE. UU.',     'Director y animador; CEO de Laika, dirigió Bumblebee y Kubo.',                     't.knight@cinemail.com',      '+1 310 111 0017'),   -- 17
('Nicholas','Galitzine', 'Reino Unido', 'Actor en ascenso; protagonista de Amos del Universo.',                             'n.galitzine@cinemail.com',   '+44 20 111 0018'),   -- 18
('Kane',    'Parsons',   'EE. UU.',     'Creador del fenómeno de internet Backrooms; director debutante.',                  'k.parsons@cinemail.com',     '+1 310 111 0019'),   -- 19
('Curry',   'Barker',    'EE. UU.',     'Director y guionista de terror independiente.',                                    'c.barker@cinemail.com',      '+1 310 111 0020'),   -- 20
('Andrew',  'Stanton',   'EE. UU.',     'Director de Pixar; ganador del Óscar por Buscando a Nemo y WALL-E.',               'a.stanton@cinemail.com',     '+1 310 111 0021'),   -- 21
('Craig',   'Gillespie', 'Australia',   'Director de Yo, Tonya y Cruella.',                                                 'c.gillespie@cinemail.com',   '+61 4 111 0022'),    -- 22
('Milly',   'Alcock',    'Australia',   'Actriz revelación de House of the Dragon; protagonista de Supergirl.',             'm.alcock@cinemail.com',      '+61 4 111 0023'),    -- 23
('David',   'Frankel',   'EE. UU.',     'Director de El Diablo Viste a la Moda y Marley y Yo.',                             'd.frankel@cinemail.com',     '+1 310 111 0024'),   -- 24
('Meryl',   'Streep',    'EE. UU.',     'Tres veces ganadora del Óscar; la actriz más nominada de la historia.',            'm.streep@cinemail.com',      '+1 310 111 0025'),   -- 25
('Antoine', 'Fuqua',     'EE. UU.',     'Director de Día de Entrenamiento y The Equalizer.',                                'a.fuqua@cinemail.com',       '+1 310 111 0026'),   -- 26
('Jaafar',  'Jackson',   'EE. UU.',     'Cantante y actor; sobrino de Michael Jackson, lo encarna en la pantalla.',         'j.jackson@cinemail.com',     '+1 310 111 0027');   -- 27

-- ----------------------------------------------------------------------------
-- Películas (la 1 pertenece a la edición histórica 2025)
-- ----------------------------------------------------------------------------
INSERT INTO pelicula (edicion_id, titulo, anio_produccion, duracion_min, pais_origen, sinopsis, clasificacion, formato, estado, poster) VALUES
(1, 'Sombras de Sal',        2024, 102, 'Bolivia', 'Una salinera artesanal lucha por preservar su oficio frente a la industrialización.', '12+', 'Digital', 'Premiada', NULL),  -- 1
(2, 'Dolly',                 2026,  83, 'EE. UU.',  'Una muñeca de tamaño real convierte el juego de una familia en una pesadilla. Juega conmigo.', '12+', 'Digital', 'Seleccionada', 'dolly.jpg'),          -- 2
(2, 'Star Wars: The Mandalorian and Grogu', 2026, 132, 'EE. UU.', 'El cazarrecompensas y Grogu emprenden una misión que los llevará a los confines de la galaxia.', 'TP', 'IMAX', 'Seleccionada', 'mandalorian.jpg'),  -- 3
(2, 'The Amazing Digital Circus: El Último Acto', 2026, 93, 'EE. UU.', 'El final del fenómeno viral de internet llega a los cines: Pomni y compañía enfrentan el último acto.', 'TP', 'Digital', 'Seleccionada', 'digital_circus.jpg'), -- 4
(2, 'El Día de la Revelación', 2026, 146, 'EE. UU.', 'Merecemos saber. Un evento global obliga a la humanidad a confrontar aquello que la observa.', '12+', 'IMAX', 'Premiada', 'revelacion.jpg'),  -- 5
(2, 'Scary Movie',           2026,  95, 'EE. UU.',  'La saga de parodias regresa terroríficamente incorrecta, con sus protagonistas originales.', '12+', 'Digital', 'Seleccionada', 'scary_movie.jpg'),  -- 6
(2, 'Backrooms',             2026, 110, 'EE. UU.',  'Si sales de la realidad en el lugar equivocado, caerás en los Backrooms. Sin salida.', '12+', 'Digital', 'Postulada', 'backrooms.jpg'),   -- 7
(2, 'Obsesión',              2026, 109, 'EE. UU.',  'Un flechazo instantáneo se convierte en una espiral de terror psicológico.', '12+', 'Digital', 'Rechazada', 'obsesion.jpg'),    -- 8
(2, 'Amos del Universo',     2026, 141, 'EE. UU.',  'Las leyendas no nacen, se forjan: He-Man y los defensores de Grayskull llegan a la pantalla grande.', 'TP', 'Digital', 'Seleccionada', 'amos_universo.jpg'),  -- 9
(2, 'Toy Story 5',           2026, 104, 'EE. UU.',  'Woody, Buzz y la pandilla enfrentan a su rival más inesperado: una tableta electrónica que quiere reemplazar el juego.', 'TP', 'Digital', 'Seleccionada', 'toy_story5.jpg'),    -- 10
(2, 'Supergirl',             2026, 125, 'EE. UU.',  'Kara Zor-El recorre la galaxia para ajustar cuentas con su pasado kryptoniano.', '12+', 'IMAX', 'Seleccionada', 'supergirl.jpg'),      -- 11
(2, 'El Diablo Viste a la Moda 2', 2026, 119, 'EE. UU.', 'Miranda Priestly enfrenta el ocaso de las revistas impresas... y a una antigua asistente convertida en rival.', 'TP', 'Digital', 'Seleccionada', 'diablo_moda2.jpg'),  -- 12
(2, 'Michael',               2026, 134, 'EE. UU.',  'La vida del Rey del Pop como nunca se ha contado, interpretado por Jaafar Jackson.', '12+', 'Digital', 'Seleccionada', 'michael.jpg'),     -- 13
(2, 'BTS World Tour Arirang in Busan: Live Viewing', 2026, 130, 'Corea del Sur', 'Transmisión en directo desde Busan del concierto del grupo más influyente del pop global.', 'TP', 'Digital', 'Seleccionada', 'bts_busan.jpg');  -- 14

INSERT INTO pelicula_genero (pelicula_id, genero_id) VALUES
(1,1),
(2,7), (2,6),
(3,2),
(4,5), (4,4),
(5,2), (5,1),
(6,4), (6,7),
(7,7), (7,6),
(8,6),
(9,2), (9,8),
(10,5), (10,4),
(11,2), (11,8),
(12,4), (12,1),
(13,1), (13,9),
(14,9), (14,3);

-- Una misma persona puede tener varios roles en la misma obra (Favreau:
-- director y guionista; Gooseworx: directora y guionista; Wayans: actor y productor)
INSERT INTO pelicula_persona (pelicula_id, persona_id, rol_id) VALUES
(1, 15, 1),
(2, 7, 1),
(3, 4, 1), (3, 4, 3), (3, 5, 2),
(4, 6, 1), (4, 6, 3),
(5, 1, 1), (5, 2, 3), (5, 3, 2),
(6, 8, 1), (6, 9, 2), (6, 10, 2), (6, 10, 4),
(7, 19, 1),
(8, 20, 1),
(9, 17, 1), (9, 18, 2),
(10, 21, 1), (10, 21, 3),
(11, 22, 1), (11, 23, 2),
(12, 24, 1), (12, 25, 2),
(13, 26, 1), (13, 27, 2);

-- ----------------------------------------------------------------------------
-- Sedes y salas
-- ----------------------------------------------------------------------------
INSERT INTO sede (nombre, direccion, ciudad) VALUES
('Cine Center Equipetrol',    'Av. San Martín #1392, Equipetrol', 'Santa Cruz de la Sierra'),   -- 1
('Centro Cultural Santa Cruz','2do Anillo, Av. Cristo Redentor #780', 'Santa Cruz de la Sierra'); -- 2

INSERT INTO sala (sede_id, nombre, capacidad) VALUES
(1, 'Sala Principal', 250),  -- 1
(1, 'Sala 2',         120),  -- 2
(2, 'Sala Andina',    180),  -- 3
(2, 'Sala Íntima',     60);  -- 4

-- ----------------------------------------------------------------------------
-- Proyecciones (el trigger TR1 valida cruces e inicializa aforo_disponible)
-- ----------------------------------------------------------------------------
INSERT INTO proyeccion (pelicula_id, sala_id, fecha_hora, precio_base, tiene_qa) VALUES
(2, 1, '2026-06-12 18:00:00', 35, 0),  -- 1  Dolly                 / S.Principal (83m -> libre 19:53)
(3, 1, '2026-06-12 21:00:00', 40, 0),  -- 2  Mandalorian and Grogu / S.Principal
(5, 1, '2026-06-13 18:00:00', 35, 1),  -- 3  El Día de la Revelación (Q&A) / S.Principal
(2, 1, '2026-06-14 17:00:00', 35, 0),  -- 4  Dolly                 / S.Principal
(4, 2, '2026-06-12 16:00:00', 30, 0),  -- 5  Digital Circus        / Sala 2 (93m -> libre 18:03)
(6, 2, '2026-06-12 19:00:00', 30, 0),  -- 6  Scary Movie           / Sala 2
(4, 2, '2026-06-15 18:00:00', 30, 1),  -- 7  Digital Circus (Q&A)  / Sala 2
(3, 3, '2026-06-13 15:00:00', 40, 1),  -- 8  Mandalorian (Q&A)     / S.Andina (132m -> libre 17:42)
(5, 3, '2026-06-13 19:00:00', 35, 0),  -- 9  El Día de la Revelación / S.Andina
(6, 3, '2026-06-16 18:00:00', 30, 0),  -- 10 Scary Movie           / S.Andina
(4, 4, '2026-06-14 16:00:00', 25, 1),  -- 11 Digital Circus (Q&A)  / S.Íntima
(2, 4, '2026-06-17 18:00:00', 25, 0),  -- 12 Dolly                 / S.Íntima
(9, 1, '2026-06-15 19:00:00', 35, 0),  -- 13 Amos del Universo     / S.Principal
(9, 3, '2026-06-14 18:00:00', 35, 1),  -- 14 Amos del Universo (Q&A) / S.Andina
(10, 2, '2026-06-13 15:00:00', 30, 0), -- 15 Toy Story 5           / Sala 2
(10, 4, '2026-06-15 16:00:00', 25, 0), -- 16 Toy Story 5           / S.Íntima
(11, 1, '2026-06-16 18:00:00', 40, 0), -- 17 Supergirl             / S.Principal
(11, 3, '2026-06-15 17:00:00', 35, 0), -- 18 Supergirl             / S.Andina
(12, 2, '2026-06-14 18:00:00', 30, 0), -- 19 El Diablo Viste a la Moda 2 / Sala 2
(12, 4, '2026-06-16 18:00:00', 25, 0), -- 20 El Diablo Viste a la Moda 2 / S.Íntima
(13, 1, '2026-06-17 19:00:00', 35, 0), -- 21 Michael               / S.Principal
(13, 3, '2026-06-17 18:00:00', 35, 1), -- 22 Michael (Q&A)         / S.Andina
(14, 1, '2026-06-13 22:30:00', 50, 0), -- 23 BTS Live Viewing      / S.Principal (sáb 13)
(14, 3, '2026-06-18 19:00:00', 50, 0); -- 24 BTS Live Viewing      / S.Andina

-- ----------------------------------------------------------------------------
-- Eventos paralelos y expositores
-- ----------------------------------------------------------------------------
INSERT INTO evento (edicion_id, tipo, nombre, descripcion, sede_id, fecha_hora, duracion_min, aforo_maximo, aforo_disponible, costo_inscripcion) VALUES
(2, 'Masterclass', 'Masterclass: Dirección de actores',      'Encuentro con el maestro Marco Antonelli.',          1, '2026-06-13 10:00:00', 120,  80,  80, 150),  -- 1
(2, 'Taller',      'Taller: Escritura de guion en 5 días',   'Taller intensivo con el guionista Paulo Mendes.',    2, '2026-06-15 09:00:00', 240,  25,  25, 250),  -- 2
(2, 'Coctel',      'Coctel de Apertura FestCine 2026',       'Recepción oficial para acreditados e invitados.',    1, '2026-06-10 20:00:00', 180, 150, 150,     0);  -- 3

INSERT INTO evento_expositor (evento_id, persona_id) VALUES
(1, 12), (2, 16), (3, 15);

-- ----------------------------------------------------------------------------
-- Competición: categorías, jurados, competidoras, evaluaciones y premios
-- ----------------------------------------------------------------------------
INSERT INTO categoria (edicion_id, nombre, descripcion) VALUES
(1, 'Mejor Película',         'Premio principal de la edición 2025'),              -- 1
(2, 'Mejor Película',         'Premio principal de la edición 2026'),              -- 2
(2, 'Mejor Película Animada', 'Reconocimiento al mejor largometraje de animación'),-- 3
(2, 'Premio del Público',     'Otorgado según la votación de los asistentes');     -- 4

-- Helena (13) y Ricardo (14) participan en MÁS de una categoría
INSERT INTO categoria_jurado (categoria_id, persona_id) VALUES
(1, 11), (1, 12),
(2, 11), (2, 12), (2, 13),
(3, 13), (3, 14),
(4, 14);

INSERT INTO pelicula_categoria (pelicula_id, categoria_id) VALUES
(1, 1),
(2, 2), (3, 2), (5, 2), (6, 2),
(4, 3), (10, 3),
(2, 4), (3, 4), (4, 4), (5, 4), (6, 4);

INSERT INTO evaluacion (categoria_id, pelicula_id, persona_id, puntuacion, comentario) VALUES
-- Mejor Película 2025 (histórico)
(1, 1, 11,  9, 'Fotografía deslumbrante y guion sólido.'),
(1, 1, 12,  8, 'Una ópera prima madura.'),
-- Mejor Película 2026
(2, 2, 11,  8, 'Terror artesanal: la muñeca da más miedo cuanto menos se mueve.'),
(2, 2, 12,  7, 'Sólida aunque previsible en su tercer acto.'),
(2, 2, 13,  8, 'Gran manejo de la tensión doméstica.'),
(2, 3, 11,  7, 'Espectáculo impecable; el vínculo con Grogu sostiene la película.'),
(2, 3, 12,  8, 'Favreau lleva la galaxia de vuelta a la pantalla grande con oficio.'),
(2, 3, 13,  6, 'Visualmente notable, narrativamente conservadora.'),
(2, 5, 11,  9, 'Hipnótica. Spielberg confronta lo desconocido con humanidad.'),
(2, 5, 12,  9, 'Dirección magistral; el guion de Koepp no da tregua.'),
(2, 5, 13, 10, 'La película del festival.'),
(2, 6, 11,  6, 'Divertida pero menor frente a sus competidoras.'),
(2, 6, 12,  7, 'La parodia recupera su filo; Faris y Wayans en plena forma.'),
(2, 6, 13,  7, 'Carcajadas garantizadas, riesgo limitado.'),
-- Mejor Película Animada 2026
(3, 4, 13,  9, 'Cierre brillante del fenómeno digital; animación desbordante.'),
(3, 4, 14,  8, 'El salto de internet al cine le sienta de maravilla.'),
(3, 10, 13, 8, 'Pixar vuelve a emocionar sin perder la frescura.'),
(3, 10, 14, 7, 'Entrañable, aunque la fórmula empieza a notarse.'),
-- Premio del Público 2026 (votación delegada en jurado representante)
(4, 5, 14,  9, 'Ovación de pie en ambas funciones.'),
(4, 2, 14,  8, 'Gran recepción del público en la función de medianoche.');

INSERT INTO premio (categoria_id, pelicula_id, fecha_otorgamiento) VALUES
(1, 1, '2025-06-21'),   -- Sombras de Sal            -> Mejor Película 2025
(2, 5, '2026-06-11');   -- El Día de la Revelación   -> Mejor Película 2026 (gala de la crítica)

-- ----------------------------------------------------------------------------
-- Asistentes (20+) y acreditaciones especiales
-- ----------------------------------------------------------------------------
INSERT INTO asistente (nombre, apellidos, email, telefono, fecha_nacimiento, usuario) VALUES
('Laura',    'Gómez',      'laura.gomez@mail.com',      '+591 301 000 0001', '1995-04-12', 'laugomez'),    -- 1  (VIP)
('Carlos',   'Pérez',      'carlos.perez@prensa.com',   '+591 301 000 0002', '1988-09-30', 'cperez'),      -- 2  (Prensa)
('Ana',      'Martínez',   'ana.martinez@industria.co', '+591 301 000 0003', '1979-02-17', 'anamartinez'), -- 3  (Industria)
('Ricardo',  'Salcedo',    'r.salcedo.acred@mail.com',  '+591 301 000 0004', '1970-11-05', 'rsalcedo'),    -- 4  (Jurado)
('Juliana',  'Restrepo',   'juliana.r@mail.com',        '+591 301 000 0005', '2001-06-23', 'julianar'),
('Mateo',    'Hernández',  'mateo.h@mail.com',          '+591 301 000 0006', '1999-12-01', 'mateoh'),
('Sara',     'López',      'sara.lopez@mail.com',       '+591 301 000 0007', '1993-03-14', 'saralopez'),
('Daniel',   'Torres',     'daniel.t@mail.com',         '+591 301 000 0008', '1985-07-19', 'danielt'),
('Camilo',   'Vargas',     'camilo.v@mail.com',         '+591 301 000 0009', '2003-01-28', 'camilov'),
('Manuela',  'Ossa',       'manuela.o@mail.com',        '+591 301 000 0010', '1997-10-08', 'manuelao'),
('Felipe',   'Cárdenas',   'felipe.c@mail.com',         '+591 301 000 0011', '1990-05-25', 'felipec'),
('Isabella', 'Mejía',      'isabella.m@mail.com',       '+591 301 000 0012', '2002-08-16', 'isabellam'),
('Santiago', 'Ruiz',       'santiago.r@mail.com',       '+591 301 000 0013', '1982-04-03', 'santiagor'),
('Valeria',  'Castro',     'valeria.c@mail.com',        '+591 301 000 0014', '1996-09-11', 'valeriac'),
('Andrés',   'Zapata',     'andres.z@mail.com',         '+591 301 000 0015', '1955-12-20', 'andresz'),
('Gabriela', 'Montoya',    'gabriela.m@mail.com',       '+591 301 000 0016', '1958-02-09', 'gabrielam'),
('Nicolás',  'Arango',     'nicolas.a@mail.com',        '+591 301 000 0017', '2000-07-07', 'nicolasa'),
('Mariana',  'Bedoya',     'mariana.b@mail.com',        '+591 301 000 0018', '1994-11-29', 'marianab'),
('Tomás',    'Echeverri',  'tomas.e@mail.com',          '+591 301 000 0019', '1989-01-15', 'tomase'),
('Luisa',    'Franco',     'luisa.f@mail.com',          '+591 301 000 0020', '1998-06-04', 'luisaf'),
('Emilio',   'Giraldo',    'emilio.g@mail.com',         '+591 301 000 0021', '1976-03-22', 'emiliog'),
('Catalina', 'Hoyos',      'catalina.h@mail.com',       '+591 301 000 0022', '2004-10-31', 'catalinah');

-- Contraseña de demostración para todos los asistentes precargados: 12345678
UPDATE asistente SET clave_hash = SHA2('12345678', 256) WHERE clave_hash IS NULL;

INSERT INTO acreditacion (asistente_id, edicion_id, tipo, fecha_emision) VALUES
(1, 2, 'VIP',       '2026-06-01'),
(2, 2, 'Prensa',    '2026-06-01'),
(3, 2, 'Industria', '2026-06-02'),
(4, 2, 'Jurado',    '2026-06-02');

-- ----------------------------------------------------------------------------
-- Tarifas y tipos de abono
-- ----------------------------------------------------------------------------
INSERT INTO tarifa (nombre, descuento_pct) VALUES
('General',    0.00),    -- 1
('Estudiante', 25.00),   -- 2
('Jubilado',   30.00),   -- 3
('Acreditado', 50.00),   -- 4
('VIP',        100.00);  -- 5  (entrada $0, pero queda registrada por control de aforo)

INSERT INTO tipo_abono (nombre, descripcion, precio_base, num_accesos) VALUES
('Abono Fin de Semana', 'Acceso a 5 proyecciones entre viernes y domingo.', 300,  5),  -- 1
('Abono Total',         'Acceso a 20 proyecciones durante todo el festival.', 800, 20), -- 2
('Abono Documental',    'Acceso a 4 proyecciones de la muestra documental.',  200,  4);  -- 3

-- ----------------------------------------------------------------------------
-- VENTAS DE ENTRADAS — registradas con el procedimiento P1
-- CALL sp_comprar_entrada(asistente, proyeccion, tarifa)
-- ----------------------------------------------------------------------------
CALL sp_comprar_entrada( 5,  1, 1, @res);
CALL sp_comprar_entrada( 6,  1, 2, @res);
CALL sp_comprar_entrada( 7,  1, 1, @res);
CALL sp_comprar_entrada( 8,  1, 1, @res);
CALL sp_comprar_entrada(15,  1, 3, @res);
CALL sp_comprar_entrada( 1,  1, 5, @res);   -- VIP: $0 pero descuenta aforo
CALL sp_comprar_entrada( 9,  2, 2, @res);
CALL sp_comprar_entrada(10,  2, 1, @res);
CALL sp_comprar_entrada(11,  2, 1, @res);
CALL sp_comprar_entrada( 2,  2, 4, @res);   -- Acreditado (Prensa): 50%
CALL sp_comprar_entrada(12,  3, 2, @res);
CALL sp_comprar_entrada(13,  3, 1, @res);
CALL sp_comprar_entrada(14,  3, 1, @res);
CALL sp_comprar_entrada(16,  3, 3, @res);
CALL sp_comprar_entrada( 1,  3, 5, @res);   -- VIP
CALL sp_comprar_entrada(17,  4, 2, @res);
CALL sp_comprar_entrada(18,  4, 1, @res);
CALL sp_comprar_entrada(19,  5, 1, @res);
CALL sp_comprar_entrada(20,  5, 2, @res);
CALL sp_comprar_entrada(21,  6, 1, @res);
CALL sp_comprar_entrada(22,  6, 2, @res);
CALL sp_comprar_entrada( 3,  7, 4, @res);   -- Acreditado (Industria)
CALL sp_comprar_entrada( 5,  8, 1, @res);
CALL sp_comprar_entrada( 6,  8, 2, @res);
CALL sp_comprar_entrada( 9,  9, 2, @res);
CALL sp_comprar_entrada(10, 10, 1, @res);
CALL sp_comprar_entrada(12, 11, 2, @res);
CALL sp_comprar_entrada(15, 11, 3, @res);
CALL sp_comprar_entrada(17, 12, 2, @res);
CALL sp_comprar_entrada(18, 12, 1, @res);

-- ----------------------------------------------------------------------------
-- VENTAS DE ABONOS — registradas con la transacción T1
-- CALL sp_vender_abono(asistente, tipo_abono, tarifa, pago_aprobado)
-- Genera códigos predecibles: ACC-<abono>-<consecutivo>
-- ----------------------------------------------------------------------------
CALL sp_vender_abono( 5, 1, 1, 1, @res);   -- abono 1: Fin de Semana, tarifa General
CALL sp_vender_abono( 6, 2, 1, 1, @res);   -- abono 2: Total, tarifa General
CALL sp_vender_abono( 7, 3, 2, 1, @res);   -- abono 3: Documental, tarifa Estudiante

-- Canje de códigos de abono en proyecciones (cuenta como asistencia real)
CALL sp_usar_codigo_abono('ACC-0001-001',  1);
CALL sp_usar_codigo_abono('ACC-0001-002',  3);
CALL sp_usar_codigo_abono('ACC-0002-001',  2);
CALL sp_usar_codigo_abono('ACC-0002-002',  3);
CALL sp_usar_codigo_abono('ACC-0002-003',  9);
CALL sp_usar_codigo_abono('ACC-0003-001',  5);
CALL sp_usar_codigo_abono('ACC-0003-002',  7);

-- ----------------------------------------------------------------------------
-- Inscripciones a eventos paralelos (registro administrativo directo)
-- ----------------------------------------------------------------------------
INSERT INTO venta (asistente_id, tipo_venta, total) VALUES (8, 'Entrada', 150);
SET @v_evento1 = LAST_INSERT_ID();
INSERT INTO pago (venta_id, metodo, monto, estado) VALUES (@v_evento1, 'Online', 150, 'Aprobado');
INSERT INTO entrada (venta_id, evento_id, tarifa_id, precio_pagado, codigo)
VALUES (@v_evento1, 1, 1, 150, CONCAT('EVT-', LPAD(@v_evento1, 8, '0')));
UPDATE evento SET aforo_disponible = aforo_disponible - 1 WHERE evento_id = 1;

INSERT INTO venta (asistente_id, tipo_venta, total) VALUES (9, 'Entrada', 187.5);
SET @v_evento2 = LAST_INSERT_ID();
INSERT INTO pago (venta_id, metodo, monto, estado) VALUES (@v_evento2, 'Online', 187.5, 'Aprobado');
INSERT INTO entrada (venta_id, evento_id, tarifa_id, precio_pagado, codigo)
VALUES (@v_evento2, 2, 2, 187.5, CONCAT('EVT-', LPAD(@v_evento2, 8, '0')));
UPDATE evento SET aforo_disponible = aforo_disponible - 1 WHERE evento_id = 2;

-- ----------------------------------------------------------------------------
-- Logística de invitados: hoteles, alojamientos y traslados
-- ----------------------------------------------------------------------------
INSERT INTO hotel (nombre, direccion, telefono) VALUES
('Hotel Los Tajibos',  'Av. San Martín #455, Equipetrol, Santa Cruz de la Sierra', '+591 3 342 1000'),  -- 1
('Camino Real Hotel',  'Av. San Martín #2828, Santa Cruz de la Sierra',            '+591 3 343 4000'); -- 2

INSERT INTO alojamiento (persona_id, hotel_id, edicion_id, habitacion, fecha_checkin, fecha_checkout) VALUES
(7,  1, 2, '501', '2026-06-09', '2026-06-15'),   -- Rod Blackhurst (director invitado)
(12, 1, 2, '502', '2026-06-09', '2026-06-21'),   -- Marco Antonelli (jurado)
(4,  2, 2, '203', '2026-06-11', '2026-06-14');   -- Jon Favreau (director invitado)

INSERT INTO traslado (persona_id, edicion_id, tipo, origen, destino, fecha_hora, referencia, notas) VALUES
(7,  2, 'Vuelo',     'Los Ángeles (LAX)',       'Santa Cruz de la Sierra (VVI)',  '2026-06-09 08:30:00', 'AV-0089', 'Clase ejecutiva, escala en São Paulo'),
(12, 2, 'Vuelo',     'Roma (FCO)',              'Santa Cruz de la Sierra (VVI)',  '2026-06-09 11:15:00', 'AZ-0680', NULL),
(7,  2, 'Terrestre', 'Aeropuerto Viru Viru (VVI)', 'Hotel Los Tajibos', '2026-06-09 15:00:00', 'VAN-03',  'Recogida oficial del festival');

-- ----------------------------------------------------------------------------
-- Patrocinadores y patrocinios (incluye histórico 2025)
-- ----------------------------------------------------------------------------
INSERT INTO patrocinador (nombre, contacto_nombre, contacto_email) VALUES
('Banco Mercantil Santa Cruz', 'Patricia Lemos',  'p.lemos@bancomercantil.com.bo'),  -- 1
('Cervecería Boliviana Nacional (CBN)', 'Jorge Iván Mesa', 'j.mesa@cbn.bo'),         -- 2
('AltaVisión Streaming',  'Renata Cuéllar',  'r.cuellar@altavision.tv');              -- 3

INSERT INTO patrocinio (patrocinador_id, edicion_id, tipo_aporte, monto, descripcion) VALUES
(1, 1, 'Economica', 500000, 'Patrocinio principal edición 2025'),
(1, 2, 'Economica', 800000, 'Patrocinio principal edición 2026'),
(2, 2, 'Especie',   NULL,     'Barra de bebidas para coctel de apertura y clausura'),
(3, 2, 'Economica', 450000, 'Patrocinio de la competencia documental + streaming de la premiación');
