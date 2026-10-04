-- 스모크 테스트: 도핑 버프(포만감·영약) 이름 매칭 (node fengari 러너 또는 luajit tests/doping-buff.test.lua)
-- WythicPlusGear.lua 의 DOPING_PATTERNS/DetectDopingBuffs 매칭 로직을 미러링한다 (WoW API 의존 → 오라 목록 주입).
-- ⚠️ 패턴 테이블과 match 함수는 원본과 일치해야 한다 (변경 시 함께 갱신).

local DOPING_PATTERNS = {
    { key = "food", ko = { "포만감" }, en = { "Well Fed" } },
    { key = "flask", ko = { "영약", "약병" }, en = { "^Flask of", "^Phial of" } },
}
local function detect(auraNames)
    local found = {}
    local function match(name)
        for _, p in ipairs(DOPING_PATTERNS) do
            if not found[p.key] then
                for _, s in ipairs(p.ko) do if name:find(s, 1, true) then found[p.key] = name end end
                for _, s in ipairs(p.en) do if name:find(s) then found[p.key] = name end end
            end
        end
    end
    for _, n in ipairs(auraNames) do match(n) end
    return found
end

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

local r1 = detect({ "포만감", "연금술적 혼돈의 영약", "결정화된 강화 룬", "전투의 외침" })
check("ko: 포만감+영약 감지, 룬/기타 무시", r1.food == "포만감" and r1.flask == "연금술적 혼돈의 영약")

local r2 = detect({ "Well Fed", "Flask of Alchemical Chaos", "Crystallized Augment Rune", "Battle Shout" })
check("en: Well Fed+Flask 감지", r2.food == "Well Fed" and r2.flask == "Flask of Alchemical Chaos")

local r3 = detect({ "Phial of Tepid Versatility", "약병 효과" })
check("en Phial / ko 약병 → flask", r3.flask ~= nil and r3.food == nil)

local r4 = detect({ "Battle Shout", "Mark of the Wild", "죽음의 진군" })
check("도핑 없음 → 빈 결과", next(r4) == nil)

local r5 = detect({ "Flasking Around" })
check("'^Flask of' 앵커 — 'Flasking' 오탐 없음", r5.flask == nil)

local r6 = detect({ "Well Fed", "Well Fed" })
check("중복 버프 → 1개만", r6.food == "Well Fed")

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
