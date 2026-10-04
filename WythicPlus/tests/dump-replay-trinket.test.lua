-- 덤프 재생 테스트: 실제 WythicPlusGearDiag.lua + WythicPlusGearCore.lua 를 스텁 환경에서 그대로 로드하고,
-- 인게임 `/wythic dump` 로 뜬 입력(2026-09-22 장신구 치명타 0 사고)을 재생한다. 미러 아님 — 원본이 바뀌면 여기서 검증된다.
-- 실행: node scripts/addon-lua-test.mjs (wythic-plus 레포) 또는 애드온 루트에서 luajit tests/dump-replay-trinket.test.lua
--
-- 사고 상황: 착용 장신구1 = 무리의 종양(250245, 315, 2차 없음), 장신구2 = 공명의 울림석(250228, 315, 2차 없음).
-- 가방 = 전쟁의 로아의 우상(250229, 321, 치명타 136). 유저가 드롭다운에서 우상을 골라 장신구2에 핀.
-- 기대: 장신구2 추천 = 우상(핀), 치명타 장비 증감 = +136. 예전 코어는 장신구1 목록의 울림석을 장신구2로 새어 들여
-- 우상을 도로 울림석으로 바꾸는 시뮬을 해 증감 0이 나왔다.

local ROOT = WYTHIC_ADDON_ROOT or "./"
local W = dofile(ROOT .. "tests/harness/wow-stub.lua")
dofile(ROOT .. "WythicPlusGearCore.lua")
dofile(ROOT .. "WythicPlusGearDiag.lua")

local pass, fail = 0, 0
local function check(name, cond, detail)
    if cond then pass = pass + 1; print("PASS " .. name)
    else fail = fail + 1; print("FAIL " .. name .. (detail and (" — " .. tostring(detail)) or "")) end
end

-- ── 픽스처 (덤프 그대로) ──
local L_TUMOR  = "|cnIQ4:|Hitem:250245::::::::90:250::33:4:13440:6652:12699:12844:1:28:1279:::::|h[무리의 종양]|h|r"
local L_BELLOW = "|cnIQ4:|Hitem:250228::::::::90:250::33:4:13440:6652:12699:12844:1:28:1279:::::|h[공명의 울림석]|h|r"
local L_IDOL   = "|cnIQ4:|Hitem:250229::::::::90:250::16:4:13440:6652:12699:12846:1:28:1279:::::|h[전쟁의 로아의 우상]|h|r"
local TUMOR, BELLOW, IDOL = 250245, 250228, 250229

W.reset()
W.worn[13], W.worn[14] = L_TUMOR, L_BELLOW            -- TRINKET_1=13, TRINKET_2=14
W.ilvl[L_TUMOR], W.ilvl[L_BELLOW], W.ilvl[L_IDOL] = 315, 315, 321
W.stats[L_TUMOR], W.stats[L_BELLOW] = {}, {}
W.stats[L_IDOL] = { crit = 136 }
for _, id in ipairs({ TUMOR, BELLOW, IDOL }) do
    W.info[id] = { equipLoc = "INVTYPE_TRINKET", classID = 4, subclassID = 0, name = "t" .. id }
    W.specInfo[id] = { 250 } -- 내 스펙 지정 → 착용 적합
end
W.ratings = { [9] = 927 } -- CR_CRIT_MELEE 근사(표시 gap 용; 판정엔 영향 없음)

-- 혈기 메타(09.21 데이터 그대로). 데이터 엔트리: [1]=id [2]=count [3]=ilvl [4..7]=c/h/m/v [8]=2h [9]=embel [10]=set [11]=bonus [12]=conv [13]=convSrc
local function e(id, n, ilvl, c, h, m, v) return { id, n, ilvl, c, h, m, v, 0, 0, "", "", "", 0 } end
local T1 = { e(270175, 56, 344, 149, 0, 0, 0), e(270165, 17, 334, 0, 0, 0, 0), e(270173, 10, 334, 0, 0, 0, 0), e(270174, 4, 324, 0, 0, 138, 0), e(BELLOW, 3, 321, 0, 0, 0, 0) }
local T2 = { e(270175, 31, 334, 143, 0, 0, 0), e(270165, 22, 334, 0, 0, 0, 0), e(270173, 16, 344, 0, 0, 0, 0), e(TUMOR, 8, 321, 0, 0, 0, 0), e(BELLOW, 6, 321, 0, 0, 0, 0) }
for _, list in ipairs({ T1, T2 }) do
    for _, en in ipairs(list) do W.info[en[1]] = W.info[en[1]] or { equipLoc = "INVTYPE_TRINKET", classID = 4, subclassID = 0 } end
