-- 스모크 테스트: 마나용제(촉매) 변환 가정 계획 (node fengari 러너 또는 luajit tests/catalyst-convert.test.lua)
-- WythicPlusGearDiag.lua 의 BestConvCand / PlanConversions 를 미러링한다 (WoW API 의존 없음 — 순수 함수).
-- ⚠️ 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
--
-- 왜 필요한가: 소지품 모드는 "지금 가진 것"만 후보라, 마나용제가 있어도 비티어 아이템을 티어로 바꾸는
-- 경로를 몰랐다(2026-09-13 지적 — "이거까지 되어야 의미 있는 추천"). 규칙:
--   보유 = 착용 조각 + 가방 실물 티어(착용 부위 제외). 세트 보너스는 2/4에서만 생기므로
--   보유+용제로 닿는 가장 높은 문턱(4 → 2)까지만 변환한다. 문턱에 못 닿으면 변환 없음, 4 초과도 없음.
--   부위 우선순위: 랭커가 티어를 끼는 부위(메타 순위) → 후보 ilvl → 부위 고정 순서.
--   부위 안 후보 선택: 최고 ilvl, 동률이면 착용 중인 것(교체 없이 변환만).

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

local TIER_SLOT_ORDER = { "HEAD", "SHOULDER", "CHEST", "HANDS", "LEGS" }

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

local function slots(plan)
    local t = {}
    for i, pl in ipairs(plan) do t[i] = pl.slot end
    return table.concat(t, ",")
end

-- 랭커 메타: 머리·어깨·가슴·다리 티어(순위 1), 손은 비티어 부위(티어가 top5에 3위로 등장)
local metaRank = { HEAD = 1, SHOULDER = 1, CHEST = 1, HANDS = 3, LEGS = 1 }
local cHands = { itemId = 501, ilvl = 321, worn = true }
local cLegs = { itemId = 502, ilvl = 318, worn = false }

-- 3조각 착용(머리·어깨·가슴) + 용제 1 → 4세트 완성: 다리(순위 1)가 손(순위 3)보다 우선
local worn3 = { HEAD = true, SHOULDER = true, CHEST = true }
check("3착용 + 용제1 → 랭커 티어 부위(다리) 1건",
    slots(PlanConversions({ charges = 1, wornTierCount = 3, wornTierSlots = worn3, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = metaRank })) == "LEGS")
