--------------------------------------------------------------------
-- 02_data_model.sql  –  Sprocket Phase 1 Data Model
--------------------------------------------------------------------

USE ROLE SPROCKET_DEPLOYER;
USE WAREHOUSE SPROCKET_WH;

----------------------------------------------------------------------
-- RAW SCHEMA – pipeline landing tables
----------------------------------------------------------------------

CREATE OR ALTER TABLE RAW.DOCUMENT_REGISTRY (
    document_id     VARCHAR DEFAULT UUID_STRING(),
    source_file     VARCHAR NOT NULL,
    file_path       VARCHAR,
    upload_date     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    status          VARCHAR DEFAULT 'UPLOADED',
    page_count      INT,
    file_size_bytes INT,
    metadata        VARIANT,
    status_updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    progress_pct    INT DEFAULT 0,    
    classification  VARIANT,
    error_message   VARCHAR,
    PRIMARY KEY (document_id)
);

CREATE OR ALTER TABLE RAW.DOCUMENT_PAGES (
    page_id         VARCHAR DEFAULT UUID_STRING(),
    document_id     VARCHAR NOT NULL,
    page_number     INT NOT NULL,
    content         VARCHAR(16777216),
    images          VARIANT,
    metadata        VARIANT,
    PRIMARY KEY (page_id)
);

CREATE OR ALTER TABLE RAW.DOCUMENT_IMAGES (
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
-- MODELED SCHEMA – reference tables
----------------------------------------------------------------------

CREATE OR ALTER TABLE MODELED.BIKES (
    bike_id         VARCHAR DEFAULT UUID_STRING(),
    model_year      INT NOT NULL,
    make            VARCHAR NOT NULL,
    model           VARCHAR NOT NULL,
    category        VARCHAR,
    condition_level INT,
    notes           VARCHAR,
    PRIMARY KEY (bike_id)
);

CREATE OR ALTER TABLE MODELED.COMPONENT_CATALOG (
    catalog_id          VARCHAR DEFAULT UUID_STRING(),
    make                VARCHAR NOT NULL,
    model               VARCHAR NOT NULL,
    model_year          INT,
    component_type      VARCHAR NOT NULL,
    component_category  VARCHAR NOT NULL,
    default_specs       VARIANT DEFAULT OBJECT_CONSTRUCT(),
    notes               VARCHAR,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (catalog_id)
);

CREATE OR ALTER TABLE MODELED.BIKE_COMPONENT_INSTANCES (
    instance_id             VARCHAR DEFAULT UUID_STRING(),
    bike_id                 VARCHAR NOT NULL,
    catalog_id              VARCHAR NOT NULL,
    installed_date          DATE,
    serial_number           VARCHAR,
    custom_notes            VARCHAR,
    current_service_hours   FLOAT,
    is_stock                BOOLEAN DEFAULT TRUE,
    created_at              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (instance_id)
);

CREATE OR ALTER TABLE MODELED.COMPONENT_DOCUMENT_LINK (
    link_id         VARCHAR DEFAULT UUID_STRING(),
    catalog_id      VARCHAR NOT NULL,
    document_id     VARCHAR NOT NULL,
    link_type       VARCHAR DEFAULT 'manual',
    notes           VARCHAR,
    created_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (link_id),
    UNIQUE (catalog_id, document_id)
);

----------------------------------------------------------------------
-- SEARCH SCHEMA – Cortex Search source table
----------------------------------------------------------------------
CREATE OR ALTER TABLE SEARCH.DOCUMENT_CHUNKS (
    chunk_id                VARCHAR DEFAULT UUID_STRING(),
    document_id             VARCHAR NOT NULL,
    content                 VARCHAR(16777216) NOT NULL,
    section                 VARCHAR,
    section_type            VARCHAR,
    page_number             INT,
    chunk_type              VARCHAR DEFAULT 'text',
    source_file             VARCHAR,
    bike_model              VARCHAR,
    model_year              INT,
    component_category      VARCHAR,
    document_type           VARCHAR,
    component_catalog_ids   ARRAY,
    component_makes         ARRAY,
    component_models        ARRAY,
    PRIMARY KEY (chunk_id)
);


