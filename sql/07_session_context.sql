--------------------------------------------------------------------
-- 07_session_context.sql  -  Session context helpers
--
-- These helpers let the app layer (Streamlit / React) answer two
-- questions without the agent having to know the data model:
--
--   1. Which bikes does this user have? (for a bike-picker UI)
--   2. What context should I inject into the agent conversation
--      when the user has selected bike X?
--
-- Philosophy: the agent stays generic. It does not know about
-- BIKE_COMPONENT_INSTANCES or COMPONENT_CATALOG. The app layer
-- pulls the right context for the session and prepends it to
-- each agent call as a preamble. This scales cleanly to hundreds
-- of bikes with thousands of components without any changes to
-- the agent itself.
--------------------------------------------------------------------

USE ROLE SYSADMIN;
USE WAREHOUSE SPROCKET_WH;

--------------------------------------------------------------------
-- USER_BIKES view - backs the bike-picker dropdown
--------------------------------------------------------------------

CREATE OR REPLACE VIEW SPROCKET.APP.USER_BIKES AS
SELECT 
    b.bike_id,
    b.model_year || ' ' || b.make || ' ' || b.model AS display_name,
    b.make,
    b.model,
    b.model_year,
    b.category,
    COUNT(i.instance_id) AS component_count
FROM SPROCKET.CURATED.BIKES b
LEFT JOIN SPROCKET.CURATED.BIKE_COMPONENT_INSTANCES i ON b.bike_id = i.bike_id
GROUP BY b.bike_id, b.model_year, b.make, b.model, b.category
ORDER BY b.model_year DESC, b.make, b.model;

--------------------------------------------------------------------
-- GET_BIKE_CONTEXT - returns a VARIANT blob with:
--   .bike            - {bike_id, display_name, category}
--   .components      - array of {category, make, model, model_year, is_stock, notes}
--   .preamble        - ready-to-inject text for the agent
--------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE SPROCKET.APP.GET_BIKE_CONTEXT(p_bike_id VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_result VARIANT;
BEGIN
    WITH bike AS (
        SELECT 
            bike_id,
            model_year || ' ' || make || ' ' || model AS display_name,
            category
        FROM SPROCKET.CURATED.BIKES
        WHERE bike_id = :p_bike_id
    ),
    components AS (
        SELECT 
            c.component_category,
            c.make,
            c.model,
            c.model_year,
            i.is_stock,
            i.custom_notes
        FROM SPROCKET.CURATED.BIKE_COMPONENT_INSTANCES i
        JOIN SPROCKET.CURATED.COMPONENT_CATALOG c ON i.catalog_id = c.catalog_id
        WHERE i.bike_id = :p_bike_id
    ),
    component_json AS (
        SELECT ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'category', component_category,
                'make', make,
                'model', model,
                'model_year', model_year,
                'is_stock', is_stock,
                'notes', custom_notes
            )
        ) WITHIN GROUP (ORDER BY component_category, make, model) AS items,
        LISTAGG(make || ' ' || model, ', ') WITHIN GROUP (ORDER BY component_category) AS component_str
        FROM components
    ),
    preamble AS (
        SELECT 
            'User is working on their ' || b.display_name || 
            COALESCE(' (' || b.category || ' bike)', '') ||
            '. Components on this bike: ' || c.component_str ||
            '. When answering questions, restrict searches to these component models when relevant using the component_models filter attribute. Use bike_model = ''' || b.display_name || 
            ''' for frame-specific questions.' AS text
        FROM bike b, component_json c
    )
    SELECT OBJECT_CONSTRUCT(
        'bike', OBJECT_CONSTRUCT(
            'bike_id', b.bike_id,
            'display_name', b.display_name,
            'category', b.category
        ),
        'components', c.items,
        'preamble', p.text
    )
    INTO v_result
    FROM bike b, component_json c, preamble p;

    RETURN v_result;
END;
$$;

--------------------------------------------------------------------
-- USAGE PATTERN (from Streamlit app)
--
-- 1. Populate bike-picker:
--    SELECT bike_id, display_name FROM SPROCKET.APP.USER_BIKES;
--
-- 2. When user selects a bike, get context:
--    CALL SPROCKET.APP.GET_BIKE_CONTEXT('stumpjumper-evo-2021');
--    -> pulls .preamble text + .components for UI display
--
-- 3. When user sends a chat message, build the agent payload as:
--    messages: [
--      {role: 'user', content: [{type: 'text', text: <preamble>}]},
--      {role: 'assistant', content: [{type: 'text', text: 'Understood.'}]},
--      ...prior conversation turns...,
--      {role: 'user', content: [{type: 'text', text: <user message>}]}
--    ]
--
-- The agent receives the context, figures out the right filters,
-- and answers in the scope of the user's bike without the agent
-- instructions needing to know about any specific bike or component.
--------------------------------------------------------------------
