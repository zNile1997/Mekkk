local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local PlaceId = game.PlaceId

-- ====== LIST ITEM ======
local defaultList = {
    ['La Vacca Saturno Saturnita'] = true,
    ['Karkerkar Kurkur'] = true,
    ['Chimpanzini Spiderini'] = true,
    ['Torrtuginni Dragonfrutini'] = true,
    ['Bisonte Giuppitere'] = true,
    ['Dul Dul Dul'] = true,
    ['Sammyni Spyderini'] = true,
    ['Agarrini la Palini'] = true,
    ['Blackhole Goat'] = true,
}
local fixedExtra = {
    ["Los Tralaleritos"] = true,
    ["Los Spyderinis"] = true,
    ["Las Tralaleritas"] = true,
    ["Los Matteos"] = true,
    ["Las Vaquitas Saturnitas"] = true,
    ["Job Job Job Sahur"] = true,
    ["Nooo My Hotsoot"] = true,
    ["Ketupat Kepat"] = true,
    ["La Supreme Combinasion"] = true,
    ['Graipuss Medussi'] = true,
    ['Pot Hotspot'] = true,
    ['Chicleteira Bicicleteira'] = true,
    ['La Grande Combinasion'] = true,
    ['Los Combinasionas'] = true,
    ['Los Hotspotsitos'] = true,
    ['Dragon Cannelloni'] = true,
    ['Nuclearo Dinossauro'] = true,
    ['Esok Sekolah'] = true,
    ['Garama and Madundung'] = true,
}

getgenv().EXTRA_ITEMS = getgenv().EXTRA_ITEMS or {}
getgenv().ITEMS_TO_FIND = {}
for k in pairs(defaultList) do getgenv().ITEMS_TO_FIND[k] = "default" end
for k in pairs(fixedExtra) do getgenv().ITEMS_TO_FIND[k] = "extra" end
for k in pairs(getgenv().EXTRA_ITEMS) do getgenv().ITEMS_TO_FIND[k] = "extra" end

getgenv().SCAN_DELAY = getgenv().SCAN_DELAY or 10
getgenv().STOP_MODE = getgenv().STOP_MODE or "none" -- "none" / "default" / "extra"

local visitedServers, hopCount, foundSecret = {}, 0, false

-- 🖥️ GUI SETUP
if game.CoreGui:FindFirstChild("SecretServerUI") then
    game.CoreGui.SecretServerUI:Destroy()
end
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "SecretServerUI"

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 320)
MainFrame.Position = UDim2.new(0.5, -120, 0.5, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 112)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

-- Header
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -120, 1, 0)
Title.Position = UDim2.new(0, 8, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🔮 Secret Finder"
Title.TextColor3 = Color3.new(1,1,1)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Buttons
local function makeBtn(parent, txt, xPos)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0, 30, 0, 24)
    btn.Position = UDim2.new(1, xPos, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
    btn.Text = txt
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local RefreshBtn = makeBtn(Header, "🔄", -105)
local ScanBtn = makeBtn(Header, "🔍", -70)
local HopBtn = makeBtn(Header, "🔁", -70-35)
local MinBtn = makeBtn(Header, "➖", -35)
HopBtn.BackgroundColor3 = Color3.fromRGB(200,100,50)
ScanBtn.BackgroundColor3 = Color3.fromRGB(50,200,100)

-- Scroll Area
local ScrollFrame = Instance.new("ScrollingFrame", MainFrame)
ScrollFrame.Size = UDim2.new(1, -8, 1, -45)
ScrollFrame.Position = UDim2.new(0, 4, 0, 40)
ScrollFrame.CanvasSize = UDim2.new(0,0,0,0)
ScrollFrame.ScrollBarThickness = 5
ScrollFrame.BackgroundTransparency = 1
local ListLayout = Instance.new("UIListLayout", ScrollFrame)
ListLayout.Padding = UDim.new(0,4)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Minimize
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        ScrollFrame.Visible = false
        RefreshBtn.Visible = false
        ScanBtn.Visible = false
        HopBtn.Visible = false
        MinBtn.Text = "➕"
        MainFrame.Size = UDim2.new(0,240,0,35)
    else
        ScrollFrame.Visible = true
        RefreshBtn.Visible = true
        ScanBtn.Visible = true
        HopBtn.Visible = true
        MinBtn.Text = "➖"
        MainFrame.Size = UDim2.new(0,240,0,320)
    end
end)

-- 🔔 NOTIF ROBLOX
local function showPopup(msg, _, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Notification",
            Text = msg,
            Duration = dur or 3
        })
    end)
end

