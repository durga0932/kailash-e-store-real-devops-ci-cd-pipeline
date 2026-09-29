FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Remove any old/vulnerable package files and metadata
RUN find /usr/local/lib/python3.14/site-packages \
       -maxdepth 1 \
       \( -name 'msgpack*' -o -name 'setuptools*' \) \
       -exec rm -rf {} + \
    && echo "Old msgpack/setuptools files removed"

# Install dependencies with secure versions
RUN python -m pip install --upgrade pip \
    && python -m pip install --no-cache-dir -r requirements.txt \
    && python -m pip install --no-cache-dir --upgrade \
       "msgpack>=1.2.1" \
       "setuptools>=78.1.1" \
    && echo "===== SECURITY PACKAGE VERSIONS =====" \
    && python -m pip show msgpack setuptools \
    && python -c "import msgpack, setuptools; print('msgpack:', msgpack.__version__); print('setuptools:', setuptools.__version__)"

COPY . .

RUN python manage.py collectstatic --noinput

EXPOSE 8000

CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--access-logfile", "-", "--error-logfile", "-"]