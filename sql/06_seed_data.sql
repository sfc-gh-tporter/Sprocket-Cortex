--------------------------------------------------------------------
-- 06_seed_data.sql  –  Reference Data Seeding
--------------------------------------------------------------------

USE ROLE SYSADMIN;
USE WAREHOUSE SPROCKET_WH;

--------------------------------------------------------------------
-- Bike record
--------------------------------------------------------------------

INSERT INTO SPROCKET.CURATED.BIKES (bike_id, model_year, make, model, category, condition_level, notes)
VALUES ('stumpjumper-evo-2021', 2021, 'Specialized', 'Stumpjumper EVO', 'Mountain', 4, 'Full-suspension trail/enduro bike. Condition 4 intended use.');

--------------------------------------------------------------------
-- Component catalog
--------------------------------------------------------------------

INSERT INTO SPROCKET.CURATED.COMPONENT_CATALOG (catalog_id, make, model, model_year, component_type, component_category, default_specs, notes)
SELECT column1, column2, column3, column4, column5, column6, PARSE_JSON(column7), column8 FROM VALUES
    ('frame-stumpjumper-evo-2021', 'Specialized', 'Stumpjumper EVO', 2021, 'Frame', 'Frame',
     '{"material": "FACT 11m Carbon", "rear_travel_mm": "145-150", "hub_spacing_mm": 148, "bb_type": "BSA Threaded 73mm", "headset": "1 1/8 upper / 1.5 lower", "seatpost_diameter_mm": 34.9, "udh": true}', NULL),
    ('shock-rockshox-vivid-2024', 'RockShox', 'Vivid', 2024, 'Rear Shock', 'Suspension',
     '{"length_mm": 210, "stroke_s1_mm": 50, "stroke_s2_s6_mm": 55}', '2024 service manual applies');

--------------------------------------------------------------------
-- Bike component instances (what's actually on the user's bike)
--------------------------------------------------------------------

INSERT INTO SPROCKET.CURATED.BIKE_COMPONENT_INSTANCES (bike_id, catalog_id, is_stock, custom_notes)
VALUES
    ('stumpjumper-evo-2021', 'frame-stumpjumper-evo-2021', TRUE, 'Frame - primary component'),
    ('stumpjumper-evo-2021', 'shock-rockshox-vivid-2024', FALSE, 'Upgraded from stock Super Deluxe');

--------------------------------------------------------------------
-- Component-to-document links
--------------------------------------------------------------------

INSERT INTO SPROCKET.CURATED.COMPONENT_DOCUMENT_LINK (catalog_id, document_id, link_type)
SELECT 
    'frame-stumpjumper-evo-2021',
    document_id,
    'manual'
FROM SPROCKET.RAW.DOCUMENT_REGISTRY
WHERE source_file = '2021_STUMPJUMPER_EVO_USER_MANUAL_ENGLISH.pdf'
UNION ALL
SELECT 
    'shock-rockshox-vivid-2024',
    document_id,
    'service_manual'
FROM SPROCKET.RAW.DOCUMENT_REGISTRY
WHERE source_file = '2024-vivid-service-manual.pdf';

--------------------------------------------------------------------
-- Document registry (already done in pipeline, but included here for completeness)
--------------------------------------------------------------------

INSERT INTO SPROCKET.RAW.DOCUMENT_REGISTRY (source_file, file_path, page_count, file_size_bytes, status)
SELECT 
    '2021_STUMPJUMPER_EVO_USER_MANUAL_ENGLISH.pdf',
    '@SPROCKET.RAW.MANUALS_STAGE/2021_STUMPJUMPER_EVO_USER_MANUAL_ENGLISH.pdf',
    33,
    26075887,
    'PROCESSED'
WHERE NOT EXISTS (
    SELECT 1 FROM SPROCKET.RAW.DOCUMENT_REGISTRY 
    WHERE source_file = '2021_STUMPJUMPER_EVO_USER_MANUAL_ENGLISH.pdf'
);
