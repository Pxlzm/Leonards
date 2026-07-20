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
-- 🕵️‍♂️ ฟังก์ชันหลัก (เน้น Path Mounts โดยเฉพาะ)
-- =========================================================
local function tryComboScanAndSendLog()
    local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local itemsResult, mountsResult = {}, {}, {}
    local hasFoundSomething = false
    local config = _G.HorstInventoryConfig or {}

    -- 1. เปิด Inventory
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
        task.wait(1.5)

        -- กำหนด Path Mounts เฉพาะเจาะจง
        local baseFrame = itemInventory.Frame.Frame.Frame.Frame.Frame
        local btnMounts = baseFrame:GetChildren()[5].Folder.Frame.Frame

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

        -- A. สแกน Items (แท็บที่ถูกเลือกอัตโนมัติ)
        scanTab(false)

        -- B. สลับแท็บ Mounts ด้วย Path ที่ระบุ
        pcall(function() click(btnMounts) end)
        task.wait(1.5)
        
        -- C. สแกน Mounts
        scanTab(true)

        -- ปิด Inventory
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.5); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
    end

    -- 2. ส่ง Log
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
