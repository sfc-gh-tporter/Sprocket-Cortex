-- ============================================
-- Sample Evaluation Data: Multi-Step Reasoning
-- ============================================
-- Purpose: Populate EVAL_MULTI_STEP_REASONING with complex test questions
-- DO NOT RUN WITHOUT EXPLICIT APPROVAL - This is a template

USE SCHEMA SPROCKET.PIPELINE;

-- ============================================
-- Troubleshooting scenarios (multi-step)
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING VALUES (
    'ms_troubleshoot_01',
    'troubleshooting',
    'My rear shock is bottoming out on big hits. Walk me through diagnosis and fixes.',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "rear shock bottoming out diagnosis"}},
            {"tool_name": "search_manuals", "tool_sequence": 2, "parameters": {"query": "rear shock air pressure adjustment volume spacers"}}
        ],
        "ground_truth_output": "Shock bottoming out diagnosis: 1) Check current sag - should be 25-30%. If sag is correct but still bottoming, you need more progression. 2) Add air pressure in 5 psi increments and retest. 3) If max pressure reached and still bottoming, add volume spacers to increase progression. 4) If no spacers available, consider upgrading to coil spring for more support."
    }'),
    'search -> search -> synthesize',
    'Tests multi-step troubleshooting guidance with diagnosis and multiple solutions'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING VALUES (
    'ms_troubleshoot_02',
    'troubleshooting',
    'My fork feels sticky and does not return fully after compression. What should I check?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "fork stiction sticky return"}},
            {"tool_name": "search_manuals", "tool_sequence": 2, "parameters": {"query": "fork lower leg service seal replacement"}}
        ],
        "ground_truth_output": "Fork stiction diagnosis: 1) Check for visible seal damage or dirt buildup around dust seals. 2) Check air pressure - low pressure can cause poor return. 3) Most common cause: dry or contaminated seals. Solution: Perform lower leg service - replace foam rings, clean and re-oil seals, check for scoring on stanchions. If stanchions are scored, they need replacement."
    }'),
    'search -> search -> synthesize',
    'Tests diagnostic flow from symptoms to root cause to fix'
);

-- ============================================
-- Comparison questions
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING VALUES (
    'ms_compare_01',
    'comparison',
    'Compare the bleed procedures for Hayes and Shimano brakes.',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "Hayes brake bleed procedure"}},
            {"tool_name": "search_manuals", "tool_sequence": 2, "parameters": {"query": "Shimano brake bleed procedure"}}
        ],
        "ground_truth_output": "Hayes vs Shimano bleed comparison: Both use gravity bleed method. Hayes: Uses DOT 5.1 fluid, requires syringe at both caliper and lever, push fluid from caliper to lever. Shimano: Uses mineral oil, funnel at lever, syringe at caliper, push fluid from caliper to lever. Hayes takes ~20 min, Shimano ~15 min. Critical: NEVER mix fluid types."
    }'),
    'search -> search -> synthesize comparison',
    'Tests ability to retrieve two separate procedures and compare/contrast them'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING VALUES (
    'ms_compare_02',
    'comparison',
    'What are the differences between air and coil rear shocks?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "air shock characteristics advantages"}},
            {"tool_name": "search_manuals", "tool_sequence": 2, "parameters": {"query": "coil shock characteristics advantages"}}
        ],
        "ground_truth_output": "Air vs Coil comparison: Air: Lighter weight, adjustable spring rate via pressure, progressive force curve, requires more maintenance, susceptible to temperature changes. Coil: Heavier, fixed spring rate (swappable springs), linear force curve, less maintenance, consistent across temps. Air better for climbing/weight-conscious, Coil better for consistency/aggressive descending."
    }'),
    'search -> search -> synthesize comparison',
    'Tests conceptual comparison requiring synthesis of characteristics'
);

-- ============================================
-- Multi-component questions
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING VALUES (
    'ms_multi_comp_01',
    'multi-component',
    'What are all the adjustments available on my RockShox suspension setup?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "RockShox fork adjustments rebound compression"}},
            {"tool_name": "search_manuals", "tool_sequence": 2, "parameters": {"query": "RockShox shock adjustments rebound compression volume"}}
        ],
        "ground_truth_output": "RockShox suspension adjustments: Fork - Rebound damping (red knob base of leg), low-speed compression (blue knob top of leg), high-speed compression (screw behind blue knob), air pressure, volume spacers. Shock - Rebound damping (red knob), low-speed compression (if equipped), air pressure, volume spacers. Start with all adjustments at middle settings and tune from there."
    }'),
    'search -> search -> synthesize list',
    'Tests ability to aggregate info across fork and shock components'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING VALUES (
    'ms_multi_comp_02',
    'multi-component',
    'What torque specs do I need for a complete brake installation?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "brake caliper mount bolt torque"}},
            {"tool_name": "search_manuals", "tool_sequence": 2, "parameters": {"query": "brake rotor bolt torque"}},
            {"tool_name": "search_manuals", "tool_sequence": 3, "parameters": {"query": "brake lever clamp bolt torque"}}
        ],
        "ground_truth_output": "Complete brake installation torque specs: Rotor bolts - 6.2 Nm (55 in-lb) in star pattern. Caliper mount bolts - 8-10 Nm (70-88 in-lb) depending on frame material. Lever clamp bolt - 4-5 Nm (35-44 in-lb). Hose banjo bolt - 5-7 Nm (44-62 in-lb). Always use torque wrench and thread locker where specified."
    }'),
    'search -> search -> search -> synthesize checklist',
    'Tests comprehensive information gathering for complete procedure'
);

