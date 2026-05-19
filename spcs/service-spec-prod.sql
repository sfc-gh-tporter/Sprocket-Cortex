-- =============================================================
-- Sprocket Frontend — PROD Service Specification
-- Applied via deploy-frontend-service.yml on changes to spcs/
-- =============================================================

USE WAREHOUSE SPROCKET_WH;

ALTER SERVICE SPROCKET.APP.SPROCKET_FRONTEND
FROM SPECIFICATION $$
spec:
  containers:
    - name: sprocket-frontend
      image: /sprocket/app/sprocket_images/sprocket-frontend:latest
      env:
        SNOWFLAKE_WAREHOUSE: SPROCKET_WH
        SNOWFLAKE_DATABASE: SPROCKET
        SNOWFLAKE_SCHEMA: APP
        AGENT_DB: SPROCKET
        AGENT_SCHEMA: AGENT
        AGENT_NAME: SPROCKET_AGENT
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
