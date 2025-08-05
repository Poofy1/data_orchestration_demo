FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy and install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project code
COPY dagster_project/ ./dagster_project/
COPY dagster.yaml .

# Set environment
ENV DAGSTER_HOME=/app

# Expose port
EXPOSE 3000

# Run Dagster webserver
CMD ["dagster", "dev", "-h", "0.0.0.0", "-p", "3000"]