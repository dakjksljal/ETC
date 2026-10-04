-- 스모크 테스트: 제작 탭 데이터·링크·수치 (node fengari 러너 또는 luajit tests/craft-pin.test.lua)
-- WythicPlusGear.lua 의 ApplyEmbellish / CraftLink / CraftStats / EmbApplies / EnchantStatsById 를 미러링한다 (WoW API 의존 → 스텁).
-- ⚠️ 아래 두 함수는 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 규칙: 제작템 2차 스탯은 유저가 고른다(아이템마다 1~2개, 0 = 고정). 링크 modifier 29/30 = 제작 스탯 1/2(ITEM_MOD 스탯 ID).
-- 수치 = 최고 품질 ilvl의 2차 스탯 예산(툴팁 자리표시자 합)을 지정 스탯에 균등 배분.

local root = (arg and arg[0] and arg[0]:match("^(.*)tests[/\\]")) or "./"
dofile(root .. "WythicPlusCraftData.lua")
local cd = WythicPlusCraftData

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

-- ── 데이터 무결성 ──
local count, bad, byN = 0, 0, { [0] = 0, [1] = 0, [2] = 0 }
for id, e in pairs(cd.items) do
    count = count + 1
    if type(id) ~= "number" or type(e.inv) ~= "number" or e.inv <= 0 or type(e.specs) ~= "table"
        or not (e.n == 0 or e.n == 1 or e.n == 2) then
        bad = bad + 1
    else
        byN[e.n] = byN[e.n] + 1
    end
end
check("데이터: 제작 장비 50종 이상", count >= 50)
check("데이터: 모든 항목 필드 유효", bad == 0)
check("데이터: 2스탯 선택형 존재", byN[2] > 0)
check("데이터: 스탯 고정형 존재", byN[0] > 0)
check("데이터: 최고 품질 ilvl", type(cd.ilvl) == "number" and cd.ilvl > 0)
check("데이터: 스탯 ID 4종", cd.statIds.crit == 32 and cd.statIds.haste == 36 and cd.statIds.mastery == 49 and cd.statIds.versatility == 40)
check("데이터: 보너스 템플릿", type(cd.bonus.std) == "string" and type(cd.bonus.twoHand) == "string")

-- ── 미러: 링크·수치 ──
local STAT_ORDER = { "crit", "haste", "mastery", "versatility" }
local META_BONUS = {}   -- itemId → 랭커 최고 품질 보너스 (원본 CraftBonuses의 메타 조회 결과 대용)
local LINK_STATS = {}   -- link → GetItemStats 2차 스탯 (조립 링크는 보통 비어 있음 — 자리표시자)
local LINK_BUDGET = {}  -- link → 툴팁 2차 스탯 줄 합 (자리표시자 포함)
local SPEC = "250"

local function CraftInfo(itemId) return cd.items[itemId] end
local function CraftBonuses(itemId)
    if META_BONUS[itemId] then return META_BONUS[itemId] end
    local info = CraftInfo(itemId)
    return (info and cd.twoHandInv and cd.twoHandInv[info.inv]) and cd.bonus.twoHand or cd.bonus.std
