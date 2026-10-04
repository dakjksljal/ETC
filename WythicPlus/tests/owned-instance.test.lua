-- 스모크 테스트: 소지품 모드의 실물 식별 (node fengari 러너 또는 luajit tests/owned-instance.test.lua)
-- WythicPlusGearDiag.lua 의 SplitSig 와 LockPins 의 같은 실물 판정, WythicPlusGear.lua 셀 숨김 판정을 미러링한다.
-- ⚠️ 아래 함수들은 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 배경(2026-09-20): 착용 중인 변환 티어 장갑(가속/특화)과 같은 ID인데 배분이 다른 장갑이 가방에 있으면
-- ID 기준 정체성 때문에 후보에서 사라지고(ID당 최고 ilvl 하나), 핀도 "유지"로 처리되고, 카드도 숨겨졐다.

local SECONDARY = { "crit", "haste", "mastery", "versatility" }

-- ── 미러 (원본과 동일) ──
local function SplitSig(st)
    local total = 0
    for _, k in ipairs(SECONDARY) do total = total + (st[k] or 0) end
    if total <= 0 then return "0" end
    local parts = {}
    for i, k in ipairs(SECONDARY) do parts[i] = tostring(math.floor((st[k] or 0) / total * 20 + 0.5)) end
    return table.concat(parts, ":")
end

-- LockPins: 착용템과 같은 ID라도 다른 실물(링크가 다른 가방 사본 핀)이면 교체 추천(lockedRec)
local function IsSameInstancePin(rw, pin, pinId)
    return rw ~= nil and rw.id == pinId
        and not (type(pin) == "table" and pin.link ~= nil and pin.link ~= rw.link)
end

-- Redraw 시작의 잔존 링크 핀 정리: 가방 사본 핀은 지금 착용한 실물 그 자체일 때만 걷어낸다
local ITEM_INFO = {} -- link → { id, ilvl, stats }
C_Item = {
    GetItemInfoInstant = function(link) return ITEM_INFO[link] and ITEM_INFO[link].id end,
    GetDetailedItemLevelInfo = function(link) return ITEM_INFO[link] and ITEM_INFO[link].ilvl end,
}
function WythicPlus_GearLinkStats(link) return ITEM_INFO[link] and ITEM_INFO[link].stats or {} end
local STAT_ORDER = SECONDARY
local function PinIsWornInstance(v, pwl)
    if v.link == pwl then return true end
    if C_Item.GetItemInfoInstant(pwl) ~= v.item_id then return false end
    if (v.ilvl or 0) ~= (C_Item.GetDetailedItemLevelInfo(pwl) or 0) then return false end
    local ws = (WythicPlus_GearLinkStats and WythicPlus_GearLinkStats(pwl)) or {}
    for _, sk in ipairs(STAT_ORDER) do
        if (ws[sk] or 0) ~= ((v.stats and v.stats[sk]) or 0) then return false end
    end
    return true
end
local function IsStalePin(v, pwl)
    if v.srcTab == "bags" then return PinIsWornInstance(v, pwl) end
    return C_Item.GetItemInfoInstant(pwl) == v.item_id and (v.ilvl or 0) <= (C_Item.GetDetailedItemLevelInfo(pwl) or 0)
end

-- 셀 숨김: 같은 ID 추천은 숨기되, 표시 ilvl이 높거나 가방의 다른 실물이면 유지
local function HideSameIdRec(recInfo, equippedId, wornLink, wornIl)
    if recInfo and recInfo.itemId == equippedId then
        local otherCopy = recInfo.bagLink ~= nil and recInfo.bagLink ~= wornLink
        if not otherCopy and (not recInfo.ilvl or recInfo.ilvl <= wornIl) then return true end
    end
    return false
end

-- ── 테스트 ──
local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

-- SplitSig: 배분이 다르면 다른 키, 같은 배분은 ilvl이 달라도 같은 키
check("sig: 가속/특화 100/50", SplitSig({ haste = 100, mastery = 50 }) == "0:13:7:0")
check("sig: 치명/유연 100/50", SplitSig({ crit = 100, versatility = 50 }) == "13:0:0:7")
check("sig: 같은 배분 다른 ilvl → 같은 키", SplitSig({ haste = 96, mastery = 48 }) == SplitSig({ haste = 100, mastery = 50 }))
check("sig: 뒤집힌 배분 → 다른 키", SplitSig({ haste = 50, mastery = 100 }) ~= SplitSig({ haste = 100, mastery = 50 }))
check("sig: 스탯 없음 → 0", SplitSig({}) == "0")
local WORN, BAG = "item:271475:::::::::250:::3:1:2:3:1:64:271878", "item:271475:::::::::250:::3:1:2:3:1:64:271499"
check("key: 같은 ID·다른 배분 = 다른 실물 키",
    (271475 .. "|" .. SplitSig({ haste = 100, mastery = 50 })) ~= (271475 .. "|" .. SplitSig({ crit = 100, versatility = 50 })))

