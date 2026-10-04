-- 스모크 테스트: 제작 탭 데이터·링크·수치 (node fengari 러너 또는 luajit tests/craft-pin.test.lua)
-- WythicPlusGear.lua 의 CraftLink / CraftStats 를 미러링한다 (WoW API 의존 → 스텁).
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
local function CraftLink(itemId, keys)
    local info = CraftInfo(itemId)
    if not info then return nil end
    local bonuses = CraftBonuses(itemId)
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

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
