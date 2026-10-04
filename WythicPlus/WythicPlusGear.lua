local L = WythicPlusL -- 로케일 테이블 (Locales.lua, koKR은 원문 그대로)
local IS_KO = GetLocale() == "koKR" -- 서버 동봉 사전(ko|en 병기)에서 이름 선택용
-- Wythic+ 장비 최적화 — 아머리 (웹 CharacterProfile.tsx 렌더 코드 기준 이식)
-- 웹 정본 스펙:
--   · 헤더: 등급 원(테두리 3px 등급색 + 8% 배경) + "메타 일치율 NN%" + 도넛 4개(스탯·특성·장비·마법부여,
--     링 색 = 해당 점수의 등급색) + [캐릭터 점검/접기] 버튼(amber)
--   · 스탯 비교: 스탯 고유색(치명 빨강/가속 초록/특화 보라/유연 파랑), 내 행(캐릭터명+색바+레이팅+%)
--     + 메타 평균 행(40% 알파 바 + 회색 %)
--   · 아머리: 좌 6슬롯 / 우 8슬롯 / 무기 2 하단 중앙. 셀 = [추천(바깥)][아이콘+체크][이름·ilvl(안쪽)]
--   · 매칭 = 아이콘 모서리 초록 체크. 추천 = amber 화살표 + amber 테두리 아이콘 + "메타N위" 코너 배지 + amber 이름

local LEFT_SLOTS = {
    { key = "HEAD", inv = 1 }, { key = "NECK", inv = 2 }, { key = "SHOULDER", inv = 3 },
    { key = "BACK", inv = 15 }, { key = "CHEST", inv = 5 },
    { key = "SHIRT", inv = 4 }, { key = "TABARD", inv = 19 }, -- 코스메틱: 착용만 표시 (진단·추천 없음)
    { key = "WRIST", inv = 9 },
}
local RIGHT_SLOTS = {
    { key = "HANDS", inv = 10 }, { key = "WAIST", inv = 6 }, { key = "LEGS", inv = 7 },
    { key = "FEET", inv = 8 }, { key = "FINGER_1", inv = 11 }, { key = "FINGER_2", inv = 12 },
    { key = "TRINKET_1", inv = 13 }, { key = "TRINKET_2", inv = 14 },
}
local BOTTOM_SLOTS = {
    { key = "MAIN_HAND", inv = 16 }, { key = "OFF_HAND", inv = 17 },
}

-- 웹 STAT_COLORS (constants.ts)
local STAT_COLORS = {
    crit = { 0.937, 0.267, 0.267 },        -- #ef4444
    haste = { 0.133, 0.773, 0.369 },       -- #22c55e
    mastery = { 0.659, 0.333, 0.969 },     -- #a855f7
    versatility = { 0.231, 0.510, 0.965 }, -- #3b82f6
}
local STAT_LABELS = { crit = L["치명타"], haste = L["가속"], mastery = L["특화"], versatility = L["유연성"] }
local STAT_ORDER = { "crit", "haste", "mastery", "versatility" }
local CR_BY_STAT = { crit = CR_CRIT_MELEE, haste = CR_HASTE_MELEE, mastery = CR_MASTERY, versatility = CR_VERSATILITY_DAMAGE_DONE }

local AMBER = { 0.961, 0.62, 0.043 } -- #f59e0b (메타 계열)
local EMERALD = { 0.204, 0.827, 0.6 } -- #34d399 (가방/소지품 계열)
local SKY = { 0.22, 0.74, 0.97 } -- 던전 탭 계열
local VIOLET = { 0.75, 0.52, 0.99 } -- 레이드 탭 계열
local TEAL = { 0.176, 0.831, 0.749 } -- #2dd4bf (마나용제 변환 가정 계열, 웹 catalyst 색)
local CRAFT_BLUE = { 0.376, 0.647, 0.980 } -- #60a5fa (제작 탭 계열 — 출처 칩 "제작"과 같은 색)
local RING_BG = { 0.153, 0.153, 0.165 } -- #27272a

local ROW_H = 52
local ICON = 40
local NAME_W = 170
local REC_W = 310
local COL_W = REC_W + 6 + ICON + 6 + NAME_W
local MODEL_W = 250
local PANEL_W = COL_W * 2 + MODEL_W + 32
local PANEL_H = 952 -- 스탯 거터 박스 + 근접도 밴드 포함 — 무기/푸터까지 겹침 없이
local UI_MARGIN = 64 -- 히어로·스탯 등 컨텐츠 공통 좌우 마진
local PAIRED_KEYS = { FINGER_1 = true, FINGER_2 = true, TRINKET_1 = true, TRINKET_2 = true }
local PAIRED_OF = { FINGER_1 = "FINGER_2", FINGER_2 = "FINGER_1", TRINKET_1 = "TRINKET_2", TRINKET_2 = "TRINKET_1" }

local function HexToRGB(hex)
    hex = hex:gsub("#", "")
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- 패널·스킨 상태 (파일 전역 — 아래 모든 함수가 업밸류로 참조하므로 최상단에 선언)
local panel
local ShowEnchantDropdown -- 마법부여 선택 드롭다운 (드롭다운 모듈에서 할당 — 카드 마부 줄 클릭이 참조)
-- 커스텀 초기화(모드/필터 전환) 시 잠긴 슬롯의 핀은 보존 — 잠금 = 사용자가 확정한 선택.
-- ⚠️ 핸들러 클로저들이 참조하므로 반드시 패널 생성 코드보다 먼저(파일 레벨) 정의할 것.
local function WipeCustomKeepLocked()
    for k in pairs(panel.pinnedItems) do
        if not panel.lockedSlots[k] then
            panel.pinnedItems[k] = nil
        end
    end
    for k in pairs(panel.pinnedConv) do
        if not panel.lockedSlots[k] then panel.pinnedConv[k] = nil end
    end
    for k in pairs(panel.pinnedGems) do
        if not panel.lockedSlots[k] then panel.pinnedGems[k] = nil end
    end
    for k in pairs(panel.pinnedEnchants) do
        if not panel.lockedSlots[k] then panel.pinnedEnchants[k] = nil end
    end
    for k in pairs(panel.pinnedTracks) do
        if not panel.lockedSlots[k] then panel.pinnedTracks[k] = nil end
    end
    wipe(panel.dismissedSlots)
end
local euiSkin

-- 폰트 한 단계 업(+1pt) — 전체 가독성 (템플릿 폰트 유지, 크기만)
local function BumpFont(fsObj)
    local f, size, flags = fsObj:GetFont()
    if f and size then fsObj:SetFont(f, size + 1, flags) end
    return fsObj
end

-- 창 안 요소들의 툴팁 공통 처리: 창을 가리지 않게 패널 오른쪽 바깥에 고정하고,
-- 장착 아이템 자동 비교 툴팁(ShoppingTooltip)은 억제한다 — 호버한 아이템만 보이게.
local function OwnTooltip(anchor, sideFrame)
    GameTooltip:SetOwner(panel, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    if not anchor and sideFrame then
        -- 아머리 뷰 툴팁: 호버한 요소가 패널 왼쪽 절반이면 패널 왼쪽 바깥에
        local sx = sideFrame:GetCenter()
        local px = panel:GetCenter()
        if sx and px and sx < px then
            GameTooltip:SetPoint("TOPRIGHT", panel, "TOPLEFT", -12, 0)
            return
        end
    end
    if anchor then
        -- 드롭다운 내부 툴팁: 드롭다운이 패널 왼쪽 절반에 있으면 왼쪽에, 아니면 오른쪽에
        -- (왼쪽 열 슬롯의 드롭다운 툴팁이 본문을 덮지 않게)
        local ax = anchor:GetCenter()
        local px = panel:GetCenter()
        if ax and px and ax < px then
            GameTooltip:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -12, 0)
        else
            GameTooltip:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 12, 0)
        end
    else
        GameTooltip:SetPoint("TOPLEFT", panel, "TOPRIGHT", 12, 0)
    end
end
local function FinishTooltip()
    GameTooltip:Show()
    if ShoppingTooltip1 then ShoppingTooltip1:Hide() end
    if ShoppingTooltip2 then ShoppingTooltip2:Hide() end
end

-- 트랙 선택 툴팁 — 보너스 문자열의 트랙 단계 ID를 목표 ilvl의 ID로 교체하면
-- 클라이언트가 그 트랙 ilvl·스탯으로 툴팁을 그린다. ID 맵(trackBonus: ilvl→bonusID)은
-- 서버가 수집 데이터 통계로 도출해 동봉(시즌 자동 추종 — 하드코딩 없음).
local function RelinkTrackBonuses(bonuses, targetIlvl)
    local map = WythicPlusGearData and WythicPlusGearData.trackBonus
    local target = map and targetIlvl and map[targetIlvl]
    if not target then return bonuses end
    local stepIds = {}
    for _, id in pairs(map) do stepIds[id] = true end
    local kept = {}
    local removed = false
    if bonuses and bonuses ~= "" then
        for id in bonuses:gmatch("[^:]+") do
            if stepIds[tonumber(id)] then
                removed = true
            else
                kept[#kept + 1] = id
            end
        end
    end
    -- 원래 트랙 단계 ID가 없던 링크(맹독저주 등 고정템)에 무단 추가하면
    -- "신화 6/6 + 맹독저주" 같은 존재 불가능한 툴팁이 생긴다 → 교체만 허용
    if not removed then return bonuses end
    kept[#kept + 1] = tostring(target)
    return table.concat(kept, ":")
end

-- 링크 보너스에 트랙 단계 ID가 있는가 — 없으면 트랙 개념 밖(맹독저주 등 고정템)
local function HasTrackStep(bonuses)
    local map = WythicPlusGearData and WythicPlusGearData.trackBonus
    if not (map and bonuses and bonuses ~= "") then return false end
    local stepIds = {}
    for _, id in pairs(map) do stepIds[id] = true end
    for id in bonuses:gmatch("[^:]+") do
        if stepIds[tonumber(id)] then return true end
    end
    return false
end

-- 아이템 캐시 미로드 시 로드 요청 (GET_ITEM_INFO_RECEIVED로 재드로우)
-- ⚠️ SetRec 등 상단 함수들이 참조하므로 반드시 이들보다 먼저 정의할 것
-- 우리가 요청한 ID만 ITEM_PENDING에 기록해 이벤트 재드로우를 그 ID에 한정하고, 로드 실패(success=false) ID는
-- ITEM_FAILED에 넣어 재요청하지 않는다. 이전엔 모든 아이템 이벤트(다른 애드온 조회 포함)에 전체 리드로우를
-- 돌렸고, 리드로우가 낸 요청의 응답이 다시 리드로우를 불러 연쇄·실패 아이템은 무한 반복됐다
-- (2026-09-11 인벤 제보: 창 열면 모델이 떨리며 계속 새로고침, 열고 닫기 반복 시 프레임 하락).
local ITEM_PENDING, ITEM_FAILED = {}, {}
local function EnsureItem(itemId)
    if not itemId or itemId == 0 or ITEM_FAILED[itemId] or ITEM_PENDING[itemId] then return end
    if not C_Item.GetItemInfo(itemId) then
        ITEM_PENDING[itemId] = true
        C_Item.RequestLoadItemDataByID(itemId)
    end
end
-- GET_ITEM_INFO_RECEIVED(itemId, success) 처리 — 재드로우가 필요하면 true
local function OnItemInfoReceived(itemId, success)
    if not ITEM_PENDING[itemId] then return false end
    ITEM_PENDING[itemId] = nil
    if success == false then
        ITEM_FAILED[itemId] = true
        return false
    end
    return true
end

-- 추천 화살표 — 웹 SVG(축+삼각머리)를 재현한 동봉 텍스처. 애드온에 포함되므로
-- 모든 유저에게 항상 존재(클라이언트 내장 텍스처 의존 없음). 흰색 원본에 색을 입힌다.
-- ⚠️ AttachRecSub 등 아래 함수들이 참조하므로 반드시 이들보다 먼저 정의할 것.
local ARROW_TEX = "Interface\\AddOns\\WythicPlus\\Textures\\arrow"
local function StyleRecArrow(arrow, pointRight, r, g, b, w, h)
    arrow:SetTexture(ARROW_TEX)
    arrow:SetSize(w or 20, h or 10)
    if not pointRight then arrow:SetTexCoord(1, 0, 0, 1) end
    arrow:SetVertexColor(r or AMBER[1], g or AMBER[2], b or AMBER[3])
end

-- "메타N위" 코너 배지 — 텍스처 레이어 밀림 방지를 위해 상위 프레임으로 그린다
local function AttachRecBadge(rec, anchor)
    local bf = CreateFrame("Frame", nil, rec, "BackdropTemplate")
    bf:SetSize(38, 12)
    bf:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
    bf:SetFrameLevel(rec:GetFrameLevel() + 3)
    bf:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    bf:SetBackdropColor(AMBER[1], AMBER[2], AMBER[3], 1)
    rec.badge = bf:CreateFontString(nil, "OVERLAY")
    rec.badge:SetFont(STANDARD_TEXT_FONT, 8, "")
    rec.badge:SetTextColor(0, 0, 0)
    rec.badge:SetPoint("CENTER")
    rec.badgeFrame = bf
end

-- 마법부여/보석 서브 스택 — 웹 extras처럼 이름 바깥쪽 옆, 각 항목 한 줄 고정(줄바꿈 금지)
-- + 항목별 슬롯 방향 미니 화살표(마부 보라 / 보석 파랑) + 마우스 호버 툴팁
local function AttachRecSub(rec, isLeft)
    local just = isLeft and "RIGHT" or "LEFT"
    local function line(ar, ag, ab)
        local f = CreateFrame("Frame", nil, rec)
        f:SetSize(150, 14)
        f.fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.fs:SetAllPoints(f)
        f.fs:SetJustifyH(just)
        f.fs:SetWordWrap(false)
        f.arrow = rec:CreateTexture(nil, "ARTWORK")
        StyleRecArrow(f.arrow, isLeft, ar, ag, ab, 14, 7)
        f.arrow:SetPoint(isLeft and "LEFT" or "RIGHT", f, isLeft and "RIGHT" or "LEFT", isLeft and 1 or -1, 0)
        -- 착용 표시용(기본 화면): 줄이 안쪽에 있을 때 아이템(바깥) 쪽을 가리키는 반대 방향 화살표
        f.arrowIn = rec:CreateTexture(nil, "ARTWORK")
        StyleRecArrow(f.arrowIn, not isLeft, ar, ag, ab, 14, 7)
        f.arrowIn:SetPoint(isLeft and "RIGHT" or "LEFT", f, isLeft and "LEFT" or "RIGHT", isLeft and -1 or 1, 0)
        f.arrowIn:Hide()
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(self)
            OwnTooltip(nil, self)
            if self.tipItemId and self.tipItemId > 0 then
                GameTooltip:SetItemByID(self.tipItemId)
            elseif self.tipText then
                GameTooltip:SetText(self.tipText, 1, 1, 1)
            else
                GameTooltip:Hide()
                return
            end
            FinishTooltip()
        end)
        f:SetScript("OnLeave", GameTooltip_Hide)
        f:SetScript("OnMouseDown", function(self)
            local r = self:GetParent() -- rec
            -- 마부 줄 = 마법부여 선택, 보석 줄 = 보석 선택
            if self.isEnch and r.slotKey and ShowEnchantDropdown then
                ShowEnchantDropdown(r.slotKey, self)
            elseif r.slotKey and ShowGemDropdown then
                ShowGemDropdown(r.slotKey, self)
            end
        end)
        f.SetShownAll = function(self, shown)
            self:SetShown(shown)
            self.arrow:SetShown(shown)
            if self.arrowIn and not shown then self.arrowIn:Hide() end
        end
        f:SetShownAll(false)
        return f
    end
    rec.subEnch = line(0.655, 0.545, 0.980) -- #a78bfa
    rec.subEnch.isEnch = true
    rec.subGem = line(0.376, 0.647, 0.980)  -- #60a5fa
    rec.subInward = isLeft and "RIGHT" or "LEFT"
    rec.subOutward = isLeft and "LEFT" or "RIGHT"
end

-- 추천 등장 페이드 애니메이션
local function AttachRecAnim(rec)
    rec.anim = rec:CreateAnimationGroup()
    local a = rec.anim:CreateAnimation("Alpha")
    a:SetFromAlpha(0)
    a:SetToAlpha(1)
    a:SetDuration(0.35)
    a:SetSmoothing("OUT")
end

-- 출처 칩 — 웹 sourceLabel/sourceColor와 동일 규칙
-- 타입 라벨(티어/제작 등)이 이름보다 우선 → 이름 없는 티어 세트도 표시된다
local SOURCE_TYPE_LABEL = {
    tier = L["티어 세트"], craft = L["제작"], crafted = L["제작"],
    ["pvp-set"] = L["PvP 세트"], pvp = "PvP", catalyst = L["변환"],
}
local SOURCE_TYPE_COLOR = { -- tailwind 400 계열 (웹 sourceColor)
    dungeon = "4ade80", raid = "c084fc", tier = "fbbf24",
    craft = "60a5fa", crafted = "60a5fa",
    ["pvp-set"] = "f87171", pvp = "f87171", catalyst = "2dd4bf",
}
local SOURCE_NAME_COLOR = { -- 이름별 특수색 (웹과 동일)
    ["March on Quel'Danas"] = "fb923c", ["Sporefall"] = "a3e635",
    ["Field Boss"] = "e879f9", ["Vendor"] = "facc15", ["Quest"] = "38bdf8", ["BoE"] = "fb7185",
}
local DUNGEON_BADGE_HEX = { -- 시즌2 던전별 고유색 (웹 DUNGEON_BADGE_HEX와 동일)
    ["Altar of Fangs"] = "a8de7c", ["Murder Row"] = "aa7cde", ["Den of Nalorakk"] = "7cdeb8",
    ["The Blinding Vale"] = "dece7c", ["Voidscar Arena"] = "7c7cde", ["Ruby Life Pools"] = "7cc6de",
    ["Temple of Sethraliss"] = "de857c", ["Kings' Rest"] = "7cde7c",
}
-- 인챈트 이름 — 동봉 사전 [1]=ko, [4]=en("" = 미보유). 비-koKR 클라는 폰트에 한글
-- 글리프가 없어 ko를 그대로 그리면 네모로 깨지므로 en을 우선한다(구 데이터는 ko 폴백).
local function EnchantName(e)
    if not e then return nil end
    if not IS_KO and e[4] and e[4] ~= "" then return e[4] end
    return e[1]
end

-- 출처 라벨·색 (웹 sourceLabel/sourceColor 규칙) — 뱃지 렌더용으로 분리 반환
local function SourceChip(srcType, nameKo, nameEn)
    local first, second = nameKo, nameEn
    if not IS_KO then first, second = nameEn, nameKo end
    local label = SOURCE_TYPE_LABEL[srcType]
        or (first ~= "" and first) or (second ~= "" and second) or nil
    if not label then return nil, nil end
    local c
    if srcType == "raid" then
        c = SOURCE_NAME_COLOR[nameEn] or SOURCE_TYPE_COLOR.raid
    elseif srcType == "dungeon" then
        c = DUNGEON_BADGE_HEX[nameEn] or SOURCE_TYPE_COLOR.dungeon -- 웹 dungeonBadgeStyle: 던전별 고유색
    else
        c = SOURCE_TYPE_COLOR[srcType] or SOURCE_NAME_COLOR[nameEn] or "a1a1aa"
    end
    return label, c
end

-- 출처 뱃지 위젯 — 웹처럼 색 10% 배경 + 색 글자의 알약 형태
local function AttachSrcBadge(rec, isLeft)
    local ShowGemDropdown -- 보석 선택 드롭다운 (드롭다운 모듈에서 할당 — 클로저 전방 선언)

-- 이름 아랫줄: [아이템레벨] [출처 뱃지] — 안쪽 정렬
    rec.ilvlText = rec:CreateFontString(nil, "OVERLAY")
    rec.ilvlText:SetFont(STANDARD_TEXT_FONT, 11, "")
    rec.ilvlText:SetTextColor(0.62, 0.62, 0.68)
    local bf = CreateFrame("Frame", nil, rec, "BackdropTemplate")
    bf:SetHeight(14)
    bf:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    bf.fs = bf:CreateFontString(nil, "OVERLAY")
    bf.fs:SetFont(STANDARD_TEXT_FONT, 10, "")
    bf.fs:SetPoint("CENTER")
    if isLeft then
        rec.ilvlText:SetPoint("TOPRIGHT", rec.name, "BOTTOMRIGHT", 0, -3)
        bf:SetPoint("RIGHT", rec.ilvlText, "LEFT", -5, 0)
    else
        rec.ilvlText:SetPoint("TOPLEFT", rec.name, "BOTTOMLEFT", 0, -3)
        bf:SetPoint("LEFT", rec.ilvlText, "RIGHT", 5, 0)
    end
    bf:Hide()
    rec.srcBadge = bf
end

-- 출처 뱃지 채우기/숨김. conv("type|ko|en") = 마나용제 변환 티어 → "변환: 원본명" teal 뱃지
local function SetSrcBadge(rec, srcType, nameKo, nameEn, conv, convFrom, craftLabel)
    local label, hex
    -- 제작 탭 핀: 칩 = "제작 · 지정 스탯" (제작 색)
    if craftLabel then
        label, hex = craftLabel, "60a5fa"
    end
    -- 마나용제 변환 가정 추천: 칩 = 마나용제 아이콘 + "세트 변환 필요" (원본 아이템명은 툴팁 줄에)
    if not label and convFrom then
        local icon = WythicPlus_GearCatalystInfo and WythicPlus_GearCatalystInfo()
        local pre = icon and ("|T" .. icon .. ":12:12:0:0|t ") or ""
        label, hex = pre .. L["세트 변환 필요"], "2dd4bf"
    end
    if not label and conv and conv ~= "" then
        local _, ck, ce = conv:match("^([^|]*)|([^|]*)|([^|]*)$")
        if not IS_KO then ck, ce = ce, ck end
        local nm = (ck and ck ~= "" and ck) or ce or ""
        if nm ~= "" then
            label, hex = L["변환: "] .. nm, "2dd4bf" -- teal (웹 catalyst 색)
        end
    end
    if not label then
        label, hex = SourceChip(srcType, nameKo or "", nameEn or "")
    end
    if not label then
        rec.srcBadge:Hide()
        return
    end
    local r, g, b = HexToRGB(hex)
    rec.srcBadge:SetBackdropColor(r, g, b, 0.13)
    rec.srcBadge.fs:SetText(label)
    rec.srcBadge.fs:SetTextColor(r, g, b)
    rec.srcBadge:SetWidth(rec.srcBadge.fs:GetStringWidth() + 10)
    rec.srcBadge:Show()
end

-- 추천 표시/숨김 (아이템 교체 + 마법부여/보석 서브 라인, 애니메이션 포함)
local ENCH_ICON = "|TInterface\\Icons\\INV_Misc_EnchantedScroll:14:14:0:0:64:64:5:59:5:59|t"
local function SetRec(rec, recInfo, animate)
    local hasItem = recInfo and recInfo.itemId
    local hasSub = recInfo and (recInfo.ench or recInfo.gemId or recInfo.gemEmpty or recInfo.gemNone)
    if not (hasItem or hasSub) then
        rec.itemId = nil
        rec:Hide()
        return
    end
    local wasHidden = not rec:IsShown()

    if hasItem then
        rec.itemId = recInfo.itemId
        rec.icon:SetTexture(C_Item.GetItemIconByID(recInfo.itemId) or 134400)
        rec.name:SetText(C_Item.GetItemNameByID(recInfo.itemId) or (L["아이템 "] .. recInfo.itemId))
        rec.ilvlText:SetText((recInfo.ilvl and recInfo.ilvl > 0) and tostring(recInfo.ilvl) or "")
        rec.ilvlText:Show()
        SetSrcBadge(rec, recInfo.srcType, recInfo.srcName, recInfo.srcNameEn, recInfo.conv, recInfo.convFrom, recInfo.craftLabel) -- 출처 뱃지 (웹 스타일)
        local st = recInfo.srcTab
        rec.badge:SetText(recInfo.convFrom and L["용제 변환"]
            or (st == "dungeon" or st == "raid" or st == "craft") and L["커스텀"]
            or (recInfo.bagLink and st ~= "meta") and L["가방"]
            or (recInfo.rank and string.format(L["메타 %d위"], recInfo.rank)) or L["추천"])
        rec.recIlvl = recInfo.ilvl
        rec.recBonuses = recInfo.bonuses
        rec.recLink = recInfo.bagLink
        rec.recConvFrom = recInfo.convFrom -- 마나용제 변환 가정: 원본 아이템 ID / 원본 링크(핀 승격 시 스탯 출처)
        rec.recConvLink = recInfo.convLink
        rec.recConvWorn = recInfo.convWorn
        rec.recConv = recInfo.conv or "" -- 잠금 시 핀 승격용 (변형 구분)
        rec.recSrcTab = recInfo.srcTab -- 잠금 승격 핀이 출처 탭 색/딱지를 유지하도록
        rec.recTrackPinned = recInfo.trackPinned
        rec.recCrafted = (recInfo.srcType == "crafted")
        rec.recCraftStats = recInfo.craftStats -- 제작 탭 핀: 툴팁 2차 스탯 줄을 지정 스탯으로 고쳐 쓴다
        -- 탭 색 체계 그대로: 메타=앰버 / 가방=에메랄드 / 던전=하늘 / 레이드=보라 / 제작=파랑
        -- (srcTab이 "meta"인 링크 핀 — Peak 344 등 — 은 메타 취급, 앰버)
        local rc = AMBER
        if recInfo.convFrom then rc = TEAL
        elseif st == "dungeon" then rc = SKY
        elseif st == "raid" then rc = VIOLET
        elseif st == "craft" then rc = CRAFT_BLUE
        elseif recInfo.bagLink and st ~= "meta" then rc = EMERALD end
        rec.iconBorder:SetVertexColor(rc[1], rc[2], rc[3], 1)
        rec.arrow:SetVertexColor(rc[1], rc[2], rc[3])
        rec.badgeFrame:SetBackdropColor(rc[1], rc[2], rc[3], 1)
        if recInfo.convFrom or st == "dungeon" or st == "raid" or st == "craft" then
            rec.name:SetTextColor(rc[1], rc[2], rc[3])
        elseif recInfo.bagLink and st ~= "meta" then
            rec.name:SetTextColor(0.42, 0.85, 0.66) -- emerald-350쯤 (가독용 밝은 톤)
        else
            rec.name:SetTextColor(0.98, 0.75, 0.14) -- amber-400 (기존)
        end
        rec.arrow:Show() -- amber 화살표는 아이템 교체 추천 전용 (마부/보석엔 자체 미니 화살표)
        rec.icon:Show(); rec.iconBorder:Show(); rec.name:Show(); rec.badgeFrame:Show()
    else
        rec.itemId = nil
        rec.recIlvl = nil
        rec.recBonuses = nil
        rec.recLink = nil
        rec.recConvFrom = nil
        rec.recConvLink = nil
        rec.recConvWorn = nil
        rec.recTrackPinned = nil
        rec.recCraftStats = nil
        rec.srcBadge:Hide()
        rec.ilvlText:Hide()
        rec.arrow:Hide()
        rec.icon:Hide(); rec.iconBorder:Hide(); rec.name:Hide(); rec.badgeFrame:Hide()
    end

    -- 마법부여(보라) / 보석(파랑) 서브 라인 — 인라인 아이콘 + 이름, 항목당 한 줄 고정
    -- 마부 이름은 두루마리 아이템 실제 품질색 (품질 미상이면 흰색)
    local enchTxt = nil
    if recInfo.ench then
        local qc = recInfo.enchQuality and ITEM_QUALITY_COLORS[recInfo.enchQuality]
        enchTxt = ENCH_ICON .. " " .. (qc and qc.hex or "|cffffffff") .. recInfo.ench .. "|r"
    end
    local gemTxt = nil
    if recInfo.gemId then
        EnsureItem(recInfo.gemId)
        local gname = C_Item.GetItemNameByID(recInfo.gemId) or L["보석"]
        local gicon = C_Item.GetItemIconByID(recInfo.gemId)
        -- 보석 이름도 실제 아이템 품질색 (캐시 미로드면 흰색 → 로드 이벤트로 재드로우됨)
        local gq = C_Item.GetItemQualityByID(recInfo.gemId)
        local gqc = gq and ITEM_QUALITY_COLORS[gq]
        gemTxt = (gicon and ("|T" .. gicon .. ":14:14|t ") or "") .. (gqc and gqc.hex or "|cffffffff") .. gname .. "|r"
    elseif recInfo.gemEmpty or recInfo.gemNone then
        -- 빈 소켓 (웹의 점선 다이아 자국) — 상태 표시 "빈 홈"(지시형 "보석 선택"은 빼라는 듯 읽혔음, 2026-09-12).
        -- 클릭하면 보석 선택창. 보석 해제 핀도 같은 표시
        gemTxt = L["|cff5f6672◇ 빈 홈|r"]
    end
    local anchor = hasItem and rec.name or rec -- 아이템 추천 옆 / 없으면 rec 안쪽 끝 기준
    local anchorPoint = hasItem and rec.subOutward or rec.subInward
    -- 미니 화살표(14px) 자리: 아이템 있으면 이름과 간격, 없으면 착용 아이콘 쪽에 바짝
    local ax = (rec.subInward == "RIGHT" and -1 or 1) * (hasItem and 18 or 26)
    local both = enchTxt and gemTxt
    if enchTxt then
        rec.subEnch.fs:SetText(enchTxt)
        rec.subEnch.tipItemId = recInfo.enchItemId
        rec.subEnch.tipText = recInfo.ench
        if recInfo.enchItemId and recInfo.enchItemId > 0 then EnsureItem(recInfo.enchItemId) end
        rec.subEnch:ClearAllPoints()
        rec.subEnch:SetPoint(rec.subInward, anchor, anchorPoint, ax, both and 8 or 0)
        rec.subEnch:SetShownAll(true)
    else
        rec.subEnch:SetShownAll(false)
    end
    if gemTxt then
        rec.subGem.fs:SetText(gemTxt)
        rec.subGem.tipItemId = recInfo.gemId
        rec.subGem.tipText = nil
        rec.subGem:ClearAllPoints()
        local cell = rec:GetParent()
        if recInfo.gemWorn and cell and cell.icon then
            -- 기본 화면(비슬라이드): 착용 아이콘 바깥쪽에 추천 줄과 완전히 동일하게 —
            -- 화살표가 아이콘을 가리키고, 클릭 = 보석 커스텀. 공간은 셀 바깥까지 사용
            rec.subGem.fs:SetJustifyH(rec.subInward == "RIGHT" and "RIGHT" or "LEFT")
            rec.subGem:SetPoint(rec.subInward, cell.icon, rec.subOutward,
                rec.subInward == "RIGHT" and -18 or 18, 0)
            rec.subGem:SetShownAll(true)
            if rec.subGem.arrowIn then rec.subGem.arrowIn:Hide() end
        else
            rec.subGem.fs:SetJustifyH(rec.subInward == "RIGHT" and "RIGHT" or "LEFT")
            rec.subGem:SetPoint(rec.subInward, anchor, anchorPoint, ax, both and -8 or 0)
            rec.subGem:SetShownAll(true)
            if rec.subGem.arrowIn then rec.subGem.arrowIn:Hide() end
        end
    else
        rec.subGem:SetShownAll(false)
    end

    rec:Show()
    if animate and wasHidden and rec.anim then rec.anim:Play() end
end

-- 시뮬 입력 필터: ①체크 해제된 레이드 출처 제외 ②저레벨 쓰레기 후보 제외
-- (랭커가 형상용 등으로 잠깐 착용해 수집에 낀 옛 아이템이 추천을 오염시키는 것 방지 —
--  슬롯 내 최고 ilvl보다 100 이상 낮으면 후보에서 뺀다)
-- 순위 라벨은 웹 규칙대로 절대 순위 — 원본 spec으로 계산하므로 여기선 items만 거른다.
local function FilterSpecItems(spec, excluded)
    local src = WythicPlusGearData.sources or {}
    local items = {}
    for slot, list in pairs(spec.items or {}) do
        local maxIlvl = 0
        for i = 1, #list do
            local il = list[i][3] or 0
            if il > maxIlvl then maxIlvl = il end
        end
        local out = {}
        for i = 1, #list do
            local e = list[i]
            local s = src[e[1]]
            local raidExcluded = s and s[1] == "raid" and excluded[s[3]]
            local tooLow = (e[3] or 0) < maxIlvl - 100
            if not raidExcluded and not tooLow then out[#out + 1] = e end
        end
        items[slot] = out
    end
    -- 쌍 슬롯(반지/장신구): 양쪽 후보 합집합을 통합 순위(paired)로 정렬해 두 슬롯이 공유 —
    -- 슬롯별 상위가 제외될 때 반대쪽의 통합 상위를 두고 낮은 순위로 건너뛰는 문제 방지
    -- (같은 아이템 쌍 중복은 엔진이 자체 회피)
    local PAIR_MERGE = { { "FINGER_1", "FINGER_2" }, { "TRINKET_1", "TRINKET_2" } }
    for _, pr in ipairs(PAIR_MERGE) do
        local a, b = items[pr[1]], items[pr[2]]
        if a and b then
            local merged, seen = {}, {}
            for _, srcList in ipairs({ a, b }) do
                for i = 1, #srcList do
                    local e = srcList[i]
                    local k = e[1] .. "|" .. (e[12] or "")
                    if not seen[k] then
                        seen[k] = true
                        merged[#merged + 1] = e
                    end
                end
            end
            local paired = spec.paired
            table.sort(merged, function(x, y)
                local rx = (paired and paired[x[1]]) or 999
                local ry = (paired and paired[y[1]]) or 999
                if rx ~= ry then return rx < ry end
                return (x[2] or 0) > (y[2] or 0)
            end)
            -- 다른 부위와 동일하게 '통합 순위 5위까지'만 취급 (6위 이하 순위는 제외)
            for i = #merged, 1, -1 do
                local r = (paired and paired[merged[i][1]]) or 999
                if r > 5 then table.remove(merged, i) end
            end
            items[pr[1]] = merged
            items[pr[2]] = merged
        end
    end
    return setmetatable({ items = items }, { __index = spec })
end

-- 현 시즌 레이드 — 웹 CharacterProfile와 동일한 명시 목록 (한밤 시즌2). 시즌 교체 시 함께 갱신.
-- 데이터에서 휴리스틱으로 뽑으면 형상용 착용 등으로 수집에 낀 옛 레이드가 섞여서 안 됨.
local SEASON_RAIDS = {
    { en = "The Venomous Abyss", ko = L["맹독 심연"] },
    { en = "The Tidebound Grotto", ko = L["해일결속 동굴"] },
}
local function CollectRaids()
    return SEASON_RAIDS
end

-- 데이터 items에서 아이템 항목 조회. 쌍 슬롯(반지/장신구)은 엔진이 두 슬롯 목록을 합쳐 고르므로 반대 슬롯 목록에만
-- 있는 아이템이 이 슬롯에 추천될 수 있다 → 제 목록에 없으면 반대 슬롯 목록까지 본다. 안 보면 ilvl·보너스ID가 비어
-- 카드에 레벨이 안 뜨고 툴팁이 보너스 없는 기본 아이템(저레벨 희귀)으로 뜬다(2026-09-26 제보: 부정 DK 공명의 울림석).
-- (tests/pair-dedup.test.lua 가 미러 — 변경 시 함께 갱신)
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

-- 데이터 items에서 아이템의 수집 ilvl·보너스ID 조회
-- (제작템 등은 base 툴팁이 저레벨로 떠서, 보너스ID 링크로 실제 착용 상태 툴팁을 띄운다)
local function MetaItemInfo(spec, slotKey, itemId, conv)
    local e = FindMetaEntry(spec, slotKey, itemId, conv)
    if e then return e[3], e[11], e[12] end -- ilvl, bonuses, conv("type|ko|en")
    return nil, nil, nil
end

-- 데이터 items에서 아이템의 2차 스탯 (프리셋 저장용 — 데이터 개편에도 프리셋이 살아있게 스냅샷)
-- conv(변환 원본, e[12])를 주면 그 변형만 — 같은 itemId의 일반/변환 티어는 스탯 배분이 다르다
local function MetaItemStats(spec, slotKey, itemId, conv)
    local e = FindMetaEntry(spec, slotKey, itemId, conv)
    if e then return { crit = e[4] or 0, haste = e[5] or 0, mastery = e[6] or 0, versatility = e[7] or 0 } end
    return nil
end

-- 메타 순위 (반지/장신구는 쌍 슬롯 합산 순위, 그 외는 슬롯 목록 인덱스)
-- conv(변환 원본, e[12])까지 맞춰 변형 구분 — 같은 itemId의 일반/변환 티어가 둘 다 1위로 뜨는 것 방지
local function MetaRankOf(spec, slotKey, itemId, conv)
    if PAIRED_KEYS[slotKey] and spec.paired and spec.paired[itemId] then
        return spec.paired[itemId]
    end
    local list = spec.items and spec.items[slotKey]
    if list then
        for i = 1, #list do
            local e = list[i]
            if e[1] == itemId and (conv == nil or (e[12] or "") == conv) then return i end
        end
    end
    return nil
end

-- ── 2차 스탯 배분: 게임 표시 vs 수집 데이터 ──
-- 애드온이 조립한 링크(아이템ID + 보너스ID)로는 게임이 2차 스탯을 항상 맞게 그리지 못한다. 마나용제 변환 티어는
-- 원본 배분을 링크 modifier 64로, 레이드 착귀·제작템의 "무작위 능력치 1/2"는 modifier 29/30(제작 스탯)으로 정하는데
-- Blizzard API bonus_list에는 둘 다 없다(2026-09-09 변환 티어 제보, 2026-09-20 착귀 견갑 "무작위 능력치 1 +100" 제보).
-- 인코딩을 하나씩 좇지 않고 한 규칙으로 처리한다: 게임이 그린 2차 스탯 줄(자리표시자 포함)을 읽어 수집 배분과 비율이
-- 다르면 그 ilvl 예산을 수집 배분으로 재분배해 같은 줄에 덮어쓴다. 같으면 손대지 않는다. 표시 = 시뮬에 쓴 값.
-- 수치도 같은 규칙: TrackPinLinkStats가 AlignLinkStats로 링크 스탯을 보정한다. 웹은 DB 스탯을 써 영향 없음.
local function IsConvertedVariant(conv)
    return conv ~= nil and conv ~= ""
end

-- 예산 total(게임이 준 그 ilvl의 2차 스탯 합)을 데이터 배분 비율로 나눈다 — 선형 추정 아님. 나눌 수 없으면 nil
local function SplitBudget(total, dataStats)
    local dtotal = 0
    for _, k in ipairs(STAT_ORDER) do dtotal = dtotal + (dataStats[k] or 0) end
    if not total or total <= 0 or dtotal <= 0 then return nil end
    local out = {}
    for _, k in ipairs(STAT_ORDER) do
        out[k] = math.floor(total * (dataStats[k] or 0) / dtotal + 0.5)
    end
    return out
end

-- 링크에서 읽은 2차 스탯 총량을 데이터 배분 비율로 재분배(다른 키는 유지)
local function RedistributeSecondary(linkStats, dataStats)
    local total = 0
    for _, k in ipairs(STAT_ORDER) do total = total + (linkStats[k] or 0) end
    local split = SplitBudget(total, dataStats)
    if not split then return linkStats end
    local out = {}
    for k, v in pairs(linkStats) do out[k] = v end
    for _, k in ipairs(STAT_ORDER) do out[k] = split[k] end
    return out
end

-- 두 배분의 비율이 같은가(총량은 ilvl 차이로 달라도 됨). 종류가 다르거나 비율 차가 tol을 넘으면 false
local function SameSecondarySplit(a, b, tol)
    tol = tol or 0.03
    local ta, tb = 0, 0
    for _, k in ipairs(STAT_ORDER) do
        ta = ta + (a[k] or 0)
        tb = tb + (b[k] or 0)
    end
    if ta <= 0 or tb <= 0 then return false end
    for _, k in ipairs(STAT_ORDER) do
        if math.abs((a[k] or 0) / ta - (b[k] or 0) / tb) > tol then return false end
    end
    return true
end

-- 변환 티어의 원본 아이템 ID (링크 modifier 64 값). 데이터 e[13](서버가 proc 서명으로 역추적한 원본) 우선,
-- 없으면(구 데이터 패키지) 맹독저주 4종 중 같은 부위·방어구 재질인 것을 인게임 GetItemInfoInstant로 판정.
local convertedSrcCache = {}
local function ConvertedSourceItem(spec, slotKey, itemId, conv)
    if not (IsConvertedVariant(conv) and itemId) then return nil end
    local list = spec and spec.items and spec.items[slotKey]
    if list then
        for i = 1, #list do
            local e = list[i]
            if e[1] == itemId and (e[12] or "") == conv then
                local s = tonumber(e[13])
                if s and s > 0 then return s end
                break
            end
        end
    end
    if conv:sub(1, 5) ~= "raid|" then return nil end -- 맹독저주 폴백은 레이드 변환만
    local v = WythicPlusGearData.venom
    if not (v and v.items and C_Item and C_Item.GetItemInfoInstant) then return nil end
    local key = itemId .. "|" .. conv
    local cached = convertedSrcCache[key]
    if cached ~= nil then return cached or nil end
    local _, _, _, tLoc, _, tClass, tSub = C_Item.GetItemInfoInstant(itemId)
    local found = false
    if tLoc then
        for id in pairs(v.items) do
            local _, _, _, loc, _, cls, sub = C_Item.GetItemInfoInstant(id)
            if loc == tLoc and cls == tClass and sub == tSub then found = id break end
        end
    end
    convertedSrcCache[key] = found
    return found or nil
end

-- 툴팁 한 줄이 2차 스탯 줄인지 판정 → key("crit"… 또는 "placeholder"), 값, 숫자 선행 여부.
-- 줄 형식은 로케일마다 다르다: enUS "+100 Haste", koKR "가속 +100"(GlobalStrings ITEM_MOD_*의 "%c%s" 위치가 다름).
-- 자리표시자(ITEM_MOD_MODIFIED_CRAFTING_STAT_1/2 = "무작위 능력치 1/2", "Random Stat 1/2")도 예산에 넣는다.
-- 줄 전체가 "숫자 이름" 또는 "이름 숫자"여야 한다 — 스탯명이 들어간 세트 효과·착효 설명문·마법부여 줄은 걸리지 않는다.
local SECONDARY_MOD_KEYS = {
    crit = "ITEM_MOD_CRIT_RATING_SHORT", haste = "ITEM_MOD_HASTE_RATING_SHORT",
    mastery = "ITEM_MOD_MASTERY_RATING_SHORT", versatility = "ITEM_MOD_VERSATILITY",
}
local PLACEHOLDER_KEYS = { "ITEM_MOD_MODIFIED_CRAFTING_STAT_1", "ITEM_MOD_MODIFIED_CRAFTING_STAT_2" }
local function StatLineName(k)
    return _G[SECONDARY_MOD_KEYS[k]] or STAT_LABELS[k]
end
local function ParseStatLine(txt)
    if type(txt) ~= "string" then return nil end
    local num, rest = txt:match("^%+([%d,%.]+)%s+(.-)%s*$")
    local numFirst = num ~= nil
    if not num then rest, num = txt:match("^(.-)%s+%+([%d,%.]+)%s*$") end
    if not (num and rest and rest ~= "") then return nil end
    local v = tonumber((num:gsub("[,%.]", "")))
    if not v then return nil end
    for k, g in pairs(SECONDARY_MOD_KEYS) do
        if _G[g] == rest then return k, v, numFirst end
    end
    for _, g in ipairs(PLACEHOLDER_KEYS) do
        if _G[g] == rest then return "placeholder", v, numFirst end
    end
    return nil
end
local function FormatStatLine(k, v, numFirst)
    if numFirst then return "+" .. v .. " " .. StatLineName(k) end
    return StatLineName(k) .. " +" .. v
end
-- getText(i)로 n줄을 훑어 2차 스탯 줄을 모은다 → hits {i, key, value}, 표시 배분 shown, 예산 total, 숫자 선행 여부
local function ScanSecondaryLines(getText, n)
    local hits, shown, total, numFirst = {}, {}, 0, true
    for i = 1, n do
        local k, v, nf = ParseStatLine(getText(i))
        if k then
            hits[#hits + 1] = { i = i, key = k, value = v }
            if k ~= "placeholder" and shown[k] == nil then shown[k] = v end
            total = total + v
            if #hits == 1 then numFirst = nf end
        end
    end
    return hits, shown, total, numFirst
end

-- 링크 툴팁 데이터(C_TooltipInfo)에서 2차 스탯 예산 — GetItemStats가 자리표시자를 2차 스탯으로 돌려주지 않는
-- 아이템(무작위 능력치·제작)의 그 ilvl 예산을 읽는다. 반환: shown, total
local function LinkSecondaryBudget(link)
    if not (link and C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return {}, 0 end
    local ok, td = pcall(C_TooltipInfo.GetHyperlink, link)
    if not (ok and type(td) == "table" and type(td.lines) == "table") then return {}, 0 end
    local _, shown, total = ScanSecondaryLines(function(i)
        local ln = td.lines[i]
        return ln and ln.leftText
    end, #td.lines)
    return shown, total
end

-- 링크 2차 스탯(GetItemStats)을 수집 배분과 맞춘다. 비어 있으면(자리표시자) 툴팁 예산을 수집 배분으로 나누고,
-- 배분이 다르면 재분배, 같으면 그대로. 반환 nil = 판단 불가(예산 0·데이터 없음)
local function AlignLinkStats(st, link, data)
    if next(st) == nil then
        if not data then return nil end
        local _, budget = LinkSecondaryBudget(link)
        return SplitBudget(budget, data)
    end
    if data and not SameSecondarySplit(st, data) then return RedistributeSecondary(st, data) end
    return st
end

-- 우리가 SetHyperlink로 띄운 GameTooltip 직후에만 호출. 게임이 그린 2차 스탯 줄이 수집 배분과 다르면(변환 티어·
-- 무작위 능력치·제작) 그 줄에 수집 배분을 덮어쓴다(줄 수 유지 → 레이아웃 불변). 남는 줄은 안내로, 부족하면 하단 추가.
-- 줄을 못 찾으면 하단에 수집 배분을 병기하는 폴백. 반환: 바꿨으면 true
local function FixTooltipSecondaryStats(spec, slotKey, itemId, conv)
    if not (spec and slotKey and itemId) then return false end
    local data = MetaItemStats(spec, slotKey, itemId, conv)
    if not data then return false end
    local dtotal = 0
    for _, k in ipairs(STAT_ORDER) do dtotal = dtotal + (data[k] or 0) end
    if dtotal <= 0 then return false end -- 수집 스탯이 비어 있으면(API 결손) 게임 표시를 믿는다
    local hits, shown, total, numFirst = ScanSecondaryLines(function(i)
        local fs = _G["GameTooltipTextLeft" .. i]
        return fs and fs:GetText()
    end, GameTooltip:NumLines())
    if #hits == 0 then
        -- 2차 스탯 줄을 못 찾음(파서가 모르는 로케일 형식 등). 변환 티어만 하단에 수집 배분을 병기하고(기존 동작),
        -- 그 외 아이템은 게임 표시를 그대로 둔다 — 안 그러면 그 로케일의 모든 툴팁에 안내 줄이 붙는다
        if not IsConvertedVariant(conv) then return false end
        local parts = {}
        for _, k in ipairs(STAT_ORDER) do
            if (data[k] or 0) > 0 then parts[#parts + 1] = FormatStatLine(k, data[k], true) end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ccffWythic+|r " .. L["2차 스탯은 랭커 착용 배분 기준"] .. ": " .. table.concat(parts, ", "), 0.8, 0.8, 0.8, true)
        return true
    end
    local hasPlaceholder = false
    for _, h in ipairs(hits) do
        if h.key == "placeholder" then hasPlaceholder = true end
    end
    if not hasPlaceholder and SameSecondarySplit(shown, data) then return false end -- 게임이 이미 맞게 그렸다
    local actual = SplitBudget(total, data)
    if not actual then return false end
    local j = 0
    for _, k in ipairs(STAT_ORDER) do
        local v = actual[k] or 0
        if v > 0 then
            local text = FormatStatLine(k, v, numFirst)
            if j < #hits then
                j = j + 1
                _G["GameTooltipTextLeft" .. hits[j].i]:SetText(text)
            else
                GameTooltip:AddLine(text, 0, 1, 0) -- 게임이 그린 줄보다 스탯 종류가 많으면(드묾) 하단 추가
            end
        end
    end
    for i = j + 1, #hits do
        _G["GameTooltipTextLeft" .. hits[i].i]:SetText(i == j + 1 and ("|cff9d9d9d" .. L["2차 스탯은 랭커 착용 배분 기준"] .. "|r") or " ")
    end
    return true
end

local function ApplySkin()
    if not (euiSkin and panel) then return end
    -- noTopBar: EUI의 상단 다크 타이틀 스트립 제거 — 우리 타이틀은 중앙 정렬이라 어긋나 보임
    euiSkin.Shell(panel, { noTopBar = true })
    if panel.close then euiSkin.CloseButton(panel.close) end
    if panel.fontStrings then
        for _, fs in ipairs(panel.fontStrings) do
            -- 색 보존 전달 — EUI Font가 폰트 교체 시 색을 리셋해 전부 검게 보이는 문제 방지
            local r, g, b = fs:GetTextColor()
            euiSkin.Font(fs, r, g, b)
        end
    end
end

local function RankColor(rank)
    if rank == 1 then return "|cffffd100" end
    if rank <= 3 then return "|cffe6cc80" end
    if rank <= 30 then return "|cff00ccff" end
    return "|cffaaaaaa"
end

local function GetCurrentSpecData()
    local data = WythicPlusGearData
    if not data or not data.specs then return nil, L["데이터가 아직 로드되지 않았습니다."] end
    local specIndex = GetSpecialization()
    if not specIndex then return nil, L["전문화를 선택하지 않았습니다."] end
    local specID = GetSpecializationInfo(specIndex)
    if not specID then return nil, L["전문화를 확인할 수 없습니다."] end
    local key = data.specIds and data.specIds[specID]
    local spec = key and data.specs[key]
    if not spec then return nil, L["이 전문화의 메타 데이터가 없습니다."] end
    return spec, nil, key
end

-- 원형 텍스처 (마스크). CircleMaskScalable 미로드 대비 TempPortraitAlphaMask 사용
local function Circle(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetSize(size, size)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    local mask = parent:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(t)
    t:AddMaskTexture(mask)
    return t
end

-- 링(도넛): 색 원 + 안쪽 배경색 원
local function Ring(parent, size, thickness)
    local outer = Circle(parent, size)
    local inner = Circle(parent, size - thickness * 2, "OVERLAY")
    inner:SetPoint("CENTER", outer, "CENTER")
    inner:SetVertexColor(0.04, 0.05, 0.07, 1) -- 패널 배경색
    return outer, inner
end

-- ── 진단 도우미 ──────────────────────────────────────────────────────────────

local GRADE_HEX = { S = "ff8000", A = "a335ee", B = "0070dd", C = "1eff00", D = "9d9d9d" }
local function gradeRGB(grade)
    return HexToRGB(GRADE_HEX[grade] or "9d9d9d")
end
local function scoreGrade(score)
    local Core = WythicPlusGearCore
    return Core and Core:toGrade(score) or "D"
end

-- ── 슬롯 셀 ──────────────────────────────────────────────────────────────────
-- 웹 renderSlot 구조: 좌측 = [rec][icon+check][name(안쪽)], 우측 = [name(안쪽)][icon+check][rec]

local SLIDE_OUT = 0 -- 기본 모드에도 컨텐츠는 모델 쪽에 붙어 있음 (바깥으로 뺄 이유 없음)
local SLIDE_IN_EXTRA = 100 -- 최적화 시 착용 라인을 모델 쪽으로 강하게 몰아 추천 공간 확보

-- 강화 트랙 (웹 UPGRADE_TRACKS 시즌2와 동일 — 시즌 교체 시 constants.ts와 함께 갱신)
local UPGRADE_TRACKS = {
    { key = "Veteran",  ko = L["노련가"], base = 279, max = 295 },
    { key = "Champion", ko = L["챔피언"], base = 292, max = 308 },
    { key = "Hero",     ko = L["영웅"],   base = 305, max = 321 },
    { key = "Myth",     ko = L["신화"],   base = 318, max = 334 },
}
local CRAFTED_ILVL_OFFSET = -3 -- 제작 q5 = 트랙 max -3 (웹과 동일)

local function TrackMaxIlvl(trackKey, crafted)
    if trackKey == "VENOM" then
        -- 맹독저주: 트랙 밖 고정 ilvl (서버가 시즌 상수로 동봉)
        local v = WythicPlusGearData.venom
        return v and v.ilvl or nil
    end
    for _, t in ipairs(UPGRADE_TRACKS) do
        if t.key == trackKey then return t.max + (crafted and CRAFTED_ILVL_OFFSET or 0) end
    end
    return nil
end

-- ── SimC 프로필 (Raidbots 내보내기) ──
-- 슬롯키 → simc 슬롯 토큰
local SIMC_SLOT = {
    HEAD = "head", NECK = "neck", SHOULDER = "shoulder", BACK = "back", CHEST = "chest",
    WRIST = "wrist", HANDS = "hands", WAIST = "waist", LEGS = "legs", FEET = "feet",
    FINGER_1 = "finger1", FINGER_2 = "finger2", TRINKET_1 = "trinket1", TRINKET_2 = "trinket2",
    MAIN_HAND = "main_hand", OFF_HAND = "off_hand",
}
local SIMC_ORDER = {
    "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST",
    "LEGS", "FEET", "FINGER_1", "FINGER_2", "TRINKET_1", "TRINKET_2", "MAIN_HAND", "OFF_HAND",
}
local SIMC_REGION = { "us", "kr", "eu", "tw", "cn" }

-- 아이템 링크 → simc 구성요소 (id/enchant/gems/bonuses) — 웹 toSimcString과 동일 순서로 조립
local function LinkSimcParts(link)
    local payload = link and link:match("item:([%-%d:]+)")
    if not payload then return nil end
    local t = {}
    for tok in (payload .. ":"):gmatch("([^:]*):") do t[#t + 1] = tok end
    local out = { id = t[1] or "0", gems = {}, bonuses = {} }
    local ench = t[2]
    if ench and ench ~= "" and ench ~= "0" then out.enchant = ench end
    for gi = 3, 6 do
        local g = t[gi]
        if g and g ~= "" and g ~= "0" then out.gems[#out.gems + 1] = g end
    end
    local nb = tonumber(t[13]) or 0
    for bi = 14, 13 + nb do
        if t[bi] and t[bi] ~= "" then out.bonuses[#out.bonuses + 1] = t[bi] end
    end
    -- modifier 64(원본 스탯 계승 = 변환 티어 원본 아이템 ID) → simc redirected_base_stats,
    -- modifier 29/30(제작 스탯 = "무작위 능력치 1/2", 착귀·제작템의 2차 스탯) → simc crafted_stats (SimC 애드온 12.1과 동일)
    local nm = tonumber(t[14 + nb]) or 0
    for mi = 0, nm - 1 do
        local mt, mv = t[15 + nb + mi * 2], t[16 + nb + mi * 2]
        if mv and mv ~= "" and mv ~= "0" then
            if mt == "64" then out.redirect = mv end
            if mt == "29" or mt == "30" then
                out.crafted = out.crafted or {}
                out.crafted[#out.crafted + 1] = mv
            end
        end
    end
    return out
end

-- Adler-32 체크섬 — SimC 애드온 core.lua/웹 simc.ts와 동일 (끝에서 한 번 mod)
local function SimcAdler32(str)
    local PRIME = 65521
    local s1, s2 = 1, 0
    for i = 1, #str do
        s1 = s1 + str:byte(i)
        s2 = s2 + s1
    end
    return (s2 % PRIME) * 65536 + (s1 % PRIME)
end

-- 역할 토큰 (웹 simc.ts getRole과 동일 — SimC 애드온 동작 기준)
local SIMC_TANK = { Blood = 1, Protection = 1, Guardian = 1, Brewmaster = 1, Vengeance = 1 }
local SIMC_HEAL = { Holy = 1, Discipline = 1, Restoration = 1, Mistweaver = 1, Preservation = 1 }
local SIMC_SPELL = {
    Balance = 1, Elemental = 1, Shadow = 1, Arcane = 1, Fire = 1, Frost = 1,
    Affliction = 1, Demonology = 1, Destruction = 1,
    Devastation = 1, Augmentation = 1, Devourer = 1,
}
local function SimcRole(specEn)
    if SIMC_TANK[specEn] then return "tank" end
    if SIMC_HEAL[specEn] then return "heal" end
    if SIMC_SPELL[specEn] then return "spell" end
    return "attack"
end

-- ilvl → 트랙 역산 (base~max 범위 매칭, 제작 오프셋 고려)
local function TrackFromIlvl(ilvl, crafted)
    if not ilvl then return nil end
    local off = crafted and CRAFTED_ILVL_OFFSET or 0
    for _, t in ipairs(UPGRADE_TRACKS) do
        if ilvl >= t.base + off and ilvl <= t.max + off then return t.key end
    end
    return nil
end

-- ── 아이템 선택 드롭다운 — 인게임 장비 플라이아웃 스타일 그리드 ──
-- 탭: 메타(랭커 인기 후보) / 가방(내 소지품 중 착용 가능). 아이콘 위 ilvl(품질색) 오버레이,
-- 클릭 = 핀(가방은 실제 링크 스탯으로 수치 반영). 페이지가 넘치면 이전/다음.
-- 하단 강화 트랙(메타 탭 전용)은 표기 ilvl 기준 변경 — 스탯 수치는 유지(선형 추정 금지).
local GRID_COLS, GRID_ROWS = 5, 2
local GRID_CELL = 44
local GRID_PER_PAGE = GRID_COLS * GRID_ROWS
local DROP_W = 12 + GRID_COLS * (GRID_CELL + 6) - 6 + 12 -- 268

-- 슬롯키 → 착용 가능 INVTYPE (가방 탭 필터)
local SLOT_INVTYPE = {
    HEAD = { INVTYPE_HEAD = true }, NECK = { INVTYPE_NECK = true },
    SHOULDER = { INVTYPE_SHOULDER = true }, BACK = { INVTYPE_CLOAK = true },
    CHEST = { INVTYPE_CHEST = true, INVTYPE_ROBE = true },
    WRIST = { INVTYPE_WRIST = true }, HANDS = { INVTYPE_HAND = true },
    WAIST = { INVTYPE_WAIST = true }, LEGS = { INVTYPE_LEGS = true }, FEET = { INVTYPE_FEET = true },
    FINGER_1 = { INVTYPE_FINGER = true }, FINGER_2 = { INVTYPE_FINGER = true },
    TRINKET_1 = { INVTYPE_TRINKET = true }, TRINKET_2 = { INVTYPE_TRINKET = true },
    MAIN_HAND = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true },
    OFF_HAND = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true },
}

-- ── 도감(Encounter Journal) 로트 스캐너 — 던전/레이드 탭용 ──
-- 시즌 인스턴스에서 "내 클래스가 착용 가능한 모든 드랍"을 조회한다 (커스터마이징 소스 브라우저).
-- 번들 데이터(랭커 착용 상위권)와 달리 전체 로트 테이블이 나온다.
local EJ_CACHE = { instances = nil, loot = {} } -- loot[instanceID] = { {itemId, link}, ... }

local function EJEnsure()
    if not C_EncounterJournal then return false end
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    elseif UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_EncounterJournal")
    end
    return type(EJ_GetNumTiers) == "function" and type(EJ_GetInstanceByIndex) == "function"
end

-- 시즌 인스턴스 식별: 데이터의 출처 이름(던전)·SEASON_RAIDS(레이드)와 도감 이름 매칭 (ko/en 모두)
local function EJSeasonInstances()
    if EJ_CACHE.instances then return EJ_CACHE.instances end
    if not EJEnsure() then return nil end
    local want = {}
    -- 이번 시즌 쐐기 로테이션 던전만 (DUNGEON_BADGE_HEX = 시즌 던전 8개 고유색 테이블)
    for en in pairs(DUNGEON_BADGE_HEX) do
        local w = { type = "dungeon", ko = "", en = en }
        -- ko 이름은 출처 테이블에서 en 매칭으로 확보 (도감이 ko 이름을 주는 한국 클라 대응)
        for _, s in pairs(WythicPlusGearData.sources or {}) do
            if s[1] == "dungeon" and s[3] == en then w.ko = s[2] or "" break end
        end
        want[en] = w
        if w.ko ~= "" then want[w.ko] = w end
    end
    for _, r in ipairs(SEASON_RAIDS) do
        local w = { type = "raid", ko = r.ko, en = r.en }
        want[r.ko] = w
        want[r.en] = w
    end
    local found = {}
    local ok = pcall(function()
        for t = 1, EJ_GetNumTiers() do
            EJ_SelectTier(t)
            for _, isRaid in ipairs({ false, true }) do
                local idx = 1
                while true do
                    local instID, name = EJ_GetInstanceByIndex(idx, isRaid)
                    if not instID then break end
                    local w = name and want[name]
                    if w and not found[instID] then
                        found[instID] = { id = instID, type = w.type, isRaid = isRaid,
                            ko = w.ko ~= "" and w.ko or name, en = w.en ~= "" and w.en or name }
                    end
                    idx = idx + 1
                end
            end
        end
    end)
    if not ok then return nil end
    -- 도감이 아직 덜 로드돼 일부 인스턴스를 못 찾았으면 캐시하지 않는다 (다음 렌더에서 재스캔)
    -- — 빈/부분 결과가 박제되면 레이드 탭이 세션 내내 안 나오는 사고
    local expected = #SEASON_RAIDS
    for _ in pairs(DUNGEON_BADGE_HEX) do expected = expected + 1 end
    local got = 0
    for _ in pairs(found) do got = got + 1 end
    if got >= expected then EJ_CACHE.instances = found end
    return found
end

-- 착용 가능 검사 — 도감 클래스 필터가 놓치는 타 재질/타 스펙 아이템 차단
local EJ_CLASS_ARMOR = { WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4, HUNTER = 3, SHAMAN = 3, EVOKER = 3,
    ROGUE = 2, MONK = 2, DRUID = 2, DEMONHUNTER = 2, PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local EJ_ARMOR_SLOTS = { HEAD = true, SHOULDER = true, CHEST = true, WRIST = true,
    HANDS = true, WAIST = true, LEGS = true, FEET = true }
local function EJUsable(itemId, link, slotKey)
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemId)
    if EJ_ARMOR_SLOTS[slotKey] and classID == 4 then -- 방어구는 내 클래스 재질만
        local _, classFile = UnitClass("player")
        local wantSub = EJ_CLASS_ARMOR[classFile]
        if wantSub and subClassID ~= wantSub then return false end
    end
    -- 주의: GetItemSpecInfo의 빈 목록은 "스펙 지정 없음(범용)"일 수 있어 거부 조건으로 쓰지 않는다
    -- (범용 반지/장신구가 전멸하던 버그). 재질 검사 + 도감 클래스/스펙 필터로 충분.
    return true
end

-- 인스턴스의 클래스 필터 적용 로트 (전 보스 합산, 캐시)
-- 도감 링크 → 선택 트랙으로 리링크한 "최종 링크" 생성.
-- 카드 표기 ilvl·툴팁·핀 스탯이 전부 이 링크 하나에서 나온다 (숫자 불일치 원천 차단).
-- 트랙 스텝이 없거나 리링크 불가면 원본 링크 그대로 — 그래도 세 값은 항상 같은 링크 기준.
-- ── 애드온이 조립하는 아이템 링크 ──
-- item:ID:enchant:gem1:gem2:gem3:gem4:suffix:unique:linkLevel:specID:modMask:context:numBonus:bonuses
-- 10번째 필드 specializationID가 비어 있으면 클라이언트가 아이템 원본 스탯 순서의 첫 주스탯을 활성으로
-- 그려, 민첩/지능 겸용 장비가 수호 드루에게 지능으로 표시됐다(2026-09-08 디스코드 제보). 표시 전용 버그 —
-- 추천 계산은 동봉 데이터 스탯 기준이라 무관. 직접 "item:" .. 문자열 조립 금지, 반드시 이 헬퍼로.
local function CurrentSpecID()
    local specIndex = GetSpecialization and GetSpecialization()
    local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
    return specID and tostring(specID) or ""
end
local function BuildItemLink(itemId, bonuses, srcItemId)
    -- id 뒤 콜론 9개 → specID(10번째) → 콜론 3개 → numBonus(13번째) → bonuses(14번째~) → numModifiers → (type:value)*
    -- srcItemId: 마나용제 변환 티어의 원본 아이템 ID → modifier 64(원본 스탯 계승)로 붙인다. 변환 티어의 2차 배분·착효는
    -- 보너스ID가 아니라 이 modifier로 결정되므로 없으면 게임이 티어 기본 배분(치명+특화)에 착효만 덧씌워 그린다.
    -- (12.1 실링크 확인 2026-09-10: item:271455:8159:::::::90:250::93:8:<보너스8개>:1:64:271878 — SimC 애드온도 동일 해석)
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
-- 기존 링크(도감·핀·가방)의 10번째 필드를 현재 전문화로 교체 — 스펙 전환 뒤 이전 스펙 주스탯이 남지 않게
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

-- 표시 중인 추천 카드(가방/변환 링크)를 잠금용 핀 테이블로 승격. 마나용제 변환 가정 카드는 링크가
-- "변환 후 티어"(modifier 64)이고 스탯은 원본 아이템 것이므로 원본 링크로 스탯을 읽는다 — 티어 아이템이
-- 미캐시면 변환 링크의 GetItemStats가 비어 핀 스탯이 0이 된다.
local function RecToPin(rec)
    local statsLink = rec.recConvLink or rec.recLink
    return {
        item_id = rec.itemId, link = rec.recLink,
        ilvl = C_Item.GetDetailedItemLevelInfo(rec.recLink) or rec.recIlvl or 0,
        stats = (WythicPlus_GearLinkStats and WythicPlus_GearLinkStats(statsLink)) or {},
        srcTab = rec.recSrcTab,
    }
end

-- ── 제작 탭 — 시즌 전체 제작 장비(WythicPlusCraftData) + 유저 지정 2차 스탯 ──
-- 제작템의 2차 스탯은 제작할 때 유저가 고른다(아이템마다 1~2개, 0 = 스탯 고정 아이템). 링크에선 modifier 29/30
-- (제작 스탯 1/2 = ITEM_MOD 스탯 ID)로 표현된다. 템렙은 최고 품질 고정(데이터 ilvl). 수치 = 그 ilvl의 2차 스탯
-- 예산을 지정 스탯에 균등 배분. 핀(srcTab "craft")으로 들어가 엔진이 나머지 부위를 재최적화한다.
local function CraftInfo(itemId)
    local cd = WythicPlusCraftData
    return cd and cd.items and itemId and cd.items[itemId] or nil
end

-- 최고 품질 보너스ID: 랭커가 최고 품질로 착용한 같은 아이템이 있으면 그 보너스(장식 포함 — 메타 픽),
-- 없으면 데이터 템플릿(양손/원거리 무기는 별도). 현재 스펙 데이터 우선, 없으면 전체 스펙에서 찾는다.
local craftMetaBonus -- itemId → bonuses (전체 스펙, 1회 구성)
local function CraftBonuses(itemId)
    local cd = WythicPlusCraftData
    local function find(items)
        for _, list in pairs(items or {}) do
            for i = 1, #list do
                local e = list[i]
                if e[1] == itemId and e[3] == cd.ilvl and e[11] and e[11] ~= "" then return e[11] end
            end
        end
        return nil
    end
    local b = panel and panel.curSpec and find(panel.curSpec.items)
    if b then return b end
    if not craftMetaBonus then
        craftMetaBonus = {}
        for _, sp in pairs(WythicPlusGearData.specs or {}) do
            for _, list in pairs(sp.items or {}) do
                for i = 1, #list do
                    local e = list[i]
                    if craftMetaBonus[e[1]] == nil and CraftInfo(e[1]) and e[3] == cd.ilvl and e[11] and e[11] ~= "" then
                        craftMetaBonus[e[1]] = e[11]
                    end
                end
            end
        end
    end
    if craftMetaBonus[itemId] then return craftMetaBonus[itemId] end
    local info = CraftInfo(itemId)
    return (info and cd.twoHandInv and cd.twoHandInv[info.inv]) and cd.bonus.twoHand or cd.bonus.std
end

-- 장식 교체: 보너스에서 장식 표지(8960 등)·장식 효과 ID를 걷어내고, emb(보너스 ID)가 있으면 "8960:<ID>"를 붙인다.
-- emb = nil → 메타 픽 그대로(보너스 무변경), 0 → 장식 없음
local function ApplyEmbellish(bonuses, emb)
    if emb == nil then return bonuses end
    local cd = WythicPlusCraftData
    local kept = {}
    for b in bonuses:gmatch("[^:]+") do
        local n = tonumber(b)
        if not ((cd.embellishMarkers and cd.embellishMarkers[n]) or (cd.embellishments and cd.embellishments[n])) then
            kept[#kept + 1] = b
        end
    end
    if emb ~= 0 then
        kept[#kept + 1] = "8960"
        kept[#kept + 1] = tostring(emb)
    end
    return table.concat(kept, ":")
end

-- 제작 링크: 최고 품질 보너스 + 제작 스탯 modifier(29 = 스탯1, 30 = 스탯2). keys = 지정 스탯(순서 = 스탯1, 스탯2)
-- emb = 장식 선택(nil 메타 픽 / 0 없음 / 보너스 ID). 스탯 고정형(n = 0)은 장식이 아이템에 내장돼 있어 무시
local function CraftLink(itemId, keys, emb)
    local cd = WythicPlusCraftData
    local info = CraftInfo(itemId)
    if not info then return nil end
    local bonuses = CraftBonuses(itemId)
    if (info.n or 0) > 0 then bonuses = ApplyEmbellish(bonuses, emb) end
    local nb = 1 + select(2, bonuses:gsub(":", ""))
    local mods = {}
    for i = 1, math.min(info.n or 0, 2) do
        local sid = keys and keys[i] and cd.statIds[keys[i]]
        if sid then mods[#mods + 1] = (i == 1 and "29:" or "30:") .. sid end
    end
    local tail = #mods > 0 and (":" .. #mods .. ":" .. table.concat(mods, ":")) or ""
    return ("item:%d:::::::::%s:::%d:%s%s"):format(itemId, CurrentSpecID(), nb, bonuses, tail)
end

-- 제작 핀 수치: 스탯 고정 아이템은 링크 그대로, 선택형은 그 ilvl의 2차 스탯 예산(게임 툴팁의 자리표시자 합)을
-- 지정 스탯에 균등 배분. 지정 스탯이 모자라거나 아이템 정보가 아직 없으면 nil
local function CraftStats(itemId, link, keys)
    local info = CraftInfo(itemId)
    if not (info and link) then return nil end
    local n = info.n or 0
    local st = (WythicPlus_GearLinkStats and WythicPlus_GearLinkStats(link)) or {}
    local total = 0
    for _, k in ipairs(STAT_ORDER) do total = total + (st[k] or 0) end
    if n == 0 then
        if total > 0 then return st end
        local shown = LinkSecondaryBudget(link)
        return next(shown) ~= nil and shown or nil
    end
    if not keys or #keys < n then return nil end
    if total <= 0 then
        local _, budget = LinkSecondaryBudget(link)
        total = budget
    end
    if not total or total <= 0 then return nil end
    local out = { crit = 0, haste = 0, mastery = 0, versatility = 0 }
    local each = math.floor(total / n + 0.5)
    for i = 1, n do out[keys[i]] = each end
    return out
end

-- 제작 탭 선택 스탯 (부위별, 세션 유지)
local function CraftKeys(slotKey)
    panel.craftStats = panel.craftStats or {}
    panel.craftStats[slotKey] = panel.craftStats[slotKey] or {}
    return panel.craftStats[slotKey]
end

local CRAFT_SHORT = { crit = L["치명"], haste = L["가속"], mastery = L["특화"], versatility = L["유연"] }

-- 제작 핀 생성 (스탯 미지정·정보 미로딩이면 nil). ilvl은 최고 품질 고정. emb = 장식 선택(CraftLink 참고)
local function MakeCraftPin(itemId, keys, emb)
    local info = CraftInfo(itemId)
    if not info then return nil end
    local link = CraftLink(itemId, keys, emb)
    local st = CraftStats(itemId, link, keys)
    if not st then
        EnsureItem(itemId)
        return nil
    end
    return { item_id = itemId, link = link, ilvl = WythicPlusCraftData.ilvl, stats = st, srcTab = "craft" }
end

-- 카드 칩 라벨: "제작 · 치명/가속" (스탯 고정 아이템은 "제작")
local function CraftLabel(pin)
    local info = CraftInfo(pin.item_id)
    local parts = {}
    if info and (info.n or 0) > 0 then
        for _, k in ipairs(STAT_ORDER) do
            if (pin.stats and pin.stats[k] or 0) > 0 then parts[#parts + 1] = CRAFT_SHORT[k] end
        end
    end
    return #parts > 0 and (L["제작"] .. " · " .. table.concat(parts, "/")) or L["제작"]
end

-- 제작 링크 툴팁 직후 호출: 게임이 그린 2차 스탯 줄(자리표시자 포함)을 지정 스탯 수치로 덮어쓴다
local function CraftFixTooltip(stats)
    if not stats then return end
    local hits, shown, _, numFirst = ScanSecondaryLines(function(i)
        local fs = _G["GameTooltipTextLeft" .. i]
        return fs and fs:GetText()
    end, GameTooltip:NumLines())
    if #hits > 0 then
        local hasPlaceholder = false
        for _, h in ipairs(hits) do
            if h.key == "placeholder" then hasPlaceholder = true end
        end
        if hasPlaceholder or not SameSecondarySplit(shown, stats, 0.001) then
            local j = 0
            for _, k in ipairs(STAT_ORDER) do
                local v = stats[k] or 0
                if v > 0 then
                    local text = FormatStatLine(k, v, numFirst)
                    if j < #hits then
                        j = j + 1
                        _G["GameTooltipTextLeft" .. hits[j].i]:SetText(text)
                    else
                        GameTooltip:AddLine(text, 0, 1, 0)
                    end
                end
            end
            for i = j + 1, #hits do _G["GameTooltipTextLeft" .. hits[i].i]:SetText(" ") end
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff00ccffWythic+|r " .. string.format(L["제작 가정 — 최고 품질 %d, 선택한 2차 스탯 기준"],
        (WythicPlusCraftData and WythicPlusCraftData.ilvl) or 0), 0.8, 0.8, 0.8, true)
end

-- 이 부위·내 전문화에 맞는 제작 장비 (제작 탭 목록·장식 선택지 공용)
local function CraftItemsForSlot(slotKey)
    local cd = WythicPlusCraftData
    local allow = SLOT_INVTYPE[slotKey]
    local specIndex = GetSpecialization and GetSpecialization()
    local mySpec = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
    local out = {}
    for itemId, info in pairs((cd and cd.items) or {}) do
        local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemId)
        local specOk = not (info.specs and #info.specs > 0)
        if not specOk then
            for _, s in ipairs(info.specs) do
                if s == mySpec then specOk = true break end
            end
        end
        if allow and equipLoc and allow[equipLoc] and specOk then out[#out + 1] = { itemId = itemId, info = info } end
    end
    return out
end

-- ── 장식 선택 (제작 탭 전용 — 게임 규칙상 장식은 제작템에만 붙는다. 가치는 계산하지 않음) ──
local function EmbApplies(use, info)
    local inv, cls, prof = info.inv, info.cls, info.prof
    local nonArmor = { [2] = true, [11] = true, [12] = true, [14] = true, [22] = true, [23] = true }
    local isArmor = cls == 4 and not nonArmor[inv]
    local isWeapon = cls == 2
    if use == "armor" then return isArmor
    elseif use == "equipment" then return true
    elseif use == "weaponArmor" then return isArmor or isWeapon
    elseif use == "weaponOffhand" then return isWeapon or inv == 14 or inv == 22 or inv == 23
    elseif use == "accessory" then return inv == 2 or inv == 11
    elseif use == "bsWeapon" then return isWeapon and prof == 164
    elseif use == "engGun" then return prof == 202 and (inv == 15 or inv == 26)
    elseif use == "engBoots" then return prof == 202 and inv == 8
    elseif use == "engEquip" then return prof == 202
    end
    return false
end

-- 부위별 장식 선택 (nil = 메타 픽, 0 = 없음, 보너스 ID)
local function CraftEmb(slotKey)
    panel.craftEmb = panel.craftEmb or {}
    return panel.craftEmb[slotKey]
end

-- 이 부위 제작템 중 하나라도 쓸 수 있는 장식 (선택지 목록)
local function EmbOptionsForSlot(slotKey)
    local cd = WythicPlusCraftData
    local items = CraftItemsForSlot(slotKey)
    local out = {}
    for bid, emb in pairs((cd and cd.embellishments) or {}) do
        for _, it in ipairs(items) do
            if (it.info.n or 0) > 0 and EmbApplies(emb.use, it.info) then
                out[#out + 1] = { bid = bid, item = emb.item }
                break
            end
        end
    end
    table.sort(out, function(a, b) return a.bid < b.bid end)
    return out
end

-- 장식 이름(재료 아이템 이름, 클라이언트 언어)
local function EmbName(emb)
    if emb == nil then return L["메타 픽"] end
    if emb == 0 then return L["장식 없음"] end
    local e = WythicPlusCraftData.embellishments[emb]
    if e then
        EnsureItem(e.item)
        return C_Item.GetItemNameByID(e.item) or (L["아이템 "] .. e.item)
    end
    return tostring(emb)
end

-- 보너스 문자열이 장식 장비인가 (장식 표지 또는 장식 효과 ID 포함)
local function BonusesEmbellished(bonuses)
    local cd = WythicPlusCraftData
    if not (cd and bonuses and bonuses ~= "") then return false end
    for b in tostring(bonuses):gmatch("[^:/]+") do
        local n = tonumber(b)
        if n and ((cd.embellishMarkers and cd.embellishMarkers[n]) or (cd.embellishments and cd.embellishments[n])) then return true end
    end
    return false
end
local function LinkEmbellished(link)
    local p = link and LinkSimcParts(link)
    return p ~= nil and BonusesEmbellished(table.concat(p.bonuses, ":"))
end

-- ── 마법부여 선택 (유저가 직접 고른 부위에만 — 기본값은 착용 마부 유지, 바꾸면 그 차이만 계산) ──
-- 데이터(WythicPlusCraftData.enchants)는 최고 등급(s2) 고정 2차 스탯을 가진다. 링크용 마법부여 ID는 동봉 enchantNames의
-- 영문 이름으로 찾는다(같은 이름의 ID가 둘이면 작은 쪽 = 1등급). 착용 마부의 스탯도 이 표로 읽는다(모르는 마부 = 0).
local ENCH_SLOT_OF = { FINGER_1 = "FINGER", FINGER_2 = "FINGER", FEET = "FEET", CHEST = "CHEST", HEAD = "HEAD",
    SHOULDER = "SHOULDER", LEGS = "LEGS", MAIN_HAND = "WEAPON", OFF_HAND = "WEAPON" }
local enchIndex
local function EnchIndex()
    if enchIndex then return enchIndex end
    enchIndex = { byId = {}, byName = {} }
    local idsByName = {}
    for id, n in pairs(WythicPlusGearData.enchantNames or {}) do
        local en = n[4]
        if en and en ~= "" then
            idsByName[en] = idsByName[en] or {}
            table.insert(idsByName[en], id)
        end
    end
    for _, e in ipairs((WythicPlusCraftData and WythicPlusCraftData.enchants) or {}) do
        enchIndex.byName[e.name] = e
        local ids = idsByName[e.name]
        if ids then
            table.sort(ids)
            e.enchId = ids[#ids] -- 링크·SimC용 (최고 등급 쪽)
            for i, id in ipairs(ids) do enchIndex.byId[id] = { e = e, tier = (#ids >= 2 and i == 1) and 1 or 2 } end
        end
    end
    return enchIndex
end
local function EnchantByName(name) return name and EnchIndex().byName[name] or nil end
-- 착용(또는 링크) 마법부여 ID → 고정 2차 스탯 (모르는 마부·계산 제외 마부 = {})
local function EnchantStatsById(id)
    local hit = id and EnchIndex().byId[id]
    if not hit then return {} end
    return (hit.tier == 1 and hit.e.s1 or hit.e.s2) or {}
end
local function WornEnchantId(slotKey)
    local c = panel.cells and panel.cells[slotKey]
    local link = c and c.inv and GetInventoryItemLink("player", c.inv)
    local e = link and tonumber(link:match("item:%d+:(%d+)") or "")
    return (e and e > 0) and e or nil
end
-- 이 부위에 고를 수 있는 마법부여 (보조무기는 무기일 때만)
local function EnchantsForSlot(slotKey)
    local want = ENCH_SLOT_OF[slotKey]
    if slotKey == "OFF_HAND" then
        local pin = panel.pinnedItems[slotKey]
        local id = type(pin) == "table" and pin.item_id or pin
        local c = panel.cells and panel.cells[slotKey]
        id = id or (c and c.inv and GetInventoryItemID("player", c.inv))
        local _, _, _, loc = id and C_Item.GetItemInfoInstant(id)
        if not (loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_2HWEAPON") then want = nil end
    end
    local out = {}
    if not want then return out end
    EnchIndex()
    for _, e in ipairs((WythicPlusCraftData and WythicPlusCraftData.enchants) or {}) do
        if e.slot == want then out[#out + 1] = e end
    end
    return out
end
local function EnchantShortName(e)
    local nm = C_Item.GetItemNameByID(e.item2) or e.name
    return nm:match("^.-%s%-%s(.+)$") or nm -- "반지 마법부여 - 자연의 격노" → "자연의 격노"
end
local function EnchantStatText(st)
    if not st then return nil end
    local parts = {}
    for _, k in ipairs(STAT_ORDER) do
        if (st[k] or 0) > 0 then parts[#parts + 1] = CRAFT_SHORT[k] .. " +" .. st[k] end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end
-- 마부 핀의 스탯 차분 (핀 마부 - 착용 마부). 프리셋 레이팅 동결 중이면 이미 반영돼 있어 0
local function EnchantPinDelta()
    local delta = { crit = 0, haste = 0, mastery = 0, versatility = 0 }
    local any = false
    if panel.presetRatings then return delta, false end
    for slot, name in pairs(panel.pinnedEnchants or {}) do
        local e = EnchantByName(name)
        if e then
            local new, old = e.s2 or {}, EnchantStatsById(WornEnchantId(slot))
            for _, k in ipairs(STAT_ORDER) do
                local d = (new[k] or 0) - (old[k] or 0)
                if d ~= 0 then delta[k] = delta[k] + d; any = true end
            end
        end
    end
    return delta, any
end

local function EJDisplayLink(link, trackKey)
    if not link then return nil end
    local itemId = tonumber(link:match("item:(%d+)"))
    if not itemId then return link end
    -- 맹독저주 고정템: 트랙 개념 밖 — 원본 링크 그대로 (고정 344)
    local venom = WythicPlusGearData.venom
    if venom and venom.items and venom.items[itemId] then return link end
    local map = WythicPlusGearData.trackBonus
    local targetIlvl = TrackMaxIlvl(trackKey, false)
    local tgt = map and targetIlvl and map[targetIlvl]
    if not tgt then return link end
    local itemString = link:match("item:([%-%d:]+)")
    local f = {}
    for v in ((itemString or "") .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
    local n = tonumber(f[13]) or 0
    if n > 0 then
        local bons = {}
        for i = 1, n do bons[#bons + 1] = f[13 + i] end
        local bon = table.concat(bons, ":")
        if HasTrackStep(bon) then
            -- 아는 스텝이면 교체 (다른 보너스 보존)
            local nb = RelinkTrackBonuses(bon, targetIlvl)
            if nb and nb ~= "" and nb ~= bon then
                local head = {}
                for i = 1, 12 do head[#head + 1] = f[i] or "" end
                head[10] = CurrentSpecID() -- 도감 링크의 전문화는 조회 시점 값 — 현재 전문화로 갱신
                local cnt = 1 + select(2, nb:gsub(":", ""))
                -- 보너스 뒤 꼬리(numModifiers·변환 원본 modifier 64 등) 보존 — 잘라내면 변환 티어가 기본 배분으로 그려진다
                local tail = {}
                for i = 14 + n, #f do tail[#tail + 1] = f[i] end
                local out = "item:" .. table.concat(head, ":") .. ":" .. cnt .. ":" .. nb
                if #tail > 0 then out = out .. ":" .. table.concat(tail, ":") end
                return out
            end
        end
    end
    -- 모르는 스텝(레이드 난이도 드랍 등): 베이스 아이템 + 목표 스텝만 가진 깨끗한 링크로 재구성
    -- (도감 미리보기의 보너스는 난이도/스텝뿐이라 버려도 잃는 정보 없음)
    return BuildItemLink(itemId, tgt)
end

local function EJLoot(instID, isRaid)
    local ck = instID .. "|" .. tostring(isRaid)
    local c = EJ_CACHE.loot[ck]
    if c then return c end
    local out = {}
    local ok = pcall(function()
        EJ_SelectInstance(instID)
        -- 도감의 부위/클래스 필터는 전역 잔존 — 유저가 도감 UI에서 부위 필터를 걸어뒀으면
        -- 그 부위만 조회되는 사고(반지 실종)가 난다. 조회 전 반드시 리셋.
        if EJ_ResetLootFilter then pcall(EJ_ResetLootFilter) end
        if C_EncounterJournal and C_EncounterJournal.ResetSlotFilter then
            pcall(C_EncounterJournal.ResetSlotFilter)
        end
        -- 레이드는 신화 난이도로 조회: 마지막 2보스의 344 상향 드랍이 링크에 그대로 반영됨
        if EJ_SetDifficulty then pcall(EJ_SetDifficulty, isRaid and 16 or 23) end
        -- 마지막 2보스 식별 (신화 7·8넴 = 트랙 초과 344 고정 — 2026-09-08 리서치)
        if isRaid and EJ_GetEncounterInfoByIndex then
            local encs = {}
            local ei = 1
            while true do
                local _, _, encID = EJ_GetEncounterInfoByIndex(ei, instID)
                if not encID then break end
                encs[#encs + 1] = encID
                ei = ei + 1
            end
            local lastTwo = {}
            if #encs >= 1 then lastTwo[encs[#encs]] = true end
            if #encs >= 2 then lastTwo[encs[#encs - 1]] = true end
            EJ_CACHE.lastTwo = EJ_CACHE.lastTwo or {}
            EJ_CACHE.lastTwo[instID] = lastTwo
        end
        local _, _, classID = UnitClass("player")
        local specIndex = GetSpecialization and GetSpecialization()
        local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex) or 0
        if EJ_SetLootFilter and classID then EJ_SetLootFilter(classID, specID or 0) end
        local n = (EJ_GetNumLoot and EJ_GetNumLoot()) or 0
        for i = 1, n do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            if info and info.itemID then
                out[#out + 1] = { itemId = info.itemID, link = info.link, enc = info.encounterID }
            end
        end
    end)
    if not ok then return {} end
    -- 빈 결과는 캐시하지 않는다 — 도감 지연 로딩 중의 0건이 박제되면
    -- EJ_LOOT_DATA_RECIEVED 재렌더가 와도 캐시가 빈 걸 돌려줘 영영 안 나온다
    if #out > 0 then EJ_CACHE.loot[ck] = out end
    return out
end

-- 시즌 레이드 마지막 2보스의 아이템 → 신화 링크(344) 맵 — 메타 탭 신화 트랙 표기용
local EJ_TOP -- itemId → mythic link
local function EJTopBossLink(itemId)
    if EJ_TOP == nil then
        local built = {}
        local any = false
        local inst = EJSeasonInstances()
        if inst then
            for _, info in pairs(inst) do
                if info.type == "raid" then
                    local loot = EJLoot(info.id, true) -- lastTwo 캐시도 여기서 채워짐
                    local lastTwo = EJ_CACHE.lastTwo and EJ_CACHE.lastTwo[info.id]
                    for _, it in ipairs(loot) do
                        if lastTwo and it.enc and lastTwo[it.enc] and it.link then
                            built[it.itemId] = it.link
                            any = true
                        end
                    end
                end
            end
        end
        -- 도감 지연 로딩으로 아무것도 못 얻었으면 확정하지 않는다 (다음 렌더에서 재시도)
        if not any then return nil end
        EJ_TOP = built
    end
    return EJ_TOP[itemId]
end

-- '막넴 344' 스텝 보너스ID — 344 실착용 수집 링크의 미지 보너스들을 후보로,
-- 링크를 만들어 게임에 ilvl을 물어보는 런타임 검증으로 확정 (하드코딩 추정 금지)
local MYTH_PEAK_CANDIDATES = { 13848, 13691, 13697, 13335 }
local mythPeakStep -- 검증된 ID (false = 전부 탈락)
local function Find344Step(probeItemId)
    if mythPeakStep then return mythPeakStep end
    if mythPeakStep == false then return nil end
    local allResolved = true
    for _, id in ipairs(MYTH_PEAK_CANDIDATES) do
        local il = C_Item.GetDetailedItemLevelInfo(BuildItemLink(probeItemId, id))
        if il == 344 then
            mythPeakStep = id
            return id
        elseif il == nil then
            allResolved = false -- 아이템 미캐시 — 다음 렌더에서 재시도
        end
    end
    if allResolved then mythPeakStep = false end
    return nil
end

-- 막 2넴 대상 아이템의 344 링크 (비대상이면 nil)
local function PeakLink(itemId)
    if not EJTopBossLink(itemId) then return nil end
    local step = Find344Step(itemId)
    if not step then return nil end
    return BuildItemLink(itemId, step)
end

function WythicPlus_GearInvalidateEJLoot() -- 도감 데이터 지연 로딩 시 캐시 무효화
    wipe(EJ_CACHE.loot)
    EJ_TOP = nil
end

-- 가방 스캔 → 이 슬롯에 착용 가능한 아이템 (ilvl 내림차순)
local function ScanBagsForSlot(slotKey)
    local allow = SLOT_INVTYPE[slotKey]
    local out = {}
    if not (allow and C_Container) then return out end
    for bag = 0, 4 do
        for s = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local link = C_Container.GetContainerItemLink(bag, s)
            if link then
                local itemId, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
                if itemId and allow[equipLoc] then
                    out[#out + 1] = {
                        itemId = itemId, link = link,
                        ilvl = C_Item.GetDetailedItemLevelInfo(link) or 0,
                        bag = bag, slot = s, -- 위치: 마나용제 변환 가능 판정(ItemLocation)용
                    }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.ilvl > b.ilvl end)
    return out
end

local RenderDropdown -- 전방 선언 (탭/페이지 버튼이 참조)

local function EnsureDropdown()
    if panel.dropdown then return panel.dropdown end
    local d = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    d:SetFrameStrata("DIALOG")
    d:SetClampedToScreen(true)
    d:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    d:SetBackdropColor(0.05, 0.06, 0.09, 0.98)
    d:SetBackdropBorderColor(AMBER[1], AMBER[2], AMBER[3], 0.5)
    d:EnableMouse(true)
    d.grid = {}
    d.page = 1
    d.tab = "meta"

    -- 탭 (메타 / 가방 / 던전 / 레이드 / 제작) — 5탭이 드롭다운 폭(268)에 들어가도록 46px
    local TAB_W, TAB_STEP = 46, 49
    local function TabButton(text, key, x)
        local b = CreateFrame("Button", nil, d, "BackdropTemplate")
        b:SetSize(TAB_W, 22)
        b:SetPoint("TOPLEFT", x, -8)
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.label:SetPoint("CENTER")
        b.label:SetText(text)
        b:SetScript("OnClick", function()
            d.tab = key
            d.page = 1
            RenderDropdown(d)
        end)
        return b
    end
    d.tabMeta = TabButton(L["메타"], "meta", 12)
    d.tabBags = TabButton(L["가방"], "bags", 12 + TAB_STEP)
    d.tabDungeon = TabButton(L["던전"], "dungeon", 12 + TAB_STEP * 2)
    d.tabRaid = TabButton(L["레이드"], "raid", 12 + TAB_STEP * 3)
    d.tabCraft = TabButton(L["제작"], "craft", 12 + TAB_STEP * 4)

    -- 제작 탭: 2차 스탯 선택 (최대 2개, 세 번째를 누르면 먼저 고른 것이 빠진다). 부위에 제작 핀이 있으면 즉시 갱신
    d.craftLabel = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d.craftLabel:SetText(L["2차 스탯 선택"])
    d.craftHint = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d.craftHint:SetJustifyH("LEFT")
    d.craftHint:SetSpacing(2)
    d.craftStatBtns = {}
    for i, k in ipairs(STAT_ORDER) do
        local b = CreateFrame("Button", nil, d, "BackdropTemplate")
        b:SetSize((DROP_W - 24 - 3 * 4) / 4, 20)
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.label:SetPoint("CENTER")
        b.label:SetText(CRAFT_SHORT[k])
        b.statKey = k
        b:SetScript("OnClick", function(self)
            local keys = CraftKeys(d.slotKey)
            local idx
            for j, v in ipairs(keys) do if v == self.statKey then idx = j end end
            if idx then
                table.remove(keys, idx)
            else
                if #keys >= 2 then table.remove(keys, 1) end
                keys[#keys + 1] = self.statKey
            end
            d.craftWarn = nil
            -- 이 부위의 제작 핀은 새 스탯으로 다시 만든다 (스탯이 모자라면 기존 핀 유지)
            local pin = panel.pinnedItems[d.slotKey]
            if type(pin) == "table" and pin.srcTab == "craft" then
                local np = MakeCraftPin(pin.item_id, keys, CraftEmb(d.slotKey))
                if np then
                    panel.pinnedItems[d.slotKey] = np
                    panel.presetRatings = nil
                    if panel.Redraw then panel.Redraw() end
                end
            end
            RenderDropdown(d)
            d:Show()
        end)
        d.craftStatBtns[i] = b
    end

    -- 제작 탭: 장식 선택 줄 — 버튼을 누르면 장식 목록(emb 모드)으로 바뀐다
    d.embLabel = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d.embLabel:SetText(L["장식"])
    d.embBtn = CreateFrame("Button", nil, d, "BackdropTemplate")
    d.embBtn:SetSize(DROP_W - 24 - 40, 20)
    d.embBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    d.embBtn:SetBackdropColor(1, 1, 1, 0.07)
    d.embBtn.label = d.embBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.embBtn.label:SetPoint("LEFT", 8, 0)
    d.embBtn.label:SetPoint("RIGHT", -8, 0)
    d.embBtn.label:SetJustifyH("LEFT")
    d.embBtn.label:SetWordWrap(false)
    d.embBtn:SetScript("OnClick", function()
        d.mode = "emb"
        d.page = 1
        RenderDropdown(d)
        d:Show()
    end)
    d.embBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(1, 1, 1, 0.14) end)
    d.embBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 1, 1, 0.07) end)
    -- emb 모드 → 제작 탭 복귀
    d.backBtn = CreateFrame("Button", nil, d, "BackdropTemplate")
    d.backBtn:SetSize(80, 20)
    d.backBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    d.backBtn:SetBackdropColor(1, 1, 1, 0.07)
    d.backBtn.label = d.backBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.backBtn.label:SetPoint("CENTER")
    d.backBtn.label:SetText(L["◀ 제작 탭"])
    d.backBtn:SetScript("OnClick", function()
        d.mode = "item"
        d.tab = "craft"
        d.fromCraft = nil
        d.page = 1
        RenderDropdown(d)
        d:Show()
    end)
    d.embLabel:Hide(); d.embBtn:Hide(); d.backBtn:Hide()

    -- 제작 탭: 보석·마부 줄 — 누르면 보석/마법부여 목록(gem/ench 모드)으로 바뀌고 「◀ 제작 탭」으로 돌아온다
    local function CraftRow(labelText, mode)
        local lbl = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        lbl:SetText(labelText)
        local btn = CreateFrame("Button", nil, d, "BackdropTemplate")
        btn:SetSize(DROP_W - 24 - 40, 20)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        btn:SetBackdropColor(1, 1, 1, 0.07)
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.label:SetPoint("LEFT", 8, 0)
        btn.label:SetPoint("RIGHT", -8, 0)
        btn.label:SetJustifyH("LEFT")
        btn.label:SetWordWrap(false)
        btn:SetScript("OnClick", function(self)
            if self.disabled then return end
            d.mode = mode
            d.fromCraft = true
            d.page = 1
            RenderDropdown(d)
            d:Show()
        end)
        btn:SetScript("OnEnter", function(self) if not self.disabled then self:SetBackdropColor(1, 1, 1, 0.14) end end)
        btn:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 1, 1, 0.07) end)
        lbl:Hide(); btn:Hide()
        return lbl, btn
    end
    d.gemRowLabel, d.gemRowBtn = CraftRow(L["보석"], "gem")
    d.enchRowLabel, d.enchRowBtn = CraftRow(L["마부"], "ench")

    -- 도감 로트가 지연 로딩되면 캐시 비우고 다시 그림 (연속 이벤트는 0.5초 스로틀)
    d:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
    d:SetScript("OnEvent", function(self)
        if not (self:IsShown() and (self.tab == "dungeon" or self.tab == "raid") and self.mode ~= "gem") then return end
        if self.ejRefreshQueued then return end
        self.ejRefreshQueued = true
        C_Timer.After(0.5, function()
            self.ejRefreshQueued = nil
            if self:IsShown() and (self.tab == "dungeon" or self.tab == "raid") then
                if WythicPlus_GearInvalidateEJLoot then WythicPlus_GearInvalidateEJLoot() end
                RenderDropdown(self)
            end
        end)
    end)

    -- 페이지 바 (이전/다음 — 인게임 플라이아웃처럼 하단)
    local function PageButton(text, delta)
        local b = CreateFrame("Button", nil, d, "BackdropTemplate")
        b:SetSize(52, 20)
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        b:SetBackdropColor(1, 1, 1, 0.07)
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.label:SetPoint("CENTER")
        b.label:SetText(text)
        b:SetScript("OnClick", function()
            d.page = d.page + delta
            RenderDropdown(d)
        end)
        return b
    end
    d.pagePrev = PageButton(L["◀ 이전"], -1)
    d.pageNext = PageButton(L["다음 ▶"], 1)
    d.pageText = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")

    -- 초기화 (핀 해제)
    d.resetBtn = CreateFrame("Button", nil, d, "BackdropTemplate")
    d.resetBtn:SetSize(60, 20)
    d.resetBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    d.resetBtn:SetBackdropColor(1, 1, 1, 0.07)
    d.resetBtn.label = d.resetBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.resetBtn.label:SetPoint("CENTER")
    d.resetBtn.label:SetText(L["|cffffb454초기화|r"])
    d.resetBtn:SetScript("OnClick", function()
        if d.mode == "gem" then
            panel.pinnedGems[d.slotKey] = nil
        elseif d.mode == "ench" then
            panel.pinnedEnchants[d.slotKey] = nil -- 착용 마부 유지로 복귀
        else
            panel.pinnedItems[d.slotKey] = nil
            panel.pinnedConv[d.slotKey] = nil
            panel.pinnedTracks[d.slotKey] = nil
        end
        panel.presetRatings = nil
        if panel.Redraw then panel.Redraw() end
        RenderDropdown(d)
        d:Show()
    end)

    -- 추천 해제/복원 (핀 없이 시뮬 추천만 끄기 — 착용템 유지, 웹의 '추천 해제'와 동일)
    d.dismissBtn = CreateFrame("Button", nil, d, "BackdropTemplate")
    d.dismissBtn:SetSize(68, 20)
    d.dismissBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    d.dismissBtn:SetBackdropColor(1, 1, 1, 0.07)
    d.dismissBtn.label = d.dismissBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.dismissBtn.label:SetPoint("CENTER")
    d.dismissBtn:SetScript("OnClick", function()
        if panel.dismissedSlots[d.slotKey] then
            panel.dismissedSlots[d.slotKey] = nil
        else
            panel.dismissedSlots[d.slotKey] = true
            panel.pinnedTracks[d.slotKey] = nil
        end
        panel.presetRatings = nil
        if panel.Redraw then panel.Redraw() end
        RenderDropdown(d)
        d:Show()
    end)

    -- 부위 잠금 버튼 — 현재 선택(핀 있으면 그 아이템, 없으면 착용템)을 고정하고 최적화에서 제외.
    -- 가방/메타에서 아이템을 고른 자리에서 바로 잠글 수 있게 하단 바에 항상 노출 (발견성).
    d.lockBtn = CreateFrame("Button", nil, d, "BackdropTemplate")
    d.lockBtn:SetSize(102, 20)
    d.lockBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    d.lockBtn:SetBackdropColor(1, 1, 1, 0.07)
    d.lockBtn.label = d.lockBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.lockBtn.label:SetPoint("CENTER")
    d.lockBtn:SetScript("OnClick", function()
        local k = d.slotKey
        local turningOn = not panel.lockedSlots[k]
        -- 핀 없는 자동 추천이 표시 중이면 그 추천을 핀으로 승격해 "그 아이템"이 잠기게
        local cellHere = panel.cells and panel.cells[k]
        local recHere = cellHere and cellHere.rec
        if turningOn and panel.pinnedItems[k] == nil and recHere and recHere.itemId then
            if recHere.recLink then
                panel.pinnedItems[k] = RecToPin(recHere)
            else
                panel.pinnedItems[k] = recHere.itemId
                panel.pinnedConv[k] = recHere.recConv or ""
            end
        end
        panel.lockedSlots[k] = turningOn or nil
        if panel.lockedSlots[k] then panel.dismissedSlots[k] = nil end
        panel.presetRatings = nil
        if panel.Redraw then panel.Redraw() end
        RenderDropdown(d)
        d:Show()
    end)
    d.lockBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(1, 1, 1, 0.12)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["부위 잠금"], 0.96, 0.72, 0.33)
        GameTooltip:AddLine(L["잠근 부위는 최적화가 건드리지 않습니다."], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["아이템을 골라두고 잠그면 그 아이템으로 확정, 그냥 잠그면 지금 낀 그대로 유지됩니다."], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["|cff888888단축: 슬롯/선택 카드 Shift+클릭|r"], 1, 1, 1)
        GameTooltip:Show()
    end)
    d.lockBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(1, 1, 1, 0.07)
        GameTooltip:Hide()
    end)

    -- 강화 트랙 섹션 (메타 탭 전용)
    d.trackDivider = d:CreateTexture(nil, "ARTWORK")
    d.trackDivider:SetTexture("Interface\\Buttons\\WHITE8X8")
    d.trackDivider:SetVertexColor(1, 1, 1, 0.08)
    d.trackDivider:SetHeight(1)
    d.trackLabel = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d.trackLabel:SetText(L["강화 트랙"])

    d.trackBtns = {}
    -- UPGRADE_TRACKS + '막넴 344' (레이드 마지막 2보스 한정 고정급 — 신화 위 별도 선택지)
    local TRACK_BTN_DEFS = {}
    for i, t in ipairs(UPGRADE_TRACKS) do TRACK_BTN_DEFS[i] = t end
    TRACK_BTN_DEFS[#TRACK_BTN_DEFS + 1] = { key = "Peak", ko = L["상위 신화"] }
    d.trackDefs = TRACK_BTN_DEFS
    for i, t in ipairs(TRACK_BTN_DEFS) do
        local b = CreateFrame("Button", nil, d, "BackdropTemplate")
        b:SetSize((DROP_W - 24 - 6) / 2, 24)
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.label:SetPoint("CENTER")
        b.trackKey = t.key
        b:SetScript("OnClick", function(self)
            if d.tab == "dungeon" or d.tab == "raid" then
                d.viewTrack = self.trackKey -- 조회 필터만 변경 (핀 아님)
            else
                panel.pinnedTracks[d.slotKey] = self.trackKey
                if panel.Redraw then panel.Redraw() end
            end
            RenderDropdown(d)
            d:Show()
        end)
        b:SetScript("OnEnter", function(self)
            if not self.active then self:SetBackdropColor(1, 1, 1, 0.14) end
        end)
        b:SetScript("OnLeave", function(self)
            if not self.active then self:SetBackdropColor(1, 1, 1, 0.07) end
        end)
        d.trackBtns[i] = b
    end

    d:Hide()
    panel.dropdown = d
    return d
end

-- 그리드 아이콘 버튼 (플라이아웃 셀): 아이콘 + 상단 ilvl(품질색) + 하단 순위/가방 표기
-- 드롭다운 공용 섹션 헤더 — 구분선 + 라벨 (4탭 동일 디자인, 색만 출처별)
local function SectionHeader(d, idx, y, text, hexColor)
    d.secHeaders = d.secHeaders or {}
    local h = d.secHeaders[idx]
    if not h then
        h = { div = d:CreateTexture(nil, "ARTWORK"), fs = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") }
        h.div:SetTexture("InterfaceButtonsWHITE8X8")
        h.div:SetVertexColor(1, 1, 1, 0.08)
        h.div:SetHeight(1)
        d.secHeaders[idx] = h
    end
    h.div:ClearAllPoints()
    h.div:SetPoint("TOPLEFT", 10, y)
    h.div:SetPoint("TOPRIGHT", -10, y)
    h.fs:ClearAllPoints()
    h.fs:SetPoint("TOPLEFT", 12, y - 6)
    h.fs:SetText("|cff" .. (hexColor or "8f9199") .. (text or "") .. "|r")
    h.div:Show()
    h.fs:Show()
    return y - 24 -- 다음 콘텐츠 시작
end

local function GridButton(d, i)
    local b = d.grid[i]
    if b then return b end
    b = CreateFrame("Button", nil, d, "BackdropTemplate")
    b:SetSize(GRID_CELL, GRID_CELL)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b:SetBackdropColor(0, 0, 0, 0.5)
    b:SetBackdropBorderColor(0, 0, 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    hl:SetVertexColor(1, 1, 1, 0.15)
    b.ilvl = b:CreateFontString(nil, "OVERLAY")
    b.ilvl:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    b.ilvl:SetPoint("TOP", 0, -3)
    b.sub = b:CreateFontString(nil, "OVERLAY")
    b.sub:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    b.sub:SetPoint("BOTTOM", 0, 3)
    -- 빈 홈(보석 해제) 항목용 다이아 글리프 — 클라이언트 빈 소켓 텍스처는 32px라 44px 셀에서 뭉개진다.
    -- 폰트 글리프는 어느 배율에서도 선명하고 "◇ 보석 선택" 줄과 같은 모양
    b.glyph = b:CreateFontString(nil, "OVERLAY")
    b.glyph:SetFont(STANDARD_TEXT_FONT, 26, "OUTLINE")
    b.glyph:SetPoint("CENTER", 0, 3)
    b.glyph:SetText("|cff9ca3af◇|r")
    b.glyph:Hide()
    -- 착용 중 표시 (아머리 슬롯의 초록 체크와 동일)
    b.check = b:CreateTexture(nil, "OVERLAY")
    b.check:SetSize(14, 14)
    b.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    b.check:SetPoint("TOPRIGHT", 3, 3)
    b.check:Hide()
    b:SetScript("OnEnter", function(self)
        OwnTooltip(d) -- 드롭다운 내부 툴팁은 드롭다운 오른쪽에
        if self.link then
            GameTooltip:SetHyperlink(WithCurrentSpec(self.link))
            -- 제작 탭: 2차 스탯 줄을 지금 선택한 스탯 수치로 (스탯이 모자라면 안내)
            local pd = self:GetParent()
            if pd.tab == "craft" and pd.mode ~= "gem" then
                local info = CraftInfo(self.itemId)
                local keys = CraftKeys(pd.slotKey)
                local st = CraftStats(self.itemId, self.link, keys)
                if st and info and (info.n or 0) > 0 then
                    CraftFixTooltip(st)
                elseif info and (info.n or 0) > #keys then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff00ccffWythic+|r " .. string.format(L["2차 스탯 %d개를 선택하면 수치가 표시됩니다"], info.n), 0.96, 0.62, 0.04, true)
                end
            end
        elseif self.bonuses and self.bonuses ~= "" then
            -- 선택된 강화 트랙을 그리드 툴팁에도 반영 (트랙 스텝 교체만 — VENOM 제외)
            local bonuses = self.bonuses
            local dd = self:GetParent()
            local pt
            if dd.tab == "dungeon" or dd.tab == "raid" then
                pt = dd.viewTrack
            elseif dd.slotKey then
                pt = panel.pinnedTracks[dd.slotKey]
            end
            if pt == "Peak" then pt = "Myth" end -- 비대상 아이템은 신화 기준 (대상은 링크 경로)
            if pt and pt ~= "VENOM" then
                local src = (WythicPlusGearData.sources or {})[self.itemId]
                local tIlvl = TrackMaxIlvl(pt, src and src[1] == "crafted")
                if tIlvl then bonuses = RelinkTrackBonuses(bonuses, tIlvl) end
            end
            -- 변환 티어: 원본 아이템 modifier(64)를 붙여 게임이 원본 2차 배분·착효로 그리게 한다
            local gSpec = panel.effSpec or panel.curSpec
            local srcItem = dd.slotKey and ConvertedSourceItem(gSpec, dd.slotKey, self.itemId, self.conv) or nil
            local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, BuildItemLink(self.itemId, bonuses, srcItem))
            if not ok then GameTooltip:SetItemByID(self.itemId) end
            -- 게임이 그린 2차 스탯 줄이 수집 배분과 다르면(변환 티어·무작위 능력치·제작) 수집 배분으로 고쳐 쓴다
            if ok and dd.slotKey then
                FixTooltipSecondaryStats(gSpec, dd.slotKey, self.itemId, self.conv)
            end
        elseif self.embKey ~= nil then
            -- 장식 모드: 재료 아이템 툴팁 (메타 픽/없음은 안내문)
            if self.embKey == "meta" then
                GameTooltip:SetText(L["메타 픽"], 1, 1, 1)
                GameTooltip:AddLine(L["랭커가 같은 아이템에 쓴 장식을 그대로 따릅니다 (랭커 데이터가 없으면 장식 없음)"], 0.7, 0.7, 0.7, true)
            elseif self.embKey == 0 then
                GameTooltip:SetText(L["장식 없음"], 1, 1, 1)
            else
                GameTooltip:SetItemByID(self.itemId)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cff00ccffWythic+|r " .. L["장식 효과는 메타 근접도 계산에 넣지 않습니다 (Raidbots로 확인)"], 0.8, 0.8, 0.8, true)
        elseif self.enchEntry then
            -- 마법부여 모드: 최고 등급 주문서 툴팁 + 계산 반영 여부
            GameTooltip:SetItemByID(self.itemId)
            local st = EnchantStatText(self.enchEntry.s2)
            GameTooltip:AddLine(" ")
            if st then
                GameTooltip:AddLine("|cff00ccffWythic+|r " .. string.format(L["계산 반영: %s (최고 등급, 착용 마부와의 차이만큼)"], st), 0.8, 0.8, 0.8, true)
            else
                GameTooltip:AddLine("|cff00ccffWythic+|r " .. L["계산 제외 — 발동형·주 스탯·3차 스탯 효과는 메타 근접도에 넣지 않습니다"], 0.6, 0.6, 0.6, true)
            end
        elseif self.itemId == 0 then
            -- 보석 해제(빈 홈) 항목
            GameTooltip:SetText(L["보석 해제"], 1, 1, 1)
            GameTooltip:AddLine(L["이 부위의 보석을 뺀 상태로 계산합니다"], 0.7, 0.7, 0.7, true)
        elseif self.itemId then
            GameTooltip:SetItemByID(self.itemId)
        end
        -- 막 2넴 아이템: 획득 사다리 안내 (랭커 착용 334와 직드랍 344의 혼란 방지)
        if EJTopBossLink and self.itemId and (self.itemIlvl or 0) < 344 and EJTopBossLink(self.itemId) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["신화 난이도 마지막 2보스 직드랍은 344 고정입니다 (금고 경로는 신화 트랙 318~334)"], 0.96, 0.62, 0.04, true)
            GameTooltip:Show()
        end
        FinishTooltip()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self)
        local dd = self:GetParent()
        if dd.mode == "ench" then
            -- 마법부여 핀 토글 (부위 기준 — 아이템 핀이 바뀌어도 유지, 보석 핀과 같은 규칙)
            local nm = self.enchEntry and self.enchEntry.name
            if nm then
                panel.pinnedEnchants[dd.slotKey] = (panel.pinnedEnchants[dd.slotKey] ~= nm) and nm or nil
                panel.presetRatings = nil
                if panel.Redraw then panel.Redraw() end
            end
            RenderDropdown(dd)
            dd:Show()
            return
        end
        if dd.mode == "emb" then
            -- 장식 선택 → 이 부위 제작 핀을 새 장식으로 다시 만들고 제작 탭으로 복귀
            panel.craftEmb = panel.craftEmb or {}
            local emb = (self.embKey ~= "meta") and self.embKey or nil
            panel.craftEmb[dd.slotKey] = emb
            dd.craftEmbWarn = nil
            local pin = panel.pinnedItems[dd.slotKey]
            if type(pin) == "table" and pin.srcTab == "craft" then
                local info = CraftInfo(pin.item_id)
                local e = emb and emb ~= 0 and WythicPlusCraftData.embellishments[emb]
                if not (e and info and not EmbApplies(e.use, info)) then
                    local np = MakeCraftPin(pin.item_id, CraftKeys(dd.slotKey), emb)
                    if np then
                        panel.pinnedItems[dd.slotKey] = np
                        panel.presetRatings = nil
                        if panel.Redraw then panel.Redraw() end
                    end
                else
                    dd.craftEmbWarn = true
                end
            end
            dd.mode = "item"
            dd.tab = "craft"
            dd.page = 1
            RenderDropdown(dd)
            dd:Show()
            return
        end
        if dd.mode == "gem" then
            -- 보석 핀 토글
            if panel.pinnedGems[dd.slotKey] == self.itemId then
                panel.pinnedGems[dd.slotKey] = nil
            else
                -- 다이아몬드(고유 장착) 보석: 전 부위 1개 — 다른 슬롯의 고유 보석 핀 자동 해제
                if WythicPlus_GearIsUniqueGem and WythicPlus_GearIsUniqueGem(self.itemId) then
                    for k, gid in pairs(panel.pinnedGems) do
                        if k ~= dd.slotKey and WythicPlus_GearIsUniqueGem(gid) then
                            panel.pinnedGems[k] = nil
                        end
                    end
                end
                panel.pinnedGems[dd.slotKey] = self.itemId
            end
            panel.presetRatings = nil
            if panel.Redraw then panel.Redraw() end
            RenderDropdown(dd)
            dd:Show()
            return
        end
        local cur = panel.pinnedItems[dd.slotKey]
        local curId = type(cur) == "table" and cur.item_id or cur
        local sameVariant = self.link ~= nil or (panel.pinnedConv[dd.slotKey] or "") == (self.conv or "")
        -- 제작 탭에선 기존 제작 핀만 "같은 선택"(다른 탭의 같은 ID 핀은 제작 핀으로 교체)
        if dd.tab == "craft" and not (type(cur) == "table" and cur.srcTab == "craft") then sameVariant = false end
        if curId and curId == self.itemId and sameVariant then
            -- 핀된 아이템 재클릭 = 핀 해제 (토글)
            panel.pinnedItems[dd.slotKey] = nil
            panel.pinnedConv[dd.slotKey] = nil
        elseif dd.tab == "craft" then
            -- 제작 탭: 지정 스탯으로 최고 품질 제작을 가정한 핀. 착용 중인 같은 제작템도 다른 스탯 재제작일 수 있어
            -- "착용 이하 레벨은 유지" 규칙을 적용하지 않는다. 스탯이 모자라면 핀 없이 안내만
            local keys = CraftKeys(dd.slotKey)
            -- 고른 장식을 이 아이템에 쓸 수 없으면(재질·전문기술 제한) 핀 없이 안내
            local emb = CraftEmb(dd.slotKey)
            local embDef = emb and emb ~= 0 and WythicPlusCraftData.embellishments[emb]
            local cinfo = CraftInfo(self.itemId)
            if embDef and cinfo and (cinfo.n or 0) > 0 and not EmbApplies(embDef.use, cinfo) then
                dd.craftEmbWarn = true
                RenderDropdown(dd)
                dd:Show()
                return
            end
            dd.craftEmbWarn = nil
            local pin = MakeCraftPin(self.itemId, keys, emb)
            if not pin then
                -- 스탯이 모자라면 안내. 스탯은 충분한데 nil이면 아이템 정보 로딩 중(EnsureItem 요청됨) — 다시 클릭하면 된다
                local info = CraftInfo(self.itemId)
                dd.craftWarn = info and #keys < (info.n or 0) or nil
                RenderDropdown(dd)
                dd:Show()
                return
            end
            panel.pinnedItems[dd.slotKey] = pin
            panel.pinnedConv[dd.slotKey] = nil
            panel.pinnedTracks[dd.slotKey] = nil -- 제작템은 강화 트랙 밖
        elseif self.link then
            -- 착용템과 같은 아이템의 착용 이하 레벨 버전은 핀하지 않는다 — "유지"로 처리
            -- (카드는 숨김 규칙으로 안 뜨는데 시뮬에만 저레벨이 반영되던 불일치 방지)
            local wc = panel.cells and panel.cells[dd.slotKey]
            local wl = wc and wc.inv and GetInventoryItemLink("player", wc.inv)
            local wid = wl and C_Item.GetItemInfoInstant(wl)
            -- 가방 탭의 같은 ID 아이템은 다른 실물(2차 배분·ilvl이 다른 사본)이므로 이 규칙에서 제외한다(2026-09-20)
            if dd.tab ~= "bags" and wid == self.itemId and (self.itemIlvl or 0) <= ((wl and C_Item.GetDetailedItemLevelInfo(wl)) or 0) then
                panel.pinnedItems[dd.slotKey] = nil
                panel.pinnedConv[dd.slotKey] = nil
            else
                -- 가방/도감/메타(344 링크) 아이템: 실제 링크 스탯으로 핀 (수치 반영).
                -- srcTab = 선택한 탭 — 카드 색/딱지 체계의 근거 (메타 탭 링크 핀이 '가방'으로 새는 것 방지)
                panel.pinnedItems[dd.slotKey] = {
                    item_id = self.itemId, link = self.link,
                    ilvl = self.itemIlvl or 0,
                    stats = (WythicPlus_GearLinkStats and WythicPlus_GearLinkStats(self.link)) or {},
                    srcTab = dd.tab,
                }
            end
        elseif self.itemId then
            panel.pinnedItems[dd.slotKey] = self.itemId
            panel.pinnedConv[dd.slotKey] = self.conv or ""
        end
        panel.dismissedSlots[dd.slotKey] = nil -- 수동 핀 = 추천 해제 상태 종료
        -- 새 핀이 맹독저주 대상이 아니면 잔존 VENOM 트랙핀 해제
        if panel.pinnedTracks[dd.slotKey] == "VENOM" then
            local v = WythicPlusGearData.venom
            local pin = panel.pinnedItems[dd.slotKey]
            local pid = type(pin) == "table" and pin.item_id or pin
            if not (v and v.items and pid and v.items[pid]) then
                panel.pinnedTracks[dd.slotKey] = nil
            end
        end
        -- 불가능 무기 조합 가드: 양손 주무기 핀과 한손용 보조 핀은 공존 불가 (최근 선택 우선).
        -- 분노 쌍양손(보조도 양손)은 유지. (매트릭스 스캔에서 발견 — 존재 불가 세팅 수치 표시 방지)
        local function pinIsTwoHand(slotKey2, pin)
            if not pin then return false end
            if type(pin) == "table" and pin.link then
                local _, _, _, eloc = C_Item.GetItemInfoInstant(pin.link)
                return eloc == "INVTYPE_2HWEAPON" or eloc == "INVTYPE_RANGED" or eloc == "INVTYPE_RANGEDRIGHT"
            end
            local pid = type(pin) == "table" and pin.item_id or pin
            local list = panel.effSpec and panel.effSpec.items and panel.effSpec.items[slotKey2]
            for gi = 1, #(list or {}) do
                if list[gi][1] == pid then return list[gi][8] == 1 end
            end
            return false
        end
        if dd.slotKey == "MAIN_HAND" and pinIsTwoHand("MAIN_HAND", panel.pinnedItems.MAIN_HAND)
            and panel.pinnedItems.OFF_HAND and not pinIsTwoHand("OFF_HAND", panel.pinnedItems.OFF_HAND) then
            panel.pinnedItems.OFF_HAND = nil
            panel.pinnedConv.OFF_HAND = nil
        elseif dd.slotKey == "OFF_HAND" and panel.pinnedItems.OFF_HAND
            and not pinIsTwoHand("OFF_HAND", panel.pinnedItems.OFF_HAND)
            and pinIsTwoHand("MAIN_HAND", panel.pinnedItems.MAIN_HAND) then
            panel.pinnedItems.MAIN_HAND = nil
            panel.pinnedConv.MAIN_HAND = nil
        end
        panel.presetRatings = nil -- 수동 변경 → 프리셋 레이팅 동결 해제
        -- 핀은 잠금이 아니다: 이번에 수정한 슬롯만 확정하고, 잠기지 않은 다른 슬롯의
        -- 이전 핀은 풀어 엔진 재최적화에 맡긴다 (선택을 유지하려면 부위 잠금 사용)
        for k in pairs(panel.pinnedItems) do
            if k ~= dd.slotKey and not panel.lockedSlots[k] then
                panel.pinnedItems[k] = nil
                panel.pinnedConv[k] = nil
            end
        end
        -- 기본 상태(최적화 OFF)에서 아이템을 수정하면 최적화를 바로 시작
        -- (가방 탭에서 골랐으면 소지품 기준, 그 외 탭은 메타 기준)
        local autoStart = not panel.optimize and panel.pinnedItems[dd.slotKey] ~= nil
        if autoStart then
            panel.optimize = true
            panel.optMode = (dd.tab == "bags") and "owned" or "meta"
        end
        if panel.Redraw then panel.Redraw(autoStart) end
        RenderDropdown(dd) -- 닫지 않고 핀 상태 반영해 유지 (초기화·해제 접근성)
        dd:Show()
    end)
    d.grid[i] = b
    return b
end

-- 드롭다운 내용 렌더 (탭/페이지 상태 기준)
RenderDropdown = function(d)
    local slotKey = d.slotKey
    -- 제작 탭 위젯은 제작 탭에서만 (아래 레이아웃에서 다시 표시)
    d.craftLabel:Hide()
    d.craftHint:Hide()
    for _, b in ipairs(d.craftStatBtns) do b:Hide() end
    d.embLabel:Hide()
    d.embBtn:Hide()
    d.backBtn:Hide()
    d.gemRowLabel:Hide(); d.gemRowBtn:Hide()
    d.enchRowLabel:Hide(); d.enchRowBtn:Hide()

    -- ── 마법부여 모드 / 장식 모드: 탭·트랙 없이 선택지 그리드 (보석 모드와 같은 골격) ──
    if d.mode == "ench" or d.mode == "emb" then
        for _, t in ipairs({ d.tabMeta, d.tabBags, d.tabDungeon, d.tabRaid, d.tabCraft }) do t:Hide() end
        d.trackDivider:Hide()
        d.trackLabel:Hide()
        for _, b in ipairs(d.trackBtns) do b:Hide() end
        d.dismissBtn:Hide()
        d.lockBtn:Hide()
        local isEnch = d.mode == "ench"
        d:SetBackdropBorderColor(isEnch and 0.655 or CRAFT_BLUE[1], isEnch and 0.545 or CRAFT_BLUE[2], isEnch and 0.980 or CRAFT_BLUE[3], 0.5)
        local list = {}
        if isEnch then
            -- 2차 스탯 마부(계산 반영) 먼저 — 수치 큰 순, 나머지는 이름순
            for _, e in ipairs(EnchantsForSlot(slotKey)) do list[#list + 1] = { ench = e } end
            local function tot(e)
                local t = 0
                for _, k in ipairs(STAT_ORDER) do t = t + ((e.s2 and e.s2[k]) or 0) end
                return t
            end
            table.sort(list, function(a, b)
                local ta, tb = tot(a.ench), tot(b.ench)
                if ta ~= tb then return ta > tb end
                return a.ench.name < b.ench.name
            end)
        else
            list[#list + 1] = { emb = "meta" }
            list[#list + 1] = { emb = 0 }
            for _, o in ipairs(EmbOptionsForSlot(slotKey)) do list[#list + 1] = { emb = o.bid, item = o.item } end
        end
        local y = SectionHeader(d, 1, -10, isEnch and L["마법부여 · 최고 등급"] or L["장식 선택 (계산 제외)"],
            isEnch and "a78bfa" or "60a5fa")
        if d.secHeaders then
            for i = 2, #d.secHeaders do d.secHeaders[i].div:Hide(); d.secHeaders[i].fs:Hide() end
        end
        local pages = math.max(1, math.ceil(#list / GRID_PER_PAGE))
        if d.page > pages then d.page = pages end
        local first = (d.page - 1) * GRID_PER_PAGE
        local shown = 0
        local wornEnch = isEnch and WornEnchantId(slotKey)
        local curEmb = CraftEmb(slotKey)
        for i = 1, GRID_PER_PAGE do
            local o = list[first + i]
            local b = GridButton(d, i)
            if o then
                shown = shown + 1
                local col = (i - 1) % GRID_COLS
                local row = math.floor((i - 1) / GRID_COLS)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 12 + col * (GRID_CELL + 6), y - row * (GRID_CELL + 6))
                b.link, b.bonuses, b.conv, b.itemIlvl = nil, nil, nil, nil
                b.ilvl:SetText("")
                b.icon:SetVertexColor(1, 1, 1, 1)
                b.glyph:Hide()
                local selected
                if isEnch then
                    local e = o.ench
                    EnsureItem(e.item2)
                    b.itemId, b.enchEntry, b.embKey = e.item2, e, nil
                    b.icon:SetTexture(C_Item.GetItemIconByID(e.item2) or 134400)
                    local st = e.s2
                    local txt
                    for _, k in ipairs(STAT_ORDER) do
                        if st and (st[k] or 0) > 0 then txt = CRAFT_SHORT[k] .. st[k] break end
                    end
                    b.sub:SetText(txt and ("|cffa78bfa" .. txt .. "|r") or ("|cff6b7280" .. L["효과"] .. "|r"))
                    local wHit = wornEnch and EnchIndex().byId[wornEnch]
                    b.check:SetShown(wHit ~= nil and wHit.e == e)
                    selected = panel.pinnedEnchants[slotKey] == e.name
                else
                    b.enchEntry, b.embKey = nil, o.emb
                    if o.emb == "meta" or o.emb == 0 then
                        b.itemId = nil
                        b.icon:SetTexture("Interface\\Buttons\\WHITE8X8")
                        b.icon:SetVertexColor(0.08, 0.09, 0.11, 1)
                        b.glyph:SetText(o.emb == "meta" and "|cfffbbf24M|r" or "|cff9ca3af◇|r")
                        b.glyph:Show()
                        b.sub:SetText("|cff9ca3af" .. (o.emb == "meta" and L["메타 픽"] or L["없음"]) .. "|r")
                    else
                        EnsureItem(o.item)
                        b.itemId = o.item
                        b.icon:SetTexture(C_Item.GetItemIconByID(o.item) or 134400)
                        b.sub:SetText("")
                    end
                    b.check:Hide()
                    selected = (o.emb == "meta" and curEmb == nil) or (o.emb ~= "meta" and curEmb == o.emb)
                end
                if selected then
                    local c = isEnch and { 0.655, 0.545, 0.980 } or CRAFT_BLUE
                    b:SetBackdropBorderColor(c[1], c[2], c[3], 1)
                else
                    b:SetBackdropBorderColor(0, 0, 0, 1)
                end
                b:Show()
            else
                b:Hide()
            end
        end
        for i = GRID_PER_PAGE + 1, #d.grid do d.grid[i]:Hide() end
        local gridRows = shown > 0 and math.ceil(math.min(#list - first, GRID_PER_PAGE) / GRID_COLS) or 1
        y = y - gridRows * (GRID_CELL + 6) - 2
        if shown == 0 then
            d.pageText:SetText(isEnch and L["이 부위에 고를 수 있는 마법부여 없음"] or L["이 부위에 쓸 수 있는 장식 없음"])
            d.pageText:ClearAllPoints()
            d.pageText:SetPoint("TOPLEFT", 14, y - 4)
            d.pageText:SetWidth(DROP_W - 28)
            y = y - 22
        end
        -- 하단: (마부) 초기화 = 착용 마부 유지 / (장식) 제작 탭 복귀 + 페이징
        local pinnedHere = isEnch and panel.pinnedEnchants[slotKey] ~= nil
        d.resetBtn:ClearAllPoints()
        d.resetBtn:SetPoint("TOPLEFT", 12, y)
        d.resetBtn:SetShown(pinnedHere)
        d.backBtn:ClearAllPoints()
        if pinnedHere then d.backBtn:SetPoint("LEFT", d.resetBtn, "RIGHT", 6, 0) else d.backBtn:SetPoint("TOPLEFT", 12, y) end
        d.backBtn:SetShown(not isEnch or d.fromCraft == true)
        if pages > 1 then
            d.pageNext:ClearAllPoints()
            d.pageNext:SetPoint("TOPRIGHT", -12, y)
            d.pagePrev:ClearAllPoints()
            d.pagePrev:SetPoint("RIGHT", d.pageNext, "LEFT", -4, 0)
            d.pagePrev:SetShown(d.page > 1)
            d.pageNext:SetShown(d.page < pages)
            if shown > 0 then
                d.pageText:ClearAllPoints()
                d.pageText:SetPoint("RIGHT", (d.page > 1) and d.pagePrev or d.pageNext, "LEFT", -8, 0)
                d.pageText:SetWidth(0)
                d.pageText:SetText(d.page .. "/" .. pages)
            end
        else
            d.pagePrev:Hide()
            d.pageNext:Hide()
            if shown > 0 then d.pageText:SetText("") end
        end
        if pinnedHere or not isEnch or d.fromCraft or pages > 1 then y = y - 26 end
        d:SetSize(DROP_W, -y + 10)
        return
    end

    -- ── 보석 모드: 탭/트랙/맹독저주 없이 보석 후보 그리드만 ──
    if d.mode == "gem" then
        -- 아이템 모드가 남긴 섹션 제목·추가 그리드 칸 정리 (제작 탭 제목이 보석 아이콘 위에 겹치던 문제)
        for _, h in ipairs(d.secHeaders or {}) do h.div:Hide(); h.fs:Hide() end
        for i = GRID_PER_PAGE + 1, #d.grid do d.grid[i]:Hide() end
        d.tabMeta:Hide()
        d.tabBags:Hide()
        d.tabDungeon:Hide()
        d.tabRaid:Hide()
        d.tabCraft:Hide()
        d.trackDivider:Hide()
        d.trackLabel:Hide()
        for _, b in ipairs(d.trackBtns) do b:Hide() end

        local metaList = (panel.effSpec and panel.effSpec.gems and panel.effSpec.gems[slotKey]) or {}
        -- 착용 보석 / 보석 핀 / 시뮬 보석 추천이 있으면 맨 앞에 "빈 홈(보석 해제)" 항목 — 핀 값 0 (2026-09-12 요청)
        local cellRef = panel.cells[slotKey]
        local wlink = cellRef and cellRef.inv and GetInventoryItemLink("player", cellRef.inv)
        local wg = wlink and WythicPlus_GearLinkGems and WythicPlus_GearLinkGems(wlink)
        local ls = panel.lastSim
        local hasRec = ls ~= nil and ((ls.gemPins ~= nil and ls.gemPins[slotKey] ~= nil)
            or (ls.gemRecommendations ~= nil and ls.gemRecommendations[slotKey] ~= nil))
        local canRemove = (wg ~= nil and wg[1] ~= nil) or panel.pinnedGems[slotKey] ~= nil or hasRec
        local list = {}
        if canRemove then list[#list + 1] = { 0 } end
        for _, e in ipairs(metaList) do list[#list + 1] = e end
        local pages = math.max(1, math.ceil(#list / GRID_PER_PAGE))
        if d.page > pages then d.page = pages end
        local first = (d.page - 1) * GRID_PER_PAGE
        local y = -12
        local shown = 0
        for i = 1, GRID_PER_PAGE do
            local e = list[first + i]
            local b = GridButton(d, i)
            if e then
                shown = shown + 1
                local gid = e[1]
                EnsureItem(gid)
                local col = (i - 1) % GRID_COLS
                local row = math.floor((i - 1) / GRID_COLS)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 12 + col * (GRID_CELL + 6), y - row * (GRID_CELL + 6))
                b.itemId = gid
                b.link = nil
                b.bonuses = nil
                b.conv = nil
                b.embKey = nil
                b.enchEntry = nil
                b.itemIlvl = nil
                b.ilvl:SetText("")
                if gid == 0 then
                    -- 빈 홈: 어두운 바탕 + 선명한 다이아 글리프 (텍스처 재사용이라 색을 명시)
                    b.icon:SetTexture("Interface\\Buttons\\WHITE8X8")
                    b.icon:SetVertexColor(0.08, 0.09, 0.11, 1)
                    b.glyph:SetText("|cff9ca3af◇|r") -- 장식 모드가 바꿔 둔 글리프 복원 (버튼 재사용)
                    b.glyph:Show()
                    b.sub:SetText("|cff9ca3af" .. L["빈 홈"] .. "|r")
                    b.check:SetShown(wg == nil or wg[1] == nil) -- 지금 보석이 없으면 현재 상태 표시
                else
                    b.icon:SetTexture(C_Item.GetItemIconByID(gid) or 134400)
                    b.icon:SetVertexColor(1, 1, 1, 1)
                    b.glyph:Hide()
                    b.sub:SetText("|cff9ca3af" .. string.format(L["%d명"], e[2] or 0) .. "|r")
                    b.check:SetShown(wg ~= nil and wg[1] == gid)
                end
                if panel.pinnedGems[slotKey] == gid then
                    b:SetBackdropBorderColor(AMBER[1], AMBER[2], AMBER[3], 1)
                else
                    b:SetBackdropBorderColor(0, 0, 0, 1)
                end
                b:Show()
            else
                b:Hide()
            end
        end
        local gridRows = shown > 0 and math.ceil(math.min(#list - first, GRID_PER_PAGE) / GRID_COLS) or 1
        y = y - gridRows * (GRID_CELL + 6) - 2
        if shown == 0 then
            d.pageText:SetText(L["이 부위의 메타 보석 데이터 없음"])
            d.pageText:ClearAllPoints()
            d.pageText:SetPoint("TOPLEFT", 14, y - 4)
            y = y - 22
        end
        local pinnedHere = panel.pinnedGems[slotKey] ~= nil
        d.resetBtn:ClearAllPoints()
        d.resetBtn:SetPoint("TOPLEFT", 12, y)
        d.resetBtn:SetShown(pinnedHere)
        d.backBtn:ClearAllPoints()
        if pinnedHere then d.backBtn:SetPoint("LEFT", d.resetBtn, "RIGHT", 6, 0) else d.backBtn:SetPoint("TOPLEFT", 12, y) end
        d.backBtn:SetShown(d.fromCraft == true)
        d.dismissBtn:Hide()
        d.lockBtn:Hide() -- 보석 모드엔 부위 잠금 버튼 없음 (아이템 드롭다운 전용)
        if pages > 1 then
            d.pageNext:ClearAllPoints()
            d.pageNext:SetPoint("TOPRIGHT", -12, y)
            d.pagePrev:ClearAllPoints()
            d.pagePrev:SetPoint("RIGHT", d.pageNext, "LEFT", -4, 0)
            d.pagePrev:SetShown(d.page > 1)
            d.pageNext:SetShown(d.page < pages)
        else
            d.pagePrev:Hide()
            d.pageNext:Hide()
            if shown > 0 then d.pageText:SetText("") end
        end
        if pinnedHere or pages > 1 or d.fromCraft then y = y - 26 end
        d:SetSize(DROP_W, -y + 10)
        return
    end
    d.tabMeta:Show()
    d.tabBags:Show()
    d.tabDungeon:Show()
    d.tabRaid:Show()
    d.tabCraft:Show()

    -- 탭 스타일: 메타=앰버 / 가방=에메랄드 / 던전=하늘 / 레이드=보라 / 제작=파랑 (출처 뱃지 색 계열)
    local TAB_DEFS = {
        { btn = d.tabMeta, key = "meta", name = L["메타"], color = AMBER },
        { btn = d.tabBags, key = "bags", name = L["가방"], color = EMERALD },
        { btn = d.tabDungeon, key = "dungeon", name = L["던전"], color = SKY },
        { btn = d.tabRaid, key = "raid", name = L["레이드"], color = VIOLET },
        { btn = d.tabCraft, key = "craft", name = L["제작"], color = CRAFT_BLUE },
    }
    local bc = AMBER
    for _, t in ipairs(TAB_DEFS) do
        if d.tab == t.key then
            -- 선택 표시는 반투명 색 배경 — 텍스트는 흰색 유지 (검은 반전 금지)
            t.btn:SetBackdropColor(t.color[1], t.color[2], t.color[3], 0.35)
            t.btn.label:SetText(t.name)
            bc = t.color
        else
            t.btn:SetBackdropColor(1, 1, 1, 0.07)
            t.btn.label:SetText(t.name)
        end
    end
    d:SetBackdropBorderColor(bc[1], bc[2], bc[3], 0.5)

    -- 웹과 동일: 다른 부위에 착용 중이거나 다른 부위에서 추천/핀 중인 아이템은 후보에서 제외
    -- (현재 슬롯 착용템은 남김 — 선택하면 "유지"로 처리)
    local taken = {}
    for k, c in pairs(panel.cells) do
        if k ~= slotKey then
            local eid = GetInventoryItemID("player", c.inv)
            if eid then taken[eid] = true end
            if panel.lastRecs[k] then taken[panel.lastRecs[k]] = true end
            local pin = panel.pinnedItems[k]
            local pinId = type(pin) == "table" and pin.item_id or pin
            if pinId then taken[pinId] = true end
        end
    end

    -- 항목 수집
    local entries = {}
    local dgGroups -- 던전 탭: { { name = 던전명, items = {entry...} }, ... }
    local srcs = WythicPlusGearData.sources or {}
    -- 쌍 슬롯(장신구/반지)은 슬롯 구분이 무의미 — 양쪽 목록 합집합을 통합 순위(paired)로 정렬
    local SLOT_PAIR = { FINGER_1 = "FINGER_2", FINGER_2 = "FINGER_1",
                        TRINKET_1 = "TRINKET_2", TRINKET_2 = "TRINKET_1" }
    local function SlotCandidates()
        local items = panel.effSpec and panel.effSpec.items
        local list = (items and items[slotKey]) or {}
        local otherKey = SLOT_PAIR[slotKey]
        local other = otherKey and items and items[otherKey]
        if not other then return list end
        local merged, seen = {}, {}
        for _, src in ipairs({ list, other }) do
            for i = 1, #src do
                local e = src[i]
                local k = e[1] .. "|" .. (e[12] or "")
                if not seen[k] then
                    seen[k] = true
                    merged[#merged + 1] = e
                end
            end
        end
        table.sort(merged, function(a, b)
            local ra = MetaRankOf(panel.curSpec, slotKey, a[1], a[12] or "") or 999
            local rb = MetaRankOf(panel.curSpec, slotKey, b[1], b[12] or "") or 999
            if ra ~= rb then return ra < rb end
            return (a[2] or 0) > (b[2] or 0) -- 순위 동률은 착용자 수
        end)
        return merged
    end
    local function MetaEntry(e, ptOverride)
        local crafted = srcs[e[1]] and srcs[e[1]][1] == "crafted"
        local pt = ptOverride or panel.pinnedTracks[slotKey]
        local shownIlvl = e[3]
        if pt == "VENOM" then
            -- 맹독저주는 대상 4종에만 344 — 나머지 후보는 원래 ilvl 유지
            local v = WythicPlusGearData.venom
            if v and v.items and v.items[e[1]] then shownIlvl = v.ilvl end
        elseif pt and HasTrackStep(e[11]) then
            -- 트랙 단계 ID가 있는(=트랙 강화되는) 아이템에만 트랙 ilvl 표기
            shownIlvl = TrackMaxIlvl(pt, crafted) or e[3]
        end
        return {
            itemId = e[1], ilvl = shownIlvl, bonuses = e[11], conv = e[12] or "",
            rank = MetaRankOf(panel.curSpec, slotKey, e[1], e[12] or ""), -- 절대 순위 (변형 구분)
        }
    end
    if d.tab == "meta" then
        local list = SlotCandidates()
        local metaPt = panel.pinnedTracks[slotKey]
        for i = 1, #list do
            local e = list[i]
            if not taken[e[1]] then
                -- '막넴 344': 대상(마지막 2보스) 아이템은 검증된 344 링크, 비대상은 신화(334) 기준
                local entry = MetaEntry(e, metaPt == "Peak" and "Myth" or nil)
                if metaPt == "Peak" then
                    local pl = PeakLink(e[1])
                    if pl then
                        entry.link = pl
                        entry.ilvl = C_Item.GetDetailedItemLevelInfo(pl) or entry.ilvl
                        entry.bonuses = nil
                    end
                end
                entries[#entries + 1] = entry
            end
        end
    elseif d.tab == "dungeon" or d.tab == "raid" then
        -- 도감(Encounter Journal) 로트 브라우저: 시즌 던전/레이드에서 이 부위에 드랍되는
        -- 내 클래스 착용 가능 아이템 전부 (커스터마이징 소스). 데이터에 있는 아이템은
        -- 데이터 항목으로(트랙/변형 표기 일치), 없는 아이템은 도감 링크로 표시·핀.
        local inst = EJSeasonInstances()
        local allow = SLOT_INVTYPE[slotKey]
        local excluded = panel.excludedRaids or {}
        -- 이 탭들의 강화 트랙은 탭 로컬 조회 기준(핀과 분리) — 처음 열면 챔피언.
        -- 표기·툴팁 모두 선택 트랙 만렙으로 리링크해 애드온 전체의 트랙 기준과 일치시킨다.
        d.viewTrack = d.viewTrack or "Champion"
        if d.tab == "dungeon" and d.viewTrack == "Peak" then d.viewTrack = "Myth" end -- 막넴은 레이드 전용
        local ptView = d.viewTrack
        local effView = ptView == "Peak" and "Myth" or ptView -- 리링크 기준
        dgGroups = {}
        -- 데이터 항목도 최종 링크를 달아 링크 핀 경로로 — 핀하면 메타 딱지가 아니라
        -- 탭 색/딱지(던전·레이드)가 붙고, 표기·툴팁·핀이 같은 링크(단일 진실원)
        local function DataLink(e)
            -- 변환 티어면 원본 아이템 modifier(64)까지 붙여 툴팁이 원본 배분·착효로 그려지게
            local srcItem = ConvertedSourceItem(panel.effSpec or panel.curSpec, slotKey, e[1], e[12] or "")
            return EJDisplayLink(BuildItemLink(e[1], e[11], srcItem), effView)
        end
        local function AttachLink(entry, e)
            if entry.link then return end -- Peak 오버라이드 우선
            local dl = DataLink(e)
            if dl then
                entry.link = dl
                entry.ilvl = C_Item.GetDetailedItemLevelInfo(dl) or entry.ilvl
            end
        end
        if inst and allow then
            local dataById = {}
            local mlist = SlotCandidates()
            for i = 1, #mlist do
                if dataById[mlist[i][1]] == nil then dataById[mlist[i][1]] = mlist[i] end
            end
            local names, byName = {}, {}
            for _, info in pairs(inst) do
                if info.type == d.tab and not (d.tab == "raid" and excluded[info.en]) then
                    local grp = { type = d.tab, nameKo = info.ko, nameEn = info.en, items = {} }
                    local seen = {}
                    for _, it in ipairs(EJLoot(info.id, info.isRaid)) do
                        local itemId = it.itemId
                        local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemId)
                        if equipLoc and allow[equipLoc] and not taken[itemId] and not seen[itemId]
                            and EJUsable(itemId, it.link, slotKey) then
                            seen[itemId] = true
                            local e = dataById[itemId]
                            if e then
                                local entry = MetaEntry(e, effView)
                                if ptView == "Peak" then
                                    local pl = PeakLink(itemId)
                                    if pl then
                                        entry.link = pl
                                        entry.ilvl = C_Item.GetDetailedItemLevelInfo(pl) or entry.ilvl
                                        entry.bonuses = nil
                                    end
                                end
                                AttachLink(entry, e)
                                grp.items[#grp.items + 1] = entry
                            else
                                -- 단일 진실원: 트랙 리링크된 최종 링크 → 표기 ilvl·툴팁·핀 전부 이 링크.
                                -- '막넴 344' 선택 시 대상 아이템은 검증된 344 스텝 링크 사용
                                local dl
                                if ptView == "Peak" then dl = PeakLink(itemId) end
                                if not dl then dl = EJDisplayLink(it.link, effView) end
                                grp.items[#grp.items + 1] = {
                                    itemId = itemId,
                                    ilvl = dl and C_Item.GetDetailedItemLevelInfo(dl) or nil,
                                    link = dl,
                                    rank = MetaRankOf(panel.curSpec, slotKey, itemId, ""),
                                }
                            end
                        end
                    end
                    byName[info.en] = grp
                    grp.seen = seen
                end
            end
            -- 번들 데이터의 레이드/던전 아이템 합류 — 도감은 보스 드랍만 보여주므로
            -- 쓰레기몹 BOE·수집 기반 아이템(랭커 착용)이 빠질 수 있다 (예: 레이드 반지)
            for i = 1, #mlist do
                local e = mlist[i]
                local src2 = srcs[e[1]]
                if src2 and src2[1] == d.tab and not taken[e[1]]
                    and not (d.tab == "raid" and excluded[src2[3]]) then
                    local en = src2[3] or "?"
                    local grp = byName[en]
                    if not grp then -- 도감 매칭 실패해도 데이터 기반으로 그룹 생성
                        grp = { type = d.tab, nameKo = src2[2] or en, nameEn = en, items = {}, seen = {} }
                        byName[en] = grp
                    end
                    if not grp.seen[e[1]] then
                        grp.seen[e[1]] = true
                        local entry = MetaEntry(e, effView)
                        if ptView == "Peak" then
                            local pl = PeakLink(e[1])
                            if pl then
                                entry.link = pl
                                entry.ilvl = C_Item.GetDetailedItemLevelInfo(pl) or entry.ilvl
                                entry.bonuses = nil
                            end
                        end
                        AttachLink(entry, e)
                        grp.items[#grp.items + 1] = entry
                    end
                end
            end
            for en, grp in pairs(byName) do
                if #grp.items > 0 then names[#names + 1] = en end
                grp.seen = nil
            end
            table.sort(names)
            for _, nm in ipairs(names) do dgGroups[#dgGroups + 1] = byName[nm] end
            for _, grp in ipairs(dgGroups) do
                table.sort(grp.items, function(a, b)
                    if (a.rank ~= nil) ~= (b.rank ~= nil) then return a.rank ~= nil end
                    if a.rank and b.rank and a.rank ~= b.rank then return a.rank < b.rank end
                    return (a.ilvl or 0) > (b.ilvl or 0)
                end)
            end
        end
    elseif d.tab == "craft" then
        -- 시즌 전체 제작 장비 중 이 부위·내 전문화에 맞는 것. 링크 = 지금 선택한 스탯 기준 제작 링크
        local cd = WythicPlusCraftData
        local keys = CraftKeys(slotKey)
        for _, it in ipairs(CraftItemsForSlot(slotKey)) do
            if not taken[it.itemId] then
                entries[#entries + 1] = {
                    itemId = it.itemId, ilvl = cd.ilvl, link = CraftLink(it.itemId, keys, CraftEmb(slotKey)),
                    rank = MetaRankOf(panel.curSpec, slotKey, it.itemId, ""), craftN = it.info.n or 0,
                }
            end
        end
        table.sort(entries, function(a, b)
            if (a.rank ~= nil) ~= (b.rank ~= nil) then return a.rank ~= nil end
            if a.rank and b.rank and a.rank ~= b.rank then return a.rank < b.rank end
            if a.craftN ~= b.craftN then return a.craftN > b.craftN end
            return a.itemId < b.itemId
        end)
    else
        for _, it in ipairs(ScanBagsForSlot(slotKey)) do
            if not taken[it.itemId] then
                entries[#entries + 1] = {
                    itemId = it.itemId, ilvl = it.ilvl, link = it.link,
                    -- 메타 채용 순위 라벨 (1~5위만 표시 — FillCard 공통 규칙)
                    rank = MetaRankOf(panel.curSpec, slotKey, it.itemId, ""),
                }
            end
        end
    end

    -- 카드 채우기 (메타/가방/던전 탭 공용)
    local function FillCard(b, e)
        EnsureItem(e.itemId)
        b.itemId = e.itemId
        b.link = e.link
        b.bonuses = e.bonuses
        b.conv = e.conv
        b.itemIlvl = e.ilvl
        b.embKey = nil -- 장식/마부 모드가 남긴 값 초기화 (버튼 재사용)
        b.enchEntry = nil
        b.icon:SetTexture(C_Item.GetItemIconByID(e.itemId) or 134400)
        b.icon:SetVertexColor(1, 1, 1, 1) -- 보석 모드의 빈 홈 항목이 남긴 어두운 색/글리프 초기화 (버튼 재사용)
        if b.glyph then b.glyph:Hide() end
        -- 품질색: 베이스 아이템은 희귀(파랑)여도 강화 상태(보너스ID)면 에픽 — 보너스 링크로 판정
        local qSrc = e.link or e.itemId
        if not e.link and e.bonuses and e.bonuses ~= "" then
            qSrc = BuildItemLink(e.itemId, e.bonuses)
        end
        local q = C_Item.GetItemQualityByID(qSrc)
        if not q and qSrc ~= e.itemId then q = C_Item.GetItemQualityByID(e.itemId) end
        local qc = q and ITEM_QUALITY_COLORS[q]
        b.ilvl:SetText((qc and qc.hex or "|cffffffff") .. (e.ilvl or "") .. "|r")
        -- 순위 라벨은 통합 취급 범위(1~5위)만 — 던전/레이드 탭의 6위 이하 메타 순위는 표시하지 않음
        b.sub:SetText((e.rank and e.rank <= 5) and string.format(L["|cfffbbf24%d위|r"], e.rank)
            or (e.craftN == 0 and ("|cff9ca3af" .. L["고정"] .. "|r")) or "") -- 제작 탭: 스탯 고정 아이템 표기
        local cellRef = panel.cells[slotKey]
        local wornId = cellRef and cellRef.inv and GetInventoryItemID("player", cellRef.inv)
        -- 가방 탭은 실물 비교: 같은 ID의 다른 사본(배분·ilvl 다름)에 "착용 중" 체크를 달지 않는다(2026-09-20)
        local wornLink = (d.tab == "bags" and cellRef and cellRef.inv) and GetInventoryItemLink("player", cellRef.inv) or nil
        b.check:SetShown(wornId ~= nil and e.itemId == wornId and (d.tab ~= "bags" or e.link == wornLink))
        -- 선택 중(핀) 하이라이트 — 가방 아이템 핀은 에메랄드, 메타 핀은 앰버
        local pin = panel.pinnedItems[slotKey]
        local pinId = type(pin) == "table" and pin.item_id or pin
        local convMatch = e.link ~= nil or (panel.pinnedConv[slotKey] or "") == (e.conv or "")
        if pinId == e.itemId and convMatch then
            -- 하이라이트도 핀의 출처 탭 색 체계: 메타=앰버 / 가방=에메랄드 / 던전=하늘 / 레이드=보라
            local pst = type(pin) == "table" and pin.srcTab
            local pc = AMBER
            if pst == "dungeon" then pc = SKY
            elseif pst == "raid" then pc = VIOLET
            elseif pst == "craft" then pc = CRAFT_BLUE
            elseif type(pin) == "table" and pst ~= "meta" then pc = EMERALD end
            b:SetBackdropBorderColor(pc[1], pc[2], pc[3], 1)
        else
            b:SetBackdropBorderColor(0, 0, 0, 1)
        end
        b:Show()
    end

    local pages = 1
    local y = -36 -- 탭 아래
    local shown = 0
    local used = 0 -- 이번 렌더에 쓴 그리드 버튼 수 (탭 전환 잔상 정리용)
    local usedHeaders = 0
    d.secHeaders = d.secHeaders or {}
    if d.tab == "dungeon" or d.tab == "raid" then
        -- 행 레이아웃: [출처명 | 아이콘들] 한 줄 — 던전 8개도 세로로 안 터진다.
        -- 이름은 고정폭(출처 고유색), 아이콘은 오른쪽으로 흐르고 넘치면 줄바꿈.
        local NAME_W = 96
        local ICONS_X = 12 + NAME_W + 8
        local perRow = math.max(1, math.floor((DROP_W - ICONS_X - 10 + 6) / (GRID_CELL + 6)))
        local function GrpName(g)
            if IS_KO then return (g.nameKo ~= "" and g.nameKo) or g.nameEn end
            return (g.nameEn ~= "" and g.nameEn) or g.nameKo
        end
        for gi, grp in ipairs(dgGroups or {}) do
            usedHeaders = usedHeaders + 1
            local _, hex = SourceChip(grp.type, grp.nameKo, grp.nameEn)
            local rows = math.max(1, math.ceil(#grp.items / perRow))
            local rowH = rows * (GRID_CELL + 6)
            -- 행 구분선 (첫 행 제외) + 이름 라벨 (행 세로 중앙)
            local h = d.secHeaders[usedHeaders]
            if not h then
                h = { div = d:CreateTexture(nil, "ARTWORK"), fs = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") }
                h.div:SetTexture("InterfaceButtonsWHITE8X8")
                h.div:SetVertexColor(1, 1, 1, 0.08)
                h.div:SetHeight(1)
                d.secHeaders[usedHeaders] = h
            end
            if gi > 1 then
                h.div:ClearAllPoints()
                h.div:SetPoint("TOPLEFT", 10, y + 3)
                h.div:SetPoint("TOPRIGHT", -10, y + 3)
                h.div:Show()
            else
                h.div:Hide()
            end
            h.fs:ClearAllPoints()
            h.fs:SetWidth(NAME_W)
            h.fs:SetJustifyH("LEFT")
            h.fs:SetPoint("LEFT", d, "TOPLEFT", 12, y - rowH / 2)
            h.fs:SetText("|cff" .. (hex or "a1a1aa") .. (GrpName(grp) or "?") .. "|r")
            h.fs:Show()
            for j, e in ipairs(grp.items) do
                used = used + 1
                shown = shown + 1
                local b = GridButton(d, used)
                local col = (j - 1) % perRow
                local row = math.floor((j - 1) / perRow)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", ICONS_X + col * (GRID_CELL + 6), y - row * (GRID_CELL + 6))
                FillCard(b, e)
            end
            y = y - rowH - 6
        end
        y = y + 2
    else
        usedHeaders = usedHeaders + 1
        if d.tab == "craft" then
            y = SectionHeader(d, usedHeaders, y,
                string.format(L["제작 · 최고 품질 %d"], (WythicPlusCraftData and WythicPlusCraftData.ilvl) or 0), "60a5fa")
            -- 2차 스탯 선택 줄 + 안내문
            d.craftLabel:ClearAllPoints()
            d.craftLabel:SetPoint("TOPLEFT", 12, y)
            d.craftLabel:Show()
            y = y - 16
            local keys = CraftKeys(slotKey)
            local bw = (DROP_W - 24 - 3 * 4) / 4
            for i, b in ipairs(d.craftStatBtns) do
                local sel = false
                for _, v in ipairs(keys) do if v == b.statKey then sel = true end end
                local c = STAT_COLORS[b.statKey]
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 12 + (i - 1) * (bw + 4), y)
                if sel then
                    b:SetBackdropColor(c[1], c[2], c[3], 0.45)
                else
                    b:SetBackdropColor(1, 1, 1, 0.07)
                end
                b:Show()
            end
            y = y - 26
            -- 장식 선택 줄 (기본 = 메타 픽)
            d.embLabel:ClearAllPoints()
            d.embLabel:SetPoint("TOPLEFT", 12, y - 4)
            d.embLabel:Show()
            d.embBtn:ClearAllPoints()
            d.embBtn:SetPoint("TOPRIGHT", -12, y)
            d.embBtn.label:SetText(EmbName(CraftEmb(slotKey)) .. "  |cff9ca3af▾|r")
            d.embBtn:Show()
            y = y - 26
            -- 보석 줄: 홈 가능 부위(랭커 보석 데이터가 있는 부위)만. 아이템을 고르기 전엔 착용템에 홈이 있을 때만 선택 가능
            -- (홈 가정은 직접 고른 아이템에만 적용 — 홈 없는 착용템에 보석이 계산되지 않게)
            local gemList = panel.effSpec and panel.effSpec.gems and panel.effSpec.gems[slotKey]
            if gemList and #gemList > 0 then
                local c2 = panel.cells and panel.cells[slotKey]
                local wl3 = c2 and c2.inv and GetInventoryItemLink("player", c2.inv)
                local sockets = wl3 and WythicPlus_GearSocketCount and WythicPlus_GearSocketCount(wl3) or 0
                local canGem = panel.pinnedItems[slotKey] ~= nil or (sockets or 0) > 0
                local gp = panel.pinnedGems[slotKey]
                local gtxt
                if not canGem then
                    gtxt = "|cff6b7280" .. L["아이템을 먼저 고르세요"] .. "|r"
                elseif gp == 0 then
                    gtxt = L["보석 해제"]
                elseif gp then
                    EnsureItem(gp)
                    gtxt = C_Item.GetItemNameByID(gp) or (L["보석"] .. " " .. gp)
                else
                    gtxt = L["자동 (추천 보석)"]
                end
                d.gemRowLabel:ClearAllPoints()
                d.gemRowLabel:SetPoint("TOPLEFT", 12, y - 4)
                d.gemRowLabel:Show()
                d.gemRowBtn:ClearAllPoints()
                d.gemRowBtn:SetPoint("TOPRIGHT", -12, y)
                d.gemRowBtn.disabled = not canGem
                d.gemRowBtn:SetAlpha(canGem and 1 or 0.6)
                d.gemRowBtn.label:SetText(gtxt .. (canGem and "  |cff9ca3af▾|r" or ""))
                d.gemRowBtn:Show()
                y = y - 26
            end
            -- 마부 줄: 고른 마부 → 착용 마부(유지)
            if #EnchantsForSlot(slotKey) > 0 then
                local pe2 = EnchantByName(panel.pinnedEnchants[slotKey])
                local etxt
                if pe2 then
                    EnsureItem(pe2.item2)
                    etxt = EnchantShortName(pe2)
                else
                    local wid = WornEnchantId(slotKey)
                    local wn = wid and (WythicPlusGearData.enchantNames or {})[wid]
                    etxt = wn and (EnchantName(wn) .. L[" (유지)"]) or L["없음"]
                end
                d.enchRowLabel:ClearAllPoints()
                d.enchRowLabel:SetPoint("TOPLEFT", 12, y - 4)
                d.enchRowLabel:Show()
                d.enchRowBtn:ClearAllPoints()
                d.enchRowBtn:SetPoint("TOPRIGHT", -12, y)
                d.enchRowBtn.label:SetText(etxt .. "  |cff9ca3af▾|r")
                d.enchRowBtn:Show()
                y = y - 26
            end
            d.craftHint:ClearAllPoints()
            d.craftHint:SetPoint("TOPLEFT", 12, y)
            d.craftHint:SetWidth(DROP_W - 24)
            if d.craftEmbWarn then
                d.craftHint:SetText("|cfff59e0b" .. L["고른 장식은 이 아이템에 쓸 수 없습니다 — 다른 장식을 고르거나 메타 픽으로 두세요."] .. "|r")
            elseif d.craftWarn then
                d.craftHint:SetText("|cfff59e0b" .. L["아이템을 고르기 전에 2차 스탯을 먼저 선택하세요 (아이템에 따라 1~2개)."] .. "|r")
            else
                d.craftHint:SetText(L["선택한 스탯으로 최고 품질 제작을 가정합니다. 「고정」은 스탯을 고를 수 없는 아이템입니다."])
            end
            d.craftHint:Show()
            y = y - math.max(14, (d.craftHint:GetStringHeight() or 14)) - 8
        else
            y = SectionHeader(d, usedHeaders, y,
                d.tab == "bags" and L["내 소지품"] or L["랭커 채용 순위"], nil)
        end
        pages = math.max(1, math.ceil(#entries / GRID_PER_PAGE))
        if d.page > pages then d.page = pages end
        local first = (d.page - 1) * GRID_PER_PAGE
        for i = 1, GRID_PER_PAGE do
            local e = entries[first + i]
            local b = GridButton(d, i)
            if e then
                shown = shown + 1
                local col = (i - 1) % GRID_COLS
                local row = math.floor((i - 1) / GRID_COLS)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 12 + col * (GRID_CELL + 6), y - row * (GRID_CELL + 6))
                FillCard(b, e)
            else
                b:Hide()
            end
        end
        used = GRID_PER_PAGE
        local gridRows = shown > 0 and math.ceil(math.min(#entries - first, GRID_PER_PAGE) / GRID_COLS) or 1
        y = y - gridRows * (GRID_CELL + 6) - 2
    end
    -- 남은 풀 숨김 (탭 전환 시 잔상 방지)
    for i = used + 1, #d.grid do d.grid[i]:Hide() end
    for i = usedHeaders + 1, #d.secHeaders do
        d.secHeaders[i].div:Hide()
        d.secHeaders[i].fs:Hide()
    end

    -- 빈 목록 안내 — 레이드 탭에서 레이드 필터가 하나라도 걸려 있으면 그쪽을 먼저 안내
    if shown == 0 then
        local raidFiltered = false
        if d.tab == "raid" and panel.excludedRaids then
            for _, r in ipairs(SEASON_RAIDS) do
                if panel.excludedRaids[r.en] then
                    raidFiltered = true
                    break
                end
            end
        end
        d.pageText:SetText(d.tab == "bags" and L["가방에 착용 가능한 아이템 없음"]
            or (d.tab == "craft" and L["이 부위의 제작 아이템 없음"])
            or (raidFiltered and L["레이드 필터가 적용되어 있는지 확인해주세요"])
            or ((d.tab == "dungeon" or d.tab == "raid") and L["이 부위의 드랍이 없습니다 — 도감 로딩 중이면 잠시 후 다시 열어주세요"])
            or L["메타 데이터 없음"])
        d.pageText:ClearAllPoints()
        d.pageText:SetPoint("TOPLEFT", 14, y - 4)
        -- 긴 안내문이 박스 밖으로 나가지 않게 폭 제한 + 줄바꿈 (높이는 실제 줄 수만큼)
        d.pageText:SetWidth(DROP_W - 28)
        d.pageText:SetJustifyH("LEFT")
        y = y - math.max(22, (d.pageText:GetStringHeight() or 14) + 8)
    end

    -- 하단 바: 초기화(좌) + 추천 해제/복원 + 페이징(우)
    local pinnedHere = panel.pinnedItems[slotKey] ~= nil or panel.pinnedTracks[slotKey] ~= nil
    d.resetBtn:ClearAllPoints()
    d.resetBtn:SetPoint("TOPLEFT", 12, y)
    d.resetBtn:SetShown(pinnedHere)
    -- 추천 해제: 핀 없이 시뮬 추천이 표시 중인 슬롯(착용템 있을 때)만. 해제 상태면 복원.
    local dismissed = panel.dismissedSlots[slotKey] and true or false
    local cellHere = panel.cells and panel.cells[slotKey]
    local recShown = cellHere and cellHere.rec and cellHere.rec.itemId ~= nil
    local worn = cellHere and cellHere.inv and GetInventoryItemLink("player", cellHere.inv)
    local showDismiss = (dismissed or (recShown and worn ~= nil)) and panel.pinnedItems[slotKey] == nil
    d.dismissBtn.label:SetText(dismissed and L["|cffffb454추천 복원|r"] or L["|cffffb454추천 해제|r"])
    d.dismissBtn:ClearAllPoints()
    if pinnedHere then
        d.dismissBtn:SetPoint("LEFT", d.resetBtn, "RIGHT", 6, 0)
    else
        d.dismissBtn:SetPoint("TOPLEFT", 12, y)
    end
    d.dismissBtn:SetShown(showDismiss)
    -- 부위 잠금 버튼: 항상 표시 — 현재 선택(핀/착용)을 고정
    local lockedHere = panel.lockedSlots[slotKey] and true or false
    d.lockBtn.label:SetText("|TInterface\\PetBattles\\PetBattle-LockIcon:12|t "
        .. (lockedHere and L["|cfff59e0b잠금 해제|r"] or L["|cffcfcfcf이 부위 잠금|r"]))
    d.lockBtn:ClearAllPoints()
    if showDismiss then
        d.lockBtn:SetPoint("LEFT", d.dismissBtn, "RIGHT", 6, 0)
    elseif pinnedHere then
        d.lockBtn:SetPoint("LEFT", d.resetBtn, "RIGHT", 6, 0)
    else
        d.lockBtn:SetPoint("TOPLEFT", 12, y)
    end
    d.lockBtn:SetShown(panel.optimize == true)
    if pages > 1 then
        d.pageNext:ClearAllPoints()
        d.pageNext:SetPoint("TOPRIGHT", -12, y)
        d.pagePrev:ClearAllPoints()
        d.pagePrev:SetPoint("RIGHT", d.pageNext, "LEFT", -4, 0)
        d.pagePrev:SetShown(d.page > 1)
        d.pageNext:SetShown(d.page < pages)
        if shown > 0 then
            d.pageText:ClearAllPoints()
            d.pageText:SetPoint("RIGHT", (d.page > 1) and d.pagePrev or d.pageNext, "LEFT", -8, 0)
            d.pageText:SetWidth(0) -- 안내문용 고정폭 해제 (페이지 표기는 자동폭)
            d.pageText:SetText(d.page .. "/" .. pages)
        end
    else
        d.pagePrev:Hide()
        d.pageNext:Hide()
        if shown > 0 then d.pageText:SetText("") end
    end
    if panel.optimize or pinnedHere or showDismiss or pages > 1 then y = y - 26 end

    -- 강화 트랙 (메타 탭 전용)
    local showTrack = (d.tab == "meta" or d.tab == "dungeon" or d.tab == "raid") and shown > 0
    d.trackDivider:SetShown(showTrack)
    d.trackLabel:SetShown(showTrack)
    if showTrack then
        local activeId
        do
            local pin = panel.pinnedItems[slotKey]
            activeId = type(pin) == "table" and pin.item_id or pin or (panel.lastRecs and panel.lastRecs[slotKey])
        end
        local crafted = activeId and srcs[activeId] and srcs[activeId][1] == "crafted" or false
        local activeTrack = (d.tab == "dungeon" or d.tab == "raid") and (d.viewTrack or "Champion")
            or panel.pinnedTracks[slotKey]
        local activeIlvl = activeId and panel.curSpec and MetaItemInfo(panel.curSpec, slotKey, activeId) or nil
        if not activeTrack and activeIlvl then
            activeTrack = TrackFromIlvl(activeIlvl, crafted)
        end
        d.trackLabel:SetText(L["강화 트랙"])
        d.trackDivider:ClearAllPoints()
        d.trackDivider:SetPoint("TOPLEFT", 10, y)
        d.trackDivider:SetPoint("TOPRIGHT", -10, y)
        y = y - 8
        d.trackLabel:ClearAllPoints()
        d.trackLabel:SetPoint("TOPLEFT", 12, y)

        y = y - 18

        local visBtns = 0
        for i, b in ipairs(d.trackBtns) do
            local t = d.trackDefs[i]
            if t.key == "Peak" and d.tab == "dungeon" then
                b:Hide() -- 막넴 344는 레이드/메타 전용
            else
                visBtns = visBtns + 1
                local col = (visBtns - 1) % 2
                local rowIdx = math.floor((visBtns - 1) / 2)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 12 + col * ((DROP_W - 24 - 6) / 2 + 6), y - rowIdx * 28)
                b.active = (activeTrack == t.key)
                b:SetAlpha(1)
                -- 숫자 없이 이름만 — 실제 아이템레벨은 카드가 보여준다
                if b.active then
                    -- 선택 표시는 반투명 앰버 배경 — 텍스트는 흰색 유지 (검은 반전 금지)
                    b:SetBackdropColor(AMBER[1], AMBER[2], AMBER[3], 0.35)
                    b.label:SetText(t.ko)
                else
                    b:SetBackdropColor(1, 1, 1, 0.07)
                    b.label:SetText(t.ko)
                end
                b:Show()
            end
        end
        y = y - math.ceil(visBtns / 2) * 28
    else
        for _, b in ipairs(d.trackBtns) do b:Hide() end
    end

    d:SetSize(DROP_W, -y + 10)
end

-- 드롭다운을 클릭한 아이콘 바로 옆 바깥쪽에 펼친다 — 아래로 열면 아머리를 다 가린다.
-- 왼쪽 열은 아이콘 왼쪽(창 밖 방향), 오른쪽 열은 아이콘 오른쪽. 세로는 아이콘 상단 정렬.
local function AnchorDropdownOutside(d, anchor)
    d:ClearAllPoints()
    d:SetClampedToScreen(true)
    local ax = anchor:GetCenter()
    local px = panel:GetCenter()
    if ax and px and ax < px then
        d:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -6, 0)
    else
        d:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, 0)
    end
end

-- 슬롯의 선택 드롭다운을 창 밖 옆에 펼친다 (같은 슬롯 재클릭 = 닫기)
local function ShowItemDropdown(slotKey, anchor)
    if not (panel and panel.effSpec) then return end -- 최적화 OFF에서도 커스텀 가능
    local d = EnsureDropdown()
    if d:IsShown() and d.slotKey == slotKey and d.mode == "item" then d:Hide() return end
    d.mode = "item"
    d.slotKey = slotKey
    d.tab = "meta"
    d.page = 1
    RenderDropdown(d)
    AnchorDropdownOutside(d, anchor)
    d:Show()
end

-- ── 프리셋 — 현재 최적화 구성을 저장/복원. 슬롯별: 추천 있으면 추천템(핀 포함),
--    없으면 착용템. 마부/보석도 동일 규칙. WythicPlusDB(계정 저장)에 스펙별 보관. ──
local function PresetDB()
    -- 캐릭터별 + 전문화별 분리 (WythicPlusDB는 계정 단위 SavedVariables라 캐릭 키 필요 —
    -- 프리셋 스냅샷엔 착용/가방 링크가 들어가 다른 캐릭과 공유하면 무의미)
    WythicPlusDB.gearPresets = WythicPlusDB.gearPresets or {}
    local specID = GetSpecializationInfo(GetSpecialization() or 0)
    if not specID then return nil end
    local charKey = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    local root = WythicPlusDB.gearPresets
    root[charKey] = root[charKey] or {}
    root[charKey][specID] = root[charKey][specID] or {}
    return root[charKey][specID]
end

local function BuildPresetSnapshot()
    local slots = {}
    local enchNames = WythicPlusGearData.enchantNames or {}
    for key, cell in pairs(panel.cells) do
        local v = panel.lastView[key]
        local entry
        if v and v.itemId then
            local pin = panel.pinnedItems[key]
            if type(pin) == "table" then
                -- srcTab도 스냅샷 — 복원 시 카드 색/딱지(메타/가방/던전/레이드)가 저장 시점 그대로
                entry = { id = v.itemId, src = "bag", link = pin.link, ilvl = pin.ilvl, stats = pin.stats, srcTab = pin.srcTab }
            else
                -- 저장 시점 스탯 스냅샷 — 이후 메타 개편에도 프리셋 수치가 유지되게
                entry = { id = v.itemId, src = "meta", ilvl = v.ilvl, bonuses = v.bonuses, conv = v.conv,
                    stats = MetaItemStats(panel.effSpec, key, v.itemId, v.conv) }
            end
        else
            local id = GetInventoryItemID("player", cell.inv)
            local link = id and GetInventoryItemLink("player", cell.inv)
            if id and link then
                entry = { id = id, src = "eq", link = link,
                    ilvl = C_Item.GetDetailedItemLevelInfo(link) or 0,
                    stats = WythicPlus_GearLinkStats and WythicPlus_GearLinkStats(link) or {} }
            end
        end
        if entry then
            entry.enchPin = panel.pinnedEnchants[key] -- 유저가 고른 마법부여 (복원 시 다시 핀)
            -- 마부/보석: 추천이 있으면 추천, 없으면 착용 중인 것
            if v then
                entry.ench, entry.enchItemId, entry.gemId, entry.gemNone = v.ench, v.enchItemId, v.gemId, v.gemNone
            end
            local link = GetInventoryItemLink("player", cell.inv)
            if link then
                if not entry.ench then
                    local eid = tonumber(link:match("item:%d+:(%d+)") or "")
                    local en = eid and enchNames[eid]
                    if en then entry.ench, entry.enchItemId = EnchantName(en), en[3] end
                end
                if not entry.gemId and not entry.gemNone and WythicPlus_GearLinkGems then
                    entry.gemId = WythicPlus_GearLinkGems(link)[1]
                end
            end
            slots[key] = entry
        end
    end
    return slots
end

local function SavePreset(name)
    local db = PresetDB()
    if not db then return end
    if #db >= 10 then table.remove(db, 1) end -- 스펙당 최대 10개 (오래된 것부터 밀림)
    local sim = panel.lastSim
    -- 저장 시점 레이팅 동결 — 적용 시 시뮬 재실행(보석 추천 편차)과 무관하게 점수 일치 보장
    local ratings
    if sim and sim.statRatios then
        ratings = {}
        for _, r in ipairs(sim.statRatios) do
            ratings[r.stat] = { sim = r.simRating, gear = r.gearOnlyRating }
        end
    end
    db[#db + 1] = {
        name = (name and name ~= "") and name or (L["프리셋 "] .. (#db + 1)),
        at = date("%m/%d %H:%M"),
        score = sim and { o = sim.originalDistance, f = sim.finalDistance } or nil,
        ratings = ratings,
        slots = BuildPresetSnapshot(),
    }
end

StaticPopupDialogs["WYTHICPLUS_GEAR_PRESET"] = {
    text = L["프리셋 이름을 입력하세요"],
    button1 = L["저장"], button2 = L["취소"],
    hasEditBox = true, maxLetters = 24,
    OnAccept = function(self)
        local eb = self.editBox or (self.GetEditBox and self:GetEditBox())
        SavePreset(eb and eb:GetText() or "")
        if panel and panel.RefreshPresets then panel.RefreshPresets() end
    end,
    EditBoxOnEnterPressed = function(self)
        SavePreset(self:GetText())
        if panel and panel.RefreshPresets then panel.RefreshPresets() end
        self:GetParent():Hide()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- 프리셋을 핀으로 복원 — 저장 시점 스탯/링크 기반 균일 테이블 핀이라
-- 이후 장비를 갈아입었거나 메타가 바뀌어도 그대로 재현된다.
local function ApplyPreset(p)
    panel.optimize = true
    wipe(panel.pinnedItems)
    wipe(panel.pinnedConv)
    wipe(panel.pinnedGems)
    wipe(panel.pinnedEnchants)
    wipe(panel.dismissedSlots)
    wipe(panel.pinnedTracks)
    wipe(panel.lockedSlots) -- 프리셋 = 전체 구성 교체이므로 잠금도 해제
    for slot, e in pairs(p.slots or {}) do
        panel.pinnedItems[slot] = { item_id = e.id, stats = e.stats or {}, link = e.link, ilvl = e.ilvl or 0, srcTab = e.srcTab }
        -- 메타 핀은 변형(변환 원본 conv)도 복원 — 같은 itemId의 일반/변환 티어를 구분 (툴팁 병기·순위 라벨)
        if e.src == "meta" and e.conv then panel.pinnedConv[slot] = e.conv end
        -- 보석도 핀으로 복원 — 저장만 되고 복원이 빠져 있었음 (2026-09-06)
        if e.enchPin then panel.pinnedEnchants[slot] = e.enchPin end
        if e.gemId then panel.pinnedGems[slot] = e.gemId
        elseif e.gemNone then panel.pinnedGems[slot] = 0 end -- 보석 해제(빈 홈) 핀
    end
    panel.presetRatings = p.ratings -- 저장 시점 레이팅으로 표시 동결 (목록 점수와 일치)
    if panel.Redraw then panel.Redraw(true) end
end

local RenderPresets -- 전방 선언

local function EnsurePresetFrame()
    if panel.presetFrame then return panel.presetFrame end
    local f = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.06, 0.09, 0.98)
    f:SetBackdropBorderColor(AMBER[1], AMBER[2], AMBER[3], 0.5)
    f:EnableMouse(true)
    f:SetWidth(280)
    f.rows = {}

    -- 상단: 현재 구성 저장
    f.saveBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    f.saveBtn:SetSize(256, 24)
    f.saveBtn:SetPoint("TOP", 0, -8)
    f.saveBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    f.saveBtn:SetBackdropColor(AMBER[1], AMBER[2], AMBER[3], 0.12)
    f.saveBtn.label = f.saveBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.saveBtn.label:SetPoint("CENTER")
    f.saveBtn.label:SetText(L["|cffffb454＋ 현재 구성 저장|r"])
    f.saveBtn:SetScript("OnClick", function()
        if not f.saveBtn.enabledSave then return end
        StaticPopup_Show("WYTHICPLUS_GEAR_PRESET")
    end)

    panel.RefreshPresets = function()
        if f:IsShown() then RenderPresets(f) end
    end
    f:Hide()
    panel.presetFrame = f
    return f
end

local function PresetRow(f, i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f)
    r:SetHeight(24)
    r:SetPoint("LEFT", 12, 0)
    r:SetPoint("RIGHT", -34, 0)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    hl:SetVertexColor(1, 1, 1, 0.08)
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.label:SetPoint("LEFT", 2, 0)
    r.label:SetPoint("RIGHT", -2, 0)
    r.label:SetJustifyH("LEFT")
    r.label:SetWordWrap(false)
    r:SetScript("OnClick", function(self)
        if self.preset then
            ApplyPreset(self.preset)
            f:Hide()
        end
    end)
    -- 삭제 X
    r.del = CreateFrame("Button", nil, f)
    r.del:SetSize(20, 20)
    r.del:SetPoint("LEFT", r, "RIGHT", 4, 0)
    r.del.label = r.del:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.del.label:SetPoint("CENTER")
    r.del.label:SetText("|cfff87171×|r")
    r.del:SetScript("OnClick", function(self)
        local db = PresetDB()
        if db and self.idx then
            table.remove(db, self.idx)
            RenderPresets(f)
        end
    end)
    f.rows[i] = r
    return r
end

RenderPresets = function(f)
    -- 저장 가능 조건: 최적화/커스텀으로 뭔가 바뀐 상태 (착용 그대로면 저장 의미 없음)
    local canSave = (panel.lastSim ~= nil)
        or next(panel.pinnedItems) ~= nil or next(panel.pinnedGems) ~= nil or next(panel.pinnedEnchants) ~= nil
        or next(panel.pinnedTracks) ~= nil
    f.saveBtn.enabledSave = canSave
    f.saveBtn:SetAlpha(canSave and 1 or 0.4)
    f.saveBtn.label:SetText(canSave and L["|cffffb454＋ 현재 구성 저장|r"]
        or L["|cff777777최적화·커스텀 후 저장할 수 있습니다|r"])

    local db = PresetDB() or {}
    local y = -38 -- 저장 버튼 아래
    local n = 0
    for i = #db, 1, -1 do -- 최신이 위
        n = n + 1
        local r = PresetRow(f, n)
        local p = db[i]
        local score = p.score and string.format("  |cffffb454%.1f→%.1f|r", 100 - p.score.o, 100 - p.score.f) or ""
        r.label:SetText(p.name .. " |cff888888" .. (p.at or "") .. "|r" .. score)
        r.preset = p
        r.del.idx = i
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 12, y)
        r:SetPoint("RIGHT", f, "RIGHT", -34, 0)
        r.del:ClearAllPoints()
        r.del:SetPoint("TOP", f, "TOP", 0, y - 2)
        r.del:SetPoint("RIGHT", -8, 0)
        r:Show()
        r.del:Show()
        y = y - 26
    end
    for i = n + 1, #f.rows do
        f.rows[i]:Hide()
        f.rows[i].del:Hide()
    end
    if n == 0 then
        f.emptyText = f.emptyText or f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        f.emptyText:ClearAllPoints()
        f.emptyText:SetPoint("TOP", 0, y - 4)
        f.emptyText:SetText(L["저장된 프리셋 없음"])
        f.emptyText:Show()
        y = y - 24
    elseif f.emptyText then
        f.emptyText:Hide()
    end
    f:SetHeight(-y + 10)
end

local function TogglePresetFrame(anchor)
    local f = EnsurePresetFrame()
    if f:IsShown() then f:Hide() return end
    RenderPresets(f)
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    f:Show()
end

-- 보석 선택 드롭다운 — 아이템 드롭다운 프레임 재사용 (gem 모드)
ShowGemDropdown = function(slotKey, anchorFrame)
    if not (panel and panel.effSpec) then return end
    local d = EnsureDropdown()
    d.fromCraft = nil
    if d:IsShown() and d.slotKey == slotKey and d.mode == "gem" then d:Hide() return end
    d.mode = "gem"
    d.slotKey = slotKey
    d.page = 1
    RenderDropdown(d)
    AnchorDropdownOutside(d, anchorFrame)
    d:Show()
end

-- 마법부여 선택 드롭다운 — 아이템 드롭다운 프레임 재사용 (ench 모드). 카드의 마부 줄 클릭으로 연다
ShowEnchantDropdown = function(slotKey, anchorFrame)
    if not (panel and panel.effSpec) then return end
    local d = EnsureDropdown()
    d.fromCraft = nil
    if d:IsShown() and d.slotKey == slotKey and d.mode == "ench" then d:Hide() return end
    d.mode = "ench"
    d.slotKey = slotKey
    d.page = 1
    RenderDropdown(d)
    AnchorDropdownOutside(d, anchorFrame)
    d:Show()
end

local function CreateSlotCell(parent, slot, side)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetSize(COL_W, ROW_H)
    cell.inv = slot.inv
    cell.slotKey = slot.key
    local isLeft = (side == "LEFT")
    cell.isLeft = isLeft

    -- 컨텐츠(아이콘+이름) 묶음 — 최적화 토글 시 모델 쪽으로 슬라이드
    local content = CreateFrame("Frame", nil, cell)
    content:SetSize(ICON + 8 + NAME_W, ROW_H)
    content:SetPoint(isLeft and "RIGHT" or "LEFT", cell, isLeft and "RIGHT" or "LEFT", isLeft and -SLIDE_OUT or SLIDE_OUT, 0)
    cell.content = content

    -- 아이콘 (컨텐츠 바깥쪽 끝 — 이름이 안쪽/모델 쪽)
    cell.icon = content:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(ICON, ICON)
    if isLeft then
        cell.icon:SetPoint("RIGHT", content, "RIGHT", -(NAME_W + 8), 0)
    else
        cell.icon:SetPoint("LEFT", content, "LEFT", NAME_W + 8, 0)
    end
    cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    cell.iconBg = content:CreateTexture(nil, "BACKGROUND")
    cell.iconBg:SetPoint("TOPLEFT", cell.icon, -1, 1)
    cell.iconBg:SetPoint("BOTTOMRIGHT", cell.icon, 1, -1)
    cell.iconBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    cell.iconBg:SetVertexColor(0, 0, 0, 1)

    -- 매칭 체크 (아이콘 안쪽 모서리, 웹 checkBadge)
    cell.check = content:CreateTexture(nil, "OVERLAY")
    cell.check:SetSize(16, 16)
    cell.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    cell.check:SetPoint(isLeft and "TOPRIGHT" or "TOPLEFT", cell.icon, isLeft and "TOPRIGHT" or "TOPLEFT", isLeft and 5 or -5, 5)
    cell.check:Hide()
    -- 부위 잠금 배지 (Shift+클릭 토글 — 잠긴 부위는 최적화 제외)
    cell.lock = content:CreateTexture(nil, "OVERLAY")
    cell.lock:SetSize(15, 15)
    cell.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    cell.lock:SetPoint(isLeft and "BOTTOMRIGHT" or "BOTTOMLEFT", cell.icon, isLeft and "BOTTOMRIGHT" or "BOTTOMLEFT", isLeft and 5 or -5, -4)
    cell.lock:Hide()

    -- 이름 + ilvl (안쪽 = 모델 쪽, 아이콘에 붙여 정렬)
    cell.name = BumpFont(content:CreateFontString(nil, "ARTWORK", "GameFontNormal"))
    cell.name:SetSize(NAME_W - 6, 15)
    cell.name:SetPoint(isLeft and "TOPLEFT" or "TOPRIGHT", cell.icon, isLeft and "TOPRIGHT" or "TOPLEFT", isLeft and 8 or -8, -4)
    cell.name:SetJustifyH(isLeft and "LEFT" or "RIGHT")
    cell.name:SetWordWrap(false)

    cell.ilvl = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    cell.ilvl:SetSize(NAME_W - 6, 12)
    cell.ilvl:SetPoint("TOP", cell.name, "BOTTOM", 0, -2)
    cell.ilvl:SetJustifyH(isLeft and "LEFT" or "RIGHT")

    -- 추천 (바깥쪽)
    local rec = CreateFrame("Frame", nil, cell)
    rec:SetSize(REC_W + SLIDE_IN_EXTRA + 12, ROW_H) -- 컨텐츠가 비운 안쪽까지 사용
    rec:SetPoint(isLeft and "LEFT" or "RIGHT", 0, 0)
    rec:Hide()
    cell.rec = rec

    -- amber 화살표 (슬롯 아이콘을 가리킴 — 안쪽 방향)
    rec.arrow = rec:CreateTexture(nil, "ARTWORK")
    StyleRecArrow(rec.arrow, isLeft) -- 좌측 컬럼 추천은 오른쪽(슬롯)을 가리킴
    -- 착용 라인이 최적화 때 안쪽으로 슬라이드해 오므로, 화살표는 안쪽 끝에서 이격
    rec.arrow:SetPoint(isLeft and "RIGHT" or "LEFT", rec, isLeft and "RIGHT" or "LEFT", isLeft and -16 or 16, 0)

    -- 추천 아이콘 40px + amber 2px 테두리
    rec.iconBorder = rec:CreateTexture(nil, "BACKGROUND")
    rec.iconBorder:SetSize(ICON + 4, ICON + 4)
    rec.iconBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    rec.iconBorder:SetVertexColor(AMBER[1], AMBER[2], AMBER[3], 1)
    rec.iconBorder:SetPoint(isLeft and "RIGHT" or "LEFT", rec.arrow, isLeft and "LEFT" or "RIGHT", isLeft and -4 or 4, 0)

    rec.icon = rec:CreateTexture(nil, "ARTWORK")
    rec.icon:SetSize(ICON, ICON)
    rec.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    rec.icon:SetPoint("CENTER", rec.iconBorder, "CENTER")

    -- "메타N위" 코너 배지 (amber 배경 + 검정 글자)
    AttachRecBadge(rec, rec.iconBorder)

    -- 추천 이름 (amber)
    rec.name = BumpFont(rec:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"))
    rec.name:SetSize(155, 15) -- 이름 한 줄 (아랫줄 = ilvl + 출처 뱃지)
    rec.name:SetPoint(isLeft and "RIGHT" or "LEFT", rec.iconBorder, isLeft and "LEFT" or "RIGHT", isLeft and -6 or 6, 8)
    rec.name:SetJustifyH(isLeft and "RIGHT" or "LEFT")
    rec.name:SetTextColor(0.98, 0.75, 0.14) -- amber-400
    rec.name:SetWordWrap(false)

    -- 잠금 배지 (선택 카드용) — 선택을 잠갔을 땐 착용 아이콘이 아니라 이 카드에 표시
    rec.lock = rec:CreateTexture(nil, "OVERLAY")
    rec.lock:SetSize(15, 15)
    rec.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    rec.lock:SetVertexColor(0.96, 0.62, 0.04)
    rec.lock:SetPoint(isLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", rec.iconBorder, isLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", isLeft and -5 or 5, -4)
    rec.lock:Hide()

    -- 호버/클릭은 컨텐츠(아이콘+이름) 영역만 — 행의 빈 공간(허공)은 패널로 전달돼 드롭다운을 닫는다
    content:EnableMouse(true)
    content:SetScript("OnEnter", function()
        if GetInventoryItemLink("player", cell.inv) then
            OwnTooltip(nil, content or zone)
            GameTooltip:SetInventoryItem("player", cell.inv)
            if panel.optimize then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(panel.lockedSlots[slot.key]
                and L["|cffffb454Shift+클릭: 부위 잠금 해제|r"]
                or L["|cff888888Shift+클릭: 착용템 잠금 (최적화에서 제외)|r"], 1, 1, 1)
            end
            FinishTooltip()
        end
    end)
    content:SetScript("OnLeave", GameTooltip_Hide)
    content:SetScript("OnMouseDown", function(_, btn)
        -- Shift+좌클릭 = 부위 잠금 토글 (잠긴 부위는 메타/소지품 최적화 대상에서 제외)
        if btn == "LeftButton" and IsShiftKeyDown() and panel.optimize then
            -- 착용 아이콘 잠금 = "착용템 그대로" 고정 — 핀이 있어도 걷어내고 착용템을 잠근다
            -- (추천/선택 카드를 잠그면 그 카드의 아이템이 잠긴다 — 제스처별 대상 분리)
            local k = slot.key
            local turningOn = not panel.lockedSlots[k]
            if turningOn then
                panel.pinnedItems[k] = nil
                panel.pinnedConv[k] = nil
                panel.pinnedGems[k] = nil
                panel.pinnedEnchants[k] = nil
                panel.pinnedTracks[k] = nil
                panel.dismissedSlots[k] = nil
            end
            panel.lockedSlots[k] = turningOn or nil
            if panel.Redraw then panel.Redraw() end
            return
        end
        -- 클릭 = 아이템 드롭다운 (보석은 보석 줄 클릭으로만 — 우클릭 진입 제거)
        if btn == "RightButton" then return end
        ShowItemDropdown(slot.key, cell.icon or cell)
    end)
    rec:EnableMouse(true)
    rec:SetScript("OnEnter", function(self)
        if self.itemId then
            OwnTooltip(nil, self)
            -- 가방 핀이면 실제 소지 아이템 링크 그대로
            if self.recLink then
                GameTooltip:SetHyperlink(WithCurrentSpec(self.recLink))
                -- 제작 탭 핀: 2차 스탯 줄을 지정 스탯 수치로
                if self.recCraftStats then CraftFixTooltip(self.recCraftStats) end
                -- 마나용제 변환 가정: 어떤 소지/착용 아이템을 변환한 모습인지 명시
                if self.recConvFrom then
                    local _, charges, cname = WythicPlus_GearCatalystInfo and WythicPlus_GearCatalystInfo()
                    local src = C_Item.GetItemNameByID(self.recConvFrom) or (L["아이템 "] .. self.recConvFrom)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff00ccffWythic+|r " .. L["마나용제로 변환: "] .. "|cffffffff" .. src .. "|r"
                        .. (self.recConvWorn and L[" (착용 중)"] or L[" (가방)"]), 0.8, 0.8, 0.8)
                    if cname and charges then
                        GameTooltip:AddLine(string.format(L["보유 %s: %d개"], cname, charges), 0.6, 0.6, 0.6)
                    end
                end
                FinishTooltip()
                return
            end
            -- 랭커 착용 보너스ID 링크로 실제 제작/강화 상태 툴팁을 띄운다 (실패 시 base 폴백)
            -- 트랙 핀이면 트랙 단계 ID를 교체해 선택 트랙 ilvl로 렌더 (제작템은 트랙 개념 없음 → 제외)
            local shown = false
            local bonuses = self.recBonuses
            if self.recTrackPinned and not self.recCrafted then
                bonuses = RelinkTrackBonuses(bonuses, self.recIlvl)
            end
            local gSpec = panel.effSpec or panel.curSpec
            if bonuses and bonuses ~= "" then
                -- 변환 티어: 원본 아이템 modifier(64)를 붙여 게임이 원본 2차 배분·착효로 그리게 한다
                local srcItem = ConvertedSourceItem(gSpec, self.slotKey, self.itemId, self.recConv)
                shown = pcall(GameTooltip.SetHyperlink, GameTooltip, BuildItemLink(self.itemId, bonuses, srcItem))
            end
            if not shown then
                GameTooltip:SetItemByID(self.itemId)
            end
            -- 링크(수집 트랙) 툴팁과 별개로: 트랙 핀 시 선택 트랙 ilvl 병기, 링크 실패 시 수집 ilvl 병기
            if self.recIlvl and self.recIlvl > 0 and (not shown or self.recTrackPinned) then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff00ccffWythic+|r " .. (self.recTrackPinned and L["선택 트랙"] or L["랭커 수집"])
                    .. L[" 기준 아이템 레벨 |cffffffff"] .. self.recIlvl .. "|r", 0.8, 0.8, 0.8)
            end
            -- 게임이 그린 2차 스탯 줄이 수집 배분과 다르면(변환 티어·무작위 능력치·제작) 수집 배분으로 고쳐 쓴다
            if shown then
                FixTooltipSecondaryStats(gSpec, self.slotKey, self.itemId, self.recConv)
            end
            FinishTooltip()
        end
    end)
    rec:SetScript("OnLeave", GameTooltip_Hide)
    -- 클릭 = 메타 후보 드롭다운 (커스텀 핀) — 추천 아이콘·착용 아이콘 모두 (웹과 동일)
    rec.slotKey = slot.key
    rec:SetScript("OnMouseDown", function(self, btn)
        -- 아이템 카드가 표시 중일 때만 — 빈 카드 영역(허공) 클릭은 열린 드롭다운을 닫는다
        if not self.itemId then
            if panel.dropdown and panel.dropdown:IsShown() then panel.dropdown:Hide() end
            if panel.presetFrame and panel.presetFrame:IsShown() then panel.presetFrame:Hide() end
            return
        end
        -- Shift+클릭 = 이 카드의 아이템을 부위 잠금으로 고정 토글.
        -- 핀이 없는 자동 추천 카드라면 그 추천을 핀으로 승격해 "이 아이템"이 잠기게 한다
        -- (안 그러면 착용템이 잠겨서 추천이 사라지는 오동작 — 2026-09-07 제보)
        if btn == "LeftButton" and IsShiftKeyDown() and panel.optimize then
            local k = slot.key
            local turningOn = not panel.lockedSlots[k]
            if turningOn and panel.pinnedItems[k] == nil and self.itemId then
                if self.recLink then
                    panel.pinnedItems[k] = RecToPin(self)
                else
                    panel.pinnedItems[k] = self.itemId
                    panel.pinnedConv[k] = self.recConv or ""
                end
            end
            panel.lockedSlots[k] = turningOn or nil
            if panel.lockedSlots[k] then panel.dismissedSlots[k] = nil end
            if panel.Redraw then panel.Redraw() end
            return
        end
        ShowItemDropdown(slot.key, rec.icon or rec)
    end)
    AttachRecAnim(rec)
    AttachRecSub(rec, isLeft)
    AttachSrcBadge(rec, isLeft)

    return cell
end

local function FillSlotCell(cell, diagSlot, recInfo, animate)
    local equippedId = GetInventoryItemID("player", cell.inv)
    if equippedId then
        EnsureItem(equippedId)
        cell.icon:SetTexture(GetInventoryItemTexture("player", cell.inv) or 134400)
        cell.icon:SetDesaturated(false)
        local link = GetInventoryItemLink("player", cell.inv)
        local name = link and link:match("%[(.-)%]") or C_Item.GetItemNameByID(equippedId) or "..."
        local quality = link and C_Item.GetItemQualityByID(link) or 1
        local qc = ITEM_QUALITY_COLORS[quality] or ITEM_QUALITY_COLORS[1]
        cell.name:SetText(qc.hex .. name .. "|r")
        cell.iconBg:SetVertexColor(qc.r, qc.g, qc.b, 1) -- 아이콘 테두리 = 품질색
        local ilvl = link and C_Item.GetDetailedItemLevelInfo(link)
        cell.ilvl:SetText(ilvl and tostring(ilvl) or "")
    else
        -- 빈 슬롯: 물음표 대신 은은한 빈 칸
        cell.icon:SetTexture("Interface\\Buttons\\WHITE8X8")
        cell.icon:SetDesaturated(false)
        cell.icon:SetVertexColor(1, 1, 1, 0.05)
        cell.iconBg:SetVertexColor(0, 0, 0, 1)
        cell.name:SetText(L["|cff666666미착용|r"])
        cell.ilvl:SetText("")
    end
    if equippedId then cell.icon:SetVertexColor(1, 1, 1, 1) end

    cell.check:SetShown(diagSlot ~= nil and diagSlot.matched == true)
    -- 착용템과 동일 아이템이면 추천 숨김 — 단 표시 ilvl이 착용보다 높으면(핀+트랙 업 등), 또는 가방의 다른 실물
    -- (같은 ID인데 2차 배분·ilvl이 다른 사본, 링크가 착용템과 다름)이면 유지(2026-09-20)
    if recInfo and recInfo.itemId == equippedId then
        local wl3 = GetInventoryItemLink("player", cell.inv)
        local wornIl = wl3 and C_Item.GetDetailedItemLevelInfo(wl3) or 0
        local otherCopy = recInfo.bagLink ~= nil and recInfo.bagLink ~= wl3
        if not otherCopy and (not recInfo.ilvl or recInfo.ilvl <= wornIl) then recInfo.itemId = nil end
    end
    if recInfo and recInfo.itemId then EnsureItem(recInfo.itemId) end
    SetRec(cell.rec, recInfo, animate)
end

-- 무기 셀 (하단 중앙: 아이콘+체크, 이름 아래, 추천은 바깥 좌/우)
local function CreateBottomCell(parent, slot, side)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetSize(REC_W + 6 + 52, 76)
    cell.inv = slot.inv
    cell.slotKey = slot.key
    local isLeft = (side == "LEFT") -- MAIN_HAND: 추천 왼쪽 / OFF_HAND: 추천 오른쪽

    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(52, 52)
    if isLeft then
        cell.icon:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 0, 0)
    else
        cell.icon:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, 0)
    end
    cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    cell.iconBg = cell:CreateTexture(nil, "BACKGROUND")
    cell.iconBg:SetPoint("TOPLEFT", cell.icon, -1, 1)
    cell.iconBg:SetPoint("BOTTOMRIGHT", cell.icon, 1, -1)
    cell.iconBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    cell.iconBg:SetVertexColor(0, 0, 0, 1)

    cell.check = cell:CreateTexture(nil, "OVERLAY")
    cell.check:SetSize(16, 16)
    cell.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    cell.check:SetPoint(isLeft and "TOPLEFT" or "TOPRIGHT", cell.icon, isLeft and "TOPLEFT" or "TOPRIGHT", isLeft and -5 or 5, 5)
    cell.check:Hide()
    -- 부위 잠금 배지 (Shift+클릭 토글)
    cell.lock = cell:CreateTexture(nil, "OVERLAY")
    cell.lock:SetSize(15, 15)
    cell.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    cell.lock:SetPoint(isLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", cell.icon, isLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", isLeft and -5 or 5, -4)
    cell.lock:Hide()

    -- 이름/ilvl: 주무기(좌측 셀)는 우측정렬, 보조무기(우측 셀)는 좌측정렬 — 중앙에서 서로 겹침 방지
    cell.name = cell:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cell.name:SetSize(150, 14)
    cell.name:SetPoint(isLeft and "TOPRIGHT" or "TOPLEFT", cell.icon, isLeft and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -3)
    cell.name:SetJustifyH(isLeft and "RIGHT" or "LEFT")
    cell.name:SetWordWrap(false)

    cell.ilvl = cell:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    cell.ilvl:SetPoint(isLeft and "TOPRIGHT" or "TOPLEFT", cell.name, isLeft and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -1)
    cell.ilvl:SetJustifyH(isLeft and "RIGHT" or "LEFT")

    local rec = CreateFrame("Frame", nil, cell)
    rec:SetSize(REC_W + SLIDE_IN_EXTRA + 12, 52)
    rec:SetPoint(isLeft and "TOPRIGHT" or "TOPLEFT", cell.icon, isLeft and "TOPLEFT" or "TOPRIGHT", isLeft and -6 or 6, 0)
    rec:Hide()
    cell.rec = rec

    rec.arrow = rec:CreateTexture(nil, "ARTWORK")
    StyleRecArrow(rec.arrow, isLeft) -- 좌측 컬럼 추천은 오른쪽(슬롯)을 가리킴
    -- 착용 라인이 최적화 때 안쪽으로 슬라이드해 오므로, 화살표는 안쪽 끝에서 이격
    rec.arrow:SetPoint(isLeft and "RIGHT" or "LEFT", rec, isLeft and "RIGHT" or "LEFT", isLeft and -16 or 16, 0)

    rec.iconBorder = rec:CreateTexture(nil, "BACKGROUND")
    rec.iconBorder:SetSize(ICON + 4, ICON + 4)
    rec.iconBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    rec.iconBorder:SetVertexColor(AMBER[1], AMBER[2], AMBER[3], 1)
    rec.iconBorder:SetPoint(isLeft and "RIGHT" or "LEFT", rec.arrow, isLeft and "LEFT" or "RIGHT", isLeft and -4 or 4, 0)

    rec.icon = rec:CreateTexture(nil, "ARTWORK")
    rec.icon:SetSize(ICON, ICON)
    rec.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    rec.icon:SetPoint("CENTER", rec.iconBorder, "CENTER")

    AttachRecBadge(rec, rec.iconBorder)

    rec.name = BumpFont(rec:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"))
    rec.name:SetSize(155, 15) -- 이름 한 줄 (아랫줄 = ilvl + 출처 뱃지)
    rec.name:SetPoint(isLeft and "RIGHT" or "LEFT", rec.iconBorder, isLeft and "LEFT" or "RIGHT", isLeft and -6 or 6, 8)
    rec.name:SetJustifyH(isLeft and "RIGHT" or "LEFT")
    rec.name:SetTextColor(0.98, 0.75, 0.14)
    rec.name:SetWordWrap(false)

    -- 잠금 배지 (선택 카드용) — 선택을 잠갔을 땐 착용 아이콘이 아니라 이 카드에 표시
    rec.lock = rec:CreateTexture(nil, "OVERLAY")
    rec.lock:SetSize(15, 15)
    rec.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    rec.lock:SetVertexColor(0.96, 0.62, 0.04)
    rec.lock:SetPoint(isLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", rec.iconBorder, isLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", isLeft and -5 or 5, -4)
    rec.lock:Hide()

    -- 호버/클릭은 아이콘+이름 존만 — 빈 공간 클릭은 패널로 전달돼 드롭다운을 닫는다
    local zone = CreateFrame("Frame", nil, cell)
    zone:SetPoint("TOPLEFT", cell.icon, "TOPLEFT", -2, 2)
    zone:SetPoint("BOTTOMRIGHT", cell.icon, "BOTTOMRIGHT", 2, -24) -- 아이콘 + 아래 이름/ilvl 줄
    zone:EnableMouse(true)
    zone:SetScript("OnEnter", function()
        if GetInventoryItemLink("player", cell.inv) then
            OwnTooltip(nil, content or zone)
            GameTooltip:SetInventoryItem("player", cell.inv)
            if panel.optimize then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(panel.lockedSlots[slot.key]
                and L["|cffffb454Shift+클릭: 부위 잠금 해제|r"]
                or L["|cff888888Shift+클릭: 착용템 잠금 (최적화에서 제외)|r"], 1, 1, 1)
            end
            FinishTooltip()
        end
    end)
    zone:SetScript("OnLeave", GameTooltip_Hide)
    zone:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" and IsShiftKeyDown() and panel.optimize then
            -- 착용 아이콘 잠금 = "착용템 그대로" 고정 — 핀이 있어도 걷어내고 착용템을 잠근다
            -- (추천/선택 카드를 잠그면 그 카드의 아이템이 잠긴다 — 제스처별 대상 분리)
            local k = slot.key
            local turningOn = not panel.lockedSlots[k]
            if turningOn then
                panel.pinnedItems[k] = nil
                panel.pinnedConv[k] = nil
                panel.pinnedGems[k] = nil
                panel.pinnedEnchants[k] = nil
                panel.pinnedTracks[k] = nil
                panel.dismissedSlots[k] = nil
            end
            panel.lockedSlots[k] = turningOn or nil
            if panel.Redraw then panel.Redraw() end
            return
        end
        -- 클릭 = 아이템 드롭다운 (보석은 보석 줄 클릭으로만 — 우클릭 진입 제거)
        if btn == "RightButton" then return end
        ShowItemDropdown(slot.key, cell.icon or cell)
    end)
    rec:EnableMouse(true)
    rec:SetScript("OnEnter", function(self)
        if self.itemId then
            OwnTooltip(nil, self)
            -- 가방 핀이면 실제 소지 아이템 링크 그대로
            if self.recLink then
                GameTooltip:SetHyperlink(WithCurrentSpec(self.recLink))
                -- 제작 탭 핀: 2차 스탯 줄을 지정 스탯 수치로
                if self.recCraftStats then CraftFixTooltip(self.recCraftStats) end
                -- 마나용제 변환 가정: 어떤 소지/착용 아이템을 변환한 모습인지 명시
                if self.recConvFrom then
                    local _, charges, cname = WythicPlus_GearCatalystInfo and WythicPlus_GearCatalystInfo()
                    local src = C_Item.GetItemNameByID(self.recConvFrom) or (L["아이템 "] .. self.recConvFrom)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff00ccffWythic+|r " .. L["마나용제로 변환: "] .. "|cffffffff" .. src .. "|r"
                        .. (self.recConvWorn and L[" (착용 중)"] or L[" (가방)"]), 0.8, 0.8, 0.8)
                    if cname and charges then
                        GameTooltip:AddLine(string.format(L["보유 %s: %d개"], cname, charges), 0.6, 0.6, 0.6)
                    end
                end
                FinishTooltip()
                return
            end
            -- 랭커 착용 보너스ID 링크로 실제 제작/강화 상태 툴팁을 띄운다 (실패 시 base 폴백)
            -- 트랙 핀이면 트랙 단계 ID를 교체해 선택 트랙 ilvl로 렌더 (제작템은 트랙 개념 없음 → 제외)
            local shown = false
            local bonuses = self.recBonuses
            if self.recTrackPinned and not self.recCrafted then
                bonuses = RelinkTrackBonuses(bonuses, self.recIlvl)
            end
            local gSpec = panel.effSpec or panel.curSpec
            if bonuses and bonuses ~= "" then
                -- 변환 티어: 원본 아이템 modifier(64)를 붙여 게임이 원본 2차 배분·착효로 그리게 한다
                local srcItem = ConvertedSourceItem(gSpec, self.slotKey, self.itemId, self.recConv)
                shown = pcall(GameTooltip.SetHyperlink, GameTooltip, BuildItemLink(self.itemId, bonuses, srcItem))
            end
            if not shown then
                GameTooltip:SetItemByID(self.itemId)
            end
            -- 링크(수집 트랙) 툴팁과 별개로: 트랙 핀 시 선택 트랙 ilvl 병기, 링크 실패 시 수집 ilvl 병기
            if self.recIlvl and self.recIlvl > 0 and (not shown or self.recTrackPinned) then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff00ccffWythic+|r " .. (self.recTrackPinned and L["선택 트랙"] or L["랭커 수집"])
                    .. L[" 기준 아이템 레벨 |cffffffff"] .. self.recIlvl .. "|r", 0.8, 0.8, 0.8)
            end
            -- 게임이 그린 2차 스탯 줄이 수집 배분과 다르면(변환 티어·무작위 능력치·제작) 수집 배분으로 고쳐 쓴다
            if shown then
                FixTooltipSecondaryStats(gSpec, self.slotKey, self.itemId, self.recConv)
            end
            FinishTooltip()
        end
    end)
    rec:SetScript("OnLeave", GameTooltip_Hide)
    -- 클릭 = 메타 후보 드롭다운 (커스텀 핀) — 추천 아이콘·착용 아이콘 모두 (웹과 동일)
    rec.slotKey = slot.key
    rec:SetScript("OnMouseDown", function(self, btn)
        -- 아이템 카드가 표시 중일 때만 — 빈 카드 영역(허공) 클릭은 열린 드롭다운을 닫는다
        if not self.itemId then
            if panel.dropdown and panel.dropdown:IsShown() then panel.dropdown:Hide() end
            if panel.presetFrame and panel.presetFrame:IsShown() then panel.presetFrame:Hide() end
            return
        end
        -- Shift+클릭 = 이 카드의 아이템을 부위 잠금으로 고정 토글.
        -- 핀이 없는 자동 추천 카드라면 그 추천을 핀으로 승격해 "이 아이템"이 잠기게 한다
        -- (안 그러면 착용템이 잠겨서 추천이 사라지는 오동작 — 2026-09-07 제보)
        if btn == "LeftButton" and IsShiftKeyDown() and panel.optimize then
            local k = slot.key
            local turningOn = not panel.lockedSlots[k]
            if turningOn and panel.pinnedItems[k] == nil and self.itemId then
                if self.recLink then
                    panel.pinnedItems[k] = RecToPin(self)
                else
                    panel.pinnedItems[k] = self.itemId
                    panel.pinnedConv[k] = self.recConv or ""
                end
            end
            panel.lockedSlots[k] = turningOn or nil
            if panel.lockedSlots[k] then panel.dismissedSlots[k] = nil end
            if panel.Redraw then panel.Redraw() end
            return
        end
        ShowItemDropdown(slot.key, rec.icon or rec)
    end)
    AttachRecAnim(rec)
    AttachRecSub(rec, isLeft)
    AttachSrcBadge(rec, isLeft)

    return cell
end

local function FillBottomCell(cell, diagSlot, recInfo, animate)
    local equippedId = GetInventoryItemID("player", cell.inv)
    if equippedId then
        EnsureItem(equippedId)
        cell.icon:SetTexture(GetInventoryItemTexture("player", cell.inv) or 134400)
        cell.icon:SetDesaturated(false)
        local link = GetInventoryItemLink("player", cell.inv)
        local name = link and link:match("%[(.-)%]") or C_Item.GetItemNameByID(equippedId) or "..."
        local quality = link and C_Item.GetItemQualityByID(link) or 1
        local qc = ITEM_QUALITY_COLORS[quality] or ITEM_QUALITY_COLORS[1]
        cell.name:SetText(qc.hex .. name .. "|r")
        cell.iconBg:SetVertexColor(qc.r, qc.g, qc.b, 1) -- 아이콘 테두리 = 품질색
        local ilvl = link and C_Item.GetDetailedItemLevelInfo(link)
        cell.ilvl:SetText(ilvl and tostring(ilvl) or "")
    else
        -- 빈 슬롯: 물음표 대신 은은한 빈 칸 + 슬롯 라벨
        cell.icon:SetTexture("Interface\\Buttons\\WHITE8X8")
        cell.icon:SetDesaturated(false)
        cell.icon:SetVertexColor(1, 1, 1, 0.05)
        cell.iconBg:SetVertexColor(0, 0, 0, 1)
        cell.name:SetText("|cff666666" .. (cell.slotKey == "OFF_HAND" and L["보조무기"] or L["주무기"]) .. "|r")
        cell.ilvl:SetText("")
    end
    if equippedId then cell.icon:SetVertexColor(1, 1, 1, 1) end
    cell.check:SetShown(diagSlot ~= nil and diagSlot.matched == true)
    -- 착용템과 동일 아이템이면 추천 숨김 — 단 표시 ilvl이 착용보다 높으면(핀+트랙 업 등), 또는 가방의 다른 실물
    -- (같은 ID인데 2차 배분·ilvl이 다른 사본, 링크가 착용템과 다름)이면 유지(2026-09-20)
    if recInfo and recInfo.itemId == equippedId then
        local wl3 = GetInventoryItemLink("player", cell.inv)
        local wornIl = wl3 and C_Item.GetDetailedItemLevelInfo(wl3) or 0
        local otherCopy = recInfo.bagLink ~= nil and recInfo.bagLink ~= wl3
        if not otherCopy and (not recInfo.ilvl or recInfo.ilvl <= wornIl) then recInfo.itemId = nil end
    end
    if recInfo and recInfo.itemId then EnsureItem(recInfo.itemId) end
    SetRec(cell.rec, recInfo, animate)
end

-- ── 패널 구성 ─────────────────────────────────────────────────────────────────

-- ── 트랙 핀 스탯 ──
-- 메타 아이템에 강화 트랙을 골랐으면 그 트랙 만렙 ilvl 링크의 실제 스탯(인게임 GetItemStats)을 시뮬에 넘긴다.
-- 이전엔 트랙이 표기 ilvl에만 반영되고 수치는 데이터 스탯 그대로라 "장비 +N"이 안 움직였다
-- (2026-09-09 디스코드 제보). 웹은 같은 상황에서 Wowhead로 해당 ilvl 스탯을 받아 반영한다 — 선형 추정 아님.
-- 반환: link, ilvl, stats. 적용 불가(트랙 단계 없는 고정템·데이터 ilvl과 동일·미캐시)면 nil → 데이터 스탯 유지.
local function TrackPinLinkStats(slotKey, itemId, conv)
    local pt = panel and panel.pinnedTracks and panel.pinnedTracks[slotKey]
    if not pt or pt == "VENOM" then return nil end
    if pt == "Peak" then pt = "Myth" end -- 막넴 344 대상은 링크 핀 경로, 비대상은 신화 기준 (툴팁과 동일)
    local spec = panel.curSpec
    if not spec then return nil end
    local dataIlvl, bonuses = MetaItemInfo(spec, slotKey, itemId, conv)
    if not (bonuses and bonuses ~= "" and HasTrackStep(bonuses)) then return nil end
    local src = (WythicPlusGearData.sources or {})[itemId]
    local tIlvl = TrackMaxIlvl(pt, src and src[1] == "crafted")
    if not tIlvl or tIlvl == dataIlvl then return nil end
    local nb = RelinkTrackBonuses(bonuses, tIlvl)
    if not nb or nb == "" or nb == bonuses then return nil end
    -- 변환 티어는 원본 modifier(64)를 붙여야 GetItemStats가 원본 배분으로 나온다
    local link = BuildItemLink(itemId, nb, ConvertedSourceItem(spec, slotKey, itemId, conv))
    local st = (WythicPlus_GearLinkStats and WythicPlus_GearLinkStats(link)) or {}
    if next(st) == nil and not C_Item.GetItemInfo(itemId) then
        EnsureItem(itemId) -- 미캐시: GET_ITEM_INFO_RECEIVED 재드로우에서 반영
        return nil
    end
    -- 게임 배분 ≠ 수집 배분(변환 티어·무작위 능력치·제작)이면 그 ilvl 예산을 수집 배분으로 — 툴팁과 같은 규칙
    st = AlignLinkStats(st, link, MetaItemStats(spec, slotKey, itemId, conv))
    if not st then return nil end
    return link, tIlvl, st
end

-- ── 도핑 버프 감지 (음식 포만감 · 영약) ──
-- % 표시는 캐릭터창과 같은 실측 값이라 이 버프들이 2차 스탯을 부풀린다. 버프가 실제로 있을 때만
-- 경고를 띄운다(상시 안내문 대체, 2026-09-09 요청). 룬은 주스탯만 올려 2차 스탯 표시와 무관 → 제외.
-- 이름 패턴 매칭(ko/en) — 버프 spellID는 시즌마다 바뀌어 하드코딩 불가.
local DOPING_PATTERNS = {
    { key = "food", ko = { "포만감" }, en = { "Well Fed" } },
    { key = "flask", ko = { "영약", "약병" }, en = { "^Flask of", "^Phial of" } },
}
local function DetectDopingBuffs()
    local found = {}
    local function match(name)
        for _, p in ipairs(DOPING_PATTERNS) do
            if not found[p.key] then
                for _, s in ipairs(p.ko) do if name:find(s, 1, true) then found[p.key] = name end end
                for _, s in ipairs(p.en) do if name:find(s) then found[p.key] = name end end
            end
        end
    end
    -- 12.x: 전투 중(특히 인던) 오라 이름이 secret string으로 오면 find 자체가 에러라 리드로우 전체가 죽어
    -- 창이 빈 채로 뜬다(2026-09-11 디스코드 제보 — "attempt to index local 'name' (a secret string value)").
    -- 봉인된 이름은 조용히 건너뛰고(도핑 경고만 못 띄움), 나머지 렌더는 계속한다.
    local function safeMatch(name)
        if type(name) ~= "string" then return end
        if issecretvalue and issecretvalue(name) then return end
        pcall(match, name)
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 80 do
            local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not a then break end
            safeMatch(a.name)
        end
    elseif UnitAura then
        for i = 1, 80 do
            local name = UnitAura("player", i, "HELPFUL")
            if not name then break end
            safeMatch(name)
        end
    end
    return found
end
local function UpdateDopingNote()
    if not (panel and panel.dopingNote) then return end
    local found = DetectDopingBuffs()
    local names = {}
    if found.food then names[#names + 1] = found.food end
    if found.flask then names[#names + 1] = found.flask end
    if #names > 0 then
        -- 이모지는 WoW 폰트에서 깨짐 → 인게임 경고 텍스처로 대체. 문구는 "버프 중 · 정확하지 않을 수 있음" 톤.
        panel.dopingNote:SetText("|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:12:12:0:0|t |cfffbbf24" .. string.format(
            L["버프 중: %s — 지금 수치는 버프가 포함돼 정확하지 않을 수 있습니다."], table.concat(names, ", ")) .. "|r")
        panel.dopingNote:Show()
        if panel.dopingBlink and not panel.dopingBlink:IsPlaying() then panel.dopingBlink:Play() end
    else
        if panel.dopingBlink then panel.dopingBlink:Stop() end
        panel.dopingNote:SetAlpha(1)
        panel.dopingNote:SetText("")
        panel.dopingNote:Hide()
    end
end

-- 재드로우 디바운스 — 아이템 정보 응답·장비 교체(세트 스왑은 슬롯당 이벤트 16개)가 연달아 와도 0.1초 뒤 1회만.
local redrawQueued = false
-- ── 가방 추천 일괄 착용 ──
-- 현재 화면(lastView)의 아이템 추천/선택 중 실제 가방 아이템(bagLink 있음, 마나용제 변환 가정 제외, 이미 착용 아님)을
-- 인벤 슬롯 번호와 함께 모은다. 반지·장신구는 슬롯을 지정해 넣어야 원하는 쪽에 들어간다.
local function CollectBagEquips()
    local list = {}
    if not (panel and panel.cells and panel.lastView) then return list end
    for key, cell in pairs(panel.cells) do
        local v = panel.lastView[key]
        if v and v.itemId and v.bagLink and not v.convFrom and not v.craft and cell.inv then
            local worn = GetInventoryItemLink("player", cell.inv)
            if worn ~= v.bagLink then
                list[#list + 1] = { link = v.bagLink, inv = cell.inv, key = key }
            end
        end
    end
    table.sort(list, function(a, b) return a.inv < b.inv end)
    return list
end

-- 순서대로 착용 (같은 프레임에 여러 가방 이동을 넣으면 서로 꼬일 수 있어 0.25초 간격).
-- 장비 변경 이벤트(PLAYER_EQUIPMENT_CHANGED)가 리드로우를 부르므로 여기서 다시 그리지 않는다.
-- 전투 중엔 게임이 착용을 막고, 귀속 전 장비는 게임의 귀속 확인 창이 뜬다(유저 확인 필요).
local function EquipBagRecs()
    if InCombatLockdown and InCombatLockdown() then
        print("|cff00ccffWythic+|r " .. L["전투 중에는 착용할 수 없습니다."])
        return
    end
    local list = CollectBagEquips()
    if #list == 0 then return end
    local equip = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if not equip then return end
    local i = 0
    local function step()
        i = i + 1
        local e = list[i]
        if not e then return end
        pcall(equip, e.link, e.inv)
        if list[i + 1] then C_Timer.After(0.25, step) end
    end
    step()
end

local function QueueRedraw()
    if redrawQueued then return end
    redrawQueued = true
    C_Timer.After(0.1, function()
        redrawQueued = false
        if panel and panel:IsShown() and panel.Redraw then
            -- 배경 재드로우(아이템 정보 수신·장비 변경)는 유저 조작이 아니므로 열려 있던 선택창을 유지한다.
            -- Redraw가 선택창을 닫기 때문에, 아이콘 로딩 응답이 올 때마다 선택창이 깜빡이며 사라졌다.
            local d = panel.dropdown
            local keepOpen = d and d:IsShown()
            panel.Redraw()
            if keepOpen and RenderDropdown then
                RenderDropdown(d)
                d:Show()
            end
        end
    end)
end

local function BuildPanel()
    panel = CreateFrame("Frame", "WythicPlusGearFrame", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "WythicPlusGearFrame") -- ESC로 닫기 (설정 창과 동일, 2026-09-12 제보)
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("MEDIUM") -- 표준 창과 동급 — 블리자드 창(애드온 목록 등)에 항상 덮이지 않게
    panel:SetToplevel(true) -- 클릭한 창이 위로 (표준 창 동작)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.04, 0.05, 0.07, 0.96)
    panel:SetBackdropBorderColor(0, 0, 0, 1)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnMouseDown", function()
        -- 허공 클릭 = 열린 팝업 닫기 (드롭다운/프리셋)
        if panel.dropdown and panel.dropdown:IsShown() then panel.dropdown:Hide() end
        if panel.presetFrame and panel.presetFrame:IsShown() then panel.presetFrame:Hide() end
    end)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true) -- 드래그로 화면 밖 이탈 방지
    panel:Hide()

    -- 저해상도·큰 UI 스케일에서 창이 화면을 넘으면 자동 축소 (여유 5%)
    panel.FitToScreen = function()
        local want = (WythicPlusDB and WythicPlusDB.gearScale) or 1
        local fit = math.min(UIParent:GetWidth() * 0.95 / PANEL_W, UIParent:GetHeight() * 0.95 / PANEL_H)
        panel:SetScale(math.min(want, fit))
    end
    local sizeEv = CreateFrame("Frame")
    sizeEv:RegisterEvent("DISPLAY_SIZE_CHANGED")
    sizeEv:RegisterEvent("UI_SCALE_CHANGED")
    sizeEv:SetScript("OnEvent", function() panel.FitToScreen() end)

    -- 우하단 리사이즈 그립(빗금) — 드래그로 창 전체 스케일 조절 (계정 저장, 재접속 유지)
    local grip = CreateFrame("Button", nil, panel)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function(self)
        self.sx = GetCursorPosition()
        self.s0 = panel:GetScale()
        self:SetScript("OnUpdate", function(self2)
            local x = GetCursorPosition()
            local sc = math.max(0.6, math.min(1.5, self2.s0 * (1 + (x - self2.sx) / 800)))
            panel:SetScale(sc)
        end)
    end)
    grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        WythicPlusDB.gearScale = panel:GetScale()
    end)
    panel.fontStrings = {}
    local function FS(parent, template, text)
        local fs = BumpFont(parent:CreateFontString(nil, "OVERLAY", template))
        if text then fs:SetText(text) end
        panel.fontStrings[#panel.fontStrings + 1] = fs
        return fs
    end

    -- 타이틀 / 닫기 / 리그
    local title = FS(panel, "GameFontNormalHuge", L["|cff00ccffWythic+|r 장비 최적화"])
    title:SetPoint("TOP", panel, "TOP", 0, -20) -- 가운데 정렬 + 상단 마진
    panel.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.close:SetPoint("TOPRIGHT", 0, 0)
    panel.league = FS(panel, "GameFontHighlightSmall")
    panel.league:SetPoint("TOP", title, "BOTTOM", 0, -6) -- 랭크 정보는 타이틀 아랫줄 중앙


    -- ── 헤더: 등급 원 + 메타 일치율 + 도넛 + 버튼 ──
    -- 등급 원 (테두리 3px 등급색 + 안쪽 8% 배경)
    -- 등급 원: 검증된 Ring 방식(원+구멍 마스크) — 등급색 테두리 링 + 대형 알파벳 (웹과 동일 룩)
    local gradeHolder = CreateFrame("Frame", nil, panel)
    gradeHolder:SetSize(84, 84)
    gradeHolder:SetPoint("TOPLEFT", UI_MARGIN, -64)
    panel.gradeOuter, panel.gradeInner = Ring(gradeHolder, 84, 4)
    panel.gradeOuter:SetPoint("CENTER", gradeHolder, "CENTER")
    -- 웹과 동일: 내부는 투명(배경 노출), 링 테두리 + 알파벳만
    panel.gradeFill = Circle(gradeHolder, 60, "BORDER")
    panel.gradeFill:SetPoint("CENTER", panel.gradeOuter, "CENTER")
    panel.gradeFill:Hide()
    panel.gradeText = FS(gradeHolder, "GameFontNormalHuge")
    panel.gradeText:SetFont(STANDARD_TEXT_FONT, 32, "OUTLINE")
    panel.gradeText:SetPoint("CENTER", panel.gradeOuter, "CENTER", 0, 0)

    panel.diagTitle = FS(panel, "GameFontNormalLarge", L["메타 일치율"])
    panel.diagTitle:SetPoint("LEFT", panel.gradeOuter, "RIGHT", 14, 10)
    panel.diagPct = FS(panel, "GameFontNormalHuge")
    panel.diagPct:SetPoint("LEFT", panel.diagTitle, "RIGHT", 10, 0)
    panel.diagDesc = FS(panel, "GameFontDisableSmall", L["상위 랭커 메타와 비교한 내 캐릭터 분석"])
    panel.diagDesc:SetPoint("TOPLEFT", panel.diagTitle, "BOTTOMLEFT", 0, -4)
    -- 도핑 경고 — 포만감/영약 버프가 실제로 있을 때만 표시 (UpdateDopingNote, UNIT_AURA로 갱신)
    panel.dopingNote = FS(panel, "GameFontDisableSmall", "")
    panel.dopingNote:SetPoint("TOPLEFT", panel.diagDesc, "BOTTOMLEFT", 0, -2)
    panel.dopingNote:Hide()
    -- 장식 3개 이상 경고 (Redraw가 화면의 최종 구성으로 판정)
    panel.embWarn = FS(panel, "GameFontDisableSmall", "")
    panel.embWarn:SetPoint("TOPLEFT", panel.dopingNote, "BOTTOMLEFT", 0, -2)
    panel.embWarn:Hide()
    -- 깜빡임: 알파 1 ↔ 0.25 왕복 루프 (버프가 있을 때만 재생)
    panel.dopingBlink = panel.dopingNote:CreateAnimationGroup()
    panel.dopingBlink:SetLooping("BOUNCE")
    local blink = panel.dopingBlink:CreateAnimation("Alpha")
    blink:SetFromAlpha(1)
    blink:SetToAlpha(0.25)
    blink:SetDuration(0.7)
    blink:SetSmoothing("IN_OUT")

    -- 도넛 4개 (우측 정렬: 스탯 · 특성 · 장비 · 마법부여)
    panel.donuts = {}
    local DONUT = 52
    for i = 1, 4 do
        local holder = CreateFrame("Frame", nil, panel)
        holder:SetSize(DONUT, DONUT + 14)
        holder:SetPoint("TOPRIGHT", -UI_MARGIN - (4 - i) * (DONUT + 18), -70)
        -- 트랙(어두운 링) — 번들 흰색 링 텍스처를 어둡게 틴트
        local RING_FILE = "Interface\\AddOns\\WythicPlus\\Textures\\ring.png"
        local outer = holder:CreateTexture(nil, "ARTWORK")
        outer:SetSize(DONUT, DONUT)
        outer:SetPoint("TOP", holder, "TOP", 0, 0)
        outer:SetTexture(RING_FILE)
        outer:SetVertexColor(RING_BG[1], RING_BG[2], RING_BG[3])
        -- 수치 비례 원호: 같은 링을 쿨다운 스와이프로 잘라 그림 (12시부터 시계방향 — 웹과 동일)
        local arc = CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
        arc:SetPoint("TOPLEFT", outer, "TOPLEFT")
        arc:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT")
        arc:SetDrawEdge(false)
        arc:SetDrawBling(false)
        arc:SetHideCountdownNumbers(true)
        arc:SetReverse(true)
        arc:SetSwipeTexture(RING_FILE)
        arc:EnableMouse(false)
        arc:SetFrameLevel(holder:GetFrameLevel() + 1)
        -- 숫자는 원호 위 레이어
        local cap = CreateFrame("Frame", nil, holder)
        cap:SetFrameLevel(holder:GetFrameLevel() + 2)
        cap:SetAllPoints(outer)
        -- 정중앙: 영역 채움+정렬로 수평/수직 중앙. koKR 폰트는 숫자 글리프가 라인박스에서
        -- 살짝 위에 앉아 시각적으로 떠 보이므로 1px 아래로 보정
        local num = FS(cap, "GameFontNormal")
        num:SetPoint("TOPLEFT", cap, "TOPLEFT", 1, -1)
        num:SetPoint("BOTTOMRIGHT", cap, "BOTTOMRIGHT", 1, -1)
        num:SetJustifyH("CENTER")
        num:SetJustifyV("MIDDLE")
        local label = FS(holder, "GameFontHighlightSmall")
        label:SetPoint("TOP", outer, "BOTTOM", 0, -2)
        panel.donuts[i] = { holder = holder, ring = outer, arc = arc, num = num, label = label }
    end

    -- ── 상세 컨테이너 (접기 대상: 스탯 비교 + 아머리 + 푸터) ──
    local detail = CreateFrame("Frame", nil, panel)
    detail:SetPoint("TOPLEFT", 0, -158)
    detail:SetPoint("BOTTOMRIGHT", 0, 0)
    panel.detail = detail
    local function DFS(template, text)
        local fs = BumpFont(detail:CreateFontString(nil, "OVERLAY", template))
        if text then fs:SetText(text) end
        panel.fontStrings[#panel.fontStrings + 1] = fs
        return fs
    end

    -- ── 스탯 비교 (2열, 스탯 고유색, 내 행 + 메타 행) — 좌우 마진 + 절제된 바 길이 ──
    panel.statRows = {}
    -- 중앙 거터 344 = 최적화 박스(320)가 스탯 2컬럼 사이에 들어가는 자리
    local STAT_GUTTER = 344
    local halfW = math.floor((PANEL_W - UI_MARGIN * 2 - STAT_GUTTER) / 2)
    local BAR_W = halfW - 68 - 66 -- 라벨(68) + %영역(66) → 컬럼 끝이 우측 마진에 정확히 닿음
    for i, k in ipairs(STAT_ORDER) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = UI_MARGIN + col * (halfW + STAT_GUTTER)
        local y = -(row * 66)
        local c = STAT_COLORS[k]

        local lab = DFS("GameFontNormal", STAT_LABELS[k])
        lab:SetPoint("TOPLEFT", x, y)
        lab:SetTextColor(c[1], c[2], c[3])

        -- 최적화 변동 수치 ("장비 +158  보석 +14") — 라벨 오른쪽
        local deltaLab = DFS("GameFontHighlightSmall")
        deltaLab:SetPoint("TOPLEFT", x + 68, y) -- 막대 시작 x에 정렬

        -- 내 행
        local meLab = DFS("GameFontHighlightSmall")
        meLab:SetSize(64, 12)
        meLab:SetPoint("TOPLEFT", x, y - 16)
        meLab:SetJustifyH("LEFT")
        local myBg = CreateFrame("Frame", nil, detail, "BackdropTemplate")
        myBg:SetSize(BAR_W, 16)
        myBg:SetPoint("TOPLEFT", x + 68, y - 14)
        myBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        myBg:SetBackdropColor(1, 1, 1, 0.06)
        local myFill = myBg:CreateTexture(nil, "ARTWORK")
        myFill:SetTexture("Interface\\Buttons\\WHITE8X8")
        myFill:SetPoint("TOPLEFT")
        myFill:SetPoint("BOTTOMLEFT")
        myFill:SetVertexColor(c[1], c[2], c[3], 0.85)
        myFill:SetWidth(1)
        -- 최적화 시뮬 증가분 (amber) — myFill 오른쪽에 이어붙는 세그먼트
        local deltaFill = myBg:CreateTexture(nil, "ARTWORK")
        deltaFill:SetTexture("Interface\\Buttons\\WHITE8X8")
        deltaFill:SetPoint("TOPLEFT", myFill, "TOPRIGHT")
        deltaFill:SetPoint("BOTTOMLEFT", myFill, "BOTTOMRIGHT")
        deltaFill:SetVertexColor(AMBER[1], AMBER[2], AMBER[3], 0.85)
        deltaFill:SetWidth(1)
        deltaFill:Hide()
        -- 바 안 절대수치 — 채움 텍스처(자식 프레임)가 부모의 글자 위에 그려져 숫자가
        -- 물 빠져 보이던 근본 원인 수정: 숫자를 바보다 높은 레벨의 전용 프레임에 올려
        -- 어떤 채움 색 위에서도 온전한 흰색으로 렌더 (EUI 스킨 폰트 교체 제외 대상)
        local myNumHolder = CreateFrame("Frame", nil, myBg)
        myNumHolder:SetAllPoints(myBg)
        myNumHolder:SetFrameLevel(myBg:GetFrameLevel() + 5)
        local myNum = myNumHolder:CreateFontString(nil, "OVERLAY")
        myNum:SetFont(STANDARD_TEXT_FONT, 12)
        myNum:SetTextColor(1, 1, 1)
        myNum:SetShadowColor(0, 0, 0, 1)
        myNum:SetShadowOffset(1, -1)
        myNum:SetPoint("RIGHT", myFill, "RIGHT", -5, 0)
        local myPct = DFS("GameFontNormalSmall")
        myPct:SetSize(60, 14)
        myPct:SetJustifyH("RIGHT")
        myPct:SetPoint("LEFT", myBg, "RIGHT", 6, 0)
        myPct:SetTextColor(c[1], c[2], c[3])

        -- 메타 행
        local metaLab = DFS("GameFontDisableSmall", L["메타 평균"])
        metaLab:SetSize(64, 12)
        metaLab:SetPoint("TOPLEFT", x, y - 36)
        metaLab:SetJustifyH("LEFT")
        local metaBg = CreateFrame("Frame", nil, detail, "BackdropTemplate")
        metaBg:SetSize(BAR_W, 16)
        metaBg:SetPoint("TOPLEFT", x + 68, y - 34)
        metaBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        metaBg:SetBackdropColor(1, 1, 1, 0.06)
        local metaFill = metaBg:CreateTexture(nil, "ARTWORK")
        metaFill:SetTexture("Interface\\Buttons\\WHITE8X8")
        metaFill:SetPoint("TOPLEFT")
        metaFill:SetPoint("BOTTOMLEFT")
        metaFill:SetVertexColor(c[1], c[2], c[3], 0.4)
        metaFill:SetWidth(1)
        local metaNumHolder = CreateFrame("Frame", nil, metaBg)
        metaNumHolder:SetAllPoints(metaBg)
        metaNumHolder:SetFrameLevel(metaBg:GetFrameLevel() + 5)
        local metaNum = metaNumHolder:CreateFontString(nil, "OVERLAY")
        metaNum:SetFont(STANDARD_TEXT_FONT, 12)
        metaNum:SetTextColor(1, 1, 1)
        metaNum:SetShadowColor(0, 0, 0, 1)
        metaNum:SetShadowOffset(1, -1)
        metaNum:SetPoint("RIGHT", metaFill, "RIGHT", -5, 0)
        local metaPct = DFS("GameFontDisableSmall")
        metaPct:SetSize(60, 14)
        metaPct:SetJustifyH("RIGHT")
        metaPct:SetPoint("LEFT", metaBg, "RIGHT", 6, 0)

        panel.statRows[k] = {
            meLab = meLab, deltaLab = deltaLab, myFill = myFill, deltaFill = deltaFill, myNum = myNum, myPct = myPct, myMax = BAR_W,
            metaFill = metaFill, metaNum = metaNum, metaPct = metaPct,
        }
    end

    -- ── 최적화 토글 + 개선 바 (아머리 상단 중앙) ──
    -- 최적화 컨트롤 박스 — 제목 / 모드 버튼 2컬럼(메타·소지품) / 레이드 체크 / 근접도 변화
    panel.optMode = "meta"
    local optBox = CreateFrame("Frame", nil, detail, "BackdropTemplate")
    optBox:SetSize(320, 112)
    optBox:SetPoint("TOP", detail, "TOP", 0, -2) -- 스탯 2컬럼 사이 중앙 거터에 배치
    optBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    optBox:SetBackdropColor(1, 1, 1, 0.03)
    optBox:SetBackdropBorderColor(1, 1, 1, 0.12)
    optBox.title = FS(optBox, "GameFontNormal", L["장비 최적화하기"])
    optBox.title:SetPoint("TOP", 0, -8)
    optBox.title:SetTextColor(0.99, 0.83, 0.30)
    panel.optBox = optBox

    -- 만렙 미만 안내 — 메타 비교·추천이 만렙 랭커 기준이라 부정확함을 명시
    panel.levelWarn = FS(detail, "GameFontHighlightSmall", L["만렙 기준 분석 — 만렙 미만 캐릭터는 추천·수치가 부정확합니다"])
    panel.levelWarn:SetPoint("TOP", optBox, "BOTTOM", 0, -4)
    panel.levelWarn:SetTextColor(0.97, 0.44, 0.44)
    panel.levelWarn:Hide()

    local function ModeButton(labelText, point, xOff, color, labelRGB)
        local c = color or AMBER
        local b = CreateFrame("Button", nil, optBox, "BackdropTemplate")
        b.baseColor = c
        b:SetSize(140, 26)
        b:SetPoint(point, xOff, -28)
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        b:SetBackdropColor(c[1], c[2], c[3], 0.08)
        b:SetBackdropBorderColor(c[1], c[2], c[3], 0.35)
        b.label = FS(b, "GameFontNormal", labelText)
        b.label:SetPoint("CENTER")
        local lr = labelRGB or { 0.99, 0.83, 0.30 }
        b.label:SetTextColor(lr[1], lr[2], lr[3])
        b:SetScript("OnEnter", function(self)
            self:SetBackdropColor(self.baseColor[1], self.baseColor[2], self.baseColor[3], self.active and 0.28 or 0.18)
        end)
        b:SetScript("OnLeave", function(self)
            self:SetBackdropColor(self.baseColor[1], self.baseColor[2], self.baseColor[3], self.active and 0.22 or 0.08)
        end)
        return b
    end
    local function ToggleMode(mode)
        if panel.optimize and panel.optMode == mode then
            panel.optimize = false -- 활성 모드 재클릭 = 최적화 끄기
        else
            panel.optimize = true
            panel.optMode = mode
        end
        WipeCustomKeepLocked() -- 토글 시 커스텀 초기화 — 잠긴 핀은 보존 (웹과 동일)
        panel.presetRatings = nil
        if panel.Redraw then panel.Redraw(true) end -- true = 추천 등장 애니메이션
    end
    local optBtn = ModeButton("|TInterface\\AddOns\\WythicPlus\\Textures\\wyplus.png:18:18|t " .. L["메타 기준"], "TOPLEFT", 14)
    optBtn:SetScript("OnClick", function() ToggleMode("meta") end)
    panel.optBtn = optBtn
    -- 소지품 기준 — 후보를 메타가 아닌 내 가방 소지품으로 제한한 최적화 모드
    local ownedBtn = ModeButton("|TInterface\\Icons\\INV_Misc_Bag_08:14:14|t " .. L["가방 기준"], "TOPRIGHT", -14,
        EMERALD, { 0.42, 0.85, 0.66 }) -- 가방(에메랄드) 테마
    ownedBtn:SetScript("OnClick", function() ToggleMode("owned") end)
    panel.ownedBtn = ownedBtn

    -- 개선 표시: "메타 근접도 X점 → Y점" — 아머리 뷰 상단 중앙에 크게 (박스 밖)
    local improve = CreateFrame("Frame", nil, detail)
    improve:SetSize(420, 26)
    improve:SetPoint("TOP", detail, "TOP", 0, -186)
    improve.text = improve:CreateFontString(nil, "OVERLAY")
    improve.text:SetFont(STANDARD_TEXT_FONT, 19, "OUTLINE")
    improve.text:SetShadowColor(0, 0, 0, 1)
    improve.text:SetShadowOffset(1, -1)
    improve.text:SetPoint("CENTER", 0, 0)
    improve.text:SetTextColor(1, 1, 1)
    -- 아이템 레벨: 근접도 오른쪽 "아이템 레벨 현재 → 추천 반영" (추천 부위의 표기 ilvl로 치환한 16슬롯 평균, 2026-09-13 요청)
    improve.ilvl = improve:CreateFontString(nil, "OVERLAY")
    improve.ilvl:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    improve.ilvl:SetShadowColor(0, 0, 0, 1)
    improve.ilvl:SetShadowOffset(1, -1)
    improve.ilvl:SetPoint("LEFT", improve.text, "RIGHT", 16, -1)
    improve.ilvl:SetTextColor(0.75, 0.75, 0.75)
    improve:Hide()
    panel.improve = improve

    -- 영웅특성 토글 버튼 (박스 상단, 제목 아래) — 데이터에 heroes가 있을 때만 표시
    panel.heroCaption = FS(optBox, "GameFontDisableSmall", L["영웅특성 기준"])
    panel.heroCaption:Hide()
    panel.raidLabel = FS(optBox, "GameFontDisableSmall", L["레이드 필터"])
    panel.raidLabel:Hide()
    panel.heroBtns = {}
    panel.GetHeroBtn = function(i)
        local b = panel.heroBtns[i]
        if b then return b end
        b = CreateFrame("Button", nil, optBox, "BackdropTemplate")
        b:SetSize(140, 22)
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        -- 영웅특성 공식 아이콘 (탤런트 창 아틀라스) — 없으면 텍스트만. 내용은 중앙 정렬(Redraw에서 배치)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(20, 20)
        b.label = FS(b, "GameFontHighlightSmall")
        b.label:SetWordWrap(false)
        b:SetScript("OnEnter", function(self)
            if not self.activeHero then self:SetBackdropColor(1, 1, 1, 0.12) end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["영웅특성 기준"], 1, 1, 1)
            if self.heroDisabled then
                GameTooltip:AddLine(L["표본 부족(10명 미만) — 전체 랭커 기준으로 분석 중"], 0.6, 0.62, 0.68, true)
            else
                GameTooltip:AddLine(string.format(L["이 영웅특성 랭커들의 메타(표본 %d명)로 진단·추천합니다"], self.heroSample or 0), 0.6, 0.62, 0.68, true)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            if not self.activeHero then self:SetBackdropColor(1, 1, 1, 0.05) end
            GameTooltip:Hide()
        end)
        b:SetScript("OnClick", function(self)
            if self.heroDisabled then return end -- 표본 부족 트리 (웹의 비활성 토글과 동일)
            if not self.treeId or self.treeId == panel.heroActive then return end
            panel.heroTreeId = self.treeId
            WipeCustomKeepLocked() -- 기준 변경 = 후보 풀 변경 → 커스텀 초기화 (잠긴 핀 보존)
            panel.presetRatings = nil
            if panel.Redraw then panel.Redraw() end
        end)
        panel.heroBtns[i] = b
        return b
    end

    -- 유저 커스텀 핀 (슬롯키 → 아이템ID / 강화 트랙) — 추천 클릭 드롭다운에서 선택
    panel.pinnedItems = {}
    panel.pinnedConv = {} -- 메타 핀의 변형(conv) — 같은 itemId 일반/변환 구분
    panel.pinnedGems = {} -- 슬롯 → 핀 보석ID (보석 드롭다운에서 선택)
    panel.pinnedEnchants = {} -- 슬롯 → 핀 마법부여 이름(enUS, WythicPlusCraftData.enchants) — 착용 마부 대비 차분 반영
    panel.dismissedSlots = {} -- 슬롯 → true (시뮬 추천 해제 — 착용템 유지)
    panel.lockedSlots = {} -- 슬롯 → true (부위 잠금 — 메타/소지품 최적화에서 제외, Shift+클릭 토글)
    panel.pinnedTracks = {}
    panel.lastRecs = {} -- 슬롯 → 현재 표시 중인 추천 아이템ID (트랙 역산용)
    panel.lastView = {} -- 슬롯 → 현재 화면 최종 상태 (프리셋 저장용)

    -- ── Raidbots (SimC 프로필 내보내기) — 현재 화면 최종 세트(추천/핀/트랙 반영)를 simc 텍스트로 ──
    -- 웹 toSimcString(= SimC 애드온 12.0.5-02 형식)과 동일한 프로필 생성
    local function BuildSimcProfile()
        local classToken = (select(2, UnitClass("player")) or "unknown"):lower()
        -- 종족 파일명 → simc 토큰 (CamelCase → snake_case, 언데드 파일명 Scourge 보정)
        local raceFile = select(2, UnitRace("player")) or "Human"
        local raceToken = raceFile == "Scourge" and "undead"
            or raceFile:gsub("(%l)(%u)", "%1_%2"):lower()
        local name = UnitName("player") or "Char"
        local realm = (GetRealmName and GetRealmName()) or ""
        local region = SIMC_REGION[GetCurrentRegion and GetCurrentRegion() or 0] or "us"
        local specIndex = GetSpecialization()
        local specID = specIndex and GetSpecializationInfo(specIndex)
        local key = specID and WythicPlusGearData.specIds and WythicPlusGearData.specIds[specID]
        local specEn = (key and key:match("/(.+)$")) or "Unknown"
        local specToken = specEn:lower():gsub("%s+", "_")

        local lines = {}
        -- 애드온 헤더 (웹과 동일 서식)
        lines[#lines + 1] = "# " .. name .. " - " .. specEn .. " - " .. date("%Y-%m-%d") .. " - " .. region:upper() .. "/" .. realm
        -- 게임 버전은 실제 클라이언트에서 — 하드코딩하면 패치 후 Raidbots가 Old Patch로 거부한다
        local wowVer, wowBuild, _, wowToc = GetBuildInfo()
        lines[#lines + 1] = "# SimC Addon " .. (wowVer or "") .. "-01"
        lines[#lines + 1] = "# WoW " .. (wowVer or "") .. "." .. (wowBuild or "") .. ", TOC " .. (wowToc or "")
        lines[#lines + 1] = "# Requires SimulationCraft 1000-01 or newer"
        lines[#lines + 1] = classToken .. "=\"" .. name .. "\""
        lines[#lines + 1] = "level=" .. UnitLevel("player")
        lines[#lines + 1] = "race=" .. raceToken
        lines[#lines + 1] = "region=" .. region
        lines[#lines + 1] = "server=" .. realm:lower():gsub("%s", "_")
        lines[#lines + 1] = "role=" .. SimcRole(specEn)
        lines[#lines + 1] = "spec=" .. specToken
        local tcode = WythicPlus_GearTalentCode and WythicPlus_GearTalentCode()
        if tcode then lines[#lines + 1] = "talents=" .. tcode end
        lines[#lines + 1] = ""

        -- 장비: 웹과 동일하게 "추천 적용 최종 세트" — 최적화 버튼을 안 눌렀어도 시뮬을 돌려 반영
        local view = panel.optimize and panel.lastView or nil
        if not view then
            local sim = WythicPlus_GearSimulate and panel.effSpec
                and WythicPlus_GearSimulate(panel.effSpec, panel.pinnedItems, panel.presetRatings, panel.pinnedGems)
            local diag = WythicPlus_GearDiagnose and panel.effSpec and WythicPlus_GearDiagnose(panel.effSpec)
            local slotsByKey = {}
            if diag and diag.gear and diag.gear.slots then
                for _, s2 in ipairs(diag.gear.slots) do slotsByKey[s2.slot] = s2 end
            end
            view = {}
            for _, slotKey in ipairs(SIMC_ORDER) do
                local pin = panel.pinnedItems[slotKey]
                local entry
                if type(pin) == "table" then
                    entry = { itemId = pin.item_id, bagLink = pin.link, ilvl = pin.ilvl }
                elseif pin then
                    entry = { itemId = pin }
                elseif sim and sim.slotRecommendations and type(sim.slotRecommendations[slotKey]) == "number" then
                    entry = { itemId = sim.slotRecommendations[slotKey] }
                else
                    local ds = slotsByKey[slotKey]
                    if ds and not ds.matched and ds.metaTop then
                        entry = { itemId = ds.metaTop.item_id }
                    end
                end
                -- 추천 == 착용템이면 착용 유지 (웹 getRec의 item_id 비교와 동일)
                local cell2 = panel.cells[slotKey]
                local eqId = cell2 and cell2.inv and GetInventoryItemID("player", cell2.inv)
                if entry and entry.itemId and entry.itemId == eqId and not entry.bagLink then
                    entry = nil
                end
                if entry and entry.itemId and not entry.bagLink then
                    entry.ilvl, entry.bonuses, entry.conv = MetaItemInfo(panel.effSpec, slotKey, entry.itemId, panel.pinnedConv[slotKey])
                end
                -- 보석: 핀 우선 → 시뮬 추천 (웹 getRecGemIds 대응). 핀 0 = 보석 해제(빈 홈)
                local gemId = sim and sim.gemPins and sim.gemPins[slotKey] or nil
                local gemNone = gemId == 0
                if gemNone then gemId = nil end
                if not gemId and not gemNone and sim and sim.gemRecommendations then
                    local gi = sim.gemRecommendations[slotKey]
                    if gi ~= nil and sim.gemIdsBySlot and sim.gemIdsBySlot[slotKey] then
                        gemId = sim.gemIdsBySlot[slotKey][gi + 1]
                    end
                end
                if gemId or gemNone then
                    entry = entry or {}
                    entry.gemId = gemId
                    entry.gemNone = gemNone
                end
                view[slotKey] = entry
            end
        end
        local replacedWorn = {} -- 추천으로 교체된 착용템 → 가방 섹션 (웹 bagItems 대응)
        for _, slotKey in ipairs(SIMC_ORDER) do
            local cell = panel.cells[slotKey]
            local sslot = SIMC_SLOT[slotKey]
            if cell and sslot then
                local v = view and view[slotKey]
                local p, dispName, dispIlvl, ilevelOverride
                if v and v.bagLink then
                    p = LinkSimcParts(v.bagLink)
                    dispName = v.bagLink:match("%[(.-)%]")
                    dispIlvl = v.ilvl
                    -- 유저가 직접 고른 아이템(링크 핀): 보석 = 화면의 보석(핀/추천), 마부 = 착용 마부 유지(가방 실물은 자기 마부)
                    local pinT = panel.pinnedItems[slotKey]
                    if p and type(pinT) == "table" then
                        if v.gemId then p.gems = { tostring(v.gemId) } end
                        if not p.enchant and pinT.srcTab ~= "bags" then
                            local wlE = cell.inv and GetInventoryItemLink("player", cell.inv)
                            local wpE = wlE and LinkSimcParts(wlE)
                            if wpE and wpE.enchant then p.enchant = wpE.enchant end
                        end
                    end
                elseif v and v.itemId then
                    local b = v.bonuses or ""
                    local pt = panel.pinnedTracks[slotKey]
                    if pt and pt ~= "VENOM" and b ~= "" then
                        local src = (WythicPlusGearData.sources or {})[v.itemId]
                        local tIlvl = TrackMaxIlvl(pt, src and src[1] == "crafted")
                        if tIlvl then
                            b = RelinkTrackBonuses(b, tIlvl)
                            ilevelOverride = tIlvl
                        end
                    end
                    -- 변환 티어: 원본 아이템 ID → redirected_base_stats (SimC 가 원본 2차 배분으로 시뮬)
                    p = { id = tostring(v.itemId), gems = {}, bonuses = {},
                          redirect = ConvertedSourceItem(panel.effSpec, slotKey, v.itemId, v.conv) }
                    for tok in b:gmatch("[^:]+") do p.bonuses[#p.bonuses + 1] = tok end
                    if v.gemId then p.gems[1] = tostring(v.gemId) end
                    dispName = C_Item.GetItemNameByID(v.itemId)
                    dispIlvl = v.ilvl
                    -- 착용 마부 유지 + 교체된 착용템은 가방 섹션으로 (웹 finalEquip/bagItems와 동일)
                    local wl2 = cell.inv and GetInventoryItemLink("player", cell.inv)
                    if wl2 then
                        local wp = LinkSimcParts(wl2)
                        if wp and wp.enchant then p.enchant = wp.enchant end
                        replacedWorn[#replacedWorn + 1] = { sslot = sslot, link = wl2 }
                    end
                else
                    local wl = cell.inv and GetInventoryItemLink("player", cell.inv)
                    if wl then
                        p = LinkSimcParts(wl)
                        dispName = wl:match("%[(.-)%]")
                        dispIlvl = C_Item.GetDetailedItemLevelInfo(wl)
                    end
                end
                if p then
                    -- 유저가 고른 마법부여가 있으면 그 마부 ID (링크용 ID를 아는 마부만)
                    local peS = EnchantByName(panel.pinnedEnchants[slotKey])
                    if peS and peS.enchId then p.enchant = tostring(peS.enchId) end
                    if dispName then
                        lines[#lines + 1] = "# " .. dispName .. " (" .. tostring(dispIlvl or "?") .. ")"
                    end
                    local parts = { "id=" .. p.id }
                    if p.enchant then parts[#parts + 1] = "enchant_id=" .. p.enchant end
                    if #p.gems > 0 then parts[#parts + 1] = "gem_id=" .. table.concat(p.gems, "/") end
                    if #p.bonuses > 0 then parts[#parts + 1] = "bonus_id=" .. table.concat(p.bonuses, "/") end
                    if p.redirect then parts[#parts + 1] = "redirected_base_stats=" .. tostring(p.redirect) end
                    if p.crafted then parts[#parts + 1] = "crafted_stats=" .. table.concat(p.crafted, "/") end
                    if ilevelOverride then parts[#parts + 1] = "ilevel=" .. ilevelOverride end
                    lines[#lines + 1] = sslot .. "=," .. table.concat(parts, ",")
                end
            end
        end

        -- 가방 대안 장비 (Top Gear용, 주석 처리 — 웹 bagItems 섹션과 동일)
        -- 같은 실물(id+보너스)은 1회만 — 쌍 슬롯(장신구/반지/무기) 중복 방출 방지
        local bagLines = {}
        local bagSeen = {}
        for _, rw in ipairs(replacedWorn) do
            local p = LinkSimcParts(rw.link)
            if p then
                bagSeen[p.id .. ":" .. table.concat(p.bonuses, "/")] = true
                bagLines[#bagLines + 1] = "#"
                local nm = rw.link:match("%[(.-)%]")
                if nm then bagLines[#bagLines + 1] = "# " .. nm .. " (" .. tostring(C_Item.GetDetailedItemLevelInfo(rw.link) or "?") .. ")" end
                local parts = { "id=" .. p.id }
                if #p.bonuses > 0 then parts[#parts + 1] = "bonus_id=" .. table.concat(p.bonuses, "/") end
                if p.redirect then parts[#parts + 1] = "redirected_base_stats=" .. tostring(p.redirect) end
                if p.crafted then parts[#parts + 1] = "crafted_stats=" .. table.concat(p.crafted, "/") end
                bagLines[#bagLines + 1] = "# " .. rw.sslot .. "=," .. table.concat(parts, ",")
            end
        end
        for _, slotKey in ipairs(SIMC_ORDER) do
            local sslot = SIMC_SLOT[slotKey]
            if sslot and SLOT_INVTYPE[slotKey] then
                for _, bi in ipairs(ScanBagsForSlot(slotKey)) do
                    local p = LinkSimcParts(bi.link)
                    local dedupeKey = p and (p.id .. ":" .. table.concat(p.bonuses, "/")) or nil
                    if p and not bagSeen[dedupeKey] then
                        bagSeen[dedupeKey] = true
                        bagLines[#bagLines + 1] = "#"
                        local nm = bi.link:match("%[(.-)%]")
                        if nm then bagLines[#bagLines + 1] = "# " .. nm .. " (" .. tostring(bi.ilvl or "?") .. ")" end
                        local parts = { "id=" .. p.id }
                        if #p.bonuses > 0 then parts[#parts + 1] = "bonus_id=" .. table.concat(p.bonuses, "/") end
                        if p.redirect then parts[#parts + 1] = "redirected_base_stats=" .. tostring(p.redirect) end
                        if p.crafted then parts[#parts + 1] = "crafted_stats=" .. table.concat(p.crafted, "/") end
                        bagLines[#bagLines + 1] = "# " .. sslot .. "=," .. table.concat(parts, ",")
                    end
                end
            end
        end
        if #bagLines > 0 then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "### Gear from Bags"
            for _, bl in ipairs(bagLines) do lines[#lines + 1] = bl end
        end

        -- Adler-32 체크섬 (본문 끝 개행 포함, || → | 정규화 — 웹/SimC 애드온과 동일)
        local body = table.concat(lines, "\n") .. "\n"
        return body .. "# Checksum: " .. string.format("%x", SimcAdler32(body:gsub("||", "|")))
    end

    local simcFrame
    local function ShowSimcDialog()
        if not simcFrame then
            simcFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
            simcFrame:SetSize(720, 520)
            simcFrame:SetPoint("CENTER")
            simcFrame:SetFrameStrata("DIALOG")
            simcFrame:EnableMouse(true) -- 뒤 요소 클릭 관통 차단
            simcFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            simcFrame:SetBackdropColor(0.09, 0.09, 0.12, 0.98) -- 웹 모달 배경 톤
            simcFrame:SetBackdropBorderColor(1, 1, 1, 0.12)

            -- 제목줄: 아이콘 + SimC Export + 우상단 X (웹 모달과 동일 구성)
            local titleIcon = simcFrame:CreateTexture(nil, "ARTWORK")
            titleIcon:SetSize(18, 18)
            titleIcon:SetPoint("TOPLEFT", 14, -12)
            titleIcon:SetTexture("Interface\\AddOns\\WythicPlus\\Textures\\raidbots.png")
            simcFrame.title = FS(simcFrame, "GameFontNormalLarge", "SimC Export")
            simcFrame.title:SetPoint("LEFT", titleIcon, "RIGHT", 6, 0)
            local closeX = CreateFrame("Button", nil, simcFrame)
            closeX:SetSize(20, 20)
            closeX:SetPoint("TOPRIGHT", -8, -8)
            closeX.label = FS(closeX, "GameFontHighlight", "×")
            closeX.label:SetPoint("CENTER")
            closeX:SetScript("OnClick", function() simcFrame:Hide() end)

            -- 코드 박스: 더 어두운 인셋 (웹 코드블록 톤)
            local codeBox = CreateFrame("Frame", nil, simcFrame, "BackdropTemplate")
            codeBox:SetPoint("TOPLEFT", 14, -38)
            codeBox:SetPoint("BOTTOMRIGHT", -14, 100)
            codeBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            codeBox:SetBackdropColor(0.03, 0.03, 0.045, 1)
            codeBox:SetBackdropBorderColor(1, 1, 1, 0.08)
            local sf = CreateFrame("ScrollFrame", nil, codeBox, "UIPanelScrollFrameTemplate")
            sf:SetPoint("TOPLEFT", 8, -8)
            sf:SetPoint("BOTTOMRIGHT", -26, 8)
            local eb = CreateFrame("EditBox", nil, sf)
            eb:SetMultiLine(true)
            eb:SetFontObject(ChatFontNormal)
            eb:SetWidth(640)
            eb:SetAutoFocus(false)
            eb:SetScript("OnEscapePressed", function() simcFrame:Hide() end)
            eb:SetScript("OnTextChanged", function(self, userInput)
                -- 읽기 전용: 사용자가 지워도 원문 복원 (SetText 재호출은 userInput=false라 무한루프 없음)
                if userInput then
                    self:SetText(self.simcText or "")
                    self:HighlightText()
                end
            end)
            sf:SetScrollChild(eb)
            simcFrame.edit = eb

            -- 하단: [전체 선택] + Raidbots URL 안내 (인게임은 브라우저를 못 열어 URL 복사로 대체)
            local selBtn = CreateFrame("Button", nil, simcFrame, "BackdropTemplate")
            selBtn:SetSize(150, 26)
            selBtn:SetPoint("BOTTOMLEFT", 14, 66)
            selBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            selBtn:SetBackdropColor(AMBER[1], AMBER[2], AMBER[3], 0.15)
            selBtn:SetBackdropBorderColor(AMBER[1], AMBER[2], AMBER[3], 0.5)
            selBtn.label = FS(selBtn, "GameFontNormal", L["전체 선택 (Ctrl+C 복사)"])
            selBtn.label:SetPoint("CENTER")
            selBtn:SetScript("OnClick", function()
                eb:SetFocus()
                eb:HighlightText()
            end)
            local hint = FS(simcFrame, "GameFontHighlightSmall")
            hint:SetPoint("LEFT", selBtn, "RIGHT", 10, 0)
            hint:SetText(L["복사한 프로필을 아래 주소의 Quick Sim / Top Gear에 붙여넣으세요"])
            hint:SetTextColor(0.6, 0.63, 0.7)
            -- URL 줄 (선택-복사 가능) — 웹 모달의 Top Gear/Quick Sim 링크 대응 (같은 문자열 사용)
            local function UrlRow(labelText, url, yOff, r, g, b)
                local lab = FS(simcFrame, "GameFontHighlightSmall", labelText)
                lab:SetPoint("BOTTOMLEFT", 16, yOff)
                lab:SetTextColor(r, g, b)
                local ub = CreateFrame("EditBox", nil, simcFrame)
                ub:SetSize(440, 16)
                ub:SetPoint("LEFT", lab, "RIGHT", 8, 0)
                ub:SetFontObject(GameFontHighlightSmall)
                ub:SetAutoFocus(false)
                ub:SetText(url)
                ub:SetTextColor(0.38, 0.65, 0.98)
                ub:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
                ub:SetScript("OnTextChanged", function(self, userInput)
                    if userInput then
                        self:SetText(url)
                        self:HighlightText()
                    end
                end)
                ub:SetScript("OnMouseDown", function(self)
                    self:SetFocus()
                    self:HighlightText()
                end)
            end
            UrlRow("Top Gear", "https://www.raidbots.com/simbot/topgear", 44, 0.98, 0.75, 0.14)
            UrlRow("Quick Sim", "https://www.raidbots.com/simbot/quick", 26, 0.38, 0.65, 0.98)
            local credit = FS(simcFrame, "GameFontDisableSmall", L["Raidbots는 Seriallos의 서비스입니다 — 로고는 연동 안내용, Wythic+와 제휴 아님"])
            credit:SetPoint("BOTTOMLEFT", 16, 8)
        end
        local ok, txt = pcall(BuildSimcProfile)
        if not ok then
            print(L["|cff00ccff[Wythic+]|r SimC 프로필 생성 오류: "] .. tostring(txt))
            return
        end
        simcFrame.edit.simcText = txt
        simcFrame.edit:SetText(txt)
        simcFrame.edit:HighlightText()
        simcFrame.edit:SetFocus()
        simcFrame:Show()
    end

    local simcBtn = CreateFrame("Button", nil, detail, "BackdropTemplate")
    simcBtn:SetSize(90, 30)
    simcBtn:SetPoint("TOPLEFT", detail, "TOPLEFT", UI_MARGIN, -138)
    simcBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    simcBtn:SetBackdropColor(1, 1, 1, 0.06)
    simcBtn:SetBackdropBorderColor(1, 1, 1, 0.25)
    simcBtn.label = FS(simcBtn, "GameFontNormal", "|TInterface\\AddOns\\WythicPlus\\Textures\\raidbots.png:14:14|t Raidbots")
    simcBtn.label:SetPoint("CENTER")
    simcBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(1, 1, 1, 0.12)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["SimC 프로필 복사 — raidbots.com에서 시뮬레이션"], 1, 1, 1)
        GameTooltip:AddLine(L["Raidbots 로고 © Seriallos — 연동 안내용이며 제휴 아님"], 0.55, 0.57, 0.62)
        GameTooltip:Show()
    end)
    simcBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(1, 1, 1, 0.06)
        GameTooltip:Hide()
    end)
    simcBtn:SetScript("OnClick", ShowSimcDialog)
    panel.simcBtn = simcBtn

    -- 프리셋 버튼 (최적화 줄 우측 끝)
    local presetBtn = CreateFrame("Button", nil, detail, "BackdropTemplate")
    presetBtn:SetSize(80, 30)
    presetBtn:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -UI_MARGIN, -138)
    presetBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    presetBtn:SetBackdropColor(1, 1, 1, 0.06)
    presetBtn:SetBackdropBorderColor(1, 1, 1, 0.25)
    presetBtn.label = FS(presetBtn, "GameFontNormal", L["프리셋"])
    presetBtn.label:SetPoint("CENTER")
    presetBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(1, 1, 1, 0.12) end)
    presetBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 1, 1, 0.06) end)
    presetBtn:SetScript("OnClick", function(self) TogglePresetFrame(self) end)
    panel.presetBtn = presetBtn

    -- 부위 잠금 안내 — 아머리 뷰어 우상단 한 줄 힌트, 호버 시 사용법 상세 (기능 발견성)
    panel.lockHint = CreateFrame("Frame", nil, detail)
    panel.lockHint:SetSize(220, 16)
    panel.lockHint:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -UI_MARGIN, -188)
    panel.lockHint.text = FS(panel.lockHint, "GameFontDisableSmall",
        "|TInterface\\PetBattles\\PetBattle-LockIcon:12|t " .. L["부위 잠금: |cffcfcfcfShift+클릭|r"])
    panel.lockHint.text:SetPoint("RIGHT")
    panel.lockHint:EnableMouse(true)
    panel.lockHint:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT") -- 힌트 바로 우측에
        GameTooltip:AddLine(L["부위 잠금"], 0.96, 0.72, 0.33)
        GameTooltip:AddLine(L["잠근 부위는 최적화가 건드리지 않습니다."], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["아이템을 골라두고 잠그면 그 아이템으로 확정, 그냥 잠그면 지금 낀 그대로 유지됩니다."], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["· 추천/선택 카드 Shift+클릭 = 그 아이템 잠금"], 1, 1, 1)
        GameTooltip:AddLine(L["· 착용 아이콘 Shift+클릭 = 착용템 잠금"], 1, 1, 1)
        GameTooltip:AddLine(L["· 아이템 선택창 하단 「이 부위 잠금」 버튼"], 1, 1, 1)
        GameTooltip:Show()
    end)
    panel.lockHint:SetScript("OnLeave", GameTooltip_Hide)

    -- 가방 추천 일괄 착용 — 표시 중인 가방 추천/선택(bagLink, 변환 가정 제외)을 해당 부위에 순서대로 착용 (2026-09-13 요청)
    local equipAll = CreateFrame("Button", nil, detail, "BackdropTemplate")
    equipAll:SetSize(200, 22)
    equipAll:SetPoint("TOPRIGHT", panel.lockHint, "BOTTOMRIGHT", 0, -6)
    equipAll:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    equipAll:SetBackdropColor(EMERALD[1], EMERALD[2], EMERALD[3], 0.10)
    equipAll:SetBackdropBorderColor(EMERALD[1], EMERALD[2], EMERALD[3], 0.6)
    equipAll.label = FS(equipAll, "GameFontHighlightSmall", "")
    equipAll.label:SetPoint("CENTER")
    equipAll.label:SetTextColor(0.42, 0.85, 0.66)
    equipAll:SetScript("OnEnter", function(self)
        self:SetBackdropColor(EMERALD[1], EMERALD[2], EMERALD[3], 0.22)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["가방 추천 일괄 착용"], 0.42, 0.85, 0.66)
        GameTooltip:AddLine(L["표시 중인 가방 추천·선택 아이템을 해당 부위에 한 번에 착용합니다."], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["변환 가정(마나용제) 추천은 제외됩니다."], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["귀속 확인 창이 뜨는 아이템(귀속 전 장비)은 확인이 필요합니다."], 0.8, 0.8, 0.8, true)
        if InCombatLockdown and InCombatLockdown() then GameTooltip:AddLine(L["전투 중에는 착용할 수 없습니다."], 1, 0.4, 0.4) end
        GameTooltip:Show()
    end)
    equipAll:SetScript("OnLeave", function(self)
        self:SetBackdropColor(EMERALD[1], EMERALD[2], EMERALD[3], 0.10)
        GameTooltip_Hide()
    end)
    equipAll:SetScript("OnClick", function() EquipBagRecs() end)
    equipAll:Hide()
    panel.equipAllBtn = equipAll

    -- 전체 초기화 — 커스텀(핀·트랙) 전부 리셋. 핀이 하나라도 있으면 표시 (최적화 ON/OFF 무관)
    local clearBtn = CreateFrame("Button", nil, detail, "BackdropTemplate")
    clearBtn:SetSize(90, 30)
    clearBtn:SetPoint("RIGHT", presetBtn, "LEFT", -8, 0)
    clearBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    clearBtn:SetBackdropColor(1, 1, 1, 0.06)
    clearBtn:SetBackdropBorderColor(0.97, 0.44, 0.44, 0.4) -- 붉은 테두리 (리셋 성격)
    clearBtn.label = FS(clearBtn, "GameFontNormal", L["|cfff87171전체 초기화|r"])
    clearBtn.label:SetPoint("CENTER")
    clearBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(1, 1, 1, 0.12) end)
    clearBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 1, 1, 0.06) end)
    clearBtn:SetScript("OnClick", function()
        wipe(panel.pinnedItems)
        wipe(panel.pinnedConv)
        wipe(panel.pinnedGems)
        wipe(panel.pinnedEnchants)
        wipe(panel.dismissedSlots)
        wipe(panel.pinnedTracks)
        wipe(panel.lockedSlots)
        panel.presetRatings = nil
        if panel.Redraw then panel.Redraw() end
    end)
    clearBtn:Hide()
    panel.clearBtn = clearBtn

    -- 설정: 프리셋 왼쫀, 같은 크기·스타일의 라벨 버튼 "⚙ 설정" (순서: 전체 초기화 · 설정 · 프리셋). 우상단 아이콘은
    -- 너무 구석이라 안 보인다는 지적(2026-09-14). 설정 창(장비 최적화 섹션 포함)을 연다
    local settingsBtn = CreateFrame("Button", nil, detail, "BackdropTemplate")
    settingsBtn:SetSize(76, 30)
    settingsBtn:SetPoint("RIGHT", presetBtn, "LEFT", -8, 0)
    settingsBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    settingsBtn:SetBackdropColor(1, 1, 1, 0.06)
    settingsBtn:SetBackdropBorderColor(1, 1, 1, 0.25)
    settingsBtn.label = FS(settingsBtn, "GameFontNormal", "|TInterface\\Buttons\\UI-OptionsButton:14:14|t " .. L["설정"])
    settingsBtn.label:SetPoint("CENTER")
    -- 전체 초기화는 설정 버튼 왼쪽으로 재배치 (설정 버튼이 뒤에 만들어지므로 여기서 앵커를 옮긴다)
    clearBtn:ClearAllPoints()
    clearBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -8, 0)
    settingsBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(1, 1, 1, 0.12)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["설정"], 1, 1, 1)
        GameTooltip:AddLine(L["장비 최적화 조절값(허용 하락폭·마나용제 변환 가정)과 전투 로그 옵션"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(1, 1, 1, 0.06)
        GameTooltip_Hide()
    end)
    settingsBtn:SetScript("OnClick", function() if WythicPlus_ToggleSettings then WythicPlus_ToggleSettings() end end)
    panel.settingsBtn = settingsBtn

    -- 강화 추천 라인 — 메타 일치지만 트랙 만렙 미달인 착용템 (코어 upgradePriorities)
    panel.upgradeLine = FS(detail, "GameFontHighlightSmall")
    panel.upgradeLine:SetPoint("TOP", detail, "TOP", 0, -170)

    -- 레이드 체크박스 (최적화 모드 전용, 버튼 오른쪽) — 해제 시 그 레이드 아이템은 추천에서 제외
    panel.excludedRaids = {}
    panel.raidChecks = {}
    panel.GetRaidCheck = function(i)
        local cb = panel.raidChecks[i]
        if cb then return cb end
        cb = CreateFrame("CheckButton", nil, detail, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb.label = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cb.label:SetPoint("LEFT", cb, "RIGHT", 1, 0)
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["레이드 필터"], 1, 1, 1)
            GameTooltip:AddLine(L["체크를 해제하면 이 레이드의 아이템을 추천 후보에서 제외합니다"], 0.6, 0.62, 0.68, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
        cb:SetScript("OnClick", function(self)
            if self.raidEn then
                panel.excludedRaids[self.raidEn] = (not self:GetChecked()) and true or nil
                WipeCustomKeepLocked() -- 필터 변경 시 핀 초기화 (웹과 동일, 잠긴 핀 보존)
                panel.presetRatings = nil
                if panel.Redraw then panel.Redraw() end
            end
        end)
        panel.raidChecks[i] = cb
        return cb
    end

    -- ── 아머리 ──
    local armoryTop = -224 -- 근접도 대형 표시 밴드(-186~-212) 아래 넉넉한 마진
    -- 셀 배치 기준 앵커 (모델 위치와 분리 — 모델만 내려도 슬롯 줄은 유지)
    local armoryAnchor = CreateFrame("Frame", nil, detail)
    armoryAnchor:SetSize(MODEL_W, 8 * ROW_H - 60)
    armoryAnchor:SetPoint("TOP", detail, "TOP", 0, armoryTop)
    panel.model = CreateFrame("PlayerModel", nil, detail)
    panel.model:SetSize(MODEL_W, 8 * ROW_H - 60)
    panel.model:SetPoint("TOP", detail, "TOP", 0, armoryTop - 78) -- 캐릭터 렌더는 무기 슬롯 쪽으로 (여유는 유지)

    -- 캐릭터 클래스 배경 (웹 히어로 배경과 결 맞춤) — 아머리 뷰 전역 커버, 없으면 클래스색 워시
    local classFile = select(2, UnitClass("player"))
    local classBg = detail:CreateTexture(nil, "BACKGROUND", nil, -6)
    classBg:SetPoint("TOPLEFT", detail, "TOPLEFT", 1, -180) -- 아머리 뷰 전체 풀블리드 (웹 히어로 스타일)
    classBg:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -1, 1)
    -- 웹과 동일한 블리자드 전투정보실 클래스 배경 — 애드온 번들 이미지 (1024x512, 2:1 센터크롭)
    local CLASS_BG_SLUG = {
        DEATHKNIGHT = "death_knight", DEMONHUNTER = "demon_hunter", DRUID = "druid", EVOKER = "evoker",
        HUNTER = "hunter", MAGE = "mage", MONK = "monk", PALADIN = "paladin", PRIEST = "priest",
        ROGUE = "rogue", SHAMAN = "shaman", WARLOCK = "warlock", WARRIOR = "warrior",
    }
    local slug = classFile and CLASS_BG_SLUG[classFile]
    if slug then
        classBg:SetTexture("Interface\\AddOns\\WythicPlus\\Textures\\ClassBG\\" .. slug .. ".png")
        classBg:SetAlpha(1)
        -- 웹 object-cover 재현: 이미지(2:1)를 프레임 비율로 중앙 크롭
        local bgW = PANEL_W - 2
        local bgH = (PANEL_H - 158) - 181
        local frameAspect = bgW / bgH
        local imgAspect = 2
        if imgAspect < frameAspect then
            local keep = imgAspect / frameAspect / 2
            classBg:SetTexCoord(0, 1, 0.5 - keep, 0.5 + keep)
        else
            local keep = frameAspect / imgAspect / 2
            classBg:SetTexCoord(0.5 - keep, 0.5 + keep, 0, 1)
        end
    else
        local cc = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if cc then
            classBg:SetTexture("Interface\\Buttons\\WHITE8X8")
            classBg:SetVertexColor(cc.r, cc.g, cc.b, 0.05)
        else
            classBg:Hide()
        end
    end
    panel.classBg = classBg

    -- 웹 히어로와 동일한 오버레이: 기본 0.15 + 좌우(→0.75)/상(0.5)/하(0.7) 가장자리 그라데이션 (rgba(9,9,11))
    local DKR, DKG, DKB = 0.035, 0.035, 0.043
    local baseScrim = detail:CreateTexture(nil, "BACKGROUND", nil, -5)
    baseScrim:SetTexture("Interface\\Buttons\\WHITE8X8")
    baseScrim:SetVertexColor(DKR, DKG, DKB, 0.15)
    baseScrim:SetAllPoints(classBg)
    if CreateColor then
        local function Grad(orient, a1, a2)
            local tx = detail:CreateTexture(nil, "BACKGROUND", nil, -4)
            tx:SetTexture("Interface\\Buttons\\WHITE8X8")
            if tx.SetGradient then
                tx:SetGradient(orient, CreateColor(DKR, DKG, DKB, a1), CreateColor(DKR, DKG, DKB, a2))
            else
                tx:SetVertexColor(DKR, DKG, DKB, (a1 + a2) / 2)
            end
            return tx
        end
        local gw = math.floor((PANEL_W - 2) * 0.3)
        local gl = Grad("HORIZONTAL", 0.6, 0) -- 좌: 진함 → 투명 (기본 0.15와 합쳐 0.75)
        gl:SetPoint("TOPLEFT", classBg, "TOPLEFT")
        gl:SetPoint("BOTTOMLEFT", classBg, "BOTTOMLEFT")
        gl:SetWidth(gw)
        local gr = Grad("HORIZONTAL", 0, 0.6)
        gr:SetPoint("TOPRIGHT", classBg, "TOPRIGHT")
        gr:SetPoint("BOTTOMRIGHT", classBg, "BOTTOMRIGHT")
        gr:SetWidth(gw)
        local gt = Grad("VERTICAL", 0, 0.5) -- 상: 위로 갈수록 진함
        gt:SetPoint("TOPLEFT", classBg, "TOPLEFT")
        gt:SetPoint("TOPRIGHT", classBg, "TOPRIGHT")
        gt:SetHeight(math.floor(((PANEL_H - 158) - 181) * 0.15))
        local gb = Grad("VERTICAL", 0.7, 0) -- 하: 아래로 갈수록 진함
        gb:SetPoint("BOTTOMLEFT", classBg, "BOTTOMLEFT")
        gb:SetPoint("BOTTOMRIGHT", classBg, "BOTTOMRIGHT")
        gb:SetHeight(math.floor(((PANEL_H - 158) - 181) * 0.2))
    end

    panel.cells = {}
    for i, slot in ipairs(LEFT_SLOTS) do
        local cell = CreateSlotCell(detail, slot, "LEFT")
        cell:SetPoint("TOPRIGHT", armoryAnchor, "TOPLEFT", -6, -(i - 1) * ROW_H)
        panel.cells[slot.key] = cell
    end
    for i, slot in ipairs(RIGHT_SLOTS) do
        local cell = CreateSlotCell(detail, slot, "RIGHT")
        cell:SetPoint("TOPLEFT", armoryAnchor, "TOPRIGHT", 6, -(i - 1) * ROW_H)
        panel.cells[slot.key] = cell
    end

    -- 무기 (하단 중앙, 모델에서 여유 있게 아래로)
    local mh = CreateBottomCell(detail, BOTTOM_SLOTS[1], "LEFT")
    mh:SetPoint("TOPRIGHT", armoryAnchor, "BOTTOM", -8, -64)
    panel.cells["MAIN_HAND"] = mh
    local oh = CreateBottomCell(detail, BOTTOM_SLOTS[2], "RIGHT")
    oh:SetPoint("TOPLEFT", armoryAnchor, "BOTTOM", 8, -64)
    panel.cells["OFF_HAND"] = oh

    panel.footer = DFS("GameFontNormal")
    panel.footer:SetTextColor(0.62, 0.62, 0.68)
    panel.footer:SetPoint("BOTTOM", detail, "BOTTOM", 0, 26)

    -- 애드온 버전 표기 (우하단 구석, 리사이즈 그립 위)
    do
        local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local ver = getMeta and getMeta("WythicPlus", "Version") or nil
        panel.version = DFS("GameFontDisableSmall")
        if not ver or ver:find("@") then
            panel.version:SetText("dev") -- 패키징 전(정션 개발 환경)
        else
            -- 패키저가 태그 이름(v 포함)을 그대로 넣으므로 v를 또 붙이지 않는다 ("vv1.6.18" 표기 버그)
            panel.version:SetText(ver:sub(1, 1) == "v" and ver or ("v" .. ver))
        end
        panel.version:SetTextColor(0.45, 0.45, 0.5)
        panel.version:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -20, 8)
    end

    -- 좌하단 사이트 홍보 박스 — 클릭 시 URL 복사 팝업
    local promo = CreateFrame("Button", nil, detail, "BackdropTemplate")
    promo:SetSize(264, 44)
    promo:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 14, 14)
    promo:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    promo:SetBackdropColor(0, 0.2, 0.26, 0.5)
    promo:SetBackdropBorderColor(0, 0.8, 1, 0.35)
    promo.icon = promo:CreateTexture(nil, "ARTWORK")
    promo.icon:SetSize(24, 24)
    promo.icon:SetPoint("LEFT", 9, 0)
    promo.icon:SetTexture("Interface\\AddOns\\WythicPlus\\Textures\\wyplus.png")
    promo.title = FS(promo, "GameFontNormal", L["|cff00ccff뱃지 리그|r 진행 중!"])
    promo.title:SetPoint("TOPLEFT", promo.icon, "TOPRIGHT", 8, 0)
    promo.sub = FS(promo, "GameFontHighlightSmall", L["내 순위는 몇 위일까? |cff00ccffwythic.com|r"])
    promo.sub:SetPoint("TOPLEFT", promo.title, "BOTTOMLEFT", 0, -2)
    promo.sub:SetTextColor(0.6, 0.63, 0.7)
    promo:SetScript("OnEnter", function(self) self:SetBackdropColor(0, 0.28, 0.36, 0.6) end)
    promo:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0.2, 0.26, 0.5) end)
    promo:SetScript("OnClick", function()
        if not panel.promoUrl then
            local uf = CreateFrame("Frame", nil, panel, "BackdropTemplate")
            uf:SetSize(320, 64)
            uf:SetPoint("CENTER")
            uf:SetFrameStrata("DIALOG")
            uf:EnableMouse(true)
            uf:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            uf:SetBackdropColor(0.07, 0.07, 0.1, 0.98)
            uf:SetBackdropBorderColor(0, 0.8, 1, 0.4)
            uf.hint = FS(uf, "GameFontHighlightSmall", L["Ctrl+C로 복사 · Esc로 닫기"])
            uf.hint:SetPoint("TOP", 0, -8)
            local ue = CreateFrame("EditBox", nil, uf)
            ue:SetSize(280, 20)
            ue:SetPoint("BOTTOM", 0, 12)
            ue:SetFontObject(GameFontHighlight)
            ue:SetAutoFocus(false)
            ue:SetJustifyH("CENTER")
            ue:SetScript("OnEscapePressed", function() uf:Hide() end)
            ue:SetScript("OnTextChanged", function(self, userInput)
                if userInput then
                    self:SetText("https://wythic.com")
                    self:HighlightText()
                end
            end)
            uf.edit = ue
            panel.promoUrl = uf
        end
        panel.promoUrl.edit:SetText("https://wythic.com")
        panel.promoUrl:Show()
        panel.promoUrl.edit:SetFocus()
        panel.promoUrl.edit:HighlightText()
    end)
    panel.promo = promo

    -- 최적화 토글 슬라이드 — 슬롯 컨텐츠가 모델 쪽으로 부드럽게 이동하며 추천 공간 확보
    panel.slideCur = 0 -- 0=기본(바깥), 1=최적화(안쪽)
    local slider = CreateFrame("Frame")
    slider:Hide()
    slider:SetScript("OnUpdate", function(self, dt)
        local target = panel.slideTarget or 0
        local cur = panel.slideCur + ((panel.slideTarget or 0) - panel.slideCur) * math.min(1, dt * 10)
        if math.abs(target - cur) < 0.005 then
            cur = target
            self:Hide()
        end
        panel.slideCur = cur
        local off = SLIDE_OUT * (1 - cur) - SLIDE_IN_EXTRA * cur
        for _, cell in pairs(panel.cells) do
            if cell.content then
                cell.content:ClearAllPoints()
                if cell.isLeft then
                    cell.content:SetPoint("RIGHT", cell, "RIGHT", -off, 0)
                else
                    cell.content:SetPoint("LEFT", cell, "LEFT", off, 0)
                end
            end
        end
    end)
    panel.slider = slider

    -- 아이템 캐시/장비/스펙 변경 시 재드로우
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterUnitEvent("UNIT_AURA", "player")
    ev:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
    ev:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "UNIT_AURA" then
            -- 버프 변화는 도핑 경고 문구만 갱신 (전체 재드로우는 시뮬 재실행이라 비쌈)
            if panel and panel:IsShown() then UpdateDopingNote() end
            return
        end
        if event == "UNIT_MODEL_CHANGED" then
            -- 변신·형상 변경은 모델만 다시 (드루이드 곰 변신 등)
            if panel and panel:IsShown() and panel.model then panel.model:SetUnit("player") end
            return
        end
        if event == "GET_ITEM_INFO_RECEIVED" then
            -- 우리가 요청한 아이템 응답만, 디바운스로 묶어서 재드로우 (모델은 건드리지 않음)
            if OnItemInfoReceived(arg1, arg2) and panel and panel:IsShown() then QueueRedraw() end
            return
        end
        -- 도감 로트 캐시의 링크는 조회 시점 전문화를 담고 있다 — 스펙 전환 시 버려서 새 스펙으로 재조회
        if event == "PLAYER_SPECIALIZATION_CHANGED" and WythicPlus_GearInvalidateEJLoot then
            WythicPlus_GearInvalidateEJLoot()
        end
        -- 장비·전문화 변경은 모델도 갱신 (외형이 바뀜)
        if panel then panel.modelDirty = true end
        if panel and panel:IsShown() then QueueRedraw() end
    end)

    ApplySkin()
end

-- ── 드로우 ────────────────────────────────────────────────────────────────────

local DONUT_DEFS = {
    { key = "stat", label = L["스탯"] },
    { key = "talent", label = L["특성"] },
    { key = "gear", label = L["장비"] },
    { key = "enchant", label = L["마법부여"] },
}

-- 바 안 숫자 배치 — 숫자가 바보다 넓으면(짧은 바) 바 오른쪽 바깥으로 빼서 라벨 침범 방지
local function PlaceBarNum(numFS, fill, barWidth)
    numFS:ClearAllPoints()
    if numFS:GetStringWidth() + 10 > barWidth then
        numFS:SetPoint("LEFT", fill, "RIGHT", 4, 0)
    else
        numFS:SetPoint("RIGHT", fill, "RIGHT", -5, 0)
    end
end

-- 쌍 슬롯(반지/장신구)에 같은 아이템 카드가 둘 뜨는 것 제거 — 웹 CharacterProfile effectiveSlots 말미와 같은 규칙.
-- 엔진 추천(시뮬)과 미일치 슬롯의 메타 대표 폴백(metaTop)은 서로 다른 경로라 같은 아이템이 두 슬롯에 갈 수 있다
-- (2026-09-26 제보: 레이드 제외한 부정 DK, 합산 후보가 '공명의 울림석' 하나뿐 → 엔진이 1번에, 폴백이 2번에 띄움).
-- 착용 ilvl이 낮은 슬롯에만 남기고(같으면 1번), 유저 핀은 지우지 않는다. 지운 슬롯은 보석·마부 줄만 남긴다.
-- 반환: 카드를 지운 슬롯 키 목록. (tests/pair-dedup.test.lua 가 미러 — 변경 시 함께 갱신)
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

local function Redraw(animate)
    if not panel or not panel:IsShown() then return end

    local entry = WythicPlus_LeaguePlayerEntry and WythicPlus_LeaguePlayerEntry()
    if entry and WythicPlus_LeagueLineParts then
        local left, right = WythicPlus_LeagueLineParts(entry)
        panel.league:SetText(left .. "  " .. right)
    else
        panel.league:SetText("")
    end

    -- 모델은 창을 열 때와 장비·전문화 변경 때만 다시 세팅 — 리드로우마다 SetUnit하면 모델이 재시작돼 떨린다
    if panel.modelDirty ~= false then
        panel.model:SetUnit("player")
        panel.modelDirty = false
    end
    UpdateDopingNote()

    local spec, err, specKey = GetCurrentSpecData()
    panel.specClass = specKey and specKey:match("^(.-)/") or nil -- 던전/레이드 탭 클래스 합산용
    if not spec then
        panel.optBtn:Hide()
        if panel.ownedBtn then panel.ownedBtn:Hide() end
        if panel.optBox then panel.optBox:Hide() end
        if panel.levelWarn then panel.levelWarn:Hide() end
        if panel.heroBtns then for _, hb in ipairs(panel.heroBtns) do hb:Hide() end end
        panel.improve:Hide()
        if panel.equipAllBtn then panel.equipAllBtn:Hide() end
        for _, cb in ipairs(panel.raidChecks) do cb:Hide(); cb.label:Hide() end
        panel.diagTitle:SetText("|cffff8080" .. (err or L["데이터 없음"]) .. "|r")
        panel.diagPct:SetText("")
        panel.gradeText:SetText("?")
        panel.gradeOuter:SetVertexColor(0.3, 0.3, 0.3)
        panel.gradeFill:SetVertexColor(0.3, 0.3, 0.3, 0.08)
        for _, d in ipairs(panel.donuts) do d.holder:Hide() end
        for _, cell in pairs(panel.cells) do
            if cell.slotKey == "MAIN_HAND" or cell.slotKey == "OFF_HAND" then FillBottomCell(cell, nil)
            else FillSlotCell(cell, nil) end
        end
        panel.footer:SetText("")
        return
    end
    panel.diagTitle:SetText(L["메타 일치율"])

    -- 영웅특성 기준 데이터 선택 — 웹 heroTreeId 토글과 동일 (기본: 내 활성 영웅특성 자동 감지).
    -- 데이터에 heroes(표본 10+ 트리 2개 이상)가 있을 때만 동작, 없으면 전체(스펙 합산) 기준.
    if panel.heroBaseSpec ~= spec then -- 전문화(또는 데이터) 변경 → 수동 선택 리셋
        panel.heroTreeId = nil
        panel.heroBaseSpec = spec
    end
    panel.heroList = spec.heroes
    if panel.heroList then
        local chosen = panel.heroTreeId
        if chosen == nil and C_ClassTalents and C_ClassTalents.GetActiveHeroTalentSpec then
            chosen = C_ClassTalents.GetActiveHeroTalentSpec()
        end
        local h = chosen and panel.heroList[chosen]
        if h and h.items then -- 표본 부족 스텁(표시 전용)은 선택 불가 — 전체 기준 유지
            panel.heroActive = chosen
            spec = h -- 이하 진단/시뮬/드롭다운 전부 이 트리 기준
        else
            panel.heroActive = nil
        end
    else
        panel.heroActive = nil
    end

    -- 최적화 모드: 시뮬 실행 (레이드 체크해제 + 유저 핀 반영) + 버튼 ↔ 개선 바 전환
    if panel.dropdown then panel.dropdown:Hide() end
    if panel.presetFrame then panel.presetFrame:Hide() end
    local sim = nil
    panel.curSpec = spec
    panel.effSpec = FilterSpecItems(spec, panel.excludedRaids)
    -- 소지품 기준용 메타: 후보가 내 소지품이라 레이드 체크(획득 경로 제외)는 무의미하고 체크박스도 비활성인데,
    -- 시뮬에 effSpec을 넘기면 toOwnedItems가 읽는 세트명·허용 타입·티어 ID·ilvl 상한이 체크 상태를 따라 바뀌어
    -- 메타 탭의 레이드 체크가 가방 추천을 흔들었다(2026-09-17 대표 제보). 저레벨 필터·쌍 슬롯 병합은 그대로 두고
    -- 레이드 제외만 없는 사본을 따로 쓴다.
    panel.ownedSpec = FilterSpecItems(spec, {})
    -- 잔존 링크 핀 정리 (핀 후 그 아이템을 착용했거나 더 높은 템을 착용한 경우 — 카드 숨김 규칙과 시뮬 반영이
    -- 어긋나지 않게 표시·수치 일관). 메타/도감 링크 핀은 "같은 ID + 착용 이하 레벨"이면 걷어낸다.
    -- 가방 사본 핀(srcTab "bags")은 같은 ID라도 다른 실물일 수 있으므로(2차 배분·ilvl이 다른 사본, 2026-09-20)
    -- 지금 착용한 실물 그 자체일 때만 걷어낸다: 링크가 같거나(가방→착용 이동), ID·ilvl·2차 스탯이 전부 같을 때.
    -- 이 정리가 선택 직후 Redraw에서 가방 사본 핀을 지워 "애니메이션은 도는데 카드가 없는" 증상을 냈다.
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
    for k, v in pairs(panel.pinnedItems) do
        if type(v) == "table" and v.link then
            local pc = panel.cells and panel.cells[k]
            local pwl = pc and pc.inv and GetInventoryItemLink("player", pc.inv)
            if pwl then
                local stale
                if v.srcTab == "bags" or v.srcTab == "craft" then
                    -- 제작 핀도 실물 기준: 같은 제작템을 다른 스탯으로 재제작하는 가정이면 유지
                    stale = PinIsWornInstance(v, pwl)
                else
                    stale = C_Item.GetItemInfoInstant(pwl) == v.item_id
                        and (v.ilvl or 0) <= (C_Item.GetDetailedItemLevelInfo(pwl) or 0)
                end
                if stale then
                    panel.pinnedItems[k] = nil
                    panel.pinnedConv[k] = nil
                end
            end
        end
    end
    -- 추천 해제 슬롯: 착용템을 내부 핀으로 주입해 "유지" 수치로 계산 (표시는 recInfo에서 숨김)
    local simPins = panel.pinnedItems
    if next(panel.dismissedSlots) then
        simPins = {}
        for k, v in pairs(panel.pinnedItems) do simPins[k] = v end
        for k in pairs(panel.dismissedSlots) do
            if simPins[k] == nil then
                local c = panel.cells[k]
                local link = c and c.inv and GetInventoryItemLink("player", c.inv)
                local iid = link and C_Item.GetItemInfoInstant(link)
                if iid then
                    simPins[k] = {
                        item_id = iid, link = link,
                        ilvl = C_Item.GetDetailedItemLevelInfo(link) or 0,
                        stats = (WythicPlus_GearLinkStats and WythicPlus_GearLinkStats(link)) or {},
                    }
                end
            end
        end
    end
    -- 트랙 핀 ①: 메타 아이템 핀(숫자)에 트랙이 골라져 있으면 그 트랙 ilvl 링크의 실제 스탯 핀으로 치환해
    -- 선고정 경로(LockPins)로 넘긴다. panel.pinnedItems는 건드리지 않음 — 카드 표기·토글 규칙은 숫자 핀 기준.
    if next(panel.pinnedTracks) then
        local conv = {}
        for k, v in pairs(simPins) do
            if type(v) == "number" and panel.pinnedTracks[k] then
                local link, tIlvl, st = TrackPinLinkStats(k, v, panel.pinnedConv[k])
                if link then conv[k] = { item_id = v, link = link, ilvl = tIlvl, stats = st, srcTab = "meta" } end
            end
        end
        if next(conv) then
            if simPins == panel.pinnedItems then
                simPins = {}
                for k, v in pairs(panel.pinnedItems) do simPins[k] = v end
            end
            for k, v in pairs(conv) do simPins[k] = v end
        end
    end
    -- 잠긴 부위: 핀 포함 그대로 전달 — 엔진이 잠긴 슬롯의 핀(가방 선택 포함)을 선고정하고
    -- 핀 없는 잠긴 슬롯은 착용 그대로 유지한다 (신규 추천/보석 추천은 붙지 않음)
    local simGemPins = panel.pinnedGems
    local locked = next(panel.lockedSlots) and panel.lockedSlots or nil
    -- 유저가 직접 고른 아이템의 부위는 홈을 뚫을 수 있다고 가정(랭커 보석 데이터가 있는 부위 = 홈 가능 부위, 1개).
    -- 착용템에 홈이 없어도 그 부위 보석 추천·선택이 계산된다. 자동 추천 부위는 기존대로 착용템 홈 기준.
    local socketSlots
    for k in pairs(panel.pinnedItems) do
        local g = spec.gems and spec.gems[k]
        if g and #g > 0 then
            socketSlots = socketSlots or {}
            socketSlots[k] = true
        end
    end
    if panel.optimize and panel.optMode == "owned" and WythicPlus_GearSimulateOwned then
        local bagBySlot = {}
        for key in pairs(SLOT_INVTYPE) do bagBySlot[key] = ScanBagsForSlot(key) end
        sim = WythicPlus_GearSimulateOwned(panel.ownedSpec, bagBySlot, simPins, panel.presetRatings, simGemPins, locked, socketSlots)
    elseif panel.optimize and WythicPlus_GearSimulate then
        sim = WythicPlus_GearSimulate(panel.effSpec, simPins, panel.presetRatings, simGemPins, locked, socketSlots)
    elseif (next(panel.pinnedItems) or next(panel.pinnedGems) or next(panel.pinnedEnchants)) and WythicPlus_GearCustomOnly then
        -- 최적화 OFF 커스텀: 착용 + 핀 차분만 (자동 추천 없음)
        sim = WythicPlus_GearCustomOnly(panel.effSpec, simPins, simGemPins)
    end
    -- 트랙 핀 ②: 아이템 핀 없이 트랙만 고른 슬롯은 시뮬 추천 아이템(메타 데이터 스탯)을
    -- 그 트랙 ilvl의 실제 스탯으로 차분 보정 — 카드가 보여주는 트랙 ilvl과 수치가 일치하도록.
    -- 가방 추천(ownedLinks)은 실제 소지템이라 트랙 개념 밖 → 제외 (카드도 트랙을 적용하지 않음).
    if sim and sim.slotRecommendations and next(panel.pinnedTracks) and WythicPlus_GearApplyDelta then
        local delta, any = { crit = 0, haste = 0, mastery = 0, versatility = 0 }, false
        for k in pairs(panel.pinnedTracks) do
            local rec = sim.slotRecommendations[k]
            if type(rec) == "number" and simPins[k] == nil and not (sim.ownedLinks and sim.ownedLinks[k]) then
                local link, _, st = TrackPinLinkStats(k, rec, nil)
                local base = link and MetaItemStats(panel.curSpec, k, rec)
                if base then
                    for _, s in ipairs({ "crit", "haste", "mastery", "versatility" }) do
                        delta[s] = delta[s] + (st[s] or 0) - (base[s] or 0)
                    end
                    any = true
                end
            end
        end
        if any then WythicPlus_GearApplyDelta(sim, panel.effSpec, delta) end
    end
    -- 마법부여 핀: 고른 마부(최고 등급 고정 2차 스탯) - 착용 마부 만큼 차분 반영 (계산 제외 마부는 0)
    if sim and sim.statRatios and WythicPlus_GearApplyDelta then
        local ed, eany = EnchantPinDelta()
        if eany then
            WythicPlus_GearApplyDelta(sim, (panel.optimize and panel.optMode == "owned") and panel.ownedSpec or panel.effSpec, ed)
        end
    end
    panel.lastSim = sim

    -- 레이드 체크박스 (최적화 모드에서만, 버튼 오른쪽)
    local raids = CollectRaids() or {} -- 항상 표시 (최적화 꺼짐 상태 포함)
    -- 소지품 기준: 후보가 내 소지품이라 레이드 출처 필터가 무의미 → 표시하되 비활성
    local raidsDisabled = sim and sim.ownedMode and true or false
    -- 1차: 내용/폭 측정 (중앙 정렬용)
    local raidRowW = 0
    for i = 1, #raids do
        local cb = panel.GetRaidCheck(i)
        local r = raids[i]
        cb.raidEn = r.en
        cb.label:SetText(r.ko)
        cb:SetChecked(not panel.excludedRaids[r.en])
        cb:SetEnabled(not raidsDisabled)
        cb:SetAlpha(raidsDisabled and 0.35 or 1)
        cb.label:SetAlpha(raidsDisabled and 0.35 or 1)
        raidRowW = raidRowW + 22 + 1 + cb.label:GetStringWidth() + (i > 1 and 12 or 0)
    end
    local raidLabelW = 0
    if #raids > 0 then
        raidLabelW = panel.raidLabel:GetStringWidth() + 10
        raidRowW = raidRowW + raidLabelW
    end
    if #raids == 0 then panel.raidLabel:Hide() end
    -- 2차: 박스 중앙 기준 배치
    for i = 1, math.max(#raids, #panel.raidChecks) do
        local cb = panel.raidChecks[i]
        if cb then
            if raids[i] then
                cb:ClearAllPoints()
                if i == 1 then
                    cb:SetPoint("TOPLEFT", panel.optBox, "TOP", -raidRowW / 2 + raidLabelW, panel.heroList and -84 or -60)
                    panel.raidLabel:ClearAllPoints()
                    panel.raidLabel:SetPoint("RIGHT", cb, "LEFT", -10, 0)
                    panel.raidLabel:SetShown(true)
                else
                    cb:SetPoint("LEFT", panel.raidChecks[i - 1].label, "RIGHT", 12, 0)
                end
                cb:Show(); cb.label:Show()
            else
                cb.raidEn = nil
                cb:Hide(); cb.label:Hide()
            end
        end
    end
    panel.optBox:Show()
    panel.optBtn:Show()
    panel.ownedBtn:Show()
    -- 프리셋 버튼에 현재 전문화 아이콘 (프리셋이 전문화별 저장임을 시각화)
    if panel.presetBtn then
        local _, _, _, specIcon = GetSpecializationInfo(GetSpecialization() or 0)
        panel.presetBtn.label:SetText((specIcon and ("|T" .. specIcon .. ":14:14|t ") or "") .. L["프리셋"])
    end
    local maxLv = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or 80
    panel.levelWarn:SetShown(UnitLevel("player") < maxLv)
    -- 영웅특성 토글 행 (제목 아래) — 표본 내림차순, 활성 트리 강조
    local heroShown = panel.heroList ~= nil
    local heroCount = 0
    if heroShown then
        local list = {}
        for id, h in pairs(panel.heroList) do list[#list + 1] = { id = id, h = h } end
        table.sort(list, function(a, b) return (a.h.sample or 0) > (b.h.sample or 0) end)
        local heroTotal = math.min(#list, 2) -- 트리가 하나면 중앙 배치
        local cfg = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
        for i, e in ipairs(list) do
            if i > 2 then break end -- 스펙당 영웅특성은 2개
            heroCount = heroCount + 1
            local b = panel.GetHeroBtn(i)
            b.treeId = e.id
            -- 인게임 로컬라이즈 이름·공식 아이콘 우선 (C_Traits.GetSubTreeInfo), 없으면 수집 표기
            local nm = e.h.name or ""
            local atlas = nil
            if cfg and C_Traits and C_Traits.GetSubTreeInfo then
                local ok, info = pcall(C_Traits.GetSubTreeInfo, cfg, e.id)
                if ok and info then
                    if info.name and info.name ~= "" then nm = info.name end
                    atlas = info.iconElementID
                end
            end
            if type(atlas) == "string" and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
                b.icon:SetAtlas(atlas)
                b.icon:Show()
            elseif type(atlas) == "number" and atlas > 0 then
                b.icon:SetTexture(atlas) -- 일부 빌드는 파일ID로 반환
                b.icon:Show()
            else
                b.icon:Hide()
            end
            local full = e.h.items ~= nil -- 표본 10+ = 데이터 있음, 아니면 표시 전용 스텁
            local on = full and (e.id == panel.heroActive)
            b.activeHero = on
            b.heroDisabled = not full
            b.heroSample = e.h.sample or 0
            local nameHex = on and "|cffffffff" or (full and "|cffb9bcc4" or "|cff6b6f78")
            b.label:SetText(nameHex .. nm .. "|r  |cff9ca3af" .. string.format(L["%d명"], e.h.sample or 0) .. "|r")
            b:SetBackdropColor(1, 1, 1, on and 0.10 or 0.04)
            b:SetBackdropBorderColor(full and AMBER[1] or 1, full and AMBER[2] or 1, full and AMBER[3] or 1,
                on and 0.9 or (full and 0.15 or 0.06))
            b.icon:SetDesaturated(not on)
            b.icon:SetAlpha(full and 1 or 0.4)
            b:SetAlpha(full and 1 or 0.6)
            -- 내용(아이콘+이름+표본) 중앙 정렬 — 텍스트 폭 기준으로 시작 위치 계산
            local iconW = b.icon:IsShown() and 24 or 0 -- 아이콘 20 + 간격 4
            local contentW = iconW + b.label:GetStringWidth()
            local startX = math.max(5, (b:GetWidth() - contentW) / 2)
            b.label:ClearAllPoints()
            if iconW > 0 then
                b.icon:ClearAllPoints()
                b.icon:SetPoint("LEFT", startX, 0)
                b.label:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
            else
                b.label:SetPoint("LEFT", startX, 0)
            end
            b:ClearAllPoints()
            if heroTotal == 1 then
                b:SetPoint("TOP", panel.optBox, "TOP", 0, -26) -- 단일 트리 = 중앙 (의미는 호버 툴팁으로)
            elseif i == 1 then
                b:SetPoint("TOPLEFT", panel.optBox, "TOPLEFT", 14, -26)
            else
                b:SetPoint("TOPRIGHT", panel.optBox, "TOPRIGHT", -14, -26)
            end
            b:Show()
        end
    end
    panel.heroCaption:Hide() -- 캡션 미사용 (호버 툴팁으로 안내)
    for i = heroCount + 1, #panel.heroBtns do panel.heroBtns[i]:Hide() end
    -- 모드 버튼 오프셋 (영웅특성 행 유무 따라)
    local modeY = heroShown and -50 or -28
    panel.optBtn:ClearAllPoints()
    panel.optBtn:SetPoint("TOPLEFT", panel.optBox, "TOPLEFT", 14, modeY)
    panel.ownedBtn:ClearAllPoints()
    panel.ownedBtn:SetPoint("TOPRIGHT", panel.optBox, "TOPRIGHT", -14, modeY)
    local metaOn = panel.optimize and panel.optMode ~= "owned"
    local ownedOn = panel.optimize and panel.optMode == "owned"
    local function SetModeActive(b, on)
        local c = b.baseColor or AMBER
        b.active = on
        b:SetBackdropColor(c[1], c[2], c[3], on and 0.22 or 0.08)
        b:SetBackdropBorderColor(c[1], c[2], c[3], on and 0.95 or 0.35)
    end
    SetModeActive(panel.optBtn, metaOn)
    SetModeActive(panel.ownedBtn, ownedOn)
    -- 전체 초기화: 커스텀(핀·보석·트랙·해제)이 하나라도 있으면 표시
    if panel.clearBtn then
        panel.clearBtn:SetShown(next(panel.pinnedItems) ~= nil or next(panel.pinnedGems) ~= nil or next(panel.pinnedEnchants) ~= nil
            or next(panel.pinnedTracks) ~= nil or next(panel.dismissedSlots) ~= nil)
    end
    -- 박스 높이: 제목 + 모드 버튼 + 레이드 줄(항상 표시, 소지품 모드는 비활성) — 영웅특성 행만 가변
    local heroPad = heroShown and 24 or 0
    panel.optBox:SetHeight(heroPad + 90)
    -- 슬롯 컨텐츠 슬라이드 (기본 ↔ 최적화) — 기본 화면은 비슬라이드, 착용 보석은 안쪽에 표시
    panel.slideTarget = (panel.optimize or (sim and sim.customOnly)) and 1 or 0
    if panel.slideCur ~= panel.slideTarget then panel.slider:Show() end
    if sim then
        panel.improve.text:SetText(string.format(L["|cffcfcfcf메타 근접도|r  %.1f점 → |cffffb454%.1f점|r"],
            100 - sim.originalDistance, 100 - sim.finalDistance))
        panel.improve:Show()
    else
        panel.improve:Hide()
        if panel.equipAllBtn then panel.equipAllBtn:Hide() end
    end
    -- 부위 잠금 안내: 최적화(메타/소지품) 상태에서만 의미 있는 기능이라 그때만 노출
    if panel.lockHint then panel.lockHint:SetShown(panel.optimize == true) end

    local diag = WythicPlus_GearDiagnose and WythicPlus_GearDiagnose(spec)
    local slotsByKey = {}
    if diag then
        if diag.gear and diag.gear.slots then
            for _, s in ipairs(diag.gear.slots) do slotsByKey[s.slot] = s end
        end

        -- 등급 원 + 일치율
        local r, g, b = gradeRGB(diag.grade)
        panel.gradeOuter:SetVertexColor(r, g, b)
        -- 내부 채움 없음 (웹과 동일 — 투명 원 + 테두리 링만)
        panel.gradeText:SetText(string.format("|cff%s%s|r", GRADE_HEX[diag.grade] or "9d9d9d", diag.grade))
        panel.diagPct:SetText(string.format("|cff%s%d|r|cffffffff%%|r", GRADE_HEX[diag.grade] or "9d9d9d", diag.overall))

        -- 도넛 (존재하는 카테고리만, 순서: 스탯 특성 장비 마법부여)
        local di = 0
        for _, def in ipairs(DONUT_DEFS) do
            local cat = diag[def.key]
            if cat then
                di = di + 1
                local d = panel.donuts[di]
                local grade = scoreGrade(cat.score)
                local rr, gg, bb = gradeRGB(grade)
                -- 원호를 점수만큼 채움 (트랙 링은 어두운 고정색)
                d.arc:SetSwipeColor(rr, gg, bb, 1)
                local pct = math.max(0.01, math.min(1, (cat.score or 0) / 100))
                -- 정적 원호: 짧은 쿨다운을 원하는 진행률에서 Pause (음수 시작시각은 렌더 안 됨)
                local DUR = 100
                if d.arc.Resume then d.arc:Resume() end
                d.arc:SetCooldown(GetTime() - DUR * pct, DUR)
                if d.arc.Pause then d.arc:Pause() end
                d.num:SetText(string.format("|cff%s%d|r", GRADE_HEX[grade] or "ffffff", cat.score))
                d.label:SetText(def.label)
                d.holder:Show()
            end
        end
        for i = di + 1, 4 do panel.donuts[i].holder:Hide() end
    end

    -- 스탯 비교 바
    local comps = diag and diag.stat and diag.stat.stats
    local playerName = UnitName("player") or L["내 캐릭터"]
    if comps then
        -- 시뮬 결과를 스탯별로 인덱싱 (최적화 모드에서 바 델타 표시)
        local simByStat = {}
        if sim and sim.statRatios then
            for _, r in ipairs(sim.statRatios) do simByStat[r.stat] = r end
        end
        -- 막대 길이 기준 = 스탯 % (우측 % 표기와 같은 기준). 사용자가 비교하는 값은 %이고 최적화 증감(노란
        -- 세그먼트)도 "현재 % → 추천 반영 %"로 보여야 우측 %와 맞는다. 막대 안 숫자(레이팅)는 라벨일 뿐 길이
        -- 기준이 아니다 — v1.6.18에서 길이를 레이팅으로 바꿨더니 추천 반영 55.29% > 메타 54.90%인데 막대는
        -- 짧게(953 < 1,018) 그려져 되돌림(2026-09-12). 전역 최대에 시뮬 %도 포함해 증감분이 막대를 넘지 않게.
        local maxPct = 1
        for _, c in ipairs(comps) do
            if c.myValue > maxPct then maxPct = c.myValue end
            if c.metaValue > maxPct then maxPct = c.metaValue end
            local sr = simByStat[c.name]
            if sr and sr.simPct and sr.simPct > maxPct then maxPct = sr.simPct end
        end
        for _, c in ipairs(comps) do
            local row = panel.statRows[c.name]
            if row then
                row.meLab:SetText(playerName)
                local rating = CR_BY_STAT[c.name] and GetCombatRating(CR_BY_STAT[c.name]) or nil
                local myW = math.max(1, row.myMax * math.min(c.myValue / maxPct, 1))
                local sr = simByStat[c.name]
                -- 변동 수치 "장비 +N 보석 +M" (웹과 동일: 장비 emerald/red, 보석 blue/orange)
                if sr then
                    local gearD = math.floor((sr.gearOnlyRating - sr.currentRating) + 0.5)
                    local gemD = math.floor((sr.simRating - sr.gearOnlyRating) + 0.5)
                    local parts = {}
                    if gearD ~= 0 then parts[#parts + 1] = string.format(L["|cff%s장비 %+d|r"], gearD > 0 and "34d399" or "f87171", gearD) end
                    if gemD ~= 0 then parts[#parts + 1] = string.format(L["|cff%s보석 %+d|r"], gemD > 0 and "60a5fa" or "fb923c", gemD) end
                    row.deltaLab:SetText(table.concat(parts, "  "))
                else
                    row.deltaLab:SetText("")
                end
                -- 코어 currentRating은 아이템+보석 합산(인챈트·음식/룬 버프 미포함)이라 인게임 레이팅보다 작다.
                -- 웹(CharacterProfile enchantGap)과 동일하게 그 차이를 더해 "인게임 레이팅 + 변동"으로 표기 —
                -- 안 하면 최적화 켤 때 라벨이 1121→897처럼 뚝 떨어져 보인다(보석 −27인데, 2026-09-09 제보).
                local gap = (sr and rating and sr.currentRating > 0) and (rating - sr.currentRating) or 0
                local curR = sr and (sr.currentRating + gap) or 0
                if sr and curR > 0 then
                    -- 추천 반영값: 증가분 amber / 감소분 red 세그먼트 — 길이는 "현재 % → 시뮬 %" 차이 그대로
                    local simR = sr.simRating + gap
                    local simPct = sr.simPct or c.myValue
                    local simW = math.max(1, row.myMax * math.min(simPct / maxPct, 1))
                    local baseW = math.min(myW, simW)
                    row.myFill:SetWidth(baseW)
                    if math.abs(simW - myW) < 0.5 then
                        row.deltaFill:Hide()
                    else
                        if simW > myW then
                            row.deltaFill:SetVertexColor(AMBER[1], AMBER[2], AMBER[3], 0.85)
                        else
                            row.deltaFill:SetVertexColor(0.937, 0.267, 0.267, 0.5) -- #ef4444: 줄어든 만큼 빨강
                        end
                        row.deltaFill:SetWidth(math.abs(simW - myW))
                        row.deltaFill:Show()
                    end
                    row.myNum:SetText(BreakUpLargeNumbers(math.floor(simR + 0.5)))
                    PlaceBarNum(row.myNum, row.myFill, baseW)
                    row.myPct:SetText(string.format("|cffffb454%.2f%%|r", simPct))
                else
                    row.myFill:SetWidth(myW)
                    row.deltaFill:Hide()
                    row.myNum:SetText(rating and BreakUpLargeNumbers(rating) or "")
                    PlaceBarNum(row.myNum, row.myFill, myW)
                    row.myPct:SetText(string.format("%.2f%%", c.myValue))
                end
                local metaRating = spec.stats and spec.stats[c.name .. "_rating"]
                local metaW = math.max(1, row.myMax * math.min(c.metaValue / maxPct, 1))
                row.metaFill:SetWidth(metaW)
                row.metaNum:SetText(metaRating and BreakUpLargeNumbers(math.floor(metaRating + 0.5)) or "")
                PlaceBarNum(row.metaNum, row.metaFill, metaW)
                row.metaPct:SetText(string.format("%.2f%%", c.metaValue))
            end
        end
    end

    -- 인챈트 개선 대상 (미매칭 슬롯 → 메타 1위 인챈트 이름; 반지 포함)
    local enchBySlot = {}
    if sim and diag and diag.enchant and diag.enchant.enchants then
        local names = WythicPlusGearData.enchantNames or {}
        for _, e in ipairs(diag.enchant.enchants) do
            if not e.matched and e.metaTopEnchantId then
                local en = names[e.metaTopEnchantId]
                local nm = EnchantName(en)
                if nm and nm ~= "" then
                    -- [2]=품질(이름 색), [3]=두루마리 아이템ID(툴팁용)
                    enchBySlot[e.slot] = { name = nm, quality = en[2], itemId = en[3] }
                end
            end
        end
    end

    -- 아머리 (추천 = 최적화 모드의 시뮬 결과만; 기본 모드는 체크/이름만 — 웹과 동일)
    -- 미일치 슬롯의 메타 대표(metaTop) 재선택 — 웹 CharacterProfile와 동일하게
    -- 공유 코어 reselectMetaTopsCore 호출 (레이드 필터 제외·타 슬롯 착용/추천 중복 회피
    -- 규칙은 코어 한 벌만 존재). 진단의 절대 순위 라벨은 그대로 원본 spec 기준.
    local resolvedTops
    if sim and WythicPlusGearCore and WythicPlusGearCore.reselectMetaTopsCore then
        local srcMap = WythicPlusGearData.sources or {}
        local function srcObj(id)
            local s = srcMap[id]
            return { item_id = id, source_type = s and s[1] or nil, source_name_en = s and s[3] or nil }
        end
        local corePop = {} -- effSpec(레이드+저레벨 필터 후) 후보 + 출처 필드
        for slotKey, list in pairs((panel.effSpec.items) or {}) do
            local arr = {}
            for i = 1, #list do arr[i] = srcObj(list[i][1]) end
            corePop[slotKey] = arr
        end
        local equippedIds = {} -- itemId → 착용 슬롯 (다른 슬롯 착용템 중복 회피용)
        for key2, cell2 in pairs(panel.cells) do
            local link2 = cell2.inv and GetInventoryItemLink("player", cell2.inv)
            local id2 = link2 and C_Item.GetItemInfoInstant(link2)
            if id2 then equippedIds[id2] = key2 end
        end
        local baseSlots = {}
        for key2 in pairs(panel.cells) do
            local ds = slotsByKey[key2]
            local engineRec = sim.slotRecommendations and sim.slotRecommendations[key2]
            local mt
            if type(engineRec) == "number" then
                mt = srcObj(engineRec) -- 엔진 추천을 선점시켜 쌍 슬롯 중복 회피에 반영
            elseif ds and ds.metaTop and ds.metaTop.item_id then
                mt = srcObj(ds.metaTop.item_id)
            end
            baseSlots[#baseSlots + 1] = { slot = key2, metaTop = mt }
        end
        resolvedTops = WythicPlusGearCore.reselectMetaTopsCore(
            nil, baseSlots, corePop, panel.excludedRaids, equippedIds)
    end
    local recInfos = {} -- 슬롯별 카드 내용. 쌍 슬롯 중복을 걸러낸 뒤 그린다
    for key, cell in pairs(panel.cells) do
        local recInfo = nil
        if sim then
            local diagSlot = slotsByKey[key]
            -- 유저 핀은 시뮬 결과와 무관하게 무조건 표시 (수치는 ApplyPins가 반영)
            local pin = panel.pinnedItems[key]
            if pin then
                if type(pin) == "table" then
                    recInfo = { itemId = pin.item_id, bagLink = pin.link, bagIlvl = pin.ilvl, srcTab = pin.srcTab,
                        pinConv = panel.pinnedConv[key] } -- 프리셋 복원 메타 핀의 변형 유지
                    if pin.srcTab == "craft" then -- 제작 탭 핀: 칩 "제작 · 지정 스탯", 툴팁 스탯 보정
                        recInfo.craftStats = pin.stats
                        recInfo.craftLabel = CraftLabel(pin) .. (LinkEmbellished(pin.link) and (" · " .. L["장식"]) or "")
                    end
                else
                    recInfo = { itemId = pin, pinConv = panel.pinnedConv[key] }
                end
            elseif sim.slotRecommendations and not panel.dismissedSlots[key] then
                local rid = sim.slotRecommendations[key]
                if type(rid) == "number" then recInfo = { itemId = rid } end
                if recInfo and sim.ownedLinks and sim.ownedLinks[key] then
                    local ol = sim.ownedLinks[key]
                    if ol.convFrom then
                        -- 마나용제 변환 가정 추천: 티어 아이템 ID + 원본의 보너스ID + modifier 64(원본 스탯 계승)로
                        -- 링크를 조립해 게임이 "변환 후 모습"(티어 이름·세트 효과, 원본 ilvl·2차 배분)을 그리게 한다
                        local parts = LinkSimcParts(ol.link)
                        local bonuses = parts and table.concat(parts.bonuses, ":") or ""
                        recInfo.bagLink = BuildItemLink(rid, bonuses, ol.convFrom)
                        recInfo.convFrom, recInfo.convLink, recInfo.convWorn = ol.convFrom, ol.link, ol.convWorn
                        EnsureItem(rid)
                    else
                        recInfo.bagLink = ol.link
                    end
                    recInfo.bagIlvl = ol.ilvl
                end
            end
            -- 웹과 동일: 시뮬이 "유지"여도 메타 미일치 슬롯엔 metaTop 폴백 추천 (티어 유지 슬롯 등)
            -- 단, 유저가 착용템을 핀으로 고른 슬롯(=의도적 유지)엔 폴백을 띄우지 않는다
            if not recInfo and diagSlot and not diagSlot.matched and diagSlot.metaTop
                and not panel.pinnedItems[key] and not sim.customOnly and not sim.ownedMode
                and not panel.dismissedSlots[key] and not panel.lockedSlots[key] then
                -- 코어 재선택 결과 사용 — 제외/중복으로 대체 불가면 카드 없음 (웹과 동일)
                local rt = resolvedTops and resolvedTops[key]
                if rt and rt.item_id then
                    recInfo = { itemId = rt.item_id }
                elseif not resolvedTops then
                    recInfo = { itemId = diagSlot.metaTop.item_id } -- 코어 미로드 시 원동작
                end
            end
            if recInfo then
                recInfo.ilvl, recInfo.bonuses, recInfo.conv = MetaItemInfo(spec, key, recInfo.itemId, recInfo.pinConv)
                recInfo.rank = MetaRankOf(spec, key, recInfo.itemId, recInfo.conv or "")
                local s = (WythicPlusGearData.sources or {})[recInfo.itemId]
                if s then
                    recInfo.srcType = s[1]
                    recInfo.srcName = s[2]
                    recInfo.srcNameEn = s[3]
                end
                -- 가방 핀: 실제 소지 아이템의 ilvl 표기
                if recInfo.bagLink then
                    recInfo.ilvl = recInfo.bagIlvl or recInfo.ilvl
                end
                -- 트랙 핀: 표기 ilvl을 선택 트랙 만렙으로 (스탯 수치는 유지 — 선형 추정 금지)
                -- 맹독저주(VENOM)는 대상 4종에만 적용
                local pt = panel.pinnedTracks[key]
                if pt and not recInfo.bagLink then
                    local ok
                    if pt == "VENOM" then
                        ok = (WythicPlusGearData.venom and WythicPlusGearData.venom.items
                            and WythicPlusGearData.venom.items[recInfo.itemId]) ~= nil
                    else
                        -- 트랙 단계 ID가 없는 아이템(맹독저주 등 고정템)엔 트랙 적용 불가
                        ok = HasTrackStep(recInfo.bonuses)
                    end
                    if ok then
                        recInfo.ilvl = TrackMaxIlvl(pt, recInfo.srcType == "crafted") or recInfo.ilvl
                        recInfo.trackPinned = true
                    end
                end
            end
            panel.lastRecs[key] = recInfo and recInfo.itemId or nil
            -- 보석: 핀 우선, 없으면 시뮬 추천 (코어 인덱스는 0-based → Lua 배열 +1). 핀 0 = 보석 해제(빈 홈)
            local gemId = sim.gemPins and sim.gemPins[key] or nil
            local gemNone = gemId == 0
            if gemNone then gemId = nil end
            if not gemId and not gemNone then
                local gi = sim.gemRecommendations and sim.gemRecommendations[key]
                if gi ~= nil and sim.gemIdsBySlot and sim.gemIdsBySlot[key] then
                    gemId = sim.gemIdsBySlot[key][gi + 1]
                end
            end
            -- 추천 레인(화살표가 슬롯을 가리키는 줄)에는 **실제 추천 보석과 유저 핀만** 둔다. 빈 홈 자리표시를 여기
            -- 두면 옆의 진짜 보석 추천과 같은 모양이라 "빈 걸로 바꿔라(=빼라)"로 읽힌다(2026-09-12 지시).
            -- 최적화 중 바꿀 필요가 없는 부위는 보석 관련 아무것도 뜨지 않는다.
            -- 빈 홈 안내는 아래 기본 화면 경로에서 착용 아이콘 옆 상태 줄로 낸다.
            local ench = enchBySlot[key]
            -- 유저가 직접 고른 부위: 마부 줄 = 고른 마부 → (메타 추천) → 착용 마부 유지 → "마법부여 선택" 안내.
            -- 마부 줄을 누르면 마법부여 선택창. 고른 마부는 아이템 핀 없이도 표시(부위 기준 핀)
            local userPicked = panel.pinnedItems[key] ~= nil
            local pe = EnchantByName(panel.pinnedEnchants[key])
            if pe then
                EnsureItem(pe.item2)
                ench = { name = EnchantShortName(pe), quality = C_Item.GetItemQualityByID(pe.item2), itemId = pe.item2 }
            elseif userPicked and not ench and #EnchantsForSlot(key) > 0 then
                local wid = WornEnchantId(key)
                local wn = wid and (WythicPlusGearData.enchantNames or {})[wid]
                ench = { name = wn and (EnchantName(wn) .. L[" (유지)"]) or L["✧ 마법부여 선택"],
                    quality = wn and wn[2] or nil, itemId = wn and wn[3] or nil }
            end
            -- 유저가 직접 고른 부위(홈 가정): 보석이 없으면 빈 홈 줄 — 누르면 보석 선택창
            local gemEmpty = userPicked and socketSlots ~= nil and socketSlots[key] == true and not gemId and not gemNone
            if gemId or ench or gemNone or gemEmpty then
                recInfo = recInfo or {}
                recInfo.gemId = gemId
                recInfo.gemNone = gemNone
                recInfo.gemEmpty = gemEmpty or nil
                recInfo.ench = ench and ench.name or nil
                recInfo.enchQuality = ench and ench.quality or nil
                recInfo.enchItemId = ench and ench.itemId or nil
            end
        end
        -- 기본 모드: 장착 보석을 추천 카드와 같은 독립 줄로 노출 — 클릭하면 보석만 커스텀.
        -- 커스텀(최적화 꺼짐 + 핀) 모드도 핀·해제·아이템 핀이 없는 부위는 똑같이 장착 보석을 유지한다 —
        -- 한 부위를 해제했다고 다른 부위의 보석 줄까지 "보석 선택"으로 바뀌면 안 된다 (2026-09-12 지적).
        local keepWorn = (not sim) or (sim.customOnly == true
            and not (recInfo and (recInfo.itemId or recInfo.gemId or recInfo.gemNone)))
        if keepWorn then
            local wlink = cell.inv and GetInventoryItemLink("player", cell.inv)
            local gids = wlink and WythicPlus_GearLinkGems and WythicPlus_GearLinkGems(wlink)
            if gids and gids[1] then
                if recInfo then
                    recInfo.gemId, recInfo.gemWorn, recInfo.gemEmpty = gids[1], true, false
                else
                    recInfo = { gemId = gids[1], gemWorn = true }
                end
            else
                -- 빈 홈: 착용 아이콘 옆 상태 줄로 안내(클릭하면 보석 선택창). 추천 레인이 아니라 "빼라"로 읽히지 않는다.
                -- 진짜 빈 홈(홈 수 > 낀 보석 수)이고 그 부위에 메타 보석 데이터가 있을 때만 — 슬롯 우클릭 진입은
                -- v1.6.13에서 없앴으므로 이 줄이 빈 홈의 유일한 진입점이다.
                local sockets = wlink and WythicPlus_GearSocketCount and WythicPlus_GearSocketCount(wlink) or nil
                if sockets ~= nil and sockets > (gids and #gids or 0)
                    and spec.gems and spec.gems[key] and #spec.gems[key] > 0 then
                    recInfo = recInfo or {}
                    recInfo.gemEmpty = true
                    recInfo.gemWorn = true -- 착용 아이콘 옆 배치 (추천 레인 아님)
                end
            end
        end
        recInfos[key] = recInfo
    end
    -- 쌍 슬롯(반지/장신구) 같은 아이템 중복 카드 제거 — 지운 슬롯은 "추천 없음"(일괄 장착·ilvl 차분에서도 제외)
    local ilvlOf = function(k) local d = slotsByKey[k]; return d and d.myItemLevel or 0 end
    for _, k in ipairs(DropPairDuplicates(recInfos, ilvlOf, panel.pinnedItems)) do
        panel.lastRecs[k] = nil
    end
    -- 장식 3개 이상 경고 — 화면의 최종 구성(핀·추천 카드, 없으면 착용템) 기준. 장식 장비는 링크/보너스에
    -- 장식 표지(8960 등) 또는 장식 효과 ID가 있다. 장식 효과의 가치는 계산하지 않으므로 개수만 알린다
    if panel.embWarn then
        local embCount = 0
        for key2, cell2 in pairs(panel.cells) do
            local ri = recInfos[key2]
            local isEmb = false
            if ri and ri.itemId then
                if ri.bagLink then isEmb = LinkEmbellished(ri.bagLink)
                elseif ri.bonuses then isEmb = BonusesEmbellished(ri.bonuses) end
            else
                local wl2 = cell2.inv and GetInventoryItemLink("player", cell2.inv)
                isEmb = wl2 ~= nil and LinkEmbellished(wl2)
            end
            if isEmb then embCount = embCount + 1 end
        end
        if embCount >= 3 then
            panel.embWarn:SetText("|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:12:12:0:0|t |cfff87171"
                .. string.format(L["장식 %d개 — 장식은 최대 2개까지만 착용할 수 있습니다"], embCount) .. "|r")
            panel.embWarn:Show()
        else
            panel.embWarn:SetText("")
            panel.embWarn:Hide()
        end
    end
    for key, cell in pairs(panel.cells) do
        local recInfo = recInfos[key]
        -- 프리셋 저장용 현재 화면 스냅샷 (아이템/마부/보석 추천 최종 상태)
        panel.lastView[key] = recInfo and {
            itemId = recInfo.itemId, bagLink = recInfo.bagLink, ilvl = recInfo.ilvl, convFrom = recInfo.convFrom,
            bonuses = recInfo.bonuses, conv = recInfo.conv, ench = recInfo.ench, enchItemId = recInfo.enchItemId,
            gemId = recInfo.gemId, gemNone = recInfo.gemNone,
            craft = (recInfo.srcTab == "craft") or nil, -- 제작 가정(미보유) — 일괄 착용 대상 아님
        } or nil
        if key == "MAIN_HAND" or key == "OFF_HAND" then
            FillBottomCell(cell, slotsByKey[key], recInfo, animate)
        else
            FillSlotCell(cell, slotsByKey[key], recInfo, animate)
        end
        -- 잠금 배지: 선택(핀/추천)이 표시 중이면 그 카드에, 아니면 착용 아이콘에
        local lockedHere = panel.optimize == true and panel.lockedSlots[key] == true
        local selShown = lockedHere and recInfo ~= nil and recInfo.itemId ~= nil
        if cell.lock then cell.lock:SetShown(lockedHere and not selShown) end
        if cell.rec and cell.rec.lock then cell.rec.lock:SetShown(selShown) end
    end

    -- 근접도 오른쪽 아이템 레벨: 현재(게임 착용 평균) → 추천 반영. 추천 부위의 표기 ilvl(가방 실물/트랙/수집)로
    -- 착용 ilvl을 치환한 차분을 16슬롯 평균에 더한다. 양손 무기(보조 비어 있음)는 게임 규칙대로 두 슬롯으로 센다.
    if sim and panel.improve.ilvl then
        local _, curAvg = GetAverageItemLevel()
        curAvg = curAvg or 0
        local mhLink, ohLink = GetInventoryItemLink("player", 16), GetInventoryItemLink("player", 17)
        local mh2h = false
        if mhLink and not ohLink then
            local _, _, _, eloc = C_Item.GetItemInfoInstant(mhLink)
            mh2h = eloc == "INVTYPE_2HWEAPON" or eloc == "INVTYPE_RANGED" or eloc == "INVTYPE_RANGEDRIGHT"
        end
        local delta = 0
        for key, cell in pairs(panel.cells) do
            local v = panel.lastView[key]
            if v and v.itemId and v.ilvl and v.ilvl > 0 and cell.inv then
                local wlink = GetInventoryItemLink("player", cell.inv)
                local worn = wlink and (C_Item.GetDetailedItemLevelInfo(wlink) or 0) or 0
                local d = v.ilvl - worn
                if key == "MAIN_HAND" and mh2h then d = d * 2 end
                delta = delta + d
            end
        end
        local after = curAvg + delta / 16
        if math.abs(after - curAvg) < 0.05 then
            panel.improve.ilvl:SetText(string.format(L["|cff9a9a9a아이템 레벨|r  %.1f"], curAvg))
        else
            local hex = after > curAvg and "7ddc7d" or "ff7a7a"
            panel.improve.ilvl:SetText(string.format(L["|cff9a9a9a아이템 레벨|r  %.1f → |cff%s%.1f|r"], curAvg, hex, after))
        end
        panel.improve.ilvl:Show()
    elseif panel.improve.ilvl then
        panel.improve.ilvl:Hide()
    end
    -- 가방 추천 일괄 착용 버튼: 실제 가방 아이템 추천/선택이 하나라도 있을 때만 (전투 중엔 흐리게)
    if panel.equipAllBtn then
        local list = CollectBagEquips()
        panel.equipAllBtn:SetShown(sim ~= nil and #list > 0)
        panel.equipAllBtn:SetAlpha((InCombatLockdown and InCombatLockdown()) and 0.4 or 1)
        panel.equipAllBtn.label:SetText(string.format(L["|TInterface\\Icons\\INV_Misc_Bag_08:12:12|t 가방 추천 일괄 착용 (%d)"], #list))
    end

    local _, specName = GetSpecializationInfo(GetSpecialization())
    panel.footer:SetText(string.format(L["%s · 상위 랭커 표본 %d명 · 데이터 %s · |cff00ccffwythic.com|r"],
        specName or "", spec.sample or 0, WythicPlusGearData.version or "?"))
end

-- ── 진입점 ────────────────────────────────────────────────────────────────────

-- 설정 창에서 장비 관련 옵션(영웅특성 자동 등)을 바꿀 때 열려 있는 창 즉시 갱신용
function WythicPlus_GearRedraw()
    if panel and panel:IsShown() and panel.Redraw then panel.Redraw() end
end

function WythicPlus_ToggleGear()
    if not panel then
        BuildPanel()
        panel.Redraw = Redraw
    end
    if panel:IsShown() then
        panel:Hide()
    else
        panel.optimize = false -- 열 때마다 기본 모드에서 시작 (웹과 동일)
        -- 커스텀 상태도 초기화 — 다시 열면 현재 착용 기준으로 렌더 (이전 세션 핀 잔존 방지)
        wipe(panel.pinnedItems)
        wipe(panel.pinnedConv)
        wipe(panel.pinnedGems)
        wipe(panel.pinnedEnchants)
        wipe(panel.dismissedSlots)
        wipe(panel.pinnedTracks)
        wipe(panel.lockedSlots)
        panel.presetRatings = nil
        panel.heroTreeId = nil -- 영웅특성 수동 선택도 자동 감지로 복귀
        panel.modelDirty = true -- 열 때 모델 재세팅 (닫혀 있는 동안의 외형 변화 반영)
        panel.FitToScreen()
        panel:Show()
        Redraw()
    end
end

-- ── EllesmereUI 스킨 연동 ─────────────────────────────────────────────────────
if EllesmereUI and EllesmereUI.RegisterSkin then
    EllesmereUI.RegisterSkin("WythicPlus", function(S)
        euiSkin = S
        ApplySkin()
    end)
end
