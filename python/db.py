"""
Database Connection and SQL Query Helpers
"""

import os

try:
    import mysql.connector
    HAS_MYSQL_CONNECTOR = True
except ImportError:
    HAS_MYSQL_CONNECTOR = False

try:
    import pymysql
    HAS_PYMYSQL = True
except ImportError:
    HAS_PYMYSQL = False

# Database configuration parameters
# Defaults to 127.0.0.1 (IPv4) to avoid macOS 'localhost' IPv6 ::1 resolution issues
DB_CONFIG = {
    'host': os.environ.get('MYSQL_HOST', '127.0.0.1'),
    'user': os.environ.get('MYSQL_USER', 'root'),
    'password': os.environ.get('MYSQL_PASSWORD', ''),
    'database': os.environ.get('MYSQL_DATABASE', 'uniphyed'),
    'port': int(os.environ.get('MYSQL_PORT', 3306))
}

# Optional Unix Socket if specified
if 'MYSQL_UNIX_SOCKET' in os.environ:
    DB_CONFIG['unix_socket'] = os.environ['MYSQL_UNIX_SOCKET']


def get_db_connection():
    """Establishes and returns a database connection using DB_CONFIG."""
    if not (HAS_MYSQL_CONNECTOR or HAS_PYMYSQL):
        raise RuntimeError("Neither 'mysql-connector-python' nor 'pymysql' is installed.")
    
    if HAS_MYSQL_CONNECTOR:
        return mysql.connector.connect(**DB_CONFIG)
    else:
        return pymysql.connect(**DB_CONFIG)


def execute_scalar(query):
    """Executes a SQL query returning a scalar result (e.g. COUNT or single value)."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        row = cursor.fetchone()
        cursor.close()
        return row[0] if row else 0
    finally:
        conn.close()


def execute_query(query):
    """Executes a SQL query returning all matching rows."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        rows = cursor.fetchall()
        cursor.close()
        return rows
    finally:
        conn.close()


def execute_update(query):
    """Executes an UPDATE/INSERT SQL query."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        conn.commit()
        cursor.close()
    finally:
        conn.close()
