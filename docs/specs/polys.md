# Symbit Polys — Current Design

`sympolys` is the polynomial and exact-domain stack for Symbit. It now covers
far more than the original sparse-polynomial milestone: domains, finite fields,
algebraic extensions, dense/sparse polynomial algorithms, domain matrices,
factorization, roots, Groebner-style helpers, resultants, subresultants, and
multiple SymPy-compatible front doors.

## Core Data Model

- `Domain`
  - exact integer/rational domains: `ZZ`, `QQ`;
  - real/complex-flavored domains: `RR`, `CC`, `ZZ_I`, `QQ_I`;
  - expression domains: `EX`, `EXRAW`;
  - composite domains: fraction fields, polynomial rings, rational function
    fields, quotient rings, power series, finite fields, finite-field
    extensions, and algebraic extensions.
- `TermOrder`
  - `Lex`, `Grlex`, `Grevlex`, and inverse variants.
- `Monomial`
  - fixed-length exponent vectors with non-negative exponents.
- `FieldElem`
  - coefficient values used by the implemented domains.
- `Poly`
  - sparse monomial-to-coefficient map plus generators, domain, and term order.
- `PolyBuilder`
  - ergonomic construction around a generator list, domain, and term order.

## Canonicalization

- Polynomial storage omits zero coefficients.
- Operations merge like terms and preserve domain consistency.
- Generator order is part of polynomial identity.
- Public operations raise `PolyError` for non-polynomial input, bad generators,
  bad exponents, domain mismatch, failed exact division, unsupported field
  requests, or invalid moduli.

## Implemented Surface

- Expression conversion: `Poly::from_expr`, `Poly::to_expr`,
  `poly_from_expr`, parallel conversion helpers, and dictionary conversion.
- Arithmetic: add/sub/neg/mul/powers, division, exact quotient, gcd/lcm-style
  helpers, dense arithmetic, and distributed-module helpers.
- Domains: domain parsing, conversion, unification, finite-field operations,
  algebraic-extension helpers, rational-function helpers, and matrix-domain
  compatibility layers.
- Algorithms: factorization, square-free tools, modular gcd, root isolation,
  polynomial roots, resultants, discriminants, Groebner helpers, special
  polynomials, orthogonal-polynomial front doors, interpolation-style helpers,
  and number-field compatibility front doors.
- Matrix-adjacent support: domain matrices, dense/sparse matrix compatibility,
  LLL helpers, and solver-adjacent linear algebra support.

## Current Limits

The package is broad but still not a full clone of the upstream `polys`
ecosystem. Some domain combinations, advanced algebraic-number workflows,
AGCA surfaces, and matrix-polynomial interactions remain conservative and raise
`PolyError` rather than guessing.

## Testing And Parity

Package white-box tests cover core algebraic invariants and algorithm-specific
branches. Oracle tests under `src/sympy/polys` compare many front doors with
SymPy across dense arithmetic, domains, factorization, roots, Groebner helpers,
matrices, subresultants, and number-field-adjacent behavior.
