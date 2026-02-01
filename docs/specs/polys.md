# Symbit Polys — Draft Design (Milestone 5)

Goal: mirror SymPy’s `polys` spirit with a minimal, strong-typed core that slots
on top of existing `symnum` + `symcore`. Focus on correctness and
canonicalization; performance tuning comes later.

## Scope (first cut)

- Domains: `ZZ` (BigInt), `QQ` (BigRational). No algebraic extensions yet.
- Gens: ordered symbols `[x0, x1, ...]` captured as `Array[String]`; order is
  part of the polynomial identity (lexicographic by position).
- Representation: sparse multivariate polynomials.
- Operations: `add`, `sub`, `neg`, `mul`, `monomial_mul`, `degree`, `leading_term`.
- Conversions: Expr ⇄ Poly bridge for expressions that are pure polynomials in
  the given gens (integers/rationals, symbols, Add/Mul/Pow with non-negative
  integer exponents).
- Printing: deterministic S-expression and infix.

## Data model (package `sympolys`)

- `enum Domain { ZZ, QQ }`
- `struct Monomial { exps : Array[Int] }`
  - invariant: length == gens.len, all exps ≥ 0
  - ordering: lex on exponent array (left-to-right), tie-breaker by length
- `struct Poly { coeffs : Map[Monomial, Coeff], gens : Array[String], domain : Domain }`
  - `Coeff = BigInt` for ZZ, `BigRational` for QQ
  - invariant: no zero coeff entries; coeffs map keyed by canonical monomials
  - zero poly: empty map; one: coeffs[{0,..0}] = 1

### Canonicalization

- All operations produce maps without zero coefficients; combine like terms on
  insert.
- Monomial arrays fixed-length per poly; creation validates lengths.
- Domain dictates coefficient arithmetic; integer literals lifted to domain.

## Core APIs (planned)

- `fn Poly::from_expr(expr : Expr, gens : Array[String], domain : Domain) -> Result[Poly, PolyError]`
  - accepts Number/Symbol/Add/Mul/Pow with int exponents only; rejects others.
- `fn Poly::to_expr(poly : Poly) -> Expr`
- Arithmetic: `add`, `sub`, `neg`, `mul` (schoolbook), `scale_coeff`.
- Structural: `degree(poly, gen_index)`, `total_degree`, `leading_term(order?)`
  - default order: lex with gens order; extensible to grlex later.
- Helpers: `monomial_one(len)`, `monomial_mul`, `monomial_pow`.
- Errors: `PolyError::NonPolynomial`, `PolyError::BadGenerator`, `PolyError::BadExponent`,
  `PolyError::DomainMismatch`.

## Package layout and deps

- `sympolys` imports `symnum` and `symcore`.
- No reverse deps into core.
- Tests use `symprint.debug_repr` snapshots.

## Example (intended)

```mbt nocheck
let x = @symcore.symbol("x")
let y = @symcore.symbol("y")
let p = Poly::from_expr(
  (@symcore.int(2) * (x ^ @symcore.int(2))) + y,
  ["x", "y"],
  Domain::ZZ
)? // Ok
let q = Poly::from_expr(x, ["x", "y"], Domain::ZZ)?
let sum = p.add(q) // 2*x^2 + y + x
```

## Testing plan

- Round-trips: `from_expr` then `to_expr` produce canonicalized expr/print.
- Rejection cases: negative/ non-integer exponents, unknown symbols, non-poly
  ops (Function, Pow with non-int exp) yield `NonPolynomial`.
- Arithmetic snapshots: `(x + 1)^2` expansion via mul, zero elimination, degree
  queries.

## Next steps

- Implement `sympolys` skeleton with the above types and invariants.
- Add `symbit` prelude helpers: `poly(expr, gens, domain)` returning Result.
- Once stable: add `gcd` prototype (univariate) and factor stubs; extend domain
  to `QQ` by default for Expr import (matching SymPy’s rationalization).
