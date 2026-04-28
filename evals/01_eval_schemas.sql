-- ============================================
-- Sprocket Agent Evaluation Table Schemas
-- ============================================
-- Purpose: Define evaluation dataset tables for measuring agent performance
-- DO NOT RUN WITHOUT EXPLICIT APPROVAL - This is a template

-- Create schema for eval datasets
CREATE SCHEMA IF NOT EXISTS SPROCKET.PIPELINE;
USE SCHEMA SPROCKET.PIPELINE;

-- ============================================
-- 1. EVAL_CORTEX_SEARCH_BASIC
-- ============================================
-- Tests: Basic retrieval and Q&A from manuals via Cortex Search
-- Complexity: Low (single tool call)
-- Target Metrics: AC: 0.85+, LC: 0.90+, Groundedness: 0.95+

CREATE OR REPLACE TABLE SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC (
    question_id VARCHAR PRIMARY KEY,
    category VARCHAR,                  -- Component category (e.g., 'shock', 'fork', 'brake')
    input_query VARCHAR NOT NULL,      -- Natural language question
    ground_truth_data VARIANT NOT NULL,-- Expected response and tool invocations (JSON)
    notes VARCHAR,                     -- Optional context for why this question matters
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC IS
'Evaluation dataset for testing basic Cortex Search retrieval. Single-tool questions that should yield direct answers from manual content.';

-- ============================================
-- 2. EVAL_MULTI_STEP_REASONING
-- ============================================
-- Tests: Complex questions requiring multiple tool calls and synthesis
-- Complexity: Medium (2-3 tool calls, cross-component reasoning)
-- Target Metrics: AC: 0.75+, LC: 0.75+, Execution Efficiency: 0.80+

CREATE OR REPLACE TABLE SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING (
    question_id VARCHAR PRIMARY KEY,
    category VARCHAR,                  -- Type of reasoning (e.g., 'troubleshooting', 'comparison', 'procedure')
    input_query VARCHAR NOT NULL,
    ground_truth_data VARIANT NOT NULL,
    expected_tool_sequence VARCHAR,    -- Human-readable expected flow (e.g., 'search -> search -> synthesize')
    notes VARCHAR,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING IS
'Evaluation dataset for testing multi-step reasoning and tool orchestration. Questions requiring multiple tool calls and information synthesis.';

-- ============================================
-- 3. EVAL_INGESTION_WORKFLOW
-- ============================================
-- Tests: Human-in-the-loop document ingestion orchestration
-- Complexity: High (multi-checkpoint state machine)
-- Target Metrics: AC: 0.70+, TSA: 0.85+, Safety Compliance: 0.90+

CREATE OR REPLACE TABLE SPROCKET.PIPELINE.EVAL_INGESTION_WORKFLOW (
    question_id VARCHAR PRIMARY KEY,
    scenario_type VARCHAR,             -- Type of ingestion (e.g., 'new_component', 'additional_doc', 'cancel')
    input_query VARCHAR NOT NULL,
    ground_truth_data VARIANT NOT NULL,
    expected_checkpoints ARRAY,        -- Expected checkpoint sequence (e.g., ['preview', 'classify', 'link', 'finalize'])
    notes VARCHAR,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE SPROCKET.PIPELINE.EVAL_INGESTION_WORKFLOW IS
'Evaluation dataset for testing document ingestion HITL workflow. Questions that exercise the 4-checkpoint state machine.';

-- ============================================
-- 4. EVAL_CONTEXT_INJECTION
-- ============================================
-- Tests: Bike-specific scoping via GET_BIKE_CONTEXT preamble
-- Complexity: Medium (correct filtering, component-aware answers)
-- Target Metrics: AC: 0.80+, Domain Accuracy: 0.85+

CREATE OR REPLACE TABLE SPROCKET.PIPELINE.EVAL_CONTEXT_INJECTION (
    question_id VARCHAR PRIMARY KEY,
    bike_id VARCHAR NOT NULL,          -- Which bike context to inject (e.g., 'stumpjumper-evo-2021')
    component_category VARCHAR,        -- Expected component category in answer
    input_query VARCHAR NOT NULL,
    ground_truth_data VARIANT NOT NULL,
    expected_component VARCHAR,        -- Specific component that should be mentioned (e.g., 'Vivid Air')
    notes VARCHAR,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE SPROCKET.PIPELINE.EVAL_CONTEXT_INJECTION IS
'Evaluation dataset for testing bike-specific context injection. Questions that should yield scoped answers based on user bike configuration.';

-- ============================================
-- Supporting Tables
-- ============================================

-- Track all evaluation runs across all datasets
CREATE OR REPLACE TABLE SPROCKET.PIPELINE.EVAL_RUN_REGISTRY (
    eval_run_id VARCHAR PRIMARY KEY,
    eval_run_group VARCHAR NOT NULL,   -- Logical grouping (e.g., 'v1_baseline', 'v2_improved_orchestration')
    eval_dataset_name VARCHAR NOT NULL,-- Which eval dataset was used
    eval_config_path VARCHAR NOT NULL, -- Path to YAML config on stage
    agent_name VARCHAR NOT NULL,       -- Which agent was evaluated
    agent_version VARCHAR,             -- Agent version or commit hash
    run_status VARCHAR,                -- RUNNING, COMPLETED, FAILED
    started_at TIMESTAMP_NTZ,
    completed_at TIMESTAMP_NTZ,
    total_records INT,
    avg_answer_correctness FLOAT,
    avg_logical_consistency FLOAT,
    avg_custom_metrics VARIANT,       -- JSON with custom metric averages
    notes VARCHAR,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE SPROCKET.PIPELINE.EVAL_RUN_REGISTRY IS
'Registry of all evaluation runs. Tracks which agent version was evaluated against which dataset with what config.';

-- Store ground truth schema examples for reference
CREATE OR REPLACE TABLE SPROCKET.PIPELINE.EVAL_GROUND_TRUTH_EXAMPLES (
    example_id VARCHAR PRIMARY KEY,
    example_name VARCHAR,
    eval_dataset VARCHAR,
    ground_truth_json VARIANT,
    description VARCHAR,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE SPROCKET.PIPELINE.EVAL_GROUND_TRUTH_EXAMPLES IS
'Reference examples showing proper ground_truth_data structure for each eval type. Used as templates when creating new eval questions.';

-- ============================================
-- Sample Ground Truth Structure Examples
-- ============================================

-- Example 1: Simple Cortex Search question
INSERT INTO SPROCKET.PIPELINE.EVAL_GROUND_TRUTH_EXAMPLES
VALUES (
    'cortex_search_simple',
    'Simple Cortex Search Question',
    'EVAL_CORTEX_SEARCH_BASIC',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {
                "tool_name": "search_manuals",
                "tool_sequence": 1,
                "parameters": {"query": "air pressure RockShox Vivid"}
            }
        ],
        "ground_truth_output": "The recommended air pressure for the RockShox Vivid Air is 150-250 psi depending on rider weight. Start at 200 psi and adjust based on sag."
    }'),
    'Single tool call to search_manuals with expected answer from manual content',
    CURRENT_TIMESTAMP()
);

-- Example 2: Multi-step reasoning
INSERT INTO SPROCKET.PIPELINE.EVAL_GROUND_TRUTH_EXAMPLES
VALUES (
    'multi_step_comparison',
    'Multi-Step Comparison Question',
    'EVAL_MULTI_STEP_REASONING',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {
                "tool_name": "search_manuals",
                "tool_sequence": 1,
                "parameters": {"query": "Hayes brake bleed procedure"}
            },
            {
                "tool_name": "search_manuals",
                "tool_sequence": 2,
                "parameters": {"query": "Shimano brake bleed procedure"}
            }
        ],
        "ground_truth_output": "Both Hayes and Shimano brakes use a gravity bleed method, but Hayes requires a syringe on both caliper and lever while Shimano uses a funnel at the lever. Hayes uses DOT fluid, Shimano uses mineral oil."
    }'),
    'Two sequential search calls followed by synthesis comparing procedures',
    CURRENT_TIMESTAMP()
);

-- Example 3: Ingestion workflow
INSERT INTO SPROCKET.PIPELINE.EVAL_GROUND_TRUTH_EXAMPLES
VALUES (
    'ingestion_new_doc',
    'New Document Ingestion',
    'EVAL_INGESTION_WORKFLOW',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {
                "tool_name": "ingest_start_preview",
                "tool_sequence": 1,
                "parameters": {"file_name": "fox_dhx2_service_manual.pdf"}
            },
            {
                "tool_name": "ingest_classify",
                "tool_sequence": 2,
                "parameters": {"document_id": "<generated>"}
            },
            {
                "tool_name": "ingest_link_document",
                "tool_sequence": 3,
                "parameters": {"document_id": "<generated>", "catalog_id": null, "bike_id": null, "link_type": "service_manual"}
            },
            {
                "tool_name": "ingest_finalize",
                "tool_sequence": 4,
                "parameters": {"document_id": "<generated>"}
            }
        ],
        "ground_truth_output": "I have processed the Fox DHX2 service manual through all checkpoints: preview confirmed, classified as a rear shock service manual, linked to the Fox DHX2 component catalog, and finalized for async processing. Processing will complete in approximately 3-5 minutes."
    }'),
    'Full 4-checkpoint ingestion workflow with user confirmations at each step',
    CURRENT_TIMESTAMP()
);

-- Example 4: Context injection
INSERT INTO SPROCKET.PIPELINE.EVAL_GROUND_TRUTH_EXAMPLES
VALUES (
    'context_bike_specific',
    'Bike-Specific Context Question',
    'EVAL_CONTEXT_INJECTION',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {
                "tool_name": "search_manuals",
                "tool_sequence": 1,
                "parameters": {"query": "RockShox Vivid Air rebound adjustment"}
            }
        ],
        "ground_truth_output": "To adjust rebound on your RockShox Vivid Air rear shock, turn the red rebound knob at the bottom of the shock. Clockwise slows rebound (compression returns slower), counterclockwise speeds it up. Start at 10 clicks from full slow and adjust based on terrain."
    }'),
    'Question answered in context of user bike (Stumpjumper with Vivid Air shock) - should mention specific component',
    CURRENT_TIMESTAMP()
);
