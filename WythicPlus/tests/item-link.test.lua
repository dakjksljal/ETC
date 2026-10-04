-- 스모크 테스트: 애드온 조립 아이템 링크의 전문화 ID 필드 (node fengari 러너 또는 luajit tests/item-link.test.lua)
-- WythicPlusGear.lua 의 CurrentSpecID/BuildItemLink/WithCurrentSpec 을 미러링한다 (WoW API 의존 → 스텁).
-- ⚠️ 아래 세 함수는 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 링크 규격: item:ID:enchant:gem1:gem2:gem3:gem4:suffix:unique:linkLevel:specID:modMask:context:numBonus:bonuses

local STUB_SPEC = 104 -- 수호 드루이드
GetSpecialization = function() return 3 end
GetSpecializationInfo = function(idx) if idx == 3 then return STUB_SPEC end end

local function CurrentSpecID()
    local specIndex = GetSpecialization and GetSpecialization()
    local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
    return specID and tostring(specID) or ""
end
local function BuildItemLink(itemId, bonuses, srcItemId)
    bonuses = bonuses ~= nil and tostring(bonuses) or ""
    local src = tonumber(srcItemId)
    local mods = (src and src > 0) and (":1:64:" .. math.floor(src)) or ""
    if bonuses ~= "" then
        local n = 1 + select(2, bonuses:gsub(":", ""))
        return ("item:%s:::::::::%s:::%d:%s%s"):format(tostring(itemId), CurrentSpecID(), n, bonuses, mods)
    end
    if mods ~= "" then
        return ("item:%s:::::::::%s:::0%s"):format(tostring(itemId), CurrentSpecID(), mods)
    end
    return ("item:%s:::::::::%s"):format(tostring(itemId), CurrentSpecID())
end
local function WithCurrentSpec(link)
    if type(link) ~= "string" then return link end
    local pre, itemString, post = link:match("^(.-item:)([%-%d:]+)(.*)$")
    if not itemString then return link end
    local f = {}
    for v in (itemString .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
    for i = #f + 1, 10 do f[i] = "" end
    f[10] = CurrentSpecID()
    return pre .. table.concat(f, ":") .. post
end

-- "item:" 뒤 필드 분해 (f[1]=ID ... f[10]=specID, f[13]=numBonus, f[14..]=bonusIDs)
local function fields(link)
    local s = link:match("item:([%-%d:]+)")
    local f = {}
    for v in (s .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
    return f
end

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

-- 보너스 3개: 필드 위치 정확
local l1 = BuildItemLink(268247, "13440:12846:1234")
local f1 = fields(l1)
check("bonus3: 문자열", l1 == "item:268247:::::::::104:::3:13440:12846:1234")
check("bonus3: f[1]=ID", f1[1] == "268247")
check("bonus3: f[10]=specID", f1[10] == "104")
check("bonus3: f[13]=numBonus", f1[13] == "3")
check("bonus3: f[14..16]=bonuses", f1[14] == "13440" and f1[15] == "12846" and f1[16] == "1234" and f1[17] == nil)
check("bonus3: f[2..9],f[11..12] 비어있음", f1[2] == "" and f1[9] == "" and f1[11] == "" and f1[12] == "")

-- 기존 문자열("item:ID::::::::::::n:bonuses", 콜론 12개)과 필드 수 동일
local old = "item:268247::::::::::::3:13440:12846:1234"
check("bonus3: 기존 포맷과 필드 수 동일", #fields(old) == #f1)

-- 보너스 1개 (숫자 인자 — 트랙 스텝 ID는 number 로 들어온다)
local l2 = BuildItemLink(268247, 12854)
local f2 = fields(l2)
check("bonus1(number): f[13]=1, f[14]=12854", f2[13] == "1" and f2[14] == "12854" and f2[10] == "104")

-- 보너스 없음 / nil / 빈 문자열 → 10필드까지만
local l3 = BuildItemLink(268247, nil)
local f3 = fields(l3)
check("nobonus(nil): item:ID:::::::::spec", l3 == "item:268247:::::::::104" and #f3 == 10 and f3[10] == "104")
check("nobonus(\"\"): 동일", BuildItemLink(268247, "") == l3)

-- 전문화 없음(GetSpecialization nil) → specID 빈 필드, 위치 유지
GetSpecialization = function() return nil end
local l4 = BuildItemLink(1, "5")
check("spec 없음: f[10]='' 유지, f[13]=1", fields(l4)[10] == "" and fields(l4)[13] == "1" and fields(l4)[14] == "5")
GetSpecialization = function() return 3 end

-- WithCurrentSpec: 도감 풀링크(이전 스펙 105)의 10번째 필드만 교체, 나머지 보존
local ej = "|cffa335ee|Hitem:268247::::::::80:105::23:2:13440:12854:1:28:2612|h[방파제 장화]|h|r"
local w = WithCurrentSpec(ej)
local wf = fields(w)
check("WithCurrentSpec: spec 105→104", wf[10] == "104")
check("WithCurrentSpec: 다른 필드 보존", wf[9] == "80" and wf[12] == "23" and wf[13] == "2" and wf[14] == "13440" and wf[15] == "12854")
check("WithCurrentSpec: 색/이름 꼬리 보존", w:sub(1, 10) == "|cffa335ee" and w:find("|h[방파제 장화]|h|r", 1, true) ~= nil)

-- WithCurrentSpec: 짧은 링크 "item:ID" → 10필드로 패딩
check("WithCurrentSpec: item:ID 패딩", WithCurrentSpec("item:268247") == "item:268247:::::::::104")

-- WithCurrentSpec: 이미 현재 스펙이면 불변 / 비링크·nil 은 그대로
check("WithCurrentSpec: 멱등", WithCurrentSpec(l1) == l1)
check("WithCurrentSpec: nil/비문자열 통과", WithCurrentSpec(nil) == nil and WithCurrentSpec(123) == 123 and WithCurrentSpec("hello") == "hello")

-- 변환 티어: 원본 아이템 modifier 64 (12.1 실링크: item:271455:8159:::::::90:250::93:8:<보너스8개>:1:64:271878)
local l5 = BuildItemLink(271473, "13334:6652:13708", 271878)
local f5 = fields(l5)
check("src: 문자열", l5 == "item:271473:::::::::104:::3:13334:6652:13708:1:64:271878")
check("src: numModifiers 는 마지막 보너스 다음(13+n+1)", f5[13] == "3" and f5[17] == "1" and f5[18] == "64" and f5[19] == "271878")
check("src: 보너스 없음 → numBonus 0 뒤 modifier", BuildItemLink(271473, nil, 271878) == "item:271473:::::::::104:::0:1:64:271878")
check("src: nil/0 → 기존 링크 그대로", BuildItemLink(271473, "5", nil) == "item:271473:::::::::104:::1:5" and BuildItemLink(271473, "5", 0) == "item:271473:::::::::104:::1:5")
check("src: 문자열 ID 허용", BuildItemLink(271473, "5", "271878") == "item:271473:::::::::104:::1:5:1:64:271878")
check("src: WithCurrentSpec 가 modifier 보존", fields(WithCurrentSpec(l5))[19] == "271878")

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
