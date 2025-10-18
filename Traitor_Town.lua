dx9.ShowConsole(true)

-- Load UI Library
local Lib = loadstring(dx9.Get("https://raw.githubusercontent.com/Brycki404/DXLibUI/refs/heads/main/main.lua"))()

-- ====================================
-- CONFIGURATION
-- ====================================

Config = _G.Config or {
    settings = {
        menu_toggle = "[F2]",
        cache_refresh_rate = 30,
        max_renders_per_frame = 100,
        screen_padding = 100,
    },
    players = {
        enabled = true,
        chams = true,
        boxes = false,
        tracers = false,
        head_dot = false,
        names = true,
        distance = true,
        health = true,
        color = {255, 100, 100},
        distance_limit = 100000,
        min_limb_count = 3,
        box_type = "2D Box",
        tracer_origin = "Mouse",
    },
    corpses = {
        enabled = true,
        chams = true,
        boxes = true,
        tracers = false,
        head_dot = false,
        names = true,
        distance = true,
        color = {255, 255, 100},
        distance_limit = 50000,
        min_limb_count = 3,
        box_type = "2D Box",
        tracer_origin = "Bottom",
    },
    items = {
        enabled = true,
        chams = false,
        boxes = true,
        tracers = false,
        names = true,
        distance = true,
        color = {100, 255, 100},
        distance_limit = 5000,
        icon_size = 6,
        box_type = "2D Box",
        tracer_origin = "Bottom",
        filter_weapons = false,
        filter_ammo = false,
        filter_attachments = false,
        filter_medical = false,
        filter_throwables = false,
        filter_food = false,
        filter_misc = false,
    },
    debug = {
        show = true,
        show_performance = true,
        show_item_list = false,
    },
}

if _G.Config == nil then
    _G.Config = Config
end
Config = _G.Config

-- ====================================
-- GLOBAL CACHE
-- ====================================

if not _G.ESP_Cache then
    _G.ESP_Cache = {
        players = {},
        corpses = {},
        items = {},
        frame_count = 0,
        last_refresh = 0,
        last_item_scan = 0,
        item_list = {},
        performance = {
            players_checked = 0,
            players_rendered = 0,
            corpses_checked = 0,
            corpses_rendered = 0,
            items_checked = 0,
            items_rendered = 0,
            parts_rendered = 0,
            tracers_drawn = 0,
            boxes_drawn = 0,
        }
    }
end

local Cache = _G.ESP_Cache

-- ====================================
-- ITEM CATEGORY PATTERNS
-- ====================================

local ItemCategories = {
    weapons = {
        -- Gun type keywords
        "rifle", "carbine", "shotgun", "pistol", "revolver", "smg", "lmg", "dmr", "sniper",
        -- Specific weapon models/names
        "ak", "m4", "m16", "ar15", "scar", "fal", "g3", "hk", "mp5", "mp7", "uzi", "mac",
        "desert eagle", "deagle", "eagle", "glock", "beretta", "colt", "1911",
        "remington", "mossberg", "benelli", "spas", "aa12", "saiga",
        "aug", "famas", "l85", "sa80", "galil", "tavor",
        "pkm", "rpk", "m249", "saw", "m60", "mg",
        "barrett", "awp", "m24", "l96", "dragunov", "sks", "mosin",
        "scout", "hunting", "battle rifle",
        -- Generic weapon indicators
        "gun", "firearm", "weapon",
        -- Pattern: ends with numbers (like AK47, M16A4, MP5K, etc.)
        "%d+[a-z]?$", -- matches numbers at end like "47", "16a4", "5k"
        -- Pattern: contains caliber indicators
        "%.%d+", -- matches .45, .556, .762, etc.
    },
    
    ammo = {
        -- Direct ammo keywords
        "ammo", "ammunition", "round", "cartridge", "bullet", "shell", "slug",
        -- Caliber patterns
        "cal", "caliber", "gauge",
        -- Specific calibers
        "9mm", "45acp", "556", "762", "50bmg", "308", "300", "338", "12gauge", "20gauge",
        "5.56", "7.62", "12.7", ".308", ".45", ".50", ".338", ".300",
        -- Pattern: mm designation
        "mm", "bmg", "nato", "magnum", "acp", "auto",
    },
    
    attachments = {
        -- Optics
        "scope", "sight", "optic", "red dot", "holo", "holographic", "acog", "reflex",
        "magnifier", "zoom", "lens", "reticle",
        -- Barrel attachments
        "suppressor", "silencer", "muzzle", "compensator", "brake", "flash hider",
        "barrel", "choke",
        -- Grips and stocks
        "grip", "foregrip", "stock", "buttstock", "cheek rest", "bipod",
        -- Magazines
        "magazine", "mag", "clip", "drum", "extended mag", "speed loader",
        -- Other attachments
        "laser", "flashlight", "light", "rail", "mount", "adapter",
        "underbarrel", "launcher",
        -- Pattern: attachment indicators
        "attachment", "mod", "accessory",
    },
    
    medical = {
        -- Direct medical items
        "medkit", "med kit", "first aid", "bandage", "gauze", "tourniquet",
        "syringe", "injector", "stim", "epinephrine", "adrenaline",
        "pills", "painkiller", "morphine", "antibiotics", "medicine",
        "health", "heal", "medical", "splint", "cast",
        -- Pattern: medical indicators
        "aid", "cure", "treatment", "remedy",
    },
    
    throwables = {
        -- Explosives
        "grenade", "frag", "explosive", "c4", "tnt", "dynamite", "mine", "claymore",
        "molotov", "cocktail", "incendiary",
        -- Tactical
        "smoke", "flashbang", "flash", "stun", "concussion", "tear gas",
        "flare", "signal",
        -- Pattern: throwable indicators
        "throw", "toss", "lob",
    },
    
    food = {
        -- Food
        "food", "ration", "mre", "meal", "can", "canned", "jerky", "meat", "fruit",
        "vegetable", "bread", "sandwich", "snack", "candy", "chocolate", "bar",
        "pasta", "rice", "beans", "soup", "stew",
        -- Drinks
        "water", "drink", "beverage", "soda", "cola", "juice", "milk", "coffee", "tea",
        "bottle", "canteen", "flask",
        -- Pattern: consumable indicators
        "edible", "consumable",
    },
    
    misc = {
        -- Tools
        "flashlight", "torch", "map", "compass", "gps", "radio", "walkie",
        "binoculars", "rangefinder", "watch", "knife", "tool", "kit",
        -- Gear
        "backpack", "vest", "armor", "helmet", "mask", "goggles", "gloves",
        "clothing", "uniform", "camo", "ghillie",
        -- Resources
        "battery", "fuel", "oil", "tape", "rope", "wire", "scrap", "parts",
        -- Pattern: utility indicators
        "equipment", "gear", "supplies", "utility",
    },
}