-- ============================================
-- Procedure synthesis questions
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING VALUES (
    'ms_procedure_01',
    'procedure',
    'Walk me through setting up a new rear shock from scratch.',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "rear shock installation mounting hardware"}},
            {"tool_name": "search_manuals", "tool_sequence": 2, "parameters": {"query": "rear shock air pressure setup sag adjustment"}}
        ],
        "ground_truth_output": "New rear shock setup procedure: 1) Install shock hardware (bushings, spacers per frame spec). 2) Mount shock to frame with correct hardware orientation. 3) Torque mounting bolts per spec (typically 15-20 Nm). 4) Set initial air pressure based on rider weight (start ~200 psi for 180lb rider). 5) Measure sag with rider in attack position - target 25-30%. 6) Adjust pressure until sag is correct. 7) Set rebound to middle setting. 8) Test ride and fine-tune."
    }'),
    'search -> search -> synthesize ordered procedure',
    'Tests ability to create step-by-step procedure from multiple sources'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING VALUES (
    'ms_procedure_02',
    'procedure',
    'How do I prepare my bike for long-term storage?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "suspension storage maintenance prep"}},
            {"tool_name": "search_manuals", "tool_sequence": 2, "parameters": {"query": "brake storage maintenance cleaning"}},
            {"tool_name": "search_manuals", "tool_sequence": 3, "parameters": {"query": "frame cleaning long term storage"}}
        ],
        "ground_truth_output": "Bike long-term storage prep: 1) Clean entire bike thoroughly, dry completely. 2) Suspension - cycle fork/shock fully, leave at 25% travel to keep seals lubricated. 3) Brakes - clean rotors with isopropyl alcohol, do not compress levers during storage. 4) Drivetrain - clean and lube chain. 5) Tires - inflate to max pressure to prevent flat spots. 6) Store in cool, dry place away from UV. 7) Check every 2-3 months, cycle suspension, spin wheels."
    }'),
    'search -> search -> search -> synthesize comprehensive checklist',
    'Tests synthesis of maintenance procedures across multiple bike systems'
);

-- ============================================
-- Concept explanation questions
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING VALUES (
    'ms_concept_01',
    'concept',
    'Explain compression damping and why there are low-speed and high-speed adjustments.',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "compression damping explanation"}},
            {"tool_name": "search_manuals", "tool_sequence": 2, "parameters": {"query": "low speed high speed compression damping difference"}}
        ],
        "ground_truth_output": "Compression damping controls how fast suspension compresses. Low-speed compression affects slow inputs (body weight shifts, G-outs, pedaling). High-speed compression affects fast impacts (rocks, roots, drops). LSC prevents wallowing and bob, HSC prevents harsh bottom-outs. Separate adjustments allow tuning small bump compliance (HSC) independently from pedaling efficiency (LSC)."
    }'),
    'search -> search -> synthesize explanation',
    'Tests ability to explain technical concepts by synthesizing info from multiple sources'
);

-- ============================================
-- Optimization questions
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING VALUES (
    'ms_optimize_01',
    'optimization',
    'My bike feels harsh on small bumps but bottoms out on big hits. How do I tune suspension to fix both?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "suspension small bump sensitivity tuning"}},
            {"tool_name": "search_manuals", "tool_sequence": 2, "parameters": {"query": "suspension bottom out prevention volume spacers progression"}},
            {"tool_name": "search_manuals", "tool_sequence": 3, "parameters": {"query": "suspension compression rebound balance tuning"}}
        ],
        "ground_truth_output": "Harsh small bumps + bottoming requires balancing sensitivity and support: 1) For small bump harshness: Reduce rebound damping (faster), reduce HSC if available. Check for stiction (service seals). 2) For bottom-out: Add volume spacers for more end-stroke support without increasing initial pressure. 3) Final tune: Set sag at 25%, tune LSC for pedaling support, tune HSC for impact control, tune rebound for recovery speed. Volume spacers are key to getting both."
    }'),
    'search -> search -> search -> synthesize optimization strategy',
    'Tests complex tuning advice requiring balance of competing concerns'
);

-- ============================================
-- Query to verify data loaded
-- ============================================

-- SELECT 
--     category,
--     COUNT(*) as question_count
-- FROM SPROCKET.PIPELINE.EVAL_MULTI_STEP_REASONING
-- GROUP BY category
-- ORDER BY category;

-- Expected output:
-- comparison: 2
-- concept: 1
-- multi-component: 2
-- optimization: 1
-- procedure: 2
-- troubleshooting: 2
-- TOTAL: 10 questions