-- LockPins 같은 실물 판정
local rw = { id = 271475, link = WORN }
check("lock: 메타 핀(숫자) 같은 ID → 같은 실물(유지)", IsSameInstancePin(rw, 271475, 271475) == true)
check("lock: 가방 사본 핀(링크 다름) 같은 ID → 다른 실물(교체 추천)", IsSameInstancePin(rw, { item_id = 271475, link = BAG }, 271475) == false)
check("lock: 착용 링크와 같은 링크 핀 → 같은 실물", IsSameInstancePin(rw, { item_id = 271475, link = WORN }, 271475) == true)
check("lock: 다른 ID → 다른 실물", IsSameInstancePin(rw, 271444, 271444) == false)
check("lock: 미착용 부위 → 다른 실물", IsSameInstancePin(nil, 271475, 271475) == false)

-- 잔존 핀 정리 판정 (Redraw 시작)
ITEM_INFO[WORN] = { id = 271475, ilvl = 331, stats = { haste = 100, mastery = 50 } }
ITEM_INFO[BAG] = { id = 271475, ilvl = 331, stats = { crit = 100, versatility = 50 } }
local bagPin = { item_id = 271475, link = BAG, ilvl = 331, stats = { crit = 100, versatility = 50 }, srcTab = "bags" }
check("stale: 가방 사본 핀(같은 ID·ilvl, 배분 다름) → 유지", IsStalePin(bagPin, WORN) == false)
check("stale: 가방 사본 핀, 착용 ilvl 더 높음 → 유지(다른 실물)", IsStalePin({ item_id = 271475, link = BAG, ilvl = 328, stats = { crit = 90, versatility = 45 }, srcTab = "bags" }, WORN) == false)
check("stale: 그 사본을 착용해 링크가 같아짐 → 걷어냄", IsStalePin(bagPin, BAG) == true)
local MOVED = "item:271475:::::::::250:::3:1:2:3:2:29:32:30:40" -- 같은 실물인데 링크 문자열만 달라진 경우
ITEM_INFO[MOVED] = { id = 271475, ilvl = 331, stats = { crit = 100, versatility = 50 } }
check("stale: ID·ilvl·스탯 전부 같으면 링크가 달라도 걷어냄", IsStalePin(bagPin, MOVED) == true)
local META_LINK = "item:271475:::::::::250:::1:13335"
check("stale: 메타 링크 핀 같은 ID·착용 이하 → 걷어냄(기존 규칙)", IsStalePin({ item_id = 271475, link = META_LINK, ilvl = 331, srcTab = "meta" }, WORN) == true)
check("stale: 메타 링크 핀 트랙 업(ilvl 높음) → 유지", IsStalePin({ item_id = 271475, link = META_LINK, ilvl = 334, srcTab = "meta" }, WORN) == false)
check("stale: 다른 ID 핀 → 유지", IsStalePin({ item_id = 271444, link = BAG, ilvl = 331, srcTab = "bags" }, WORN) == false)

-- 셀 숨김 판정
check("hide: 같은 ID 메타 추천, ilvl 같음 → 숨김", HideSameIdRec({ itemId = 271475, ilvl = 331 }, 271475, WORN, 331) == true)
check("hide: 같은 ID, 트랙 업(ilvl 높음) → 유지", HideSameIdRec({ itemId = 271475, ilvl = 334 }, 271475, WORN, 331) == false)
check("hide: 같은 ID 가방 다른 실물(ilvl 같음) → 유지", HideSameIdRec({ itemId = 271475, ilvl = 331, bagLink = BAG }, 271475, WORN, 331) == false)
check("hide: 같은 ID 가방 다른 실물(ilvl 낮음) → 유지", HideSameIdRec({ itemId = 271475, ilvl = 328, bagLink = BAG }, 271475, WORN, 331) == false)
check("hide: 착용 실물 그대로(링크 같음) → 숨김", HideSameIdRec({ itemId = 271475, ilvl = 331, bagLink = WORN }, 271475, WORN, 331) == true)
check("hide: 다른 ID → 유지", HideSameIdRec({ itemId = 271444, ilvl = 331 }, 271475, WORN, 331) == false)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
