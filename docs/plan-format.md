# SoulFound String Format (v1)

Open and documented so anyone can write a SoulFound plan by hand or with
their own tools. The addon reads every valid plan the same way, wherever it
came from. Plans are data only: the addon never runs code from a plan.

## Envelope

```
<prefix><base64 of UTF-8 JSON>
```

| Prefix | Contents | Made by |
|---|---|---|
| `SF1E:` | character export | `/sf export` |
| `SF1P:` | plan | the planner, or anyone |
| `SF1R:` | reserved for reports | — |

Whitespace anywhere in the string is ignored, so line breaks from copy/paste
are harmless.

## Plan

```json
{
  "format": "soulfound-plan",
  "version": 1,
  "plan_id": "p1abc",
  "created": "2026-10-19",
  "title": "Tanky dodge/parry rogue",
  "goal": "A tanky solo rogue that dodges and parries everything.",
  "class": "ROGUE",
  "importance": { "agility": 10, "dodge": 10 },
  "stat_values": { "agility": 1, "dodge": 20 },
  "talent_order": ["Lightning Reflexes", "Lightning Reflexes", "Deflection"],
  "advice": ["Keep Evasion for pulls where a second mob joins."],
  "professions": { "primary": ["Leatherworking", "Skinning"], "secondary": ["First Aid"] }
}
```

| Field | Required | Meaning |
|---|---|---|
| `format`, `version` | yes | `"soulfound-plan"`, `1` |
| `class` | no | Class file name (`ROGUE`). If set, the addon refuses the plan on another class. |
| `stat_values` | for gear features | Value of **one point** of each stat. Item score = Σ stat amount × value. Percent stats (crit, hit, dodge, parry, block, spell crit, spell hit) count per 1%. |
| `talent_order` | for talent reminders | One talent name per point, in spending order. Names must match the character's live tree. Points already spent count toward the list, so an order can start from level 10 on any character. |
| `advice` | no | Short tips shown by `/sf show`. |
| `professions` | no | `primary`: up to two of Alchemy, Blacksmithing, Enchanting, Engineering, Herbalism, Leatherworking, Mining, Skinning, Tailoring. `secondary`: any of First Aid, Cooking, Fishing. The addon reminds the player to learn primaries they don't have yet. |
| `title`, `goal`, `importance`, `plan_id`, `created` | no | Shown or kept for re-editing; the addon doesn't depend on them. |

Stat keys: `agility strength stamina intellect spirit armor weapon_dps
attack_power ranged_attack_power crit hit dodge parry block defense
spell_power healing mp5 spell_crit spell_hit`.

## Export

`format: "soulfound-export"`, `version: 1`, plus:

- `client`: `version`, `build`, `interface`, `project`, `forever`
- `char`: `class`, `race`, `faction`, `level`, `xp`, `xp_max`, `money` (copper), `zone`, `pos` (`map`, `x`, `y` in map percent)
- `talents`: `available`, `unspent`, `tabs[]` → `name`, `spent`, `talents[]` → `name`, `tier`, `col`, `rank`, `max`, `index`, optional `prereq` `[tier, col]`
- `gear[]`: `slot`, `id`, `name`, `sub`, `loc`, `stats`
- `professions[]`: `name`, `rank`, `max`
- `quests`: `log[]` (`id`, `title`, `level`, `complete`), `completed[]` (quest IDs)
- `trace[]`, only if the player turned on `/sf trace`: `t` (unix time), `e` (`A` accepted, `T` turned in, `D` died, `L` level up), `q` quest ID, `l` level, `m`/`x`/`y` position

Lua writes empty lists as `[]`, but readers should accept `{}` for an empty
list too.
