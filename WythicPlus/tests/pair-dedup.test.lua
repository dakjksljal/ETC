-- 스모크 테스트: 쌍 슬롯(반지/장신구) 같은 아이템 중복 카드 제거 + 반대 슬롯 목록 조회 (node scripts/addon-lua-test.mjs)
-- WythicPlusGear.lua 의 FindMetaEntry / MetaItemInfo / DropPairDuplicates 를 미러링한다 (UI 파일이라 로드 불가 → 미러).
-- ⚠️ 아래 함수들은 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
--
-- 제보(2026-09-26): 레이드를 제외한 부정 DK. 장신구 합산 후보가 '공명의 울림석'(250228, 죽음의 골목 321) 하나뿐이라
-- 엔진이 1번(착용 334)에 추천하고, 2번(착용 321)은 엔진 추천이 없어 메타 대표 폴백이 같은 아이템을 또 띄웠다.
-- 또 250228은 장신구 2번 목록에만 있어 1번 카드의 조회가 비었고(레벨 공백), 툴팁이 보너스 없는 기본형(ilvl 28 희귀)으로 떴다.

local pass, fail = 0, 0
local function check(name, cond, detail)
    if cond then pass = pass + 1; print("PASS " .. name)
    else fail = fail + 1; print("FAIL " .. name .. (detail and (" — " .. tostring(detail)) or "")) end
end

-- ── 미러 (WythicPlusGear.lua) ──
local PAIRED_OF = { FINGER_1 = "FINGER_2", FINGER_2 = "FINGER_1", TRINKET_1 = "TRINKET_2", TRINKET_2 = "TRINKET_1" }

local function FindMetaEntry(spec, slotKey, itemId, conv)
    local items = spec and spec.items
    if not items then return nil end
    local keys = { slotKey, PAIRED_OF[slotKey] }
    for _, sk in ipairs(keys) do
        local list = items[sk]
        if list then
            for i = 1, #list do
                local e = list[i]
                if e[1] == itemId and (conv == nil or (e[12] or "") == conv) then return e end
            end
        end
    end
    return nil
end

local function MetaItemInfo(spec, slotKey, itemId, conv)
    local e = FindMetaEntry(spec, slotKey, itemId, conv)
    if e then return e[3], e[11], e[12] end
    return nil, nil, nil
end

