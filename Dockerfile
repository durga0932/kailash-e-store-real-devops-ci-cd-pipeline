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

# Remove vulnerable pre-installed Python package versions
RUN python -m pip uninstall -y msgpack setuptools || true

# Install application dependencies and secure package versions
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