-- ============================================
-- Sprocket Agent GPA Calculation Views
-- ============================================
-- Purpose: Calculate Agent GPA across multiple evaluation datasets
-- DO NOT RUN WITHOUT EXPLICIT APPROVAL - This is a template

USE SCHEMA SPROCKET.PIPELINE;

-- ============================================
-- 1. Per-Eval GPA Summary
-- ============================================

CREATE OR REPLACE VIEW SPROCKET.PIPELINE.EVAL_RUN_SUMMARY AS
SELECT 
    eval_run_id,
    eval_run_group,
    eval_dataset_name,
    
    -- Extract eval type from dataset name
    CASE 
        WHEN eval_dataset_name LIKE '%CORTEX_SEARCH%' THEN 'cortex_search'
        WHEN eval_dataset_name LIKE '%MULTI_STEP%' THEN 'multi_step'
        WHEN eval_dataset_name LIKE '%INGESTION%' THEN 'ingestion'
        WHEN eval_dataset_name LIKE '%CONTEXT%' THEN 'context'
        ELSE 'unknown'
    END AS eval_type,
    
    run_status,
    started_at,
    completed_at,
    DATEDIFF('second', started_at, completed_at) AS duration_seconds,
    
    total_records,
    avg_answer_correctness,
    avg_logical_consistency,
    
    -- Per-Eval GPA: Average of built-in metrics
    -- (Custom metrics would be averaged from avg_custom_metrics VARIANT column)
    ROUND((avg_answer_correctness + avg_logical_consistency) / 2, 3) AS eval_gpa,
    
    notes
FROM SPROCKET.PIPELINE.EVAL_RUN_REGISTRY
WHERE run_status = 'COMPLETED';

COMMENT ON VIEW SPROCKET.PIPELINE.EVAL_RUN_SUMMARY IS
'Summary of each evaluation run with per-eval GPA calculated as average of built-in metrics.';

-- ============================================
-- 2. Agent GPA Report (Weighted Average)
-- ============================================

CREATE OR REPLACE VIEW SPROCKET.PIPELINE.AGENT_GPA_REPORT AS
WITH eval_weights AS (
    -- Define weights for each eval type (should sum to 1.0)
    SELECT 'cortex_search' AS eval_type, 0.30 AS weight
    UNION ALL
    SELECT 'multi_step', 0.30
    UNION ALL
    SELECT 'ingestion', 0.20
    UNION ALL
    SELECT 'context', 0.20
),
weighted_scores AS (
    SELECT 
        ers.eval_run_group,
        ers.eval_type,
        ers.eval_gpa,
        ew.weight,
        ers.eval_gpa * ew.weight AS weighted_gpa,
        ers.total_records,
        ers.completed_at
    FROM SPROCKET.PIPELINE.EVAL_RUN_SUMMARY ers
    LEFT JOIN eval_weights ew ON ers.eval_type = ew.eval_type
)
SELECT 
    eval_run_group,
    
    -- Individual eval GPAs
    MAX(CASE WHEN eval_type = 'cortex_search' THEN eval_gpa END) AS cortex_search_gpa,
    MAX(CASE WHEN eval_type = 'multi_step' THEN eval_gpa END) AS multi_step_gpa,
    MAX(CASE WHEN eval_type = 'ingestion' THEN eval_gpa END) AS ingestion_gpa,
    MAX(CASE WHEN eval_type = 'context' THEN eval_gpa END) AS context_gpa,
    
    -- Overall Agent GPA (weighted average)
    ROUND(SUM(weighted_gpa), 3) AS overall_agent_gpa,
    
    -- Metadata
    SUM(total_records) AS total_questions_evaluated,
    MAX(completed_at) AS last_eval_completed,
    
    -- Grade interpretation
    CASE 
        WHEN SUM(weighted_gpa) >= 0.90 THEN 'A+ (Excellent)'
        WHEN SUM(weighted_gpa) >= 0.85 THEN 'A  (Excellent)'
        WHEN SUM(weighted_gpa) >= 0.80 THEN 'B+ (Good)'
        WHEN SUM(weighted_gpa) >= 0.75 THEN 'B  (Good)'
        WHEN SUM(weighted_gpa) >= 0.70 THEN 'C+ (Acceptable)'
        WHEN SUM(weighted_gpa) >= 0.65 THEN 'C  (Needs Improvement)'
        ELSE 'F  (Failing)'
    END AS gpa_grade
    