-- ====================================
-- HELPER FUNCTIONS
-- ====================================

local function GetDistance(p1, p2)
    if not p1 or not p2 then return 9999 end
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function IsOnScreen(pos, width, height, padding)
    return pos and pos.x and pos.y and 
           pos.x > -padding and pos.y > -padding and 
           pos.x < width + padding and pos.y < height + padding
end

local function CountTable(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local function ModelExists(model)
    if not model or model == 0 then
        return false
    end
    
    local success, result = pcall(function()
        return dx9.GetType(model)
    end)
    
    return success and (result == "Model" or result == "Folder" or result == "Part" or result == "MeshPart")
end

-- Enhanced item categorization with pattern matching
local function CategorizeItem(itemName)
    if not itemName then return "unknown" end
    
    local name = itemName:lower()
    
    -- Check each category
    for category, patterns in pairs(ItemCategories) do
        for _, pattern in ipairs(patterns) do
            -- Check if pattern contains Lua pattern characters
            if pattern:find("[%^%$%(%)%%%.%[%]%*%+%-%?]") then
                -- It's a Lua pattern, use pattern matching
                if name:find(pattern) then
                    return category
                end
            else
                -- It's a plain string, use simple find
                if name:find(pattern, 1, true) then
                    return category
                end
            end
        end
    end
    
    return "unknown"
end

-- Smart item filtering based on detected category
local function ItemMatchesFilter(itemName)
    if not itemName then return true end
    
    -- If no filters are active, show all items
    if not Config.items.filter_weapons and not Config.items.filter_ammo and 
       not Config.items.filter_attachments and not Config.items.filter_medical and
       not Config.items.filter_throwables and not Config.items.filter_food and 
       not Config.items.filter_misc then
        return true
    end
    
    -- Detect item category
    local category = CategorizeItem(itemName)
    
    -- Check if this category's filter is enabled
    if Config.items.filter_weapons and category == "weapons" then
        return true
    end
    
    if Config.items.filter_ammo and category == "ammo" then
        return true
    end
    
    if Config.items.filter_attachments and category == "attachments" then
        return true
    end
    
    if Config.items.filter_medical and category == "medical" then
        return true
    end
    
    if Config.items.filter_throwables and category == "throwables" then
        return true
    end
    
    if Config.items.filter_food and category == "food" then
        return true
    end
    
    if Config.items.filter_misc and category == "misc" then
        return true
    end
    
    return false
end

local PartSizeCache = {}

local function EstimatePartSize(partName)
    if not partName then
        return {x = 1, y = 1.5, z = 1}
    end
    
    if PartSizeCache[partName] then
        return PartSizeCache[partName]
    end
    
    local name = partName:lower()
    local size
    
    if name:find("head") then
        size = {x = 1, y = 1, z = 1}
    elseif name:find("humanoidrootpart") then
        size = {x = 2, y = 2, z = 1}
    elseif name:find("uppertorso") then
        size = {x = 2, y = 1.5, z = 1}
    elseif name:find("lowertorso") then
        size = {x = 1.8, y = 1, z = 1}
    elseif name:find("torso") then
        size = {x = 2, y = 2, z = 1}
    elseif name:find("upperarm") then
        size = {x = 1, y = 1.5, z = 1}
    elseif name:find("lowerarm") then
        size = {x = 0.8, y = 1.2, z = 0.8}
    elseif name:find("hand") then
        size = {x = 0.8, y = 0.4, z = 0.8}
    elseif name:find("arm") then
        size = {x = 1, y = 2, z = 1}
    elseif name:find("upperleg") then
        size = {x = 1, y = 1.5, z = 1}
    elseif name:find("lowerleg") then
        size = {x = 0.9, y = 1.5, z = 0.9}
    elseif name:find("foot") then
        size = {x = 1, y = 0.5, z = 0.8}
    elseif name:find("leg") then
        size = {x = 1, y = 2, z = 1}
    else
        size = {x = 1, y = 1.5, z = 1}
    end
    
    PartSizeCache[partName] = size
    return size
end

local ItemSizeCache = {}

-- Enhanced item size estimation based on category
local function EstimateItemSize(itemName)
    if not itemName then
        return {x = 0.5, y = 0.5, z = 0.5}
    end
    
    if ItemSizeCache[itemName] then
        return ItemSizeCache[itemName]
    end
    
    local category = CategorizeItem(itemName)
    local name = itemName:lower()
    local size
    
    if category == "weapons" then
        -- Determine weapon size based on type
        if name:find("sniper") or name:find("barrett") or name:find("awp") or name:find("dmr") then
            size = {x = 0.5, y = 0.5, z = 4}
        elseif name:find("rifle") or name:find("carbine") or name:find("ar") or name:find("ak") or name:find("m16") or name:find("m4") then
            size = {x = 0.5, y = 0.5, z = 3}
        elseif name:find("lmg") or name:find("mg") or name:find("saw") or name:find("m249") or name:find("pkm") then
            size = {x = 0.6, y = 0.6, z = 3.5}
        elseif name:find("shotgun") or name:find("gauge") then
            size = {x = 0.5, y = 0.5, z = 2.5}
        elseif name:find("smg") or name:find("mp") or name:find("uzi") or name:find("mac") then
            size = {x = 0.4, y = 0.4, z = 1.5}
        elseif name:find("pistol") or name:find("revolver") or name:find("glock") or name:find("eagle") or name:find("deagle") or name:find("1911") then
            size = {x = 0.3, y = 0.3, z = 0.8}
        else
            -- Default weapon size
            size = {x = 0.5, y = 0.5, z = 2.5}
        end
        
    elseif category == "ammo" then
        size = {x = 0.3, y = 0.5, z = 0.3}
        
    elseif category == "attachments" then
        if name:find("scope") or name:find("sight") or name:find("optic") then
            size = {x = 0.3, y = 0.3, z = 0.5}
        elseif name:find("suppressor") or name:find("silencer") then
            size = {x = 0.2, y = 0.2, z = 0.6}
        elseif name:find("grip") or name:find("stock") then
            size = {x = 0.3, y = 0.3, z = 0.4}
        elseif name:find("magazine") or name:find("mag") then
            size = {x = 0.2, y = 0.5, z = 0.2}
        else
            size = {x = 0.2, y = 0.2, z = 0.4}
        end
        
    elseif category == "medical" then
        if name:find("medkit") or name:find("first aid") then
            size = {x = 0.5, y = 0.3, z = 0.5}
        else
            size = {x = 0.3, y = 0.3, z = 0.3}
        end
        
    elseif category == "throwables" then
        size = {x = 0.3, y = 0.3, z = 0.3}
        
    elseif category == "food" then
        if name:find("bottle") or name:find("canteen") then
            size = {x = 0.2, y = 0.5, z = 0.2}
        else
            size = {x = 0.3, y = 0.3, z = 0.3}
        end
        
    elseif category == "misc" then
        if name:find("backpack") or name:find("vest") then
            size = {x = 1, y = 1, z = 0.5}
        else
            size = {x = 0.4, y = 0.4, z = 0.4}
        end
        
    else
        -- Unknown category - use default
        size = {x = 0.5, y = 0.5, z = 0.5}
    end
    
    ItemSizeCache[itemName] = size
    return size
end

local function DrawBodyPartChams(position, cframe, size, color, screenWidth, screenHeight, padding)
    if not cframe or not cframe.RightVector or not cframe.UpVector or not cframe.LookVector then
        return false
    end
    
    if not position or not position.x or not position.y or not position.z then
        return false
    end
    
    local function isValidVector(vec)
        if not vec or not vec.x or not vec.y or not vec.z then return false end
        local x, y, z = vec.x, vec.y, vec.z
        return x == x and y == y and z == z and 
               x > -1e6 and x < 1e6 and y > -1e6 and y < 1e6 and z > -1e6 and z < 1e6
    end
    
    if not isValidVector(cframe.RightVector) or not isValidVector(cframe.UpVector) or not isValidVector(cframe.LookVector) then
        return false
    end
    
    local hx, hy, hz = size.x * 0.5, size.y * 0.5, size.z * 0.5
    
    local corners = {}
    local idx = 1
    
    for dx = -1, 1, 2 do
        local rx = dx * hx
        for dy = -1, 1, 2 do
            local ry = dy * hy
            for dz = -1, 1, 2 do
                local offset = {
                    x = cframe.RightVector.x * rx + cframe.UpVector.x * ry + cframe.LookVector.x * (dz * hz),
                    y = cframe.RightVector.y * rx + cframe.UpVector.y * ry + cframe.LookVector.y * (dz * hz),
                    z = cframe.RightVector.z * rx + cframe.UpVector.z * ry + cframe.LookVector.z * (dz * hz)
                }
                corners[idx] = {
                    x = position.x + offset.x,
                    y = position.y + offset.y,
                    z = position.z + offset.z
                }
                idx = idx + 1
            end
        end
    end
    
    local screenPoints = {}
    local validCount = 0
    
    for i = 1, 8 do
        local world = corners[i]
        local success, screenPos = pcall(dx9.WorldToScreen, {world.x, world.y, world.z})
        
        if success and screenPos and screenPos.x and screenPos.y then
            local sx, sy = screenPos.x, screenPos.y
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
        
        if i == 4 and validCount == 0 then
            return false
        end
    end
    
    if validCount < 3 then
        return false
    end
    
    local edges = {
        {1,2},{2,4},{4,3},{3,1},
        {5,6},{6,8},{8,7},{7,5},
        {1,5},{2,6},{3,7},{4,8}
    }
    
    local drawnEdges = 0
    for i = 1, #edges do
        local edge = edges[i]
        local p1, p2 = screenPoints[edge[1]], screenPoints[edge[2]]
        if p1.valid and p2.valid then
            dx9.DrawLine({p1.x, p1.y}, {p2.x, p2.y}, color)
            drawnEdges = drawnEdges + 1
        end
    end
    
    return drawnEdges > 0
end

local function GetBoundingBox(parts, screenWidth, screenHeight, padding)
    if not parts or #parts == 0 then
        return nil
    end
    
    local screenPoints = {}
    local pointCount = 0
    
    for i = 1, #parts do
        local part = parts[i]
        local success, partPos = pcall(dx9.GetPosition, part)
        
        if success and partPos and partPos.x then
            local px, py, pz = partPos.x, partPos.y, partPos.z
            
            if px == px and py == py and pz == pz and 
               px > -1e6 and px < 1e6 and py > -1e6 and py < 1e6 and pz > -1e6 and pz < 1e6 then
                
                local success2, screenPos = pcall(dx9.WorldToScreen, {px, py, pz})
                
                if success2 and screenPos and screenPos.x and screenPos.y then
                    local sx, sy = screenPos.x, screenPos.y
                    
                    if sx == sx and sy == sy then
                        pointCount = pointCount + 1
                        screenPoints[pointCount] = {x = sx, y = sy}
                    end
                end
            end
        end
    end
    
    if pointCount < 4 then
        return nil
    end
    
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
    
    local sumDistSq = 0
    for i = 1, pointCount do
        local dx = screenPoints[i].x - medianX
        local dy = screenPoints[i].y - medianY
        sumDistSq = sumDistSq + (dx * dx + dy * dy)
    end
    local stdDev = math.sqrt(sumDistSq / pointCount)
    
    local maxScreenDist = math.max(screenWidth, screenHeight) * 1.5
    local maxAllowedDist = math.min(stdDev * 3, maxScreenDist)
    
    local absoluteMinX = -screenWidth * 0.5
    local absoluteMaxX = screenWidth * 1.5
    local absoluteMinY = -screenHeight * 0.5
    local absoluteMaxY = screenHeight * 1.5
    
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local validPoints = 0
    
    for i = 1, pointCount do
        local point = screenPoints[i]
        local dx = point.x - medianX
        local dy = point.y - medianY
        local distFromMedian = math.sqrt(dx * dx + dy * dy)
        
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
    
    if validPoints < 3 then
        return nil
    end
    
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

local function Draw2DBox(topLeft, bottomRight, color)
    dx9.DrawBox(topLeft, bottomRight, color)
end

local function DrawCornerBox(topLeft, bottomRight, color)
    local x1, y1 = topLeft[1], topLeft[2]
    local x2, y2 = bottomRight[1], bottomRight[2]
    local width = x2 - x1
    local height = y2 - y1
    local cornerSize = math.min(width, height) * 0.25
    
    local x1_plus = x1 + cornerSize
    local x2_minus = x2 - cornerSize
    local y1_plus = y1 + cornerSize
    local y2_minus = y2 - cornerSize
    
    dx9.DrawLine({x1, y1}, {x1_plus, y1}, color)
    dx9.DrawLine({x1, y1}, {x1, y1_plus}, color)
    
    dx9.DrawLine({x2, y1}, {x2_minus, y1}, color)
    dx9.DrawLine({x2, y1}, {x2, y1_plus}, color)
    
    dx9.DrawLine({x1, y2}, {x1_plus, y2}, color)
    dx9.DrawLine({x1, y2}, {x1, y2_minus}, color)
    
    dx9.DrawLine({x2, y2}, {x2_minus, y2}, color)
    dx9.DrawLine({x2, y2}, {x2, y2_minus}, color)
end

local function DrawTracer(fromPos, toPos, color)
    dx9.DrawLine(fromPos, toPos, color)
    Cache.performance.tracers_drawn = Cache.performance.tracers_drawn + 1
end

local function GetVisualsModel(model)
    if not model then return nil end
    
    local children = dx9.GetChildren(model)
    if not children then return nil end
    
    for i = 1, #children do
        local child = children[i]
        local success, childType = pcall(dx9.GetType, child)
        
        if success and childType == "Model" then
            local success2, childName = pcall(dx9.GetName, child)
            
            if success2 and childName == "Visuals" then
                return child
            end
        end
    end
    
    return nil
end

local function IsPlayerModel(model, modelAddress, cacheTable)
    if cacheTable[modelAddress] then
        if not ModelExists(model) then
            cacheTable[modelAddress] = nil
            return false, 0
        end
        return cacheTable[modelAddress].isPlayer, cacheTable[modelAddress].partCount
    end
    
    local visualsModel = GetVisualsModel(model)
    if not visualsModel then
        return false, 0
    end
    
    local children = dx9.GetChildren(visualsModel)
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
    
    local isPlayer = hasHumanoid and partCount >= Config.players.min_limb_count
    
    cacheTable[modelAddress] = {
        isPlayer = isPlayer,
        partCount = partCount,
        children = children,
        visualsModel = visualsModel,
        humanoidRootPart = humanoidRootPart,
        lastSeen = Cache.frame_count
    }
    
    return isPlayer, partCount
end

local function IsCorpseModel(model, modelAddress)
    if Cache.corpses[modelAddress] then
        if not ModelExists(model) then
            Cache.corpses[modelAddress] = nil
            return false, 0
        end
        return Cache.corpses[modelAddress].isCorpse, Cache.corpses[modelAddress].partCount
    end
    
    local visualsModel = GetVisualsModel(model)
    if not visualsModel then
        return false, 0
    end
    
    local children = dx9.GetChildren(visualsModel)
    if not children or #children == 0 then
        return false, 0
    end
    
    local partCount = 0
    local humanoidRootPart = nil
    
    for i = 1, #children do
        local child = children[i]
        local success, childType = pcall(dx9.GetType, child)
        
        if success then
            if childType == "Part" or childType == "MeshPart" then
                partCount = partCount + 1
                
                local success2, childName = pcall(dx9.GetName, child)
                
                if success2 and childName == "HumanoidRootPart" then
                    humanoidRootPart = child
                end
            end
        end
    end
    
    local isCorpse = partCount >= Config.corpses.min_limb_count
    
    Cache.corpses[modelAddress] = {
        isCorpse = isCorpse,
        partCount = partCount,
        children = children,
        visualsModel = visualsModel,
        humanoidRootPart = humanoidRootPart,
        lastSeen = Cache.frame_count
    }
    
    return isCorpse, partCount
end

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
    
    local children = nil
    if cachedData and cachedData.visualsModel then
        children = dx9.GetChildren(cachedData.visualsModel)
    elseif cachedData and cachedData.children then
        children = cachedData.children
    else
        local visualsModel = GetVisualsModel(model)
        if visualsModel then
            children = dx9.GetChildren(visualsModel)
        else
            children = dx9.GetChildren(model)
        end
    end
    
    if not children then return nil end
    
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

local function GetItemPosition(item)
    local success, pos = pcall(dx9.GetPosition, item)
    
    if success and pos and pos.x then
        return pos
    end
    
    return nil
end

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

local function ScanForItems(folder)
    local items = {}
    local iCount = 0
    
    if not folder then
        return items
    end
    
    local children = dx9.GetChildren(folder)
    if not children or #children == 0 then
        return items
    end
    
    for i = 1, #children do
        local child = children[i]
        local success, childType = pcall(dx9.GetType, child)
        
        if success and (childType == "MeshPart" or childType == "Part") then
            local success2, itemName = pcall(dx9.GetName, child)
            
            if success2 and itemName then
                if ItemMatchesFilter(itemName) then
                    iCount = iCount + 1
                    items[iCount] = {
                        item = child,
                        name = itemName,
                        category = CategorizeItem(itemName)
                    }
                end
            end
        end
    end
    
    return items
end

local function RenderPlayerESP(playerData, config, cameraPos, screenWidth, screenHeight)
    if not ModelExists(playerData.model) then
        return false
    end
    
    local cachedData = Cache.players[playerData.model]
    if not cachedData then
        return false
    end
    
    local children = cachedData.children
    if not children then
        return false
    end
    
    local referencePos = GetReferencePosition(playerData.model, playerData.model, Cache.players)
    if not referencePos then
        return false
    end
    
    local distance = GetDistance(cameraPos, referencePos)
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
    
    if config.health then
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
                    local modelName = dx9.GetName(playerData.model)
                    nameText = modelName or "Player"
                end
                
                if config.health and healthInfo then
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

local function RenderCorpseESP(corpseData, config, cameraPos, screenWidth, screenHeight)
    if not ModelExists(corpseData.model) then
        return false
    end
    
    local cachedData = Cache.corpses[corpseData.model]
    if not cachedData then
        return false
    end
    
    local children = cachedData.children
    if not children then
        return false
    end
    
    local referencePos = GetReferencePosition(corpseData.model, corpseData.model, Cache.corpses)
    if not referencePos then
        return false
    end
    
    local distance = GetDistance(cameraPos, referencePos)
    if distance > config.distance_limit then
        return false
    end
    
    local visibleParts = GetAllVisibleParts(children)
    if #visibleParts == 0 then
        return false
    end
    
    local anyPartVisible = false
    local headPos = nil
    local currentColor = config.color
    
    if config.boxes and config.box_type ~= "3D Chams" then
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
    
    if anyPartVisible and (config.names or config.distance) then
        local labelPos = headPos or referencePos
        if labelPos then
            local screenPos = dx9.WorldToScreen({labelPos.x, labelPos.y + 2, labelPos.z})
            
            if IsOnScreen(screenPos, screenWidth, screenHeight, 0) then
                local nameText = ""
                
                if config.names then
                    local modelName = dx9.GetName(corpseData.model)
                    nameText = (modelName or "Corpse") .. " [CORPSE]"
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

local function RenderItemESP(itemData, config, cameraPos, screenWidth, screenHeight)
    if not ModelExists(itemData.item) then
        return false
    end
    
    local itemPos = GetItemPosition(itemData.item)
    if not itemPos then
        return false
    end
    
    local distance = GetDistance(cameraPos, itemPos)
    if distance > config.distance_limit then
        return false
    end
    
    local currentColor = config.color
    local anyPartVisible = false
    
    if config.chams or (config.boxes and config.box_type == "3D Chams") then
        local success, screenPos = pcall(function()
            return dx9.WorldToScreen({itemPos.x, itemPos.y, itemPos.z})
        end)
        
        if success and IsOnScreen(screenPos, screenWidth, screenHeight, Config.settings.screen_padding) then
            anyPartVisible = true
            
            local success2, itemCFrame = pcall(function()
                return dx9.GetCFrame(itemData.item)
            end)
            
            if success2 and itemCFrame then
                local itemSize = EstimateItemSize(itemData.name)
                
                local drawn = DrawBodyPartChams(itemPos, itemCFrame, itemSize, currentColor, screenWidth, screenHeight, Config.settings.screen_padding)
                if drawn then
                    Cache.performance.parts_rendered = Cache.performance.parts_rendered + 1
                end
            end
        end
    end
    
    if config.boxes and config.box_type ~= "3D Chams" then
        local parts = {itemData.item}
        local boundingBox = GetBoundingBox(parts, screenWidth, screenHeight, Config.settings.screen_padding)
        
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
    
    if config.tracers then
        local toScreen = dx9.WorldToScreen({itemPos.x, itemPos.y, itemPos.z})
        
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
            anyPartVisible = true
        end
    end
    
    if config.names or config.distance then
        local toScreen = dx9.WorldToScreen({itemPos.x, itemPos.y, itemPos.z})
        
        if IsOnScreen(toScreen, screenWidth, screenHeight, 0) then
            local iconSize = config.icon_size
            dx9.DrawBox(
                {toScreen.x - iconSize/2, toScreen.y - iconSize/2},
                {toScreen.x + iconSize/2, toScreen.y + iconSize/2},
                currentColor
            )
            
            local labelText = ""
            
            if config.names then
                labelText = itemData.name or "Item"
            end
            
            if config.distance then
                if labelText ~= "" then
                    labelText = labelText .. " [" .. math.floor(distance) .. "m]"
                else
                    labelText = "[" .. math.floor(distance) .. "m]"
                end
            end
            
            if labelText ~= "" then
                local textWidth = dx9.CalcTextWidth(labelText)
                local textX = toScreen.x - (textWidth / 2)
                local textY = toScreen.y + iconSize/2 + 5
                
                dx9.DrawString({textX, textY}, currentColor, labelText)
            end
            
            anyPartVisible = true
        end
    end
    
    return anyPartVisible
end

-- ====================================
-- CREATE UI
-- ====================================

local Window = Lib:CreateWindow({
    Title = "Universal ESP",
    Size = {700, 600},
    Resizable = true,
    ToggleKey = Config.settings.menu_toggle,
    FooterToggle = true,
    FooterRGB = true,
})

local Tabs = {
    players = Window:AddTab("Player"),
    corpses = Window:AddTab("Corpses"),
    items = Window:AddTab("Items"),
    settings = Window:AddTab("Settings"),
}

local PlayerGroupboxes = {
    main = Tabs.players:AddLeftGroupbox("Player ESP"),
    visual = Tabs.players:AddLeftGroupbox("Visual Settings"),
    extra = Tabs.players:AddRightGroupbox("Extra Features"),
}

local CorpseGroupboxes = {
    main = Tabs.corpses:AddLeftGroupbox("Corpse ESP"),
    visual = Tabs.corpses:AddLeftGroupbox("Visual Settings"),
    extra = Tabs.corpses:AddRightGroupbox("Extra Features"),
}

local ItemGroupboxes = {
    main = Tabs.items:AddLeftGroupbox("Item ESP"),
    visual = Tabs.items:AddLeftGroupbox("Visual Settings"),
    filters = Tabs.items:AddRightGroupbox("Filters"),
}

local SettingsGroupboxes = {
    main = Tabs.settings:AddLeftGroupbox("Performance"),
    debug = Tabs.settings:AddRightGroupbox("Debug"),
}

-- Player Settings
PlayerGroupboxes.main:AddToggle({
    Default = Config.players.enabled,
    Text = "Enabled",
}):OnChanged(function(value)
    Lib:Notify(value and "Player ESP Enabled" or "Player ESP Disabled", 1)
    Config.players.enabled = value
end)

PlayerGroupboxes.main:AddToggle({
    Default = Config.players.chams,
    Text = "Chams",
}):OnChanged(function(value)
    Config.players.chams = value
end)

PlayerGroupboxes.main:AddToggle({
    Default = Config.players.boxes,
    Text = "Boxes",
}):OnChanged(function(value)
    Config.players.boxes = value
end)

PlayerGroupboxes.main:AddToggle({
    Default = Config.players.tracers,
    Text = "Tracers",
}):OnChanged(function(value)
    Config.players.tracers = value
end)

PlayerGroupboxes.main:AddToggle({
    Default = Config.players.head_dot,
    Text = "Head Dot",
}):OnChanged(function(value)
    Config.players.head_dot = value
end)

PlayerGroupboxes.visual:AddToggle({
    Default = Config.players.names,
    Text = "Names",
}):OnChanged(function(value)
    Config.players.names = value
end)

PlayerGroupboxes.visual:AddToggle({
    Default = Config.players.distance,
    Text = "Distance",
}):OnChanged(function(value)
    Config.players.distance = value
end)

PlayerGroupboxes.visual:AddToggle({
    Default = Config.players.health,
    Text = "Health",
}):OnChanged(function(value)
    Config.players.health = value
end)

PlayerGroupboxes.visual:AddColorPicker({
    Default = Config.players.color,
    Text = "Color",
}):OnChanged(function(value)
    Config.players.color = value
end)

PlayerGroupboxes.visual:AddSlider({
    Default = Config.players.distance_limit,
    Text = "Max Distance",
    Min = 50,
    Max = 100000,
    Rounding = 0,
}):OnChanged(function(value)
    Config.players.distance_limit = value
end)

PlayerGroupboxes.visual:AddSlider({
    Default = Config.players.min_limb_count,
    Text = "Min Limbs",
    Min = 1,
    Max = 10,
    Rounding = 0,
}):OnChanged(function(value)
    Config.players.min_limb_count = value
end)

PlayerGroupboxes.extra:AddDropdown({
    Default = 1,
    Text = "Box Type",
    Values = {"2D Box", "3D Chams", "Corner Box"},
}):OnChanged(function(value)
    Config.players.box_type = value
end)

PlayerGroupboxes.extra:AddDropdown({
    Default = 3,
    Text = "Tracer Origin",
    Values = {"Top", "Bottom", "Mouse"},
}):OnChanged(function(value)
    Config.players.tracer_origin = value
end)

-- Corpse Settings
CorpseGroupboxes.main:AddToggle({
    Default = Config.corpses.enabled,
    Text = "Enabled",
}):OnChanged(function(value)
    Lib:Notify(value and "Corpse ESP Enabled" or "Corpse ESP Disabled", 1)
    Config.corpses.enabled = value
end)

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
    Default = 2,
    Text = "Tracer Origin",
    Values = {"Top", "Bottom", "Mouse"},
}):OnChanged(function(value)
    Config.corpses.tracer_origin = value
end)

