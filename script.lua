-- crimson | Rivals (Skin Changer + ESP) – fixed skin paths
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local MaterialService = game:GetService("MaterialService")
local LP = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Characters = workspace:WaitForChild("Characters", 10)

-- ====================== CONFIG ======================
local Cfg = {
    -- Skin Changer
    SkinEnabled = false,
    SelectedWeapon = nil,
    SelectedWrap = nil,
    UseColor = false,
    SkinColor = Color3.fromRGB(255, 255, 255),
    UseTransparency = false,
    SkinTransparency = 0,
    UseReflectance = false,
    SkinReflectance = 0,
    UseMaterial = false,
    SelectedMaterial = "Metal",
    UseWrapTexture = false,
    ApplyAll = false,

    -- ESP
    ESP_Enabled = false,
    ESP_Boxes = true,
    ESP_Names = true,
    ESP_Health = true,
    ESP_Distance = true,
    ESP_Tracers = true,
    ESP_HeadDot = true,
    ESP_TeamCheck = true,
    ESP_VisCheck = false,
    ESP_FOV = false,
    ESP_FOV_Radius = 120,
    ESP_EnemyColor = Color3.fromRGB(255, 80, 80),
    ESP_TeammateColor = Color3.fromRGB(80, 180, 255),
}

-- ====================== ASSETS (FIXED PATHS) ======================
local WeaponFolder = nil
local WrapFolder = nil
local WrapMatFolder = MaterialService.Wraps:GetChildren()

local WeaponOptions = {}
local WrapOptions = {}
local MaterialOptions = {}
for _, v in pairs(Enum.Material:GetEnumItems()) do
    table.insert(MaterialOptions, v.Name)
end

local function RefreshAssets()
    local ps = LP:FindFirstChild("PlayerScripts")
    local assets = ps and ps:FindFirstChild("Assets")
    local vms = assets and assets:FindFirstChild("ViewModels")

    WeaponFolder = vms and vms:FindFirstChild("Weapons")
    WrapFolder = assets and assets:FindFirstChild("WrapTextures")

    -- Populate weapon names
    WeaponOptions = {}
    if WeaponFolder then
        for _, weapon in ipairs(WeaponFolder:GetChildren()) do
            table.insert(WeaponOptions, weapon.Name)
        end
    end

    -- Populate wrap names (filtered: only wraps that are NOT material variants)
    WrapOptions = {}
    if WrapFolder then
        local wrapMatNames = {}
        for _, wm in ipairs(WrapMatFolder) do wrapMatNames[wm.Name] = true end
        for _, wrap in ipairs(WrapFolder:GetChildren()) do
            if not wrapMatNames[wrap.Name] then
                table.insert(WrapOptions, wrap.Name)
            end
        end
    end

    if #WeaponOptions == 0 then WeaponOptions = {"(no weapons found)"} end
    if #WrapOptions == 0 then WrapOptions = {"(no wraps found)"} end
end

