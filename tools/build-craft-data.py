#!/usr/bin/env python3
"""Wythic+ 제작 장비 데이터 생성기 (와우헤드 기반).

시즌 전체 제작 가능 장비 목록을 와우헤드에서 모아 WythicPlus/WythicPlusCraftData.lua 를 만든다.
시즌이 바뀌면(제작 장비·최고 품질 ilvl이 바뀌면) 상단 상수를 갱신하고 다시 실행한다.

  python3 tools/build-craft-data.py            # 생성
  python3 tools/build-craft-data.py --cache D  # 와우헤드 응답을 D 폴더에 캐시 (재실행 시 재사용)

수집 기준
  1. 각 전문기술 제작법 목록에서 이번 확장팩 제작법(주문 ID >= RECIPE_MIN_SPELL)이 만드는 아이템
  2. 그중 무기/방어구, 영웅(에픽) 등급, 제작 출처, 제작 품질 보너스 트리(5102 무작위 능력치 / 5287 고정 능력치)
     (PvP 제작템은 등급·최고 ilvl이 달라 제외)
  3. 툴팁의 "Random Stat N" 개수 = 유저가 고르는 2차 스탯 수(0이면 스탯 고정 아이템)
"""
import argparse
import concurrent.futures as cf
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys

# ── 시즌 상수 (시즌 교체 시 갱신) ──
SEASON = "Midnight Season 2 (12.1)"
CRAFT_ILVL = 331  # 최고 품질 제작 ilvl = 신화 트랙 최대(334) - 3
RECIPE_MIN_SPELL = 1220000  # 이번 확장팩 제작법 주문 ID 하한
PROFESSIONS = ["blacksmithing", "leatherworking", "tailoring", "jewelcrafting",
               "engineering", "inscription", "alchemy", "enchanting"]
CRAFT_TREES = {5102, 5287}
# 최고 품질 보너스 템플릿 (랭커 착용 데이터에 없는 아이템용). 메타에 있는 아이템은 애드온이 랭커 보너스를 그대로 쓴다.
BONUS_STD = "12214:13667:12497:13751:14001:13836"
BONUS_2H = "12214:13667:12497:13751:14004:13836"
TWO_HAND_INV = {15, 17, 26}

# 장식(embellishment) 보너스 ID → (장식 재료 아이템, 적용 가능 장비). 와우헤드 툴팁에 아이템 + "8960:<보너스>"를 넣어
# 그려지는 착용 효과 문구를 재료 툴팁 "Provides the following property" 문구와 대조해 확인한 값(2026-10-04).
#   armor = 방어구, equipment = 모든 장비, weaponArmor = 무기·방어구, weaponOffhand = 무기·보조장비,
#   accessory = 목·반지, bsWeapon = 대장기술 무기, engEquip/engBoots/engGun = 기계공학 제작 장비/신발/총
EMBELLISHMENTS = {
    12384: (240166, "armor"),          # Arcanoweave Lining
    12385: (240164, "armor"),          # Sunfire Silk Lining
    12685: (244674, "weaponArmor"),    # Devouring Banding
    12686: (244603, "equipment"),      # Blessed Pango Charm
    12687: (244607, "weaponArmor"),    # Primal Spore Binding
    12692: (245877, "weaponOffhand"),  # Darkmoon Sigil: Rot
    12693: (245875, "weaponOffhand"),  # Darkmoon Sigil: Hunt
    12705: (245871, "weaponOffhand"),  # Darkmoon Sigil: Blood
    13640: (245873, "weaponOffhand"),  # Darkmoon Sigil: Void
    12715: (248130, "equipment"),      # Lucky Keychain
    12991: (248136, "equipment"),      # M3DDY, Travel-Sized
    13453: (251487, "equipment"),      # Prismatic Focusing Iris
    13454: (251489, "equipment"),      # Stabilizing Gemstone Bandolier
    13767: (273068, "equipment"),      # Adorned Fang
    13768: (273065, "accessory"),      # Polished Ammolite
    13771: (273059, "bsWeapon"),       # Hunter's Ritual Stone
    13769: (273062, "engGun"),         # Coiled Snake-Eye
    12717: (248132, "engBoots"),       # Kinetic Ankle Primers
    12990: (248135, "engEquip"),       # B1P, Scorcher of Souls
    13556: (255843, "engEquip"),       # HU5H, Nonchalant Pup
}
# 장식 표시 보너스(장식 효과 없이 "장식됨" 표지만 붙는 것) — 장식 개수 판정·교체 시 제거 대상
EMBELLISH_MARKERS = [8960, 13555]

