-- BigWigs Bar Color Mappings
-- Maps spell IDs to canonical color categories from BigWigs_Color_Guide.md
--
-- Categories:
--   gray   = Default / Info / Phase (#6B7280)
--   red    = Raid Damage (#DC2626)
--   orange = Dodge / Move (#EA580C)
--   yellow = Soak / Stack / Positioning (#CA8A04)
--   green  = Adds / Target Swap / Kicks / Priority Control (#16A34A)
--   blue   = Knockback / Forced Movement (#2563EB)
--   purple = Beams / Debuffs / Magic Mechanics (#9333EA)
--   brown  = Tank Buster / Tank Swap / Tank-focused Hit (#92400E)
--
-- Assignment methodology:
--   Classified by PRIMARY PLAYER RESPONSE from wowhead spell descriptions.
--   "damage to all players" unavoidable = red
--   "within X yards of impact" on ground = orange (dodge)
--   "within X yards of each player" targeted = yellow (spread)
--   "current target" / "primary target" = brown (tank)
--   "split evenly" = yellow (soak)
--   Spawns adds/clones = green
--   Applies debuff/DoT = purple
--   Forced displacement IS the mechanic = blue

return {

    ----------------------------------------------------------------
    -- The Voidspire
    ----------------------------------------------------------------

    ["BigWigs_Bosses_Vorasius"] = {
        [1256855] = "orange",  -- Void Breath: frontal beam sweep; dodge out of path
        [1254199] = "green",   -- Parasite Expulsion: spawns Blistercreep adds
        [1241692] = "yellow",  -- Shadowclaw Slam: must soak central impact or raid takes 777k
        [1260052] = "blue",    -- Primordial Roar: pulls players in then knocks away; forced movement
    },

    ["BigWigs_Bosses_Imperator Averzian"] = {
        [1251361] = "green",   -- Shadow's Advance: summons Abyssal Voidshapers (adds)
        [1249262] = "yellow",  -- Umbral Collapse: damage split by players within 10y; soak
        [1280015] = "purple",  -- Void Marked: debuff marks on several players
        [1260712] = "orange",  -- Oblivion's Wrath: void lances in paths; dodge
        [1258883] = "orange",  -- Void Fall: knockback + rain at destinations within 7y; dodge zones
        [1249251] = "red",     -- Dark Upheaval: damage to all players + ticking; unavoidable
    },

    ["BigWigs_Bosses_Fallen-King Salhadaar"] = {
        [1247738] = "yellow",  -- Void Convergence: orbs drawn to boss; intercept/position
        [1246175] = "red",     -- Entropic Unraveling: damage to all players every 1s; unavoidable
        [1250803] = "brown",   -- Shattering Twilight: hurled at current target for 893k; tank buster
        [1254081] = "green",   -- Fractured Projection: manifests adds (Fractured Images)
        [1248697] = "purple",  -- Despotic Command: debuff on several players; spreads + creates pools
        [1250686] = "red",     -- Twisting Obscurity: jumps between all players; unavoidable raid DoT
    },

    ["BigWigs_Bosses_Vaelgor & Ezzorak"] = {
        [1249748] = "red",     -- Midnight Flames: damage to all players + 25s DoT; unavoidable
        [1280458] = "brown",   -- Grappling Maw: lashes primary target; tank mechanic
        [1262623] = "orange",  -- Nullbeam: frontal cone; dodge out of path
        [1244221] = "orange",  -- Dread Breath: frontal cone at targeted player; dodge
        [1265131] = "brown",   -- Vaelwing: buffets primary target; tank buster with stacking
        [1245391] = "yellow",  -- Gloom: players soak through darkness to shrink Gloomfield
        [1244917] = "yellow",  -- Void Howl: spawns Voidorb at each player; spread positioning
        [1245645] = "brown",   -- Rakfang: strikes primary target for 932k; tank buster
    },

    ["BigWigs_Bosses_Lightblinded Vanguard"] = {
        -- Commander Venel Lightblood
        [1248449] = "gray",    -- Aura of Wrath: phase aura at 100 energy; informational
        [1248983] = "yellow",  -- Execution Sentence: damage split evenly within 8y; soak
        [1246765] = "orange",  -- Divine Storm: damage within 8y; dodge out of melee
        [1246749] = "red",     -- Sacred Toll: damage to all players within 100y; unavoidable
        [1246736] = "brown",   -- Judgement [R]: current target + 500% damage amp; tank buster
        -- General Amias Bellamy
        [1246162] = "gray",    -- Aura of Devotion: phase aura at 100 energy; informational
        [1248644] = "orange",  -- Divine Toll: shields fly out; dodge or get silenced 6s
        [1246485] = "yellow",  -- Avenger's Shield: targets several players; spread within 5y
        [1251857] = "brown",   -- Judgement [B]: current target + 500% damage amp; tank buster
        -- War Chaplain Senn
        [1248451] = "gray",    -- Aura of Peace: phase aura at 100 energy; informational
        [1248710] = "yellow",  -- Tyr's Wrath: hits 5 nearest players; position who gets it
        [1255738] = "red",     -- Searing Radiance: damage to all players every 1s for 15s; unavoidable
        [1248674] = "green",   -- Sacred Shield: shield on boss; priority target to break
        -- Mythic
        [1276243] = "green",   -- Zealous Spirit: add that empowers bosses; priority control
    },

    ["BigWigs_Bosses_Crown of the Cosmos"] = {
        -- Stage 1: The Void's Spire
        [1233602] = "orange",  -- Silverstrike Arrow: fires in a line through player; dodge path
        [1232467] = "purple",  -- Grasp of Emptiness: debuff on player (slow + DoT for 8s)
        [1255368] = "red",     -- Void Expulsion: damage to all players; unavoidable
        [1233865] = "purple",  -- Null Corona: healing absorb debuff; dispel management
        [1233787] = "brown",   -- Dark Hand: strikes current target for 1.9M; tank buster
        [1243743] = "orange",  -- Interrupting Tremor: damage within 40y + interrupt; dodge/range
        [1243753] = "orange",  -- Ravenous Abyss: within 15y; dodge out or get 70% damage reduction
        -- Intermission
        [1243982] = "orange",  -- Silverstrike Barrage: dodge arrows; 500% stacking on hit
        [1245874] = "orange",  -- Orbiting Matter: dodge orbital mass
        -- Stage 2: The Severed Rift
        [1237614] = "yellow",  -- Ranger Captain's Mark: applied to random players; spread
        [1237038] = "purple",  -- Voidstalker's Sting: stacking DoT debuff on several players
        [1237837] = "green",   -- Call of the Void: spawns Undying Voidspawn add
        [1246918] = "green",   -- Cosmic Barrier: shield on boss; DPS to break, stops raid damage
        [1246461] = "brown",   -- Rift Slash: current target + stacking stat reduction; tank buster
        -- Stage 3: The End of the End
        [1238843] = "orange",  -- Devouring Cosmos: "players caught within" = dodge the area
        [1239080] = "purple",  -- Aspect of the End: stacking debuff; must move 30y to clear
    },

    ----------------------------------------------------------------
    -- The Dreamrift
    ----------------------------------------------------------------

    ["BigWigs_Bosses_Chimaerus the Undreamt God"] = {
        -- Stage 1: Insatiable Hunger
        [1262289] = "yellow",  -- Alndust Upheaval: damage split evenly within 10y; soak
        [1258610] = "green",   -- Rift Emergence: Manifestations emerge (adds)
        [1264756] = "purple",  -- Rift Madness: debuff on several players (horror + DoT)
        [1257087] = "purple",  -- Consuming Miasma: 1min DoT debuff; dispel-required
        [1246653] = "red",     -- Caustic Phlegm: damage to all players; unavoidable raid DoT
        [1272726] = "orange",  -- Rending Tear: frontal cone; dodge
        [1245396] = "red",     -- Consume: damage to all players every 2s for 10s; unavoidable
        -- Stage 2: To The Skies
        [1245486] = "orange",  -- Corrupted Devastation: "players standing in the area"; dodge breath
        [1245406] = "gray",    -- Ravenous Dive: phase transition (returns to S1)
        [1246621] = "red",     -- Caustic Phlegm: damage to all players; unavoidable (S2)
        [1257085] = "yellow",  -- Consuming Miasma S2: eruption within 10y; spread positioning
    },

    ----------------------------------------------------------------
    -- M+ Season 1 Dungeons (LittleWigs)
    ----------------------------------------------------------------

    -- Magister's Terrace
    ["BigWigs_Bosses_Arcanotron Custos"] = {
        [474496] = "brown",    -- Repulsing Slam: strikes current target; tank buster
        [1214081] = "red",     -- Arcane Expulsion: damage to all players + knockback; unavoidable
        [1214032] = "purple",  -- Ethereal Shackles: root + DoT on several players; debuff
        [474345] = "green",    -- Refueling Protocol: boss vulnerable; priority burn window
    },
    ["BigWigs_Bosses_Seranel Sunlash"] = {
        [1225787] = "yellow",  -- Runic Mark: bouncing glaive; spread to avoid chaining
        [1224903] = "orange",  -- Suppression Zone: within 8y; dodge zone
        [1248689] = "purple",  -- Hastening Ward: boss buff; magic mechanic to deal with
    },
    ["BigWigs_Bosses_Gemellus"] = {
        [1223847] = "green",   -- Triplicate: creates 2 clones (adds)
        [1284954] = "yellow",  -- Cosmic Sting: creates pool at player location; place well
        [1253709] = "yellow",  -- Neural Link: player must touch Gemellus to break; positioning
        [1224299] = "blue",    -- Astral Grasp: pulls player toward boss; forced movement
    },
    ["BigWigs_Bosses_Degentrius"] = {
        [1280113] = "brown",   -- Hulking Fragment: smashes current target; tank buster
        [1215897] = "purple",  -- Devouring Entropy: DoT debuff on several players; orbs on expiry
    },

    -- Maisara Caverns
    ["BigWigs_Bosses_Muro'jin and Nekraxx"] = {
        [1266480] = "brown",   -- Flanking Spear: harpoons behind current target; tank hit
        [1246666] = "purple",  -- Infected Pinions: 30s plague DoT on all players; debuff
        [1260731] = "orange",  -- Freezing Trap: dodge traps on ground
        [1243900] = "orange",  -- Fetid Quillstorm: within 10y/3y; dodge impact zones
        [1260643] = "orange",  -- Barrage: frontal cone at fixated player; dodge cone
    },
    ["BigWigs_Bosses_Vordaza"] = {
        [1251554] = "brown",   -- Drain Soul: siphons from current target; tank hit + heal absorb
        [1251204] = "green",   -- Wrest Phantoms: manifests Unstable Phantoms (adds)
        [1252054] = "orange",  -- Unmake: frontal surge; dodge
        [1250708] = "red",     -- Necrotic Convergence: damage to all players every 2s; unavoidable
    },
    ["BigWigs_Bosses_Rak'tul, Vessel of Souls"] = {
        [1251023] = "brown",   -- Spiritbreaker: pummels "his target" twice; tank buster
        [1252676] = "orange",  -- Crush Souls: within 5y of each slam; dodge impacts
        [1253788] = "red",     -- Soulrending Roar: applies Withering Soul to all players; unavoidable
    },

    -- Nexus-Point Xenas
    ["BigWigs_Bosses_Corewarden Nysarra"] = {
        [1247937] = "brown",   -- Umbral Lash: slashes primary target; tank buster
        [1249014] = "orange",  -- Eclipsing Step: within 14y of random strikes; dodge
        [1252703] = "green",   -- Null Vanguard: remnants rise (adds)
        [1264439] = "yellow",  -- Lightscar Flare: position in flare for damage buff; positioning
    },
    ["BigWigs_Bosses_Lothraxion"] = {
        [1253950] = "brown",   -- Searing Rend: double-slash on current target; tank buster
        [1253855] = "yellow",  -- Brilliant Dispersion: targets several players within 8y; spread
        [1255531] = "orange",  -- Flicker: images move, damage in path; dodge
        [1257595] = "green",   -- Divine Guile: find + interrupt Lothraxion; priority control
    },

    -- Windrunner Spire
    ["BigWigs_Bosses_Emberdawn"] = {
        [466556] = "purple",   -- Flaming Updraft: DoT debuff on targeted player; fire patch after
        [466064] = "brown",    -- Searing Beak: pecks current target; tank buster
        [465904] = "red",      -- Burning Gale: damage to all players every 1s + push; unavoidable
    },
    ["BigWigs_Bosses_Derelict Duo"] = {
        [472745] = "yellow",   -- Splattering Spew: targets players within 5y; spread
        [472888] = "brown",    -- Bone Hack: chops primary target; tank buster
        [474105] = "purple",   -- Curse of Darkness: curses players; debuff
        [472736] = "red",      -- Debilitating Shriek: damage to all players + stacking; unavoidable
    },
    ["BigWigs_Bosses_Commander Kroluk"] = {
        [467620] = "brown",    -- Rampage: thrashes current target; tank buster
        [472081] = "orange",   -- Reckless Leap: within 12y of impact; dodge
        [1253272] = "yellow",  -- Intimidating Shout: stand alone = feared; stack together
    },
    ["BigWigs_Bosses_Restless Heart"] = {
        [472556] = "orange",   -- Arrow Rain: within 3.5y of impacts; dodge zones
        [472662] = "brown",    -- Tempest Slash: knocks away primary target + 40% phys debuff; tank
        [1253986] = "yellow",  -- Gust Shot: marks players, within 8y on expiry; spread
        [474528] = "orange",   -- Bolt Gale: frontal cone at player; dodge cone
    },

    -- Algeth'ar Academy (Dragonflight)
    ["BigWigs_Bosses_Crawth"] = {
        [376997] = "brown",    -- Savage Peck: pecks "her target"; tank buster
        [377004] = "yellow",   -- Deafening Screech: eruption at each player location within 4y; spread
        [377034] = "blue",     -- Overpowering Gust: faces player, knocks back all in front; forced movement
    },
    ["BigWigs_Bosses_Echo of Doragosa"] = {
        [373326] = "purple",   -- Arcane Missiles: applies Overwhelming Power debuff
        [1282251] = "purple",  -- Astral Blast: blasts target player + Overwhelming Power; debuff
        [374343] = "yellow",   -- Energy Bomb: positioning/soak mechanic
        [388822] = "blue",     -- Power Vacuum: pulls all players in then knocks back; forced movement
    },
    ["BigWigs_Bosses_Overgrown Ancient"] = {
        [388796] = "orange",   -- Germinate: seeds erupt at feet every 1s; move immediately
        [388923] = "green",    -- Burst Forth: awakens all dormant Lashers (adds)
        [388623] = "green",    -- Branch Out: throws branch that animates as add
        [388544] = "brown",    -- Barkbreaker: stomps target + 100% phys debuff; tank buster
    },
    ["BigWigs_Bosses_Vexamus"] = {
        [386544] = "yellow",   -- Arcane Orbs: soak orbs before boss absorbs; positioning
        [388537] = "red",      -- Arcane Fissure: damage to all players at 100 energy; unavoidable
        [386173] = "yellow",   -- Mana Bombs: detonates at player location; place pools well
        [385958] = "orange",   -- Arcane Expulsion: frontal cone; dodge
    },

    -- Skyreach (Warlords of Draenor)
    ["BigWigs_Bosses_Ranjit"] = {
        [153757] = "red",      -- Fan of Blades: all directions; unavoidable raid damage + bleed
        [1258152] = "orange",  -- Wind Chakram: in front of him; dodge path
    },
    ["BigWigs_Bosses_Araknath"] = {
        [154110] = "orange",   -- Fiery Smash: smashes one side; dodge to other side
        [154135] = "red",      -- Supernova: damage to all players; unavoidable
    },
    ["BigWigs_Bosses_Rukhran"] = {
        [1253519] = "brown",   -- Burning Claws: lashes current target; tank buster
        [1253510] = "green",   -- Sunbreak: summons a Sunwing (add)
    },
    ["BigWigs_Bosses_High Sage Viryx"] = {
        [1253538] = "purple",  -- Scorching Ray: DoT on several players; debuff
        [154396] = "brown",    -- Solar Blast: blasts current target for 228k; tank buster
        [153954] = "blue",     -- Cast Down: carries player off balcony; forced displacement
        [1253840] = "orange",  -- Lens Flare: within 6y of impact; dodge
    },

    -- Pit of Saron (Wrath of the Lich King)
    ["BigWigs_Bosses_Forgemaster Garfrost"] = {
        [1261299] = "orange",  -- Throw Saronite: within 10y of impact; dodge
        [1261546] = "brown",   -- Orebreaker: within 5y of primary target; tank buster
        [1262029] = "yellow",  -- Glacial Overload: get behind saronite ore; positioning
        [1261847] = "red",     -- Cryostomp: damage to all players; unavoidable + sends Cryoshards
    },
    ["BigWigs_Bosses_Ick & Krick"] = {
        [1264287] = "brown",   -- Blight Smash: smashes target; tank buster
        [1264336] = "red",     -- Plague Expulsion: damage to all players; unavoidable + globs
        [1264027] = "green",   -- Shade Shift: summons Shades of Krick (adds)
        [1264363] = "gray",    -- Get 'Em, Ick!: Ick enters fixation phase; informational
    },
    ["BigWigs_Bosses_Scourgelord Tyrannus"] = {
        [1262745] = "orange",  -- Rime Blast: within 6y of player; dodge splash
        [1262582] = "brown",   -- Scourgelord's Brand: knocks primary target + 200% shadow debuff; tank
        [1263756] = "orange",  -- Death's Grasp: within 6y at player locations; dodge
        [1263406] = "green",   -- Army of the Dead: raises adds from Bone Piles
        [1276948] = "orange",  -- Ice Barrage: within 6y of each impact for 4.5s; dodge
    },
}