-- Item Settings
ItemGroupboxes.main:AddToggle({
    Default = Config.items.enabled,
    Text = "Enabled",
}):OnChanged(function(value)
    Lib:Notify(value and "Item ESP Enabled" or "Item ESP Disabled", 1)
    Config.items.enabled = value
end)

ItemGroupboxes.main:AddToggle({
    Default = Config.items.chams,
    Text = "Chams",
}):OnChanged(function(value)
    Config.items.chams = value
end)

ItemGroupboxes.main:AddToggle({
    Default = Config.items.boxes,
    Text = "Boxes",
}):OnChanged(function(value)
    Config.items.boxes = value
end)

ItemGroupboxes.main:AddToggle({
    Default = Config.items.tracers,
    Text = "Tracers",
}):OnChanged(function(value)
    Config.items.tracers = value
end)

ItemGroupboxes.visual:AddToggle({
    Default = Config.items.names,
    Text = "Names",
}):OnChanged(function(value)
    Config.items.names = value
end)

ItemGroupboxes.visual:AddToggle({
    Default = Config.items.distance,
    Text = "Distance",
}):OnChanged(function(value)
    Config.items.distance = value
end)

ItemGroupboxes.visual:AddColorPicker({
    Default = Config.items.color,
    Text = "Color",
}):OnChanged(function(value)
    Config.items.color = value
end)

