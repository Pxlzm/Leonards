-- 🕵️‍♂️ ฟังก์ชันสแกนแบบลำดับ (Sequential) - ปรับปรุงใหม่
local function runInventoryScanOnce()
    local results = {Units = {}, Items = {}, Mounts = {}}
    local hasFoundAny = false
    
    -- 1. สแกน Units
    local unitInventory = playerGui:FindFirstChild("UnitInventory")
    if unitInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
        task.wait(1.5)
        local frame = findScrollingFrame(unitInventory)
        if frame then
            frame.CanvasPosition = Vector2.new(0, frame.AbsoluteCanvasSize.Y)
            task.wait(1)
            for _, slot in pairs(frame:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" and not string.find(string.lower(child.Text), "lvl") then
                            local matched = isInWhitelist(child.Text, targetUnitsWhitelist)
                            if matched then results.Units[matched] = (results.Units[matched] or 0) + 1; hasFoundAny = true end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game) -- ปิด Units
        task.wait(1.5)
    end

    -- 2. สแกน Items และ Mounts
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game) -- เปิด Items
        task.wait(1.5)
        local frame = findScrollingFrame(itemInventory)
        
        -- สแกน Items
        if frame then
            for _, slot in pairs(frame:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    local name, count = nil, 1
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            if string.find(string.lower(child.Text), "x") then count = safeToNumber(child.Text)
                            elseif not string.find(string.lower(child.Text), "lvl") then name = child.Text end
                        end
                    end
                    if name then
                        local matched = isInWhitelist(name, targetItemsWhitelist)
                        if matched then results.Items[matched] = (results.Items[matched] or 0) + count; hasFoundAny = true end
                    end
                end
            end
        end

        -- สลับ Mounts (วิธีค้นหาจาก TextLabel ที่เป็น "Mounts" โดยตรง)
        local foundMountsTab = false
        for _, obj in pairs(itemInventory:GetDescendants()) do
            if obj:IsA("TextLabel") and string.lower(obj.Text) == "mounts" then
                -- ลองกดปุ่มที่อยู่ใกล้ๆ Label นี้
                local btn = obj.Parent:FindFirstChildWhichIsA("TextButton") or obj.Parent.Parent:FindFirstChildWhichIsA("TextButton")
                if btn then
                    btn.MouseButton1Click:Fire()
                    foundMountsTab = true
                    break
                end
            end
        end
        
        task.wait(2) -- รอให้หน้า Mounts โหลดเสร็จ
        
        -- สแกน Mounts (ใช้ frame เดิม)
        if frame then
            for _, slot in pairs(frame:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            local matched = isInWhitelist(child.Text, targetMountsWhitelist)
                            if matched then results.Mounts[matched] = (results.Mounts[matched] or 0) + 1; hasFoundAny = true end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game) -- ปิดหน้าต่าง J
    end

    -- 3. ส่งข้อมูล
    if hasFoundAny and _G.Horst_SetDescription then
        local outputSections = {}
        if next(results.Units) then
            local list = {}
            for n, c in pairs(results.Units) do table.insert(list, n) end
            table.insert(outputSections, "👤 Units : " .. table.concat(list, ", "))
        end
        if next(results.Items) then
            local list = {}
            for n, c in pairs(results.Items) do table.insert(list, n .. " " .. formatNumber(c)) end
            table.insert(outputSections, "🧰 Items : " .. table.concat(list, ", "))
        end
        if next(results.Mounts) then
            local list = {}
            for n, c in pairs(results.Mounts) do table.insert(list, n) end
            table.insert(outputSections, "🐅 Mounts : " .. table.concat(list, ", "))
        end
        
        local finalMsg = table.concat(outputSections, " / ")
        _G.Horst_SetDescription(finalMsg, HttpService:JSONEncode(results))
        print("[Horst Scanner] ส่ง Log สำเร็จ!")
    end
end

runInventoryScanOnce()
