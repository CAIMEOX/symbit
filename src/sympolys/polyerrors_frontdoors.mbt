///|
/// Compatibility aliases for SymPy's polynomial exception hierarchy.
///
/// - Does: Exposes the public exception-family names as aliases of the single
///   MoonBit `PolyError` error type.
/// - Input: These are type names, not constructors.
/// - Returns: `PolyError`-typed errors.
/// - Limits: MoonBit uses one typed error family with variants instead of
///   Python's subclass hierarchy.
pub type BasePolynomialError = PolyError

///|
pub type ExactQuotientFailed = PolyError

///|
pub type PolynomialDivisionFailed = PolyError

///|
pub type OperationNotSupported = PolyError

///|
pub type HeuristicGCDFailed = PolyError

///|
pub type HomomorphismFailed = PolyError

///|
pub type IsomorphismFailed = PolyError

///|
pub type ExtraneousFactors = PolyError

///|
pub type EvaluationFailed = PolyError

///|
pub type RefinementFailed = PolyError

///|
pub type CoercionFailed = PolyError

///|
pub type NotInvertible = PolyError

///|
pub type NotReversible = PolyError

///|
pub type NotAlgebraic = PolyError

///|
pub type DomainError = PolyError

///|
pub type PolynomialError = PolyError

///|
pub type UnificationFailed = PolyError

///|
pub type GeneratorsError = PolyError

///|
pub type GeneratorsNeeded = PolyError

///|
pub type ComputationFailed = PolyError

///|
pub type UnivariatePolynomialError = PolyError

///|
pub type MultivariatePolynomialError = PolyError

///|
pub type PolificationFailed = PolyError

///|
pub type OptionError = PolyError

///|
pub type FlagError = PolyError