ItemGroupboxes.visual:AddSlider({
    Default = Config.items.distance_limit,
    Text = "Max Distance",
    Min = 50,
    Max = 10000,
    Rounding = 0,
}):OnChanged(function(value)
    Config.items.distance_limit = value
end)

ItemGroupboxes.visual:AddSlider({
    Default = Config.items.icon_size,
    Text = "Icon Size",
    Min = 5,
    Max = 30,
    Rounding = 0,
}):OnChanged(function(value)
    Config.items.icon_size = value
end)

ItemGroupboxes.filters:AddToggle({
    Default = Config.items.filter_weapons,
    Text = "Weapons Only",
}):OnChanged(function(value)
    Config.items.filter_weapons = value
    Cache.last_item_scan = 0
end)

ItemGroupboxes.filters:AddToggle({
    Default = Config.items.filter_ammo,
    Text = "Ammo Only",
}):OnChanged(function(value)
    Config.items.filter_ammo = value
    Cache.last_item_scan = 0
end)

ItemGroupboxes.filters:AddToggle({
    Default = Config.items.filter_attachments,
    Text = "Attachments Only",
}):OnChanged(function(value)
    Config.items.filter_attachments = value
    Cache.last_item_scan = 0
end)

ItemGroupboxes.filters:AddToggle({
    Default = Config.items.filter_medical,
    Text = "Medical Only",
}):OnChanged(function(value)
    Config.items.filter_medical = value
    Cache.last_item_scan = 0
end)

