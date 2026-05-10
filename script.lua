-- crimson | Rivals ·
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MaterialService = game:GetService("MaterialService")
local LP = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Characters = workspace:WaitForChild("Characters", 10)

-- ====================== CONFIG ======================
local Cfg = {
    SkinEnabled = false,
    SelectedWeapon = nil,
    SelectedWrap = nil,
    SelectedSkin = nil,
    ApplyAll = false,

    ESP_Enabled = false,
    ESP_Boxes = true,
    ESP_Names = true,
    ESP_Health = true,
    ESP_Distance = true,
    ESP_Tracers = true,
    ESP_HeadDot = true,
    ESP_TeamCheck = true,
    ESP_EnemyColor = Color3.fromRGB(255, 80, 80),
    ESP_TeammateColor = Color3.fromRGB(80, 180, 255),
}

-- ====================== ASSET REFERENCES ======================
local Weapons = {}        -- table of weapon Model instances (templates)
local WrapTextures = {}   -- table of WrapTexture Folder instances
local WrapMaterials = {}  -- table of MaterialVariant instances
local WeaponNames = {}
local WrapNames = {}
local SkinNames = {}

local function RefreshAssets()
    local ps = LP:FindFirstChild("PlayerScripts")
    local assets = ps and ps:FindFirstChild("Assets")
    local vms = assets and assets:FindFirstChild("ViewModels")
    local wepsFolder = vms and vms:FindFirstChild("Weapons")
    local wrapsFolder = assets and assets:FindFirstChild("WrapTextures")

    Weapons = {}
    if wepsFolder then
        local waited = 0
        while #wepsFolder:GetChildren() == 0 and waited < 30 do
            task.wait(0.1)
            waited = waited + 1
        end
        for _, v in ipairs(wepsFolder:GetChildren()) do
            if v:IsA("Model") then table.insert(Weapons, v) end
        end
    end

    WrapTextures = {}
    if wrapsFolder then
        local waited = 0
        while #wrapsFolder:GetChildren() == 0 and waited < 30 do
            task.wait(0.1)
            waited = waited + 1
        end
        for _, v in ipairs(wrapsFolder:GetChildren()) do
            table.insert(WrapTextures, v)
        end
    end

    WeaponNames = {}
    for _, v in ipairs(Weapons) do table.insert(WeaponNames, v.Name) end
    if #WeaponNames == 0 then WeaponNames = {"(equip a weapon first)"} end

    WrapMaterials = {}
    SkinNames = {}
    local wrapTexNames = {}
    for _, v in ipairs(WrapTextures) do wrapTexNames[v.Name] = true end
    for _, v in ipairs(MaterialService.Wraps:GetChildren()) do
        table.insert(WrapMaterials, v)
        if not wrapTexNames[v.Name] then
            table.insert(SkinNames, v.Name)
        end
    end
    if #SkinNames == 0 then SkinNames = {"(none)"} end

    WrapNames = {}
    local matNames = {}
    for _, v in ipairs(WrapMaterials) do matNames[v.Name] = true end
    for _, v in ipairs(WrapTextures) do
        if not matNames[v.Name] then
            table.insert(WrapNames, v.Name)
        end
    end
    if #WrapNames == 0 then WrapNames = {"(none)"} end
end

-- ====================== APPLY SKIN TO A SINGLE MODEL ======================
local function ApplyToModel(model)
    for _, part in ipairs(model:GetDescendants()) do
        if not part:IsA("BasePart") or part.Transparency >= 1 then continue end

        -- Material variant (Skin)
        if Cfg.SelectedSkin and Cfg.SelectedSkin ~= "(none)" then
            for _, mv in ipairs(WrapMaterials) do
                if mv.Name == Cfg.SelectedSkin then
                    part.Material = Enum.Material.Fabric
                    part.MaterialVariant = mv.Name
                    for _, child in ipairs(part:GetChildren()) do
                        if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
                            child:Destroy()
                        end
                    end
                    break
                end
            end
        end

        -- Wrap texture
        if Cfg.SelectedWrap and Cfg.SelectedWrap ~= "(none)" then
            for _, wrap in ipairs(WrapTextures) do
                if wrap.Name == Cfg.SelectedWrap then
                    for _, child in ipairs(part:GetChildren()) do
                        if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
                            child:Destroy()
                        end
                    end
                    for _, asset in ipairs(wrap:GetChildren()) do
                        if asset:IsA("Decal") or asset:IsA("Texture") or asset:IsA("SurfaceAppearance") then
                            local clone = asset:Clone()
                            clone.Parent = part
                        end
                    end
                    break
                end
            end
        end
    end
end

-- ====================== APPLY SKIN TO TEMPLATES + LIVE CAMERA MODELS ======================
local function ApplySkin()
    if not Cfg.SkinEnabled then return end

    -- Apply to templates (for future spawns)
    for _, weaponModel in ipairs(Weapons) do
        if Cfg.ApplyAll or weaponModel.Name == Cfg.SelectedWeapon then
            ApplyToModel(weaponModel)
        end
    end

    -- Apply to live camera models (immediate update)
    for _, obj in ipairs(camera:GetChildren()) do
        if obj:IsA("Model") and not obj:FindFirstChild("Humanoid") then -- weapon models, not player
            if Cfg.ApplyAll or obj.Name == Cfg.SelectedWeapon then
                ApplyToModel(obj)
            end
        end
    end
end

