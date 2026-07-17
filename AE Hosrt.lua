local players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local localPlayer = players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- =========================================================
-- 🛡️ [DYNAMIC CONFIG]
-- =========================================================
local config = _G.HorstInventoryConfig or {}
local targetUnitsWhitelist = config.Units or {}
local targetItemsWhitelist = config.Items or {}
local targetMountsWhitelist = config.Mounts or {}

-- =========================================================
-- 🛠️ Helpers
-- =========================================================
local function findScrollingFrame(currentObject)
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
        if string.lower(whitelistedName) == cleanName then 
            return whitelistedName 
        end
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
-- 🕵️‍♂️ GitHub Edition
-- =========================================================
local function tryComboScanAndSendLog()
    local unitsResult = {}
    local itemsResult = {}
    local mountsResult = {}
    local hasFoundSomething = false

    -- ---------------------------------------------------
    -- 👤 Units
    -- ---------------------------------------------------
    local unitInventory = playerGui:FindFirstChild("UnitInventory")
    if unitInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
        task.wait(1.0)

        local scrollingFrame = findScrollingFrame(unitInventory)
        if scrollingFrame then
            scrollingFrame.CanvasPosition = Vector2.new(0, scrollingFrame.AbsoluteCanvasSize.Y)
            task.wait(0.2)

            for _, slot in pairs(scrollingFrame:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    local foundTextLabels = {}
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then table.insert(foundTextLabels, child.Text) end
                    end

                    for _, currentText in pairs(foundTextLabels) do
                        if not string.find(currentText, "¥") and not string.find(currentText, "Lvl") and not string.find(currentText, "LVL") then
                            local cleanName = string.gsub(string.gsub(currentText, "|", ""), ";", "")
                            cleanName = string.match(cleanName, "^%s*(.-)%s*$")
                            
                            local matchedName = isInWhitelist(cleanName, targetUnitsWhitelist)
                            if matchedName then
                                unitsResult[matchedName] = (unitsResult[matchedName] or 0) + 1
                                hasFoundSomething = true
                                break
                            end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
    end

    task.wait(0.5)

    -- ---------------------------------------------------
    -- 🧰 & 🐅 Items & Mounts
    -- ---------------------------------------------------
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
        task.wait(1.0)

        local scrollingFrame = findScrollingFrame(itemInventory)
        
        local function scanTab(isMountsTab)
            if not scrollingFrame then return end
            for _, slot in pairs(scrollingFrame:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    local itemName, itemCount = nil, 1
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            local text = child.Text
                            if string.find(text, "x") or string.find(text, "X") then
                                local cleanAmount = string.gsub(string.gsub(string.lower(text), "x", ""), ",", "")
                                itemCount = tonumber(cleanAmount) or 1
                            else
                                local cleanName = string.gsub(string.gsub(text, "|", ""), ";", "")
                                cleanName = string.match(cleanName, "^%s*(.-)%s*$")
                                if cleanName and cleanName ~= "" and not string.find(cleanName, "Lvl") then itemName = cleanName end
                            end
                        end
                    end
                    
                    if itemName then
                        if isMountsTab then
                            local matchedName = isInWhitelist(itemName, targetMountsWhitelist)
                            if matchedName then
                                mountsResult[matchedName] = (mountsResult[matchedName] or 0) + itemCount
                                hasFoundSomething = true
                            end
                        else
                            local matchedName = isInWhitelist(itemName, targetItemsWhitelist)
                            if matchedName then
                                itemsResult[matchedName] = (itemsResult[matchedName] or 0) + itemCount
                                hasFoundSomething = true
                            end
                        end
                    end
                end
            end
        end

        scanTab(false)

        pcall(function()
            local tabContainer = itemInventory.Frame.Frame.Frame.Frame.Frame
            local mountsButton = nil
            
            for _, child in pairs(tabContainer:GetChildren()) do
                if child:FindFirstChild("PrimaryButton") then
                    local label = child:FindFirstChildOfClass("TextLabel") or child:FindFirstChild("Text", true)
                    if label and string.find(string.lower(label.Text), "mounts") then
                        mountsButton = child.PrimaryButton
                        break
                    end
                end
            end
            
            if not mountsButton and tabContainer:GetChildren()[5] then
                local backupObj = tabContainer:GetChildren()[5]
                mountsButton = backupObj:FindFirstChild("PrimaryButton") or backupObj
            end
            
            if mountsButton then
                if getconnections then
                    for _, connection in pairs(getconnections(mountsButton.MouseButton1Click)) do
                        connection:Fire()
                    end
                end
                local x = mountsButton.AbsolutePosition.X + (mountsButton.AbsoluteSize.X / 2)
                local y = mountsButton.AbsolutePosition.Y + (mountsButton.AbsoluteSize.Y / 2) + 60
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
            end
        end)
        
        task.wait(1.0)
        scanTab(true)

        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
    end

    -- ---------------------------------------------------
    -- 📊 Whitelist
    -- ---------------------------------------------------
    if hasFoundSomething then
        local outputSections = {}

        -- 👤Units
        local unitsList = {}
        for _, name in ipairs(targetUnitsWhitelist) do
            if unitsResult[name] then table.insert(unitsList, name) end
        end
        if #unitsList > 0 then
            table.insert(outputSections, "👤Units : " .. table.concat(unitsList, ", "))
        end

        -- 🧰Items
        local itemsList = {}
        for _, name in ipairs(targetItemsWhitelist) do
            if itemsResult[name] then
                table.insert(itemsList, string.format("%s %s", name, formatNumber(itemsResult[name])))
            end
        end
        if #itemsList > 0 then
            table.insert(outputSections, "🧰Items : " .. table.concat(itemsList, ", "))
        end

        -- 🐅Mounts
        local mountsList = {}
        for _, name in ipairs(targetMountsWhitelist) do
            if mountsResult[name] then table.insert(mountsList, name) end
        end
        if #mountsList > 0 then
            table.insert(outputSections, "🐅Mounts : " .. table.concat(mountsList, ", "))
        end

        local descriptionMessage = table.concat(outputSections, " / ")
        print("[GitHub Script] ส่งข้อมูลสำเร็จ: " .. descriptionMessage)

        local finalJsonTable = { Units = unitsResult, Items = itemsResult, Mounts = mountsResult }
        local encodeJson = HttpService:JSONEncode(finalJsonTable)

        if _G.Horst_SetDescription then
            _G.Horst_SetDescription(descriptionMessage, encodeJson)
            print("[GitHub Script] ส่ง Log เข้า Horst เรียบร้อย!")
            return true
        else
            warn("[GitHub Script] ไม่พบฟังก์ชัน _G.Horst_SetDescription")
            return false
        end
    else
        print("[GitHub Script] ไม่พบของในตู้... กำลังรอวนเช็คใหม่")
        return false
    end
end

task.spawn(function()
    print("[GitHub Script] โหลดสคริปต์หลักสำเร็จ... เริ่มทำงานระบบวนลูปตรวจสอบ")
    while true do
        local success = tryComboScanAndSendLog()
        if success then break end
        task.wait(5)
    end
end)
