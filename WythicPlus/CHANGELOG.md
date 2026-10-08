# Changelog

## Unreleased

### Added
- **All 21 gems in the gem picker.** After the rankers' gems for the slot (sorted by player count), the picker lists every other gem in the data, so all 21 can be chosen in any socket. Gems no ranker uses show a dash instead of a player count.
- **Second gem on its own line.** On a two-socket item (e.g. a neck), the second gem now shows on its own line under the first instead of being joined on one line and cut off. Clicking that line opens the picker for socket 2.
- **Crafted tab in the item picker.** A fifth tab lists every crafted item of the season that fits the slot and your specialization (98 items, collected from Wowhead by `tools/build-craft-data.py` into `WythicPlusCraftData.lua`). Pick the secondary stats with the four stat buttons (up to two; items with one stat choice use the first, "Fixed" items have no choice), then click an item: it is pinned at max crafting quality (331) with that item level's secondary budget split evenly over your stats, and the optimizer re-optimizes the other slots around it like any pin. Changing the stat buttons updates a crafted pin in place. Bonus IDs (embellishment included) follow the rankers' copy of the same item when one exists. Card chip reads "Crafted · Crit/Haste", tooltips show the chosen stats, the SimC export carries `crafted_stats`, and "Equip all bag picks" skips crafted pins (you don't own them yet)
- The picker tabs are 46px wide (was 58px) so the fifth tab fits
- **Gems, enchants and embellishments for items you pick yourself.** Applies only to items you choose (any tab); automatic recommendations are unchanged
  - Gems: a slot you picked an item for is assumed socketable (one socket) wherever rankers socket that slot (neck, rings, head, wrist, waist), so the optimizer suggests a gem there and the gem picker opens from the "◇ Empty socket" line even if your current item has no socket
  - Enchants: clicking a card's enchant line now opens an enchant picker (it used to open the gem picker). Every enchant of the season is listed at max rank; flat secondary-stat enchants (the ring enchants) are scored as the difference from the enchant you wear now, other effects (procs, primary or tertiary stats) are selectable but not scored. Without a choice the worn enchant is assumed to carry over. Choices are saved in presets and exported to SimC (`enchant_id`, gems for picked items)
  - Embellishments (Crafted tab only, since only crafted gear can be embellished): "Meta pick" (default), "None" or any of the season's embellishments that fit the item; the link, tooltip and SimC export follow the choice, the effect itself is not scored. Fixed-stat crafted items keep their built-in embellishment
  - A warning appears under the header when the shown setup has 3 or more embellished items
  - Every picker tab (Meta, Bags, Dungeons, Raids, Crafted) ends with a "Gems · Enchant" section for the slot, for picked items and the item you wear alike. The number of gem rows follows the item: the larger of its real sockets and the sockets that can be added there (from ranker gem data: 2 on the neck, 1 on rings, head, wrist and waist); each row is tagged [Socket] or [Can add]. A second gem row covers two-socket items
  - Replacing an item you wear with one you pick drops its old gems and enchant: the new item starts with no enchant (a bag item keeps its own enchant and gems) until you choose one. Automatic recommendations keep the previous behavior (worn enchant carried over)
  - Crafted and Bags tabs get the same five upgrade-track buttons as the Meta tab. Crafted: Veteran 292 / Champion 305 / Hero 318 / Myth 331 (default), set through the crafting quality and crest bonus IDs. Bags: the item is assumed upgraded to that track's max (click the active button again to go back to its real item level); items without a track stay as they are

## v1.6.45 (2026-09-26)

### Fixed
- **The same trinket (or ring) is no longer recommended for both slots.** The optimizer's pick and the "meta top" fallback shown on a slot that got no pick are independent paths, so with a raid filtered out and only one non-raid trinket left in the meta, both trinket slots showed that one item. As on the website, the card now stays only on the slot whose worn item has the lower item level (ties keep slot 1, pins are never removed); the other slot keeps only its gem and enchant lines
- **Ring and trinket cards no longer show a bare base item.** Rings and trinkets are picked from both slots' candidate lists combined, but a card looked up its item level and bonus IDs only in its own slot's list. An item present only in the other slot's list showed no item level, and its tooltip rendered the base item without bonus IDs (a low-level rare version). The lookup now falls back to the paired slot's list

## v1.6.42 (2026-09-23)

### Fixed
- **The optimizer no longer recommends a strictly weaker item.** A candidate whose item level is not higher than the piece you wear and that has no secondary stat above it (typically a lower-item-level copy of the very same item with the same stat split, such as worn 308 boots and a 295 copy in your bags) is never recommended, in Bags mode or Meta mode. The meta-distance measure only looks at the stat split, so shedding stats you had "too much" of could look like an improvement even though the swap was a pure downgrade
## v1.6.39 (2026-09-22)

### Fixed
- **Catalyst-converted Venomcursed tier is now recognised as a Venomcursed item.** A Venomcursed piece converted into tier keeps the original's single secondary stat and its equip proc, but carries the tier item's ID, so the priority rule never saw it. The addon now also reads the conversion source from the item link (and the website from ranker data), and the optimizer applies the priority rule to slots where it picks between copies of the same tier piece (the set count cannot change there). A converted copy in your bags is preferred over a plain copy of the same tier piece, and a worn converted copy is kept instead of being swapped for a plain one
- **Pinned or locked trinkets stay put.** Trinkets are chosen as a pair from both slots' candidate lists, so emptying one slot's list for a pin or a slot lock still let the other list's trinket flow into the locked slot: the optimizer quietly swapped your pinned trinket back out while the arrow kept showing the pin, and its stats never appeared in the stat deltas (a pinned Critical Strike trinket showed +0 Critical Strike). A trinket slot without candidates is now left alone and its trinket is excluded from the other slot's picks
- **Pins re-read their stats and item level from the item link at simulation time.** The snapshot taken when a pin is created could be empty or stale (item data not yet loaded, older presets), and was fed to the optimizer as if worn. A pin is also treated as "already worn" when the worn item matches by ID, item level and secondary stats, not only by identical link text, so moving a pinned bag item onto your character no longer leaves a phantom "swap to the same item" recommendation
- **Gear panel no longer goes blank after an optimizer core update.** A core build contained a construct the game client's Lua does not support, which made the whole core fail to load (scores, stat bars and meta distance empty, only gem and enchant arrows left). The build now refuses to produce such output

### Added
- **`/wythic dump` diagnostic toggle.** When enabled, the optimizer writes the exact trinket inputs it receives (worn items, candidates, pins, locks, overrides) to the saved variables on every run, so a reported case can be reproduced outside the game after a `/reload`. Off by default; turning it off clears the record

## v1.6.37 (2026-09-21)

### Fixed
- **Bags mode no longer recommends a socket-less copy of the gemmed piece you already wear.** The game's item-stat API returns an item's stats without its gems, but the addon treated that value as gem-inclusive and subtracted the worn gem's stats once more, so a worn belt with Mastery 83 and a Mastery/Haste gem was read as Mastery 67 and the copy without a socket in your bags (Mastery 83) looked like a different item with a better stat split. Worn items are now read without their gems for the item's own stats, and the gem's stats are added on top from the ranker gem table (or measured in game when the API does include them)

## v1.6.36 (2026-09-20)

### Fixed
- **Raid Bind-on-Equip items no longer show "Random Stat 1 / Random Stat 2" in the optimizer tooltips.** Season 2 raid BoEs (Pauldrons of the Forgotten Sacrifice and the other Venomous Abyss BoEs) roll their two secondary stats per item, and the link the addon assembles from ranker data cannot carry that roll, so the game drew placeholders. The addon now compares the secondary-stat lines the game draws against the collected ranker split and rewrites them with that split at the shown item level whenever they differ or are placeholders. The same comparison now feeds the numbers when you pick an upgrade track for such an item (previously the track changed nothing for them). One rule covers Catalyst-converted tier, crafted pieces and any future stat mechanic
- **Korean client: stat lines are now corrected in place.** The Korean client writes stat lines as "가속 +100" (name first) while the previous check only understood "+100 Haste", so Catalyst-converted tier tooltips appended a footer line instead of correcting the stat lines themselves
- **SimC export includes `crafted_stats` for worn crafted and raid BoE items**, read from the item link's crafting-stat modifiers, so SimulationCraft uses their actual secondary stats
- **Bags mode: a second copy of the item you wear with different secondary stats can now be picked and recommended.** Catalyst-converted tier and raid BoEs share one item ID across several stat splits, but the addon treated "same item ID at the same or lower item level" as the piece you already wear: it dropped the copy from the candidates, ignored the pick in the item selector and hid the card. Candidates are now identified as physical items (item ID, item level and secondary stats; links in the UI), so such a copy is a regular candidate. A higher-item-level copy is still recommended outright; a same-level copy with a different split is recommended only when it moves you closer to the ranker split. The item selector's "worn" check mark on the Bags tab now marks the exact worn item only

## v1.6.34 (2026-09-20)

### Fixed
- **Bags mode now recommends a higher-item-level copy of an item you already wear.** A bag item with the same item ID as your worn piece but a higher item level (e.g. worn tier gloves at 308, a 311 copy in your bags) used to count as "already equipped", so it was never suggested even when it scored better once the gems were re-picked (manual 98.7 vs. automatic 98.0). Such copies are now regular upgrade candidates. Meta mode is unchanged
- **Trinkets are no longer recommended in two rounds.** With the #2 trinket in your first slot and a lower one in the second, the optimizer suggested swapping the first slot to #1 (pushing #2 out) and only after you equipped it suggested #2 for the second slot. It now decides the target pair first, keeps trinkets you already wear where they are, and fills only the open slot
- **The remaining tier slot of a 4-piece wearer is no longer frozen.** It is optimized like any other slot; previously it received no recommendation at all

### Added
- **Venomcursed proc items are prioritized.** The five Venomcursed pieces from Ula'tek (Venomkeeper's Horrific Cowl, Gaze of the Coiled Watcher, Awoken Dreadfang Cuirass, Chausses of Unbound Rancor, Aqirbane Reliquary) are recommended whenever they are among the candidates, even up to 10 item levels below your worn piece, and a worn one is kept unless a candidate beats it by more than 10 item levels. Slots wearing tier (4-piece) are left alone. Applies to Meta and Bags mode; the website applies the same rule
- **Weapon + trinket 2-piece sets are handled as a set.** If your equipped weapon and trinket belong to the same set (Zul'jin's Guillotine Technique with its matching weapon), the optimizer keeps both and only fills the other trinket slot. If the set weapon and trinket are among the candidates (ranker data in Meta mode, your bags in Bags mode), both are recommended together whenever each piece is within your configured item-level tolerance of the item it replaces (the Gear Optimizer settings "item-level tolerance" for the trinket and "weapon tolerance" for the weapon): the weapon in its slot and the trinket in place of your lower-ranked trinket. The Venomcursed priority rule uses the same settings. Two-handed set weapons are not suggested to players using a one-hander plus off-hand. Requires the set pieces to be present in the ranker data so the addon can recognise the set

