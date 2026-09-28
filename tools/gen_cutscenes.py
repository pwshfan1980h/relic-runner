#!/usr/bin/env python3
"""Writes Relic Runner's chapter-intro cutscenes with Claude Sonnet 5.5.

Run from the project root:  python3 tools/gen_cutscenes.py [chapter ...]
Needs:  pip install anthropic   and credentials (ANTHROPIC_API_KEY, or `ant auth login`).

Each cutscene is a JSON script (tools/cutscene_schema.json) that the game stages in its own
engine (scripts/ui/cutscene.gd), with the game's sky, rigs, animations, fonts, dialogue box
and music, so the result always matches the game. Sonnet writes the direction and the
jokes; the schema (enforced by structured outputs) and the checks below keep it inside what
the engine can actually stage. Output: assets/cutscenes/<chapter>.json
"""
import json
import os
import re
import sys

import anthropic

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "cutscenes")
MODEL = "claude-sonnet-5-5"
SCHEMA = json.load(open(os.path.join(ROOT, "tools", "cutscene_schema.json")))

CLIPS = ["idle", "idle_hat", "walk", "run", "jump", "crouch", "hurt", "punch_a", "front_kick", "reload", "whip_pull",
         "throw", "skid", "roll", "land", "fall", "hang", "tread"]
SOUNDS = ["whip_crack", "gunshot", "rifle", "explosion", "splash", "jaguar_growl", "snake_hiss", "stone_grind", "slam",
          "intro_boom", "coin_pickup", "item_pickup", "checkpoint", "gate_rumble", "grenade_pin", "hit_wood", "land"]

SYSTEM = """You direct the chapter-intro cutscenes for RELIC RUNNER, a 1990s-style cinematic platformer (Another World,
Flashback, Prince of Persia) set in 1936: a pulp adventure with warm, dry humour. You write a JSON script that the game
stages in its own engine, so you are limited to what the engine can show. Write like a good Saturday-matinee serial:
clear staging, a laugh or two, and a hook into the chapter.

THE STAGE
- 480x270 pixel screen, letterboxed. Characters stand on the ground line; x runs 0 (left) to 480 (right). Keep everyone
  between x=40 and x=440 and at least 40px apart. Characters are about 64px tall at cutscene scale.
- A shot = one setting under a live sky at `hour` (0-24; 18-19 is sunset, 20+ night, 5.5-7 dawn). The biome sets the
  backdrop (canyon: red mesas; jungle: canopy and ruins).
- Settings: desert_road, mesa_foot, mesa_top, mine_mouth, mine_tunnel, campfire, jungle_river, temple_steps,
  temple_hall. Props (simple silhouettes): campfire, mules, signpost, lanterns, tents, crates, ruins, idol, boat,
  dead_tree, watchtower, mine_cart.
- Actors: the cast ids, plus "bandit"/"bandit2" (Crane's rifle-men) and "brute" (a huge bandit in a bandana). Each
  actor appears in a shot's `actors` list before any step uses it. Starting clip: idle, idle_hat, crouch, hang, fall or tread.

STEPS (every field is always present; unused ones are "" or 0)
- wait: pause `seconds`.
- say: `actor` speaks `text` in the dialogue box (the player reads at their pace). One or two sentences, under 140
  characters. actor "" is narration. A named cast member may speak from offscreen (a voice from the dark).
- caption: subtitle `text` for `seconds` (scene-setting, sound cues like "(distant rifle fire)").
- walk / run: `actor` moves to `x`.
- face: `actor` turns toward `x`.
- anim: `actor` plays clip `text` for `seconds`. Clips: %s.
- sfx: play sound `text`. Sounds: %s.
- shake: screen shake, strength `seconds` (0.2-1.0).
- pan: camera drifts to offset `x` (-200..200) over `seconds`.

RULES
- 2 or 3 shots, 5-14 steps each. The whole cutscene should run 40-90 seconds.
- Stay true to the story bible and the chapter beats you're given: never contradict them, never invent new major plot
  facts, never kill or permanently change a named character. Set up the chapter; don't play its ending.
- Keep characters in voice (see the cast). Humour comes from character, not from breaking the fourth wall.
- Rook's pronouns are never used; Rook is always "Rook" or "Calloway".
""" % (", ".join(CLIPS), ", ".join(SOUNDS))


