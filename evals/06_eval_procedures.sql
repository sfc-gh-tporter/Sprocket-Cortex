-- ============================================
-- Sprocket Agent Evaluation Procedures
-- ============================================
-- Purpose: Stored procedures for running evaluations and calculating Agent GPA
-- DO NOT RUN WITHOUT EXPLICIT APPROVAL - This is a template

USE SCHEMA SPROCKET.PIPELINE;

-- ============================================
-- 1. Convert eval tables to datasets
-- ============================================

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.CREATE_EVAL_DATASETS()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Create dataset for Cortex Search Basic eval
    CALL SYSTEM$CREATE_EVALUATION_DATASET(
        'Cortex Agent',
        'SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC',
        'SPROCKET.PIPELINE.DATASET_CORTEX_SEARCH_BASIC',
        OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH_DATA')
    );
    
    -- Create dataset for Multi-Step Reasoning eval
    CALL SYSTEM$CREATE_EVALUATION_DATASET(
        'Cortex Agent',
        'SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING',
        'SPROCKET.PIPELINE.DATASET_MULTI_STEP_REASONING',
        OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH_DATA')
    );
    
    -- Create dataset for Ingestion Workflow eval
    CALL SYSTEM$CREATE_EVALUATION_DATASET(
        'Cortex Agent',
        'SPROCKET.PIPELINE.EVAL_INGESTION_WORKFLOW',
        'SPROCKET.PIPELINE.DATASET_INGESTION_WORKFLOW',
        OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH_DATA')
    );
    
    -- Create dataset for Context Injection eval
    CALL SYSTEM$CREATE_EVALUATION_DATASET(
        'Cortex Agent',
        'SPROCKET.PIPELINE.EVAL_CONTEXT_INJECTION',
        'SPROCKET.PIPELINE.DATASET_CONTEXT_INJECTION',
        OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH_DATA')
    );
    
    RETURN 'All evaluation datasets created successfully';
END;
$$;

COMMENT ON PROCEDURE SPROCKET.PIPELINE.CREATE_EVAL_DATASETS IS
'Creates Snowflake evaluation datasets from eval tables. Run once after populating eval tables.';

