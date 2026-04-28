# Sprocket Agent Evaluation Framework - Quick Start Guide

## 🎯 Goal

Establish a systematic evaluation pipeline to measure and improve Sprocket agent performance across multiple dimensions, ultimately calculating an **Agent GPA** that tracks quality over time.

---

## 📋 Prerequisites

- Sprocket agent deployed (`SPROCKET.APP.SPROCKET_AGENT`)
- Stage for YAML configs: `SPROCKET.PIPELINE.EVAL_CONFIG_STAGE`
- Cross-region inference enabled (required for claude-4-sonnet LLM judge)
- Manual documents indexed and searchable via Cortex Search

---

## 🚀 Quick Start (5 Steps)

### Step 1: Create Eval Schemas and Load Sample Data

```sql
-- Create tables
@evals/01_eval_schemas.sql

-- Load sample questions (start with these two datasets)
@evals/02_eval_data_cortex_search.sql   -- 14 questions
@evals/03_eval_data_multi_step.sql      -- 10 questions
```

### Step 2: Upload YAML Configs to Stage

```bash
# From your local machine
cd /path/to/Sprocket/evals/config

# Upload YAML configs
snow stage copy cortex_search_eval_config.yaml @SPROCKET.PIPELINE.EVAL_CONFIG_STAGE/ --connection tporterawsdev
snow stage copy multi_step_eval_config.yaml @SPROCKET.PIPELINE.EVAL_CONFIG_STAGE/ --connection tporterawsdev

# Verify upload
snow stage list @SPROCKET.PIPELINE.EVAL_CONFIG_STAGE/ --connection tporterawsdev
```

### Step 3: Convert Tables to Datasets

```sql
-- Create stored procedures and views
@evals/06_eval_procedures.sql
@evals/07_eval_views.sql

-- Convert eval tables to Snowflake datasets
CALL SPROCKET.PIPELINE.CREATE_EVAL_DATASETS();

-- Verify datasets created
SHOW DATASETS IN SCHEMA SPROCKET.PIPELINE;
```

### Step 4: Run Your First Evaluation

```sql
-- Option A: Run all evals at once
CALL SPROCKET.PIPELINE.RUN_ALL_EVALS('v1_baseline');

-- Option B: Run individual eval
CALL SPROCKET.PIPELINE.RUN_SINGLE_EVAL(
    'cortex_search',
    'v1_baseline',
    '@SPROCKET.PIPELINE.EVAL_CONFIG_STAGE/cortex_search_eval_config.yaml'
);

-- Check status (wait 3-5 minutes for completion)
CALL SPROCKET.PIPELINE.CHECK_EVAL_STATUS('<run_name_from_output>');
```

### Step 5: View Your Agent GPA

```sql
-- After evals complete, finalize results
CALL SPROCKET.PIPELINE.FINALIZE_EVAL_GROUP('v1_baseline');

-- View Agent GPA report
SELECT * FROM SPROCKET.PIPELINE.AGENT_GPA_REPORT
WHERE eval_run_group = 'v1_baseline';

-- Expected output:
-- eval_run_group | cortex_search_gpa | multi_step_gpa | overall_agent_gpa | gpa_grade
-- v1_baseline    | 0.850             | 0.780          | 0.815             | B+ (Good)
```

---

## 📊 Understanding Your Results

### Agent GPA Scale

| GPA Range | Grade | Interpretation |
|-----------|-------|----------------|
| 0.90+     | A+/A  | Excellent - Production ready |
| 0.80-0.89 | B+/B  | Good - Minor improvements needed |
| 0.70-0.79 | C+/C  | Acceptable - Significant improvements needed |
| < 0.70    | F     | Failing - Major issues, not ready |

### Built-in Metrics

- **Answer Correctness (AC)**: How closely agent response matches expected answer (0-1)
- **Logical Consistency (LC)**: Execution efficiency without redundancy (0-1)
- **Tool Selection Accuracy (TSA)**: Whether agent chose correct tools at correct stages (0-1, private preview)
- **Tool Execution Accuracy (TEA)**: How closely tool invocations match expected (0-1, private preview)

### Custom Metrics (Defined in YAML)

- **Groundedness**: Is response supported by tool outputs? (no fabrication)
- **Domain Accuracy**: Are technical specs, procedures, and safety warnings correct?
- **Execution Efficiency**: Optimal tool usage without redundancy?
- **Synthesis Quality**: For multi-step questions, how well did agent combine info?
- **Completeness**: Did agent address all parts of complex questions?

---

