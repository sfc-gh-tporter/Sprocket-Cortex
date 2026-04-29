#!/usr/bin/env python3
"""
Deploy Cortex Agent from YAML definition to Snowflake.

Usage:
    python deploy_agent.py agents/sprocket_agent.yaml
"""
import os
import sys
import yaml
from snowflake.snowpark import Session


def get_connection():
    """Create Snowflake connection from config"""
    connection_name = os.environ.get("SNOWFLAKE_CONNECTION_NAME", "prod")
    return Session.builder.config("connection_name", connection_name).create()


def deploy_agent(yaml_path):
    """Deploy agent from YAML definition"""
    print(f"📖 Reading agent definition from {yaml_path}...")
    
    with open(yaml_path, 'r') as f:
        config = yaml.safe_load(f)
    
    agent_name = f"{config['database']}.{config['schema']}.{config['name']}"
    print(f"🤖 Deploying agent: {agent_name}")
    
    # Build CREATE AGENT SQL
    instructions = config.get('instructions', '') + '\n\n' + config.get('response_style', '')
    tools_list = config.get('tools', [])
    tools_str = ', '.join(tools_list) if tools_list else ''
    
    sql = f"""
    CREATE OR REPLACE CORTEX AGENT {agent_name}
        ORCHESTRATION_MODEL = '{config['orchestration_model']}'
        INSTRUCTIONS = $$
{instructions.strip()}
        $$
    """
    
    if tools_str:
        sql += f"\n        TOOLS = ({tools_str})"
    
    if config.get('comment'):
        sql += f"\n        COMMENT = '{config['comment']}'"
    
    print(f"🔧 Connecting to Snowflake...")
    session = get_connection()
    
    try:
        print(f"🚀 Executing CREATE OR REPLACE CORTEX AGENT...")
        session.sql(sql).collect()
        print(f"✅ Agent {agent_name} deployed successfully!")
        print(f"📍 Access at: https://app.snowflake.com")
        return True
    except Exception as e:
        print(f"❌ Deployment failed: {str(e)}")
        return False
    finally:
        session.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python deploy_agent.py <yaml_path>")
        print("Example: python deploy_agent.py agents/sprocket_agent.yaml")
        sys.exit(1)
    
    yaml_path = sys.argv[1]
    
    if not os.path.exists(yaml_path):
        print(f"❌ Error: File not found: {yaml_path}")
        sys.exit(1)
    
    success = deploy_agent(yaml_path)
    sys.exit(0 if success else 1)
