# 🎬 FestCine — Sistema de Gestión del Festival de Cine

Proyecto de base de datos relacional para el festival internacional de cine
independiente **FestCine**: catálogo de películas, agenda de proyecciones,
competición con jurados, boletería (entradas y abonos), logística de invitados
y patrocinios con soporte histórico por ediciones.

| Componente | Tecnología |
|---|---|
| Base de datos | **MySQL 8.0+ / 9.x** |
| Aplicación cliente | **Python 3 + Flask** (web) |
| Acceso a datos | Solo **vistas** y **procedimientos almacenados** (sin SQL embebido) |

## 📁 Estructura del proyecto

```
FestCine/
├── docs/
│   └── Fase1_Modelado.md      Fase 1: DER (Mermaid), normalización 3FN, asunciones
├── sql/                       Ejecutar EN ORDEN (DataGrip, Workbench o consola)
│   ├── 01_esquema.sql         Fase 2: DDL (32 tablas con PK, FK, CHECK, UNIQUE)
│   ├── 02_programacion.sql    Fase 4: función, P1, T1, TR1, vistas y usuario app
│   ├── 03_datos.sql           Fase 2: datos de prueba (vía procedimientos)
│   └── 04_consultas.sql       Fase 3: consultas avanzadas (DQL)
└── app/                       Fase 5: aplicación cliente Flask
    ├── app.py                 Rutas y manejo de errores del servidor
    ├── db.py                  Capa de acceso (vistas + CALL procedimientos)
    ├── config.py              Credenciales de conexión
    └── templates/             Interfaz (taquilla, abonos, agenda, reportes)
```

## 🚀 Puesta en marcha (para cualquier compañero)

### 1. Crear la base de datos

Requisito: un servidor **MySQL 8.0 o superior** corriendo en `localhost:3306`.

Desde **DataGrip**: conéctate con tu usuario `root`, abre los archivos de
`sql/` y ejecútalos **en orden** (01 → 02 → 03; el 04 son las consultas de la
Fase 3 para revisar resultados).

O desde consola:

```bash
mysql -u root -p < sql/01_esquema.sql
mysql -u root -p < sql/02_programacion.sql
mysql -u root -p < sql/03_datos.sql
```

> `01_esquema.sql` borra y recrea la base `festcine`, así que puedes
> re-ejecutar la secuencia completa cuantas veces quieras.
> `02_programacion.sql` también crea el usuario `festcine_app` (clave
> `festcine123`) con permisos de **solo lectura y ejecución**, que es el que
> usa la aplicación: la app no puede tocar las tablas directamente.

### 2. Ejecutar la aplicación

```bash
python -m venv .venv
.venv\Scripts\pip install -r app\requirements.txt    # Windows
cd app
..\.venv\Scripts\python app.py
```

Abrir **http://127.0.0.1:5000**

## 👥 Perfiles y módulos de la aplicación

La app tiene **registro y login** (`/login`):

- **Cliente** — puede **registrarse** (nombre, correo, nombre de usuario y
  contraseña; la valida y registra `sp_registrar_asistente` con hash SHA-256)
  e iniciar sesión con **correo o usuario + contraseña** vía
  `sp_login_asistente`. Compra siempre a su propio nombre y cada compra
  termina en una **factura descargable en PDF** (póster, función, tarifa,
  IVA). Cuentas precargadas: contraseña `12345678` (ej. `laura.gomez@mail.com`
  o usuario `laugomez`).
- **Administrador** — acceso discreto desde el login (`admin / admin123`).
  Ve la operación del festival y además actúa como **cajero** (vende a
  cualquier asistente).

| Módulo | Perfil | Ruta | Mecanismo en el servidor |
|---|---|---|---|
| **Registro / Login** | Público | `/login` | `sp_registrar_asistente` y `sp_login_asistente` (errores SIGNAL amigables: correo duplicado, clave corta, credenciales inválidas). |
| **Cartelera + ficha de película** | Público (compra requiere sesión) | `/taquilla`, `/pelicula/<id>` | Ficha con sinopsis, fechas, disponibilidad de asientos y horarios; la compra invoca **P1 `sp_comprar_entrada`** (que además emite la factura). Si no hay aforo, el SIGNAL del servidor se muestra como mensaje amigable. |
| **Factura + PDF** | Cliente dueño / Admin | `/factura/<venta>` | Vista `v_factura_detalle`; el PDF se genera con fpdf2 e incluye el póster, la función, la tarifa y el desglose de IVA. |
| **Abonos** (T1) | Cliente / Admin | `/abonos` | Invoca **`sp_vender_abono`**: pago + códigos de acceso + factura en una transacción atómica. La casilla *"simular fallo de pasarela"* demuestra el **ROLLBACK**. |
| **Mis compras** | Cliente | `/mis-compras` | Vista `v_compras` filtrada por el asistente en sesión. |
| **Agenda / salas ocupadas** | Admin | `/agenda` | Invoca `sp_programar_proyeccion`; el INSERT lo valida el trigger **TR1**: si la sala está ocupada (duración + 30 min de limpieza) la app informa el bloqueo. Tabla de ocupación con hora de fin y "sala libre". |
| **Ventas** | Admin | `/ventas` | Vistas `v_ventas` (listado) y `v_informe_financiero` (Fase 3). |
| **Reportes** | Admin | `/reportes` | Vistas `v_ranking_peliculas`, `v_acta_premiacion`, `v_informe_financiero` (Fase 3). |

## 🧪 Guion de demostración sugerido

