local _, ns = ...

------------------------------------------------------------
-- Boss Roster (order determines prev/next cycling)
------------------------------------------------------------
ns.BOSSES = {
    -- The Voidspire (instanceID 2912)
    { key = "averzian",  name = "Imperator Averzian",         short = "Averzian",   instanceID = 2912, encounterID = 3176 },
    { key = "vorasius",  name = "Vorasius",                   short = "Vorasius",   instanceID = 2912, encounterID = 3177 },
    { key = "salhadaar", name = "Fallen-King Salhadaar",      short = "Salhadaar",  instanceID = 2912, encounterID = 3179 },
    { key = "vaelgor",   name = "Vaelgor & Ezzorak",          short = "V&E",        instanceID = 2912, encounterID = 3178 },
    { key = "vanguard",  name = "Lightblinded Vanguard",      short = "Vanguard",   instanceID = 2912, encounterID = 3180 },
    { key = "crown",     name = "Crown of the Cosmos",        short = "Crown",      instanceID = 2912, encounterID = 3181 },
    -- The Dreamrift (instanceID 2939)
    { key = "chimaerus", name = "Chimaerus the Undreamt God", short = "Chimaerus",  instanceID = 2939, encounterID = 3306 },
    -- March on Quel'Danas (instanceID 2913)
    { key = "beloren",   name = "Belo'ren, Child of Al'ar",   short = "Belo'ren",   instanceID = 2913, encounterID = 3182 },
    { key = "lura",      name = "Midnight Falls",             short = "L'ura",      instanceID = 2913, encounterID = 3183 },
}

-- Encounter ID -> boss index lookup
ns.ENCOUNTER_TO_BOSS = {}
for i, boss in ipairs(ns.BOSSES) do
    ns.ENCOUNTER_TO_BOSS[boss.encounterID] = i
end

-- Raid groupings (for display context)
ns.RAIDS = {
    { name = "The Voidspire",       short = "VS",  instanceID = 2912, first = 1, last = 6 },
    { name = "The Dreamrift",       short = "DR",  instanceID = 2939, first = 7, last = 7 },
    { name = "March on Quel'Danas", short = "MQD", instanceID = 2913, first = 8, last = 9 },
}

-- Instance ID -> raid lookup
ns.INSTANCE_TO_RAID = {}
for _, raid in ipairs(ns.RAIDS) do
    ns.INSTANCE_TO_RAID[raid.instanceID] = raid
end

