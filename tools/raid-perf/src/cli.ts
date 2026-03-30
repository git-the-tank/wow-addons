#!/usr/bin/env node

import { loadConfig } from "./config.js";
import { fetchGuildRoster, filterByRank } from "./blizzard.js";
import { fetchCurrentZone, fetchAllParsesForCharacter } from "./wcl.js";
import { computePlayerData, computeRaidAverages } from "./metrics.js";
import { writeSavedVariables, serializeToLua } from "./lua-writer.js";
import type { Config, PlayerData, RaidPerformanceData } from "./types.js";
import { writeFile } from "node:fs/promises";

async function cmdRoster(config: Config) {
  console.log(`Fetching roster for <${config.guild}> on ${config.realm}-${config.region}...`);
  console.log(`Filtering to ranks: [${config.ranks.join(", ")}]\n`);

  const allMembers = await fetchGuildRoster(config);
  const filtered = filterByRank(allMembers, config.ranks);

  console.log(`${allMembers.length} total members, ${filtered.length} match rank filter:\n`);

  // Sort by rank, then name
  filtered.sort((a, b) => a.rank - b.rank || a.name.localeCompare(b.name));

  for (const m of filtered) {
    console.log(
      `  [Rank ${m.rank}] ${m.name}-${m.realm}  ${m.class}  Lvl ${m.level}`
    );
  }
}

async function cmdSync(config: Config, opts: { dryRun?: boolean; zone?: string }) {
  console.log(`Syncing performance data for <${config.guild}> on ${config.realm}-${config.region}`);
  console.log(`Difficulty: ${config.difficulty}`);
  console.log(`Ranks: [${config.ranks.join(", ")}]\n`);

  // Step 1: Get roster
  console.log("Fetching guild roster...");
  const allMembers = await fetchGuildRoster(config);
  const roster = filterByRank(allMembers, config.ranks);
  console.log(`  ${roster.length} raiders found\n`);

  if (roster.length === 0) {
    console.log("No members match rank filter. Check your config ranks.");
    return;
  }

  // Step 2: Get current zone/encounters
  console.log("Fetching raid zone info...");
  const zone = await fetchCurrentZone(config, opts.zone);
  console.log(`  Zone: ${zone.name} (${zone.encounters.length} bosses)\n`);

  // Step 3: Fetch parses for each raider
  const maxRecent = config.maxRecentParses ?? 10;
  const players: Record<string, PlayerData> = {};

  for (let i = 0; i < roster.length; i++) {
    const member = roster[i];
    const key = `${member.name}-${member.realm}`;
    console.log(
      `  [${i + 1}/${roster.length}] Fetching parses for ${key}...`
    );

    const serverSlug = member.realm.toLowerCase().replace(/\s+/g, "-");
    const parses = await fetchAllParsesForCharacter(
      config,
      member.name,
      serverSlug,
      zone
    );

    if (parses.length === 0) {
      console.log(`    No parses found`);
      continue;
    }

    console.log(`    ${parses.length} parses across ${new Set(parses.map((p) => p.encounterName)).size} bosses`);
    players[key] = computePlayerData(member, parses, maxRecent);
  }

  // Step 4: Compute raid averages
  const raidAverages = computeRaidAverages(players);

  // Step 5: Build output
  const output: RaidPerformanceData = {
    generatedAt: Math.floor(Date.now() / 1000),
    tier: zone.name,
    difficulty: config.difficulty,
    guild: config.guild,
    realm: config.realm,
    players,
    raidAverages,
  };

  if (opts.dryRun) {
    const path = "raid-perf-output.lua";
    await writeFile(path, serializeToLua(output), "utf-8");
    console.log(`\nDry run: wrote output to ${path}`);
  } else {
    const path = await writeSavedVariables(config, output);
    console.log(`\nWrote SavedVariables to ${path}`);
  }

  // Print summary
  console.log(`\nSummary:`);
  console.log(`  Players: ${Object.keys(players).length}`);
  console.log(`  Bosses: ${Object.keys(raidAverages).length}`);
  for (const [boss, avg] of Object.entries(raidAverages)) {
    console.log(`    ${boss}: raid median ${avg.medianParse}% / ${avg.medianDPS.toLocaleString()} DPS`);
  }
}

function printUsage() {
  console.log(`raid-perf - Raid performance data for WoW addon

Usage:
  raid-perf roster              Show filtered guild roster (dry run)
  raid-perf sync                Pull WCL data and write SavedVariables
  raid-perf sync --dry-run      Pull data but write to local file instead
  raid-perf sync --zone "Name"  Target a specific raid zone

Config:
  Create .raidperfrc.json in the current directory. See README for format.
`);
}

async function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command || command === "--help" || command === "-h") {
    printUsage();
    return;
  }

  const config = await loadConfig();

  switch (command) {
    case "roster":
      await cmdRoster(config);
      break;

    case "sync": {
      const dryRun = args.includes("--dry-run");
      const zoneIdx = args.indexOf("--zone");
      const zone = zoneIdx >= 0 ? args[zoneIdx + 1] : undefined;
      await cmdSync(config, { dryRun, zone });
      break;
    }

    default:
      console.error(`Unknown command: ${command}`);
      printUsage();
      process.exit(1);
  }
}

main().catch((err) => {
  console.error("Error:", err instanceof Error ? err.message : err);
  process.exit(1);
});
