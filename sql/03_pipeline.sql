--------------------------------------------------------------------
-- 03_pipeline.sql  –  Sprocket Phase 1 Document Processing Pipeline
--------------------------------------------------------------------

USE ROLE SYSADMIN;
USE WAREHOUSE SPROCKET_WH;

--------------------------------------------------------------------
-- Step 1: Parse PDF with AI_PARSE_DOCUMENT (LAYOUT + page_split + images)
--------------------------------------------------------------------

INSERT INTO SPROCKET.RAW.DOCUMENT_PAGES (document_id, page_number, content, images)
WITH parsed AS (
    SELECT SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
        @SPROCKET.RAW.MANUALS_STAGE,
        '2021_STUMPJUMPER_EVO_USER_MANUAL_ENGLISH.pdf',
        {'mode': 'LAYOUT', 'page_split': TRUE, 'extract_images': TRUE}
    ) AS result
),
doc AS (
    SELECT document_id FROM SPROCKET.RAW.DOCUMENT_REGISTRY 
    WHERE source_file = '2021_STUMPJUMPER_EVO_USER_MANUAL_ENGLISH.pdf'
    LIMIT 1
)
SELECT 
    doc.document_id,
    p.value:index::INT + 1 AS page_number,
    p.value:content::VARCHAR AS content,
    p.value:images AS images
FROM parsed, doc,
     LATERAL FLATTEN(input => parsed.result:pages) p;

--------------------------------------------------------------------
-- Step 2: Extract images into DOCUMENT_IMAGES
--------------------------------------------------------------------

INSERT INTO SPROCKET.RAW.DOCUMENT_IMAGES (document_id, page_number, image_index, image_base64, image_type)
SELECT 
    document_id,
    page_number,
    img.index AS image_index,
    img.value:image_base64::VARCHAR AS image_base64,
    img.value:id::VARCHAR AS image_type
FROM SPROCKET.RAW.DOCUMENT_PAGES,
     LATERAL FLATTEN(input => images) img
WHERE ARRAY_SIZE(images) > 0;

--------------------------------------------------------------------
-- Step 3: Save images to stage for AI_COMPLETE vision
--------------------------------------------------------------------

CALL SPROCKET.PIPELINE.SAVE_IMAGES_TO_STAGE();
ALTER STAGE SPROCKET.RAW.IMAGES_STAGE REFRESH;

--------------------------------------------------------------------
-- Step 4: Generate image descriptions with pixtral-large
--------------------------------------------------------------------

UPDATE SPROCKET.RAW.DOCUMENT_IMAGES di
SET description = AI_COMPLETE(
    'pixtral-large',
    'You are a bicycle mechanic assistant. Describe this image from a Specialized Stumpjumper EVO 2021 user manual. Focus on technical details like part names, assembly steps, bolt locations, tool sizes, torque specs, and measurements. Be concise but thorough. If it shows a diagram, describe all labeled parts.',
    TO_FILE('@SPROCKET.RAW.IMAGES_STAGE', 'page' || di.page_number || '_img' || di.image_index || '.jpeg'),
    {'max_tokens': 500}
)
WHERE description IS NULL;

--------------------------------------------------------------------
-- Step 5: Populate SEARCH.DOCUMENT_CHUNKS (text + image descriptions)
--------------------------------------------------------------------

