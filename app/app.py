"""FestCine — Aplicación cliente (Fase 5).

Aplicación web Flask con dos perfiles de uso:

  CLIENTE (asistente registrado, ingresa con su correo)
    - Cartelera y ficha de película con horarios -> compra invoca P1
    - Abonos -> compra invoca la transacción T1
    - Mis compras (vista v_compras)

  ADMINISTRADOR (coordinador del festival, usuario y clave)
    - Panel de agenda (Módulo 2): programar proyecciones; el INSERT lo
      valida el trigger TR1 y el bloqueo se informa amigablemente
    - Ventas: listado de ventas + informe financiero (Fase 3)
    - Reportes: ranking de ocupación y acta de premiación (Fase 3)
    - En la ficha de película actúa como CAJERO: puede vender una
      entrada a cualquier asistente (Módulo 1)

La aplicación NO contiene sentencias SQL de negocio: solo lee vistas e
invoca procedimientos almacenados (ver db.py).
"""

import os
from datetime import date
from functools import wraps

from flask import Flask, Response, flash, redirect, render_template, request, session, url_for
from fpdf import FPDF
from pymysql import MySQLError

import db
from config import ADMIN_PASS, ADMIN_USER

app = Flask(__name__)
app.secret_key = "festcine-demo-2026"

ER_SIGNAL_EXCEPTION = 1644  # errno de los errores SIGNAL SQLSTATE '45000'

DIAS_ES = ["LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB", "DOM"]
MESES_ES = ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]

# Banners del carrusel principal (artes promocionales en app/static/banners)
BANNERS = {
    "revelacion.jpg": "banner_revelacion.webp",
    "scary_movie.jpg": "banner_scary.webp",
    "digital_circus.jpg": "banner_amazing.webp",
}


@app.template_filter("duracion")
def filtro_duracion(minutos) -> str:
    """Formatea minutos como '1h 52m' (estilo cartelera de cine)."""
    horas, mins = divmod(int(minutos), 60)
    return f"{horas}h {mins:02d}m" if horas else f"{mins}m"


def mensaje_amigable(exc: Exception) -> str:
    """Convierte un error del servidor MySQL en un mensaje para el usuario.

    Los SIGNAL de los procedimientos/triggers (errno 1644) traen un texto de
    negocio pensado para mostrarse tal cual; cualquier otro error de base de
    datos se oculta tras un mensaje genérico (nunca se muestra SQL crudo).
    """
    if isinstance(exc, MySQLError) and len(exc.args) >= 2 and exc.args[0] == ER_SIGNAL_EXCEPTION:
        return f"Lo sentimos: {exc.args[1]}."
    return "Ocurrió un error inesperado al procesar la operación. Inténtalo de nuevo."


def requiere_rol(rol: str):
    """Protege una ruta para que solo la use el perfil indicado."""
    def decorador(funcion):
        @wraps(funcion)
        def envoltura(*args, **kwargs):
            if session.get("rol") != rol:
                flash("Inicia sesión con el perfil adecuado para acceder a esa sección.", "error")
                return redirect(url_for("login", next=request.path))
            return funcion(*args, **kwargs)
        return envoltura
    return decorador


def _disponibilidad(aforo: int, capacidad: int) -> str:
    """Clasifica la ocupación de una función como en las cadenas de cine."""
    if aforo <= 0:
        return "lleno"
    ratio = aforo / capacidad if capacidad else 0
    if ratio >= 0.6:
        return "alta"
    if ratio >= 0.3:
        return "media"
    return "baja"


# ============================================================================
#  AUTENTICACIÓN
#  - Clientes: registro e inicio de sesión mediante los procedimientos
#    sp_registrar_asistente y sp_login_asistente (correo O usuario + clave).
#  - Administrador: credenciales de demostración (acceso discreto).
# ============================================================================
def _iniciar_sesion_cliente(fila: dict) -> None:
    session.clear()
    session["rol"] = "cliente"
    session["asistente_id"] = fila["asistente_id"]
    session["nombre"] = fila["nombre_completo"]


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        destino = request.form.get("next") or None
        accion = request.form.get("accion")

        if accion == "admin":
            if (request.form.get("usuario") == ADMIN_USER
                    and request.form.get("clave") == ADMIN_PASS):
                session.clear()
                session["rol"] = "admin"
                session["nombre"] = "Administración FestCine"
                flash("Bienvenido, administrador.", "exito")
                return redirect(destino or url_for("agenda"))
            flash("Usuario o clave de administrador incorrectos.", "error")

        elif accion == "registro":
            try:
                fila = db.llamar_procedimiento("sp_registrar_asistente", (
                    request.form["nombre"],
                    request.form["apellidos"],
                    request.form["email"],
                    request.form["usuario"],
                    request.form["clave"],
                    request.form.get("telefono", ""),
                ))
                _iniciar_sesion_cliente(fila)
                flash(f"¡Cuenta creada! Bienvenido, {fila['nombre_completo']}.", "exito")
                return redirect(destino or url_for("taquilla"))
            except MySQLError as exc:
                flash(mensaje_amigable(exc), "error")

        else:  # inicio de sesión de cliente
            try:
                fila = db.llamar_procedimiento("sp_login_asistente", (
                    request.form["login"],
                    request.form["clave"],
                ))
                _iniciar_sesion_cliente(fila)
                flash(f"Hola, {fila['nombre_completo']}. ¡Disfruta el festival!", "exito")
                return redirect(destino or url_for("taquilla"))
            except MySQLError as exc:
                flash(mensaje_amigable(exc), "error")

    return render_template("login.html", siguiente=request.args.get("next", ""))


