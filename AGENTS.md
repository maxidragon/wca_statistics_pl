# AGENTS.md

Guidance for coding agents working in this repository. See `README.md` for setup.

## What this is

A Ruby tool that runs SQL queries against a local MySQL copy of the WCA database and renders
each result as a Markdown page. The pages are published to GitHub Pages from the `gh-pages` branch.
Every statistic is about Poland: Polish competitors (`persons.country_id = 'Poland'`,
`users.country_iso2 = 'PL'`) or competitions held in Poland (`competitions.country_id = 'Poland'`).

The project started as a copy of `jonatanklosko/wca_statistics` but is a separate repository now.
Do not open PRs against, or pull changes from, the original project.

## Layout

- `core/` — base classes and shared data.
  - `statistic.rb` — `Statistic`: implement `query`, optionally `transform`; renders one table.
  - `grouped_statistic.rb` — `GroupedStatistic`: `transform` returns `[header, rows]` groups
    (optionally `[header, rows, table_header, description]`), one table per group.
  - `categories.rb` — the index sections. Every statistic sets `@category` to one of these keys.
  - `events.rb`, `solve_time.rb`, `voivodeships.rb` — helpers for events, result formatting and Polish regions.
- `statistics/` — one file per statistic. The file name is the statistic id and the page URL;
  the class name must be its CamelCase form (`statistics/index.rb` loads them by that rule).
- `statistics/abstract/` — parameterised base classes reused by thin subclasses
  (e.g. `average_of_5.rb` subclasses `AverageOfX`). Files here are not pages themselves.
- `bin/` — scripts (`compute.rb`, `compute_all.rb`, `compute_index.rb`, `new_statistic.rb`, …)
  and `bin/templates/`.
- `build/` — generated Markdown output, git-ignored.

## Adding or changing a statistic

1. `bin/new_statistic.rb some_name` (append `--grouped` for a grouped statistic) and fill in the template.
2. Set `@title`, `@category`, `@table_header` (column name → `:left` / `:center` / `:right`) and,
   where it helps, `@note`.
3. Link people as `[Name](https://www.worldcubeassociation.org/persons/WCA_ID)` and competitions
   as `[Name](https://www.worldcubeassociation.org/competitions/ID)`, built in SQL or in `transform`.
4. When querying `competitions` directly (not through `results`), filter out unannounced,
   cancelled and future competitions: `show_at_all = 1`, `cancelled_at IS NULL`, `start_date < CURDATE()`.
5. Run `bin/compute.rb statistics/some_name.rb` and check `build/some_name.md`, then
   `bin/compute_index.rb` — it aborts if any statistic has a missing or unknown category.

Computing needs a local MySQL with the WCA data (`bin/init.rb`, then `bin/update_database.rb`).
There is no test suite; running the statistic against real data is the check.

## CI

`.github/workflows/build.yml` runs `bin/ci.sh`:

- push to `master` — computes only the statistic files changed in the push,
- daily cron and manual dispatch — recomputes everything,
- then regenerates the index and deploys `build/` to `gh-pages` (runs are queued, never cancelled).

A change in `core/` or `statistics/abstract/` alone does not recompute dependent statistics on push;
they refresh on the next daily run, or trigger the workflow manually.

## Conventions

- Commits follow Conventional Commits, e.g. `feat: add most solves per year`,
  `fix: remove kls from most attended comps in series`.
- Never commit `database.yml` or anything from `build/`.
