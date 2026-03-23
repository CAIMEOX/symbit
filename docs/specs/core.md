# Symbit Core & Numbers — Draft Spec

This file captures the first iteration of the core object model and numeric
layer for the SymPy → MoonBit rewrite. It follows the AGENTS milestones:
L0 (numbers/domains) and the lower half of L1 (Expr kernel + canonicalization).

## Package layout (module `CAIMEOX/symbit`)

- `symnum` — `BigInt` helpers + `BigRational` (normalized, denominator > 0).
- `symcore` — expression AST, constructors with canonicalization, traversal
  helpers.
- `symprint` — stable printers (`debug_repr`, minimal infix string).
- Root package (`symbit`) re-exports convenience constructors as a prelude.

## Numeric layer (symnum)

- `BigRational { num: BigInt, den: BigInt }`
  - invariants: `den != 0`, `den > 0`, `gcd(|num|, den) == 1`.
  - normalization: flip sign to numerator if `den < 0`; divide by `gcd`.
  - operations: `add`, `mul`, `neg`, `compare`, `is_zero`, `one`, `zero`,
    `from_int`, `from_bigint`.
  - errors: `RationalError::ZeroDenominator` on invalid construction.
- helpers: `gcd_bigint(a, b)` using Euclidean algorithm on absolute values.
- floating backend bridge:
  - `symnum` now exposes an mpmath-style compatibility layer over
    `CAIMEOX/moon_floating` (`Mpf`, `Mpc`, precision helpers, interval context,
    raw ops, high-level numeric wrappers).
  - this is the intended backend for future `Float`/`evalf` work; exact
    `BigRational` remains the canonical exact-number layer.

## Floating sketch (`symcore.Float`)

- `symcore.Float` is intentionally **not** an `Expr` variant yet.
  - Reason: adding a new `Expr` constructor today would require widening
    exhaustive matches across the entire repository.
  - Instead, the first step is a dedicated core wrapper around `symnum.Mpf`
    with tracked binary precision.
- current surface:
  - constructors from string / `Double` / exact rational / `BigRational`
  - `to_mpf`, `to_rational`, `to_double`, `precision`, `is_finite`
  - stable `Show`/`format` using the `symnum` mpmath-compatible printer
- next step:
  - once enough downstream packages are ready, `Expr::Float` can be introduced
    in a controlled repo-wide refactor instead of a partial break.

## Expr kernel (symcore)

Chosen route: **recursive ADT** for fast iteration; arena/hash-consing can be
added later without changing public shape.

### Types

- `enum Expr`
  - `Number(BigRational)` — exact numeric atoms.
  - `Symbol(String)` — atomic symbols (no assumptions yet).
  - `Add(Array[Expr])`, `Mul(Array[Expr])` — variadic, canonicalized on build.
  - `Pow(base~, exp~)` — binary, normalized for trivial exponents.
  - `Function(name~, args~ : Array[Expr])` — function application node.

### Canonicalization invariants

- `Add`:
  - flatten nested `Add`.
  - merge numeric terms into a single `Number`; drop zeros.
  - sort args by total order (variant order + lexicographic structure).
  - collapse to `0` when empty, or the sole child when length == 1.
- `Mul`:
  - flatten nested `Mul`.
  - zero annihilator: any zero factor → `0`.
  - drop multiplicative identity `1`.
  - merge numeric terms into one `Number`.
  - sort args by same total order; collapse to `1`/single child accordingly.
- `Pow`:
  - `x^1 = x`, `x^0 = 1` (with a note: 0^0 currently treated as 1; revisit).
- `Symbol` names are opaque strings; comparison uses string order.

### Ordering / equality / hashing

- Total order: `Number < Symbol < Pow < Mul < Add < Function`.
- Structural comparison: lexicographic on children after variant tag;
  numbers compare via `BigRational::compare`.
- `Eq`/`Hash` rely on normalized representation, so structural equality matches
  mathematical equality under these invariants.

### Traversal utilities

- `children(e)` returns `ArrayView[Expr]` (empty for atoms).
- `map_children(e, f)` reconstructs with canonical builders.
- `subst(e, env : Map[String, Expr])` substitutes symbols (re-normalizes).

## Printing (symprint)

- `debug_repr(e)` — S-expression style, deterministic and aligned with sort
  order; primary target for snapshot tests.
- `to_string(e)` — minimal infix printer with parentheses for precedence
  (Add/Mul/Pow).

## Testing plan (milestone 0/1 scope)

- Numeric normalization tests: sign handling, gcd reduction, zero denominator
  error, arithmetic closure.
- Core canonicalization tests: different construction paths for Add/Mul/Pow
  yield identical `debug_repr`.
- Ordering tests: `compare_expr` sorts mixed numbers/symbols/functions
  deterministically.
- Printing snapshots via `debug_repr` for stability.
