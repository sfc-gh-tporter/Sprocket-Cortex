import json
import requests

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
