-- ====================================
-- OPTIMIZED PLAYER ESP SCRIPT
-- ====================================
--
-- HOTKEYS:
-- [P] - Toggle team switching (swap enemy/friendly)
-- [O] - Cycle through enemy colors (7 colors available)
-- [L] - Toggle name tags and distance display
--
-- ====================================

-- Configuration
local BOXES = false
local CHAMS = true
local SHOWTEAM = false
local MAX_DISTANCE = 500

-- Color palette for enemy team (cycle with O key)
local COLOR_PALETTE = {
    {255, 0, 0},      -- Red
    {255, 165, 0},    -- Orange
    {255, 255, 0},    -- Yellow
    {255, 0, 255},    -- Magenta/Pink
    {0, 255, 255},    -- Cyan
    {255, 255, 255},  -- White
    {128, 0, 128},    -- Purple
}

local TEAM_COLOR = {0, 255, 0}  -- Friendly team color (Green)

-- ====================================
-- PERSISTENT VARIABLES (use globals to persist across frames)
-- ====================================

if not _G.ESP_INITIALIZED then
    _G.SWITCHTEAM = false
    _G.lastKeyState_P = false
    _G.lastKeyState_O = false
    _G.lastKeyState_L = false
    _G.currentColorIndex = 1
    _G.SHOW_TAGS = true
    _G.ESP_INITIALIZED = true
end

-- ====================================
-- HELPER FUNCTIONS
-- ====================================

function GetDistance(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dz = b.z - a.z
    return math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz))
end

function addVec(a, b)
    return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end

function scaleVec(v, s)
    return {x = v.x * s, y = v.y * s, z = v.z * s}
end

function DrawBox(position, cframe, size, color)
    local halfSize = {x = (size.x * 0.5), y = (size.y * 0.5), z = (size.z * 0.5)}
    local corners = {}

    -- Generate corners
    for dx = -1, 1, 2 do
        for dy = -1, 1, 2 do
            for dz = -1, 1, 2 do
                local offset = addVec(
                    addVec(
                        scaleVec(cframe.RightVector, dx * halfSize.x),
                        scaleVec(cframe.UpVector, dy * halfSize.y)
                    ),
                    scaleVec(cframe.LookVector, dz * halfSize.z)
                )
                table.insert(corners, addVec(position, offset))
            end
        end
    end
    
    -- Convert to screen space and validate
    local screenPoints = {}
    local screenWidth = dx9.size().width
    local screenHeight = dx9.size().height
    local validPoints = {}
    
    for i, world in ipairs(corners) do
        local screenPos = dx9.WorldToScreen({world.x, world.y, world.z})
        screenPoints[i] = {x = screenPos.x, y = screenPos.y}
        
        -- Check if point is within reasonable screen bounds
        if screenPos.x > -100 and screenPos.x < screenWidth + 100 and 
           screenPos.y > -100 and screenPos.y < screenHeight + 100 then
            validPoints[i] = true
        else
            validPoints[i] = false
        end
    end

    -- Draw edges
    local edges = {
        {1,2},{2,4},{4,3},{3,1},
        {5,6},{6,8},{8,7},{7,5},
        {1,5},{2,6},{3,7},{4,8}
    }

    for _, edge in ipairs(edges) do
        local idx1, idx2 = edge[1], edge[2]
        if validPoints[idx1] and validPoints[idx2] then
            local a, b = screenPoints[idx1], screenPoints[idx2]
            dx9.DrawLine({a.x, a.y}, {b.x, b.y}, color)
        end
    end
end

-- ====================================
-- HOTKEY HANDLING
-- ====================================

local currentKey = dx9.GetKey()

-- [P] Toggle team switching
if currentKey == "[P]" then
    if not _G.lastKeyState_P then
        _G.SWITCHTEAM = not _G.SWITCHTEAM
        _G.lastKeyState_P = true
    end
else
    _G.lastKeyState_P = false
end

-- [O] Cycle through enemy colors
if currentKey == "[O]" then
    if not _G.lastKeyState_O then
        _G.currentColorIndex = _G.currentColorIndex + 1
        if _G.currentColorIndex > #COLOR_PALETTE then
            _G.currentColorIndex = 1
        end
        _G.lastKeyState_O = true
    end
else
    _G.lastKeyState_O = false
end

-- [L] Toggle name/distance display
if currentKey == "[L]" then
    if not _G.lastKeyState_L then
        _G.SHOW_TAGS = not _G.SHOW_TAGS
        _G.lastKeyState_L = true
    end
else
    _G.lastKeyState_L = false
end

-- ====================================
-- MAIN ESP EXECUTION
-- ====================================