end
local function ApplyEmbellish(bonuses, emb)
    if emb == nil then return bonuses end
    local kept = {}
    for b in bonuses:gmatch("[^:]+") do
        local n = tonumber(b)
        if not ((cd.embellishMarkers and cd.embellishMarkers[n]) or (cd.embellishments and cd.embellishments[n])) then
            kept[#kept + 1] = b
        end
    end
    if emb ~= 0 then
        kept[#kept + 1] = "8960"
        kept[#kept + 1] = tostring(emb)
    end
    return table.concat(kept, ":")
end
local function CraftLink(itemId, keys, emb)
    local info = CraftInfo(itemId)
    if not info then return nil end
    local bonuses = CraftBonuses(itemId)
    if (info.n or 0) > 0 then bonuses = ApplyEmbellish(bonuses, emb) end
    local nb = 1 + select(2, bonuses:gsub(":", ""))
    local mods = {}
    for i = 1, math.min(info.n or 0, 2) do
        local sid = keys and keys[i] and cd.statIds[keys[i]]
        if sid then mods[#mods + 1] = (i == 1 and "29:" or "30:") .. sid end
    end
    local tail = #mods > 0 and (":" .. #mods .. ":" .. table.concat(mods, ":")) or ""
    return ("item:%d:::::::::%s:::%d:%s%s"):format(itemId, SPEC, nb, bonuses, tail)
end
local function LinkSecondaryBudget(link) return {}, LINK_BUDGET[link] or 0 end
local function CraftStats(itemId, link, keys)
    local info = CraftInfo(itemId)
    if not (info and link) then return nil end
    local n = info.n or 0
    local st = LINK_STATS[link] or {}
    local total = 0
    for _, k in ipairs(STAT_ORDER) do total = total + (st[k] or 0) end
    if n == 0 then
        if total > 0 then return st end
        local shown = LinkSecondaryBudget(link)
        return next(shown) ~= nil and shown or nil
    end
    if not keys or #keys < n then return nil end
    if total <= 0 then
        local _, budget = LinkSecondaryBudget(link)
        total = budget
    end
    if not total or total <= 0 then return nil end
    local out = { crit = 0, haste = 0, mastery = 0, versatility = 0 }
    local each = math.floor(total / n + 0.5)
    for i = 1, n do out[keys[i]] = each end
    return out
end

-- 링크 파서 (WythicPlusGear.lua LinkSimcParts와 같은 필드 해석) — 조립 링크가 규격대로인지 확인
local function parse(link)
    local t = {}
    for tok in (link:match("item:([%-%d:]+)") .. ":"):gmatch("([^:]*):") do t[#t + 1] = tok end
    local nb = tonumber(t[13]) or 0
    local bon = {}
    for i = 14, 13 + nb do bon[#bon + 1] = t[i] end
    local mods = {}
    local nm = tonumber(t[14 + nb]) or 0
    for mi = 0, nm - 1 do mods[t[15 + nb + mi * 2]] = t[16 + nb + mi * 2] end
    return { id = t[1], spec = t[10], bonuses = bon, mods = mods }
end

-- 237828 Spellbreaker's March: 2스탯 선택형 판금 신발
local MARCH = 237828
check("데이터: 237828은 2스탯 선택형", CraftInfo(MARCH) and CraftInfo(MARCH).n == 2)
local l1 = CraftLink(MARCH, { "haste", "versatility" })
local p1 = parse(l1)
check("링크: 아이템 ID", p1.id == tostring(MARCH))
check("링크: 전문화 필드(10번째)", p1.spec == SPEC)
check("링크: 템플릿 보너스 그대로", table.concat(p1.bonuses, ":") == cd.bonus.std)
check("링크: modifier 29 = 가속(36)", p1.mods["29"] == "36")
check("링크: modifier 30 = 유연(40)", p1.mods["30"] == "40")

-- 메타 보너스가 있으면 그것 (장식 포함 — 메타 픽)
META_BONUS[MARCH] = "12214:13667:12497:13751:14001:8960:12384:8792:13836"
local l2 = CraftLink(MARCH, { "crit", "mastery" })
check("링크: 메타 보너스 우선(장식 포함)", table.concat(parse(l2).bonuses, ":") == META_BONUS[MARCH])
check("링크: 스탯1 치명(32)·스탯2 특화(49)", parse(l2).mods["29"] == "32" and parse(l2).mods["30"] == "49")

-- 수치: 예산 148을 지정 스탯 2개에 74씩
LINK_BUDGET[l2] = 148
local s2 = CraftStats(MARCH, l2, { "crit", "mastery" })
check("수치: 치명 74", s2 and s2.crit == 74)
check("수치: 특화 74", s2 and s2.mastery == 74)
check("수치: 미지정 스탯 0", s2 and s2.haste == 0 and s2.versatility == 0)
check("수치: 스탯 1개만 지정 → nil(핀 안 함)", CraftStats(MARCH, l2, { "crit" }) == nil)
check("수치: 예산 미로딩 → nil", CraftStats(MARCH, l1, { "haste", "versatility" }) == nil)
-- 게임이 modifier를 반영해 실제 스탯을 주면 그 합이 예산
LINK_STATS[l1] = { haste = 74, versatility = 74 }
local s1 = CraftStats(MARCH, l1, { "haste", "versatility" })
check("수치: 링크 실스탯 합을 예산으로", s1 and s1.haste == 74 and s1.versatility == 74)

-- 1스탯 선택형 (Aetherlume 계열): 예산 전부 한 스탯에, modifier 29만
local ONE
for id, e in pairs(cd.items) do if e.n == 1 then ONE = id break end end
check("데이터: 1스탯 선택형 존재", ONE ~= nil)
if ONE then
    local l3 = CraftLink(ONE, { "haste", "crit" })
    local p3 = parse(l3)
    check("1스탯: modifier 29만", p3.mods["29"] == "36" and p3.mods["30"] == nil)
    LINK_BUDGET[l3] = 198
    local s3 = CraftStats(ONE, l3, { "haste", "crit" })
    check("1스탯: 예산 전부 가속", s3 and s3.haste == 198 and s3.crit == 0)
end

-- 스탯 고정형: modifier 없음, 링크 스탯 그대로
local FIXED
for id, e in pairs(cd.items) do if e.n == 0 then FIXED = id break end end
if FIXED then
    local l4 = CraftLink(FIXED, { "crit", "haste" })
    check("고정형: modifier 없음", next(parse(l4).mods) == nil)
    LINK_STATS[l4] = { mastery = 120, versatility = 60 }
    local s4 = CraftStats(FIXED, l4, {})
    check("고정형: 스탯 미지정이어도 링크 스탯", s4 and s4.mastery == 120 and s4.versatility == 60)
end

-- 양손 무기는 양손 템플릿
local TWO
for id, e in pairs(cd.items) do if cd.twoHandInv[e.inv] and not META_BONUS[id] then TWO = id break end end
if TWO then
    check("양손 무기: 양손 보너스 템플릿", table.concat(parse(CraftLink(TWO, { "crit", "haste" })).bonuses, ":") == cd.bonus.twoHand)
end

-- ── 장식 ──
check("데이터: 장식 15종 이상", (function() local c = 0 for _ in pairs(cd.embellishments) do c = c + 1 end return c >= 15 end)())
check("데이터: 장식 표지 8960", cd.embellishMarkers[8960] == true)
-- 메타 보너스(장식 Arcanoweave 12384 포함)에서 장식만 교체
META_BONUS[MARCH] = "12214:13667:12497:13751:14001:8960:12384:8792:13836"
local lMeta = CraftLink(MARCH, { "haste", "versatility" }, nil)
check("장식 메타 픽: 보너스 그대로", table.concat(parse(lMeta).bonuses, ":") == META_BONUS[MARCH])
local lNone = CraftLink(MARCH, { "haste", "versatility" }, 0)
check("장식 없음: 8960·12384 제거, 나머지 유지", table.concat(parse(lNone).bonuses, ":") == "12214:13667:12497:13751:14001:8792:13836")
local lSun = CraftLink(MARCH, { "haste", "versatility" }, 12385)
check("장식 교체: 8960:12385 부착, 12384 제거", table.concat(parse(lSun).bonuses, ":") == "12214:13667:12497:13751:14001:8792:13836:8960:12385")
check("장식 교체해도 스탯 modifier 유지", parse(lSun).mods["29"] == "36" and parse(lSun).mods["30"] == "40")
if FIXED then
    local before = table.concat(parse(CraftLink(FIXED, {}, nil)).bonuses, ":")
    check("스탯 고정형: 장식 선택 무시(내장 장식)", table.concat(parse(CraftLink(FIXED, {}, 12385)).bonuses, ":") == before)
end

local function EmbApplies(use, info)
    local inv, cls, prof = info.inv, info.cls, info.prof
    local nonArmor = { [2] = true, [11] = true, [12] = true, [14] = true, [22] = true, [23] = true }
    local isArmor = cls == 4 and not nonArmor[inv]
    local isWeapon = cls == 2
    if use == "armor" then return isArmor
    elseif use == "equipment" then return true
    elseif use == "weaponArmor" then return isArmor or isWeapon
    elseif use == "weaponOffhand" then return isWeapon or inv == 14 or inv == 22 or inv == 23
    elseif use == "accessory" then return inv == 2 or inv == 11
    elseif use == "bsWeapon" then return isWeapon and prof == 164
    elseif use == "engGun" then return prof == 202 and (inv == 15 or inv == 26)
    elseif use == "engBoots" then return prof == 202 and inv == 8
    elseif use == "engEquip" then return prof == 202
    end
    return false
end
local boots = cd.items[MARCH]
check("데이터: 제작템 cls/prof 필드", boots.cls == 4 and boots.prof == 164)
check("장식 적용: 안감(armor) → 판금 신발 가능", EmbApplies("armor", boots))
check("장식 적용: 다크문 인장(weaponOffhand) → 신발 불가", not EmbApplies("weaponOffhand", boots))
check("장식 적용: 사냥꾼 의식석(bsWeapon) → 신발 불가", not EmbApplies("bsWeapon", boots))
check("장식 적용: 반지에 안감 불가", not EmbApplies("armor", { inv = 11, cls = 4, prof = 755 }))
check("장식 적용: 반지에 암모나이트(accessory) 가능", EmbApplies("accessory", { inv = 11, cls = 4, prof = 755 }))
check("장식 적용: 대장 무기에 의식석 가능", EmbApplies("bsWeapon", { inv = 17, cls = 2, prof = 164 }))
check("장식 적용: 기계공학 신발 전용", EmbApplies("engBoots", { inv = 8, cls = 4, prof = 202 }) and not EmbApplies("engBoots", boots))

-- ── 마법부여 ──
local ench = {}
for _, e in ipairs(cd.enchants) do ench[e.name] = e end
check("데이터: 마법부여 20종 이상", #cd.enchants >= 20)
local th = ench["Enchant Ring - Thalassian Haste"]
check("마부: 탈라시안 가속 2등급 = 가속 24", th and th.s2 and th.s2.haste == 24)
check("마부: 탈라시안 가속 1등급 = 가속 22", th and th.s1 and th.s1.haste == 22)
local br = ench["Enchant Weapon - Berserker's Rage"]
check("마부: 발동형 무기 마부는 계산 제외(nil)", br and br.s2 == nil)
local mw = ench["Enchant Chest - Mark of the Worldsoul"]
check("마부: 주 스탯 마부는 계산 제외(nil)", mw and mw.s2 == nil)
for _, e in ipairs(cd.enchants) do
    if e.s2 then
        local only = true
        for k in pairs(e.s2) do if k ~= "crit" and k ~= "haste" and k ~= "mastery" and k ~= "versatility" then only = false end end
        check("마부 스탯은 2차 스탯만: " .. e.name, only)
    end
end
-- 착용 마부 ID → 스탯: 같은 이름 ID가 둘이면 작은 쪽 1등급 (원본 EnchIndex 규칙)
local names = { [8020] = { "", 3, 244010, "Enchant Ring - Thalassian Haste" }, [8021] = { "", 3, 244011, "Enchant Ring - Thalassian Haste" },
                [7997] = { "", 3, 243987, "Enchant Ring - Nature's Fury" } }
local byId = {}
local idsByName = {}
for id, n in pairs(names) do idsByName[n[4]] = idsByName[n[4]] or {}; table.insert(idsByName[n[4]], id) end
for _, e in ipairs(cd.enchants) do
    local ids = idsByName[e.name]
    if ids then
        table.sort(ids)
        for i, id in ipairs(ids) do byId[id] = { e = e, tier = (#ids >= 2 and i == 1) and 1 or 2 } end
    end
end
local function EnchantStatsById(id)
    local hit = id and byId[id]
    if not hit then return {} end
    return (hit.tier == 1 and hit.e.s1 or hit.e.s2) or {}
end
check("착용 마부 1등급 ID → 가속 22", EnchantStatsById(8020).haste == 22)
check("착용 마부 2등급 ID → 가속 24", EnchantStatsById(8021).haste == 24)
check("ID 하나뿐 → 2등급 취급(치명 29)", EnchantStatsById(7997).crit == 29)
check("모르는 마부 → 0", next(EnchantStatsById(1234)) == nil)
-- 핀 차분 = 새 마부 - 착용 마부 (예: 착용 자연의 격노 치명 29 → 탈라시안 가속 24)
local new, old = th.s2, EnchantStatsById(7997)
check("마부 교체 차분: 가속 +24 / 치명 -29", (new.haste or 0) - (old.haste or 0) == 24 and (new.crit or 0) - (old.crit or 0) == -29)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
