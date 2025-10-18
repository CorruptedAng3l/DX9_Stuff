-- ====================================
-- INFECTED ESP + AIMBOT - STABLE FIXED
-- Fixed spinning + removed debug cube
-- ====================================

dx9.ShowConsole(true)

-- Load libraries
local Lib = loadstring(dx9.Get("https://raw.githubusercontent.com/Brycki404/DXLibUI/refs/heads/main/main.lua"))()
local ESP = loadstring(dx9.Get("https://raw.githubusercontent.com/Brycki404/DXLibESP/refs/heads/main/main.lua"))()

-- ====================================
-- CONFIGURATION
-- ====================================

Config = _G.Config or {
    settings = {
        esp_enabled = true,
        aimbot_enabled = true,
        aimbot_smoothness = 8,
        aimbot_deadzone = 5, -- Stop moving when within this many pixels
        aimbot_fov = 150,
        aimbot_part = 1,
        menu_toggle = "[F2]",
    },
    infected = {
        boxes = true,
        chams = false, -- DISABLED BY DEFAULT
        names = true,
        health = true,
        distance = true,
        tracers = false,
        box_type = 1,
        tracer_type = 1,
        color = {255, 0, 0},
        distance_limit = 500,
    },
}

if _G.Config == nil then
    _G.Config = Config
    Config = _G.Config
end

-- Frame limiting
if not _G.lastAimbotFrame then
    _G.lastAimbotFrame = 0
end

-- ====================================
-- HELPER FUNCTIONS
-- ====================================

local function GetDistance(p1, p2)
    local a = (p1.x - p2.x) * (p1.x - p2.x)
    local b = (p1.y - p2.y) * (p1.y - p2.y)
    local c = (p1.z - p2.z) * (p1.z - p2.z)
    return math.sqrt(a + b + c)
end

local function GetDistance2D(p1, p2)
    local a = (p1.x - p2.x) * (p1.x - p2.x)
    local b = (p1.y - p2.y) * (p1.y - p2.y)
    return math.sqrt(a + b)
end

local function IsOnScreen(pos, width, height)
    return pos and pos.x > 0 and pos.y > 0 and pos.x < width and pos.y < height
end

-- ====================================
-- CREATE UI
-- ====================================

local Window = Lib:CreateWindow({
    Title = "Infected ESP + Aimbot",
    Size = {500, 500},
    Resizable = true,
    ToggleKey = Config.settings.menu_toggle,
    FooterToggle = true,
    FooterRGB = true,
})

local Tabs = {
    aimbot = Window:AddTab("Aimbot"),
    esp = Window:AddTab("ESP"),
}

local Groupboxes = {
    aimbot_main = Tabs.aimbot:AddLeftGroupbox("Aimbot Settings"),
    aimbot_advanced = Tabs.aimbot:AddRightGroupbox("Advanced Settings"),
    esp_main = Tabs.esp:AddLeftGroupbox("ESP Settings"),
    esp_visual = Tabs.esp:AddRightGroupbox("Visual Options"),
}

-- Aimbot Settings
local AimbotToggles = {
    enabled = Groupboxes.aimbot_main:AddToggle({
        Default = Config.settings.aimbot_enabled,
        Text = "Aimbot Enabled",
    }):OnChanged(function(value)
        Lib:Notify(value and "Aimbot Enabled" or "Aimbot Disabled", 1)
    end),

    part = Groupboxes.aimbot_main:AddDropdown({
        Text = "Target Part",
        Default = Config.settings.aimbot_part,
        Values = {"Head", "Torso"},
    }):OnChanged(function(value)
        Lib:Notify("Targeting: " .. value, 1)
    end),

    smoothness = Groupboxes.aimbot_main:AddSlider({
        Default = Config.settings.aimbot_smoothness,
        Text = "Smoothness",
        Min = 1,
        Max = 20,
        Rounding = 0,
    }),

    deadzone = Groupboxes.aimbot_main:AddSlider({
        Default = Config.settings.aimbot_deadzone,
        Text = "Deadzone (pixels)",
        Min = 1,
        Max = 50,
        Rounding = 0,
    }),

    fov = Groupboxes.aimbot_main:AddSlider({
        Default = Config.settings.aimbot_fov,
        Text = "FOV Size",
        Min = 50,
        Max = 500,
        Rounding = 0,
    }),

    show_fov = Groupboxes.aimbot_advanced:AddToggle({
        Default = true,
        Text = "Show FOV Circle",
    }),

    show_target = Groupboxes.aimbot_advanced:AddToggle({
        Default = true,
        Text = "Show Target Indicator",
    }),

    debug_info = Groupboxes.aimbot_advanced:AddToggle({
        Default = false,
        Text = "Show Debug Info",
    }),
}

Groupboxes.aimbot_advanced:AddLabel("Hold RIGHT CLICK to aim")
Groupboxes.aimbot_advanced:AddBlank(5)
Groupboxes.aimbot_advanced:AddLabel("Increase smoothness if\nit spins or shakes")

