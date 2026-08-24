# Commit Style Guide

Follows [Conventional Commits 1.0.0](https://www.conventionalcommits.org/)

## Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Types

| Type | When to use |
|------|-------------|
| `feat` | Add a new feature |
| `fix` | Fix a bug |
| `chore` | Build process, tooling, setup — no production code change |
| `docs` | Documentation only |
| `refactor` | Code restructure, no behavior change |
| `test` | Add or fix tests |
| `ci` | CI/CD configuration |
| `perf` | Performance improvement |
| `style` | Formatting, whitespace — no logic change |
| `build` | Build system or dependency changes |

## Rules

- **description**: lowercase, imperative mood, no period at end
- **scope**: optional, in parentheses — names the subsystem affected, e.g. `feat(bridge): ...`
- **body**: explain *why*, not *what* — separate from description with a blank line
- **BREAKING CHANGE**: add `BREAKING CHANGE: <description>` in footer, or append `!` after type/scope

## Examples

```
chore: initial project scaffold for PowerVR DDK Linux → eMCOS porting
```

```
feat(osfunc): implement OSThreadCreate using eMCOS pthread
```

```
fix(bridge): correct IPC message size for PVRSRVBridgeCall
```

```
feat(bridge)!: replace DRM ioctl with mcos_message_send

BREAKING CHANGE: bridge protocol changed — client and server must be updated together
```

```
docs: add porting order and open questions to CLAUDE.md
```