local DataModel = dx9.GetDatamodel()
local workspace = dx9.FindFirstChildOfClass(DataModel, "Workspace")
local cameraFolder = dx9.FindFirstChild(workspace, "Camera")
local cameraPart = dx9.FindFirstChild(cameraFolder, "Part")
local camPosition = dx9.GetPosition(cameraPart)
local playersFolder = dx9.FindFirstChild(workspace, "Players")

if not playersFolder then return end

local teamsFolders = dx9.GetChildren(playersFolder)

-- Cache screen dimensions
local screenWidth = dx9.size().width
local screenHeight = dx9.size().height

-- Draw hotkey status indicator
local statusY = 10
local statusText = "[P] Team: " .. (_G.SWITCHTEAM and "SWITCHED" or "NORMAL") .. 
                   " | [O] Color: " .. _G.currentColorIndex .. "/" .. #COLOR_PALETTE ..
                   " | [L] Tags: " .. (_G.SHOW_TAGS and "ON" or "OFF")
dx9.DrawString({10, statusY}, {255, 255, 255}, statusText)

for i = 1, 2 do
    local myTeamIndex = 2
    local enemyTeamIndex = 1
    local color = nil
    
    if _G.SWITCHTEAM then
        myTeamIndex = 1
        enemyTeamIndex = 2
    end
    
    -- Assign colors based on team
    if i == enemyTeamIndex then
        color = COLOR_PALETTE[_G.currentColorIndex]
    else
        color = TEAM_COLOR
    end
    
    local shouldShow = false
    if i == enemyTeamIndex then
        shouldShow = true
    elseif i == myTeamIndex and SHOWTEAM then
        shouldShow = true
    end
    
    if shouldShow then
        local playersOnThisTeam = dx9.GetChildren(teamsFolders[i])
        
        for j = 1, #playersOnThisTeam do
            local player = playersOnThisTeam[j]
            local playerName = dx9.GetName(player)
            local playerBodyParts = dx9.GetChildren(player)
            local highestPoint = nil
            local lowestPoint = nil
            local headPosition = nil
            local shouldDraw = false

            for k = 1, #playerBodyParts do
                local bodyPart = playerBodyParts[k]
                
                if dx9.GetType(bodyPart) == "Part" then
                    local pos = dx9.GetPosition(bodyPart)
                    local distance = GetDistance(pos, camPosition)
                    
                    if distance > 5 and distance <= MAX_DISTANCE then
                        shouldDraw = true
                        local size = {x = 1, y = 2, z = 1}
                        local decal = dx9.FindFirstChildOfClass(bodyPart, "Decal")
                        local light = dx9.FindFirstChildOfClass(bodyPart, "SpotLight")
                        
                        if decal ~= 0 then
                            size = {x = 1, y = 1, z = 1}
                            highestPoint = {x = pos.x, y = pos.y + 0.5, z = pos.z}
                            headPosition = pos
                        elseif light ~= 0 then
                            size = {x = 2, y = 2, z = 1}
                            lowestPoint = {x = pos.x, y = pos.y - 1, z = pos.z}
                        end
                        
                        if CHAMS then
                            local cf = dx9.GetCFrame(bodyPart)
                            DrawBox(pos, cf, size, color)
                        end
                    end
                end
            end
            
            if shouldDraw then
                if BOXES then
                    if lowestPoint and highestPoint then
                        local topScreenPosition = dx9.WorldToScreen({highestPoint.x, highestPoint.y, highestPoint.z})
                        local bottomScreenPosition = dx9.WorldToScreen({lowestPoint.x, lowestPoint.y, lowestPoint.z})
                        local diff = (bottomScreenPosition.y - topScreenPosition.y) / 3
                        local topLeft = {x = topScreenPosition.x - diff, y = topScreenPosition.y}
                        local bottomRight = {x = bottomScreenPosition.x + diff, y = bottomScreenPosition.y}

                        dx9.DrawBox({topLeft.x, topLeft.y}, {bottomRight.x, bottomRight.y}, color)
                    end
                end
                
                -- Draw player name and distance above head
                if headPosition and _G.SHOW_TAGS then
                    local screenPos = dx9.WorldToScreen({headPosition.x, headPosition.y + 1.5, headPosition.z})
                    
                    if screenPos.x > 0 and screenPos.x < screenWidth and 
                       screenPos.y > 0 and screenPos.y < screenHeight then
                        
                        local distance = GetDistance(headPosition, camPosition)
                        local infoText = playerName .. " [" .. distance .. "m]"
                        
                        local textWidth = dx9.CalcTextWidth(infoText)
                        local textX = screenPos.x - (textWidth / 2)
                        local textY = screenPos.y
                        
                        -- Background box
                        dx9.DrawFilledBox(
                            {textX - 3, textY - 2}, 
                            {textX + textWidth + 3, textY + 14}, 
                            {0, 0, 0}
                        )
                        
                        -- Text
                        dx9.DrawString({textX, textY}, color, infoText)
                    end
                end
            end
        end
    end
end