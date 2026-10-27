# WCA Statistics PL [![Build](https://github.com/maxidragon/wca_statistics_pl/actions/workflows/build.yml/badge.svg)](https://github.com/maxidragon/wca_statistics_pl/actions/workflows/build.yml)

Speedcubing statistics for Polish competitors and competitions, computed from the
public [WCA database exports](https://www.worldcubeassociation.org/export/results).
The statistics are published on GitHub Pages: [maxidragon.github.io/wca_statistics_pl](https://maxidragon.github.io/wca_statistics_pl/).

## Origin

This project started as a copy of [jonatanklosko/wca_statistics](https://github.com/jonatanklosko/wca_statistics)
by Jonatan Kłosko, and the scripts and core classes still come from there.
It is now a separate repository, not a GitHub fork, and is developed independently:
the statistics are limited to Poland, and changes are not synced with the original project in either direction.

## Getting started

Requirements: Ruby (see `.ruby-version`) and MySQL.

- Clone the repository and cd into it: `git clone https://github.com/maxidragon/wca_statistics_pl.git && cd wca_statistics_pl`
- Install third party dependencies: `bundle`
- Run the initialization script: `bin/init.rb`
- If necessary edit the `database.yml` file in the project root directory. It is created by the initialization script and is not stored in git.
- Download the WCA database: `bin/update_database.rb`

## Scripts

| Script | Description |
| ------ | ----------- |
| `compute.rb` | Computes a single statistic from the given statistic file path. |
| `compute_all.rb` | Computes all the statistics. |
| `compute_index.rb` | Generates the index page, which lists the statistics grouped by category. |
| `list.rb` | Lists all the statistics. |
| `init.rb` | Does basic initialization. |
| `new_statistic.rb` | Generates a new statistic. Accepts a filename as an argument. When the `--grouped` flag is appended, generates so-called grouped statistics, which consist of a couple of tables (e.g. a list of top 10 competitors for each event). |
| `update_database.rb` | Downloads and imports the WCA database copy. |

Each statistic must set `@category` to one of the keys in `core/categories.rb`, otherwise `compute_index.rb` fails.

## Deployment

The `Build` GitHub Actions workflow publishes the results to the `gh-pages` branch:

- on a push to `master` it computes only the statistics changed in that push,
- once a day, and when run manually, it recomputes all of them.

## License

MIT, see [LICENSE](LICENSE).