-- ====================== SKIN APPLICATION ======================
local function ApplySkinToModel(weaponModel)
    pcall(function()
        for _, part in ipairs(weaponModel:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency ~= 1 then
                -- Color
                if Cfg.UseColor then
                    part.Color = Cfg.SkinColor
                end
                -- Transparency
                if Cfg.UseTransparency then
                    part.Transparency = Cfg.SkinTransparency
                end
                -- Reflectance
                part.Reflectance = Cfg.UseReflectance and Cfg.SkinReflectance or part.Reflectance
                -- Material
                if Cfg.UseMaterial and Cfg.SelectedMaterial then
                    local mat = Enum.Material[Cfg.SelectedMaterial]
                    if mat then part.Material = mat end
                end
                -- Wrap texture
                if Cfg.UseWrapTexture and Cfg.SelectedWrap and WrapFolder then
                    -- Remove old textures/decals
                    for _, child in ipairs(part:GetChildren()) do
                        if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
                            child:Destroy()
                        end
                    end
                    -- Apply selected wrap
                    for _, wrapTemplate in ipairs(WrapFolder:GetChildren()) do
                        if wrapTemplate.Name == Cfg.SelectedWrap then
                            for _, wrapChild in ipairs(wrapTemplate:GetChildren()) do
                                if wrapChild:IsA("Decal") or wrapChild:IsA("Texture") or wrapChild:IsA("SurfaceAppearance") then
                                    local clone = wrapChild:Clone()
                                    clone.Parent = part
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end)
end

local function RunSkinChanger()
    if not Cfg.SkinEnabled then return end
    if not WeaponFolder then RefreshAssets() end
    if not WeaponFolder then return end

    for _, weapon in ipairs(WeaponFolder:GetChildren()) do
        if Cfg.ApplyAll or (Cfg.SelectedWeapon and weapon.Name == Cfg.SelectedWeapon) then
            ApplySkinToModel(weapon)
        end
    end
end

-- ====================== TEAM DETECTION ======================
local function isAlive()
    return LP.Character and LP.Character:FindFirstChild("Head") and LP.Character:FindFirstChild("Humanoid") and LP.Character.Humanoid.Health > 0
end

local function getTeam(plr)
    if Characters.Terrorists and Characters.Terrorists:FindFirstChild(plr.Name) then return "T" end
    if Characters["Counter-Terrorists"] and Characters["Counter-Terrorists"]:FindFirstChild(plr.Name) then return "CT" end
    return nil
end

local function isEnemy(plr)
    if plr == LP then return false end
    if not Cfg.ESP_TeamCheck then return true end
    local my = getTeam(LP)
    local their = getTeam(plr)
    return my and their and my ~= their
end

local function worldToScreen(pos)
    local s, on = camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), on
end

-- ====================== ESP LOGIC ======================
local ESP_Drawings = {}
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false

local function updateESP()
    for _, d in pairs(ESP_Drawings) do pcall(function() d:Remove() end) end
    ESP_Drawings = {}
    if not Cfg.ESP_Enabled or not isAlive() then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = plr.Character
        local root, head = char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChild("Head")
        if not root or not head then continue end

        if Cfg.ESP_VisCheck then
            local ray = RaycastParams.new()
            ray.FilterType = Enum.RaycastFilterType.Exclude
            ray.FilterDescendantsInstances = {LP.Character, char}
            local result = workspace:Raycast(camera.CFrame.Position, (head.Position - camera.CFrame.Position).Unit * 500, ray)
            if result and not result.Instance:IsDescendantOf(char) then continue end
        end

        local col = isEnemy(plr) and Cfg.ESP_EnemyColor or Cfg.ESP_TeammateColor
        local hum = char:FindFirstChild("Humanoid")
        local hp = hum and hum.Health or 0
        local maxHp = hum and hum.MaxHealth or 100
        local health = maxHp > 0 and math.floor(hp / maxHp * 100) or 0
        local dist = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and math.floor((LP.Character.HumanoidRootPart.Position - root.Position).Magnitude) or 0

        local rootPos, onRoot = worldToScreen(root.Position)
        local headPos, onHead = worldToScreen(head.Position)
        if not onRoot or not onHead then continue end

        local boxHeight = math.abs(headPos.Y - rootPos.Y) * 1.5
        local boxWidth = boxHeight * 0.4

        if Cfg.ESP_Boxes then
            local box = Drawing.new("Square")
            box.Visible = true; box.Color = col; box.Thickness = 1; box.Filled = false
            box.Size = Vector2.new(boxWidth, boxHeight)
            box.Position = Vector2.new(headPos.X - boxWidth / 2, headPos.Y - boxHeight * 0.1)
            ESP_Drawings["box_" .. plr.Name] = box
        end
        if Cfg.ESP_Names then
            local nm = Drawing.new("Text")
            nm.Visible = true; nm.Text = plr.Name; nm.Size = 13; nm.Center = true; nm.Outline = true; nm.Color = col
            nm.Position = Vector2.new(headPos.X, headPos.Y - boxHeight * 0.1 - 16)
            ESP_Drawings["name_" .. plr.Name] = nm
        end
        if Cfg.ESP_Health then
            local per = health / 100
            local bar = Drawing.new("Square")
            bar.Visible = true; bar.Size = Vector2.new(3, boxHeight * per)
            bar.Position = Vector2.new(headPos.X - boxWidth / 2 - 6, headPos.Y - boxHeight * 0.1 + boxHeight * (1 - per))
            bar.Color = Color3.fromRGB(math.floor(255 * (1 - per)), math.floor(255 * per), 0); bar.Filled = true
            ESP_Drawings["hp_" .. plr.Name] = bar
        end
        if Cfg.ESP_Distance then
            local dt = Drawing.new("Text")
            dt.Visible = true; dt.Text = dist .. "m"; dt.Size = 12; dt.Center = true; dt.Outline = true
            dt.Color = Color3.new(1, 1, 1); dt.Position = Vector2.new(rootPos.X, rootPos.Y + boxHeight / 2 + 5)
            ESP_Drawings["dist_" .. plr.Name] = dt
        end
        if Cfg.ESP_Tracers then
            local tracer = Drawing.new("Line")
            tracer.Visible = true; tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
            tracer.To = Vector2.new(rootPos.X, rootPos.Y); tracer.Color = col; tracer.Thickness = 1
            ESP_Drawings["tracer_" .. plr.Name] = tracer
        end
        if Cfg.ESP_HeadDot then
            local dot = Drawing.new("Circle")
            dot.Visible = true; dot.Radius = 3; dot.Position = Vector2.new(headPos.X, headPos.Y)
            dot.Color = col; dot.Filled = true
            ESP_Drawings["dot_" .. plr.Name] = dot
        end
    end

    FOVCircle.Visible = Cfg.ESP_FOV
    if Cfg.ESP_FOV then
        FOVCircle.Radius = Cfg.ESP_FOV_Radius
        FOVCircle.Position = UIS:GetMouseLocation()
        FOVCircle.Color = Color3.fromRGB(255, 255, 255)
        FOVCircle.Thickness = 1; FOVCircle.Filled = false
    end