-- Text chunks (one per page)
INSERT INTO SPROCKET.SEARCH.DOCUMENT_CHUNKS (document_id, content, section, page_number, chunk_type, source_file, bike_model, model_year)
WITH doc AS (
    SELECT document_id FROM SPROCKET.RAW.DOCUMENT_REGISTRY 
    WHERE source_file = '2021_STUMPJUMPER_EVO_USER_MANUAL_ENGLISH.pdf'
    LIMIT 1
)
SELECT 
    doc.document_id,
    p.content,
    CASE 
        WHEN p.page_number <= 3 THEN 'Cover and Table of Contents'
        WHEN p.page_number = 4 THEN '1. Introduction'
        WHEN p.page_number BETWEEN 5 AND 8 THEN '2. Assembly Notes'
        WHEN p.page_number = 9 THEN '4. Specifications - Geometry'
        WHEN p.page_number = 10 THEN '4. Specifications - General'
        WHEN p.page_number BETWEEN 11 AND 13 THEN '4. Specifications - Torque and Hardware'
        WHEN p.page_number BETWEEN 14 AND 18 THEN '5. Internal Routing'
        WHEN p.page_number BETWEEN 19 AND 25 THEN '6. Rear Triangle Pivot Assembly'
        WHEN p.page_number BETWEEN 26 AND 27 THEN '7.1 Flip Chips'
        WHEN p.page_number BETWEEN 28 AND 30 THEN '7.2 Headset and Fork / 8. Air Shock Setup'
        WHEN p.page_number = 31 THEN '9. Derailleur Hanger'
        WHEN p.page_number BETWEEN 32 AND 33 THEN '10. SWAT Bladder'
        ELSE 'Other'
    END AS section,
    p.page_number,
    'text' AS chunk_type,
    '2021_STUMPJUMPER_EVO_USER_MANUAL_ENGLISH.pdf' AS source_file,
    '2021 Specialized Stumpjumper EVO' AS bike_model,
    2021 AS model_year
FROM SPROCKET.RAW.DOCUMENT_PAGES p, doc
WHERE p.content IS NOT NULL AND LENGTH(p.content) > 10;

-- Image description chunks
INSERT INTO SPROCKET.SEARCH.DOCUMENT_CHUNKS (document_id, content, section, page_number, chunk_type, source_file, bike_model, model_year)
WITH doc AS (
    SELECT document_id FROM SPROCKET.RAW.DOCUMENT_REGISTRY 
    WHERE source_file = '2021_STUMPJUMPER_EVO_USER_MANUAL_ENGLISH.pdf'
    LIMIT 1
)
SELECT 
    doc.document_id,
    '[Image: page ' || di.page_number || ', figure ' || di.image_index || '] ' || di.description AS content,
    CASE 
        WHEN di.page_number <= 3 THEN 'Cover and Table of Contents'
        WHEN di.page_number = 4 THEN '1. Introduction'
        WHEN di.page_number BETWEEN 5 AND 8 THEN '2. Assembly Notes'
        WHEN di.page_number = 9 THEN '4. Specifications - Geometry'
        WHEN di.page_number = 10 THEN '4. Specifications - General'
        WHEN di.page_number BETWEEN 11 AND 13 THEN '4. Specifications - Torque and Hardware'
        WHEN di.page_number BETWEEN 14 AND 18 THEN '5. Internal Routing'
        WHEN di.page_number BETWEEN 19 AND 25 THEN '6. Rear Triangle Pivot Assembly'
        WHEN di.page_number BETWEEN 26 AND 27 THEN '7.1 Flip Chips'
        WHEN di.page_number BETWEEN 28 AND 30 THEN '7.2 Headset and Fork / 8. Air Shock Setup'
        WHEN di.page_number = 31 THEN '9. Derailleur Hanger'
        WHEN di.page_number BETWEEN 32 AND 33 THEN '10. SWAT Bladder'
        ELSE 'Other'
    END AS section,
    di.page_number,
    'image_description' AS chunk_type,
    '2021_STUMPJUMPER_EVO_USER_MANUAL_ENGLISH.pdf' AS source_file,
    '2021 Specialized Stumpjumper EVO' AS bike_model,
    2021 AS model_year
FROM SPROCKET.RAW.DOCUMENT_IMAGES di, doc
WHERE di.description IS NOT NULL AND LENGTH(di.description) > 10;

--------------------------------------------------------------------
-- Step 6: Update document status
--------------------------------------------------------------------

UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY 
SET status = 'PROCESSED' 
WHERE source_file = '2021_STUMPJUMPER_EVO_USER_MANUAL_ENGLISH.pdf';