## v1.6.31 (2026-09-18)

### Fixed
- **Bags mode no longer changes with the raid checkboxes.** The raid checkboxes only mean "don't recommend items from a raid I don't run", so Bags mode (candidates are what you already own) shows them disabled. Yet the Bags simulation was still reading ranker reference data with those raids filtered out, so unchecking a raid on the Meta tab could quietly change set detection, allowed item types and the item-level ceiling used for your bag picks. Bags mode now always uses the full ranker data
- **League tooltip missing for some characters on Korean and Taiwanese clients.** On those clients the game reports realm names in the local language, so the addon matched characters by name and region instead. To avoid showing the wrong person, it skipped any name that also exists on another realm in the same region, so those characters never got a "Wy+" line (a player's own line could disappear the day a same-named character joined the league). The daily data now ships a realm-name table and the addon matches name and realm exactly, so same-named characters on different realms each show their own rank. Requires league data from 2026-09-18 or later; older data keeps the previous behaviour

## v1.6.26 (2026-09-14)

### Added
- **Bags mode now plans Catalyst conversions.** If you hold Venomblight Manaflux (the Season 2 Catalyst charge), the optimizer treats convertible non-set items in the five tier slots — in your bags or worn — as what they become after conversion: the tier piece with that item's own item level and secondary stats. It recommends the conversions that complete your 2- or 4-piece bonus, converts only as far as your charges reach a bonus threshold, never goes past 4 pieces, and prefers the slots where rankers wear tier. The card is labelled "Catalyst" with a Manaflux-icon chip reading "Set conversion needed"; its tooltip shows the post-conversion piece plus which bag/worn item to convert and how many charges you hold, and Shift+click locks it like any other pick
- **Bags mode now searches every gear combination instead of settling one slot at a time.** When the number of candidate combinations is small (as it is with your own bags), the optimizer evaluates all of them and picks the best; the previous one-slot-at-a-time approach could miss sets where three pieces only pay off when changed together (e.g., automatic 90.5 vs. manual 92.1). Large candidate pools (Meta mode) keep the fast approach
- **Item level next to the meta distance.** The header now reads "Meta distance X → Y" followed by "Item level current → after picks" (green when it rises, red when it drops), so you can see the item-level trade-off of a stat-driven recommendation at a glance
- **"Equip all bag picks" button** (under the slot-lock hint) equips every displayed bag recommendation and bag pick into its slot in one go — rings and trinkets land in the intended slot. Catalyst-conversion picks are skipped, combat blocks equipping, and bind-on-equip items still show the game's confirmation
- **Gear Optimizer settings.** The settings window (minimap menu, `/wp config`, or the new gear button in the gear window) has a "Gear Optimizer" section: the item-level tolerance for Bags mode (how many item levels below your worn piece a bag item may be and still count — default 13, one upgrade step; weapons default 0) and a switch for Catalyst conversion planning. Changes apply to the open gear window immediately

### Fixed
- **Settings: "Use combat log feature" now behaves as a real master switch.** Turning it on also turns combat logging on right away (it already turned logging off when unchecked), and while it is off the manual toggle in the settings window is locked, and the minimap menu toggle and `/wp on` explain that the feature is off instead of enabling logging behind the switch
- The settings window is drawn 25% larger, text included, and laid out as one system: labels in a left column, controls in a right column, section headers with dividers, consistent row height and label font, notes set apart under each section. It opens at the center of the screen, its checkboxes are now toggle switches, and its close button matches the flat style. The gear window has a labelled Settings button between Reset and Presets
- **EllesmereUI auto-logging is now detected from its settings** at login and whenever the settings window opens, so the combat-log controls lock immediately. Previously it was only detected after EllesmereUI actually switched logging on (i.e., inside a dungeon), so outside instances the controls stayed operable despite the external control
- **The optimizer could miss a better set of gear that you could assemble by hand** (e.g., automatic 85.4 vs. manual 90.9). Two causes: in Bags mode the tier pieces you wear were invisible to the engine, so it could neither count your set nor complete it; and with 5 tier pieces worn, the surplus piece was locked even though the set bonus stops at 4. Worn tier pieces are now part of the candidate pool, and a surplus tier piece can be swapped for a non-set item when that genuinely improves the meta distance — exactly one swap per surplus piece, so the 4-piece bonus is always kept. The website's optimizer applies the same surplus rule

## v1.6.24 (2026-09-13)

### Fixed
- **The gear optimizer could suggest a swap that lowered your meta score** (e.g., "Meta distance 85.9 -> 85.1"). In Bags mode, when you already wear the 4-piece tier set, a fifth tier piece sitting in your bags was force-placed into a non-set slot — the set bonus stops at 4 pieces, so all you got was the lower item level. The optimizer now recognizes the tier pieces you are wearing and stops treating a surplus piece as a set piece; it is still considered on its stats alone, so it is recommended when it genuinely wins
- **Badge titles and enchant names now display in English on non-Korean clients.** Western client fonts have no Korean glyphs, so those names rendered as empty boxes in the league tooltip, the gear window header, and enchant recommendations. The server now ships both names and the addon picks by client locale; the SimC profile error message was also missing from the translation table

## v1.6.22 (2026-09-12)

### Fixed
- **No more gem suggestions for slots that have no socket.** Ranker gem data exists for wrists, belts, and helms because some rankers add a socket there; the optimizer suggested those gems (and showed the empty-socket line) even when your equipped item has no socket. It now counts the sockets on the item you wear (empty + filled) and skips gem suggestions when there are none. The website applies the same rule
- **No more empty-socket placeholder in the recommendation lane.** While optimizing, only real gem recommendations (and your own picks) are shown next to a slot — a slot that needs no gem change shows nothing gem-related. The placeholder used to sit in the same spot with the same arrow as a real recommendation, so it read as "swap your gem for nothing". The empty-socket line (now labelled "Empty socket" rather than "Choose gem") appears on the normal view, where you can click it to pick a gem. Same on the website

## v1.6.21 (2026-09-12)

### Fixed
- **The gear window could open as an empty shell (black slots, no numbers) on the 12.x client** — typically in combat or inside an instance, when the game hands addons "secret" buff names. The food/flask warning scanned buff names and errored on a secret one, which aborted the whole draw. Sealed names are now skipped silently (only the buff warning is affected); reported via Discord with the error text

## v1.6.20 (2026-09-12)

### Added
- **Gem picker: "Empty" entry to remove a gem.** When a slot has a gem equipped (or a gem pinned/recommended), the gem picker now starts with an empty-socket entry; pick it to see your stats with that gem removed — the slot shows the usual empty-socket line and the stat bars show the loss. Click the line to pick a gem again, or press Reset. Saved in presets and honored by the SimC export
- The gear optimizer window now closes with Esc, like the Settings window

## v1.6.19 (2026-09-11)

### Fixed
- **The gear window could keep "refreshing" — the character model jittered and the game stuttered, and opening/closing it repeatedly dragged the frame rate down.** The window redrew itself in full (diagnosis, simulation, all 16 slots, and a model reset) on every item-info event the client fired, including lookups made by other addons, and its own cache requests triggered more events in a chain; an item that failed to load re-requested itself forever. It now reacts only to items it asked for, never re-requests a failed one, coalesces bursts into a single redraw, and re-sets the model only when the window opens or your gear/spec/form changes
- The version label in the bottom-right corner of the gear window showed a doubled prefix (e.g., `vv1.6.18`)

### Changed
- **Stat comparison bars are drawn by percentage again** (reverting v1.6.18's rating-based length). The percentage on the right is what you compare against the meta, so the bar follows it, and the amber/red segment while optimizing now spans exactly the change from your current percentage to the recommended one — e.g., a recommendation that takes you from 54.3% to 55.29% against a 54.90% meta average now shows your bar overtaking the meta bar. The rating printed inside the bar is a label only and can rank differently from the bar length when a buff or passive adds percent without rating
- **Daily data-only releases now use the same version numbering as code releases** (the next patch number, e.g., v1.6.20) instead of date tags like `v2026.09.11`. Mixed schemes made the version list on CurseForge/Wago hard to read, and date tags sorted above newer code releases. Data releases carry no changelog entry; if a version is missing here, it only refreshed the bundled meta and league data

## v1.6.18 (2026-09-11)

### Fixed
- **Stat comparison bars could contradict the numbers printed on them**: the bar length was scaled by the stat percentage while the number inside the bar is the rating, so with a temporary haste-percent buff active (one that adds % without rating) your bar drew longer than the meta-average bar even though your rating was lower (e.g., 1,134 vs 1,176). Bar lengths are now scaled by rating, the same as the website, so a longer bar always means a bigger number. Percent labels on the right are unchanged; recommendation math was never affected

## v1.6.17 (2026-09-10)

### Fixed
- **The "update your addon" login notice only fired after 10 days, even though meta and league data are released every day.** The threshold dated from when gear meta shipped weekly; users could sit on week-old rankings without ever being told. The notice now fires on every login as soon as the bundled gear meta is a day behind the latest daily release (the data carries its build date), and its wording says a newer data release is available and that data is updated daily. The league week field is only a fallback guard, since it holds the weekly reset date rather than the build date

## v1.6.16 (2026-09-10)

### Fixed
- **Converted tier pieces showed an impossible stat combination in addon-built tooltips** (e.g., the Blood DK #2 legs — the tier greaves converted from the Venomcursed raid legs — showed Crit + Mastery + the Venomcursed equip effect, while the real item is Crit only + the effect). Since 12.1 a catalyzed tier piece inherits the stat split and cantrip of the item it was made from, and the game encodes that in the item link as modifier 64 (redirected base stats = source item ID), not in bonus IDs — so links the addon built from bonus IDs alone rendered the tier's default split. The addon now appends that modifier (source item resolved from the meta data, or from the Venomcursed item of the same slot and armor type for raid conversions) to every link it builds for converted variants: item picker and recommendation tooltips, upgrade-track stat reads, and the SimC export (`redirected_base_stats=`). As a safety net, if the source cannot be resolved the tooltip's stat lines are rewritten to the collected split. Recommendation numbers were already based on the collected stats and are unchanged

## v1.6.15 (2026-09-09)

### Fixed
- **Choosing an upgrade track in the Meta tab now changes the stat numbers**: the selected track (e.g., Myth 334) used to update only the tooltip item level while the simulation kept the stats at the collected item level, so "Gear +N" did not move. The addon now rebuilds the item link with the track's bonus IDs and reads the real stats from the game client at that item level — the same result the website gets from Wowhead, with no linear estimation. Applies both to pinned items and to a track chosen on the recommended item; bag recommendations and fixed-level Venomcursed items are unaffected

## v1.6.14 (2026-09-09)

### Fixed
- **Dual-primary-stat gear (Agility/Intellect, Strength/Intellect) showed the wrong primary stat in addon-built tooltips**: item links the addon constructs (item picker, recommendation cards, track re-links, upper-Myth links) had no specialization ID, so the client displayed the item's default stat (e.g., Intellect on a Guardian Druid). Links now carry the current specialization, and Encounter Journal links are refreshed on spec change. Display-only — recommendations were unaffected
- **"By Bags" mode kept recommending trinkets forever**: equipped trinkets were not part of the candidate pool, so any trinket in your bags was always recommended, and after equipping it the trinket you just removed was recommended back. Equipped trinkets are now candidates, so nothing is recommended when what you wear is already the best you own
- **Stat rating labels dropped sharply when optimization was on** (e.g., 1121 → 897 for a −27 gem change): the engine's baseline counts items and gems only, excluding enchants and food/flask buffs. The label and bar now show your in-game rating plus the change, matching the website

### Changed
- The permanent "use this unbuffed" notice is replaced by a blinking warning that appears only while a Well Fed or Flask/Phial buff is active, naming the buff and noting that readouts may be inaccurate. Augment runes are ignored (primary stat only)

## v1.6.13 (2026-09-08)

### Changed
- Right-clicking a slot or weapon icon no longer opens the gem picker — gem customization is now only via the gem line under the card (◇ or the equipped gem icon)

## v1.6.12 (2026-09-08)

### Changed
- Track button "Final Bosses 344" renamed to **"Upper Myth"** (same function: the fixed-344 drops from the last two Mythic bosses)
- Mode button "By Bags" wording unified with the Bags tab (Korean label)

## v1.6.11 (2026-09-08)

Loot browser (Dungeons & Raids tabs) + pins that actually re-optimize the rest of your set

### Added
- **Dungeons & Raids tabs in the item picker**: every item your class can equip for that slot, straight from the Encounter Journal — this season's M+ rotation dungeons and both raids, grouped per instance in compact rows. Class/spec and armor-material filtered; items that also appear in the ranker meta show their adoption rank (top 5 only)
- **Upgrade-track selector on those tabs**: every shown item is re-linked to the selected track, so the card's item level, the tooltip, and the pinned stats all come from one and the same link
- **"Final Bosses 344" track**: the last two Mythic bosses drop fixed 344 items above the Myth track — selectable on the Meta/Raids tabs (validated at runtime against the game, not hardcoded), with a tooltip note explaining the ladder (Mythic direct drop 344 vs. vault path 318–334)
- Picking an item from the default view starts optimization immediately (Bags tab → By Bags, any other tab → By Meta)
- Bags-tab items now show their meta adoption rank too

### Changed
- **Pinning an item re-optimizes the rest of the set in By Meta mode as well** (previously only By Bags): the pin's stats are locked into the baseline and the other slots re-shuffle to compensate — swap to a stat-heavy neck and the rest of the recommendations follow
- **Pin ≠ lock**: a new manual pick releases your previous unlocked pins back to the optimizer. Want a slot to stay put? Lock it (Shift+Click or the picker's lock button)
- **Rings and trinkets are one pool**: both slots share the unified adoption ranking and only ranks 1–5 are considered — no more "#9" filler picks on paired slots
- The item picker now opens right beside the icon you clicked instead of dropping over the whole armory
- Source colors are consistent everywhere — meta amber / bags emerald / dungeon sky / raid violet across tab buttons, armory cards, borders, arrows, badges, and picker highlights; dungeon/raid picks are badged "Custom"
- Selected tab/track buttons keep white text on a translucent accent (no more black-on-amber)

### Fixed
- **Raids tab could stay empty for a whole session**: empty Encounter Journal responses (lazy server loading) were being cached — they no longer are, and data fills in automatically when it arrives. A raid tab emptied by your raid filter now says so instead of pretending the journal is loading
- Rings missing from the journal tabs: the journal's global slot/loot filters leaked into our queries (now reset before every query) and spec-agnostic items were misread as unusable
- Pinning the same item at or below your equipped item level is treated as "keep equipped" — it used to silently lower the simulated stats while showing no card
- Presets and slot-lock promotion now preserve a pick's source tab: a raid pick restored from a preset shows raid colors again, and meta 344-link pins no longer masquerade as "Bags"

## v1.6.10 (2026-09-08)

### Changed
- **Combat logging is now opt-in per dungeon instead of per login**: nothing happens at login anymore. When you enter a dungeon or raid, the addon asks whether to enable combat logging (or enables it silently if you turn on the auto option). No more per-character popups or reload spam — many players never upload logs, and they shouldn't be nagged
- **New Settings window** (minimap right-click → Settings, or `/wp config`): a master "Enable combat log feature" switch at the top — turn it off and every prompt, auto-enable, and indicator goes quiet (minimap border turns gray). Below it: the dungeon-entry popup toggle and dungeon auto-enable
- The dungeon popup asks once per instance run (re-entering the same dungeon won't re-ask; resetting instances asks again), has a "Don't ask again" button, and a pending popup closes when you leave
- **Plays nice with other auto-logging addons**: if another addon (e.g., an auto-logger module) is managing combat logging, Wythic+ detects it, skips its own prompts/auto-enable for the session, and the Settings window shows which addon is in charge
- The Settings window also shows the live combat-log state with an instant Enable/Disable button, and checkbox labels are clickable
- Minimap menu simplified to three rows: Gear Optimizer, combat-log toggle, Settings
- `/wp auto` now toggles dungeon-entry auto-enable; `/wp config` opens Settings; `/wp status` shows the full switch state; `/wp help` updated

### Fixed
- **Raid-filtered items could still appear as the meta-top suggestion card**: the engine respected the filter, but the informational "Meta #1" card on unmatched slots didn't — it now reselects through the same shared core rule the website uses (raid exclusions, no duplicate on paired ring/trinket slots, no items worn elsewhere)
- With raids filtered out, two-hander users could be suggested a lone off-hand (Balance/Shadow) — impossible weapon combos are now guarded on every path, not just pinned ones
- **Combat-log state could display wrong (red border / flipped labels)**: the `LoggingCombat` query API is rate-limited (5 calls per 10s across all addons) and returns nil when throttled — nil was misread as "off". All reads now keep the last known state instead
- Lua error from protected ("secret") system chat messages on the 12.x client

### Removed
- The wythic.com promo message at login is gone. The only login message left is the data-staleness warning when the bundled meta is over 10 days old

### Migration
- Existing users are moved to the new defaults once: login auto-enable and quiet mode are retired, the combat log feature stays on with the dungeon-entry popup enabled and auto-enable off

### Notes
- A small hint was added to the gear optimizer: food/rune buffs inflate the % readouts — recommendations and proximity are gear-based and unaffected, but compare percentages unbuffed

## v1.6.9 (2026-09-07)

### Fixed
- **Bags-mode trinket picks now follow meta adoption rank**: with several owned trinkets close in score, the recommendation used to fall back to bag order — it now prefers the trinket top rankers actually equip, and the same trinket can no longer be suggested for both slots or duplicate the one you're wearing

### Data
- Fresh gear meta & league standings bundled (2026-09-07)

## v1.6.8 (2026-09-07)

### Fixed
- **Minimap right-click menu now works**: menu item clicks were never reaching their actions on the 12.x client (Blizzard menu API issue), and the auto-close logic hit a removed global (MouseIsOver), erroring every frame. The menu is rebuilt as a lightweight custom frame — combat-log toggle updates the border color instantly, the auto-enable checkbox toggles in place, and the menu closes when the mouse leaves it
- Combat-log toggle now verifies the actual client state after switching and tells you if another addon (e.g., a WCL uploader) reverted it

## v1.6.7 (2026-09-07)

### Added
- **Slot lock**: freeze a slot so optimization never touches it. Lock the item you picked (bag or meta) by Shift+Clicking its card or using the new "Lock this slot" button at the bottom of the item picker; Shift+Click the worn slot icon to keep your equipped item instead. Locked slots show a 🔒 badge, and a hint in the armory's top-right explains the gestures (optimization mode only)
- Locking an auto-recommendation promotes it to a pin first, so the item you see is exactly what gets locked
- Locked picks survive switching between Meta/Bags, hero-tree and raid-filter changes (those still reset other pins); applying a preset clears locks
- Addon version shown in the bottom-right corner of the main window
- **Bag pins are now hard constraints in Bags mode**: the engine fixes pinned items first and optimizes only the remaining slots around them (previously other slots were chosen as if the pin didn't exist)

### Fixed
- Weapon-combo safety with locks: locking a one-hand off-hand filters two-handers out of main-hand suggestions; locking a two-hander drops the off-hand from the baseline (dual-2H specs unaffected)
- Tooltips now open on the matching side: left-column slots anchor to the window's left, dropdown item tooltips anchor beside the dropdown instead of the main window

## v1.6.6 (2026-09-07)

### Fixed
- **Pinning an item no longer collides with the paired-slot recommendation**: pinning a ring/trinket that the engine was also recommending on the other slot used to show the same unique item twice and double-count its stats — the conflicting recommendation is now cancelled automatically
- **Impossible weapon combos are guarded**: pinning a two-hander clears a one-hand off-hand pin/recommendation (and vice versa); dual-2H specs like Fury keep both

### Data
- Fresh gear meta bundled — trinket rankings now reflect the current week (e.g., Voracious Heart of Ula'tek overtaking Zul'jin's kit for Arms), and outlier off-hand pools for two-hander metas are removed at the source

## v1.6.5 (2026-09-06)

### Fixed
- **Custom picks no longer distort stat %**: v1.6.4 fixed the % conversion for the optimizer run but missed the custom-pin path, so swapping a ring could still show nonsense like Haste jumping to 40% while the bar decreased. Custom picks now use the same real rating-to-percent slope, and the last-resort fallback can never move a percentage against the direction of the rating change

## v1.6.4 (2026-09-06)

### Fixed
- **Off-hand no longer recommended to two-hander users**: an empty off-hand slot was fed to the engine as a zero-stat placeholder, making it treat you as an off-hand user (it could even suggest a two-handed weapon there). Weapon slots now pass through only when actually equipped — same as the website
- **Stat % no longer collapses on custom picks**: when your rating sat close to the meta average, swapping a single item could display e.g. Haste 26% → 9%. Percentages are now converted linearly from your character's real rating-to-percent slope instead of meta interpolation
- **Presets now restore gems**: saved gem picks were stored but never re-applied when loading a preset
- Minimap menu/tooltip re-syncs the actual combat-log state (other addons toggling logging no longer desyncs the label and border color); menu errors now print to chat instead of failing silently

## v1.6.3 (2026-09-06)

Major update: English localization · Optimize from Bags · Hero Talent metas · Raidbots export

### Added
- **English localization (enUS)**: automatic client language detection — full UI in English on English clients (item/gem/enchant names use the client's native language)
- **Optimize from Bags**: finds the best set using only items you own (real item-link stats, a "swap right now" guide)
  - Usability filter: the item's loot-spec designation comes first, with a fallback to the armor/weapon types top rankers actually wear — no more shield/wrong-armor recommendations
  - Weapons must be at or above your equipped item level; armor allows up to -13 (one upgrade step); items above the season ceiling (old-expansion scaling misreads) are excluded
  - Only the highest item level per duplicate item; **an equipped tier 4-set is only ever replaced by pieces of the same set** (set bonus protection)
- **Hero Talent metas**: detects your active Hero Talent tree and adds a toggle above the optimizer (tree icons, active highlight; trees with a thin ranker sample explain themselves in a tooltip)
- **Raidbots export**: copy the exact set on screen (recommendations/pins/tracks applied) as a SimC profile and simulate it at raidbots.com (bag alternatives included as "Gear from Bags", real client build version)
- Equipped gems now show on the default screen — click one to jump straight into gem customization (unique-equipped diamond gems limited to one)
- 13 class background artworks behind the character model (same presentation as the web armory)
- Badge League teaser in the bottom-left corner — click to copy the wythic.com address
- Login reminder, addon-data staleness warning (10+ days), and a notice for characters below max level

### Changed
- Optimizer controls regrouped into a center box: title / Hero Talents / Meta·Bags buttons / raid filter (labeled, with tooltip, always visible)
- Larger meta-proximity readout; category donuts now draw as true progress arcs; the overall grade uses the same ring + letter look as the website
- Bag-sourced picks get their own accent color (emerald) across borders, arrows, badges and tabs — meta picks stay amber
- Presets are now stored per character and specialization; saving is disabled when nothing changed
- Custom state fully resets every time the window opens; clicking outside a dropdown closes it
- Texture resources optimized (3.2MB → 2.1MB)

## v1.6.2 (2026-09-06)

### Added
- **Dismiss recommendation button**: turn off a slot's simulated recommendation from the dropdown footer and re-score against your equipped item, with "Restore recommendation" to undo

### Fixed
- Selecting an upgrade track now updates the selection grid tooltips with that track's item level/stats as well (previously only the recommendation card tooltip reflected it)

## v1.6.1 (2026-09-06)

Gear optimizer customization — bend the recommendations to your will

### Custom pins (click a recommended item)
- Click a recommendation → pick any item from the **meta-ranking / bags tab dropdown** (pin), with paging
- Slots can be customized without running the optimizer; per-slot unpin and reset-all buttons
- The regular and Manaforged **conversion variants of the same item are selected and highlighted separately**
- **Upgrade track selection** (Veteran through Myth, crafted -3): tooltips reflect the chosen track's real item level and stats
- **Venomcursed checkbox**: limited to the 4 eligible items; checking it locks the track and fixes the item level at 344
- **Gem customization**: empty sockets show as ◇; picking a gem from the dropdown updates the stat bars
- **Presets**: snapshot the current recommendation + enchant/gem combination and restore it with its saved score

### Improved
- League tooltip: shows your best-RP main role, hold Shift to expand other roles (alts)
- Recommendation cards: two-line name/item level layout, source badges in the website's per-dungeon colors, converted items labeled "Converted: original"
- Weapon slot name alignment (main hand right / off hand left) to prevent overlap; window resize grip with saved scale
- Tooltips anchored outside the window, equipped-comparison tooltips suppressed, font size +1

## v1.6.0 (2026-09-06)

Gear optimizer armory + personal Badge League — a huge update

### Gear optimizer (`/wp gear` or left-click the minimap button)
- **Character diagnosis**: meta-match score against top rankers (S–D grade) — graded across stats, talents, gear and enchants
- **Optimize Gear**: 5-pass greedy simulation recommending per-slot replacements (keeps tier 4-sets, avoids two-hander/paired-slot duplicates)
- Recommended items carry a meta-rank badge, source chips (dungeon/raid/tier/crafted) and ranker-usage tooltips (bonus IDs applied)
- **Enchant & gem recommendations** with quality colors and hover tooltips
- Stat comparison bars: your values vs. the meta average (rating & %), with gear/gem deltas while optimizing
- Unchecking the raid filter re-recommends with raid items excluded
- Armory layout around a central 3D character model, with slide animations while optimizing

### Personal Badge League
- Player tooltips show **season rank (Challenger–Bronze) · position within the rank · RP** (same criteria as the wythic.com league)
- Representative badge with label; your rank shown in the character frame header

### Misc
- Windows auto-skin to EllesmereUI when it is installed
- Window auto-shrinks on low resolutions / large UI scales
- Meta data ships as automatic releases: weekly (gear) · daily (league)

## v1.5.0

- Combat-log auto-enable helper on login (WCL logging)
- Minimap button, onboarding guide
