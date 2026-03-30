// --- Config ---

export interface Config {
  guild: string;
  realm: string;
  region: "us" | "eu" | "kr" | "tw";
  ranks: number[]; // guild rank IDs to include (0 = GM, 1-9 = custom ranks)
  difficulty: "Normal" | "Heroic" | "Mythic";
  blizzard: {
    clientId: string;
    clientSecret: string;
  };
  wcl: {
    clientId: string;
    clientSecret: string;
  };
  output: {
    wtfPath: string; // e.g. "H:\\World of Warcraft\\_retail_\\WTF"
    accountName: string; // e.g. "ACCOUNTNAME"
  };
  /** Max recent parses to store per player per boss (default: 10) */
  maxRecentParses?: number;
}

// --- Blizzard API ---

export interface GuildMember {
  name: string;
  realm: string;
  rank: number;
  level: number;
  class: string;
  classId: number;
}

// --- WCL API ---

export interface WclParse {
  encounterName: string;
  encounterId: number;
  difficulty: number;
  percentile: number;
  dps: number;
  ilvl: number;
  spec: string;
  startTime: number; // unix ms
  duration: number; // ms
  reportCode: string;
  fightId: number;
}

// --- Computed Output ---

export interface RecentParse {
  date: number; // unix seconds
  dps: number;
  parse: number; // percentile
  ilvl: number;
  spec: string;
}

export interface BossPerformance {
  kills: number;
  medianParse: number;
  bestParse: number;
  medianDPS: number;
  bestDPS: number;
  trend: number; // positive = improving
  consistency: number; // std dev of parse %
  recentParses: RecentParse[];
}

export interface PlayerOverall {
  medianParse: number;
  trend: number;
  consistency: number;
}

export interface PlayerData {
  class: string;
  spec: string;
  ilvl: number;
  bosses: Record<string, BossPerformance>;
  overall: PlayerOverall;
}

export interface RaidAverage {
  medianParse: number;
  medianDPS: number;
}

export interface RaidPerformanceData {
  generatedAt: number; // unix seconds
  tier: string;
  difficulty: string;
  guild: string;
  realm: string;
  players: Record<string, PlayerData>;
  raidAverages: Record<string, RaidAverage>;
}
