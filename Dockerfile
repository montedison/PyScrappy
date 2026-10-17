# --- STAGE 1: Builder (Isolamento Totale) ---
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /build

# Installazione build-essentials per compilare eventuali estensioni C
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 1. Creazione del Virtual Environment
# Questo risolve il problema del "root user" perché pip lavorerà dentro una sandbox
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 2. Installazione dipendenze esterne
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --upgrade pip
# 3. Installazione del pacchetto locale con supporto MCP
# Copiamo il codice prima per permettere l'installazione del progetto stesso
COPY . .
RUN pip install --no-cache-dir .[mcp]


# --- STAGE 2: Final Runtime (Minimalismo e Sicurezza) ---
FROM python:3.12-slim AS runtime

WORKDIR /app

# Installazione dipendenze di sistema per i browser
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdrm2 libdbus-1-3 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxrandr2 libgbm1 libasound2 \
    && rm -rf /var/lib/apt/lists/*

# 4. COPIA DELL'AMBIENTE ISOLATO
# Copiamo l'intero venv creato nello stage builder. 
# Questo include tutti i binari (come pyscrappy-mcp) e le librerie.
COPY --from=builder /opt/venv /opt/venv

# 5. ATTIVAZIONE AUTOMATICA
# Aggiungendo il venv al PATH, il sistema userà sempre il python e i binari del venv
ENV PATH="/opt/venv/bin:$PATH"

# Copia il codice sorgente
COPY . .

# --- INSTALLAZIONE BROWSER ---
RUN playwright install chromium

# --- SECURITY ---
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# --- COMANDO FINALE (Con binding di rete corretto) ---
CMD ["pyscrappy-mcp", "--http", "--host", "0.0.0.0"]
