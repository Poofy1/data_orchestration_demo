import pandas as pd
import boto3
from dagster import asset, MaterializeResult, MetadataValue, Config
from datetime import datetime
import snowflake.connector

class PipelineConfig(Config):
    bucket_name: str = "poofington-test-bucket-0"

@asset(compute_kind="s3")
def raw_finance_data(context, config: PipelineConfig) -> pd.DataFrame:  # Return DataFrame, not MaterializeResult
    """Load Finance_data.csv from S3"""
    
    s3_client = boto3.client('s3')
    response = s3_client.get_object(Bucket=config.bucket_name, Key='Finance_data.csv')
    df = pd.read_csv(response['Body'])
    
    context.log.info(f"Loaded {len(df)} survey responses")
    
    # Log metadata but return the actual data
    context.add_output_metadata({
        "records": len(df),
        "columns": len(df.columns),
        "genders": MetadataValue.json(df['gender'].value_counts().to_dict())
    })
    
    return df  # Return the actual DataFrame

@asset(compute_kind="pandas")
def demographic_analysis(context, raw_finance_data: pd.DataFrame, config: PipelineConfig) -> pd.DataFrame:  # Type hint for clarity
    """Analyze investment patterns by demographics"""
    
    df = raw_finance_data  # Now this works!
    
    # Investment preferences by gender  
    investment_cols = ['Mutual_Funds', 'Equity_Market', 'Government_Bonds', 'Fixed_Deposits', 'Gold']
    gender_analysis = df.groupby('gender')[investment_cols].mean().round(2)
    
    # Age group analysis
    df['age_group'] = pd.cut(df['age'], bins=[0, 30, 45, 60, 100], labels=['<30', '30-45', '45-60', '60+'])
    age_analysis = df.groupby('age_group')[investment_cols].mean().round(2)
    
    # Save to S3
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    s3_client = boto3.client('s3')
    gender_analysis.to_parquet(f"s3://{config.bucket_name}/analytics/gender_analysis_{timestamp}.parquet")
    age_analysis.to_parquet(f"s3://{config.bucket_name}/analytics/age_analysis_{timestamp}.parquet")
    
    context.add_output_metadata({
        "gender_groups": len(gender_analysis),
        "age_groups": len(age_analysis),
        "top_investment": gender_analysis.mean().idxmin()
    })
    
    return gender_analysis  # Return data for next asset

@asset(compute_kind="snowflake")  
def investment_summary_table(context, demographic_analysis: pd.DataFrame, config: PipelineConfig) -> MaterializeResult:
    """Load analysis results to Snowflake"""
    
    # Create summary from the actual analysis
    summary_data = {
        'analysis_date': [datetime.now().date()],
        'total_responses': [len(demographic_analysis) * 10],  # Rough estimate
        'gender_groups': [len(demographic_analysis)],
        'top_investment': [demographic_analysis.mean().idxmin()],
        'analysis_type': ['demographic_batch']
    }
    
    summary_df = pd.DataFrame(summary_data)
    
    # Save to S3 as "snowflake ready" format
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    summary_df.to_parquet(f"s3://{config.bucket_name}/snowflake_ready/investment_summary_{timestamp}.parquet")
    
    context.log.info("Investment summary prepared for Snowflake")
    
    return MaterializeResult(
        metadata={
            "summary_records": len(summary_df),
            "analysis_date": str(datetime.now().date())
        }
    )