end
-- Gear UI의 FilterSpecItems는 쌍 슬롯(장신구) 두 목록을 합쳐 통합 순위(paired)로 정렬하고 5위까지만 남겨 **두 슬롯에 같은 목록**을
-- 넣는다. 입력층(toOwnedItems)이 받는 spec은 그 결과이므로 여기서도 같은 모양을 만든다. 이걸 슬롯별 원본 목록으로 넣으면 종양이
-- 장신구1 목록에 없어 순위 밖(999)이 되고 사고가 재현되지 않는다(처음 작성 때 그렇게 해서 수정 전 코어도 통과해 버렸다).
local paired = { [270175] = 1, [270165] = 2, [270173] = 3, [TUMOR] = 4, [BELLOW] = 5, [IDOL] = 10 }
local merged, seen = {}, {}
for _, list in ipairs({ T1, T2 }) do
    for _, en in ipairs(list) do
        if not seen[en[1]] and (paired[en[1]] or 999) <= 5 then seen[en[1]] = true; merged[#merged + 1] = en end
    end
end
table.sort(merged, function(x, y) return (paired[x[1]] or 999) < (paired[y[1]] or 999) end)
local spec = {
    sample = 99,
    stats = { crit = 26.4, crit_rating = 985, haste = 29.3, haste_rating = 1072, mastery = 36.5, mastery_rating = 471, versatility = 8.6, versatility_rating = 467 },
    items = { TRINKET_1 = merged, TRINKET_2 = merged },
    paired = paired,
    gems = {}, enchants = {},
}
check("픽스처: 통합 목록 순서 = 270175,270165,270173,종양,울림석", table.concat({ merged[1][1], merged[2][1], merged[3][1], merged[4][1], merged[5][1] }, ",") == "270175,270165,270173,250245,250228")
-- 가방 스캔 결과(Gear UI가 넘기는 형태): 장신구는 두 슬롯 키 모두에 들어간다
local bagIdol = { itemId = IDOL, link = L_IDOL, ilvl = 321, bag = 0, slot = 1 }
local bagBySlot = { TRINKET_1 = { bagIdol }, TRINKET_2 = { bagIdol } }

local function critDelta(sim)
    for _, r in ipairs(sim.statRatios or {}) do
        if r.stat == "crit" then return r.gearOnlyRating - r.currentRating, r end
    end
end

-- ── 케이스 1: 핀 없음 → 코어는 둘 다 유지(울림석이 우상보다 인기 순위 위) ──
do
    local sim = WythicPlus_GearSimulateOwned(spec, bagBySlot, {}, nil, nil, nil)
    check("핀 없음: 시뮬 결과 있음", sim ~= nil)
    check("핀 없음: 장신구2 추천 없음(울림석 유지)", sim and sim.slotRecommendations.TRINKET_2 == nil, sim and tostring(sim.slotRecommendations.TRINKET_2))
    check("핀 없음: 장신구1 추천 없음(종양 유지)", sim and sim.slotRecommendations.TRINKET_1 == nil, sim and tostring(sim.slotRecommendations.TRINKET_1))
end

-- ── 케이스 2 (사고 재현): 장신구2에 우상 핀 → 우상이 표시되고 치명타 +136이 반영돼야 한다 ──
do
    local pinned = { TRINKET_2 = { item_id = IDOL, link = L_IDOL, ilvl = 321, stats = { crit = 136 }, srcTab = "bags" } }
    local sim = WythicPlus_GearSimulateOwned(spec, bagBySlot, pinned, nil, nil, nil)
    check("우상 핀: 시뮬 결과 있음", sim ~= nil)
    check("우상 핀: 장신구2 추천 = 우상", sim and sim.slotRecommendations.TRINKET_2 == IDOL, sim and tostring(sim.slotRecommendations.TRINKET_2))
    local d = sim and critDelta(sim)
    check("우상 핀: 치명타 장비 증감 +136 (코어가 울림석으로 되돌리지 않음)", d == 136, d)
    check("우상 핀: 장신구1은 그대로(우상을 겹쳐 추천하지 않음)", sim and sim.slotRecommendations.TRINKET_1 ~= IDOL)
end

-- ── 케이스 3: 빈 스냅샷 핀(stats={} ilvl=0)도 링크에서 다시 읽어 같은 결과 ──
do
    local pinned = { TRINKET_2 = { item_id = IDOL, link = L_IDOL, ilvl = 0, stats = {}, srcTab = "bags" } }
    local sim = WythicPlus_GearSimulateOwned(spec, bagBySlot, pinned, nil, nil, nil)
    local d = sim and critDelta(sim)
    check("빈 스냅샷 핀: 치명타 장비 증감 +136", d == 136, d)
end

-- ── 케이스 4: 우상을 실제로 착용한 뒤(가방엔 울림석) → 인기 순위대로 울림석 추천, 치명타 -136 ──
do
    W.worn[14] = L_IDOL
    local bagBellow = { itemId = BELLOW, link = L_BELLOW, ilvl = 315, bag = 0, slot = 1 }
    local sim = WythicPlus_GearSimulateOwned(spec, { TRINKET_1 = { bagBellow }, TRINKET_2 = { bagBellow } }, {}, nil, nil, nil)
    check("우상 착용: 장신구2 추천 = 울림석(인기순)", sim and sim.slotRecommendations.TRINKET_2 == BELLOW, sim and tostring(sim.slotRecommendations.TRINKET_2))
    local d = sim and critDelta(sim)
    check("우상 착용: 치명타 장비 증감 -136 (장신구 스탯 반영)", d == -136, d)
    W.worn[14] = L_BELLOW
end

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
