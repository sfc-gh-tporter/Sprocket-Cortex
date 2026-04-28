# Runbook

Common operational tasks for Sprocket. Assume `USE ROLE SYSADMIN; USE WAREHOUSE SPROCKET_WH;`.

## Adding a new document (manual SQL path)

Useful for dev/debug when you want to skip the agent. The full flow in order:

```sql
-- 1. PUT file to stage
PUT 'file:///path/to/manual.pdf' @SPROCKET.RAW.MANUALS_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 2. Register + parse preview
CALL SPROCKET.PIPELINE.INGEST_START('manual.pdf');
-- capture the document_id from the result

-- 3. Classify
CALL SPROCKET.PIPELINE.INGEST_CLASSIFY('<document_id>');
-- review classification and candidate_matches

-- 4. Link to catalog + bike
CALL SPROCKET.PIPELINE.INGEST_LINK(
    '<document_id>',
    '<catalog_id or NULL to create>',
    '<bike_id or NULL>',
    '<link_type>'
);

-- 5. Kick off async
CALL SPROCKET.PIPELINE.INGEST_FINALIZE('<document_id>');

-- 6. Poll until ready
CALL SPROCKET.PIPELINE.INGEST_STATUS('<document_id>');
```

## Checking ingestion state

### All in-flight documents

```sql
SELECT 
    document_id,
    source_file,
    status,
    progress_pct,
    status_updated_at,
    classification:make::VARCHAR AS make,
    classification:model::VARCHAR AS model
FROM SPROCKET.RAW.DOCUMENT_REGISTRY
WHERE status NOT IN ('READY', 'ABORTED', 'PROCESSED')
ORDER BY status_updated_at DESC;
```

### Queue contents

```sql
SELECT q.*, r.source_file, r.status
FROM SPROCKET.PIPELINE.INGEST_QUEUE q
JOIN SPROCKET.RAW.DOCUMENT_REGISTRY r ON q.document_id = r.document_id
ORDER BY q.enqueued_at;
```

### Worker task status

```sql
SHOW TASKS IN SCHEMA SPROCKET.PIPELINE;
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'INGEST_WORKER_TASK',
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;
```

## Querying the knowledge base

### Session context for a bike

```sql
CALL SPROCKET.APP.GET_BIKE_CONTEXT('stumpjumper-evo-2021');
SELECT $1 FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-1)));
```

### Direct Cortex Search query

```sql
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'SPROCKET.SEARCH.MANUAL_SEARCH',
    OBJECT_CONSTRUCT(
        'query', 'main pivot bolt torque',
        'filter', OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('chunk_type', 'text')),
        'columns', ARRAY_CONSTRUCT('content', 'source_file', 'page_number'),
        'limit', 5
    )::VARCHAR
));
```

### Multi-model filter

```sql
-- Only chunks relevant to a Lyrik Ultimate
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'SPROCKET.SEARCH.MANUAL_SEARCH',
    OBJECT_CONSTRUCT(
        'query', 'oil volume Lyrik Ultimate 2023',
        'filter', OBJECT_CONSTRUCT(
            '@and', ARRAY_CONSTRUCT(
                OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('chunk_type', 'text')),
                OBJECT_CONSTRUCT('@contains', OBJECT_CONSTRUCT('component_models', 'Lyrik Ultimate'))
            )
        ),
        'limit', 5
    )::VARCHAR
));
```

## Inspecting a bike's components

```sql
SELECT 
    c.component_category,
    c.component_type,
    c.make,
    c.model,
    i.is_stock,
    i.custom_notes,
    (SELECT COUNT(*) FROM SPROCKET.CURATED.COMPONENT_DOCUMENT_LINK l WHERE l.catalog_id = c.catalog_id) AS doc_count
FROM SPROCKET.CURATED.BIKE_COMPONENT_INSTANCES i
JOIN SPROCKET.CURATED.COMPONENT_CATALOG c ON i.catalog_id = c.catalog_id
WHERE i.bike_id = 'stumpjumper-evo-2021';
```

## All documents attached to a bike

```sql
SELECT DISTINCT
    d.source_file,
    l.link_type,
    c.make || ' ' || c.model AS component,
    d.status
FROM SPROCKET.CURATED.BIKE_COMPONENT_INSTANCES i
JOIN SPROCKET.CURATED.COMPONENT_CATALOG c ON i.catalog_id = c.catalog_id
JOIN SPROCKET.CURATED.COMPONENT_DOCUMENT_LINK l ON c.catalog_id = l.catalog_id
JOIN SPROCKET.RAW.DOCUMENT_REGISTRY d ON l.document_id = d.document_id
WHERE i.bike_id = 'stumpjumper-evo-2021';
```

