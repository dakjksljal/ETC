local L = WythicPlusL -- 로케일 테이블 (Locales.lua, koKR은 원문 그대로)
-- Wythic+ Combat Log Helper
-- 로그인 시 전투 로그 활성화를 도와주는 애드온

local ADDON_NAME = "WythicPlus"
local PREFIX = "|cff00ccff[Wythic+]|r "

-- Saved variables (persisted across sessions)
WythicPlusDB = WythicPlusDB or {}

-- v1.6.10 설정 개편: 로그인 자동 활성화/팝업 제거 → 던전 입장 기준으로 전환.
-- 신규·업데이트 유저 모두 자동 동작은 전부 OFF에서 시작하고, 던전 입장 확인 창만 기본 ON.
-- 주의: SavedVariables는 파일 실행 "후" ADDON_LOADED 직전에 로드되어 전역을 덮어쓴다.
-- 파일 최상단에서 DB에 쓰면 전부 유실되므로 마이그레이션은 반드시 ADDON_LOADED에서 실행.
local dbLoader = CreateFrame("Frame")
dbLoader:RegisterEvent("ADDON_LOADED")
dbLoader:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    WythicPlusDB = WythicPlusDB or {}
    if (WythicPlusDB.schema or 0) < 2 then
        WythicPlusDB.schema = 2
        WythicPlusDB.autoEnable = nil -- 구버전 로그인 자동 활성화 — 폐기
        WythicPlusDB.quietLog = nil -- 구버전 조용히 모드 — 던전 알럿 옵션으로 대체
        WythicPlusDB.logFeature = true -- 마스터: 전투 로그 기능 사용 (끄면 던전 알럿·자동 중단)
        WythicPlusDB.dungeonPrompt = true -- 던전 입장 시 확인 창
        WythicPlusDB.dungeonAuto = false -- 던전 입장 시 자동 켜기 (확인 창 없이)
    end
    if WythicPlusDB.logFeature == nil then WythicPlusDB.logFeature = true end
    if WythicPlusDB.dungeonPrompt == nil then WythicPlusDB.dungeonPrompt = true end
end)

----------------------------------------------------------------
-- Forward declarations
----------------------------------------------------------------
local minimapBtn
local DEFAULT_ANGLE = 220
local isLogging = false