ItemGroupboxes.filters:AddToggle({
    Default = Config.items.filter_throwables,
    Text = "Throwables Only",
}):OnChanged(function(value)
    Config.items.filter_throwables = value
    Cache.last_item_scan = 0
end)

ItemGroupboxes.filters:AddToggle({
    Default = Config.items.filter_food,
    Text = "Food/Drink Only",
}):OnChanged(function(value)
    Config.items.filter_food = value
    Cache.last_item_scan = 0
end)

ItemGroupboxes.filters:AddToggle({
    Default = Config.items.filter_misc,
    Text = "Misc Only",
}):OnChanged(function(value)
    Config.items.filter_misc = value
    Cache.last_item_scan = 0
end)

ItemGroupboxes.filters:AddDropdown({
    Default = 1,
    Text = "Box Type",
    Values = {"2D Box", "3D Chams", "Corner Box"},
}):OnChanged(function(value)
    Config.items.box_type = value
end)

ItemGroupboxes.filters:AddDropdown({
    Default = 2,
    Text = "Tracer Origin",
    Values = {"Top", "Bottom", "Mouse"},
}):OnChanged(function(value)
    Config.items.tracer_origin = value
end)

-- Performance Settings
SettingsGroupboxes.main:AddSlider({
    Default = Config.settings.cache_refresh_rate,
    Text = "Cache Refresh Rate",
    Min = 15,
    Max = 120,
    Rounding = 0,
}):OnChanged(function(value)
    Config.settings.cache_refresh_rate = value
end)

