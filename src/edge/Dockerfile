FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app

COPY src/edge/requirements-edge.txt ./requirements-edge.txt
RUN pip install --no-cache-dir -r requirements-edge.txt

COPY src/edge/silentguard ./silentguard
COPY src/edge/showcase.yaml ./showcase.yaml
COPY yolov8n-pose.pt ./yolov8n-pose.pt

EXPOSE 8080

CMD ["python", "-m", "silentguard.worker", "--config", "/app/showcase.yaml"]

