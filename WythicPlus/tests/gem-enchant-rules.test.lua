-- 스모크 테스트: 보석 칸 수·템 교체 시 마부/보석 규칙 (lua5.1/luajit tests/gem-enchant-rules.test.lua)
-- WythicPlusGear.lua 의 PossibleSockets / EnchantPinDelta(교체 규칙) 를 미러링하고, 동봉 데이터로 홈 수를 확인한다.
-- ⚠️ 미러 함수는 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 규칙: 유저가 템을 바꾸면 기존 템의 마부·보석은 빠진다. 마부 = 고른 마부 → 바꾼 템의 원래 마부(가방 실물) → 없음.
--       템을 바꾸지 않았으면 착용 마부 유지. 보석 칸 수 = 실제 홈과 뚫을 수 있는 홈(랭커 1인당 보석 수 올림, 1~2) 중 큰 쪽.

local root = (arg and arg[0] and arg[0]:match("^(.*)tests[/\\]")) or "./"
dofile(root .. "WythicPlusGearData.lua")
local D = WythicPlusGearData

local pass, fail = 0, 0
local function check(name, cond, detail)
    if cond then pass = pass + 1; print("PASS " .. name)
    else fail = fail + 1; print("FAIL " .. name .. (detail and (" — " .. tostring(detail)) or "")) end
end

-- ── 미러: PossibleSockets ──
local cache
local function PossibleSockets(slotKey)
    if not cache then
        cache = {}
        for _, sp in pairs(D.specs or {}) do
            local n = sp.sample or 0
            if n >= 20 then
                for slot, list in pairs(sp.gems or {}) do
                    local t = 0
                    for _, g in ipairs(list) do t = t + (g[2] or 0) end
                    if t / n > (cache[slot] or 0) then cache[slot] = t / n end
                end
            end
        end
    end
    local r = cache[slotKey]
    if not r then return 0 end
    return math.min(2, math.max(1, math.ceil(r - 0.05)))
end
check("홈: 목은 2개까지", PossibleSockets("NECK") == 2, PossibleSockets("NECK"))
check("홈: 반지 1개", PossibleSockets("FINGER_1") == 1 and PossibleSockets("FINGER_2") == 1)
check("홈: 머리·손목·허리 1개", PossibleSockets("HEAD") == 1 and PossibleSockets("WRIST") == 1 and PossibleSockets("WAIST") == 1)
check("홈: 랭커가 보석을 안 끼는 부위(신발·다리) 0", PossibleSockets("FEET") == 0 and PossibleSockets("LEGS") == 0)
local function GemSlots(actual, slot) return math.max(actual, PossibleSockets(slot)) end
check("보석 칸 = max(실제 홈, 뚫을 홈): 실제 2홈 반지 → 2", GemSlots(2, "FINGER_1") == 2)
check("보석 칸: 홈 없는 머리 → 뚫을 홈 1", GemSlots(0, "HEAD") == 1)

-- ── 미러: 마부 교체 규칙 ──
local STATS = { [8021] = { haste = 24 }, [7997] = { crit = 29 }, [8027] = { versatility = 29 } }
local PICK = { ["Thalassian Haste"] = { haste = 24 } }
local function delta(o)
    -- o = { worn = 착용 마부 ID, pinned = 고른 마부 이름, swapped = 템 교체 여부, itemEnchant = 바꾼 템의 원래 마부 ID }
    local old = STATS[o.worn] or {}
    local new
    if o.pinned then new = PICK[o.pinned] or {}
    elseif o.swapped then new = STATS[o.itemEnchant] or {}
    else new = old end
    local d = {}
    for _, k in ipairs({ "crit", "haste", "mastery", "versatility" }) do d[k] = (new[k] or 0) - (old[k] or 0) end
    return d
end
local d1 = delta({ worn = 7997, swapped = false })
check("교체 안 함: 착용 마부 유지(차분 0)", d1.crit == 0)
local d2 = delta({ worn = 7997, swapped = true })
check("메타·제작 템으로 교체: 기존 마부 빠짐(치명 -29)", d2.crit == -29)
local d3 = delta({ worn = 7997, swapped = true, itemEnchant = 8027 })
check("가방 실물로 교체: 그 템 원래 마부(유연 +29)로", d3.crit == -29 and d3.versatility == 29)
local d4 = delta({ worn = 7997, swapped = true, pinned = "Thalassian Haste" })
check("교체 + 마부 고름: 고른 마부(가속 +24)", d4.crit == -29 and d4.haste == 24)
local d5 = delta({ worn = nil, swapped = true })
check("착용 마부 없던 부위 교체: 차분 0", d5.crit == 0 and d5.haste == 0)

-- ── 실제 Diag: 보석 차분은 장비 전용 레이팅(gearOnly)에 넣지 않는다 ──
local W = dofile(root .. "tests/harness/wow-stub.lua")
dofile(root .. "WythicPlusGearCore.lua")
dofile(root .. "WythicPlusGearDiag.lua")
check("Diag: 보석 차분 함수 노출", type(WythicPlus_GearApplyGemDelta) == "function")
local sim = { statRatios = {
    { stat = "crit", currentRating = 1000, gearOnlyRating = 1000, simRating = 1000, currentPct = 25 },
    { stat = "haste", currentRating = 900, gearOnlyRating = 900, simRating = 900, currentPct = 24 },
    { stat = "mastery", currentRating = 600, gearOnlyRating = 600, simRating = 600, currentPct = 30 },
    { stat = "versatility", currentRating = 400, gearOnlyRating = 400, simRating = 400, currentPct = 10 },
}, finalDistance = 0 }
local spec = { stats = { crit = 26, crit_rating = 1051, haste = 29, haste_rating = 1051, mastery = 38, mastery_rating = 523, versatility = 8, versatility_rating = 410 } }
WythicPlus_GearApplyGemDelta(sim, spec, { crit = 7, haste = 16, mastery = 0, versatility = 0 })
check("보석 차분: 시뮬 레이팅에 반영", sim.statRatios[1].simRating == 1007 and sim.statRatios[2].simRating == 916)
check("보석 차분: 장비 전용 레이팅은 그대로", sim.statRatios[1].gearOnlyRating == 1000 and sim.statRatios[2].gearOnlyRating == 900)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
