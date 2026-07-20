local players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- =========================================================
-- 🛠️ ฟังก์ชันช่วยเหลือ (Helpers)
-- =========================================================
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

local function formatNumber(amount)
    local formatted = tostring(amount)
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- =========================================================
-- 🕵️‍♂️ ฟังก์ชันหลักที่แก้ไขให้ทำงานลื่นไหล
-- =========================================================
local function tryComboScanAndSendLog()
    local localPlayer = players.LocalPlayer
    if not localPlayer then return end
    local playerGui = localPlayer:WaitForChild("PlayerGui", 5)
    if not playerGui then return end

    local config = _G.HorstInventoryConfig or {}
    local targetUnitsWhitelist = config.Units or {}
    local targetItemsWhitelist = config.Items or {}
    local targetMountsWhitelist = config.Mounts or {}

    local unitsResult, itemsResult, mountsResult = {}, {}, {}
    local hasFoundSomething = false

    -- 👤 พาร์ท 1: สแกน Units
    local unitInventory = playerGui:FindFirstChild("UnitInventory")
    if unitInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game); task.wait(0.05); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
        task.wait(3.0)
        local scrollingFrame = findScrollingFrame(unitInventory)
        if scrollingFrame then
            scrollingFrame.CanvasPosition = Vector2.new(0, scrollingFrame.AbsoluteCanvasSize.Y); task.wait(3.0)
            for _, slot in pairs(scrollingFrame:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" and not string.find(child.Text, "Lvl") then
                            local matched = isInWhitelist(child.Text, targetUnitsWhitelist)
                            if matched then unitsResult[matched] = (unitsResult[matched] or 0) + 1; hasFoundSomething = true; break end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game); task.wait(0.5); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
    end

    -- 🧰 & 🐅 พาร์ท 2: สแกน Items & Mounts
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.05); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
        task.wait(3.0)
        
        local function scanTab(isMountsTab)
            local scrollingFrame = findScrollingFrame(itemInventory)
            if not scrollingFrame then return end
            for _, slot in pairs(scrollingFrame:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    local itemName, itemCount = nil, 1
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            local text = child.Text
                            if string.find(string.lower(text), "x") then
                                itemCount = tonumber((string.gsub(string.gsub(string.lower(text), "x", ""), ",", ""))) or 1
                            elseif not string.find(text, "Lvl") then
                                local cleanName = string.match(string.gsub(string.gsub(text, "|", ""), ";", ""), "^%s*(.-)%s*$")
                                if cleanName and cleanName ~= "" then itemName = cleanName end
                            end
                        end
                    end
                    if itemName then
                        local list = isMountsTab and targetMountsWhitelist or targetItemsWhitelist
                        local matchedName = isInWhitelist(itemName, list)
                        if matchedName then
                            if isMountsTab then mountsResult[matchedName] = (mountsResult[matchedName] or 0) + 1
                            else itemsResult[matchedName] = (itemsResult[matchedName] or 0) + itemCount end
                            hasFoundSomething = true
                        end
                    end
                end
            end
        end

        scanTab(false) -- สแกน Items
        
        -- เปลี่ยนแท็บ Mounts ด้วยวิธีค้นหาที่ยืดหยุ่นขึ้น
        pcall(function()
            local found = false
            -- สแกนหา Object ทุกตัวที่มี Text ว่า "mounts"
            for _, obj in pairs(itemInventory:GetDescendants()) do
                if obj:IsA("TextLabel") and string.find(string.lower(obj.Text), "mounts") then
                    local btn = obj:FindFirstAncestorOfClass("TextButton") or obj:FindFirstAncestorOfClass("ImageButton")
                    if btn then
                        local x, y = btn.AbsolutePosition.X + btn.AbsoluteSize.X/2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y/2
                        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1); task.wait(0.2); VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
                        found = true; break
                    end
                end
            end
            if not found then warn("[Scan] ไม่พบปุ่ม Mounts!") end
        end)
        
        task.wait(3.0); scanTab(true) -- สแกน Mounts
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.5); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
    end

    -- 📊 สรุปผลและส่ง Log
    if hasFoundSomething and _G.Horst_SetDescription then
        local outputSections = {}
        for _, n in ipairs(targetUnitsWhitelist) do if unitsResult[n] then table.insert(outputSections, "👤Units : " .. n) end end
        for _, n in ipairs(targetItemsWhitelist) do if itemsResult[n] then table.insert(outputSections, "🧰Items : " .. n .. " " .. formatNumber(itemsResult[n])) end end
        for _, n in ipairs(targetMountsWhitelist) do if mountsResult[n] then table.insert(outputSections, "🐅Mounts : " .. n) end end
        
        _G.Horst_SetDescription(table.concat(outputSections, " / "), HttpService:JSONEncode({Units=unitsResult, Items=itemsResult, Mounts=mountsResult}))
        print("[Log Sent]")
    end
    task.wait(5.0)
end

task.spawn(function() while true do tryComboScanAndSendLog() end end)
