-- 실제 WythicPlusGearCore.lua 를 로드해 "열세 후보 차단" 규칙을 검증한다(미러 아님 — 코어가 바뀌면 여기서 잡힌다).
-- 실행: node scripts/addon-lua-test.mjs (wythic-plus 레포)
--
-- 배경(2026-09-23 디스코드 제보): 착용 중인 안개추적자의 성큼장화 308과 같은 2차 배분의 295 사본이 가방에 있었는데
-- 가방 기준 추천이 그 사본을 추천했다(메타 근접도 84.2 → 85.3, 아이템 레벨 316.0 → 315.2). 거리는 배분만 보므로
-- 과잉 스탯이 줄어드는 하향 교체가 "메타에 가깝다"고 보였다. 착용템보다 ilvl이 높지 않고 어느 2차 스탯도 더 많지 않은
-- 후보는 어떤 거리에서도 추천하지 않는다(메타·소지품 공통).

local ROOT = WYTHIC_ADDON_ROOT or "./"
dofile(ROOT .. "WythicPlusGearCore.lua")
local core = WythicPlusGearCore

local pass, fail = 0, 0
local function check(name, cond, detail)
    if cond then pass = pass + 1; print("PASS " .. name)
    else fail = fail + 1; print("FAIL " .. name .. (detail and (" — " .. tostring(detail)) or "")) end
end

-- 메타 40/40/10/10. 착용 허리는 치명/유연 몰빵이라 메타보다 치명·유연이 과잉 → 같은 배분의 낮은 사본으로 바꾸면 거리는 좁아진다
local META = { crit = 400, haste = 400, mastery = 100, versatility = 100 }
local OWNED = { ownedMode = true }
local function eq(slot, id, stats, ilvl)
    return { slot = slot, item_id = id, item_name = slot, item_level = ilvl or 308, stats = stats, gem_stats = {}, is_embellished = false }
end
local function item(id, stats, ilvl)
    return { item_id = id, item_level = ilvl or 308, stats = stats, set_name = "", is_two_hand = false, is_embellished = false }
end
local equip = { eq("WAIST", 9, { crit = 120, versatility = 80 }), eq("WRIST", 10, { haste = 40, mastery = 20 }) }

-- 1. 같은 ID·같은 배분·낮은 ilvl 가방 사본 (제보 상황)
local copy = item(9, { crit = 110, versatility = 73 }, 295)
local r = core:simulateGearSetCore(equip, { WAIST = { copy } }, META, nil, nil, OWNED)
check("소지품: 같은 ID·같은 배분·낮은 ilvl 사본은 추천하지 않는다", r.slotRecommendations.WAIST == nil, r.slotRecommendations.WAIST)
check("소지품: slotPicks 에도 없다", r.slotPicks == nil or r.slotPicks.WAIST == nil)
check("소지품: 거리 변화 없음", r.finalDistance == r.originalDistance, tostring(r.finalDistance) .. " vs " .. tostring(r.originalDistance))

-- 2. 다른 ID라도 열세(ilvl 이하·모든 2차 스탯 이하)면 추천하지 않는다 — 소지품·메타 공통
local worse = item(99, { crit = 100, versatility = 70 }, 300)
local ro = core:simulateGearSetCore(equip, { WAIST = { worse } }, META, nil, nil, OWNED)
local rm = core:simulateGearSetCore(equip, { WAIST = { worse } }, META, nil, nil, nil)
check("소지품: 다른 ID 열세 후보 미추천", ro.slotRecommendations.WAIST == nil, ro.slotRecommendations.WAIST)
check("메타: 다른 ID 열세 후보 미추천", rm.slotRecommendations.WAIST == nil, rm.slotRecommendations.WAIST)

-- 3. ilvl이 낮아도 어느 한 스탯이 착용템보다 많으면 열세가 아니라 거리로 판단한다(기존 동작 유지)
local shifted = item(9, { crit = 60, haste = 90 }, 295)
local rs = core:simulateGearSetCore(equip, { WAIST = { shifted } }, META, nil, nil, OWNED)
check("소지품: 배분이 다른(가속 있음) 낮은 사본은 거리로 판단해 추천", rs.slotRecommendations.WAIST == 9, rs.slotRecommendations.WAIST)
check("소지품: slotPicks 가 그 사본 객체", rs.slotPicks and rs.slotPicks.WAIST == shifted)

-- 4. 상위 ilvl 사본은 열세가 아니다(스탯이 더 많음) — 2026-09-19 규칙과 충돌하지 않는다
local upper = item(9, { crit = 130, versatility = 87 }, 311)
local ru = core:simulateGearSetCore(equip, { WAIST = { upper } }, META, nil, nil, OWNED)
check("소지품: 상위 ilvl 사본은 열세 차단에 걸리지 않는다(추천 여부는 거리가 정함)", ru.finalDistance ~= nil)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