SettingsGroupboxes.main:AddSlider({
    Default = Config.settings.max_renders_per_frame,
    Text = "Max Renders/Frame",
    Min = 10,
    Max = 200,
    Rounding = 0,
}):OnChanged(function(value)
    Config.settings.max_renders_per_frame = value
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
    Default = Config.debug.show_item_list,
    Text = "Show Item List",
}):OnChanged(function(value)
    Config.debug.show_item_list = value
end)

SettingsGroupboxes.debug:AddBlank(10)
SettingsGroupboxes.debug:AddLabel("Debug info appears in\ntop-left corner")

-- ====================================
-- MAIN LOOP
-- ====================================

Cache.frame_count = Cache.frame_count + 1

Cache.performance = {
    players_checked = 0,
    players_rendered = 0,
    corpses_checked = 0,
    corpses_rendered = 0,
    items_checked = 0,
    items_rendered = 0,
    parts_rendered = 0,
    tracers_drawn = 0,
    boxes_drawn = 0,
}

local Datamodel = dx9.GetDatamodel()
local Workspace = dx9.FindFirstChild(Datamodel, 'Workspace')

if not Workspace then
    return
end

local screenWidth = dx9.size().width
local screenHeight = dx9.size().height

local Camera = dx9.FindFirstChild(Workspace, "Camera")
local cameraPos = nil
if Camera then
    local cameraPart = dx9.FindFirstChild(Camera, "CameraSubject") or dx9.FindFirstChild(Camera, "Focus")
    if not cameraPart or cameraPart == 0 then
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

