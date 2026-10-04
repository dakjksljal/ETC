-- 스모크 테스트: 아이템 링크 → SimC 옵션 조각 (node fengari 러너 또는 luajit tests/simc-link-parts.test.lua)
-- WythicPlusGear.lua 의 LinkSimcParts 를 미러링한다. ⚠️ 원본과 로직이 일치해야 한다 (변경 시 함께 갱신).
-- modifier 64 → redirected_base_stats(변환 티어 원본), modifier 29/30 → crafted_stats(무작위 능력치·제작 미시브)

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

local pass, fail = 0, 0
local function check(name, cond) if cond then pass = pass + 1; print("PASS " .. name) else fail = fail + 1; print("FAIL " .. name) end end

-- 착귀(무작위 능력치 가속/유연): modifier 29:36, 30:40
local p = LinkSimcParts("|cffa335ee|Hitem:271444:::::::::250:::5:6652:13662:13335:10844:12854:2:29:36:30:40|h[잊힌 희생의 견갑]|h|r")
check("boe: id/bonus", p.id == "271444" and #p.bonuses == 5 and p.bonuses[5] == "12854")
check("boe: crafted_stats 36/40", p.crafted ~= nil and table.concat(p.crafted, "/") == "36/40")
check("boe: redirect 없음", p.redirect == nil)

-- 변환 티어: modifier 64만
p = LinkSimcParts("item:271473:::::::::104:::3:13334:6652:13708:1:64:271878")
check("converted: redirect 271878", p.redirect == "271878" and p.crafted == nil)

-- 둘 다: 순서 무관
p = LinkSimcParts("item:271473:::::::::104:::1:13334:3:64:271878:29:32:30:49")
check("both: redirect + crafted 32/49", p.redirect == "271878" and table.concat(p.crafted, "/") == "32/49")

-- modifier 없음 / 0·빈 값 무시
p = LinkSimcParts("item:268247:::::::::104:::2:13440:12846")
check("none: crafted nil", p.crafted == nil and p.redirect == nil)
p = LinkSimcParts("item:268247:::::::::104:::0:2:29:0:30:")
check("zero/empty values ignored", p.crafted == nil)

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
