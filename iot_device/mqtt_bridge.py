import paho.mqtt.client as mqtt
import requests
import json
import sys
import time

MQTT_BROKER = "broker.hivemq.com"
MQTT_PORT = 1883
MQTT_TOPIC = "fisi/smat/estaciones/+/lecturas"

API_URL = "http://backend:8000/lecturas/"
JWT_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbl9maXNpIiwiZXhwIjoxNzgxMTEyMDQwfQ.D6ohyeBWnaTRP_h5uLlUpCOKRL2XEmcxn2LhhS564QA" 

# MEMORIA CACHÉ LOCAL
cache_estaciones = {}

# CONFIGURACIÓN DEL FILTRO DE ZONA MUERTA
UMBRAL_CAMBIO_PORCENTAJE = 0.05
TIEMPO_MAXIMO_REPORTE_SEG = 60

def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print("\n[MQTT] Conectado exitosamente al broker MQTT")
        client.subscribe(MQTT_TOPIC)
        print(f"[MQTT] Escuchando transmisiones en el tópico: {MQTT_TOPIC}")
        print("--------------------------------------------------")
    else:
        print(f"[ERROR] Error de conexión al Broker. Código: {rc}")
        sys.exit(1)
    
def on_message(client, userdata, msg):
    global cache_estaciones
    try:
        payload_raw = msg.payload.decode('utf-8')
        data_json = json.loads(payload_raw)

        # Extraer ID dinámico del tópico
        topic_parts = msg.topic.split('/')
        estacion_id = int(topic_parts[3])
        nuevo_valor = float(data_json["valor"])
        tiempo_actual = time.time()

        print(f"\n[MQTT RECIBIDO] Estación {estacion_id} -> Valor entrante: {nuevo_valor} cm")

        # Variables para decidir si se envía o se bloquea
        debe_enviar = False
        razon_filtro = ""

        # LÓGICA DEL FILTRO POR UMBRAL DE CAMBIO Y TIEMPO MÁXIMO DE REPORTE
        if estacion_id not in cache_estaciones:
            debe_enviar = True
            razon_filtro = "Primera lectura registrada de la estación."
        else:
            datos_anteriores = cache_estaciones[estacion_id]
            ultimo_valor = datos_anteriores["valor"]
            ultimo_timestamp = datos_anteriores["timestamp"]

            # Calcular la variación porcentual absoluta
            if ultimo_valor != 0:
                variacion = abs(nuevo_valor - ultimo_valor) / ultimo_valor
            else:
                variacion = 1.0  # Si era cero, asumimos cambio total

            tiempo_transcurrido = tiempo_actual - ultimo_timestamp

            if variacion >= UMBRAL_CAMBIO_PORCENTAJE:
                debe_enviar = True
                razon_filtro = f"Variación del {variacion * 100:.2f}% supera el umbral del 5%."
            elif tiempo_transcurrido >= TIEMPO_MAXIMO_REPORTE_SEG:
                debe_enviar = True
                razon_filtro = f"Tiempo transcurrido ({tiempo_transcurrido:.1f}s) superó el límite de latido de 60s."
            else:
                # No cumple ninguna condición: Se bloquea/descarta el dato redundante
                debe_enviar = False
                print(f"[FILTRO EDGE] Dato bloqueado. Variación: {variacion * 100:.2f}% | "
                      f"Último reporte hace: {tiempo_transcurrido:.1f}s (Redundancia evitada)")

        # SI PASA EL FILTRO, PROCEDEMOS CON LA INGESTIÓN HTTP POST
        if debe_enviar:
            print(f"[FILTRO EDGE] Razón: {razon_filtro}")
            
            api_payload = {
                "valor": nuevo_valor,
                "estacion_id": estacion_id
            }

            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {JWT_TOKEN}"
            }

            try:
                response = requests.post(API_URL, json=api_payload, headers=headers, timeout=5)
                
                if response.status_code in [200, 201]:
                    print(f"[DB Sincronizada] Lectura de {api_payload['valor']} cm guardada en SQLite.")
                    # ACTUALIZAR CACHÉ LOCAL
                    cache_estaciones[estacion_id] = {
                        "valor": nuevo_valor,
                        "timestamp": tiempo_actual
                    }
                else:
                    print(f"[HTTP ERROR] API rechazó el dato. Código: {response.status_code}")
            except requests.exceptions.RequestException as e:
                print(f"[CRÍTICO] Error de conexión con FastAPI: {e}")

    except (KeyError, ValueError, IndexError) as e:
        print(f"[FORMATO INVÁLIDO] Mensaje inválido omitido: {e}")
    except Exception as e:
        print(f"[ERROR INESPERADO]: {e}")

# INICIALIZACIÓN DEL PUENTE
if __name__ == "__main__":
    try:
        bridge_client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2)
    except AttributeError:
        bridge_client = mqtt.Client()

    bridge_client.on_connect = on_connect
    bridge_client.on_message = on_message

    try:
        print("Inicializando el Bridge de Acoplamiento SMAT...")
        bridge_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        bridge_client.loop_forever()
    except KeyboardInterrupt:
        print(f"\n Apagando Bridge de manera limpia...")
        bridge_client.disconnect()
        sys.exit(0)