# 마법부여: 이번 확장팩 마법부여 주문서(등급별 별도 아이템, 1등급 다음 ID가 2등급) + 다리 마법실/방어구 키트
ENCHANT_PROFS = ["enchanting", "tailoring", "leatherworking"]
ENCHANT_SLOT = [("Enchant Ring", "FINGER"), ("Enchant Boots", "FEET"), ("Enchant Chest", "CHEST"),
                ("Enchant Helm", "HEAD"), ("Enchant Shoulders", "SHOULDER"), ("Enchant Weapon", "WEAPON"),
                ("Spellthread", "LEGS"), ("Armor Kit", "LEGS")]
SECONDARY_EN = {"Critical Strike": "crit", "Haste": "haste", "Mastery": "mastery", "Versatility": "versatility"}

UA = "Mozilla/5.0"
CACHE = None


def get(url):
    if CACHE:
        p = os.path.join(CACHE, hashlib.md5(url.encode()).hexdigest())
        if os.path.exists(p):
            return open(p, encoding="utf-8").read()
    out = subprocess.run(["curl", "-sL", "--max-time", "90", "-A", UA, url],
                         capture_output=True, text=True).stdout
    if CACHE and out:
        open(os.path.join(CACHE, hashlib.md5(url.encode()).hexdigest()), "w", encoding="utf-8").write(out)
    return out


def listview(html, var):
    i = html.find("var %s = " % var)
    if i < 0:
        return []
    j = html.find(";\n", i)
    s = html[i + len("var %s = " % var):j]
    s = re.sub(r'([{,])([A-Za-z_][A-Za-z0-9_]*):', r'\1"\2":', s)  # JS 객체 키 → JSON
    return json.loads(s)


def item_xml(item_id):
    x = get("https://www.wowhead.com/item=%d&xml" % item_id)

    def part(tag):
        m = re.search(r"<%s><!\[CDATA\[(.*?)\]\]></%s>" % (tag, tag), x, re.S)
        if not m:
            return {}
        try:
            return json.loads("{" + m.group(1) + "}")
        except ValueError:
            return {}

    j = part("json")
    j["_nRandom"] = len(set(re.findall(r"Random Stat (\d)", x)))
    return j


def item_tooltip(item_id):
    """nether 툴팁 → (이름, Use: 문구)."""
    out = get("https://nether.wowhead.com/tooltip/item/%d?dataEnv=1&locale=0" % item_id)
    try:
        j = json.loads(out)
    except ValueError:
        return None, ""
    t = re.sub(r"<br ?/?>", "\n", j.get("tooltip", ""))
    t = re.sub(r"<[^>]+>", "", t)
    m = re.search(r"Use: (.*?)(?:Cannot be applied|Requires|Max Stack|$)", t, re.S)
    return j.get("name"), (m.group(1) if m else "").replace("\n", " ").strip()


def flat_secondary(use_text):
    """고정 2차 스탯만 ("increasing Haste by 24"). 발동형("... by 124 for 15 sec")·주 스탯·3차 스탯은 제외."""
    out = {}
    for name, val, tail in re.findall(r"increasing (Critical Strike|Haste|Mastery|Versatility) by (\d+)(\s+for\s+\d+)?", use_text):
        if not tail:
            out[SECONDARY_EN[name]] = int(val)
    return out


def collect_enchants():
    recipes = []
    for prof in ENCHANT_PROFS:
        for s in listview(get("https://www.wowhead.com/spells/professions/" + prof), "listviewspells"):
            if s["id"] >= RECIPE_MIN_SPELL and s.get("creates"):
                recipes.append(s["creates"][0])
    tier1 = sorted(set(recipes))
    with cf.ThreadPoolExecutor(8) as ex:
        t1 = dict(zip(tier1, ex.map(item_tooltip, tier1)))
        t2 = dict(zip(tier1, ex.map(item_tooltip, [i + 1 for i in tier1])))
    out, seen = [], set()
    for item in tier1:
        name, use = t1[item]
        if not name or name in seen:
            continue
        slot = next((sl for pre, sl in ENCHANT_SLOT if pre in name), None)
        if not slot or not re.search(r"Permanently enchants|to your leggings|to your leg armor", use):
            continue
        seen.add(name)
        n2, use2 = t2[item]
        has2 = n2 == name
        out.append({"name": name, "slot": slot, "item1": item, "item2": item + 1 if has2 else item,
                    "s1": flat_secondary(use), "s2": flat_secondary(use2 if has2 else use)})
    return out


def lua_stats(st):
    return "{ " + ", ".join("%s = %d" % (k, v) for k, v in sorted(st.items())) + " }" if st else "nil"


