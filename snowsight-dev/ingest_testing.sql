use role sysadmin;
use database sprocket;

show schemas;

select *
from information_schema.procedures
where procedure_schema = 'PIPELINE';
order by created_on;

ls @sprocket.raw.manuals_stage;

--STEP 1: pipeline.ingest_start
call sprocket.pipeline.ingest_start('605-50-008_Rev_B_Race_Face_Stem_Owner_s_Guide.pdf');

---Review: raw.document_registry
select *
from raw.document_registry
where document_id = 'bfcf2fc8-8839-4ec8-be2c-0b2bcc50d338';

select *
from raw.document_pages
where document_id = 'bfcf2fc8-8839-4ec8-be2c-0b2bcc50d338';

select *
from raw.document_images
where document_id = 'bfcf2fc8-8839-4ec8-be2c-0b2bcc50d338';

--STEP 2:
call pipeline.ingest_classify('bfcf2fc8-8839-4ec8-be2c-0b2bcc50d338');

--STEP 3:
call pipeline.ingest_link('bfcf2fc8-8839-4ec8-be2c-0b2bcc50d338', NULL, NULL, NULL);

Select *
from curated.component_document_link
where document_id = 'bfcf2fc8-8839-4ec8-be2c-0b2bcc50d338';

select *
from curated.bike_component_instances;
where document_id = 'bfcf2fc8-8839-4ec8-be2c-0b2bcc50d338';

--Step 4:
CALL SPROCKET.PIPELINE.INGEST_FINALIZE('bfcf2fc8-8839-4ec8-be2c-0b2bcc50d338');

CALL SPROCKET.PIPELINE.INGEST_STATUS('bfcf2fc8-8839-4ec8-be2c-0b2bcc50d338');

SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY;
WHERE root_query_id = '01c40b10-051c-df4f-0075-0083055e87fa'
ORDER BY start_time asc;


------Testing Again with Event Logging------
--STEP 1: pipeline.ingest_start
call sprocket.pipeline.ingest_start('Industry-Nine-Hydra-Hub-Service.pdf');

---Review: raw.document_registry
select *
from raw.document_registry
where document_id = 'b830439c-6e04-4600-87d9-c380267b53df';

select *
from raw.document_pages
where document_id = 'b830439c-6e04-4600-87d9-c380267b53df';

select *
from raw.document_images
where document_id = 'b830439c-6e04-4600-87d9-c380267b53df';

--STEP 2:
call pipeline.ingest_classify('b830439c-6e04-4600-87d9-c380267b53df');

--STEP 3:
call pipeline.ingest_link('b830439c-6e04-4600-87d9-c380267b53df', NULL, NULL, NULL);

Select *
from curated.component_document_link
where document_id = '';

select *
from curated.bike_component_instances;
where document_id = 'bfcf2fc8-8839-4ec8-be2c-0b2bcc50d338';

--Step 4:
CALL SPROCKET.PIPELINE.INGEST_FINALIZE('b830439c-6e04-4600-87d9-c380267b53df');

CALL SPROCKET.PIPELINE.INGEST_STATUS('b830439c-6e04-4600-87d9-c380267b53df');

SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY;
WHERE root_query_id = '01c40b10-051c-df4f-0075-0083055e87fa'
ORDER BY start_time asc;

select *
from pipeline.ingest_queue;

delete from pipeline.ingest_queue 
where document_id = 'bfcf2fc8-8839-4ec8-be2c-0b2bcc50d338';

select source_file,document_id,count(chunk_id)
from search.document_chunks
group by all;

sele


