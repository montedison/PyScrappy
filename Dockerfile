# --- STAGE 1: Builder (Isolamento Totale) ---
FROM python:3.12-slim AS builder
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /dev/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY . .
# Installiamo con gli extra necessari per il rendering JS
RUN pip install --no-cache-dir .[mcp,browser]

# --- STAGE 2: Final Runtime ---
FROM python:3.12-slim AS runtime

WORKDIR /app

# 1. Installazione dipendenze di sistema per i browser
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdrm2 libdbus-1-3 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxrandr2 libgbm1 libasound2 \
    && rm -rf /var/lib/apt/lists/*

# 2. CREAZIONE UTENTE (Deve avvenire PRIMA di ogni chown)
RUN useradd -m appuser

# 3. Configurazione Ambiente e Virtual Env
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
# Path globale per i browser per garantire accessibilità a appuser
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright/browsers

# 4. Installazione Browser e Gestione Permessi Directory
# Creiamo la directory, installiamo e poi diamo la proprietà ad appuser
RUN mkdir -p /opt/playwright/browsers && \
    playwright install chromium && \
    chown -R appuser:appuser /opt/playwright

# 5. Copia Codice e Gestione Permessi Applicazione
COPY . .
RUN chown -R appuser:appuser /app

# 6. SECURITY: Switch all'utente non-privilegiato
USER appuser

EXPOSE 8000

# --- COMANDO FINALE ---
CMD ["pyscrappy-mcp", "--http", "--host", "0.0.0.0"]
