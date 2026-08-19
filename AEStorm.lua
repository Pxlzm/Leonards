-- ============================================================
--  Storm Inventory Logger  (Anime Expeditions)
--
--  Publishes live account progress to Storm Launcher and marks
--  the account finished once a configured target is reached.
--
--  Data source verified against the decompiled game:
--    ReplicatedStorage.FusionPackage.Dependencies.PlayerData
--      .Level                       number
--      .UnitData[uid].Asset         asset key, e.g. "Sugar"
--      .UnitData[uid].Trait         trait display name, e.g. "Unbound"
--      .ItemData[assetKey].Amount   e.g. Gem / TraitReroll / StatReroll
-- ============================================================

repeat task.wait() until game:IsLoaded()

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

repeat task.wait() until Players.LocalPlayer
local LocalPlayer = Players.LocalPlayer

local CFG      = (getgenv and getgenv().StormInventoryConfig) or _G.StormInventoryConfig or {}
local Palette  = CFG.Palette or {}
local INTERVAL = math.max(tonumber(CFG.Interval) or 15, 5)

local function Log(message)
    print("[Storm] " .. message)
end

local function LogWarn(message)
    warn("[Storm] " .. message)
end

-- ============================================================
--  Storm Launcher account binding
-- ============================================================

local STORM_MODULE_URL = "https://raw.githubusercontent.com/Androssy/Storm-Launcher/refs/heads/main/StormAccount.lua"

-- Executors expose their HTTP function under different names.
local httpRequest = request or (syn and syn.request) or http_request

local function FetchSource(url)
    if type(httpRequest) == "function" then
        local ok, res = pcall(httpRequest, { Url = url, Method = "GET" })
        if ok and type(res) == "table" and type(res.Body) == "string" and res.Body ~= "" then
            return res.Body
        end
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" and body ~= "" then
        return body
    end

    return nil
end

local function LoadStormAccountModule()
    local source = FetchSource(STORM_MODULE_URL)
    if not source then
        return nil, "unable to download StormAccount.lua"
    end

    local chunk, compileError = loadstring(source)
    if not chunk then
        return nil, "StormAccount.lua failed to compile: " .. tostring(compileError)
    end

    local ok, moduleOrError = pcall(chunk)
    if not ok then
        return nil, "StormAccount.lua raised an error: " .. tostring(moduleOrError)
    end

    return moduleOrError, nil
end

-- The Storm module talks to the launcher over http://localhost:3030 using the
-- executor's global `request`. Without it every call fails.
if type(httpRequest) ~= "function" then
    LogWarn("Executor does not expose a `request` function - Storm reporting will be disabled.")
end

local currentAccount

do
    local StormAccount, loadError = LoadStormAccountModule()
    if not StormAccount then
        LogWarn("Storm module unavailable: " .. tostring(loadError))
    else
        local key = CFG.StormKey
        if type(key) ~= "string" or key == "" then
            LogWarn("StormKey is missing from the config - Storm API calls that require auth will fail.")
        end

        local ok, err = pcall(function()
            StormAccount.SetKey(key or "")
            currentAccount = StormAccount.new(LocalPlayer.Name)
        end)

        if ok and currentAccount then
            Log("Connected to Storm Launcher as account: " .. LocalPlayer.Name)
        else
            LogWarn("Storm account binding failed: " .. tostring(err))
        end
    end
end

-- Offline stub so the reporting logic below stays branch-free.
if not currentAccount then
    currentAccount = {
        SetDescription = function() return true, nil end,
        MarkFinished   = function() return true, nil end,
    }
    LogWarn("Running in offline mode - progress will be logged locally only.")
end

-- ============================================================
--  Fusion / game data access
-- ============================================================