-- Hook: when a new weapon appears in the camera (respawn, pick‑up, re‑equip), skin it instantly
camera.ChildAdded:Connect(function(obj)
    if not Cfg.SkinEnabled then return end
    if obj:IsA("Model") and not obj:FindFirstChild("Humanoid") then
        if Cfg.ApplyAll or obj.Name == Cfg.SelectedWeapon then
            task.wait(0.05)  -- tiny delay so the model is fully assembled
            ApplyToModel(obj)
        end
    end
end)

-- ====================== ESP ======================
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
    local my, their = getTeam(LP), getTeam(plr)
    return my and their and my ~= their
end

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

        local col = isEnemy(plr) and Cfg.ESP_EnemyColor or Cfg.ESP_TeammateColor
        local hum = char:FindFirstChild("Humanoid")
        local hp = hum and hum.Health or 100
        local maxHp = hum and hum.MaxHealth or 100
        local health = math.floor(hp / maxHp * 100)
        local dist = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and math.floor((LP.Character.HumanoidRootPart.Position - hrp.Position).Magnitude) or 0

        local headPos, onScreen = camera:WorldToViewportPoint(head.Position)
        local rootPos, _ = camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then continue end

        local boxH = math.abs(headPos.Y - rootPos.Y) * 1.6
        local boxW = boxH * 0.4

        if Cfg.ESP_Boxes then
            local box = Drawing.new("Square")
            box.Visible = true; box.Color = col; box.Thickness = 1; box.Filled = false
            box.Size = Vector2.new(boxW, boxH); box.Position = Vector2.new(headPos.X - boxW/2, headPos.Y)
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
            local dt = Drawing.new("Text")
            dt.Visible = true; dt.Text = dist.."m"; dt.Size = 11; dt.Center = true; dt.Outline = true
            dt.Color = Color3.new(1,1,1); dt.Position = Vector2.new(headPos.X, headPos.Y + boxH + 5)
            ESP_Cache["dist_"..plr.Name] = dt
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
    Theme = "Bloom",
})
local SkinTab = Window:CreateTab("Skins", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)

task.wait(1)
RefreshAssets()

local wepDropdown = SkinTab:CreateDropdown({
    Name = "Weapon",
    Options = WeaponNames,
    CurrentOption = WeaponNames[1] or "(none)",
    Callback = function(v) Cfg.SelectedWeapon = v[1]; if Cfg.SkinEnabled then ApplySkin() end end
})

local wrapDropdown = SkinTab:CreateDropdown({
    Name = "Wrap",
    Options = WrapNames,
    CurrentOption = "(none)",
    Callback = function(v) Cfg.SelectedWrap = v[1]; if Cfg.SkinEnabled then ApplySkin() end end
})

local skinDropdown = SkinTab:CreateDropdown({
    Name = "Skin (Material)",
    Options = SkinNames,
    CurrentOption = "(none)",
    Callback = function(v) Cfg.SelectedSkin = v[1]; if Cfg.SkinEnabled then ApplySkin() end end
})

SkinTab:CreateToggle({
    Name = "Apply to All Weapons",
    CurrentValue = false,
    Callback = function(v) Cfg.ApplyAll = v; if Cfg.SkinEnabled then ApplySkin() end end
})

SkinTab:CreateToggle({
    Name = "Enable Skin Changer",
    CurrentValue = false,
    Callback = function(v) Cfg.SkinEnabled = v; if v then ApplySkin() end end
})

SkinTab:CreateButton({Name = "Refresh", Callback = function()
    RefreshAssets()
    wepDropdown:Set(WeaponNames)
    wrapDropdown:Set(WrapNames)
    skinDropdown:Set(SkinNames)
    Rayfield:Notify({Title="Refreshed", Content="Weapons: "..#WeaponNames.." · Wraps: "..#WrapNames.." · Skins: "..#SkinNames})
end})

SkinTab:CreateButton({Name = "Randomize", Callback = function()
    if #WrapNames > 0 and WrapNames[1] ~= "(none)" then
        Cfg.SelectedWrap = WrapNames[math.random(#WrapNames)]
        wrapDropdown:Set({Cfg.SelectedWrap})
    end
    if #SkinNames > 0 and SkinNames[1] ~= "(none)" then
        Cfg.SelectedSkin = SkinNames[math.random(#SkinNames)]
        skinDropdown:Set({Cfg.SelectedSkin})
    end
    ApplySkin()
    Rayfield:Notify({Title="Randomized", Content="Wrap: "..(Cfg.SelectedWrap or "none").." · Skin: "..(Cfg.SelectedSkin or "none")})
end})

-- ESP Tab
ESPTab:CreateToggle({Name = "ESP Enabled", CurrentValue = false, Callback = function(v) Cfg.ESP_Enabled = v end})
ESPTab:CreateToggle({Name = "Team Check", CurrentValue = true, Callback = function(v) Cfg.ESP_TeamCheck = v end})
ESPTab:CreateToggle({Name = "Boxes", CurrentValue = true, Callback = function(v) Cfg.ESP_Boxes = v end})
ESPTab:CreateToggle({Name = "Names", CurrentValue = true, Callback = function(v) Cfg.ESP_Names = v end})
ESPTab:CreateToggle({Name = "Health", CurrentValue = true, Callback = function(v) Cfg.ESP_Health = v end})
ESPTab:CreateToggle({Name = "Distance", CurrentValue = true, Callback = function(v) Cfg.ESP_Distance = v end})
ESPTab:CreateToggle({Name = "Tracers", CurrentValue = true, Callback = function(v) Cfg.ESP_Tracers = v end})
ESPTab:CreateToggle({Name = "Head Dot", CurrentValue = true, Callback = function(v) Cfg.ESP_HeadDot = v end})

RunService.RenderStepped:Connect(UpdateESP)

Rayfield:Notify({Title="crimson | Rivals", Content=""})