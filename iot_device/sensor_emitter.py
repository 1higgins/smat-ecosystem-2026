import requests
import time
import random

API_URL = "http://127.0.0.1:8000/lecturas/"

def leer_sensor_emulado() -> float:
    return round(random.uniform(10.5, 85.0), 2)

def generar_token():
    url = "http://127.0.0.1:8000/token"

    try:
        response = requests.post(url, timeout=5)
        if response.status_code == 200:
            token_nuevo = response.json().get("access_token")
            print(f"[TOKEN OBTENIDO]")
            return token_nuevo
    except Exception as e:
        print(f"[ERROR] No se pudo generar el token: {e}")
    return None

def obtener_ids_estaciones_dinamico():
    """Consulta al backend las estaciones reales creadas en el sistema"""
    url = f"http://127.0.0.1:8000/estaciones/"
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            # Extraemos la lista de ids de la respuesta JSON
            estaciones = response.json()
            ids = [estacion["id"] for estacion in estaciones]
            return ids
        return []
    except Exception:
        return []

def enviar_telemetria():
    print(f"\n==================================================")
    print(f"--- BUSCANDO ESTACIONES ---")
    print(f"==================================================")
    
    token = generar_token()
    if not token:
        print("[ERROR] No se pudo obtener un token válido. Verifica el backend.")
        return

    while True:

        headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
        }
        lista_estaciones = obtener_ids_estaciones_dinamico()

        if not lista_estaciones:
            print("No se encontraron estaciones creadas en la aplicacion")
            time.sleep(5)
            continue

        estacion_actual = random.choice(lista_estaciones)
        valor = leer_sensor_emulado()

        if valor > 70.0:
            print(f"[ALERTA] Lectura critica de valor encontrada: {valor} en la estacion {estacion_actual}")
            tiempo_espera = 2
        else:
            tiempo_espera = 4

        payload = {
            "valor": valor,
            "estacion_id": estacion_actual
        }

        try:
            response = requests.post(API_URL, json=payload, headers=headers, timeout=5)
            
            if response.status_code == 200 or response.status_code == 201:
                print(f"[OK] {time.strftime('%H:%mm:%ss')} -> Lectura enviada con éxito: {valor} cm a la estacion: {estacion_actual}")
            elif response.status_code == 401:
                print(f"[ERROR] Código 401: Token inválido o expirado. Genera uno nuevo.")
            elif response.status_code == 404:
                print(f"[ERROR] Código 404: La estación con ID {estacion_actual} no existe en la base de datos.")
            else:
                print(f"[ERROR] Código {response.status_code} inesperado: {response.text}")
                
        except requests.exceptions.ConnectionError:
            print(f"[CRÍTICO] No se pudo conectar con el servidor en {API_URL}. ¿Está FastAPI corriendo?")
        except requests.exceptions.Timeout:
            print(f"[ALERTA] Tiempo de espera agotado al conectar con el backend.")
        except Exception as e:
            print(f"[INESPERADO] Ocurrió un error no controlado: {e}")

        time.sleep(tiempo_espera)

if __name__ == "__main__":
    enviar_telemetria()