def main():
    global CACHE
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "WythicPlus", "WythicPlusCraftData.lua"))
    a = ap.parse_args()
    if a.cache:
        CACHE = a.cache
        os.makedirs(CACHE, exist_ok=True)

    created = {}
    for prof in PROFESSIONS:
        spells = listview(get("https://www.wowhead.com/spells/professions/" + prof), "listviewspells")
        if not spells:
            sys.exit("제작법 목록을 못 읽음: " + prof)
        for s in spells:
            if s.get("creates") and s["id"] >= RECIPE_MIN_SPELL:
                created[s["creates"][0]] = prof
        print(prof, len(spells), file=sys.stderr)

    with cf.ThreadPoolExecutor(8) as ex:
        details = dict(zip(created, ex.map(item_xml, list(created))))

    items = []
    for item_id, j in sorted(details.items()):
        if j.get("quality") != 4 or j.get("classs") not in (2, 4):
            continue
        if 1 not in j.get("source", []) or not (CRAFT_TREES & set(j.get("bonustrees", []))):
            continue
        items.append((item_id, j))
    if len(items) < 50:
        sys.exit("제작 장비가 너무 적음(%d) — 와우헤드 응답 확인 필요" % len(items))

    lines = [
        "-- 자동 생성 파일 — 수정 금지. 생성: tools/build-craft-data.py (와우헤드 제작법·아이템 데이터)",
        "-- 시즌 전체 제작 장비. 아이템 선택창 「제작」 탭이 쓴다(유저가 2차 스탯을 지정해 핀 → 나머지 부위 재최적화).",
        "-- 필드: inv = 장착 부위(INVTYPE 번호), n = 유저가 고르는 2차 스탯 수(0 = 스탯 고정), specs = 착용 가능 전문화(빈 표 = 전체)",
        "WythicPlusCraftData = {",
        '  season = "%s",' % SEASON,
        '  generated = "%s",' % datetime.date.today().isoformat(),
        "  ilvl = %d, -- 최고 품질" % CRAFT_ILVL,
        "  statIds = { crit = 32, haste = 36, mastery = 49, versatility = 40 }, -- 링크 modifier 29/30 값 (ITEM_MOD_*_RATING)",
        '  bonus = { std = "%s", twoHand = "%s" }, -- 최고 품질 보너스 템플릿 (랭커 데이터에 없는 아이템용)' % (BONUS_STD, BONUS_2H),
        "  twoHandInv = { [15] = true, [17] = true, [26] = true },",
        "  items = {",
    ]
    for item_id, j in items:
        specs = ",".join(str(s) for s in j.get("specs", []))
        name = (j.get("name") or "").replace("\n", " ")
        prof = (j.get("sourcemore") or [{}])[0].get("s") or 0
        lines.append("    [%d] = { inv = %d, n = %d, cls = %d, prof = %d, specs = { %s } }, -- %s" % (
            item_id, j.get("slot") or 0, j["_nRandom"], j.get("classs") or 0, prof, specs, name))
    lines += ["  },"]

    # 장식: 제작 탭에서 유저가 고른다(계산 제외 — 링크·툴팁·SimC 반영, 3개 이상 경고)
    lines += [
        "  -- 장식 보너스 ID → { item = 장식 재료, use = 적용 가능 장비 }. 링크엔 \"8960:<ID>\"로 붙는다",
        "  embellishMarkers = { %s }," % ", ".join("[%d] = true" % m for m in EMBELLISH_MARKERS),
        "  embellishments = {",
    ]
    for bid, (item, use) in sorted(EMBELLISHMENTS.items()):
        lines.append('    [%d] = { item = %d, use = "%s" },' % (bid, item, use))
    lines += ["  },"]

    # 마법부여: 이름(enUS) = 애드온 동봉 enchantNames[4]와 매칭해 링크용 마법부여 ID를 런타임에 찾는다
    enchants = collect_enchants()
    if len(enchants) < 20:
        sys.exit("마법부여가 너무 적음(%d) — 와우헤드 응답 확인 필요" % len(enchants))
    lines += [
        "  -- 마법부여: s1/s2 = 1·2등급 고정 2차 스탯(nil = 계산 제외: 발동형·주 스탯·3차 스탯), item1/item2 = 등급별 주문서",
        "  enchants = {",
    ]
    for e in enchants:
        lines.append('    { name = "%s", slot = "%s", item1 = %d, item2 = %d, s1 = %s, s2 = %s },' % (
            e["name"].replace('"', '\\"'), e["slot"], e["item1"], e["item2"], lua_stats(e["s1"]), lua_stats(e["s2"])))
    lines += ["  },", "}", ""]
    open(a.out, "w", encoding="utf-8").write("\n".join(lines))
    print("items", len(items), "->", os.path.normpath(a.out), file=sys.stderr)


if __name__ == "__main__":
    main()