------------------------------------------------------------
-- Default Note Content
--
-- Line prefixes drive color coding:
--   SWAP  = orange     (tank swap triggers)
--   POS   = cyan       (positioning)
--   DEF   = red        (defensive / danger)
--   ADDS  = green      (add management)
--   MOVE  = yellow     (movement / transitions)
--   CALL  = white      (raid leader callouts)
--   HERO  = yellow     (lust timing)
--   [M]   = purple     (mythic-only)
--   (other) = gray     (continuation / detail)
------------------------------------------------------------
ns.DEFAULT_NOTES = {

    ----------------------------------------------------------------
    -- 1. Imperator Averzian (Voidspire)
    ----------------------------------------------------------------
    averzian = {
        tank = {
            default = table.concat({
                "SWAP @ 8-10 stacks Blackening Wounds (20s, -4% maxHP/stack)",
                "  Off-tank = add magnet (highest stacks pulls adds)",
                "",
                "POS  Keep boss OFF claimed tiles (10yd = 75% dmg + 90% DR)",
                "POS  Center boss on grid, tanks adjust around claims",
                "POS  3x3 tic-tac-toe -- block 3-in-a-row or wipe",
                "",
                "DEF  Add waves at high stacks -- Shield Wall if needed",
                "DEF  Adds buffed near boss on Heroic+ (Imperator's Glory)",
                "",
                "ADDS Voidshapers x3 per Shadow's Advance wave",
                "ADDS Raid soaks Umbral Collapse on 2 of 3 tiles",
                "ADDS 1 tile claimed per wave -- RL calls which to save",
                "",
                "MOVE No phase transitions -- continuous waves + board",
                "MOVE Soft enrage: 3 tiles in a line = wipe",
            }, "\n"),
            mythic = table.concat({
                "[M] Abyssal Nightshade adds spawn -- extra pickup",
            }, "\n"),
        },
        calls = {
            default = table.concat({
                "CALL Which 2 tiles to soak each Shadow's Advance",
                "CALL \"Adds spawning\" -- DPS switch + swap warning",
                "CALL Track board state: which tiles claimed, what's dangerous",
                "",
                "HERO On pull",
                "  2T / 4H / 14 DPS -- heavy cleave fight",
            }, "\n"),
        },
        notes = { default = "" },
    },

    ----------------------------------------------------------------
    -- 2. Vorasius (Voidspire)
    ----------------------------------------------------------------
    vorasius = {
        tank = {
            default = table.concat({
                "SWAP T1 soaks first 2 Shadowclaw Slams -> 2x Smashed",
                "  Smashed = 150% phys taken/stack, 2 min duration",
                "  T2 takes boss + soaks remaining slams until reset",
                "  Immunities do NOT prevent Smashed",
                "",
                "POS  Stack in front of boss on pull (Primordial Roar healing)",
                "POS  After slam: melee step into impact center (safe from Aftershock)",
                "",
                "DEF  2-stack Smashed = 300% phys for 2 min -- play defensive",
                "DEF  Primordial Roar = heavy raidwide -- stack tight",
                "",
                "ADDS Blistercreep fixate on one tank -- kite into walls",
                "ADDS Walls need 2 Blistercreep explosions to destroy (Heroic)",
                "",
                "MOVE Cycle: slams -> walls -> parasites -> kite to walls -> detonate -> Void Breath",
                "MOVE Hand glow: left glow = run right, right glow = run left",
            }, "\n"),
            mythic = table.concat({
                "[M] Walls need 3 Blistercreep explosions to destroy",
            }, "\n"),
        },
        calls = {
            default = table.concat({
                "CALL \"Stack front\" on pull and after each Void Breath",
                "CALL \"Kite parasites to wall\" when Blistercreep spawns",
                "CALL \"Dodge left/right\" for Void Breath (hand glow)",
                "",
                "HERO On pull",
                "  2T / 4H / 14 DPS -- heavy ST + intermittent cleave",
            }, "\n"),
        },
        notes = { default = "" },
    },

    ----------------------------------------------------------------
    -- 3. Fallen-King Salhadaar (Voidspire)
    ----------------------------------------------------------------
    salhadaar = {
        tank = {
            default = table.concat({
                "SWAP On Destabilizing Strikes stacks (15s DoT, ramps)",
                "  Swap when damage feels dangerous, no fixed count",
                "",
                "POS  Move boss to side before Entropic Unraveling",
                "POS  Leave room for raid to rotate with beams",
                "POS  Drag boss toward marked gates for orb cleave",
                "",
                "DEF  Shattering Twilight on tank -- spikes erupt outward",
                "DEF  Aim spikes AWAY from boss and raid",
                "DEF  Never aim toward orb lanes",
                "",
                "ADDS Concentrated Void Orbs from portals -- must die before reaching boss",
                "ADDS If orb reaches boss: Reckless Infusion = massive raidwide + 1min DoT",
                "ADDS Destroy orbs 8s apart (Galactic Miasma overlap kills)",
                "",
                "MOVE Boss immobile during 20s damage amp window",
                "MOVE Otherwise movable -- reposition for orb management",
            }, "\n"),
        },
        calls = {
            default = table.concat({
                "CALL \"Orbs spawning [gate]\" -- call which portal",
                "CALL \"Kill orb NOW\" / \"HOLD -- wait for miasma\"",
                "CALL \"Spread for spikes\" on Shattering Twilight",
                "CALL \"Rotate\" during Entropic Unraveling beams",
                "",
                "HERO During damage amp window (boss immobile phase)",
            }, "\n"),
        },
        notes = { default = "" },
    },

    ----------------------------------------------------------------
    -- 4. Vaelgor & Ezzorak (Voidspire)
    ----------------------------------------------------------------
    vaelgor = {
        tank = {
            default = table.concat({
                "SWAP After each Gloom cast -- run to other boss",
                "  Do NOT drag bosses, just run to swap positions",
                "  Vaelwing/Rakfang ramp resets on new target",
                "",
                "POS  Keep 15yd+ apart (Twilight Bond = 100% dmg if <15yd)",
                "POS  Keep within 10% HP or same bond triggers",
                "POS  NEVER stand behind either boss (Tail Lash = KB + bleed)",
                "",
                "DEF  Nullbeam (Vaelgor): frontal 4s DoT -- soak ~8 stacks then step out",
                "DEF  Rakfang (Ezzorak): big hit + heal absorb -> Impale cone = stun + bleed",
                "DEF  Grappling Maw (flying phase): stay CLOSE to minimize grip dmg",
                "",
                "ADDS Nullzone tethers: tank snaps LAST (final snap = raid DoT)",
                "ADDS Void Howl: stack tight so orbs spawn grouped",
                "",
                "MOVE One boss flies each phase, alternates after intermission",
                "MOVE At 100 energy: unavoidable raidwide -- stack for healing",
            }, "\n"),
        },
        calls = {
            default = table.concat({
                "CALL \"Swap\" after each Gloom",
                "CALL \"Stack for Void Howl\" -- tight stack, no circle overlap",
                "CALL \"Snap tethers\" on Nullzone -- all snap, tank LAST",
                "CALL \"Balance DPS\" if HP gap >5%",
                "",
                "HERO Second ground phase (both grounded after first intermission)",
            }, "\n"),
        },
        notes = { default = "" },
    },

    ----------------------------------------------------------------
    -- 5. Lightblinded Vanguard (Voidspire)
    ----------------------------------------------------------------
    vanguard = {
        tank = {
            default = table.concat({
                "SWAP Immediately after Judgment lands (Venel + Bellamy)",
                "  Judgment = 200% dmg taken from next spender for 5s",
                "  Venel: Judgment -> Final Verdict (swap before FV hits)",
                "  Bellamy: Judgment -> Shield of the Righteous (swap before SotR)",
                "  Senn: Exorcism only, no Judgment combo -- no swap needed",
                "",
                "POS  Tank energy-capping boss on EDGE of room",
                "  At 100 energy: boss is immovable, drops permanent Consecration",
                "  Energy order: Bellamy -> Venel -> Senn",
                "POS  Keep Consecration puddles at edges, preserve center",
                "",
                "DEF  Avenging Wrath (Venel): +30% dmg done for 20s -- more dangerous",
                "DEF  Divine Shield: 8s immunity, can't prevent -- plan around it",
                "DEF  Aura of Peace (Senn): don't attack protected targets = 4s pacify",
                "",
                "ADDS All 3 bosses need tanking at all times",
                "ADDS Keep HP within ~5% -- Retribution on death = 5% ramp every 2s",
                "ADDS Kill all 3 together -- stagger deaths = wipe",
                "",
                "MOVE Bellamy Aura of Devotion: 75% DR to allies in 40yd",
                "MOVE Senn Aura of Peace: pacify if you attack shielded targets",
            }, "\n"),
        },
        calls = {
            default = table.concat({
                "CALL \"[Boss] capping\" -- 5s before 100 energy, confirm edge position",
                "CALL \"Swap\" after each Judgment (Venel/Bellamy)",
                "CALL \"Balance DPS\" -- keep HP even across all 3",
                "CALL \"Don't attack\" during Aura of Peace (Senn)",
                "CALL \"Burn together\" at 10% -- coordinate kill timing",
                "",
                "HERO After first round of ultimates (all 3 have cast once)",
            }, "\n"),
        },
        notes = { default = "" },
    },

    ----------------------------------------------------------------
    -- 6. Crown of the Cosmos / Alleria (Voidspire)
    ----------------------------------------------------------------
    crown = {
        tank = {
            default = table.concat({
                "SWAP P2: at 2-3 stacks Rift Slash (-10% all stats/stack, 20s)",
                "SWAP P3: around Aspect of the End tether break",
                "  Tank break = 300% phys taken for 12s -- pre-swap before break",
                "",
                "POS  P1: One tank on Morium (stays at portal), one on Demair (raid stack)",
                "  Morium tank needs dedicated melee healer in range",
                "POS  P2: Position for Voidspawn adds -- interrupt Void Barrage before 100 energy",
                "POS  P3: Manage platform rotation for Devouring Cosmos puddles",
                "",
                "DEF  P3 tether break order: Ranged -> Melee -> Tank",
                "DEF  Tank break last = 300% phys 12s -- big CD + external",
                "DEF  Void Barrage at 100 energy = uninterruptible, massive dmg",
                "",
                "ADDS P1: Morium tank collects Void Droplets (30% dmg taken debuff on expire)",
                "  Droplet expire debuffs sentinels too -- cleave value",
                "ADDS P1: Sentinels unkillable until hit by Silverstrike Arrow",
                "ADDS P2: Undying Voidspawns need Ranger Captain's Mark before killable",
                "",
                "MOVE P1->P2: Sentinels die, Rift Simulacrum spawns",
                "MOVE P2->P3: Simulacrum dies at 62% boss HP (Voidlink shared HP)",
                "MOVE P3: DPS race -- Hero here, burn before Gravity Collapse overwhelms",
            }, "\n"),
        },
        calls = {
            default = table.concat({
                "CALL P1: \"Arrow on [sentinel]\" -- coordinate Silverstrike targets",
                "CALL P2: \"Interrupt Void Barrage\" -- assign interrupt rotation",
                "CALL P2: \"Swap\" at 2-3 Rift Slash stacks",
                "CALL P3: \"Break order: ranged -> melee -> tank\"",
                "CALL P3: \"Rotate\" for Devouring Cosmos puddles",
                "",
                "HERO P3 start -- DPS race, burn with everything",
                "  Hardest boss in tier. Multi-phase coordination check.",
            }, "\n"),
        },
        notes = { default = "" },
    },

    ----------------------------------------------------------------
    -- 7. Chimaerus (Dreamrift)
    ----------------------------------------------------------------
    chimaerus = {
        tank = {
            default = table.concat({
                "SWAP Follows Alnsight debuff rotation",
                "  Group A soaks Alndust Upheaval -> gains Alnsight (40s)",
                "  Alnsight expires -> Rift Vulnerability (90s, can't soak next)",
                "  Group B soaks next -> groups alternate",
                "",
                "POS  Pre-split: 2 groups, 1T / 2H / 7D each",
                "POS  Alnsight tank goes downstairs to Colossal Horror",
                "POS  Normal tank stays on boss",
                "POS  Place Alndust Upheaval soak off to the side",
                "",
                "DEF  Colossal Horror ramps damage over time -- CDs as it escalates",
                "DEF  Boss eats any add that reaches him: raidwide + 200% heal + 100% dmg buff",
                "DEF  One eaten add can snowball into a wipe",
                "",
                "ADDS DO NOT let adds reach boss -- #1 priority",
                "ADDS Small adds (Swarming Shade): stack for AoE before they reach boss",
                "ADDS Colossal Horror: tank away, keep positioned for group cleave",
                "",
                "MOVE P1 ends at 100 energy: Consume (eats remaining adds, KBs everyone)",
                "MOVE Intermission: dodge Corrupted Devastation breath + line",
                "MOVE Ravenous Dive: boss crashes down, KBs all, eats remaining adds -> P1 repeat",
                "MOVE Rending Tear: frontal cone -- if aimed at you, step out",
            }, "\n"),
        },
        calls = {
            default = table.concat({
                "CALL \"Group A soak\" / \"Group B soak\" -- alternate on Alndust Upheaval",
                "CALL \"Kill adds\" -- priority call if anything leaking toward boss",
                "CALL \"Interrupt Haunting Essence\" -- assign rotation",
                "CALL \"Spread\" during Rending Tear",
                "CALL \"Dodge breath\" during intermission",
                "",
                "HERO Second P1 (after first intermission, boss is lower)",
                "  1-boss raid. Interrupt-heavy. Add control = fight control.",
            }, "\n"),
        },
        notes = { default = "" },
    },

    ----------------------------------------------------------------
    -- 8. Belo'ren, Child of Al'ar (March on Quel'Danas)
    ----------------------------------------------------------------
    beloren = {
        tank = {
            default = table.concat({
                "SWAP Tanks always have opposite feather colors (Light vs Void)",
                "  Each tank soaks matching-color Guardian's Edict frontals",
                "  Missed soak = boss gains 30% dmg buff for 30s (stacks!)",
                "",
                "POS  Set markers for Light side and Void side",
                "POS  Position so each tank catches their color frontals",
                "POS  Active positioning -- move to intercept, not passive",
                "",
                "DEF  Burning Heart escalates each Rebirth cycle -- healing gets harder",
                "DEF  Death Drop: boss launches skyward then crashes -- reposition fast",
                "DEF  Use gateway after Death Drop to recover position",
                "",
                "ADDS Egg Phase: 30s burn window at 0% Phoenix HP",
                "ADDS Egg phase still has cone mechanics -- stay sharp",
                "ADDS Phoenix form damage does NOT count toward kill",
                "",
                "MOVE Phoenix Phase -> Death Drop -> Egg Phase -> repeat",
                "MOVE Each cycle = more Burning Heart stacks = harder healing",
            }, "\n"),
        },
        calls = {
            default = table.concat({
                "CALL \"Soak [Light/Void]\" -- remind tanks of color assignments",
                "CALL \"Egg phase -- burn\" -- all CDs on egg",
                "CALL \"Gateway\" after Death Drop for repositioning",
                "CALL Track missed soaks -- boss dmg buff is multiplicative",
                "",
                "HERO First Egg Phase burn window (not Phoenix Phase)",
            }, "\n"),
        },
        notes = { default = "" },
    },

    ----------------------------------------------------------------
    -- 9. Midnight Falls / L'ura (March on Quel'Danas)
    ----------------------------------------------------------------
    lura = {
        tank = {
            default = table.concat({
                "SWAP Standard swap rotation on tankbusters",
                "  No dramatic swap mechanic -- just trade on buster CDs",
                "",
                "POS  Hold Void Tentacles away from raid",
                "POS  Position for Death's Dirge sharing (stack with raid when targeted)",
                "",
                "DEF  Death's Dirge: massive dmg on expire + vulnerability",
                "  Stack with raid to split damage",
                "DEF  Big CDs if targeted by Dirge",
                "",
                "ADDS Void Tentacles: add spawns, must be controlled",
                "ADDS Too many alive = healers overwhelmed",
                "ADDS Assign DPS to tentacle duty",
                "",
                "MOVE P2: Shattered Sky -- burn phase, L'ura must die before loops overwhelm",
            }, "\n"),
            mythic = table.concat({
                "[M] No Safeguard Prism on Mythic -- significantly harder",
                "[M] Personal defensives more critical for Dirge soaks",
            }, "\n"),
        },
        calls = {
            default = table.concat({
                "CALL \"Stack for Dirge\" -- Death's Dirge soak",
                "CALL \"Tentacles\" -- assign DPS to add control",
                "CALL \"Personals\" when Dirge targets go out",
                "CALL \"Burn phase\" at P2 start -- all CDs",
                "",
                "HERO P2 start (Shattered Sky) -- must burn before overwhelm",
                "  Final boss of MQD. Less mechanically complex, more throughput.",
            }, "\n"),
        },
        notes = { default = "" },
    },
}
