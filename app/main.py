from fastapi import FastAPI
import os

APP_VERSION = os.getenv("APP_VERSION", "dev")   # 部署时由 Helm 设置成镜像 tag，也就是 commit hash

app = FastAPI(title="AKS Platform API", version=APP_VERSION)


@app.get("/")
def read_root():
    return {
        "message": "Hello from FastAPI on Azure AKS!",
        "environment": os.getenv("ENVIRONMENT", "production"),
        "version": APP_VERSION,
    }


@app.get("/health")      # Kubernetes 的健康检查会访问这个路径，chart 里的路径必须和这里一致
def health_check():
    return {"status": "healthy"}
