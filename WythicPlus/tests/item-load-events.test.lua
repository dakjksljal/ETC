-- 스모크 테스트: 아이템 캐시 요청/응답 필터 (node fengari 러너 또는 luajit tests/item-load-events.test.lua)
-- WythicPlusGear.lua 의 EnsureItem / OnItemInfoReceived 를 미러링한다 (WoW API 의존 → 스텁).
-- ⚠️ 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 배경: 모든 GET_ITEM_INFO_RECEIVED에 전체 리드로우 → 요청→응답→리드로우 연쇄, 실패 아이템 무한 재요청
-- (2026-09-11 인벤 제보: 모델 떨림·프레임 하락). 우리가 요청한 ID만, 실패는 1회로 끝낸다.

local cached, requests = {}, {}
C_Item = {
    GetItemInfo = function(id) return cached[id] and "name" or nil end,
    RequestLoadItemDataByID = function(id) requests[#requests + 1] = id end,
}

local ITEM_PENDING, ITEM_FAILED = {}, {}
local function EnsureItem(itemId)
    if not itemId or ITEM_FAILED[itemId] or ITEM_PENDING[itemId] then return end
    if not C_Item.GetItemInfo(itemId) then
        ITEM_PENDING[itemId] = true
        C_Item.RequestLoadItemDataByID(itemId)
    end
end
local function OnItemInfoReceived(itemId, success)
    if not ITEM_PENDING[itemId] then return false end
    ITEM_PENDING[itemId] = nil
    if success == false then
        ITEM_FAILED[itemId] = true
        return false
    end
    return true
end

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

-- 미캐시 → 1회 요청, 같은 ID 반복 호출은 요청 안 함 (응답 전 중복 방지)
EnsureItem(100); EnsureItem(100); EnsureItem(100)
check("미캐시 아이템은 응답 전까지 요청 1회", #requests == 1 and requests[1] == 100)

-- 캐시된 아이템은 요청 안 함
cached[200] = true
EnsureItem(200)
check("캐시된 아이템 요청 없음", #requests == 1)

-- 남이 요청한(우리가 모르는) 아이템 응답은 무시
check("미요청 ID 응답 → 재드로우 안 함", OnItemInfoReceived(999, true) == false)

-- 우리가 요청한 아이템 성공 응답 → 재드로우 1회, 다시 오면 무시
check("요청 ID 성공 응답 → 재드로우", OnItemInfoReceived(100, true) == true)
check("같은 응답 재수신 → 무시", OnItemInfoReceived(100, true) == false)

-- 응답 후 여전히 미캐시면 다시 요청 가능 (pending 해제됨)
EnsureItem(100)
check("응답 뒤 미캐시면 재요청 허용", #requests == 2)

-- 실패 응답 → 재드로우 없음 + 이후 영구 재요청 금지 (무한 루프 차단)
check("실패 응답 → 재드로우 안 함", OnItemInfoReceived(100, false) == false)
EnsureItem(100); EnsureItem(100)
check("실패 아이템은 다시 요청하지 않음", #requests == 2 and ITEM_FAILED[100] == true)

-- nil 안전
EnsureItem(nil)
check("nil ID 무시", #requests == 2)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