-- ============================================
-- 2. Run individual evaluation
-- ============================================

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.RUN_SINGLE_EVAL(
    p_eval_name VARCHAR,           -- 'cortex_search', 'multi_step', 'ingestion', 'context'
    p_run_group VARCHAR,           -- Logical grouping (e.g., 'v1_baseline')
    p_config_stage_path VARCHAR    -- Path to YAML config file on stage
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_run_name VARCHAR;
    v_result VARIANT;
    v_eval_dataset VARCHAR;
BEGIN
    -- Construct unique run name
    SELECT CONCAT(p_run_group, '_', p_eval_name, '_', TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS'))
    INTO :v_run_name;
    
    -- Determine dataset name
    SELECT 
        CASE 
            WHEN p_eval_name = 'cortex_search' THEN 'SPROCKET.PIPELINE.DATASET_CORTEX_SEARCH_BASIC'
            WHEN p_eval_name = 'multi_step' THEN 'SPROCKET.PIPELINE.DATASET_MULTI_STEP_REASONING'
            WHEN p_eval_name = 'ingestion' THEN 'SPROCKET.PIPELINE.DATASET_INGESTION_WORKFLOW'
            WHEN p_eval_name = 'context' THEN 'SPROCKET.PIPELINE.DATASET_CONTEXT_INJECTION'
            ELSE NULL
        END
    INTO :v_eval_dataset;
    
    IF (v_eval_dataset IS NULL) THEN
        RETURN OBJECT_CONSTRUCT('error', 'Invalid eval_name. Must be: cortex_search, multi_step, ingestion, or context');
    END IF;
    
    -- Register eval run
    INSERT INTO SPROCKET.PIPELINE.EVAL_RUN_REGISTRY (
        eval_run_id,
        eval_run_group,
        eval_dataset_name,
        eval_config_path,
        agent_name,
        run_status,
        started_at
    ) VALUES (
        :v_run_name,
        :p_run_group,
        :v_eval_dataset,
        :p_config_stage_path,
        'SPROCKET.APP.SPROCKET_AGENT',
        'RUNNING',
        CURRENT_TIMESTAMP()
    );
    
    -- Start evaluation
    CALL EXECUTE_AI_EVALUATION(
        'START',
        OBJECT_CONSTRUCT('run_name', :v_run_name),
        :p_config_stage_path
    );
    
    RETURN OBJECT_CONSTRUCT(
        'status', 'started',
        'run_name', :v_run_name,
        'eval_dataset', :v_eval_dataset,
        'message', CONCAT('Evaluation started. Check status with: CALL SPROCKET.PIPELINE.CHECK_EVAL_STATUS(''', :v_run_name, ''')')
    );
END;
$$;

COMMENT ON PROCEDURE SPROCKET.PIPELINE.RUN_SINGLE_EVAL IS
'Runs a single evaluation and registers it in EVAL_RUN_REGISTRY.';

-- ============================================
-- 3. Check evaluation status
-- ============================================

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.CHECK_EVAL_STATUS(
    p_run_name VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_config_path VARCHAR;
    v_status VARIANT;
BEGIN
    -- Get config path from registry
    SELECT eval_config_path INTO :v_config_path
    FROM SPROCKET.PIPELINE.EVAL_RUN_REGISTRY
    WHERE eval_run_id = :p_run_name;
    
    -- Call status check
    CALL EXECUTE_AI_EVALUATION(
        'STATUS',
        OBJECT_CONSTRUCT('run_name', :p_run_name),
        :v_config_path
    );
    
    -- Return result (actual status is returned by EXECUTE_AI_EVALUATION via result set)
    RETURN OBJECT_CONSTRUCT(
        'message', 'Status check complete. See result set above.',
        'run_name', :p_run_name
    );
END;
$$;

COMMENT ON PROCEDURE SPROCKET.PIPELINE.CHECK_EVAL_STATUS IS
'Checks status of a running evaluation. Pass the run_name returned from RUN_SINGLE_EVAL.';

-- ============================================
-- 4. Update registry with completed eval results
-- ============================================

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.UPDATE_EVAL_RESULTS(
    p_run_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_eval_data VARIANT;
    v_avg_ac FLOAT;
    v_avg_lc FLOAT;
    v_custom_metrics VARIANT;
    v_record_count INT;
BEGIN
    -- Fetch evaluation results
    SELECT 
        AVG(record:metrics:correctness:score::FLOAT),
        AVG(record:metrics:logical_consistency:score::FLOAT),
        COUNT(*)
    INTO :v_avg_ac, :v_avg_lc, :v_record_count
    FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
        'SPROCKET',
        'APP',
        'SPROCKET_AGENT',
        'cortex agent',
        :p_run_name
    ));
    
    -- Update registry with results
    UPDATE SPROCKET.PIPELINE.EVAL_RUN_REGISTRY
    SET 
        run_status = 'COMPLETED',
        completed_at = CURRENT_TIMESTAMP(),
        total_records = :v_record_count,
        avg_answer_correctness = :v_avg_ac,
        avg_logical_consistency = :v_avg_lc
    WHERE eval_run_id = :p_run_name;
    
    RETURN CONCAT('Updated results for run: ', :p_run_name);
END;
$$;

COMMENT ON PROCEDURE SPROCKET.PIPELINE.UPDATE_EVAL_RESULTS IS
'Fetches evaluation results from Snowflake system tables and updates EVAL_RUN_REGISTRY. Call after eval completes.';

-- ============================================
-- 5. Run all evaluations in sequence
-- ============================================

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.RUN_ALL_EVALS(
    p_run_group VARCHAR  -- e.g., 'v1_baseline', 'v2_improved_orchestration'
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_result_cs VARIANT;
    v_result_ms VARIANT;
    v_results VARIANT;
BEGIN
    -- Run Cortex Search eval
    CALL SPROCKET.PIPELINE.RUN_SINGLE_EVAL(
        'cortex_search',
        :p_run_group,
        '@SPROCKET.PIPELINE.EVAL_CONFIG_STAGE/cortex_search_eval_config.yaml'
    );
    SELECT :v_result_cs := $1 FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    
    -- Run Multi-Step eval
    CALL SPROCKET.PIPELINE.RUN_SINGLE_EVAL(
        'multi_step',
        :p_run_group,
        '@SPROCKET.PIPELINE.EVAL_CONFIG_STAGE/multi_step_eval_config.yaml'
    );
    SELECT :v_result_ms := $1 FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    
    -- Note: Ingestion and Context evals require additional YAML configs and sample data
    -- Add those runs here once configs are created
    
    SELECT OBJECT_CONSTRUCT(
        'status', 'started',
        'run_group', :p_run_group,
        'evaluations_started', ARRAY_CONSTRUCT('cortex_search', 'multi_step'),
        'cortex_search_run', :v_result_cs:run_name,
        'multi_step_run', :v_result_ms:run_name,
        'message', 'All evaluations started. Wait 5-10 minutes then call SPROCKET.PIPELINE.FINALIZE_EVAL_GROUP to compute GPA.'
    ) INTO :v_results;
    
    RETURN :v_results;
END;
$$;

COMMENT ON PROCEDURE SPROCKET.PIPELINE.RUN_ALL_EVALS IS
'Runs all configured evaluations sequentially for a given run group. Use run_group to version agent iterations.';

-- ============================================
-- 6. Finalize eval group and calculate GPA
-- ============================================

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.FINALIZE_EVAL_GROUP(
    p_run_group VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_run_name VARCHAR;
    v_cursor CURSOR FOR 
        SELECT eval_run_id 
        FROM SPROCKET.PIPELINE.EVAL_RUN_REGISTRY 
        WHERE eval_run_group = :p_run_group 
          AND run_status = 'RUNNING';
BEGIN
    -- Update all completed runs in this group
    OPEN v_cursor;
    FOR record IN v_cursor DO
        v_run_name := record.eval_run_id;
        CALL SPROCKET.PIPELINE.UPDATE_EVAL_RESULTS(:v_run_name);
    END FOR;
    CLOSE v_cursor;
    
    RETURN OBJECT_CONSTRUCT(
        'status', 'finalized',
        'run_group', :p_run_group,
        'message', CONCAT('Eval group finalized. View GPA: SELECT * FROM SPROCKET.PIPELINE.AGENT_GPA_REPORT WHERE eval_run_group = ''', :p_run_group, '''')
    );
END;
$$;

COMMENT ON PROCEDURE SPROCKET.PIPELINE.FINALIZE_EVAL_GROUP IS
'Finalizes all evaluations in a run group by fetching results and calculating GPA. Call after all evals complete.';

-- ============================================
-- 7. Helper: List all eval runs
-- ============================================

CREATE OR REPLACE PROCEDURE SPROCKET.PIPELINE.LIST_EVAL_RUNS(
    p_run_group VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    eval_run_id VARCHAR,
    eval_run_group VARCHAR,
    eval_dataset_name VARCHAR,
    run_status VARCHAR,
    started_at TIMESTAMP_NTZ,
    completed_at TIMESTAMP_NTZ,
    total_records INT,
    avg_answer_correctness FLOAT,
    avg_logical_consistency FLOAT
)
LANGUAGE SQL
AS
$$
    SELECT 
        eval_run_id,
        eval_run_group,
        eval_dataset_name,
        run_status,
        started_at,
        completed_at,
        total_records,
        avg_answer_correctness,
        avg_logical_consistency
    FROM SPROCKET.PIPELINE.EVAL_RUN_REGISTRY
    WHERE (p_run_group IS NULL OR eval_run_group = p_run_group)
    ORDER BY started_at DESC
$$;

COMMENT ON PROCEDURE SPROCKET.PIPELINE.LIST_EVAL_RUNS IS
'Lists all evaluation runs, optionally filtered by run_group.';
