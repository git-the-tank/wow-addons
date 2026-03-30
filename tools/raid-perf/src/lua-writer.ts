import { writeFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import type { Config, RaidPerformanceData } from "./types.js";

/**
 * Serialize a JS value to Lua table syntax.
 */
function toLua(value: unknown, indent: number = 0): string {
  const pad = "\t".repeat(indent);
  const padInner = "\t".repeat(indent + 1);

  if (value === null || value === undefined) {
    return "nil";
  }
  if (typeof value === "boolean") {
    return value ? "true" : "false";
  }
  if (typeof value === "number") {
    return String(value);
  }
  if (typeof value === "string") {
    // Escape backslashes, quotes, and newlines
    const escaped = value
      .replace(/\\/g, "\\\\")
      .replace(/"/g, '\\"')
      .replace(/\n/g, "\\n");
    return `"${escaped}"`;
  }
  if (Array.isArray(value)) {
    if (value.length === 0) return "{}";
    const items = value.map((v) => `${padInner}${toLua(v, indent + 1)},`);
    return `{\n${items.join("\n")}\n${pad}}`;
  }
  if (typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length === 0) return "{}";

    const items = entries.map(([k, v]) => {
      // Use ["key"] syntax for keys with special characters, otherwise bare identifiers
      const keyStr = /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(k)
        ? k
        : `["${k.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"]`;
      return `${padInner}${keyStr} = ${toLua(v, indent + 1)},`;
    });
    return `{\n${items.join("\n")}\n${pad}}`;
  }
  return "nil";
}

export function serializeToLua(data: RaidPerformanceData): string {
  return `RaidPerformanceData = ${toLua(data, 0)}\n`;
}

export async function writeSavedVariables(
  config: Config,
  data: RaidPerformanceData
): Promise<string> {
  const svDir = join(
    config.output.wtfPath,
    "Account",
    config.output.accountName,
    "SavedVariables"
  );

  await mkdir(svDir, { recursive: true });

  const filePath = join(svDir, "RaidPerformance.lua");
  const content = serializeToLua(data);

  await writeFile(filePath, content, "utf-8");
  return filePath;
}