## 🔍 Debugging Low Scores

### In Snowsight UI

1. Navigate to: **AI & ML → Agents → SPROCKET_AGENT → Evaluations**
2. Click on your evaluation run (e.g., "v1_baseline_cortex_search_...")
3. Sort by Answer Correctness (ascending) to see worst performers
4. Click a low-scoring question to see:
   - **Left pane**: Metric scores with detailed explanations
   - **Middle pane**: Agent trace (tool calls, reasoning, outputs)
   - **Right pane**: Span details (messages, token counts, timing)

### Via SQL

```sql
-- Get all questions with AC < 0.70
SELECT 
    record:input_query AS question,
    record:metrics:correctness:score AS answer_correctness,
    record:metrics:logical_consistency:score AS logical_consistency
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
    'SPROCKET', 'APP', 'SPROCKET_AGENT', 'cortex agent', '<run_name>'
))
WHERE record:metrics:correctness:score < 0.70
ORDER BY record:metrics:correctness:score;

-- Get trace for specific failing question
SELECT * FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_RECORD_TRACE(
    'SPROCKET', 'APP', 'SPROCKET_AGENT', 'cortex agent', '<record_id>'
));
```

---

## 🔄 Iterative Improvement Workflow

### 1. Baseline Evaluation

```sql
CALL SPROCKET.PIPELINE.RUN_ALL_EVALS('v1_baseline');
-- Wait for completion, then:
CALL SPROCKET.PIPELINE.FINALIZE_EVAL_GROUP('v1_baseline');
```

**Result**: Overall GPA = 0.72 (C+ grade)

### 2. Identify Weaknesses

```sql
-- Find weakest eval area
SELECT * FROM SPROCKET.PIPELINE.AGENT_GPA_REPORT WHERE eval_run_group = 'v1_baseline';
```

**Finding**: Multi-step reasoning GPA = 0.68 (below target)

### 3. Drill into Failures

Navigate to Snowsight → Evaluations → multi_step run → Sort by AC

**Root Cause Analysis**:
- Agent making redundant search calls
- Not synthesizing information well across multiple tools
- Missing key details in comparison questions

### 4. Make Targeted Changes

```sql
ALTER AGENT SPROCKET.APP.SPROCKET_AGENT
MODIFY LIVE VERSION SET SPECIFICATION = $$
{
  ...
  "instructions": {
    "orchestration": "Enhanced multi-step orchestration rules:
    1. Plan all tool calls before executing
    2. Avoid redundant searches - check if info already retrieved
    3. For comparisons, explicitly state similarities AND differences
    4. For troubleshooting, connect symptoms → diagnosis → solution causally"
  }
  ...
}
$$;
```

### 5. Re-evaluate

```sql
CALL SPROCKET.PIPELINE.RUN_ALL_EVALS('v2_improved_orchestration');
-- Wait, then:
CALL SPROCKET.PIPELINE.FINALIZE_EVAL_GROUP('v2_improved_orchestration');
```

### 6. Compare Results

```sql
SELECT * FROM SPROCKET.PIPELINE.AGENT_GPA_COMPARISON
WHERE baseline_group = 'v1_baseline' AND comparison_group = 'v2_improved_orchestration';
```

**Result**:
- Multi-step GPA: 0.68 → 0.78 (+0.10 improvement ✅)
- Overall GPA: 0.72 → 0.81 (+0.09 improvement ✅)
- Grade: C+ → B+

### 7. Repeat

Continue iterating: v3, v4, v5... until target GPA achieved.

---

## 📈 Tracking Progress Over Time

```sql
-- View historical trend
SELECT 
    eval_run_group,
    overall_agent_gpa,
    cumulative_improvement,
    gpa_grade,
    last_eval_completed
FROM SPROCKET.PIPELINE.GPA_TREND
ORDER BY last_eval_completed;

-- Output:
-- v1_baseline                    | 0.720 | 0.000  | C+         | 2025-04-15
-- v2_improved_orchestration      | 0.810 | +0.090 | B+         | 2025-04-18
-- v3_enhanced_tool_descriptions  | 0.835 | +0.115 | A          | 2025-04-22
-- v4_added_safety_instructions   | 0.880 | +0.160 | A          | 2025-04-25
```

---

## 🎓 Custom Metric Design Best Practices

### Good Custom Metric Prompt Structure