## Troubleshooting

### Document stuck in INDEXING

1. Check queue: is the row still there with `picked_up_at IS NULL`?
   - If yes: worker task may be suspended. `ALTER TASK SPROCKET.PIPELINE.INGEST_WORKER_TASK RESUME;`
2. Check task history for errors: `SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(...))`
3. Check document error: `SELECT status, error_message FROM DOCUMENT_REGISTRY WHERE document_id = ...`

### Classification returned wrong component

1. Don't re-run classify — it'll re-hit the LLM. Instead pass correct values to `INGEST_LINK`:
   ```sql
   CALL SPROCKET.PIPELINE.INGEST_LINK(
       '<document_id>',
       '<correct_catalog_id>',  -- override with the right one
       '<bike_id>',
       '<correct_link_type>'
   );
   ```

### Retry a failed document

```sql
-- Reset status so the worker picks it up again
UPDATE SPROCKET.RAW.DOCUMENT_REGISTRY
SET status = 'LINKED', error_message = NULL
WHERE document_id = '<document_id>';

-- Re-enqueue
CALL SPROCKET.PIPELINE.INGEST_FINALIZE('<document_id>');
```

### Duplicate chunks after retry

INGEST_PROCESS_ASYNC has `NOT EXISTS` guards, so it shouldn't duplicate. If it does, clean up:

```sql
-- Keep oldest chunk per (document_id, page_number, chunk_type)
DELETE FROM SPROCKET.SEARCH.DOCUMENT_CHUNKS
WHERE chunk_id IN (
    SELECT chunk_id FROM (
        SELECT chunk_id,
               ROW_NUMBER() OVER (PARTITION BY document_id, page_number, chunk_type ORDER BY chunk_id) AS rn
        FROM SPROCKET.SEARCH.DOCUMENT_CHUNKS
        WHERE document_id = '<document_id>'
    )
    WHERE rn > 1
);
```

### Completely remove a document

```sql
-- Use INGEST_ABORT for partial cleanup
CALL SPROCKET.PIPELINE.INGEST_ABORT('<document_id>', 'manual removal');

-- Then delete the registry row itself
DELETE FROM SPROCKET.RAW.DOCUMENT_REGISTRY WHERE document_id = '<document_id>';
```

Note: `INGEST_ABORT` leaves the registry row with `status = 'ABORTED'` intentionally — that
history is useful. Only hard-delete when you want to re-ingest the same file clean.

### Search service not returning new content

Cortex Search has a target lag (currently 1 minute for dev). Check:

```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA SPROCKET.SEARCH;
-- source_data_num_rows tells you how many rows are indexed
-- compare to: SELECT COUNT(*) FROM SPROCKET.SEARCH.DOCUMENT_CHUNKS
```

If source count is higher than indexed count, just wait for the lag interval.

### Adjust search target lag

```sql
-- Fast refresh for dev
ALTER CORTEX SEARCH SERVICE SPROCKET.SEARCH.MANUAL_SEARCH SET TARGET_LAG = '1 minute';

-- Cheaper refresh for production
ALTER CORTEX SEARCH SERVICE SPROCKET.SEARCH.MANUAL_SEARCH SET TARGET_LAG = '1 hour';
```

## Agent spec

Current spec lives in Snowflake. To view or export:

```sql
DESCRIBE AGENT SPROCKET.APP.SPROCKET_AGENT;
SHOW AGENTS IN SCHEMA SPROCKET.APP;
```

Version snapshots are in `SPROCKET_APP_SPROCKET_AGENT/versions/`.

## Cost / resource notes

| Operation | Approximate cost profile |
|---|---|
| `INGEST_START` preview | Cheap: just parses 3 pages. ~2-5 seconds |
| `INGEST_CLASSIFY` | 1 claude-4-sonnet call, ~1000 tokens in + out |
| `INGEST_LINK` | Metadata only, trivial |
| `INGEST_FINALIZE` | Metadata only, trivial |
| `INGEST_PROCESS_ASYNC` | Dominated by pixtral-large calls (~1-3s per image). 200 pages / 50 images ~= 2-3 minutes |
| Cortex Search refresh | Triggered by source table writes, billed per refresh |
| Agent `search_manuals` | Each turn: 1 search API call + orchestration LLM tokens |

For production, watch:
- Task failures (worker task running on an empty queue every minute is negligible, but errors should alert)
- pixtral-large throughput (if many docs are ingested, serialize them)
- Cortex Search refresh cost at scale (target_lag tradeoff)
