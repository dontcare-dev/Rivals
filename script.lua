-- crimson | Rivals (simple skin changer + ESP)
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local MaterialService = game:GetService("MaterialService")
local LP = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Characters = workspace:WaitForChild("Characters", 10)

-- ====================== CONFIG ======================
local Cfg = {
    SkinEnabled = false,
    SelectedWeapon = nil,
    SelectedWrap = nil,
    SelectedMaterial = "Metal",
    UseColor = false,
    SkinColor = Color3.fromRGB(255,255,255),
    UseTransparency = false,
    SkinTransparency = 0.3,
    UseReflectance = false,
    SkinReflectance = 0.2,

    ESP_Enabled = false,
    ESP_Boxes = true,
    ESP_Names = true,
    ESP_Health = true,
    ESP_Distance = true,
    ESP_Tracers = true,
    ESP_HeadDot = true,
    ESP_TeamCheck = true,
    ESP_VisCheck = false,
    ESP_EnemyColor = Color3.fromRGB(255,80,80),
    ESP_TeammateColor = Color3.fromRGB(80,180,255),
}

-- ====================== ASSET REFRESH ======================
local WeaponOptions = {}
local WrapOptions = {}
local ColorOptions = {
    "White", "Red", "Blue", "Green", "Yellow", "Orange", "Purple", "Pink",
    "Black", "Grey", "Cyan", "Gold", "Silver"
}
local ColorValues = {
    White = Color3.new(1,1,1), Red = Color3.new(1,0,0), Blue = Color3.new(0,0,1),
    Green = Color3.new(0,1,0), Yellow = Color3.new(1,1,0), Orange = Color3.new(1,0.5,0),
    Purple = Color3.new(0.5,0,1), Pink = Color3.new(1,0.4,1), Black = Color3.new(0,0,0),
    Grey = Color3.new(0.5,0.5,0.5), Cyan = Color3.new(0,1,1), Gold = Color3.new(1,0.85,0),
    Silver = Color3.new(0.75,0.75,0.75)
}

local function RefreshAssets()
    local ps = LP:FindFirstChild("PlayerScripts")
    local assets = ps and ps:FindFirstChild("Assets")
    local vms = assets and assets:FindFirstChild("ViewModels")
    local weps = vms and vms:FindFirstChild("Weapons")
    local wraps = assets and assets:FindFirstChild("WrapTextures")

    WeaponOptions = {}
    if weps then
        for _, w in ipairs(weps:GetChildren()) do if w:IsA("Model") then table.insert(WeaponOptions, w.Name) end end
    end
    WrapOptions = {}
    if wraps then
        for _, w in ipairs(wraps:GetChildren()) do table.insert(WrapOptions, w.Name) end
    end
    if #WeaponOptions == 0 then WeaponOptions = {"(no weapons)"} end
    if #WrapOptions == 0 then WrapOptions = {"(no wraps)"} end
end

