import type { Config, WclParse } from "./types.js";

const WCL_TOKEN_URL = "https://www.warcraftlogs.com/oauth/token";
const WCL_API_URL = "https://www.warcraftlogs.com/api/v2/client";

// WCL difficulty IDs
const DIFFICULTY_MAP: Record<string, number> = {
  Normal: 3,
  Heroic: 4,
  Mythic: 5,
};

interface WclToken {
  access_token: string;
  expires_at: number;
}

let cachedToken: WclToken | null = null;

async function getAccessToken(config: Config): Promise<string> {
  if (cachedToken && Date.now() < cachedToken.expires_at - 60_000) {
    return cachedToken.access_token;
  }

  const { clientId, clientSecret } = config.wcl;
  const res = await fetch(WCL_TOKEN_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Authorization:
        "Basic " + Buffer.from(`${clientId}:${clientSecret}`).toString("base64"),
    },
    body: "grant_type=client_credentials",
  });

  if (!res.ok) {
    throw new Error(`WCL auth failed: ${res.status} ${await res.text()}`);
  }

  const data = (await res.json()) as {
    access_token: string;
    expires_in: number;
  };
  cachedToken = {
    access_token: data.access_token,
    expires_at: Date.now() + data.expires_in * 1000,
  };
  return cachedToken.access_token;
}

async function graphql<T>(config: Config, query: string, variables: Record<string, unknown>): Promise<T> {
  const token = await getAccessToken(config);

  const res = await fetch(WCL_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ query, variables }),
  });

  if (!res.ok) {
    throw new Error(`WCL API error: ${res.status} ${await res.text()}`);
  }

  const json = (await res.json()) as { data?: T; errors?: Array<{ message: string }> };
  if (json.errors?.length) {
    throw new Error(`WCL GraphQL errors: ${json.errors.map((e) => e.message).join(", ")}`);
  }
  if (!json.data) {
    throw new Error("WCL returned no data");
  }
  return json.data;
}

// Get the current zone (raid tier) info
const ZONE_QUERY = `
  query {
    worldData {
      expansions {
        id
        name
        zones {
          id
          name
          encounters {
            id
            name
          }
        }
      }
    }
  }
`;

export interface ZoneInfo {
  id: number;
  name: string;
  encounters: Array<{ id: number; name: string }>;
}

export async function fetchCurrentZone(config: Config, zoneName?: string): Promise<ZoneInfo> {
  interface ExpansionData {
    worldData: {
      expansions: Array<{
        id: number;
        name: string;
        zones: Array<{
          id: number;
          name: string;
          encounters: Array<{ id: number; name: string }>;
        }>;
      }>;
    };
  }

  const data = await graphql<ExpansionData>(config, ZONE_QUERY, {});

  // Find the latest expansion's zones
  const expansions = data.worldData.expansions;
  const latest = expansions[expansions.length - 1];

  if (zoneName) {
    const zone = latest.zones.find(
      (z) => z.name.toLowerCase() === zoneName.toLowerCase()
    );
    if (zone) return zone;
    throw new Error(
      `Zone "${zoneName}" not found. Available: ${latest.zones.map((z) => z.name).join(", ")}`
    );
  }

  // Default to the last zone in the latest expansion (most recent raid)
  const zone = latest.zones[latest.zones.length - 1];
  if (!zone) {
    throw new Error("No zones found in latest expansion");
  }
  return zone;
}

// Get all parses for a character on a specific encounter
const CHARACTER_RANKINGS_QUERY = `
  query($name: String!, $serverSlug: String!, $serverRegion: String!, $encounterID: Int!, $difficulty: Int!) {
    characterData {
      character(name: $name, serverSlug: $serverSlug, serverRegion: $serverRegion) {
        encounterRankings(
          encounterID: $encounterID,
          difficulty: $difficulty,
          metric: dps
        )
      }
    }
  }
`;

interface RankingsResponse {
  characterData: {
    character: {
      encounterRankings: {
        totalKills: number;
        ranks: Array<{
          lockedIn: boolean;
          rankPercent: number;
          amount: number;
          report: { code: string; fightID: number; startTime: number };
          startTime: number;
          duration: number;
          bracketData: number; // ilvl
          spec: string;
        }>;
        difficulty: number;
        metric: string;
        encounterID: number;
      } | null;
    } | null;
  };
}

export async function fetchCharacterParses(
  config: Config,
  characterName: string,
  serverSlug: string,
  encounterId: number,
  encounterName: string
): Promise<WclParse[]> {
  const difficulty = DIFFICULTY_MAP[config.difficulty] ?? 4;

  let data: RankingsResponse;
  try {
    data = await graphql<RankingsResponse>(config, CHARACTER_RANKINGS_QUERY, {
      name: characterName,
      serverSlug,
      serverRegion: config.region,
      encounterID: encounterId,
      difficulty,
    });
  } catch (err) {
    // Character may not exist on WCL
    return [];
  }

  const character = data.characterData?.character;
  if (!character?.encounterRankings?.ranks) {
    return [];
  }

  const rankings = character.encounterRankings;
  return rankings.ranks.map((r) => ({
    encounterName,
    encounterId,
    difficulty: rankings.difficulty,
    percentile: Math.round(r.rankPercent * 100) / 100,
    dps: Math.round(r.amount),
    ilvl: r.bracketData,
    spec: r.spec,
    startTime: r.startTime,
    duration: r.duration,
    reportCode: r.report.code,
    fightId: r.report.fightID,
  }));
}

/**
 * Fetch all parse data for a character across all encounters in a zone.
 * Rate-limits requests to avoid hammering the WCL API.
 */
export async function fetchAllParsesForCharacter(
  config: Config,
  characterName: string,
  serverSlug: string,
  zone: ZoneInfo
): Promise<WclParse[]> {
  const allParses: WclParse[] = [];

  for (const encounter of zone.encounters) {
    const parses = await fetchCharacterParses(
      config,
      characterName,
      serverSlug,
      encounter.id,
      encounter.name
    );
    allParses.push(...parses);

    // Small delay between requests to be respectful of rate limits
    if (zone.encounters.indexOf(encounter) < zone.encounters.length - 1) {
      await delay(200);
    }
  }

  return allParses;
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
