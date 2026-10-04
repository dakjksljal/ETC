-- 스모크 테스트: 착용템의 보석 제외 2차 스탯(wornBaseStats) (node fengari 러너 또는 luajit tests/worn-base-stats.test.lua)
-- WythicPlusGearDiag.lua 의 linkGemIds / linkSecondaryStats / stripGemsFromLink / dictGemStats / wornBaseStats 를 미러링한다.
-- ⚠️ 아래 함수들은 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 배경(2026-09-21): 허리에 홈을 뚫고 보석(특화 16/가속 7, 사전에 있음)을 낀 채로 가방에 같은 아이템(같은 ilvl, 홈 없음)이
-- 있으면 그 사본이 교체 추천됐다. 원 링크 총량에서 사전 보석 값을 뺐는데 GetItemStats가 보석을 합쳐 주지 않아
-- 특화 83이 67로 잡혔고, 코어가 착용템과 사본(83)을 다른 실물로 봤다. 지금은 보석을 뗀 링크의 실측이 아이템 스탯이다.

local SECONDARY = { "crit", "haste", "mastery", "versatility" }
local ITEM_MOD_MAP = {
    ITEM_MOD_CRIT_RATING_SHORT = "crit",
    ITEM_MOD_HASTE_RATING_SHORT = "haste",
    ITEM_MOD_MASTERY_RATING_SHORT = "mastery",
    ITEM_MOD_VERSATILITY = "versatility",
}

-- 스텁: 링크 문자열 → GetItemStats 결과
local STATS = {}
C_Item = { GetItemStats = function(link) return STATS[link] end }

-- ── 미러 (원본과 동일) ──
local function linkSecondaryStats(link)
    local out = {}
    local stats = link and C_Item.GetItemStats and C_Item.GetItemStats(link)
    if stats then
        for mod, key in pairs(ITEM_MOD_MAP) do
            if stats[mod] then out[key] = stats[mod] end
        end
    end
    return out
end

