-- 스모크 테스트: 착용 아이템 보석 홈 수 (node fengari 러너 또는 luajit tests/socket-count.test.lua)
-- WythicPlusGearDiag.lua 의 linkGemIds / SocketCount 를 미러링한다 (WoW API 의존 → 스텁).
-- ⚠️ 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 규칙: 홈 수 = 빈 홈(GetItemStats EMPTY_SOCKET_*) + 낀 보석(링크 gem 필드). 0이면 그 부위 보석 추천·빈 홈 표시 제외.

local statsByLink = {}
C_Item = { GetItemStats = function(link) local s = statsByLink[link]; if s == "error" then error("bad link") end; return s end }

local function linkGemIds(link)
    local ids = {}
    if link then
        local g1, g2, g3, g4 = link:match("item:%d+:%d*:(%d*):(%d*):(%d*):(%d*)")
        for _, g in ipairs({ g1, g2, g3, g4 }) do
            local n = tonumber(g)
            if n and n > 0 then ids[#ids + 1] = n end
        end
    end
    return ids
end
local function SocketCount(link)
    if not link then return nil end
    local n = #linkGemIds(link)
    local ok, st = pcall(C_Item.GetItemStats, link)
    if ok and type(st) == "table" then
        for k, v in pairs(st) do
            if type(k) == "string" and k:find("^EMPTY_SOCKET_") then n = n + (tonumber(v) or 0) end
        end
    end
    return n
end

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

local noSocket = "item:12345:7418::::::::90:250"
statsByLink[noSocket] = { ITEM_MOD_HASTE_RATING_SHORT = 300 }
check("홈 없는 손목 → 0", SocketCount(noSocket) == 0)

local emptySocket = "item:12345:7418::::::::90:250"
local emptySocket2 = emptySocket .. "::1:8781" -- 다른 링크 문자열로 구분
statsByLink[emptySocket2] = { EMPTY_SOCKET_PRISMATIC = 1 }
check("빈 홈 1개 → 1", SocketCount(emptySocket2) == 1)

local filled = "item:12345:7418:240890:::::::90:250"
statsByLink[filled] = { ITEM_MOD_HASTE_RATING_SHORT = 300 } -- 낀 보석은 GetItemStats에 빈 홈으로 안 잡힘
check("보석 낀 홈 1개 → 1", SocketCount(filled) == 1)

local mixed = "item:12345:7418:240890:::::::90:251"
statsByLink[mixed] = { EMPTY_SOCKET_PRISMATIC = 1 }
check("낀 1 + 빈 1 → 2", SocketCount(mixed) == 2)

check("링크 없음 → nil(미상, 게이트 없음)", SocketCount(nil) == nil)

statsByLink["item:1:::::::::90:250"] = "error"
check("GetItemStats 실패 → 링크 보석 수만 (0)", SocketCount("item:1:::::::::90:250") == 0)

-- 게이트 판정: 0만 제외, nil은 통과
local function gated(link) local s = SocketCount(link); return s ~= nil and s == 0 end
check("게이트: 0 → 제외, nil → 통과, 1 → 통과", gated(noSocket) == true and gated(nil) == false and gated(filled) == false)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
