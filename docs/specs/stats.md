# Symbit Stats — Current Coverage

`symstats` implements a broad symbolic statistics surface: random variables,
distributions, query functions, stochastic-process placeholders, matrix
ensembles, and compatibility constructors. Read this package as a runtime
implementation with active parity tests and an explicit gap checklist.

## Scope

- Core random-variable model and event/query interface.
- Finite, discrete, continuous, joint, compound, process, and matrix-family
  compatibility constructors.
- Symbolic `Probability`, `Expectation`, variance, covariance, density, CDF,
  moment, moment-generating, characteristic-function, quantile, and entropy
  front doors.
- Distribution-specific symbolic fallback nodes for cases without closed forms.
- Oracle/parity tests under `src/sympy/stats`.

## Current Runtime Behavior

- Public query functions return canonical `@symcore.Expr` values.
- Numeric finite cases are evaluated exactly with `BigRational` where practical.
- Concrete formulas exist for many common continuous and discrete families.
- Symbolic compatibility RVs retain parameters in `RVKind::Symbolic`.
- Compatibility constructors are family-tagged (`C/D/J/P/M`) so dispatch can
  choose distribution-specific symbolic forms instead of generic wrappers.
- `moment_generating_function`, `characteristic_function`, `quantile`, and
  `entropy` attempt closed-form evaluation for supported RV kinds.
- `central_moment` computes exact finite-atom moments when possible.

## Known API Difference

`sympy.stats.where` cannot be exported as `where` in MoonBit because `where` is
a reserved keyword. The public alias is `where_`.

## Gap Tracking

The distribution metric checklist lives in
`docs/stats-gap-checklist.md`. That file records which density/CDF/moment-style
metrics are aligned for the broad compatibility surface.

## Oracle Strategy

`src/sympy/stats/stats_oracle.mbt` evaluates SymPy-side expressions for parity
tests. Tests use algebraic equivalence where possible instead of raw string
comparison only.
