-- 스모크 테스트: 로케일별 이름 선택 (node fengari 러너 또는 luajit tests/locale-names.test.lua)
-- WythicPlusLeague.lua 의 BadgeLabel, WythicPlusGear.lua 의 EnchantName 을 미러링한다 (GetLocale 의존 → 스텁).
-- ⚠️ 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 규칙: 비-koKR 클라이언트 폰트에는 한글 글리프가 없다 → 영문이 있으면 반드시 영문, 없을 때만 한글 폴백.

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

-- 뱃지 칭호: 서버가 "ko|en" 병기로 내보낸다 (영문 없으면 한 토막)
local function BadgeLabel(raw, isKo)
    if not raw or raw == "" then return "" end
    local ko, en = raw:match("^([^|]*)|([^|]*)$")
    if not ko then return raw end
    if isKo then return ko end
    return (en ~= "" and en) or ko
end

check("ko 클라 → 한글", BadgeLabel("캐리|Carry", true) == "캐리")
check("en 클라 → 영문", BadgeLabel("캐리|Carry", false) == "Carry")
check("병기 없음(구 데이터) ko", BadgeLabel("탱신", true) == "탱신")
check("병기 없음(구 데이터) en → 한글 폴백", BadgeLabel("탱신", false) == "탱신")
check("영문 빈칸 → 한글 폴백", BadgeLabel("테토탱|", false) == "테토탱")
check("빈 칭호 → 빈 문자열", BadgeLabel("", false) == "")
check("nil 칭호 → 빈 문자열", BadgeLabel(nil, false) == "")

-- 인챈트 이름: 동봉 사전 [1]=ko, [2]=품질, [3]=두루마리 아이템ID, [4]=en("" = 미보유)
local function EnchantName(e, isKo)
    if not e then return nil end
    if not isKo and e[4] and e[4] ~= "" then return e[4] end
    return e[1]
end

local ench = { "비행자의 활력", 2, 223784, "Aerial Vitality" }
check("인챈트 ko 클라 → 한글", EnchantName(ench, true) == "비행자의 활력")
check("인챈트 en 클라 → 영문", EnchantName(ench, false) == "Aerial Vitality")
check("인챈트 en 없음 → 한글 폴백", EnchantName({ "토륨 방패 쐐기", 2, 12645, "" }, false) == "토륨 방패 쐐기")
check("인챈트 구 데이터(3필드) → 한글 폴백", EnchantName({ "돌가죽 가고일의 룬", 0, 0 }, false) == "돌가죽 가고일의 룬")
check("인챈트 nil → nil", EnchantName(nil, false) == nil)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
