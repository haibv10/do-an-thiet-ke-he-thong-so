# Git Flow Guide

## 1. Purpose

This document defines the branching model for the repository so that contributors and AI-assisted tools
target the same integration branch.

## 2. Branch Model

```text
feat/* → develop → release/* → main
```

| Branch | Role |
|---|---|
| `main` | Stable. Receives release and hotfix merges only. Remains the GitHub default branch. |
| `develop` | Integration branch. All feature work lands here first. |
| `feat/*` | One feature or subsystem. Branched from `develop`, merged back into `develop`. |
| `release/*` | Release preparation. Branched from `develop`, merged into `main`. |
| `fix/*` | Bug fix for an unreleased change. Same lifecycle as `feat/*`. |
| `docs/*` | Documentation, diagrams or these guides, with no change to RTL, firmware or tooling. Same lifecycle as `feat/*`. |
| `chore/*` | Repository setup, CI, ignore rules and build tooling. Same lifecycle as `feat/*`. |
| `hotfix/*` | Urgent production fix. Branched from `main`, merged into both `main` and `develop`. |

## 3. Rules

* Never merge a `feat/*` branch directly into `main`.
* Every pull request targets `develop` unless it is a release or hotfix.
* Branch from `develop` only after it is synchronized with the remote.
* Keep one subsystem per branch. Do not add an unrelated peripheral to a feature branch already in review.
* Use a lowercase `snake_case` or hyphenated subsystem name after the prefix, for example `feat/uart-rx`.
* A branch that touches anything besides documentation is not a `docs/*` branch, whatever else it also changes.

## 4. Starting a Feature

```bash
git fetch origin
git checkout develop
git pull --ff-only origin develop
git checkout -b feat/<subsystem>
git push -u origin feat/<subsystem>
```

## 5. Finishing a Feature

Open the pull request against `develop`. The description states the target board, the verification that was
run, and any limitation the feature deliberately leaves open. Follow `rules/commit_style.md` for the commit
messages themselves.

After the merge:

```bash
git checkout develop
git pull --ff-only origin develop
git branch -d feat/<subsystem>
```

## 6. Release

```bash
git checkout develop
git pull --ff-only origin develop
git checkout -b release/<version>
```

Merge `release/<version>` into `main`, tag the merge, then merge `main` back into `develop` so that both
branches carry the release commit.
