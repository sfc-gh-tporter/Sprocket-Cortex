# Sprocket Documentation

Sprocket is an AI bicycle maintenance assistant built entirely on Snowflake. It ingests
manufacturer service manuals, generates AI-powered image descriptions, and answers user
questions via a Cortex Agent that orchestrates over a Cortex Search service.

## Quick Links

| Doc | What's in it |
|---|---|
| [architecture.md](architecture.md) | Schemas, tables, agent, search service, embedding model |
| [ingestion-pipeline.md](ingestion-pipeline.md) | Human-in-the-loop ingestion procedures, state machine, flow diagrams |
| [runbook.md](runbook.md) | How to call each procedure, troubleshoot failures, common queries |

## The 30-second version

A user uploads a service manual. The Sprocket agent walks them through four confirmation
checkpoints (preview, classify, link, finalize), then kicks off async processing that
parses pages, extracts images, generates descriptions with a vision LLM, and inserts
everything into a Cortex Search-indexed table. Once processing completes, the same agent
can answer questions about the manual, scoped to the user's specific bike.

## Codebase layout

```
Sprocket/
|-- sql/                                   Deployable DDL, in numeric order
|   |-- 01_foundation.sql                  Database, schemas, warehouse, stages, file formats
|   |-- 02_data_model.sql                  All tables (RAW, CURATED, SEARCH, APP)
|   |-- 03_pipeline.sql                    Legacy one-off pipeline (superseded by ingestion procs)
|   |-- 05_cortex_search.sql               MANUAL_SEARCH service definition
|   |-- 06_seed_data.sql                   Initial bike + component + doc-link seed
|   `-- 07_session_context.sql             USER_BIKES view + GET_BIKE_CONTEXT proc
|-- SPROCKET_APP_SPROCKET_AGENT/           Agent workspace (spec snapshots, eval results)
|-- tests/                                 Local test harness (gitignored)
|-- SampleDocuments/                       Source PDFs (gitignored)
`-- docs/                                  You are here
```

## Current state (April 2026)

- **Documents processed:** 3 manuals
  - 2021 Specialized Stumpjumper EVO (33 pages)
  - 2024 RockShox Vivid shock (147 pages)
  - Hayes Dominion brake service manual + install guide (28 + 10 pages)
- **Bikes:** 1 (`stumpjumper-evo-2021`)
- **Component instances:** 3 (Frame, Vivid shock, Hayes Dominion brakes)
- **Search chunks:** ~387 (text + image descriptions combined)
- **Embedding model:** `snowflake-arctic-embed-l-v2.0-8k`

## Known limitations

- **PARSE_DOCUMENT requires text-based PDFs.** Scanned/image-only PDFs return empty
  content. Use `PIPELINE.SPLIT_PDF` to chunk files over 100MB (PARSE_DOCUMENT limit).
- **Chunking is page-level** (~200-460 tokens avg). 23 chunks exceed Snowflake's
  recommended 512-token max. `SPLIT_TEXT_RECURSIVE_CHARACTER` is available if we need
  finer-grained chunks later.
- **Image descriptions are AI-generated,** not source truth. pixtral-large writes
  technical descriptions of each extracted figure; these are searchable but not
  guaranteed accurate.
- **Session context is pulled at query time** from `BIKE_COMPONENT_INSTANCES`. The
  context-injection pattern is the app layer's responsibility (Streamlit/React), not
  the agent's.
