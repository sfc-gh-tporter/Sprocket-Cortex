--------------------------------------------------------------------
-- 08_ingestion_worker_task.sql  –  Sprocket Ingestion Worker Task
--------------------------------------------------------------------
-- Creates a scheduled task that processes the ingestion queue every 1 minute
-- Picks up documents from INGEST_QUEUE and calls INGEST_PROCESS_ASYNC

USE ROLE SYSADMIN;
USE WAREHOUSE SPROCKET_WH;

--------------------------------------------------------------------
-- INGEST_WORKER_TASK: Scheduled Queue Processor
--------------------------------------------------------------------
-- Runs every 1 minute, picks oldest document from queue, processes it
-- Uses row locking (picked_up_at) to prevent concurrent processing

CREATE OR REPLACE TASK SPROCKET.PIPELINE.INGEST_WORKER_TASK
    WAREHOUSE = SPROCKET_WH
    SCHEDULE = '1 MINUTE'
AS
DECLARE
    v_document_id VARCHAR;
    v_queue_id VARCHAR;
BEGIN
    -- Find oldest unprocessed document in queue
    SELECT queue_id, document_id INTO :v_queue_id, :v_document_id
    FROM SPROCKET.PIPELINE.INGEST_QUEUE
    WHERE picked_up_at IS NULL
    ORDER BY enqueued_at
    LIMIT 1;

    -- Process if found
    IF (v_queue_id IS NOT NULL) THEN
        -- Mark as picked up (prevents other workers from grabbing it)
        UPDATE SPROCKET.PIPELINE.INGEST_QUEUE 
        SET picked_up_at = CURRENT_TIMESTAMP() 
        WHERE queue_id = :v_queue_id;
        
        -- Execute async processing
        CALL SPROCKET.PIPELINE.INGEST_PROCESS_ASYNC(:v_document_id);
    END IF;
END;

--------------------------------------------------------------------
-- Start the task
--------------------------------------------------------------------
ALTER TASK SPROCKET.PIPELINE.INGEST_WORKER_TASK RESUME;

--------------------------------------------------------------------
-- Query to check task status
--------------------------------------------------------------------
-- SHOW TASKS IN SCHEMA SPROCKET.PIPELINE;
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'INGEST_WORKER_TASK')) ORDER BY SCHEDULED_TIME DESC LIMIT 10;
