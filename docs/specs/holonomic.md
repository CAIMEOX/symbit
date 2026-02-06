# Symbit Holonomic — Design and Port Plan (Stages 0–5)

Goal: port SymPy `sympy.holonomic` to MoonBit with deterministic, testable
behavior and explicit API boundaries.

## Scope

- Operator algebras:
  - recurrence operators (`Sn`) over polynomial coefficients in `n`
  - differential operators (`Dx`) over polynomial coefficients in `x`
- Symbolic objects:
  - `HolonomicSequence`
  - `HolonomicFunction`
- Core workflows:
  - operator arithmetic (`+`, `*`, `**`)
  - sequence extraction from constant-coefficient ODEs
  - truncated series generation
  - numeric approximation via truncated series
  - expression conversion for common elementary holonomic forms
- Oracle parity:
  - recurrence/differential operator `str`/`srepr`
  - selected holonomic function canonical display

## Data model

- `RecurrenceOperatorAlgebra`
  - `var : Expr` (must be `Symbol`)
  - `generator : String` (default `"Sn"`)
- `RecurrenceOperator`
  - `coeffs : Array[Expr]` (coefficient of `Sn**k` at index `k`)
  - invariant: trailing zero coefficients removed
- `DifferentialOperatorAlgebra`
  - `var : Expr` (must be `Symbol`)
  - `generator : String` (default `"Dx"`)
- `DifferentialOperator`
  - `coeffs : Array[Expr]` (coefficient of `Dx**k` at index `k`)
  - invariant: trailing zero coefficients removed
- `HolonomicSequence`
  - `recurrence : RecurrenceOperator`
  - `u0 : Array[Expr]`
- `HolonomicFunction`
  - `annihilator : DifferentialOperator?`
  - `x : Expr` (must be `Symbol`)
  - `x0 : Expr`
  - `y0 : Array[Expr]`
  - `expr_hint : Expr?` (used by conversion/pretty fallback)

## Canonical invariants

- Coefficients are always canonical `Expr` from `symcore` constructors.
- Operator coefficient arrays are always trimmed:
  - zero operator -> `[0]`
  - order = `coeffs.length() - 1`
- Parent equality (`var`, `generator`) must hold for binary operations.
- `HolonomicFunction` arithmetic preserves variable and base point equality.

## Implemented algorithmic commitments

- Recurrence multiplication uses:
  - `Sn^i * p(n) = p(n + i) * Sn^i`
- Differential multiplication uses generalized Leibniz rule:
  - `Dx^i * p(x) = sum_{r=0..i} binom(i, r) p^{(r)}(x) Dx^{i-r}`
- Series/sequence engine (first complete pass):
  - constant-coefficient linear ODE support
  - finite-order recurrence for Maclaurin coefficients
  - fallback to `expr_hint` for known elementary forms

## Staged delivery

- Stage 0: package + spec + oracle wiring
- Stage 1: recurrence operators
- Stage 2: differential operators
- Stage 3: holonomic sequence object and conversions
- Stage 4: holonomic function core ops
- Stage 5: conversions, series, numerical evaluation

## Test strategy

- Port tests assert direct parity with SymPy oracle on:
  - recurrence and differential operator algebra arithmetic
  - selected canonical `HolonomicFunction` string forms
- Unit tests assert:
  - canonicalization and invariants
  - deterministic output and stable behavior
