local players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local localPlayer = players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

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
-- 🕵️‍♂️ ฟังก์ชันหลักที่แก้ไขแล้ว (ไม่หยุดทำงานกลางคัน)
-- =========================================================
local function tryComboScanAndSendLog()
    local config = _G.HorstInventoryConfig or {}
    local targetUnitsWhitelist = config.Units or {}
    local targetItemsWhitelist = config.Items or {}
    local targetMountsWhitelist = config.Mounts or {}

    local unitsResult, itemsResult, mountsResult = {}, {}, {}
    local hasFoundSomething = false

    -- 1. สแกน Units
    local unitInventory = playerGui:FindFirstChild("UnitInventory")
    if unitInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
        task.wait(1.5)
        local sf = findScrollingFrame(unitInventory)
        if sf then
            sf.CanvasPosition = Vector2.new(0, sf.AbsoluteCanvasSize.Y); task.wait(1)
            for _, slot in pairs(sf:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" and not string.find(child.Text, "Lvl") then
                            local matched = isInWhitelist(child.Text, targetUnitsWhitelist)
                            if matched then unitsResult[matched] = (unitsResult[matched] or 0) + 1; hasFoundSomething = true end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
    end

    -- 2. สแกน Items และ Mounts (รวมกันในลูปเดียว)
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
        task.wait(1.5)

        local function runScan(isMounts)
            local sf = findScrollingFrame(itemInventory)
            if not sf then return end
            for _, slot in pairs(sf:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    local name, count = nil, 1
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            local text = child.Text
                            if string.find(string.lower(text), "x") then
                                count = tonumber((string.gsub(string.gsub(string.lower(text), "x", ""), ",", ""))) or 1
                            elseif not string.find(text, "Lvl") then
                                name = string.match(string.gsub(string.gsub(text, "|", ""), ";", ""), "^%s*(.-)%s*$")
                            end
                        end
                    end
                    if name then
                        local list = isMounts and targetMountsWhitelist or targetItemsWhitelist
                        local match = isInWhitelist(name, list)
                        if match then
                            if isMounts then mountsResult[match] = (mountsResult[match] or 0) + 1
                            else itemsResult[match] = (itemsResult[match] or 0) + count end
                            hasFoundSomething = true
                        end
                    end
                end
            end
        end

        runScan(false) -- สแกน Items หน้าแรก

        -- สลับหน้าไป Mounts
        pcall(function()
            for _, obj in pairs(itemInventory:GetDescendants()) do
                if obj:IsA("TextLabel") and string.find(string.lower(obj.Text), "mounts") then
                    local btn = obj:FindFirstAncestorOfClass("TextButton") or obj:FindFirstAncestorOfClass("ImageButton")
                    if btn then
                        local x, y = btn.AbsolutePosition.X + btn.AbsoluteSize.X/2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y/2
                        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1); task.wait(0.2); VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
                        break
                    end
                end
            end
        end)
        task.wait(2)
        runScan(true) -- สแกน Mounts หน้าสอง
        
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
    end

    -- 3. สรุป Log (เช็คทุกครั้งไม่ว่าจะเจออะไรหรือไม่ เพื่อให้มันทำงานตลอด)
    if _G.Horst_SetDescription then
        local sections = {}
        for _, n in ipairs(targetUnitsWhitelist) do if unitsResult[n] then table.insert(sections, "👤Units : " .. n) end end
        for _, n in ipairs(targetItemsWhitelist) do if itemsResult[n] then table.insert(sections, "🧰Items : " .. n .. " " .. formatNumber(itemsResult[n])) end end
        for _, n in ipairs(targetMountsWhitelist) do if mountsResult[n] then table.insert(sections, "🐅Mounts : " .. n) end end
        
        _G.Horst_SetDescription(table.concat(sections, " / "), HttpService:JSONEncode({Units=unitsResult, Items=itemsResult, Mounts=mountsResult}))
        print("[Log Sent] " .. (hasFoundSomething and "Found items" or "Empty inventory"))
    end
    return false -- ไม่ต้องใส่ true เพื่อไม่ให้ break ลูป
end

task.spawn(function()
    while true do
        tryComboScanAndSendLog()
        task.wait(5) -- เว้นระยะก่อนเริ่มลูปใหม่
    end
end)
