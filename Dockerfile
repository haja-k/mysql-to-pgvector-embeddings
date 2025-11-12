FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy and install requirements
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy application
COPY . .

# Create logs directory
RUN mkdir -p logs

EXPOSE 5050

CMD ["python", "app.py"]