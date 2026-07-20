local players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local localPlayer = players.LocalPlayer

-- =========================================================
-- 🛡️ [DYNAMIC CONFIG] ดึงค่าจาก _G
-- =========================================================
local config = _G.HorstInventoryConfig or {}
local targetUnitsWhitelist = config.Units or {}
local targetItemsWhitelist = config.Items or {}
local targetMountsWhitelist = config.Mounts or {}

-- =========================================================
-- 🛠️ ฟังก์ชันช่วยเหลือ (Helpers)
-- =========================================================
local function findScrollingFrame(currentObject)
    if not currentObject then return nil end
    if currentObject:IsA("ScrollingFrame") and currentObject.Name == "ScrollingFrame" then
        return currentObject
    end
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

local function formatNumber(amount)
    local formatted = tostring(amount)
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- =========================================================
-- 🕵️‍♂️ ฟังก์ชันหลัก (Main Scan Logic)
-- =========================================================
local function tryComboScanAndSendLog()
    local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local unitsResult, itemsResult, mountsResult = {}, {}, {}
    local hasFoundSomething = false

    -- 1. สแกน Units
    local unitInventory = playerGui:FindFirstChild("UnitInventory")
    if unitInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
        task.wait(1.5)
        local scrollingFrame = findScrollingFrame(unitInventory)
        if scrollingFrame then
            scrollingFrame.CanvasPosition = Vector2.new(0, scrollingFrame.AbsoluteCanvasSize.Y)
            task.wait(0.5)
            for _, slot in pairs(scrollingFrame:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" and not string.find(child.Text, "Lvl") then
                            local cleanName = string.match(string.gsub(string.gsub(child.Text, "|", ""), ";", ""), "^%s*(.-)%s*$")
                            local matched = isInWhitelist(cleanName, targetUnitsWhitelist)
                            if matched then unitsResult[matched] = (unitsResult[matched] or 0) + 1; hasFoundSomething = true; break end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game); task.wait(0.5); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
    end

    task.wait(0.5)

    -- 2. สแกน Items & Mounts
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
        task.wait(1.5)
        
        local function scanInventoryTab(isMounts)
            local sf = findScrollingFrame(itemInventory)
            if not sf then return end
            for _, slot in pairs(sf:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    local itemName, itemCount = nil, 1
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            if string.find(string.lower(child.Text), "x") then
                                itemCount = tonumber((string.gsub(string.gsub(string.lower(child.Text), "x", ""), ",", ""))) or 1
                            elseif not string.find(child.Text, "Lvl") then
                                itemName = string.match(string.gsub(string.gsub(child.Text, "|", ""), ";", ""), "^%s*(.-)%s*$")
                            end
                        end
                    end
                    if itemName then
                        local list = isMounts and targetMountsWhitelist or targetItemsWhitelist
                        local matched = isInWhitelist(itemName, list)
                        if matched then
                            if isMounts then mountsResult[matched] = (mountsResult[matched] or 0) + 1
                            else itemsResult[matched] = (itemsResult[matched] or 0) + itemCount end
                            hasFoundSomething = true
                        end
                    end
                end
            end
        end

        scanInventoryTab(false) -- Scan Items

        -- สลับ Tab Mounts
        pcall(function()
            local tabContainer = itemInventory.Frame.Frame.Frame.Frame.Frame
            for _, child in pairs(tabContainer:GetChildren()) do
                local label = child:FindFirstChildOfClass("TextLabel") or child:FindFirstChild("Text", true)
                if label and string.find(string.lower(label.Text), "mounts") then
                    local btn = child:FindFirstChild("PrimaryButton", true)
                    if btn then
                        local x, y = btn.AbsolutePosition.X + btn.AbsoluteSize.X/2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y/2 + 60
                        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1); task.wait(0.2); VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
                        break
                    end
                end
            end
        end)
        
        task.wait(1.5)
        scanInventoryTab(true) -- Scan Mounts
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.5); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
    end

    -- 3. ส่ง Log
    if hasFoundSomething and _G.Horst_SetDescription then
        local logMsg = {}
        for _, n in ipairs(targetUnitsWhitelist) do if unitsResult[n] then table.insert(logMsg, "👤Units : " .. n) end end
        for _, n in ipairs(targetItemsWhitelist) do if itemsResult[n] then table.insert(logMsg, "🧰Items : " .. n .. " " .. formatNumber(itemsResult[n])) end end
        for _, n in ipairs(targetMountsWhitelist) do if mountsResult[n] then table.insert(logMsg, "🐅Mounts : " .. n) end end
        _G.Horst_SetDescription(table.concat(logMsg, " / "), HttpService:JSONEncode({Units=unitsResult, Items=itemsResult, Mounts=mountsResult}))
    end
end

-- =========================================================
-- 🚀 เริ่มทำงานลูป
-- =========================================================
task.spawn(function()
    print("[System] สคริปต์ทำงานแล้ว")
    while true do
        tryComboScanAndSendLog()
        task.wait(5) -- เว้นระยะ 5 วินาทีก่อนเริ่มรอบใหม่
    end
end)
