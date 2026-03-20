#!/usr/bin/env bash
#
# 07_git_stats.sh — Generates statistics for a Git repository
#
# Usage: ./07_git_stats.sh [path_to_repo]
#
# If no path is given, uses the current directory.
#

set -euo pipefail

repo_dir="${1:-.}"
cd "$repo_dir"

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: '$repo_dir' is not inside a Git repository" >&2
    exit 1
fi

repo_name=$(basename "$(git rev-parse --show-toplevel)")
branch=$(git branch --show-current 2>/dev/null || echo "detached")
total_commits=$(git rev-list --count HEAD 2>/dev/null || echo 0)
first_commit=$(git log --reverse --format='%ai' 2>/dev/null | head -1)
latest_commit=$(git log -1 --format='%ai' 2>/dev/null)

echo "======================================="
echo "  Git Repository Statistics"
echo "======================================="
echo ""
echo "Repository:    $repo_name"
echo "Branch:        $branch"
echo "Total commits: $total_commits"
echo "First commit:  ${first_commit:-N/A}"
echo "Latest commit: ${latest_commit:-N/A}"

echo ""
echo "--- Top 10 Contributors ---"
git shortlog -sn --no-merges HEAD 2>/dev/null | head -10 | while read -r count author; do
    printf "  %4d  %s\n" "$count" "$author"
done

echo ""
echo "--- Commits by Day of Week ---"
git log --format='%ad' --date=format:'%A' 2>/dev/null | sort | uniq -c | sort -rn | \
    while read -r count day; do
        printf "  %-12s %d\n" "$day" "$count"
    done

echo ""
echo "--- File Type Distribution ---"
git ls-files 2>/dev/null | grep '\.' | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15 | \
    while read -r count ext; do
        printf "  %-12s %d files\n" ".$ext" "$count"
    done

echo ""
echo "--- Recent Activity (last 10 commits) ---"
git log --oneline --format='  %h  %an  %s' -10 2>/dev/null

echo ""
echo "Report generated: $(date)"
