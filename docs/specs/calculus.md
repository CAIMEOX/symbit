# Symbit Calculus — Current Design

`symcalculus` contains the symbolic calculus utilities currently used by the
runtime: accumulation bounds, finite differences, singularity detection,
periodicity, and Euler-Lagrange style helpers.

## Scope

- Accumulation bounds as symbolic real-value ranges.
- Arithmetic on accumulation bounds for supported exact/numeric endpoints.
- Finite-difference weights and finite-difference application over exact grids.
- Minimal symbolic differentiation needed by calculus and higher packages.
- Euler-Lagrange equation construction.
- Singularity detection for supported poles and logarithmic arguments.
- Periodicity for supported trigonometric forms with linear arguments.

## Data Model And Invariants

- Accumulation bounds are represented as `Expr::Function("AccumBounds", ...)`
  compatible symbolic nodes.
- Infinity uses `NumberSymbolKind::Infinity` / related core number symbols where
  available, with legacy symbolic forms normalized by core helpers.
- Set-like outputs use symbolic set expressions understood by the surrounding
  packages and oracle tests.
- Numeric endpoints are validated; equal endpoints collapse to the endpoint.

## Public Surface

- `accum_bounds`, `accum_is_bounds`, `accum_min`, `accum_max`, `accum_delta`,
  `accum_mid`.
- `accum_add`, `accum_sub`, `accum_neg`, `accum_mul`, `accum_div`,
  `accum_pow`, `accum_abs`, `accum_union`.
- `diff`.
- `euler_equations`.
- `finite_diff_weights`.
- `apply_finite_diff`.
- `singularities`.
- `periodicity`.

## Current Limits

The differentiation and analytic-query front doors are intentionally focused.
Unsupported analytic shapes return conservative symbolic results or `None`
rather than claiming a complete SymPy calculus implementation.

## Testing And Parity

Oracle tests compare supported numeric and structurally simple cases with SymPy.
Runtime tests cover exact arithmetic paths, bounds invariants, finite
differences, Euler equations, singularities, and periodicity.