----------------------------------------------------------------
-- 데이터 신선도 안내 — 동봉 메타/리그 데이터가 오래되면 로그인 시 업데이트 권고 (RaiderIO 스타일)
----------------------------------------------------------------
local function DaysSince(dateStr)
    if type(dateStr) ~= "string" then return nil end
    local y, m, d = dateStr:match("^(%d+)[.%-](%d+)[.%-](%d+)$")
    if not y then return nil end
    local ok, t = pcall(time, { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
    if not ok or not t then return nil end
    return math.floor((time() - t) / 86400)
end

local function CheckDataFreshness()
    -- 장비 메타·리그 데이터는 서버 스케줄러가 매일 릴리즈한다(09:30/10:00 KST, wythic-plus scripts/scheduler.mjs).
    -- version은 생성일(UTC). DaysSince는 그날 정오 기준 경과일(floor)이라 당일·다음날 오전(릴리즈 전)은 0,
    -- 다음날 릴리즈가 나간 뒤 그 데이터로 로그인하면 1 → 하루라도 뒤처졌으면 매 로그인마다 안내 (대표 지시 2026-09-10).
    -- (이전 문턱 10일은 "장비 메타 주 1회" 시절 값 — 매일 갱신되는 지금은 일주일 넘게 안내가 안 나갔다)
    local days = 0
    local g = WythicPlusGearData and DaysSince(WythicPlusGearData.version)
    if g and g > 0 then days = g end
    -- 리그 week는 주간 리셋일이라 일 단위 판정 불가 — 장비 데이터가 없을 때의 보조 가드만
    local lw = WythicPlusLeagueData and DaysSince(WythicPlusLeagueData.week)
    if lw and lw > 10 and lw > days then days = lw end
    if days > 0 then
        print(PREFIX .. string.format(
            L["새 데이터 릴리즈가 있습니다 — 동봉 메타 데이터가 %d일 전 것입니다 (매일 갱신). 애드온을 업데이트하세요: CurseForge/Wago 또는 |cff00ccffwythic.com|r"],
            days))
    end
end

local function UpdateIndicator()
    if not minimapBtn then return end
    if isLogging then
        minimapBtn.border:SetVertexColor(0, 0.85, 0, 1)
    elseif not WythicPlusDB.logFeature then
        minimapBtn.border:SetVertexColor(0.55, 0.55, 0.6, 1) -- 기능 꺼짐 = 중립 회색
    else
        minimapBtn.border:SetVertexColor(0.85, 0, 0, 1)
    end
end

-- 다른 애드온의 전투 로그 자동 제어 감지 (예: EllesmereUIQoL AutoLogging).
-- 감지되면 이 세션 동안 던전 입장 알림/자동 켜기를 쉬어 이중 제어를 피한다.
local externalLogController = nil -- 감지된 애드온 폴더명 (세션 한정)
local inOwnLoggingCall = false

local function SetLogging(enable)
    inOwnLoggingCall = true
    LoggingCombat(enable)
    inOwnLoggingCall = false
    isLogging = enable
    UpdateIndicator()
end

-- LoggingCombat 안전 조회 — 이 API는 10초당 5회 레이트리밋(모든 애드온 공유)이 있고
-- 제한에 걸리면 nil(상태 불명)을 반환한다. nil을 "꺼짐"으로 오독하면 표시/팝업이
-- 전부 틀어지므로, nil이면 마지막으로 알던 상태(isLogging)를 유지한다.
local function ReadLogging()
    local v = LoggingCombat()
    if v == nil then return nil end
    return v and true or false
end

-- 실제 클라이언트 상태와 재동기화 — 다른 애드온(WCL 업로더 등)이나 존 전환이
-- 로깅을 바꿔도 메뉴 라벨/테두리 색이 어긋나지 않도록 사용 직전마다 호출
local function SyncLogging()
    local v = ReadLogging()
    if v ~= nil then isLogging = v end
    UpdateIndicator()
end

-- 선제 감지: EllesmereUI QoL의 자동 로깅 설정(EllesmereUIDB.autoLogging.enabled)이 켜져 있으면 그 애드온이 로그를
-- 켜기 전에도 외부 제어로 본다. 아래 훅 감지는 그 애드온이 이 세션에서 실제로 LoggingCombat(true)를 부른 뒤에만
-- 잡혀, 던전 밖에서 설정 창을 열면 잠금이 안 걸리고 수동 조작이 가능했다(2026-09-14 지적).
-- 설정 기반 감지분은 그 설정이 꺼지면 해제한다(훅 감지분은 세션 유지).
local externalByConfig = false
local function DetectExternalLogger()
    local eui = EllesmereUIDB and EllesmereUIDB.autoLogging
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EllesmereUIQoL"))
        or type(_G._EUI_AutoLogging_Check) == "function"
    local on = loaded and eui and eui.enabled == true
    if on and not externalLogController then
        externalLogController = "EllesmereUIQoL"
        externalByConfig = true
        StaticPopup_Hide("WYTHICPLUS_COMBAT_LOG")
        if WythicPlusDB and WythicPlusDB.logFeature
            and (WythicPlusDB.dungeonPrompt or WythicPlusDB.dungeonAuto) then
            print(PREFIX .. string.format(
                L["다른 애드온(%s)이 전투 로그를 제어하고 있어 이번 접속 동안 던전 알림을 끕니다."],
                externalLogController))
        end
    elseif not on and externalByConfig then
        externalLogController = nil
        externalByConfig = false
    end
    return externalLogController
end

-- LoggingCombat 훅: 외부 애드온의 자동 로깅 감지
if type(hooksecurefunc) == "function" then
    hooksecurefunc("LoggingCombat", function(v)
        if v == nil then return end -- 인자 없는 조회는 무시
        -- 외부 애드온이 로그를 "켠" 경우만 감지 (우리 호출/블리자드 /combatlog 제외)
        if v and not inOwnLoggingCall and not externalLogController
            and type(debugstack) == "function" then
            local stack = debugstack(3, 6, 0) or ""
            local addon = stack:match("AddOns[/\\]([^/\\]+)[/\\]")
            if addon and addon ~= ADDON_NAME then
                externalLogController = addon
                StaticPopup_Hide("WYTHICPLUS_COMBAT_LOG") -- 헛뜬 알림 정리
                if WythicPlusDB and WythicPlusDB.logFeature
                    and (WythicPlusDB.dungeonPrompt or WythicPlusDB.dungeonAuto) then
                    print(PREFIX .. string.format(
                        L["다른 애드온(%s)이 전투 로그를 제어하고 있어 이번 접속 동안 던전 알림을 끕니다."],
                        addon))
                end
                SyncLogging()
                if WythicPlus_RefreshSettings then WythicPlus_RefreshSettings() end
            end
        end
    end)
end

----------------------------------------------------------------
-- 설정 창 — 전투 로그 동작 옵션 (미니맵 메뉴·/wp config 로 열기)
----------------------------------------------------------------
local settingsFrame
local function ToggleSettings()
    if settingsFrame and settingsFrame:IsShown() then
        settingsFrame:Hide()
        return
    end
    if not settingsFrame then
        settingsFrame = CreateFrame("Frame", "WythicPlusSettings", UIParent, "BackdropTemplate")
        settingsFrame:SetFrameStrata("DIALOG")
        settingsFrame:SetSize(400, 100) -- 높이는 아래 레이아웃이 내용에 맞춰 정한다
        settingsFrame:SetScale(1.25) -- 글자 포함 전체 확대 (2026-09-14 요청)
        settingsFrame:SetPoint("CENTER", 0, 0) -- 화면 정중앙 (2026-09-14 요청)
        settingsFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        settingsFrame:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
        settingsFrame:SetBackdropBorderColor(1, 1, 1, 0.18)
        settingsFrame:EnableMouse(true)
        settingsFrame:SetMovable(true)
        settingsFrame:RegisterForDrag("LeftButton")
        settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
        settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
        tinsert(UISpecialFrames, "WythicPlusSettings") -- ESC로 닫기

        settingsFrame.title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        settingsFrame.title:SetPoint("TOP", 0, -14)
        settingsFrame.title:SetText("|cff00ccffWythic+|r " .. L["설정"])
        -- 닫기 X: 블리자드 원형 대신 스위치·스테퍼와 같은 플랫 스타일 (2026-09-14 요청)
        settingsFrame.close = CreateFrame("Button", nil, settingsFrame, "BackdropTemplate")
        settingsFrame.close:SetSize(24, 24)
        settingsFrame.close:SetPoint("TOPRIGHT", -8, -8)
        settingsFrame.close:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        settingsFrame.close:SetBackdropColor(1, 1, 1, 0.06)
        settingsFrame.close:SetBackdropBorderColor(1, 1, 1, 0.2)
        settingsFrame.close.label = settingsFrame.close:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        settingsFrame.close.label:SetPoint("CENTER", 0, 1)
        settingsFrame.close.label:SetText("×")
        settingsFrame.close:SetScript("OnEnter", function(self) self:SetBackdropColor(0.97, 0.44, 0.44, 0.28) end)
        settingsFrame.close:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 1, 1, 0.06) end)
        settingsFrame.close:SetScript("OnClick", function() settingsFrame:Hide() end)

        -- ── 레이아웃 체계 (2026-09-14 재구성) ──
        -- 라벨은 왼쪽 열(PAD), 컨트롤(스위치·체크·스테퍼)은 오른쪽 열(CTRL_R)에 정렬. 행 높이 ROW 고정.
        -- 섹션 = 앰버 헤더 + 1px 구분선, 섹션 사이 18px. 라벨 폰트는 GameFontHighlight 하나, 안내문은 GameFontDisableSmall.
        local PAD, ROW, CTRL_R = 18, 30, -18
        local y = -48
        local firstSection = true
        local function Section(text)
            if not firstSection then y = y - 18 end
            firstSection = false
            local h = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            h:SetPoint("TOPLEFT", PAD, y)
            h:SetText(text)
            h:SetTextColor(0.96, 0.72, 0.33) -- 앰버 (장비 창 메타 색과 통일)
            local line = settingsFrame:CreateTexture(nil, "ARTWORK")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(1, 1, 1, 0.12)
            line:SetPoint("TOPLEFT", PAD, y - 19)
            line:SetPoint("TOPRIGHT", -PAD, y - 19)
            line:SetHeight(1)
            y = y - 32
        end
        local function Label(text, indent)
            local fs = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetPoint("TOPLEFT", PAD + (indent or 0), y - (ROW - 14) / 2)
            fs:SetText(text)
            return fs
        end
        local function Note(text, lines)
            local fs = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            fs:SetPoint("TOPLEFT", PAD, y - 4)
            fs:SetPoint("TOPRIGHT", -PAD, y - 4)
            fs:SetJustifyH("LEFT")
            fs:SetSpacing(3)
            fs:SetText(text)
            y = y - (13 * (lines or 2) + 10)
            return fs
        end
        local function SetRowEnabled(cb, enabled)
            cb:SetEnabled(enabled)
            cb.label:SetTextColor(enabled and 1 or 0.45, enabled and 1 or 0.45, enabled and 1 or 0.5)
        end
        -- 모던 토글 스위치. 전투 로그 켜짐/꺼짐 즉시 전환 (엘스미어 스타일)
        local function MakeSwitch(onToggle)
            local t = CreateFrame("Button", nil, settingsFrame, "BackdropTemplate")
            t:SetSize(40, 20)
            t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            t:SetBackdropBorderColor(0, 0, 0, 0.55)
            t.knob = t:CreateTexture(nil, "OVERLAY")
            t.knob:SetTexture("Interface\\Buttons\\WHITE8X8")
            t.knob:SetSize(16, 16)
            t.SetValue = function(self, on)
                self.on = on and true or false
                self.knob:ClearAllPoints()
                if self.on then
                    self:SetBackdropColor(0.07, 0.68, 0.47, 1) -- 초록 트랙 = 켜짐
                    self.knob:SetPoint("RIGHT", -2, 0)
                    self.knob:SetVertexColor(1, 1, 1, 1)
                else
                    self:SetBackdropColor(0.27, 0.28, 0.32, 1) -- 회색 트랙 = 꺼짐
                    self.knob:SetPoint("LEFT", 2, 0)
                    self.knob:SetVertexColor(0.8, 0.8, 0.84, 1)
                end
            end
            t:SetScript("OnClick", function(self)
                if self.disabled then return end
                self:SetValue(not self.on)
                onToggle(self, self.on)
            end)
            t:SetScript("OnEnter", function(self)
                if not self.disabled then self:SetBackdropBorderColor(1, 1, 1, 0.35) end
            end)
            t:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0, 0, 0, 0.55) end)
            t:SetValue(false)
            return t
        end
        -- 스위치 행: 라벨 왼쪽, 토글 스위치 오른쪽. 행 어디를 눌러도 토글. 체크박스 대신 스위치로 통일(2026-09-14 요청).
        -- 기존 체크박스 코드(GetChecked/SetChecked/SetEnabled)가 그대로 동작하도록 같은 이름의 메서드를 얹는다.
        local function CheckRow(text, indent, onClick)
            local row = CreateFrame("Button", nil, settingsFrame, "BackdropTemplate")
            row:SetPoint("TOPLEFT", PAD - 8, y)
            row:SetPoint("TOPRIGHT", -PAD + 8, y)
            row:SetHeight(ROW)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            row:SetBackdropColor(1, 1, 1, 0)
            local sw = MakeSwitch(function(self) onClick(self) end)
            sw:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", CTRL_R, y - (ROW - 20) / 2)
            sw.label = Label(text, indent)
            sw.GetChecked = function(self) return self.on end
            sw.SetChecked = function(self, v) self:SetValue(v) end
            sw.SetEnabled = function(self, en)
                self.disabled = not en
                self:SetAlpha(en and 1 or 0.4)
            end
            row:SetScript("OnClick", function() if not sw.disabled then sw:Click() end end)
            row:SetScript("OnEnter", function(self) if not sw.disabled then self:SetBackdropColor(1, 1, 1, 0.05) end end)
            row:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 1, 1, 0) end)
            sw.row = row
            y = y - ROW
            return sw
        end
        -- 스테퍼 행: 라벨 왼콠, [-] 값 [+] 오른쪽. 값 변경 즉시 저장 + 열려 있는 장비 창 재계산.
        local function StepperRow(labelText, key, minV, maxV)
            local row = { label = Label(labelText, 0) }
            local function get()
                return tonumber(WythicPlus_GearOption and WythicPlus_GearOption(key)) or 0
            end
            local function mk(txt, delta)
                local b = CreateFrame("Button", nil, settingsFrame, "BackdropTemplate")
                b:SetSize(22, 20)
                b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
                b:SetBackdropColor(1, 1, 1, 0.08)
                b:SetBackdropBorderColor(1, 1, 1, 0.25)
                b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                b.fs:SetPoint("CENTER", 0, 1)
                b.fs:SetText(txt)
                b:SetScript("OnClick", function()
                    if not WythicPlus_SetGearOption then return end
                    local v = math.max(minV, math.min(maxV, get() + delta))
                    WythicPlus_SetGearOption(key, v)
                    row.Refresh()
                end)
                b:SetScript("OnEnter", function(self) self:SetBackdropColor(1, 1, 1, 0.16) end)
                b:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 1, 1, 0.08) end)
                return b
            end
            row.plus = mk("+", 1)
            row.plus:SetPoint("TOPRIGHT", CTRL_R, y - (ROW - 20) / 2)
            row.value = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.value:SetPoint("RIGHT", row.plus, "LEFT", -4, 0)
            row.value:SetWidth(36)
            row.value:SetJustifyH("CENTER")
            row.minus = mk("-", -1)
            row.minus:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
            row.Refresh = function()
                local v = get()
                local def = WythicPlus_GearOptionDefault and WythicPlus_GearOptionDefault(key)
                row.value:SetText(v == def and ("|cffffffff" .. v .. "|r") or ("|cffffb454" .. v .. "|r")) -- 기본값과 다르면 앰버
            end
            row.Refresh()
            y = y - ROW
            return row
        end

        -- ── 전투 로그 ──
        Section(L["전투 로그"])
        settingsFrame.statusFs = Label("", 0)
        settingsFrame.toggleSw = MakeSwitch(function(_, on)
            SetLogging(on)
            local v = ReadLogging() -- 다른 애드온이 되돌렸는지 실측 (nil=레이트리밋이면 설정값 신뢰)
            local actual = (v == nil) and on or v
            isLogging = actual
            UpdateIndicator()
            if actual ~= on then
                print(PREFIX .. L["전투 로그 전환이 되돌려졌습니다 — 다른 애드온(WCL 업로더 등)이 로깅을 제어 중일 수 있습니다."])
            end
            settingsFrame.RefreshStatus()
        end)
        settingsFrame.toggleSw:SetPoint("TOPRIGHT", CTRL_R, y - (ROW - 20) / 2)
        y = y - ROW
        settingsFrame.RefreshStatus = function()
            SyncLogging()
            settingsFrame.statusFs:SetText(L["전투 로그: "]
                .. (isLogging and L["|cff00ff00활성|r"] or L["|cffff0000비활성|r"]))
            settingsFrame.toggleSw:SetValue(isLogging)
        end

        settingsFrame.featureCb = CheckRow(L["전투 로그 기능 사용"], 0, function(self)
            WythicPlusDB.logFeature = self:GetChecked() and true or false
            -- 마스터를 끄면 켜져 있는 로그도 함께 끔 (명시적 유저 조작)
            if not WythicPlusDB.logFeature and isLogging then
                SetLogging(false)
                print(PREFIX .. L["전투 로그가 비활성화되었습니다."])
            elseif WythicPlusDB.logFeature and not isLogging and not externalLogController then
                -- 마스터를 켜면 로그도 바로 켠다 (끄기와 대칭. "기능 사용"만 켜지고 상태는 비활성으로 남아 혼란, 2026-09-14 지적).
                SetLogging(true)
                local v = ReadLogging()
                local actual = (v == nil) and true or v
                isLogging = actual
                UpdateIndicator()
                if actual then
                    print(PREFIX .. L["전투 로그가 활성화되었습니다."])
                else
                    print(PREFIX .. L["전투 로그 전환이 되돌려졌습니다 — 다른 애드온(WCL 업로더 등)이 로깅을 제어 중일 수 있습니다."])
                end
            end
            UpdateIndicator()
            settingsFrame.RefreshRows()
            settingsFrame.RefreshStatus()
        end)
        settingsFrame.promptCb = CheckRow(L["던전 입장 시 확인 창 표시"], 16, function(self)
            WythicPlusDB.dungeonPrompt = self:GetChecked() and true or false
        end)
        settingsFrame.autoCb = CheckRow(L["던전 입장 시 자동으로 켜기 (확인 창 없이)"], 16, function(self)
            WythicPlusDB.dungeonAuto = self:GetChecked() and true or false
        end)
        settingsFrame.note = Note("", 2)

        settingsFrame.RefreshRows = function()
            local feature = WythicPlusDB.logFeature and true or false
            local ext = externalLogController
            settingsFrame.featureCb:SetChecked(feature)
            settingsFrame.promptCb:SetChecked(WythicPlusDB.dungeonPrompt and true or false)
            settingsFrame.autoCb:SetChecked(WythicPlusDB.dungeonAuto and true or false)
            -- 외부 애드온이 로그를 제어 중이면 이 세션 동안 설정 전체 잠금 (스위치 포함)
            SetRowEnabled(settingsFrame.featureCb, not ext)
            SetRowEnabled(settingsFrame.promptCb, feature and not ext)
            SetRowEnabled(settingsFrame.autoCb, feature and not ext)
            -- 마스터가 꺼져 있으면 수동 토글도 잠근다 (마스터 꺼짐 = 전투 로그 기능 전체 사용 안 함, 2026-09-14 지적)
            local swLocked = ext or not feature
            settingsFrame.toggleSw.disabled = swLocked and true or false
            settingsFrame.toggleSw:SetAlpha(swLocked and 0.4 or 1)
            if ext then
                settingsFrame.note:SetText("|cffffa500" .. string.format(
                    L["다른 애드온(%s)이 전투 로그를 제어하고 있어 이 기능을 사용할 수 없습니다."], ext) .. "|r")
            else
                settingsFrame.note:SetText(L["전투 로그는 WCL(로그 사이트) 업로드에 필요합니다. 수동 전환: 미니맵 메뉴 또는 /wp on·off"])
            end
        end

        -- ── 장비 최적화 (알고리즘 조절값. WythicPlusDB.gear, 접근자는 WythicPlusGearDiag.lua) ──
        Section(L["장비 최적화"])
        settingsFrame.downTolRow = StepperRow(L["가방 기준 · 방어구 허용 하락폭 (ilvl)"], "downTol", 0, 40)
        settingsFrame.weaponTolRow = StepperRow(L["가방 기준 · 무기 허용 하락폭 (ilvl)"], "weaponDownTol", 0, 40)
        settingsFrame.catalystCb = CheckRow(L["마나용제 변환 가정 사용 (가방 기준)"], 0, function(self)
            if WythicPlus_SetGearOption then WythicPlus_SetGearOption("catalyst", self:GetChecked() and true or false) end
        end)
        settingsFrame.gearNote = Note(L["하락폭: 착용보다 이만큼 낮은 아이템 레벨까지 가방 후보로 봅니다. 기본 13(강화 한 단계), 무기 0. 기본값과 다르면 주황색으로 표시됩니다."], 3)
        settingsFrame.RefreshGearRows = function()
            settingsFrame.downTolRow.Refresh()
            settingsFrame.weaponTolRow.Refresh()
            settingsFrame.catalystCb:SetChecked((WythicPlus_GearOption and WythicPlus_GearOption("catalyst")) ~= false)
        end

        settingsFrame:SetHeight(-y + PAD)

        -- 외부 제어 감지가 설정 창이 열린 채로 일어나도 즉시 반영되도록 전역 노출
        WythicPlus_RefreshSettings = function()
            if settingsFrame and settingsFrame:IsShown() then
                settingsFrame.RefreshRows()
                settingsFrame.RefreshStatus()
                settingsFrame.RefreshGearRows()
            end
        end
    end
    DetectExternalLogger() -- 설정 창을 열 때마다 외부 자동 로깅 설정을 다시 확인
    settingsFrame.RefreshRows()
    settingsFrame.RefreshStatus()
    settingsFrame.RefreshGearRows()
    settingsFrame:Show()
