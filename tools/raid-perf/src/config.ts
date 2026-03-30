import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import type { Config } from "./types.js";

const CONFIG_FILENAME = ".raidperfrc.json";

export async function loadConfig(dir?: string): Promise<Config> {
  const searchDir = dir ?? process.cwd();
  const configPath = resolve(searchDir, CONFIG_FILENAME);

  let raw: string;
  try {
    raw = await readFile(configPath, "utf-8");
  } catch {
    throw new Error(
      `Config not found: ${configPath}\n` +
        `Create a ${CONFIG_FILENAME} file. See README for format.`
    );
  }

  const config: Config = JSON.parse(raw);

  // Validate required fields
  const required: (keyof Config)[] = [
    "guild",
    "realm",
    "region",
    "ranks",
    "difficulty",
    "blizzard",
    "wcl",
    "output",
  ];
  for (const key of required) {
    if (config[key] === undefined) {
      throw new Error(`Config missing required field: ${key}`);
    }
  }
  if (!config.blizzard.clientId || !config.blizzard.clientSecret) {
    throw new Error("Config missing blizzard.clientId or blizzard.clientSecret");
  }
  if (!config.wcl.clientId || !config.wcl.clientSecret) {
    throw new Error("Config missing wcl.clientId or wcl.clientSecret");
  }
  if (!config.output.wtfPath || !config.output.accountName) {
    throw new Error("Config missing output.wtfPath or output.accountName");
  }

  return config;
}