if not cameraPos then
    cameraPos = {x = 0, y = 50, z = 0}
end

-- ====================================
-- CACHE CLEANUP
-- ====================================

local shouldRefresh = (Cache.frame_count - Cache.last_refresh) >= Config.settings.cache_refresh_rate

if shouldRefresh then
    Cache.last_refresh = Cache.frame_count
    
    local _StaticFolder = dx9.FindFirstChild(Workspace, '_Static')
    local _DynamicFolder = dx9.FindFirstChild(Workspace, '_Dynamic')
    
    local CharactersFolder = nil
    local CorpsesFolder = nil
    local ItemsFolder = nil
    
    if _StaticFolder then
        CharactersFolder = dx9.FindFirstChild(_StaticFolder, 'Characters')
    end
    
    if _DynamicFolder then
        CorpsesFolder = dx9.FindFirstChild(_DynamicFolder, 'Corpses')
        ItemsFolder = dx9.FindFirstChild(_DynamicFolder, 'Items')
    end
    
    local currentPlayers = {}
    local currentCorpses = {}
    local currentItems = {}
    
    if CharactersFolder then
        local players = dx9.GetChildren(CharactersFolder)
        if players then
            for _, player in next, players do
                currentPlayers[player] = true
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
    
    if ItemsFolder then
        local items = dx9.GetChildren(ItemsFolder)
        if items then
            for _, item in next, items do
                currentItems[item] = true
            end
        end
    end
    
    for addr, _ in next, Cache.players do
        if not currentPlayers[addr] then
            Cache.players[addr] = nil
        end
    end
    
    for addr, _ in next, Cache.corpses do
        if not currentCorpses[addr] then
            Cache.corpses[addr] = nil
        end
    end
    
    for addr, _ in next, Cache.items do
        if not currentItems[addr] then
            Cache.items[addr] = nil
        end
    end
end

-- ====================================
-- ITEM SCANNING
-- ====================================

local shouldScanItems = (Cache.frame_count - Cache.last_item_scan) >= 30

if shouldScanItems and Config.items.enabled then
    Cache.last_item_scan = Cache.frame_count
    
    local _DynamicFolder = dx9.FindFirstChild(Workspace, '_Dynamic')
    if _DynamicFolder then
        local ItemsFolder = dx9.FindFirstChild(_DynamicFolder, 'Items')
        if ItemsFolder then
            Cache.item_list = ScanForItems(ItemsFolder)
        end
    end
end

-- ====================================
-- PROCESS PLAYERS
-- ====================================

if Config.players.enabled then
    local _StaticFolder = dx9.FindFirstChild(Workspace, '_Static')
    
    if _StaticFolder then
        local CharactersFolder = dx9.FindFirstChild(_StaticFolder, 'Characters')
        
        if CharactersFolder then
            local FolderChildren = dx9.GetChildren(CharactersFolder)
            
            if FolderChildren then
                local playerDistances = {}
                
                for _, object in next, FolderChildren do
                    local success, objectType = pcall(function()
                        return dx9.GetType(object)
                    end)
                    
                    if success and objectType == "Model" then
                        Cache.performance.players_checked = Cache.performance.players_checked + 1
                        
                        if ModelExists(object) then
                            local isPlayer, partCount = IsPlayerModel(object, object, Cache.players)
                            
                            if isPlayer then
                                local referencePos = GetReferencePosition(object, object, Cache.players)
                                
                                if referencePos then
                                    local distance = GetDistance(cameraPos, referencePos)
                                    
                                    if distance <= Config.players.distance_limit then
                                        table.insert(playerDistances, {
                                            model = object,
                                            distance = distance,
                                            referencePos = referencePos
                                        })
                                    end
                                end
                            end
                        else
                            Cache.players[object] = nil
                        end
                    end
                end
                
                table.sort(playerDistances, function(a, b)
                    return a.distance < b.distance
                end)
                
                local renderedThisFrame = 0
                
                for _, modelData in next, playerDistances do
                    if renderedThisFrame >= Config.settings.max_renders_per_frame then
                        break
                    end
                    
                    local rendered = RenderPlayerESP(modelData, Config.players, cameraPos, screenWidth, screenHeight)
                    
                    if rendered then
                        renderedThisFrame = renderedThisFrame + 1
                        Cache.performance.players_rendered = Cache.performance.players_rendered + 1
                    end
                end
            end
        end
    end
