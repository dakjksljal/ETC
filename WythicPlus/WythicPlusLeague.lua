local L = WythicPlusL -- 로케일 테이블 (Locales.lua, koKR은 원문 그대로)
-- Wythic+ 개인 뱃지 리그 툴팁
-- 플레이어 유닛 툴팁에 이번 주 리그 순위·점수·대표 뱃지를 표시한다.
-- 데이터는 WythicPlusLeagueData.lua (일일 자동 릴리즈로 갱신).

local REGION_BY_ID = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }

-- 이름+지역 폴백 인덱스 — 데이터 키의 realm은 영문 슬러그(RIO)인데 KR/TW/CN 클라의
-- 서버명은 로컬라이즈("아즈샤라")라 직접 매칭이 안 된다. 이름+지역으로 찾되,
-- 동명이인(같은 지역, 다른 서버)은 오표시 방지를 위해 표시하지 않는다.
local nameIndex
local function GetNameIndex()
    if nameIndex then return nameIndex end
    nameIndex = {}
    local entries = WythicPlusLeagueData and WythicPlusLeagueData.entries
    if entries then
        for key, e in pairs(entries) do
            local n = key:match("^(.+)%-[^%-]+$") -- 마지막 '-' 앞 = 캐릭터명
            if n then
                local nkey = n .. "@" .. (e[5] or "")
                if nameIndex[nkey] == nil then
                    nameIndex[nkey] = e
                else
                    nameIndex[nkey] = false -- 동명이인 → 사용 안 함
                end
            end
        end
    end
    return nameIndex
end

local function LookupByName(name, realm)
    local data = WythicPlusLeagueData
    if not data or not data.entries or not name or name == "" then return nil end
    local myRegion = REGION_BY_ID[GetCurrentRegion()]

    -- 1차: realm 키. 영문 클라는 서버명이 곧 슬러그. KR/TW 클라는 서버명이 "아즈샤라"처럼 로컬라이즈돼 있어
    -- 서버가 동봉한 realms 표(정규화 서버명 → 정규화 슬러그)로 바꿔 찾는다(표가 없는 구 데이터면 그대로).
    -- 정규화 = 소문자 + 공백·하이픈·아포스트로피 제거(서버 exportAddonLua와 같은 규칙).
    if not realm or realm == "" then realm = GetNormalizedRealmName() end
    if realm then
        local norm = realm:lower():gsub("[%-'%s]", "")
        local slug = (data.realms and data.realms[norm]) or norm
        local e = data.entries[name .. "-" .. slug]
        if e and (not myRegion or e[5] == myRegion) then return e, data.week end
    end

    -- 2차: 이름+지역 폴백 (realms 표에 없는 서버명·CN 클라). 동명이인은 오표시 방지로 표시 안 함, 
    -- 1차가 실패한 동명이인 캐릭터는 툴팁이 비었다(2026-09-17 제보, realms 표로 해소).
    if myRegion then
        local e = GetNameIndex()[name .. "@" .. myRegion]
        if e then return e, data.week end
    end
    return nil
end

local function RankColor(rank)
    if rank == 1 then return "|cffffd100" end      -- 금
    if rank <= 3 then return "|cffe6cc80" end      -- 메달권
    if rank <= 30 then return "|cff00ccff" end     -- 각인권
    return "|cffaaaaaa"
end

-- 시즌 랭크(승급제) 표시 — 웹 RANK_META와 동일한 이름·색
local RANK_STYLE = {
    challenger  = { ko = L["챌린저"],       c = "f2e9cf" },
    grandmaster = { ko = L["그랜드마스터"], c = "f0705a" },
    master      = { ko = L["마스터"],       c = "b98be6" },
    diamond     = { ko = L["다이아"],       c = "6cc0f0" },
    platinum    = { ko = L["플래티넘"],     c = "4fd6c4" },
    gold        = { ko = L["골드"],         c = "f0c850" },
    silver      = { ko = L["실버"],         c = "cdd4db" },
    bronze      = { ko = L["브론즈"],       c = "d09565" },
}

local ROLE_KO = { tank = L["탱커"], healer = L["힐러"], dps = L["딜러"] }

