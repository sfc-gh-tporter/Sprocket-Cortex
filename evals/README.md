# Sprocket Agent Evaluation Framework

## Overview

This directory contains a templated evaluation framework for measuring Sprocket agent performance across multiple complexity levels. The goal is to calculate an **Agent GPA** that tracks quality over time.

**DO NOT RUN ANYTHING IN THIS DIRECTORY WITHOUT EXPLICIT APPROVAL** - This is a template only.

## Framework Design

### Evaluation Philosophy

**Multiple Eval Datasets**: Different tables for different complexity levels
- `EVAL_CORTEX_SEARCH_BASIC`: Tests basic Q&A using Cortex Search across all manuals
- `EVAL_MULTI_STEP_REASONING`: Tests complex questions requiring multiple tool calls
- `EVAL_INGESTION_WORKFLOW`: Tests human-in-the-loop document ingestion process
- `EVAL_CONTEXT_INJECTION`: Tests bike-specific scoping and context awareness

**Built-in Metrics** (automatically scored by GPA framework):
- Answer Correctness (AC): How closely the response matches expected answer
- Logical Consistency (LC): Redundancies, superfluous tool calls, inefficiencies
- Tool Selection Accuracy (TSA) (private preview): Whether agent selects correct tools at correct stages
- Tool Execution Accuracy (TEA) (private preview): How closely tool invocations match expected

**Custom Metrics** (LLM-as-judge via YAML):
- Groundedness: Is response supported by tool outputs/retrieved data?
- Execution Efficiency: Optimal tool usage without redundancy?
- Domain Accuracy: Bike maintenance-specific correctness (e.g., torque specs, procedures)
- Safety Compliance: Does response include necessary safety warnings?

### GPA Calculation

**Per-Eval GPA**: Average of all metric scores (0-1 scale) across all questions in that eval dataset

**Overall Agent GPA**: Weighted average across all eval datasets
```
Overall GPA = (w1 * Eval1_GPA) + (w2 * Eval2_GPA) + (w3 * Eval3_GPA) + ...
where weights sum to 1.0
```

**Weight recommendations**:
- Cortex Search Basic: 0.3 (foundational capability)
- Multi-step Reasoning: 0.3 (core use case)
- Ingestion Workflow: 0.2 (operational capability)
- Context Injection: 0.2 (user experience quality)

## Directory Structure

```
evals/
├── README.md                           # This file
├── 01_eval_schemas.sql                 # CREATE TABLE statements for eval datasets
├── 02_eval_data_cortex_search.sql      # Sample eval questions for basic Cortex Search
├── 03_eval_data_multi_step.sql         # Sample eval questions for complex reasoning
├── 04_eval_data_ingestion.sql          # Sample eval questions for ingestion workflow
├── 05_eval_data_context.sql            # Sample eval questions for context injection
├── config/
│   ├── cortex_search_eval_config.yaml  # Metrics config for basic eval
│   ├── multi_step_eval_config.yaml     # Metrics config for reasoning eval
│   ├── ingestion_eval_config.yaml      # Metrics config for ingestion eval
│   └── context_eval_config.yaml        # Metrics config for context eval
├── 06_eval_procedures.sql              # Stored procedures for running evals
└── 07_eval_views.sql                   # Views for Agent GPA calculation
```

## Evaluation Datasets

### 1. EVAL_CORTEX_SEARCH_BASIC

**Purpose**: Verify agent can correctly retrieve and answer questions from manual content using Cortex Search

**Complexity**: Low (single tool call, straightforward retrieval)

**Example Questions**:
- "What is the recommended air pressure for the RockShox Vivid Air shock?"
- "How do I adjust rebound damping on my Fox 38 fork?"
- "What torque spec should I use for rotor bolts on Hayes Dominion brakes?"

**Expected Metrics**:
- AC: 0.85+ (should match manual content exactly)
- LC: 0.90+ (single tool call, minimal overhead)
- Groundedness: 0.95+ (all info from retrieved chunks)

### 2. EVAL_MULTI_STEP_REASONING

**Purpose**: Test agent's ability to orchestrate multiple tools and synthesize information

**Complexity**: Medium (2-3 tool calls, cross-component reasoning)

**Example Questions**:
- "My rear shock is bottoming out. Walk me through diagnosis and fixes."
- "Compare the bleed procedures for Shimano and Hayes brakes."
- "What are all the adjustments available on my RockShox fork?"

**Expected Metrics**:
- AC: 0.75+ (synthesis required)
- LC: 0.75+ (multi-step but efficient)
- Execution Efficiency: 0.80+ (no redundant calls)

