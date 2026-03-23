We are defining a canonical color system for World of Warcraft boss ability timeline bars.

Goal:
Create a consistent, low-friction visual language so players can recognize the type of mechanic instantly across all bosses, instead of relearning colors boss by boss. The purpose is faster pattern recognition during raid and Mythic+, especially when reading compact timeline bars.

Core strategy:
Color bars by required player response, not by spell school, boss theme, or class fantasy.

This is important because:
1. The same kind of action should always look the same, even on different bosses.
2. Players should identify "what do I need to do?" at a glance.
3. Timeline bars are easier to scan when color meaning is stable.
4. Default/info bars should fade into the background, while action bars stand out.

Canonical palette (high-contrast, varied brightness for readability on small bars):
Default / Info / Phase: #6B7280
Raid Damage: #FF3333
Dodge / Move: #E67300
Soak / Stack / Positioning: #FFD700
Adds / Target Swap / Kicks / Priority Control: #22BB55
Knockback / Forced Movement: #4488FF
Beams / Debuffs / Magic Mechanics: #BB44EE
Tank Buster / Tank Swap / Tank-focused Hit: #7A3B10

High-level meaning of each color:
#6B7280 = informational or neutral; phase markers, berserk, general info, low urgency (dark)
#FF3333 = raid-wide damage or major group defensive/healing event (bright)
#E67300 = immediate movement or personal dodge response (medium-high)
#FFD700 = positioning check; soak, stack, spread, orb handling, pools, placement mechanics (very bright)
#22BB55 = priority enemy interaction; adds, interrupts, kicks, target swap, control target (medium)
#4488FF = forced movement; knockback, pull, displacement, movement imposed on player (bright)
#BB44EE = beams, debuffs, magic-style targeted mechanics, magical pressure mechanics (medium)
#7A3B10 = tank-centric mechanic; tank buster, tank hit, taunt swap, current-target impact (low)

Decision rules:
1. Default to gray if the mechanic is informational and not action-defining.
2. Choose the color based on the primary player response.
3. If a mechanic could fit multiple categories, pick the category that matters most in real gameplay.
4. Prefer consistency over perfect semantic purity.
5. Tank-specific mechanics should stay visually distinct from raid-wide mechanics.
6. Do not color by damage type alone; color by what players need to do.
7. Do not use multiple shades of red/orange for different urgent mechanics unless there is a strong reason, because that reduces scan speed.

Priority order when assigning a color:
1. Is it tank-specific? Use Tank if that is the main gameplay implication.
2. Is it raid-wide damage or a healing/defensive event? Use Raid Damage.
3. Is the main response to move or dodge immediately? Use Dodge / Move.
4. Is the main response to position correctly, soak, stack, spread, handle orbs, or place pools? Use Soak / Stack / Positioning.
5. Is the main response to swap to adds, interrupt, kick, or control a target? Use Adds / Target Swap / Kicks.
6. Is the mechanic mainly a beam, debuff, or magic-style targeted effect? Use Beams / Debuffs / Magic Mechanics.
7. Is the mechanic mainly forced displacement? Use Knockback / Forced Movement.
8. Otherwise use Default / Info / Phase.

Examples from one boss:
Berserk = #6B7280
Reason: informational timer, not a discrete response mechanic

Void Convergence (Orbs) = #CA8A04
Reason: orb handling and positioning mechanic

Entropic Unraveling (Full Energy) = #DC2626
Reason: major raid-wide damage event

Shattering Twilight (Spikes) = #92400E
Reason: current-target hit; tank-linked mechanic first

Fractured Projection (Kicks) = #16A34A
Reason: priority control / interrupt style mechanic

Despotic Command (Pools) = #CA8A04
Reason: positioning and placement mechanic

Twisting Obscurity (Raid Damage) = #DC2626
Reason: explicit raid damage event

Design philosophy:
We are optimizing for readability, consistency, and muscle memory. The player should eventually learn:
red = survive raid damage
orange = move now
yellow = position correctly
green = interact with adds / kicks / swaps
blue = forced movement
purple = beam / debuff / magic pressure
brown = tank event
gray = info

When classifying new abilities:
Do not overfit to boss flavor text. Read the mechanic description and decide what the player or raid actually has to do. If an ability name sounds magical but functions mainly as a soak or positioning check, color it yellow, not purple.

Output expectation:
When given a list of boss abilities, assign one canonical hex color to each ability and include a short reason based on the primary response category.
