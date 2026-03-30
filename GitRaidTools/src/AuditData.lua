local _, ns = ...

------------------------------------------------------------
-- Data version — update when patching enchant/gem/tier tables
-- If game interface > this, we warn once about possible stale data
------------------------------------------------------------
ns.AUDIT_DATA_INTERFACE = 120001

------------------------------------------------------------
-- Equipment Slot Constants
------------------------------------------------------------

-- All inspectable equipment slots (same order as MRT)
ns.ALL_EQUIPMENT_SLOTS = {
    1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
}

-- Slots that should have enchants in Midnight (weapons lead)
-- Wpn(16), OH(17), Head(1), Shoulder(3), Chest(5), Legs(7), Feet(8), Ring1(11), Ring2(12)
ns.ENCHANTABLE_SLOTS = { 16, 17, 1, 3, 5, 7, 8, 11, 12 }

-- Short column headers for the audit table
ns.SLOT_SHORT = {
    [16] = "Wpn", [17] = "OH", [1] = "Head", [3] = "Shld", [5] = "Chest",
    [7] = "Legs", [8] = "Feet", [11] = "R1", [12] = "R2",
}

-- Full slot names for tooltips / iLvl display
ns.SLOT_NAMES = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest",
    [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrist",
    [10] = "Hands", [11] = "Ring 1", [12] = "Ring 2",
    [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Back",
    [16] = "Weapon", [17] = "Off Hand",
}

-- Tier set piece slots (Head, Shoulder, Chest, Hands, Legs)
ns.TIER_SLOTS = { 1, 3, 5, 10, 7 }

-- DK Runeforging enchant IDs — always pass regardless of quality settings
local DK_RUNE_IDS = {
    [3368] = true, -- Rune of the Fallen Crusader
    [3370] = true, -- Rune of Razorice
    [3847] = true, -- Rune of the Stoneskin Gargoyle
    [6241] = true, -- Rune of Sanguination (Blood)
    [6242] = true, -- Rune of Spellwarding (defensive)
    [6243] = true, -- Rune of Hysteria (removed 11.0, legacy)
    [6244] = true, -- Rune of Unending Thirst
    [6245] = true, -- Rune of the Apocalypse (Unholy BiS)
}

------------------------------------------------------------
-- Enhancement Data Encoding
--
-- Midnight uses 2-tier quality: Q1 (normal) and Q2 (max)
-- Single number per entry:
--   1  = low-level Q1,  2  = low-level Q2
--   11 = high-level Q1, 12 = high-level Q2
--
-- "Low" = cheap / previous-tier enchant
-- "High" = current Midnight tier enchant
------------------------------------------------------------

-- Enchant IDs → encoded level+quality
-- Source: MRT InspectViewer.lua IS_MN block + topEnchGemsCheap
ns.ENCHANT_DATA = {
    -- Midnight high-level gear enchants (Q1/Q2 pairs)
    -- Source: SpellItemEnchantment DB2 via wago.tools
    -- Amani tier: chest, helm, boots, rings, shoulders, weapons
    [7956]=11,[7957]=12,[7958]=11,[7959]=12,[7960]=11,[7961]=12,
    [7962]=11,[7963]=12,[7964]=11,[7965]=12,[7966]=11,[7967]=12,
    [7968]=11,[7969]=12,[7970]=11,[7971]=12,[7972]=11,[7973]=12,
    [7978]=11,[7979]=12,[7980]=11,[7981]=12,[7982]=11,[7983]=12,
    -- Nature / Amirdrassil tier
    [7984]=11,[7985]=12,[7986]=11,[7987]=12,[7988]=11,[7989]=12,
    [7990]=11,[7991]=12,[7992]=11,[7993]=12,[7994]=11,[7995]=12,
    [7996]=11,[7997]=12,[7998]=11,[7999]=12,[8000]=11,[8001]=12,
    [8006]=11,[8007]=12,[8008]=11,[8009]=12,[8010]=11,[8011]=12,
    -- Silvermoon / Thalassian tier
    [8012]=11,[8013]=12,[8014]=11,[8015]=12,[8016]=11,[8017]=12,
    [8018]=11,[8019]=12,[8020]=11,[8021]=12,[8022]=11,[8023]=12,
    [8024]=11,[8025]=12,[8026]=11,[8027]=12,[8028]=11,[8029]=12,
    [8030]=11,[8031]=12,[8036]=11,[8037]=12,[8038]=11,[8039]=12,
    [8040]=11,[8041]=12,

    -- Midnight high-level leg enhancements (Tailoring spellthreads + LW armor kits)
    -- Sunfire Silk Spellthread Q1/Q2
    [7934]=11,[7935]=12,
    -- Arcanoweave Spellthread Q1/Q2
    [7936]=11,[7937]=12,
    -- Forest Hunter's Armor Kit Q1/Q2
    [8158]=11,[8159]=12,
    -- Blood Knight's Armor Kit Q1/Q2
    [8162]=11,[8163]=12,

    -- Midnight low-level enchants (Q1/Q2) — cheaper alternatives
    [7905]=2,[7906]=1,[7907]=1,[7908]=2,[7909]=1,[7910]=2,
    -- Bright Linen Spellthread Q1/Q2 (low-level leg)
    [7938]=1,[7939]=2,
    [8051]=1,[8052]=2,[8053]=1,[8054]=2,[8055]=1,[8056]=2,
    -- Thalassian Scout Armor Kit Q1/Q2 (low-level leg)
    [8160]=1,[8161]=2,
    [8608]=1,[8609]=2,[8610]=1,[8611]=2,[8612]=1,[8613]=2,[8614]=1,[8615]=2,
}

-- Gem item IDs → encoded level+quality
-- Source: MRT InspectViewer.lua IS_MN block (240xxx range)
ns.GEM_DATA = {
    -- Midnight high-level gems (Q1/Q2)
    -- Pairs: odd ID = Q1, even ID = Q2
    [240855]=11,[240856]=12,[240857]=11,[240858]=12,[240859]=11,[240860]=12,
    [240861]=11,[240862]=12,[240863]=11,[240864]=12,[240865]=11,[240866]=12,
    [240867]=11,[240868]=12,[240869]=11,[240870]=12,[240871]=11,[240872]=12,
    [240873]=11,[240874]=12,[240875]=11,[240876]=12,[240877]=11,[240878]=12,
    [240879]=11,[240880]=12,[240881]=11,[240882]=12,[240883]=11,[240884]=12,
    [240885]=11,[240886]=12,[240887]=11,[240888]=12,[240889]=11,[240890]=12,
    [240891]=11,[240892]=12,[240893]=11,[240894]=12,[240895]=11,[240896]=12,
    [240897]=11,[240898]=12,[240899]=11,[240900]=12,[240901]=11,[240902]=12,
    [240903]=11,[240904]=12,[240905]=11,[240906]=12,[240907]=11,[240908]=12,
    [240909]=11,[240910]=12,[240911]=11,[240912]=12,[240913]=11,[240914]=12,
    [240915]=11,[240916]=12,[240917]=11,[240918]=12,[240966]=11,[240967]=12,
    [240968]=11,[240969]=12,[240970]=11,[240971]=12,[240982]=11,[240983]=12,
}

------------------------------------------------------------
-- Quality Icon Inline Textures
------------------------------------------------------------
-- Midnight 2-tier quality icons (silver/gold, not the old 5-tier gems)
ns.Q1_ICON = "|A:professions-chaticon-quality-12-tier1:0:0|a"
ns.Q2_ICON = "|A:professions-chaticon-quality-12-tier2:0:0|a"

------------------------------------------------------------
-- Enchant Names — enchantID → display name for tooltips
-- Source: SpellItemEnchantment DB2 via wago.tools (2026-03-30)
------------------------------------------------------------
-- Each entry: { name, effect }
ns.ENCHANT_NAMES = {
    -- DK Runeforging
    [3368] = { "Rune of the Fallen Crusader", "Chance to heal 6% and increase Str" },
    [3370] = { "Rune of Razorice", "Frost damage + vulnerability" },
    [3847] = { "Rune of the Stoneskin Gargoyle", "+Armor and Stamina" },
    [6241] = { "Rune of Sanguination", "Damage heals when below 35% HP" },
    [6242] = { "Rune of Spellwarding", "Absorb magic damage" },
    [6243] = { "Rune of Hysteria", "+Max Runic Power (removed)" },
    [6244] = { "Rune of Unending Thirst", "+Speed, heal on kill" },
    [6245] = { "Rune of the Apocalypse", "Debuffs on attacks" },
    -- Leg: Tailoring spellthreads
    [7934] = { "Sunfire Silk Spellthread", "+Int, +Stamina" },
    [7935] = { "Sunfire Silk Spellthread", "+Int, +Stamina" },
    [7936] = { "Arcanoweave Spellthread", "+Int, +Mana%" },
    [7937] = { "Arcanoweave Spellthread", "+Int, +Mana%" },
    [7938] = { "Bright Linen Spellthread", "+Int" },
    [7939] = { "Bright Linen Spellthread", "+Int" },
    -- Amani / Zul'Aman tier
    [7956] = { "Mark of Nalorakk", "Absorb shield proc" },
    [7957] = { "Mark of Nalorakk", "Absorb shield proc" },
    [7958] = { "Hex of Leeching", "+Leech" },
    [7959] = { "Hex of Leeching", "+Leech" },
    [7960] = { "Empowered Hex of Leeching", "+Leech, bonus on kill" },
    [7961] = { "Empowered Hex of Leeching", "+Leech, bonus on kill" },
    [7962] = { "Lynx's Dexterity", "+Speed" },
    [7963] = { "Lynx's Dexterity", "+Speed" },
    [7964] = { "Amani Mastery", "+Mastery" },
    [7965] = { "Amani Mastery", "+Mastery" },
    [7966] = { "Eyes of the Eagle", "+Crit" },
    [7967] = { "Eyes of the Eagle", "+Crit" },
    [7968] = { "Zul'jin's Mastery", "+Mastery" },
    [7969] = { "Zul'jin's Mastery", "+Mastery" },
    [7970] = { "Flight of the Eagle", "+Avoidance" },
    [7971] = { "Flight of the Eagle", "+Avoidance" },
    [7972] = { "Akil'zon's Swiftness", "+Speed" },
    [7973] = { "Akil'zon's Swiftness", "+Speed" },
    [7978] = { "Strength of Halazzi", "+Haste proc" },
    [7979] = { "Strength of Halazzi", "+Haste proc" },
    [7980] = { "Jan'alai's Precision", "+Crit proc" },
    [7981] = { "Jan'alai's Precision", "+Crit proc" },
    [7982] = { "Berserker's Rage", "+Primary stat proc" },
    [7983] = { "Berserker's Rage", "+Primary stat proc" },
    -- Nature / Amirdrassil tier
    [7984] = { "Mark of the Rootwarden", "+Armor proc" },
    [7985] = { "Mark of the Rootwarden", "+Armor proc" },
    [7986] = { "Mark of the Worldsoul", "+Primary stat" },
    [7987] = { "Mark of the Worldsoul", "+Primary stat" },
    [7988] = { "Blessing of Speed", "+Speed" },
    [7989] = { "Blessing of Speed", "+Speed" },
    [7990] = { "Empowered Blessing of Speed", "+Speed, +Vigor" },
    [7991] = { "Empowered Blessing of Speed", "+Speed, +Vigor" },
    [7992] = { "Shaladrassil's Roots", "+Stamina" },
    [7993] = { "Shaladrassil's Roots", "+Stamina" },
    [7994] = { "Nature's Wrath", "+Haste" },
    [7995] = { "Nature's Wrath", "+Haste" },
    [7996] = { "Nature's Fury", "+Versatility" },
    [7997] = { "Nature's Fury", "+Versatility" },
    [7998] = { "Nature's Grace", "+Avoidance" },
    [7999] = { "Nature's Grace", "+Avoidance" },
    [8000] = { "Amirdrassil's Grace", "+Leech" },
    [8001] = { "Amirdrassil's Grace", "+Leech" },
    [8006] = { "Worldsoul Cradle", "+Mastery proc" },
    [8007] = { "Worldsoul Cradle", "+Mastery proc" },
    [8008] = { "Worldsoul Aegis", "+Versatility proc" },
    [8009] = { "Worldsoul Aegis", "+Versatility proc" },
    [8010] = { "Worldsoul Tenacity", "+Stamina proc" },
    [8011] = { "Worldsoul Tenacity", "+Stamina proc" },
    -- Silvermoon / Thalassian tier
    [8012] = { "Mark of the Magister", "+Intellect" },
    [8013] = { "Mark of the Magister", "+Intellect" },
    [8014] = { "Rune of Avoidance", "+Avoidance" },
    [8015] = { "Rune of Avoidance", "+Avoidance" },
    [8016] = { "Empowered Rune of Avoidance", "+Avoidance, reduced AoE dmg" },
    [8017] = { "Empowered Rune of Avoidance", "+Avoidance, reduced AoE dmg" },
    [8018] = { "Farstrider's Hunt", "+Crit" },
    [8019] = { "Farstrider's Hunt", "+Crit" },
    [8020] = { "Thalassian Haste", "+Haste" },
    [8021] = { "Thalassian Haste", "+Haste" },
    [8022] = { "Thalassian Versatility", "+Versatility" },
    [8023] = { "Thalassian Versatility", "+Versatility" },
    [8024] = { "Silvermoon's Alacrity", "+Haste" },
    [8025] = { "Silvermoon's Alacrity", "+Haste" },
    [8026] = { "Silvermoon's Tenacity", "+Stamina" },
    [8027] = { "Silvermoon's Tenacity", "+Stamina" },
    [8028] = { "Thalassian Recovery", "+Leech" },
    [8029] = { "Thalassian Recovery", "+Leech" },
    [8030] = { "Silvermoon's Mending", "+Leech" },
    [8031] = { "Silvermoon's Mending", "+Leech" },
    [8036] = { "Flames of the Sin'dorei", "+Haste proc" },
    [8037] = { "Flames of the Sin'dorei", "+Haste proc" },
    [8038] = { "Acuity of the Ren'dorei", "+Mastery proc" },
    [8039] = { "Acuity of the Ren'dorei", "+Mastery proc" },
    [8040] = { "Arcane Mastery", "+Primary stat proc" },
    [8041] = { "Arcane Mastery", "+Primary stat proc" },
    -- Weapon oils / stones (low-level)
    [8051] = { "Thalassian Phoenix Oil", "+Fire damage proc" },
    [8052] = { "Thalassian Phoenix Oil", "+Fire damage proc" },
    [8053] = { "Oil of Dawn", "+Holy damage" },
    [8054] = { "Oil of Dawn", "+Holy damage" },
    [8055] = { "Smuggler's Enchanted Edge", "+Nature damage" },
    [8056] = { "Smuggler's Enchanted Edge", "+Nature damage" },
    -- Leg: Leatherworking armor kits
    [8158] = { "Forest Hunter's Armor Kit", "+Agi/Str, +Stamina" },
    [8159] = { "Forest Hunter's Armor Kit", "+Agi/Str, +Stamina" },
    [8160] = { "Thalassian Scout Armor Kit", "+Agi/Str" },
    [8161] = { "Thalassian Scout Armor Kit", "+Agi/Str" },
    [8162] = { "Blood Knight's Armor Kit", "+Agi/Str, +Armor" },
    [8163] = { "Blood Knight's Armor Kit", "+Agi/Str, +Armor" },
    -- Engineering scopes (low-level)
    [8608] = { "Laced Zoomshots", "+Ranged attack" },
    [8609] = { "Laced Zoomshots", "+Ranged attack" },
    [8610] = { "Weighted Boomshots", "+Ranged attack" },
    [8611] = { "Weighted Boomshots", "+Ranged attack" },
    [8612] = { "Smuggler's Lynxeye", "+Crit ranged" },
    [8613] = { "Smuggler's Lynxeye", "+Crit ranged" },
    [8614] = { "Farstrider's Hawkeye", "+Ranged attack" },
    [8615] = { "Farstrider's Hawkeye", "+Ranged attack" },
}

-- TWW-era enchant/gem IDs not in the Midnight tables — treated as low/Q1
-- If someone still has a TWW enchant, it's valid but below current tier
ns.KNOWN_CHEAP = {
    [7493]=true,[7494]=true,[7495]=true,[7496]=true,[7497]=true,[7498]=true,
    [7500]=true,[7501]=true,[7502]=true,[7529]=true,[7530]=true,[7531]=true,
    [7532]=true,[7533]=true,[7534]=true,[7535]=true,[7536]=true,[7537]=true,
    [7538]=true,[7539]=true,[7540]=true,[7543]=true,[7544]=true,[7545]=true,
    [7546]=true,[7547]=true,[7548]=true,[7549]=true,[7550]=true,[7551]=true,
    [7593]=true,[7594]=true,[7595]=true,[7596]=true,[7597]=true,[7598]=true,
    [7599]=true,[7600]=true,[7601]=true,[7652]=true,[7653]=true,[7654]=true,
    [217113]=true,[217114]=true,[217115]=true,
}

------------------------------------------------------------
-- Tier Set Items — itemID → true
-- Midnight Season 1 (12.0)
-- 5 tier slots (Head, Shoulder, Chest, Hands, Legs) × 13 classes
-- Source: Wowhead item-set 1978-1990
------------------------------------------------------------
ns.TIER_ITEMS = {
    -- Warrior — Rage of the Night Ender
    [249952]=true,[249950]=true,[249955]=true,[249953]=true,[249951]=true,
    -- Paladin — Luminant Verdict's Vestments
    [249961]=true,[249959]=true,[249964]=true,[249962]=true,[249960]=true,
    -- Hunter — Primal Sentry's Camouflage
    [249988]=true,[249986]=true,[249991]=true,[249989]=true,[249987]=true,
    -- Rogue — Motley of the Grim Jest
    [250006]=true,[250004]=true,[250009]=true,[250007]=true,[250005]=true,
    -- Priest — Blind Oath's Burden
    [250051]=true,[250049]=true,[250054]=true,[250052]=true,[250050]=true,
    -- Death Knight — Relentless Rider's Lament
    [249970]=true,[249968]=true,[249973]=true,[249971]=true,[249969]=true,
    -- Shaman — Mantle of the Primal Core
    [249979]=true,[249977]=true,[249982]=true,[249980]=true,[249978]=true,
    -- Mage — Voidbreaker's Accordance
    [250060]=true,[250058]=true,[250063]=true,[250061]=true,[250059]=true,
    -- Warlock — Reign of the Abyssal Immolator
    [250042]=true,[250040]=true,[250045]=true,[250043]=true,[250041]=true,
    -- Monk — Way of Ra-den's Chosen
    [250015]=true,[250013]=true,[250018]=true,[250016]=true,[250014]=true,
    -- Druid — Sprouts of the Luminous Bloom
    [250024]=true,[250022]=true,[250027]=true,[250025]=true,[250023]=true,
    -- Demon Hunter — Devouring Reaver's Sheathe
    [250033]=true,[250031]=true,[250036]=true,[250034]=true,[250032]=true,
    -- Evoker — Livery of the Black Talon
    [249997]=true,[249995]=true,[250000]=true,[249998]=true,[249996]=true,
}

------------------------------------------------------------
-- Socket Detection Bonus IDs
-- If an item link contains any of these bonus IDs, it has a socket
-- Source: MRT InspectViewer.lua socketsBonusIDs
------------------------------------------------------------
ns.SOCKET_BONUS_IDS = {
    [523]=true,[563]=true,[564]=true,[565]=true,[572]=true,
    [608]=true,[715]=true,[716]=true,[717]=true,[718]=true,
    [719]=true,[721]=true,[722]=true,[723]=true,[724]=true,
    [725]=true,[726]=true,[727]=true,[728]=true,[729]=true,
    [730]=true,[731]=true,[732]=true,[733]=true,[734]=true,
    [735]=true,[736]=true,[737]=true,[738]=true,[739]=true,
    [740]=true,[741]=true,[742]=true,[743]=true,[744]=true,
    [745]=true,[746]=true,[747]=true,[748]=true,[749]=true,
    [750]=true,[751]=true,[752]=true,[1808]=true,[3475]=true,
    [3522]=true,[4231]=true,[4802]=true,[6514]=true,[6672]=true,
    [6935]=true,[7576]=true,[7580]=true,[7935]=true,[7947]=true,
    [8289]=true,[8780]=true,[8781]=true,[8782]=true,[8810]=true,
    [9413]=true,[9436]=true,[9438]=true,[9516]=true,[10397]=true,
    [10531]=true,[10589]=true,[10596]=true,[10601]=true,[10608]=true,
    [10615]=true,[10622]=true,[10629]=true,[10636]=true,[10643]=true,
    [10650]=true,[10657]=true,[10659]=true,[10666]=true,[10674]=true,
    [10681]=true,[10688]=true,[10695]=true,[10702]=true,[10709]=true,
    [10716]=true,[10733]=true,[10734]=true,[10735]=true,[10736]=true,
    [10737]=true,[10738]=true,[10739]=true,[10740]=true,[10741]=true,
    [10742]=true,[10743]=true,[10776]=true,[10775]=true,[10774]=true,
    [10773]=true,[10772]=true,[10771]=true,[10770]=true,[10769]=true,
    [10768]=true,[10767]=true,[10766]=true,[10719]=true,[10712]=true,
    [10705]=true,[10698]=true,[10691]=true,[10684]=true,[10677]=true,
    [10670]=true,[10663]=true,[10658]=true,[10651]=true,[10644]=true,
    [10637]=true,[10630]=true,[10623]=true,[10616]=true,[10609]=true,
    [10602]=true,[10597]=true,[10591]=true,[10599]=true,[10606]=true,
    [10613]=true,[10620]=true,[10627]=true,[10634]=true,[10641]=true,
    [10648]=true,[10655]=true,[10662]=true,[10669]=true,[10676]=true,
    [10683]=true,[10690]=true,[10697]=true,[10704]=true,[10711]=true,
    [10718]=true,[10755]=true,[10756]=true,[10757]=true,[10758]=true,
    [10759]=true,[10760]=true,[10761]=true,[10762]=true,[10763]=true,
    [10764]=true,[10765]=true,[10593]=true,[10603]=true,[10610]=true,
    [10617]=true,[10624]=true,[10631]=true,[10638]=true,[10645]=true,
    [10652]=true,[10661]=true,[10668]=true,[10675]=true,[10682]=true,
    [10689]=true,[10696]=true,[10703]=true,[10710]=true,[10717]=true,
    [10744]=true,[10745]=true,[10746]=true,[10747]=true,[10748]=true,
    [10749]=true,[10750]=true,[10751]=true,[10752]=true,[10753]=true,
    [10754]=true,[10835]=true,[10836]=true,[10838]=true,[10878]=true,
    [10879]=true,[10880]=true,[10891]=true,[10892]=true,[10893]=true,
    [10894]=true,[10895]=true,[10896]=true,[10897]=true,[10898]=true,
    [10899]=true,[10900]=true,[10901]=true,[10902]=true,[10903]=true,
    [10904]=true,[10905]=true,[10906]=true,[10907]=true,[10908]=true,
    [10909]=true,[10910]=true,[10911]=true,[10912]=true,[10913]=true,
    [10914]=true,[10915]=true,[10916]=true,[10917]=true,[10918]=true,
    [10919]=true,[10920]=true,[10921]=true,[10922]=true,[10923]=true,
    [10924]=true,[10925]=true,[10926]=true,[10927]=true,[10928]=true,
    [10929]=true,[10930]=true,[10931]=true,[10932]=true,[10933]=true,
    [10934]=true,[10935]=true,[10936]=true,[10937]=true,[10938]=true,
    [10939]=true,[10940]=true,[10941]=true,[10942]=true,[10943]=true,
    [10944]=true,[10945]=true,[10946]=true,[10947]=true,[10948]=true,
    [11145]=true,[11146]=true,[11147]=true,[11148]=true,[11149]=true,
    [11150]=true,[11151]=true,[11152]=true,[11153]=true,[11154]=true,
    [11165]=true,[11166]=true,[11167]=true,[11168]=true,[11169]=true,
    [11170]=true,[11171]=true,[11172]=true,[11173]=true,[11174]=true,
    [11180]=true,[11181]=true,[11182]=true,[11183]=true,[11184]=true,
    [11185]=true,[11186]=true,[11187]=true,[11188]=true,[11189]=true,
    [11307]=true,[12055]=true,[12056]=true,[12234]=true,[12365]=true,
    [12666]=true,[12922]=true,[13534]=true,[13576]=true,[13668]=true,
}

------------------------------------------------------------
-- Item Link Parsing
------------------------------------------------------------

-- Parse an item link into its component IDs
-- Returns: itemID, enchantID, {gem1, gem2, gem3, gem4}, bonusIDs table
function ns.ParseItemLink(link)
    if not link then return nil end

    -- Strip the |H...|h wrapper to get the raw item string
    local itemString = link:match("item:[^|]+")
    if not itemString then return nil end

    local parts = { strsplit(":", itemString) }
    -- parts[1]="item", [2]=itemID, [3]=enchantID, [4..7]=gem1..gem4
    -- After gems: [8]=suffixID, [9]=uniqueID, [10]=level, [11]=specID,
    -- [12]=upgradeType, [13]=difficultyID, [14]=numBonusIDs, [15+]=bonusIDs

    local itemID = tonumber(parts[2]) or 0
    local enchantID = tonumber(parts[3]) or 0
    local gems = {}
    for i = 4, 7 do
        local g = tonumber(parts[i]) or 0
        if g > 0 then gems[#gems + 1] = g end
    end

    local bonusIDs = {}
    local numBonuses = tonumber(parts[14]) or 0
    for i = 15, 14 + numBonuses do
        local b = tonumber(parts[i]) or 0
        if b > 0 then bonusIDs[b] = true end
    end

    return itemID, enchantID, gems, bonusIDs
end

-- Count gem sockets on an item via bonus IDs
function ns.CountSockets(bonusIDs)
    if not bonusIDs then return 0 end
    local count = 0
    for id in pairs(bonusIDs) do
        if ns.SOCKET_BONUS_IDS[id] then count = count + 1 end
    end
    return count
end

------------------------------------------------------------
-- Item Level + Difficulty Track from Tooltip
------------------------------------------------------------
local ILVL_PATTERN = ITEM_LEVEL and ITEM_LEVEL:gsub("%%d", "(%%d+)") or "Item Level (%d+)"

-- Track keywords parsed from "Upgrade Level: Hero 3/6" etc.
local TRACK_MAP = {
    Myth      = "M",
    Hero      = "H",
    Champion  = "C",
    Veteran   = "V",
    Adventurer = "A",
    Explorer  = "A",  -- alias used in some contexts
}

-- Returns: ilvl (number), track (letter string or nil)
function ns.GetItemDetails(unit, slotID)
    local data = C_TooltipInfo.GetInventoryItem(unit, slotID)
    if not data or not data.lines then return 0, nil end

    local ilvl = 0
    local track = nil

    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text then
            if ilvl == 0 then
                local level = text:match(ILVL_PATTERN)
                if level then ilvl = tonumber(level) or 0 end
            end
            if not track then
                local trackName = text:match("Upgrade Level: (%a+)")
                if trackName and TRACK_MAP[trackName] then
                    track = TRACK_MAP[trackName]
                end
            end
            if ilvl > 0 and track then break end
        end
    end

    return ilvl, track
end

------------------------------------------------------------
-- Enhancement Evaluation
------------------------------------------------------------

-- Core evaluator shared by enchant and gem checks
-- Returns: result, detail
--   "pass"        — meets all thresholds
--   "missing"     — no enchant/gem (id = 0)
--   "low_level"   — known but below level threshold (old expansion)
--   "low_quality", rank — right level but rank below threshold
--   "unknown"     — non-zero ID not in data tables
local function EvaluateEnhancement(id, dataTable, levelSetting, minQuality)
    if id == 0 then return "missing" end
    if DK_RUNE_IDS[id] then return "pass" end

    local encoded = dataTable[id]
    -- TWW fallback: old-expansion enchant/gem -> treat as low/Q1
    if not encoded and ns.KNOWN_CHEAP[id] then encoded = 1 end
    if not encoded then
        -- At "any" threshold, having something is enough — don't flag unknowns
        if levelSetting == "low" and minQuality <= 1 then return "pass" end
        return "unknown"
    end

    local isHigh = encoded >= 10
    local quality = isHigh and (encoded - 10) or encoded

    if levelSetting == "high" and not isHigh then return "low_level" end
    if quality < minQuality then return "low_quality", quality end
    return "pass"
end

-- Map combined threshold to level + minQuality
local THRESHOLD_MAP = {
    any     = { level = "low",  minQuality = 1 },
    high_q1 = { level = "high", minQuality = 1 },
    high_q2 = { level = "high", minQuality = 2 },
}

function ns.EvaluateEnchant(enchantID)
    if not ns.db then return "unknown" end
    local t = THRESHOLD_MAP[ns.db.auditEnchantThreshold or "high_q1"]
    return EvaluateEnhancement(enchantID, ns.ENCHANT_DATA, t.level, t.minQuality)
end

function ns.EvaluateGem(gemID)
    if not ns.db then return "unknown" end
    local t = THRESHOLD_MAP[ns.db.auditGemThreshold or "high_q1"]
    return EvaluateEnhancement(gemID, ns.GEM_DATA, t.level, t.minQuality)
end

-- Get a gem's quality (1=Q1, 2=Q2) from our data table, or 0 if unknown
function ns.GetGemRank(gemID)
    local encoded = ns.GEM_DATA[gemID]
    if not encoded then return 0 end
    return encoded >= 10 and (encoded - 10) or encoded
end

------------------------------------------------------------
-- Data Version Warning (called once on PLAYER_LOGIN)
------------------------------------------------------------
local warnedDataVersion = false

function ns.CheckAuditDataVersion()
    if warnedDataVersion then return end
    local _, _, _, tocVersion = GetBuildInfo()
    if tocVersion and tocVersion > ns.AUDIT_DATA_INTERFACE then
        print("|cff00ccffGRT Audit:|r Enchant/gem data may be outdated for this patch. Some items may show as unknown.")
        warnedDataVersion = true
    end
end