### 3. EVAL_INGESTION_WORKFLOW

**Purpose**: Test human-in-the-loop document ingestion orchestration

**Complexity**: High (multi-checkpoint state machine)

**Example Questions**:
- "I have a new manual for a Fox DHX2 shock. Walk me through adding it."
- "Can you help me upload the bleed guide for SRAM Code RSC brakes?"
- "I uploaded the wrong manual. Can you cancel the ingestion?"

**Expected Metrics**:
- AC: 0.70+ (conversational flow correctness)
- Tool Selection Accuracy: 0.85+ (correct checkpoint order)
- Safety Compliance: 0.90+ (confirms before finalizing)

### 4. EVAL_CONTEXT_INJECTION

**Purpose**: Test bike-specific scoping via GET_BIKE_CONTEXT preamble

**Complexity**: Medium (correct filtering, component-aware answers)

**Example Questions**:
- "How do I service my rear shock?" (should answer for Vivid Air specifically)
- "What's the travel on my fork?" (should reference bike's actual fork)
- "Show me the bleed procedure for my brakes." (Hayes-specific answer)

**Expected Metrics**:
- AC: 0.80+ (bike-specific correctness)
- Domain Accuracy: 0.85+ (component specs match bike)

## Workflow

### 1. Create Eval Datasets

```sql
-- Run schema creation
@evals/01_eval_schemas.sql

-- Populate with sample questions
@evals/02_eval_data_cortex_search.sql
@evals/03_eval_data_multi_step.sql
@evals/04_eval_data_ingestion.sql
@evals/05_eval_data_context.sql
```

### 2. Upload YAML Configs to Stage

```sql
CREATE OR REPLACE STAGE SPROCKET.PIPELINE.EVAL_CONFIG_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Evaluation metric configurations';

-- Upload YAML files from config/ directory
PUT file:///path/to/evals/config/*.yaml @SPROCKET.PIPELINE.EVAL_CONFIG_STAGE/;
```

### 3. Convert Tables to Datasets

```sql
CALL SYSTEM$CREATE_EVALUATION_DATASET(
    'Cortex Agent',
    'SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC',
    'SPROCKET.PIPELINE.DATASET_CORTEX_SEARCH_BASIC',
    OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH_DATA')
);

-- Repeat for other eval tables
```

### 4. Run Evaluations

```sql
-- Option A: Via stored procedure (runs all evals in sequence)
CALL SPROCKET.PIPELINE.RUN_ALL_EVALS('v1_baseline');

-- Option B: Run individual evals
CALL EXECUTE_AI_EVALUATION(
    'START',
    OBJECT_CONSTRUCT('run_name', 'cortex_search_v1'),
    '@SPROCKET.PIPELINE.EVAL_CONFIG_STAGE/cortex_search_eval_config.yaml'
);
```

### 5. Calculate Agent GPA

```sql
-- View per-eval GPAs
SELECT * FROM SPROCKET.PIPELINE.EVAL_RUN_SUMMARY
WHERE eval_run_group = 'v1_baseline';

-- View overall Agent GPA
SELECT * FROM SPROCKET.PIPELINE.AGENT_GPA_REPORT
WHERE eval_run_group = 'v1_baseline';
```

### 6. Compare Over Time

```sql
-- Compare two agent versions
SELECT * FROM SPROCKET.PIPELINE.AGENT_GPA_COMPARISON
WHERE baseline_group = 'v1_baseline'
  AND comparison_group = 'v2_improved_orchestration';
```

## Iterating on Agent Performance

### Improvement Cycle

1. **Baseline**: Run all evals on current agent → get baseline GPA
2. **Identify weaknesses**: Drill into low-scoring questions in Snowsight
3. **Hypothesis**: What change would improve that failure mode?
   - Add orchestration instructions?
   - Update tool descriptions?
   - Improve Cortex Search configuration?
   - Refine context injection preamble?
4. **Change agent**: ALTER AGENT with updated spec
5. **Re-evaluate**: Run all evals again → get new GPA
6. **Compare**: Did GPA improve? Did any evals regress?
7. **Repeat**: Iterate until target GPA is achieved

### Tracking Progress

**Recommended Naming Convention for Eval Runs**:
```
v{N}_{change_description}

Examples:
- v1_baseline
- v2_improved_orchestration
- v3_refined_tool_descriptions
- v4_added_safety_warnings
```

**Target GPAs** (adjust based on your requirements):
- Minimum production readiness: 0.70 overall
- Good performance: 0.80 overall
- Excellent performance: 0.85+ overall

## Custom Metrics Design

### Example: Domain Accuracy (Bike-Specific)

```yaml
metrics:
  - name: domain_accuracy
    score_ranges:
      min_score: [0, 0.50]      # Wrong specs or procedures
      median_score: [0.51, 0.79] # Correct but generic
      max_score: [0.80, 1.0]     # Correct and component-specific
    prompt: |
      You are evaluating the domain accuracy of a bicycle maintenance assistant's response.
      
      User Query: {{input}}
      Agent Response: {{output}}
      Expected Answer: {{ground_truth}}
      
      Evaluate the response on these criteria:
      1. Component Identification: Does the response correctly identify the specific component (make/model)?
      2. Technical Specs: Are torque values, pressures, and measurements accurate?
      3. Procedure Correctness: Does the procedure match the manufacturer's documented steps?
      4. Tool Requirements: Are the required tools correctly specified?
      
      Score 1.0: All specs and procedures are component-specific and accurate
      Score 0.5-0.79: Correct general guidance but missing specific details
      Score 0.0-0.49: Contains incorrect specs, wrong procedures, or dangerous advice
      
      Return a score between 0.0 and 1.0.
```

### Example: Safety Compliance

```yaml
metrics:
  - name: safety_compliance
    score_ranges:
      min_score: [0, 0.60]      # Missing critical safety info
      median_score: [0.61, 0.85] # Some safety warnings present
      max_score: [0.86, 1.0]     # Comprehensive safety guidance
    prompt: |
      You are evaluating whether the response includes necessary safety warnings and precautions.
      
      User Query: {{input}}
      Agent Response: {{output}}
      Context: Bicycle maintenance involves risks like component failure, injury, and equipment damage.
      
      Evaluate the response on these criteria:
      1. Hazard Identification: Does it mention risks (e.g., sudden brake failure, spring tension)?
      2. PPE Requirements: Does it recommend safety glasses, gloves when appropriate?
      3. Torque Specifications: Does it emphasize proper torque to prevent failure?
      4. Testing Requirements: Does it recommend testing in controlled environment before riding?
      5. Skill Level: Does it warn if procedure requires professional service?
      
      Score 1.0: Comprehensive safety guidance appropriate to the procedure
      Score 0.6-0.85: Some safety warnings but missing key precautions
      Score 0.0-0.59: Inadequate or no safety information
      
      Return a score between 0.0 and 1.0.
```

## Integration with CI/CD

**Recommended**: Schedule automated eval runs on agent changes

```sql
CREATE OR REPLACE TASK SPROCKET.PIPELINE.WEEKLY_EVAL_TASK
    WAREHOUSE = SPROCKET_WH
    SCHEDULE = 'USING CRON 0 2 * * 1 America/Los_Angeles'  -- Monday 2am
AS
    CALL SPROCKET.PIPELINE.RUN_ALL_EVALS(
        CONCAT('auto_', TO_VARCHAR(CURRENT_DATE(), 'YYYY_MM_DD'))
    );

ALTER TASK SPROCKET.PIPELINE.WEEKLY_EVAL_TASK RESUME;
```

## Troubleshooting

### Low Answer Correctness Score

**Possible causes**:
- Cortex Search not returning relevant chunks
- Agent not using search_manuals tool
- Orchestration instructions causing wrong tool selection

**Debug steps**:
1. Check Snowsight eval details → drill into low AC questions
2. Review trace → did agent call search_manuals?
3. Check tool outputs → was relevant chunk returned?
4. Review chunk content → is answer actually in the manual?

### Low Logical Consistency Score

**Possible causes**:
- Agent making redundant tool calls
- Unnecessary back-and-forth in reasoning
- Tool selection inefficiency

**Debug steps**:
1. Review trace for redundant calls
2. Check orchestration instructions for ambiguous guidance
3. Look for tool description conflicts

### Low Tool Selection Accuracy

**Possible causes**:
- Orchestration instructions not clear on when to use which tool
- Tool descriptions don't distinguish use cases well
- Ground truth expectations are wrong

**Debug steps**:
1. Review eval dataset → is ground_truth_invocations correct?
2. Check tool descriptions for clarity
3. Update orchestration instructions with explicit tool selection rules

## References

- [Cortex Agent Evaluations Blog Post](https://www.snowflake.com/en/engineering-blog/cortex-agent-evaluations/)
- [Getting Started Quickstart](https://www.snowflake.com/en/developers/guides/getting-started-with-cortex-agent-evaluations/)
- [GPA Framework Paper](https://www.snowflake.com/en/engineering-blog/ai-agent-evaluation-gpa-framework/)
- [Cortex Agent Evaluations Docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations)
