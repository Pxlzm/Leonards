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
-- 🕵️‍♂️ ฟังก์ชันหลักการสแกน (Fixed Nil Index Error)
-- =========================================================
local function tryComboScanAndSendLog()
    -- ดึงค่าใหม่ทุกรอบเพื่อกัน Error Nil
    local localPlayer = players.LocalPlayer
    if not localPlayer then return false end
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end

    local config = _G.HorstInventoryConfig or {}
    local targetUnitsWhitelist = config.Units or {}
    local targetItemsWhitelist = config.Items or {}
    local targetMountsWhitelist = config.Mounts or {}

    local unitsResult, itemsResult, mountsResult = {}, {}, {}
    local hasFoundSomething = false

    -- 👤 สแกน Units
    local unitInventory = playerGui:FindFirstChild("UnitInventory")
    if unitInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
        task.wait(0.05); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
        task.wait(3.0)
        local scrollingFrame = findScrollingFrame(unitInventory)
        if scrollingFrame then
            scrollingFrame.CanvasPosition = Vector2.new(0, scrollingFrame.AbsoluteCanvasSize.Y)
            task.wait(3.0)
            for _, slot in pairs(scrollingFrame:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" and not string.find(child.Text, "Lvl") then
                            local matchedName = isInWhitelist(child.Text, targetUnitsWhitelist)
                            if matchedName then unitsResult[matchedName] = (unitsResult[matchedName] or 0) + 1; hasFoundSomething = true; break end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game); task.wait(0.5); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
    end

    -- 🧰 & 🐅 สแกน Items & Mounts
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(0.05); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
        task.wait(3.0)
        local scrollingFrame = findScrollingFrame(itemInventory)
        
        local function scanTab(isMounts)
            if not scrollingFrame then return end
            for _, slot in pairs(scrollingFrame:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    local name, count = nil, 1
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            if string.find(string.lower(child.Text), "x") then count = tonumber(string.gsub(string.lower(child.Text), "x", "")) or 1
                            elseif not string.find(child.Text, "Lvl") then name = child.Text end
                        end
                    end
                    if name then
                        local list = isMounts and targetMountsWhitelist or targetItemsWhitelist
                        local match = isInWhitelist(name, list)
                        if match then
                            if isMounts then mountsResult[match] = (mountsResult[match] or 0) + 1 else itemsResult[match] = (itemsResult[match] or 0) + count end
                            hasFoundSomething = true
                        end
                    end
                end
            end
        end

        scanTab(false)
        -- สลับ Tab Mounts
        pcall(function()
            local tabContainer = itemInventory.Frame.Frame.Frame.Frame.Frame
            local btn = nil
            for _, c in pairs(tabContainer:GetChildren()) do
                local l = c:FindFirstChildOfClass("TextLabel") or c:FindFirstChild("Text", true)
                if l and string.find(string.lower(l.Text), "mounts") then btn = c:FindFirstChild("PrimaryButton", true) break end
            end
            if btn then
                local x, y = btn.AbsolutePosition.X + btn.AbsoluteSize.X/2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y/2 + 60
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1); task.wait(0.1); VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
            end
        end)
        task.wait(3.0); scanTab(true)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.5); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
    end

    -- ส่ง Log
    if hasFoundSomething and _G.Horst_SetDescription then
        local msg = "" -- (รวมข้อความของคุณ)
        _G.Horst_SetDescription(msg, HttpService:JSONEncode({Units=unitsResult, Items=itemsResult, Mounts=mountsResult}))
        print("[Log Sent]")
        task.wait(5.0)
    else
        task.wait(5.0)
    end
    return true
end

task.spawn(function() while true do tryComboScanAndSendLog() end end)
