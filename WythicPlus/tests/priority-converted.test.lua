-- 스모크 테스트: 변환 티어 사본의 맹독저주 우선 판정 (node fengari 러너 또는 luajit tests/priority-converted.test.lua)
--
-- 배경(2026-09-21 제보): 마나용제로 티어가 된 맹독저주 조각은 **아이템 ID가 티어 것**이라
-- venom.items(원본 ID 목록) 조회만으로는 우선 아이템으로 안 잡힌다. 변환 티어는 원본의 단일 2차 배분과
-- 착용 효과를 그대로 물려받고, 게임은 그 계승을 아이템 링크 modifier 64(원본 아이템 ID)로 표현한다.
-- ⚠️ 아래 두 함수는 WythicPlusGearDiag.lua 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).

WythicPlusGearData = { venom = { items = { [271878] = 1, [271874] = 1, [268265] = 1 } } }

local function IsPriorityItemId(itemId)
    local v = WythicPlusGearData and WythicPlusGearData.venom
    return (v and v.items and itemId and v.items[itemId]) ~= nil
end

local function LinkRedirectSourceId(link)
    if not link then return nil end
    local body = link:match("item:([%-%d:]+)")
    if not body then return nil end
    local t = {}
    for f in (body .. ":"):gmatch("([^:]*):") do t[#t + 1] = f end
    local nb = tonumber(t[13]) or 0
    local nm = tonumber(t[14 + nb]) or 0
    for mi = 0, nm - 1 do
        if t[15 + nb + mi * 2] == "64" then return tonumber(t[16 + nb + mi * 2]) end
    end
    return nil
end

local function IsPriorityItem(itemId, link)
    if IsPriorityItemId(itemId) then return true end
    return IsPriorityItemId(LinkRedirectSourceId(link))
end

local pass, fail = 0, 0
local function check(name, cond)
    if cond then pass = pass + 1; print("PASS " .. name)
    else fail = fail + 1; print("FAIL " .. name) end
end

-- 12.1 실링크 형태: item:271455:8159:::::::90:250::93:8:<보너스8개>:1:64:271878
local converted = "item:271473:8159:::::::90:250::93:8:1:2:3:4:5:6:7:8:1:64:271878"
check("modifier 64 → 원본 ID", LinkRedirectSourceId(converted) == 271878)
check("변환 티어 사본은 우선 아이템", IsPriorityItem(271473, converted) == true)

-- 보너스 없는 변환 링크
local noBonus = "item:271473:::::::::104:::0:1:64:271878"
check("보너스 0개 링크도 원본 ID를 읽는다", LinkRedirectSourceId(noBonus) == 271878)
check("보너스 0개 변환 사본도 우선", IsPriorityItem(271473, noBonus) == true)

-- 평범한 티어 사본(modifier 없음)은 우선이 아니다
local plain = "item:271473:::::::::104:::3:13334:6652:13708"
check("modifier 없는 링크 → 원본 없음", LinkRedirectSourceId(plain) == nil)
check("평범한 티어 사본은 우선 아님", IsPriorityItem(271473, plain) == false)

-- 맹독저주 원본 자체는 링크 없이도 우선
check("맹독저주 원본 ID는 링크 없이 우선", IsPriorityItem(271878, nil) == true)
check("목걸이도 목록에 있으면 우선", IsPriorityItem(268265, nil) == true)

-- 맹독저주가 아닌 원본에서 변환된 티어는 우선이 아니다
local otherSrc = "item:271473:::::::::104:::0:1:64:999999"
check("비맹독저주 원본 변환은 우선 아님", IsPriorityItem(271473, otherSrc) == false)

-- modifier 가 64 말고 29/30(제작 스탯)만 있는 링크
local crafted = "item:271473:::::::::104:::2:11:12:2:29:1234:30:5678"
check("제작 스탯 modifier만 있으면 원본 없음", LinkRedirectSourceId(crafted) == nil)
check("제작템은 우선 아님", IsPriorityItem(271473, crafted) == false)

-- 깨진 입력 방어
check("nil 링크 안전", LinkRedirectSourceId(nil) == nil)
check("아이템 링크 아님 안전", LinkRedirectSourceId("spell:12345") == nil)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
