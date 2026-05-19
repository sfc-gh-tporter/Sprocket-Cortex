-- =============================================================
-- Sprocket Frontend — DEV Service Specification
-- Applied via deploy-frontend-service.yml on changes to spcs/
-- =============================================================

USE WAREHOUSE SPROCKET_WH;

CREATE SERVICE IF NOT EXISTS SPROCKET_DEV.APP.SPROCKET_FRONTEND_DEV
  IN COMPUTE POOL SPROCKET_FRONTEND_POOL
  MIN_INSTANCES = 1
  MAX_INSTANCES = 1
  FROM SPECIFICATION $$
spec:
  containers:
    - name: sprocket-frontend
      image: /sprocket_dev/app/sprocket_images/sprocket-frontend:dev
      env:
        SNOWFLAKE_WAREHOUSE: SPROCKET_WH
        SNOWFLAKE_DATABASE: SPROCKET_DEV
        SNOWFLAKE_SCHEMA: APP
        AGENT_DB: SPROCKET_DEV
        AGENT_SCHEMA: AGENT
        AGENT_NAME: SPROCKET_AGENT_DEV
        FRONTEND_DIST: /app/frontend/dist
      readinessProbe:
        port: 3001
        path: /health
  endpoints:
    - name: http
      port: 3001
      public: true
capabilities:
  securityContext:
    executeAsCaller: true
$$;

ALTER SERVICE SPROCKET_DEV.APP.SPROCKET_FRONTEND_DEV
FROM SPECIFICATION $$
spec:
  containers:
    - name: sprocket-frontend
      image: /sprocket_dev/app/sprocket_images/sprocket-frontend:dev
      env:
        SNOWFLAKE_WAREHOUSE: SPROCKET_WH
        SNOWFLAKE_DATABASE: SPROCKET_DEV
        SNOWFLAKE_SCHEMA: APP
        AGENT_DB: SPROCKET_DEV
        AGENT_SCHEMA: AGENT
        AGENT_NAME: SPROCKET_AGENT_DEV
        FRONTEND_DIST: /app/frontend/dist
      readinessProbe:
        port: 3001
        path: /health
  endpoints:
    - name: http
      port: 3001
      public: true
capabilities:
  securityContext:
    executeAsCaller: true
$$;
