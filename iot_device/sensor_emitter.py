import requests
import time
import random

API_URL = "http://127.0.0.1:8000/lecturas/"
ESTACION_ID = 1  # Asegúrate de que este ID exista en tu base de datos
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbl9maXNpIiwiZXhwIjoxNzc5OTEyNDc3fQ.JHntK8cx2XYB2QXRAd-481S5TQedzrZt1B_IUco2nsM"  # Reemplaza con el token generado en /token

def leer_sensor_emulado() -> float:
    return round(random.uniform(10.5, 85.0), 2)

def enviar_telemetria():
    print(f"\n==================================================")
    print(f"--- INICIANDO EMISOR IOT: ESTACIÓN ID {ESTACION_ID} ---")
    print(f"==================================================")
    
    headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json"
    }

    while True:
        valor = leer_sensor_emulado()
        payload = {
            "valor": valor,
            "estacion_id": ESTACION_ID
        }

        try:
            # Enviamos la telemetría al endpoint de FastAPI
            response = requests.post(API_URL, json=payload, headers=headers, timeout=5)
            
            if response.status_code == 200 or response.status_code == 201:
                print(f"[OK] {time.strftime('%H:%mm:%ss')} -> Lectura enviada con éxito: {valor} cm")
            elif response.status_code == 401:
                print(f"[ERROR] Código 401: Token inválido o expirado. Genera uno nuevo.")
            elif response.status_code == 404:
                print(f"[ERROR] Código 404: La estación con ID {ESTACION_ID} no existe en la base de datos.")
            else:
                print(f"[ERROR] Código {response.status_code} inesperado: {response.text}")
                
        except requests.exceptions.ConnectionError:
            print(f"[CRÍTICO] No se pudo conectar con el servidor en {API_URL}. ¿Está FastAPI corriendo?")
        except requests.exceptions.Timeout:
            print(f"[ALERTA] Tiempo de espera agotado al conectar con el backend.")
        except Exception as e:
            print(f"[INESPERADO] Ocurrió un error no controlado: {e}")

        time.sleep(5)

if __name__ == "__main__":
    enviar_telemetria()