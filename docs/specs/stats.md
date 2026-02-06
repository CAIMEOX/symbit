# Symbit Stats Port Plan (Stage 0-8)

Goal: port the SymPy `sympy.stats` stack into MoonBit with stable symbolic
behavior and deterministic query APIs.

## Scope Summary

- Core random variable model and query interface.
- Finite/discrete/continuous scalar distributions.
- Symbolic `Probability`/`Expectation` style wrappers.
- Joint random variables (independent-product first).
- Compound RV and error propagation helpers.
- Stochastic process and matrix-distribution starter layer.

## Stage Map

- Stage 0: package skeleton + specs + oracle test bridge.
- Stage 1: core `RandomVar`, `Event`, `RExpr`, `P/E/variance` base.
- Stage 2: finite RVs (`FiniteRV`, `Die`, `Coin`, `Bernoulli`, `DiscreteUniform`).
- Stage 3: symbolic wrappers (`ProbabilityExpr`, `ExpectationExpr`, ...)
- Stage 4: discrete infinite RVs (`Binomial`, `Poisson`, `Geometric`,
  `NegativeBinomial`).
- Stage 5: continuous RVs (`Normal`, `Exponential`, `Gamma`) + `pdf/cdf`.
- Stage 6: joint RV (independent product) and marginal expectation/covariance.
- Stage 7: compound RV (basic finite mixture) + `error_prop.variance_prop`.
- Stage 8: stochastic process + random matrix/matrix distributions starter APIs.

## Post-Stage-8 Expansion

- Symbolic distribution constructors now retain parameters in `RVKind::Symbolic`.
- Symbolic compatibility constructors are family-tagged (`C/D/J/P/M`) so query
  dispatch can avoid generic `density(...)`/`cdf(...)` fallback for compat APIs.
- Added concrete continuous formulas (density/cdf/mean/variance) for:
  `Uniform`, `Beta`, `Laplace`, `Cauchy`, `Pareto`, `Rayleigh`,
  `LogNormal`, `Weibull`, `StudentT`.
- Upgraded compat query helpers:
  - `moment_generating_function`, `characteristic_function`, `quantile`
    attempt closed-form evaluation for supported RV kinds.
  - `entropy` computes exact finite-atom entropy when possible.
  - `central_moment` computes exact finite-atom moments when possible.
- Oracle equivalence now sympifies expressions with `locals`, reducing float
  parsing drift in parity checks.
- For symbolic compat RVs without closed forms, query APIs emit distribution-
  specific symbolic nodes (`<Name>PMF`, `<Name>CDF`, `<Name>Mean`, etc.) rather
  than generic wrappers.

## Known Parity Gap

- `sympy.stats.where` cannot be exported as `where` in MoonBit because
  `where` is a reserved keyword. Current public alias is `where_`.

## Canonical Rules

- All public query functions return canonical `@symcore.Expr`.
- Numeric cases are evaluated exactly using `BigRational` whenever practical.
- Non-evaluable cases return symbolic function nodes (e.g. `Probability(...)`).
- Independence defaults to `True` for distinct scalar RVs unless explicitly joint.

## Oracle Strategy

- Add `sympy/stats/stats_oracle.mbt` with eval helpers to compute expected
  SymPy output for parity tests.
- Use `sympy.simplify(a-b)==0` for algebraic equivalence, not raw string only.