local function RequireGameData()
    local package = ReplicatedStorage:WaitForChild("FusionPackage", 60)
    if not package then
        return nil, nil, "FusionPackage was not found in ReplicatedStorage"
    end

    local fusionModule = package:WaitForChild("Fusion", 20)
    local dependenciesModule = package:WaitForChild("Dependencies", 20)
    if not fusionModule or not dependenciesModule then
        return nil, nil, "FusionPackage is missing the Fusion or Dependencies module"
    end

    local okFusion, fusion = pcall(require, fusionModule)
    if not okFusion then
        return nil, nil, "require(Fusion) failed: " .. tostring(fusion)
    end

    local okDeps, dependencies = pcall(require, dependenciesModule)
    if not okDeps then
        return nil, nil, "require(Dependencies) failed: " .. tostring(dependencies)
    end

    return fusion, dependencies, nil
end

local Fusion, Dependencies, dataError = RequireGameData()
if not Fusion then
    LogWarn("Cannot read game data: " .. tostring(dataError))
    return
end

local peek = Fusion.peek

-- Information.Assets maps every asset key to its definition, including
-- DisplayName. Units and items are sheet-synced at runtime, so this index is
-- what lets the config accept either form, e.g. "TraitReroll" or "Trait Crystal".
local function BuildAssetIndex()
    local information = peek(Dependencies.Information) or {}
    local assets = information.Assets or {}

    local lookup, displayNames = {}, {}
    for key, definition in pairs(assets) do
        local assetKey = tostring(key)
        lookup[string.lower(assetKey)] = assetKey

        if type(definition) == "table" and definition.DisplayName then
            local display = tostring(definition.DisplayName)
            displayNames[assetKey] = display
            -- An asset key always wins over a display name collision.
            local lowered = string.lower(display)
            if lookup[lowered] == nil then
                lookup[lowered] = assetKey
            end
        end
    end

    return lookup, displayNames
end

local assetLookup, assetDisplayNames = {}, {}

local function IsKnownAsset(nameOrKey)
    return assetLookup[string.lower(tostring(nameOrKey))] ~= nil
end

local function ResolveAssetKey(nameOrKey)
    local raw = tostring(nameOrKey)
    return assetLookup[string.lower(raw)] or raw
end

local function DisplayNameOf(assetKey)
    return assetDisplayNames[assetKey] or assetKey
end

local function ReadPlayerData()
    local data = peek(Dependencies.PlayerData)
    if type(data) ~= "table" then
        data = Dependencies.RawPlayerData
    end
    -- Level is written as part of the initial profile load, so its presence
    -- is a reliable "profile has replicated" signal.
    if type(data) ~= "table" or data.Level == nil then
        return nil
    end
    return data
end

local function GetItemAmount(itemData, assetKey)
    local entry = itemData[assetKey]
    if type(entry) == "table" then
        return tonumber(entry.Amount) or 0
    end
    return tonumber(entry) or 0
end

-- ============================================================
--  Description formatting
-- ============================================================

-- Storm's description parser is a tag stack: every tag opens with <name:value>
-- or <b>, and each one is closed by a bare <>. Tags nest, e.g.
--   <b><size:lg><mark:#4ade80>text<><><>
local BOLD_TEXT = CFG.BoldText == true
local TEXT_SIZE = type(CFG.TextSize) == "string" and CFG.TextSize ~= "" and CFG.TextSize or nil

-- Colour is applied innermost so the hex inside <mark:...> is never wrapped
-- by another tag, then size, then bold on the outside.
local function Mark(color, text)
    if color then
        text = string.format("<mark:%s>%s<>", color, text)
    end
    if TEXT_SIZE then
        text = string.format("<size:%s>%s<>", TEXT_SIZE, text)
    end
    if BOLD_TEXT then
        text = "<b>" .. text .. "<>"
    end
    return text
end

-- Stat rows are data driven so the config toggle, the palette key and the
-- backing item key always stay in sync.
local STAT_ROWS = {
    { Key = "Level",       Icon = "⭐", Label = "Level" },
    { Key = "Gems",        Icon = "💎", Label = "Gem",          Item = "Gem" },
    { Key = "VillainCoin", Icon = "🦹", Label = "Villain Coin", Item = "VillainCoin" },
    { Key = "TraitReroll", Icon = "🔮", Label = "Trait Reroll", Item = "TraitReroll" },
    { Key = "StatReroll",  Icon = "🎲", Label = "Stat Reroll",  Item = "StatReroll" },
}

