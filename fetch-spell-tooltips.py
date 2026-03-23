#!/usr/bin/env python3
"""
Fetch spell tooltip descriptions from Wowhead and cache them locally.

Usage:
    python3 fetch-spell-tooltips.py                  # Fetch missing spells, update cache
    python3 fetch-spell-tooltips.py --force           # Re-fetch all spells
    python3 fetch-spell-tooltips.py --audit           # Regenerate audit log from cache

Reads spell IDs from bigwigs_colors.lua, fetches tooltips from
nether.wowhead.com/tooltip/spell/{id}, caches in spell_tooltips.json.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
from html.parser import HTMLParser
from pathlib import Path


class HTMLStripper(HTMLParser):
    """Strip HTML tags, keep text content."""
    def __init__(self):
        super().__init__()
        self.parts = []

    def handle_data(self, data):
        self.parts.append(data)

    def get_text(self):
        return ''.join(self.parts).strip()


def strip_html(html):
    """Remove HTML tags from a string."""
    s = HTMLStripper()
    s.feed(html)
    return s.get_text()


def extract_description(tooltip_html):
    """Extract just the description text from a wowhead tooltip HTML.

    Wowhead tooltips have two <table> blocks:
      1. Header: spell name, range, cast time
      2. Body: actual description (inside <div class="q">)
    We want only the body text.
    """
    # Find the description div (class="q" contains the actual description)
    m = re.search(r'<div class="q">(.*?)</div>', tooltip_html, re.DOTALL)
    if m:
        desc_html = m.group(1)
        # Replace <br /> with spaces
        desc_html = re.sub(r'<br\s*/?>', ' ', desc_html)
        return strip_html(desc_html).strip()
    # Fallback: strip everything
    return strip_html(tooltip_html)


def parse_mapping(path):
    """Parse bigwigs_colors.lua. Returns dict of boss -> {spell_id: category}."""
    mapping = {}
    current_boss = None
    with open(path) as f:
        for line in f:
            stripped = line.split("--")[0].strip()
            m = re.match(r'\["(.+?)"\]\s*=\s*\{', stripped)
            if m:
                current_boss = m.group(1)
                mapping[current_boss] = {}
                continue
            m = re.match(r'\[(-?\d+)\]\s*=\s*"(\w+)"', stripped)
            if m and current_boss:
                mapping[current_boss][int(m.group(1))] = m.group(2)
                continue
            if stripped.startswith("},"):
                current_boss = None
    return mapping


def parse_comments(path):
    """Parse bigwigs_colors.lua comments for each spell. Returns {spell_id: comment}."""
    comments = {}
    with open(path) as f:
        for line in f:
            # Match: [spellID] = "category",  -- comment text
            m = re.match(r'\s*\[(-?\d+)\]\s*=\s*"(\w+)",\s*--\s*(.+)', line)
            if m:
                spell_id = int(m.group(1))
                comments[spell_id] = m.group(3).strip()
    return comments


def load_cache(path):
    """Load spell tooltip cache from JSON file."""
    if path.exists():
        with open(path) as f:
            return json.load(f)
    return {}


def save_cache(path, cache):
    """Save spell tooltip cache to JSON file."""
    with open(path, 'w') as f:
        json.dump(cache, f, indent=2, sort_keys=True)


def fetch_tooltip(spell_id):
    """Fetch a single spell tooltip from Wowhead. Returns dict or None."""
    url = f"https://nether.wowhead.com/tooltip/spell/{spell_id}"
    try:
        req = urllib.request.Request(url, headers={
            'User-Agent': 'Mozilla/5.0 (wow-addons spell tooltip fetcher)',
            'Accept': 'application/json',
        })
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            tooltip_html = data.get('tooltip', '')
            return {
                'name': data.get('name', ''),
                'icon': data.get('icon', ''),
                'tooltip_html': tooltip_html,
                'description': extract_description(tooltip_html),
            }
    except urllib.error.HTTPError as e:
        print(f"  HTTP {e.code} for spell {spell_id}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"  Error fetching spell {spell_id}: {e}", file=sys.stderr)
        return None


def fetch_all(mapping, cache, force=False):
    """Fetch tooltips for all spells in mapping. Updates cache in-place."""
    all_spells = set()
    for boss_spells in mapping.values():
        for spell_id in boss_spells:
            all_spells.add(spell_id)

    to_fetch = []
    for spell_id in sorted(all_spells):
        key = str(spell_id)
        if force or key not in cache:
            to_fetch.append(spell_id)

    if not to_fetch:
        print("All spells cached, nothing to fetch.", file=sys.stderr)
        return

    print(f"Fetching {len(to_fetch)} spell tooltips from Wowhead...", file=sys.stderr)
    for i, spell_id in enumerate(to_fetch):
        print(f"  [{i+1}/{len(to_fetch)}] Spell {spell_id}...", file=sys.stderr)
        result = fetch_tooltip(spell_id)
        if result:
            cache[str(spell_id)] = result
        # Be nice to wowhead
        if i < len(to_fetch) - 1:
            time.sleep(0.3)

    print(f"Done. Cache now has {len(cache)} spells.", file=sys.stderr)


def generate_audit(mapping, cache, comments, mapping_path):
    """Generate BIGWIGS_COLOR_AUDIT.md from mapping + cache."""
    lines = []
    lines.append("# BigWigs Color Assignment Audit Log")
    lines.append("")
    lines.append("Source of truth for all color override decisions. Generated from `bigwigs_colors.lua` + `spell_tooltips.json`.")
    lines.append("")
    lines.append("Regenerate: `python3 fetch-spell-tooltips.py --audit`")
    lines.append("")
    lines.append("---")

    # Group bosses by section (read from the lua file to preserve order and section comments)
    sections = []
    current_section = None
    current_bosses = []

    with open(mapping_path) as f:
        for line in f:
            # Section headers: ---- comments
            if line.strip().startswith("--") and "----" in line:
                continue
            m = re.match(r'\s*--\s*(.+)', line)
            if m and not re.match(r'\s*--\s*(Stage|Commander|General|War Chaplain|Intermission|Mythic)', line):
                text = m.group(1).strip()
                # Section headers like "The Voidspire", "M+ Season 1 Dungeons"
                if any(keyword in text for keyword in ['Voidspire', 'Dreamrift', 'M+ Season', 'Magister', 'Maisara',
                                                        'Nexus', 'Windrunner', 'Algeth', 'Skyreach', 'Pit of Saron',
                                                        'Dragonflight', 'Warlords', 'Wrath', 'March']):
                    if current_section and current_bosses:
                        sections.append((current_section, current_bosses))
                    current_section = text
                    current_bosses = []

    # Simpler approach: iterate mapping in order, group by boss
    # Use the lua file order
    boss_order = []
    with open(mapping_path) as f:
        for line in f:
            m = re.match(r'\s*\["(.+?)"\]\s*=\s*\{', line)
            if m:
                boss_name = m.group(1)
                if boss_name in mapping:
                    boss_order.append(boss_name)

    # Read section markers from lua file
    section_for_boss = {}
    current_section = ""
    with open(mapping_path) as f:
        for line in f:
            # Look for section comment lines (lines that are ONLY comments, not inline)
            stripped = line.strip()
            if stripped.startswith("--") and not stripped.startswith("---"):
                text = stripped.lstrip("- ").strip()
                if text and not any(c.isdigit() for c in text[:1]):
                    current_section = text
            m = re.match(r'\s*\["(.+?)"\]\s*=\s*\{', stripped)
            if m:
                section_for_boss[m.group(1)] = current_section

    # Build output
    last_section = ""
    for boss_key in boss_order:
        section = section_for_boss.get(boss_key, "")
        if section != last_section:
            lines.append("")
            lines.append(f"## {section}")
            last_section = section

        # Extract boss display name from key
        display_name = boss_key.replace("BigWigs_Bosses_", "")
        lines.append("")
        lines.append(f"### {display_name}")
        lines.append("")
        lines.append("| Spell | Ability | Color | BW Label | Wowhead Description | Reasoning |")
        lines.append("|-------|---------|-------|----------|---------------------|-----------|")

        # Get spells in order from lua file
        spell_order = []
        with open(mapping_path) as f:
            in_boss = False
            for fline in f:
                if f'["{boss_key}"]' in fline:
                    in_boss = True
                    continue
                if in_boss:
                    if fline.strip().startswith("},"):
                        break
                    sm = re.match(r'\s*\[(-?\d+)\]\s*=', fline)
                    if sm:
                        spell_order.append(int(sm.group(1)))

        for spell_id in spell_order:
            category = mapping[boss_key].get(spell_id, "?")
            tooltip = cache.get(str(spell_id), {})
            spell_name = tooltip.get('name', f'Spell {spell_id}')
            description = tooltip.get('description', '')

            desc_text = description

            # Truncate long descriptions for table readability
            if len(desc_text) > 250:
                desc_text = desc_text[:247] + "..."

            # Escape pipe chars for markdown table
            desc_text = desc_text.replace('|', '\\|')

            # Parse comment format: "Spell Name: evidence; reasoning"
            comment = comments.get(spell_id, '')
            reasoning = ''
            bw_label = ''
            if ':' in comment:
                after_name = comment.split(':', 1)[1].strip()
                # Evidence is before semicolon, reasoning after
                if ';' in after_name:
                    evidence, reasoning = after_name.split(';', 1)
                    reasoning = reasoning.strip()
                else:
                    evidence = after_name
                    reasoning = after_name

                # Extract BW label from evidence: look for CL.xxx or quoted "Label"
                cl_match = re.search(r'CL\.(\w+)', evidence)
                quoted_match = re.search(r'"([^"]+)"', evidence)
                if cl_match:
                    # Map CL constant to display string
                    cl_labels = {
                        'breath': 'Breath', 'adds': 'Adds', 'soak': 'Soak',
                        'dodge': 'Dodge', 'knockback': 'Knockback', 'raid_damage': 'Raid Damage',
                        'roar': 'Roar', 'orbs': 'Orbs', 'full_energy': 'Full Energy',
                        'spikes': 'Spikes', 'pools': 'Pools', 'marks': 'Marks',
                        'shield': 'Shield', 'heal_absorbs': 'Heal Absorbs',
                        'frontal_cone': 'Frontal Cone',
                    }
                    bw_label = cl_labels.get(cl_match.group(1), cl_match.group(1))
                elif quoted_match:
                    bw_label = quoted_match.group(1)
            else:
                reasoning = comment

            wh_link = f"[{spell_name}](https://www.wowhead.com/spell={spell_id})"

            lines.append(f"| {spell_id} | {wh_link} | {category} | {bw_label} | {desc_text} | {reasoning} |")

    lines.append("")
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description="Fetch WoW spell tooltips and manage audit log")
    parser.add_argument("--force", action="store_true",
                        help="Re-fetch all spells even if cached")
    parser.add_argument("--audit", action="store_true",
                        help="Regenerate audit log from cache (no fetching)")
    parser.add_argument("--mapping", default=None,
                        help="Path to bigwigs_colors.lua")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    mapping_path = Path(args.mapping) if args.mapping else script_dir / "bigwigs_colors.lua"
    cache_path = script_dir / "spell_tooltips.json"
    audit_path = script_dir / "BIGWIGS_COLOR_AUDIT.md"

    if not mapping_path.exists():
        print(f"Error: {mapping_path} not found", file=sys.stderr)
        sys.exit(1)

    mapping = parse_mapping(mapping_path)
    comments = parse_comments(mapping_path)
    cache = load_cache(cache_path)

    if not args.audit:
        fetch_all(mapping, cache, force=args.force)
        save_cache(cache_path, cache)
        print(f"Cache saved to {cache_path}", file=sys.stderr)

    # Always regenerate audit after fetching
    total = sum(len(s) for s in mapping.values())
    cached = sum(1 for boss in mapping.values() for sid in boss if str(sid) in cache)
    print(f"Generating audit: {cached}/{total} spells have cached tooltips", file=sys.stderr)

    audit_content = generate_audit(mapping, cache, comments, mapping_path)
    audit_path.write_text(audit_content)
    print(f"Audit log written to {audit_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