check("3착용 + 용제2 → 여전히 1건 (4 초과 변환 없음)",
    #PlanConversions({ charges = 2, wornTierCount = 3, wornTierSlots = worn3, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = metaRank }) == 1)
check("3착용 + 용제1 + 다리 후보 없음 → 손으로 완성",
    slots(PlanConversions({ charges = 1, wornTierCount = 3, wornTierSlots = worn3, cands = { HANDS = cHands }, metaRank = metaRank })) == "HANDS")
check("3착용 + 용제0 → 없음",
    #PlanConversions({ charges = 0, wornTierCount = 3, wornTierSlots = worn3, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = metaRank }) == 0)

-- 4조각 이미 착용 → 어떤 후보도 변환 없음
local worn4 = { HEAD = true, SHOULDER = true, CHEST = true, LEGS = true }
check("4착용 → 없음",
    #PlanConversions({ charges = 3, wornTierCount = 4, wornTierSlots = worn4, cands = { HANDS = cHands }, metaRank = metaRank }) == 0)

-- 가방에 실물 티어(다리)가 있으면 그건 변환 없이 배치되므로 필요 개수에서 뺀다
check("3착용 + 가방 실물 티어(다리) + 용제1 → 이미 4 도달 → 없음",
    #PlanConversions({ charges = 1, wornTierCount = 3, wornTierSlots = worn3, realBagTierSlots = { LEGS = true }, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = metaRank }) == 0)
check("3착용 + 착용 부위와 같은 실물 티어(머리, 중복) → 보유로 안 세고 다리 1건",
    slots(PlanConversions({ charges = 1, wornTierCount = 3, wornTierSlots = worn3, realBagTierSlots = { HEAD = true }, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = metaRank })) == "LEGS")
check("2착용 + 가방 실물 티어(다리) + 용제1 → 손 1건으로 4 완성",
    slots(PlanConversions({ charges = 1, wornTierCount = 2, wornTierSlots = { HEAD = true, SHOULDER = true }, realBagTierSlots = { LEGS = true }, cands = { HANDS = cHands, LEGS = cLegs, CHEST = { itemId = 9, ilvl = 300 } }, metaRank = metaRank })) == "CHEST")

-- 문턱 규칙: 4에 못 닿으면 2까지만, 2에도 못 닿으면 변환 없음
check("2착용 + 용제1 → 4 불가·2 이미 보유 → 없음",
    #PlanConversions({ charges = 1, wornTierCount = 2, wornTierSlots = { HEAD = true, SHOULDER = true }, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = metaRank }) == 0)
check("2착용 + 용제2 → 4 완성 2건 (다리 → 손 순)",
    slots(PlanConversions({ charges = 2, wornTierCount = 2, wornTierSlots = { HEAD = true, SHOULDER = true }, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = metaRank })) == "LEGS,HANDS")
check("1착용 + 용제1 → 2세트 문턱 1건",
    #PlanConversions({ charges = 1, wornTierCount = 1, wornTierSlots = { HEAD = true }, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = metaRank }) == 1)
check("0착용 + 용제1 → 2에도 못 닿음 → 없음",
    #PlanConversions({ charges = 1, wornTierCount = 0, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = metaRank }) == 0)
check("0착용 + 용제2 → 2세트 2건",
    #PlanConversions({ charges = 2, wornTierCount = 0, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = metaRank }) == 2)
check("0착용 + 용제4 → 4세트: 후보 2부위뿐이면 2건",
    #PlanConversions({ charges = 4, wornTierCount = 0, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = metaRank }) == 2)

-- 착용 티어 부위는 후보가 있어도 변환하지 않는다
check("착용 티어 부위(머리) 후보 무시",
    #PlanConversions({ charges = 1, wornTierCount = 3, wornTierSlots = worn3, cands = { HEAD = { itemId = 7, ilvl = 330 } }, metaRank = metaRank }) == 0)

-- 같은 순위면 ilvl 높은 부위, 그것도 같으면 고정 부위 순서
check("동순위 → ilvl 높은 부위(다리 330 > 손 321)",
    slots(PlanConversions({ charges = 1, wornTierCount = 3, wornTierSlots = worn3, cands = { HANDS = cHands, LEGS = { itemId = 8, ilvl = 330 } }, metaRank = { HANDS = 1, LEGS = 1 } })) == "LEGS")
check("동순위·동ilvl → 부위 고정 순서(손 < 다리)",
    slots(PlanConversions({ charges = 1, wornTierCount = 3, wornTierSlots = worn3, cands = { HANDS = cHands, LEGS = { itemId = 8, ilvl = 321 } }, metaRank = { HANDS = 1, LEGS = 1 } })) == "HANDS")
check("메타 순위 없는 부위는 999 취급 → 뒤로",
    slots(PlanConversions({ charges = 1, wornTierCount = 3, wornTierSlots = worn3, cands = { HANDS = cHands, LEGS = cLegs }, metaRank = { LEGS = 2 } })) == "LEGS")

-- 부위 안 후보 선택
check("BestConvCand: 최고 ilvl",
    BestConvCand({ { itemId = 1, ilvl = 310 }, { itemId = 2, ilvl = 324 }, { itemId = 3, ilvl = 318 } }).itemId == 2)
check("BestConvCand: 동률이면 착용 중인 것",
    BestConvCand({ { itemId = 1, ilvl = 321, worn = false }, { itemId = 2, ilvl = 321, worn = true } }).itemId == 2)
check("BestConvCand: 착용이 더 낮으면 높은 가방템",
    BestConvCand({ { itemId = 1, ilvl = 324, worn = false }, { itemId = 2, ilvl = 321, worn = true } }).itemId == 1)
check("BestConvCand: 빈 목록 → nil", BestConvCand({}) == nil and BestConvCand(nil) == nil)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
