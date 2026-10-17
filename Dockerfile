# --- STAGE 1: Builder ---
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 1. Installiamo prima le dipendenze esterne
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# 2. Copiamo il codice sorgente per poter installare il pacchetto locale
COPY . .

# 3. INSTALLAZIONE CRITICA: Installiamo il progetto stesso con il supporto MCP
# Assicurati che nel tuo progetto ci sia un pyproject.toml o setup.py
RUN pip install --no-cache-dir --prefix=/install .[mcp]


# --- STAGE 2: Final Runtime ---
FROM python:3.12-slim AS runtime

WORKDIR /app

# Installazione dipendenze di sistema per i browser
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Copia le dipendenze Python (inclusi i binari di pyscrappy-mcp) dallo stage builder
COPY --from=builder /install /usr/local

# Copia il codice sorgente
COPY . .

# --- INSTALLAZIONE BROWSER ---
RUN playwright install chromium

# --- SECURITY ---
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# --- IL COMANDO CHE MANCAVA ---
# Questo avvia il server MCP e lo espone sulla rete
CMD ["pyscrappy-mcp", "--http"]
