# Symbit Concrete — Current Design

`symconcrete` implements concrete mathematics front doors for sums, products,
integer limits, Kronecker-delta simplification, Gosper-style helpers, and
sequence guessing. It mirrors SymPy-facing behavior where the current runtime
surface supports it, while keeping MoonBit data structures explicit.

## Scope

- `ExprWithLimits` and `ExprWithIntLimits` base types.
- `Sum`, `summation`, finite evaluation, polynomial/geometric/telescoping
  cases, and Gosper-style rational helpers.
- `Product`, `product`, finite evaluation, and simple closed forms.
- `deltasummation` and `deltaproduct` for `KroneckerDelta`-driven rewrites.
- `guess`, `find_simple_recurrence`, `guess_generating_function`, and related
  recurrence helpers.

## Data Model

- `LimitSpec`
  - variable-only, lower-bound, and finite-range forms;
  - variables are represented as `symcore.Expr` symbols.
- `ExprWithLimits`
  - expression plus general symbolic limits.
- `ExprWithIntLimits`
  - expression plus integer-oriented limits.
- `Sum` and `Product`
  - wrappers that provide `doit`, expression conversion, reordering, reverse
    ordering, and index-change helpers.

## Canonical Form

- Limits are normalized into stable internal forms.
- Conversion to symbolic expressions uses `Sum` / `Product` function nodes with
  tuple-encoded limits.
- Evaluation keeps exact arithmetic when bounds and terms are exact.
- Unsupported or intentionally unevaluated cases remain symbolic instead of
  falling back to Python.

## Evaluation Rules

- Finite integer bounds can be evaluated by exact loops.
- Polynomial terms use closed-form summation rules where implemented.
- Geometric and telescoping patterns are detected by shape.
- Products support finite evaluation and simple product identities.
- Delta simplification reduces exact in-range/out-of-range cases.
- Sequence guessing uses rational/integer sequence algorithms and returns the
  simplest supported recurrence or generating-function candidate.

## Testing And Parity

Package tests cover data-model invariants, exact evaluation, delta behavior, and
guessing helpers. Oracle tests under `src/sympy/concrete` compare supported
front doors with SymPy.
