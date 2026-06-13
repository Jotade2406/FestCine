"""Configuración de conexión a la base de datos FestCine.

El usuario 'festcine_app' lo crea el script sql/02_programacion.sql y SOLO
tiene permisos de SELECT (vistas) y EXECUTE (procedimientos): la aplicación
no puede modificar tablas directamente.
"""

DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 3306,
    "user": "festcine_app",
    "password": "festcine123",
    "database": "festcine",
    "charset": "utf8mb4",
}

# Credenciales del perfil Administrador (demo académica; en producción irían
# en una tabla de usuarios con contraseñas cifradas)
ADMIN_USER = "admin"
ADMIN_PASS = "admin123"