```yaml
- name: my_custom_metric
  score_ranges:
    min_score: [0, 0.50]     # Clear failure criteria
    median_score: [0.51, 0.79] # Partial success
    max_score: [0.80, 1.0]    # Excellence criteria
  prompt: |
    [ROLE] You are evaluating X aspect of an agent's response.
    
    [CONTEXT]
    User Query: {{input}}
    Agent Response: {{output}}
    Expected Answer: {{ground_truth}}
    
    [CRITERIA]
    1. Specific criterion with examples
    2. Another specific criterion
    3. Edge cases to watch for
    
    [RUBRIC]
    - 1.0: Specific description of perfect score
    - 0.65-0.79: Specific description of good score
    - 0.0-0.64: Specific description of poor score
    
    [CRITICAL FAILURES]
    - Specific failure mode that auto-scores 0.0
    
    Return a score between 0.0 and 1.0 as a JSON object: {"score": <value>}
```

### Template Variables Available

- `{{input}}` - User question
- `{{output}}` - Agent response
- `{{ground_truth}}` - Expected answer
- `{{tool_info}}` - Tools used (for execution metrics)
- `{{duration}}` - Execution time (for performance metrics)
- Full trace always provided to judge as context

---

## 🔧 Common Issues

### Issue: Eval stuck in RUNNING status

**Cause**: LLM judge may be overloaded or question set too large

**Fix**:
```sql
-- Check status
CALL SPROCKET.PIPELINE.CHECK_EVAL_STATUS('<run_name>');

-- If truly stuck (> 30 min), re-run with smaller question set
```

### Issue: Low groundedness scores across the board

**Cause**: Agent fabricating information or not using Cortex Search effectively

**Fix**:
1. Check Cortex Search service is returning relevant chunks
2. Add orchestration instruction: "NEVER fabricate information. Only use data from tool outputs."
3. Check if search queries are well-formed in agent trace

### Issue: GPA comparison shows unexpected regression

**Cause**: Changes improved one eval but hurt another (unintended side effects)

**Fix**:
```sql
-- Drill into which eval regressed
SELECT 
    baseline_group,
    comparison_group,
    cortex_search_delta,
    multi_step_delta,
    ingestion_delta,
    context_delta
FROM SPROCKET.PIPELINE.AGENT_GPA_COMPARISON;

-- Focus improvement on regressed area without losing gains
```

---

## 📚 Additional Eval Datasets (TODO)

### EVAL_INGESTION_WORKFLOW

**Purpose**: Test HITL document ingestion orchestration

**Questions needed**:
- "I have a new manual for a Fox DHX2 shock. Walk me through adding it."
- "Can you help me upload the bleed guide for SRAM Code RSC brakes?"
- "I uploaded the wrong manual. Can you cancel the ingestion?"

**YAML config**: `evals/config/ingestion_eval_config.yaml` (needs creation)

### EVAL_CONTEXT_INJECTION

**Purpose**: Test bike-specific scoping via GET_BIKE_CONTEXT

**Questions needed**:
- "How do I service my rear shock?" (should answer for user's Vivid Air)
- "What's the travel on my fork?" (should reference user's specific fork)
- "Show me the bleed procedure for my brakes." (Hayes-specific)

**YAML config**: `evals/config/context_eval_config.yaml` (needs creation)

---

## 🎯 Recommended Targets

### Phase 1: MVP Launch
- Overall GPA: **0.70+** (Acceptable)
- Cortex Search Basic: **0.80+** (core functionality)
- Multi-Step Reasoning: **0.65+** (acceptable for complex questions)

### Phase 2: Production Hardening
- Overall GPA: **0.80+** (Good)
- All individual evals: **0.75+**
- No critical failures (safety warnings, wrong specs)

### Phase 3: Excellence
- Overall GPA: **0.85+** (Excellent)
- Custom metrics (groundedness, domain accuracy): **0.90+**
- Ready for public launch

---

## 📞 Next Steps

1. **Run baseline evaluation** on current Sprocket agent
2. **Review results** in Snowsight to understand strengths/weaknesses
3. **Prioritize improvements** based on lowest-scoring eval areas
4. **Iterate** with targeted agent spec changes
5. **Track progress** via GPA_TREND view
6. **Celebrate** when you hit 0.85+ overall GPA! 🎉

**Questions?** Refer to:
- [Cortex Agent Evaluations Blog](https://www.snowflake.com/en/engineering-blog/cortex-agent-evaluations/)
- [Getting Started Quickstart](https://www.snowflake.com/en/developers/guides/getting-started-with-cortex-agent-evaluations/)
- [GPA Framework Paper](https://www.snowflake.com/en/engineering-blog/ai-agent-evaluation-gpa-framework/)
