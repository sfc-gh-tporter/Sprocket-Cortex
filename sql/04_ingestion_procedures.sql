--------------------------------------------------------------------
-- 04_ingestion_procedures.sql  –  Sprocket HITL Ingestion Pipeline
--------------------------------------------------------------------
-- Creates 7 stored procedures for human-in-the-loop document ingestion
-- with 4 checkpoints: Preview → Classify → Link → Finalize → Async Processing

USE ROLE SYSADMIN;
USE WAREHOUSE SPROCKET_WH;

--------------------------------------------------------------------
-- INGEST_START: Checkpoint 1 - Register & Parse Preview
--------------------------------------------------------------------
-- Registers document, parses first 3 pages, extracts title guess
-- Returns preview data for user confirmation

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.INGEST_START(p_file_name VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
'
DECLARE
    v_document_id VARCHAR;
    v_existing_id VARCHAR;
    v_file_size INT;
    v_page_count INT;
    v_title VARCHAR;
    v_preview VARCHAR;
    v_result VARIANT;
BEGIN
    -- Check if already registered (idempotency)
    SELECT document_id INTO :v_existing_id
    FROM SPROCKET.RAW.DOCUMENT_REGISTRY
    WHERE source_file = :p_file_name
    LIMIT 1;

    IF (v_existing_id IS NOT NULL) THEN
        -- Return existing preview if already parsed
        SELECT 
            OBJECT_CONSTRUCT(
                ''document_id'', document_id,
                ''status'', status,
                ''resumed'', TRUE,
                ''title_guess'', COALESCE(classification:title::VARCHAR, source_file),
                ''source_file'', source_file,
                ''page_count'', page_count
            )
        INTO :v_result
        FROM SPROCKET.RAW.DOCUMENT_REGISTRY
        WHERE document_id = :v_existing_id;
        RETURN v_result;
    END IF;

    -- Register new document
    INSERT INTO SPROCKET.RAW.DOCUMENT_REGISTRY (source_file, file_path, status, status_updated_at, progress_pct)
    VALUES (
        :p_file_name,
        ''@SPROCKET.RAW.MANUALS_STAGE/'' || :p_file_name,
        ''UPLOADED'',
        CURRENT_TIMESTAMP(),
        0
    );

    SELECT document_id INTO :v_document_id
    FROM SPROCKET.RAW.DOCUMENT_REGISTRY WHERE source_file = :p_file_name LIMIT 1;

    -- Parse first pages only (cheap preview)
    CREATE OR REPLACE TEMPORARY TABLE SPROCKET.RAW._TEMP_PREVIEW AS
    SELECT SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
        @SPROCKET.RAW.MANUALS_STAGE,
        :p_file_name,
        {''mode'': ''LAYOUT'', ''page_split'': TRUE}
    ) AS result;

    -- Insert first 3 pages into DOCUMENT_PAGES for the classify step to use
    INSERT INTO SPROCKET.RAW.DOCUMENT_PAGES (document_id, page_number, content, images)
    SELECT 
        :v_document_id,
        p.value:index::INT + 1,
        p.value:content::VARCHAR,
        NULL
    FROM SPROCKET.RAW._TEMP_PREVIEW, LATERAL FLATTEN(input => result:pages) p
    WHERE p.value:index::INT < 3;

    -- Compute preview values
    SELECT 
        ARRAY_SIZE(result:pages),
        LEFT(result:pages[0]:content::VARCHAR, 400)
    INTO :v_page_count, :v_preview
    FROM SPROCKET.RAW._TEMP_PREVIEW;

    -- Extract a title guess (first markdown heading in first page)
    SELECT COALESCE(
        REGEXP_SUBSTR(content, ''# ([^\\n]+)'', 1, 1, ''e''),
        LEFT(content, 100)
    )
    INTO :v_title
    FROM SPROCKET.RAW.DOCUMENT_PAGES
    WHERE document_id = :v_document_id AND page_number = 1;

    UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY
    SET page_count = :v_page_count,
        status = ''PARSED'',
        status_updated_at = CURRENT_TIMESTAMP(),
        progress_pct = 10,
        classification = OBJECT_CONSTRUCT(''title'', :v_title)
    WHERE document_id = :v_document_id;

    DROP TABLE IF EXISTS SPROCKET.RAW._TEMP_PREVIEW;

    RETURN OBJECT_CONSTRUCT(
        ''document_id'', :v_document_id,
        ''status'', ''PARSED'',
        ''resumed'', FALSE,
        ''title_guess'', :v_title,
        ''source_file'', :p_file_name,
        ''page_count'', :v_page_count,
        ''first_page_preview'', :v_preview
    );
END;
';

--------------------------------------------------------------------
-- INGEST_CLASSIFY: Checkpoint 2 - AI Classification
--------------------------------------------------------------------
-- Classifies document using Claude-4-Sonnet
-- Returns classification + fuzzy-matched existing catalog entries

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.INGEST_CLASSIFY(p_document_id VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
'
DECLARE
    v_combined_text VARCHAR;
    v_raw_response VARCHAR;
    v_classification VARIANT;
    v_matches VARIANT;
    v_proposed_catalog_id VARCHAR;
BEGIN
    SELECT LISTAGG(LEFT(content, 3000), ''\\n---PAGE BREAK---\\n'') WITHIN GROUP (ORDER BY page_number)
    INTO :v_combined_text
    FROM SPROCKET.RAW.DOCUMENT_PAGES
    WHERE document_id = :p_document_id AND page_number <= 3;

    SELECT AI_COMPLETE(
        ''claude-4-sonnet'',
        ''You are classifying a bicycle service manual. Based on the pages below, return ONLY a JSON object (no markdown fences) with these fields:

- "make": brand/manufacturer
- "model": component model
- "model_year": numeric year if mentioned, otherwise null
- "component_type": one of "Frame", "Fork", "Rear Shock", "Hydraulic Disc Brake", "Derailleur", "Cassette", "Chain", "Crankset", "Wheel", "Dropper Post", "Stem", "Handlebar", "Saddle", "Headset", "Bottom Bracket", "Pedal", "Other"
- "component_category": one of "Frame", "Suspension", "Brakes", "Drivetrain", "Wheels", "Cockpit", "Seatpost"
- "document_type": one of "frame_manual", "fork_manual", "shock_manual", "brake_service_manual", "brake_install_guide", "drivetrain_manual", "wheel_manual", "dropper_manual", "other"
- "link_type": one of "manual", "service_manual", "install_guide", "bleed_guide", "user_manual", "exploded_view"
- "confidence": number 0.0 to 1.0
- "reasoning": one-sentence explanation

PAGES:
'' || :v_combined_text,
        {''max_tokens'': 1000, ''temperature'': 0}
    )
    INTO :v_raw_response;

    SELECT TRY_PARSE_JSON(TRIM(REPLACE(REPLACE(:v_raw_response, ''```json'', ''''), ''```'', '''')))
    INTO :v_classification;

    IF (v_classification IS NULL) THEN
        UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY
        SET status = ''FAILED'', status_updated_at = CURRENT_TIMESTAMP(),
            error_message = ''Classification JSON parse failed: '' || LEFT(:v_raw_response, 500)
        WHERE document_id = :p_document_id;
        RETURN OBJECT_CONSTRUCT(''status'', ''FAILED'', ''error'', ''Could not parse classification JSON'', ''raw'', :v_raw_response);
    END IF;

    SELECT ARRAY_AGG(
        OBJECT_CONSTRUCT(
            ''catalog_id'', catalog_id,
            ''make'', make,
            ''model'', model,
            ''model_year'', model_year,
            ''component_type'', component_type,
            ''component_category'', component_category
        )
    ) WITHIN GROUP (ORDER BY
        CASE WHEN UPPER(make) = UPPER(:v_classification:make::VARCHAR) THEN 0 ELSE 1 END,
        CASE WHEN UPPER(model) = UPPER(:v_classification:model::VARCHAR) THEN 0 ELSE 1 END
    )
    INTO :v_matches
    FROM SPROCKET.CURATED.COMPONENT_CATALOG
    WHERE UPPER(make) = UPPER(:v_classification:make::VARCHAR)
       OR UPPER(model) LIKE ''%'' || UPPER(:v_classification:model::VARCHAR) || ''%''
       OR UPPER(:v_classification:model::VARCHAR) LIKE ''%'' || UPPER(model) || ''%'';

    SELECT catalog_id INTO :v_proposed_catalog_id
    FROM SPROCKET.CURATED.COMPONENT_CATALOG
    WHERE UPPER(make) = UPPER(:v_classification:make::VARCHAR)
      AND (UPPER(model) = UPPER(:v_classification:model::VARCHAR)
           OR UPPER(model) LIKE ''%'' || UPPER(:v_classification:model::VARCHAR) || ''%''
           OR UPPER(:v_classification:model::VARCHAR) LIKE ''%'' || UPPER(model) || ''%'')
    ORDER BY LENGTH(model) ASC
    LIMIT 1;

    UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY
    SET status = ''CLASSIFIED'',
        status_updated_at = CURRENT_TIMESTAMP(),
        progress_pct = 25,
        classification = :v_classification,
        proposed_catalog_id = :v_proposed_catalog_id
    WHERE document_id = :p_document_id;

    RETURN OBJECT_CONSTRUCT(
        ''document_id'', :p_document_id,
        ''status'', ''CLASSIFIED'',
        ''classification'', :v_classification,
        ''proposed_catalog_id'', :v_proposed_catalog_id,
        ''existing_catalog_matches'', COALESCE(:v_matches, ARRAY_CONSTRUCT())
    );
END;
';

--------------------------------------------------------------------
-- INGEST_LINK: Checkpoint 3 - Create Catalog/Instance/Link
--------------------------------------------------------------------
-- Creates or reuses catalog entry, optionally creates bike instance, creates document link
-- Parameters:
--   p_catalog_id: NULL creates new catalog entry from classification
--   p_bike_id: NULL skips bike instance creation
--   p_link_type: NULL uses classification's link_type

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.INGEST_LINK(
    p_document_id VARCHAR,
    p_catalog_id VARCHAR,
    p_bike_id VARCHAR,
    p_link_type VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
'
DECLARE
    v_classification VARIANT;
    v_catalog_id VARCHAR;
    v_link_type VARCHAR;
    v_instance_id VARCHAR;
    v_link_id VARCHAR;
BEGIN
    SELECT classification INTO :v_classification
    FROM SPROCKET.RAW.DOCUMENT_REGISTRY
    WHERE document_id = :p_document_id;

    IF (v_classification IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(''status'', ''FAILED'', ''error'', ''Document not classified yet'');
    END IF;

    -- Resolve catalog_id
    IF (p_catalog_id IS NOT NULL) THEN
        v_catalog_id := :p_catalog_id;
    ELSE
        -- Create new catalog entry from classification
        v_catalog_id := UUID_STRING();
        INSERT INTO SPROCKET.CURATED.COMPONENT_CATALOG 
            (catalog_id, make, model, model_year, component_type, component_category, notes)
        SELECT 
            :v_catalog_id,
            :v_classification:make::VARCHAR,
            :v_classification:model::VARCHAR,
            :v_classification:model_year::INT,
            :v_classification:component_type::VARCHAR,
            :v_classification:component_category::VARCHAR,
            ''Auto-created via ingestion from document '' || :p_document_id;
    END IF;

    -- Resolve link_type
    v_link_type := COALESCE(:p_link_type, :v_classification:link_type::VARCHAR, ''manual'');

    -- Create bike instance if bike_id given and instance doesn''t exist
    IF (p_bike_id IS NOT NULL) THEN
        SELECT instance_id INTO :v_instance_id
        FROM SPROCKET.CURATED.BIKE_COMPONENT_INSTANCES
        WHERE bike_id = :p_bike_id AND catalog_id = :v_catalog_id
        LIMIT 1;

        IF (v_instance_id IS NULL) THEN
            v_instance_id := UUID_STRING();
            INSERT INTO SPROCKET.CURATED.BIKE_COMPONENT_INSTANCES 
                (instance_id, bike_id, catalog_id, is_stock, custom_notes)
            VALUES (
                :v_instance_id, :p_bike_id, :v_catalog_id, FALSE,
                ''Linked via ingestion''
            );
        END IF;
    END IF;

    -- Create document link if not exists
    SELECT link_id INTO :v_link_id
    FROM SPROCKET.CURATED.COMPONENT_DOCUMENT_LINK
    WHERE catalog_id = :v_catalog_id AND document_id = :p_document_id
    LIMIT 1;

    IF (v_link_id IS NULL) THEN
        v_link_id := UUID_STRING();
        INSERT INTO SPROCKET.CURATED.COMPONENT_DOCUMENT_LINK (link_id, catalog_id, document_id, link_type)
        VALUES (:v_link_id, :v_catalog_id, :p_document_id, :v_link_type);
    END IF;

    UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY
    SET status = ''LINKED'',
        status_updated_at = CURRENT_TIMESTAMP(),
        progress_pct = 40,
        proposed_catalog_id = :v_catalog_id
    WHERE document_id = :p_document_id;

    RETURN OBJECT_CONSTRUCT(
        ''document_id'', :p_document_id,
        ''status'', ''LINKED'',
        ''catalog_id'', :v_catalog_id,
        ''instance_id'', :v_instance_id,
        ''link_id'', :v_link_id,
        ''link_type'', :v_link_type
    );
END;
';

--------------------------------------------------------------------
-- INGEST_FINALIZE: Checkpoint 4 - Enqueue for Async Processing
--------------------------------------------------------------------
-- Validates status is LINKED or CLASSIFIED, enqueues for background processing
-- Returns estimated processing time

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.INGEST_FINALIZE(p_document_id VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
'
DECLARE
    v_current_status VARCHAR;
    v_page_count INT;
BEGIN
    SELECT status, page_count INTO :v_current_status, :v_page_count
    FROM SPROCKET.RAW.DOCUMENT_REGISTRY
    WHERE document_id = :p_document_id;

    IF (v_current_status NOT IN (''LINKED'', ''CLASSIFIED'')) THEN
        RETURN OBJECT_CONSTRUCT(''status'', ''ERROR'', ''error'', ''Cannot finalize, current status: '' || :v_current_status);
    END IF;

    -- Enqueue for async processing
    INSERT INTO SPROCKET.PIPELINE.INGEST_QUEUE (document_id) VALUES (:p_document_id);

    UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY
    SET status = ''INDEXING'', progress_pct = 45, status_updated_at = CURRENT_TIMESTAMP()
    WHERE document_id = :p_document_id;

    RETURN OBJECT_CONSTRUCT(
        ''document_id'', :p_document_id,
        ''status'', ''INDEXING'',
        ''message'', ''Document queued for processing. Typical time: 1 minute per 10 pages (image description is the slow step).'',
        ''estimated_minutes'', GREATEST(1, CEIL(:v_page_count / 10.0))
    );
END;
';

--------------------------------------------------------------------
-- INGEST_PROCESS_ASYNC: Background Worker
--------------------------------------------------------------------
-- Heavy-lifting async procedure:
-- 1. Parses all remaining pages
-- 2. Extracts images
-- 3. Saves images to stage
-- 4. Generates descriptions with pixtral-large
-- 5. Inserts text + image chunks into DOCUMENT_CHUNKS
-- 6. Updates progress_pct at checkpoints (50 → 60 → 70 → 75 → 90 → 100)

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.INGEST_PROCESS_ASYNC(p_document_id VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
'
DECLARE
    v_source_file VARCHAR;
    v_catalog_id VARCHAR;
    v_bike_id VARCHAR;
    v_bike_display VARCHAR;
    v_make VARCHAR;
    v_model VARCHAR;
    v_component_category VARCHAR;
    v_document_type VARCHAR;
    v_prefix VARCHAR;
    v_start_time TIMESTAMP;
    v_step_start TIMESTAMP;
    v_pages_parsed INT;
    v_images_extracted INT;
    v_text_chunks INT;
    v_image_chunks INT;
BEGIN
    -- Set event table for this session only
    ALTER SESSION SET EVENT_TABLE = SPROCKET.PIPELINE.INGESTION_EVENTS;
    
    v_start_time := CURRENT_TIMESTAMP();
    
    -- Log procedure entry
    SYSTEM$LOG_INFO(OBJECT_CONSTRUCT(
        ''procedure'', ''INGEST_PROCESS_ASYNC'',
        ''document_id'', :p_document_id,
        ''step'', ''start'',
        ''message'', ''Beginning async document processing''
    )::VARCHAR);

    UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY
    SET status = ''INDEXING'', status_updated_at = CURRENT_TIMESTAMP(), progress_pct = 50
    WHERE document_id = :p_document_id;

    -- Pull document + catalog info
    SELECT 
        dr.source_file,
        l.catalog_id,
        c.make, c.model, c.component_category,
        dr.classification:document_type::VARCHAR
    INTO :v_source_file, :v_catalog_id, :v_make, :v_model, :v_component_category, :v_document_type
    FROM SPROCKET.RAW.DOCUMENT_REGISTRY dr
    LEFT JOIN SPROCKET.CURATED.COMPONENT_DOCUMENT_LINK l ON dr.document_id = l.document_id
    LEFT JOIN SPROCKET.CURATED.COMPONENT_CATALOG c ON l.catalog_id = c.catalog_id
    WHERE dr.document_id = :p_document_id
    LIMIT 1;

    -- Generate unique image prefix from catalog_id (fallback to doc_id)
    v_prefix := REPLACE(COALESCE(:v_catalog_id, :p_document_id), ''-'', ''_'');

    -- Parse ALL pages (skipping already-parsed preview pages)
    v_step_start := CURRENT_TIMESTAMP();
    INSERT INTO SPROCKET.RAW.DOCUMENT_PAGES (document_id, page_number, content, images)
    WITH parsed AS (
        SELECT SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
            @SPROCKET.RAW.MANUALS_STAGE,
            :v_source_file,
            {''mode'': ''LAYOUT'', ''page_split'': TRUE, ''extract_images'': TRUE}
        ) AS result
    )
    SELECT 
        :p_document_id,
        p.value:index::INT + 1,
        p.value:content::VARCHAR,
        p.value:images
    FROM parsed, LATERAL FLATTEN(input => result:pages) p
    WHERE p.value:index::INT + 1 NOT IN (
        SELECT page_number FROM SPROCKET.RAW.DOCUMENT_PAGES WHERE document_id = :p_document_id
    );
    
    SELECT COUNT(*) INTO :v_pages_parsed FROM SPROCKET.RAW.DOCUMENT_PAGES WHERE document_id = :p_document_id;
    
    SYSTEM$LOG_INFO(OBJECT_CONSTRUCT(
        ''procedure'', ''INGEST_PROCESS_ASYNC'',
        ''document_id'', :p_document_id,
        ''step'', ''parse_pages'',
        ''duration_seconds'', DATEDIFF(second, :v_step_start, CURRENT_TIMESTAMP()),
        ''pages_parsed'', :v_pages_parsed,
        ''source_file'', :v_source_file
    )::VARCHAR);

    UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY SET progress_pct = 60, status_updated_at = CURRENT_TIMESTAMP()
    WHERE document_id = :p_document_id;

    -- Update images on the preview pages (we parsed them without extract_images earlier)
    UPDATE SPROCKET.RAW.DOCUMENT_PAGES dp
    SET images = src.images
    FROM (
        WITH parsed AS (
            SELECT SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
                @SPROCKET.RAW.MANUALS_STAGE,
                :v_source_file,
                {''mode'': ''LAYOUT'', ''page_split'': TRUE, ''extract_images'': TRUE}
            ) AS result
        )
        SELECT p.value:index::INT + 1 AS page_number, p.value:images AS images
        FROM parsed, LATERAL FLATTEN(input => result:pages) p
    ) src
    WHERE dp.document_id = :p_document_id
      AND dp.page_number = src.page_number
      AND dp.images IS NULL;

    -- Extract images
    v_step_start := CURRENT_TIMESTAMP();
    INSERT INTO SPROCKET.RAW.DOCUMENT_IMAGES (document_id, page_number, image_index, image_base64, image_type)
    SELECT 
        document_id, page_number, img.index, img.value:image_base64::VARCHAR, img.value:id::VARCHAR
    FROM SPROCKET.RAW.DOCUMENT_PAGES,
         LATERAL FLATTEN(input => images) img
    WHERE document_id = :p_document_id AND ARRAY_SIZE(images) > 0;
    
    SELECT COUNT(*) INTO :v_images_extracted FROM SPROCKET.RAW.DOCUMENT_IMAGES WHERE document_id = :p_document_id;
    
    SYSTEM$LOG_INFO(OBJECT_CONSTRUCT(
        ''procedure'', ''INGEST_PROCESS_ASYNC'',
        ''document_id'', :p_document_id,
        ''step'', ''extract_images'',
        ''duration_seconds'', DATEDIFF(second, :v_step_start, CURRENT_TIMESTAMP()),
        ''images_extracted'', :v_images_extracted
    )::VARCHAR);

    UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY SET progress_pct = 70, status_updated_at = CURRENT_TIMESTAMP()
    WHERE document_id = :p_document_id;

    -- Save images to stage and generate descriptions
    v_step_start := CURRENT_TIMESTAMP();
    CALL SPROCKET.PIPELINE.SAVE_DOC_IMAGES_TO_STAGE(:p_document_id, :v_prefix);
    ALTER STAGE SPROCKET.RAW.IMAGES_STAGE REFRESH;

    UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY SET progress_pct = 75, status_updated_at = CURRENT_TIMESTAMP()
    WHERE document_id = :p_document_id;

    UPDATE SPROCKET.RAW.DOCUMENT_IMAGES di
    SET description = AI_COMPLETE(
        ''pixtral-large'',
        ''You are a bicycle mechanic assistant. Describe this image from a '' || COALESCE(:v_make || '' '' || :v_model, ''bicycle'') || '' service manual. Focus on technical details like part names, assembly steps, bolt locations, tool sizes, torque specs, and measurements. Be concise but thorough. If it shows a diagram, describe all labeled parts.'',
        TO_FILE(''@SPROCKET.RAW.IMAGES_STAGE'', ''page'' || di.page_number || ''_img'' || di.image_index || ''.jpeg''),
        {''max_tokens'': 500}
    )
    WHERE document_id = :p_document_id AND description IS NULL;
    
    SYSTEM$LOG_INFO(OBJECT_CONSTRUCT(
        ''procedure'', ''INGEST_PROCESS_ASYNC'',
        ''document_id'', :p_document_id,
        ''step'', ''generate_image_descriptions'',
        ''duration_seconds'', DATEDIFF(second, :v_step_start, CURRENT_TIMESTAMP()),
        ''images_described'', :v_images_extracted,
        ''message'', ''pixtral-large AI_COMPLETE calls completed''
    )::VARCHAR);

    UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY SET progress_pct = 90, status_updated_at = CURRENT_TIMESTAMP()
    WHERE document_id = :p_document_id;

    -- Insert text chunks
    v_step_start := CURRENT_TIMESTAMP();
    INSERT INTO SPROCKET.SEARCH.DOCUMENT_CHUNKS (
        document_id, content, page_number, chunk_type, source_file,
        component_category, document_type, component_catalog_ids, component_makes, component_models
    )
    SELECT 
        dp.document_id,
        dp.content,
        dp.page_number,
        ''text'',
        :v_source_file,
        :v_component_category,
        :v_document_type,
        ARRAY_CONSTRUCT(:v_catalog_id),
        ARRAY_CONSTRUCT(:v_make),
        ARRAY_CONSTRUCT(:v_model)
    FROM SPROCKET.RAW.DOCUMENT_PAGES dp
    WHERE dp.document_id = :p_document_id AND LENGTH(dp.content) > 10;
    
    SELECT COUNT(*) INTO :v_text_chunks FROM SPROCKET.SEARCH.DOCUMENT_CHUNKS 
    WHERE document_id = :p_document_id AND chunk_type = ''text'';

    -- Insert image description chunks
    INSERT INTO SPROCKET.SEARCH.DOCUMENT_CHUNKS (
        document_id, content, page_number, chunk_type, source_file,
        component_category, document_type, component_catalog_ids, component_makes, component_models
    )
    SELECT 
        di.document_id,
        ''[Image: page '' || di.page_number || '', figure '' || di.image_index || ''] '' || di.description,
        di.page_number,
        ''image_description'',
        :v_source_file,
        :v_component_category,
        :v_document_type,
        ARRAY_CONSTRUCT(:v_catalog_id),
        ARRAY_CONSTRUCT(:v_make),
        ARRAY_CONSTRUCT(:v_model)
    FROM SPROCKET.RAW.DOCUMENT_IMAGES di
    WHERE di.document_id = :p_document_id AND LENGTH(di.description) > 10;
    
    SELECT COUNT(*) INTO :v_image_chunks FROM SPROCKET.SEARCH.DOCUMENT_CHUNKS 
    WHERE document_id = :p_document_id AND chunk_type = ''image_description'';
    
    SYSTEM$LOG_INFO(OBJECT_CONSTRUCT(
        ''procedure'', ''INGEST_PROCESS_ASYNC'',
        ''document_id'', :p_document_id,
        ''step'', ''create_search_chunks'',
        ''duration_seconds'', DATEDIFF(second, :v_step_start, CURRENT_TIMESTAMP()),
        ''text_chunks'', :v_text_chunks,
        ''image_chunks'', :v_image_chunks,
        ''total_chunks'', :v_text_chunks + :v_image_chunks
    )::VARCHAR);

    UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY
    SET status = ''READY'', progress_pct = 100, status_updated_at = CURRENT_TIMESTAMP()
    WHERE document_id = :p_document_id;

    DELETE FROM SPROCKET.PIPELINE.INGEST_QUEUE WHERE document_id = :p_document_id;
    
    -- Log successful completion
    SYSTEM$LOG_INFO(OBJECT_CONSTRUCT(
        ''procedure'', ''INGEST_PROCESS_ASYNC'',
        ''document_id'', :p_document_id,
        ''step'', ''complete'',
        ''total_duration_seconds'', DATEDIFF(second, :v_start_time, CURRENT_TIMESTAMP()),
        ''pages'', :v_pages_parsed,
        ''images'', :v_images_extracted,
        ''chunks'', :v_text_chunks + :v_image_chunks,
        ''status'', ''SUCCESS''
    )::VARCHAR);

    RETURN OBJECT_CONSTRUCT(
        ''document_id'', :p_document_id,
        ''status'', ''READY'',
        ''message'', ''Document processing complete''
    );

EXCEPTION
    WHEN OTHER THEN
        -- Log error
        SYSTEM$LOG_ERROR(OBJECT_CONSTRUCT(
            ''procedure'', ''INGEST_PROCESS_ASYNC'',
            ''document_id'', :p_document_id,
            ''step'', ''error'',
            ''error_message'', :SQLERRM,
            ''sqlstate'', :SQLSTATE,
            ''duration_seconds'', DATEDIFF(second, :v_start_time, CURRENT_TIMESTAMP())
        )::VARCHAR);
        
        UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY
        SET status = ''FAILED'',
            status_updated_at = CURRENT_TIMESTAMP(),
            error_message = :SQLERRM
        WHERE document_id = :p_document_id;

        DELETE FROM SPROCKET.PIPELINE.INGEST_QUEUE WHERE document_id = :p_document_id;

        RETURN OBJECT_CONSTRUCT(
            ''document_id'', :p_document_id,
            ''status'', ''FAILED'',
            ''error'', :SQLERRM
        );
END;
';

--------------------------------------------------------------------
-- INGEST_ABORT: Cancel Ingestion and Clean Up
--------------------------------------------------------------------
-- Removes document from queue, deletes chunks/images/pages/links, marks ABORTED

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.INGEST_ABORT(
    p_document_id VARCHAR,
    p_reason VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
'
BEGIN
    DELETE FROM SPROCKET.PIPELINE.INGEST_QUEUE WHERE document_id = :p_document_id;
    DELETE FROM SPROCKET.SEARCH.DOCUMENT_CHUNKS WHERE document_id = :p_document_id;
    DELETE FROM SPROCKET.RAW.DOCUMENT_IMAGES WHERE document_id = :p_document_id;
    DELETE FROM SPROCKET.RAW.DOCUMENT_PAGES WHERE document_id = :p_document_id;
    DELETE FROM SPROCKET.CURATED.COMPONENT_DOCUMENT_LINK WHERE document_id = :p_document_id;

    UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY
    SET status = ''ABORTED'',
        status_updated_at = CURRENT_TIMESTAMP(),
        error_message = COALESCE(:p_reason, ''User aborted'')
    WHERE document_id = :p_document_id;

    RETURN OBJECT_CONSTRUCT(
        ''document_id'', :p_document_id,
        ''status'', ''ABORTED'',
        ''reason'', COALESCE(:p_reason, ''User aborted'')
    );
END;
';

--------------------------------------------------------------------
-- INGEST_STATUS: Check Ingestion Status and Progress
--------------------------------------------------------------------
-- Returns current status, progress_pct, classification, errors

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.INGEST_STATUS(p_document_id VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
'
DECLARE
    v_result VARIANT;
BEGIN
    SELECT OBJECT_CONSTRUCT(
        ''document_id'', document_id,
        ''source_file'', source_file,
        ''status'', status,
        ''progress_pct'', progress_pct,
        ''status_updated_at'', status_updated_at,
        ''page_count'', page_count,
        ''classification'', classification,
        ''proposed_catalog_id'', proposed_catalog_id,
        ''error_message'', error_message
    )
    INTO :v_result
    FROM SPROCKET.RAW.DOCUMENT_REGISTRY
    WHERE document_id = :p_document_id;

    RETURN COALESCE(v_result, OBJECT_CONSTRUCT(''status'', ''NOT_FOUND'', ''document_id'', :p_document_id));
END;
';
