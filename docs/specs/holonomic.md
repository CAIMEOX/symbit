# Symbit Holonomic — Current Design

`symholonomic` provides recurrence and differential-operator support together
with holonomic sequence/function objects, runtime APIs, and parity tests.

## Scope

- Recurrence operators (`Sn`) over symbolic polynomial coefficients in `n`.
- Differential operators (`Dx`) over symbolic polynomial coefficients in `x`.
- `HolonomicSequence`.
- `HolonomicFunction`.
- Operator arithmetic (`+`, `*`, powers).
- Sequence extraction from supported constant-coefficient ODE shapes.
- Truncated series generation and numeric approximation via truncated series.
- Conversion/display support for common elementary holonomic forms.

## Data Model

- `RecurrenceOperatorAlgebra`
  - `var : Expr`, normally a symbol;
  - `generator : String`, defaulting to `"Sn"`.
- `RecurrenceOperator`
  - coefficient array indexed by generator power;
  - trailing zero coefficients are trimmed.
- `DifferentialOperatorAlgebra`
  - `var : Expr`, normally a symbol;
  - `generator : String`, defaulting to `"Dx"`.
- `DifferentialOperator`
  - coefficient array indexed by generator power;
  - trailing zero coefficients are trimmed.
- `HolonomicSequence`
  - recurrence operator plus initial values.
- `HolonomicFunction`
  - optional annihilator, variable, base point, initial values, and optional
    expression hint for conversion/printing fallbacks.

## Canonical Invariants

- Coefficients are canonical `symcore.Expr` values.
- Zero operators use the package's stable zero representation.
- Binary operator operations require matching parent algebra data.
- Holonomic-function arithmetic preserves variable and base-point consistency.

## Algorithms

- Recurrence multiplication follows `Sn^i * p(n) = p(n + i) * Sn^i`.
- Differential multiplication uses the generalized Leibniz rule.
- Series and sequence logic supports the implemented constant-coefficient and
  known-elementary cases, with expression hints used for conservative fallback.

## Testing And Parity

Port tests compare recurrence and differential operator arithmetic plus selected
holonomic-function displays with SymPy. Runtime tests cover canonicalization,
parent matching, deterministic output, and supported sequence/series behavior.
