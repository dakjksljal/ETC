-- 스모크 테스트: 2차 스탯 줄 고쳐쓰기 (node fengari 러너 또는 luajit tests/tooltip-secondary.test.lua)
-- WythicPlusGear.lua 의 SplitBudget/RedistributeSecondary/SameSecondarySplit/ParseStatLine/ScanSecondaryLines/
-- LinkSecondaryBudget/AlignLinkStats/FixTooltipSecondaryStats 를 미러링한다 (WoW API 의존 → 스텁).
-- ⚠️ 아래 함수들은 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 배경: 조립 링크로는 게임이 2차 스탯을 항상 맞게 그리지 못한다(변환 티어 modifier 64, 착귀·제작 "무작위 능력치" modifier
-- 29/30 — 둘 다 Blizzard API bonus_list에 없음). 인코딩별 대응 대신 "게임 표시 ≠ 수집 배분이면 수집 배분으로 덮어쓰기" 한 규칙.
-- 줄 형식은 로케일마다 다르다: enUS "+100 Haste", koKR "가속 +100".

-- ── 스텁 ──
local L = setmetatable({}, { __index = function(_, k) return k end })
local STAT_ORDER = { "crit", "haste", "mastery", "versatility" }
local STAT_LABELS = { crit = "치명타", haste = "가속", mastery = "특화", versatility = "유연성" }
local function useLocale(ko)
    if ko then
        ITEM_MOD_CRIT_RATING_SHORT, ITEM_MOD_HASTE_RATING_SHORT = "치명타 및 극대화", "가속"
        ITEM_MOD_MASTERY_RATING_SHORT, ITEM_MOD_VERSATILITY = "특화", "유연성"
        ITEM_MOD_MODIFIED_CRAFTING_STAT_1, ITEM_MOD_MODIFIED_CRAFTING_STAT_2 = "무작위 능력치 1", "무작위 능력치 2"
    else
        ITEM_MOD_CRIT_RATING_SHORT, ITEM_MOD_HASTE_RATING_SHORT = "Critical Strike", "Haste"
        ITEM_MOD_MASTERY_RATING_SHORT, ITEM_MOD_VERSATILITY = "Mastery", "Versatility"
        ITEM_MOD_MODIFIED_CRAFTING_STAT_1, ITEM_MOD_MODIFIED_CRAFTING_STAT_2 = "Random Stat 1", "Random Stat 2"
    end
end
useLocale(true)

