-- 스모크 테스트: 소지품 모드 장신구 추천 (luajit tests/trinket-sort.test.lua)
-- GearDiag toOwnedItems 의 장신구 정렬(메타 우선) + GearCore 장신구 고정 dedup 을
-- 재현해 회귀를 막는다. 실제 함수는 WoW API 의존이라 순수 로직만 미러링한다.
-- ⚠️ 아래 두 함수는 GearDiag/GearCore 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).

-- GearDiag toOwnedItems: 장신구 슬롯 정렬 (메타 채용순위 우선, ilvl tiebreak)
local function sortTrinkets(arr, metaList)
  local function metaRankOf(id)
    if metaList then for mi = 1, #metaList do if metaList[mi][1] == id then return mi end end end
    return 999
  end
  table.sort(arr, function(a, c)
    local ra, rc = metaRankOf(a.item_id), metaRankOf(c.item_id)
    if ra ~= rc then return ra < rc end
    return a.item_level > c.item_level
  end)
  return arr
end

-- GearCore simulateGearSetCore 1.5단계(2026-09-19): 목표 집합(상위 N개, N = 착용 장신구 슬롯 수)을 먼저 정하고
-- 착용 중인 것은 자리 유지, 빈 자리에만 새 장신구. 두 슬롯 목록은 순위대로 번갈아 합친다.
local function pickTrinkets(pop, equipped)
  local slots, rec = {}, {}
  for _, tSlot in ipairs({ "TRINKET_1", "TRINKET_2" }) do
    if equipped[tSlot] ~= nil then slots[#slots + 1] = tSlot end
  end
  if #slots == 0 then return rec end
  local merged, seen = {}, {}
  local l1, l2 = pop.TRINKET_1 or {}, pop.TRINKET_2 or {}
  for i = 1, math.max(#l1, #l2) do
    if l1[i] and not seen[l1[i].item_id] then seen[l1[i].item_id] = true; merged[#merged + 1] = l1[i] end
    if l2[i] and not seen[l2[i].item_id] then seen[l2[i].item_id] = true; merged[#merged + 1] = l2[i] end
  end
  local target = {}
  for _, c in ipairs(merged) do if #target < #slots then target[#target + 1] = c end end
  local assigned, open = {}, {}
  for _, tSlot in ipairs(slots) do
    local hit
    for _, c in ipairs(target) do
      if not hit and not assigned[c.item_id] and c.item_id == equipped[tSlot] then hit = c end
    end
    if hit then assigned[hit.item_id] = true; rec[tSlot] = "KEEP" else open[#open + 1] = tSlot end
  end
  for _, tSlot in ipairs(open) do
    local nxt
    for _, c in ipairs(target) do if not nxt and not assigned[c.item_id] then nxt = c end end
    if nxt then assigned[nxt.item_id] = true; rec[tSlot] = nxt.item_id end
  end
  return rec
end

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

local META = { { 101 }, { 102 }, { 103 } } -- 메타 장신구 순위: 101>102>103

-- 정렬: 메타 우선 (비메타 고ilvl이 아래로)
local s1 = sortTrinkets({ { item_id = 999, item_level = 650 }, { item_id = 102, item_level = 630 }, { item_id = 101, item_level = 620 } }, META)
check("정렬:메타우선 (101,102,999)", s1[1].item_id == 101 and s1[2].item_id == 102 and s1[3].item_id == 999)

-- 정렬: 메타 없으면 ilvl 폴백 (기존 동작)
local s2 = sortTrinkets({ { item_id = 900, item_level = 640 }, { item_id = 901, item_level = 655 } }, META)
check("정렬:메타없음→ilvl (901,900)", s2[1].item_id == 901 and s2[2].item_id == 900)

-- dedup: 양 슬롯 후보 동일 → 서로 다른 장신구 추천 (같은 것 중복 X)
local pool = sortTrinkets({ { item_id = 999, item_level = 650 }, { item_id = 102, item_level = 630 }, { item_id = 101, item_level = 620 } }, META)
local function clone(a) local t = {} for i, v in ipairs(a) do t[i] = v end return t end
local r1 = pickTrinkets({ TRINKET_1 = clone(pool), TRINKET_2 = clone(pool) }, { TRINKET_1 = 500, TRINKET_2 = 501 })
check("dedup:양슬롯 다른 장신구", r1.TRINKET_1 ~= r1.TRINKET_2 and r1.TRINKET_1 == 101 and r1.TRINKET_2 == 102)

-- dedup: 메타 1개뿐 → 슬롯2는 중복 대신 비메타로 (그래도 서로 다름)
local pool1 = sortTrinkets({ { item_id = 101, item_level = 620 }, { item_id = 999, item_level = 650 } }, META)
local r2 = pickTrinkets({ TRINKET_1 = clone(pool1), TRINKET_2 = clone(pool1) }, { TRINKET_1 = 500, TRINKET_2 = 501 })
check("dedup:메타1개 → 슬롯 다름", r2.TRINKET_1 == 101 and r2.TRINKET_2 == 999)

-- 착용 중인 장신구 재추천 안 함 (같은 아이템 가방에도 있을 때 = KEEP)
local r3 = pickTrinkets({ TRINKET_1 = { { item_id = 101, item_level = 620 } }, TRINKET_2 = { { item_id = 101, item_level = 620 } } }, { TRINKET_1 = 101, TRINKET_2 = 501 })
check("착용템 재추천 X (T1=KEEP, T2 없음)", r3.TRINKET_1 == "KEEP" and r3.TRINKET_2 == nil)

-- 핑퐁 회귀 (2026-09-08): 가방 기준 모드 후보에 착용 장신구가 없으면 가방 템을 무조건 추천 →
-- 착용하면 내려간 원래 템이 다시 추천됨. toOwnedItems가 착용 장신구 2개를 풀에 넣어 막는다.
local function ownedPool(bag, worn)
  local arr = clone(bag)
  for _, w in ipairs(worn) do arr[#arr + 1] = w end
  return sortTrinkets(arr, META)
end
-- 착용 101/102(메타 1·2위) + 가방 비메타 900/901 → 둘 다 유지 (이전엔 900/901로 교체 추천)
local w1 = { { item_id = 101, item_level = 640 }, { item_id = 102, item_level = 640 } }
local p1 = ownedPool({ { item_id = 900, item_level = 645 }, { item_id = 901, item_level = 650 } }, w1)
local r4 = pickTrinkets({ TRINKET_1 = clone(p1), TRINKET_2 = clone(p1) }, { TRINKET_1 = 101, TRINKET_2 = 102 })
check("핑퐁:착용 메타 + 가방 비메타 → 둘 다 KEEP", r4.TRINKET_1 == "KEEP" and r4.TRINKET_2 == "KEEP")
-- 착용 비메타 900/901 + 가방 메타 101/102 → 메타로 교체 (핑퐁 반대편, 정상 추천은 유지)
local p2 = ownedPool({ { item_id = 101, item_level = 640 }, { item_id = 102, item_level = 640 } },
  { { item_id = 900, item_level = 645 }, { item_id = 901, item_level = 650 } })
local r5 = pickTrinkets({ TRINKET_1 = clone(p2), TRINKET_2 = clone(p2) }, { TRINKET_1 = 900, TRINKET_2 = 901 })
check("핑퐁:착용 비메타 + 가방 메타 → 101/102 교체", r5.TRINKET_1 == 101 and r5.TRINKET_2 == 102)
-- 착용 103(메타3위)/101(메타1위) + 가방 102(메타2위) → 103만 102로, 101 유지
local p3 = ownedPool({ { item_id = 102, item_level = 640 } },
  { { item_id = 103, item_level = 640 }, { item_id = 101, item_level = 640 } })
local r6 = pickTrinkets({ TRINKET_1 = clone(p3), TRINKET_2 = clone(p3) }, { TRINKET_1 = 103, TRINKET_2 = 101 })
check("핑퐁:상위 착용은 유지, 하위만 교체", r6.TRINKET_1 == 102 and r6.TRINKET_2 == "KEEP")
-- 가방 비어 있음 + 착용만 → 둘 다 KEEP (추천 없음)
local p4 = ownedPool({}, w1)
local r7 = pickTrinkets({ TRINKET_1 = clone(p4), TRINKET_2 = clone(p4) }, { TRINKET_1 = 101, TRINKET_2 = 102 })
check("핑퐁:가방 비어도 KEEP", r7.TRINKET_1 == "KEEP" and r7.TRINKET_2 == "KEEP")

-- 2라운드 추천 회귀 (2026-09-09 지적, 2026-09-19 수정): 1번에 2위(102)·2번에 3위(103) 착용, 후보 [101,102,103]
-- 이전 방식은 "1번→101" 뒤 다음 라운드에 "2번→102"를 냈다. 이제 1번은 유지, 2번만 101로.
local p5 = sortTrinkets({ { item_id = 101, item_level = 640 }, { item_id = 102, item_level = 640 }, { item_id = 103, item_level = 640 } }, META)
local r8 = pickTrinkets({ TRINKET_1 = clone(p5), TRINKET_2 = clone(p5) }, { TRINKET_1 = 102, TRINKET_2 = 103 })
check("2라운드 제거: 1번 KEEP, 2번→101", r8.TRINKET_1 == "KEEP" and r8.TRINKET_2 == 101)
-- 상위 2개를 순서만 바꿔 착용 → 둘 다 KEEP
local r9 = pickTrinkets({ TRINKET_1 = clone(p5), TRINKET_2 = clone(p5) }, { TRINKET_1 = 102, TRINKET_2 = 101 })
check("순서만 다른 상위 2개 → KEEP/KEEP", r9.TRINKET_1 == "KEEP" and r9.TRINKET_2 == "KEEP")
-- 장신구 슬롯 하나만 착용 → 1위 하나만 목표
local r10 = pickTrinkets({ TRINKET_1 = clone(p5), TRINKET_2 = clone(p5) }, { TRINKET_1 = 103 })
check("슬롯 하나 → 1위만", r10.TRINKET_1 == 101 and r10.TRINKET_2 == nil)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
