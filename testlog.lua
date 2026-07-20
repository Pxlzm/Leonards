-- =========================================================
-- 🕵️‍♂️ ฟังก์ชันหลักการสแกนและจัดหมวดหมู่ (V10 GitHub Edition - Optimized)
-- =========================================================
local function tryComboScanAndSendLog()
    local unitsResult = {}
    local itemsResult = {}
    local mountsResult = {}
    local hasFoundSomething = false

    -- ---------------------------------------------------
    -- 👤 พาร์ท 1: สแกน Units (ปุ่ม H)
    -- ---------------------------------------------------
    local unitInventory = playerGui:FindFirstChild("UnitInventory")
    if unitInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
        task.wait(3.0) -- ปรับเป็น 3 วิ

        local scrollingFrame = findScrollingFrame(unitInventory)
        if scrollingFrame then
            scrollingFrame.CanvasPosition = Vector2.new(0, scrollingFrame.AbsoluteCanvasSize.Y)
            task.wait(3.0) -- ปรับเป็น 3 วิ

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

    task.wait(1.0)

    -- ---------------------------------------------------
    -- 🧰 & 🐅 พาร์ท 2: สแกน Items & Mounts (ปุ่ม J)
    -- ---------------------------------------------------
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
        task.wait(3.0) -- ปรับเป็น 3 วิ

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
                        local matchedName = isInWhitelist(itemName, isMountsTab and targetMountsWhitelist or targetItemsWhitelist)
                        if matchedName then
                            if isMountsTab then mountsResult[matchedName] = (mountsResult[matchedName] or 0) + itemCount
                            else itemsResult[matchedName] = (itemsResult[matchedName] or 0) + itemCount end
                            hasFoundSomething = true
                        end
                    end
                end
            end
        end

        scanTab(false) -- สแกน Items
        
        -- เปลี่ยนแท็บ Mounts
        pcall(function()
            local tabContainer = itemInventory.Frame.Frame.Frame.Frame.Frame
            local mountsButton = nil
            for _, child in pairs(tabContainer:GetChildren()) do
                if child:FindFirstChild("PrimaryButton") then
                    local label = child:FindFirstChildOfClass("TextLabel") or child:FindFirstChild("Text", true)
                    if label and string.find(string.lower(label.Text), "mounts") then mountsButton = child.PrimaryButton break end
                end
            end
            if mountsButton then
                if getconnections then for _, c in pairs(getconnections(mountsButton.MouseButton1Click)) do c:Fire() end end
                local x = mountsButton.AbsolutePosition.X + (mountsButton.AbsoluteSize.X / 2)
                local y = mountsButton.AbsolutePosition.Y + (mountsButton.AbsoluteSize.Y / 2) + 60
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                task.wait(0.1)
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
            end
        end)
        
        task.wait(3.0) -- ปรับเป็น 3 วิ
        scanTab(true) -- สแกน Mounts

        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
    end

    -- ส่ง Log
    if hasFoundSomething and _G.Horst_SetDescription then
        -- (Logic การรวมข้อความของคุณคงเดิม)
        -- ... [ใส่ชุดส่ง Log ของคุณตรงนี้] ...
        _G.Horst_SetDescription(descriptionMessage, encodeJson)
        print("[Log Sent] Success. Waiting 5s for next cycle.")
        task.wait(5.0) -- Delay หลังส่ง Log
    else
        print("[Log] No items found, waiting 5s.")
        task.wait(5.0)
    end
    return true
end

-- ลูปทำงานอัตโนมัติ (วนลูปไม่หยุด)
task.spawn(function()
    while true do
        tryComboScanAndSendLog()
    end
end)
