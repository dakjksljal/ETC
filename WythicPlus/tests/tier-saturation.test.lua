-- 스모크 테스트: 세트 포화 조각 판정 (node fengari 러너 또는 luajit tests/tier-saturation.test.lua)
-- WythicPlusGearDiag.lua toOwnedItems 의 setSaturated / set_name 결정을 미러링한다 (WoW API 의존 → 스텁).
-- ⚠️ 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
--
-- 왜 필요한가: 코어 2단계(티어)는 후보 풀에 set_name이 있으면 **거리를 보지 않고 강제 배치**하고,
-- equippedTierCount를 후보 풀 기준으로 센다. 소지품 모드에서 착용 티어 4조각은 가방에 없으니 0으로
-- 잡혀, 이미 4세트인데도 가방의 다섯 번째 조각을 세트 밖 부위에 밀어넣어 근접도가 떨어졌다.
-- 규칙: 그 세트를 4조각 이상 착용 중이고 그 부위가 세트 조각 부위가 아니면 set_name을 비운다
--       (후보로는 남아 순수 스탯 그리디로 평가된다).

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

-- setNames: 메타 목록에서 차용한 itemId → set_name
-- wornSetNameBySlot / wornSetNameCount: 착용 장비를 같은 식별자로 집계한 값
local function resolveSetName(itemId, slotKey, setNames, wornSetNameBySlot, wornSetNameCount)
    local bSetName = setNames[itemId]
    local setSaturated = bSetName ~= nil
        and (wornSetNameCount[bSetName] or 0) >= 4
        and wornSetNameBySlot[slotKey] ~= bSetName
    return (not setSaturated) and bSetName or nil
end

local TIER = "무덤기사"
local setNames = { [101] = TIER, [102] = TIER, [103] = TIER, [104] = TIER, [105] = TIER, [900] = "다른세트", [777] = nil }

-- 착용: 머리·가슴·손·다리 4조각 (어깨는 비티어)
local worn4 = { HEAD = TIER, CHEST = TIER, HANDS = TIER, LEGS = TIER }
local count4 = { [TIER] = 4 }

check("4세트 착용 + 세트 밖 부위(어깨) → 티어 해제",
    resolveSetName(105, "SHOULDER", setNames, worn4, count4) == nil)
check("4세트 착용 + 같은 세트 부위(머리) 교체 → 티어 유지",
    resolveSetName(101, "HEAD", setNames, worn4, count4) == TIER)
check("4세트 착용 + 비세트 아이템 → 원래대로 nil",
    resolveSetName(777, "SHOULDER", setNames, worn4, count4) == nil)
check("4세트 착용 + 다른 세트 조각 → 그 세트는 포화 아님",
    resolveSetName(900, "SHOULDER", setNames, worn4, count4) == "다른세트")

-- 착용 3조각 — 아직 4세트 전이라 다섯 번째가 아니라 네 번째다. 강제 배치가 정상 동작해야 한다.
local worn3 = { HEAD = TIER, CHEST = TIER, HANDS = TIER }
local count3 = { [TIER] = 3 }
check("3세트 착용 + 세트 밖 부위 → 티어 유지 (4세트 완성 경로)",
    resolveSetName(105, "SHOULDER", setNames, worn3, count3) == TIER)
check("3세트 착용 + 같은 세트 부위 교체 → 티어 유지",
    resolveSetName(101, "HEAD", setNames, worn3, count3) == TIER)

-- 5조각 이상 착용(이미 초과 착용) — 여섯 번째도 이득 없음
local worn5 = { HEAD = TIER, CHEST = TIER, HANDS = TIER, LEGS = TIER, SHOULDER = TIER }
local count5 = { [TIER] = 5 }
check("5세트 착용 + 세트 밖 부위(허리) → 티어 해제",
    resolveSetName(102, "WAIST", setNames, worn5, count5) == nil)
check("5세트 착용 + 같은 세트 부위(어깨) 교체 → 티어 유지",
    resolveSetName(105, "SHOULDER", setNames, worn5, count5) == TIER)

-- 착용 세트 없음(신규 캐릭) — 집계가 비어도 죽지 않는다
check("착용 세트 없음 → 티어 유지", resolveSetName(101, "HEAD", setNames, {}, {}) == TIER)
check("착용 세트 없음 + 비세트 → nil", resolveSetName(777, "HEAD", setNames, {}, {}) == nil)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
