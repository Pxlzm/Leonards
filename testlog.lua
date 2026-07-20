local players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

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

local function tryComboScanAndSendLog()
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
        local scrollingFrame = findScrollingFrame(itemInventory)
        
        local function scanTab(isMounts)
            if not scrollingFrame then return end
            for _, slot in pairs(scrollingFrame:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    local name, count = nil, 1
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            if string.find(string.lower(child.Text), "x") then count = tonumber((string.gsub(string.lower(child.Text), "x", ""))) or 1
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
        pcall(function()
            local tabContainer = itemInventory.Frame.Frame.Frame.Frame.Frame
            for _, c in pairs(tabContainer:GetChildren()) do
                local l = c:FindFirstChildOfClass("TextLabel") or c:FindFirstChild("Text", true)
                if l and string.find(string.lower(l.Text), "mounts") then
                    local btn = c:FindFirstChild("PrimaryButton", true)
                    if btn then
                        local x, y = btn.AbsolutePosition.X + btn.AbsoluteSize.X/2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y/2 + 60
                        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1); task.wait(0.1); VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
                        break
                    end
                end
            end
        end)
        task.wait(3.0); scanTab(true)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game); task.wait(0.5); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
    end

    -- 📊 สรุปผลและส่ง Log
    local outputSections = {}
    for _, n in ipairs(targetUnitsWhitelist) do if unitsResult[n] then table.insert(outputSections, "👤Units : " .. n) end end
    for _, n in ipairs(targetItemsWhitelist) do if itemsResult[n] then table.insert(outputSections, "🧰Items : " .. n .. " " .. formatNumber(itemsResult[n])) end end
    for _, n in ipairs(targetMountsWhitelist) do if mountsResult[n] then table.insert(outputSections, "🐅Mounts : " .. n) end end
    
    local msg = table.concat(outputSections, " / ")
    if _G.Horst_SetDescription then
        _G.Horst_SetDescription(msg, HttpService:JSONEncode({Units=unitsResult, Items=itemsResult, Mounts=mountsResult}))
        print("[Log Sent]: " .. msg)
    end
    
    task.wait(5.0)
    return true
end

task.spawn(function() while true do tryComboScanAndSendLog() end end)