@app.route("/logout")
def logout():
    session.clear()
    flash("Sesión cerrada. ¡Vuelve pronto!", "exito")
    return redirect(url_for("taquilla"))


@app.route("/")
def inicio():
    if session.get("rol") == "admin":
        return redirect(url_for("agenda"))
    return redirect(url_for("taquilla"))


# ============================================================================
#  MÓDULO 1: CARTELERA Y VENTA DE ENTRADAS (Cliente / Cajero-admin)
# ============================================================================
@app.route("/taquilla")
def taquilla():
    peliculas = db.leer_vista("v_cartelera")
    hero = [
        {"pelicula_id": p["pelicula_id"], "titulo": p["titulo"], "banner": BANNERS[p["poster"]]}
        for p in peliculas
        if p["poster"] in BANNERS
    ]
    return render_template("taquilla.html", peliculas=peliculas, hero=hero)


@app.route("/pelicula/<int:pelicula_id>")
def pelicula_detalle(pelicula_id: int):
    """Ficha de la película: póster, sinopsis y horarios agrupados por
    fecha y sede, con semáforo de disponibilidad de asientos."""
    pelicula = next(
        (p for p in db.leer_vista("v_cartelera") if p["pelicula_id"] == pelicula_id), None
    )
    if pelicula is None:
        flash("La película no hace parte de la cartelera de la edición vigente.", "error")
        return redirect(url_for("taquilla"))

    funciones = sorted(
        (f for f in db.leer_vista("v_proyecciones") if f["pelicula_id"] == pelicula_id),
        key=lambda f: f["fecha_hora"],
    )

    hoy = date.today()
    fechas, agenda = [], {}
    for f in funciones:
        d = f["fecha_hora"].date()
        clave = d.isoformat()
        if clave not in agenda:
            agenda[clave] = []
            fechas.append({
                "clave": clave,
                "dia": "HOY" if d == hoy else DIAS_ES[d.weekday()],
                "fecha": f"{d.day:02d}/{MESES_ES[d.month - 1]}",
            })
        agenda[clave].append({
            "proyeccion_id": f["proyeccion_id"],
            "hora": f"{f['fecha_hora']:%H:%M}",
            "sede": f["sede"],
            "direccion": f["sede_direccion"],
            "sala": f["sala"],
            "qa": bool(f["tiene_qa"]),
            "disp": _disponibilidad(f["aforo_disponible"], f["capacidad"]),
            "info": (
                f"{DIAS_ES[d.weekday()]} {d.day:02d}/{MESES_ES[d.month - 1]} · "
                f"{f['fecha_hora']:%H:%M} · {f['sala']} ({f['sede']}) · "
                f"Bs {f['precio_base']:,.2f}"
            ),
        })

    # El administrador actúa como cajero: puede elegir el asistente
    asistentes = db.leer_vista("v_asistentes") if session.get("rol") == "admin" else []

    return render_template(
        "pelicula.html",
        pelicula=pelicula,
        fechas=fechas,
        agenda=agenda,
        tarifas=db.leer_vista("v_tarifas"),
        asistentes=asistentes,
    )


@app.route("/taquilla/comprar", methods=["POST"])
def comprar_entrada():
    if session.get("rol") == "admin":
        asistente_id = request.form["asistente_id"]      # venta en taquilla
    elif session.get("rol") == "cliente":
        asistente_id = session["asistente_id"]           # compra propia
    else:
        flash("Inicia sesión para comprar entradas.", "error")
        return redirect(url_for("login", next=request.form.get("volver", "")))

    try:
        resultado = db.llamar_procedimiento("sp_comprar_entrada", (
            asistente_id,
            request.form["proyeccion_id"],
            request.form["tarifa_id"],
        ), con_salida=True)
        flash(f"✔ {resultado['resultado']}", "exito")
        return redirect(url_for("factura_ver", venta_id=resultado["venta_id"]))
    except MySQLError as exc:
        flash(mensaje_amigable(exc), "error")
    return redirect(request.form.get("volver") or url_for("taquilla"))


