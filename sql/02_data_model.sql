--------------------------------------------------------------------
-- 02_data_model.sql  –  Sprocket Phase 1 Data Model
--------------------------------------------------------------------

USE ROLE SYSADMIN;
USE WAREHOUSE SPROCKET_WH;

----------------------------------------------------------------------
-- RAW SCHEMA – pipeline landing tables
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS SPROCKET.RAW.DOCUMENT_REGISTRY (
    document_id     VARCHAR DEFAULT UUID_STRING(),
    source_file     VARCHAR NOT NULL,
    file_path       VARCHAR,
    upload_date     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    status          VARCHAR DEFAULT 'UPLOADED',
    page_count      INT,
    file_size_bytes INT,
    metadata        VARIANT,
    PRIMARY KEY (document_id)
);

CREATE TABLE IF NOT EXISTS SPROCKET.RAW.DOCUMENT_PAGES (
    page_id         VARCHAR DEFAULT UUID_STRING(),
    document_id     VARCHAR NOT NULL,
    page_number     INT NOT NULL,
    content         VARCHAR(16777216),
    images          VARIANT,
    metadata        VARIANT,
    PRIMARY KEY (page_id)
);

CREATE TABLE IF NOT EXISTS SPROCKET.RAW.DOCUMENT_IMAGES (
    image_id        VARCHAR DEFAULT UUID_STRING(),
    document_id     VARCHAR NOT NULL,
    page_number     INT NOT NULL,
    image_index     INT NOT NULL,
    image_base64    VARCHAR(16777216),
    image_type      VARCHAR,
    description     VARCHAR(16777216),
    PRIMARY KEY (image_id)
);

----------------------------------------------------------------------
-- CURATED SCHEMA – reference tables
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS SPROCKET.CURATED.BIKES (
    bike_id         VARCHAR DEFAULT UUID_STRING(),
    model_year      INT NOT NULL,
    make            VARCHAR NOT NULL,
    model           VARCHAR NOT NULL,
    category        VARCHAR,
    condition_level INT,
    notes           VARCHAR,
    PRIMARY KEY (bike_id)
);

CREATE TABLE IF NOT EXISTS SPROCKET.CURATED.COMPONENTS (
    component_id    VARCHAR DEFAULT UUID_STRING(),
    bike_id         VARCHAR,
    category        VARCHAR NOT NULL,
    component       VARCHAR NOT NULL,
    part            VARCHAR,
    specs           VARIANT,
    PRIMARY KEY (component_id)
);

----------------------------------------------------------------------
-- SEARCH SCHEMA – Cortex Search source table
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS SPROCKET.SEARCH.DOCUMENT_CHUNKS (
    chunk_id            VARCHAR DEFAULT UUID_STRING(),
    document_id         VARCHAR NOT NULL,
    content             VARCHAR(16777216) NOT NULL,
    section             VARCHAR,
    page_number         INT,
    chunk_type          VARCHAR DEFAULT 'text',
    source_file         VARCHAR,
    bike_model          VARCHAR,
    model_year          INT,
    component_category  VARCHAR,
    document_type       VARCHAR,
    PRIMARY KEY (chunk_id)
);

----------------------------------------------------------------------
-- APP SCHEMA – Hybrid tables for transactional data
----------------------------------------------------------------------

CREATE HYBRID TABLE IF NOT EXISTS SPROCKET.APP.SERVICE_HISTORY (
    service_id      VARCHAR NOT NULL DEFAULT UUID_STRING(),
    bike_id         VARCHAR NOT NULL,
    service_date    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    service_type    VARCHAR NOT NULL,
    component_id    VARCHAR,
    description     VARCHAR,
    parts_used      VARIANT,
    cost            FLOAT,
    mileage         FLOAT,
    technician      VARCHAR,
    notes           VARCHAR,
    PRIMARY KEY (service_id)
);

CREATE HYBRID TABLE IF NOT EXISTS SPROCKET.APP.CHAT_SESSIONS (
    session_id      VARCHAR NOT NULL DEFAULT UUID_STRING(),
    user_id         VARCHAR DEFAULT 'default',
    bike_id         VARCHAR,
    started_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    ended_at        TIMESTAMP_NTZ,
    title           VARCHAR,
    PRIMARY KEY (session_id)
);

CREATE HYBRID TABLE IF NOT EXISTS SPROCKET.APP.CHAT_MESSAGES (
    message_id      VARCHAR NOT NULL DEFAULT UUID_STRING(),
    session_id      VARCHAR NOT NULL,
    role            VARCHAR NOT NULL,
    content         VARCHAR(16777216) NOT NULL,
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    tool_calls      VARIANT,
    PRIMARY KEY (message_id),
    INDEX idx_session (session_id)
);
