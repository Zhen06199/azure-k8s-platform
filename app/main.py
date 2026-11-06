from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
import os
import time

APP_VERSION = os.getenv("APP_VERSION", "dev")

app = FastAPI(title="AKS Platform API", version=APP_VERSION)

# Rate + Errors：按方法、路径、状态码统计请求数
REQUESTS = Counter("http_requests_total", "HTTP requests", ["method", "path", "status"])
# Duration：请求耗时的直方图
LATENCY = Histogram("http_request_duration_seconds", "HTTP request latency", ["method", "path"])


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        route = request.scope.get("route")
        path = route.path if route else "unmatched"
        REQUESTS.labels(request.method, path, str(status)).inc()
        LATENCY.labels(request.method, path).observe(time.perf_counter() - start)


@app.get("/")
def read_root():
    return {
        "message": "Hello from FastAPI on Azure AKS!",
        "environment": os.getenv("ENVIRONMENT", "production"),
        "version": APP_VERSION,
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.get("/fail")
def fail():
    raise HTTPException(status_code=500, detail="simulated failure")


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
