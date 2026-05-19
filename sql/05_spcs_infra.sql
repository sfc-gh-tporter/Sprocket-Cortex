-- =============================================================
-- Sprocket Frontend — SPCS Infrastructure (Compute Pool + Image Repo)
-- Run once to set up shared infra. Service specs live in spcs/
-- =============================================================

-- ── DEV ───────────────────────────────────────────────────────

USE DATABASE SPROCKET_DEV;
USE SCHEMA APP;
USE WAREHOUSE SPROCKET_WH;

CREATE IMAGE REPOSITORY IF NOT EXISTS SPROCKET_DEV.APP.SPROCKET_IMAGES;

CREATE COMPUTE POOL IF NOT EXISTS SPROCKET_FRONTEND_POOL_DEV
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 300
  COMMENT = 'Sprocket frontend service (dev)';

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