end

-- ====================================
-- PROCESS CORPSES
-- ====================================

if Config.corpses.enabled then
    local _DynamicFolder = dx9.FindFirstChild(Workspace, '_Dynamic')
    
    if _DynamicFolder then
        local CorpsesFolder = dx9.FindFirstChild(_DynamicFolder, 'Corpses')
        
        if CorpsesFolder then
            local FolderChildren = dx9.GetChildren(CorpsesFolder)
            
            if FolderChildren then
                local corpseDistances = {}
                
                for _, object in next, FolderChildren do
                    local success, objectType = pcall(function()
                        return dx9.GetType(object)
                    end)
                    
                    if success and objectType == "Model" then
                        Cache.performance.corpses_checked = Cache.performance.corpses_checked + 1
                        
                        if ModelExists(object) then
                            local isCorpse, partCount = IsCorpseModel(object, object)
                            
                            if isCorpse then
                                local referencePos = GetReferencePosition(object, object, Cache.corpses)
                                
                                if referencePos then
                                    local distance = GetDistance(cameraPos, referencePos)
                                    
                                    if distance <= Config.corpses.distance_limit then
                                        table.insert(corpseDistances, {
                                            model = object,
                                            distance = distance,
                                            referencePos = referencePos
                                        })
                                    end
                                end
                            end
                        else
                            Cache.corpses[object] = nil
                        end
                    end
                end
                
                table.sort(corpseDistances, function(a, b)
                    return a.distance < b.distance
                end)
                
                for _, modelData in next, corpseDistances do
                    local rendered = RenderCorpseESP(modelData, Config.corpses, cameraPos, screenWidth, screenHeight)
                    
                    if rendered then
                        Cache.performance.corpses_rendered = Cache.performance.corpses_rendered + 1
                    end
                end
            end
        end
    end
end

-- ====================================
-- PROCESS ITEMS
-- ====================================

if Config.items.enabled and Cache.item_list then
    local itemDistances = {}
    
    for _, itemData in next, Cache.item_list do
        if ModelExists(itemData.item) then
            Cache.performance.items_checked = Cache.performance.items_checked + 1
            
            local itemPos = GetItemPosition(itemData.item)
            
            if itemPos then
                local distance = GetDistance(cameraPos, itemPos)
                
                if distance <= Config.items.distance_limit then
                    table.insert(itemDistances, {
                        item = itemData.item,
                        name = itemData.name,
                        category = itemData.category,
                        distance = distance
                    })
                end
            end
        end
    end
    
    table.sort(itemDistances, function(a, b)
        return a.distance < b.distance
    end)
    
    for _, itemData in next, itemDistances do
        local rendered = RenderItemESP(itemData, Config.items, cameraPos, screenWidth, screenHeight)
        
        if rendered then
            Cache.performance.items_rendered = Cache.performance.items_rendered + 1
        end
    end
end

-- ====================================
-- DEBUG INFO OVERLAY
-- ====================================

if Config.debug.show then
    local yOffset = 10
    local lineHeight = 18
    
    dx9.DrawString({10, yOffset}, {255, 255, 255}, "Universal ESP")
    yOffset = yOffset + lineHeight
    
    dx9.DrawString({10, yOffset}, {0, 255, 0}, "Players: " .. Cache.performance.players_rendered .. "/" .. Cache.performance.players_checked)
    yOffset = yOffset + lineHeight
    
    dx9.DrawString({10, yOffset}, {255, 255, 100}, "Corpses: " .. Cache.performance.corpses_rendered .. "/" .. Cache.performance.corpses_checked)
    yOffset = yOffset + lineHeight
    
    dx9.DrawString({10, yOffset}, {100, 255, 100}, "Items: " .. Cache.performance.items_rendered .. "/" .. Cache.performance.items_checked)
    yOffset = yOffset + lineHeight
    
    if Config.debug.show_performance then
        dx9.DrawString({10, yOffset}, {255, 255, 100}, "Parts Rendered: " .. Cache.performance.parts_rendered)
        yOffset = yOffset + lineHeight
        
        dx9.DrawString({10, yOffset}, {255, 200, 100}, "Boxes Drawn: " .. Cache.performance.boxes_drawn)
        yOffset = yOffset + lineHeight
        
        dx9.DrawString({10, yOffset}, {255, 150, 255}, "Tracers Drawn: " .. Cache.performance.tracers_drawn)
        yOffset = yOffset + lineHeight
        
        dx9.DrawString({10, yOffset}, {200, 200, 200}, "Item List Size: " .. (Cache.item_list and #Cache.item_list or 0))
        yOffset = yOffset + lineHeight
        
        dx9.DrawString({10, yOffset}, {200, 200, 200}, "Frame: " .. Cache.frame_count)
        yOffset = yOffset + lineHeight
    end
    
    if Config.debug.show_item_list and Cache.item_list then
        yOffset = yOffset + 5
        dx9.DrawString({10, yOffset}, {150, 255, 150}, "--- Items Found ---")
        yOffset = yOffset + lineHeight
        
        for i, item in ipairs(Cache.item_list) do
            if i > 15 then
                break
            end
            local categoryTag = item.category and (" [" .. item.category .. "]") or ""
            dx9.DrawString({10, yOffset}, {200, 255, 200}, "- " .. item.name .. categoryTag)
            yOffset = yOffset + lineHeight
        end
    end
end