-- ====================== SKIN APPLICATION ======================
local function ApplySkin()
    if not Cfg.SkinEnabled then return end
    local ps = LP:FindFirstChild("PlayerScripts")
    local vms = ps and ps.Assets and ps.Assets.ViewModels
    local weps = vms and vms.Weapons
    if not weps then return end

    for _, weaponModel in ipairs(weps:GetChildren()) do
        if weaponModel:IsA("Model") and (Cfg.SelectedWeapon == weaponModel.Name or Cfg.SelectedWeapon == "All") then
            for _, part in ipairs(weaponModel:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency < 1 then
                    if Cfg.UseColor then part.Color = Cfg.SkinColor end
                    if Cfg.UseTransparency then part.Transparency = Cfg.SkinTransparency end
                    if Cfg.UseReflectance then part.Reflectance = Cfg.SkinReflectance end
                    local mat = Enum.Material[Cfg.SelectedMaterial]
                    if mat then part.Material = mat end

                    -- Apply wrap texture
                    if Cfg.SelectedWrap and Cfg.SelectedWrap ~= "(no wraps)" then
                        -- Remove existing textures/decals
                        for _, obj in ipairs(part:GetChildren()) do
                            if obj:IsA("Texture") or obj:IsA("Decal") or obj:IsA("SurfaceAppearance") then
                                obj:Destroy()
                            end
                        end
                        -- Clone wrap assets onto part
                        local wrapsFolder = ps.Assets.WrapTextures
                        if wrapsFolder then
                            for _, wrap in ipairs(wrapsFolder:GetChildren()) do
                                if wrap.Name == Cfg.SelectedWrap then
                                    for _, child in ipairs(wrap:GetDescendants()) do
                                        if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
                                            local clone = child:Clone()
                                            clone.Parent = part
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
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

-- ====================== ESP ======================
local ESP_Cache = {}
local function UpdateESP()
    for _, d in pairs(ESP_Cache) do pcall(function() d:Remove() end) end
    ESP_Cache = {}
    if not Cfg.ESP_Enabled or not isAlive() then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = plr.Character
        local hrp, head = char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChild("Head")
        if not hrp or not head then continue end

        local visOK = true
        if Cfg.ESP_VisCheck then
            local ray = RaycastParams.new()
            ray.FilterType = Enum.RaycastFilterType.Exclude
            ray.FilterDescendantsInstances = {LP.Character, char}
            local r = workspace:Raycast(camera.CFrame.Position, (head.Position - camera.CFrame.Position).Unit * 500, ray)
            visOK = not r or r.Instance:IsDescendantOf(char)
        end
        if not visOK then continue end

        local col = isEnemy(plr) and Cfg.ESP_EnemyColor or Cfg.ESP_TeammateColor
        local hum = char:FindFirstChild("Humanoid")
        local hp = hum and hum.Health > 0 and hum.Health or 100
        local maxHp = hum and hum.MaxHealth or 100
        local health = math.floor(hp / maxHp * 100)
        local dist = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and math.floor((LP.Character.HumanoidRootPart.Position - hrp.Position).Magnitude) or 0

        local headPos, vis = camera:WorldToViewportPoint(head.Position)
        local rootPos, _ = camera:WorldToViewportPoint(hrp.Position)
        if not vis then continue end

        local boxH = math.abs(headPos.Y - rootPos.Y) * 1.6
        local boxW = boxH * 0.4

        if Cfg.ESP_Boxes then
            local box = Drawing.new("Square")
            box.Visible = true; box.Color = col; box.Thickness = 1; box.Filled = false
            box.Size = Vector2.new(boxW, boxH)
            box.Position = Vector2.new(headPos.X - boxW/2, headPos.Y)
            ESP_Cache["box_"..plr.Name] = box
        end
        if Cfg.ESP_Names then
            local txt = Drawing.new("Text")
            txt.Visible = true; txt.Text = plr.Name; txt.Size = 12; txt.Center = true; txt.Outline = true; txt.Color = col
            txt.Position = Vector2.new(headPos.X, headPos.Y - 20)
            ESP_Cache["name_"..plr.Name] = txt
        end
        if Cfg.ESP_Health then
            local per = health / 100
            local bar = Drawing.new("Square")
            bar.Visible = true; bar.Size = Vector2.new(3, boxH * per)
            bar.Position = Vector2.new(headPos.X - boxW/2 - 6, headPos.Y + boxH * (1 - per))
            bar.Color = Color3.fromRGB(math.floor(255*(1-per)), math.floor(255*per), 0); bar.Filled = true
            ESP_Cache["hp_"..plr.Name] = bar
        end
        if Cfg.ESP_Distance then
            local distTxt = Drawing.new("Text")
            distTxt.Visible = true; distTxt.Text = dist.."m"; distTxt.Size = 11; distTxt.Center = true; distTxt.Outline = true
            distTxt.Color = Color3.new(1,1,1)
            distTxt.Position = Vector2.new(headPos.X, headPos.Y + boxH + 5)
            ESP_Cache["dist_"..plr.Name] = distTxt
        end
        if Cfg.ESP_Tracers then
            local line = Drawing.new("Line")
            line.Visible = true; line.From = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
            line.To = Vector2.new(headPos.X, headPos.Y); line.Color = col; line.Thickness = 1
            ESP_Cache["tracer_"..plr.Name] = line
        end
        if Cfg.ESP_HeadDot then
            local dot = Drawing.new("Circle")
            dot.Visible = true; dot.Radius = 3; dot.Position = Vector2.new(headPos.X, headPos.Y)
            dot.Color = col; dot.Filled = true
            ESP_Cache["dot_"..plr.Name] = dot
        end
    end
end

-- ====================== UI ======================
local Window = Rayfield:CreateWindow({
    Name = "crimson | Rivals",
    LoadingTitle = "crimson hub",
    LoadingSubtitle = "by crimson",
    Theme = "Bloom"
})
local SkinTab = Window:CreateTab("🎨 Skins", 4483362458)
local ESPTab = Window:CreateTab("👁️ ESP", 4483362458)

task.wait(1)
RefreshAssets()

-- Weapon / Wrap dropdowns
local wepDropdown = SkinTab:CreateDropdown({
    Name = "Weapon",
    Options = WeaponOptions,
    CurrentOption = WeaponOptions[1] or "(none)",
    Callback = function(v) Cfg.SelectedWeapon = v[1] ; ApplySkin() end
})
local wrapDropdown = SkinTab:CreateDropdown({
    Name = "Wrap",
    Options = WrapOptions,
    CurrentOption = WrapOptions[1] or "(none)",
    Callback = function(v) Cfg.SelectedWrap = v[1] ; ApplySkin() end
})

-- Material dropdown
local matDropdown = SkinTab:CreateDropdown({
    Name = "Material",
    Options = {"Metal","Plastic","SmoothPlastic","Wood","CorrodedMetal","Foil","Ice","Marble","Neon","Glass","ForceField","Grass","Sand","Fabric","Leather"},
    CurrentOption = "Metal",
    Callback = function(v) Cfg.SelectedMaterial = v[1] ; ApplySkin() end
})

-- Color selection via dropdown
SkinTab:CreateDropdown({
    Name = "Color",
    Options = ColorOptions,
    CurrentOption = "White",
    Callback = function(v)
        Cfg.UseColor = true
        Cfg.SkinColor = ColorValues[v[1]]
        ApplySkin()
    end
})

-- Transparency slider
SkinTab:CreateToggle({Name = "Transparency On", CurrentValue = false, Callback = function(v) Cfg.UseTransparency = v ; ApplySkin() end})
SkinTab:CreateSlider({Name = "Transparency", Range={0,100}, Increment=5, CurrentValue=30, Callback = function(v) Cfg.SkinTransparency = v/100 ; ApplySkin() end})

-- Reflectance slider
SkinTab:CreateToggle({Name = "Reflectance On", CurrentValue = false, Callback = function(v) Cfg.UseReflectance = v ; ApplySkin() end})
SkinTab:CreateSlider({Name = "Reflectance", Range={0,100}, Increment=5, CurrentValue=20, Callback = function(v) Cfg.SkinReflectance = v/100 ; ApplySkin() end})

-- Skin master toggle
SkinTab:CreateToggle({Name = "Enable Skin Changer", CurrentValue = false, Callback = function(v) Cfg.SkinEnabled = v ; ApplySkin() end})

-- Refresh button
SkinTab:CreateButton({Name = "Refresh Assets", Callback = function()
    RefreshAssets()
    wepDropdown:Set(WeaponOptions)
    wrapDropdown:Set(WrapOptions)
    Rayfield:Notify({Title="Refreshed",Content="Weapons: "..#WeaponOptions..", Wraps: "..#WrapOptions})
end})

-- Randomize button
SkinTab:CreateButton({Name = "Randomize", Callback = function()
    if #ColorOptions > 0 then
        local randColor = ColorOptions[math.random(#ColorOptions)]
        Cfg.SkinColor = ColorValues[randColor]
    end
    Cfg.UseTransparency = math.random() > 0.5
    Cfg.SkinTransparency = math.random() * 0.6
    Cfg.UseReflectance = math.random() > 0.5
    Cfg.SkinReflectance = math.random() * 0.5
    if #WrapOptions > 0 then Cfg.SelectedWrap = WrapOptions[math.random(#WrapOptions)] end
    Cfg.SelectedMaterial = matDropdown.CurrentOption[1] or "Metal"
    Cfg.UseColor = true
    ApplySkin()
    Rayfield:Notify({Title="Randomized",Content="Skin applied"})
end})

-- ESP Tab (simplified)
ESPTab:CreateToggle({Name = "ESP Enabled", CurrentValue = false, Callback = function(v) Cfg.ESP_Enabled = v end})
ESPTab:CreateToggle({Name = "Team Check", CurrentValue = true, Callback = function(v) Cfg.ESP_TeamCheck = v end})
ESPTab:CreateToggle({Name = "Boxes", CurrentValue = true, Callback = function(v) Cfg.ESP_Boxes = v end})
ESPTab:CreateToggle({Name = "Names", CurrentValue = true, Callback = function(v) Cfg.ESP_Names = v end})
ESPTab:CreateToggle({Name = "Health", CurrentValue = true, Callback = function(v) Cfg.ESP_Health = v end})
ESPTab:CreateToggle({Name = "Distance", CurrentValue = true, Callback = function(v) Cfg.ESP_Distance = v end})
ESPTab:CreateToggle({Name = "Tracers", CurrentValue = true, Callback = function(v) Cfg.ESP_Tracers = v end})
ESPTab:CreateToggle({Name = "Head Dot", CurrentValue = true, Callback = function(v) Cfg.ESP_HeadDot = v end})
ESPTab:CreateToggle({Name = "Visible Only", CurrentValue = false, Callback = function(v) Cfg.ESP_VisCheck = v end})

-- Main loop
RunService.RenderStepped:Connect(UpdateESP)

-- Re-apply skin periodically (in case new weapon appears)
task.spawn(function()
    while task.wait(0.5) do
        if Cfg.SkinEnabled then ApplySkin() end
    end
end)

Rayfield:Notify({Title = "crimson", Content = "Press 'Refresh Assets' if dropdowns are empty"})