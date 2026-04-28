import streamlit as st
import json
import os
import requests
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

def call_agent_streaming(session, messages):
    """
    Call SPROCKET_AGENT REST API with SSE streaming.
    Yields text chunks as they arrive.
    
    Args:
        session: Snowflake Snowpark session
        messages: List of message dicts in agent API format
    
    Yields:
        str: Text chunks from response.text.delta events
    """
    conn = session._conn._conn
    token = conn.rest.token
    host = conn.host
    
    url = f"https://{host}/api/v2/databases/SPROCKET/schemas/APP/agents/SPROCKET_AGENT:run"
    headers = {
        "Authorization": f'Snowflake Token="{token}"',
        "Content-Type": "application/json"
    }
    payload = {"messages": messages}
    
    response = requests.post(url, headers=headers, json=payload, stream=True, verify=True, timeout=600)
    
    if response.status_code != 200:
        yield f"Error {response.status_code}: {response.text[:500]}"
        return
    
    event_type = None
    for line in response.iter_lines():
        if not line:
            continue
        decoded = line.decode('utf-8')
        
        if decoded.startswith('event: '):
            event_type = decoded[7:].strip()
            if event_type == 'done':
                break
        elif decoded.startswith('data: '):
            try:
                data = json.loads(decoded[6:])
            except json.JSONDecodeError:
                continue
            
            if event_type == 'response.text.delta':
                yield data.get('text', '')

st.set_page_config(page_title="Sprocket AI", layout="wide", page_icon="🔧")

session = get_snowflake_session()

with st.sidebar:
    st.title("🚴 Sprocket")
    st.caption("AI Bicycle Maintenance Assistant")
    
    st.divider()
    
    bikes_df = session.sql("SELECT * FROM SPROCKET.APP.USER_BIKES ORDER BY model_year DESC").to_pandas()
    
    if bikes_df.empty:
        st.warning("No bikes found. Add a bike to get started.")
        st.stop()
    
    selected_bike = st.selectbox(
        "Select your bike",
        options=bikes_df['BIKE_ID'].tolist(),
        format_func=lambda x: bikes_df[bikes_df['BIKE_ID']==x]['DISPLAY_NAME'].values[0],
        key='bike_selector'
    )
    
    if 'current_bike' not in st.session_state or st.session_state.current_bike != selected_bike:
        with st.spinner("Loading bike context..."):
            result = session.call('SPROCKET.APP.GET_BIKE_CONTEXT', selected_bike)
            context_json = json.loads(result)
            st.session_state.current_bike = selected_bike
            st.session_state.context = context_json
            st.session_state.messages = []
    
    bike_info = st.session_state.get('context', {}).get('bike', {})
    components = st.session_state.get('context', {}).get('components', [])
    
    st.subheader("Current Bike")
    st.write(f"**{bike_info.get('display_name', 'Unknown')}**")
    if bike_info.get('category'):
        st.caption(f"Category: {bike_info['category']}")
    
    st.divider()
    
    st.subheader(f"Components ({len(components)})")
    for comp in components:
        with st.expander(f"{comp['category']}: {comp['make']} {comp['model']}"):
            if comp.get('model_year'):
                st.caption(f"Year: {comp['model_year']}")
            if comp.get('is_stock'):
                st.caption("Stock component")
            if comp.get('notes'):
                st.caption(f"Notes: {comp['notes']}")

st.title("Sprocket AI")
current_bike_name = st.session_state.get('context', {}).get('bike', {}).get('display_name', 'No bike selected')
st.caption(f"💬 Chat about your {current_bike_name}")

if 'messages' not in st.session_state:
    st.session_state.messages = []

for msg in st.session_state.messages:
    with st.chat_message(msg['role']):
        st.markdown(msg['content'])

if prompt := st.chat_input("Ask about maintenance, specs, or upload a new manual..."):
    st.session_state.messages.append({'role': 'user', 'content': prompt})
    
    with st.chat_message('user'):
        st.markdown(prompt)
    
    preamble = st.session_state.context.get('preamble', '')
    
    agent_messages = [
        {'role': 'user', 'content': [{'type': 'text', 'text': preamble}]},
        {'role': 'assistant', 'content': [{'type': 'text', 'text': 'Understood.'}]},
    ]
    
    for msg in st.session_state.messages:
        agent_messages.append({
            'role': msg['role'],
            'content': [{'type': 'text', 'text': msg['content']}]
        })
    
    with st.chat_message('assistant'):
        response_placeholder = st.empty()
        full_response = ""
        
        try:
            for chunk in call_agent_streaming(session, agent_messages):
                full_response += chunk
                response_placeholder.markdown(full_response + "▌")
            
            response_placeholder.markdown(full_response)
        except Exception as e:
            error_msg = f"Error calling agent: {str(e)}"
            response_placeholder.error(error_msg)
            full_response = error_msg
    
    st.session_state.messages.append({'role': 'assistant', 'content': full_response})
