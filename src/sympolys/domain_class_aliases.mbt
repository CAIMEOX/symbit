///|
/// Compatibility aliases for SymPy domain class names.
///
/// - Does: Exposes domain-class spellings as aliases of the MoonBit `Domain`
///   descriptor.
/// - Input: These are type names; construct values with `Domain::ZZ`,
///   `Domain::QQ`, `Domain::GF(p)`, or the domain constructor helpers.
/// - Returns: `Domain` values.
/// - Limits: SymPy's Python class hierarchy and singleton domain objects are
///   represented by the `Domain` enum and helper functions in MoonBit.
pub type FiniteField = Domain

///|
pub type IntegerRing = Domain

///|
pub type RationalField = Domain

///|
pub type PythonFiniteField = Domain

///|
pub type GMPYFiniteField = Domain

///|
pub type PythonIntegerRing = Domain

///|
pub type GMPYIntegerRing = Domain

///|
pub type PythonRational = Domain

///|
pub type GMPYRationalField = Domain

///|
pub type AlgebraicField = Domain

///|
pub type PolynomialRing = Domain

///|
pub type FractionField = Domain

///|
pub type ExpressionDomain = Domain
