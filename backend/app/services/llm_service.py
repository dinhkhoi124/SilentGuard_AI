"""
LLM Service for SilentGuard
Ref: Section 8 - LLM Prompt Templates in silentguard-technical-plan.md
TODO: Interface with Anthropic Claude API for Vietnamese natural alert messages and daily report summaries.
"""

async def generate_alert_message(event_details: dict) -> str:
    """
    TODO: Use Claude API to generate a user-friendly Vietnamese alert message.
    Ref: Section 8 & Section 10 Day 6 of design doc
    """
    pass

async def generate_daily_report(date_str: str, events: list) -> str:
    """
    TODO: Use Claude API to generate a daily report summary for the family.
    Ref: Section 8 & Section 10 Day 6 of design doc
    """
    pass
