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
        lines.append("    [%d] = { inv = %d, n = %d, specs = { %s } }, -- %s" % (
            item_id, j.get("slot") or 0, j["_nRandom"], specs, name))
    lines += ["  },", "}", ""]
    open(a.out, "w", encoding="utf-8").write("\n".join(lines))
    print("items", len(items), "->", os.path.normpath(a.out), file=sys.stderr)


if __name__ == "__main__":
    main()