end
WythicPlus_ToggleSettings = ToggleSettings -- 슬래시/외부 접근용

----------------------------------------------------------------
-- 미니맵 컨텍스트 메뉴 — 자체 프레임 구현
-- (MenuUtil 메뉴는 항목 클릭이 콜백까지 전달되지 않는 문제가 보고됨, 2026-09-07 —
--  장비창 드롭다운과 동일한 검증된 버튼 프레임 방식으로 교체)
----------------------------------------------------------------
local ctxMenu
local function ToggleContextMenu(anchorBtn)
    if ctxMenu and ctxMenu:IsShown() then
        ctxMenu:Hide()
        return
    end
    if not ctxMenu then
        ctxMenu = CreateFrame("Frame", "WythicPlusMiniMenu", UIParent, "BackdropTemplate")
        ctxMenu:SetFrameStrata("TOOLTIP")
        ctxMenu:SetSize(210, 94)
        ctxMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        ctxMenu:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
        ctxMenu:SetBackdropBorderColor(1, 1, 1, 0.18)
        ctxMenu:EnableMouse(true)
        ctxMenu.title = ctxMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ctxMenu.title:SetPoint("TOP", 0, -7)
        ctxMenu.title:SetText("|cff00ccffWythic+|r")

        local function Row(y)
            local b = CreateFrame("Button", nil, ctxMenu, "BackdropTemplate")
            b:SetSize(198, 20)
            b:SetPoint("TOP", 0, y)
            b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            b:SetBackdropColor(1, 1, 1, 0)
            b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.label:SetPoint("LEFT", 8, 0)
            b:SetScript("OnEnter", function(self) self:SetBackdropColor(1, 1, 1, 0.12) end)
            b:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 1, 1, 0) end)
            return b
        end

        ctxMenu.gearRow = Row(-24)
        ctxMenu.gearRow:SetScript("OnClick", function()
            ctxMenu:Hide()
            if WythicPlus_ToggleGear then WythicPlus_ToggleGear() end
        end)

        ctxMenu.logRow = Row(-45)
        ctxMenu.logRow:SetScript("OnClick", function()
            ctxMenu:Hide()
            if not WythicPlusDB.logFeature then
                print(PREFIX .. L["전투 로그 기능이 꺼져 있습니다. 설정에서 「전투 로그 기능 사용」을 켜세요."])
                return
            end
            local target = not isLogging
            SetLogging(target)
            -- 실측 재확인 — 다른 애드온이 되돌리는 경우 구분 (nil=레이트리밋 → 설정값 신뢰)
            local v = ReadLogging()
            local actual = (v == nil) and target or v
            isLogging = actual
            UpdateIndicator()
            if actual ~= target then
                print(PREFIX .. L["전투 로그 전환이 되돌려졌습니다 — 다른 애드온(WCL 업로더 등)이 로깅을 제어 중일 수 있습니다."])
            else
                print(PREFIX .. (actual and L["전투 로그가 활성화되었습니다."] or L["전투 로그가 비활성화되었습니다."]))
            end
        end)

        -- 세부 옵션(던전 알럿/자동 켜기)은 설정 창으로 분리
        ctxMenu.settingsRow = Row(-66)
        ctxMenu.settingsRow:SetScript("OnClick", function()
            ctxMenu:Hide()
            ToggleSettings()
        end)

        ctxMenu.Refresh = function()
            ctxMenu.gearRow.label:SetText(L["장비 최적화 열기"])
            ctxMenu.logRow.label:SetText(isLogging and L["전투 로그 끄기"] or L["전투 로그 켜기"])
            ctxMenu.settingsRow.label:SetText(L["설정"])
        end

        -- 마우스가 메뉴를 벗어나면 잠시 후 자동 닫힘
        ctxMenu:SetScript("OnUpdate", function(self, elapsed)
            if self:IsMouseOver() or (minimapBtn and minimapBtn:IsMouseOver()) then
                self.away = 0
            else
                self.away = (self.away or 0) + elapsed
                if self.away > 0.7 then self:Hide() end
            end
        end)
        ctxMenu:SetScript("OnShow", function(self) self.away = 0 end)
    end
    SyncLogging()
    ctxMenu.Refresh()
    ctxMenu:ClearAllPoints()
    ctxMenu:SetPoint("TOPRIGHT", anchorBtn, "BOTTOMLEFT", 6, -2)
    ctxMenu:Show()
