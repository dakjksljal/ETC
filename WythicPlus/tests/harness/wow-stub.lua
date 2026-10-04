-- WoW API 스텁 — 실제 WythicPlusGearDiag.lua 를 인게임 밖(fengari/luajit)에서 그대로 로드해 돌리기 위한 최소 환경.
-- 미러 테스트(로직 베껴 쓰기)가 아니라 원본 파일을 로드하므로, 원본이 바뀌면 테스트가 함께 검증된다.
--
-- 사용: local W = dofile(root .. "tests/harness/wow-stub.lua"); W.reset(); W.worn[13] = link; W.stats[link] = {crit=136} ...
--       그 뒤 dofile(root .. "WythicPlusGearCore.lua"); dofile(root .. "WythicPlusGearDiag.lua")
--
-- 모델: 아이템은 "링크"로 식별한다. W.stats[link] = 2차 스탯, W.ilvl[link] = ilvl, W.info[id] = { equipLoc, classID, subclassID, name }.
-- 링크에서 ID는 "item:(%d+)"로 읽는다.

local W = {}

local function idOf(linkOrId)
    if type(linkOrId) == "number" then return linkOrId end
    if type(linkOrId) == "string" then return tonumber(linkOrId:match("item:(%d+)")) end
    return nil
end
W.idOf = idOf

function W.reset()
    W.worn = {}        -- invSlot → link
    W.stats = {}       -- link → { crit=, haste=, mastery=, versatility= } (GetItemStats 결과, 보석 미포함 기본 스탯)
    W.ilvl = {}        -- link → ilvl
    W.info = {}        -- itemId → { equipLoc=, classID=, subclassID=, name= }
    W.specInfo = {}    -- itemId → { specIDs... } (GetItemSpecInfo)
    W.ratings = {}     -- CR_* → 인게임 레이팅
    W.mySpecID = 250   -- 혈기 죽음의 기사
    W.convertible = {} -- itemId → true (마나용제 변환 가능)
    W.uniqueGems = {}
end
W.reset()

local MOD = { crit = "ITEM_MOD_CRIT_RATING_SHORT", haste = "ITEM_MOD_HASTE_RATING_SHORT", mastery = "ITEM_MOD_MASTERY_RATING_SHORT", versatility = "ITEM_MOD_VERSATILITY" }

C_Item = {
    GetItemStats = function(link)
        local st = W.stats[link]
        if not st then return nil end
        local out = {}
        for k, v in pairs(st) do if MOD[k] and v ~= 0 then out[MOD[k]] = v end end
        return out
    end,
    GetItemInfoInstant = function(linkOrId)
        local id = idOf(linkOrId)
        local i = id and W.info[id]
        if not i then return id end
        return id, i.itemType or "", i.subType or "", i.equipLoc or "", i.icon or 0, i.classID or 0, i.subclassID or 0
    end,
    GetDetailedItemLevelInfo = function(link) return W.ilvl[link] end,
    GetItemInfo = function(linkOrId) local id = idOf(linkOrId); local i = id and W.info[id]; return i and (i.name or ("item" .. id)) or nil end,
    GetItemNameByID = function(id) local i = W.info[id]; return i and i.name or nil end,
    GetItemUniquenessByID = function(id) return W.uniqueGems[id] == true, W.uniqueGems[id] and 1 or 0 end,
    IsItemConvertibleAndValidForPlayer = function(loc) return loc and W.convertible[loc.itemId] == true or false end,
}
C_TooltipInfo = { GetItemByID = function() return nil end }
C_Traits = { GenerateImportString = function() return "" end }
C_ClassTalents = { GetActiveConfigID = function() return nil end, GetActiveHeroTalentSpec = function() return nil end }
ItemLocation = {
    CreateFromBagAndSlot = function(bag, slot) return { bag = bag, slot = slot, itemId = W.bagItemAt and W.bagItemAt[bag .. ":" .. slot] } end,
    CreateFromEquipmentSlot = function(inv) return { inv = inv, itemId = W.worn[inv] and idOf(W.worn[inv]) } end,
}

function GetInventoryItemLink(_, inv) return W.worn[inv] end
function GetInventoryItemID(_, inv) local l = W.worn[inv]; return l and idOf(l) or nil end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return W.mySpecID end
function GetItemSpecInfo(link) local id = idOf(link); return id and W.specInfo[id] or nil end
function GetCombatRating(cr) return W.ratings[cr] or 0 end
-- 캐릭터 스탯 % (진단 표시용 — 판정엔 영향 없음). 필요 시 테스트가 W.pct 로 덮어쓴다.
W.pct = W.pct or { crit = 26.15, haste = 27.85, mastery = 41.69, versatility = 5.30 }
function GetMasteryEffect() return W.pct.mastery, 1 end
function GetCritChance() return W.pct.crit end
function GetSpellCritChance() return W.pct.crit end
function GetRangedCritChance() return W.pct.crit end
function GetHaste() return W.pct.haste end
function GetMeleeHaste() return W.pct.haste end
function GetVersatilityBonus() return W.pct.versatility end
function UnitStat() return 0, 0, 0, 0 end
function UnitClass() return "죽음의 기사", "DEATHKNIGHT", 6 end
function UnitLevel() return 80 end
function GetAverageItemLevel() return 322.5, 322.5, 322.5 end
function GetDodgeChance() return 0 end
function GetParryChance() return 0 end
function GetBlockChance() return 0 end
function GetLifesteal() return 0 end
function GetAvoidance() return 0 end
function GetSpeed() return 0 end
CR_CRIT_MELEE, CR_HASTE_MELEE, CR_MASTERY, CR_VERSATILITY_DAMAGE_DONE = 9, 18, 26, 29
CR_CRIT_SPELL, CR_HASTE_SPELL, CR_VERSATILITY_HEALING_DONE = 11, 20, 30
CR_LIFESTEAL, CR_AVOIDANCE, CR_SPEED = 17, 21, 14
Enum = Enum or { ItemQuality = { Epic = 4, Rare = 3 } }
function GetCombatRatingBonus() return 0 end
date = date or function() return "00:00:00" end
wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = tinsert or table.insert

-- 애드온 전역(다른 파일이 만드는 것)의 최소치
WythicPlusDB = WythicPlusDB or {}
WythicPlusGearData = WythicPlusGearData or { gemStats = {}, venom = { items = {} }, version = "test" }

return W