# ============================================================================
#  VENTA DE ABONOS (transacción crítica T1)
# ============================================================================
@app.route("/abonos")
def abonos():
    return render_template(
        "abonos.html",
        tipos=db.leer_vista("v_tipos_abono"),
        tarifas=db.leer_vista("v_tarifas"),
        asistentes=db.leer_vista("v_asistentes") if session.get("rol") == "admin" else [],
    )


@app.route("/abonos/comprar", methods=["POST"])
def comprar_abono():
    if session.get("rol") == "admin":
        asistente_id = request.form["asistente_id"]
    elif session.get("rol") == "cliente":
        asistente_id = session["asistente_id"]
    else:
        flash("Inicia sesión para comprar un abono.", "error")
        return redirect(url_for("login", next=url_for("abonos")))

    # El checkbox permite demostrar el ROLLBACK: simula que la pasarela rechaza
    pago_aprobado = 0 if request.form.get("simular_fallo") else 1
    try:
        resultado = db.llamar_procedimiento("sp_vender_abono", (
            asistente_id,
            request.form["tipo_abono_id"],
            request.form["tarifa_id"],
            pago_aprobado,
        ), con_salida=True)
        flash(f"✔ {resultado['resultado']}", "exito")
        return redirect(url_for("factura_ver", venta_id=resultado["venta_id"]))
    except MySQLError as exc:
        flash(mensaje_amigable(exc), "error")
    return redirect(url_for("abonos"))


# ============================================================================
#  FACTURA: confirmación de compra + descarga en PDF
# ============================================================================
def _factura_autorizada(venta_id: int) -> dict | None:
    """Busca la factura y valida que el usuario en sesión pueda verla."""
    fila = next(
        (f for f in db.leer_vista("v_factura_detalle") if f["venta_id"] == venta_id), None
    )
    if fila is None:
        return None
    if session.get("rol") == "admin":
        return fila
    if session.get("rol") == "cliente" and fila["asistente_id"] == session["asistente_id"]:
        return fila
    return None


@app.route("/factura/<int:venta_id>")
def factura_ver(venta_id: int):
    fila = _factura_autorizada(venta_id)
    if fila is None:
        flash("No se encontró la factura o no tienes permiso para verla.", "error")
        return redirect(url_for("inicio"))
    return render_template("factura.html", f=fila)


@app.route("/factura/<int:venta_id>/pdf")
def factura_pdf(venta_id: int):
    fila = _factura_autorizada(venta_id)
    if fila is None:
        flash("No se encontró la factura o no tienes permiso para verla.", "error")
        return redirect(url_for("inicio"))
    pdf = _generar_pdf_factura(fila)
    return Response(
        pdf,
        mimetype="application/pdf",
        headers={"Content-Disposition":
                 f"attachment; filename=factura_{fila['numero_factura']}.pdf"},
    )


def _latin(texto) -> str:
    """fpdf2 con fuentes base usa latin-1: degrada los caracteres que no existan."""
    return str(texto).encode("latin-1", "replace").decode("latin-1")


