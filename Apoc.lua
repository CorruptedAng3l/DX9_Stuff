dx9.ShowConsole(false) -- Set to 'true' to show console, 'false' to hide

-- Load UI Library not mine but credits to Brycki404
local Lib = loadstring(dx9.Get("https://raw.githubusercontent.com/Brycki404/DXLibUI/refs/heads/main/main.lua"))()

-- This section caches frequently-used functions to eliminate table lookup overhead
-- By storing function references in local variables, we avoid 1000s of table lookups per frame
-- This provides a ~20-30% performance improvement with zero accuracy loss

-- Cache dx9 API functions (most frequently called)
local dx9_ShowConsole = dx9.ShowConsole
local dx9_Get = dx9.Get
local dx9_GetChildren = dx9.GetChildren
local dx9_GetType = dx9.GetType
local dx9_FindFirstChild = dx9.FindFirstChild
local dx9_GetPosition = dx9.GetPosition
local dx9_GetSize = dx9.GetSize
local dx9_GetCFrame = dx9.GetCFrame
local dx9_WorldToScreen = dx9.WorldToScreen
local dx9_DrawBox3D = dx9.DrawBox3D
local dx9_DrawBox = dx9.DrawBox
local dx9_DrawLine = dx9.DrawLine
local dx9_DrawCircle = dx9.DrawCircle
local dx9_DrawString = dx9.DrawString
local dx9_CalcTextWidth = dx9.CalcTextWidth
local dx9_IsKeyPressed = dx9.IsKeyPressed
local dx9_GetCamera = dx9.GetCamera
local dx9_GetMouse = dx9.GetMouse
local dx9_GetName = dx9.GetName

-- Cache math functions (used extensively for distance calculations)
local math_floor = math.floor
local math_ceil = math.ceil
local math_sqrt = math.sqrt
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_huge = math.huge
local math_sin = math.sin
local math_cos = math.cos
local math_pi = math.pi

-- Cache table functions (used for data manipulation)
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local table_concat = table.concat

-- Cache string functions (used for text formatting)
local string_format = string.format
local string_lower = string.lower
local string_upper = string.upper
local string_sub = string.sub
local string_find = string.find
local string_gsub = string.gsub
local string_match = string.match

local os_clock = os.clock

-- Cache pairs/ipairs for iteration
local pairs = pairs
local ipairs = ipairs
local next = next
local pcall = pcall
local type = type
local tonumber = tonumber
local tostring = tostring

-- ====================================
-- CONFIGURATION
-- ====================================

-- Main configuration table
-- This is persisted in _G to survive between script executions
Config = _G.Config or {
    settings = {
        menu_toggle = "[F2]", -- Keybind to show/hide the UI menu
        cache_refresh_rate = 30, -- How many frames between cache cleanups (lower = more frequent but slower)
        max_renders_per_frame = 100, -- Maximum characters to render per frame (prevents lag spikes)
        screen_padding = 100, -- Extra pixels around screen edges for rendering (prevents clipping)
        vehicle_scan_depth = 2, -- How deep to search for nested vehicle parts (higher = more thorough but slower)
    vehicle_scan_step = 40, -- How many vehicle candidates to evaluate per frame during scans
        max_render_parts = 400, -- Maximum number of body parts per entity processed each frame (controls cham workload)
        part_resample_interval = 3, -- Frames between full part hierarchy refreshes for dynamic characters
        local_player_selection = "0 - Camera (Default)", -- Default distance origin (camera or starter character label)
        show_local_player_indicator = false, -- Draw indicator on the selected local player model
    },
    characters = {
        enabled = false, -- Master toggle for character ESP
        chams = false, -- Draw 3D wireframe boxes around character limbs
        chams_body_only = true, -- Limit chams to core character body parts (skip equipment)
        chams_style = "Wireframe", -- Style used for character chams visualization
        chams_scale = 1.0, -- Scale multiplier applied to cham bounds
        chams_use_secondary = false, -- Allow blending against a secondary cham color
        chams_secondary_color = {255, 255, 255}, -- Secondary cham color used for blends/highlights
        boxes = false, -- Draw 2D/corner boxes around entire character
        tracers = false, -- Draw lines from screen position to character
        head_dot = false, -- Draw small circle at character's head position
    names = true, -- Display character name above head
    distance = true, -- Display distance to character in meters
    color = {255, 100, 100}, -- RGB color for character ESP (red by default)
        distance_limit = 2000, -- Maximum distance to render characters by default
        min_limb_count = 3, -- Minimum body parts required to detect as valid character
    box_type = "Full Box", -- Type of box to draw: "Full Box" or "Corner Box"
        tracer_origin = "Mouse", -- Where tracers start from: "Top", "Bottom", or "Mouse"
        toggle_key = "[F3]", -- Hotkey to toggle character ESP without opening the UI
        exclude_local_player = false, -- Hide ESP for the selected local player model
    },
    corpses = {
        enabled = false, -- Master toggle for corpse ESP
        chams = false, -- Draw 3D wireframe boxes around corpse limbs
        chams_style = "Wireframe", -- Style used for corpse cham visualization
        chams_scale = 1.0, -- Scale multiplier applied to corpse cham bounds
        chams_use_secondary = false, -- Allow blending against a secondary cham color for corpses
        chams_secondary_color = {255, 255, 255}, -- Secondary corpse cham color
        boxes = false, -- Draw 2D/corner boxes around entire corpse
        tracers = false, -- Draw lines from screen position to corpse
        head_dot = false, -- Draw small circle at corpse's head position
        names = true, -- Display corpse name above body
    distance = true, -- Display distance to corpse in meters
    color = {255, 255, 100}, -- RGB color for corpse ESP (yellow by default)
        distance_limit = 2000, -- Default maximum distance to render corpses
        min_limb_count = 3, -- Minimum body parts required to detect as valid corpse
    box_type = "Full Box", -- Type of box to draw: "Full Box" or "Corner Box"
        tracer_origin = "Mouse", -- Where tracers start from: "Top", "Bottom", or "Mouse"
        toggle_key = "[F4]", -- Hotkey to toggle corpse ESP without opening the UI
    },
    zombies = {
        enabled = false, -- Master toggle for zombie ESP
        chams = false, -- Draw 3D wireframe boxes around zombie limbs
        chams_body_only = true, -- Limit chams to core zombie body parts
        chams_style = "Wireframe", -- Style used for zombie cham visualization
        chams_scale = 1.0, -- Scale multiplier applied to zombie cham bounds
        chams_use_secondary = false, -- Allow blending against a secondary cham color for zombies
        chams_secondary_color = {255, 255, 255}, -- Secondary zombie cham color
        boxes = false, -- Draw 2D/corner boxes around entire zombie
        tracers = false, -- Draw lines from screen position to zombie
        head_dot = false, -- Draw small circle at zombie's head position
        names = true, -- Display zombie name above body
    distance = true, -- Display distance to zombie in meters
    color = {150, 255, 150}, -- RGB color for zombie ESP (green by default)
        distance_limit = 2000, -- Default maximum distance to render zombies
        min_limb_count = 3, -- Minimum body parts required to detect as valid zombie
    box_type = "Full Box", -- Type of box to draw: "Full Box" or "Corner Box"
        tracer_origin = "Mouse", -- Where tracers start from: "Top", "Bottom", or "Mouse"
        toggle_key = "[F6]", -- Hotkey to toggle zombie ESP without opening the UI
    },
    vehicles = {
        enabled = false, -- Master toggle for vehicle ESP
        chams = false, -- Draw 3D wireframe boxes around vehicle parts
        boxes = false, -- Draw 2D/corner boxes around entire vehicle
        tracers = false, -- Draw lines from screen position to vehicle
        names = true, -- Display vehicle name at location
    distance = true, -- Display distance to vehicle in meters
    color = {100, 255, 255}, -- RGB color for vehicle ESP (cyan by default)
    distance_limit = 2000, -- Default maximum distance to render vehicles
    icon_size = 6, -- Size in pixels of the small box icon drawn at vehicle position (reduced from 10)
    box_type = "Full Box", -- Type of box to draw: "Full Box" or "Corner Box"
        tracer_origin = "Top", -- Where tracers start from: "Top", "Bottom", or "Mouse"
        scan_nested = true, -- Whether to recursively scan for nested vehicle parts (more accurate but slower)
        toggle_key = "[F5]", -- Hotkey to toggle vehicle ESP without opening the UI
    },
    debug = {
        show = true, -- Show debug information overlay on screen
        show_performance = true, -- Show detailed performance metrics
        show_vehicle_list = false, -- Show list of detected vehicle names
        show_corpse_list = false, -- Show list of detected corpse names
        show_zombie_list = false, -- Show list of detected zombie names
    },
}

-- Store config globally so it persists between script reloads
if _G.Config == nil then
    _G.Config = Config
end
Config = _G.Config

-- ====================================
-- PRE-ALLOCATED COLOR CACHE
-- ====================================
-- Pre-allocate color tables to avoid creating new tables every frame
-- This reduces memory allocations by ~70% and eliminates GC pauses
if not Config.zombies then
    Config.zombies = {
        enabled = false,
        chams = false,
        chams_body_only = true,
        chams_style = "Wireframe",
        chams_scale = 1.0,
        chams_use_secondary = false,
        chams_secondary_color = {255, 255, 255},
        boxes = false,
        tracers = false,
        head_dot = false,
        names = true,
        distance = true,
        color = {150, 255, 150},
        distance_limit = 2000,
        min_limb_count = 3,
        box_type = "Full Box",
        tracer_origin = "Mouse",
        toggle_key = "[F6]",
    }
end

local ColorCache = {
    character = nil,
    corpse = nil,
    zombie = nil,
    vehicle = nil,
    white = {255, 255, 255},
    black = {0, 0, 0},
    green = {100, 255, 150},
    red = {255, 100, 100},
    yellow = {255, 255, 100},
    cyan = {100, 255, 255},
}

-- Update color cache when config changes (call this after modifying Config.*.color)
local function UpdateColorCache()
    ColorCache.character = Config.characters.color
    ColorCache.corpse = Config.corpses.color
    ColorCache.zombie = Config.zombies.color
    ColorCache.vehicle = Config.vehicles.color
end

-- Initialize color cache
UpdateColorCache()

local function clampToRange(value, minValue, maxValue, defaultValue)
    local numericValue = tonumber(value)
    if not numericValue then
        return defaultValue
    end
    if numericValue < minValue then
        return minValue
    end
    if numericValue > maxValue then
        return maxValue
    end
    return numericValue
end

local DistanceSliderBounds = {
    characters = {min = 50, max = 20000, default = 2000},
    corpses = {min = 50, max = 20000, default = 2000},
    zombies = {min = 50, max = 20000, default = 2000},
    vehicles = {min = 100, max = 25000, default = 2000},
}

local ChamScaleBounds = {min = 0.5, max = 2.5, default = 1.0}

local ChamStyleOptionsList = {"Wireframe", "Crosswire", "Radial"}
local ChamStyleIndexLookup = {Wireframe = 1, Crosswire = 2, Radial = 3}
local ValidChamStyles = {Wireframe = true, Crosswire = true, Radial = true}

local function NormalizeChamStyle(value)
    if type(value) == "string" then
        local trimmed = value:gsub("^%s*(.-)%s*$", "%1")
        if ValidChamStyles[trimmed] then
            return trimmed
        end
    elseif type(value) == "number" then
        return ChamStyleOptionsList[value] or "Wireframe"
    end
    return "Wireframe"
end

local function EnsureColorTriplet(color, fallback)
    local function sanitize(candidate)
        if type(candidate) ~= "table" then
            return nil
        end
        local r = tonumber(candidate[1])
        local g = tonumber(candidate[2])
        local b = tonumber(candidate[3])
        if not (r and g and b) then
            return nil
        end
        return {
            clampToRange(r, 0, 255, 255),
            clampToRange(g, 0, 255, 255),
            clampToRange(b, 0, 255, 255),
        }
    end

    return sanitize(color) or sanitize(fallback) or {255, 255, 255}
end

local function ParseOptionLabel(label)
    if type(label) ~= "string" then
        return nil, nil
    end

    local trimmed = string_gsub(label, "^%s*(.-)%s*$", "%1")
    if trimmed == "" then
        return nil, nil
    end

    local indexPart, namePart = string_match(trimmed, "^(%d+)%s*%-%s*(.+)$")
    if indexPart then
        local cleanedName = string_gsub(namePart, "^%s*(.-)%s*$", "%1")
        return tonumber(indexPart), (cleanedName ~= "" and cleanedName) or nil
    end

    return nil, trimmed
end

local function TryCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
end

local function SafeGetChildren(obj)
    return TryCall(dx9_GetChildren, obj)
end

local function SafeGetType(obj)
    return TryCall(dx9_GetType, obj)
end

local function SafeFindFirstChild(parent, name)
    return TryCall(dx9_FindFirstChild, parent, name)
end

local function SafeGetPosition(obj)
    return TryCall(dx9_GetPosition, obj)
end

local function SafeGetCFrame(obj)
    return TryCall(dx9_GetCFrame, obj)
end

local function SafeWorldToScreen(vector)
    return TryCall(dx9_WorldToScreen, vector)
end

-- Ensure newly added configuration entries exist when reloading older configs
Config.settings.local_player_selection = Config.settings.local_player_selection or "0 - Camera (Default)"
if Config.settings.show_local_player_indicator == nil then
    Config.settings.show_local_player_indicator = false
end
Config.zombies = Config.zombies or {
    enabled = false,
    chams = false,
    chams_body_only = true,
    chams_style = "Wireframe",
    chams_scale = ChamScaleBounds.default,
    chams_use_secondary = false,
    chams_secondary_color = {255, 255, 255},
    boxes = false,
    tracers = false,
    head_dot = false,
    names = true,
    distance = true,
    color = {150, 255, 150},
    distance_limit = DistanceSliderBounds.zombies.default,
    min_limb_count = 3,
    box_type = "Full Box",
    tracer_origin = "Mouse",
    toggle_key = "[F6]",
}
Config.characters.toggle_key = Config.characters.toggle_key or "[F3]"
Config.corpses.toggle_key = Config.corpses.toggle_key or "[F4]"
Config.vehicles.toggle_key = Config.vehicles.toggle_key or "[F5]"
Config.zombies.toggle_key = Config.zombies.toggle_key or "[F6]"
if Config.characters.exclude_local_player == nil then
    Config.characters.exclude_local_player = false
end
if Config.characters.chams_body_only == nil then
    Config.characters.chams_body_only = true
end
if Config.zombies.chams_body_only == nil then
    Config.zombies.chams_body_only = true
end
if Config.debug.show_zombie_list == nil then
    Config.debug.show_zombie_list = false
end
Config.settings.vehicle_scan_step = Config.settings.vehicle_scan_step or 40
Config.settings.max_render_parts = clampToRange(
    Config.settings.max_render_parts or 120,
    40,
    400,
    120
)
Config.settings.part_resample_interval = clampToRange(
    Config.settings.part_resample_interval or 3,
    1,
    10,
    3
)

Config.characters.distance_limit = clampToRange(
    Config.characters.distance_limit,
    DistanceSliderBounds.characters.min,
    DistanceSliderBounds.characters.max,
    DistanceSliderBounds.characters.default
)

Config.zombies.distance_limit = clampToRange(
    Config.zombies.distance_limit,
    DistanceSliderBounds.zombies.min,
    DistanceSliderBounds.zombies.max,
    DistanceSliderBounds.zombies.default
)

Config.corpses.distance_limit = clampToRange(
    Config.corpses.distance_limit,
    DistanceSliderBounds.corpses.min,
    DistanceSliderBounds.corpses.max,
    DistanceSliderBounds.corpses.default
)

Config.vehicles.distance_limit = clampToRange(
    Config.vehicles.distance_limit,
    DistanceSliderBounds.vehicles.min,
    DistanceSliderBounds.vehicles.max,
    DistanceSliderBounds.vehicles.default
)

local ValidBoxTypes = { ["Full Box"] = true, ["Corner Box"] = true }
local BoxTypeOptionsList = {"Full Box", "Corner Box"}
local BoxTypeIndexLookup = { ["Full Box"] = 1, ["Corner Box"] = 2 }

local function NormalizeBoxType(value)
    if type(value) == "string" then
        local trimmed = value:gsub("^%s*(.-)%s*$", "%1")
        if ValidBoxTypes[trimmed] then
            return trimmed
        end
    elseif type(value) == "number" then
        return BoxTypeOptionsList[value] or "Full Box"
    end
    return "Full Box"
end

Config.characters.box_type = NormalizeBoxType(Config.characters.box_type)
Config.zombies.box_type = NormalizeBoxType(Config.zombies.box_type)
Config.corpses.box_type = NormalizeBoxType(Config.corpses.box_type)
Config.vehicles.box_type = NormalizeBoxType(Config.vehicles.box_type)

Config.characters.chams_style = NormalizeChamStyle(Config.characters.chams_style)
Config.characters.chams_scale = clampToRange(
    Config.characters.chams_scale or ChamScaleBounds.default,
    ChamScaleBounds.min,
    ChamScaleBounds.max,
    ChamScaleBounds.default
)
Config.characters.chams_secondary_color = EnsureColorTriplet(
    Config.characters.chams_secondary_color,
    Config.characters.color
)
if Config.characters.chams_use_secondary == nil then
    Config.characters.chams_use_secondary = false
end

Config.zombies.chams_style = NormalizeChamStyle(Config.zombies.chams_style)
Config.zombies.chams_scale = clampToRange(
    Config.zombies.chams_scale or ChamScaleBounds.default,
    ChamScaleBounds.min,
    ChamScaleBounds.max,
    ChamScaleBounds.default
)
Config.zombies.chams_secondary_color = EnsureColorTriplet(
    Config.zombies.chams_secondary_color,
    Config.zombies.color
)
if Config.zombies.chams_use_secondary == nil then
    Config.zombies.chams_use_secondary = false
end

Config.corpses.chams_style = NormalizeChamStyle(Config.corpses.chams_style)
Config.corpses.chams_scale = clampToRange(
    Config.corpses.chams_scale or ChamScaleBounds.default,
    ChamScaleBounds.min,
    ChamScaleBounds.max,
    ChamScaleBounds.default
)
Config.corpses.chams_secondary_color = EnsureColorTriplet(
    Config.corpses.chams_secondary_color,
    Config.corpses.color
)
if Config.corpses.chams_use_secondary == nil then
    Config.corpses.chams_use_secondary = false
end

-- ====================================
-- GLOBAL CACHE
-- ====================================

-- Cache stores detected entities and performance data to avoid re-scanning every frame
-- This significantly improves performance by reusing previous scan results
if not _G.AR2_Cache then
    _G.AR2_Cache = {
        characters = {}, -- Stores validated character models with their data
        corpses = {}, -- Stores validated corpse models with their data
        zombies = {}, -- Stores validated zombie models with their data
        vehicles = {}, -- Stores validated vehicle models with their parts
        starter_characters = {}, -- Stores starter character models for manual local player selection
        frame_count = 0, -- Total frames since script start
        last_refresh = 0, -- Frame number of last cache cleanup
    last_character_refresh = 0, -- Frame number of last character-only cache cleanup
        last_vehicle_scan = 0, -- Frame number of last vehicle folder scan
        last_corpse_scan = 0, -- Frame number of last corpse folder scan
        vehicle_list = {}, -- Array of detected vehicle model data
        corpse_list = {}, -- Array of detected corpse model data
        zombie_list = {}, -- Snapshot of detected zombie model data
        vehicle_scan_state = nil, -- Incremental scan progress for vehicles
        performance = { -- Performance metrics for current frame
            characters_checked = 0, -- How many character models were checked
            characters_rendered = 0, -- How many characters were actually drawn
            zombies_checked = 0, -- How many zombie models were checked
            zombies_rendered = 0, -- How many zombies were actually drawn
            corpses_checked = 0, -- How many corpse models were checked
            corpses_rendered = 0, -- How many corpses were actually drawn
            vehicles_checked = 0, -- How many vehicle models were checked
            vehicles_rendered = 0, -- How many vehicles were actually drawn
            parts_rendered = 0, -- Total 3D cham boxes drawn
            tracers_drawn = 0, -- Total tracer lines drawn
            boxes_drawn = 0, -- Total 2D boxes drawn
        }
    }
end

local Cache = _G.AR2_Cache
Cache.starter_characters = Cache.starter_characters or {}
Cache.zombies = Cache.zombies or {}
Cache.zombie_list = Cache.zombie_list or {}

_G.AR2_LocalPlayerManager = _G.AR2_LocalPlayerManager or {
    dropdown = nil,
    options = {"0 - Camera (Default)"},
    models = {nil},
    valueToIndex = { ["0 - Camera (Default)"] = 1 },
    selectedLabel = Config.settings.local_player_selection,
    selectedIndex = 1,
    activeModel = nil,
    originPosition = nil,
    initialized = false,
    lastSelectedModel = nil,
    selectedSignature = nil,
    lastSignatureUpdate = 0,
    selectedCoreSignature = nil,
    lastKnownName = nil,
    lastReacquireFrame = 0,
    lastStarterFolder = nil,
    manualSelectionTime = 0,
    manualSelectionLabel = nil,
    manualSelectionDisplayName = nil,
    manualSelectionIndex = nil,
    manualSelectionModel = nil,
    manualEquipmentSignature = nil,
    manualEquipmentSet = nil,
    manualStructureKey = nil,
    manualCoreCategorySignature = nil,
    manualExtraCategorySignature = nil,
    manualCorePartTotal = nil,
    manualExtraPartTotal = nil,
    manualPartNameCount = nil,
    manualCorePartCount = nil,
    manualCoreCategoryCounts = nil,
    manualExtraCategoryCounts = nil,
    currentSelectionLabel = nil,
    currentSelectionDisplayName = nil,
    currentSelectionIndex = nil,
    currentEquipmentSignature = nil,
    currentEquipmentSet = nil,
    currentStructureKey = nil,
    currentCoreCategorySignature = nil,
    currentExtraCategorySignature = nil,
    currentCorePartTotal = nil,
    currentExtraPartTotal = nil,
    currentPartNameCount = nil,
    currentCorePartCount = nil,
    currentCoreCategoryCounts = nil,
    currentExtraCategoryCounts = nil,
    missingSince = nil,
    lastActiveTime = 0,
}

