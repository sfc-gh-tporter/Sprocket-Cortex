--------------------------------------------------------------------
-- test_phase1.sql  –  Phase 1 Acceptance Tests (Pure Search Path)
-- All 8 queries validated via Cortex Search
--------------------------------------------------------------------

USE ROLE SYSADMIN;
USE WAREHOUSE SPROCKET_WH;

--------------------------------------------------------------------
-- TEST 1: Allen key size and torque of main pivot bolt
-- Expected: 6mm HEX, 210 in-lbf / 24 Nm
--------------------------------------------------------------------
SELECT '** TEST 1: Main Pivot Bolt **' AS test;
WITH sr AS (
    SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SPROCKET.SEARCH.MANUAL_SEARCH',
        '{"query": "allen key size and torque main pivot bolt", "columns": ["content", "section", "page_number"], "limit": 3}'
    )) AS r
)
SELECT v.value:section::VARCHAR AS section, v.value:page_number::INT AS page,
       LEFT(v.value:content::VARCHAR, 300) AS content_preview
FROM sr, LATERAL FLATTEN(input => r:results) v;

--------------------------------------------------------------------
-- TEST 2: Stack in size S5
-- Expected: 644 mm
--------------------------------------------------------------------
SELECT '** TEST 2: Stack in S5 **' AS test;
WITH sr AS (
    SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SPROCKET.SEARCH.MANUAL_SEARCH',
        '{"query": "stack measurement size S5", "columns": ["content", "section", "page_number"], "limit": 3}'
    )) AS r
)
SELECT v.value:section::VARCHAR AS section, v.value:page_number::INT AS page,
       LEFT(v.value:content::VARCHAR, 300) AS content_preview
FROM sr, LATERAL FLATTEN(input => r:results) v;

--------------------------------------------------------------------
-- TEST 3: How to install rear wheel
--------------------------------------------------------------------
SELECT '** TEST 3: Rear Wheel Install **' AS test;
WITH sr AS (
    SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SPROCKET.SEARCH.MANUAL_SEARCH',
        '{"query": "how to install rear wheel", "columns": ["content", "section", "page_number"], "limit": 3}'
    )) AS r
)
SELECT v.value:section::VARCHAR AS section, v.value:page_number::INT AS page,
       LEFT(v.value:content::VARCHAR, 300) AS content_preview
FROM sr, LATERAL FLATTEN(input => r:results) v;

--------------------------------------------------------------------
-- TEST 4: Rear hub spacing
-- Expected: 148mm Boost
--------------------------------------------------------------------
SELECT '** TEST 4: Rear Hub Spacing **' AS test;
WITH sr AS (
    SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SPROCKET.SEARCH.MANUAL_SEARCH',
        '{"query": "rear hub spacing", "columns": ["content", "section", "page_number"], "limit": 3}'
    )) AS r
)
SELECT v.value:section::VARCHAR AS section, v.value:page_number::INT AS page,
       LEFT(v.value:content::VARCHAR, 300) AS content_preview
FROM sr, LATERAL FLATTEN(input => r:results) v;

--------------------------------------------------------------------
-- TEST 5: Walk through headset installation with pictures
--------------------------------------------------------------------
SELECT '** TEST 5: Headset Installation **' AS test;
WITH sr AS (
    SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SPROCKET.SEARCH.MANUAL_SEARCH',
        '{"query": "headset cup installation procedure", "columns": ["content", "section", "page_number", "chunk_type"], "limit": 5}'
    )) AS r
)
SELECT v.value:section::VARCHAR AS section, v.value:page_number::INT AS page,
       v.value:chunk_type::VARCHAR AS chunk_type,
       LEFT(v.value:content::VARCHAR, 300) AS content_preview
FROM sr, LATERAL FLATTEN(input => r:results) v;

--------------------------------------------------------------------
-- TEST 6: Does this use a UDH
-- Expected: Yes, SRAM UDH
--------------------------------------------------------------------
SELECT '** TEST 6: UDH **' AS test;
WITH sr AS (
    SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SPROCKET.SEARCH.MANUAL_SEARCH',
        '{"query": "UDH universal derailleur hanger", "columns": ["content", "section", "page_number"], "limit": 3}'
    )) AS r
)
SELECT v.value:section::VARCHAR AS section, v.value:page_number::INT AS page,
       LEFT(v.value:content::VARCHAR, 300) AS content_preview
FROM sr, LATERAL FLATTEN(input => r:results) v;

--------------------------------------------------------------------
-- TEST 7: Max insertion of seat post
-- Expected: Size-dependent: S1=220...S6=300
--------------------------------------------------------------------
SELECT '** TEST 7: Seatpost Max Insertion **' AS test;
WITH sr AS (
    SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SPROCKET.SEARCH.MANUAL_SEARCH',
        '{"query": "seatpost maximum insertion depth by frame size", "columns": ["content", "section", "page_number"], "limit": 3}'
    )) AS r
)
SELECT v.value:section::VARCHAR AS section, v.value:page_number::INT AS page,
       LEFT(v.value:content::VARCHAR, 300) AS content_preview
FROM sr, LATERAL FLATTEN(input => r:results) v;

--------------------------------------------------------------------
-- TEST 8: How to internally route rear brake lines
--------------------------------------------------------------------
SELECT '** TEST 8: Internal Brake Routing **' AS test;
WITH sr AS (
    SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SPROCKET.SEARCH.MANUAL_SEARCH',
        '{"query": "internally route rear brake lines housing", "columns": ["content", "section", "page_number"], "limit": 3}'
    )) AS r
)
SELECT v.value:section::VARCHAR AS section, v.value:page_number::INT AS page,
       LEFT(v.value:content::VARCHAR, 300) AS content_preview
FROM sr, LATERAL FLATTEN(input => r:results) v;

--------------------------------------------------------------------
-- SUMMARY
--------------------------------------------------------------------
SELECT '** DATA SUMMARY **' AS test;
SELECT 'SEARCH_CHUNKS' AS tbl, COUNT(*) AS cnt FROM SPROCKET.SEARCH.DOCUMENT_CHUNKS
UNION ALL SELECT 'DOCUMENT_PAGES', COUNT(*) FROM SPROCKET.RAW.DOCUMENT_PAGES
UNION ALL SELECT 'DOCUMENT_IMAGES', COUNT(*) FROM SPROCKET.RAW.DOCUMENT_IMAGES
UNION ALL SELECT 'BIKES', COUNT(*) FROM SPROCKET.CURATED.BIKES
UNION ALL SELECT 'COMPONENTS', COUNT(*) FROM SPROCKET.CURATED.COMPONENTS;
