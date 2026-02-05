# Symbit Concrete — Draft Design (Stages 0–5)

Goal: port SymPy `sympy.concrete` features into MoonBit with a small, explicit
API that still mirrors SymPy behavior for sums/products, delta simplification,
and sequence guessing. Prefer determinism and canonicalization; defer heavy
performance tuning.

## Scope

- Core: `ExprWithLimits` + `ExprWithIntLimits` base types.
- Summations: `Sum`, `summation`, evaluation helpers (finite, polynomial,
  geometric, telescoping, Gosper-style rational).
- Products: `Product`, `product`, finite evaluation, simple closed forms.
- Delta: `deltasummation`, `deltaproduct` for `KroneckerDelta`-driven rewrites.
- Guessing: `guess`, `find_simple_recurrence`, `guess_generating_function`.

## Data model

- `enum LimitSpec`:
  - `Var(symbol)`
  - `Lower(symbol, lower)`
  - `Range(symbol, lower, upper)`
  - invariant: `symbol` is a `Symbol` expression
- `struct ExprWithLimits`:
  - `expr : Expr`
  - `limits : Array[LimitSpec]`
- `struct ExprWithIntLimits`:
  - `expr : Expr`
  - `limits : Array[LimitSpec]`

`Sum` and `Product` wrap the above and provide `doit`, `as_expr`, and
manipulation helpers (reorder, reverse_order, change_index).

## Canonical form

- Limits are normalized to `Var`/`Lower`/`Range` order, with symbols retained.
- Conversion to `Expr` uses `Function("Sum"| "Product")` with `Tuple`-encoded
  limits: `Sum(expr, Tuple(i, a, b), Tuple(j, c, d))`.

## Evaluation rules (first pass)

- Finite integer bounds: evaluate by loop when feasible.
- Polynomial in the summation variable: use closed-form formulas (Faulhaber).
- Geometric series: detect `a*r**k` and evaluate.
- Telescoping: detect `f(k+1) - f(k)` or ratio for products.
- Fallback: return symbolic `Sum`/`Product`.

## Delta simplification

- `Sum(KroneckerDelta(i, k), (i, a, b))` reduces to `1` if `k` in range, else `0`
  when bounds are integer literals.
- Products with delta use similar checks (zeroing when delta is zero).

## Guessing

- `find_simple_recurrence` via Berlekamp–Massey (integer/rational sequences).
- `guess_generating_function` uses rational interpolation on coefficients.
- `guess` selects simplest candidate based on polynomial degree + recurrence
  order.

## Package layout

- `symconcrete/expr_with_limits.mbt`
- `symconcrete/summations.mbt`
- `symconcrete/products.mbt`
- `symconcrete/delta.mbt`
- `symconcrete/guess.mbt`
- `symconcrete/utils.mbt`

## Tests

- Snapshot parity with SymPy `srepr` and string normalization.
- Separate port tests for sums/products, delta, and guess algorithms.
