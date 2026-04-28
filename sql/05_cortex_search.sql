--------------------------------------------------------------------
-- 05_cortex_search.sql  –  Cortex Search Service
--------------------------------------------------------------------

USE ROLE SYSADMIN;
USE WAREHOUSE SPROCKET_WH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SPROCKET.SEARCH.MANUAL_SEARCH
ON content
ATTRIBUTES section, page_number, chunk_type, source_file, bike_model, model_year,
           component_category, document_type, component_catalog_id, component_make, component_model
WAREHOUSE = SPROCKET_WH
TARGET_LAG = '1 hour'
EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0-8k'
AS (
    SELECT 
        chunk_id,
        document_id,
        content,
        section,
        page_number,
        chunk_type,
        source_file,
        bike_model,
        model_year,
        component_category,
        document_type,
        component_catalog_id,
        component_make,
        component_model
    FROM SPROCKET.SEARCH.DOCUMENT_CHUNKS
);
