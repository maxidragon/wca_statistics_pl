#!/bin/bash

# Diff against the state before the push, so every commit pushed together is covered.
# Fall back to the parent commit when there is no usable before SHA (new branch, force push).
diff_base="$GITHUB_BEFORE_SHA"
if [[ -z "$diff_base" || "$diff_base" =~ ^0+$ ]] || ! git cat-file -e "$diff_base^{commit}" 2>/dev/null; then
  diff_base="$GITHUB_SHA~1"
fi
# Deleted files are skipped, as there is nothing left to compute for them.
changed_statistic_files=`git diff --name-only --diff-filter=d $diff_base..$GITHUB_SHA | grep 'statistics/' | grep -v 'statistics/index.rb'`

if [[ "$GITHUB_EVENT_NAME" != "schedule" && "$GITHUB_EVENT_NAME" != "workflow_dispatch" && "$changed_statistic_files" == "" ]]; then
  echo "There is nothing to compute."
else
  # Set up database.
  bin/init.rb
  printf "database: \"wca_statistics\"\nusername: \"root\"\npassword: \"root\"" > database.yml
  bin/update_database.rb
  # When a cron job compute all statistics, otherwise just the updated and new ones.
  if [[ "$GITHUB_EVENT_NAME" == "schedule" || "$GITHUB_EVENT_NAME" == "workflow_dispatch" ]]; then
    bin/compute_all.rb || exit 1
  else
    echo "$changed_statistic_files" | while read file; do
      echo "File has changed: $file"
      bin/compute.rb $file || exit 1
    done
  fi
  # Update the index file in both cases.
  bin/compute_index.rb
  # Add the GitHub repository link in the corner of each page.
  github_repo_slug="${GITHUB_REPOSITORY:-jonatanklosko/wca_statistics}"
  github_corner_template_html=`cat bin/templates/github_corner.html`
  github_corner_html="${github_corner_template_html/"<<<GITHUB_REPO_SLUG>>>"/$github_repo_slug}"
  grep --files-without-match "github-corner" build/* | while read file; do
    echo -e "\n\n$github_corner_html" >> $file
  done
fi
