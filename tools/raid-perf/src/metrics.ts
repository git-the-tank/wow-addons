import type {
  WclParse,
  BossPerformance,
  PlayerData,
  PlayerOverall,
  RaidAverage,
  RecentParse,
  GuildMember,
} from "./types.js";

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[mid];
}

function stddev(values: number[]): number {
  if (values.length < 2) return 0;
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  const variance =
    values.reduce((sum, v) => sum + (v - mean) ** 2, 0) / (values.length - 1);
  return Math.sqrt(variance);
}

/**
 * Compute trend as the slope of recent parse percentiles.
 * Positive = improving, negative = declining.
 * Uses simple linear regression over the last N parses (chronological order).
 */
function computeTrend(parses: WclParse[]): number {
  if (parses.length < 2) return 0;

  // Sort chronologically (oldest first)
  const sorted = [...parses].sort((a, b) => a.startTime - b.startTime);
  // Use last 8 parses for trend
  const recent = sorted.slice(-8);

  const n = recent.length;
  const xs = recent.map((_, i) => i);
  const ys = recent.map((p) => p.percentile);

  const xMean = xs.reduce((a, b) => a + b, 0) / n;
  const yMean = ys.reduce((a, b) => a + b, 0) / n;

  let num = 0;
  let den = 0;
  for (let i = 0; i < n; i++) {
    num += (xs[i] - xMean) * (ys[i] - yMean);
    den += (xs[i] - xMean) ** 2;
  }

  // Slope per parse, but we report it as total change over the window
  return den === 0 ? 0 : Math.round((num / den) * (n - 1) * 10) / 10;
}

export function computeBossPerformance(
  parses: WclParse[],
  maxRecent: number
): BossPerformance {
  const percentiles = parses.map((p) => p.percentile);
  const dpsValues = parses.map((p) => p.dps);

  // Sort by date descending for recent parses
  const sortedByDate = [...parses].sort((a, b) => b.startTime - a.startTime);
  const recentParses: RecentParse[] = sortedByDate
    .slice(0, maxRecent)
    .map((p) => ({
      date: Math.floor(p.startTime / 1000),
      dps: p.dps,
      parse: p.percentile,
      ilvl: p.ilvl,
      spec: p.spec,
    }));

  return {
    kills: parses.length,
    medianParse: Math.round(median(percentiles) * 10) / 10,
    bestParse: Math.round(Math.max(...percentiles) * 10) / 10,
    medianDPS: Math.round(median(dpsValues)),
    bestDPS: Math.round(Math.max(...dpsValues)),
    trend: computeTrend(parses),
    consistency: Math.round(stddev(percentiles) * 10) / 10,
    recentParses,
  };
}

export function computePlayerData(
  member: GuildMember,
  allParses: WclParse[],
  maxRecent: number
): PlayerData {
  // Group parses by encounter name
  const byBoss = new Map<string, WclParse[]>();
  for (const parse of allParses) {
    const existing = byBoss.get(parse.encounterName) ?? [];
    existing.push(parse);
    byBoss.set(parse.encounterName, existing);
  }

  const bosses: Record<string, BossPerformance> = {};
  for (const [bossName, parses] of byBoss) {
    bosses[bossName] = computeBossPerformance(parses, maxRecent);
  }

  // Overall stats across all bosses
  const allPercentiles = allParses.map((p) => p.percentile);
  const overall: PlayerOverall = {
    medianParse: Math.round(median(allPercentiles) * 10) / 10,
    trend: computeTrend(allParses),
    consistency: Math.round(stddev(allPercentiles) * 10) / 10,
  };

  // Use most recent parse for spec/ilvl
  const mostRecent = allParses.length > 0
    ? allParses.reduce((a, b) => (a.startTime > b.startTime ? a : b))
    : null;

  return {
    class: member.class,
    spec: mostRecent?.spec ?? "",
    ilvl: mostRecent?.ilvl ?? 0,
    bosses,
    overall,
  };
}

export function computeRaidAverages(
  players: Record<string, PlayerData>
): Record<string, RaidAverage> {
  // Collect all boss names
  const bossNames = new Set<string>();
  for (const player of Object.values(players)) {
    for (const bossName of Object.keys(player.bosses)) {
      bossNames.add(bossName);
    }
  }

  const averages: Record<string, RaidAverage> = {};
  for (const bossName of bossNames) {
    const medianParses: number[] = [];
    const medianDPSes: number[] = [];

    for (const player of Object.values(players)) {
      const boss = player.bosses[bossName];
      if (boss) {
        medianParses.push(boss.medianParse);
        medianDPSes.push(boss.medianDPS);
      }
    }

    averages[bossName] = {
      medianParse: Math.round(median(medianParses) * 10) / 10,
      medianDPS: Math.round(median(medianDPSes)),
    };
  }

  return averages;
}
