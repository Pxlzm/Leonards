local players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local localPlayer = players.LocalPlayer

-- =========================================================
-- 🛠️ ฟังก์ชันคลิกปุ่ม (ระบุ Path ตรง)
-- =========================================================
local function clickButton(btn)
    if not btn then return end
    local x = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
    local y = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
end

-- =========================================================
-- 🕵️‍♂️ ฟังก์ชันหลัก (Main Scan Logic)
-- =========================================================
local function tryComboScanAndSendLog()
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    local itemInventory = playerGui and playerGui:FindFirstChild("ItemInventory")
    if not itemInventory then return end

    -- อ้างอิง Path ที่คุณให้มา
    local baseFrame = itemInventory.Frame.Frame.Frame.Frame.Frame
    local btnItems = baseFrame.PrimaryButton.Folder.Frame.Frame
    local btnMounts = baseFrame:GetChildren()[5].Folder.Frame.Frame -- ตาม Path ที่บอกมา

    local unitsResult, itemsResult, mountsResult = {}, {}, {}
    local hasFoundSomething = false

    -- ฟังก์ชันช่วยสแกน
    local function scanCurrentTab(isMounts)
        local sf = itemInventory:FindFirstChild("ScrollingFrame", true) -- ค้นหาแบบกว้างขึ้น
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
                    local list = isMounts and (_G.HorstInventoryConfig.Mounts or {}) or (_G.HorstInventoryConfig.Items or {})
                    for _, whitelistedName in pairs(list) do
                        if string.lower(whitelistedName) == string.lower(itemName) then
                            if isMounts then mountsResult[whitelistedName] = (mountsResult[whitelistedName] or 0) + 1
                            else itemsResult[whitelistedName] = (itemsResult[whitelistedName] or 0) + itemCount end
                            hasFoundSomething = true
                        end
                    end
                end
            end
        end
    end

    -- 1. กด Items แล้วสแกน
    clickButton(btnItems)
    task.wait(1.5)
    scanCurrentTab(false)

    -- 2. กด Mounts แล้วสแกน
    clickButton(btnMounts)
    task.wait(1.5)
    scanCurrentTab(true)

    -- 3. ส่ง Log
    if hasFoundSomething and _G.Horst_SetDescription then
        local logMsg = {}
        if next(itemsResult) then table.insert(logMsg, "🧰Items: พบของ") end
        if next(mountsResult) then table.insert(logMsg, "🐅Mounts: พบของ") end
        _G.Horst_SetDescription(table.concat(logMsg, " / "), HttpService:JSONEncode({Items=itemsResult, Mounts=mountsResult}))
    end
end

-- =========================================================
-- 🚀 รันระบบ
-- =========================================================
task.spawn(function()
    while true do
        tryComboScanAndSendLog()
        task.wait(5)
    end
end)
