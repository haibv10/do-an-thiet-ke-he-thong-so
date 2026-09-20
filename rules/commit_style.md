# Commit Style Guide

Use [Conventional Commits 1.0.0](https://www.conventionalcommits.org/) with a concise subject and a
technical body. The commit body is required for every commit so that the design context remains available
to contributors and AI-assisted tools.

## Format

```text
<type>(<scope>): <short description>

Context:
<hardware or architectural context>

Changes:
<modules, interfaces, FSM behavior, or documentation changed>

Verification:
<simulation, synthesis, hardware test, or explicitly not run>
```

Use only the sections that are relevant, but always include enough detail to explain the change independently
of the conversation. Do not include user requests, chat history, or vague statements such as “update code”.

## Types and Scopes

| Type | Use |
|------|-----|
| `feat` | Add hardware or software behavior. |
| `fix` | Correct functional, timing, reset, or interface behavior. |
| `refactor` | Restructure code without changing intended behavior. |
| `test` | Add or update simulation and verification. |
| `docs` | Change README, diagrams, or technical documentation. |
| `chore` | Change repository setup, ignore rules, or tooling. |
| `build` | Change FPGA project or synthesis configuration. |

Use a lowercase `snake_case` scope naming the affected subsystem, for example `cpu`, `i2c`, `lcd`, `uart`,
`gpio`, `memory`, or `verification`.

## Subject Rules

- Use lowercase imperative English and no trailing period.
- Keep the subject specific and under 72 characters where practical.
- Keep unrelated RTL, documentation, and generated files in separate commits.

## Technical Body Rules

For RTL changes, record the affected module and relevant clock/reset contract. For FSM changes, describe
states, transitions, timing, ACK/error handling, or externally visible behavior. For SoC changes, record
MMIO addresses/registers and bus assumptions. For hardware changes, state the FPGA or peripheral constraint.
Always state verification performed and distinguish “not run” from a passing result.

## Examples

```text
feat(i2c): import lcd write controller

Context:
The LCD demo uses a PCF8574 adapter over a 1 MHz I2C control clock.

Changes:
Add the existing I2C frame, LCD nibble, and clock-divider modules without changing their RTL behavior.

Verification:
Not run; no simulator is configured in the repository.
```

```text
fix(gpio): correct active-low LED handling

Context:
The board LED is active-low while software writes the logical LED state.

Changes:
Preserve the software-visible register format while matching the board output polarity.

Verification:
Simulation passed for reset, LED set and LED clear states.
```
