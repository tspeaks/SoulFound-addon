# SoulFound

A World of Warcraft: Forever add-on that helps you level the character you actually want to play, however off-meta.

## What it does

- Talent reminders when you get a point, following your plan.
- Quest reward picks at turn-in, ranked for your build.
- Tooltip scores on items, compared with what you're wearing.
- Profession tips: what to craft next and when to train.

It reads your own character through the normal add-on API. Plans come in as plain text strings you paste in. The plan format is open and documented in `docs/plan-format.md`, so anyone can write one.

## Advice only

SoulFound never plays for you. No automation, no input, no reading the screen or memory, no chat or add-on messages. Data only moves when you copy and paste it.

## Free

The add-on is free, with every feature, for everyone. No unlock codes, no ads.

## Install

Copy the `addon/SoulFound` folder into `World of Warcraft/<game folder>/Interface/AddOns/`, then make sure SoulFound is checked in the AddOns list at character select.

Commands: `/sf`, `/sf export`, `/sf import`, `/sf show`, `/sf talent`, `/sf prof`, `/sf check`, `/sf trace on|off|clear`.

## Tests

Needs Lua 5.1 (`lua5.1` and `luac5.1` on your PATH). From the repo root:

```
./tests/run.sh
```

This runs a lint check, unit tests, and integration tests against a fake WoW interface.

## License

MIT. See `LICENSE`.