local PAIR_SLOTS = { { "TRINKET_1", "TRINKET_2" }, { "FINGER_1", "FINGER_2" } }
local function DropPairDuplicates(recs, ilvlOf, pinned)
    local dropped = {}
    for _, pr in ipairs(PAIR_SLOTS) do
        local a, b = pr[1], pr[2]
        local ra, rb = recs[a], recs[b]
        if ra and rb and ra.itemId and rb.itemId and ra.itemId == rb.itemId then
            local pa, pb = pinned[a] ~= nil, pinned[b] ~= nil
            local drop
            if pa ~= pb then
                drop = pa and b or a
            elseif not pa then
                drop = (ilvlOf(a) <= ilvlOf(b)) and b or a
            end
            if drop then
                local r = recs[drop]
                recs[drop] = (r.gemId or r.gemNone or r.gemEmpty or r.ench) and {
                    gemId = r.gemId, gemNone = r.gemNone, gemWorn = r.gemWorn, gemEmpty = r.gemEmpty,
                    ench = r.ench, enchQuality = r.enchQuality, enchItemId = r.enchItemId,
                } or nil
                dropped[#dropped + 1] = drop
            end
        end
    end
    return dropped
end

-- ── 픽스처: 부정 DK 2026.09.25 데이터의 장신구 목록 (제보 당시 그대로) ──
local BELLOW = 250228 -- 공명의 울림석 (죽음의 골목)
local SPEC = { items = {
    TRINKET_1 = {
        { 270175, 28, 334, 143, 0, 0, 0, 0, 0, "", "6652:13334:12854:13696", "", 0 },
        { 270173, 15, 334, 0, 0, 0, 0, 0, 0, "Bite of Zul'jan", "6652:13334:12854", "", 0 },
        { 270164, 3, 334, 0, 0, 0, 0, 0, 0, "", "6652:13335:12854", "", 0 },
    },
    TRINKET_2 = {
        { 270175, 19, 334, 143, 0, 0, 0, 0, 0, "", "6652:13334:12854:13696", "", 0 },
        { 270173, 17, 334, 0, 0, 0, 0, 0, 0, "Bite of Zul'jan", "40:13334:12854:13696", "", 0 },
        { BELLOW, 5, 321, 0, 0, 0, 0, 0, 0, "", "13440:6652:12699:12846", "", 0 },
    },
    HEAD = {
        { 271474, 40, 334, 61, 140, 0, 0, 0, 0, "Set", "13334:6652", "", 0 },
    },
} }

-- ── 반대 슬롯 목록 조회 ──
local il, bon = MetaItemInfo(SPEC, "TRINKET_1", BELLOW)
check("장신구1 카드: 2번 목록에만 있는 울림석의 ilvl·보너스ID를 찾는다", il == 321 and bon == "13440:6652:12699:12846", tostring(il) .. "/" .. tostring(bon))
il, bon = MetaItemInfo(SPEC, "TRINKET_2", BELLOW)
check("장신구2 카드: 제 목록에서 찾는다", il == 321 and bon == "13440:6652:12699:12846")
il, bon = MetaItemInfo(SPEC, "TRINKET_2", 270173)
check("양쪽에 있으면 제 슬롯 항목이 우선", bon == "40:13334:12854:13696", bon)
il, bon = MetaItemInfo(SPEC, "TRINKET_1", 270173)
check("양쪽에 있으면 제 슬롯 항목이 우선(1번)", bon == "6652:13334:12854", bon)
check("conv 불일치는 nil", MetaItemInfo(SPEC, "TRINKET_1", BELLOW, "x|y|z") == nil)
check("conv 빈 문자열은 일반 변형과 일치", (MetaItemInfo(SPEC, "TRINKET_1", BELLOW, "")) == 321)
check("비쌍 슬롯은 반대 목록 없음(HEAD 미포함 → nil)", MetaItemInfo(SPEC, "HEAD", BELLOW) == nil)
check("비쌍 슬롯 제 목록 조회", (MetaItemInfo(SPEC, "HEAD", 271474)) == 334)
check("items 없는 spec은 nil", MetaItemInfo({}, "TRINKET_1", BELLOW) == nil)

-- ── 쌍 슬롯 중복 카드 제거 ──
local function ilvls(t) return function(k) return t[k] or 0 end end
local function keys(list) local s = {} for _, k in ipairs(list) do s[k] = true end return s end

-- 제보 상황: 1번 착용 334, 2번 착용 321, 둘 다 울림석 → 낮은 2번에만 남긴다
local recs = { TRINKET_1 = { itemId = BELLOW, rank = 4 }, TRINKET_2 = { itemId = BELLOW, rank = 4 } }
local d = DropPairDuplicates(recs, ilvls({ TRINKET_1 = 334, TRINKET_2 = 321 }), {})
check("제보 상황: 착용 ilvl 높은 1번 카드를 지운다", #d == 1 and d[1] == "TRINKET_1")
check("제보 상황: 1번 카드 없음, 2번 카드 유지", recs.TRINKET_1 == nil and recs.TRINKET_2 and recs.TRINKET_2.itemId == BELLOW)

-- 착용 ilvl 같으면 2번을 지운다 (웹과 동일)
recs = { TRINKET_1 = { itemId = 1 }, TRINKET_2 = { itemId = 1 } }
d = DropPairDuplicates(recs, ilvls({ TRINKET_1 = 321, TRINKET_2 = 321 }), {})
check("동률이면 2번을 지운다", d[1] == "TRINKET_2" and recs.TRINKET_1 ~= nil and recs.TRINKET_2 == nil)

-- 1번이 더 낮으면 2번을 지운다
recs = { TRINKET_1 = { itemId = 1 }, TRINKET_2 = { itemId = 1 } }
d = DropPairDuplicates(recs, ilvls({ TRINKET_1 = 300, TRINKET_2 = 334 }), {})
check("1번 착용이 낮으면 2번을 지운다", d[1] == "TRINKET_2")

-- 핀은 지우지 않는다: 1번 핀(착용 334)·2번 폴백(착용 321) → ilvl과 무관하게 2번을 지운다
recs = { TRINKET_1 = { itemId = 1 }, TRINKET_2 = { itemId = 1 } }
d = DropPairDuplicates(recs, ilvls({ TRINKET_1 = 334, TRINKET_2 = 321 }), { TRINKET_1 = 1 })
check("핀은 남기고 반대쪽을 지운다", d[1] == "TRINKET_2" and recs.TRINKET_1 ~= nil)
recs = { TRINKET_1 = { itemId = 1 }, TRINKET_2 = { itemId = 1 } }
d = DropPairDuplicates(recs, ilvls({ TRINKET_1 = 300, TRINKET_2 = 334 }), { TRINKET_2 = { item_id = 1 } })
check("2번이 핀(테이블)이면 1번을 지운다", d[1] == "TRINKET_1" and recs.TRINKET_2 ~= nil)
recs = { TRINKET_1 = { itemId = 1 }, TRINKET_2 = { itemId = 1 } }
d = DropPairDuplicates(recs, ilvls({}), { TRINKET_1 = 1, TRINKET_2 = 1 })
check("둘 다 핀이면 손대지 않는다", #d == 0 and recs.TRINKET_1 ~= nil and recs.TRINKET_2 ~= nil)

-- 다른 아이템·한쪽만 카드·아이템 없는 카드는 손대지 않는다
recs = { TRINKET_1 = { itemId = 1 }, TRINKET_2 = { itemId = 2 } }
check("다른 아이템은 유지", #DropPairDuplicates(recs, ilvls({}), {}) == 0)
recs = { TRINKET_1 = { itemId = 1 } }
check("한쪽만 카드면 유지", #DropPairDuplicates(recs, ilvls({}), {}) == 0 and recs.TRINKET_1 ~= nil)
recs = { TRINKET_1 = { gemId = 5 }, TRINKET_2 = { gemId = 5 } }
check("보석만 있는 줄은 아이템 중복이 아니다", #DropPairDuplicates(recs, ilvls({}), {}) == 0)

-- 지운 슬롯은 보석·마부 줄만 남긴다
recs = { TRINKET_1 = { itemId = 1, ilvl = 321, bonuses = "1:2", gemId = 99, ench = "마부", enchItemId = 7 }, TRINKET_2 = { itemId = 1 } }
d = DropPairDuplicates(recs, ilvls({ TRINKET_1 = 334, TRINKET_2 = 321 }), {})
local r1 = recs.TRINKET_1
check("지운 슬롯: 아이템 필드 제거", r1 and r1.itemId == nil and r1.ilvl == nil and r1.bonuses == nil)
check("지운 슬롯: 보석·마부 유지", r1 and r1.gemId == 99 and r1.ench == "마부" and r1.enchItemId == 7)

-- 반지도 같은 규칙, 장신구와 독립
recs = { FINGER_1 = { itemId = 9 }, FINGER_2 = { itemId = 9 }, TRINKET_1 = { itemId = 1 }, TRINKET_2 = { itemId = 2 } }
d = DropPairDuplicates(recs, ilvls({ FINGER_1 = 311, FINGER_2 = 298 }), {})
check("반지: 착용 높은 1번을 지운다, 장신구는 무관", #d == 1 and d[1] == "FINGER_1" and recs.TRINKET_1 ~= nil and recs.TRINKET_2 ~= nil)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
