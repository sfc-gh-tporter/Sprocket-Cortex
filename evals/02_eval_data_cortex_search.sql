-- ============================================
-- Sample Evaluation Data: Cortex Search Basic
-- ============================================
-- Purpose: Populate EVAL_CORTEX_SEARCH_BASIC with test questions
-- DO NOT RUN WITHOUT EXPLICIT APPROVAL - This is a template

USE SCHEMA SPROCKET.PIPELINE;

-- ============================================
-- Shock-related questions
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_shock_01',
    'shock',
    'What is the recommended air pressure for the RockShox Vivid Air?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "RockShox Vivid Air pressure"}}
        ],
        "ground_truth_output": "The recommended air pressure for the RockShox Vivid Air is 150-250 psi depending on rider weight. Start at 200 psi for a 180 lb rider and adjust based on 25-30% sag."
    }'),
    'Tests basic retrieval of technical spec from RockShox manual'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_shock_02',
    'shock',
    'How do I adjust rebound damping on my rear shock?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "rebound adjustment rear shock"}}
        ],
        "ground_truth_output": "To adjust rebound damping, turn the red rebound adjuster knob. Clockwise slows rebound (more damping), counterclockwise speeds it up (less damping). Start at the middle setting and adjust based on terrain - slower for rough terrain, faster for smooth."
    }'),
    'Tests procedural guidance retrieval'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_shock_03',
    'shock',
    'What tools do I need to service the RockShox Vivid Air?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "RockShox Vivid Air service tools required"}}
        ],
        "ground_truth_output": "Required tools for Vivid Air service: shock pump (300 psi), 8mm socket, torque wrench, pick tool, seal driver, seal press tool, bearing press, suspension oil, and seal kit."
    }'),
    'Tests tool list retrieval'
);

-- ============================================
-- Brake-related questions
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_brake_01',
    'brake',
    'What torque spec should I use for Hayes Dominion rotor bolts?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "Hayes Dominion rotor bolt torque"}}
        ],
        "ground_truth_output": "Hayes Dominion rotor bolts should be torqued to 6.2 Nm (55 in-lb). Use a torque wrench and tighten in a star pattern."
    }'),
    'Tests specific torque spec retrieval - critical safety data'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_brake_02',
    'brake',
    'How do I bleed Hayes Dominion brakes?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "Hayes Dominion brake bleed procedure"}}
        ],
        "ground_truth_output": "Hayes Dominion brake bleed procedure: 1) Remove wheel and pads. 2) Attach syringe to caliper bleed port. 3) Attach syringe to lever bleed port. 4) Push fluid from caliper to lever until bubble-free. 5) Close bleed ports and test lever feel. Use DOT 5.1 fluid only."
    }'),
    'Tests multi-step procedure retrieval'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_brake_03',
    'brake',
    'What type of brake fluid does Hayes use?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "Hayes brake fluid type DOT"}}
        ],
        "ground_truth_output": "Hayes brakes use DOT 5.1 brake fluid. Never use mineral oil or other DOT fluids. DOT 5.1 is compatible with DOT 3 and DOT 4 but has a higher boiling point."
    }'),
    'Tests critical compatibility information retrieval'
);

-- ============================================
-- Fork-related questions
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_fork_01',
    'fork',
    'How often should I service my suspension fork?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "suspension fork service intervals maintenance"}}
        ],
        "ground_truth_output": "Suspension fork service intervals: Lower leg service (foam rings, seals) every 50 hours or annually. Damper service every 100 hours or annually. Air spring service every 100 hours. More frequent for wet/muddy conditions."
    }'),
    'Tests maintenance schedule retrieval'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_fork_02',
    'fork',
    'What is the correct sag percentage for a mountain bike fork?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "mountain bike fork sag percentage setup"}}
        ],
        "ground_truth_output": "Mountain bike fork sag should be 20-30% of total travel. 25% is a good starting point for trail riding. More sag (30%) for downhill, less (20%) for cross-country. Measure with rider in normal riding position."
    }'),
    'Tests setup guidance retrieval'
);

