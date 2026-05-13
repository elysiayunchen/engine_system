<div align="center">

```
╔═══════════════════════════════════════════════╗
║           ENGINE SYSTEM                       ║
║   Persistent AI memory for vibe coding        ║
╚═══════════════════════════════════════════════╝
```

**Your AI forgets everything the moment you close the tab.**  
**Engine System doesn't let it.**

[English](./README.md) · [中文](./README.zh.md)

</div>

---

## The problem nobody talks about

You've probably felt this. You open a new Claude Code session and spend the first fifteen minutes doing this:

> *"So my project is a Next.js app with a Postgres backend — wait, don't use Prisma, I switched to Drizzle last month. The auth is in `src/features/auth/`, not `src/lib/`. And whatever you do, don't touch the migration files directly, I learned that the hard way..."*

Then two hours later you're explaining it again in a new tab.

**The AI isn't the problem. The missing memory layer is.**

Every session, you pay the same onboarding tax. You're the only one who holds the full picture — the architectural decisions, the landmines, the half-finished refactor, the library that looked great but silently broke everything. That knowledge lives in your head, not your project. And every time you start fresh, a piece of it gets lost or miscommunicated.

The result:

- AI confidently refactors something you already tried and abandoned
- AI uses the library you blacklisted because of an obscure production bug
- AI breaks a constraint you forgot to mention this session
- You spend 20% of your time re-briefing instead of building
- The project gets *harder* to work on as it grows, not easier

---

## What Engine System does

Engine System gives your project a structured memory layer: **eight markdown files** in `engine/` that tell any AI everything it needs to know before touching a single line of code.

Run `/engine-init` in Claude Code once. Claude interviews you for ~10 minutes, then writes the files directly to your project. Every session after that, they're loaded automatically. No briefing, no re-explaining, no context drift.

```
Without Engine System              With Engine System
──────────────────────             ─────────────────────────────
Open Claude Code                   Open Claude Code
↓                                  ↓
Re-brief for 15 min                Claude reads engine files (5 sec)
↓                                  ↓
Start building                     Start building
↓                                  ↓
AI breaks something                AI already knew not to touch it
you forgot to mention              ↓
↓                                  Ship
Undo, explain again, retry
↓
Eventually ship
```

---

## The eight engine files

| File | What it holds |
|------|---------------|
| `CONTEXT.md` | What's broken right now, what's in progress, what's blocking you |
| `SYSTEM.md` | Your rules — what the AI must, should, and must never do in your project |
| `PITFALLS.md` | The landmine registry. Every bug hit, every footgun, every "never do this" |
| `ARCHITECTURE.md` | Tech stack, directory map, data model, key decisions and their trade-offs |
| `SPRINT.md` | Active tasks and priorities in plain language |
| `ROADMAP.md` | Milestones, planned features, what might need a full rewrite later |
| `HANDOFF.md` | Session history — pick up exactly where you left off, weeks later |
| `SOURCEMAP.md` | Code GPS: which file owns which feature, where to add new things |

They're plain markdown. Commit them. Read them yourself.  
They're also the best project documentation you'll ever accidentally write.

---

## Real numbers

| | Without | With |
|--|---------|------|
| Session startup (re-briefing) | 10–20 min | ~30 sec |
| "Undo that, I told you not to" moments | Multiple per session | Near zero |
| Resume after a week away | 30+ min to reorient | < 5 min |
| Onboarding a second AI agent | Start from scratch | Instant |
| Project knowledge when you stop | Gone | Preserved |

---

## Install

**macOS / Linux**
```bash
bash <(curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/engine-system/main/install.sh)
```

**Windows (PowerShell)**
```powershell
irm https://raw.githubusercontent.com/YOUR_USERNAME/engine-system/main/install.ps1 | iex
```

**Via degit** (no git history baggage)
```bash
npx degit YOUR_USERNAME/engine-system/plugin
```

Adds to your project root — **nothing else is touched:**
```
your-project/
├── engine/                 ← engine files live here (empty until /engine-init)
├── .claude/
│   └── commands/           ← becomes slash commands in Claude Code
│       ├── engine-init.md      →  /engine-init
│       ├── engine-update.md    →  /engine-update
│       ├── add-pitfall.md      →  /add-pitfall
│       └── engine-status.md    →  /engine-status
└── CLAUDE.md               ← auto-loaded by Claude Code every session
```

No npm package. No runtime dependency. No config file. Just files.

---

## First session

```
/engine-init
```

Claude interviews you: project vision, tech stack, current state, known pitfalls, how you like to collaborate. About 10 minutes. All eight engine files are written directly to `engine/`. Open your editor — they're there.

**No Claude Code?** Copy `.claude/commands/engine-init.md` into any Claude session. Save the output manually to `engine/`. Everything else works the same.

---

## Every session after

**Start:** Claude Code reads `CLAUDE.md` automatically. Context loaded, zero effort.

**End of session:**
```
/engine-update
```
Three questions. State synced. Handoff written. Thirty seconds.

**When you hit something weird:**
```
/add-pitfall
```
Record it immediately, before you close the window. It lives in `PITFALLS.md` permanently — every future AI session will know about it.

**Quick check:**
```
/engine-status
```
Current state, open tasks, unresolved pitfalls. One snapshot.

---

## Keeping the plugin current

```bash
bash <(curl -sSL .../install.sh) --update
```

Updates the command files to the latest version. Your `engine/*.md` files are never touched.

---

## Philosophy

Engine System doesn't fight the context window — it works around it.

The core insight: **the AI doesn't need to remember; the project does.** Engine files are the project's memory, not the AI's. They survive tab closes, model upgrades, long weekends, and new teammates — human or AI.

The files are designed to be read cold: dense with facts, sparse with filler, structured for immediate orientation. But they're also readable by humans. If you've ever returned to a project after two months and felt completely lost, you'll recognize what these files are doing.

---

## License

MIT
