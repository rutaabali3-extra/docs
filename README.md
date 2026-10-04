# Experimental Repository

> [!WARNING]
> **This repository is a sandbox for noisy GitHub automation. Do not copy or run these workflows from your main GitHub profile, a production repository, or an organization you care about.** The workflows intentionally create large amounts of public repository activity.

This project is for isolated experiments only. It is not production-ready and may leave behind generated commits, pull requests, tags, and releases.

## Workflows

- **Auto 1000 Commits** (`.github/workflows/auto-1000-commits.yml`) appends 1,000 lines and pushes directly to this repository's `main` branch each time it runs. Its current cron expression (`*/30 * * * *`) requests a run every 30 minutes; GitHub may delay scheduled runs.
- **Experimental Batch: 15 PRs and Releases** (`.github/workflows/experimental-batch.yml`) is manual-only. When explicitly confirmed from a non-default branch, it creates 15 small test pull requests, merges them into the default branch, and publishes 15 prereleases. This is intentionally noisy and should only be used in this disposable test repository.

The batch workflow is guarded by a confirmation checkbox (unchecked by default), refuses to run from the default branch, and refuses to repeat a batch whose artifacts already exist. A completed run is not intended to be repeated.

## Safe-use guidance

- Keep experiments in this repository or another disposable sandbox.
- Do not reuse these workflows on a primary profile, production repository, or shared organization.
- Review the workflow permissions and generated changes before enabling or dispatching it.
- Remember that pull requests, merges, tags, and releases are visible to repository users and may send notifications.
