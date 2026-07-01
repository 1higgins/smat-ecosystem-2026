import time
import random
import json
import paho.mqtt.client as mqtt

BROKER = "broker.hivemq.com"
PUERTO = 1883

def conectar_mqtt():
    client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2)
    print(f"Conectando al broker {BROKER}...")
    client.connect(BROKER, PUERTO, 60)
    return client

def main():
    cliente = conectar_mqtt()
    cliente.loop_start()
    
    #esta es la lista de cámaras para simular de forma intercalada
    camaras = ["camara_01", "camara_02"]
    
    try:
        while True:
            for id_camara in camaras:
                topico = f"unmsm/callao/camara/{id_camara}/telemetria"
                
                tipo_lectura = random.choices(["normal", "falla_limite", "falla_tipo"], weights=[80, 10, 10])[0]
                
                if tipo_lectura == "normal":
                    # aqui van valores realistas entre -5 a 12 grados Celsius para simular la temperatura dentro de la cámara
                    temperatura = round(random.uniform(-5.0, 12.0), 2)
                elif tipo_lectura == "falla_limite":
                    # aqui la temperatura que viola los límites lógicos de Pydantic (>100°C)
                    temperatura = 150.0
                    print(f"[SIMULADOR] Inyectando falla de límite en {id_camara}")
                else:
                    temperatura = "ERROR_SENSOR_STRING"
                    print(f"[SIMULADOR] Inyectando falla de tipo de dato en {id_camara}")

                datos_sensor = {
                    "sensor_id": random.randint(100, 199),
                    "timestamp": time.time(),
                    "valor": temperatura,
                    "unidad": "Celsius"
                }
                
                mensaje = json.dumps(datos_sensor)
                cliente.publish(topico, mensaje, qos=1)
                
                print(f"[PUBLISHER] Enviado a {topico}: {mensaje}")
                time.sleep(2) 
                
    except KeyboardInterrupt:
        print("\nDeteniendo publicador...")
    finally:
        cliente.loop_stop()
        cliente.disconnect()

if __name__ == "__main__":
    main()