local function linkGemIds(link)
    local ids = {}
    if link then
        local g1, g2, g3, g4 = link:match("item:%d+:%d*:(%d*):(%d*):(%d*):(%d*)")
        for _, g in ipairs({ g1, g2, g3, g4 }) do
            local n = tonumber(g)
            if n and n > 0 then ids[#ids + 1] = n end
        end
    end
    return ids
end

local function stripGemsFromLink(link)
    if not link then return nil end
    local out = link:gsub("(item:%d+:%d*):%d*:%d*:%d*:%d*", "%1::::", 1)
    return out
end

local function dictGemStats(gemIds, gemStatsDict)
    local gem = {}
    for _, gid in ipairs(gemIds) do
        local gs = gemStatsDict and gemStatsDict[gid]
        if gs then
            for k, v in pairs(gs) do gem[k] = (gem[k] or 0) + v end
        end
    end
    return gem
end

local function wornBaseStats(link, gemStatsDict)
    local total = linkSecondaryStats(link)
    local gemIds = linkGemIds(link)
    local base = {}
    if #gemIds == 0 then
        for _, k in ipairs(SECONDARY) do base[k] = total[k] or 0 end
        return base, {}
    end
    local stripped = linkSecondaryStats(stripGemsFromLink(link))
    local valid, diffSum, diff = next(stripped) ~= nil, 0, {}
    for _, k in ipairs(SECONDARY) do
        local d = (total[k] or 0) - (stripped[k] or 0)
        if d < 0 then valid = false end
        if d > 0 then diff[k] = d; diffSum = diffSum + d end
    end
    if valid then
        for _, k in ipairs(SECONDARY) do base[k] = stripped[k] or 0 end
        if diffSum > 0 then return base, diff end
        return base, dictGemStats(gemIds, gemStatsDict)
    end
    local gem = dictGemStats(gemIds, gemStatsDict)
    for _, k in ipairs(SECONDARY) do base[k] = math.max(0, (total[k] or 0) - (gem[k] or 0)) end
    return base, gem
end

-- ── 테스트 ──
local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end
local function sameStats(a, b)
    for _, k in ipairs(SECONDARY) do
        if (a[k] or 0) ~= (b[k] or 0) then return false end
    end
    return true
end
local function S(crit, haste, mastery, vers)
    return { ITEM_MOD_CRIT_RATING_SHORT = crit, ITEM_MOD_HASTE_RATING_SHORT = haste, ITEM_MOD_MASTERY_RATING_SHORT = mastery, ITEM_MOD_VERSATILITY = vers }
end
local DICT = { [240900] = { mastery = 16, haste = 7 }, [240888] = { haste = 17 }, [240896] = { mastery = 17 } }

-- 링크 보석 필드 비우기
local WORN = "item:271475:7534:240900:::::90:250:::1:12838"   -- 홈 1개, 보석 240900(특화 16/가속 7)
local WORN_NOGEM = "item:271475:7534::::::90:250:::1:12838"
check("strip: 보석 1개 링크 → gem1~4 비움, 나머지 필드 보존", stripGemsFromLink(WORN) == WORN_NOGEM)
check("strip: 보석 없는 링크는 그대로", stripGemsFromLink(WORN_NOGEM) == WORN_NOGEM)
local TWO = "item:271475::240888:240896::::90:250"
local TWO_NOGEM = "item:271475:::::::90:250"
check("strip: 보석 2개 링크", stripGemsFromLink(TWO) == TWO_NOGEM)
check("strip: 인챈트 없는(빈 필드) 링크도 보석만 비움", stripGemsFromLink("item:5::240888:::::7") == "item:5:::::::7")
check("strip: nil → nil", stripGemsFromLink(nil) == nil)

-- 제보 상황(GetItemStats가 보석을 합치지 않는 경우): 원 링크 총량 = 무보석 = 아이템 스탯. 가방 사본(홈 없음)도 같은 값.
STATS[WORN] = S(0, 0, 83, 54)
STATS[WORN_NOGEM] = S(0, 0, 83, 54)
local BAG = "item:271475:::::::91:250:::1:12838"
STATS[BAG] = S(0, 0, 83, 54)
local base, gem = wornBaseStats(WORN, DICT)
check("보석 미합산 API: base = 아이템 스탯(특화 83/유연 54), 사전 값을 빼지 않음", sameStats(base, { mastery = 83, versatility = 54 }))
check("보석 미합산 API: gem = 사전 값(특화 16/가속 7)", sameStats(gem, { mastery = 16, haste = 7 }))
check("보석 미합산 API: 홈 없는 가방 사본과 같은 실물로 판정", sameStats(base, linkSecondaryStats(BAG)))
base, gem = wornBaseStats(WORN, {})
check("보석 미합산 API·사전에 없는 보석: base 그대로, gem 비어 있음", sameStats(base, { mastery = 83, versatility = 54 }) and next(gem) == nil)

-- GetItemStats가 보석을 합쳐 주는 경우: 총량 - 무보석 = 보석 실측(사전 불필요)
STATS[WORN] = S(0, 7, 99, 54)
base, gem = wornBaseStats(WORN, {})
check("보석 합산 API·사전에 없는 보석: base = 무보석 실측(83/54)", sameStats(base, { mastery = 83, versatility = 54 }))
check("보석 합산 API·사전에 없는 보석: gem = 차이(16/7)", sameStats(gem, { mastery = 16, haste = 7 }))
check("보석 합산 API: 홈 없는 가방 사본과 같은 실물로 판정", sameStats(base, linkSecondaryStats(BAG)))
base, gem = wornBaseStats(WORN, { [240900] = { mastery = 14, haste = 6 } })
check("보석 합산 API·사전 값이 달라도 실측 우선: gem 16/7", sameStats(gem, { mastery = 16, haste = 7 }))

-- 보석 없는 착용템: 총량 그대로, gem 비어 있음(무보석 링크를 읽지 않음)
base, gem = wornBaseStats(WORN_NOGEM, DICT)
check("보석 없음: base = 총량", sameStats(base, { mastery = 83, versatility = 54 }))
check("보석 없음: gem 비어 있음", next(gem) == nil)

-- 폴백 1: 무보석 링크 읽기 실패(nil) → 총량에서 사전 차감(기존 동작)
local W2 = "item:271444::240888:::::90:250"
local W2_NOGEM = "item:271444:::::::90:250"
STATS[W2] = S(0, 117, 0, 0)
STATS[W2_NOGEM] = nil
base, gem = wornBaseStats(W2, DICT)
check("폴백(읽기 실패): 총량 - 사전 → base haste 100", sameStats(base, { haste = 100 }))
check("폴백(읽기 실패): gem 사전 값 17", sameStats(gem, { haste = 17 }))
base, gem = wornBaseStats(W2, {})
check("폴백(읽기 실패·사전에도 없음): 차감 없음", sameStats(base, { haste = 117 }) and next(gem) == nil)

-- 폴백 2: 무보석 링크가 총량보다 큼(비정상) → 총량에서 사전 차감
STATS[W2_NOGEM] = S(0, 120, 0, 0)
base, gem = wornBaseStats(W2, DICT)
check("폴백(무보석 > 총량): 총량 - 사전 → base haste 100", sameStats(base, { haste = 100 }))

-- 무보석 링크에 2차 스탯이 하나도 없으면(빈 테이블) 무효 → 사전 폴백. base가 0으로 무너지지 않는다
STATS[W2_NOGEM] = {}
base, gem = wornBaseStats(W2, DICT)
check("빈 실측: 사전 폴백 → base haste 100", sameStats(base, { haste = 100 }))
base, gem = wornBaseStats(W2, {})
check("빈 실측·사전 없음: base는 총량(0으로 무너지지 않음)", sameStats(base, { haste = 117 }) and next(gem) == nil)

-- 보석 2개: 합산 차이(합산 API) / 사전 합산(미합산 API)
STATS[TWO] = S(0, 117, 17, 0)
STATS[TWO_NOGEM] = S(0, 100, 0, 0)
base, gem = wornBaseStats(TWO, {})
check("보석 2개(합산 API): base 100", sameStats(base, { haste = 100 }))
check("보석 2개(합산 API): gem 차이 합산 17/17", sameStats(gem, { haste = 17, mastery = 17 }))
STATS[TWO] = S(0, 100, 0, 0)
base, gem = wornBaseStats(TWO, DICT)
check("보석 2개(미합산 API): base 100, gem 사전 합산 17/17", sameStats(base, { haste = 100 }) and sameStats(gem, { haste = 17, mastery = 17 }))

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
