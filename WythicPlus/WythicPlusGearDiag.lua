-- Wythic+ 장비 진단 (입력 어댑터 + 코어 호출)
-- WoW API로 내 장비/스탯/인챈트/특성을 읽어 공유 코어(WythicPlusGearCore)가 받는 형태로 변환하고,
-- 채점 4종(장비·스탯·인챈트·특성)을 계산해 종합 등급을 낸다. 웹 diagnosis.ts computeDiagnosis와 동일한
-- 재정규화(데이터 없는 카테고리는 가중치에서 제외)를 적용해 웹과 결과를 맞춘다.
-- 스펙 메타(비교 대상)는 WythicPlusGearData(주간 릴리즈)에서 오고, 여기서는 "내 캐릭터" 값만 수집한다.

local Core = WythicPlusGearCore  -- .toc에서 이 파일보다 먼저 로드됨

-- 코어 슬롯 키 → WoW 인벤토리 슬롯 ID (정규화 키는 gear-core.ts와 일치)
local SLOTS = {
    { key = "HEAD", inv = 1 }, { key = "NECK", inv = 2 }, { key = "SHOULDER", inv = 3 },
    { key = "BACK", inv = 15 }, { key = "CHEST", inv = 5 }, { key = "WRIST", inv = 9 },
    { key = "HANDS", inv = 10 }, { key = "WAIST", inv = 6 }, { key = "LEGS", inv = 7 },
    { key = "FEET", inv = 8 }, { key = "FINGER_1", inv = 11 }, { key = "FINGER_2", inv = 12 },
    { key = "TRINKET_1", inv = 13 }, { key = "TRINKET_2", inv = 14 },
    { key = "MAIN_HAND", inv = 16 }, { key = "OFF_HAND", inv = 17 },
}

-- 내 2차 스탯(%) — 메타(stats)도 %라 비율 비교가 일관됨
local STAT_ALIASES = { crit = { "crit" }, haste = { "haste" }, mastery = { "mastery" }, versatility = { "versatility" } }

-- ── base64 디코더 (특성 로드아웃 코드 → 바이트) ───────────────────────────────
-- 코어 bitSimilarity는 디코딩된 바이트 배열을 받는다. 디코드 실패 시 nil 반환 → 코어가 문자 비교로 폴백.
local B64 = {}
do
    local alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, #alpha do B64[alpha:sub(i, i)] = i - 1 end
end

