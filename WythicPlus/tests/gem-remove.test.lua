-- 스모크 테스트: 보석 해제(빈 홈) 핀 = gid 0 (node fengari 러너 또는 luajit tests/gem-remove.test.lua)
-- WythicPlusGearDiag.lua ApplyGemPins / WythicPlus_GearCustomOnly 의 보석 핀 차분 계산을 미러링한다.
-- ⚠️ 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 규칙: 핀 값 0은 "보석 없음"으로 취급해 pinStats = {} → 착용(또는 추천) 보석 스탯만큼 빠진다.

local SECONDARY = { "crit", "haste", "mastery", "versatility" }
local dict = { [1001] = { haste = 88 }, [1002] = { crit = 44, mastery = 44 } }

-- ApplyGemPins 핵심: prev(추천 보석 or 착용 보석) → pinStats 차분
local function gemDelta(gemPins, equipBySlot, gemRec)
    local delta = { crit = 0, haste = 0, mastery = 0, versatility = 0 }
    local applied = {}
    for slot, gid in pairs(gemPins) do
        local pinStats = (gid == 0) and {} or dict[gid]
        if pinStats then
            local prev = {}
            if gemRec and gemRec[slot] then
                prev = dict[gemRec[slot]] or {}
            else
                local eq = equipBySlot[slot]
                if eq then prev = eq.gem_stats end
            end
            for _, k in ipairs(SECONDARY) do
                delta[k] = delta[k] + (pinStats[k] or 0) - (prev[k] or 0)
            end
            applied[slot] = gid
        end
    end
    return delta, applied
end

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

local equip = { NECK = { gem_stats = { haste = 88 } }, FINGER_1 = { gem_stats = {} } }

-- 착용 보석(가속 88) 해제 → 가속 −88
local d1, a1 = gemDelta({ NECK = 0 }, equip)
check("착용 보석 해제 → 그 스탯만큼 감소", d1.haste == -88 and d1.crit == 0 and a1.NECK == 0)

-- 보석 없는 부위 해제 → 변동 없음 (핀은 기록)
local d2, a2 = gemDelta({ FINGER_1 = 0 }, equip)
check("보석 없는 부위 해제 → 변동 0", d2.haste == 0 and d2.crit == 0 and a2.FINGER_1 == 0)

-- 시뮬 추천 보석(치명/특화 44)이 있는 부위 해제 → 추천분이 빠진다
local d3 = gemDelta({ NECK = 0 }, equip, { NECK = 1002 })
check("추천 보석 대체 해제 → 추천 스탯 감소", d3.crit == -44 and d3.mastery == -44 and d3.haste == 0)

-- 일반 보석 핀은 기존과 동일 (교체 차분)
local d4 = gemDelta({ NECK = 1002 }, equip)
check("보석 교체 핀: 가속 −88, 치명·특화 +44", d4.haste == -88 and d4.crit == 44 and d4.mastery == 44)

-- 사전에 없는 보석 ID는 무시 (0은 무시되지 않아야 함)
local d5, a5 = gemDelta({ NECK = 9999 }, equip)
check("미상 보석 ID 무시", d5.haste == 0 and a5.NECK == nil)

-- 0은 Lua에서 truthy — 표시 계층은 gemNone으로 분기해야 한다 (gemId 0을 아이템으로 취급 금지)
local gemId = 0
local gemNone = gemId == 0
if gemNone then gemId = nil end
check("표시 분기: gemId 0 → gemNone=true, gemId=nil", gemNone == true and gemId == nil)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
