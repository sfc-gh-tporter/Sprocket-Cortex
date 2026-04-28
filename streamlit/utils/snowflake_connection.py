import streamlit as st
import os
from snowflake.snowpark import Session
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.exceptions import SnowparkSessionException

@st.cache_resource
def get_snowflake_session():
    """
    Get Snowflake session. In Snowflake-in-Snowflake runtime, uses get_active_session().
    For local dev, creates a session using connection_name from environment.
    """
    try:
        return get_active_session()
    except SnowparkSessionException:
        connection_name = os.getenv('SNOWFLAKE_CONNECTION_NAME', 'tporterawsdev')
        connection_params = {'connection_name': connection_name}
        return Session.builder.configs(connection_params).create()
