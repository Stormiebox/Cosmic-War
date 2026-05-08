return {
    pages = {
        {
            title = "War Pressure",
            options = {
                {
                    key = "sectorPressureInterval",
                    type = "number",
                    title = "Sector Pressure Interval (s)",
                    description = "How often sector war pressure controller updates.",
                    default = 180,
                    min = 30,
                    max = 1800,
                },
                {
                    key = "sectorPressureChance",
                    type = "slider",
                    title = "Sector Pressure Trigger Chance",
                    description = "Chance per sector tick to apply war pressure.",
                    default = 35,
                    min = 0,
                    max = 100,
                    step = 1,
                    unit = "%",
                },
                {
                    key = "sectorPressureMinSpacing",
                    type = "number",
                    title = "Sector Pressure Min Spacing (s)",
                    description = "Minimum seconds between pressure events in a loaded sector.",
                    default = 600,
                    min = 60,
                    max = 7200,
                },
            },
        },
        {
            title = "Diplomacy",
            options = {
                {
                    key = "diplomacyInterval",
                    type = "number",
                    title = "Diplomacy Update Interval (s)",
                    description = "How often diplomacy drift runs.",
                    default = 300,
                    min = 30,
                    max = 3600,
                },
                {
                    key = "diplomacyPairSteps",
                    type = "number",
                    title = "Diplomacy Pair Steps",
                    description = "How many random faction pairs are evaluated per diplomacy tick.",
                    default = 10,
                    min = 1,
                    max = 100,
                },
                {
                    key = "rivalryThreshold",
                    type = "number",
                    title = "Rivalry Threshold",
                    description = "Relations value at or below which enemies/targets are locked in.",
                    default = -45000,
                    min = -100000,
                    max = 0,
                },
            },
        },
        {
            title = "Diagnostics",
            options = {
                {
                    key = "debugLogs",
                    type = "bool",
                    title = "Enable Cosmic War Debug Logs",
                    description = "Enables informational debug prints in logs.",
                    default = true,
                },
            },
        },
    },
}
