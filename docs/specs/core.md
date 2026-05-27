# Symbit Core & Numbers — Current Design

This file describes the current core object model and numeric layer used by
the MoonBit implementation.

## Package Layout

- `symnum` — exact rationals, MP-compatible real/complex numeric helpers,
  precision helpers, and interval-context support.
- `symcore` — the symbolic expression tree, canonical and raw constructors,
  traversal, substitution, matching, ordering, singleton handling, and `evalf`.
- `symprint` — deterministic string and LaTeX-oriented printers.
- Root package `CAIMEOX/symbit` — the small facade for common expression,
  matrix, simplification, printing, and CSE front doors.

## Numeric Layer

- `BigRational` remains the exact numeric atom used throughout the symbolic
  stack.
  - denominator is non-zero and positive;
  - numerator and denominator are normalized by gcd;
  - arithmetic preserves exactness;
  - invalid construction raises `RationalError`.
- The MP compatibility layer in `symnum` wraps `CAIMEOX/moon_floating` and
  provides `Mpf`, `Mpc`, precision conversion, interval context, raw `mpf_*` /
  `mpc_*` operations, and higher-level helpers used by `evalf`.

## Floating Values

`symcore.Expr` now has floating leaves:

- `Expr::Float(Float)` for real MP-backed floating values.
- `Expr::ComplexFloat(ComplexFloat)` for complex MP-backed floating values.

`Float` tracks binary precision and can be built from strings, `Double`, exact
rationals, or `BigRational`. `evalf` can therefore return symbolic expressions
that still carry precision information instead of collapsing to plain MoonBit
`Double` values.

## Expression Kernel

Symbit uses a recursive algebraic data type for expression structure. The main
variants currently include:

- numeric and symbolic atoms: `Number`, `Float`, `ComplexFloat`,
  `NumberSymbol`, `Boolean`, `Symbol`, `Dummy`;
- pattern/callable atoms: `Wild`, `WildFunction`, `FunctionHead`,
  `UndefinedFunction`, `IdentityFunction`;
- structural nodes: `Apply`, `Add`, `Mul`, `Pow`, `Mod`, `Tuple`, `Dict`;
- semantic nodes: `Relational`, `Derivative`, `Subs`, `Lambda`;
- legacy `Function(name, args)` nodes, normalized by `normalize_legacy_expr`
  into the newer callable-head representation where applicable.

This ADT is the shared substrate for simplification, parsing, assumptions,
polys, matrices, solvers, physics, and oracle conversion.

## Canonical And Raw Construction

Canonical constructors are used by ordinary front doors:

- `add` flattens nested additions, merges exact numeric terms, removes zeros,
  sorts terms, and collapses empty/singleton results.
- `mul` flattens nested products, handles the zero annihilator, merges exact
  numeric factors, removes ones, sorts factors, and collapses empty/singleton
  results.
- `pow` simplifies trivial powers, evaluates exact numeric integer powers, and
  keeps non-trivial powers symbolic.

Raw constructors such as `raw_add`, `raw_mul`, `raw_pow`, and `raw_apply` are
available for parser, strategy, and parity paths that need to preserve shape,
argument order, or `evaluate=false` behavior.

## Ordering, Equality, And Hashing

Ordering and hashing operate over normalized expression structure. This keeps
structural equality aligned with the canonicalization rules while still allowing
raw expression paths when a caller explicitly needs them.

## Traversal And Substitution

`children`, `map_children`, substitution helpers, match helpers, and expression
path utilities work over normalized expression views. Higher-level packages
should use these front doors rather than inspecting every variant manually unless
they own a specific semantic node.

## Testing And Parity

Core tests cover numeric normalization, constructor canonicalization,
`evaluate=false` paths, singleton behavior, traversal, matching, ordering,
floating conversion, and `evalf`. Oracle tests under `src/sympy/core` compare
selected observable behavior with live SymPy through the test-only bridge.