FROM weighted_scores
GROUP BY eval_run_group
ORDER BY last_eval_completed DESC;

COMMENT ON VIEW SPROCKET.PIPELINE.AGENT_GPA_REPORT IS
'Overall Agent GPA calculated as weighted average across all eval types. Weights: cortex_search=0.3, multi_step=0.3, ingestion=0.2, context=0.2';

-- ============================================
-- 3. Agent GPA Comparison (Before vs After)
-- ============================================

CREATE OR REPLACE VIEW SPROCKET.PIPELINE.AGENT_GPA_COMPARISON AS
SELECT 
    b.eval_run_group AS baseline_group,
    c.eval_run_group AS comparison_group,
    
    -- Overall GPA change
    b.overall_agent_gpa AS baseline_gpa,
    c.overall_agent_gpa AS comparison_gpa,
    ROUND(c.overall_agent_gpa - b.overall_agent_gpa, 3) AS gpa_delta,
    ROUND(((c.overall_agent_gpa - b.overall_agent_gpa) / NULLIF(b.overall_agent_gpa, 0)) * 100, 1) AS gpa_change_pct,
    
    -- Per-eval changes
    ROUND(c.cortex_search_gpa - b.cortex_search_gpa, 3) AS cortex_search_delta,
    ROUND(c.multi_step_gpa - b.multi_step_gpa, 3) AS multi_step_delta,
    ROUND(c.ingestion_gpa - b.ingestion_gpa, 3) AS ingestion_delta,
    ROUND(c.context_gpa - b.context_gpa, 3) AS context_delta,
    
    -- Grade changes
    b.gpa_grade AS baseline_grade,
    c.gpa_grade AS comparison_grade,
    
    CASE 
        WHEN c.overall_agent_gpa > b.overall_agent_gpa THEN '📈 Improved'
        WHEN c.overall_agent_gpa < b.overall_agent_gpa THEN '📉 Regressed'
        ELSE '➡️ No Change'
    END AS trend
    
FROM SPROCKET.PIPELINE.AGENT_GPA_REPORT b
CROSS JOIN SPROCKET.PIPELINE.AGENT_GPA_REPORT c
WHERE b.eval_run_group < c.eval_run_group  -- Only compare earlier baselines to later versions
ORDER BY c.last_eval_completed DESC;

COMMENT ON VIEW SPROCKET.PIPELINE.AGENT_GPA_COMPARISON IS
'Compares Agent GPA between different run groups to track improvement over iterations.';

-- ============================================
-- 4. Metric Breakdown by Question Category
-- ============================================

CREATE OR REPLACE VIEW SPROCKET.PIPELINE.METRIC_BY_CATEGORY AS
WITH raw_eval_data AS (
    SELECT 
        err.eval_run_group,
        err.eval_dataset_name,
        
        -- Parse eval results (this is a placeholder - actual query depends on GET_AI_EVALUATION_DATA schema)
        'shock' AS category,  -- This would come from parsing actual eval data
        0.85 AS answer_correctness,
        0.90 AS logical_consistency
    FROM SPROCKET.PIPELINE.EVAL_RUN_REGISTRY err
    WHERE err.run_status = 'COMPLETED'
    -- TODO: JOIN with actual eval results from TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(...))
)
SELECT 
    eval_run_group,
    category,
    ROUND(AVG(answer_correctness), 3) AS avg_answer_correctness,
    ROUND(AVG(logical_consistency), 3) AS avg_logical_consistency,
    ROUND((AVG(answer_correctness) + AVG(logical_consistency)) / 2, 3) AS category_gpa,
    COUNT(*) AS question_count
FROM raw_eval_data
GROUP BY eval_run_group, category
ORDER BY eval_run_group, category;

