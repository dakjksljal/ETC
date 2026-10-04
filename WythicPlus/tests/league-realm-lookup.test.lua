-- 스모크 테스트: 리그 툴팁 캐릭터 조회 (node fengari 러너 또는 luajit tests/league-realm-lookup.test.lua)
-- WythicPlusLeague.lua 의 GetNameIndex / LookupByName 을 미러링한다 (WoW API 의존 → 스텁).
-- ⚠️ 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 규칙: 1차 = 이름-realm 키. KR/TW 클라는 서버명이 로컬라이즈돼 있어 서버가 동봉한 realms 표로 슬러그 변환.
--       2차 = 이름+지역 폴백, 동명이인(같은 지역 다른 서버)은 오표시 방지로 표시하지 않는다.
--       2026-09-17 제보: KR 클라 + 동명이인 → 1차 실패(서버명 불일치) + 2차 건너뜀 → 툴팁 없음. realms 표가 해소.

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

local myRegion = "kr"
local data

local nameIndex
local function GetNameIndex()
    if nameIndex then return nameIndex end
    nameIndex = {}
    local entries = data and data.entries
    if entries then
        for key, e in pairs(entries) do
            local n = key:match("^(.+)%-[^%-]+$")
            if n then
                local nkey = n .. "@" .. (e[5] or "")
                if nameIndex[nkey] == nil then
                    nameIndex[nkey] = e
                else
                    nameIndex[nkey] = false
                end
            end
        end
    end
    return nameIndex
end

local function LookupByName(name, realm)
    if not data or not data.entries or not name or name == "" then return nil end

    if realm then
        local norm = realm:lower():gsub("[%-'%s]", "")
        local slug = (data.realms and data.realms[norm]) or norm
        local e = data.entries[name .. "-" .. slug]
        if e and (not myRegion or e[5] == myRegion) then return e, data.week end
    end

    if myRegion then
        local e = GetNameIndex()[name .. "@" .. myRegion]
        if e then return e, data.week end
    end
    return nil
end

local function reset(realms)
    nameIndex = nil
    data = {
        week = "2026-09-17",
        realms = realms,
        entries = {
            ["가나다-azshara"]        = { 1, 100, "", "", "kr", "dps" },   -- 동명이인 A (아즈샤라)
            ["가나다-hyjal"]          = { 2, 90,  "", "", "kr", "tank" },  -- 동명이인 B (하이잘)
            ["유일-burninglegion"]    = { 3, 80,  "", "", "kr", "healer" }, -- 이름 유일 (불타는 군단)
            ["Solo-illidan"]          = { 4, 70,  "", "", "us", "dps" },   -- 다른 지역 같은 이름 없음
        },
    }
end

local KR_REALMS = { ["아즈샤라"] = "azshara", ["하이잘"] = "hyjal", ["불타는군단"] = "burninglegion" }

-- 구 데이터(realms 표 없음): KR 클라 동명이인은 1차 실패 + 2차 건너뜀 → nil (제보된 증상)
reset(nil)
check("표 없음: 동명이인 KR 클라 → 표시 없음(제보 증상)", LookupByName("가나다", "아즈샤라") == nil)
check("표 없음: 이름 유일은 2차 폴백으로 찾음", LookupByName("유일", "불타는 군단") == data.entries["유일-burninglegion"])
check("표 없음: 영문 클라(슬러그 그대로)는 1차로 찾음", LookupByName("가나다", "Azshara") == data.entries["가나다-azshara"])

-- 신 데이터(realms 표 동봉): 로컬 서버명 → 슬러그 변환으로 1차 매칭
reset(KR_REALMS)
check("표 있음: 동명이인 A 아즈샤라 → 아즈샤라 엔트리", LookupByName("가나다", "아즈샤라") == data.entries["가나다-azshara"])
check("표 있음: 동명이인 B 하이잘 → 하이잘 엔트리", LookupByName("가나다", "하이잘") == data.entries["가나다-hyjal"])
check("표 있음: 공백 있는 서버명(불타는 군단) 정규화", LookupByName("유일", "불타는 군단") == data.entries["유일-burninglegion"])
check("표 있음: GetNormalizedRealmName 형태(불타는군단)도 동일", LookupByName("유일", "불타는군단") == data.entries["유일-burninglegion"])
check("표 있음: 표에 없는 서버명은 정규화 그대로 시도 후 2차 폴백", LookupByName("유일", "알수없음") == data.entries["유일-burninglegion"])
check("표 있음: 표에 없는 서버명 + 동명이인 → 표시 없음", LookupByName("가나다", "알수없음") == nil)
check("다른 지역 엔트리는 내 지역 필터에 걸림", LookupByName("Solo", "Illidan") == nil)
check("빈 이름 → nil", LookupByName("", "아즈샤라") == nil)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
