"""
Universidad Nacional de La Matanza (UNLaM) - 3641 Bases de Datos Aplicada
Entrega 9: App de consola en Python para ABM de op.Club usando los SPs de Entrega 5.
"""

import pyodbc

# Cambiar SERVER si usás instancia nombrada (ej: "localhost\\SQLEXPRESS")
SERVER = "localhost"
DATABASE = "Mundial2026"


def conectar():
    drivers = [d for d in pyodbc.drivers() if "SQL Server" in d]
    driver = next((d for d in drivers if "17" in d or "18" in d), drivers[0])
    conn_str = (
        f"DRIVER={{{driver}}};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        f"Trusted_Connection=yes;"
        f"TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str, autocommit=True)


def listar(conn):
    print("\n--- LISTADO DE CLUBES ---")
    for row in conn.cursor().execute("SELECT IdClub, Nombre FROM op.Club ORDER BY IdClub;"):
        print(f"  {row.IdClub:>3} | {row.Nombre}")


def alta(conn):
    nombre = input("Nombre del nuevo club: ").strip()
    conn.cursor().execute("EXEC op.usp_AltaClub @Nombre = ?;", nombre)
    print(f"OK: Club '{nombre}' dado de alta.")


def modificar(conn):
    id_club = int(input("ID del club a modificar: "))
    nombre = input("Nuevo nombre: ").strip()
    conn.cursor().execute("EXEC op.usp_ModificarClub @IdClub = ?, @Nombre = ?;", id_club, nombre)
    print(f"OK: Club ID {id_club} actualizado.")


def baja(conn):
    id_club = int(input("ID del club a eliminar: "))
    conn.cursor().execute("EXEC op.usp_BajaClub @IdClub = ?;", id_club)
    print(f"OK: Club ID {id_club} eliminado.")


def main():
    with conectar() as conn:
        while True:
            print("\n=== MUNDIAL 2026 - ABM DE CLUBES ===")
            print("1. Listar clubes")
            print("2. Alta de club")
            print("3. Modificar club")
            print("4. Baja de club")
            print("0. Salir")
            op = input("Elegí una opción: ").strip()
            try:
                if op == "1":
                    listar(conn)
                elif op == "2":
                    alta(conn)
                elif op == "3":
                    modificar(conn)
                elif op == "4":
                    baja(conn)
                elif op == "0":
                    break
                else:
                    print("Opción inválida.")
            except Exception as e:
                print(f"ERROR: {e}")


if __name__ == "__main__":
    main()