local tip = { lines = {}, added = {} }
GameTooltip = tip
function tip:NumLines() return #self.lines end
function tip:AddLine(text) self.added[#self.added + 1] = text end
local function setTooltip(texts)
    tip.lines, tip.added = {}, {}
    for i, t in ipairs(texts) do
        local fs = { text = t }
        function fs:GetText() return self.text end
        function fs:SetText(t2) self.text = t2 end
        tip.lines[i] = fs
        _G["GameTooltipTextLeft" .. i] = fs
    end
    for i = #texts + 1, 30 do _G["GameTooltipTextLeft" .. i] = nil end
end
local function lineText(i) return tip.lines[i] and tip.lines[i].text end

-- C_TooltipInfo 스텁: 링크별 툴팁 줄
local TOOLTIP_INFO = {}
C_TooltipInfo = { GetHyperlink = function(link) return TOOLTIP_INFO[link] end }

-- 데이터 items 엔트리: {id, count, ilvl, c, h, m, v, 2h, embel, setName, bonuses, conv}
local spec = { items = {
    LEGS = {
        { 271473, 24, 334, 0, 136, 65, 0, 0, 0, "Set", "13335:42", "" },                                  -- 일반 티어(가속/특화)
        { 271473, 21, 334, 201, 0, 0, 0, 0, 0, "Set", "13334:6652:13708", "raid|맹독 심연|The Venomous Abyss" }, -- 맹독저주 변환(치명 단일)
        { 271473, 3, 334, 0, 136, 65, 0, 0, 0, "Set", "13334:6652", "dungeon|A|B" },                    -- 2스탯 변환(가속/특화)
    },
    SHOULDER = {
        { 271444, 2, 334, 0, 100, 0, 50, 0, 0, "", "6652:13662:13335:10844:12854", "" },                  -- 착귀(무작위 능력치: 가속/유연)
        { 271472, 5, 334, 50, 0, 100, 0, 0, 0, "Set", "13335", "" },                                     -- 일반 티어(치명/특화)
        { 999001, 1, 334, 0, 0, 0, 0, 0, 0, "", "", "" },                                                -- 수집 스탯 결손
    },
} }

-- ── 미러 (원본과 동일) ──
local function MetaItemStats(spec, slotKey, itemId, conv)
    local list = spec and spec.items and spec.items[slotKey]
    if list then
        for i = 1, #list do
            local e = list[i]
            if e[1] == itemId and (conv == nil or (e[12] or "") == conv) then
                return { crit = e[4] or 0, haste = e[5] or 0, mastery = e[6] or 0, versatility = e[7] or 0 }
            end
        end
    end
    return nil
end

local function IsConvertedVariant(conv)
    return conv ~= nil and conv ~= ""
end

local function SplitBudget(total, dataStats)
    local dtotal = 0
    for _, k in ipairs(STAT_ORDER) do dtotal = dtotal + (dataStats[k] or 0) end
    if not total or total <= 0 or dtotal <= 0 then return nil end
    local out = {}
    for _, k in ipairs(STAT_ORDER) do
        out[k] = math.floor(total * (dataStats[k] or 0) / dtotal + 0.5)
    end
    return out
end

local function RedistributeSecondary(linkStats, dataStats)
    local total = 0
    for _, k in ipairs(STAT_ORDER) do total = total + (linkStats[k] or 0) end
    local split = SplitBudget(total, dataStats)
    if not split then return linkStats end
    local out = {}
    for k, v in pairs(linkStats) do out[k] = v end
    for _, k in ipairs(STAT_ORDER) do out[k] = split[k] end
    return out
end

local function SameSecondarySplit(a, b, tol)
    tol = tol or 0.03
    local ta, tb = 0, 0
    for _, k in ipairs(STAT_ORDER) do
        ta = ta + (a[k] or 0)
        tb = tb + (b[k] or 0)
    end
    if ta <= 0 or tb <= 0 then return false end
    for _, k in ipairs(STAT_ORDER) do
        if math.abs((a[k] or 0) / ta - (b[k] or 0) / tb) > tol then return false end
    end
    return true
end

local SECONDARY_MOD_KEYS = {
    crit = "ITEM_MOD_CRIT_RATING_SHORT", haste = "ITEM_MOD_HASTE_RATING_SHORT",
    mastery = "ITEM_MOD_MASTERY_RATING_SHORT", versatility = "ITEM_MOD_VERSATILITY",
}
local PLACEHOLDER_KEYS = { "ITEM_MOD_MODIFIED_CRAFTING_STAT_1", "ITEM_MOD_MODIFIED_CRAFTING_STAT_2" }
local function StatLineName(k)
    return _G[SECONDARY_MOD_KEYS[k]] or STAT_LABELS[k]
end
local function ParseStatLine(txt)
    if type(txt) ~= "string" then return nil end
    local num, rest = txt:match("^%+([%d,%.]+)%s+(.-)%s*$")
    local numFirst = num ~= nil
    if not num then rest, num = txt:match("^(.-)%s+%+([%d,%.]+)%s*$") end
    if not (num and rest and rest ~= "") then return nil end
    local v = tonumber((num:gsub("[,%.]", "")))
    if not v then return nil end
    for k, g in pairs(SECONDARY_MOD_KEYS) do
        if _G[g] == rest then return k, v, numFirst end
    end
    for _, g in ipairs(PLACEHOLDER_KEYS) do
        if _G[g] == rest then return "placeholder", v, numFirst end
    end
    return nil
end
local function FormatStatLine(k, v, numFirst)
    if numFirst then return "+" .. v .. " " .. StatLineName(k) end
    return StatLineName(k) .. " +" .. v
end
local function ScanSecondaryLines(getText, n)
    local hits, shown, total, numFirst = {}, {}, 0, true
    for i = 1, n do
        local k, v, nf = ParseStatLine(getText(i))
        if k then
            hits[#hits + 1] = { i = i, key = k, value = v }
            if k ~= "placeholder" and shown[k] == nil then shown[k] = v end
            total = total + v
            if #hits == 1 then numFirst = nf end
        end
    end
    return hits, shown, total, numFirst
end

local function LinkSecondaryBudget(link)
    if not (link and C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return {}, 0 end
    local ok, td = pcall(C_TooltipInfo.GetHyperlink, link)
    if not (ok and type(td) == "table" and type(td.lines) == "table") then return {}, 0 end
    local _, shown, total = ScanSecondaryLines(function(i)
        local ln = td.lines[i]
        return ln and ln.leftText
    end, #td.lines)
    return shown, total
end

local function AlignLinkStats(st, link, data)
    if next(st) == nil then
        if not data then return nil end
        local _, budget = LinkSecondaryBudget(link)
        return SplitBudget(budget, data)
    end
    if data and not SameSecondarySplit(st, data) then return RedistributeSecondary(st, data) end
    return st
end

local function FixTooltipSecondaryStats(spec, slotKey, itemId, conv)
    if not (spec and slotKey and itemId) then return false end
    local data = MetaItemStats(spec, slotKey, itemId, conv)
    if not data then return false end
    local dtotal = 0
    for _, k in ipairs(STAT_ORDER) do dtotal = dtotal + (data[k] or 0) end
    if dtotal <= 0 then return false end
    local hits, shown, total, numFirst = ScanSecondaryLines(function(i)
        local fs = _G["GameTooltipTextLeft" .. i]
        return fs and fs:GetText()
    end, GameTooltip:NumLines())
    if #hits == 0 then
        -- 2차 스탯 줄을 못 찾음(파서가 모르는 로케일 형식 등). 변환 티어만 하단에 수집 배분을 병기하고(기존 동작),
        -- 그 외 아이템은 게임 표시를 그대로 둔다 — 안 그러면 그 로케일의 모든 툴팁에 안내 줄이 붙는다
        if not IsConvertedVariant(conv) then return false end
        local parts = {}
        for _, k in ipairs(STAT_ORDER) do
            if (data[k] or 0) > 0 then parts[#parts + 1] = FormatStatLine(k, data[k], true) end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ccffWythic+|r " .. L["2차 스탯은 랭커 착용 배분 기준"] .. ": " .. table.concat(parts, ", "), 0.8, 0.8, 0.8, true)
        return true
    end
    local hasPlaceholder = false
    for _, h in ipairs(hits) do
        if h.key == "placeholder" then hasPlaceholder = true end
    end
    if not hasPlaceholder and SameSecondarySplit(shown, data) then return false end
    local actual = SplitBudget(total, data)
    if not actual then return false end
    local j = 0
    for _, k in ipairs(STAT_ORDER) do
        local v = actual[k] or 0
        if v > 0 then
            local text = FormatStatLine(k, v, numFirst)
            if j < #hits then
                j = j + 1
                _G["GameTooltipTextLeft" .. hits[j].i]:SetText(text)
            else
                GameTooltip:AddLine(text, 0, 1, 0)
            end
        end
    end
    for i = j + 1, #hits do
        _G["GameTooltipTextLeft" .. hits[i].i]:SetText(i == j + 1 and ("|cff9d9d9d" .. L["2차 스탯은 랭커 착용 배분 기준"] .. "|r") or " ")
    end
    return true
end

-- ── 테스트 ──
local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

local VENOM = "raid|맹독 심연|The Venomous Abyss"
local NOTE = "|cff9d9d9d2차 스탯은 랭커 착용 배분 기준|r"

-- ParseStatLine: 두 로케일 형식, 자리표시자, 비스탯 줄
do
    local k, v, nf = ParseStatLine("가속 +100")
    check("parse ko: 가속 +100", k == "haste" and v == 100 and nf == false)
    k, v, nf = ParseStatLine("무작위 능력치 1 +100")
    check("parse ko: 자리표시자", k == "placeholder" and v == 100 and nf == false)
    check("parse ko: 힘 +141 → 비대상", ParseStatLine("힘 +141") == nil)
    check("parse ko: 체력 +2,932 → 비대상", ParseStatLine("체력 +2,932") == nil)
    check("parse ko: 세트 효과 문구 → 비대상", ParseStatLine("(2) 세트: 가속이 5%만큼 증가합니다.") == nil)
    check("parse ko: 마법부여 줄 → 비대상", ParseStatLine("마법부여: 가속 +200") == nil)
    check("parse ko: 착효 설명 → 비대상", ParseStatLine("착용 효과: 치명타 및 극대화가 363 만큼 증가합니다.") == nil)
    check("parse: nil/숫자 → nil", ParseStatLine(nil) == nil and ParseStatLine(5) == nil)
    useLocale(false)
    k, v, nf = ParseStatLine("+1,234 Haste")
    check("parse en: +1,234 Haste (천단위)", k == "haste" and v == 1234 and nf == true)
    k, v = ParseStatLine("+50 Random Stat 2")
    check("parse en: placeholder 2", k == "placeholder" and v == 50)
    check("parse en: +141 Strength → 비대상", ParseStatLine("+141 Strength") == nil)
    check("format en: 숫자 선행", FormatStatLine("crit", 7, true) == "+7 Critical Strike")
    useLocale(true)
    check("format ko: 이름 선행", FormatStatLine("crit", 7, false) == "치명타 및 극대화 +7")
end

-- SplitBudget / RedistributeSecondary / SameSecondarySplit
do
    local sp = SplitBudget(150, { crit = 0, haste = 100, mastery = 0, versatility = 50 })
    check("split: 150 → 가속100/유연50", sp.haste == 100 and sp.versatility == 50 and sp.crit == 0)
    check("split: 예산 0 → nil", SplitBudget(0, { crit = 1 }) == nil)
    check("split: 데이터 0 → nil", SplitBudget(100, { crit = 0 }) == nil)
    local r = RedistributeSecondary({ crit = 59, mastery = 142 }, { crit = 201, haste = 0, mastery = 0, versatility = 0 })
    check("redistribute: 단일 → 총량 201 전부 치명", r.crit == 201 and r.mastery == 0 and r.haste == 0)
    check("redistribute: 총량 0 → 그대로", RedistributeSecondary({}, { crit = 201 }).crit == nil)
    check("same: 같은 아이템 다른 ilvl(48/95 vs 50/100)", SameSecondarySplit({ haste = 48, mastery = 95 }, { haste = 50, mastery = 100 }))
    check("same: 종류 다름", not SameSecondarySplit({ crit = 59, mastery = 142 }, { crit = 201 }))
    check("same: 비율 다름", not SameSecondarySplit({ crit = 100, mastery = 50 }, { crit = 50, mastery = 100 }))
    check("same: 빈 표시 → false", not SameSecondarySplit({}, { crit = 100 }))
end

-- 핵심 1: 착귀(무작위 능력치) koKR 툴팁 → 자리표시자 두 줄이 수집 배분으로, 나머지 불변
setTooltip({ "잊힌 희생의 견갑", "신화", "아이템 레벨: 334", "레벨 강화: 신화 6/6", "착용 시 귀속", "어깨", "방어도 299",
    "힘 +141", "체력 +2,932", "무작위 능력치 1 +100", "무작위 능력치 2 +50", "지능 +141", "최소 요구 레벨: 90" })
check("boe ko: 반환 true", FixTooltipSecondaryStats(spec, "SHOULDER", 271444, "") == true)
check("boe ko: 자리표시자1 → 가속 +100", lineText(10) == "가속 +100")
check("boe ko: 자리표시자2 → 유연성 +50", lineText(11) == "유연성 +50")
check("boe ko: 주스탯·체력 불변", lineText(8) == "힘 +141" and lineText(9) == "체력 +2,932" and lineText(12) == "지능 +141")
check("boe ko: 하단 추가 없음", #tip.added == 0)

-- 핵심 1b: 트랙 리링크(다른 ilvl 예산)도 같은 비율
setTooltip({ "x", "무작위 능력치 1 +90", "무작위 능력치 2 +45" })
FixTooltipSecondaryStats(spec, "SHOULDER", 271444, "")
check("boe ko track: 135 → 가속 90 / 유연 45", lineText(2) == "가속 +90" and lineText(3) == "유연성 +45")

-- 핵심 1c: enUS 클라이언트 (숫자 선행 유지)
useLocale(false)
setTooltip({ "Pauldrons of the Forgotten Sacrifice", "+141 Strength", "+2,932 Stamina", "+100 Random Stat 1", "+50 Random Stat 2" })
check("boe en: 반환 true", FixTooltipSecondaryStats(spec, "SHOULDER", 271444, "") == true)
check("boe en: +100 Haste / +50 Versatility", lineText(4) == "+100 Haste" and lineText(5) == "+50 Versatility")
check("boe en: 주스탯 불변", lineText(2) == "+141 Strength")
useLocale(true)

-- 핵심 2: 일반 티어 — 게임 표시가 수집 배분과 같으면 손대지 않음 (다른 ilvl이라도)
setTooltip({ "악의적인 무덤기사의 교수대", "치명타 및 극대화 +48", "특화 +95" })
check("plain ko: 반환 false", FixTooltipSecondaryStats(spec, "SHOULDER", 271472, "") == false)
check("plain ko: 줄 불변", lineText(2) == "치명타 및 극대화 +48" and lineText(3) == "특화 +95")

-- 핵심 3: 변환 티어(원본 modifier 없음) koKR — 치명59/특화142 + 착효 → 치명 201, 특화 줄은 안내로, 착효 불변
local PROC = "착용 효과: 주문 및 능력 사용 시 일정 확률로 치명타 및 극대화가 363 만큼 증가하지만 12초 동안 다른 보조 능력치가 60 만큼 감소합니다."
setTooltip({ "악의적인 무덤기사의 경갑", "상급 맹독저주", "아이템 레벨: 334", "힘 +189", "체력 +3,910",
    "치명타 및 극대화 +59", "특화 +142", "내구도 120 / 120", PROC })
check("venom ko: 반환 true", FixTooltipSecondaryStats(spec, "LEGS", 271473, VENOM) == true)
check("venom ko: 치명 줄 → +201", lineText(6) == "치명타 및 극대화 +201")
check("venom ko: 특화 줄 → 안내", lineText(7) == NOTE)
check("venom ko: 착효·주스탯 불변", lineText(9) == PROC and lineText(4) == "힘 +189")
check("venom ko: 하단 추가 없음", #tip.added == 0)

-- 핵심 3b: 원본 modifier가 붙어 게임이 이미 맞게 그렸으면 no-op
setTooltip({ "악의적인 무덤기사의 경갑", "치명타 및 극대화 +201", PROC })
check("venom ko drawn right: false", FixTooltipSecondaryStats(spec, "LEGS", 271473, VENOM) == false)
check("venom ko drawn right: 불변", lineText(2) == "치명타 및 극대화 +201")

-- 트랙 리링크 툴팁(다른 예산) + 숫자 선행 형식 유지
setTooltip({ "악의적인 무덤기사의 경갑", "+65 치명타 및 극대화", "+156 특화" })
FixTooltipSecondaryStats(spec, "LEGS", 271473, VENOM)
check("track: 총량 221 → +221 치명 (숫자 선행 유지)", lineText(2) == "+221 치명타 및 극대화" and lineText(3) == NOTE)

-- 2스탯 변환: 두 줄 모두 실제 배분으로, 안내 줄 없음
setTooltip({ "x", "치명타 및 극대화 +59", "특화 +142" })
FixTooltipSecondaryStats(spec, "LEGS", 271473, "dungeon|A|B")
check("2스탯: STAT_ORDER 순 가속/특화", lineText(2) == "가속 +136" and lineText(3) == "특화 +65")

-- 게임 줄보다 데이터 스탯 종류가 많으면 하단 추가
setTooltip({ "x", "치명타 및 극대화 +201" })
FixTooltipSecondaryStats(spec, "LEGS", 271473, "dungeon|A|B")
check("more stats than lines: 첫 줄 가속, 하단 특화", lineText(2) == "가속 +136" and #tip.added == 1 and tip.added[1] == "특화 +65")

-- 폴백: 2차 스탯 줄을 못 찾으면 하단 병기
setTooltip({ "x", "힘 +189", "체력 +3,910" })
check("fallback: true", FixTooltipSecondaryStats(spec, "LEGS", 271473, VENOM) == true)
check("fallback: 하단에 수집 배분", #tip.added == 2 and tip.added[2]:find("+201 치명타 및 극대화", 1, true) ~= nil)

-- 폴백은 변환 티어만: 일반 아이템은 줄을 못 찾으면 손대지 않는다(미지원 로케일에서 모든 툴팁에 안내 줄이 붙는 부작용 방지)
setTooltip({ "x", "힘 +189", "체력 +3,910" })
check("fallback plain: false", FixTooltipSecondaryStats(spec, "SHOULDER", 271472, "") == false)
check("fallback plain: 하단 추가 없음", #tip.added == 0)

-- 데이터 없음 / 수집 스탯 결손 → false
setTooltip({ "x", "치명타 및 극대화 +59" })
check("unknown item → false", FixTooltipSecondaryStats(spec, "LEGS", 999, VENOM) == false)
check("empty data → false", FixTooltipSecondaryStats(spec, "SHOULDER", 999001, "") == false)
check("empty data → 줄 불변", lineText(2) == "치명타 및 극대화 +59")

-- AlignLinkStats (TrackPinLinkStats 수치 경로)
do
    local data = MetaItemStats(spec, "SHOULDER", 271444, "")
    local link = "item:271444:::::::::250:::5:6652:13662:13335:10844:12854"
    TOOLTIP_INFO[link] = { lines = { { leftText = "잊힌 희생의 견갑" }, { leftText = "힘 +141" },
        { leftText = "무작위 능력치 1 +100" }, { leftText = "무작위 능력치 2 +50" } } }
    local st = AlignLinkStats({}, link, data)
    check("align: 빈 링크 스탯 → 툴팁 예산 150을 가속/유연으로", st ~= nil and st.haste == 100 and st.versatility == 50 and st.crit == 0)
    check("align: 빈 링크 스탯 + 데이터 없음 → nil", AlignLinkStats({}, link, nil) == nil)
    check("align: 빈 링크 스탯 + 툴팁 없음 → nil", AlignLinkStats({}, "item:1", data) == nil)
    local same = { haste = 96, versatility = 48 }
    check("align: 배분 같으면 그대로", AlignLinkStats(same, link, data) == same)
    local fixed = AlignLinkStats({ crit = 59, mastery = 142 }, link, MetaItemStats(spec, "LEGS", 271473, VENOM))
    check("align: 배분 다르면 재분배(치명 201)", fixed.crit == 201 and fixed.mastery == 0)
    local shown, total = LinkSecondaryBudget(link)
    check("budget: 자리표시자 합 150, shown 비어 있음", total == 150 and next(shown) == nil)
end

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
