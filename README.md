# Investment Analytics Pipeline

Batch processing pipeline analyzing investment behavior across demographic segments using Dagster, AWS S3, and Snowflake.

## Architecture
- **Data Source**: S3 (Finance_data.csv) 
- **Processing**: Dagster orchestration on AWS ECS
- **Analytics**: Demographic investment pattern analysis
- **Output**: Snowflake-ready analytics tables

## Pipeline Steps
1. Load survey data from S3
2. Analyze investment preferences by gender and age
3. Generate summary statistics for Snowflake

## Local Development
```bash
pip install -r requirements.txt
dagster dev
```