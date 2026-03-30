import type { Config, GuildMember } from "./types.js";

// Blizzard class IDs → class names
const CLASS_NAMES: Record<number, string> = {
  1: "WARRIOR",
  2: "PALADIN",
  3: "HUNTER",
  4: "ROGUE",
  5: "PRIEST",
  6: "DEATHKNIGHT",
  7: "SHAMAN",
  8: "MAGE",
  9: "WARLOCK",
  10: "MONK",
  11: "DRUID",
  12: "DEMONHUNTER",
  13: "EVOKER",
};

interface BlizzardToken {
  access_token: string;
  expires_at: number;
}

let cachedToken: BlizzardToken | null = null;

async function getAccessToken(config: Config): Promise<string> {
  if (cachedToken && Date.now() < cachedToken.expires_at - 60_000) {
    return cachedToken.access_token;
  }

  const { clientId, clientSecret } = config.blizzard;
  const tokenUrl = `https://${config.region}.battle.net/oauth/token`;

  const res = await fetch(tokenUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Authorization:
        "Basic " + Buffer.from(`${clientId}:${clientSecret}`).toString("base64"),
    },
    body: "grant_type=client_credentials",
  });

  if (!res.ok) {
    throw new Error(`Blizzard auth failed: ${res.status} ${await res.text()}`);
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

export async function fetchGuildRoster(
  config: Config
): Promise<GuildMember[]> {
  const token = await getAccessToken(config);

  // Blizzard API expects lowercase, hyphenated slug
  const realmSlug = config.realm.toLowerCase().replace(/\s+/g, "-");
  const guildSlug = config.guild.toLowerCase().replace(/\s+/g, "-");

  const url =
    `https://${config.region}.api.blizzard.com/data/wow/guild` +
    `/${realmSlug}/${guildSlug}/roster` +
    `?namespace=profile-${config.region}&locale=en_US`;

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!res.ok) {
    throw new Error(
      `Failed to fetch guild roster: ${res.status} ${await res.text()}`
    );
  }

  const data = (await res.json()) as {
    members: Array<{
      character: {
        name: string;
        realm: { slug: string; name: string };
        level: number;
        playable_class: { id: number };
      };
      rank: number;
    }>;
  };

  return data.members.map((m) => ({
    name: m.character.name,
    realm: m.character.realm.name,
    rank: m.rank,
    level: m.character.level,
    classId: m.character.playable_class.id,
    class: CLASS_NAMES[m.character.playable_class.id] ?? "UNKNOWN",
  }));
}

export function filterByRank(
  members: GuildMember[],
  ranks: number[]
): GuildMember[] {
  const rankSet = new Set(ranks);
  return members
    .filter((m) => rankSet.has(m.rank))
    .filter((m) => m.level >= 80); // only max-level characters
}