local function decodeBase64(s)
    if not s or s == "" then return nil end
    local bytes = {}
    local acc, bits = 0, 0
    for i = 1, #s do
        local c = s:sub(i, i)
        if c ~= "=" then
            local v = B64[c]
            if v == nil then return nil end  -- 알 수 없는 문자 → 폴백
            acc = acc * 64 + v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local byte = math.floor(acc / (2 ^ bits)) % 256
                bytes[#bytes + 1] = byte
            end
        end
    end
    return #bytes > 0 and bytes or nil
end

-- ── 내 캐릭터 값 수집 ─────────────────────────────────────────────────────────

-- 레이팅과 레이팅 기여 %(환산 기울기 재료) — 코어가 pctPerRating(선형 %/레이팅)을 만들 때 쓴다.
-- 이게 없으면 코어는 메타 대비 보간 폴백을 쓰는데, 내 레이팅≈메타 평균이면 %가 폭발한다.
local function crInfo(cr, bonusScale)
    local rating = GetCombatRating and cr and GetCombatRating(cr) or nil
    local bonus = GetCombatRatingBonus and cr and GetCombatRatingBonus(cr) or nil
    if bonus and bonusScale then bonus = bonus * bonusScale end
    return rating, bonus
end

local function collectStats()
    -- 특화는 GetCombatRatingBonus가 계수 적용 전 값이라 GetMasteryEffect의 계수를 곱한다
    local _, masteryCoeff = GetMasteryEffect()
    local critR, critB = crInfo(CR_CRIT_MELEE)
    local hasteR, hasteB = crInfo(CR_HASTE_MELEE)
    local masteryR, masteryB = crInfo(CR_MASTERY, masteryCoeff or 1)
    local versR, versB = crInfo(CR_VERSATILITY_DAMAGE_DONE)
    return {
        { stat_name = "crit", stat_value = GetCritChance() or 0, stat_rating = critR, stat_rating_bonus = critB },
        { stat_name = "haste", stat_value = GetHaste() or 0, stat_rating = hasteR, stat_rating_bonus = hasteB },
        { stat_name = "mastery", stat_value = GetMasteryEffect() or 0, stat_rating = masteryR, stat_rating_bonus = masteryB },
        { stat_name = "versatility", stat_value = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0, stat_rating = versR, stat_rating_bonus = versB },
    }
end

-- 코어 calcGearScore용 EquipLite 목록 + 착용 아이템ID 맵
local function collectEquipment()
    local eq = {}
    for _, slot in ipairs(SLOTS) do
        local id = GetInventoryItemID("player", slot.inv)
        if id then
            eq[#eq + 1] = {
                slot = slot.key,
                item_id = id,
                item_name = C_Item.GetItemNameByID(id) or "",
                item_level = 0,  -- 장비 점수는 item_id 매칭만 사용
            }
        end
    end
    return eq
end

-- 코어 calcEnchantScoreCore용 EquipEnchantLite 목록. 인챈트 ID는 아이템 링크에서 파싱.
local function collectEnchantEquip()
    local out = {}
    local anyEnchant = false
    for _, slot in ipairs(SLOTS) do
        local link = GetInventoryItemLink("player", slot.inv)
        local enchantId = nil
        if link then
            local e = link:match("item:%d+:(%d+)")
            if e and e ~= "0" then enchantId = tonumber(e) end
        end
        if enchantId then anyEnchant = true end
        out[#out + 1] = {
            slot = slot.key,
            myEnchantId = enchantId,
            myEnchant = nil,   -- 인게임은 ID 매칭으로 충분 (메타도 ID 보유)
            myEnchantEn = nil,
            myBase = "",
        }
    end
    return out, anyEnchant
end

-- 현재 특성 로드아웃 export 문자열 (메타 talents 코드와 동일 형식)
local function collectTalentCode()
    if not (C_ClassTalents and C_Traits) then return nil end
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil end
    local ok, code = pcall(C_Traits.GenerateImportString, configID)
    if ok and type(code) == "string" and code ~= "" then return code end
    return nil
end

-- 강화 트랙 범위 — 웹 UPGRADE_TRACKS 시즌2와 동일 (Gear.lua 표기 테이블과 함께 시즌마다 갱신).
-- 착용 ilvl로 트랙을 역산해 코어 upgradePriorities(같은 템 유지 슬롯의 강화 여지)를 살린다.
local TRACKS = {
    { ko = "모험가", base = 266, max = 282 },
    { ko = "노련가", base = 279, max = 295 },
    { ko = "챔피언", base = 292, max = 308 },
    { ko = "영웅",   base = 305, max = 321 },
    { ko = "신화",   base = 318, max = 334 },
}
local function trackOfIlvl(ilvl)
    if not ilvl then return nil end
    -- 겹치는 구간(예: 318~321)은 높은 트랙 우선 — 역순 탐색
    for i = #TRACKS, 1, -1 do
        local t = TRACKS[i]
        if ilvl >= t.base and ilvl <= t.max then return t end
    end
    return nil
end

-- ── 메타 → 코어 입력 변환 ─────────────────────────────────────────────────────

local function toPopularItems(items)
    local pop = {}
    if items then
        for slotKey, list in pairs(items) do
            local arr = {}
            for i = 1, #list do arr[i] = { item_id = list[i][1] } end
            pop[slotKey] = arr
        end
    end
    return pop
end

local function toEnchantMeta(enchants)
    local meta = {}
    local any = false
    if enchants then
        for slotKey, list in pairs(enchants) do
            local arr = {}
            for i = 1, #list do
                arr[i] = { enchant_id = list[i][1], name = "", name_en = "", base = "", base_en = "", quality = nil }
            end
            if #arr > 0 then any = true end
            meta[slotKey] = arr
        end
    end
    return meta, any
end

local function toMetaBuilds(talents)
    local builds = {}
    if talents then
        for i = 1, #talents do
            builds[i] = { code = talents[i], bytes = decodeBase64(talents[i]) }
        end
    end
    return builds
end

local function anyPositive(t)
    if not t then return false end
    for _, v in pairs(t) do if type(v) == "number" and v > 0 then return true end end
    return false
end

-- ── 진단 실행 ─────────────────────────────────────────────────────────────────
-- spec = WythicPlusGearData.specs[key] (뷰어가 해석해 넘김). 반환: 종합 등급 + 카테고리 점수.
function WythicPlus_GearDiagnose(spec)
    if not (Core and spec) then return nil end

    local equipment = collectEquipment()
    local gear = Core:calcGearScore(equipment, toPopularItems(spec.items))

    -- 웹 computeDiagnosis와 동일: 장비 항상, 나머지는 데이터 있을 때만 → 남은 가중치로 재정규화
    local categories = { { weight = 0.40, score = gear.score } }
    local result = { gear = { score = gear.score, slots = gear.slots } }

    -- 스탯
    local myStats = collectStats()
    local hasMyStats = false
    for _, s in ipairs(myStats) do if s.stat_value > 0 then hasMyStats = true break end end
    if hasMyStats and anyPositive(spec.stats) then
        local stat = Core:calcStatScore(myStats, spec.stats, STAT_ALIASES)
        result.stat = { score = stat.score, stats = stat.stats }
        categories[#categories + 1] = { weight = 0.25, score = stat.score }
    end

    -- 인챈트
    local enchantEquip, hasMyEnchant = collectEnchantEquip()
    local enchantMeta, hasEnchantMeta = toEnchantMeta(spec.enchants)
    if hasMyEnchant and hasEnchantMeta then
        local ench = Core:calcEnchantScoreCore(enchantEquip, enchantMeta)
        result.enchant = { score = ench.score, enchants = ench.enchants }
        categories[#categories + 1] = { weight = 0.15, score = ench.score }
    end

    -- 특성
    local myCode = collectTalentCode()
    if myCode and spec.talents and #spec.talents > 0 then
        local tal = Core:calcTalentScore(myCode, decodeBase64(myCode), toMetaBuilds(spec.talents))
        result.talent = { score = tal.score }
        categories[#categories + 1] = { weight = 0.20, score = tal.score }
    end

    -- 재정규화 가중 평균
    local totalWeight = 0
    for _, c in ipairs(categories) do totalWeight = totalWeight + c.weight end
    local overall = 0
    if totalWeight > 0 then
        local sum = 0
        for _, c in ipairs(categories) do sum = sum + c.score * c.weight / totalWeight end
        overall = math.floor(sum + 0.5)
    end

    result.overall = overall
    result.grade = Core:toGrade(overall)
    result.color = Core:gradeColor(result.grade)
    return result
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 시뮬레이션 (5단계 그리디) 입력 어댑터
-- 메타 아이템 스탯은 데이터(주간 릴리즈)에 사전계산돼 있고, 내 장비 스탯은
-- C_Item.GetItemStats(착용 링크)로 읽는다. 보석은 링크의 gemID → 데이터 gemStats 사전.
-- ══════════════════════════════════════════════════════════════════════════════

local ITEM_MOD_MAP = {
    ITEM_MOD_CRIT_RATING_SHORT = "crit",
    ITEM_MOD_HASTE_RATING_SHORT = "haste",
    ITEM_MOD_MASTERY_RATING_SHORT = "mastery",
    ITEM_MOD_VERSATILITY = "versatility",
}
local SECONDARY = { "crit", "haste", "mastery", "versatility" }

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

-- 다이아몬드류 고유 장착 보석 판별 — 전 부위 통틀어 1개만 소켓 가능.
-- C_Item API 우선, 없으면 툴팁의 "고유" 라인 검사 (둘 다 실패하면 비고유 취급)
local uniqueGemCache = {}
local function IsUniqueGem(gemId)
    if not gemId or gemId == 0 then return false end -- 0 = 보석 해제 핀
    local c = uniqueGemCache[gemId]
    if c ~= nil then return c end
    local unique = false
    if C_Item and C_Item.GetItemUniquenessByID then
        local ok, isU, limit = pcall(C_Item.GetItemUniquenessByID, gemId)
        if ok and (isU or (type(limit) == "number" and limit > 0)) then unique = true end
    end
    if not unique and C_TooltipInfo and C_TooltipInfo.GetItemByID and ITEM_UNIQUE then
        local ok, td = pcall(C_TooltipInfo.GetItemByID, gemId)
        if ok and td and td.lines then
            for _, ln in ipairs(td.lines) do
                local txt = ln.leftText
                if type(txt) == "string" and txt:find(ITEM_UNIQUE, 1, true) == 1 then
                    unique = true
                    break
                end
            end
        end
    end
    uniqueGemCache[gemId] = unique
    return unique
end
function WythicPlus_GearIsUniqueGem(gemId)
    return IsUniqueGem(gemId)
end

-- 아이템 링크의 소켓 보석 ID들 (item:id:enchant:gem1:gem2:gem3:gem4:...)
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

-- 착용 아이템의 보석 홈 수 = 빈 홈(GetItemStats의 EMPTY_SOCKET_*) + 낀 보석(링크 gem 필드). 링크 없으면 nil(미상).
-- 랭커 보석 데이터는 "홈을 뚫은 랭커"의 부위(손목·허리·머리 등)에도 생기므로, 내 아이템에 홈이 없으면
-- 그 부위 보석 추천·"보석 선택" 줄을 내지 않는다 (2026-09-12 지적 — 손목에 홈이 없는데 보석 추천).
local function SocketCount(link)
    if not link then return nil end
    local n = #linkGemIds(link)
    local ok, st = pcall(C_Item.GetItemStats, link)
    if ok and type(st) == "table" then
        for k, v in pairs(st) do
            if type(k) == "string" and k:find("^EMPTY_SOCKET_") then n = n + (tonumber(v) or 0) end
        end
    end
    return n
end
function WythicPlus_GearSocketCount(link)
    return SocketCount(link)
end

-- 데이터 items 엔트리 → 코어 PreparedItem
-- [1]=id [2]=count [3]=ilvl [4..7]=c/h/m/v [8]=2h [9]=embel [10]=set_name [11]=bonus [12]=conv [13]=변환 원본 ID
-- 맹독저주 착효템(데이터 venom.items, 시즌 상수) → 코어 우선 착용 규칙(2.5단계)의 is_priority 플래그.
local function IsPriorityItemId(itemId)
    local v = WythicPlusGearData and WythicPlusGearData.venom
    return (v and v.items and itemId and v.items[itemId]) ~= nil
end

-- 아이템 링크의 modifier 64 = 원본 스탯 계승(마나용제로 변환한 티어가 물려받은 원본 아이템 ID).
-- 링크 구조: item:id:ench:g1:g2:g3:g4:...:numBonus:<보너스들>:numModifier:<타입:값 쌍들>
local function LinkRedirectSourceId(link)
    if not link then return nil end
    local body = link:match("item:([%-%d:]+)")
    if not body then return nil end
    local t = {}
    for f in (body .. ":"):gmatch("([^:]*):") do t[#t + 1] = f end
    local nb = tonumber(t[13]) or 0
    local nm = tonumber(t[14 + nb]) or 0
    for mi = 0, nm - 1 do
        if t[15 + nb + mi * 2] == "64" then return tonumber(t[16 + nb + mi * 2]) end
    end
    return nil
end

-- 우선 아이템 판정(링크 기준). 마나용제로 티어가 된 맹독저주 조각은 **아이템 ID가 티어 것**이라
-- ID만 보면 못 잡는다. 변환 티어는 원본의 단일 2차 배분과 착용 효과를 그대로 물려받으므로 proc 가치는
-- 원본과 같고, 게임은 그 계승을 링크 modifier 64로 표현한다. 그래서 원본 ID까지 본다.
-- (2026-09-21 제보: 혈기 다리 변환 사본이 우선 추천되지 않던 문제)
local function IsPriorityItem(itemId, link)
    if IsPriorityItemId(itemId) then return true end
    return IsPriorityItemId(LinkRedirectSourceId(link))
end
function WythicPlus_GearIsPriorityItem(itemId, link)
    return IsPriorityItem(itemId, link)
end

local function toPreparedItems(items)
    local pop = {}
    if items then
        for slotKey, list in pairs(items) do
            local arr = {}
            for i = 1, #list do
                local e = list[i]
                arr[i] = {
                    item_id = e[1],
                    item_level = e[3] or 0,
                    stats = { crit = e[4] or 0, haste = e[5] or 0, mastery = e[6] or 0, versatility = e[7] or 0 },
                    is_two_hand = (e[8] == 1),
                    is_embellished = (e[9] == 1),
                    set_name = e[10],
                    is_priority = IsPriorityItemId(e[1]) or IsPriorityItemId(tonumber(e[13])),
                }
            end
            pop[slotKey] = arr
        end
    end
    return pop
end

-- ── 최적화 설정 (설정 창 「장비 최적화」 섹션, WythicPlusDB.gear 계정 저장) ────────────────────────────
-- 알고리즘 상수 중 유저가 조절할 만한 것만 노출한다(2026-09-13 요청). 없으면 기본값.
--   downTol       가방 기준에서 방어구·장신구 후보로 볼 "착용 대비 허용 하락폭"(ilvl). 기본 13 = 강화 한 단계.
--   weaponDownTol 무기 허용 하락폭. 무기는 ilvl이 지배적이라 기본 0(착용 이상만).
--   catalyst      마나용제 변환 가정 후보 생성 여부.
local GEAR_OPTION_DEFAULTS = { downTol = 13, weaponDownTol = 0, catalyst = true }
function WythicPlus_GearOption(key)
    local db = WythicPlusDB and WythicPlusDB.gear
    local v = db and db[key]
    if v == nil then return GEAR_OPTION_DEFAULTS[key] end
    return v
end
function WythicPlus_GearOptionDefault(key)
    return GEAR_OPTION_DEFAULTS[key]
end
function WythicPlus_SetGearOption(key, value)
    if not WythicPlusDB then return end
    WythicPlusDB.gear = WythicPlusDB.gear or {}
    WythicPlusDB.gear[key] = value
    if WythicPlus_GearRedraw then WythicPlus_GearRedraw() end -- 열려 있는 장비 창 즉시 재계산
end

-- ── 마나용제(촉매) 변환 가정 ──────────────────────────────────────────────────
-- 시즌2(12.1) 촉매 충전 화폐 = 3465 "맹독역병 마나용제"(Venomblight Manaflux; Wowhead currency=3465, 2026-09-13 확인).
-- 시즌마다 바뀐다(시즌1은 3378 새벽빛 마나용제). 결정화된 맹독역병 마나용제(아이템 274707)는 사용해야
-- 화폐가 되므로 세지 않는다.
local CATALYST_CURRENCY_ID = 3465
-- 촉매로 세트 조각이 되는 부위 — 티어 방어구 5부위만 (손목·허리·신발·망토 변환은 외형만, 세트 효과 없음)
local TIER_SLOT_ORDER = { "HEAD", "SHOULDER", "CHEST", "HANDS", "LEGS" }
local TIER_SLOTS = {}
for _, k in ipairs(TIER_SLOT_ORDER) do TIER_SLOTS[k] = true end

local function CatalystCharges()
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return 0 end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, CATALYST_CURRENCY_ID)
    return (ok and type(info) == "table" and tonumber(info.quantity)) or 0
end
-- UI용: 마나용제 아이콘(fileID)·보유 수·인게임 이름 (칩 "세트 변환 필요" 앞 아이콘, 툴팁 줄)
function WythicPlus_GearCatalystInfo()
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, CATALYST_CURRENCY_ID)
    if ok and type(info) == "table" then return info.iconFileID, tonumber(info.quantity) or 0, info.name end
    return nil
end

-- 이 아이템을 촉매에 넣을 수 있는가 — 게임 판정 그대로(시즌·출처·제작 여부를 클라이언트가 안다). 실패/미지원 = 불가.
local function IsConvertibleLoc(loc)
    if not (loc and C_Item and C_Item.IsItemConvertibleAndValidForPlayer) then return false end
    local ok, res = pcall(C_Item.IsItemConvertibleAndValidForPlayer, loc)
    return ok and res == true
end

-- 부위별 변환 후보 중 하나 고르기 — 최고 ilvl, 동률이면 착용 중인 것(교체 없이 변환만).
-- 스탯 거리는 보지 않는다 — 코어 2단계가 티어를 거리 무시로 강제 배치하므로 여기서 고른 것이 그대로 간다.
local function BestConvCand(list)
    local best
    for i = 1, #(list or {}) do
        local c = list[i]
        if not best or (c.ilvl or 0) > (best.ilvl or 0)
            or ((c.ilvl or 0) == (best.ilvl or 0) and c.worn and not best.worn) then
            best = c
        end
    end
    return best
end

-- 변환 계획 (순수 함수 — tests/catalyst-convert.test.lua 가 미러링, 변경 시 함께 갱신).
-- p = { charges, wornTierCount, wornTierSlots={slot→true}, realBagTierSlots={slot→true},
--       cands={slot→후보}, metaRank={slot→그 부위 티어의 메타 순위} }
-- 보유 = 착용 조각 + 가방 실물 티어(착용 부위 제외). 세트 보너스는 2/4에서만 생기므로
-- 보유+용제로 닿는 가장 높은 문턱(4 → 2)까지만 변환한다. 문턱에 못 닿으면 변환하지 않는다
-- (보너스 없이 스탯만 바뀔 수 있으므로). 4 초과 변환도 없다.
-- 우선순위: 랭커가 티어를 끼는 부위(메타 순위 낮은 수) → 후보 ilvl 높은 순 → 부위 고정 순서.
local function PlanConversions(p)
    local realBag = 0
    for slot in pairs(p.realBagTierSlots or {}) do
        if not (p.wornTierSlots and p.wornTierSlots[slot]) then realBag = realBag + 1 end
    end
    local have = (p.wornTierCount or 0) + realBag
    local reach = have + (p.charges or 0)
    local target = (reach >= 4 and 4) or (reach >= 2 and 2) or 0
    local need = target - have
    if need <= 0 then return {} end
    local list = {}
    for _, slot in ipairs(TIER_SLOT_ORDER) do
        local c = p.cands and p.cands[slot]
        if c and not (p.wornTierSlots and p.wornTierSlots[slot])
            and not (p.realBagTierSlots and p.realBagTierSlots[slot]) then
            list[#list + 1] = { slot = slot, cand = c, rank = (p.metaRank and p.metaRank[slot]) or 999, order = #list + 1 }
        end
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if (a.cand.ilvl or 0) ~= (b.cand.ilvl or 0) then return (a.cand.ilvl or 0) > (b.cand.ilvl or 0) end
        return a.order < b.order
    end)
    local out = {}
    for i = 1, math.min(need, #list) do out[i] = list[i] end
    return out
end

-- 보유템 최적화 후보 — 가방 실물 아이템을 실제 링크 스탯으로 코어 후보화.
-- set_name은 메타 목록의 같은 item_id에서 차용 (티어 4세트 유지 로직용). 같은 아이템 중복 소지 시 높은 ilvl만.
-- 2차 스탯 배분 서명(5% 버킷) — 같은 아이템 ID의 실물 구분용. 총량 0이면 "0"
local function SplitSig(st)
    local total = 0
    for _, k in ipairs(SECONDARY) do total = total + (st[k] or 0) end
    if total <= 0 then return "0" end
    local parts = {}
    for i, k in ipairs(SECONDARY) do parts[i] = tostring(math.floor((st[k] or 0) / total * 20 + 0.5)) end
    return table.concat(parts, ":")
end

-- 링크의 보석 필드(gem1~4)만 비운 링크. GetItemStats는 보석·마법부여를 뺀 기본 스탯을 돌려준다(Wowpedia API_GetItemStats).
-- 그래도 보석을 뗀 링크로 읽어, API가 보석을 합쳐 주는 경우까지 아이템 자체의 2차 스탯이 나오게 한다.
local function stripGemsFromLink(link)
    if not link then return nil end
    local out = link:gsub("(item:%d+:%d*):%d*:%d*:%d*:%d*", "%1::::", 1)
    return out
end

-- 링크의 보석 ID들을 랭커 보석 사전으로 합산. 사전은 그 스펙 랭커가 쓴 보석만 담고 일부는 스탯이 빈 {} 다.
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

-- 착용템의 보석 제외 2차 스탯(+보석 스탯). 코어 PreparedEquip.stats와 같은 기준. 착용템을 후보 풀에 넣을 때도
-- 이 값을 써야 코어가 "같은 실물"(ID·ilvl·스탯 동일 = 유지)로 알아본다.
-- 아이템 자체 스탯은 보석 필드(gem1~4)를 비운 링크를 GetItemStats로 읽은 값이다(보석 유무와 무관한 순수 스탯).
-- 이전엔 GetItemStats가 보석을 합쳐 준다고 잘못 가정해 원 링크 총량에서 사전 보석 값을 뺐고, 보석만큼 덜 잡힌 스탯이 되어
-- 홈 없는 같은 아이템 가방 사본(순수 스탯)과 다른 실물로 갈려 그 사본이 교체 추천됐다(2026-09-21 허리 제보:
-- 특화 83 착용템이 67로 잡혀 특화 83 사본이 후보가 되고, 가속 7이 빠지는 쪽이 거리가 줄어 추천).
-- 보석 스탯은 총량과 무보석의 차이가 있으면 그 차이(실측), 차이가 없으면 사전 값. 무보석 링크를 못 읽으면 기존 사전 차감.
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

local function toOwnedItems(spec, bagBySlot)
    local setNames = {}
    local tierBySlot = {} -- 티어 부위 → { id, setName, rank } (마나용제 변환 가정의 대상)
    -- 슬롯별 허용 아이템 타입(classID:subclassID) — 메타 랭커가 실제 쓰는 타입만 후보 허용.
    -- 방어구 재질(천/가죽/사슬/판금)·무기 숙련(방패 등 착용 불가) 오추천을 원천 차단한다.
    local allowedTypes = {}
    for slotKey, list in pairs((spec and spec.items) or {}) do
        local m = allowedTypes[slotKey] or {}
        allowedTypes[slotKey] = m
        for i = 1, #list do
            local e = list[i]
            if e[10] then setNames[e[1]] = e[10] end
            -- 부위별 "일반" 티어(conv 없음) — 첫 등장 = 그 부위에서의 메타 순위
            if TIER_SLOTS[slotKey] and e[10] and e[10] ~= "" and (e[12] == nil or e[12] == "") and not tierBySlot[slotKey] then
                tierBySlot[slotKey] = { id = e[1], setName = e[10], rank = i }
            end
            local _, _, _, _, _, cid, sid = C_Item.GetItemInfoInstant(e[1])
            if cid then m[cid .. ":" .. (sid or 0)] = true end
        end
    end
    -- 다운그레이드 가드: 방어구는 착용-13(한 강화 단계)까지만 허용 — 2차 스탯이 맞으면 약간의
    -- 템렙 하락은 이득일 수 있다. 무기는 ilvl이 지배적이라 착용 이상만 허용.
    -- (같은 아이템 중복 소지는 아래에서 최고 ilvl만 남김)
    local wornIlvl = {}
    -- 착용 세트 집계 — 4조각 이상이면 그 부위 교체를 막아 세트 효과를 지킨다
    -- (코어의 티어 유지는 "후보 풀의 티어" 기준이라 소지품 모드에선 착용 세트를 모른다)
    local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local function itemSetIdOf(link)
        if not (link and getItemInfo) then return nil end
        local ok, sid = pcall(function() return select(16, getItemInfo(link)) end)
        if ok and sid and sid ~= 0 then return sid end
        return nil
    end
    local wornSetId, wornSetCount = {}, {}
    -- 세트 포화 판정용 집계는 **코어와 같은 식별자(메타 set_name)** 로 따로 센다.
    -- itemSetID(GetItemInfo 16번째)는 구 세트 시스템 값이라 현 시즌 티어에서 비는 경우가 있고,
    -- 코어 2단계는 set_name만 보므로 그쪽 기준으로 세야 판정이 어긋나지 않는다.
    local wornSetNameBySlot, wornSetNameCount = {}, {}
    local wornLinkBySlot, wornInvBySlot = {}, {}
    for _, slot in ipairs(SLOTS) do
        local link = GetInventoryItemLink("player", slot.inv)
        wornInvBySlot[slot.key] = slot.inv
        if link then
            wornLinkBySlot[slot.key] = link
            wornIlvl[slot.key] = C_Item.GetDetailedItemLevelInfo(link) or 0
            local sid = itemSetIdOf(link)
            if sid then
                wornSetId[slot.key] = sid
                wornSetCount[sid] = (wornSetCount[sid] or 0) + 1
            end
            local wid = tonumber(link:match("item:(%d+)"))
            local sname = wid and setNames[wid]
            if sname then
                wornSetNameBySlot[slot.key] = sname
                wornSetNameCount[sname] = (wornSetNameCount[sname] or 0) + 1
            end
        end
    end
    -- 시즌 ilvl 상한: 메타 최고 ilvl(+맹독저주)에 여유 20 — 이를 넘는 값은 구시대 아이템의
    -- 스케일링 오판독(예: 오리지널 장갑이 548로 읽힘)이므로 후보에서 배제한다.
    local seasonCeil = 0
    for _, list in pairs((spec and spec.items) or {}) do
        for i = 1, #list do
            if (list[i][3] or 0) > seasonCeil then seasonCeil = list[i][3] end
        end
    end
    local venomIlvl = WythicPlusGearData and WythicPlusGearData.venom and WythicPlusGearData.venom.ilvl or 0
    if venomIlvl > seasonCeil then seasonCeil = venomIlvl end
    seasonCeil = seasonCeil > 0 and (seasonCeil + 20) or math.huge

    local pop = {}
    local convCands = {} -- 티어 부위 → 촉매 가능 비티어 후보 목록 (가방 + 착용)
    local specIndex = GetSpecialization and GetSpecialization()
    local mySpecID = specIndex and GetSpecializationInfo(specIndex) or nil
    -- 판정 로그 (진단용): /run for _,l in ipairs(WythicPlusOwnedLog) do print(l) end
    WythicPlusOwnedLog = { "mySpecID=" .. tostring(mySpecID) }
    local function olog(slotKey, b, why)
        WythicPlusOwnedLog[#WythicPlusOwnedLog + 1] = slotKey .. " " .. tostring(b.itemId) .. " ilvl" .. tostring(b.ilvl) .. " → " .. why
    end
    for slotKey, list in pairs(bagBySlot or {}) do
        local isWeapon = (slotKey == "MAIN_HAND" or slotKey == "OFF_HAND")
        local downTol = tonumber(WythicPlus_GearOption(isWeapon and "weaponDownTol" or "downTol"))
            or GEAR_OPTION_DEFAULTS[isWeapon and "weaponDownTol" or "downTol"]
        local floor = (wornIlvl[slotKey] or 0) - downTol
        local allowed = allowedTypes[slotKey]
        local best = {}
        for i = 1, #list do
            local b = list[i]
            -- 실물 단위 키: 같은 ID라도 2차 배분이 다르면 다른 실물(착귀 무작위 능력치·촉매 변환 결과)이라 따로 남긴다.
            -- 같은 배분은 최고 ilvl 하나만(하위 사본은 지배됨). 이전엔 ID당 하나라 배분이 다른 사본이 사라졌다(2026-09-20)
            local st = linkSecondaryStats(b.link)
            local ikey = b.itemId .. "|" .. SplitSig(st)
            local prev = best[ikey]
            local _, _, _, equipLoc, _, cid, sid = C_Item.GetItemInfoInstant(b.link)
            -- 착용 적합성 판정:
            -- ① 아이템의 스펙 지정(GetItemSpecInfo — 블리자드 전리품 스펙 시스템)에 내 스펙이 있으면 허용.
            --    랭커가 안 쓰는 타입(도끼 메타의 둔기 등)이어도 같은 부위 합법템은 후보 유지.
            --    방패/타 재질처럼 내 스펙 지정이 없는 아이템은 여기서 배제된다.
            -- ② 스펙 지정이 아예 없는 범용 아이템만 메타 랭커 착용 타입(classID:subclassID) 폴백.
            local usable, why
            local specsOf = GetItemSpecInfo and GetItemSpecInfo(b.link)
            if type(specsOf) == "table" and #specsOf > 0 then
                usable = false
                for si = 1, #specsOf do
                    if specsOf[si] == mySpecID then
                        usable = true
                        break
                    end
                end
                why = usable and "스펙지정 일치" or ("스펙지정 불일치 {" .. table.concat(specsOf, ",") .. "}")
            else
                usable = (cid and allowed and allowed[cid .. ":" .. (sid or 0)]) and true or false
                why = (usable and "타입폴백 일치 " or "타입폴백 불일치 ")
                    .. tostring(cid) .. ":" .. tostring(sid)
                    .. (specsOf == nil and " (specInfo=nil)" or " (specInfo={})")
            end
            local wsid = wornSetId[slotKey]
            -- 정확히 4조각일 때만 보호. 5조각(잉여)이면 비티어 후보를 열어 두고 코어가 잉여만큼만 교체한다
            -- (코어 "잉여 티어" 규칙 — 5조각 착용자의 잉여 교체를 막아 자동 85.4 < 수동 90.9가 났던 2026-09-13 지적)
            local protectSet = wsid and (wornSetCount[wsid] or 0) == 4
            if not usable then
                olog(slotKey, b, "제외: " .. why)
            elseif protectSet and itemSetIdOf(b.link) ~= wsid then
                -- 착용 정확히 4세트인 조각 부위: 같은 세트 조각으로만 교체 허용 (세트 효과 보호)
                olog(slotKey, b, "제외: 착용 티어 4세트 보호")
            elseif (b.ilvl or 0) > seasonCeil then
                olog(slotKey, b, "제외: 시즌 상한 초과 (오판독 의심, 상한 " .. tostring(seasonCeil) .. ")")
            elseif (b.ilvl or 0) < floor then
                olog(slotKey, b, "제외: 다운그레이드 (착용 " .. tostring(wornIlvl[slotKey]) .. ", 허용 -" .. downTol .. ")")
            elseif not prev or (b.ilvl or 0) > prev.item_level then
                olog(slotKey, b, "후보 채택 (" .. why .. ")")
                -- 세트 포화 조각은 티어로 넘기지 않는다: 이미 4조각을 입고 있으면 세트 밖 부위에
                -- 다섯 번째 조각을 껴도 보너스가 늘지 않는데, 코어 2단계는 후보 풀에 티어가 있으면
                -- **거리를 보지 않고 강제 배치**한다(equippedTierCount를 후보 풀 기준으로 세는데
                -- 착용 4조각은 가방에 없어 0으로 잡힌다). 그래서 ilvl 낮은 티어 어깨가 밀려 들어와
                -- 메타 근접도가 85.9 → 85.1로 떨어지는 추천이 나왔다(2026-09-13 지적).
                -- set_name을 비우면 후보로는 남되 순수 스탯 그리디로만 평가된다 — 정말 이득이면
                -- 그때는 정상적으로 추천된다.
                local bSetName = setNames[b.itemId]
                local setSaturated = bSetName ~= nil
                    and (wornSetNameCount[bSetName] or 0) >= 4
                    and wornSetNameBySlot[slotKey] ~= bSetName
                if setSaturated then olog(slotKey, b, "티어 해제: 착용 4세트 포화 (세트 밖 부위)") end
                -- 마나용제 변환 후보: 티어 부위의 비티어 소지품 중 게임이 "촉매 가능"이라 판정하는 것
                if TIER_SLOTS[slotKey] and (bSetName == nil or bSetName == "") and b.bag ~= nil and b.slot ~= nil
                    and ItemLocation and IsConvertibleLoc(ItemLocation:CreateFromBagAndSlot(b.bag, b.slot)) then
                    convCands[slotKey] = convCands[slotKey] or {}
                    convCands[slotKey][#convCands[slotKey] + 1] = { itemId = b.itemId, link = b.link, ilvl = b.ilvl or 0, stats = st, worn = false }
                    olog(slotKey, b, "변환 후보 (촉매 가능)")
                end
                best[ikey] = {
                    item_id = b.itemId,
                    item_level = b.ilvl or 0,
                    stats = { crit = st.crit or 0, haste = st.haste or 0, mastery = st.mastery or 0, versatility = st.versatility or 0 },
                    is_two_hand = (equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"),
                    is_embellished = false,
                    set_name = (not setSaturated) and bSetName or nil,
                    is_priority = IsPriorityItem(b.itemId, b.link),
                    link = b.link, -- UI 표시용 (코어는 무시)
                }
            end
        end
        local arr = {}
        for _, e in pairs(best) do arr[#arr + 1] = e end
        -- 장신구는 스탯 시뮬에서 제외(프록 가치를 못 잼)라 "인기순 1위"로 고정된다.
        -- 소지품 모드에서 순수 ilvl 정렬이면 가방의 비메타 고ilvl 장신구가 착용 중인
        -- 메타/최적 장신구보다 위로 추천되는 문제 → 장신구만 메타 채용순위 우선, ilvl은 tiebreak.
        -- 가방에 메타 장신구가 없으면 전부 rank 999 → 기존 ilvl 정렬로 폴백(동작 불변).
        if slotKey == "TRINKET_1" or slotKey == "TRINKET_2" then
            -- 착용 중인 장신구 2개도 후보에 넣는다. 코어 장신구 단계는 후보 1순위를 "무조건 채택"하고
            -- 1순위가 착용템일 때만 유지로 판정하므로, 착용템이 풀에 없으면 가방에 장신구가 하나라도
            -- 있는 한 항상 교체 추천 → 착용하면 내려간 원래 템이 다시 추천되는 무한 핑퐁(2026-09-08 제보).
            -- 같은 아이템이 가방에 더 높은 ilvl로 있으면 그쪽을 남긴다(기존 최고 ilvl 규칙과 동일).
            for _, ws in ipairs(SLOTS) do
                if ws.key == "TRINKET_1" or ws.key == "TRINKET_2" then
                    local wlink = GetInventoryItemLink("player", ws.inv)
                    local wid = wlink and C_Item.GetItemInfoInstant(wlink)
                    if wid then
                        local wilvl = C_Item.GetDetailedItemLevelInfo(wlink) or 0
                        local dup
                        for i = 1, #arr do
                            if arr[i].item_id == wid then dup = i break end
                        end
                        if not dup or wilvl > arr[dup].item_level then
                            local st = wornBaseStats(wlink, WythicPlusGearData and WythicPlusGearData.gemStats)
                            local e = {
                                item_id = wid,
                                item_level = wilvl,
                                stats = { crit = st.crit or 0, haste = st.haste or 0, mastery = st.mastery or 0, versatility = st.versatility or 0 },
                                is_two_hand = false,
                                is_embellished = false,
                                set_name = setNames[wid],
                                link = wlink,
                            }
                            if dup then arr[dup] = e else arr[#arr + 1] = e end
                            olog(slotKey, { itemId = wid, ilvl = wilvl }, "후보 채택 (착용 " .. ws.key .. ")")
                        end
                    end
                end
            end
            local metaList = spec and spec.items and spec.items[slotKey]
            local function metaRankOf(id)
                if metaList then
                    for mi = 1, #metaList do
                        if metaList[mi][1] == id then return mi end
                    end
                end
                return 999
            end
            table.sort(arr, function(a, c)
                local ra, rc = metaRankOf(a.item_id), metaRankOf(c.item_id)
                if ra ~= rc then return ra < rc end
                return a.item_level > c.item_level
            end)
        else
            table.sort(arr, function(a, c) return a.item_level > c.item_level end)
        end
        pop[slotKey] = arr
    end

    -- ── 티어 부위 보강: 착용 티어 조각 + 마나용제 변환 가정 후보 ──
    -- 코어 2단계는 "후보 풀의 티어"만 본다(set_name 후보가 2부위 이상 최상위여야 티어 세트로 인식하고,
    -- equippedTierCount도 후보 풀 기준). 소지품 모드에선 착용 티어가 가방에 없어 세트 인식·개수 집계가
    -- 둘 다 빠졌다 → 착용 중인 티어 조각을 그 부위 후보로 넣어(착용 그대로 = 추천 없음) 코어가 실제 착용
    -- 개수를 세게 한다. 그 위에 마나용제가 있으면 촉매 가능한 비티어 아이템을 "변환 후 티어"(item_id=그 부위
    -- 티어, set_name=세트, 스탯·ilvl=원본 — 촉매 변환은 원본 2차 배분을 물려받는다)로 후보에 넣어 코어가
    -- 세트 문턱(2/4) 완성 경로를 추천하게 한다. 변환 개수는 PlanConversions가 용제 수·문턱으로 제한.
    local tierSetName
    do
        local cnt, bestN = {}, 0
        for _, t in pairs(tierBySlot) do cnt[t.setName] = (cnt[t.setName] or 0) + 1 end
        for name, n in pairs(cnt) do
            if n > bestN then tierSetName, bestN = name, n end
        end
    end
    if tierSetName then
        local wornTierSlots, realBagTierSlots, metaRank = {}, {}, {}
        for slotKey in pairs(TIER_SLOTS) do
            local t = tierBySlot[slotKey]
            if t and t.setName == tierSetName then metaRank[slotKey] = t.rank end
            if wornSetNameBySlot[slotKey] == tierSetName then wornTierSlots[slotKey] = true end
            for _, e in ipairs(pop[slotKey] or {}) do
                if e.set_name == tierSetName then realBagTierSlots[slotKey] = true end
            end
        end
        -- ① 착용 티어 조각을 후보로 (실측 스탯; 같은 아이템이 가방에 더 높은 ilvl로 있으면 그쪽 유지)
        for slotKey in pairs(wornTierSlots) do
            local wlink = wornLinkBySlot[slotKey]
            local wid = wlink and tonumber(wlink:match("item:(%d+)"))
            if wid then
                local arr = pop[slotKey] or {}
                pop[slotKey] = arr
                -- 가방의 같은 ID 사본(상위 ilvl·다른 배분)은 다른 실물이라 그대로 두고 착용 조각을 뒤에 덧붙인다(2026-09-20).
                -- 스탯은 보석 제외(코어 PreparedEquip과 같은 기준) → 코어가 "같은 실물 = 유지"로 알아보고 후보에서 뺀다.
                -- 어느 실물을 추천했는지는 코어 slotPicks가 알려주므로 가방 쪽만 남길 필요가 없다.
                local wilvl = wornIlvl[slotKey] or 0
                local same = false
                for i = 1, #arr do if arr[i].link == wlink then same = true end end
                if not same then
                    local st = wornBaseStats(wlink, WythicPlusGearData and WythicPlusGearData.gemStats)
                    arr[#arr + 1] = {
                        item_id = wid, item_level = wilvl,
                        stats = { crit = st.crit or 0, haste = st.haste or 0, mastery = st.mastery or 0, versatility = st.versatility or 0 },
                        is_two_hand = false, is_embellished = false, set_name = tierSetName, link = wlink,
                    }
                    olog(slotKey, { itemId = wid, ilvl = wilvl }, "후보 채택 (착용 티어 조각)")
                end
            end
        end
        -- ② 착용 중인 비티어(촉매 가능)도 변환 후보 — 교체 없이 변환만 하면 되는 가장 자연스러운 경로
        for slotKey in pairs(TIER_SLOTS) do
            local wlink = wornLinkBySlot[slotKey]
            if wlink and not wornTierSlots[slotKey] and ItemLocation
                and IsConvertibleLoc(ItemLocation:CreateFromEquipmentSlot(wornInvBySlot[slotKey])) then
                local wid = tonumber(wlink:match("item:(%d+)"))
                if wid then
                    convCands[slotKey] = convCands[slotKey] or {}
                    convCands[slotKey][#convCands[slotKey] + 1] = {
                        itemId = wid, link = wlink, ilvl = wornIlvl[slotKey] or 0, stats = linkSecondaryStats(wlink), worn = true,
                    }
                    olog(slotKey, { itemId = wid, ilvl = wornIlvl[slotKey] }, "변환 후보 (착용, 촉매 가능)")
                end
            end
        end
        -- ③ 계획 → 가상 "변환 후 티어" 후보 삽입
        local charges = (WythicPlus_GearOption("catalyst") ~= false) and CatalystCharges() or 0 -- 설정에서 꺼두면 변환 가정 없음
        local cands = {}
        for slotKey, list in pairs(convCands) do
            if tierBySlot[slotKey] and tierBySlot[slotKey].setName == tierSetName then cands[slotKey] = BestConvCand(list) end
        end
        local wornTierCount = wornSetNameCount[tierSetName] or 0
        local plan = PlanConversions({
            charges = charges, wornTierCount = wornTierCount,
            wornTierSlots = wornTierSlots, realBagTierSlots = realBagTierSlots, cands = cands, metaRank = metaRank,
        })
        WythicPlusOwnedLog[#WythicPlusOwnedLog + 1] = ("마나용제 %d개, 착용 티어 %d조각, 변환 계획 %d건"):format(charges, wornTierCount, #plan)
        for _, pl in ipairs(plan) do
            local t, c = tierBySlot[pl.slot], pl.cand
            local arr = pop[pl.slot] or {}
            pop[pl.slot] = arr
            arr[#arr + 1] = {
                item_id = t.id, item_level = c.ilvl,
                stats = { crit = c.stats.crit or 0, haste = c.stats.haste or 0, mastery = c.stats.mastery or 0, versatility = c.stats.versatility or 0 },
                is_two_hand = false, is_embellished = false, set_name = tierSetName,
                link = c.link, convFrom = c.itemId, convWorn = c.worn, -- UI용 원본 링크/ID (코어는 무시)
            }
            olog(pl.slot, { itemId = c.itemId, ilvl = c.ilvl }, ("변환 가정 → 티어 %d (메타 %d위)"):format(t.id, pl.rank))
        end
        -- 티어 부위는 세트 조각을 앞에 — 코어의 세트 인식은 각 부위 첫 후보의 set_name만 본다
        for slotKey in pairs(TIER_SLOTS) do
            local arr = pop[slotKey]
            if arr and #arr > 1 then
                table.sort(arr, function(a, c)
                    local at, ct = a.set_name == tierSetName, c.set_name == tierSetName
                    if at ~= ct then return at end
                    return a.item_level > c.item_level
                end)
            end
        end
    end
    return pop
end

-- 내 착용 장비 → 코어 PreparedEquip 목록
local function collectPreparedEquip(gemStatsDict, spec)
    local out = {}
    -- 착용템 세트명: 메타 목록(e[10])에서 같은 ID로 찾는다. 코어 0.5단계(무기+장신구 2세트 보호, 줄잔의 이빨)용.
    -- 메타 목록에 없는 세트템은 세트명을 모르니 보호도 없다.
    local setNameById = {}
    if spec and spec.items then
        for _, list in pairs(spec.items) do
            for i = 1, #list do
                local e = list[i]
                if e[10] and e[10] ~= "" then setNameById[e[1]] = e[10] end
            end
        end
    end
    for _, slot in ipairs(SLOTS) do
        local link = GetInventoryItemLink("player", slot.inv)
        if link then
            -- 보석 스탯 분리: GetItemStats는 보석 미포함(기본 스탯) → 아이템 스탯 + 사전 보석 스탯으로 stats/gem_stats 분리 (착용 후보 삽입과 같은 헬퍼)
            local base, gem = wornBaseStats(link, gemStatsDict)
            local ilvl = C_Item.GetDetailedItemLevelInfo(link) or 0
            local tr = trackOfIlvl(ilvl)
            local wornId = GetInventoryItemID("player", slot.inv)
            out[#out + 1] = {
                slot = slot.key,
                item_id = wornId,
                item_name = link:match("%[(.-)%]") or "",
                item_level = ilvl,
                stats = base,
                gem_stats = gem,
                is_embellished = false, -- 인게임 판별 불가 (툴팁 파싱 필요) — 장식 제약은 서버 메타 쪽만 적용
                is_priority = IsPriorityItem(wornId, link),
                set_name = setNameById[wornId],
                -- 트랙 역산 → 코어 upgradePriorities("같은 템인데 강화 덜 됨" 안내) 활성화
                upgrade_track = tr and tr.ko or nil,
                is_capped = (tr and ilvl >= tr.max) or false,
                track_max = tr and tr.max or nil,
            }
        elseif slot.key ~= "MAIN_HAND" and slot.key ~= "OFF_HAND" then
            -- 빈 슬롯: 코어가 "착용 슬롯만 교체 검토"하므로 0-스탯 더미를 넣어
            -- 벗은 부위(의도적 해제 포함)도 최고 후보가 정상 추천되게 한다.
            -- ⚠️ 무기 슬롯은 제외 — OFF_HAND 더미는 코어 1단계가 "보조 사용자"로 오인해
            -- 양손무기 유저에게 보조무기(심지어 양손무기)를 추천한다 (2026-09-06 제보).
            -- 웹과 동일하게 무기는 실착용 슬롯만 코어에 넘긴다.
            out[#out + 1] = {
                slot = slot.key,
                item_id = 0,
                item_name = "",
                item_level = 0,
                stats = {},
                gem_stats = {},
                is_embellished = false,
            }
        end
    end
    return out
end

-- 메타 레이팅·가중치 — gear-core simulateGearSetCore 내부와 동일 공식(노이즈 컷 + 평균 대비 가중).
-- 코어가 내부값을 노출하지 않아 핀 조정용으로만 복제. 공식 변경 시 gear-core.ts와 함께 갱신할 것.
local function MetaWeights(stats)
    local metaR, total = {}, 0
    for _, k in ipairs(SECONDARY) do
        metaR[k] = stats[k .. "_rating"] or stats[k] or 0
        total = total + metaR[k]
    end
    for _, k in ipairs(SECONDARY) do
        if total > 0 and metaR[k] / total < 0.01 then metaR[k] = 0 end
    end
    local clean = 0
    for _, k in ipairs(SECONDARY) do clean = clean + metaR[k] end
    local avg = clean / 4
    local w = {}
    for _, k in ipairs(SECONDARY) do w[k] = avg > 0 and metaR[k] / avg or 1 end
    return metaR, w
end

-- 인게임 % 재추정 — gear-core statRatios와 동일 공식 (핀 조정·프리셋 오버라이드 공용).
-- 실측 기울기(pctPerRating = 레이팅 기여 %/총 레이팅)가 있으면 선형 환산으로 정확.
-- 보간 폴백은 내 레이팅≈메타 평균이면 폭발한다 (반지 하나에 26%→9% 사고, 2026-09-06).
local function RecomputePct(r, stats)
    local curPct = r.currentPct
    local d = r.simRating - r.currentRating
    local simPct
    if r.pctPerRating and r.pctPerRating > 0 then
        simPct = curPct + d * r.pctPerRating
    elseif curPct > 0 and r.currentRating > 0 then
        -- 최후 폴백: 내 %÷내 레이팅 추정 기울기 — 방향이 뒤집힐 수 없다(단조).
        -- 과거 "메타 대비 보간"은 메타 %와 레이팅의 부호가 어긋나면(무전: 메타 %↓·레이팅↑)
        -- 레이팅이 줄어도 %가 40%로 튀는 출력을 냈다 (2026-09-06 사고 2건의 원인).
        simPct = curPct + d * (curPct / r.currentRating)
    else
        simPct = curPct
    end
    r.simPct = math.max(0, math.floor(simPct * 100 + 0.5) / 100)
end

-- 스탯 delta를 statRatios·finalDistance에 반영 (아이템 핀·보석 핀 공용)
local function ApplyDelta(Core, sim, spec, delta, gearAlso)
    local metaR, w = MetaWeights(spec.stats or {})
    local simMap = {}
    for _, r in ipairs(sim.statRatios) do
        r.simRating = r.simRating + (delta[r.stat] or 0)
        if gearAlso then r.gearOnlyRating = r.gearOnlyRating + (delta[r.stat] or 0) end
        simMap[r.stat] = r.simRating
        RecomputePct(r, spec.stats)
    end
    sim.finalDistance = math.floor(Core:calcWeightedDistance(simMap, metaR, w) * 10 + 0.5) / 10
end

-- Gear UI용 — 시뮬 결과에 아이템 스탯 차분 반영 (트랙 핀: 추천 아이템을 선택 트랙 ilvl 스탯으로 치환)
function WythicPlus_GearApplyDelta(sim, spec, delta)
    if not (Core and sim and sim.statRatios and spec) then return end
    ApplyDelta(Core, sim, spec, delta, true)
end

-- 핀(유저 커스텀 선택) 적용 — 웹 adjustSim과 동일하게 베이스 시뮬 결과 위에 차분 반영:
-- 추천을 핀 아이템으로 교체하고 statRatios·finalDistance를 재계산한다 (시뮬 재실행 없음).
local function ApplyPins(Core, sim, spec, pop, equip, pinned)
    local popStats = {} -- slot → itemId → stats
    local popIlvl = {} -- slot → itemId → 대표 ilvl (같은 착용템 트랙 업 판정용)
    local popTwoHand = {} -- itemId → 양손 여부 (무기 조합 검증용)
    for slot, arr in pairs(pop) do
        local m, mi = {}, {}
        for i = 1, #arr do
            m[arr[i].item_id] = arr[i].stats
            mi[arr[i].item_id] = arr[i].item_level
            if slot == "MAIN_HAND" or slot == "OFF_HAND" then
                popTwoHand[arr[i].item_id] = arr[i].is_two_hand or false
            end
        end
        popStats[slot] = m
        popIlvl[slot] = mi
    end
    local equipBySlot = {}
    for _, e in ipairs(equip) do equipBySlot[e.slot] = e end

    local delta = { crit = 0, haste = 0, mastery = 0, versatility = 0 }
    local changed = false
    for slot, pin in pairs(pinned) do
        -- pin: 숫자 = 메타 아이템(데이터 스탯), 테이블 = 가방 아이템 {item_id, stats(실제 링크)}
        local pinId = type(pin) == "table" and pin.item_id or pin
        local slotPop = popStats[slot]
        local pinStats = type(pin) == "table" and pin.stats or (slotPop and slotPop[pinId])
        local curRec = sim.slotRecommendations[slot]
        -- 같은 착용템(메타 핀): 대표 ilvl이 착용보다 높을 때만 차분 반영 — 낮거나 같으면 유지(no-op)
        local eqPre = equipBySlot[slot]
        if type(pin) ~= "table" and eqPre and eqPre.item_id == pinId then
            local repIlvl = popIlvl[slot] and popIlvl[slot][pinId]
            if not (repIlvl and repIlvl > (eqPre.item_level or 0)) then pinStats = nil end
        end
        if pinStats and curRec ~= pinId then
            -- 이전 선택(추천 아이템 또는 유지 중인 착용템+보석)의 스탯을 빼고 핀 스탯을 더한다
            local prev = {}
            if type(curRec) == "number" then
                prev = (slotPop and slotPop[curRec]) or {}
            else
                local eq = equipBySlot[slot]
                if eq then
                    for _, k in ipairs(SECONDARY) do
                        prev[k] = (eq.stats[k] or 0) + (eq.gem_stats[k] or 0)
                    end
                end
            end
            for _, k in ipairs(SECONDARY) do
                delta[k] = delta[k] + (pinStats[k] or 0) - (prev[k] or 0)
            end
            local eq = equipBySlot[slot]
            if eq and eq.item_id == pinId then
                sim.slotRecommendations[slot] = nil -- 착용템 선택 = 유지
            else
                sim.slotRecommendations[slot] = pinId
            end
            -- 쌍 슬롯 충돌 해소: 반대편 추천이 핀과 같은 아이템이면 그 추천을 취소하고
            -- 스탯을 원착용으로 롤백 (같은 고유템이 양쪽에 표시되던 버그 — 매트릭스 스캔 발견)
            local PAIR = { FINGER_1 = "FINGER_2", FINGER_2 = "FINGER_1",
                           TRINKET_1 = "TRINKET_2", TRINKET_2 = "TRINKET_1" }
            local other = PAIR[slot]
            if other and type(sim.slotRecommendations[other]) == "number"
                and sim.slotRecommendations[other] == pinId then
                local recStats = (popStats[other] and popStats[other][pinId]) or {}
                local backEq = equipBySlot[other]
                for _, k in ipairs(SECONDARY) do
                    local back = backEq and ((backEq.stats[k] or 0) + (backEq.gem_stats[k] or 0)) or 0
                    delta[k] = delta[k] - (recStats[k] or 0) + back
                end
                sim.slotRecommendations[other] = nil
            end
            changed = true
        end
    end
    -- 불가능 무기 조합 해소: 양손 주무기 핀 + 한손용 보조 추천(또는 그 반대)은 공존 불가.
    -- 남은 쪽 추천을 취소하고 스탯을 원착용으로 롤백 (매트릭스 스캔 발견 — 2026-09-06)
    local function cancelRec(slot)
        local rec = sim.slotRecommendations[slot]
        if type(rec) ~= "number" then return end
        local recStats = (popStats[slot] and popStats[slot][rec]) or {}
        local backEq = equipBySlot[slot]
        for _, k in ipairs(SECONDARY) do
            local back = backEq and ((backEq.stats[k] or 0) + (backEq.gem_stats[k] or 0)) or 0
            delta[k] = delta[k] - (recStats[k] or 0) + back
        end
        sim.slotRecommendations[slot] = nil
        changed = true
    end
    local mhPin = pinned.MAIN_HAND
    local mhPinId = type(mhPin) == "table" and mhPin.item_id or mhPin
    local ohPin = pinned.OFF_HAND
    local ohPinId = type(ohPin) == "table" and ohPin.item_id or ohPin
    local ohRec = sim.slotRecommendations.OFF_HAND
    if mhPinId and popTwoHand[mhPinId] and type(ohRec) == "number" and not popTwoHand[ohRec] then
        cancelRec("OFF_HAND") -- 양손 주무기 핀 → 한손용 보조 추천 취소
    end
    local mhRec = sim.slotRecommendations.MAIN_HAND
    if ohPinId and not popTwoHand[ohPinId] and type(mhRec) == "number" and popTwoHand[mhRec] then
        cancelRec("MAIN_HAND") -- 한손용 보조 핀 → 양손 주무기 추천 취소
    end
    if not changed then return end
    ApplyDelta(Core, sim, spec, delta, true)
end

-- 보석 핀 적용 — 시뮬 보석 추천(또는 유지 중인 착용 보석)을 핀 보석으로 교체하고 차분 반영
local function ApplyGemPins(Core2, sim, spec, equip, gemPins)
    local dict = (WythicPlusGearData and WythicPlusGearData.gemStats) or {}
    local equipBySlot = {}
    for _, e in ipairs(equip) do equipBySlot[e.slot] = e end
    local delta = { crit = 0, haste = 0, mastery = 0, versatility = 0 }
    local changed = false
    sim.gemPins = sim.gemPins or {}
    for slot, gid in pairs(gemPins) do
        -- gid 0 = 보석 해제(빈 홈) 핀 — 스탯 0으로 취급해 착용/추천 보석만큼 빠진다 (2026-09-12)
        local pinStats = (gid == 0) and {} or dict[gid]
        if pinStats then
            local prev = {}
            local gi = sim.gemRecommendations and sim.gemRecommendations[slot]
            if gi ~= nil and sim.gemIdsBySlot and sim.gemIdsBySlot[slot] and sim.gemIdsBySlot[slot][gi + 1] then
                prev = dict[sim.gemIdsBySlot[slot][gi + 1]] or {}
            elseif type(sim.slotRecommendations[slot]) ~= "number" then
                local eq = equipBySlot[slot]
                if eq then prev = eq.gem_stats end
            end
            for _, k in ipairs(SECONDARY) do
                delta[k] = delta[k] + (pinStats[k] or 0) - (prev[k] or 0)
            end
            if sim.gemRecommendations then sim.gemRecommendations[slot] = nil end -- 핀이 대체
            sim.gemPins[slot] = gid
            changed = true
        end
    end
    if changed then ApplyDelta(Core2, sim, spec, delta, false) end -- 보석은 gearOnly 제외 (웹 gemD와 동일)
end

-- 불가능 무기 조합 가드 (전 경로) — 최종 주무기가 양손이면 한손용 보조 추천을 취소한다.
-- 핀 경로는 ApplyPins가 자체 처리하지만, 레이드 필터 등으로 주무기 추천이 사라져
-- "착용 양손 + 보조 단독 추천"만 남는 무핀 경로가 있었다 (매트릭스 스캔 raidX:I4 — 2026-09-07).
local function GuardWeaponCombo(Core, sim, spec, pop, equip)
    local ohRec = sim.slotRecommendations and sim.slotRecommendations.OFF_HAND
    if type(ohRec) ~= "number" then return end
    local twoHand, ohStats = {}, nil
    for _, slot in ipairs({ "MAIN_HAND", "OFF_HAND" }) do
        for _, it in ipairs(pop[slot] or {}) do
            twoHand[it.item_id] = it.is_two_hand or false
            if slot == "OFF_HAND" and it.item_id == ohRec then ohStats = it.stats end
        end
    end
    local mhRec = sim.slotRecommendations.MAIN_HAND
    local finalMH2H
    if type(mhRec) == "number" then
        finalMH2H = twoHand[mhRec]
    else
        for _, e in ipairs(equip) do
            if e.slot == "MAIN_HAND" then finalMH2H = twoHand[e.item_id] end
        end
    end
    if not finalMH2H or twoHand[ohRec] then return end -- 합법 조합 (쌍양손 포함)
    -- 보조 추천 취소 + 스탯 롤백 (착용 보조가 있으면 그 수치로 복원)
    local delta = { crit = 0, haste = 0, mastery = 0, versatility = 0 }
    local backEq
    for _, e in ipairs(equip) do
        if e.slot == "OFF_HAND" then backEq = e end
    end
    for _, k in ipairs(SECONDARY) do
        local back = backEq and ((backEq.stats[k] or 0) + (backEq.gem_stats[k] or 0)) or 0
        delta[k] = delta[k] - ((ohStats and ohStats[k]) or 0) + back
    end
    sim.slotRecommendations.OFF_HAND = nil
    ApplyDelta(Core, sim, spec, delta, true)
end

-- 시뮬 실행. pinned = {슬롯키→핀} (숫자=메타 아이템, 테이블=가방/프리셋 아이템).
-- ratingsOverride = {stat→{sim,gear}} — 프리셋 적용 시 저장 시점 레이팅으로 동결
-- (시뮬 재실행의 보석 추천 편차로 목록 점수와 어긋나는 것 방지).
-- 반환: CoreSimResult + gemIdsBySlot(추천 보석 인덱스 → 실제 gemId)
-- equipOverride = {슬롯키 → PreparedEquip} — 소지품 모드 핀 고정용: 해당 슬롯을
-- "이미 착용 중"으로 치환해 코어가 그 스탯을 깔고 나머지 슬롯만 최적화하게 한다.
-- lockedSlots = {슬롯키 → true} — 부위 잠금: 후보/보석 풀을 제거해 착용 그대로 유지,
-- 코어는 그 부위 스탯을 깔고 나머지 슬롯만 메타를 추종한다 (Shift+클릭 잠금 기능).
local function RunSimulate(spec, pop, pinned, ratingsOverride, gemPins, pinPop, equipOverride, lockedSlots, coreOpts)
    local Core = WythicPlusGearCore
    local data = WythicPlusGearData
    -- 특수 아이템(맹독저주 우선·무기+장신구 세트) 추천의 "착용템 대비 허용 ilvl 하락폭"은 설정 창 값을 그대로 쓴다(2026-09-20 대표 지시).
    coreOpts = coreOpts or {}
    coreOpts.priorityIlvlTolerance = tonumber(WythicPlus_GearOption("downTol")) or GEAR_OPTION_DEFAULTS.downTol
    coreOpts.weaponIlvlTolerance = tonumber(WythicPlus_GearOption("weaponDownTol")) or GEAR_OPTION_DEFAULTS.weaponDownTol
    if lockedSlots then
        for slot in pairs(lockedSlots) do pop[slot] = nil end
    end
    local equip = collectPreparedEquip(data.gemStats, spec)
    if equipOverride then
        for slot, ov in pairs(equipOverride) do
            local replaced = false
            for i = 1, #equip do
                if equip[i].slot == slot then
                    equip[i] = ov
                    replaced = true
                    break
                end
            end
            if not replaced then equip[#equip + 1] = ov end
        end
    end
    -- 진단 덤프(옵트인, 2026-09-22): `/wythic dump` 로 켜면 코어에 실제로 들어가는 장신구 입력(착용·후보·핀·잠금·덮어쓰기)을
    -- SavedVariables에 남긴다. 재현 뒤 /reload 하면 WTF/.../WythicPlus.lua 에 기록돼 밖에서 읽을 수 있다. 장신구 2슬롯,
    -- 마지막 실행 1건. 인게임 증상이 유닛 테스트·골든벡터와 어긋날 때 코드 추론 대신 이걸 먼저 뜬다 — 장신구 치명타 0 사고에서
    -- 코드로 세운 가설 두 개가 빗나간 뒤 이 덤프 한 번으로 원인이 확정됐다.
    if WythicPlusDB and WythicPlusDB.debugTrinket then
        local function slim(e)
            if not e then return nil end
            local st = e.stats or {}
            return { id = e.item_id, ilvl = e.item_level, c = st.crit or 0, h = st.haste or 0, m = st.mastery or 0, v = st.versatility or 0,
                set = e.set_name, pri = e.is_priority and 1 or nil, link = e.link }
        end
        local dump = { at = date and date("%H:%M:%S") or "", owned = coreOpts.ownedMode and 1 or 0, equip = {}, pop = {}, pinned = {}, locked = {}, override = {} }
        for i = 1, #equip do
            local e = equip[i]
            if e.slot == "TRINKET_1" or e.slot == "TRINKET_2" then dump.equip[e.slot] = slim(e) end
        end
        for _, sk in ipairs({ "TRINKET_1", "TRINKET_2" }) do
            local arr = pop[sk]
            if arr then
                local out = {}
                for i = 1, #arr do out[i] = slim(arr[i]) end
                dump.pop[sk] = out
            end
            if pinned and pinned[sk] ~= nil then
                local pn = pinned[sk]
                dump.pinned[sk] = type(pn) == "table" and { id = pn.item_id, link = pn.link, ilvl = pn.ilvl, src = pn.srcTab } or pn
            end
            if lockedSlots and lockedSlots[sk] then dump.locked[sk] = 1 end
            if equipOverride and equipOverride[sk] then dump.override[sk] = slim(equipOverride[sk]) end
        end
        if WythicPlusDB then WythicPlusDB.debugTrinketSim = dump end
    end

    -- preparedGems: 슬롯별 [gemId,count] → {stats=...}; 인덱스→gemId 역맵 유지
    local preparedGems, gemIdsBySlot = nil, {}
    if spec.gems and data.gemStats then
        preparedGems = {}
        local invBySlot = {}
        for _, s in ipairs(SLOTS) do invBySlot[s.key] = s.inv end
        for slotKey, list in pairs(spec.gems) do
            -- 착용 아이템에 홈이 0개면 보석 추천 제외 (빈 슬롯·링크 미상은 기존대로 추천)
            local wlink = invBySlot[slotKey] and GetInventoryItemLink("player", invBySlot[slotKey])
            local sockets = SocketCount(wlink)
            local noSocket = sockets ~= nil and sockets == 0
            if not (lockedSlots and lockedSlots[slotKey]) and not noSocket then -- 잠긴 부위는 보석 추천도 제외
                local arr, ids = {}, {}
                for i = 1, #list do
                    local gid = list[i][1]
                    arr[i] = { stats = data.gemStats[gid] or {} }
                    ids[i] = gid
                end
                preparedGems[slotKey] = arr
                gemIdsBySlot[slotKey] = ids
            end
        end
    end

    local sim = Core:simulateGearSetCore(equip, pop, spec.stats, preparedGems, collectStats(), coreOpts)
    if sim then
        sim.gemIdsBySlot = gemIdsBySlot
        -- 다이아몬드(고유 장착) 보석은 전 부위 1개 — 중복 추천 시 한 슬롯만 남기고 수치 보정.
        -- 유저 핀 중에 고유 보석이 있으면 핀이 우선이라 추천 쪽 고유 보석은 전부 제거.
        if sim.gemRecommendations and data and data.gemStats then
            local kept = false
            if gemPins then
                for _, gid in pairs(gemPins) do
                    if IsUniqueGem(gid) then
                        kept = true
                        break
                    end
                end
            end
            local slots = {}
            for k in pairs(sim.gemRecommendations) do slots[#slots + 1] = k end
            table.sort(slots)
            local delta = { crit = 0, haste = 0, mastery = 0, versatility = 0 }
            local changed = false
            for _, k in ipairs(slots) do
                local gi = sim.gemRecommendations[k]
                local gid = gi ~= nil and gemIdsBySlot[k] and gemIdsBySlot[k][gi + 1] or nil
                if gid and IsUniqueGem(gid) then
                    if kept then
                        sim.gemRecommendations[k] = nil
                        local gs = data.gemStats[gid]
                        if gs then
                            for stat, v in pairs(gs) do delta[stat] = (delta[stat] or 0) - v end
                            changed = true
                        end
                    else
                        kept = true
                    end
                end
            end
            if changed then ApplyDelta(Core, sim, spec, delta, false) end
        end
        if pinned and next(pinned) then
            ApplyPins(Core, sim, spec, pinPop or pop, equip, pinned)
        end
        if gemPins and next(gemPins) then
            ApplyGemPins(Core, sim, spec, equip, gemPins)
        end
        GuardWeaponCombo(Core, sim, spec, pinPop or pop, equip)
        if ratingsOverride then
            local metaR, w = MetaWeights(spec.stats or {})
            local map = {}
            for _, r in ipairs(sim.statRatios) do
                local o = ratingsOverride[r.stat]
                if o then
                    r.simRating = o.sim
                    r.gearOnlyRating = o.gear
                    RecomputePct(r, spec.stats)
                end
                map[r.stat] = r.simRating
            end
            sim.finalDistance = math.floor(Core:calcWeightedDistance(map, metaR, w) * 10 + 0.5) / 10
        end
    end
    return sim
end

-- 핀 선고정 공용 헬퍼 — filter(slot)가 참인 핀을 "착용 치환(equipOverride)"으로 잠근다:
-- 그 슬롯 후보 풀을 비우고 핀 스탯을 baseline에 깔아, 코어가 나머지 슬롯만 최적화한다.
-- 소지품/메타 모두 모든 핀이 이 경로 — 핀을 깔아둔 상태에서 나머지 슬롯을 재최적화
-- (2차 스탯 테트리스). 스탯 조회 불가 핀만 사후 ApplyPins로 폴백.
-- 핀의 실효 스탯·ilvl. 링크 핀은 **시뮬 시점에 링크에서 다시 읽는다** — 핀 테이블의 stats/ilvl은 생성 시점
-- 스냅샷이라 아이템 미로딩·구버전 프리셋 등으로 비거나 낡을 수 있고, 그걸 그대로 "착용 중"으로 코어에 깔면
-- 증감은 0인데 화살표만 남는 화면이 된다(2026-09-22 장신구 제보: 고정 치명타 장신구가 치명타 0으로 들어감).
-- 링크에서 못 읽을 때만 스냅샷 → 메타/보유 풀 항목 순으로 폴백한다. 코어는 이 함수가 돌려준 값만 본다.
local function PinLiveStats(pin, src)
    local isTbl = type(pin) == "table"
    local link = isTbl and pin.link or nil
    local stats, ilvl
    if link then
        local live = linkSecondaryStats(link)
        if next(live) ~= nil then stats = live end
        ilvl = C_Item.GetDetailedItemLevelInfo(link)
    end
    stats = stats or (isTbl and pin.stats) or (src and src.stats)
    ilvl = ilvl or (isTbl and pin.ilvl) or (src and src.item_level) or 0
    return stats, ilvl, link
end
function WythicPlus_GearPinLiveStats(pin, src) return PinLiveStats(pin, src) end

-- 핀이 지금 착용한 실물 그 자체인가. 링크가 같으면 참. 가방→착용 이동 뒤엔 링크 문자열이 달라질 수 있어
-- 링크만 비교하면 "같은 것으로 바꾸라"는 유령 추천이 남으므로 ID·ilvl·2차 스탯이 전부 같아도 참으로 본다
-- (Redraw의 잔존 핀 정리 PinIsWornInstance와 같은 기준). 숫자 핀(메타 ID)은 ID만 같으면 착용으로 본다.
local function PinIsWorn(pinId, pinIlvl, pinStats, pinLink, rw)
    if not rw or rw.id ~= pinId then return false end
    if not pinLink then return true end
    if pinLink == rw.link then return true end
    if (rw.ilvl or 0) ~= (pinIlvl or 0) then return false end
    for _, k in ipairs(SECONDARY) do
        if ((pinStats and pinStats[k]) or 0) ~= ((rw.total and rw.total[k]) or 0) then return false end
    end
    return true
end
function WythicPlus_GearPinIsWorn(pinId, pinIlvl, pinStats, pinLink, rw) return PinIsWorn(pinId, pinIlvl, pinStats, pinLink, rw) end

local function LockPins(pop, pinPop, pinned, filter)
    if not (pinned and next(pinned)) then return pinned, nil, nil, nil end
    local pinIdx = {} -- slot → itemId → prepared (스탯/ilvl 조회)
    for slot, arr in pairs(pinPop) do
        local m = {}
        for i = 1, #arr do m[arr[i].item_id] = arr[i] end
        pinIdx[slot] = m
    end
    local realWorn = {} -- slotKey → {id, link, ilvl, total(무보석 기본 스탯)}
    for _, s in ipairs(SLOTS) do
        local link = GetInventoryItemLink("player", s.inv)
        if link then
            realWorn[s.key] = {
                id = GetInventoryItemID("player", s.inv), link = link,
                ilvl = C_Item.GetDetailedItemLevelInfo(link) or 0, total = linkSecondaryStats(link),
            }
        end
    end
    local runPinned, equipOverride, lockedRecs = {}, {}, {}
    local corr = { crit = 0, haste = 0, mastery = 0, versatility = 0 }
    local locked, remain = false, false
    for slot, pin in pairs(pinned) do
        local pinId = type(pin) == "table" and pin.item_id or pin
        local src = pinIdx[slot] and pinIdx[slot][pinId]
        local pinStats, pinIlvl, pinLink = PinLiveStats(pin, src)
        if (not filter or filter(slot)) and pinId and pinStats then
            equipOverride[slot] = {
                slot = slot, item_id = pinId, item_name = "",
                item_level = pinIlvl,
                stats = pinStats, gem_stats = {}, is_embellished = false,
            }
            pop[slot] = nil -- 후보 제거 = 이 슬롯 고정
            local rw = realWorn[slot]
            for _, k in ipairs(SECONDARY) do
                corr[k] = corr[k] + (pinStats[k] or 0) - ((rw and rw.total[k]) or 0)
            end
            -- 착용 실물 그 자체면 교체 추천을 내지 않는다. 다른 실물(가방 사본 등)이면 교체 추천으로 표시한다(2026-09-20)
            if not PinIsWorn(pinId, pinIlvl, pinStats, pinLink, rw) then lockedRecs[slot] = pinId end
            locked = true
        else
            runPinned[slot] = pin
            remain = true
        end
    end
    if not locked then return pinned, nil, nil, nil end
    -- 무기 조합 정합: 잠긴 핀이 무기면 반대편을 게임 규칙에 맞게 정리
    local function lockedPinTwoHand(slot)
        local ov = equipOverride[slot]
        if not ov then return nil end
        local orig = pinned[slot]
        if type(orig) == "table" and orig.link and C_Item and C_Item.GetItemInfoInstant then
            local _, _, _, eloc = C_Item.GetItemInfoInstant(orig.link)
            if eloc then
                return eloc == "INVTYPE_2HWEAPON" or eloc == "INVTYPE_RANGED" or eloc == "INVTYPE_RANGEDRIGHT"
            end
        end
        local src = pinIdx[slot] and pinIdx[slot][ov.item_id]
        return (src and src.is_two_hand) or false
    end
    local mh2h = lockedPinTwoHand("MAIN_HAND")
    if mh2h and not equipOverride.OFF_HAND then
        -- 양손 주무기 잠금 = 보조 없음: baseline에서 착용 보조를 빼고 보조 추천도 차단
        equipOverride.OFF_HAND = { slot = "OFF_HAND", item_id = 0, item_name = "",
            item_level = 0, stats = {}, gem_stats = {}, is_embellished = false }
        pop.OFF_HAND = nil
        local rw = realWorn.OFF_HAND
        if rw then
            for _, k in ipairs(SECONDARY) do corr[k] = corr[k] - (rw.total[k] or 0) end
        end
    end
    local oh2h = lockedPinTwoHand("OFF_HAND")
    if oh2h == false and equipOverride.OFF_HAND and equipOverride.OFF_HAND.item_id ~= 0 then
        -- 한손 보조 잠금: 주무기 후보에서 양손 무기를 걸러 불가능 조합 추천 차단
        local arr = pop.MAIN_HAND
        if arr then
            local kept = {}
            for i = 1, #arr do
                if not arr[i].is_two_hand then kept[#kept + 1] = arr[i] end
            end
            if #kept > 0 then pop.MAIN_HAND = kept else pop.MAIN_HAND = nil end
        end
    end
    if not remain then runPinned = nil end
    return runPinned, lockedRecs, corr, equipOverride
end

-- 선고정 결과 반영: 잠긴 핀을 추천으로 표기(착용 그대로면 생략)하고,
-- 코어 baseline이 핀 포함으로 계산됐으므로 "내 현재" 기준을 실착용으로 복원한다.
local function ApplyLockPostSim(sim, spec, lockedRecs, corr)
    if not (sim and lockedRecs) then return end
    local Core = WythicPlusGearCore
    for slot, id in pairs(lockedRecs) do sim.slotRecommendations[slot] = id end
    local anyCorr = false
    for _, k in ipairs(SECONDARY) do if corr[k] ~= 0 then anyCorr = true end end
    if anyCorr then
        local metaR, w = MetaWeights(spec.stats or {})
        local curMap = {}
        for _, r in ipairs(sim.statRatios) do
            r.currentRating = r.currentRating - (corr[r.stat] or 0)
            curMap[r.stat] = r.currentRating
            RecomputePct(r, spec.stats)
        end
        sim.originalDistance = math.floor(Core:calcWeightedDistance(curMap, metaR, w) * 10 + 0.5) / 10
    end
end

-- 시뮬 실행(메타 후보). pinned = {슬롯키→핀} (숫자=메타 아이템, 테이블=가방/프리셋 아이템).
-- lockedSlots = {슬롯키→true} 부위 잠금 — 잠긴 슬롯에 핀이 있으면 그 핀(가방 선택 포함)을
-- 선고정하고, 없으면 착용 그대로 유지한다.
function WythicPlus_GearSimulate(spec, pinned, ratingsOverride, gemPins, lockedSlots)
    if not (WythicPlusGearCore and spec) then return nil end
    local pop = toPreparedItems(spec.items)
    -- 소지품 모드와 동일하게 모든 핀을 선고정: 핀 스탯을 baseline에 깔고 나머지 슬롯을
    -- 그 위에서 재최적화한다 (핀으로 2차 스탯이 크게 바뀌면 다른 부위 추천도 따라 움직임).
    -- 이전엔 잠금 슬롯의 핀만 선고정이라, 일반 핀은 "핀 없는 셈 친 추천" 위에 얹혀
    -- 다른 부위가 반응하지 않았다 (2026-09-08 제보).
    local runPinned, lockedRecs, corr, equipOverride = LockPins(pop, pop, pinned, nil)
    local sim = RunSimulate(spec, pop, runPinned, ratingsOverride, gemPins, nil, equipOverride, lockedSlots)
    ApplyLockPostSim(sim, spec, lockedRecs, corr)
    return sim
end

-- 보유템 최적화 — 후보를 "가방 소지품"으로 제한해 같은 코어로 시뮬.
-- bagBySlot = {슬롯키 → {{itemId,link,ilvl}...}} (Gear UI 가방 스캔 결과).
-- 핀 스탯 조회는 메타+보유 병합(pinPop)이라 메타 아이템 핀도 수치에 반영된다.
function WythicPlus_GearSimulateOwned(spec, bagBySlot, pinned, ratingsOverride, gemPins, lockedSlots)
    if not (WythicPlusGearCore and spec) then return nil end
    local pop = toOwnedItems(spec, bagBySlot)
    local pinPop = {}
    local meta = toPreparedItems(spec.items)
    for slot, arr in pairs(meta) do
        local m = {}
        for i = 1, #arr do m[i] = arr[i] end
        pinPop[slot] = m
    end
    for slot, arr in pairs(pop) do
        pinPop[slot] = pinPop[slot] or {}
        local m = pinPop[slot]
        for i = 1, #arr do m[#m + 1] = arr[i] end -- 보유 항목이 뒤 → 같은 id면 실측 스탯 우선
    end
    -- 핀 선고정: 모든 핀 슬롯을 "착용 중"으로 치환하고 그 슬롯 후보 풀을 비운다 →
    -- 코어가 핀 스탯을 깔고 나머지 슬롯만 가방 후보로 메타를 추종한다.
    -- (기존 사후 ApplyPins 방식은 "핀이 없다는 가정"으로 다른 슬롯을 먼저 정해 어긋났음)
    local runPinned, lockedRecs, corr, equipOverride = LockPins(pop, pinPop, pinned, nil)
    -- ownedMode: 후보가 내 소지품이라 착용템과 같은 ID의 상위 ilvl 사본(예: 손 티어 308 착용, 가방 311)을
    -- 코어가 "이미 착용"으로 넘기지 않고 교체 후보로 본다(2026-09-19).
    local sim = RunSimulate(spec, pop, runPinned, ratingsOverride, gemPins, pinPop, equipOverride, lockedSlots, { ownedMode = true })
    ApplyLockPostSim(sim, spec, lockedRecs, corr)
    if sim then
        sim.ownedMode = true
        sim.ownedLinks = {}
        for slot, rid in pairs(sim.slotRecommendations or {}) do
            if type(rid) == "number" and pop[slot] then
                -- 코어가 고른 후보 객체(slotPicks)로 실물을 특정한다 — 같은 ID의 사본이 여럿이면 첫 ID 매치는 틀릴 수 있다
                local pick = sim.slotPicks and sim.slotPicks[slot]
                local e = (pick and pick.item_id == rid and pick.link) and pick or nil
                if not e then
                    for _, c in ipairs(pop[slot]) do
                        if c.item_id == rid then e = c break end
                    end
                end
                if e then
                    sim.ownedLinks[slot] = { link = e.link, ilvl = e.item_level, convFrom = e.convFrom, convWorn = e.convWorn }
                end
            end
        end
    end
    return sim
end

-- 가방 아이템 핀용 — 아이템 링크의 2차 스탯 추출 (입력층 공용, Gear UI가 사용)
function WythicPlus_GearLinkStats(link)
    return linkSecondaryStats(link)
end

-- 프리셋 스냅샷용 — 아이템 링크의 소켓 보석 ID 목록
-- SimC 프로필용 — 활성 특성 로드아웃 코드 (Raidbots 내보내기)
function WythicPlus_GearTalentCode()
    return collectTalentCode()
end

function WythicPlus_GearLinkGems(link)
    return linkGemIds(link)
end

-- 최적화 OFF 커스텀 모드 — 그리디 추천 없이 "착용 장비 + 유저 핀 차분"만 계산.
-- 반환 형태는 CoreSimResult 호환(+customOnly 플래그) — Gear UI가 동일 경로로 렌더.
function WythicPlus_GearCustomOnly(spec, pinned, gemPins)
    if not (Core and spec) then return nil end
    local data = WythicPlusGearData
    local equip = collectPreparedEquip(data.gemStats, spec)
    local metaR, w = MetaWeights(spec.stats or {})

    local actual = { crit = 0, haste = 0, mastery = 0, versatility = 0 }
    local equipBySlot = {}
    for _, e in ipairs(equip) do
        equipBySlot[e.slot] = e
        for _, k in ipairs(SECONDARY) do
            actual[k] = actual[k] + (e.stats[k] or 0) + (e.gem_stats[k] or 0)
        end
    end
    local originalDistance = Core:calcWeightedDistance(actual, metaR, w)

    local simR, gearR = {}, {} -- simR = 장비+보석 반영, gearR = 장비 핀만 (UI 장비/보석 델타 분리용)
    for _, k in ipairs(SECONDARY) do
        simR[k] = actual[k]
        gearR[k] = actual[k]
    end

    -- 메타 핀 스탯 조회용
    local pop = toPreparedItems(spec.items)
    local popStats = {}
    for slot, arr in pairs(pop) do
        local m = {}
        for i = 1, #arr do m[arr[i].item_id] = arr[i].stats end
        popStats[slot] = m
    end

    local recs = {}
    for slot, pin in pairs(pinned or {}) do
        local pinId = type(pin) == "table" and pin.item_id or pin
        local pinStats = type(pin) == "table" and pin.stats or (popStats[slot] and popStats[slot][pinId])
        local eq = equipBySlot[slot]
        -- 같은 착용템(메타 핀): 대표 ilvl이 착용보다 높을 때만(트랙 업 여지) 대표 스탯 차분 반영
        local sameWorn = eq and eq.item_id == pinId
        if sameWorn and type(pin) ~= "table" then
            local repIlvl
            for i = 1, #(pop[slot] or {}) do
                if pop[slot][i].item_id == pinId then
                    repIlvl = pop[slot][i].item_level
                    break
                end
            end
            if not (repIlvl and repIlvl > (eq.item_level or 0)) then pinStats = nil end
        elseif sameWorn then
            pinStats = nil -- 가방 핀이 착용템 그대로면 차분 없음
        end
        if pinStats then
            local prev = {}
            if eq then
                for _, k in ipairs(SECONDARY) do
                    prev[k] = (eq.stats[k] or 0) + (eq.gem_stats[k] or 0)
                end
            end
            for _, k in ipairs(SECONDARY) do
                local d = (pinStats[k] or 0) - (prev[k] or 0)
                simR[k] = simR[k] + d
                gearR[k] = gearR[k] + d
            end
            if not sameWorn then recs[slot] = pinId end
        end
    end

    -- 보석 핀 (착용 보석 대비 차분)
    local gemPinsOut = {}
    local gemDict = data.gemStats or {}
    for slot, gid in pairs(gemPins or {}) do
        local pinStats = (gid == 0) and {} or gemDict[gid] -- 0 = 보석 해제(빈 홈)
        if pinStats then
            local eq = equipBySlot[slot]
            local prev = (eq and eq.gem_stats) or {}
            for _, k in ipairs(SECONDARY) do
                simR[k] = simR[k] + (pinStats[k] or 0) - (prev[k] or 0)
            end
            gemPinsOut[slot] = gid
        end
    end

    local blz, blzSlope = {}, {}
    for _, s in ipairs(collectStats()) do
        blz[s.stat_name] = s.stat_value
        -- 실측 환산 기울기 — 이게 빠지면 RecomputePct가 폴백으로 떨어진다
        -- (v1.6.4에서 최적화 경로만 싣고 커스텀 경로를 빠뜨려 40% 표시 사고, 2026-09-06)
        if s.stat_rating and s.stat_rating_bonus and s.stat_rating > 0 and s.stat_rating_bonus > 0 then
            blzSlope[s.stat_name] = s.stat_rating_bonus / s.stat_rating
        end
    end
    local ratios = {}
    for _, k in ipairs(SECONDARY) do
        local r = {
            stat = k, currentRating = actual[k], gearOnlyRating = gearR[k], simRating = simR[k],
            currentPct = math.floor((blz[k] or 0) * 100 + 0.5) / 100,
            metaPct = math.floor(((spec.stats and spec.stats[k]) or 0) * 100 + 0.5) / 100,
            pctPerRating = blzSlope[k],
        }
        RecomputePct(r, spec.stats)
        ratios[#ratios + 1] = r
    end

    return {
        slotRecommendations = recs,
        gemRecommendations = {},
        gemIdsBySlot = {},
        finalDistance = math.floor(Core:calcWeightedDistance(simR, metaR, w) * 10 + 0.5) / 10,
        originalDistance = math.floor(originalDistance * 10 + 0.5) / 10,
        statRatios = ratios,
        upgradePriorities = {},
        gemPins = gemPinsOut,
        customOnly = true,
    }
end
