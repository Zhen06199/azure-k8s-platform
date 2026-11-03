FROM python:3.11-slim
WORKDIR /app

# 先只复制依赖文件并安装：代码改了但依赖没变时，这一层可以直接用缓存，构建更快
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# 用非 root 用户运行。USER 必须写数字 UID，kubelet 才能确认它不是 root
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin app
USER 10001

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
