-- 1. รอให้เกมโหลดเสร็จ
if not game:IsLoaded() then game.Loaded:Wait() end
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer or players:GetPropertyChangedSignal("LocalPlayer"):Wait() or players.LocalPlayer

local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- 🛡️ โหลด Config
local config = _G.HorstInventoryConfig or {}
local targetUnitsWhitelist = config.Units or {}
local targetItemsWhitelist = config.Items or {}
local targetMountsWhitelist = config.Mounts or {}

-- 🛠️ Helper Functions
local function findScrollingFrame(currentObject)
    if currentObject:IsA("ScrollingFrame") and currentObject.Name == "ScrollingFrame" then return currentObject end
    for _, child in pairs(currentObject:GetChildren()) do
        local found = findScrollingFrame(child)
        if found then return found end
    end
    return nil
end

local function isInWhitelist(name, whitelistTable)
    if not name then return false end
    local cleanName = string.lower(string.match(name, "^%s*(.-)%s*$") or "")
    for _, whitelistedName in pairs(whitelistTable) do
        if string.lower(whitelistedName) == cleanName then return whitelistedName end
    end
    return nil
end

local function safeToNumber(val)
    if type(val) ~= "string" then return 1 end
    local cleaned = string.gsub(string.gsub(string.gsub(val, ",", ""), "x", ""), "X", "")
    local numberOnly = string.match(cleaned, "%d+")
    return tonumber(numberOnly) or 1
end

local function formatNumber(amount)
    local formatted = tostring(amount)
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- 🕵️‍♂️ ฟังก์ชันสแกนหลัก (แบบสะสมข้อมูล)
local function runInventoryScan()
    local GlobalResults = {Units = {}, Items = {}, Mounts = {}}
    local hasFound = false
    
    -- 1. สแกน Units
    local unitInventory = playerGui:FindFirstChild("UnitInventory")
    if unitInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
        task.wait(0.5)
        local frame = findScrollingFrame(unitInventory)
        if frame then
            frame.CanvasPosition = Vector2.new(0, frame.AbsoluteCanvasSize.Y)
            task.wait(0.5)
            for _, slot in pairs(frame:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" and not string.find(string.lower(child.Text), "lvl") then
                            local matched = isInWhitelist(child.Text, targetUnitsWhitelist)
                            if matched then GlobalResults.Units[matched] = (GlobalResults.Units[matched] or 0) + 1; hasFound = true end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
    end

    -- 2. สแกน Items & Mounts (อยู่ใน Inventory เดียวกัน)
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(0.5)
        local frame = findScrollingFrame(itemInventory)
        
        -- สแกน Items
        if frame then
            for _, slot in pairs(frame:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    local name, count = nil, 1
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            if string.find(string.lower(child.Text), "x") then count = safeToNumber(child.Text)
                            elseif not string.find(string.lower(child.Text), "lvl") then name = child.Text end
                        end
                    end
                    if name then
                        local matched = isInWhitelist(name, targetItemsWhitelist)
                        if matched then GlobalResults.Items[matched] = (GlobalResults.Items[matched] or 0) + count; hasFound = true end
                    end
                end
            end
        end

        -- สลับไป Mounts
        pcall(function()
            local tabContainer = itemInventory.Frame.Frame.Frame.Frame.Frame
            for _, child in pairs(tabContainer:GetChildren()) do
                if child:FindFirstChild("PrimaryButton") then
                    local label = child:FindFirstChild("Text", true)
                    if label and string.find(string.lower(label.Text), "mounts") then
                        child.PrimaryButton.MouseButton1Click:Fire()
                        break
                    end
                end
            end
        end)
        task.wait(1.5)
        
        -- สแกน Mounts
        if frame then
            for _, slot in pairs(frame:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            local matched = isInWhitelist(child.Text, targetMountsWhitelist)
                            if matched then GlobalResults.Mounts[matched] = (GlobalResults.Mounts[matched] or 0) + 1; hasFound = true end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
    end

    -- 3. ส่งข้อมูลครั้งเดียวเมื่อจบกระบวนการ
    if hasFound and _G.Horst_SetDescription then
        local outputSections = {}
        
        if next(GlobalResults.Units) then
            local list = {}
            for n, c in pairs(GlobalResults.Units) do table.insert(list, n) end
            table.insert(outputSections, "👤 Units : " .. table.concat(list, ", "))
        end
        
        if next(GlobalResults.Items) then
            local list = {}
            for n, c in pairs(GlobalResults.Items) do table.insert(list, n .. " " .. formatNumber(c)) end
            table.insert(outputSections, "🧰 Items : " .. table.concat(list, ", "))
        end
        
        if next(GlobalResults.Mounts) then
            local list = {}
            for n, c in pairs(GlobalResults.Mounts) do table.insert(list, n) end
            table.insert(outputSections, "🐅 Mounts : " .. table.concat(list, ", "))
        end
        
        local descriptionMessage = table.concat(outputSections, " / ")
        _G.Horst_SetDescription(descriptionMessage, HttpService:JSONEncode(GlobalResults))
        print("[Horst Scanner] ส่ง Log รวมสำเร็จ: " .. descriptionMessage)
        return true
    end
    return false
end

-- ลูปเริ่มทำงาน
task.spawn(function()
    while true do
        local success = runInventoryScan()
        task.wait(success and 10 or 2)
    end
end)