-- 🧩 SECRET FINDER (LABEL TETAP ADA)
local function isValidItem(obj)
    return obj:IsA("BasePart") or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")))
end

local function addLabel(obj)
    if obj:FindFirstChild("SecretLabel") then return end
    local adornee = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
    if not adornee then return end
    local bb = Instance.new("BillboardGui", obj)
    bb.Name="SecretLabel"
    bb.Size=UDim2.new(0,200,0,12)
    bb.AlwaysOnTop=true
    bb.Adornee=adornee
    bb.StudsOffset=Vector3.new(0, (adornee.Size and adornee.Size.Y/2 or 2)+2, 0)
    local t=Instance.new("TextLabel",bb)
    t.Size=UDim2.new(1,0,1,0)
    t.BackgroundTransparency=1
    t.Text=obj.Name
    t.TextColor3=Color3.fromRGB(255,59,216)
    t.Font=Enum.Font.GothamBold
    t.TextScaled=true
end

local function scanWorkspace()
    local found=false
    for _,o in ipairs(workspace:GetDescendants()) do
        local itemType = getgenv().ITEMS_TO_FIND[o.Name]
        if itemType and isValidItem(o) then
            addLabel(o)
            showPopup("🎯 Found: "..o.Name, nil, 4)
            found=true
            if getgenv().STOP_MODE==itemType then foundSecret=true end
        end
    end
    return found
end

workspace.DescendantAdded:Connect(function(o)
    local itemType = getgenv().ITEMS_TO_FIND[o.Name]
    if itemType and isValidItem(o) then
        task.delay(0.1,function()
            if o and o.Parent then
                addLabel(o)
                showPopup("🎯 Live: "..o.Name, nil, 4)
                if getgenv().STOP_MODE==itemType then foundSecret=true end
            end
        end)
    end
end)

-- 🔁 SERVER HOP
local function serverHop()
    if foundSecret then return end
    showPopup("🔁 Server Hop...", nil, 3)
    local succ,res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if not succ or not res or not res.data then return end
    local servers={}
    for _,s in ipairs(res.data) do
        if s.playing < s.maxPlayers and not visitedServers[s.id] then
            table.insert(servers,s.id)
        end
    end
    if #servers==0 then return end
    local target=servers[math.random(1,#servers)]
    visitedServers[target]=true
    hopCount+=1
    TeleportService:TeleportToPlaceInstance(PlaceId,target,LocalPlayer)
end

TeleportService.TeleportInitFailed:Connect(function(p,_,reason)
    if p==LocalPlayer then
        showPopup("Teleport gagal: "..tostring(reason), nil, 3)
        task.delay(2,serverHop)
    end
end)

-- 📋 SERVER LIST
local function ClearList()
    for _,c in pairs(ScrollFrame:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
    end
    ScrollFrame.CanvasSize=UDim2.new(0,0,0,0)
end

local function LoadServers()
    ClearList()
    local url="https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Desc&limit=25"
    local succ,res=pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if succ and res and res.data then
        local count=0
        for _,s in pairs(res.data) do
            count+=1
            local btn=Instance.new("TextButton",ScrollFrame)
            btn.Size=UDim2.new(1,-6,0,28)
            btn.BackgroundColor3=Color3.fromRGB(60,60,60)
            btn.Text="👥 "..s.playing.." / "..s.maxPlayers
            btn.TextColor3=Color3.new(1,1,1)
            btn.Font=Enum.Font.SourceSans
            btn.TextSize=14
            Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
            btn.MouseButton1Click:Connect(function()
                TeleportService:TeleportToPlaceInstance(PlaceId,s.id,LocalPlayer)
            end)
        end
        ScrollFrame.CanvasSize=UDim2.new(0,0,0,count*32)
    end
end
RefreshBtn.MouseButton1Click:Connect(LoadServers)

-- 🎮 BUTTON LOGIC
ScanBtn.MouseButton1Click:Connect(function()
    showPopup("🔍 Scanning...", nil, 3)
    task.wait(getgenv().SCAN_DELAY)
    if not scanWorkspace() then
        showPopup("❌ No secret found", nil, 3)
    end
end)

HopBtn.MouseButton1Click:Connect(function()
    showPopup("🔁 Auto Hop Enabled", nil, 3)
    foundSecret=false
    task.spawn(function()
        while not foundSecret do
            task.wait(getgenv().SCAN_DELAY)
            if not scanWorkspace() then
                serverHop()
            else
                showPopup("✅ Secret Found! Stop hopping", nil, 5)
                break
            end
        end
    end)
end)

-- 🔄 AUTO LOAD SERVER LIST
LoadServers()
showPopup("✅ Secret Finder + Server List Loaded", nil, 5)
