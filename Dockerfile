# --- STAGE 1: Builder (Isolamento Totale) ---
FROM python:3.12-slim AS builder
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY . .
# FIX 1: Installiamo il pacchetto locale con entrambi gli extra [mcp,browser]
RUN pip install --no-cache-dir .[mcp,browser]

# --- STAGE 2: Final Runtime ---
FROM python:3.12-slim AS runtime

WORKDIR /app

# Installazione dipendenze di sistema per i browser
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdrm2 libdbus-1-3 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxrandr2 libgbm1 libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Copia dell'ambiente virtuale
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# FIX 2: Definiamo un path globale per i browser di Playwright
# Questo evita che Playwright cerchi in /root/ o in /home/appuser/
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright/browsers

# Copia del codice sorgente
COPY . .

# FIX 3: Installazione dei browser in una directory controllata e assegnazione permessi
RUN mkdir -p /opt/playwright/browsers && \
    playwright install chromium && \
    chown -R appuser:appuser /app /opt/playwright

# --- SECURITY ---
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

CMD ["pyscrappy-mcp", "--http", "--host", "0.0.0.0"]
