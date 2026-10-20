import logging
import os

import httpx
from fastapi import FastAPI, HTTPException
from mangum import Mangum


logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS define esta variable automáticamente dentro de Lambda
EN_LAMBDA = "AWS_LAMBDA_FUNCTION_NAME" in os.environ

app = FastAPI(
    title="Pokemon SRE Training API",
    description="API dummy para entrenamiento de despliegues y DevOps",
    version="1.1.0",
)

# Prometheus solo tiene sentido en un proceso que vive todo el tiempo (local / contenedor).
# En Lambda las métricas se reiniciarían en cada instancia, así que ahí usamos CloudWatch.
if not EN_LAMBDA:
    from prometheus_fastapi_instrumentator import Instrumentator

    Instrumentator().instrument(app).expose(app)


@app.get("/health", tags=["Monitoreo"])
def health_check():
    return {
        "status": "ok",
        "message": "El servicio está operando correctamente",
        "entorno": "lambda" if EN_LAMBDA else "local",
    }


@app.get("/", tags=["Inicio"])
def read_root():
    return {"mensaje": "Bienvenido a la API de Pokemon para entrenamiento SRE. Visita /docs para probarla."}


@app.get("/pokemon/{name}", tags=["Pokemon"])
async def get_pokemon_data(name: str):
    url = f"https://pokeapi.co/api/v2/pokemon/{name.lower()}"

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(url)
    except httpx.RequestError as exc:
        # El detalle técnico va al log (CloudWatch), no a la respuesta del cliente
        logger.error("Error llamando a PokeAPI: %s", exc)
        raise HTTPException(status_code=503, detail="Servicio externo no disponible en este momento.")

    if response.status_code == 404:
        raise HTTPException(status_code=404, detail="Pokemon no encontrado")
    if response.status_code != 200:
        logger.warning("PokeAPI respondió %s para %s", response.status_code, name)
        raise HTTPException(status_code=502, detail="Error en la base de datos externa")

    data = response.json()
    return {
        "name": data["name"],
        "pokedex_id": data["id"],
        "types": [t["type"]["name"] for t in data["types"]],
        "base_experience": data["base_experience"],
    }


# Punto de entrada para AWS Lambda
handler = Mangum(app, lifespan="off")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)