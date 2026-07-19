-- 1. ส่วนเริ่มต้น - ใช้การรอที่ปลอดภัยขึ้น
if not game:IsLoaded() then game.Loaded:Wait() end
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer or players:GetPropertyChangedSignal("LocalPlayer"):Wait() or players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui", 10)

if not playerGui then warn("[Horst] หา PlayerGui ไม่พบ") return end

local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- (ส่วน Helper Functions คงเดิมที่เคยมี)

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
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
        task.wait(1.5)
    end

    -- 2. สแกน Items และ Mounts
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(1.5)
        local frame = findScrollingFrame(itemInventory)
        
        -- สแกน Items (หน้าแรก)
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

        -- สลับ Tab Mounts (Safe Method)
        local success = pcall(function()
            local found = false
            for _, obj in pairs(itemInventory:GetDescendants()) do
                if obj:IsA("TextLabel") and string.lower(obj.Text) == "mounts" then
                    -- สั่งคลิกที่ปุ่มแม่ (Parent หรือ Parent ของ Parent)
                    local btn = obj.Parent:FindFirstChildWhichIsA("TextButton") or obj.Parent.Parent:FindFirstChildWhichIsA("TextButton")
                    if btn then 
                        btn.MouseButton1Click:Fire()
                        found = true
                        break 
                    end
                end
            end
            return found
        end)
        
        task.wait(2)
        
        -- สแกน Mounts
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
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
    end

    -- 3. ส่งข้อมูล
    if hasFoundAny and _G.Horst_SetDescription then
        -- (ส่วนการจัดข้อความส่ง Log คงเดิม)
        -- ...
        print("[Horst Scanner] ส่ง Log สำเร็จ!")
    end
end
runInventoryScanOnce()