end

----------------------------------------------------------------
-- Minimap Button (standard icon on minimap edge)
----------------------------------------------------------------
local function IsMinimapSquare()
    return ElvUI ~= nil or Minimap.backdrop ~= nil
end

local function SetMinimapButtonPosition(angle)
    local rad = math.rad(angle)
    local cos, sin = math.cos(rad), math.sin(rad)
    local half = Minimap:GetWidth() / 2 + 8
    local x, y

    if IsMinimapSquare() then
        local ac, as = math.abs(cos), math.abs(sin)
        if ac > as then
            x = half * (cos > 0 and 1 or -1)
            y = half * sin / ac
        else
            y = half * (sin > 0 and 1 or -1)
            x = half * cos / as
        end
    else
        x = cos * half
        y = sin * half
    end

    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapIndicator()
    local btn = CreateFrame("Button", "WythicPlusMinimapBtn", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Wy+ logo icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\WythicPlus\\Textures\\icon")
    btn.icon = icon

    -- Border (tinted green/red by combat log status)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.border = border

    -- Highlight on hover
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Position from saved angle
    minimapBtn = btn
    WythicPlusDB.minimapAngle = WythicPlusDB.minimapAngle or DEFAULT_ANGLE
    SetMinimapButtonPosition(WythicPlusDB.minimapAngle)

    -- Shift+left drag to reposition
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function()
        if not IsShiftKeyDown() then return end
        btn:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            WythicPlusDB.minimapAngle = angle
            SetMinimapButtonPosition(angle)
        end)
    end)
    local function StopDragging()
        btn:SetScript("OnUpdate", nil)
    end
    btn:SetScript("OnDragStop", StopDragging)
    btn:SetScript("OnMouseUp", StopDragging)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        SyncLogging()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetClampedToScreen(true)
        GameTooltip:AddLine("Wythic+", 0, 0.8, 1)
        if isLogging then
            GameTooltip:AddLine(L["전투 로그: |cff00ff00활성|r"])
        else
            GameTooltip:AddLine(L["전투 로그: |cffff0000비활성|r"])
        end
        GameTooltip:AddLine(L["|cff888888좌클릭: 장비 최적화 · 우클릭: 메뉴|r"], 0.5, 0.5, 0.5)
        GameTooltip:AddLine(L["|cff888888Shift+드래그: 이동|r"], 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Left click: gear optimizer / Right click: context menu
    btn:SetScript("OnClick", function(_, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            return -- Shift+클릭은 드래그용, 무시
        elseif button == "LeftButton" then
            -- 좌클릭: 장비 최적화 창 열기
            if WythicPlus_ToggleGear then
                WythicPlus_ToggleGear()
            else
                print(PREFIX .. L["장비 최적화 모듈을 불러오지 못했습니다."])
            end
        else
            ToggleContextMenu(btn)
        end
    end)

    UpdateIndicator()
end

----------------------------------------------------------------
-- Login event
----------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
local wasInDungeon = false -- 인스턴스 "진입 시점"에만 알럿 (안에서의 존 전환/리로드엔 안 뜸)
local promptedInstances = {} -- 같은 인스턴스 런에서는 확인 창 1회만 (초기화하면 다시 물음)

-- 인스턴스 초기화 = 새 런 → 물어본 기록을 지워 다음 입장에 다시 확인.
-- 12.x에서 초기화 호출 경로가 확실치 않아 세 겹으로 감지: 구 전역 API / C_PartyInfo / 확인 팝업.
local function OnInstanceReset()
    wipe(promptedInstances)
end
if type(ResetInstances) == "function" then
    hooksecurefunc("ResetInstances", OnInstanceReset)
end
if C_PartyInfo and type(C_PartyInfo.ResetInstances) == "function" then
    hooksecurefunc(C_PartyInfo, "ResetInstances", OnInstanceReset)
end
if StaticPopupDialogs and StaticPopupDialogs["CONFIRM_RESET_INSTANCES"] then
    local dlg = StaticPopupDialogs["CONFIRM_RESET_INSTANCES"]
    local origAccept = dlg.OnAccept
    dlg.OnAccept = function(...)
        OnInstanceReset()
        if origAccept then return origAccept(...) end
    end
end
-- 파티장이 초기화한 경우는 시스템 메시지로만 알 수 있음 ("OOO이(가) 초기화되었습니다").
-- koKR은 조사 치환(이(가)→이/가)이 일어날 수 있어, %s 뒤 조사 덩어리까지 건너뛴
-- 공백 이후 동사부("초기화되었습니다...")만 느슨하게 찾는다.
local resetPattern
if type(INSTANCE_RESET_SUCCESS) == "string" then
    local tail = INSTANCE_RESET_SUCCESS:match("%%s%S*(%s.+)$")
        or INSTANCE_RESET_SUCCESS:match("%%s(.+)$")
        or INSTANCE_RESET_SUCCESS
    resetPattern = tail:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
end

frame:SetScript("OnEvent", function(_, event, isInitialLogin, isReload)
    if event == "PLAYER_ENTERING_WORLD" then DetectExternalLogger() end -- 던전 입장 판정 전에 외부 제어 여부 확정
    if event == "CHAT_MSG_SYSTEM" then
        local msg = isInitialLogin -- CHAT_MSG_SYSTEM의 첫 인자 = 메시지
        -- 12.x: 일부 시스템 메시지는 secret string이라 내용 접근(find/concat) 자체가
        -- 차단되어 에러가 난다 → 전부 pcall로 감싸고, 봉인된 메시지는 조용히 무시
        if resetPattern and type(msg) == "string" then
            local ok, hit = pcall(string.find, msg, resetPattern)
            if ok and hit then
                wipe(promptedInstances)
            end
        end
        return
    end
    -- 존 전환/재로그마다 실제 상태와 재동기화 (nil=레이트리밋이면 마지막 상태 유지)
    local lv = ReadLogging()
    if lv ~= nil then isLogging = lv end
    if not minimapBtn then
        CreateMinimapIndicator()
    end
    UpdateIndicator()

    -- 데이터 신선도 경고만 유지 (첫 로그인, 채팅이 정리된 뒤에) — 사이트 홍보 메시지는 제거(v1.6.10)
    if isInitialLogin then
        if C_Timer and C_Timer.After then C_Timer.After(8, CheckDataFreshness) else CheckDataFreshness() end
    end

    -- 전투 로그: 로그인 시엔 아무것도 하지 않는다 (v1.6.10 정책 — 기본 전부 OFF).
    -- 던전(파티/레이드 인스턴스) "진입 시점"에만, 설정에 따라 자동 켜기 또는 확인 창.
    local inInst, instType = IsInInstance()
    local inDungeon = inInst and (instType == "party" or instType == "raid") or false
    if inDungeon and not wasInDungeon and not isReload and WythicPlusDB.logFeature
        and not externalLogController then
        if not isLogging then
            if WythicPlusDB.dungeonAuto then
                SetLogging(true)
                print(PREFIX .. L["전투 로그가 자동으로 활성화되었습니다."])
            elseif WythicPlusDB.dungeonPrompt then
                local mapID = select(8, GetInstanceInfo()) or 0
                if not promptedInstances[mapID] then
                    promptedInstances[mapID] = true
                    -- 다른 애드온의 자동 로깅이 입장 직후에 켜질 수 있어(핸들러 순서 경합)
                    -- 잠깐 기다렸다 조건을 재확인하고 표시 — 헛뜨는 팝업 방지
                    local function ShowPrompt()
                        if externalLogController or not WythicPlusDB.logFeature
                            or not WythicPlusDB.dungeonPrompt then return end
                        SyncLogging()
                        if isLogging then return end
                        local inst2, type2 = IsInInstance()
                        if inst2 and (type2 == "party" or type2 == "raid") then
                            StaticPopup_Show("WYTHICPLUS_COMBAT_LOG")
                        end
                    end
                    if C_Timer and C_Timer.After then C_Timer.After(2, ShowPrompt) else ShowPrompt() end
                end
            end
        end
    elseif not inDungeon then
        StaticPopup_Hide("WYTHICPLUS_COMBAT_LOG") -- 입장 전에 안 누르고 나간 경우 정리
    end
    wasInDungeon = inDungeon
end)

----------------------------------------------------------------
-- Static popup (for returning users)
----------------------------------------------------------------
StaticPopupDialogs["WYTHICPLUS_COMBAT_LOG"] = {
    text = L["|cff00ccffWythic+|r\n\n던전에 입장했습니다. 전투 로그를 켤까요?\n|cff888888WCL 로깅에 필요합니다.|r"],
    button1 = L["켜기"],
    button2 = L["취소"],
    button3 = L["다시 묻지 않기"],
    OnAccept = function()
        SetLogging(true)
        print(PREFIX .. L["전투 로그가 활성화되었습니다."])
    end,
    OnAlt = function()
        WythicPlusDB.dungeonPrompt = false
        print(PREFIX .. L["던전 입장 알림을 껐습니다 — 미니맵 우클릭 → 설정에서 다시 켤 수 있습니다."])
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

----------------------------------------------------------------
-- Slash commands: /wythic, /wp
----------------------------------------------------------------
SLASH_WYTHICPLUS1 = "/wythic"
SLASH_WYTHICPLUS2 = "/wp"

SlashCmdList["WYTHICPLUS"] = function(msg)
    msg = (msg or ""):lower():trim()

    if msg == "on" then
        if not WythicPlusDB.logFeature then
            print(PREFIX .. L["전투 로그 기능이 꺼져 있습니다. 설정에서 「전투 로그 기능 사용」을 켜세요."])
            return
        end
        SetLogging(true)
        print(PREFIX .. L["전투 로그가 활성화되었습니다."])

    elseif msg == "off" then
        SetLogging(false)
        print(PREFIX .. L["전투 로그가 비활성화되었습니다."])

    elseif msg == "auto" then
        WythicPlusDB.dungeonAuto = not WythicPlusDB.dungeonAuto
        if WythicPlusDB.dungeonAuto then
            print(PREFIX .. L["던전 자동 활성화 |cff00ff00켜짐|r (던전 입장 시 확인 창 없이 바로 켬)"])
        else
            print(PREFIX .. L["던전 자동 활성화 |cffff0000꺼짐|r"])
        end

    elseif msg == "dump" then
        -- 장비 최적화 진단 덤프 토글 — 코어에 들어가는 장신구 입력을 SavedVariables(WythicPlusDB.debugTrinketSim)에 기록.
        -- 켠 뒤 재현 → /reload 하면 파일에 내려간다. 증상 제보 때 개발자가 요청하는 용도.
        WythicPlusDB.debugTrinket = not WythicPlusDB.debugTrinket or nil
        if not WythicPlusDB.debugTrinket then WythicPlusDB.debugTrinketSim = nil end
        print("|cff00ccffWythic+|r 진단 덤프 " .. (WythicPlusDB.debugTrinket and "켜짐 — 재현 후 /reload" or "꺼짐"))
    elseif msg == "config" or msg == "settings" or msg == "설정" then
        ToggleSettings()

    elseif msg == "status" then
        print(PREFIX .. L["전투 로그: "] .. (isLogging and L["|cff00ff00활성|r"] or L["|cffff0000비활성|r"]))
        print(PREFIX .. L["전투 로그 기능: "] .. (WythicPlusDB.logFeature and L["|cff00ff00켜짐|r"] or L["|cffff0000꺼짐|r"])
            .. " / " .. L["던전 알림: "] .. (WythicPlusDB.dungeonPrompt and L["|cff00ff00켜짐|r"] or L["|cffff0000꺼짐|r"])
            .. " / " .. L["던전 자동: "] .. (WythicPlusDB.dungeonAuto and L["|cff00ff00켜짐|r"] or L["|cffff0000꺼짐|r"]))

    elseif msg == "gear" then
        if WythicPlus_ToggleGear then
            WythicPlus_ToggleGear()
        else
            print(PREFIX .. L["장비 최적화 모듈을 불러오지 못했습니다."])
        end

    else
        print(L["|cff00ccff[Wythic+] 명령어:|r"])
        print(L["  /wp gear   — 장비 최적화 열기"])
        print(L["  /wp config — 설정 창 열기"])
        print(L["  /wp on     — 전투 로그 켜기"])
        print(L["  /wp off    — 전투 로그 끄기"])
        print(L["  /wp auto   — 던전 입장 시 자동 켜기 토글"])
        print(L["  /wp status — 현재 상태 확인"])
    end
end
