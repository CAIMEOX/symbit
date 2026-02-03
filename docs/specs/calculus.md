# Symbit Calculus — Minimal Port Plan

Goal: port core pieces of `sympy/calculus` into MoonBit with a focused,
testable subset and SymPy oracle parity checks.

## Scope (first cut)

- AccumBounds (AccumulationBounds) as symbolic bounds on real values.
- Basic operations on AccumBounds for numeric endpoints.
- Finite difference weights and application for BigRational grids.
- Minimal symbolic differentiation for Euler–Lagrange equations.
- Singularities for simple poles and `log` arguments.
- Periodicity for trig functions with linear arguments.

## Data model & invariants

- AccumBounds are encoded as `Expr::Function("AccumBounds", [min, max])`.
- Infinity uses `Expr::Symbol("oo")`; negative infinity is `-1 * oo`.
- Set-like results are encoded as:
  - `Expr::Symbol("EmptySet")`
  - `Expr::Function("FiniteSet", [...])`
- If both endpoints are numeric:
  - Enforce `min <= max` or raise.
  - Collapse `AccumBounds(x, x)` to `x`.

## Initial APIs

- `accum_bounds(min, max) -> Expr raise AccumBoundsError`
- `accum_is_bounds`, `accum_min`, `accum_max`, `accum_delta`, `accum_mid`
- `accum_add`, `accum_sub`, `accum_neg`, `accum_mul`, `accum_div`,
  `accum_pow`, `accum_abs`, `accum_union`
- `diff(expr, var) -> Expr` (minimal: Add/Mul/Pow/sin/cos/exp/log)
- `euler_equations(L, funcs, vars) -> Array[Expr]`
- `finite_diff_weights(order, x_list, x0) -> Array[Array[Array[BigRational]]]`
- `apply_finite_diff(order, x_list, y_list, x0) -> Expr`
- `singularities(expr, symbol) -> Expr`
- `periodicity(expr, symbol) -> Expr?` (None if unknown)

## Testing

- Oracle parity via SymPy for numeric and structurally simple cases.
- Compare via `sympy.sympify` + `str` to normalize printing.
