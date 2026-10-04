-- 통합 테스트: 제작 탭 핀이 실제 WythicPlusGearDiag.lua + WythicPlusGearCore.lua 시뮬에 지정 스탯 그대로 들어가는가.
-- 미러 아님 — 원본을 스텁 환경에서 그대로 로드한다. 실행: 애드온 루트에서 luajit/lua5.1 tests/craft-pin-sim.test.lua
--
-- 상황: 착용 신발 = 제작 신발(치명/특화 74·74). 유저가 제작 탭에서 같은 신발을 가속/유연으로 지정해 핀.
-- 조립 링크의 GetItemStats는 제작 스탯 modifier를 반영하지 않고 원래 배분(치명/특화)을 돌려준다고 가정 — 그래도
-- 시뮬은 핀의 지정 스탯(가속/유연)을 써야 하고, 같은 아이템이라도 "착용 그대로"로 지워지면 안 된다.

local ROOT = WYTHIC_ADDON_ROOT or "./"
local W = dofile(ROOT .. "tests/harness/wow-stub.lua")
dofile(ROOT .. "WythicPlusGearCore.lua")
dofile(ROOT .. "WythicPlusGearDiag.lua")

local pass, fail = 0, 0
local function check(name, cond, detail)
    if cond then pass = pass + 1; print("PASS " .. name)
    else fail = fail + 1; print("FAIL " .. name .. (detail and (" — " .. tostring(detail)) or "")) end
end

local MARCH = 237828
local L_WORN = "|cnIQ4:|Hitem:237828::::::::90:250::13:6:12214:13667:12497:13751:14001:13836:2:29:32:30:49|h[Spellbreaker's March]|h|r"
local L_CRAFT = "item:237828:::::::::250:::6:12214:13667:12497:13751:14001:13836:2:29:36:30:40"
W.reset()
W.worn[8] = L_WORN -- FEET
W.ilvl[L_WORN], W.ilvl[L_CRAFT] = 331, 331
W.stats[L_WORN] = { crit = 74, mastery = 74 }
W.stats[L_CRAFT] = { crit = 74, mastery = 74 } -- modifier 미반영 가정
W.info[MARCH] = { equipLoc = "INVTYPE_FEET", classID = 4, subclassID = 4, name = "March" }

local function e(id, n, ilvl, c, h, m, v) return { id, n, ilvl, c, h, m, v, 0, 0, "", "", "", 0 } end
local spec = {
    sample = 50,
    stats = { crit = 27.8, crit_rating = 1051, haste = 28.9, haste_rating = 1051, mastery = 38.6, mastery_rating = 523, versatility = 7.6, versatility_rating = 410 },
    items = { FEET = { e(MARCH, 26, 331, 0, 74, 0, 74), e(244774, 1, 331, 0, 149, 0, 0) } },
}
W.info[244774] = { equipLoc = "INVTYPE_FEET", classID = 4, subclassID = 4 }

local pin = { item_id = MARCH, link = L_CRAFT, ilvl = 331, stats = { crit = 0, haste = 74, mastery = 0, versatility = 74 }, srcTab = "craft" }
local sim = WythicPlus_GearSimulate(spec, { FEET = pin })
check("시뮬 결과 있음", sim ~= nil)
check("신발 추천 = 제작 핀(같은 아이템이지만 다른 스탯 재제작)", sim and sim.slotRecommendations.FEET == MARCH,
    sim and tostring(sim.slotRecommendations.FEET))
local d = {}
for _, r in ipairs((sim and sim.statRatios) or {}) do d[r.stat] = r.simRating - r.currentRating end
check("가속 +74", d.haste == 74, d.haste)
check("유연 +74", d.versatility == 74, d.versatility)
check("치명 -74", d.crit == -74, d.crit)
check("특화 -74", d.mastery == -74, d.mastery)

-- 같은 스탯(치명/특화)으로 핀하면 착용 실물과 같다 → 교체 추천 없음
local same = { item_id = MARCH, link = L_CRAFT, ilvl = 331, stats = { crit = 74, haste = 0, mastery = 74, versatility = 0 }, srcTab = "craft" }
local sim2 = WythicPlus_GearSimulate(spec, { FEET = same })
check("착용과 같은 스탯 핀 → 추천 없음(유지)", sim2 and sim2.slotRecommendations.FEET == nil,
    sim2 and tostring(sim2.slotRecommendations.FEET))

-- 최적화 OFF 커스텀 경로도 지정 스탯
local sim3 = WythicPlus_GearCustomOnly(spec, { FEET = pin }, {})
local d3 = {}
for _, r in ipairs((sim3 and sim3.statRatios) or {}) do d3[r.stat] = r.simRating - r.currentRating end
check("커스텀 경로: 가속 +74 / 치명 -74", d3.haste == 74 and d3.crit == -74)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
