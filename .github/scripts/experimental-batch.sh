#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_REF_NAME:?This workflow must run from a branch.}"
: "${DEFAULT_BRANCH:?The repository default branch was not provided.}"
: "${GH_TOKEN:?The GitHub token was not provided.}"

head_branch="$GITHUB_REF_NAME"
base_branch="$DEFAULT_BRANCH"

if [[ "$GITHUB_REF" != refs/heads/* ]]; then
  echo "::error::Dispatch this workflow from a branch, not a tag."
  exit 1
fi

if [[ "$head_branch" == "$base_branch" ]]; then
  echo "::error::Dispatch from a non-default branch. The default branch is the PR/release target."
  exit 1
fi

# Fail closed if this batch has already been started or completed. Each output is
# intentionally one-shot so reruns cannot silently create another 15 releases.
existing_releases="$(gh release list --limit 100 --json tagName --jq '.[].tagName')"
for i in $(seq 1 15); do
  item="$(printf '%02d' "$i")"
  tag="experimental-${item}"
  record="experiments/pull-requests/${item}.md"

  if [[ -e "$record" ]]; then
    echo "::error::Batch record already exists: $record. This batch is one-shot."
    exit 1
  fi
  if grep -Fxq "$tag" <<< "$existing_releases"; then
    echo "::error::Release $tag already exists. This batch is one-shot."
    exit 1
  fi
done

# If this source branch already has a PR open to the default branch, the first
# generated change is added to that PR; otherwise the script opens a new PR.
open_prs="$(gh pr list --head "$head_branch" --base "$base_branch" --state open --json number)"
open_pr_count="$(jq 'length' <<< "$open_prs")"
if (( open_pr_count > 1 )); then
  echo "::error::More than one open PR exists from $head_branch to $base_branch."
  exit 1
fi
existing_pr="$(jq -r '.[0].number // empty' <<< "$open_prs")"

# Keep the source branch based on the latest default-branch content without
# creating or pushing any additional branch.
fetch_base() {
  git fetch origin "+refs/heads/${base_branch}:refs/remotes/origin/${base_branch}"
}
fetch_base
git merge --no-edit "origin/$base_branch"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

for i in $(seq 1 15); do
  item="$(printf '%02d' "$i")"
  record="experiments/pull-requests/${item}.md"
  title="[Experiment ${item}/15] Add generated PR record"

  mkdir -p "$(dirname "$record")"
  cat > "$record" <<EOF
# Experimental pull request ${item} of 15

This small generated file provides a distinct change for one pull-request test in this experimental repository.

Batch run: ${GITHUB_RUN_NUMBER:-manual}
EOF

  git add "$record"
  git commit -m "test: add experimental PR record ${item}/15"
  git push origin "HEAD:${head_branch}"

  body_file="$(mktemp)"
  cat > "$body_file" <<EOF
This is generated test pull request ${item} of 15 for the experimental repository.

It adds one small record file only. The batch workflow will merge this PR if repository rules allow it.
EOF

  if [[ -n "$existing_pr" ]]; then
    gh pr edit "$existing_pr" --title "$title" --body-file "$body_file"
    pr_number="$existing_pr"
    existing_pr=""
  else
    pr_url="$(gh pr create \
      --head "$head_branch" \
      --base "$base_branch" \
      --title "$title" \
      --body-file "$body_file")"
    pr_number="${pr_url##*/}"
  fi
  rm -f "$body_file"

  gh pr merge "$pr_number" --merge
  merged_at="$(gh pr view "$pr_number" --json mergedAt --jq '.mergedAt // empty')"
  if [[ -z "$merged_at" ]]; then
    echo "::error::PR #${pr_number} has not merged; stopping the batch."
    exit 1
  fi
  echo "Merged PR #${pr_number} (${item}/15)."

  # The merge commit is an ancestor of the source branch, so this is a
  # fast-forward that keeps every future PR limited to its new record.
  fetch_base
  git merge --ff-only "origin/$base_branch"
  git push origin "HEAD:${head_branch}"
done

# All PR changes are now on the default branch. Publish each release against
# its latest tip; use prereleases to avoid implying production stability.
for i in $(seq 1 15); do
  item="$(printf '%02d' "$i")"
  tag="experimental-${item}"
  gh release create "$tag" \
    --target "$base_branch" \
    --title "Experimental Release ${item}" \
    --notes "Test-only prerelease ${item} of 15, created by the experimental batch workflow." \
    --prerelease
done

echo "Completed: 15 PRs merged and 15 prereleases published."
