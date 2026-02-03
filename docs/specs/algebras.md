# Symbit Algebras — Quaternion (Draft Design)

Goal: port SymPy `algebras/quaternion.py` into MoonBit with a symbolic core
based on `symcore.Expr` and parity tests driven by a Python/SymPy oracle.

## Scope (first cut)

- Core quaternion type with symbolic components (`Expr`).
- Hamilton product, scalar add/mul, conjugate, norm, inverse, normalize, pow.
- Axis/angle and Euler conversions, rotation matrix helpers.
- Vector semantics: axis, angle, coplanar/parallel/orthogonal checks (3‑valued).
- Matrix outputs represented as `Array[Array[Expr]]` (row-major).

## Data model (package `symalgebras`)

- `type Expr = @symcore.Expr`
- `type Matrix = Array[Array[Expr]]`
- `struct Quaternion`
  - `a, b, c, d : Expr` (scalar + vector parts)
  - `real_field : Bool` (kept for parity; no complex splitting yet)
  - `norm_override : Expr?` (optional pre-defined norm)

### Invariants

- Components are commutative expressions (MoonBit core has only commutative
  `Expr` today).
- If `norm_override` is a numeric literal, it must be non‑negative; if all
  components are numeric, `norm_override^2 == a^2+b^2+c^2+d^2` must hold.

## Key APIs (planned)

- Construction:
- `Quaternion::new(a, b, c, d, real_field?=true, norm?)`
  - `Quaternion::with_norm(norm?)`
  - `Quaternion::from_matrix(elements)` (len 3 or 4)
- Arithmetic:
  - `add`, `sub`, `mul`, `neg`, `div` (+ scalar variants)
- Core operations:
  - `conjugate`, `norm`, `normalize`, `inverse`, `pow`
  - `exp`, `log`, `pow_cos_sin`
- Rotation helpers:
  - `from_axis_angle`, `to_axis_angle`
  - `from_euler`, `to_euler`
  - `to_rotation_matrix`, `from_rotation_matrix`
  - `rotate_point`
- Vector queries:
  - `scalar_part`, `vector_part`, `axis`, `angle`, `index_vector`, `mensor`
  - `is_pure`, `is_zero_quaternion` (3‑valued)
  - `arc_coplanar`, `vector_coplanar`, `parallel`, `orthogonal`

## Testing plan

- Oracle parity via SymPy for add/mul/conjugate/norm/inverse/pow.
- Axis/angle round‑trips and rotation matrix entries via SymPy comparison.
- 3‑valued predicates validated on numeric examples.

## Notes

- No full calculus support yet; diff/integrate are excluded for now.
- Trig simplification (`trigsimp`) is treated as identity in the core.
