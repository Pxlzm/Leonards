local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("--- 🔍 กำลังสแกนหาชื่อ Units ตัวละครทั้งหมดในเกม ---")

-- ดึงข้อมูลจากโมดูล Information ของเกม
local success, Information = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Information"))
end)

if success and type(Information) == "table" then
    -- เกมส่วนใหญ่มักจะเก็บรายชื่อตัวละครไว้ใน Key เหล่านี้
    local unitsData = Information.Units or Information.UnitData or Information.Characters
    
    if unitsData then
        local count = 0
        for internalName, data in pairs(unitsData) do
            local displayName = "ไม่ระบุชื่อ"
            
            -- พยายามดึงชื่อ Display Name ออกมาเทียบ
            if type(data) == "table" then
                displayName = data.DisplayName or data.Name or displayName
            end
            
            print(string.format("🟢 ชื่อจริง (ใช้ใส่สคริปต์): \"%s\" | 🏷️ ชื่อในเกม: \"%s\"", tostring(internalName), tostring(displayName)))
            count = count + 1
        end
        print("--- ✅ สแกนเสร็จสิ้น พบทั้งหมด " .. count .. " ตัวละคร ---")
    else
        print("⚠️ ไม่พบตาราง Units โดยตรงใน Information! กำลังลิสต์หัวข้อข้อมูลทั้งหมดที่มีแทน...")
        for key, value in pairs(Information) do
            print("📂 โฟลเดอร์ข้อมูลที่พบ:", tostring(key), type(value))
        end
    end
else
    print("❌ ไม่สามารถดึงข้อมูลจาก Shared.Information ได้")
end