def chapter_brief(chapter):
    """The chapter's card, its conversations and what came before, from the game's own data."""
    story_gd = open(os.path.join(ROOT, "scripts", "story", "story.gd")).read()
    story_md = open(os.path.join(ROOT, "docs", "STORY.md")).read()
    chapters = re.findall(r'\{"map": "(\w+)", "num": "([^"]+)", "title": "([^"]+)", "hour": ([\d.]+),\s*"card": "((?:[^"\\]|\\.)*)"\}',
                          story_gd)
    idx = [c[0] for c in chapters].index(chapter)
    m, num, title, hour, card = chapters[idx]
    prev = chapters[idx - 1] if idx > 0 else None
    return (f"STORY BIBLE\n{story_md}\n\n"
            f"WRITE THE INTRO FOR: {num} - {title} (map id {m}), which starts at hour {hour}.\n"
            f"The chapter card shown after your cutscene reads: {card}\n"
            + (f"The previous chapter was {prev[1]} - {prev[2]}; it ended at camp with Tomás (and Dolores the mule).\n"
               if prev else "This is the first chapter: the player has just watched the opening film (the letter, Crane, "
               "the Guardian's eyes). Rook arrives in the canyon country.\n")
            + "The game's dialogue for this chapter (for voice and facts; don't repeat these lines):\n"
            + story_gd[story_gd.index("const TALKS"):story_gd.index("## After the last chapter.")])


def check(data, chapter):
    """Game rules the schema can't express. Returns a list of problems."""
    problems = []
    if data.get("chapter") != chapter:
        problems.append(f'"chapter" must be "{chapter}"')
    if not 2 <= len(data.get("shots", [])) <= 3:
        problems.append("use 2 or 3 shots")
    for i, shot in enumerate(data.get("shots", [])):
        ids = {a["id"] for a in shot["actors"]}
        for a in shot["actors"]:
            if not 40 <= a["x"] <= 440:
                problems.append(f"shot {i}: actor {a['id']} x={a['x']} is off the stage (40-440)")
        if not 5 <= len(shot["steps"]) <= 14:
            problems.append(f"shot {i}: use 5-14 steps")
        for j, s in enumerate(shot["steps"]):
            act = s["action"]
            if act in ("walk", "run", "face", "anim") and s["actor"] not in ids:
                problems.append(f"shot {i} step {j}: actor '{s['actor']}' is not in this shot")
            cast = {"rook", "hattie", "tomas", "nico", "itzel", "ortiz", "crane"}
            if act == "say" and s["actor"] not in ids and s["actor"] not in cast and s["actor"] != "":
                problems.append(f"shot {i} step {j}: speaker '{s['actor']}' is not in this shot or the cast")
            if act == "say" and len(s["text"]) > 160:
                problems.append(f"shot {i} step {j}: line too long")
            if act == "anim" and s["text"] not in CLIPS:
                problems.append(f"shot {i} step {j}: unknown clip '{s['text']}'")
            if act == "sfx" and s["text"] not in SOUNDS:
                problems.append(f"shot {i} step {j}: unknown sound '{s['text']}'")
            if act in ("walk", "run") and not 40 <= s["x"] <= 440:
                problems.append(f"shot {i} step {j}: destination off the stage")
    return problems


def generate(client, chapter):
    messages = [{"role": "user", "content": chapter_brief(chapter)}]
    for attempt in range(3):
        response = client.beta.messages.create(
            model=MODEL,
            max_tokens=16000,
            system=SYSTEM,
            messages=messages,
            output_config={"effort": "medium", "format": {"type": "json_schema", "schema": SCHEMA}},
            # If a safety classifier declines, re-run on Anthropic's recommended fallback model.
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
        )
        if response.stop_reason == "refusal":
            print(f"  {chapter}: declined ({response.stop_details})")
            return None
        text = next(b.text for b in response.content if b.type == "text")
        data = json.loads(text)
        problems = check(data, chapter)
        if not problems:
            return data
        print(f"  {chapter}: attempt {attempt + 1} needs fixes: {problems[:4]}")
        messages += [{"role": "assistant", "content": response.content},
                     {"role": "user", "content": "Please fix these and return the whole script again:\n- "
                      + "\n- ".join(problems)}]
    return None


def main():
    chapters = sys.argv[1:] or SCHEMA["properties"]["chapter"]["enum"]
    os.makedirs(OUT, exist_ok=True)
    client = anthropic.Anthropic()
    for chapter in chapters:
        try:
            data = generate(client, chapter)
        except anthropic.RateLimitError:
            print(f"  {chapter}: rate limited; try again shortly")
            continue
        except anthropic.APIStatusError as e:
            print(f"  {chapter}: API error {e.status_code}: {e.message}")
            continue
        except anthropic.APIConnectionError:
            print(f"  {chapter}: couldn't reach the API")
            continue
        if data is None:
            continue
        data["_source"] = MODEL
        with open(os.path.join(OUT, chapter + ".json"), "w") as f:
            json.dump(data, f, indent=1, ensure_ascii=False)
        print("wrote", chapter)


if __name__ == "__main__":
    main()