-- ============================================================
--  Main reporting loop
-- ============================================================

do
    local special = CFG.Special or {}
    Log(string.format("Storm Inventory Logger started | interval %ds | gem target %s | tournament unit %s",
        INTERVAL,
        tostring(tonumber(special.GemsTarget) or 0),
        tostring(special.Tournaments or "off")))
end

task.spawn(function()
    local lastDescription = nil
    local rerollSafetyArmed = false
    local waitingLogged = false
    local unknownAssetsChecked = false

    while true do
        local ok, signal = pcall(function()
            local pData = ReadPlayerData()
            if not pData then
                if not waitingLogged then
                    Log("Waiting for PlayerData to replicate...")
                    waitingLogged = true
                end
                return nil
            end

            if waitingLogged then
                Log("PlayerData replicated - reporting is now live.")
                waitingLogged = false
            end

            if next(assetLookup) == nil then
                assetLookup, assetDisplayNames = BuildAssetIndex()
            end

            local statsCfg = CFG.Stats or {}
            local specialCfg = CFG.Special or {}

            -- Surface typos in the config instead of silently reporting zero.
            if not unknownAssetsChecked and next(assetLookup) ~= nil then
                unknownAssetsChecked = true

                for _, row in ipairs(STAT_ROWS) do
                    if row.Item and statsCfg[row.Key] and not IsKnownAsset(row.Item) then
                        LogWarn(string.format(
                            "Stats.%s is enabled but item '%s' does not exist in this game version - it will always read 0.",
                            row.Key, row.Item))
                    end
                end

                local function CheckUnit(name, source)
                    if name and not IsKnownAsset(name) then
                        LogWarn(string.format("%s references unit '%s', which is not a known asset - check the spelling.",
                            source, tostring(name)))
                    end
                end

                CheckUnit(specialCfg.Tournaments, "Special.Tournaments")
                for _, unitName in ipairs(CFG.TargetUnits or {}) do
                    CheckUnit(unitName, "TargetUnits")
                end
                for unitName in pairs(CFG.TargetTraits or {}) do
                    CheckUnit(unitName, "TargetTraits")
                end
            end

            local rawUnits = pData.UnitData or {}
            local rawItems = pData.ItemData or {}

            -- Collapse the unit inventory into one entry per asset key.
            local ownedUnits = {}
            for _, unit in pairs(rawUnits) do
                if type(unit) == "table" and unit.Asset then
                    local assetKey = tostring(unit.Asset)
                    local entry = ownedUnits[assetKey]
                    if not entry then
                        entry = { Count = 0, Traits = {} }
                        ownedUnits[assetKey] = entry
                    end
                    entry.Count += 1

                    local trait = unit.Trait
                    if trait ~= nil and trait ~= "" then
                        table.insert(entry.Traits, tostring(trait))
                    end
                end
            end

            local parts = {}

            -- 1. Account stats
            for _, row in ipairs(STAT_ROWS) do
                if statsCfg[row.Key] then
                    local value = row.Item and GetItemAmount(rawItems, row.Item) or pData.Level
                    table.insert(parts, Mark(Palette[row.Key],
                        string.format("%s %s %s", row.Icon, row.Label, tostring(value))))
                end
            end

            -- 2. Tournament unit check
            if specialCfg.Tournaments then
                local assetKey = ResolveAssetKey(specialCfg.Tournaments)
                local owned = ownedUnits[assetKey] ~= nil
                table.insert(parts, Mark(Palette.Tournament,
                    string.format("🏆 %s %s", owned and "✅" or "❌", DisplayNameOf(assetKey))))
            end

            -- 3. Watched units - presence only
            for _, unitName in ipairs(CFG.TargetUnits or {}) do
                local assetKey = ResolveAssetKey(unitName)
                local owned = ownedUnits[assetKey] ~= nil
                table.insert(parts, Mark(owned and Palette.Found or Palette.Missing,
                    string.format("%s %s", owned and "✅" or "❌", DisplayNameOf(assetKey))))
            end

            -- 4. Target traits - also a finish condition
            local hasTargetTraits = false
            local allTraitsMet = true

            if type(CFG.TargetTraits) == "table" and next(CFG.TargetTraits) ~= nil then
                hasTargetTraits = true

                for unitName, desiredTrait in pairs(CFG.TargetTraits) do
                    local assetKey = ResolveAssetKey(unitName)
                    local entry = ownedUnits[assetKey]

                    local matched = false
                    local shownTrait = "Not Owned"

                    if entry then
                        shownTrait = entry.Traits[1] or "No Trait"
                        for _, trait in ipairs(entry.Traits) do
                            if string.lower(trait) == string.lower(tostring(desiredTrait)) then
                                matched = true
                                shownTrait = trait
                                break
                            end
                        end
                    end

                    if not matched then
                        allTraitsMet = false
                    end

                    table.insert(parts, Mark(matched and Palette.Found or Palette.Missing,
                        string.format("%s %s [%s]", matched and "✅" or "❌",
                            DisplayNameOf(assetKey), shownTrait)))
                end
            end

            -- 5. Publish, but only when the text actually changed.
            local description = #parts > 0 and table.concat(parts, " / ") or "No data"
            if description ~= lastDescription then
                local sent, sendError = currentAccount:SetDescription(description)
                if sent then
                    lastDescription = description
                    Log("Description updated: " .. description)
                else
                    LogWarn("SetDescription failed: " .. tostring(sendError))
                end
            end

            -- 6. Finish conditions
            local gemTarget = tonumber(specialCfg.GemsTarget) or 0
            local currentGems = GetItemAmount(rawItems, "Gem")
            local gemFinished = gemTarget > 0 and currentGems >= gemTarget
            local traitFinished = hasTargetTraits and allTraitsMet

            local safetyCfg = CFG.Safety or {}
            local rerollLimitReached = false

            if safetyCfg.StopAtTraitReroll == true then
                local limit = tonumber(safetyCfg.TraitRerollLimit) or 0
                local stock = GetItemAmount(rawItems, "TraitReroll")
                -- The limit only arms once the stock has been observed above it.
                -- Without this, an account that never owned the item (count 0)
                -- would trip the limit on the very first poll.
                if stock > limit then
                    rerollSafetyArmed = true
                end
                rerollLimitReached = rerollSafetyArmed and stock <= limit
            end

            if not (gemFinished or traitFinished or rerollLimitReached) then
                return nil
            end

            local finishMessage = CFG.FinishMessage or "Done!"
            local finishColor = Palette.Finish

            local reason
            if traitFinished then
                reason = "all target traits obtained"
            elseif gemFinished then
                reason = string.format("gem target reached (%d/%d)", currentGems, gemTarget)
            else
                reason = string.format("trait reroll stock depleted (%d left)",
                    GetItemAmount(rawItems, "TraitReroll"))
                finishMessage = "⚠️ Stopped (Reroll Limit)"
                finishColor = Palette.Warning
            end

            local finishParts = { Mark(finishColor, finishMessage) }
            for _, part in ipairs(parts) do
                table.insert(finishParts, part)
            end

            local finishDescription = table.concat(finishParts, " / ")
            Log("Finish condition met - " .. reason)

            local marked, markError
            for attempt = 1, 3 do
                marked, markError = currentAccount:MarkFinished(finishDescription)
                if marked then
                    break
                end
                LogWarn(string.format("MarkFinished attempt %d/3 failed: %s", attempt, tostring(markError)))
                task.wait(2)
            end

            if marked then
                Log("Account marked as finished - Storm will rotate to the next account.")
            else
                LogWarn("MarkFinished failed after 3 attempts - stopping the loop anyway.")
            end

            return "finished"
        end)

        if not ok then
            LogWarn("Reporting loop error: " .. tostring(signal))
        elseif signal == "finished" then
            -- Returning from inside pcall only exits the inner function, so the
            -- loop must be broken out here explicitly.
            break
        end

        task.wait(INTERVAL)
    end

    Log("Storm Inventory Logger stopped.")
end)
