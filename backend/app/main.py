from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from . import models, schemas, auth, database

models.Base.metadata.create_all(bind=database.engine)
app = FastAPI(title="SMAT API - Unidad I")

# CONFIGURACIÓN CRÍTICA PARA SEMANA 5 (CONEXIÓN MÓVIL)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/token", tags=["Seguridad"])
def login():
    return {"access_token": auth.crear_token({"sub": "admin_fisi"}), "token_type": "bearer"}

@app.get("/estaciones/", response_model=list[schemas.Estacion], tags=["SMAT"])
def listar_estaciones(db: Session = Depends(database.get_db)):
    return db.query(models.EstacionDB).all()

@app.post("/estaciones/", tags=["SMAT"])
def crear_estacion(estacion: schemas.EstacionCreate, db: Session = Depends(database.get_db), user=Depends(auth.validar_token)):
    nueva = models.EstacionDB(**estacion.dict())
    db.add(nueva)
    db.commit()
    return nueva

@app.post("/lecturas/", tags=["Telemetría"])
def registrar_lectura(lectura: schemas.LecturaCreate, db: Session = Depends(database.get_db), user=Depends(auth.validar_token)):
    # Reto Maestro: Validación de existencia
    estacion = db.query(models.EstacionDB).filter(models.EstacionDB.id == lectura.estacion_id).first()
    if not estacion:
        raise HTTPException(status_code=404, detail="Estación no encontrada")
    
    nueva_lectura = models.LecturaDB(**lectura.dict())
    db.add(nueva_lectura)
    db.commit()
    return {"status": "Lectura registrada con éxito"}

@app.delete("/estaciones/{estacion_id}", tags=["SMAT"])
def eliminar_estacion(estacion_id: int, db: Session = Depends(database.get_db), user=Depends(auth.validar_token)):
    estacion = db.query(models.EstacionDB).filter(models.EstacionDB.id == estacion_id).first()
    if not estacion:
        raise HTTPException(status_code=404, detail="Estación no encontrada")
    
    db.delete(estacion)
    db.commit()
    return {"status": f'Estación "{estacion.nombre}" eliminada con éxito'}

@app.put("/estaciones/{estacion_id}", tags=["SMAT"])
def editar_estacion(
    estacion_id: int, 
    estacion_actualizada: schemas.EstacionCreate, 
    db: Session = Depends(database.get_db), 
    user = Depends(auth.validar_token)
):
    # 1. Buscar la estación existente en la base de datos
    estacion = db.query(models.EstacionDB).filter(models.EstacionDB.id == estacion_id).first()
    
    # 2. Si no existe, lanzar un error 404
    if not estacion:
        raise HTTPException(status_code=404, detail="Estación no encontrada")
    
    # 3. Actualizar los campos dinámicamente con los nuevos datos recibidos
    for key, value in estacion_actualizada.dict().items():
        setattr(estacion, key, value)
    
    # 4. Guardar los cambios en la base de datos
    db.commit()
    db.refresh(estacion)
    
    return {"status": "Estación actualizada con éxito", "estacion": estacion}

@app.get("/lecturas/", tags=["Telemetría"])
def obtener_lecturas(db: Session = Depends(database.get_db)):
    # Aquí el backend va a la base de datos, extrae las últimas 
    # lecturas registradas y las devuelve en formato JSON
    lecturas = db.query(models.LecturaDB).all()
    return lecturas