# Symbit Algebras — Quaternion Current Design

`symalgebras` currently provides the quaternion layer corresponding to SymPy's
`algebras/quaternion.py`. Components are symbolic `symcore.Expr` values, and
parity tests are driven by the test-only SymPy oracle.

## Scope

- Core quaternion type with symbolic components.
- Hamilton product, scalar arithmetic, conjugate, norm, inverse, normalize, and
  powers.
- Exponential/logarithmic helpers and trigonometric power forms.
- Axis/angle and Euler conversions.
- Rotation matrix conversion and point rotation.
- Vector semantics: axis, angle, coplanar/parallel/orthogonal checks, and
  three-valued pure/zero predicates.
- Matrix outputs represented as row-major `Array[Array[Expr]]`.

## Data Model

- `type Expr = @symcore.Expr`
- `type Matrix = Array[Array[Expr]]`
- `Quaternion`
  - `a, b, c, d : Expr` for scalar and vector parts;
  - `real_field : Bool` retained for SymPy parity;
  - `norm_override : Expr?` for externally supplied norm semantics.

## Invariants

- Components are commutative symbolic expressions.
- Numeric `norm_override` values must be non-negative.
- When all components are numeric, a provided norm must agree with
  `sqrt(a^2 + b^2 + c^2 + d^2)` according to the implemented exact checks.

## Public Surface

- Construction: `Quaternion::new`, `with_norm`, sequence/matrix constructors.
- Arithmetic: add/sub/mul/div, scalar variants, negation, and powers.
- Core operations: conjugate, norm, normalize, inverse, exp, log,
  `pow_cos_sin`.
- Rotation helpers: axis-angle, Euler conversion, rotation matrices, and
  `rotate_point`.
- Vector queries: scalar/vector parts, axis, angle, index vector, mensor,
  coplanarity, parallelism, orthogonality, purity, and zero-quaternion checks.

## Testing And Parity

Oracle tests compare arithmetic, conjugation, norm, inverse, powers,
axis-angle behavior, rotations, and selected predicate behavior with SymPy.
Package tests cover symbolic and numeric edge cases in the MoonBit runtime.