0. **Registro y login** — crea una cuenta nueva (pestaña "Registrarse") y
   observa los errores amigables del servidor (correo duplicado, clave corta).
   Cierra sesión y vuelve a entrar con el **nombre de usuario** y luego con el
   **correo** (misma contraseña). El acceso de administración es el enlace
   discreto de abajo (`admin/admin123`).
1. **Taquilla** — como cliente, abre *El Día de la Revelación*, elige una
   función en las pestañas de fecha y compra con tarifa Estudiante: la
   confirmación es la **factura** con el póster y puedes **descargar el PDF**.
   Como admin, repite la compra eligiendo el asistente (modo cajero).
2. **Aforo agotado** — en DataGrip: `UPDATE proyeccion SET aforo_disponible = 0 WHERE proyeccion_id = 10;`
   e intenta vender para esa función: la app muestra
   *"Lo sentimos: No hay aforo disponible para esta funcion"*.
3. **Abonos** — compra un *Abono Fin de Semana* con la casilla de fallo activada:
   la pasarela rechaza y **nada queda guardado** (verifícalo consultando
   `venta`/`pago`/`factura` antes y después). Repite sin la casilla: se emiten
   abono, 5 códigos de acceso y factura.
4. **Agenda** — intenta programar *Scary Movie* en la **Sala Principal el
   12/06 a las 19:00** (ocupada por *Dolly*, que con limpieza libera la sala a
   las 19:53): el trigger TR1 rechaza el INSERT y la app lo informa. Cámbiala
   a las 15:00 y se programa sin problema.
5. **Reportes** — muestra ranking de ocupación, acta de premiación con
   promedios del jurado e informe financiero por tipo de venta y tarifa.

## 📋 Cumplimiento por fases

- **Fase 1** — [docs/Fase1_Modelado.md](docs/Fase1_Modelado.md): DER, decisiones
  de diseño, normalización hasta 3FN y desnormalizaciones justificadas
  (`aforo_disponible`, precios snapshot), 13 asunciones documentadas.
- **Fase 2** — 32 tablas con integridad completa; datos de prueba: 9 películas,
  4 salas, 14 proyecciones, 22 asistentes, 35 ventas (entradas, abonos,
  canjes, eventos), logística y patrocinios históricos 2025/2026.
- **Fase 3** — Ranking con % de ocupación (asistentes reales = entradas +
  canjes de abono), acta de premiación con promedio del jurado, informe
  financiero con `WITH ROLLUP`, más consultas de apoyo (ventana `RANK()`).
- **Fase 4** — `f_precio_final` (función), **P1** `sp_comprar_entrada` (aforo +
  `FOR UPDATE` + emisión de factura), **T1** `sp_vender_abono` (transacción con
  ROLLBACK), **TR1** `trg_proyeccion_bi` (+ variante BEFORE UPDATE) y
  procedimientos de apoyo (`sp_programar_proyeccion`, `sp_usar_codigo_abono`,
  `sp_registrar_asistente`, `sp_login_asistente`, `sp_generar_reporte`).
  P1, T1 y `sp_programar_proyeccion` incluyen **parámetro de salida
  `OUT p_resultado`** con el resultado de la operación.

## 📊 Mapeo a la rúbrica de evaluación

| Criterio | % | Dónde se cumple |
|---|---|---|
| Modelo lógico completo | 15% | [docs/Fase1_Modelado.md](docs/Fase1_Modelado.md): DER, 3FN, desnormalizaciones justificadas, 16 asunciones. |
| Scripts de creación + datos | 15% | [sql/01_esquema.sql](sql/01_esquema.sql) (32 tablas con PK/FK/CHECK/UNIQUE/NOT NULL) y [sql/03_datos.sql](sql/03_datos.sql) (datos consistentes cargados a través de los propios procedimientos). |
| Procedimientos de negocio con transacción y **parámetro de salida** | 30% | [sql/02_programacion.sql](sql/02_programacion.sql): P1 `sp_comprar_entrada`, T1 `sp_vender_abono` (ROLLBACK demostrable) y `sp_programar_proyeccion`, todos con `OUT p_resultado`. Demo en SQL: `CALL sp_comprar_entrada(10, 4, 1, @r); SELECT @r;` |
| Procedimiento generador de datos para reporte | 15% | `sp_generar_reporte('ranking' \| 'acta' \| 'financiero')` — la página Reportes de la app lo invoca. |
| Capa de negocio/presentación con menú e invocación de procedimientos | 25% | App Flask ([app/](app/)): menú por perfiles (cliente/admin), invoca exclusivamente procedimientos y vistas, maneja los errores SIGNAL con mensajes amigables. |
- **Fase 5** — App Flask sin SQL de negocio embebido (lista blanca de vistas +
  CALL a procedimientos), manejo de excepciones del servidor con mensajes
  amigables, usuario de BD restringido a SELECT/EXECUTE.

> **Nota sobre las imágenes:** los pósters (`app/static/posters/`) y banners
> (`app/static/banners/`) se descargaron de la cartelera pública de
> cinemark.com.bo con fines exclusivamente académicos/demostrativos.

## 🔑 Credenciales

| Uso | Usuario | Clave |
|---|---|---|
| Administración / scripts (MySQL) | `root` | (la tuya) |
| Conexión de la app (MySQL) | `festcine_app` | `festcine123` (lo crea el script 02) |
| Perfil Administrador (web) | `admin` | `admin123` (en [app/config.py](app/config.py)) |
| Perfil Cliente (web) | correo **o** usuario (ej. `laura.gomez@mail.com` / `laugomez`) | `12345678` en cuentas precargadas; las nuevas se registran en la app |

Si tu MySQL usa otro puerto u host, ajusta [app/config.py](app/config.py).
