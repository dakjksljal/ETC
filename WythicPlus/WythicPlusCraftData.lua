-- 자동 생성 파일 — 수정 금지. 생성: tools/build-craft-data.py (와우헤드 제작법·아이템 데이터)
-- 시즌 전체 제작 장비. 아이템 선택창 「제작」 탭이 쓴다(유저가 2차 스탯을 지정해 핀 → 나머지 부위 재최적화).
-- 필드: inv = 장착 부위(INVTYPE 번호), n = 유저가 고르는 2차 스탯 수(0 = 스탯 고정), specs = 착용 가능 전문화(빈 표 = 전체)
WythicPlusCraftData = {
  season = "Midnight Season 2 (12.1)",
  generated = "2026-10-04",
  ilvl = 331, -- 최고 품질
  statIds = { crit = 32, haste = 36, mastery = 49, versatility = 40 }, -- 링크 modifier 29/30 값 (ITEM_MOD_*_RATING)
  bonus = { std = "12214:13667:12497:13751:14001:13836", twoHand = "12214:13667:12497:13751:14004:13836" }, -- 최고 품질 보너스 템플릿 (랭커 데이터에 없는 아이템용)
  twoHandInv = { [15] = true, [17] = true, [26] = true },
  items = {
    [237828] = { inv = 8, n = 2, cls = 4, prof = 164, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Spellbreaker's March
    [237829] = { inv = 5, n = 2, cls = 4, prof = 164, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Spellbreaker's Shelter
    [237830] = { inv = 6, n = 2, cls = 4, prof = 164, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Spellbreaker's Girdle
    [237831] = { inv = 14, n = 2, cls = 4, prof = 164, specs = { 73,1446,65,1451,262,264,1444,66 } }, -- Spellbreaker's Rebuke
    [237832] = { inv = 1, n = 2, cls = 4, prof = 164, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Spellbreaker's Cover
    [237833] = { inv = 7, n = 2, cls = 4, prof = 164, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Spellbreaker's Legguards
    [237834] = { inv = 9, n = 2, cls = 4, prof = 164, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Spellbreaker's Bracers
    [237835] = { inv = 3, n = 2, cls = 4, prof = 164, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Spellbreaker's Mantle
    [237836] = { inv = 10, n = 2, cls = 4, prof = 164, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Spellbreaker's Resolve
    [237837] = { inv = 13, n = 2, cls = 2, prof = 164, specs = { 259,1453,261,255 } }, -- Farstrider's Mercy
    [237838] = { inv = 13, n = 2, cls = 2, prof = 164, specs = { 62,102,258,105,256,63,64,257,262,264,265,266,267,1454,1465,1467,1468,1473,1480 } }, -- Magister's Ritual Knife
    [237839] = { inv = 13, n = 2, cls = 2, prof = 164, specs = { 577,255,251,260,268,581,1450,269,1451,66,1446,73 } }, -- Spellbreaker's Blade
    [237840] = { inv = 13, n = 2, cls = 2, prof = 164, specs = { 581,1456,1480,577 } }, -- Spellbreaker's Warglaive
    [237841] = { inv = 13, n = 2, cls = 2, prof = 164, specs = { 251,260,268,1450,269,1451,263,66,1446,73 } }, -- Spellbreaker's Ultimatum
    [237842] = { inv = 17, n = 2, cls = 2, prof = 164, specs = { 71,255,250,251,252,1455,70,72 } }, -- Bloomforged Greataxe
    [237843] = { inv = 13, n = 2, cls = 2, prof = 164, specs = { 62,63,1451,64,270,266,65,265,267,1454,1465,1467,1468,1473,1480 } }, -- Magister's Mana Sword
    [237844] = { inv = 13, n = 2, cls = 2, prof = 164, specs = { 262,270,65,1467,1451,1468,264,1473,1465,1480 } }, -- Magister's Cleaver
    [237845] = { inv = 13, n = 2, cls = 2, prof = 164, specs = { 577,260,1456,268,581,1450,269,263,1446,73 } }, -- Bloomforged Claw
    [237846] = { inv = 17, n = 2, cls = 2, prof = 164, specs = { 250,251,252,1455,70,71,72 } }, -- Blood Knight's Warblade
    [237847] = { inv = 17, n = 2, cls = 2, prof = 164, specs = { 255,103,104,252,1455,1447,251,268,70,269,250,71,72 } }, -- Blood Knight's Impetus
    [237848] = { inv = 17, n = 2, cls = 2, prof = 164, specs = { 71,103,72,104,250,251,1455,252,70 } }, -- Blood Knight's Mercy
    [237849] = { inv = 17, n = 2, cls = 2, prof = 164, specs = { 1465,102,1447,65,105,262,1468,264,1467,1473 } }, -- Magister's Valediction
    [237850] = { inv = 13, n = 2, cls = 2, prof = 164, specs = { 577,255,251,260,268,581,1450,269,263,1451,66,1446,73 } }, -- Farstrider's Chopper
    [239648] = { inv = 9, n = 2, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Martyr's Bindings
    [239649] = { inv = 6, n = 2, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Martyr's Waistwrap
    [239650] = { inv = 3, n = 2, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Martyr's Mantle
    [239651] = { inv = 7, n = 2, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Martyr's Leggings
    [239652] = { inv = 1, n = 2, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Martyr's Crown
    [239653] = { inv = 10, n = 2, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Martyr's Gloves
    [239654] = { inv = 8, n = 2, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Martyr's Slippers
    [239655] = { inv = 5, n = 2, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Martyr's Vestments
    [239656] = { inv = 16, n = 2, cls = 4, prof = 197, specs = { 261,254,62,1449,102,1447,105,255,577,63,64,270,262,1450,65,1451,256,250,257,1452,73,258,264,1444,66,265,1446,266,267,1454,1465,1467,1468,1473,1480,268,1456,581,103,104,253,260,1448,70,269,259,1453,263,251,252,1455,71,72 } }, -- Adherent's Silken Shroud
    [239657] = { inv = 9, n = 0, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Sunfire Bracers
    [239658] = { inv = 16, n = 0, cls = 4, prof = 197, specs = { 62,1449,102,1447,105,63,64,270,262,1450,65,1451,256,257,1452,258,264,1444,265,266,267,1454,1465,1467,1468,1473,1480 } }, -- Sunfire Cloak
    [239659] = { inv = 8, n = 0, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Sunfire Treads
    [239660] = { inv = 9, n = 0, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Arcanoweave Bracers
    [239661] = { inv = 16, n = 0, cls = 4, prof = 197, specs = { 62,1449,102,1447,105,63,64,270,262,1450,65,1451,256,257,1452,258,264,1444,265,266,267,1454,1465,1467,1468,1473,1480 } }, -- Arcanoweave Cloak
    [239662] = { inv = 8, n = 0, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Arcanoweave Treads
    [239663] = { inv = 6, n = 0, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Sunfire Sash
    [239664] = { inv = 6, n = 0, cls = 4, prof = 197, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Arcanoweave Cord
    [240949] = { inv = 11, n = 2, cls = 4, prof = 755, specs = {  } }, -- Masterwork Sin'dorei Band
    [240950] = { inv = 2, n = 2, cls = 4, prof = 755, specs = {  } }, -- Masterwork Sin'dorei Amulet
    [241139] = { inv = 2, n = 0, cls = 4, prof = 755, specs = {  } }, -- Thalassian Phoenix Torque
    [241140] = { inv = 11, n = 0, cls = 4, prof = 755, specs = {  } }, -- Signet of Azerothian Blessings
    [241340] = { inv = 12, n = 0, cls = 4, prof = 171, specs = {  } }, -- Magister's Alchemist Stone
    [244179] = { inv = 15, n = 2, cls = 2, prof = 333, specs = { 62,256,63,64,265,257,266,258,267,1454 } }, -- Magister's Grand Focus
    [244463] = { inv = 8, n = 2, cls = 4, prof = 164, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Murder Row Fleet Feet
    [244472] = { inv = 14, n = 2, cls = 4, prof = 164, specs = { 73,1446,65,1451,262,264,1444,66 } }, -- Knight-Commander's Palisade
    [244569] = { inv = 8, n = 2, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Silvermoon Agent's Sneakers
    [244570] = { inv = 5, n = 2, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Silvermoon Agent's Coat
    [244571] = { inv = 1, n = 2, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Silvermoon Agent's Cover
    [244572] = { inv = 3, n = 2, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Silvermoon Agent's Mantle
    [244573] = { inv = 6, n = 2, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Silvermoon Agent's Utility Belt
    [244574] = { inv = 7, n = 2, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Silvermoon Agent's Leggings
    [244575] = { inv = 10, n = 2, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Silvermoon Agent's Handwraps
    [244576] = { inv = 9, n = 2, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Silvermoon Agent's Deflectors
    [244577] = { inv = 8, n = 2, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Farstrider's Razor Talons
    [244578] = { inv = 5, n = 2, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Farstrider's Scouting Vest
    [244579] = { inv = 1, n = 2, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Farstrider's Unwavering Visage
    [244580] = { inv = 3, n = 2, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Farstrider's Brilliant Plumes
    [244581] = { inv = 6, n = 2, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Farstrider's Trophy Belt
    [244582] = { inv = 7, n = 2, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Farstrider's Reinforced Faulds
    [244583] = { inv = 10, n = 2, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Farstrider's Sharpened Claws
    [244584] = { inv = 9, n = 2, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Farstrider's Plated Bracers
    [244601] = { inv = 8, n = 0, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- World Tree Rootwraps
    [244602] = { inv = 10, n = 0, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Ranger-General's Grips
    [244605] = { inv = 9, n = 0, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Axe-Flingin' Bands
    [244606] = { inv = 6, n = 0, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Hexwoven Strand
    [244609] = { inv = 5, n = 0, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- World Tender's Trunkplate
    [244610] = { inv = 8, n = 0, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- World Tender's Rootslippers
    [244611] = { inv = 6, n = 0, cls = 4, prof = 165, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- World Tender's Barkclasp
    [244612] = { inv = 9, n = 0, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Row Walker's Deflectors
    [244613] = { inv = 5, n = 0, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Row Walker's Insurance
    [244614] = { inv = 10, n = 0, cls = 4, prof = 165, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Row Walker's Swiftgrips
    [244679] = { inv = 13, n = 2, cls = 2, prof = 164, specs = { 259,1453,261,255 } }, -- Murder Row Fishhook
    [244743] = { inv = 1, n = 1, cls = 4, prof = 202, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Aetherlume Eye Wrap
    [244744] = { inv = 1, n = 1, cls = 4, prof = 202, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Aetherlume Optics
    [244745] = { inv = 1, n = 1, cls = 4, prof = 202, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Aetherlume Vision Shroud
    [244746] = { inv = 1, n = 1, cls = 4, prof = 202, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Aetherlume Sun Guard
    [244747] = { inv = 9, n = 1, cls = 4, prof = 202, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Aetherlume Silken Cuffs
    [244748] = { inv = 9, n = 1, cls = 4, prof = 202, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Aetherlume Bands
    [244749] = { inv = 9, n = 1, cls = 4, prof = 202, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Aetherlume Bracelets
    [244750] = { inv = 9, n = 1, cls = 4, prof = 202, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Aetherlume Guards
    [244771] = { inv = 8, n = 1, cls = 4, prof = 202, specs = { 62,1449,1452,256,63,64,265,257,258,266,267,1454 } }, -- Aetherlume Softsteppers
    [244772] = { inv = 8, n = 1, cls = 4, prof = 202, specs = { 102,1447,105,270,1450,581,268,1456,1480,577,103,104,269,259,1453,260,261 } }, -- Aetherlume Runners
    [244773] = { inv = 8, n = 1, cls = 4, prof = 202, specs = { 253,262,1468,1444,264,1473,1465,1467,1448,254,255,263 } }, -- Aetherlume Clonkers
    [244774] = { inv = 8, n = 1, cls = 4, prof = 202, specs = { 65,1451,66,250,251,1455,252,70,71,72,1446,73 } }, -- Aetherlume Stompers
    [245769] = { inv = 23, n = 2, cls = 4, prof = 773, specs = { 62,1449,102,1447,105,63,64,270,262,1450,65,1451,256,257,1452,258,264,1444,265,266,267,1454,1465,1467,1468,1473,1480 } }, -- Aln'hara Lantern
    [245770] = { inv = 17, n = 2, cls = 2, prof = 773, specs = { 62,1449,102,1447,105,256,63,64,270,257,1452,258,262,264,265,266,267,1454,1465,1467,1468,1473 } }, -- Aln'hara Cane
    [245771] = { inv = 17, n = 2, cls = 2, prof = 773, specs = { 255,103,104,1447,268,269 } }, -- Aln'hara Pikestaff
    [246304] = { inv = 12, n = 0, cls = 4, prof = 773, specs = { 261,254,62,1449,102,1447,105,255,577,63,64,270,262,1450,65,1451,256,250,257,1452,73,258,264,1444,66,265,1446,266,267,1454,1465,1467,1468,1473,1480,268,1456,581,103,104,253,260,1448,70,269,259,1453,263,251,252,1455,71,72 } }, -- Darkmoon Dominion: Hunt
    [246305] = { inv = 12, n = 0, cls = 4, prof = 773, specs = { 261,254,62,1449,102,1447,105,255,577,63,64,270,262,1450,65,1451,256,250,257,1452,73,258,264,1444,66,265,1446,266,267,1454,1465,1467,1468,1473,1480,268,1456,581,103,104,253,260,1448,70,269,259,1453,263,251,252,1455,71,72 } }, -- Darkmoon Dominion: Blood
    [246306] = { inv = 12, n = 0, cls = 4, prof = 773, specs = { 261,254,62,1449,102,1447,105,255,577,63,64,270,262,1450,65,1451,256,250,257,1452,73,258,264,1444,66,265,1446,266,267,1454,1465,1467,1468,1473,1480,268,1456,581,103,104,253,260,1448,70,269,259,1453,263,251,252,1455,71,72 } }, -- Darkmoon Dominion: Rot
    [246307] = { inv = 12, n = 0, cls = 4, prof = 773, specs = { 261,254,62,1449,102,1447,105,255,577,63,64,270,262,1450,65,1451,256,250,257,1452,73,258,264,1444,66,265,1446,266,267,1454,1465,1467,1468,1473,1480,268,1456,581,103,104,253,260,1448,70,269,259,1453,263,251,252,1455,71,72 } }, -- Darkmoon Dominion: Void
    [251073] = { inv = 2, n = 0, cls = 4, prof = 755, specs = {  } }, -- Voidstone Shielding Array
    [251513] = { inv = 11, n = 0, cls = 4, prof = 755, specs = {  } }, -- Loa Worshiper's Band
    [265337] = { inv = 15, n = 2, cls = 2, prof = 773, specs = { 253,1448,254 } }, -- Aln'hara Sprigshot
    [268477] = { inv = 15, n = 1, cls = 2, prof = 202, specs = { 253,1448,254 } }, -- P.O.W. x3
  },
  -- 장식 보너스 ID → { item = 장식 재료, use = 적용 가능 장비 }. 링크엔 "8960:<ID>"로 붙는다
  embellishMarkers = { [8960] = true, [13555] = true },
  embellishments = {
    [12384] = { item = 240166, use = "armor" },
    [12385] = { item = 240164, use = "armor" },
    [12685] = { item = 244674, use = "weaponArmor" },
    [12686] = { item = 244603, use = "equipment" },
    [12687] = { item = 244607, use = "weaponArmor" },
    [12692] = { item = 245877, use = "weaponOffhand" },
    [12693] = { item = 245875, use = "weaponOffhand" },
    [12705] = { item = 245871, use = "weaponOffhand" },
    [12715] = { item = 248130, use = "equipment" },
    [12717] = { item = 248132, use = "engBoots" },
    [12990] = { item = 248135, use = "engEquip" },
    [12991] = { item = 248136, use = "equipment" },
    [13453] = { item = 251487, use = "equipment" },
    [13454] = { item = 251489, use = "equipment" },
    [13556] = { item = 255843, use = "engEquip" },
    [13640] = { item = 245873, use = "weaponOffhand" },
    [13767] = { item = 273068, use = "equipment" },
    [13768] = { item = 273065, use = "accessory" },
    [13769] = { item = 273062, use = "engGun" },
    [13771] = { item = 273059, use = "bsWeapon" },
  },
  -- 마법부여: s1/s2 = 1·2등급 고정 2차 스탯(nil = 계산 제외: 발동형·주 스탯·3차 스탯), item1/item2 = 등급별 주문서
  enchants = {
    { name = "Sunfire Silk Spellthread", slot = "LEGS", item1 = 240094, item2 = 240094, s1 = nil, s2 = nil },
    { name = "Arcanoweave Spellthread", slot = "LEGS", item1 = 240154, item2 = 240155, s1 = nil, s2 = nil },
    { name = "Bright Linen Spellthread", slot = "LEGS", item1 = 240156, item2 = 240157, s1 = nil, s2 = nil },
    { name = "Enchant Chest - Mark of Nalorakk", slot = "CHEST", item1 = 243946, item2 = 243947, s1 = nil, s2 = nil },
    { name = "Enchant Helm - Hex of Leeching", slot = "HEAD", item1 = 243948, item2 = 243949, s1 = nil, s2 = nil },
    { name = "Enchant Helm - Empowered Hex of Leeching", slot = "HEAD", item1 = 243950, item2 = 243951, s1 = nil, s2 = nil },
    { name = "Enchant Boots - Lynx's Dexterity", slot = "FEET", item1 = 243952, item2 = 243953, s1 = nil, s2 = nil },
    { name = "Enchant Ring - Amani Mastery", slot = "FINGER", item1 = 243954, item2 = 243955, s1 = { mastery = 22 }, s2 = { mastery = 24 } },
    { name = "Enchant Ring - Eyes of the Eagle", slot = "FINGER", item1 = 243956, item2 = 243957, s1 = nil, s2 = nil },
    { name = "Enchant Ring - Zul'jin's Mastery", slot = "FINGER", item1 = 243958, item2 = 243959, s1 = { mastery = 27 }, s2 = { mastery = 29 } },
    { name = "Enchant Shoulders - Flight of the Eagle", slot = "SHOULDER", item1 = 243960, item2 = 243961, s1 = nil, s2 = nil },
    { name = "Enchant Shoulders - Akil'zon's Swiftness", slot = "SHOULDER", item1 = 243962, item2 = 243963, s1 = nil, s2 = nil },
    { name = "Enchant Weapon - Strength of Halazzi", slot = "WEAPON", item1 = 243968, item2 = 243969, s1 = nil, s2 = nil },
    { name = "Enchant Weapon - Jan'alai's Precision", slot = "WEAPON", item1 = 243970, item2 = 243971, s1 = nil, s2 = nil },
    { name = "Enchant Weapon - Berserker's Rage", slot = "WEAPON", item1 = 243972, item2 = 243973, s1 = nil, s2 = nil },
    { name = "Enchant Chest - Mark of the Rootwarden", slot = "CHEST", item1 = 243974, item2 = 243975, s1 = nil, s2 = nil },
    { name = "Enchant Chest - Mark of the Worldsoul", slot = "CHEST", item1 = 243976, item2 = 243977, s1 = nil, s2 = nil },
    { name = "Enchant Helm - Blessing of Speed", slot = "HEAD", item1 = 243978, item2 = 243979, s1 = nil, s2 = nil },
    { name = "Enchant Helm - Empowered Blessing of Speed", slot = "HEAD", item1 = 243980, item2 = 243981, s1 = nil, s2 = nil },
    { name = "Enchant Boots - Shaladrassil's Roots", slot = "FEET", item1 = 243982, item2 = 243983, s1 = nil, s2 = nil },
    { name = "Enchant Ring - Nature's Wrath", slot = "FINGER", item1 = 243984, item2 = 243985, s1 = { crit = 22 }, s2 = { crit = 24 } },
    { name = "Enchant Ring - Nature's Fury", slot = "FINGER", item1 = 243986, item2 = 243987, s1 = { crit = 27 }, s2 = { crit = 29 } },
    { name = "Enchant Shoulders - Nature's Grace", slot = "SHOULDER", item1 = 243988, item2 = 243989, s1 = nil, s2 = nil },
    { name = "Enchant Shoulders - Amirdrassil's Grace", slot = "SHOULDER", item1 = 243990, item2 = 243991, s1 = nil, s2 = nil },
    { name = "Enchant Weapon - Worldsoul Cradle", slot = "WEAPON", item1 = 243996, item2 = 243997, s1 = nil, s2 = nil },
    { name = "Enchant Weapon - Worldsoul Aegis", slot = "WEAPON", item1 = 243998, item2 = 243999, s1 = nil, s2 = nil },
    { name = "Enchant Weapon - Worldsoul Tenacity", slot = "WEAPON", item1 = 244000, item2 = 244001, s1 = nil, s2 = nil },
    { name = "Enchant Chest - Mark of the Magister", slot = "CHEST", item1 = 244002, item2 = 244003, s1 = nil, s2 = nil },
    { name = "Enchant Helm - Rune of Avoidance", slot = "HEAD", item1 = 244004, item2 = 244005, s1 = nil, s2 = nil },
    { name = "Enchant Helm - Empowered Rune of Avoidance", slot = "HEAD", item1 = 244006, item2 = 244007, s1 = nil, s2 = nil },
    { name = "Enchant Boots - Farstrider's Hunt", slot = "FEET", item1 = 244008, item2 = 244009, s1 = nil, s2 = nil },
    { name = "Enchant Ring - Thalassian Haste", slot = "FINGER", item1 = 244010, item2 = 244011, s1 = { haste = 22 }, s2 = { haste = 24 } },
    { name = "Enchant Ring - Thalassian Versatility", slot = "FINGER", item1 = 244012, item2 = 244013, s1 = { versatility = 22 }, s2 = { versatility = 24 } },
    { name = "Enchant Ring - Silvermoon's Alacrity", slot = "FINGER", item1 = 244014, item2 = 244015, s1 = { haste = 27 }, s2 = { haste = 29 } },
    { name = "Enchant Ring - Silvermoon's Tenacity", slot = "FINGER", item1 = 244016, item2 = 244017, s1 = { versatility = 27 }, s2 = { versatility = 29 } },
    { name = "Enchant Shoulders - Thalassian Recovery", slot = "SHOULDER", item1 = 244018, item2 = 244019, s1 = nil, s2 = nil },
    { name = "Enchant Shoulders - Silvermoon's Mending", slot = "SHOULDER", item1 = 244020, item2 = 244021, s1 = nil, s2 = nil },
    { name = "Enchant Weapon - Flames of the Sin'dorei", slot = "WEAPON", item1 = 244026, item2 = 244027, s1 = nil, s2 = nil },
    { name = "Enchant Weapon - Acuity of the Ren'dorei", slot = "WEAPON", item1 = 244028, item2 = 244029, s1 = nil, s2 = nil },
    { name = "Enchant Weapon - Arcane Mastery", slot = "WEAPON", item1 = 244030, item2 = 244031, s1 = nil, s2 = nil },
    { name = "Forest Hunter's Armor Kit", slot = "LEGS", item1 = 244640, item2 = 244641, s1 = nil, s2 = nil },
    { name = "Blood Knight's Armor Kit", slot = "LEGS", item1 = 244642, item2 = 244643, s1 = nil, s2 = nil },
    { name = "Thalassian Scout Armor Kit", slot = "LEGS", item1 = 244644, item2 = 244645, s1 = nil, s2 = nil },
    { name = "Enchant Weapon - Rite of the Hash'ey", slot = "WEAPON", item1 = 273071, item2 = 273072, s1 = nil, s2 = nil },
  },
}
