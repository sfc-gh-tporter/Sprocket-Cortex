-- =============================================================
-- Sprocket Frontend — SPCS Infrastructure
-- Run once to set up compute pool, image repo, and OAuth policy
-- =============================================================

-- ── DEV ───────────────────────────────────────────────────────

USE DATABASE SPROCKET_DEV;
USE SCHEMA APP;
USE WAREHOUSE SPROCKET_WH;

-- Image repository (shared between dev and prod images via tags)
CREATE IMAGE REPOSITORY IF NOT EXISTS SPROCKET_DEV.APP.SPROCKET_IMAGES;

-- Compute pool for the frontend container
CREATE COMPUTE POOL IF NOT EXISTS SPROCKET_FRONTEND_POOL_DEV
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 300
  COMMENT = 'Sprocket frontend service (dev)';

-- SPCS service spec for DEV
-- NOTE: Image tag :dev is pushed by CI/CD
CREATE SERVICE IF NOT EXISTS SPROCKET_DEV.APP.SPROCKET_FRONTEND_DEV
  IN COMPUTE POOL SPROCKET_FRONTEND_POOL_DEV
  FROM SPECIFICATION $$
    spec:
      containers:
        - name: sprocket-frontend
          image: /sprocket_dev/app/sprocket_images/sprocket-frontend:dev
          env:
            PORT: "3001"
            SNOWFLAKE_ACCOUNT: ""
            SNOWFLAKE_WAREHOUSE: "SPROCKET_WH"
            SNOWFLAKE_DATABASE: "SPROCKET_DEV"
            SNOWFLAKE_SCHEMA: "APP"
            AGENT_DB: "SPROCKET_DEV"
            AGENT_SCHEMA: "APP"
            AGENT_NAME: "SPROCKET_AGENT_DEV"
            FRONTEND_DIST: "/app/frontend/dist"
          readinessProbe:
            port: 3001
            path: /health
      endpoints:
        - name: http
          port: 3001
          public: true
  $$
  MIN_INSTANCES = 1
  MAX_INSTANCES = 1
  COMMENT = 'Sprocket React+Node frontend (dev)';

GRANT USAGE ON SERVICE SPROCKET_DEV.APP.SPROCKET_FRONTEND_DEV TO ROLE SYSADMIN;

-- ── PROD ──────────────────────────────────────────────────────

USE DATABASE SPROCKET;
USE SCHEMA APP;

CREATE IMAGE REPOSITORY IF NOT EXISTS SPROCKET.APP.SPROCKET_IMAGES;

CREATE COMPUTE POOL IF NOT EXISTS SPROCKET_FRONTEND_POOL
  MIN_NODES = 1
  MAX_NODES = 2
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 600
  COMMENT = 'Sprocket frontend service (prod)';

CREATE SERVICE IF NOT EXISTS SPROCKET.APP.SPROCKET_FRONTEND
  IN COMPUTE POOL SPROCKET_FRONTEND_POOL
  FROM SPECIFICATION $$
    spec:
      containers:
        - name: sprocket-frontend
          image: /sprocket/app/sprocket_images/sprocket-frontend:latest
          env:
            PORT: "3001"
            SNOWFLAKE_ACCOUNT: ""
            SNOWFLAKE_WAREHOUSE: "SPROCKET_WH"
            SNOWFLAKE_DATABASE: "SPROCKET"
            SNOWFLAKE_SCHEMA: "APP"
            AGENT_DB: "SPROCKET"
            AGENT_SCHEMA: "APP"
            AGENT_NAME: "SPROCKET_AGENT"
            FRONTEND_DIST: "/app/frontend/dist"
          readinessProbe:
            port: 3001
            path: /health
      endpoints:
        - name: http
          port: 3001
          public: true
  $$
  MIN_INSTANCES = 1
  MAX_INSTANCES = 2
  COMMENT = 'Sprocket React+Node frontend (prod)';

GRANT USAGE ON SERVICE SPROCKET.APP.SPROCKET_FRONTEND TO ROLE SYSADMIN;

-- ── Useful queries ────────────────────────────────────────────
-- Check service status:
--   SHOW SERVICES IN SCHEMA SPROCKET.APP;
--   CALL SYSTEM$GET_SERVICE_STATUS('SPROCKET.APP.SPROCKET_FRONTEND');
--
-- Get public endpoint URL:
--   SHOW ENDPOINTS IN SERVICE SPROCKET.APP.SPROCKET_FRONTEND;
--
-- View logs:
--   CALL SYSTEM$GET_SERVICE_LOGS('SPROCKET.APP.SPROCKET_FRONTEND', '0', 'sprocket-frontend', 50);