end

-- ====================== UI (Bloom Theme) ======================
local Window = Rayfield:CreateWindow({
    Name = "crimson | Rivals",
    LoadingTitle = "crimson hub",
    LoadingSubtitle = "by crimson",
    Theme = "Bloom",
})
local SkinTab = Window:CreateTab("🎨 Skins", 4483362458)
local ESPTab = Window:CreateTab("👁️ ESP", 4483362458)

RefreshAssets()

-- Skin Tab
SkinTab:CreateToggle({Name = "Enable Skin Changer", CurrentValue = false, Callback = function(v) Cfg.SkinEnabled = v; if v then RunSkinChanger() end end})
SkinTab:CreateButton({Name = "Refresh Weapon/Wrap Lists", Callback = function()
    RefreshAssets()
    Rayfield:Notify({Title = "Refreshed", Content = "Weapons: " .. #WeaponOptions .. " · Wraps: " .. #WrapOptions})
end})

local WeaponDropdown = SkinTab:CreateDropdown({
    Name = "Target Weapon",
    Options = WeaponOptions,
    CurrentOption = WeaponOptions[1] or "(none)",
    Callback = function(v) Cfg.SelectedWeapon = v[1] end
})
local WrapDropdown = SkinTab:CreateDropdown({
    Name = "Wrap Texture",
    Options = WrapOptions,
    CurrentOption = WrapOptions[1] or "(none)",
    Callback = function(v) Cfg.SelectedWrap = v[1] end
})
local MaterialDropdown = SkinTab:CreateDropdown({
    Name = "Material",
    Options = MaterialOptions,
    CurrentOption = "Metal",
    Callback = function(v) Cfg.SelectedMaterial = v[1] end
})

SkinTab:CreateToggle({Name = "Apply to All Weapons", CurrentValue = false, Callback = function(v) Cfg.ApplyAll = v end})
SkinTab:CreateToggle({Name = "Use Color", CurrentValue = false, Callback = function(v) Cfg.UseColor = v end})
SkinTab:CreateSlider({Name = "Red", Range = {0, 255}, Increment = 1, CurrentValue = 255, Callback = function(v) Cfg.SkinColor = Color3.fromRGB(v, Cfg.SkinColor.G * 255, Cfg.SkinColor.B * 255) end})
SkinTab:CreateSlider({Name = "Green", Range = {0, 255}, Increment = 1, CurrentValue = 255, Callback = function(v) Cfg.SkinColor = Color3.fromRGB(Cfg.SkinColor.R * 255, v, Cfg.SkinColor.B * 255) end})
SkinTab:CreateSlider({Name = "Blue", Range = {0, 255}, Increment = 1, CurrentValue = 255, Callback = function(v) Cfg.SkinColor = Color3.fromRGB(Cfg.SkinColor.R * 255, Cfg.SkinColor.G * 255, v) end})
SkinTab:CreateToggle({Name = "Use Transparency", CurrentValue = false, Callback = function(v) Cfg.UseTransparency = v end})
SkinTab:CreateSlider({Name = "Transparency", Range = {0, 100}, Increment = 1, CurrentValue = 0, Callback = function(v) Cfg.SkinTransparency = v / 100 end})
SkinTab:CreateToggle({Name = "Use Reflectance", CurrentValue = false, Callback = function(v) Cfg.UseReflectance = v end})
SkinTab:CreateSlider({Name = "Reflectance", Range = {0, 100}, Increment = 1, CurrentValue = 0, Callback = function(v) Cfg.SkinReflectance = v / 100 end})
SkinTab:CreateToggle({Name = "Use Material", CurrentValue = false, Callback = function(v) Cfg.UseMaterial = v end})
SkinTab:CreateToggle({Name = "Use Wrap Texture", CurrentValue = false, Callback = function(v) Cfg.UseWrapTexture = v end})
SkinTab:CreateButton({Name = "Apply Changes", Callback = function() RunSkinChanger() end})
SkinTab:CreateButton({Name = "Randomize", Callback = function()
    Cfg.SkinColor = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
    Cfg.SkinTransparency = math.random() * 0.5
    Cfg.SkinReflectance = math.random()
    Cfg.SelectedMaterial = MaterialOptions[math.random(#MaterialOptions)]
    if #WrapOptions > 0 then Cfg.SelectedWrap = WrapOptions[math.random(#WrapOptions)] end
    Cfg.UseColor = true; Cfg.UseTransparency = true; Cfg.UseReflectance = true; Cfg.UseMaterial = true; Cfg.UseWrapTexture = true
    RunSkinChanger()
end})

-- ESP Tab
ESPTab:CreateToggle({Name = "ESP Enabled", CurrentValue = false, Callback = function(v) Cfg.ESP_Enabled = v end})
ESPTab:CreateToggle({Name = "Team Check", CurrentValue = true, Callback = function(v) Cfg.ESP_TeamCheck = v end})
ESPTab:CreateToggle({Name = "Visible Only", CurrentValue = false, Callback = function(v) Cfg.ESP_VisCheck = v end})
ESPTab:CreateToggle({Name = "Boxes", CurrentValue = true, Callback = function(v) Cfg.ESP_Boxes = v end})
ESPTab:CreateToggle({Name = "Names", CurrentValue = true, Callback = function(v) Cfg.ESP_Names = v end})
ESPTab:CreateToggle({Name = "Health", CurrentValue = true, Callback = function(v) Cfg.ESP_Health = v end})
ESPTab:CreateToggle({Name = "Distance", CurrentValue = true, Callback = function(v) Cfg.ESP_Distance = v end})
ESPTab:CreateToggle({Name = "Tracers", CurrentValue = true, Callback = function(v) Cfg.ESP_Tracers = v end})
ESPTab:CreateToggle({Name = "Head Dot", CurrentValue = true, Callback = function(v) Cfg.ESP_HeadDot = v end})
ESPTab:CreateSection("FOV Circle")
ESPTab:CreateToggle({Name = "Show FOV", CurrentValue = false, Callback = function(v) Cfg.ESP_FOV = v end})
ESPTab:CreateSlider({Name = "FOV Radius", Range = {10, 500}, Increment = 10, CurrentValue = 120, Callback = function(v) Cfg.ESP_FOV_Radius = v end})

-- ====================== Main Loop ======================
RunService.Heartbeat:Connect(function()
    if Cfg.SkinEnabled then RunSkinChanger() end
    if Cfg.ESP_Enabled then updateESP() end
end)

Rayfield:Notify({Title = "crimson | Rivals", Content = "Skin Changer + ESP loaded"})