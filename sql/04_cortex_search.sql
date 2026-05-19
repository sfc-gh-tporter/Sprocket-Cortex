--------------------------------------------------------------------
-- 05_cortex_search.sql  –  Cortex Search Service
--------------------------------------------------------------------

USE ROLE SPROCKET_DEPLOYER;
USE WAREHOUSE SPROCKET_WH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.MANUAL_SEARCH
ON content
ATTRIBUTES section, section_type, page_number, chunk_type, source_file, bike_model, model_year,
           component_category, document_type, component_catalog_ids, component_makes, component_models
WAREHOUSE = SPROCKET_WH
TARGET_LAG = '1 hour'
EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0-8k'
AS (
    SELECT 
        chunk_id,
        document_id,
        content,
        section,
        section_type,
        page_number,
        chunk_type,
        source_file,
        bike_model,
        model_year,
        component_category,
        document_type,
        component_catalog_ids,
        component_makes,
        component_models
    FROM SEARCH.DOCUMENT_CHUNKS
);