-- ESP Settings
local ESPToggles = {
    enabled = Groupboxes.esp_main:AddToggle({
        Default = Config.infected.boxes,
        Text = "ESP Enabled",
    }):OnChanged(function(value)
        Lib:Notify(value and "ESP Enabled" or "ESP Disabled", 1)
    end),

    boxes = Groupboxes.esp_main:AddToggle({
        Default = Config.infected.boxes,
        Text = "Boxes",
    }),

    names = Groupboxes.esp_main:AddToggle({
        Default = Config.infected.names,
        Text = "Names",
    }),

    health = Groupboxes.esp_main:AddToggle({
        Default = Config.infected.health,
        Text = "Health",
    }),

    distance = Groupboxes.esp_main:AddToggle({
        Default = Config.infected.distance,
        Text = "Distance",
    }),

    tracers = Groupboxes.esp_main:AddToggle({
        Default = Config.infected.tracers,
        Text = "Tracers",
    }),

    box_type = Groupboxes.esp_visual:AddDropdown({
        Text = "Box Type",
        Default = Config.infected.box_type,
        Values = {"Corners", "2D Box", "3D Box"},
    }),

    tracer_type = Groupboxes.esp_visual:AddDropdown({
        Text = "Tracer Type",
        Default = Config.infected.tracer_type,
        Values = {"Near-Bottom", "Bottom", "Top", "Mouse"},
    }),

    color = Groupboxes.esp_visual:AddColorPicker({
        Default = Config.infected.color,
        Text = "Color",
    }),

    distance_limit = Groupboxes.esp_visual:AddSlider({
        Default = Config.infected.distance_limit,
        Text = "Max Distance",
        Min = 50,
        Max = 1000,
        Rounding = 0,
    }),
}

-- ====================================
-- GAME VARIABLES
-- ====================================

local Datamodel = dx9.GetDatamodel()
local Workspace = dx9.FindFirstChild(Datamodel, 'Workspace')
local Players = dx9.FindFirstChild(Datamodel, 'Players')

-- ====================================
-- GET LOCAL PLAYER
-- ====================================

local function GetLocalPlayer()
    local lp = dx9.get_localplayer()
    if lp and lp.Position then
        return lp
    end

    if Players then
        for _, player in next, dx9.GetChildren(Players) do
            local pgui = dx9.FindFirstChild(player, "PlayerGui")
            if pgui and pgui ~= 0 then
                local name = dx9.GetName(player)
                local char = dx9.FindFirstChild(Workspace, name)
                if char and char ~= 0 then
                    local root = dx9.FindFirstChild(char, "HumanoidRootPart")
                    if root and root ~= 0 then
                        local pos = dx9.GetPosition(root)
                        if pos then
                            return {Position = pos, Name = name, Character = char}
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- ====================================
-- MAIN LOOP
-- ====================================

local screenWidth = dx9.size().width
local screenHeight = dx9.size().height
local mouse = dx9.GetMouse()

local LocalPlayer = GetLocalPlayer()

if not LocalPlayer or not LocalPlayer.Position then
    return
end

local Entities = dx9.FindFirstChild(Workspace, 'Entities')
if not Entities then return end

local Infected = dx9.FindFirstChild(Entities, 'Infected')
if not Infected then return end

local InfectedModels = dx9.GetChildren(Infected)
if not InfectedModels then return end

local closestTarget = nil
local closestDistance = math.huge
local isAimbotKeyHeld = dx9.isRightClickHeld()

-- Draw FOV circle
if AimbotToggles.enabled.Value and AimbotToggles.show_fov.Value then
    dx9.DrawCircle({mouse.x, mouse.y}, {255, 255, 255}, AimbotToggles.fov.Value)
end

local function GetIndex(type_name, value)
    local tables = {
        box = {"Corners", "2D Box", "3D Box"},
        tracer = {"Near-Bottom", "Bottom", "Top", "Mouse"},
        part = {"Head", "Torso"},
    }
    
    local tbl = tables[type_name]
    if tbl then
        for i, v in next, tbl do
            if v == value then
                return i
            end
        end
    end
    return 1
end

-- ====================================
-- PROCESS INFECTED
-- ====================================

