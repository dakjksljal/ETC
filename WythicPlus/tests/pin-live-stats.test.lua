-- 스모크 테스트: 핀 실효 스탯·착용 실물 판정 (node fengari 러너 또는 luajit tests/pin-live-stats.test.lua)
-- WythicPlusGearDiag.lua 의 PinLiveStats / PinIsWorn 을 미러링한다 (WoW API 의존 → 스텁).
-- ⚠️ 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
--
-- 배경(2026-09-22): 핀 테이블의 stats는 생성 시점 스냅샷이라 비거나 낡을 수 있다. 그 값을 그대로 "착용 중"으로
-- 코어에 깔면, 고정 치명타 장신구를 핀했는데 치명타 증감은 0이고 화살표만 남는 화면이 된다. 링크 핀은 시뮬 시점에
-- 링크에서 다시 읽는다. 착용 실물 판정도 링크 문자열만 비교하면 가방→착용 이동 뒤 유령 추천이 남으므로
-- ID·ilvl·2차 스탯으로도 본다.

local STATS_BY_LINK = {}   -- 링크 → GetItemStats 결과(2차 스탯)
local ILVL_BY_LINK = {}
local SECONDARY = { "crit", "haste", "mastery", "versatility" }
local function linkSecondaryStats(link)
    local out = {}
    for k, v in pairs(STATS_BY_LINK[link] or {}) do out[k] = v end
    return out
end
C_Item = { GetDetailedItemLevelInfo = function(link) return ILVL_BY_LINK[link] end }

local function PinLiveStats(pin, src)
    local isTbl = type(pin) == "table"
    local link = isTbl and pin.link or nil
    if isTbl and pin.srcTab == "craft" and type(pin.stats) == "table" and next(pin.stats) ~= nil then
        return pin.stats, pin.ilvl or 0, link
    end
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

local pass, fail = 0, 0
local function check(name, cond)
    if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end
end

-- 우상(250229): 고정 치명타 120. 가방 링크와 착용 링크 문자열이 다르다고 가정
local IDOL_BAG = "item:250229:0:0:0:0:0:0:11111:80:250::3:1:2:3"
local IDOL_WORN = "item:250229:0:0:0:0:0:0:22222:80:250::3:1:2:3"
STATS_BY_LINK[IDOL_BAG] = { crit = 120 }; ILVL_BY_LINK[IDOL_BAG] = 321
STATS_BY_LINK[IDOL_WORN] = { crit = 120 }; ILVL_BY_LINK[IDOL_WORN] = 321

-- 1) 빈 스냅샷 핀 → 링크에서 실효 스탯을 읽는다 (핵심 재현)
local st, il = PinLiveStats({ item_id = 250229, link = IDOL_BAG, stats = {}, ilvl = 0 }, nil)
check("빈 스냅샷 핀: 링크에서 치명타 120", st.crit == 120)
check("빈 스냅샷 핀: 링크에서 ilvl 321", il == 321)

-- 2) 낡은 스냅샷(치명 5)도 링크 값이 이긴다
st = PinLiveStats({ item_id = 250229, link = IDOL_BAG, stats = { crit = 5 }, ilvl = 300 }, nil)
check("낡은 스냅샷 핀: 링크 값 우선", st.crit == 120)

-- 3) 링크에서 못 읽으면(미로딩) 스냅샷 폴백
local UNLOADED = "item:999999:::::::::80:250::0"
st, il = PinLiveStats({ item_id = 999999, link = UNLOADED, stats = { haste = 77 }, ilvl = 310 }, nil)
check("미로딩 링크: 스냅샷 폴백 스탯", st.haste == 77)
check("미로딩 링크: 스냅샷 폴백 ilvl", il == 310)

-- 4) 링크·스냅샷 둘 다 없으면 풀 항목 폴백 (숫자 핀 = 메타 ID)
st, il = PinLiveStats(250229, { item_id = 250229, item_level = 344, stats = { crit = 149 } })
check("숫자 핀: 풀 항목 스탯", st.crit == 149)
check("숫자 핀: 풀 항목 ilvl", il == 344)

-- 5) 2차 스탯 없는 장신구(울림석)는 링크가 {}를 돌려도 정상 — 스냅샷 {}로 폴백, 코어엔 0으로 들어간다
local BELLOW = "item:250228:::::::::80:250::0"
STATS_BY_LINK[BELLOW] = {}; ILVL_BY_LINK[BELLOW] = 315
st = PinLiveStats({ item_id = 250228, link = BELLOW, stats = {}, ilvl = 315 }, nil)
check("무2차 장신구: 빈 테이블 유지(nil 아님)", type(st) == "table" and next(st) == nil)

-- 6) 제작 탭 핀: 유저 지정 스탯이 정답 — 링크가 다른 배분(제작 스탯 modifier 미반영)을 돌려줘도 핀 값 유지
local CRAFT = "item:237828:::::::::250:::6:12214:13667:12497:13751:14001:13836:2:29:36:30:40"
STATS_BY_LINK[CRAFT] = { crit = 74, mastery = 74 }; ILVL_BY_LINK[CRAFT] = 326
st, il = PinLiveStats({ item_id = 237828, link = CRAFT, stats = { haste = 74, versatility = 74 }, ilvl = 331, srcTab = "craft" }, nil)
check("제작 핀: 지정 스탯 유지(가속)", st.haste == 74 and (st.crit or 0) == 0)
check("제작 핀: 지정 스탯 유지(유연)", st.versatility == 74)
check("제작 핀: 최고 품질 ilvl 유지", il == 331)
-- 제작 핀이라도 스탯이 비어 있으면 기존 규칙(링크 재조회)
st = PinLiveStats({ item_id = 237828, link = CRAFT, stats = {}, ilvl = 331, srcTab = "craft" }, nil)
check("빈 제작 핀: 링크 폴백", st.crit == 74)

-- 착용 실물 판정
local rwIdol = { id = 250229, link = IDOL_WORN, ilvl = 321, total = { crit = 120 } }
check("같은 링크 → 착용 실물", PinIsWorn(250229, 321, { crit = 120 }, IDOL_WORN, rwIdol) == true)
check("링크 다르지만 ID·ilvl·스탯 같음 → 착용 실물(유령 추천 방지)", PinIsWorn(250229, 321, { crit = 120 }, IDOL_BAG, rwIdol) == true)
check("같은 ID, ilvl 다름 → 다른 실물", PinIsWorn(250229, 334, { crit = 149 }, IDOL_BAG, rwIdol) == false)
check("같은 ID·ilvl, 2차 배분 다름 → 다른 실물(가방 사본)", PinIsWorn(250229, 321, { haste = 120 }, IDOL_BAG, rwIdol) == false)
check("다른 ID → 다른 실물", PinIsWorn(250228, 315, {}, BELLOW, rwIdol) == false)
check("착용 없음 → 다른 실물", PinIsWorn(250229, 321, { crit = 120 }, IDOL_BAG, nil) == false)
check("숫자 핀(링크 없음): ID 같으면 착용", PinIsWorn(250229, 344, { crit = 149 }, nil, rwIdol) == true)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
