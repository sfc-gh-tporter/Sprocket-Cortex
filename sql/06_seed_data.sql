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
-- Component hierarchy
--------------------------------------------------------------------

INSERT INTO SPROCKET.CURATED.COMPONENTS (bike_id, category, component, part, specs)
SELECT column1, column2, column3, column4, PARSE_JSON(column5) FROM VALUES
    ('stumpjumper-evo-2021', 'Frame', 'Frame', 'Stumpjumper EVO Frame', '{"material": "FACT 11m Carbon", "condition_level": 4, "rear_travel_mm": "145-150"}'),
    ('stumpjumper-evo-2021', 'Frame', 'Headset', 'S182500005', '{"upper": "1 1/8 inch", "lower": "1.5 inch", "type": "ACB"}'),
    ('stumpjumper-evo-2021', 'Frame', 'Seat Collar', 'KCNC SPL-SC02-386', '{"diameter_mm": 38.6, "material": "7075-T6"}'),
    ('stumpjumper-evo-2021', 'Frame', 'Bottom Bracket', 'BSA Threaded', '{"shell_width_mm": 73, "type": "BSA threaded"}'),
    ('stumpjumper-evo-2021', 'Frame', 'Derailleur Hanger', 'SRAM UDH', '{"part_number": "S202600002", "type": "Universal Derailleur Hanger"}'),
    ('stumpjumper-evo-2021', 'Suspension', 'Rear Shock', 'Rear Shock', '{"length_mm": 210, "stroke_s1_mm": 50, "stroke_s2_s6_mm": 55, "sag_mm": 16.5}'),
    ('stumpjumper-evo-2021', 'Suspension', 'Fork', 'Front Fork', '{"max_travel_s1": 150, "max_travel_s2_s6": 160, "rake_mm": 44}'),
    ('stumpjumper-evo-2021', 'Suspension', 'Main Pivot Bearing', 'A', '{"qty": 2, "dimension": "15x24x7", "type": "double row"}'),
    ('stumpjumper-evo-2021', 'Suspension', 'Link Bearing', 'B', '{"qty": 6, "dimension": "12x21x5"}'),
    ('stumpjumper-evo-2021', 'Suspension', 'Horst Bearing', 'C', '{"qty": 4, "dimension": "12x21x5"}'),
    ('stumpjumper-evo-2021', 'Wheels', 'Rear Hub', 'S170200003', '{"spacing_mm": 148, "length_mm": 172, "axle_mm": 12, "standard": "Boost"}'),
    ('stumpjumper-evo-2021', 'Wheels', 'Rear Tire', 'Max Size', '{"max_29": "29x2.5", "max_275": "27.5x2.5"}'),
    ('stumpjumper-evo-2021', 'Drivetrain', 'Chainring', 'Chainring', '{"min_teeth": 28, "max_teeth": 34}'),
    ('stumpjumper-evo-2021', 'Brakes', 'Rear Brake Rotor', 'Brake Rotor', '{"min_mm": 180, "max_mm": 220}'),
    ('stumpjumper-evo-2021', 'Cockpit', 'Seatpost', 'Dropper Seatpost', '{"diameter_mm": 34.9, "min_insertion_mm": 80}');

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