for _, infectedModel in next, InfectedModels do
    local modelName = dx9.GetName(infectedModel)
    
    local head = dx9.FindFirstChild(infectedModel, 'Head')
    local torso = dx9.FindFirstChild(infectedModel, 'HumanoidRootPart')
    local humanoid = dx9.FindFirstChild(infectedModel, 'Humanoid')
    
    if head and head ~= 0 and torso and torso ~= 0 and humanoid and humanoid ~= 0 then
        local headPos = dx9.GetPosition(head)
        local torsoPos = dx9.GetPosition(torso)
        
        if headPos and torsoPos and headPos.x and torsoPos.x then
            local health = dx9.GetHealth(humanoid)
            local maxHealth = dx9.GetMaxHealth(humanoid)
            
            if health and health > 0 then
                local distance = GetDistance(LocalPlayer.Position, torsoPos)
                
                if distance <= ESPToggles.distance_limit.Value then
                    local headScreen = dx9.WorldToScreen({headPos.x, headPos.y, headPos.z})
                    local torsoScreen = dx9.WorldToScreen({torsoPos.x, torsoPos.y, torsoPos.z})
                    
                    if IsOnScreen(headScreen, screenWidth, screenHeight) or IsOnScreen(torsoScreen, screenWidth, screenHeight) then
                        
                        -- ====================================
                        -- ESP RENDERING
                        -- ====================================
                        
                        if ESPToggles.enabled.Value then
                            local customName = modelName
                            if ESPToggles.health.Value then
                                customName = modelName .. " | " .. math.floor(health) .. "/" .. math.floor(maxHealth)
                            end
                            
                            local boxTypeIndex = GetIndex("box", ESPToggles.box_type.Value)
                            local tracerTypeIndex = GetIndex("tracer", ESPToggles.tracer_type.Value)
                            
                            if ESPToggles.boxes.Value then
                                ESP.draw({
                                    target = infectedModel,
                                    color = ESPToggles.color.Value,
                                    healthbar = false,
                                    nametag = ESPToggles.names.Value,
                                    distance = ESPToggles.distance.Value,
                                    custom_nametag = customName,
                                    custom_distance = tostring(math.floor(distance)),
                                    tracer = ESPToggles.tracers.Value,
                                    tracer_type = tracerTypeIndex,
                                    box_type = boxTypeIndex,
                                })
                            end
                        end
                        
                        -- ====================================
                        -- AIMBOT TARGET SELECTION
                        -- ====================================
                        
                        if AimbotToggles.enabled.Value and isAimbotKeyHeld then
                            local targetWorldPos = nil
                            local targetScreen = nil
                            
                            local partIndex = GetIndex("part", AimbotToggles.part.Value)
                            
                            if partIndex == 1 then
                                targetWorldPos = headPos
                                targetScreen = headScreen
                            else
                                targetWorldPos = torsoPos
                                targetScreen = torsoScreen
                            end
                            
                            if targetScreen and targetScreen.x and targetScreen.y then
                                local distToMouse = GetDistance2D(targetScreen, mouse)
                                
                                if distToMouse < AimbotToggles.fov.Value then
                                    if distToMouse < closestDistance then
                                        closestDistance = distToMouse
                                        closestTarget = {
                                            screenPos = targetScreen,
                                            worldPos = targetWorldPos,
                                            distance = distToMouse,
                                            name = modelName,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ====================================
-- AIMBOT EXECUTION (STABLE VERSION)
-- ====================================

if AimbotToggles.enabled.Value and isAimbotKeyHeld and closestTarget then
    -- Draw target indicator
    if AimbotToggles.show_target.Value then
        dx9.DrawCircle(
            {closestTarget.screenPos.x, closestTarget.screenPos.y},
            {0, 255, 0},
            15
        )
        
        -- Draw line from crosshair to target
        dx9.DrawLine(
            {screenWidth / 2, screenHeight / 2},
            {closestTarget.screenPos.x, closestTarget.screenPos.y},
            {0, 255, 0}
        )
    end
    
    -- CRITICAL: Only aim if outside deadzone AND frame limit passed
    local currentTime = os.clock()
    if closestTarget.distance > AimbotToggles.deadzone.Value then
        if (currentTime - _G.lastAimbotFrame) > (1/120) then -- 120 FPS limit
            
            -- Calculate smooth movement toward target
            local deltaX = closestTarget.screenPos.x - mouse.x
            local deltaY = closestTarget.screenPos.y - mouse.y
            
            -- Apply smoothing (larger smoothness = slower movement)
            local moveX = deltaX / AimbotToggles.smoothness.Value
            local moveY = deltaY / AimbotToggles.smoothness.Value
            
            -- Calculate new mouse position
            local newX = mouse.x + moveX
            local newY = mouse.y + moveY
            
            -- Clamp to screen bounds
            if newX < 0 then newX = 0 end
            if newY < 0 then newY = 0 end
            if newX > screenWidth then newX = screenWidth end
            if newY > screenHeight then newY = screenHeight end
            
            -- Apply the movement
            dx9.MouseMove({newX, newY})
            
            -- Update frame timer
            _G.lastAimbotFrame = currentTime
        end
    end
    
    -- Debug info
    if AimbotToggles.debug_info.Value then
        local status = "LOCKED"
        if closestTarget.distance <= AimbotToggles.deadzone.Value then
            status = "IN DEADZONE"
        end
        
        local debugText = string.format(
            "Status: %s\nTarget: %s\nDistance to target: %.1f px\nDeadzone: %.0f px\nSmoothing: %.0f",
            status,
            closestTarget.name,
            closestTarget.distance,
            AimbotToggles.deadzone.Value,
            AimbotToggles.smoothness.Value
        )
        dx9.DrawString({10, 100}, {0, 255, 0}, debugText)
    end
end