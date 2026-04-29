use role sysadmin;
use database sprocket;
use warehouse sprocket_wh;

-- Set Up LLM Eval Schema ---
create or replace schema sprocket.agent_evals;



CREATE OR REPLACE TABLE stumpjumper_eval_sonnet_4_6 (
    input_query VARCHAR,
    ground_truth OBJECT
);

INSERT INTO agent_evaluation_data
  SELECT
    'What was the temperature in San Francisco on August 2nd 2019?',
    PARSE_JSON('
      {
        "ground_truth_output": "The temperature was 14 degrees Celsius in San Francisco on August 2nd, 2019.",
        "ground_truth_invocations": [
            {
              "tool_name": "get_weather",
              "tool_sequence": 1,
              "tool_input": {"city": "San Francisco", "date": "08/02/2019"},
              "tool_output": {"temp": "14", "units": "C"}
            }
        ]
      }
    ');