def _generar_pdf_factura(f: dict) -> bytes:
    """Construye el PDF de la factura con el póster de la película y todos
    los detalles de la compra (concepto, función, tarifa, totales)."""
    pdf = FPDF(format="A4")
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.add_page()

    # Encabezado
    pdf.set_fill_color(200, 16, 46)
    pdf.rect(0, 0, 210, 26, "F")
    pdf.set_text_color(255, 255, 255)
    pdf.set_font("helvetica", "B", 20)
    pdf.set_xy(12, 7)
    pdf.cell(100, 12, "FESTCINE 2026")
    pdf.set_font("helvetica", "", 11)
    pdf.set_xy(120, 7)
    pdf.cell(78, 6, _latin(f"Factura {f['numero_factura']}"), align="R")
    pdf.set_xy(120, 13)
    pdf.cell(78, 6, _latin(f"{f['fecha_emision']:%d/%m/%Y %H:%M}"), align="R")

    # Póster de la película (si la compra fue de una proyección)
    y_detalle = 38
    x_detalle = 12
    if f["poster"]:
        ruta = os.path.join(app.static_folder, "posters", f["poster"])
        if os.path.exists(ruta):
            pdf.image(ruta, x=12, y=y_detalle, w=58)
            x_detalle = 78

    pdf.set_text_color(20, 20, 25)
    pdf.set_xy(x_detalle, y_detalle)
    pdf.set_font("helvetica", "B", 15)
    pdf.multi_cell(198 - x_detalle, 8, _latin(f["concepto"]))

    pdf.set_font("helvetica", "", 11)
    detalles = [
        ("Cliente", f["asistente"]),
        ("Correo", f["email"]),
        ("Tipo de venta", f["tipo_venta"]),
        ("Codigo", f["codigo"]),
        ("Tarifa", f["tarifa"]),
        ("Metodo de pago", f["metodo_pago"]),
    ]
    if f["funcion"]:
        detalles.insert(3, ("Funcion", f"{f['funcion']:%d/%m/%Y %H:%M}"))
        detalles.insert(4, ("Sala", f"{f['sala']} - {f['sede']}"))
        if f["duracion_min"]:
            detalles.insert(5, ("Duracion", f"{f['duracion_min']} min ({f['clasificacion']})"))

    y = pdf.get_y() + 4
    for etiqueta, valor in detalles:
        pdf.set_xy(x_detalle, y)
        pdf.set_font("helvetica", "B", 10)
        pdf.cell(34, 7, _latin(etiqueta))
        pdf.set_font("helvetica", "", 10)
        pdf.cell(0, 7, _latin(valor))
        y += 7

    # Totales
    y = max(y + 8, y_detalle + 95)
    pdf.set_draw_color(200, 16, 46)
    pdf.line(120, y, 198, y)
    for etiqueta, valor, negrita in (
        ("Subtotal", f["subtotal"], False),
        ("IVA (19%)", f["impuestos"], False),
        ("TOTAL", f["total"], True),
    ):
        y += 8
        pdf.set_xy(120, y)
        pdf.set_font("helvetica", "B" if negrita else "", 11 if negrita else 10)
        pdf.cell(40, 7, _latin(etiqueta))
        pdf.cell(38, 7, _latin(f"Bs {valor:,.2f}"), align="R")

    pdf.set_xy(12, y + 18)
    pdf.set_font("helvetica", "I", 8)
    pdf.set_text_color(120, 120, 130)
    pdf.multi_cell(186, 4, _latin(
        "Festival Internacional de Cine Independiente FestCine - Santa Cruz de la Sierra, Bolivia. "
        "Documento generado por el sistema de boleteria; presenta el codigo en el ingreso a la sala."
    ))
    return bytes(pdf.output())


# ============================================================================
#  PERFIL CLIENTE: MIS COMPRAS
# ============================================================================
@app.route("/mis-compras")
@requiere_rol("cliente")
def mis_compras():
    compras = [
        c for c in db.leer_vista("v_compras")
        if c["asistente_id"] == session["asistente_id"]
    ]
    compras.sort(key=lambda c: c["fecha_venta"], reverse=True)
    return render_template("mis_compras.html", compras=compras)


# ============================================================================
#  MÓDULO 2 (ADMIN): PANEL DE CONTROL DE AGENDA
# ============================================================================
@app.route("/agenda")
@requiere_rol("admin")
def agenda():
    proyecciones = sorted(db.leer_vista("v_proyecciones"), key=lambda p: p["fecha_hora"])
    return render_template(
        "agenda.html",
        proyecciones=proyecciones,
        peliculas=db.leer_vista("v_cartelera"),
        salas=db.leer_vista("v_salas"),
    )


@app.route("/agenda/programar", methods=["POST"])
@requiere_rol("admin")
def programar_proyeccion():
    # input datetime-local entrega "2026-06-12T18:00"
    fecha_hora = request.form["fecha_hora"].replace("T", " ")
    try:
        resultado = db.llamar_procedimiento("sp_programar_proyeccion", (
            request.form["pelicula_id"],
            request.form["sala_id"],
            fecha_hora,
            request.form["precio_base"],
            1 if request.form.get("tiene_qa") else 0,
        ), con_salida=True)
        flash(f"✔ {resultado['resultado']}", "exito")
    except MySQLError as exc:
        flash(mensaje_amigable(exc), "error")
    return redirect(url_for("agenda"))


# ============================================================================
#  ADMIN: VENTAS Y REPORTES (Fase 3 publicada como vistas)
# ============================================================================
@app.route("/ventas")
@requiere_rol("admin")
def ventas():
    return render_template(
        "ventas.html",
        ventas=db.leer_vista("v_ventas"),
        finanzas=db.leer_vista("v_informe_financiero"),
    )


@app.route("/reportes")
@requiere_rol("admin")
def reportes():
    # Los datos de cada reporte los genera el procedimiento sp_generar_reporte
    return render_template(
        "reportes.html",
        ranking=db.llamar_procedimiento_tabla("sp_generar_reporte", ("ranking",)),
        acta=db.llamar_procedimiento_tabla("sp_generar_reporte", ("acta",)),
        finanzas=db.llamar_procedimiento_tabla("sp_generar_reporte", ("financiero",)),
    )


if __name__ == "__main__":
    app.run(debug=True, port=5000)
