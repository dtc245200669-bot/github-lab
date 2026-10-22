FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/home/billing

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && groupadd --system --gid 10001 billing \
    && useradd --system --uid 10001 --gid billing --home-dir /home/billing --create-home billing

COPY --chown=10001:10001 app.py .
COPY --chown=10001:10001 frontend ./frontend

USER 10001:10001
EXPOSE 5000
CMD ["/bin/sh", "-c", "python -c 'from app import init_db; init_db()' && exec gunicorn --workers=2 --threads=4 --bind=0.0.0.0:5000 --access-logfile=- --error-logfile=- --capture-output app:app"]
