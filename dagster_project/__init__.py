from dagster import Definitions, define_asset_job, ScheduleDefinition
from .assets import raw_finance_data, demographic_analysis, investment_summary_table

# Create a job that runs all assets
investment_pipeline_job = define_asset_job(
    name="investment_pipeline",
    selection=[raw_finance_data, demographic_analysis, investment_summary_table]
)

# Schedule it to run daily
daily_schedule = ScheduleDefinition(
    job=investment_pipeline_job,
    cron_schedule="0 6 * * *"  # 6 AM daily
)

defs = Definitions(
    assets=[raw_finance_data, demographic_analysis, investment_summary_table],
    jobs=[investment_pipeline_job],
    schedules=[daily_schedule]
)