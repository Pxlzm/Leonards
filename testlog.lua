local function tryComboScanAndSendLog()
    local localPlayer = players.LocalPlayer
    if not localPlayer then return end
    local playerGui = localPlayer:WaitForChild("PlayerGui", 5)
    if not playerGui then return end

    local unitsResult, itemsResult, mountsResult = {}, {}, {}
    local hasFoundSomething = false

    -- 👤 พาร์ท 1: สแกน Units (ปุ่ม H)
    local unitInventory = playerGui:FindFirstChild("UnitInventory")
    if unitInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
        task.wait(3.0) 

        local scrollingFrame = findScrollingFrame(unitInventory)
        if scrollingFrame then
            scrollingFrame.CanvasPosition = Vector2.new(0, scrollingFrame.AbsoluteCanvasSize.Y)
            task.wait(3.0)

            for _, slot in pairs(scrollingFrame:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    local foundTextLabels = {}
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then table.insert(foundTextLabels, child.Text) end
                    end

                    for _, currentText in pairs(foundTextLabels) do
                        if not string.find(currentText, "¥") and not string.find(currentText, "Lvl") and not string.find(currentText, "LVL") then
                            local cleanName = string.match(string.gsub(string.gsub(currentText, "|", ""), ";", ""), "^%s*(.-)%s*$")
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
        task.wait(1.0)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.H, false, game)
    end

    task.wait(0.5)

    -- 🧰 & 🐅 พาร์ท 2: สแกน Items & Mounts (ปุ่ม J)
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
        task.wait(3.0)

        local scrollingFrame = findScrollingFrame(itemInventory)
        local function scanTab(isMountsTab)
            if not scrollingFrame then return end
            for _, slot in pairs(scrollingFrame:GetChildren()) do
                if slot:IsA("TextButton") or slot:IsA("ImageButton") then
                    local itemName, itemCount = nil, 1
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            if string.find(string.lower(child.Text), "x") then itemCount = tonumber(string.gsub(string.lower(child.Text), "x", "")) or 1
                            elseif not string.find(child.Text, "Lvl") then itemName = string.match(string.gsub(string.gsub(child.Text, "|", ""), ";", ""), "^%s*(.-)%s*$") end
                        end
                    end
                    if itemName then
                        local matched = isInWhitelist(itemName, isMountsTab and targetMountsWhitelist or targetItemsWhitelist)
                        if matched then
                            if isMountsTab then mountsResult[matched] = (mountsResult[matched] or 0) + 1
                            else itemsResult[matched] = (itemsResult[matched] or 0) + itemCount end
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
                        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                        task.wait(0.1)
                        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
                        break
                    end
                end
            end
        end)
        task.wait(3.0)
        scanTab(true)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
    end

    -- ส่ง Log
    if hasFoundSomething and _G.Horst_SetDescription then
        local outputSections = {}
        for _, n in ipairs(targetUnitsWhitelist) do if unitsResult[n] then table.insert(outputSections, "👤Units : " .. n) end end
        for _, n in ipairs(targetItemsWhitelist) do if itemsResult[n] then table.insert(outputSections, "🧰Items : " .. n .. " " .. formatNumber(itemsResult[n])) end end
        for _, n in ipairs(targetMountsWhitelist) do if mountsResult[n] then table.insert(outputSections, "🐅Mounts : " .. n) end end
        
        local msg = table.concat(outputSections, " / ")
        _G.Horst_SetDescription(msg, HttpService:JSONEncode({Units=unitsResult, Items=itemsResult, Mounts=mountsResult}))
        print("[Log Sent] Success. Waiting 5s...")
        task.wait(5.0)
    else
        task.wait(5.0)
    end
end