COMMENT ON VIEW SPROCKET.PIPELINE.METRIC_BY_CATEGORY IS
'Breaks down metrics by question category (e.g., shock, brake, fork) to identify weak areas.';

-- ============================================
-- 5. Historical GPA Trend
-- ============================================

CREATE OR REPLACE VIEW SPROCKET.PIPELINE.GPA_TREND AS
SELECT 
    eval_run_group,
    overall_agent_gpa,
    cortex_search_gpa,
    multi_step_gpa,
    ingestion_gpa,
    context_gpa,
    gpa_grade,
    last_eval_completed,
    
    -- Cumulative improvement from first baseline
    overall_agent_gpa - FIRST_VALUE(overall_agent_gpa) 
        OVER (ORDER BY last_eval_completed ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) 
        AS cumulative_improvement,
    
    -- Sequential improvement (vs previous run)
    overall_agent_gpa - LAG(overall_agent_gpa) 
        OVER (ORDER BY last_eval_completed) 
        AS sequential_improvement,
    
    -- Days since last eval
    DATEDIFF('day', LAG(last_eval_completed) OVER (ORDER BY last_eval_completed), last_eval_completed) 
        AS days_since_last_eval
        
FROM SPROCKET.PIPELINE.AGENT_GPA_REPORT
ORDER BY last_eval_completed;

COMMENT ON VIEW SPROCKET.PIPELINE.GPA_TREND IS
'Historical trend of Agent GPA over time showing cumulative and sequential improvements.';

-- ============================================
-- 6. Failed Questions Report
-- ============================================
-- This would require joining with actual eval result data from GET_AI_EVALUATION_DATA
-- Placeholder view showing structure:

CREATE OR REPLACE VIEW SPROCKET.PIPELINE.FAILED_QUESTIONS AS
SELECT 
    'v1_baseline' AS eval_run_group,
    'cortex_search' AS eval_type,
    'cs_brake_01' AS question_id,
    'What torque spec should I use for Hayes Dominion rotor bolts?' AS question,
    0.45 AS answer_correctness,
    0.70 AS logical_consistency,
    'Agent provided generic torque spec instead of Hayes-specific 6.2 Nm value' AS failure_reason
WHERE 1=0;  -- Placeholder - no data

COMMENT ON VIEW SPROCKET.PIPELINE.FAILED_QUESTIONS IS
'Lists questions that scored below threshold (e.g., AC < 0.70) for debugging and improvement targeting. Requires integration with GET_AI_EVALUATION_DATA.';

-- ============================================
-- Example Queries
-- ============================================

-- View latest Agent GPA
-- SELECT * FROM SPROCKET.PIPELINE.AGENT_GPA_REPORT ORDER BY last_eval_completed DESC LIMIT 1;

-- Compare two specific versions
-- SELECT * FROM SPROCKET.PIPELINE.AGENT_GPA_COMPARISON 
-- WHERE baseline_group = 'v1_baseline' AND comparison_group = 'v2_improved_orchestration';

-- Track GPA over time
-- SELECT 
--     eval_run_group,
--     overall_agent_gpa,
--     cumulative_improvement,
--     gpa_grade
-- FROM SPROCKET.PIPELINE.GPA_TREND
-- ORDER BY last_eval_completed;

-- Find weakest eval area
-- SELECT 
--     eval_run_group,
--     LEAST(cortex_search_gpa, multi_step_gpa, ingestion_gpa, context_gpa) AS weakest_gpa,
--     CASE 
--         WHEN cortex_search_gpa = LEAST(cortex_search_gpa, multi_step_gpa, ingestion_gpa, context_gpa) THEN 'cortex_search'
--         WHEN multi_step_gpa = LEAST(cortex_search_gpa, multi_step_gpa, ingestion_gpa, context_gpa) THEN 'multi_step'
--         WHEN ingestion_gpa = LEAST(cortex_search_gpa, multi_step_gpa, ingestion_gpa, context_gpa) THEN 'ingestion'
--         ELSE 'context'
--     END AS weakest_area
-- FROM SPROCKET.PIPELINE.AGENT_GPA_REPORT
-- WHERE eval_run_group = 'v1_baseline';