-- ============================================
-- Frame-related questions
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_frame_01',
    'frame',
    'What is the recommended torque for Specialized Stumpjumper headset bolts?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "Specialized Stumpjumper headset bolt torque specification"}}
        ],
        "ground_truth_output": "Specialized Stumpjumper headset top cap should be torqued to 2.5-3 Nm. Stem bolts should be 5-6 Nm. Always use a torque wrench to avoid over-tightening."
    }'),
    'Tests frame-specific torque spec retrieval'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_frame_02',
    'frame',
    'What is the geometry of the Stumpjumper Evo?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "Stumpjumper Evo geometry specifications"}}
        ],
        "ground_truth_output": "Stumpjumper Evo geometry (size Large): 160mm rear travel, 170mm front travel, 64.5° head angle, 77.5° seat angle, 458mm reach, 1245mm wheelbase. Designed for aggressive trail and enduro riding."
    }'),
    'Tests geometry spec retrieval'
);

-- ============================================
-- Safety and warning questions
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_safety_01',
    'safety',
    'What safety precautions should I take when working with suspension springs?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "suspension spring safety precautions compressed"}}
        ],
        "ground_truth_output": "Safety precautions for suspension springs: Always wear safety glasses. Release all air pressure before disassembly. Use proper spring compressor tools. Never point the shock at yourself or others during disassembly. Springs under compression can cause serious injury."
    }'),
    'Tests safety warning retrieval - critical content'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_safety_02',
    'safety',
    'What happens if I use the wrong brake fluid?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "brake fluid compatibility mixing DOT mineral oil"}}
        ],
        "ground_truth_output": "Using the wrong brake fluid can cause seal damage, complete brake failure, and safety hazards. DOT fluid and mineral oil are NOT compatible. Mixing them destroys seals and renders the brake unsafe. Always check your brake manufacturer specification before adding fluid."
    }'),
    'Tests critical safety information about fluid compatibility'
);

-- ============================================
-- Troubleshooting questions (single-step)
-- ============================================

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_troubleshoot_01',
    'troubleshooting',
    'Why does my rear shock feel harsh over small bumps?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "rear shock harsh small bump sensitivity"}}
        ],
        "ground_truth_output": "Harsh feel over small bumps indicates insufficient rebound damping or low air pressure. Check: 1) Rebound setting - open (faster) for better small bump compliance. 2) Air pressure - may be too high, reduce 5-10 psi. 3) Check for stiction from dry seals - service lower seals."
    }'),
    'Tests diagnostic guidance retrieval'
);

INSERT INTO SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC VALUES (
    'cs_troubleshoot_02',
    'troubleshooting',
    'My brakes feel spongy. What is wrong?',
    PARSE_JSON('{
        "ground_truth_invocations": [
            {"tool_name": "search_manuals", "tool_sequence": 1, "parameters": {"query": "spongy brake lever air bubbles bleed"}}
        ],
        "ground_truth_output": "Spongy brake lever indicates air in the hydraulic system. Solution: Bleed the brakes to remove air bubbles. Check for: 1) Loose bleed port screws. 2) Damaged seals allowing air ingress. 3) Low fluid level at reservoir. Perform full brake bleed procedure."
    }'),
    'Tests common problem diagnosis'
);

-- ============================================
-- Query to verify data loaded
-- ============================================

-- SELECT 
--     category,
--     COUNT(*) as question_count
-- FROM SPROCKET.PIPELINE.EVAL_CORTEX_SEARCH_BASIC
-- GROUP BY category
-- ORDER BY category;

-- Expected output:
-- brake: 3
-- fork: 2  
-- frame: 2
-- safety: 2
-- shock: 3
-- troubleshooting: 2
-- TOTAL: 14 questions
