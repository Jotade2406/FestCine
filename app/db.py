"""Capa de acceso a datos de la aplicación FestCine.

Regla del proyecto (Fase 5): la aplicación cliente NO contiene lógica de
negocio ni SQL embebido. Toda interacción se hace a través de:
  - VISTAS del servidor   -> leer_vista()
  - PROCEDIMIENTOS        -> llamar_procedimiento()
"""

import pymysql
import pymysql.cursors

from config import DB_CONFIG

# Lista blanca de vistas publicadas por sql/02_programacion.sql
VISTAS = {
    "v_cartelera",
    "v_proyecciones",
    "v_salas",
    "v_tarifas",
    "v_tipos_abono",
    "v_asistentes",
    "v_ranking_peliculas",
    "v_acta_premiacion",
    "v_informe_financiero",
    "v_ventas",
    "v_compras",
    "v_factura_detalle",
}


def _conectar():
    return pymysql.connect(cursorclass=pymysql.cursors.DictCursor, **DB_CONFIG)


def leer_vista(nombre: str) -> list[dict]:
    """Devuelve todas las filas de una vista publicada en el servidor."""
    if nombre not in VISTAS:
        raise ValueError(f"Vista no autorizada: {nombre}")
    con = _conectar()
    try:
        with con.cursor() as cur:
            cur.execute(f"SELECT * FROM {nombre}")
            return cur.fetchall()
    finally:
        con.close()


def llamar_procedimiento(nombre: str, parametros: tuple,
                         con_salida: bool = False) -> dict | None:
    """Invoca un procedimiento almacenado y devuelve su primera fila de
    resultado (los procedimientos de FestCine responden con un SELECT final).

    Si `con_salida` es True, el procedimiento declara un parámetro OUT al
    final (p_resultado); se recupera con `SELECT @resultado` y se agrega a
    la fila devuelta bajo la clave 'resultado'.

    Los errores SIGNAL del servidor (aforo agotado, cruce de horarios,
    pasarela rechazada...) se propagan como pymysql.MySQLError para que la
    capa web los convierta en mensajes amigables.
    """
    marcadores = ", ".join(["%s"] * len(parametros))
    if con_salida:
        marcadores = f"{marcadores}, @resultado" if marcadores else "@resultado"
    con = _conectar()
    try:
        with con.cursor() as cur:
            cur.execute(f"CALL {nombre}({marcadores})", parametros)
            resultado = cur.fetchone()
            while cur.nextset():
                pass
            if con_salida:
                cur.execute("SELECT @resultado AS resultado")
                salida = cur.fetchone()
                resultado = dict(resultado or {})
                resultado["resultado"] = salida["resultado"]
        con.commit()
        return resultado
    finally:
        con.close()


def llamar_procedimiento_tabla(nombre: str, parametros: tuple = ()) -> list[dict]:
    """Invoca un procedimiento que devuelve un conjunto de filas
    (p. ej. sp_generar_reporte) y retorna todas las filas."""
    marcadores = ", ".join(["%s"] * len(parametros))
    con = _conectar()
    try:
        with con.cursor() as cur:
            cur.execute(f"CALL {nombre}({marcadores})", parametros)
            return cur.fetchall()
    finally:
        con.close()
