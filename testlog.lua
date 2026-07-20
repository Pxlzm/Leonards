local players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local localPlayer = players.LocalPlayer

-- =========================================================
-- 🛠️ ฟังก์ชันช่วยเหลือ (Helpers)
-- =========================================================
local function findScrollingFrame(currentObject)
    if not currentObject then return nil end
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

-- =========================================================
-- 🕵️‍♂️ ฟังก์ชันหลัก (แก้ไขระบบกดปุ่ม Mounts)
-- =========================================================
local function tryComboScanAndSendLog()
    local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local itemsResult, mountsResult = {}, {}, {}
    local hasFoundSomething = false
    local config = _G.HorstInventoryConfig or {}

    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        -- เปิด Inventory
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
        task.wait(1.5)

        local baseFrame = itemInventory.Frame.Frame.Frame.Frame.Frame

        -- 🔍 ระบบหาปุ่ม Mounts อัตโนมัติ (ไม่ใช้เลข 5 แล้ว)
        local btnMounts = nil
        for _, tab in pairs(baseFrame:GetChildren()) do
            -- ลองหา Label ที่มีคำว่า Mounts ข้างในปุ่มหรือกล่องปุ่มนั้น
            local label = tab:FindFirstChild("TextLabel", true) or tab:FindFirstChild("Label", true) or tab:FindFirstChild("Text", true)
            if label and string.find(string.lower(label.Text), "mounts") then
                -- ถ้าเจอ Label แล้ว ให้ดึง Path ต่อไปตามที่คุณบอก
                btnMounts = tab:FindFirstChild("Folder") and tab.Folder.Frame.Frame
                if btnMounts then break end
            end
        end

        local function click(btn)
            if not btn then return end
            local x = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
            local y = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1); task.wait(0.2); VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end

        local function scanTab(isMounts)
            local sf = findScrollingFrame(itemInventory)
            if not sf then return end
            for _, slot in pairs(sf:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
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
                        local list = isMounts and (config.Mounts or {}) or (config.Items or {})
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

        -- 1. สแกน Items
        scanTab(false)

        -- 2. สลับแท็บ Mounts (ถ้าหาปุ่มเจอ)
        if btnMounts then
            click(btnMounts)
        else
            warn("[Warning] หาปุ่ม Mounts ไม่เจอ! ตรวจสอบว่าในเกมมีแท็บชื่อ Mounts หรือไม่")
        end
        task.wait(1.5)
        
        -- 3. สแกน Mounts
        scanTab(true)

        -- ปิด Inventory
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.5); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
    end

    -- ส่ง Log
    if hasFoundSomething and _G.Horst_SetDescription then
        local logMsg = {}
        for _, n in ipairs(config.Items or {}) do if itemsResult[n] then table.insert(logMsg, "🧰Items : " .. n .. " " .. itemsResult[n]) end end
        for _, n in ipairs(config.Mounts or {}) do if mountsResult[n] then table.insert(logMsg, "🐅Mounts : " .. n) end end
        _G.Horst_SetDescription(table.concat(logMsg, " / "), HttpService:JSONEncode({Items=itemsResult, Mounts=mountsResult}))
    end
end

-- ลูปทำงาน
task.spawn(function()
    while true do
        tryComboScanAndSendLog()
        task.wait(5)
    end
end)