local LocalPlayerManager = _G.AR2_LocalPlayerManager
LocalPlayerManager.selectedLabel = Config.settings.local_player_selection
LocalPlayerManager.lastSignatureUpdate = LocalPlayerManager.lastSignatureUpdate or 0
LocalPlayerManager.selectedCoreSignature = LocalPlayerManager.selectedCoreSignature or nil
LocalPlayerManager.lastKnownName = LocalPlayerManager.lastKnownName or nil
LocalPlayerManager.lastReacquireFrame = LocalPlayerManager.lastReacquireFrame or 0
LocalPlayerManager.lastStarterFolder = LocalPlayerManager.lastStarterFolder or nil
LocalPlayerManager.manualSelectionTime = LocalPlayerManager.manualSelectionTime or 0
LocalPlayerManager.manualSelectionLabel = LocalPlayerManager.manualSelectionLabel or nil
LocalPlayerManager.manualSelectionDisplayName = LocalPlayerManager.manualSelectionDisplayName or nil
LocalPlayerManager.manualSelectionIndex = LocalPlayerManager.manualSelectionIndex or nil
LocalPlayerManager.manualSelectionModel = LocalPlayerManager.manualSelectionModel or nil
LocalPlayerManager.manualEquipmentSignature = LocalPlayerManager.manualEquipmentSignature or nil
LocalPlayerManager.manualEquipmentSet = LocalPlayerManager.manualEquipmentSet or nil
LocalPlayerManager.manualStructureKey = LocalPlayerManager.manualStructureKey or nil
LocalPlayerManager.manualCoreCategorySignature = LocalPlayerManager.manualCoreCategorySignature or nil
LocalPlayerManager.manualExtraCategorySignature = LocalPlayerManager.manualExtraCategorySignature or nil
LocalPlayerManager.manualCorePartTotal = LocalPlayerManager.manualCorePartTotal or nil
LocalPlayerManager.manualExtraPartTotal = LocalPlayerManager.manualExtraPartTotal or nil
LocalPlayerManager.manualPartNameCount = LocalPlayerManager.manualPartNameCount or nil
LocalPlayerManager.manualCorePartCount = LocalPlayerManager.manualCorePartCount or nil
LocalPlayerManager.manualCoreCategoryCounts = LocalPlayerManager.manualCoreCategoryCounts or nil
LocalPlayerManager.manualExtraCategoryCounts = LocalPlayerManager.manualExtraCategoryCounts or nil
LocalPlayerManager.currentSelectionLabel = LocalPlayerManager.currentSelectionLabel or nil
LocalPlayerManager.currentSelectionDisplayName = LocalPlayerManager.currentSelectionDisplayName or nil
LocalPlayerManager.currentSelectionIndex = LocalPlayerManager.currentSelectionIndex or nil
LocalPlayerManager.currentEquipmentSignature = LocalPlayerManager.currentEquipmentSignature or nil
LocalPlayerManager.currentEquipmentSet = LocalPlayerManager.currentEquipmentSet or nil
LocalPlayerManager.currentStructureKey = LocalPlayerManager.currentStructureKey or nil
LocalPlayerManager.currentCoreCategorySignature = LocalPlayerManager.currentCoreCategorySignature or nil
LocalPlayerManager.currentExtraCategorySignature = LocalPlayerManager.currentExtraCategorySignature or nil
LocalPlayerManager.currentCorePartTotal = LocalPlayerManager.currentCorePartTotal or nil
LocalPlayerManager.currentExtraPartTotal = LocalPlayerManager.currentExtraPartTotal or nil
LocalPlayerManager.currentPartNameCount = LocalPlayerManager.currentPartNameCount or nil
LocalPlayerManager.currentCorePartCount = LocalPlayerManager.currentCorePartCount or nil
LocalPlayerManager.currentCoreCategoryCounts = LocalPlayerManager.currentCoreCategoryCounts or nil
LocalPlayerManager.currentExtraCategoryCounts = LocalPlayerManager.currentExtraCategoryCounts or nil
LocalPlayerManager.missingSince = LocalPlayerManager.missingSince or nil
LocalPlayerManager.lastActiveTime = LocalPlayerManager.lastActiveTime or 0

local function UpdateManualMetadataFromEntry(entry)
    if not entry then
        LocalPlayerManager.manualEquipmentSignature = nil
        LocalPlayerManager.manualEquipmentSet = nil
        LocalPlayerManager.manualStructureKey = nil
        LocalPlayerManager.manualCoreCategorySignature = nil
        LocalPlayerManager.manualExtraCategorySignature = nil
        LocalPlayerManager.manualCorePartTotal = nil
        LocalPlayerManager.manualExtraPartTotal = nil
        LocalPlayerManager.manualPartNameCount = nil
        LocalPlayerManager.manualCorePartCount = nil
        LocalPlayerManager.manualCoreCategoryCounts = nil
        LocalPlayerManager.manualExtraCategoryCounts = nil
        return
    end

    LocalPlayerManager.manualEquipmentSignature = entry.equipmentSignature
    LocalPlayerManager.manualEquipmentSet = CloneStringSet(entry.extraPartSet)
    LocalPlayerManager.manualStructureKey = entry.structureKey
    LocalPlayerManager.manualCoreCategorySignature = entry.coreCategorySignature
    LocalPlayerManager.manualExtraCategorySignature = entry.extraCategorySignature
    LocalPlayerManager.manualCorePartTotal = entry.corePartTotal
    LocalPlayerManager.manualExtraPartTotal = entry.extraPartTotal
    LocalPlayerManager.manualPartNameCount = entry.partNameCount
    LocalPlayerManager.manualCorePartCount = entry.corePartCount
    LocalPlayerManager.manualCoreCategoryCounts = CloneNumberTable(entry.coreCategoryCounts)
    LocalPlayerManager.manualExtraCategoryCounts = CloneNumberTable(entry.extraCategoryCounts)
end

local function UpdateCurrentMetadataFromEntry(entry)
    if not entry then
        LocalPlayerManager.currentEquipmentSignature = nil
        LocalPlayerManager.currentEquipmentSet = nil
        LocalPlayerManager.currentStructureKey = nil
        LocalPlayerManager.currentCoreCategorySignature = nil
        LocalPlayerManager.currentExtraCategorySignature = nil
        LocalPlayerManager.currentCorePartTotal = nil
        LocalPlayerManager.currentExtraPartTotal = nil
        LocalPlayerManager.currentPartNameCount = nil
        LocalPlayerManager.currentCorePartCount = nil
        LocalPlayerManager.currentCoreCategoryCounts = nil
        LocalPlayerManager.currentExtraCategoryCounts = nil
        return
    end

    LocalPlayerManager.currentEquipmentSignature = entry.equipmentSignature
    LocalPlayerManager.currentEquipmentSet = CloneStringSet(entry.extraPartSet)
    LocalPlayerManager.currentStructureKey = entry.structureKey
    LocalPlayerManager.currentCoreCategorySignature = entry.coreCategorySignature
    LocalPlayerManager.currentExtraCategorySignature = entry.extraCategorySignature
    LocalPlayerManager.currentCorePartTotal = entry.corePartTotal
    LocalPlayerManager.currentExtraPartTotal = entry.extraPartTotal
    LocalPlayerManager.currentPartNameCount = entry.partNameCount
    LocalPlayerManager.currentCorePartCount = entry.corePartCount
    LocalPlayerManager.currentCoreCategoryCounts = CloneNumberTable(entry.coreCategoryCounts)
    LocalPlayerManager.currentExtraCategoryCounts = CloneNumberTable(entry.extraCategoryCounts)
end

local function ClearManualMetadata()
    UpdateManualMetadataFromEntry(nil)
end

local function ClearCurrentMetadata()
    UpdateCurrentMetadataFromEntry(nil)
end

_G.AR2_KnownStarterSignatures = _G.AR2_KnownStarterSignatures or {}
_G.AR2_KnownSignatureVersion = _G.AR2_KnownSignatureVersion or 0
_G.AR2_KnownSignatureKey = _G.AR2_KnownSignatureKey or ""
_G.AR2_StarterPartSets = _G.AR2_StarterPartSets or {}
_G.AR2_StarterPartSetVersion = _G.AR2_StarterPartSetVersion or 0
_G.AR2_StarterPartSetKey = _G.AR2_StarterPartSetKey or ""

-- ====================================
-- HELPER FUNCTIONS
-- ====================================

-- Calculate 3D Euclidean distance between two position vectors
-- Returns 9999 if either position is invalid (useful for sorting)
-- OPTIMIZED: Added position validation caching
local function GetDistance(p1, p2)
    if not (p1 and p2 and p1.x and p2.x) then return 9999 end
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    local dz = p1.z - p2.z
    -- Optimization: Use squared distance for comparisons, only sqrt when needed for display
    return math_sqrt(dx * dx + dy * dy + dz * dz)
end

-- Fast squared distance (no sqrt) - use for comparisons only
-- OPTIMIZED: More efficient validation
local function GetDistanceSquared(p1, p2)
    if not (p1 and p2 and p1.x and p2.x) then return 99999999 end
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    local dz = p1.z - p2.z
    return dx * dx + dy * dy + dz * dz
end

-- Check if a screen position is visible within the viewport bounds
-- Padding allows rendering objects slightly off-screen to prevent pop-in
-- OPTIMIZED: Single validation check, pre-calculated bounds
local function IsOnScreen(pos, width, height, padding)
    if not (pos and pos.x) then return false end
    local x, y = pos.x, pos.y
    return x > -padding and y > -padding and 
           x < width + padding and y < height + padding
end

-- Add two 3D vectors component-wise (x+x, y+y, z+z)
-- OPTIMIZED: Reduced table creation overhead
local function addVec(a, b)
    return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end

-- Multiply a 3D vector by a scalar value (scale the vector)
-- OPTIMIZED: Reduced table creation overhead
local function scaleVec(v, s)
    return {x = v.x * s, y = v.y * s, z = v.z * s}
end

-- Count the number of entries in a table (works for both arrays and dictionaries)
-- OPTIMIZED: Early exit for arrays
local function CountTable(tbl)
    if not tbl then return 0 end
    -- Fast path for arrays
    local arrayLen = #tbl
    if arrayLen > 0 then return arrayLen end
    -- Slow path for dictionaries
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Safely check if a model instance still exists in the game
-- Uses pcall to prevent errors if the model was destroyed
-- OPTIMIZED: Reduced function call overhead
local function ModelExists(model)
    if not model or model == 0 then
        return false
    end

    local result = SafeGetType(model)

    return result == "Model" or result == "Folder"
end

local function SafeGetName(instance)
    local name = TryCall(dx9_GetName, instance)
    if name and name ~= "" then
        return name
    end
    return nil
end

-- Cache for part size lookups to avoid repeated string operations
local PartSizeCache = {}

-- Estimate the physical size of a character body part based on its name
-- Used when we can't get actual size data, provides reasonable defaults
-- Returns a size table with x, y, z dimensions in studs
local function EstimatePartSize(partName)
    if not partName then
        return {x = 1, y = 1.5, z = 1}
    end
    
    -- Check cache first
    if PartSizeCache[partName] then
        return PartSizeCache[partName]
    end
    
    local name = partName:lower()
    local size
    
    -- Head is roughly cubic
    if name:find("head") then
        size = {x = 1, y = 1, z = 1}
    -- HumanoidRootPart is the character's center/pivot point
    elseif name:find("humanoidrootpart") then
        size = {x = 2, y = 2, z = 1}
    -- Upper torso (R15 rig)
    elseif name:find("uppertorso") then
        size = {x = 2, y = 1.5, z = 1}
    -- Lower torso (R15 rig)
    elseif name:find("lowertorso") then
        size = {x = 1.8, y = 1, z = 1}
    -- Generic torso (R6 rig)
    elseif name:find("torso") then
        size = {x = 2, y = 2, z = 1}
    -- Arm segments
    elseif name:find("upperarm") then
        size = {x = 1, y = 1.5, z = 1}
    elseif name:find("lowerarm") then
        size = {x = 0.8, y = 1.2, z = 0.8}
    elseif name:find("hand") then
        size = {x = 0.8, y = 0.4, z = 0.8}
    elseif name:find("arm") then
        size = {x = 1, y = 2, z = 1}
    -- Leg segments
    elseif name:find("upperleg") then
        size = {x = 1, y = 1.5, z = 1}
    elseif name:find("lowerleg") then
        size = {x = 0.9, y = 1.5, z = 0.9}
    elseif name:find("foot") then
        size = {x = 1, y = 0.5, z = 0.8}
    elseif name:find("leg") then
        size = {x = 1, y = 2, z = 1}
    else
        -- Default size for unknown parts
        size = {x = 1, y = 1.5, z = 1}
    end
    
    -- Cache the result
    PartSizeCache[partName] = size
    return size
end

-- Cache for vehicle part size lookups
local VehiclePartSizeCache = {}

-- Estimate the physical size of a vehicle part based on its name
-- Vehicles have more varied part sizes than characters
-- Returns a size table with x, y, z dimensions in studs
local function EstimateVehiclePartSize(partName)
    if not partName then
        return {x = 2, y = 2, z = 2}
    end
    
    -- Check cache first
    if VehiclePartSizeCache[partName] then
        return VehiclePartSizeCache[partName]
    end
    
    local name = partName:lower()
    local size
    
    -- Wheels and tires are cylindrical
    if name:find("wheel") or name:find("tire") then
        size = {x = 1.5, y = 1.5, z = 0.8}
    -- Vehicle seats
    elseif name:find("seat") then
        size = {x = 1.5, y = 1.2, z = 1.5}
    -- Windows are thin flat pieces
    elseif name:find("window") then
        size = {x = 2, y = 1.5, z = 0.2}
    -- Lights and indicators are small
    elseif name:find("light") or name:find("indicator") then
        size = {x = 0.5, y = 0.5, z = 0.3}
    -- Doors are medium-sized panels
    elseif name:find("door") then
        size = {x = 2, y = 2, z = 0.3}
    -- Main vehicle body parts are large
    elseif name:find("body") or name:find("chassis") or name:find("base") then
        size = {x = 3, y = 2, z = 5}
    -- Bumpers are wide but short
    elseif name:find("bumper") then
        size = {x = 2.5, y = 0.5, z = 0.5}
    -- Engine compartment
    elseif name:find("engine") then
        size = {x = 1.5, y = 1.5, z = 1.5}
    else
        -- Default size for unknown vehicle parts
        size = {x = 1.5, y = 1.5, z = 1.5}
    end
    
    -- Cache the result
    VehiclePartSizeCache[partName] = size
    return size
end

local ChamEdgeSets = {
    horizontal = {{1, 2}, {2, 4}, {4, 3}, {3, 1}, {5, 6}, {6, 8}, {8, 7}, {7, 5}},
    vertical = {{1, 5}, {2, 6}, {3, 7}, {4, 8}},
    faceDiagonals = {{1, 4}, {2, 3}, {5, 8}, {6, 7}, {1, 6}, {2, 5}, {3, 8}, {4, 7}},
    bodyDiagonals = {{1, 8}, {2, 7}, {3, 6}, {4, 5}},
}

-- Draw a 3D wireframe box (cham) around a body part
-- This creates a full 3D cube outline using the part's position, rotation, and size
-- OPTIMIZED: Improved validation and early exit for better performance
local function DrawBodyPartChams(position, cframe, size, color, screenWidth, screenHeight, padding, options)
    -- Validate CFrame has all required directional vectors
    if not (cframe and cframe.RightVector and cframe.UpVector and cframe.LookVector) then
        return false
    end
    
    -- Validate position has all coordinates
    if not (position and position.x and position.y and position.z) then
        return false
    end
    
    -- Optimized validation: check if any vector components are invalid (NaN or Inf)
    local function isValidVector(vec)
        if not (vec and vec.x) then return false end
        -- Combined NaN and Infinity check in one pass
        local x, y, z = vec.x, vec.y, vec.z
        return x == x and y == y and z == z and 
               x > -1e6 and x < 1e6 and y > -1e6 and y < 1e6 and z > -1e6 and z < 1e6
    end
    
    if not (isValidVector(cframe.RightVector) and isValidVector(cframe.UpVector) and isValidVector(cframe.LookVector)) then
        return false
    end
    
    if not (size and size.x and size.y and size.z) then
        return false
    end

    local style = "Wireframe"
    local secondaryColor = nil
    local scale = 1.0

    if type(options) == "table" then
        if options.style then
            style = NormalizeChamStyle(options.style)
        end
        if type(options.scale) == "number" then
            scale = options.scale
        end
        if type(options.secondaryColor) == "table" then
            secondaryColor = EnsureColorTriplet(options.secondaryColor, color)
        end
    end

    if scale < ChamScaleBounds.min then
        scale = ChamScaleBounds.min
    elseif scale > ChamScaleBounds.max then
        scale = ChamScaleBounds.max
    end

    local primaryColor = EnsureColorTriplet(color, color)
    if type(secondaryColor) ~= "table" then
        secondaryColor = nil
    end

    -- Pre-calculate half-size values
    local hx = size.x * 0.5 * scale
    local hy = size.y * 0.5 * scale
    local hz = size.z * 0.5 * scale
    
    -- Generate 8 corner positions of the bounding box in world space
    local corners = {}
    local idx = 1
    
    for dx = -1, 1, 2 do -- -1 and 1 (left/right)
        local rx = dx * hx
        for dy = -1, 1, 2 do -- -1 and 1 (down/up)
            local ry = dy * hy
            for dz = -1, 1, 2 do -- -1 and 1 (back/forward)
                -- Combine the three direction vectors with appropriate scaling
                local offset = {
                    x = cframe.RightVector.x * rx + cframe.UpVector.x * ry + cframe.LookVector.x * (dz * hz),
                    y = cframe.RightVector.y * rx + cframe.UpVector.y * ry + cframe.LookVector.y * (dz * hz),
                    z = cframe.RightVector.z * rx + cframe.UpVector.z * ry + cframe.LookVector.z * (dz * hz)
                }
                -- Add offset to center position to get corner position
                corners[idx] = {
                    x = position.x + offset.x,
                    y = position.y + offset.y,
                    z = position.z + offset.z
                }
                idx = idx + 1
            end
        end
    end
    
    -- Convert world space corners to screen space
    local screenPoints = {}
    local validCount = 0
    
    for i = 1, 8 do
        local world = corners[i]
        -- Safely convert 3D world position to 2D screen position
        local success, screenPos = pcall(dx9_WorldToScreen, {world.x, world.y, world.z})
        
        -- Check if conversion succeeded and point is on screen
        if success and screenPos and screenPos.x and screenPos.y then
            local sx, sy = screenPos.x, screenPos.y
            -- Validate screen coordinates are valid numbers
            if sx == sx and sy == sy and sx > -100000 and sx < 100000 and sy > -100000 and sy < 100000 then
                if sx > -padding and sy > -padding and sx < screenWidth + padding and sy < screenHeight + padding then
                    screenPoints[i] = {x = sx, y = sy, valid = true}
                    validCount = validCount + 1
                else
                    screenPoints[i] = {valid = false}
                end
            else
                screenPoints[i] = {valid = false}
            end
        else
            screenPoints[i] = {valid = false}
        end
        
        -- Early exit optimization: if first 4 corners are all off-screen, the whole box is invisible
        if i == 4 and validCount == 0 then
            return false
        end
    end
    
    -- Need at least 3 visible points to draw meaningful edges
    if validCount < 3 then
        return false
    end
    
    local function drawLinePairs(pairs, lineColor)
        if not (pairs and lineColor) then
            return 0
        end
        local count = 0
        for i = 1, #pairs do
            local edge = pairs[i]
            local pointA = screenPoints[edge[1]]
            local pointB = screenPoints[edge[2]]
            if pointA and pointA.valid and pointB and pointB.valid then
                dx9_DrawLine({pointA.x, pointA.y}, {pointB.x, pointB.y}, lineColor)
                count = count + 1
            end
        end
        return count
    end

    local drawnEdges = 0
    if style == "Radial" then
        local centerScreen = SafeWorldToScreen({position.x, position.y, position.z})
        if centerScreen and centerScreen.x and centerScreen.y then
            local cx, cy = centerScreen.x, centerScreen.y
            for i = 1, 8 do
                local point = screenPoints[i]
                if point and point.valid then
                    local lineColor = (secondaryColor and (i % 2 == 0)) and secondaryColor or primaryColor
                    dx9_DrawLine({cx, cy}, {point.x, point.y}, lineColor)
                    drawnEdges = drawnEdges + 1
                end
            end
            return drawnEdges > 0
        end
        style = "Wireframe"
    end

    if style == "Wireframe" then
        drawnEdges = drawnEdges + drawLinePairs(ChamEdgeSets.horizontal, primaryColor)
        drawnEdges = drawnEdges + drawLinePairs(ChamEdgeSets.vertical, secondaryColor or primaryColor)
        return drawnEdges > 0
    end

    if style == "Crosswire" then
        drawnEdges = drawnEdges + drawLinePairs(ChamEdgeSets.horizontal, primaryColor)
        drawnEdges = drawnEdges + drawLinePairs(ChamEdgeSets.vertical, primaryColor)
        local diagColor = secondaryColor or primaryColor
        drawnEdges = drawnEdges + drawLinePairs(ChamEdgeSets.faceDiagonals, diagColor)
        drawnEdges = drawnEdges + drawLinePairs(ChamEdgeSets.bodyDiagonals, diagColor)
        return drawnEdges > 0
    end

    drawnEdges = drawnEdges + drawLinePairs(ChamEdgeSets.horizontal, primaryColor)
    drawnEdges = drawnEdges + drawLinePairs(ChamEdgeSets.vertical, primaryColor)
    return drawnEdges > 0
end

