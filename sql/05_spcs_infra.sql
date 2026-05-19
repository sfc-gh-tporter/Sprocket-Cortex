-- =============================================================
-- Sprocket Frontend — SPCS Infrastructure (Compute Pool + Image Repo)
-- Run once to set up shared infra. Service specs live in spcs/
-- =============================================================

USE SCHEMA APP;

CREATE IMAGE REPOSITORY IF NOT EXISTS APP.SPROCKET_IMAGES;

CREATE COMPUTE POOL IF NOT EXISTS SPROCKET_FRONTEND_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 300
  COMMENT = 'Sprocket frontend service compute pool';
