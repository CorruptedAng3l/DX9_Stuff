dx9.ShowConsole(true)

-- Load UI Library
local Lib = loadstring(dx9.Get("https://raw.githubusercontent.com/Brycki404/DXLibUI/refs/heads/main/main.lua"))()

-- ====================================
-- CONFIGURATION
-- ====================================

-- Main configuration table
-- This is persisted in _G to survive between script executions
Config = _G.Config or {
    settings = {
        menu_toggle = "[F2]", -- Keybind to show/hide the UI menu
        cache_refresh_rate = 30, -- How many frames between cache cleanups (lower = more frequent but slower)
        max_renders_per_frame = 50, -- Maximum characters to render per frame (prevents lag spikes)
        screen_padding = 100, -- Extra pixels around screen edges for rendering (prevents clipping)
        vehicle_scan_depth = 2, -- How deep to search for nested vehicle parts (higher = more thorough but slower)
    vehicle_scan_step = 40, -- How many vehicle candidates to evaluate per frame during scans
        local_player_selection = "0 - Camera (Default)", -- Default distance origin (camera or starter character label)
        show_local_player_indicator = false, -- Draw indicator on the selected local player model
    },
    characters = {
        enabled = true, -- Master toggle for character ESP
        chams = true, -- Draw 3D wireframe boxes around character limbs
        boxes = false, -- Draw 2D/corner boxes around entire character
        tracers = false, -- Draw lines from screen position to character
        head_dot = false, -- Draw small circle at character's head position
        names = true, -- Display character name above head
        distance = true, -- Display distance to character in meters
        health = true, -- Display current/max health values
        color = {255, 100, 100}, -- RGB color for character ESP (red by default)
        distance_limit = 100000, -- Maximum distance to render characters (100,000 studs covers entire map)
        min_limb_count = 3, -- Minimum body parts required to detect as valid character
        box_type = "2D Box", -- Type of box to draw: "2D Box", "3D Chams", or "Corner Box"
        tracer_origin = "Mouse", -- Where tracers start from: "Top", "Bottom", or "Mouse"
        toggle_key = "[F3]", -- Hotkey to toggle character ESP without opening the UI
        exclude_local_player = false, -- Hide ESP for the selected local player model
    },
    corpses = {
        enabled = true, -- Master toggle for corpse ESP
        chams = true, -- Draw 3D wireframe boxes around corpse limbs
        boxes = false, -- Draw 2D/corner boxes around entire corpse
        tracers = false, -- Draw lines from screen position to corpse
        head_dot = false, -- Draw small circle at corpse's head position
        names = true, -- Display corpse name above body
        distance = true, -- Display distance to corpse in meters
        health = false, -- Health display disabled for corpses (they're dead)
        color = {255, 255, 100}, -- RGB color for corpse ESP (yellow by default)
        distance_limit = 100000, -- Maximum distance to render corpses (100,000 studs covers entire map)
        min_limb_count = 3, -- Minimum body parts required to detect as valid corpse
        box_type = "2D Box", -- Type of box to draw: "2D Box", "3D Chams", or "Corner Box"
        tracer_origin = "Mouse", -- Where tracers start from: "Top", "Bottom", or "Mouse"
        toggle_key = "[F4]", -- Hotkey to toggle corpse ESP without opening the UI
    },
    vehicles = {
        enabled = true, -- Master toggle for vehicle ESP
        chams = true, -- Draw 3D wireframe boxes around vehicle parts
        boxes = false, -- Draw 2D/corner boxes around entire vehicle
        tracers = false, -- Draw lines from screen position to vehicle
        names = true, -- Display vehicle name at location
        distance = true, -- Display distance to vehicle in meters
        color = {100, 255, 255}, -- RGB color for vehicle ESP (cyan by default)
        distance_limit = 100000, -- Maximum distance to render vehicles (100,000 studs covers entire map)
        icon_size = 6, -- Size in pixels of the small box icon drawn at vehicle position (reduced from 10)
        box_type = "2D Box", -- Type of box to draw: "2D Box", "3D Chams", or "Corner Box"
        tracer_origin = "Top", -- Where tracers start from: "Top", "Bottom", or "Mouse"
        scan_nested = true, -- Whether to recursively scan for nested vehicle parts (more accurate but slower)
        toggle_key = "[F5]", -- Hotkey to toggle vehicle ESP without opening the UI
    },
    debug = {
        show = true, -- Show debug information overlay on screen
        show_performance = true, -- Show detailed performance metrics
        show_vehicle_list = false, -- Show list of detected vehicle names
        show_corpse_list = false, -- Show list of detected corpse names
    },
}

-- Store config globally so it persists between script reloads
if _G.Config == nil then
    _G.Config = Config
end
Config = _G.Config

-- Ensure newly added configuration entries exist when reloading older configs
Config.settings.local_player_selection = Config.settings.local_player_selection or "0 - Camera (Default)"
if Config.settings.show_local_player_indicator == nil then
    Config.settings.show_local_player_indicator = false
end
Config.characters.toggle_key = Config.characters.toggle_key or "[F3]"
Config.corpses.toggle_key = Config.corpses.toggle_key or "[F4]"
Config.vehicles.toggle_key = Config.vehicles.toggle_key or "[F5]"
if Config.characters.exclude_local_player == nil then
    Config.characters.exclude_local_player = false
end
Config.settings.vehicle_scan_step = Config.settings.vehicle_scan_step or 40

-- ====================================
-- GLOBAL CACHE
-- ====================================

-- Cache stores detected entities and performance data to avoid re-scanning every frame
-- This significantly improves performance by reusing previous scan results
if not _G.AR2_Cache then
    _G.AR2_Cache = {
        characters = {}, -- Stores validated character models with their data
        corpses = {}, -- Stores validated corpse models with their data
        vehicles = {}, -- Stores validated vehicle models with their parts
        starter_characters = {}, -- Stores starter character models for manual local player selection
        frame_count = 0, -- Total frames since script start
        last_refresh = 0, -- Frame number of last cache cleanup
        last_vehicle_scan = 0, -- Frame number of last vehicle folder scan
        last_corpse_scan = 0, -- Frame number of last corpse folder scan
        vehicle_list = {}, -- Array of detected vehicle model data
        corpse_list = {}, -- Array of detected corpse model data
        vehicle_scan_state = nil, -- Incremental scan progress for vehicles
        performance = { -- Performance metrics for current frame
            characters_checked = 0, -- How many character models were checked
            characters_rendered = 0, -- How many characters were actually drawn
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
}

local LocalPlayerManager = _G.AR2_LocalPlayerManager
LocalPlayerManager.selectedLabel = Config.settings.local_player_selection
LocalPlayerManager.lastSignatureUpdate = LocalPlayerManager.lastSignatureUpdate or 0

-- ====================================
-- HELPER FUNCTIONS
-- ====================================

-- Calculate 3D Euclidean distance between two position vectors
-- Returns 9999 if either position is invalid (useful for sorting)
local function GetDistance(p1, p2)
    if not p1 or not p2 then return 9999 end
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    local dz = p1.z - p2.z
    -- Optimization: Use squared distance for comparisons, only sqrt when needed for display
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Fast squared distance (no sqrt) - use for comparisons only
local function GetDistanceSquared(p1, p2)
    if not p1 or not p2 then return 99999999 end
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    local dz = p1.z - p2.z
    return dx * dx + dy * dy + dz * dz
end

-- Check if a screen position is visible within the viewport bounds
-- Padding allows rendering objects slightly off-screen to prevent pop-in
local function IsOnScreen(pos, width, height, padding)
    return pos and pos.x and pos.y and 
           pos.x > -padding and pos.y > -padding and 
           pos.x < width + padding and pos.y < height + padding
end

-- Add two 3D vectors component-wise (x+x, y+y, z+z)
local function addVec(a, b)
    return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end

-- Multiply a 3D vector by a scalar value (scale the vector)
local function scaleVec(v, s)
    return {x = v.x * s, y = v.y * s, z = v.z * s}
end

-- Count the number of entries in a table (works for both arrays and dictionaries)
local function CountTable(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Safely check if a model instance still exists in the game
-- Uses pcall to prevent errors if the model was destroyed
local function ModelExists(model)
    if not model or model == 0 then
        return false
    end
    
    local success, result = pcall(function()
        return dx9.GetType(model)
    end)
    
    return success and (result == "Model" or result == "Folder")
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

-- Draw a 3D wireframe box (cham) around a body part
-- This creates a full 3D cube outline using the part's position, rotation, and size
-- OPTIMIZED: Improved validation and early exit for better performance
local function DrawBodyPartChams(position, cframe, size, color, screenWidth, screenHeight, padding)
    -- Validate CFrame has all required directional vectors
    if not cframe or not cframe.RightVector or not cframe.UpVector or not cframe.LookVector then
        return false
    end
    
    -- Validate position has all coordinates
    if not position or not position.x or not position.y or not position.z then
        return false
    end
    
    -- Optimized validation: check if any vector components are invalid (NaN or Inf)
    local function isValidVector(vec)
        if not vec or not vec.x or not vec.y or not vec.z then return false end
        -- Combined NaN and Infinity check in one pass
        local x, y, z = vec.x, vec.y, vec.z
        return x == x and y == y and z == z and 
               x > -1e6 and x < 1e6 and y > -1e6 and y < 1e6 and z > -1e6 and z < 1e6
    end
    
    if not isValidVector(cframe.RightVector) or not isValidVector(cframe.UpVector) or not isValidVector(cframe.LookVector) then
        return false
    end
    
    -- Pre-calculate half-size values
    local hx, hy, hz = size.x * 0.5, size.y * 0.5, size.z * 0.5
    
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
        local success, screenPos = pcall(dx9.WorldToScreen, {world.x, world.y, world.z})
        
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
    
    -- Define the 12 edges of a cube (connections between corner indices)
    local edges = {
        {1,2},{2,4},{4,3},{3,1}, -- Bottom face (4 edges)
        {5,6},{6,8},{8,7},{7,5}, -- Top face (4 edges)
        {1,5},{2,6},{3,7},{4,8}  -- Vertical connecting edges (4 edges)
    }
    
    -- Draw each edge if both endpoints are visible on screen
    local drawnEdges = 0
    for i = 1, #edges do
        local edge = edges[i]
        local p1, p2 = screenPoints[edge[1]], screenPoints[edge[2]]
        if p1.valid and p2.valid then
            -- Draw line between the two screen-space corner positions
            dx9.DrawLine({p1.x, p1.y}, {p2.x, p2.y}, color)
            drawnEdges = drawnEdges + 1
        end
    end
    
    -- Return true if we successfully drew at least one edge
    return drawnEdges > 0
end

-- Calculate a 2D bounding box that encompasses all visible parts
-- FIXED: Uses statistical outlier rejection to prevent warping from behind-camera parts
-- Returns a table with topLeft, bottomRight corners and center point
local function GetBoundingBox(parts, screenWidth, screenHeight, padding)
    if not parts or #parts == 0 then
        return nil
    end
    
    local screenPoints = {}
    local pointCount = 0
    
    -- First pass: collect all screen points
    for i = 1, #parts do
        local part = parts[i]
        local success, partPos = pcall(dx9.GetPosition, part)
        
        if success and partPos and partPos.x then
            local px, py, pz = partPos.x, partPos.y, partPos.z
            
            -- Basic validation
            if px == px and py == py and pz == pz and 
               px > -1e6 and px < 1e6 and py > -1e6 and py < 1e6 and pz > -1e6 and pz < 1e6 then
                
                local success2, screenPos = pcall(dx9.WorldToScreen, {px, py, pz})
                
                if success2 and screenPos and screenPos.x and screenPos.y then
                    local sx, sy = screenPos.x, screenPos.y
                    
                    -- Only validate that it's a number, not NaN
                    if sx == sx and sy == sy then
                        pointCount = pointCount + 1
                        screenPoints[pointCount] = {x = sx, y = sy}
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
    local sortedX = {}
    local sortedY = {}
    for i = 1, pointCount do
        sortedX[i] = screenPoints[i].x
        sortedY[i] = screenPoints[i].y
    end
    table.sort(sortedX)
    table.sort(sortedY)
    
    local medianX = sortedX[math.floor(pointCount / 2)]
    local medianY = sortedY[math.floor(pointCount / 2)]
    
    -- Calculate standard deviation to determine outlier threshold
    local sumDistSq = 0
    for i = 1, pointCount do
        local dx = screenPoints[i].x - medianX
        local dy = screenPoints[i].y - medianY
        sumDistSq = sumDistSq + (dx * dx + dy * dy)
    end
    local stdDev = math.sqrt(sumDistSq / pointCount)
    
    -- Determine max distance from median (reject extreme outliers)
    -- Use adaptive threshold: for tight clusters use screen-based limit, for spread clusters use stdDev
    local maxScreenDist = math.max(screenWidth, screenHeight) * 1.5
    local maxAllowedDist = math.min(stdDev * 3, maxScreenDist)  -- 3 standard deviations or screen limit
    
    -- Also enforce absolute screen bounds
    local absoluteMinX = -screenWidth * 0.5
    local absoluteMaxX = screenWidth * 1.5
    local absoluteMinY = -screenHeight * 0.5
    local absoluteMaxY = screenHeight * 1.5
    
    -- Second pass: filter outliers and calculate bounding box
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local validPoints = 0
    
    for i = 1, pointCount do
        local point = screenPoints[i]
        local dx = point.x - medianX
        local dy = point.y - medianY
        local distFromMedian = math.sqrt(dx * dx + dy * dy)
        
        -- Accept point if:
        -- 1. Within statistical threshold from median
        -- 2. Within absolute screen bounds
        if distFromMedian <= maxAllowedDist and
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
    dx9.DrawBox(topLeft, bottomRight, color)
end

-- Draw a corner-style box (only draws L-shaped corners instead of full rectangle)
-- This looks cleaner and less obtrusive than full boxes
-- OPTIMIZED: Pre-calculate values for better performance
local function DrawCornerBox(topLeft, bottomRight, color)
    local x1, y1 = topLeft[1], topLeft[2]
    local x2, y2 = bottomRight[1], bottomRight[2]
    local width = x2 - x1
    local height = y2 - y1
    -- Corner size is 25% of the smallest dimension
    local cornerSize = math.min(width, height) * 0.25
    
    -- Pre-calculate corner positions
    local x1_plus = x1 + cornerSize
    local x2_minus = x2 - cornerSize
    local y1_plus = y1 + cornerSize
    local y2_minus = y2 - cornerSize
    
    -- Top-left corner (two lines forming an L)
    dx9.DrawLine({x1, y1}, {x1_plus, y1}, color)
    dx9.DrawLine({x1, y1}, {x1, y1_plus}, color)
    
    -- Top-right corner
    dx9.DrawLine({x2, y1}, {x2_minus, y1}, color)
    dx9.DrawLine({x2, y1}, {x2, y1_plus}, color)
    
    -- Bottom-left corner
    dx9.DrawLine({x1, y2}, {x1_plus, y2}, color)
    dx9.DrawLine({x1, y2}, {x1, y2_minus}, color)
    
    -- Bottom-right corner
    dx9.DrawLine({x2, y2}, {x2_minus, y2}, color)
    dx9.DrawLine({x2, y2}, {x2, y2_minus}, color)
end

-- Draw a tracer line and increment the performance counter
local function DrawTracer(fromPos, toPos, color)
    dx9.DrawLine(fromPos, toPos, color)
    Cache.performance.tracers_drawn = Cache.performance.tracers_drawn + 1
end

-- OPTIMIZED: Improved character model validation with better caching
local function IsCharacterModel(model, modelAddress)
    if Cache.characters[modelAddress] then
        if not ModelExists(model) then
            Cache.characters[modelAddress] = nil
            return false, 0
        end
        return Cache.characters[modelAddress].isCharacter, Cache.characters[modelAddress].partCount
    end
    
    local children = dx9.GetChildren(model)
    if not children or #children == 0 then
        return false, 0
    end
    
    local partCount = 0
    local hasHumanoid = false
    local humanoidRootPart = nil
    
    for i = 1, #children do
        local child = children[i]
        local success, childType = pcall(dx9.GetType, child)
        
        if success then
            if childType == "Humanoid" then
                hasHumanoid = true
            elseif childType == "Part" or childType == "MeshPart" then
                partCount = partCount + 1
                
                local success2, childName = pcall(dx9.GetName, child)
                
                if success2 and childName == "HumanoidRootPart" then
                    humanoidRootPart = child
                end
            end
        end
    end
    
    local isCharacter = hasHumanoid and partCount >= Config.characters.min_limb_count
    
    Cache.characters[modelAddress] = {
        isCharacter = isCharacter,
        partCount = partCount,
        children = children,
        humanoidRootPart = humanoidRootPart,
        lastSeen = Cache.frame_count
    }
    
    return isCharacter, partCount
end

-- OPTIMIZED: Improved corpse model validation
local function IsCorpseModel(model, modelAddress)
    if Cache.corpses[modelAddress] then
        if not ModelExists(model) then
            Cache.corpses[modelAddress] = nil
            return false, 0
        end
        return Cache.corpses[modelAddress].isCorpse, Cache.corpses[modelAddress].partCount
    end
    
    local children = dx9.GetChildren(model)
    if not children or #children == 0 then
        return false, 0
    end
    
    local partCount = 0
    local hasHumanoidRootPart = false
    local humanoidRootPart = nil
    local hasHumanoid = false
    
    for i = 1, #children do
        local child = children[i]
        local success, childType = pcall(dx9.GetType, child)
        
        if success then
            if childType == "Humanoid" then
                hasHumanoid = true
            elseif childType == "Part" or childType == "MeshPart" then
                partCount = partCount + 1
                
                local success2, childName = pcall(dx9.GetName, child)
                
                if success2 and childName == "HumanoidRootPart" then
                    hasHumanoidRootPart = true
                    humanoidRootPart = child
                end
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
local function GetReferencePosition(model, modelAddress, cacheTable)
    local cachedData = cacheTable[modelAddress]
    
    if cachedData and cachedData.humanoidRootPart then
        local success, pos = pcall(dx9.GetPosition, cachedData.humanoidRootPart)
        
        if success and pos and pos.x then
            cachedData.refPos = pos
            cachedData.refPart = cachedData.humanoidRootPart
            return pos, cachedData.humanoidRootPart
        else
            cachedData.humanoidRootPart = nil
        end
    end
    
    if cachedData and cachedData.refPart then
        local success, pos = pcall(dx9.GetPosition, cachedData.refPart)
        
        if success and pos and pos.x then
            cachedData.refPos = pos
            return pos, cachedData.refPart
        else
            cachedData.refPart = nil
            cachedData.refPos = nil
        end
    end
    
    local children = cachedData and cachedData.children or dx9.GetChildren(model)
    if not children then return nil end
    
    -- Priority parts list for faster lookup
    local priorityNames = {"HumanoidRootPart", "Root", "Torso", "UpperTorso", "Body", "Base"}
    
    for i = 1, #children do
        local child = children[i]
        local success, childType = pcall(dx9.GetType, child)
        
        if success and (childType == "Part" or childType == "MeshPart") then
            local success2, childName = pcall(dx9.GetName, child)
            
            if success2 and childName then
                for j = 1, #priorityNames do
                    if childName:find(priorityNames[j]) then
                        local success3, pos = pcall(dx9.GetPosition, child)
                        
                        if success3 and pos and pos.x then
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
        local success, childType = pcall(dx9.GetType, child)
        
        if success and (childType == "Part" or childType == "MeshPart") then
            local success2, pos = pcall(dx9.GetPosition, child)
            
            if success2 and pos and pos.x then
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
local function GetHeadPosition(children)
    for i = 1, #children do
        local child = children[i]
        local success, childType = pcall(dx9.GetType, child)
        
        if success and (childType == "Part" or childType == "MeshPart") then
            local success2, partName = pcall(dx9.GetName, child)
            
            if success2 and partName and partName:lower():find("head") then
                local success3, pos = pcall(dx9.GetPosition, child)
                
                if success3 and pos then
                    return pos
                end
            end
        end
    end
    
    return nil
end

-- OPTIMIZED: Get all visible parts with better performance
local function GetAllVisibleParts(children)
    local parts = {}
    local count = 0
    
    for i = 1, #children do
        local child = children[i]
        local success, childType = pcall(dx9.GetType, child)
        
        if success and (childType == "Part" or childType == "MeshPart") then
            count = count + 1
            parts[count] = child
        end
    end
    
    return parts
end

local function CollectNamesForSignature(instance, list, depth, maxDepth)
    if depth > maxDepth then
        return
    end

    local children = dx9.GetChildren(instance)
    if not children then
        return
    end

    for i = 1, #children do
        local child = children[i]
        local successName, childName = pcall(dx9.GetName, child)
        local successType, childType = pcall(dx9.GetType, child)

        if successName and successType and childName and childType then
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
    local children = entry and entry.children or dx9.GetChildren(model)
    if not children then
        return nil
    end

    local equipmentFolders = {}
    for i = 1, #children do
        local child = children[i]
        local successName, childName = pcall(dx9.GetName, child)
        if successName and childName then
            if childName == "Equipment" then
                equipmentFolders[#equipmentFolders + 1] = child
            else
                local successType, childType = pcall(dx9.GetType, child)
                if successType and childType and (childType == "Part" or childType == "MeshPart") then
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

    table.sort(signatureParts)
    return table.concat(signatureParts, "|")
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

    local children = dx9.GetChildren(model) or {}
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
        }
        Cache.starter_characters[model] = entry
    else
        entry.lastSeen = Cache.frame_count
        entry.children = children
    end

    UpdateStarterCharacterSignature(entry, model)

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

    local function addStarterModel(model, count)
        if not model or not ModelExists(model) or currentModels[model] then
            return count
        end

        local successName, actualName = pcall(dx9.GetName, model)
        local displayName = successName and actualName and actualName ~= "" and actualName or "Starter"

        local label = string.format("%d - %s", count + 1, displayName)
        local optionIndex = count + 2 -- +1 for zero-based table, +1 for camera option

        options[optionIndex] = label
        models[optionIndex] = model
        valueToIndex[label] = optionIndex
        currentModels[model] = true
        EnsureStarterCharacterEntry(model)

        if previousModel and model == previousModel then
            matchedIndex = optionIndex
        end

        return count + 1
    end

    local starterCount = 0

    if starterFolder then
        local starters = dx9.GetChildren(starterFolder)
        if starters then
            for _, starter in ipairs(starters) do
                local success, typeName = pcall(dx9.GetType, starter)
                if success and typeName == "Model" then
                    starterCount = addStarterModel(starter, starterCount)
                end
            end
        end
    end

    LocalPlayerManager.scanCharactersFolder = charactersFolder

    if charactersFolder then
        local chars = dx9.GetChildren(charactersFolder)
        if chars then
            for _, character in ipairs(chars) do
                local successType, typeName = pcall(dx9.GetType, character)
                if successType and typeName == "Model" then
                    local successName, charName = pcall(dx9.GetName, character)
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

    if LocalPlayerManager.selectedIndex and LocalPlayerManager.selectedIndex > 1 then
        local chosenModel = models[LocalPlayerManager.selectedIndex]
        LocalPlayerManager.lastSelectedModel = chosenModel
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
        end
    else
        LocalPlayerManager.lastSelectedModel = nil
        LocalPlayerManager.selectedSignature = nil
        LocalPlayerManager.lastSignatureUpdate = 0
    end

    if LocalPlayerManager.dropdown then
        LocalPlayerManager.dropdown:SetValues(options)
        if LocalPlayerManager.dropdown.Value ~= desiredLabel then
            LocalPlayerManager.dropdown:SetValue(desiredLabel)
        end
    end
end

-- Check if a model is a valid vehicle by looking for vehicle-specific components
-- OPTIMIZED: Better early exit and reduced redundant checks
-- Returns: isVehicle (boolean), children (table or nil)
local function IsVehicleModel(model, depth)
    -- Limit recursion depth to prevent infinite loops and performance issues
    if depth > Config.settings.vehicle_scan_depth then
        return false, nil
    end
    
    local children = dx9.GetChildren(model)
    if not children or #children == 0 then
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
        local success, childType = pcall(dx9.GetType, child)
        
        if success then
            -- VehicleSeat is definitive proof of a vehicle
            if childType == "VehicleSeat" then
                return true, children -- Early exit
            end
            
            -- Count parts for vehicle detection heuristic
            if childType == "Part" or childType == "MeshPart" or childType == "Model" then
                partCount = partCount + 1
                
                -- Only check part names if we haven't already confirmed vehicle parts
                if not hasVehicleParts then
                    local success2, childName = pcall(dx9.GetName, child)
                    
                    if success2 and childName then
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
-- Used for vehicles which may have nested folder structures
-- maxParts limits the number of parts collected to prevent performance issues
local function GetAllPartsFromModel(model, maxParts)
    local parts = {}
    local visited = {}
    local count = 0
    
    -- Recursive scanning function
    local function recursiveScan(obj, depth)
        -- Stop if we've reached max parts or max depth
        if depth > 3 or count >= maxParts then
            return
        end
        
        -- Prevent infinite loops from circular references
        if visited[obj] then
            return
        end
        visited[obj] = true
        
        local success, objType = pcall(dx9.GetType, obj)
        
        if success then
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
                local children = dx9.GetChildren(obj)
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

    local success, children = pcall(dx9.GetChildren, folder)
    if not success or not children or #children == 0 then
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
                    local success3, subType = pcall(dx9.GetType, subChild)
                    if success3 and (subType == "Model" or subType == "Folder") then
                        local isSubVehicle, subVehicleChildren = IsVehicleModel(subChild, 2)
                        if isSubVehicle then
                            local success4, subVehicleName = pcall(dx9.GetName, subChild)
                            state.results[#state.results + 1] = {
                                model = subChild,
                                name = success4 and subVehicleName or "Vehicle",
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
                local success, childType = pcall(dx9.GetType, child)
                if success and (childType == "Model" or childType == "Folder") then
                    local isVehicle, vehicleChildren = IsVehicleModel(child, 1)
                    if isVehicle then
                        local success2, vehicleName = pcall(dx9.GetName, child)
                        state.results[#state.results + 1] = {
                            model = child,
                            name = success2 and vehicleName or "Vehicle",
                            children = vehicleChildren
                        }
                    else
                        local successChildren, subChildren = pcall(dx9.GetChildren, child)
                        if successChildren and subChildren and #subChildren > 0 then
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
local function ScanForCorpses(folder)
    local corpses = {}
    local cCount = 0
    
    if not folder then
        return corpses
    end
    
    local children = dx9.GetChildren(folder)
    if not children or #children == 0 then
        return corpses
    end
    
    for i = 1, #children do
        local child = children[i]
        local success, childType = pcall(dx9.GetType, child)
        
        if success and childType == "Model" then
            local isCorpse, partCount = IsCorpseModel(child, child)
            
            if isCorpse then
                local success2, corpseName = pcall(dx9.GetName, child)
                
                cCount = cCount + 1
                corpses[cCount] = {
                    model = child,
                    name = success2 and corpseName or "Corpse",
                    partCount = partCount
                }
            end
        end
    end
    
    return corpses
end

local function RenderEntityESP(entityData, config, distanceOrigin, screenWidth, screenHeight, cacheTable, isCorpse)
    if not ModelExists(entityData.model) then
        return false
    end
    
    local cachedData = cacheTable[entityData.model]
    if not cachedData then
        return false
    end

    if config.exclude_local_player and not isCorpse and LocalPlayerManager and LocalPlayerManager.activeModel and entityData.model == LocalPlayerManager.activeModel then
        return false
    end
    
    local children = cachedData.children
    if not children then
        return false
    end
    
    local referencePos = GetReferencePosition(entityData.model, entityData.model, cacheTable)
    if not referencePos then
        return false
    end
    
    local distance = GetDistance(distanceOrigin, referencePos)
    if distance > config.distance_limit then
        return false
    end
    
    local visibleParts = GetAllVisibleParts(children)
    if #visibleParts == 0 then
        return false
    end
    
    local anyPartVisible = false
    local headPos = nil
    local healthInfo = nil
    local currentColor = config.color
    
    if not isCorpse and config.health then
        for _, child in next, children do
            local success, childType = pcall(function()
                return dx9.GetType(child)
            end)
            
            if success and childType == "Humanoid" then
                local hp = dx9.GetHealth(child)
                local maxHp = dx9.GetMaxHealth(child)
                if hp and maxHp then
                    healthInfo = {current = math.floor(hp), max = math.floor(maxHp)}
                end
                break
            end
        end
    end
    
    if config.boxes and config.box_type ~= "3D Chams" then
        -- Use statistical outlier filtering for all characters
        local boundingBox = GetBoundingBox(visibleParts, screenWidth, screenHeight, Config.settings.screen_padding)
        
        if boundingBox then
            anyPartVisible = true
            
            if config.box_type == "2D Box" then
                Draw2DBox(boundingBox.topLeft, boundingBox.bottomRight, currentColor)
            elseif config.box_type == "Corner Box" then
                DrawCornerBox(boundingBox.topLeft, boundingBox.bottomRight, currentColor)
            end
            
            Cache.performance.boxes_drawn = Cache.performance.boxes_drawn + 1
        end
    end
    
    if config.chams or (config.boxes and config.box_type == "3D Chams") then
        for _, part in next, visibleParts do
            local success, partPos = pcall(function()
                return dx9.GetPosition(part)
            end)
            
            if success and partPos and partPos.x then
                local success2, quickScreen = pcall(function()
                    return dx9.WorldToScreen({partPos.x, partPos.y, partPos.z})
                end)
                
                if success2 and IsOnScreen(quickScreen, screenWidth, screenHeight, Config.settings.screen_padding) then
                    anyPartVisible = true
                    
                    local success3, partCFrame = pcall(function()
                        return dx9.GetCFrame(part)
                    end)
                    
                    if success3 and partCFrame then
                        local partName = nil
                        local success4, name = pcall(function()
                            return dx9.GetName(part)
                        end)
                        if success4 then
                            partName = name
                            if partName and partName:lower():find("head") then
                                headPos = partPos
                            end
                        end
                        
                        local partSize = EstimatePartSize(partName)
                        
                        local drawn = DrawBodyPartChams(partPos, partCFrame, partSize, currentColor, screenWidth, screenHeight, Config.settings.screen_padding)
                        if drawn then
                            Cache.performance.parts_rendered = Cache.performance.parts_rendered + 1
                        end
                    end
                end
            end
        end
    end
    
    if config.head_dot then
        if not headPos then
            headPos = GetHeadPosition(children)
        end
        
        if headPos then
            local screenPos = dx9.WorldToScreen({headPos.x, headPos.y, headPos.z})
            
            if IsOnScreen(screenPos, screenWidth, screenHeight, 0) then
                dx9.DrawCircle({screenPos.x, screenPos.y}, currentColor, 5)
            end
        end
    end
    
    if config.tracers then
        local tracerPos = headPos or referencePos
        if tracerPos then
            local toScreen = dx9.WorldToScreen({tracerPos.x, tracerPos.y, tracerPos.z})
            
            if IsOnScreen(toScreen, screenWidth, screenHeight, 0) then
                local fromScreen
                
                if config.tracer_origin == "Top" then
                    fromScreen = {screenWidth / 2, 0}
                elseif config.tracer_origin == "Bottom" then
                    fromScreen = {screenWidth / 2, screenHeight}
                elseif config.tracer_origin == "Mouse" then
                    local mouse = dx9.GetMouse()
                    fromScreen = {mouse.x, mouse.y}
                else
                    fromScreen = {screenWidth / 2, screenHeight}
                end
                
                DrawTracer(fromScreen, {toScreen.x, toScreen.y}, currentColor)
            end
        end
    end
    
    if anyPartVisible and (config.names or config.distance or (config.health and healthInfo)) then
        local labelPos = headPos or referencePos
        if labelPos then
            local screenPos = dx9.WorldToScreen({labelPos.x, labelPos.y + 2, labelPos.z})
            
            if IsOnScreen(screenPos, screenWidth, screenHeight, 0) then
                local nameText = ""
                
                if config.names then
                    local modelName = dx9.GetName(entityData.model)
                    nameText = modelName or (isCorpse and "Corpse" or "Character")
                end
                
                if config.health and healthInfo and not isCorpse then
                    if nameText ~= "" then
                        nameText = nameText .. " | " .. healthInfo.current .. "/" .. healthInfo.max
                    else
                        nameText = healthInfo.current .. "/" .. healthInfo.max
                    end
                end
                
                if config.distance then
                    if nameText ~= "" then
                        nameText = nameText .. " [" .. math.floor(distance) .. "m]"
                    else
                        nameText = "[" .. math.floor(distance) .. "m]"
                    end
                end
                
                if nameText ~= "" then
                    local textWidth = dx9.CalcTextWidth(nameText)
                    local textX = screenPos.x - (textWidth / 2)
                    local textY = screenPos.y
                    
                    dx9.DrawString({textX, textY}, currentColor, nameText)
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
    Title = "Apocalypse Rising 2 ESP",
    Size = {700, 600},
    Resizable = true,
    ToggleKey = Config.settings.menu_toggle,
    FooterToggle = true,
    FooterRGB = true,
})

local Tabs = {
    characters = Window:AddTab("Characters"),
    corpses = Window:AddTab("Corpses"),
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
    return string.format("%s: %s", label, key)
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

CharGroupboxes.visual:AddToggle({
    Default = Config.characters.health,
    Text = "Health",
}):OnChanged(function(value)
    Config.characters.health = value
end)

CharGroupboxes.visual:AddColorPicker({
    Default = Config.characters.color,
    Text = "Color",
}):OnChanged(function(value)
    Config.characters.color = value
end)

CharGroupboxes.visual:AddSlider({
    Default = Config.characters.distance_limit,
    Text = "Max Distance",
    Min = 50,
    Max = 100000,
    Rounding = 0,
}):OnChanged(function(value)
    Config.characters.distance_limit = value
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

CharGroupboxes.extra:AddDropdown({
    Default = 1,
    Text = "Box Type",
    Values = {"2D Box", "3D Chams", "Corner Box"},
}):OnChanged(function(value)
    Config.characters.box_type = value
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
    Min = 50,
    Max = 100000,
    Rounding = 0,
}):OnChanged(function(value)
    Config.corpses.distance_limit = value
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

CorpseGroupboxes.extra:AddDropdown({
    Default = 1,
    Text = "Box Type",
    Values = {"2D Box", "3D Chams", "Corner Box"},
}):OnChanged(function(value)
    Config.corpses.box_type = value
end)

CorpseGroupboxes.extra:AddDropdown({
    Default = 3,
    Text = "Tracer Origin",
    Values = {"Top", "Bottom", "Mouse"},
}):OnChanged(function(value)
    Config.corpses.tracer_origin = value
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
    Min = 100,
    Max = 100000,
    Rounding = 0,
}):OnChanged(function(value)
    Config.vehicles.distance_limit = value
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

VehicleGroupboxes.extra:AddDropdown({
    Default = 1,
    Text = "Box Type",
    Values = {"2D Box", "3D Chams", "Corner Box"},
}):OnChanged(function(value)
    Config.vehicles.box_type = value
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
    Max = 100,
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

SettingsGroupboxes.debug:AddBlank(10)
SettingsGroupboxes.debug:AddLabel("Debug info appears in\ntop-left corner")

-- ====================================
-- MAIN LOOP
-- ====================================
-- This code executes EVERY FRAME (typically 60 times per second)
-- All ESP rendering and entity detection happens here

-- Increment frame counter for timing-based operations
Cache.frame_count = Cache.frame_count + 1

-- Reset performance metrics for this frame
Cache.performance = {
    characters_checked = 0, -- How many character models we examined
    characters_rendered = 0, -- How many characters we actually drew ESP for
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
local Workspace = dx9.FindFirstChild(Datamodel, 'Workspace')

-- If Workspace doesn't exist, exit early (game hasn't loaded)
if not Workspace then
    return
end

if LocalPlayerManager.dropdown and not LocalPlayerManager.initialized then
    UpdateStarterCharacterOptions(
        dx9.FindFirstChild(Workspace, 'StarterCharacters'),
        dx9.FindFirstChild(Workspace, 'Characters')
    )
    LocalPlayerManager.initialized = true
end

-- Get screen dimensions for on-screen checks and UI positioning
local screenWidth = dx9.size().width
local screenHeight = dx9.size().height

-- Get camera position for distance calculations
-- All distances are measured from the camera's position
local Camera = dx9.FindFirstChild(Workspace, "Camera")
local cameraPos = nil
if Camera then
    local cameraPart = dx9.FindFirstChild(Camera, "CameraSubject") or dx9.FindFirstChild(Camera, "Focus")
    if not cameraPart or cameraPart == 0 then
        -- Try to get a part from camera to get its position
        local cameraChildren = dx9.GetChildren(Camera)
        if cameraChildren and #cameraChildren > 0 then
            for i = 1, #cameraChildren do
                local child = cameraChildren[i]
                local success, childType = pcall(dx9.GetType, child)
                if success and (childType == "Part" or childType == "MeshPart") then
                    cameraPart = child
                    break
                end
            end
        end
    end
    
    if cameraPart and cameraPart ~= 0 then
        local success, pos = pcall(dx9.GetPosition, cameraPart)
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
else
    LocalPlayerManager.selectedIndex = 1
    LocalPlayerManager.lastSelectedModel = nil
end

local distanceOrigin = cameraPos
LocalPlayerManager.activeModel = nil
LocalPlayerManager.originPosition = distanceOrigin

if LocalPlayerManager.selectedIndex and LocalPlayerManager.selectedIndex > 1 then
    local selectedModel = LocalPlayerManager.models and LocalPlayerManager.models[LocalPlayerManager.selectedIndex] or nil
    if selectedModel and ModelExists(selectedModel) then
        local entry = EnsureStarterCharacterEntry(selectedModel)
        if entry then
            local signature = entry.signatureHash or UpdateStarterCharacterSignature(entry, selectedModel)
            if signature then
                LocalPlayerManager.selectedSignature = signature
                LocalPlayerManager.lastSignatureUpdate = Cache.frame_count
            else
                LocalPlayerManager.selectedSignature = nil
                LocalPlayerManager.lastSignatureUpdate = 0
            end
        end
        local originPos = GetReferencePosition(selectedModel, selectedModel, Cache.starter_characters)
        if originPos then
            distanceOrigin = originPos
            LocalPlayerManager.activeModel = selectedModel
            LocalPlayerManager.originPosition = originPos
            LocalPlayerManager.lastSelectedModel = selectedModel
        end
    else
        LocalPlayerManager.lastSelectedModel = nil
    end
else
    LocalPlayerManager.lastSelectedModel = nil
end

-- ====================================
-- CACHE CLEANUP
-- ====================================
-- Periodically remove destroyed/invalid entities from cache
-- This prevents memory leaks and stale data

local shouldRefresh = (Cache.frame_count - Cache.last_refresh) >= Config.settings.cache_refresh_rate

if shouldRefresh then
    Cache.last_refresh = Cache.frame_count
    
    -- Get current entity folders from Workspace
    local CharactersFolder = dx9.FindFirstChild(Workspace, 'Characters')
    local CorpsesFolder = dx9.FindFirstChild(Workspace, 'Corpses')
    local VehiclesFolder = dx9.FindFirstChild(Workspace, 'Vehicles')
    local StarterCharactersFolder = dx9.FindFirstChild(Workspace, 'StarterCharacters')
    UpdateStarterCharacterOptions(StarterCharactersFolder, CharactersFolder)
    -- Build sets of currently existing entities
    local currentCharacters = {}
    local currentCorpses = {}
    local currentVehicles = {}
    
    if CharactersFolder then
        local chars = dx9.GetChildren(CharactersFolder)
        if chars then
            for _, char in next, chars do
                currentCharacters[char] = true
            end
        end
    end
    
    if CorpsesFolder then
        local corpses = dx9.GetChildren(CorpsesFolder)
        if corpses then
            for _, corpse in next, corpses do
                currentCorpses[corpse] = true
            end
        end
    end
    
    if VehiclesFolder then
        local vehs = dx9.GetChildren(VehiclesFolder)
        if vehs then
            for _, veh in next, vehs do
                currentVehicles[veh] = true
            end
        end
    end
    
    -- Remove cached entities that no longer exist in the game
    for addr, _ in next, Cache.characters do
        if not currentCharacters[addr] then
            Cache.characters[addr] = nil
        end
    end
    
    for addr, _ in next, Cache.corpses do
        if not currentCorpses[addr] then
            Cache.corpses[addr] = nil
        end
    end
    
    for addr, _ in next, Cache.vehicles do
        if not currentVehicles[addr] then
            Cache.vehicles[addr] = nil
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
    
    local VehiclesFolder = dx9.FindFirstChild(Workspace, 'Vehicles')
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
    
    local CorpsesFolder = dx9.FindFirstChild(Workspace, 'Corpses')
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
    local CharactersFolder = dx9.FindFirstChild(Workspace, 'Characters')
    
    if CharactersFolder then
        local FolderChildren = dx9.GetChildren(CharactersFolder)
        
        if FolderChildren then
            -- First pass: validate all characters and calculate distances
            -- We do this in two passes to allow sorting by distance (closest first)
            local characterDistances = {}
            
            for _, object in next, FolderChildren do
                local success, objectType = pcall(function()
                    return dx9.GetType(object)
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
                                    -- Calculate distance from camera to character
                                    local distance = GetDistance(distanceOrigin, referencePos)
                                    
                                    -- Only render characters within the configured distance limit
                                    if distance <= Config.characters.distance_limit then
                                        table.insert(characterDistances, {
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
            table.sort(characterDistances, function(a, b)
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
-- PROCESS CORPSES
-- ====================================
-- Render ESP for corpses using the cached corpse list
-- Corpses are scanned less frequently (every 60 frames) since they don't move

if Config.corpses.enabled and Cache.corpse_list then
    local corpseDistances = {}
    
    -- Check each corpse from the cached list
    for _, corpseData in next, Cache.corpse_list do
        if ModelExists(corpseData.model) then
            Cache.performance.corpses_checked = Cache.performance.corpses_checked + 1
            
            -- Get corpse position from cache or calculate it
            local referencePos = GetReferencePosition(corpseData.model, corpseData.model, Cache.corpses)
            
            if referencePos then
                local distance = GetDistance(distanceOrigin, referencePos)
                
                -- Only render corpses within distance limit
                if distance <= Config.corpses.distance_limit then
                    table.insert(corpseDistances, {
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
    table.sort(corpseDistances, function(a, b)
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

if Config.vehicles.enabled and Cache.vehicle_list then
    local vehicleDistances = {}
    
    -- First pass: Calculate distances for all valid vehicles
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
                local distance = GetDistance(distanceOrigin, referencePos)
                
                -- Only render vehicles within distance limit
                if distance <= Config.vehicles.distance_limit then
                    table.insert(vehicleDistances, {
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
    table.sort(vehicleDistances, function(a, b)
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
            local allParts = Cache.vehicles[modelData.model].allParts or dx9.GetChildren(modelData.model)
            
            if allParts and #allParts > 0 then
                local anyPartVisible = false
                local currentColor = Config.vehicles.color
                
                -- Draw 2D bounding box around entire vehicle if enabled
                if Config.vehicles.boxes and Config.vehicles.box_type ~= "3D Chams" then
                    local boundingBox = GetBoundingBox(allParts, screenWidth, screenHeight, Config.settings.screen_padding)
                    
                    if boundingBox then
                        anyPartVisible = true
                        
                        if Config.vehicles.box_type == "2D Box" then
                            Draw2DBox(boundingBox.topLeft, boundingBox.bottomRight, currentColor)
                        elseif Config.vehicles.box_type == "Corner Box" then
                            DrawCornerBox(boundingBox.topLeft, boundingBox.bottomRight, currentColor)
                        end
                        
                        Cache.performance.boxes_drawn = Cache.performance.boxes_drawn + 1
                    end
                end
                
                -- Draw 3D chams around individual vehicle parts if enabled
                if Config.vehicles.chams or (Config.vehicles.boxes and Config.vehicles.box_type == "3D Chams") then
                    local maxPartsToRender = 30 -- Limit parts per vehicle to prevent FPS drops
                    local partsRendered = 0
                    
                    for _, part in next, allParts do
                        if partsRendered >= maxPartsToRender then
                            break
                        end
                        
                        -- Get part's world position
                        local success, partPos = pcall(function()
                            return dx9.GetPosition(part)
                        end)
                        
                        if success and partPos and partPos.x then
                            -- Quick screen-space check before expensive CFrame operations
                            local success2, quickScreen = pcall(function()
                                return dx9.WorldToScreen({partPos.x, partPos.y, partPos.z})
                            end)
                            
                            if success2 and IsOnScreen(quickScreen, screenWidth, screenHeight, Config.settings.screen_padding) then
                                anyPartVisible = true
                                
                                -- Get part's rotation/orientation for 3D box
                                local success3, partCFrame = pcall(function()
                                    return dx9.GetCFrame(part)
                                end)
                                
                                if success3 and partCFrame then
                                    -- Get part name for size estimation
                                    local partName = nil
                                    local success4, name = pcall(function()
                                        return dx9.GetName(part)
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
                    local screenPos = dx9.WorldToScreen({modelData.referencePos.x, modelData.referencePos.y + 2, modelData.referencePos.z})
                    
                    if IsOnScreen(screenPos, screenWidth, screenHeight, 0) then
                        -- Draw small icon box at vehicle location
                        local iconSize = Config.vehicles.icon_size
                        dx9.DrawBox(
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
                                labelText = labelText .. " [" .. math.floor(modelData.distance) .. "m]"
                            else
                                labelText = "[" .. math.floor(modelData.distance) .. "m]"
                            end
                        end
                        
                        -- Draw centered text below icon
                        if labelText ~= "" then
                            local textWidth = dx9.CalcTextWidth(labelText)
                            local textX = screenPos.x - (textWidth / 2)
                            local textY = screenPos.y + iconSize/2 + 5
                            
                            dx9.DrawString({textX, textY}, currentColor, labelText)
                        end
                        
                        anyPartVisible = true
                    end
                end
                
                -- Draw tracer line to vehicle if enabled
                if Config.vehicles.tracers then
                    local toScreen = dx9.WorldToScreen({modelData.referencePos.x, modelData.referencePos.y, modelData.referencePos.z})
                    
                    if IsOnScreen(toScreen, screenWidth, screenHeight, 0) then
                        local fromScreen
                        
                        -- Determine tracer starting position based on config
                        if Config.vehicles.tracer_origin == "Top" then
                            fromScreen = {screenWidth / 2, 0}
                        elseif Config.vehicles.tracer_origin == "Bottom" then
                            fromScreen = {screenWidth / 2, screenHeight}
                        elseif Config.vehicles.tracer_origin == "Mouse" then
                            local mouse = dx9.GetMouse()
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
            dx9.DrawBox(boundingBox.topLeft, boundingBox.bottomRight, {100, 255, 150})
        end
    end

    local originPos = LocalPlayerManager.originPosition
    local screenPos = dx9.WorldToScreen({originPos.x, originPos.y + 2, originPos.z})
    if IsOnScreen(screenPos, screenWidth, screenHeight, Config.settings.screen_padding) then
        local label = "[Local Player]"
        local labelWidth = dx9.CalcTextWidth(label)
        dx9.DrawString({screenPos.x - (labelWidth / 2), screenPos.y - 40}, {100, 255, 150}, label)
        dx9.DrawCircle({screenPos.x, screenPos.y - 20}, {30, 90, 30}, 14)
        dx9.DrawCircle({screenPos.x, screenPos.y - 20}, {100, 255, 150}, 10)
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
    dx9.DrawString({10, yOffset}, {255, 255, 255}, "Apocalypse Rising 2 ESP")
    yOffset = yOffset + lineHeight

    local originLabel = LocalPlayerManager.selectedLabel or "0 - Camera (Default)"
    dx9.DrawString({10, yOffset}, {100, 255, 150}, "Distance Origin: " .. originLabel)
    yOffset = yOffset + lineHeight
    
    -- Character stats (rendered/checked)
    dx9.DrawString({10, yOffset}, {0, 255, 0}, "Characters: " .. Cache.performance.characters_rendered .. "/" .. Cache.performance.characters_checked)
    yOffset = yOffset + lineHeight
    
    -- Corpse stats (rendered/checked)
    dx9.DrawString({10, yOffset}, {255, 255, 100}, "Corpses: " .. Cache.performance.corpses_rendered .. "/" .. Cache.performance.corpses_checked)
    yOffset = yOffset + lineHeight
    
    -- Vehicle stats (rendered/checked)
    dx9.DrawString({10, yOffset}, {100, 255, 255}, "Vehicles: " .. Cache.performance.vehicles_rendered .. "/" .. Cache.performance.vehicles_checked)
    yOffset = yOffset + lineHeight
    
    -- Detailed performance metrics
    if Config.debug.show_performance then
        -- Total 3D cham boxes drawn this frame
        dx9.DrawString({10, yOffset}, {255, 255, 100}, "Parts Rendered: " .. Cache.performance.parts_rendered)
        yOffset = yOffset + lineHeight
        
        -- Total 2D boxes drawn this frame
        dx9.DrawString({10, yOffset}, {255, 200, 100}, "Boxes Drawn: " .. Cache.performance.boxes_drawn)
        yOffset = yOffset + lineHeight
        
        -- Total tracer lines drawn this frame
        dx9.DrawString({10, yOffset}, {255, 150, 255}, "Tracers Drawn: " .. Cache.performance.tracers_drawn)
        yOffset = yOffset + lineHeight
        
        -- Number of vehicles in cache
        dx9.DrawString({10, yOffset}, {200, 200, 200}, "Cached Vehicles: " .. CountTable(Cache.vehicles))
        yOffset = yOffset + lineHeight
        
        -- Number of vehicles in scan list
        dx9.DrawString({10, yOffset}, {200, 200, 200}, "Vehicle List Size: " .. (Cache.vehicle_list and #Cache.vehicle_list or 0))
        yOffset = yOffset + lineHeight
        
        -- Number of corpses in scan list
        dx9.DrawString({10, yOffset}, {200, 200, 200}, "Corpse List Size: " .. (Cache.corpse_list and #Cache.corpse_list or 0))
        yOffset = yOffset + lineHeight
        
        -- Current frame number (for debugging timing issues)
        dx9.DrawString({10, yOffset}, {200, 200, 200}, "Frame: " .. Cache.frame_count)
        yOffset = yOffset + lineHeight
    end
    
    -- List of detected vehicle names (useful for identifying vehicles)
    if Config.debug.show_vehicle_list and Cache.vehicle_list then
        yOffset = yOffset + 5
        dx9.DrawString({10, yOffset}, {150, 255, 150}, "--- Vehicles Found ---")
        yOffset = yOffset + lineHeight
        
        -- Show up to 15 vehicles to prevent overlay overflow
        for i, veh in ipairs(Cache.vehicle_list) do
            if i > 15 then
                break
            end
            dx9.DrawString({10, yOffset}, {200, 255, 200}, "- " .. veh.name)
            yOffset = yOffset + lineHeight
        end
    end
    
    -- List of detected corpse names (useful for loot detection)
    if Config.debug.show_corpse_list and Cache.corpse_list then
        yOffset = yOffset + 5
        dx9.DrawString({10, yOffset}, {255, 255, 150}, "--- Corpses Found ---")
        yOffset = yOffset + lineHeight
        
        -- Show up to 15 corpses to prevent overlay overflow
        for i, corpse in ipairs(Cache.corpse_list) do
            if i > 15 then
                break
            end
            dx9.DrawString({10, yOffset}, {255, 255, 200}, "- " .. corpse.name)
            yOffset = yOffset + lineHeight
        end
    end
end