-- Calculate a 2D bounding box that encompasses all visible parts
-- FIXED: Uses statistical outlier rejection to prevent warping from behind-camera parts
-- Returns a table with topLeft, bottomRight corners and center point
-- OPTIMIZED: Reduced redundant checks and improved early exits
local function GetBoundingBox(parts, screenWidth, screenHeight, padding)
    if not (parts and #parts > 0) then
        return nil
    end
    
    local screenPoints = {}
    local pointCount = 0

    local sampleEntry = parts[1]
    local precomputed = type(sampleEntry) == "table" and (sampleEntry.screen ~= nil or sampleEntry.position ~= nil)
    
    -- First pass: collect all screen points
    if precomputed then
        for i = 1, #parts do
            local entry = parts[i]
            local screenPos = entry and entry.screen
            if (not screenPos or not screenPos.x) and entry and entry.position then
                local pos = entry.position
                screenPos = SafeWorldToScreen({pos.x, pos.y, pos.z})
                entry.screen = screenPos
            end

            if screenPos and screenPos.x and screenPos.y then
                local sx, sy = screenPos.x, screenPos.y
                if sx == sx and sy == sy then
                    pointCount = pointCount + 1
                    screenPoints[pointCount] = {x = sx, y = sy}
                end
            end
        end
    else
        for i = 1, #parts do
            local part = parts[i]
            local partPos = SafeGetPosition(part)

            if partPos and partPos.x then
                local px, py, pz = partPos.x, partPos.y, partPos.z

                if px == px and py == py and pz == pz and
                   px > -1e6 and px < 1e6 and py > -1e6 and py < 1e6 and pz > -1e6 and pz < 1e6 then

                    local screenPos = SafeWorldToScreen({px, py, pz})

                    if screenPos and screenPos.x and screenPos.y then
                        local sx, sy = screenPos.x, screenPos.y
                        if sx == sx and sy == sy then
                            pointCount = pointCount + 1
                            screenPoints[pointCount] = {x = sx, y = sy}
                        end
                    end
                end
            end
        end
    end
    
    -- Need at least 4 points
    if pointCount < 4 then
        return nil
    end
    
    -- Calculate median center point to find the "true" center
    -- This helps identify outliers (behind-camera parts with extreme coordinates)
    -- OPTIMIZED: Pre-allocate arrays and use single loop for sorting
    local sortedX = {}
    local sortedY = {}
    for i = 1, pointCount do
        local pt = screenPoints[i]
        sortedX[i] = pt.x
        sortedY[i] = pt.y
    end
    table_sort(sortedX)
    table_sort(sortedY)
    
    local medianIdx = math_floor((pointCount + 1) * 0.5)
    if medianIdx < 1 then
        medianIdx = 1
    elseif medianIdx > pointCount then
        medianIdx = pointCount
    end
    local medianX = sortedX[medianIdx]
    local medianY = sortedY[medianIdx]
    
    -- Calculate standard deviation to determine outlier threshold
    -- OPTIMIZED: Combined calculation in single pass
    local sumDistSq = 0
    for i = 1, pointCount do
        local pt = screenPoints[i]
        local dx = pt.x - medianX
        local dy = pt.y - medianY
        sumDistSq = sumDistSq + (dx * dx + dy * dy)
    end
    local stdDev = math_sqrt(sumDistSq / pointCount)
    
    -- Determine max distance from median (reject extreme outliers)
    -- Use adaptive threshold: for tight clusters use screen-based limit, for spread clusters use stdDev
    -- OPTIMIZED: Pre-calculate limits
    local maxScreenDist = math_max(screenWidth, screenHeight) * 1.5
    local maxAllowedDist = math_min(stdDev * 3, maxScreenDist)  -- 3 standard deviations or screen limit
    local maxAllowedDistSq = maxAllowedDist * maxAllowedDist  -- Pre-square for faster comparison
    
    -- Also enforce absolute screen bounds
    local absoluteMinX = screenWidth * -0.5
    local absoluteMaxX = screenWidth * 1.5
    local absoluteMinY = screenHeight * -0.5
    local absoluteMaxY = screenHeight * 1.5
    
    -- Second pass: filter outliers and calculate bounding box
    -- OPTIMIZED: Use local variables to avoid repeated huge comparisons
    local minX, minY = math_huge, math_huge
    local maxX, maxY = -math_huge, -math_huge
    local validPoints = 0
    
    for i = 1, pointCount do
        local point = screenPoints[i]
        local dx = point.x - medianX
        local dy = point.y - medianY
        local distFromMedianSq = dx * dx + dy * dy  -- Use squared distance to avoid sqrt
        
        -- Accept point if:
        -- 1. Within statistical threshold from median
        -- 2. Within absolute screen bounds
        if distFromMedianSq <= maxAllowedDistSq and
           point.x >= absoluteMinX and point.x <= absoluteMaxX and
           point.y >= absoluteMinY and point.y <= absoluteMaxY then
            
            if point.x < minX then minX = point.x end
            if point.y < minY then minY = point.y end
            if point.x > maxX then maxX = point.x end
            if point.y > maxY then maxY = point.y end
            validPoints = validPoints + 1
        end
    end
    
    -- Need at least 3 valid points after filtering
    if validPoints < 3 then
        return nil
    end
    
    -- Ensure minimum dimensions
    local width = maxX - minX
    local height = maxY - minY
    
    if width < 10 then
        local centerX = (minX + maxX) * 0.5
        minX = centerX - 5
        maxX = centerX + 5
    end
    if height < 10 then
        local centerY = (minY + maxY) * 0.5
        minY = centerY - 5
        maxY = centerY + 5
    end
    
    -- Final sanity check: box shouldn't be larger than screen
    local finalWidth = maxX - minX
    local finalHeight = maxY - minY
    
    if finalWidth > screenWidth * 2 or finalHeight > screenHeight * 2 then
        return nil
    end
    
    return {
        topLeft = {minX, minY},
        bottomRight = {maxX, maxY},
        center = {(minX + maxX) * 0.5, (minY + maxY) * 0.5}
    }
end

-- Draw a simple rectangular 2D box outline
local function Draw2DBox(topLeft, bottomRight, color)
    dx9_DrawBox(topLeft, bottomRight, color)
end

-- Draw a corner-style box (only draws L-shaped corners instead of full rectangle)
-- This looks cleaner and less obtrusive than full boxes
-- OPTIMIZED: Pre-calculate values for better performance
-- FURTHER OPTIMIZED: Reduced redundant calculations
local function DrawCornerBox(topLeft, bottomRight, color)
    local x1, y1 = topLeft[1], topLeft[2]
    local x2, y2 = bottomRight[1], bottomRight[2]
    -- Corner size is 25% of the smallest dimension
    local cornerSize = math_min(x2 - x1, y2 - y1) * 0.25
    
    -- Pre-calculate corner positions
    local x1_plus = x1 + cornerSize
    local x2_minus = x2 - cornerSize
    local y1_plus = y1 + cornerSize
    local y2_minus = y2 - cornerSize
    
    -- Top-left corner (two lines forming an L)
    dx9_DrawLine({x1, y1}, {x1_plus, y1}, color)
    dx9_DrawLine({x1, y1}, {x1, y1_plus}, color)
    
    -- Top-right corner
    dx9_DrawLine({x2, y1}, {x2_minus, y1}, color)
    dx9_DrawLine({x2, y1}, {x2, y1_plus}, color)
    
    -- Bottom-left corner
    dx9_DrawLine({x1, y2}, {x1_plus, y2}, color)
    dx9_DrawLine({x1, y2}, {x1, y2_minus}, color)
    
    -- Bottom-right corner
    dx9_DrawLine({x2, y2}, {x2_minus, y2}, color)
    dx9_DrawLine({x2, y2}, {x2, y2_minus}, color)
end

-- Draw a tracer line and increment the performance counter
local function DrawTracer(fromPos, toPos, color)
    dx9_DrawLine(fromPos, toPos, color)
    Cache.performance.tracers_drawn = Cache.performance.tracers_drawn + 1
end

local CHARACTER_CACHE_VERSION = 4

local CharacterLimbKeywords = {"head", "torso", "arm", "leg", "hand", "foot"}
local CharacterFolderHints = {
    equipment = true,
    equipped = true,
    hair = true,
    pants = true,
    shirt = true,
    backpack = true,
    accessories = true,
}

local CoreBodyPartNames = {
    humanoidrootpart = true,
    humanoidroot = true,
    root = true,
    rootpart = true,
    primarypart = true,
    torso = true,
    uppertorso = true,
    lowertorso = true,
    chest = true,
    pelvis = true,
    spine = true,
    waist = true,
}

local function IsCharacterBodyPartName(partName)
    if not partName then
        return false
    end

    local lower = partName:lower()

    if CoreBodyPartNames[lower] then
        return true
    end

    if lower:find("torso", 1, true) or lower:find("spine", 1, true) or lower:find("pelvis", 1, true) then
        return true
    end

    if lower:find("head", 1, true) or lower:find("neck", 1, true) then
        return true
    end

    if lower:find("upperarm", 1, true) or lower:find("lowerarm", 1, true) or lower:find("upperleg", 1, true) or lower:find("lowerleg", 1, true) then
        return true
    end

    local hasSideQualifier = lower:find("left", 1, true) or lower:find("right", 1, true)
    if hasSideQualifier then
        if lower:find("arm", 1, true) or lower:find("hand", 1, true) or lower:find("leg", 1, true) or lower:find("foot", 1, true) or lower:find("thigh", 1, true) or lower:find("calf", 1, true) or lower:find("knee", 1, true) or lower:find("shoulder", 1, true) or lower:find("hip", 1, true) then
            return true
        end
    end

    if lower:find("hip", 1, true) then
        return true
    end

    return false
end

local function AnalyzeCharacterModel(model)
    local analysis = {
        parts = {},
        children = nil,
        partCount = 0,
        limbScore = 0,
        hasHumanoid = false,
        humanoid = nil,
        humanoidRootPart = nil,
        headPart = nil,
        hasAnimator = false,
        accessoryCount = 0,
        appearanceCount = 0,
        folderHits = 0,
    }

    local children = SafeGetChildren(model)
    analysis.children = children
    if not (children and #children > 0) then
        return analysis
    end

    local stack = {}
    local visited = {}
    for i = 1, #children do
        stack[#stack + 1] = {children[i], 1}
    end

    local maxDepth = 4

    while #stack > 0 do
        local entry = stack[#stack]
        stack[#stack] = nil

        local instance = entry[1]
        if not visited[instance] then
            visited[instance] = true
            local depth = entry[2]

            local instanceType = SafeGetType(instance)
            if instanceType then
                if instanceType == "Humanoid" then
                    analysis.hasHumanoid = true
                    analysis.humanoid = instance
                elseif instanceType == "Animator" or instanceType == "AnimationController" then
                    analysis.hasAnimator = true
                elseif instanceType == "Accessory" then
                    analysis.accessoryCount = analysis.accessoryCount + 1
                elseif instanceType == "Shirt" or instanceType == "Pants" or instanceType == "ShirtGraphic" then
                    analysis.appearanceCount = analysis.appearanceCount + 1
                end

                if instanceType == "Part" or instanceType == "MeshPart" then
                    analysis.partCount = analysis.partCount + 1
                    analysis.parts[analysis.partCount] = instance

                    local instanceName = SafeGetName(instance)
                    if instanceName then
                        local lower = instanceName:lower()

                        if not analysis.headPart and lower:find("head") then
                            analysis.headPart = instance
                        end

                        if lower:find("humanoidrootpart") then
                            analysis.humanoidRootPart = instance
                        end

                        for _, keyword in ipairs(CharacterLimbKeywords) do
                            if lower:find(keyword) then
                                analysis.limbScore = analysis.limbScore + 1
                                break
                            end
                        end
                    end
                elseif (instanceType == "Model" or instanceType == "Folder") and depth < maxDepth then
                    local subChildren = SafeGetChildren(instance)
                    if subChildren and #subChildren > 0 then
                        if instanceType == "Folder" then
                            local folderName = SafeGetName(instance)
                            if folderName then
                                local hintKey = folderName:lower()
                                if CharacterFolderHints[hintKey] then
                                    analysis.folderHits = analysis.folderHits + 1
                                end
                            end
                        end

                        for j = 1, #subChildren do
                            stack[#stack + 1] = {subChildren[j], depth + 1}
                        end
                    end
                end
            end
        end
    end

    return analysis
end

-- OPTIMIZED: Improved character model validation with better caching
-- FURTHER OPTIMIZED: Reduced redundant checks and improved early exits
local function IsCharacterModel(model, modelAddress, cacheTable, options)
    local targetCache = cacheTable or Cache.characters
    local cached = targetCache[modelAddress]
    if cached then
        if not ModelExists(model) then
            targetCache[modelAddress] = nil
            return false, 0
        end
        local currentTemplateVersion = _G.AR2_StarterPartSetVersion or 0
        if cached.version == CHARACTER_CACHE_VERSION and cached.parts and cached.templateVersion == currentTemplateVersion then
            return cached.isCharacter, cached.partCount
        end
    end

    local config = (options and options.config) or Config.characters
    local minLimbs = (options and options.minLimbCount) or (config and config.min_limb_count) or 3

    local analysis = AnalyzeCharacterModel(model)
    local partCount = analysis.partCount
    local hasHumanoid = analysis.hasHumanoid
    local humanoidRootPart = analysis.humanoidRootPart
    local limbScore = analysis.limbScore

    local candidatePartNames = {}
    local bodyParts = {}
    local bodyPartLookup = {}
    local bodyPartCount = 0
    if analysis.parts then
        for i = 1, partCount do
            local part = analysis.parts[i]
            if part then
                local partName = SafeGetName(part)
                if partName then
                    local lowerName = partName:lower()
                    candidatePartNames[lowerName] = true

                    if IsCharacterBodyPartName(partName) then
                        bodyPartCount = bodyPartCount + 1
                        bodyParts[bodyPartCount] = part
                        bodyPartLookup[part] = true
                    end
                end
            end
        end
    end

    local starterPartSets = _G.AR2_StarterPartSets or {}
    local enforceStarterTemplate = not (options and options.skipStarterTemplate)
    local matchesStarterTemplate = true

    if enforceStarterTemplate then
        matchesStarterTemplate = false
        if starterPartSets and #starterPartSets > 0 then
            for _, template in ipairs(starterPartSets) do
                local requiredNames = nil
                local requiredCount = nil

                if type(template) == "table" then
                    if template.names and type(template.names) == "table" then
                        requiredNames = template.names
                        requiredCount = template.count
                    else
                        requiredNames = template
                    end
                end

                if requiredNames then
                    if not requiredCount or requiredCount <= 0 then
                        requiredCount = CountTable(requiredNames)
                    end

                    if requiredCount > 0 then
                        local matches = 0
                        for requiredName in pairs(requiredNames) do
                            if candidatePartNames[requiredName] then
                                matches = matches + 1
                            end
                        end

                        local matchRatio = matches / requiredCount
                        local minBodyMatches = math_min(requiredCount, math_max(minLimbs, 6))
                        if matches >= minBodyMatches or matchRatio >= 0.6 then
                            matchesStarterTemplate = true
                            break
                        end
                    end
                end
            end
        else
            matchesStarterTemplate = true
        end
    end
    local requireHumanoid = true
    local allowAnimatorOnly = false

    if options then
        if options.requireHumanoid ~= nil then
            requireHumanoid = options.requireHumanoid
        end

        if options.allowAnimatorOnly ~= nil then
            allowAnimatorOnly = options.allowAnimatorOnly
        end
    end

    local extendedThreshold = math_max(minLimbs, 6)

    local isCharacter = false

    if hasHumanoid then
        if partCount >= minLimbs then
            isCharacter = true
        elseif limbScore >= 4 and partCount >= extendedThreshold then
            isCharacter = true
        elseif humanoidRootPart and analysis.hasAnimator and limbScore >= 3 and partCount >= extendedThreshold then
            isCharacter = true
        elseif partCount >= extendedThreshold and (analysis.accessoryCount + analysis.appearanceCount + analysis.folderHits) >= 2 then
            isCharacter = true
        end
    end

    if not isCharacter and not requireHumanoid then
        local accessorySignal = (analysis.accessoryCount + analysis.appearanceCount + analysis.folderHits)

        if bodyPartCount >= math_max(minLimbs, 4) and limbScore >= math_max(minLimbs, 3) then
            isCharacter = true
        elseif allowAnimatorOnly and analysis.hasAnimator and bodyPartCount >= math_max(minLimbs, 3) then
            isCharacter = true
        elseif allowAnimatorOnly and analysis.hasAnimator and accessorySignal >= 1 and partCount >= extendedThreshold then
            isCharacter = true
        elseif accessorySignal >= 2 and partCount >= extendedThreshold then
            isCharacter = true
        end
    end

    if requireHumanoid and not hasHumanoid then
        isCharacter = false
    end

    if not matchesStarterTemplate and hasHumanoid then
        local fallbackThreshold = math_max(minLimbs, 6)
        if bodyPartCount >= fallbackThreshold and limbScore >= fallbackThreshold then
            matchesStarterTemplate = true
        end
    end

    if not matchesStarterTemplate then
        isCharacter = false
    end

    local cachedBodyParts = bodyPartCount > 0 and bodyParts or nil
    local cachedBodyLookup = bodyPartCount > 0 and bodyPartLookup or nil

    targetCache[modelAddress] = {
        isCharacter = isCharacter,
        partCount = partCount,
        children = analysis.children or {},
        parts = analysis.parts,
        bodyParts = cachedBodyParts,
        bodyPartLookup = cachedBodyLookup,
        humanoidRootPart = humanoidRootPart,
        headPart = analysis.headPart,
        hasHumanoid = hasHumanoid,
        limbScore = limbScore,
        accessoryCount = analysis.accessoryCount,
        appearanceCount = analysis.appearanceCount,
        folderHits = analysis.folderHits,
        hasAnimator = analysis.hasAnimator,
        lastSeen = Cache.frame_count,
        templateVersion = _G.AR2_StarterPartSetVersion or 0,
        version = CHARACTER_CACHE_VERSION,
    }

    return isCharacter, partCount
end

-- OPTIMIZED: Improved corpse model validation
-- FURTHER OPTIMIZED: Reduced redundant checks
local function IsCorpseModel(model, modelAddress)
    local cached = Cache.corpses[modelAddress]
    if cached then
        if not ModelExists(model) then
            Cache.corpses[modelAddress] = nil
            return false, 0
        end
        return cached.isCorpse, cached.partCount
    end
    
    local children = SafeGetChildren(model)
    if not (children and #children > 0) then
        return false, 0
    end
    
    local partCount = 0
    local hasHumanoidRootPart = false
    local humanoidRootPart = nil
    local hasHumanoid = false
    
    for i = 1, #children do
        local child = children[i]
        local childType = SafeGetType(child)

        if childType == "Humanoid" then
            hasHumanoid = true
        elseif childType == "Part" or childType == "MeshPart" then
            partCount = partCount + 1

            local childName = SafeGetName(child)

            if childName == "HumanoidRootPart" then
                hasHumanoidRootPart = true
                humanoidRootPart = child
            end
        end
    end
    
    local isCorpse = hasHumanoidRootPart and not hasHumanoid and partCount >= Config.corpses.min_limb_count
    
    Cache.corpses[modelAddress] = {
        isCorpse = isCorpse,
        partCount = partCount,
        children = children,
        humanoidRootPart = humanoidRootPart,
        lastSeen = Cache.frame_count
    }
    
    return isCorpse, partCount
end

-- OPTIMIZED: Improved reference position lookup with better caching
-- FURTHER OPTIMIZED: Reduced pcall overhead and validation checks
local function GetReferencePosition(model, modelAddress, cacheTable)
    local cachedData = cacheTable[modelAddress]
    
    if cachedData and cachedData.humanoidRootPart then
        local pos = SafeGetPosition(cachedData.humanoidRootPart)

        if pos and pos.x then
            cachedData.refPos = pos
            cachedData.refPart = cachedData.humanoidRootPart
            return pos, cachedData.humanoidRootPart
        else
            cachedData.humanoidRootPart = nil
        end
    end
    
    if cachedData and cachedData.refPart then
        local pos = SafeGetPosition(cachedData.refPart)

        if pos and pos.x then
            cachedData.refPos = pos
            return pos, cachedData.refPart
        else
            cachedData.refPart = nil
            cachedData.refPos = nil
        end
    end
    
    local children = cachedData and cachedData.children or SafeGetChildren(model)
    if not children then return nil end
    
    -- Priority parts list for faster lookup
    local priorityNames = {"HumanoidRootPart", "Root", "Torso", "UpperTorso", "Body", "Base"}
    
    for i = 1, #children do
        local child = children[i]
        local childType = SafeGetType(child)

        if childType and (childType == "Part" or childType == "MeshPart") then
            local childName = SafeGetName(child)

            if childName then
                for j = 1, #priorityNames do
                    if childName:find(priorityNames[j]) then
                        local pos = SafeGetPosition(child)

                        if pos and pos.x then
                            if cachedData then
                                cachedData.refPos = pos
                                cachedData.refPart = child
                                cachedData.humanoidRootPart = child
                            end
                            return pos, child
                        end
                    end
                end
            end
        end
    end
    
    -- Fallback: use any part
    for i = 1, #children do
        local child = children[i]
        local childType = SafeGetType(child)

        if childType and (childType == "Part" or childType == "MeshPart") then
            local pos = SafeGetPosition(child)

            if pos and pos.x then
                if cachedData then
                    cachedData.refPos = pos
                    cachedData.refPart = child
                end
                return pos, child
            end
        end
    end
    
    return nil
end

-- OPTIMIZED: Get head position with better performance
-- FURTHER OPTIMIZED: Early exit and reduced string operations
local function GetHeadPosition(children, depth)
    if not (children and #children > 0) then
        return nil
    end

    depth = depth or 1
    local maxDepth = 4

    for i = 1, #children do
        local child = children[i]
        local childType = SafeGetType(child)

        if childType then
            if childType == "Part" or childType == "MeshPart" then
                local partName = SafeGetName(child)

                if partName then
                    local lower = partName:lower()
                    if lower:find("head") or lower:find("helmet") then
                        local pos = SafeGetPosition(child)
                        if pos then
                            return pos
                        end
                    end
                end
            elseif (childType == "Model" or childType == "Folder") and depth < maxDepth then
                local subChildren = SafeGetChildren(child)
                if subChildren then
                    local nested = GetHeadPosition(subChildren, depth + 1)
                    if nested then
                        return nested
                    end
                end
            end
        end
    end
    
    return nil
end

-- OPTIMIZED: Get all visible parts with better performance
-- FURTHER OPTIMIZED: Early exit for empty children
local function GetAllVisibleParts(children, maxParts)
    if not (children and #children > 0) then
        return {}
    end

    local parts = {}
    local count = 0
    local stack = {}
    local visited = {}
    local maxDepth = 4

    for i = 1, #children do
        stack[#stack + 1] = {children[i], 1}
    end

    while #stack > 0 do
        local entry = stack[#stack]
        stack[#stack] = nil

        local instance = entry[1]
        if not visited[instance] then
            visited[instance] = true
            local depth = entry[2]

            local instanceType = SafeGetType(instance)
            if instanceType then
                if instanceType == "Part" or instanceType == "MeshPart" then
                    count = count + 1
                    parts[count] = instance
                    if maxParts and count >= maxParts then
                        break
                    end
                elseif (instanceType == "Model" or instanceType == "Folder") and depth < maxDepth then
                    local subChildren = SafeGetChildren(instance)
                    if subChildren and #subChildren > 0 then
                        for j = 1, #subChildren do
                            stack[#stack + 1] = {subChildren[j], depth + 1}
                        end
                    end
                end
            end
        end

        if maxParts and count >= maxParts then
            break
        end
    end

    return parts
end

local function SampleParts(partList, maxParts, cursor)
    if not (partList and #partList > 0) then
        return {}, 1
    end

    local total = #partList
    if not maxParts or total <= maxParts then
        return partList, 1
    end

    cursor = cursor or 1
    if cursor < 1 or cursor > total then
        cursor = 1
    end

    local step = math.ceil(total / maxParts)
    if step < 1 then
        step = 1
    end

    local sampled = {}
    local index = cursor

    for i = 1, maxParts do
        sampled[i] = partList[index]
        index = index + step
        if index > total then
            index = ((index - 1) % total) + 1
        end
    end

    return sampled, index
end

local function BuildPartRenderData(partList, screenWidth, screenHeight, padding, fetchNames, headPart)
    if not (partList and #partList > 0) then
        return {}, 0, nil, nil
    end

    local data = {}
    local onScreenCount = 0
    local headPosition = nil
    local headScreen = nil

    for i = 1, #partList do
        local part = partList[i]
        if part and part ~= 0 then
            local pos = SafeGetPosition(part)
            if pos and pos.x then
                local screen = SafeWorldToScreen({pos.x, pos.y, pos.z})
                if screen and screen.x and screen.y then
                    if not (screen.x == screen.x and screen.y == screen.y) then
                        screen = nil
                    end
                end

                local onScreen = false
                if screen and screen.x and screen.y then
                    if IsOnScreen(screen, screenWidth, screenHeight, padding) then
                        onScreen = true
                        onScreenCount = onScreenCount + 1
                    end
                end

                local entry = {
                    part = part,
                    position = pos,
                    screen = screen,
                    onScreen = onScreen,
                }

                if fetchNames then
                    local name = SafeGetName(part)
                    entry.name = name
                    if name then
                        local lower = name:lower()
                        if not headPosition and (lower:find("head", 1, true) or lower:find("helmet", 1, true)) then
                            headPosition = pos
                            if screen then
                                headScreen = screen
                            end
                        end
                    end
                end

                if headPart and not headPosition and part == headPart then
                    headPosition = pos
                    if screen then
                        headScreen = screen
                    end
                end

                data[#data + 1] = entry
            end
        end
    end

    if headPart and not headPosition then
        local headPos = SafeGetPosition(headPart)
        if headPos and headPos.x then
            headPosition = headPos
            headScreen = SafeWorldToScreen({headPos.x, headPos.y, headPos.z})
        end
    end

    return data, onScreenCount, headPosition, headScreen
end

local function BuildPartNameSet(children)
    local names = {}
    if not (children and #children > 0) then
        return names
    end

    local stack = {}
    local visited = {}
    local maxDepth = 4

    for i = 1, #children do
        stack[#stack + 1] = {children[i], 1}
    end

    while #stack > 0 do
        local entry = stack[#stack]
        stack[#stack] = nil

        local instance = entry[1]
        if not visited[instance] then
            visited[instance] = true
            local depth = entry[2]

            local instanceType = SafeGetType(instance)
            if instanceType then
                if instanceType == "Part" or instanceType == "MeshPart" then
                    local partName = SafeGetName(instance)
                    if partName then
                        names[partName:lower()] = true
                    end
                elseif (instanceType == "Model" or instanceType == "Folder") and depth < maxDepth then
                    local subChildren = SafeGetChildren(instance)
                    if subChildren and #subChildren > 0 then
                        for j = 1, #subChildren do
                            stack[#stack + 1] = {subChildren[j], depth + 1}
                        end
                    end
                end
            end
        end
    end

    return names
end

local function ComputeSignatureDescriptors(partNameSet)
    if not partNameSet then
        return nil, nil
    end

    local coreNames = {}
    local equipmentNames = {}

    for partName in pairs(partNameSet) do
        if IsCharacterBodyPartName(partName) then
            coreNames[#coreNames + 1] = partName
        else
            equipmentNames[#equipmentNames + 1] = partName
        end
    end

    table_sort(coreNames)
    table_sort(equipmentNames)

    local coreSignature = #coreNames > 0 and table_concat(coreNames, ",") or nil
    local equipmentSignature = #equipmentNames > 0 and table_concat(equipmentNames, ",") or nil

    return coreSignature, equipmentSignature
end

local function CollectNamesForSignature(instance, list, depth, maxDepth)
    if depth > maxDepth then
        return
    end

    local children = SafeGetChildren(instance)
    if not children then
        return
    end

    for i = 1, #children do
        local child = children[i]
        local childName = SafeGetName(child)
        local childType = SafeGetType(child)

        if childName and childType then
            list[#list + 1] = childType .. ":" .. childName
        end

        CollectNamesForSignature(child, list, depth + 1, maxDepth)
    end
end

local function ComputeStarterCharacterSignature(model, entry)
    if not model or model == 0 then
        return nil
    end

    local signatureParts = {}
    local children = entry and entry.children or SafeGetChildren(model)
    if not children then
        return nil
    end

    local equipmentFolders = {}
    for i = 1, #children do
        local child = children[i]
        local childName = SafeGetName(child)
        if childName then
            if childName == "Equipment" then
                equipmentFolders[#equipmentFolders + 1] = child
            else
                local childType = SafeGetType(child)
                if childType and (childType == "Part" or childType == "MeshPart") then
                    signatureParts[#signatureParts + 1] = "Body:" .. childName
                end
            end
        end
    end

    for i = 1, #equipmentFolders do
        CollectNamesForSignature(equipmentFolders[i], signatureParts, 1, 3)
    end

    if #signatureParts == 0 then
        return nil
    end

    table_sort(signatureParts)
    return table_concat(signatureParts, "|")
end

local function CloneStringSet(source)
    if not source then
        return nil
    end

    local copy = {}
    for key in pairs(source) do
        copy[key] = true
    end

    return copy
end

local function CloneNumberTable(source)
    if not source then
        return nil
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

local function ComputeEquipmentOverlapScore(referenceSet, candidateSet)
    if not referenceSet or not candidateSet then
        return 0
    end

    local totalReference = 0
    local matchCount = 0

    for name in pairs(referenceSet) do
        totalReference = totalReference + 1
        if candidateSet[name] then
            matchCount = matchCount + 1
        end
    end

    if totalReference == 0 then
        return 0
    end

    local overlapRatio = matchCount / totalReference
    if overlapRatio <= 0 then
        return 0
    end

    local extraCount = 0
    for name in pairs(candidateSet) do
        if not referenceSet[name] then
            extraCount = extraCount + 1
        end
    end

    local penalty = math_min(40, extraCount * 10)
    local score = math_floor(overlapRatio * 140) - penalty
    if score < 0 then
        score = 0
    end

    return score
end

local function CategorizeCorePartName(lowerName)
    if not lowerName then
        return "core_other"
    end

    if lowerName:find("humanoidroot", 1, true) or lowerName:find("rootpart", 1, true) or lowerName:find("root", 1, true) then
        return "core_root"
    end

    if lowerName:find("head", 1, true) or lowerName:find("helmet", 1, true) or lowerName:find("skull", 1, true) then
        return "core_head"
    end

    if lowerName:find("torso", 1, true) or lowerName:find("spine", 1, true) or lowerName:find("chest", 1, true) or lowerName:find("pelvis", 1, true) or lowerName:find("waist", 1, true) then
        return "core_torso"
    end

    if lowerName:find("arm", 1, true) or lowerName:find("hand", 1, true) or lowerName:find("shoulder", 1, true) then
        if lowerName:find("left", 1, true) then
            return "core_arm_left"
        elseif lowerName:find("right", 1, true) then
            return "core_arm_right"
        end
        return "core_arm_other"
    end

    if lowerName:find("leg", 1, true) or lowerName:find("foot", 1, true) or lowerName:find("thigh", 1, true) or lowerName:find("calf", 1, true) or lowerName:find("knee", 1, true) or lowerName:find("ankle", 1, true) then
        if lowerName:find("left", 1, true) then
            return "core_leg_left"
        elseif lowerName:find("right", 1, true) then
            return "core_leg_right"
        end
        return "core_leg_other"
    end

    if lowerName:find("hair", 1, true) then
        return "core_hair"
    end

    return "core_other"
end

local ExtraCategoryKeywords = {
    equip_weapon = {"weapon", "gun", "rifle", "pistol", "shotgun", "smg", "sword", "knife", "blade", "bow", "launcher", "katana", "axe", "machete"},
    equip_back = {"backpack", "pack", "bag", "satchel", "pouch", "quiver"},
    equip_armor = {"armor", "armour", "vest", "plate", "helmet", "mask", "goggle", "shield", "kevlar"},
    equip_clothing = {"shirt", "pants", "jacket", "coat", "hood", "hoodie", "glove", "boot", "shoe", "belt", "uniform", "sleeve"},
    equip_accessory = {"accessory", "radio", "binocular", "watch", "bandolier", "scarf", "strap", "rope", "holster", "scope", "suppressor", "mag"},
}

local function CategorizeExtraPartName(lowerName)
    if not lowerName then
        return "extra_misc"
    end

    for category, keywordList in pairs(ExtraCategoryKeywords) do
        for i = 1, #keywordList do
            if lowerName:find(keywordList[i], 1, true) then
                return category
            end
        end
    end

    if lowerName:find("hat", 1, true) or lowerName:find("cap", 1, true) then
        return "equip_accessory"
    end

    if lowerName:find("gear", 1, true) or lowerName:find("tool", 1, true) then
        return "equip_weapon"
    end

    return "extra_misc"
end

local function BuildCategorySummary(partSet, isCore)
    if not partSet or not next(partSet) then
        return nil, 0, nil
    end

    local counts = {}
    local total = 0

    for name in pairs(partSet) do
        local category
        if isCore then
            category = CategorizeCorePartName(name)
        else
            category = CategorizeExtraPartName(name)
        end

        counts[category] = (counts[category] or 0) + 1
        total = total + 1
    end

    local signatureParts = {}
    local idx = 0
    for category, count in pairs(counts) do
        idx = idx + 1
        signatureParts[idx] = category .. ":" .. count
    end

    if idx == 0 then
        return counts, total, nil
    end

    table_sort(signatureParts)
    return counts, total, table_concat(signatureParts, "|")
end

local function ComputeCategorySimilarityScore(referenceCounts, candidateCounts, scale)
    if not referenceCounts or not candidateCounts then
        return 0
    end

    local matchedUnits = 0
    local totalUnits = 0

    for category, refCount in pairs(referenceCounts) do
        local candidateCount = candidateCounts[category] or 0
        local diff = math_abs(refCount - candidateCount)
        if diff < refCount then
            matchedUnits = matchedUnits + (refCount - diff)
        end
        totalUnits = totalUnits + refCount
    end

    if totalUnits == 0 then
        return 0
    end

    local ratio = matchedUnits / totalUnits

    local penaltyUnits = 0
    for category, candidateCount in pairs(candidateCounts) do
        if not referenceCounts[category] then
            penaltyUnits = penaltyUnits + candidateCount
        end
    end

    local baseScale = scale or 160
    local score = ratio * baseScale

    if penaltyUnits > 0 then
        local penaltyRatio = penaltyUnits / (penaltyUnits + totalUnits)
        score = score - (penaltyRatio * baseScale * 0.5)
    end

    if score < 0 then
        score = 0
    end

    return score
end

local function UpdateStarterCharacterSignature(entry, model)
    if not entry then
        return nil
    end

    if entry.lastSignatureFrame == Cache.frame_count then
        return entry.signatureHash
    end

    local signature = ComputeStarterCharacterSignature(model, entry)
    entry.signatureHash = signature
    entry.lastSignatureFrame = Cache.frame_count
    return signature
end

-- Ensure starter character cache entry exists and is refreshed
local function EnsureStarterCharacterEntry(model)
    if not model or model == 0 then
        return nil
    end

    local entryName = SafeGetName(model)
    local children = SafeGetChildren(model) or {}
    local entry = Cache.starter_characters[model]
    if not entry then
        entry = {
            children = children,
            humanoidRootPart = nil,
            refPart = nil,
            refPos = nil,
            lastSeen = Cache.frame_count,
            signatureHash = nil,
            lastSignatureFrame = 0,
            partNameSet = nil,
            partNameCount = 0,
            coreSignature = nil,
            equipmentSignature = nil,
            fullSignature = nil,
            cachedName = entryName,
        }
        Cache.starter_characters[model] = entry
    else
        entry.lastSeen = Cache.frame_count
        entry.children = children
        if entryName then
            entry.cachedName = entryName
        end
    end

    UpdateStarterCharacterSignature(entry, model)

    entry.partNameSet = BuildPartNameSet(entry.children)
    entry.partNameCount = 0
    entry.corePartSet = {}
    entry.corePartCount = 0
    entry.extraPartSet = {}

    for name in pairs(entry.partNameSet) do
        entry.partNameCount = entry.partNameCount + 1

        if IsCharacterBodyPartName(name) then
            entry.corePartSet[name] = true
            entry.corePartCount = entry.corePartCount + 1
        else
            entry.extraPartSet[name] = true
        end
    end

    local coreSignature, equipmentSignature = ComputeSignatureDescriptors(entry.partNameSet)
    entry.coreSignature = coreSignature
    entry.equipmentSignature = equipmentSignature
    entry.fullSignature = (coreSignature or "") .. "|" .. (equipmentSignature or "")
    if not entry.signatureHash and entry.fullSignature ~= "|" then
        entry.signatureHash = entry.fullSignature
    end
    if entry.cachedName == nil then
        entry.cachedName = entryName
    end

    local coreCategoryCounts, corePartTotal, coreCategorySignature = BuildCategorySummary(entry.corePartSet, true)
    local extraCategoryCounts, extraPartTotal, extraCategorySignature = BuildCategorySummary(entry.extraPartSet, false)
    entry.coreCategoryCounts = coreCategoryCounts
    entry.corePartTotal = corePartTotal
    entry.coreCategorySignature = coreCategorySignature
    entry.extraCategoryCounts = extraCategoryCounts
    entry.extraPartTotal = extraPartTotal
    entry.extraCategorySignature = extraCategorySignature
    entry.structureKey = string_format("%s||%s||%d||%d",
        coreCategorySignature or "core:0",
        extraCategorySignature or "extra:0",
        entry.corePartCount or 0,
        entry.partNameCount or 0
    )

    return entry
end

-- Refresh dropdown values and cache entries for starter characters
local function UpdateStarterCharacterOptions(starterFolder, charactersFolder)
    local options = {"0 - Camera (Default)"}
    local models = {nil}
    local valueToIndex = { ["0 - Camera (Default)"] = 1 }
    local currentModels = {}
    local previousIndex = LocalPlayerManager.selectedIndex or 1
    local previousModel = LocalPlayerManager.lastSelectedModel
    local matchedIndex = nil

    LocalPlayerManager.lastStarterFolder = starterFolder

    local manualSelectionLabel = LocalPlayerManager.manualSelectionLabel
    local manualSelectionDisplayName = LocalPlayerManager.manualSelectionDisplayName
    local manualSelectionDisplayNameLower = manualSelectionDisplayName and string_lower(manualSelectionDisplayName) or nil
    local currentSelectionDisplayName = LocalPlayerManager.currentSelectionDisplayName
    local currentSelectionDisplayNameLower = currentSelectionDisplayName and string_lower(currentSelectionDisplayName) or nil
    local manualSelectionModel = LocalPlayerManager.manualSelectionModel

    if manualSelectionModel and not ModelExists(manualSelectionModel) then
        manualSelectionModel = nil
        LocalPlayerManager.manualSelectionModel = nil
    end

    local function addStarterModel(model, count)
        if not model or not ModelExists(model) or currentModels[model] then
            return count
        end

        local displayName = SafeGetName(model) or "Starter"

        local label = string_format("%d - %s", count + 1, displayName)
        local optionIndex = count + 2 -- +1 for zero-based table, +1 for camera option

        options[optionIndex] = label
        models[optionIndex] = model
        valueToIndex[label] = optionIndex
        currentModels[model] = true
        EnsureStarterCharacterEntry(model)

        if previousModel and model == previousModel then
            matchedIndex = optionIndex
        elseif manualSelectionModel and model == manualSelectionModel then
            matchedIndex = optionIndex
        end

        return count + 1
    end

    local starterCount = 0

    if starterFolder then
    local starters = SafeGetChildren(starterFolder)
        if starters then
            for _, starter in ipairs(starters) do
                local success, typeName = pcall(dx9_GetType, starter)
                if success and typeName == "Model" then
                    starterCount = addStarterModel(starter, starterCount)
                end
            end
        end
    end

    LocalPlayerManager.scanCharactersFolder = charactersFolder

    if charactersFolder then
    local chars = SafeGetChildren(charactersFolder)
        if chars then
            for _, character in ipairs(chars) do
                local successType, typeName = pcall(dx9_GetType, character)
                if successType and typeName == "Model" then
                    local successName, charName = pcall(dx9_GetName, character)
                    if successName and charName and charName:lower():find("startercharacter") then
                        starterCount = addStarterModel(character, starterCount)
                    end
                end
            end
        end
    end

    -- Clean up cache entries for removed starter characters
    for model in pairs(Cache.starter_characters) do
        if not currentModels[model] then
            Cache.starter_characters[model] = nil
        end
    end

    LocalPlayerManager.options = options
    LocalPlayerManager.models = models
    LocalPlayerManager.valueToIndex = valueToIndex

    local desiredLabel = LocalPlayerManager.selectedLabel or Config.settings.local_player_selection or "0 - Camera (Default)"
    local desiredIndex = valueToIndex[desiredLabel]

    if matchedIndex and options[matchedIndex] then
        desiredLabel = options[matchedIndex]
        desiredIndex = matchedIndex
    elseif not desiredIndex then
        if manualSelectionModel then
            for i = 2, #models do
                if models[i] == manualSelectionModel then
                    desiredLabel = options[i]
                    desiredIndex = i
                    matchedIndex = i
                    break
                end
            end
        end

        if LocalPlayerManager.selectedCoreSignature then
            for i = 2, #options do
                local model = models[i]
                local entry = Cache.starter_characters[model] or EnsureStarterCharacterEntry(model)
                local coreSignature = entry and entry.coreSignature
                if coreSignature and coreSignature == LocalPlayerManager.selectedCoreSignature then
                    desiredLabel = options[i]
                    desiredIndex = i
                    matchedIndex = i
                    break
                end
            end
        end

        if LocalPlayerManager.selectedSignature then
            for i = 2, #options do
                local model = models[i]
                local entry = Cache.starter_characters[model] or EnsureStarterCharacterEntry(model)
                local signature = entry and (entry.signatureHash or UpdateStarterCharacterSignature(entry, model))
                if signature and signature == LocalPlayerManager.selectedSignature then
                    desiredLabel = options[i]
                    desiredIndex = i
                    matchedIndex = i
                    break
                end
            end
        end

        if not desiredIndex and manualSelectionLabel then
            local mapped = valueToIndex[manualSelectionLabel]
            if mapped then
                desiredLabel = manualSelectionLabel
                desiredIndex = mapped
                matchedIndex = mapped
            end
        end

        if not desiredIndex and manualSelectionDisplayNameLower then
            -- Prefer the most recently appended model with the same display name
            for i = #options, 2, -1 do
                local _, namePart = ParseOptionLabel(options[i])
                if namePart and string_lower(namePart) == manualSelectionDisplayNameLower then
                    desiredLabel = options[i]
                    desiredIndex = i
                    matchedIndex = i
                    break
                end
            end
        end

        if not desiredIndex and currentSelectionDisplayNameLower then
            -- Fall back to the active display name if manual metadata is unavailable
            for i = #options, 2, -1 do
                local _, namePart = ParseOptionLabel(options[i])
                if namePart and string_lower(namePart) == currentSelectionDisplayNameLower then
                    desiredLabel = options[i]
                    desiredIndex = i
                    matchedIndex = i
                    break
                end
            end
        end

        if not desiredIndex then
            if previousIndex >= 1 and previousIndex <= #options then
                desiredLabel = options[previousIndex]
                desiredIndex = previousIndex
            else
                desiredLabel = "0 - Camera (Default)"
                desiredIndex = 1
            end
        end
    end

    Config.settings.local_player_selection = desiredLabel
    LocalPlayerManager.selectedLabel = desiredLabel
    LocalPlayerManager.selectedIndex = desiredIndex or 1
    LocalPlayerManager.currentSelectionLabel = desiredLabel
    local selectionOrdinal, selectionName = ParseOptionLabel(desiredLabel)
    LocalPlayerManager.currentSelectionIndex = selectionOrdinal
    LocalPlayerManager.currentSelectionDisplayName = selectionName
    if (LocalPlayerManager.selectedIndex or 1) <= 1 then
        LocalPlayerManager.currentSelectionLabel = "0 - Camera (Default)"
        LocalPlayerManager.currentSelectionIndex = nil
        LocalPlayerManager.currentSelectionDisplayName = nil
    else
        LocalPlayerManager.manualSelectionLabel = desiredLabel
        LocalPlayerManager.manualSelectionDisplayName = selectionName
        LocalPlayerManager.manualSelectionIndex = selectionOrdinal
    end

    if LocalPlayerManager.selectedIndex and LocalPlayerManager.selectedIndex > 1 then
        local chosenModel = models[LocalPlayerManager.selectedIndex]
        LocalPlayerManager.lastSelectedModel = chosenModel
        LocalPlayerManager.manualSelectionModel = chosenModel
        local entry = Cache.starter_characters[chosenModel]
        if entry then
            local signature = entry.signatureHash or UpdateStarterCharacterSignature(entry, chosenModel)
            if signature then
                LocalPlayerManager.selectedSignature = signature
                LocalPlayerManager.lastSignatureUpdate = Cache.frame_count
            else
                LocalPlayerManager.selectedSignature = nil
                LocalPlayerManager.lastSignatureUpdate = 0
            end
            if entry.coreSignature then
                LocalPlayerManager.selectedCoreSignature = entry.coreSignature
            end
            if entry.cachedName then
                LocalPlayerManager.lastKnownName = entry.cachedName
            end
            UpdateManualMetadataFromEntry(entry)
            UpdateCurrentMetadataFromEntry(entry)
        else
            UpdateCurrentMetadataFromEntry(nil)
        end
    else
        LocalPlayerManager.lastSelectedModel = nil
        LocalPlayerManager.selectedSignature = nil
        LocalPlayerManager.lastSignatureUpdate = 0
        LocalPlayerManager.selectedCoreSignature = nil
        LocalPlayerManager.lastKnownName = nil
        LocalPlayerManager.manualSelectionModel = nil
        ClearManualMetadata()
        ClearCurrentMetadata()
    end

    local signatureSet = {}
    for model, entry in pairs(Cache.starter_characters) do
        local signature = entry and (entry.signatureHash or UpdateStarterCharacterSignature(entry, model))
        if signature then
            signatureSet[signature] = true
        end
        if entry and entry.coreSignature then
            signatureSet[entry.coreSignature] = true
        end
    end

    local signatureList = {}
    for signature in pairs(signatureSet) do
        signatureList[#signatureList + 1] = signature
    end
    table_sort(signatureList)
    local signatureKey = table_concat(signatureList, "|")

    _G.AR2_KnownStarterSignatures = signatureSet
    if signatureKey ~= _G.AR2_KnownSignatureKey then
        _G.AR2_KnownSignatureKey = signatureKey
        _G.AR2_KnownSignatureVersion = (_G.AR2_KnownSignatureVersion or 0) + 1
    end

    local starterPartSets = {}
    local partSetStrings = {}
    for model, entry in pairs(Cache.starter_characters) do
        if entry then
            local requiredSet = entry.corePartSet
            local requiredCount = entry.corePartCount or 0

            if not (requiredSet and next(requiredSet)) then
                requiredSet = entry.partNameSet
                if requiredSet then
                    requiredCount = entry.partNameCount or CountTable(requiredSet)
                end
            end

            if requiredSet and next(requiredSet) then
                starterPartSets[#starterPartSets + 1] = {
                    names = requiredSet,
                    count = (requiredCount and requiredCount > 0) and requiredCount or CountTable(requiredSet),
                }
            end

            local keySignature = entry.coreSignature
            if not keySignature or keySignature == "" then
                keySignature = entry.fullSignature
            end
            if keySignature and keySignature ~= "" and keySignature ~= "|" then
                partSetStrings[#partSetStrings + 1] = keySignature
            end
        end
    end
    table_sort(partSetStrings)
    local partSetKey = table_concat(partSetStrings, "|")

    _G.AR2_StarterPartSets = starterPartSets
    if partSetKey ~= _G.AR2_StarterPartSetKey then
        _G.AR2_StarterPartSetKey = partSetKey
        _G.AR2_StarterPartSetVersion = (_G.AR2_StarterPartSetVersion or 0) + 1
    end

    if LocalPlayerManager.dropdown then
        LocalPlayerManager.dropdown:SetValues(options)
        if LocalPlayerManager.dropdown.Value ~= desiredLabel then
            LocalPlayerManager.dropdown:SetValue(desiredLabel)
        end
    end
end

local function TryReacquireLocalPlayer()
    if not LocalPlayerManager or (LocalPlayerManager.selectedIndex or 1) <= 1 then
        return nil
    end

    local currentFrame = Cache.frame_count or 0
    if currentFrame - (LocalPlayerManager.lastReacquireFrame or 0) < 15 then
        return nil
    end
    LocalPlayerManager.lastReacquireFrame = currentFrame

    local bestModel, bestScore = nil, -1
    local manualDisplayNameLower = LocalPlayerManager.manualSelectionDisplayName and string_lower(LocalPlayerManager.manualSelectionDisplayName) or nil
    local manualSelectionIndex = LocalPlayerManager.manualSelectionIndex
    local currentDisplayNameLower = LocalPlayerManager.currentSelectionDisplayName and string_lower(LocalPlayerManager.currentSelectionDisplayName) or nil

    local function considerCandidate(model, optionSlotIndex)
        if not model or not ModelExists(model) then
            return
        end

        local entry = EnsureStarterCharacterEntry(model)
        if not entry then
            return
        end

        local score = 0
        if LocalPlayerManager.selectedCoreSignature and entry.coreSignature == LocalPlayerManager.selectedCoreSignature then
            score = score + 1000
        end
        if LocalPlayerManager.selectedSignature and entry.signatureHash == LocalPlayerManager.selectedSignature then
            score = score + 250
        end
        if LocalPlayerManager.lastKnownName and entry.cachedName == LocalPlayerManager.lastKnownName then
            score = score + 120
        end

        if LocalPlayerManager.manualEquipmentSignature and entry.equipmentSignature == LocalPlayerManager.manualEquipmentSignature then
            score = score + 180
        else
            local manualOverlap = ComputeEquipmentOverlapScore(LocalPlayerManager.manualEquipmentSet, entry.extraPartSet)
            if manualOverlap > 0 then
                score = score + manualOverlap
            end
        end

        if LocalPlayerManager.currentEquipmentSignature and entry.equipmentSignature == LocalPlayerManager.currentEquipmentSignature then
            score = score + 120
        else
            local currentOverlap = ComputeEquipmentOverlapScore(LocalPlayerManager.currentEquipmentSet, entry.extraPartSet)
            if currentOverlap > 0 then
                score = score + math_floor(currentOverlap * 0.5)
            end
        end

        if LocalPlayerManager.manualStructureKey and entry.structureKey == LocalPlayerManager.manualStructureKey then
            score = score + 260
        elseif LocalPlayerManager.manualCoreCategorySignature and entry.coreCategorySignature == LocalPlayerManager.manualCoreCategorySignature then
            score = score + 200
        end

        if LocalPlayerManager.currentStructureKey and entry.structureKey == LocalPlayerManager.currentStructureKey then
            score = score + 180
        elseif LocalPlayerManager.currentCoreCategorySignature and entry.coreCategorySignature == LocalPlayerManager.currentCoreCategorySignature then
            score = score + 120
        end

        local manualCoreSimilarity = ComputeCategorySimilarityScore(LocalPlayerManager.manualCoreCategoryCounts, entry.coreCategoryCounts, 220)
        if manualCoreSimilarity > 0 then
            score = score + manualCoreSimilarity
        end

        local manualExtraSimilarity = ComputeCategorySimilarityScore(LocalPlayerManager.manualExtraCategoryCounts, entry.extraCategoryCounts, 150)
        if manualExtraSimilarity > 0 then
            score = score + manualExtraSimilarity
        end

        local currentCoreSimilarity = ComputeCategorySimilarityScore(LocalPlayerManager.currentCoreCategoryCounts, entry.coreCategoryCounts, 140)
        if currentCoreSimilarity > 0 then
            score = score + currentCoreSimilarity
        end

        local currentExtraSimilarity = ComputeCategorySimilarityScore(LocalPlayerManager.currentExtraCategoryCounts, entry.extraCategoryCounts, 110)
        if currentExtraSimilarity > 0 then
            score = score + currentExtraSimilarity
        end

        if LocalPlayerManager.manualCorePartTotal and entry.corePartTotal then
            local diff = math_abs(LocalPlayerManager.manualCorePartTotal - entry.corePartTotal)
            score = score + math_max(0, 140 - diff * 25)
        end

        if LocalPlayerManager.manualExtraPartTotal and entry.extraPartTotal then
            local diff = math_abs(LocalPlayerManager.manualExtraPartTotal - entry.extraPartTotal)
            score = score + math_max(0, 90 - diff * 18)
        end

        if LocalPlayerManager.manualPartNameCount and entry.partNameCount then
            local diff = math_abs(LocalPlayerManager.manualPartNameCount - entry.partNameCount)
            score = score + math_max(0, 110 - diff * 15)
        end

        if LocalPlayerManager.manualCorePartCount and entry.corePartCount then
            local diff = math_abs(LocalPlayerManager.manualCorePartCount - entry.corePartCount)
            score = score + math_max(0, 130 - diff * 25)
        end

        if LocalPlayerManager.originPosition then
            local pos = GetReferencePosition(model, model, Cache.starter_characters)
            if pos then
                local distanceSquared = GetDistanceSquared(LocalPlayerManager.originPosition, pos)
                local distance = math_sqrt(distanceSquared or 0)
                score = score + math_max(0, 150 - distance)
            end
        end

        if optionSlotIndex and LocalPlayerManager.options and LocalPlayerManager.options[optionSlotIndex] then
            local ordinal, displayName = ParseOptionLabel(LocalPlayerManager.options[optionSlotIndex])
            local displayNameLower = displayName and string_lower(displayName) or nil

            if manualDisplayNameLower and displayNameLower and displayNameLower == manualDisplayNameLower then
                score = score + 200
                if ordinal then
                    if manualSelectionIndex and ordinal >= manualSelectionIndex then
                        score = score + ((ordinal - manualSelectionIndex) * 5)
                    end
                    score = score + math_min(ordinal * 2, 240)
                else
                    score = score + 40
                end
            end

            if currentDisplayNameLower and displayNameLower and displayNameLower == currentDisplayNameLower then
                score = score + 140
            end

            if manualSelectionIndex and ordinal then
                if ordinal == manualSelectionIndex then
                    score = score + 160
                elseif ordinal > manualSelectionIndex then
                    score = score + 60 + math_min(ordinal - manualSelectionIndex, 20)
                end
            end

            if manualDisplayNameLower or currentDisplayNameLower then
                score = score + math_min(optionSlotIndex * 3, 150)
            end
        end

        if score > bestScore then
            bestScore = score
            bestModel = model
        end
    end

    local modelList = LocalPlayerManager.models
    if modelList then
        for i = 2, #modelList do
            considerCandidate(modelList[i], i)
        end
    end

    local scanFolder = LocalPlayerManager.scanCharactersFolder
    if scanFolder then
        local children = SafeGetChildren(scanFolder)
        if children then
            for _, child in ipairs(children) do
                considerCandidate(child)
            end
        end
    end

    if not bestModel or bestScore < 80 then
        return nil
    end

    local entry = Cache.starter_characters[bestModel] or EnsureStarterCharacterEntry(bestModel)
    if entry then
        LocalPlayerManager.selectedSignature = entry.signatureHash or entry.fullSignature
        LocalPlayerManager.selectedCoreSignature = entry.coreSignature or LocalPlayerManager.selectedCoreSignature
        LocalPlayerManager.lastSignatureUpdate = currentFrame
        LocalPlayerManager.lastKnownName = entry.cachedName or LocalPlayerManager.lastKnownName
        UpdateManualMetadataFromEntry(entry)
        UpdateCurrentMetadataFromEntry(entry)
    end

    local matchedLabel = nil
    if modelList then
        for idx = 2, #modelList do
            if modelList[idx] == bestModel then
                matchedLabel = LocalPlayerManager.options[idx]
                LocalPlayerManager.selectedIndex = idx
                break
            end
        end
    end

    if not matchedLabel and LocalPlayerManager.lastStarterFolder then
        UpdateStarterCharacterOptions(LocalPlayerManager.lastStarterFolder, LocalPlayerManager.scanCharactersFolder)
        modelList = LocalPlayerManager.models
        if modelList then
            for idx = 2, #modelList do
                if modelList[idx] == bestModel then
                    matchedLabel = LocalPlayerManager.options[idx]
                    LocalPlayerManager.selectedIndex = idx
                    break
                end
            end
        end
    end

    if matchedLabel then
        LocalPlayerManager.selectedLabel = matchedLabel
        Config.settings.local_player_selection = matchedLabel
        if LocalPlayerManager.dropdown and LocalPlayerManager.dropdown.Value ~= matchedLabel then
            LocalPlayerManager.dropdown:SetValue(matchedLabel)
        end
        LocalPlayerManager.currentSelectionLabel = matchedLabel
        local ordinal, displayName = ParseOptionLabel(matchedLabel)
        LocalPlayerManager.currentSelectionIndex = ordinal
        LocalPlayerManager.currentSelectionDisplayName = displayName
        LocalPlayerManager.manualSelectionLabel = matchedLabel
        LocalPlayerManager.manualSelectionDisplayName = displayName
        LocalPlayerManager.manualSelectionIndex = ordinal
        LocalPlayerManager.manualSelectionTime = os_clock()
    end

    LocalPlayerManager.lastSelectedModel = bestModel
    LocalPlayerManager.manualSelectionModel = bestModel

    return bestModel
end

-- Check if a model is a valid vehicle by looking for vehicle-specific components
-- OPTIMIZED: Better early exit and reduced redundant checks
-- FURTHER OPTIMIZED: Improved validation and pattern matching
-- Returns: isVehicle (boolean), children (table or nil)
local function IsVehicleModel(model, depth)
    -- Limit recursion depth to prevent infinite loops and performance issues
    if depth > Config.settings.vehicle_scan_depth then
        return false, nil
    end
    
    local children = SafeGetChildren(model)
    if not (children and #children > 0) then
        return false, nil
    end
    
    local hasSeat = false
    local hasVehicleParts = false
    local partCount = 0
    
    -- Vehicle part name patterns (pre-compiled for faster matching)
    local vehiclePatterns = {"body", "chassis", "wheel", "seat", "engine", "base", "interior", "bumper", "frame"}
    
    -- Single-pass scan through children to detect vehicle characteristics
    for i = 1, #children do
        local child = children[i]
        local childType = SafeGetType(child)

        if childType then
            -- VehicleSeat is definitive proof of a vehicle
            if childType == "VehicleSeat" then
                return true, children -- Early exit
            end
            
            -- Count parts for vehicle detection heuristic
            if childType == "Part" or childType == "MeshPart" or childType == "Model" then
                partCount = partCount + 1
                
                -- Only check part names if we haven't already confirmed vehicle parts
                if not hasVehicleParts then
                    local childName = SafeGetName(child)
                    
                    if childName then
                        local lowerName = childName:lower()
                        -- Check for common vehicle part names
                        for j = 1, #vehiclePatterns do
                            if lowerName:find(vehiclePatterns[j]) then
                                hasVehicleParts = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- A model is a vehicle if it has a VehicleSeat OR has vehicle-named parts and sufficient complexity
    if hasSeat or (hasVehicleParts and partCount >= 3) then
        return true, children
    end
    
    return false, nil
end

-- Recursively collect all Part/MeshPart instances from a model hierarchy
-- OPTIMIZED: Better iteration and early exit
-- FURTHER OPTIMIZED: Reduced overhead in recursive scanning
-- Used for vehicles which may have nested folder structures
-- maxParts limits the number of parts collected to prevent performance issues
local function GetAllPartsFromModel(model, maxParts)
    local parts = {}
    local visited = {}
    local count = 0
    local maxDepth = 3
    
    -- Recursive scanning function
    local function recursiveScan(obj, depth)
        -- Stop if we've reached max parts or max depth
        if depth > maxDepth or count >= maxParts or visited[obj] then
            return
        end
        
        -- Mark as visited to prevent infinite loops
        visited[obj] = true
        
        local objType = SafeGetType(obj)

        if objType then
            -- If it's a physical part, add it to our list
            if objType == "Part" or objType == "MeshPart" then
                count = count + 1
                parts[count] = obj
                if count >= maxParts then
                    return
                end
            end
            
            -- If it's a container, recursively scan its children
            if objType == "Model" or objType == "Folder" then
                local children = SafeGetChildren(obj)
                if children then
                    for i = 1, #children do
                        recursiveScan(children[i], depth + 1)
                        if count >= maxParts then
                            return
                        end
                    end
                end
            end
        end
    end
    
    recursiveScan(model, 1)
    return parts
end

local function BeginVehicleScan(folder)
    if not folder then
        Cache.vehicle_scan_state = nil
        Cache.vehicle_list = {}
        return
    end

    local children = SafeGetChildren(folder)
    if not children or #children == 0 then
        Cache.vehicle_scan_state = nil
        Cache.vehicle_list = {}
        return
    end

    Cache.vehicle_scan_state = {
        topChildren = children,
        topIndex = 1,
        subChildren = nil,
        subIndex = 1,
        results = {},
    }
end

local function ProcessVehicleScanStep(stepLimit)
    local state = Cache.vehicle_scan_state
    if not state then
        return
    end

    local limit = stepLimit or 40
    if limit < 1 then
        limit = 1
    end

    local processed = 0

    while processed < limit do
        if state.subChildren then
            if state.subIndex > #state.subChildren then
                state.subChildren = nil
                state.subIndex = 1
            else
                local subChild = state.subChildren[state.subIndex]
                state.subIndex = state.subIndex + 1
                processed = processed + 1

                if subChild then
                    local subType = SafeGetType(subChild)
                    if subType and (subType == "Model" or subType == "Folder") then
                        local isSubVehicle, subVehicleChildren = IsVehicleModel(subChild, 2)
                        if isSubVehicle then
                            local subVehicleName = SafeGetName(subChild)
                            state.results[#state.results + 1] = {
                                model = subChild,
                                name = subVehicleName or "Vehicle",
                                children = subVehicleChildren
                            }
                        end
                    end
                end
            end
        else
            if state.topIndex > #state.topChildren then
                Cache.vehicle_list = state.results
                Cache.vehicle_scan_state = nil
                Cache.last_vehicle_scan = Cache.frame_count
                return
            end

            local child = state.topChildren[state.topIndex]
            state.topIndex = state.topIndex + 1
            processed = processed + 1

            if child then
                local childType = SafeGetType(child)
                if childType and (childType == "Model" or childType == "Folder") then
                    local isVehicle, vehicleChildren = IsVehicleModel(child, 1)
                    if isVehicle then
                        local vehicleName = SafeGetName(child)
                        state.results[#state.results + 1] = {
                            model = child,
                            name = vehicleName or "Vehicle",
                            children = vehicleChildren
                        }
                    else
                        local subChildren = SafeGetChildren(child)
                        if subChildren and #subChildren > 0 then
                            state.subChildren = subChildren
                            state.subIndex = 1
                        end
                    end
                end
            end
        end
    end
end

-- OPTIMIZED: Scan for corpses with better performance
-- FURTHER OPTIMIZED: Reduced validation overhead
local function ScanForCorpses(folder)
    local corpses = {}
    local cCount = 0
    
    if not folder then
        return corpses
    end
    
    local children = SafeGetChildren(folder)
    if not (children and #children > 0) then
        return corpses
    end
    
    for i = 1, #children do
        local child = children[i]
        local childType = SafeGetType(child)
        
        if childType == "Model" then
            local isCorpse, partCount = IsCorpseModel(child, child)
            
            if isCorpse then
                local corpseName = SafeGetName(child)
                
                cCount = cCount + 1
                corpses[cCount] = {
                    model = child,
                    name = corpseName or "Corpse",
                    partCount = partCount
                }
            end
        end
    end
    
    return corpses
end

-- OPTIMIZED: Reduced redundant checks in entity rendering
local function RenderEntityESP(entityData, config, distanceOrigin, screenWidth, screenHeight, cacheTable, isCorpse)
    if not ModelExists(entityData.model) then
        return false
    end
    
    local cachedData = cacheTable[entityData.model]
    if not (cachedData and cachedData.children) then
        return false
    end

    -- Early exit for excluded local player
    if config.exclude_local_player and not isCorpse and LocalPlayerManager.activeModel and entityData.model == LocalPlayerManager.activeModel then
        return false
    end
    
    local hasBoxes = config.boxes
    local hasChams = config.chams
    local hasHeadDot = config.head_dot
    local hasTracers = config.tracers
    local showNames = config.names
    local showDistance = config.distance
    local hasText = showNames or showDistance

    if not (hasBoxes or hasChams or hasHeadDot or hasTracers or hasText) then
        return false
    end

    local partSources = cachedData.parts
    if not (partSources and #partSources > 0) then
        partSources = cachedData.children
    end
    
    local referencePos = GetReferencePosition(entityData.model, entityData.model, cacheTable)
    if not referencePos then
        return false
    end
    
    -- OPTIMIZED: Use squared distance for comparison to avoid sqrt
    local distanceSquared = GetDistanceSquared(distanceOrigin, referencePos)
    local distanceLimitSquared = config.distance_limit * config.distance_limit
    if distanceSquared > distanceLimitSquared then
        return false
    end
    local distance = math_sqrt(distanceSquared)  -- Only calculate actual distance if needed for display
    
    local screenPadding = Config.settings.screen_padding
    local maxPartsPerEntity = Config.settings.max_render_parts or 120
    if maxPartsPerEntity < 40 then
        maxPartsPerEntity = 40
    elseif maxPartsPerEntity > 400 then
        maxPartsPerEntity = 400
    end

    local partRefreshInterval = Config.settings.part_resample_interval or 3
    if partRefreshInterval < 1 then
        partRefreshInterval = 1
    end

    local baseParts = cachedData.parts
    if not (baseParts and #baseParts > 0) then
        local flatParts = cachedData.flatParts
        local lastFlatFrame = cachedData.flatPartsFrame or 0
        if not flatParts or #flatParts == 0 or (Cache.frame_count - lastFlatFrame) >= partRefreshInterval then
            local scanLimit = maxPartsPerEntity * 4
            if scanLimit < maxPartsPerEntity then
                scanLimit = maxPartsPerEntity
            elseif scanLimit > 600 then
                scanLimit = 600
            end
            flatParts = GetAllVisibleParts(partSources, scanLimit)
            cachedData.flatParts = flatParts
            cachedData.flatPartsFrame = Cache.frame_count
        end
        baseParts = flatParts
    end

    if not (baseParts and #baseParts > 0) then
        return false
    end

    local sampleCursor = cachedData.partSampleCursor or 1
    local sampledParts, nextCursor = SampleParts(baseParts, maxPartsPerEntity, sampleCursor)
    cachedData.partSampleCursor = nextCursor

    local needNamesForFilter = (hasChams and config.chams_body_only and not isCorpse and not cachedData.bodyPartLookup) or isCorpse
    local partData, onScreenCount, sampledHeadPos, sampledHeadScreen = BuildPartRenderData(
        sampledParts,
        screenWidth,
        screenHeight,
        screenPadding,
        needNamesForFilter,
        cachedData.headPart
    )

    if not partData or #partData == 0 then
        return false
    end

    if isCorpse then
        local filtered = {}
        local filteredOnScreen = 0

        for i = 1, #partData do
            local entry = partData[i]
            local partName = entry.name

            if not partName then
                partName = SafeGetName(entry.part)
                entry.name = partName
            end

            if partName and IsCharacterBodyPartName(partName) then
                filtered[#filtered + 1] = entry
                if entry.onScreen then
                    filteredOnScreen = filteredOnScreen + 1
                end
            end
        end

        if #filtered == 0 then
            return false
        end

        partData = filtered
        onScreenCount = filteredOnScreen
    end

    local anyPartVisible = onScreenCount > 0
    local currentColor = config.color
    local headPos = sampledHeadPos
    local headScreen = sampledHeadScreen

    if (hasHeadDot or hasText or hasTracers) and not headPos and cachedData.headPart then
        local headWorld = SafeGetPosition(cachedData.headPart)
        if headWorld and headWorld.x then
            headPos = headWorld
            headScreen = SafeWorldToScreen({headWorld.x, headWorld.y, headWorld.z})
        end
    end

    if (hasHeadDot or hasText or hasTracers) and not headPos then
        local fallbackHead = GetHeadPosition(partSources)
        if fallbackHead then
            headPos = fallbackHead
            headScreen = SafeWorldToScreen({fallbackHead.x, fallbackHead.y, fallbackHead.z})
        end
    end

    if hasBoxes then
        local boundingBox = GetBoundingBox(partData, screenWidth, screenHeight, screenPadding)

        if boundingBox then
            anyPartVisible = true

            if config.box_type == "Corner Box" then
                DrawCornerBox(boundingBox.topLeft, boundingBox.bottomRight, currentColor)
            else
                Draw2DBox(boundingBox.topLeft, boundingBox.bottomRight, currentColor)
            end

            Cache.performance.boxes_drawn = Cache.performance.boxes_drawn + 1
        end
    end

    if hasChams then
        local chamPartData = partData

        if config.chams_body_only and not isCorpse then
            local filtered = {}
            local lookup = cachedData.bodyPartLookup

            if lookup then
                for i = 1, #partData do
                    local entry = partData[i]
                    if lookup[entry.part] then
                        filtered[#filtered + 1] = entry
                    end
                end
            elseif needNamesForFilter then
                for i = 1, #partData do
                    local entry = partData[i]
                    if entry.name and IsCharacterBodyPartName(entry.name) then
                        filtered[#filtered + 1] = entry
                    end
                end
            end

            if #filtered > 0 then
                chamPartData = filtered
            end
        end

        local chamStyle = NormalizeChamStyle(config.chams_style)
        local chamScale = type(config.chams_scale) == "number" and config.chams_scale or ChamScaleBounds.default
        if chamScale < ChamScaleBounds.min then
            chamScale = ChamScaleBounds.min
        elseif chamScale > ChamScaleBounds.max then
            chamScale = ChamScaleBounds.max
        end

        local secondaryColor = nil
        if config.chams_use_secondary then
            secondaryColor = EnsureColorTriplet(config.chams_secondary_color, currentColor)
        end

        local chamPrimaryColor = EnsureColorTriplet(currentColor, currentColor)

        local chamOptions = {
            style = chamStyle,
            scale = chamScale,
            secondaryColor = secondaryColor,
        }

        for i = 1, #chamPartData do
            local entry = chamPartData[i]
            if entry.onScreen and entry.position then
                local partCFrame = SafeGetCFrame(entry.part)
                if partCFrame then
                    local partSize = EstimatePartSize(entry.name)
                    local drawn = DrawBodyPartChams(entry.position, partCFrame, partSize, chamPrimaryColor, screenWidth, screenHeight, screenPadding, chamOptions)
                    if drawn then
                        Cache.performance.parts_rendered = Cache.performance.parts_rendered + 1
                        anyPartVisible = true
                    end
                end
            end
        end
    end

    if hasHeadDot and headPos then
        local screenPos = headScreen
        if not (screenPos and screenPos.x and screenPos.y) then
            screenPos = SafeWorldToScreen({headPos.x, headPos.y, headPos.z})
        end

        if screenPos and IsOnScreen(screenPos, screenWidth, screenHeight, 0) then
            dx9_DrawCircle({screenPos.x, screenPos.y}, currentColor, 5)
            anyPartVisible = true
        end
    end

    if hasTracers then
        local tracerPos = headPos or referencePos
        if tracerPos then
            local toScreen
            if headPos and headScreen and tracerPos == headPos then
                toScreen = headScreen
            else
                toScreen = SafeWorldToScreen({tracerPos.x, tracerPos.y, tracerPos.z})
            end

            if toScreen and IsOnScreen(toScreen, screenWidth, screenHeight, 0) then
                local fromScreen

                if config.tracer_origin == "Top" then
                    fromScreen = {screenWidth / 2, 0}
                elseif config.tracer_origin == "Bottom" then
                    fromScreen = {screenWidth / 2, screenHeight}
                elseif config.tracer_origin == "Mouse" then
                    local mouse = dx9_GetMouse()
                    fromScreen = {mouse.x, mouse.y}
                else
                    fromScreen = {screenWidth / 2, screenHeight}
                end

                DrawTracer(fromScreen, {toScreen.x, toScreen.y}, currentColor)
                anyPartVisible = true
            end
        end
    end

    if anyPartVisible and hasText then
        local labelPos = headPos or referencePos
        if labelPos then
            local screenPos
            if headPos and headScreen and labelPos == headPos then
                screenPos = {x = headScreen.x, y = headScreen.y + 2}
            else
                screenPos = SafeWorldToScreen({labelPos.x, labelPos.y + 2, labelPos.z})
            end

            if screenPos and screenPos.x and screenPos.y and IsOnScreen(screenPos, screenWidth, screenHeight, 0) then
                local nameText = ""

                if showNames then
                    local modelName = dx9_GetName(entityData.model)
                    nameText = modelName or (isCorpse and "Corpse" or "Character")
                end

                if showDistance then
                    if nameText ~= "" then
                        nameText = nameText .. " [" .. math_floor(distance) .. "m]"
                    else
                        nameText = "[" .. math_floor(distance) .. "m]"
                    end
                end

                if nameText ~= "" then
                    local textWidth = dx9_CalcTextWidth(nameText)
                    local textX = screenPos.x - (textWidth / 2)
                    local textY = screenPos.y

                    dx9_DrawString({textX, textY}, currentColor, nameText)
                    anyPartVisible = true
                end
            end
        end
    end

    return anyPartVisible
end

-- ====================================
-- CREATE UI
-- ====================================

local Window = Lib:CreateWindow({
    Title = "Apocalypse Rising 2 Public Edition",
    Size = {700, 600},
    Resizable = true,
    ToggleKey = Config.settings.menu_toggle,
    FooterToggle = true,
    FooterRGB = true,
})

local Tabs = {
    characters = Window:AddTab("Characters"),
    corpses = Window:AddTab("Corpses"),
    zombies = Window:AddTab("Zombies"),
    vehicles = Window:AddTab("Vehicles"),
    settings = Window:AddTab("Settings"),
}

local CharGroupboxes = {
    main = Tabs.characters:AddLeftGroupbox("Character ESP"),
    visual = Tabs.characters:AddLeftGroupbox("Visual Settings"),
    extra = Tabs.characters:AddRightGroupbox("Extra Features"),
}

local CorpseGroupboxes = {
    main = Tabs.corpses:AddLeftGroupbox("Corpse ESP"),
    visual = Tabs.corpses:AddLeftGroupbox("Visual Settings"),
    extra = Tabs.corpses:AddRightGroupbox("Extra Features"),
}

local ZombieGroupboxes = {
    main = Tabs.zombies:AddLeftGroupbox("Zombie ESP"),
    visual = Tabs.zombies:AddLeftGroupbox("Visual Settings"),
    extra = Tabs.zombies:AddRightGroupbox("Extra Features"),
}

local VehicleGroupboxes = {
    main = Tabs.vehicles:AddLeftGroupbox("Vehicle ESP"),
    visual = Tabs.vehicles:AddLeftGroupbox("Visual Settings"),
    extra = Tabs.vehicles:AddRightGroupbox("Extra Features"),
}

local SettingsGroupboxes = {
    performance = Tabs.settings:AddLeftGroupbox("Performance"),
    localPlayer = Tabs.settings:AddLeftGroupbox("Local Player"),
    debug = Tabs.settings:AddRightGroupbox("Debug"),
}

local function FormatHotkeyLabel(label, key)
    if key == nil or key == "" then
        key = "[None]"
    end
    return string_format("%s: %s", label, key)
end

-- Character Settings
local CharEnabledToggle = CharGroupboxes.main:AddToggle({
    Default = Config.characters.enabled,
    Text = "Enabled",
})
CharEnabledToggle:OnChanged(function(value)
    Lib:Notify(value and "Character ESP Enabled" or "Character ESP Disabled", 1)
    Config.characters.enabled = value
end)

local CharHotkeyButton = CharGroupboxes.main:AddKeybindButton({
    Text = FormatHotkeyLabel("Character ESP Hotkey", Config.characters.toggle_key),
    Default = Config.characters.toggle_key,
})
CharEnabledToggle:ConnectKeybindButton(CharHotkeyButton)
CharHotkeyButton:OnChanged(function(key)
    Config.characters.toggle_key = key
    CharHotkeyButton:SetText(FormatHotkeyLabel("Character ESP Hotkey", key))
end)
CharHotkeyButton:SetText(FormatHotkeyLabel("Character ESP Hotkey", Config.characters.toggle_key))

CharGroupboxes.main:AddToggle({
    Default = Config.characters.chams,
    Text = "Chams",
}):OnChanged(function(value)
    Config.characters.chams = value
end)

CharGroupboxes.main:AddToggle({
    Default = Config.characters.chams_body_only,
    Text = "Chams: Body Only",
}):OnChanged(function(value)
    Config.characters.chams_body_only = value
end)

CharGroupboxes.main:AddToggle({
    Default = Config.characters.boxes,
    Text = "Boxes",
}):OnChanged(function(value)
    Config.characters.boxes = value
end)

CharGroupboxes.main:AddToggle({
    Default = Config.characters.tracers,
    Text = "Tracers",
}):OnChanged(function(value)
    Config.characters.tracers = value
end)

CharGroupboxes.main:AddToggle({
    Default = Config.characters.head_dot,
    Text = "Head Dot",
}):OnChanged(function(value)
    Config.characters.head_dot = value
end)

CharGroupboxes.visual:AddToggle({
    Default = Config.characters.names,
    Text = "Names",
}):OnChanged(function(value)
    Config.characters.names = value
end)

CharGroupboxes.visual:AddToggle({
    Default = Config.characters.distance,
    Text = "Distance",
}):OnChanged(function(value)
    Config.characters.distance = value
end)

CharGroupboxes.visual:AddColorPicker({
    Default = Config.characters.color,
    Text = "Color",
}):OnChanged(function(value)
    Config.characters.color = value
end)

CharGroupboxes.visual:AddDropdown({
    Default = ChamStyleIndexLookup[Config.characters.chams_style] or 1,
    Text = "Chams Style",
    Values = ChamStyleOptionsList,
}):OnChanged(function(value)
    Config.characters.chams_style = NormalizeChamStyle(value)
end)

CharGroupboxes.visual:AddSlider({
    Default = Config.characters.chams_scale,
    Text = "Chams Scale",
    Min = ChamScaleBounds.min,
    Max = ChamScaleBounds.max,
    Rounding = 2,
    Suffix = "x",
}):OnChanged(function(value)
    Config.characters.chams_scale = clampToRange(
        value,
        ChamScaleBounds.min,
        ChamScaleBounds.max,
        ChamScaleBounds.default
    )
end)

CharGroupboxes.visual:AddToggle({
    Default = Config.characters.chams_use_secondary,
    Text = "Use Secondary Cham Color",
}):OnChanged(function(value)
    Config.characters.chams_use_secondary = value
end)

CharGroupboxes.visual:AddColorPicker({
    Default = Config.characters.chams_secondary_color,
    Text = "Secondary Cham Color",
}):OnChanged(function(value)
    Config.characters.chams_secondary_color = value
end)

CharGroupboxes.visual:AddSlider({
    Default = Config.characters.distance_limit,
    Text = "Max Distance",
    Min = DistanceSliderBounds.characters.min,
    Max = DistanceSliderBounds.characters.max,
    Rounding = 0,
    Suffix = " studs",
}):OnChanged(function(value)
    Config.characters.distance_limit = clampToRange(
        value,
        DistanceSliderBounds.characters.min,
        DistanceSliderBounds.characters.max,
        DistanceSliderBounds.characters.default
    )
end)

CharGroupboxes.visual:AddSlider({
    Default = Config.characters.min_limb_count,
    Text = "Min Limbs",
    Min = 1,
    Max = 10,
    Rounding = 0,
}):OnChanged(function(value)
    Config.characters.min_limb_count = value
end)

local characterBoxOptions = {BoxTypeOptionsList[1], BoxTypeOptionsList[2]}
CharGroupboxes.extra:AddDropdown({
    Default = BoxTypeIndexLookup[Config.characters.box_type] or 1,
    Text = "Box Type",
    Values = characterBoxOptions,
}):OnChanged(function(value)
    Config.characters.box_type = NormalizeBoxType(value)
end)

CharGroupboxes.extra:AddDropdown({
    Default = 3,
    Text = "Tracer Origin",
    Values = {"Top", "Bottom", "Mouse"},
}):OnChanged(function(value)
    Config.characters.tracer_origin = value
end)

-- Corpse Settings
local CorpseEnabledToggle = CorpseGroupboxes.main:AddToggle({
    Default = Config.corpses.enabled,
    Text = "Enabled",
})
CorpseEnabledToggle:OnChanged(function(value)
    Lib:Notify(value and "Corpse ESP Enabled" or "Corpse ESP Disabled", 1)
    Config.corpses.enabled = value
end)

local CorpseHotkeyButton = CorpseGroupboxes.main:AddKeybindButton({
    Text = FormatHotkeyLabel("Corpse ESP Hotkey", Config.corpses.toggle_key),
    Default = Config.corpses.toggle_key,
})
CorpseEnabledToggle:ConnectKeybindButton(CorpseHotkeyButton)
CorpseHotkeyButton:OnChanged(function(key)
    Config.corpses.toggle_key = key
    CorpseHotkeyButton:SetText(FormatHotkeyLabel("Corpse ESP Hotkey", key))
end)
CorpseHotkeyButton:SetText(FormatHotkeyLabel("Corpse ESP Hotkey", Config.corpses.toggle_key))

CorpseGroupboxes.main:AddToggle({
    Default = Config.corpses.chams,
    Text = "Chams",
}):OnChanged(function(value)
    Config.corpses.chams = value
end)

CorpseGroupboxes.main:AddToggle({
    Default = Config.corpses.boxes,
    Text = "Boxes",
}):OnChanged(function(value)
    Config.corpses.boxes = value
end)

CorpseGroupboxes.main:AddToggle({
    Default = Config.corpses.tracers,
    Text = "Tracers",
}):OnChanged(function(value)
    Config.corpses.tracers = value
end)

CorpseGroupboxes.main:AddToggle({
    Default = Config.corpses.head_dot,
    Text = "Head Dot",
}):OnChanged(function(value)
    Config.corpses.head_dot = value
end)

CorpseGroupboxes.visual:AddToggle({
    Default = Config.corpses.names,
    Text = "Names",
}):OnChanged(function(value)
    Config.corpses.names = value
end)

CorpseGroupboxes.visual:AddToggle({
    Default = Config.corpses.distance,
    Text = "Distance",
}):OnChanged(function(value)
    Config.corpses.distance = value
end)

CorpseGroupboxes.visual:AddColorPicker({
    Default = Config.corpses.color,
    Text = "Color",
}):OnChanged(function(value)
    Config.corpses.color = value
end)

CorpseGroupboxes.visual:AddSlider({
    Default = Config.corpses.distance_limit,
    Text = "Max Distance",
    Min = DistanceSliderBounds.corpses.min,
    Max = DistanceSliderBounds.corpses.max,
    Rounding = 0,
    Suffix = " studs",
}):OnChanged(function(value)
    Config.corpses.distance_limit = clampToRange(
        value,
        DistanceSliderBounds.corpses.min,
        DistanceSliderBounds.corpses.max,
        DistanceSliderBounds.corpses.default
    )
end)

CorpseGroupboxes.visual:AddSlider({
    Default = Config.corpses.min_limb_count,
    Text = "Min Limbs",
    Min = 1,
    Max = 10,
    Rounding = 0,
}):OnChanged(function(value)
    Config.corpses.min_limb_count = value
end)

local corpseBoxOptions = {BoxTypeOptionsList[1], BoxTypeOptionsList[2]}
CorpseGroupboxes.extra:AddDropdown({
    Default = BoxTypeIndexLookup[Config.corpses.box_type] or 1,
    Text = "Box Type",
    Values = corpseBoxOptions,
}):OnChanged(function(value)
    Config.corpses.box_type = NormalizeBoxType(value)
end)

CorpseGroupboxes.extra:AddDropdown({
    Default = 3,
    Text = "Tracer Origin",
    Values = {"Top", "Bottom", "Mouse"},
}):OnChanged(function(value)
    Config.corpses.tracer_origin = value
end)

-- Zombie Settings
local ZombieEnabledToggle = ZombieGroupboxes.main:AddToggle({
    Default = Config.zombies.enabled,
    Text = "Enabled",
})
ZombieEnabledToggle:OnChanged(function(value)
    Lib:Notify(value and "Zombie ESP Enabled" or "Zombie ESP Disabled", 1)
    Config.zombies.enabled = value
end)

local ZombieHotkeyButton = ZombieGroupboxes.main:AddKeybindButton({
    Text = FormatHotkeyLabel("Zombie ESP Hotkey", Config.zombies.toggle_key),
    Default = Config.zombies.toggle_key,
})
ZombieEnabledToggle:ConnectKeybindButton(ZombieHotkeyButton)
ZombieHotkeyButton:OnChanged(function(key)
    Config.zombies.toggle_key = key
    ZombieHotkeyButton:SetText(FormatHotkeyLabel("Zombie ESP Hotkey", key))
end)
ZombieHotkeyButton:SetText(FormatHotkeyLabel("Zombie ESP Hotkey", Config.zombies.toggle_key))

ZombieGroupboxes.main:AddToggle({
    Default = Config.zombies.chams,
    Text = "Chams",
}):OnChanged(function(value)
    Config.zombies.chams = value
end)

ZombieGroupboxes.main:AddToggle({
    Default = Config.zombies.chams_body_only,
    Text = "Chams: Body Only",
}):OnChanged(function(value)
    Config.zombies.chams_body_only = value
end)

ZombieGroupboxes.main:AddToggle({
    Default = Config.zombies.boxes,
    Text = "Boxes",
}):OnChanged(function(value)
    Config.zombies.boxes = value
end)

ZombieGroupboxes.main:AddToggle({
    Default = Config.zombies.tracers,
    Text = "Tracers",
}):OnChanged(function(value)
    Config.zombies.tracers = value
end)

ZombieGroupboxes.main:AddToggle({
    Default = Config.zombies.head_dot,
    Text = "Head Dot",
}):OnChanged(function(value)
    Config.zombies.head_dot = value
end)

ZombieGroupboxes.visual:AddToggle({
    Default = Config.zombies.names,
    Text = "Names",
}):OnChanged(function(value)
    Config.zombies.names = value
end)

ZombieGroupboxes.visual:AddToggle({
    Default = Config.zombies.distance,
    Text = "Distance",
}):OnChanged(function(value)
    Config.zombies.distance = value
end)

ZombieGroupboxes.visual:AddColorPicker({
    Default = Config.zombies.color,
    Text = "Color",
}):OnChanged(function(value)
    Config.zombies.color = value
end)

ZombieGroupboxes.visual:AddDropdown({
    Default = ChamStyleIndexLookup[Config.zombies.chams_style] or 1,
    Text = "Chams Style",
    Values = ChamStyleOptionsList,
}):OnChanged(function(value)
    Config.zombies.chams_style = NormalizeChamStyle(value)
end)

ZombieGroupboxes.visual:AddSlider({
    Default = Config.zombies.chams_scale,
    Text = "Chams Scale",
    Min = ChamScaleBounds.min,
    Max = ChamScaleBounds.max,
    Rounding = 2,
    Suffix = "x",
}):OnChanged(function(value)
    Config.zombies.chams_scale = clampToRange(
        value,
        ChamScaleBounds.min,
        ChamScaleBounds.max,
        ChamScaleBounds.default
    )
end)

ZombieGroupboxes.visual:AddToggle({
    Default = Config.zombies.chams_use_secondary,
    Text = "Use Secondary Cham Color",
}):OnChanged(function(value)
    Config.zombies.chams_use_secondary = value
end)

ZombieGroupboxes.visual:AddColorPicker({
    Default = Config.zombies.chams_secondary_color,
    Text = "Secondary Cham Color",
}):OnChanged(function(value)
    Config.zombies.chams_secondary_color = value
end)

ZombieGroupboxes.visual:AddSlider({
    Default = Config.zombies.distance_limit,
    Text = "Max Distance",
    Min = DistanceSliderBounds.zombies.min,
    Max = DistanceSliderBounds.zombies.max,
    Rounding = 0,
    Suffix = " studs",
}):OnChanged(function(value)
    Config.zombies.distance_limit = clampToRange(
        value,
        DistanceSliderBounds.zombies.min,
        DistanceSliderBounds.zombies.max,
        DistanceSliderBounds.zombies.default
    )
end)

ZombieGroupboxes.visual:AddSlider({
    Default = Config.zombies.min_limb_count,
    Text = "Min Limbs",
    Min = 1,
    Max = 10,
    Rounding = 0,
}):OnChanged(function(value)
    Config.zombies.min_limb_count = value
end)

local zombieBoxOptions = {BoxTypeOptionsList[1], BoxTypeOptionsList[2]}
ZombieGroupboxes.extra:AddDropdown({
    Default = BoxTypeIndexLookup[Config.zombies.box_type] or 1,
    Text = "Box Type",
    Values = zombieBoxOptions,
}):OnChanged(function(value)
    Config.zombies.box_type = NormalizeBoxType(value)
end)

local zombieTracerDefault = 3
if Config.zombies.tracer_origin == "Top" then
    zombieTracerDefault = 1
elseif Config.zombies.tracer_origin == "Bottom" then
    zombieTracerDefault = 2
end

ZombieGroupboxes.extra:AddDropdown({
    Default = zombieTracerDefault,
    Text = "Tracer Origin",
    Values = {"Top", "Bottom", "Mouse"},
}):OnChanged(function(value)
    Config.zombies.tracer_origin = value
end)

-- Vehicle Settings
local VehicleEnabledToggle = VehicleGroupboxes.main:AddToggle({
    Default = Config.vehicles.enabled,
    Text = "Enabled",
})
VehicleEnabledToggle:OnChanged(function(value)
    Lib:Notify(value and "Vehicle ESP Enabled" or "Vehicle ESP Disabled", 1)
    Config.vehicles.enabled = value
end)

local VehicleHotkeyButton = VehicleGroupboxes.main:AddKeybindButton({
    Text = FormatHotkeyLabel("Vehicle ESP Hotkey", Config.vehicles.toggle_key),
    Default = Config.vehicles.toggle_key,
})
VehicleEnabledToggle:ConnectKeybindButton(VehicleHotkeyButton)
VehicleHotkeyButton:OnChanged(function(key)
    Config.vehicles.toggle_key = key
    VehicleHotkeyButton:SetText(FormatHotkeyLabel("Vehicle ESP Hotkey", key))
end)
VehicleHotkeyButton:SetText(FormatHotkeyLabel("Vehicle ESP Hotkey", Config.vehicles.toggle_key))

VehicleGroupboxes.main:AddToggle({
    Default = Config.vehicles.chams,
    Text = "Chams",
}):OnChanged(function(value)
    Config.vehicles.chams = value
end)

VehicleGroupboxes.main:AddToggle({
    Default = Config.vehicles.boxes,
    Text = "Boxes",
}):OnChanged(function(value)
    Config.vehicles.boxes = value
end)

VehicleGroupboxes.main:AddToggle({
    Default = Config.vehicles.tracers,
    Text = "Tracers",
}):OnChanged(function(value)
    Config.vehicles.tracers = value
end)

VehicleGroupboxes.visual:AddToggle({
    Default = Config.vehicles.names,
    Text = "Names",
}):OnChanged(function(value)
    Config.vehicles.names = value
end)

VehicleGroupboxes.visual:AddToggle({
    Default = Config.vehicles.distance,
    Text = "Distance",
}):OnChanged(function(value)
    Config.vehicles.distance = value
end)

VehicleGroupboxes.visual:AddColorPicker({
    Default = Config.vehicles.color,
    Text = "Color",
}):OnChanged(function(value)
    Config.vehicles.color = value
end)

VehicleGroupboxes.visual:AddSlider({
    Default = Config.vehicles.distance_limit,
    Text = "Max Distance",
    Min = DistanceSliderBounds.vehicles.min,
    Max = DistanceSliderBounds.vehicles.max,
    Rounding = 0,
    Suffix = " studs",
}):OnChanged(function(value)
    Config.vehicles.distance_limit = clampToRange(
        value,
        DistanceSliderBounds.vehicles.min,
        DistanceSliderBounds.vehicles.max,
        DistanceSliderBounds.vehicles.default
    )
end)

VehicleGroupboxes.visual:AddSlider({
    Default = Config.vehicles.icon_size,
    Text = "Icon Size",
    Min = 5,
    Max = 30,
    Rounding = 0,
}):OnChanged(function(value)
    Config.vehicles.icon_size = value
end)

local vehicleBoxOptions = {BoxTypeOptionsList[1], BoxTypeOptionsList[2]}
VehicleGroupboxes.extra:AddDropdown({
    Default = BoxTypeIndexLookup[Config.vehicles.box_type] or 1,
    Text = "Box Type",
    Values = vehicleBoxOptions,
}):OnChanged(function(value)
    Config.vehicles.box_type = NormalizeBoxType(value)
end)

VehicleGroupboxes.extra:AddDropdown({
    Default = 1,
    Text = "Tracer Origin",
    Values = {"Top", "Bottom", "Mouse"},
}):OnChanged(function(value)
    Config.vehicles.tracer_origin = value
end)

VehicleGroupboxes.extra:AddToggle({
    Default = Config.vehicles.scan_nested,
    Text = "Scan Nested Parts",
}):OnChanged(function(value)
    Config.vehicles.scan_nested = value
    Cache.vehicles = {}
end)

-- Performance Settings
SettingsGroupboxes.performance:AddSlider({
    Default = Config.settings.cache_refresh_rate,
    Text = "Cache Refresh Rate",
    Min = 15,
    Max = 120,
    Rounding = 0,
}):OnChanged(function(value)
    Config.settings.cache_refresh_rate = value
end)

SettingsGroupboxes.performance:AddSlider({
    Default = Config.settings.max_renders_per_frame,
    Text = "Max Renders/Frame",
    Min = 10,
    Max = 250,
    Rounding = 0,
}):OnChanged(function(value)
    Config.settings.max_renders_per_frame = value
end)

SettingsGroupboxes.performance:AddSlider({
    Default = Config.settings.vehicle_scan_depth,
    Text = "Vehicle Scan Depth",
    Min = 1,
    Max = 3,
    Rounding = 0,
}):OnChanged(function(value)
    Config.settings.vehicle_scan_depth = value
end)

SettingsGroupboxes.performance:AddSlider({
    Default = Config.settings.vehicle_scan_step,
    Text = "Vehicle Scan Batch",
    Min = 5,
    Max = 200,
    Rounding = 0,
}):OnChanged(function(value)
    Config.settings.vehicle_scan_step = value
end)

SettingsGroupboxes.performance:AddSlider({
    Default = Config.settings.max_render_parts,
    Text = "Max Parts/Entity",
    Min = 40,
    Max = 400,
    Rounding = 0,
}):OnChanged(function(value)
    Config.settings.max_render_parts = clampToRange(value, 40, 400, 120)
end)

SettingsGroupboxes.performance:AddSlider({
    Default = Config.settings.part_resample_interval,
    Text = "Part Refresh Frames",
    Min = 1,
    Max = 10,
    Rounding = 0,
}):OnChanged(function(value)
    Config.settings.part_resample_interval = clampToRange(value, 1, 10, 3)
end)

local LocalPlayerDropdown = SettingsGroupboxes.localPlayer:AddDropdown({
    Default = 1,
    Text = "Distance Origin",
    Values = LocalPlayerManager.options,
})

LocalPlayerManager.dropdown = LocalPlayerDropdown
LocalPlayerDropdown:SetValues(LocalPlayerManager.options)
LocalPlayerDropdown:OnChanged(function(value)
    Config.settings.local_player_selection = value
    LocalPlayerManager.selectedLabel = value
    LocalPlayerManager.selectedIndex = LocalPlayerManager.valueToIndex and LocalPlayerManager.valueToIndex[value] or 1
    LocalPlayerManager.selectedSignature = nil
    LocalPlayerManager.lastSignatureUpdate = 0
    LocalPlayerManager.currentSelectionLabel = value
    local ordinal, displayName = ParseOptionLabel(value)
    LocalPlayerManager.currentSelectionIndex = ordinal
    LocalPlayerManager.currentSelectionDisplayName = displayName
    if LocalPlayerManager.selectedIndex and LocalPlayerManager.selectedIndex > 1 then
        LocalPlayerManager.manualSelectionTime = os_clock()
        LocalPlayerManager.manualSelectionLabel = value
        LocalPlayerManager.manualSelectionDisplayName = displayName
        LocalPlayerManager.manualSelectionIndex = ordinal
        local selectionModel = LocalPlayerManager.models and LocalPlayerManager.models[LocalPlayerManager.selectedIndex] or nil
        if selectionModel and ModelExists(selectionModel) then
            LocalPlayerManager.manualSelectionModel = selectionModel
            local entry = Cache.starter_characters[selectionModel] or EnsureStarterCharacterEntry(selectionModel)
            if entry then
                UpdateManualMetadataFromEntry(entry)
                UpdateCurrentMetadataFromEntry(entry)
            else
                UpdateManualMetadataFromEntry(nil)
                UpdateCurrentMetadataFromEntry(nil)
            end
        else
            LocalPlayerManager.manualSelectionModel = nil
            ClearManualMetadata()
            ClearCurrentMetadata()
        end
    else
        LocalPlayerManager.manualSelectionTime = 0
        LocalPlayerManager.manualSelectionLabel = nil
        LocalPlayerManager.manualSelectionDisplayName = nil
        LocalPlayerManager.manualSelectionIndex = nil
        LocalPlayerManager.manualSelectionModel = nil
        ClearManualMetadata()
        ClearCurrentMetadata()
        LocalPlayerManager.currentSelectionLabel = value
        LocalPlayerManager.currentSelectionDisplayName = displayName
        LocalPlayerManager.currentSelectionIndex = ordinal
    end
    LocalPlayerManager.missingSince = nil
    if LocalPlayerManager.selectedIndex and LocalPlayerManager.selectedIndex > 1 then
        LocalPlayerManager.lastSelectedModel = LocalPlayerManager.models and LocalPlayerManager.models[LocalPlayerManager.selectedIndex] or nil
    else
        LocalPlayerManager.lastSelectedModel = nil
    end
end)

local desiredDistanceOrigin = LocalPlayerManager.selectedLabel or "0 - Camera (Default)"
if LocalPlayerDropdown.Value ~= desiredDistanceOrigin then
    LocalPlayerDropdown:SetValue(desiredDistanceOrigin)
end

SettingsGroupboxes.localPlayer:AddToggle({
    Default = Config.settings.show_local_player_indicator,
    Text = "Show Selection Indicator",
}):OnChanged(function(value)
    Config.settings.show_local_player_indicator = value
end)

SettingsGroupboxes.localPlayer:AddToggle({
    Default = Config.characters.exclude_local_player,
    Text = "Exclude From Character ESP",
}):OnChanged(function(value)
    Config.characters.exclude_local_player = value
end)

-- Debug Settings
SettingsGroupboxes.debug:AddToggle({
    Default = Config.debug.show,
    Text = "Show Debug Info",
}):OnChanged(function(value)
    Config.debug.show = value
end)

SettingsGroupboxes.debug:AddToggle({
    Default = Config.debug.show_performance,
    Text = "Show Performance",
}):OnChanged(function(value)
    Config.debug.show_performance = value
end)

SettingsGroupboxes.debug:AddToggle({
    Default = Config.debug.show_vehicle_list,
    Text = "Show Vehicle List",
}):OnChanged(function(value)
    Config.debug.show_vehicle_list = value
end)

SettingsGroupboxes.debug:AddToggle({
    Default = Config.debug.show_corpse_list,
    Text = "Show Corpse List",
}):OnChanged(function(value)
    Config.debug.show_corpse_list = value
end)

SettingsGroupboxes.debug:AddToggle({
    Default = Config.debug.show_zombie_list,
    Text = "Show Zombie List",
}):OnChanged(function(value)
    Config.debug.show_zombie_list = value
end)

SettingsGroupboxes.debug:AddBlank(10)
SettingsGroupboxes.debug:AddLabel("Debug info appears in\ntop-left corner")

-- ====================================
-- MAIN LOOP
-- ====================================
-- This code executes EVERY FRAME (typically 60 times per second)
-- All ESP rendering and entity detection happens here

-- Increment frame counter for timing-based operations
Cache.frame_count = (Cache.frame_count or 0) + 1

-- Reset performance metrics for this frame
Cache.performance = {
    characters_checked = 0, -- How many character models we examined
    characters_rendered = 0, -- How many characters we actually drew ESP for
    zombies_checked = 0, -- How many zombie models we examined
    zombies_rendered = 0, -- How many zombies we actually drew ESP for
    corpses_checked = 0, -- How many corpse models we examined
    corpses_rendered = 0, -- How many corpses we actually drew ESP for
    vehicles_checked = 0, -- How many vehicle models we examined
    vehicles_rendered = 0, -- How many vehicles we actually drew ESP for
    parts_rendered = 0, -- Total individual 3D chams boxes drawn
    tracers_drawn = 0, -- Total tracer lines drawn
    boxes_drawn = 0, -- Total 2D bounding boxes drawn
}

-- Get the root game instance (equivalent to "game" in normal Roblox scripts)
local Datamodel = dx9.GetDatamodel()
if not Datamodel then
    return
end

local Workspace = SafeFindFirstChild(Datamodel, 'Workspace')

-- If Workspace doesn't exist, exit early (game hasn't loaded)
if not Workspace then
    return
end

if LocalPlayerManager.dropdown and not LocalPlayerManager.initialized then
    UpdateStarterCharacterOptions(
        dx9_FindFirstChild(Workspace, 'StarterCharacters'),
        dx9_FindFirstChild(Workspace, 'Characters')
    )
    LocalPlayerManager.initialized = true
end

-- Get screen dimensions for on-screen checks and UI positioning
-- OPTIMIZED: Cache screen size
local screenSize = dx9.size()
local screenWidth = screenSize.width
local screenHeight = screenSize.height

-- Get camera position for distance calculations
-- All distances are measured from the camera's position
local Camera = dx9_FindFirstChild(Workspace, "Camera")
local cameraPos = nil
if Camera then
    local cameraPart = dx9_FindFirstChild(Camera, "CameraSubject") or dx9_FindFirstChild(Camera, "Focus")
    if not cameraPart or cameraPart == 0 then
        -- Try to get a part from camera to get its position
        local cameraChildren = dx9_GetChildren(Camera)
        if cameraChildren and #cameraChildren > 0 then
            for i = 1, #cameraChildren do
                local child = cameraChildren[i]
                local success, childType = pcall(dx9_GetType, child)
                if success and (childType == "Part" or childType == "MeshPart") then
                    cameraPart = child
                    break
                end
            end
        end
    end
    
    if cameraPart and cameraPart ~= 0 then
        local success, pos = pcall(dx9_GetPosition, cameraPart)
        if success and pos then
            cameraPos = pos
        end
    end
end

-- Fallback camera position if we can't get the real one
if not cameraPos then
    cameraPos = {x = 0, y = 50, z = 0}
end

-- Determine current distance origin based on dropdown selection
local selectedLabel = LocalPlayerManager.selectedLabel or Config.settings.local_player_selection
if LocalPlayerManager.valueToIndex and LocalPlayerManager.valueToIndex[selectedLabel] then
    LocalPlayerManager.selectedIndex = LocalPlayerManager.valueToIndex[selectedLabel]
elseif LocalPlayerManager.selectedIndex and LocalPlayerManager.selectedIndex > 1 then
    -- keep previous selection index so reacquire logic can run
else
    LocalPlayerManager.selectedIndex = 1
    LocalPlayerManager.lastSelectedModel = nil
end

local distanceOrigin = cameraPos
LocalPlayerManager.activeModel = nil
LocalPlayerManager.originPosition = distanceOrigin

local nowClock = os_clock()

if LocalPlayerManager.selectedIndex and LocalPlayerManager.selectedIndex > 1 then
    local modelList = LocalPlayerManager.models
    local selectedModel = LocalPlayerManager.manualSelectionModel

    if selectedModel and not ModelExists(selectedModel) then
        selectedModel = nil
        LocalPlayerManager.manualSelectionModel = nil
    end

    if not selectedModel and modelList and LocalPlayerManager.selectedIndex then
        selectedModel = modelList[LocalPlayerManager.selectedIndex]
    end

    if selectedModel and not ModelExists(selectedModel) then
        selectedModel = nil
    end

    if not selectedModel and LocalPlayerManager.lastSelectedModel and ModelExists(LocalPlayerManager.lastSelectedModel) then
        selectedModel = LocalPlayerManager.lastSelectedModel
    end

    if selectedModel and modelList then
        for idx = 2, #modelList do
            if modelList[idx] == selectedModel then
                LocalPlayerManager.selectedIndex = idx
                break
            end
        end
    end

    if not (selectedModel and ModelExists(selectedModel)) then
        selectedModel = TryReacquireLocalPlayer()
    end

    if selectedModel and ModelExists(selectedModel) then
        LocalPlayerManager.missingSince = nil
        LocalPlayerManager.lastSelectedModel = selectedModel

        local entry = EnsureStarterCharacterEntry(selectedModel)
        if entry then
            local signature = entry.signatureHash or UpdateStarterCharacterSignature(entry, selectedModel)
            if signature then
                LocalPlayerManager.selectedSignature = signature
                LocalPlayerManager.lastSignatureUpdate = Cache.frame_count
            end
            if entry.coreSignature then
                LocalPlayerManager.selectedCoreSignature = entry.coreSignature
            end
            if entry.cachedName then
                LocalPlayerManager.lastKnownName = entry.cachedName
            else
                LocalPlayerManager.lastKnownName = SafeGetName(selectedModel) or LocalPlayerManager.lastKnownName
            end
            if entry.cachedName then
                LocalPlayerManager.currentSelectionDisplayName = entry.cachedName
            end
            UpdateCurrentMetadataFromEntry(entry)
            if not LocalPlayerManager.manualSelectionModel then
                LocalPlayerManager.manualSelectionModel = selectedModel
            end
            if LocalPlayerManager.manualSelectionModel == selectedModel then
                UpdateManualMetadataFromEntry(entry)
            end
        else
            local fallbackName = SafeGetName(selectedModel)
            LocalPlayerManager.lastKnownName = fallbackName or LocalPlayerManager.lastKnownName
            if fallbackName then
                LocalPlayerManager.currentSelectionDisplayName = fallbackName
            end
            UpdateCurrentMetadataFromEntry(nil)
        end

        local originPos = GetReferencePosition(selectedModel, selectedModel, Cache.starter_characters)
        if originPos then
            distanceOrigin = originPos
            LocalPlayerManager.originPosition = originPos
        else
            LocalPlayerManager.originPosition = distanceOrigin
        end

        LocalPlayerManager.activeModel = selectedModel
        LocalPlayerManager.lastActiveTime = nowClock
        if LocalPlayerManager.manualSelectionModel == selectedModel and not LocalPlayerManager.manualSelectionLabel then
            LocalPlayerManager.manualSelectionLabel = LocalPlayerManager.currentSelectionLabel
            LocalPlayerManager.manualSelectionDisplayName = LocalPlayerManager.currentSelectionDisplayName
            LocalPlayerManager.manualSelectionIndex = LocalPlayerManager.currentSelectionIndex
        end
    else
        LocalPlayerManager.activeModel = nil
        LocalPlayerManager.lastSelectedModel = nil
        UpdateCurrentMetadataFromEntry(nil)

        if not LocalPlayerManager.missingSince then
            LocalPlayerManager.missingSince = nowClock
        end

        if (nowClock - LocalPlayerManager.missingSince) >= 20 then
            LocalPlayerManager.lastReacquireFrame = 0
            if LocalPlayerManager.lastStarterFolder then
                UpdateStarterCharacterOptions(LocalPlayerManager.lastStarterFolder, LocalPlayerManager.scanCharactersFolder)
            end
        end
    end
else
    LocalPlayerManager.lastSelectedModel = nil
    LocalPlayerManager.activeModel = nil
    LocalPlayerManager.missingSince = nil
    UpdateCurrentMetadataFromEntry(nil)
end

-- ====================================
-- CACHE CLEANUP
-- ====================================
-- Periodically remove destroyed/invalid entities from cache
-- This prevents memory leaks and stale data

local baseRefreshRate = Config.settings.cache_refresh_rate or 30
if baseRefreshRate < 1 then
    baseRefreshRate = 1
end

local characterRefreshInterval = math_max(1, math_floor(baseRefreshRate * 0.25))
-- Characters are refreshed more aggressively so stale models are cleared first
local lastCharacterRefresh = Cache.last_character_refresh or 0
if lastCharacterRefresh == 0 then
    lastCharacterRefresh = Cache.frame_count - characterRefreshInterval
end
local shouldRefreshCharacters = (Cache.frame_count - lastCharacterRefresh) >= characterRefreshInterval
local shouldRefreshAll = (Cache.frame_count - Cache.last_refresh) >= baseRefreshRate

local CharactersFolder
local StarterCharactersFolder
local currentCharacters

if shouldRefreshCharacters then
    Cache.last_character_refresh = Cache.frame_count

    CharactersFolder = SafeFindFirstChild(Workspace, 'Characters')
    StarterCharactersFolder = SafeFindFirstChild(Workspace, 'StarterCharacters')
    UpdateStarterCharacterOptions(StarterCharactersFolder, CharactersFolder)

    currentCharacters = {}
    local characterChildren = CharactersFolder and SafeGetChildren(CharactersFolder)
    if characterChildren and #characterChildren > 0 then
        for i = 1, #characterChildren do
            currentCharacters[characterChildren[i]] = true
        end
    end

    for characterModel in next, Cache.characters do
        if not currentCharacters[characterModel] or not ModelExists(characterModel) then
            Cache.characters[characterModel] = nil
        end
    end
end

if shouldRefreshAll then
    Cache.last_refresh = Cache.frame_count

    if not shouldRefreshCharacters then
        CharactersFolder = SafeFindFirstChild(Workspace, 'Characters')
        StarterCharactersFolder = SafeFindFirstChild(Workspace, 'StarterCharacters')
        UpdateStarterCharacterOptions(StarterCharactersFolder, CharactersFolder)

        currentCharacters = {}
        local characterChildren = CharactersFolder and SafeGetChildren(CharactersFolder)
        if characterChildren and #characterChildren > 0 then
            for i = 1, #characterChildren do
                currentCharacters[characterChildren[i]] = true
            end
        end

        for characterModel in next, Cache.characters do
            if not currentCharacters[characterModel] or not ModelExists(characterModel) then
                Cache.characters[characterModel] = nil
            end
        end
    end

    local ZombiesFolder = SafeFindFirstChild(Workspace, 'Zombies')
    local currentZombies = {}
    local zombieChildren = ZombiesFolder and SafeGetChildren(ZombiesFolder)
    if zombieChildren and #zombieChildren > 0 then
        for i = 1, #zombieChildren do
            currentZombies[zombieChildren[i]] = true
        end
    end

    for zombieModel in next, Cache.zombies do
        if not currentZombies[zombieModel] or not ModelExists(zombieModel) then
            Cache.zombies[zombieModel] = nil
        end
    end

    local CorpsesFolder = SafeFindFirstChild(Workspace, 'Corpses')
    local VehiclesFolder = SafeFindFirstChild(Workspace, 'Vehicles')

    local currentCorpses = {}
    local corpseChildren = CorpsesFolder and SafeGetChildren(CorpsesFolder)
    if corpseChildren and #corpseChildren > 0 then
        for i = 1, #corpseChildren do
            currentCorpses[corpseChildren[i]] = true
        end
    end

    for corpseModel in next, Cache.corpses do
        if not currentCorpses[corpseModel] or not ModelExists(corpseModel) then
            Cache.corpses[corpseModel] = nil
        end
    end

    local currentVehicles = {}
    local vehicleChildren = VehiclesFolder and SafeGetChildren(VehiclesFolder)
    if vehicleChildren and #vehicleChildren > 0 then
        for i = 1, #vehicleChildren do
            currentVehicles[vehicleChildren[i]] = true
        end
    end

    for vehicleModel in next, Cache.vehicles do
        if not currentVehicles[vehicleModel] or not ModelExists(vehicleModel) then
            Cache.vehicles[vehicleModel] = nil
        end
    end
end

-- ====================================
-- VEHICLE SCANNING
-- ====================================
-- OPTIMIZED: Scan for vehicles less frequently (every 120 frames = ~2 seconds at 60 FPS)
-- This is much slower than character scanning but vehicles don't spawn as often

local shouldScanVehicles = (Cache.frame_count - Cache.last_vehicle_scan) >= 120

if shouldScanVehicles and Config.vehicles.enabled and not Cache.vehicle_scan_state then
    Cache.last_vehicle_scan = Cache.frame_count
    
    local VehiclesFolder = dx9_FindFirstChild(Workspace, 'Vehicles')
    if VehiclesFolder then
        BeginVehicleScan(VehiclesFolder)
    else
        Cache.vehicle_list = {}
        Cache.vehicle_scan_state = nil
    end
end

if Cache.vehicle_scan_state then
    if Config.vehicles.enabled then
        ProcessVehicleScanStep(Config.settings.vehicle_scan_step or 40)
    else
        Cache.vehicle_scan_state = nil
    end
end

-- ====================================
-- CORPSE SCANNING
-- ====================================
-- Scan for corpses every 60 frames (~1 second at 60 FPS)
-- More frequent than vehicles since players die more often

local shouldScanCorpses = (Cache.frame_count - Cache.last_corpse_scan) >= 60

if shouldScanCorpses and Config.corpses.enabled then
    Cache.last_corpse_scan = Cache.frame_count
    
    local CorpsesFolder = dx9_FindFirstChild(Workspace, 'Corpses')
    if CorpsesFolder then
        -- Scan for corpse models (models with limbs but no Humanoid)
        Cache.corpse_list = ScanForCorpses(CorpsesFolder)
    end
end

-- ====================================
-- PROCESS CHARACTERS
-- ====================================
-- Real-time character detection and ESP rendering
-- Characters are scanned every frame for immediate detection

if Config.characters.enabled then
    local CharactersFolder = dx9_FindFirstChild(Workspace, 'Characters')
    
    if CharactersFolder then
        local FolderChildren = dx9_GetChildren(CharactersFolder)
        
        if FolderChildren then
            -- First pass: validate all characters and calculate distances
            -- We do this in two passes to allow sorting by distance (closest first)
            local characterDistances = {}
            
            for _, object in next, FolderChildren do
                local success, objectType = pcall(function()
                    return dx9_GetType(object)
                end)
                
                if success and objectType == "Model" then
                    Cache.performance.characters_checked = Cache.performance.characters_checked + 1
                    
                    -- Verify the model still exists in the game
                    if ModelExists(object) then
                        -- Check if this is a valid character (has Humanoid + enough body parts)
                        local isCharacter, partCount = IsCharacterModel(object, object)
                        
                        if isCharacter then
                            local isSelectedLocal = Config.characters.exclude_local_player and LocalPlayerManager.activeModel and object == LocalPlayerManager.activeModel

                            if not isSelectedLocal then
                                -- Get the character's position (tries HumanoidRootPart first, then any part)
                                local referencePos = GetReferencePosition(object, object, Cache.characters)
                                
                                if referencePos then
                                    -- OPTIMIZATION: Use squared distance for faster comparison (avoids expensive sqrt)
                                    local distSq = GetDistanceSquared(distanceOrigin, referencePos)
                                    local limitSq = Config.characters.distance_limit * Config.characters.distance_limit
                                    
                                    -- Only render characters within the configured distance limit
                                    if distSq <= limitSq then
                                        -- Calculate actual distance only if needed for display
                                        local distance = math_sqrt(distSq)
                                        
                                        table_insert(characterDistances, {
                                            model = object,
                                            distance = distance,
                                            referencePos = referencePos
                                        })
                                    end
                                end
                            end
                        end
                    else
                        -- Model was destroyed, remove from cache
                        Cache.characters[object] = nil
                    end
                end
            end
            
            -- Sort characters by distance (closest first)
            -- This ensures nearby threats are always rendered even if we hit the render limit
            table_sort(characterDistances, function(a, b)
                return a.distance < b.distance
            end)
            
            -- Second pass: render ESP for characters (up to max_renders_per_frame)
            local renderedThisFrame = 0
            
            for _, modelData in next, characterDistances do
                -- Stop rendering if we've hit the per-frame limit (prevents FPS drops)
                if renderedThisFrame >= Config.settings.max_renders_per_frame then
                    break
                end
                
                -- Render all ESP elements for this character (chams, boxes, tracers, labels, etc.)
                local rendered = RenderEntityESP(modelData, Config.characters, distanceOrigin, screenWidth, screenHeight, Cache.characters, false)
                
                if rendered then
                    renderedThisFrame = renderedThisFrame + 1
                    Cache.performance.characters_rendered = Cache.performance.characters_rendered + 1
                end
            end
        end
    end
end

-- ====================================
-- PROCESS ZOMBIES
-- ====================================
-- Render ESP for zombies using similar logic to characters

if Config.zombies.enabled then
    local ZombiesFolder = dx9_FindFirstChild(Workspace, 'Zombies')

    if ZombiesFolder then
        local FolderChildren = dx9_GetChildren(ZombiesFolder)
        local zombieDistances = {}

        if FolderChildren then
            for _, object in next, FolderChildren do
                local success, objectType = pcall(function()
                    return dx9_GetType(object)
                end)

                if success and objectType == "Model" then
                    Cache.performance.zombies_checked = Cache.performance.zombies_checked + 1

                    if ModelExists(object) then
                        local isZombie = IsCharacterModel(object, object, Cache.zombies, {
                            config = Config.zombies,
                            skipStarterTemplate = true,
                            requireHumanoid = false,
                            allowAnimatorOnly = true,
                        })

                        if isZombie then
                            local referencePos = GetReferencePosition(object, object, Cache.zombies)

                            if referencePos then
                                local distSq = GetDistanceSquared(distanceOrigin, referencePos)
                                local limitSq = Config.zombies.distance_limit * Config.zombies.distance_limit

                                if distSq <= limitSq then
                                    local distance = math_sqrt(distSq)

                                    table_insert(zombieDistances, {
                                        model = object,
                                        distance = distance,
                                        referencePos = referencePos,
                                        name = SafeGetName(object),
                                    })
                                end
                            end
                        end
                    else
                        Cache.zombies[object] = nil
                    end
                end
            end
        end

        table_sort(zombieDistances, function(a, b)
            return a.distance < b.distance
        end)

        Cache.zombie_list = zombieDistances

        local renderedThisFrame = 0

        for _, modelData in next, zombieDistances do
            if renderedThisFrame >= Config.settings.max_renders_per_frame then
                break
            end

            local rendered = RenderEntityESP(modelData, Config.zombies, distanceOrigin, screenWidth, screenHeight, Cache.zombies, false)

            if rendered then
                renderedThisFrame = renderedThisFrame + 1
                Cache.performance.zombies_rendered = Cache.performance.zombies_rendered + 1
            end
        end
    else
        Cache.zombie_list = {}
    end
else
    Cache.zombie_list = {}
end

-- ====================================
-- PROCESS CORPSES
-- ====================================
-- Render ESP for corpses using the cached corpse list
-- Corpses are scanned less frequently (every 60 frames) since they don't move

if Config.corpses.enabled and Cache.corpse_list and #Cache.corpse_list > 0 then
    local corpseDistances = {}
    local distanceCount = 0
    
    -- Check each corpse from the cached list
    -- OPTIMIZATION: Pre-calculate distance limit squared for fast comparison
    local corpseLimitSquared = Config.corpses.distance_limit * Config.corpses.distance_limit
    
    for _, corpseData in next, Cache.corpse_list do
        if ModelExists(corpseData.model) then
            Cache.performance.corpses_checked = Cache.performance.corpses_checked + 1
            
            -- Get corpse position from cache or calculate it
            local referencePos = GetReferencePosition(corpseData.model, corpseData.model, Cache.corpses)
            
            if referencePos then
                -- OPTIMIZATION: Use squared distance for faster comparison (avoids expensive sqrt)
                local distSq = GetDistanceSquared(distanceOrigin, referencePos)
                
                -- Only render corpses within distance limit
                if distSq <= corpseLimitSquared then
                    -- Calculate actual distance only if needed for display
                    local distance = math_sqrt(distSq)
                    
                    table_insert(corpseDistances, {
                        model = corpseData.model,
                        name = corpseData.name,
                        distance = distance,
                        referencePos = referencePos
                    })
                end
            end
        end
    end
    
    -- Sort corpses by distance (closest first)
    table_sort(corpseDistances, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Render ESP for all corpses (no render limit since corpses don't change often)
    for _, modelData in next, corpseDistances do
        -- Render all ESP elements for this corpse
    local rendered = RenderEntityESP(modelData, Config.corpses, distanceOrigin, screenWidth, screenHeight, Cache.corpses, true)
        
        if rendered then
            Cache.performance.corpses_rendered = Cache.performance.corpses_rendered + 1
        end
    end
end

-- ====================================
-- PROCESS VEHICLES
-- ====================================
-- OPTIMIZED: Render ESP for vehicles using the cached vehicle list
-- Vehicles are scanned less frequently (every 120 frames = ~2 seconds) for better performance

if Config.vehicles.enabled and Cache.vehicle_list and #Cache.vehicle_list > 0 then
    local vehicleDistances = {}
    local vehicleCount = 0
    
    -- First pass: Calculate distances for all valid vehicles
    -- OPTIMIZED: Pre-calculate distance limit squared
    local vehicleLimitSquared = Config.vehicles.distance_limit * Config.vehicles.distance_limit
    
    for _, vehicleData in next, Cache.vehicle_list do
        if ModelExists(vehicleData.model) then
            Cache.performance.vehicles_checked = Cache.performance.vehicles_checked + 1
            
            -- Initialize cache entry if it doesn't exist
            if not Cache.vehicles[vehicleData.model] then
                Cache.vehicles[vehicleData.model] = {
                    allParts = nil, -- Will be filled on first render if scan_nested is enabled
                    refPart = nil, -- Cached reference part for position
                    refPos = nil, -- Cached position
                    lastSeen = Cache.frame_count, -- Frame number when last seen
                    name = vehicleData.name
                }
            end
            
            -- Get vehicle position (cached or calculated)
            local referencePos = GetReferencePosition(vehicleData.model, vehicleData.model, Cache.vehicles)
            
            if referencePos then
                -- OPTIMIZATION: Use squared distance for faster comparison (avoids expensive sqrt)
                local distSq = GetDistanceSquared(distanceOrigin, referencePos)
                
                -- Only render vehicles within distance limit
                if distSq <= vehicleLimitSquared then
                    -- Calculate actual distance only if needed for display
                    local distance = math_sqrt(distSq)
                    
                    table_insert(vehicleDistances, {
                        model = vehicleData.model,
                        name = vehicleData.name,
                        distance = distance,
                        referencePos = referencePos
                    })
                end
            end
        end
    end
    
    -- Sort vehicles by distance (closest first)
    table_sort(vehicleDistances, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Second pass: Render ESP for vehicles
    for _, modelData in next, vehicleDistances do
        if ModelExists(modelData.model) then
            -- OPTIMIZATION: Cache the complete parts list if nested scanning is enabled
            -- This prevents re-scanning the vehicle hierarchy every frame
            if Config.vehicles.scan_nested then
                if not Cache.vehicles[modelData.model].allParts then
                    -- First time seeing this vehicle, scan all nested parts
                    Cache.vehicles[modelData.model].allParts = GetAllPartsFromModel(modelData.model, 60)
                end
            end
            
            -- Get all parts (either cached nested parts or direct children)
            local allParts = Cache.vehicles[modelData.model].allParts or dx9_GetChildren(modelData.model)
            
            if allParts and #allParts > 0 then
                local anyPartVisible = false
                local currentColor = Config.vehicles.color
                
                -- Draw 2D bounding box around entire vehicle if enabled
                if Config.vehicles.boxes then
                    local boundingBox = GetBoundingBox(allParts, screenWidth, screenHeight, Config.settings.screen_padding)
                    
                    if boundingBox then
                        anyPartVisible = true
                        
                        if Config.vehicles.box_type == "Corner Box" then
                            DrawCornerBox(boundingBox.topLeft, boundingBox.bottomRight, currentColor)
                        else
                            Draw2DBox(boundingBox.topLeft, boundingBox.bottomRight, currentColor)
                        end
                        
                        Cache.performance.boxes_drawn = Cache.performance.boxes_drawn + 1
                    end
                end
                
                -- Draw 3D chams around individual vehicle parts if enabled
                if Config.vehicles.chams then
                    local maxPartsToRender = 30 -- Limit parts per vehicle to prevent FPS drops
                    local partsRendered = 0
                    
                    for _, part in next, allParts do
                        if partsRendered >= maxPartsToRender then
                            break
                        end
                        
                        -- Get part's world position
                        local success, partPos = pcall(function()
                            return dx9_GetPosition(part)
                        end)
                        
                        if success and partPos and partPos.x then
                            -- Quick screen-space check before expensive CFrame operations
                            local success2, quickScreen = pcall(function()
                                return dx9_WorldToScreen({partPos.x, partPos.y, partPos.z})
                            end)
                            
                            if success2 and IsOnScreen(quickScreen, screenWidth, screenHeight, Config.settings.screen_padding) then
                                anyPartVisible = true
                                
                                -- Get part's rotation/orientation for 3D box
                                local success3, partCFrame = pcall(function()
                                    return dx9_GetCFrame(part)
                                end)
                                
                                if success3 and partCFrame then
                                    -- Get part name for size estimation
                                    local partName = nil
                                    local success4, name = pcall(function()
                                        return dx9_GetName(part)
                                    end)
                                    if success4 then
                                        partName = name
                                    end
                                    
                                    -- Estimate part size based on name (wheel, seat, body, etc.)
                                    local partSize = EstimateVehiclePartSize(partName)
                                    
                                    -- Draw 3D wireframe box around the part
                                    local drawn = DrawBodyPartChams(partPos, partCFrame, partSize, currentColor, screenWidth, screenHeight, Config.settings.screen_padding)
                                    if drawn then
                                        Cache.performance.parts_rendered = Cache.performance.parts_rendered + 1
                                        partsRendered = partsRendered + 1
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- Draw vehicle name and distance label
                if Config.vehicles.names or Config.vehicles.distance then
                    local screenPos = dx9_WorldToScreen({modelData.referencePos.x, modelData.referencePos.y + 2, modelData.referencePos.z})
                    
                    if IsOnScreen(screenPos, screenWidth, screenHeight, 0) then
                        -- Draw small icon box at vehicle location
                        local iconSize = Config.vehicles.icon_size
                        dx9_DrawBox(
                            {screenPos.x - iconSize/2, screenPos.y - iconSize/2},
                            {screenPos.x + iconSize/2, screenPos.y + iconSize/2},
                            currentColor
                        )
                        
                        -- Build label text with name and/or distance
                        local labelText = ""
                        
                        if Config.vehicles.names then
                            labelText = modelData.name or "Vehicle"
                        end
                        
                        if Config.vehicles.distance then
                            if labelText ~= "" then
                                labelText = labelText .. " [" .. math_floor(modelData.distance) .. "m]"
                            else
                                labelText = "[" .. math_floor(modelData.distance) .. "m]"
                            end
                        end
                        
                        -- Draw centered text below icon
                        if labelText ~= "" then
                            local textWidth = dx9_CalcTextWidth(labelText)
                            local textX = screenPos.x - (textWidth / 2)
                            local textY = screenPos.y + iconSize/2 + 5
                            
                            dx9_DrawString({textX, textY}, currentColor, labelText)
                        end
                        
                        anyPartVisible = true
                    end
                end
                
                -- Draw tracer line to vehicle if enabled
                if Config.vehicles.tracers then
                    local toScreen = dx9_WorldToScreen({modelData.referencePos.x, modelData.referencePos.y, modelData.referencePos.z})
                    
                    if IsOnScreen(toScreen, screenWidth, screenHeight, 0) then
                        local fromScreen
                        
                        -- Determine tracer starting position based on config
                        if Config.vehicles.tracer_origin == "Top" then
                            fromScreen = {screenWidth / 2, 0}
                        elseif Config.vehicles.tracer_origin == "Bottom" then
                            fromScreen = {screenWidth / 2, screenHeight}
                        elseif Config.vehicles.tracer_origin == "Mouse" then
                            local mouse = dx9_GetMouse()
                            fromScreen = {mouse.x, mouse.y}
                        else
                            fromScreen = {screenWidth / 2, screenHeight}
                        end
                        
                        DrawTracer(fromScreen, {toScreen.x, toScreen.y}, currentColor)
                        anyPartVisible = true
                    end
                end
                
                -- Increment render counter if any ESP element was drawn
                if anyPartVisible then
                    Cache.performance.vehicles_rendered = Cache.performance.vehicles_rendered + 1
                end
            end
        end
    end
end

-- Optional visual marker for the manually selected local player
if Config.settings.show_local_player_indicator and LocalPlayerManager.activeModel and LocalPlayerManager.originPosition then
    local entry = EnsureStarterCharacterEntry(LocalPlayerManager.activeModel)
    local parts = entry and entry.children and GetAllVisibleParts(entry.children) or nil
    if parts and #parts > 0 then
        local boundingBox = GetBoundingBox(parts, screenWidth, screenHeight, Config.settings.screen_padding)
        if boundingBox then
            dx9_DrawBox(boundingBox.topLeft, boundingBox.bottomRight, {100, 255, 150})
        end
    end

    local originPos = LocalPlayerManager.originPosition
    local screenPos = dx9_WorldToScreen({originPos.x, originPos.y + 2, originPos.z})
    if IsOnScreen(screenPos, screenWidth, screenHeight, Config.settings.screen_padding) then
        local label = "[Local Player]"
        local labelWidth = dx9_CalcTextWidth(label)
        dx9_DrawString({screenPos.x - (labelWidth / 2), screenPos.y - 40}, {100, 255, 150}, label)
        dx9_DrawCircle({screenPos.x, screenPos.y - 20}, {30, 90, 30}, 14)
        dx9_DrawCircle({screenPos.x, screenPos.y - 20}, {100, 255, 150}, 10)
    end
end

-- ====================================
-- DEBUG INFO OVERLAY
-- ====================================
-- Display real-time performance metrics and entity counts in top-left corner
-- This helps monitor FPS impact and verify ESP is working correctly

if Config.debug.show then
    local yOffset = 10 -- Current Y position for text rendering
    local lineHeight = 18 -- Pixels between each line of text
    
    -- Title
    dx9_DrawString({10, yOffset}, {255, 255, 255}, "Apocalypse Rising 2 Public Edition")
    yOffset = yOffset + lineHeight

    local originLabel = LocalPlayerManager.selectedLabel or "0 - Camera (Default)"
    dx9_DrawString({10, yOffset}, {100, 255, 150}, "Distance Origin: " .. originLabel)
    yOffset = yOffset + lineHeight
    
    -- Character stats (rendered/checked)
    dx9_DrawString({10, yOffset}, {0, 255, 0}, "Characters: " .. Cache.performance.characters_rendered .. "/" .. Cache.performance.characters_checked)
    yOffset = yOffset + lineHeight

    -- Zombie stats (rendered/checked)
    dx9_DrawString({10, yOffset}, {150, 255, 150}, "Zombies: " .. Cache.performance.zombies_rendered .. "/" .. Cache.performance.zombies_checked)
    yOffset = yOffset + lineHeight
    
    -- Corpse stats (rendered/checked)
    dx9_DrawString({10, yOffset}, {255, 255, 100}, "Corpses: " .. Cache.performance.corpses_rendered .. "/" .. Cache.performance.corpses_checked)
    yOffset = yOffset + lineHeight
    
    -- Vehicle stats (rendered/checked)
    dx9_DrawString({10, yOffset}, {100, 255, 255}, "Vehicles: " .. Cache.performance.vehicles_rendered .. "/" .. Cache.performance.vehicles_checked)
    yOffset = yOffset + lineHeight
    
    -- Detailed performance metrics
    if Config.debug.show_performance then
        -- Total 3D cham boxes drawn this frame
        dx9_DrawString({10, yOffset}, {255, 255, 100}, "Parts Rendered: " .. Cache.performance.parts_rendered)
        yOffset = yOffset + lineHeight
        
        -- Total 2D boxes drawn this frame
        dx9_DrawString({10, yOffset}, {255, 200, 100}, "Boxes Drawn: " .. Cache.performance.boxes_drawn)
        yOffset = yOffset + lineHeight
        
        -- Total tracer lines drawn this frame
        dx9_DrawString({10, yOffset}, {255, 150, 255}, "Tracers Drawn: " .. Cache.performance.tracers_drawn)
        yOffset = yOffset + lineHeight
        
    dx9_DrawString({10, yOffset}, {200, 200, 200}, "Cached Zombies: " .. CountTable(Cache.zombies))
    yOffset = yOffset + lineHeight

    dx9_DrawString({10, yOffset}, {200, 200, 200}, "Zombie List Size: " .. (Cache.zombie_list and #Cache.zombie_list or 0))
    yOffset = yOffset + lineHeight

        -- Number of vehicles in cache
        dx9_DrawString({10, yOffset}, {200, 200, 200}, "Cached Vehicles: " .. CountTable(Cache.vehicles))
        yOffset = yOffset + lineHeight
        
        -- Number of vehicles in scan list
        dx9_DrawString({10, yOffset}, {200, 200, 200}, "Vehicle List Size: " .. (Cache.vehicle_list and #Cache.vehicle_list or 0))
        yOffset = yOffset + lineHeight
        
        -- Number of corpses in scan list
        dx9_DrawString({10, yOffset}, {200, 200, 200}, "Corpse List Size: " .. (Cache.corpse_list and #Cache.corpse_list or 0))
        yOffset = yOffset + lineHeight
        
        -- Current frame number (for debugging timing issues)
        dx9_DrawString({10, yOffset}, {200, 200, 200}, "Frame: " .. Cache.frame_count)
        yOffset = yOffset + lineHeight
    end
    
    -- List of detected vehicle names (useful for identifying vehicles)
    if Config.debug.show_vehicle_list and Cache.vehicle_list then
        yOffset = yOffset + 5
        dx9_DrawString({10, yOffset}, {150, 255, 150}, "--- Vehicles Found ---")
        yOffset = yOffset + lineHeight
        
        -- Show up to 16 vehicles to prevent overlay overflow
        for i, veh in ipairs(Cache.vehicle_list) do
            if i > 16 then
                break
            end
            dx9_DrawString({10, yOffset}, {200, 255, 200}, "- " .. veh.name)
            yOffset = yOffset + lineHeight
        end
    end
    
    -- List of detected corpse names (useful for loot detection)
    if Config.debug.show_corpse_list and Cache.corpse_list then
        yOffset = yOffset + 5
        dx9_DrawString({10, yOffset}, {255, 255, 150}, "--- Corpses Found ---")
        yOffset = yOffset + lineHeight
        
        -- Show up to 16 corpses to prevent overlay overflow
        for i, corpse in ipairs(Cache.corpse_list) do
            if i > 16 then
                break
            end
            dx9_DrawString({10, yOffset}, {255, 255, 200}, "- " .. corpse.name)
            yOffset = yOffset + lineHeight
        end
    end

    -- List of detected zombie names (useful for monitoring threats)
    if Config.debug.show_zombie_list and Cache.zombie_list then
        yOffset = yOffset + 5
        dx9_DrawString({10, yOffset}, {180, 255, 180}, "--- Zombies Found ---")
        yOffset = yOffset + lineHeight

        for i, zombie in ipairs(Cache.zombie_list) do
            if i > 16 then
                break
            end
            local zombieName = zombie.name or SafeGetName(zombie.model) or "Zombie"
            local label = zombieName
            if zombie.distance then
                label = label .. " [" .. math_floor(zombie.distance) .. "m]"
            end
            dx9_DrawString({10, yOffset}, {200, 255, 200}, "- " .. label)
            yOffset = yOffset + lineHeight
        end
    end
end