-- 뱃지 칭호는 서버가 "ko|en"으로 병기해 보낸다(영문이 없으면 한글 한 토막).
-- 비-koKR 클라이언트 폰트에는 한글 글리프가 없어 한글을 그대로 그리면 네모로 깨진다.
local IS_KO = GetLocale() == "koKR"
local function BadgeLabel(raw)
    if not raw or raw == "" then return "" end
    local ko, en = raw:match("^([^|]*)|([^|]*)$")
    if not ko then return raw end -- 병기 없음(구 데이터 또는 영문 미보유)
    if IS_KO then return ko end
    return (en ~= "" and en) or ko
end

-- 역할 한 줄 조각 — 시즌 값 있으면 "역할 랭크 N위 「뱃지」 / RP"(랭크색),
-- 없으면 주간 폴백 "역할 N위 「뱃지」 / 주간점수".
local function FormatRoleLine(role, rankKey, rp, pos, wRank, wScore, label)
    local roleTxt = ROLE_KO[role] and ("|cff9ca3af" .. ROLE_KO[role] .. "|r ") or ""
    local labelTxt = BadgeLabel(label)
    local badge = (labelTxt ~= "") and (" |cfffbbf24「" .. labelTxt .. "」|r") or ""
    local rs = rankKey and rankKey ~= "" and RANK_STYLE[rankKey]
    if rs and rp and pos and pos > 0 then
        return roleTxt .. string.format(L["|cff%s%s %d위|r%s"], rs.c, rs.ko, pos, badge),
            "|cff" .. rs.c .. BreakUpLargeNumbers(rp) .. " RP|r"
    end
    return roleTxt .. string.format(L["%s%d위|r%s"], RankColor(wRank or 999), wRank or 0, badge),
        "|cffcfcfcf" .. BreakUpLargeNumbers(wScore or 0) .. "|r"
end

-- 대표(주 역할 = 시즌 RP 최고) 한 줄 — 툴팁과 장비창 헤더가 공용.
-- 데이터: 1~9필드 = 대표 역할, e[10] = 나머지 역할 alts {역할,랭크키,RP,순위,주간순위,주간점수,뱃지}
function WythicPlus_LeagueLineParts(e)
    local left, right = FormatRoleLine(e[6], e[7], e[8], e[9], e[1], e[2], e[4])
    return "|cff00ccffWy+|r " .. left, right
end

local function AttachLeagueLine(tooltip, tooltipData)
    if tooltip ~= GameTooltip then return end
    -- 12.x: 툴팁의 유닛 토큰은 secret이라 Unit API에 못 넘긴다 → 툴팁 데이터의 GUID로 해석
    local guid = tooltipData and tooltipData.guid
    if not guid or (issecretvalue and issecretvalue(guid)) then return end
    if type(guid) ~= "string" or not guid:find("^Player%-") then return end
    local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(guid)
    if not name or name == "" or (issecretvalue and issecretvalue(name)) then return end
    local e = LookupByName(name, realm)
    if not e then return end

    -- M+ Score 스타일: 좌 라벨, 우 점수(랭크색) 정렬 — 주 역할(시즌 RP 최고) 표시
    local left, right = WythicPlus_LeagueLineParts(e)
    tooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)

    -- 다른 역할: Shift 누르고 호버하면 확장 (없으면 힌트 한 줄)
    local alts = e[10]
    if type(alts) == "table" and #alts > 0 then
        if IsShiftKeyDown() then
            for _, a in ipairs(alts) do
                local l2, r2 = FormatRoleLine(a[1], a[2], a[3], a[4], a[5], a[6], a[7])
                tooltip:AddDoubleLine("      " .. l2, r2, 1, 1, 1, 1, 1, 1)
            end
        else
            tooltip:AddLine(string.format(L["|cff5f6672      Shift — 다른 역할 %d개 보기|r"], #alts))
        end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AttachLeagueLine)
end

-- 장비 최적화 허브 등 다른 모듈에서 현재 캐릭터의 리그 정보를 재사용.
-- 반환: entry {rank, score, emoji, label, region, role}, week (없으면 nil)
-- "player" 리터럴 토큰은 secret이 아니므로 UnitFullName 직접 사용 가능.
function WythicPlus_LeaguePlayerEntry()
    return LookupByName(UnitFullName("player"))
end
