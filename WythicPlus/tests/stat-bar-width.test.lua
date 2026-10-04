-- 스모크 테스트: 스탯 비교 바 길이 기준 (node fengari 러너 또는 luajit tests/stat-bar-width.test.lua)
-- WythicPlusGear.lua Redraw 스탯 비교 바의 maxPct / myW / simW / metaW 계산을 미러링한다 (WoW API 의존 → 값 주입).
-- ⚠️ 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- 규칙: 막대 길이 = 스탯 %(우측 % 표기와 같은 기준). 최적화 증감 세그먼트 = 현재 % → 시뮬 % 차이.
-- 막대 안 숫자(레이팅)는 라벨일 뿐 길이 기준이 아니다. v1.6.18에서 레이팅 기준으로 바꿨다가
-- "추천 반영 55.29% > 메타 54.90%인데 막대가 짧다(953 < 1,018)"로 되돌림(2026-09-12).

local BAR_W = 200

local function widths(comps, simByStat)
    local maxPct = 1
    for _, c in ipairs(comps) do
        if c.myValue > maxPct then maxPct = c.myValue end
        if c.metaValue > maxPct then maxPct = c.metaValue end
        local sr = simByStat and simByStat[c.name]
        if sr and sr.simPct and sr.simPct > maxPct then maxPct = sr.simPct end
    end
    local out = {}
    for _, c in ipairs(comps) do
        local myW = math.max(1, BAR_W * math.min(c.myValue / maxPct, 1))
        local metaW = math.max(1, BAR_W * math.min(c.metaValue / maxPct, 1))
        local o = { my = myW, meta = metaW, base = myW, delta = 0, up = nil }
        local sr = simByStat and simByStat[c.name]
        if sr then
            local simPct = sr.simPct or c.myValue
            local simW = math.max(1, BAR_W * math.min(simPct / maxPct, 1))
            o.base = math.min(myW, simW)
            if math.abs(simW - myW) >= 0.5 then
                o.delta = math.abs(simW - myW)
                o.up = simW > myW
            end
        end
        out[c.name] = o
    end
    return out, maxPct
end

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

-- 2026-09-12 케이스: 특화 현재 54.3% → 추천 반영 55.29%, 메타 54.90%. 노란 증감 포함 막대가 메타보다 길어야 한다
local comps = { { name = "mastery", myValue = 54.3, metaValue = 54.90 } }
local w = widths(comps, { mastery = { simPct = 55.29 } })
check("추천 반영 % > 메타 % → 본 막대+증감이 메타보다 길다", w.mastery.base + w.mastery.delta > w.mastery.meta)
check("증감 세그먼트는 노란색(증가)", w.mastery.up == true)
check("증감 길이 = (55.29 − 54.3)/최대 비율", math.abs(w.mastery.delta - BAR_W * (55.29 - 54.3) / 55.29) < 0.01)
check("시뮬 %가 전역 최대 → 막대가 꽉 찬다", math.abs((w.mastery.base + w.mastery.delta) - BAR_W) < 0.01)

-- % 기준이므로 레이팅이 낮아도 %가 높으면 막대가 길다 (2026-09-10 제보 케이스는 설계상 정상)
local comps2 = { { name = "haste", myValue = 33.32, metaValue = 27.30 } }
local w2 = widths(comps2)
check("% 높은 쪽이 길다 (레이팅 무관)", w2.haste.my > w2.haste.meta and w2.haste.my == BAR_W)

-- 감소 추천: 시뮬 %가 현재보다 낮으면 본 막대를 시뮬까지 줄이고 줄어든 만큼 빨강
local w3 = widths(comps2, { haste = { simPct = 30.0 } })
check("감소: 본 막대 = 시뮬 %, 세그먼트는 빨강", w3.haste.up == false and math.abs(w3.haste.base - BAR_W * 30.0 / 33.32) < 0.01)
check("감소: 세그먼트 길이 = 줄어든 %", math.abs(w3.haste.delta - BAR_W * (33.32 - 30.0) / 33.32) < 0.01)

-- 변동 없음 → 세그먼트 숨김
local w4 = widths(comps2, { haste = { simPct = 33.32 } })
check("변동 없음 → 세그먼트 없음", w4.haste.delta == 0 and w4.haste.up == nil)

-- 여러 스탯은 전역 최대 % 하나로 정규화
local comps5 = { { name = "crit", myValue = 28, metaValue = 27 }, { name = "haste", myValue = 40, metaValue = 35 } }
local w5, maxPct5 = widths(comps5)
check("전역 최대 = 가장 큰 %", maxPct5 == 40 and w5.crit.my < w5.haste.my)

-- 전부 0이면 최소 폭 1
local w6 = widths({ { name = "vers", myValue = 0, metaValue = 0 } })
check("값 없음 → 최소 폭 1", w6.vers.my == 1 and w6.vers.meta == 1)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
