///|
/// Public error surface for `symintegrals`.
///
/// Current Limits:
/// - Runtime validation errors are funneled through this small error surface.
/// - Most symbolic failures still fall back to unevaluated expressions instead of raising.
pub suberror IntegralError {
  ValueError(String)
  IntegralTransformError(String)
} derive(Debug)

///|
/// Build a transform-specific integration error.
///
/// - Does: Wraps one message string as `IntegralTransformError`.
/// - Input: One human-readable error `String`.
/// - Returns: An `IntegralError` value.
/// - Limits: This helper only constructs the transform-specific variant.
pub fn integral_transform_error(message : String) -> IntegralError {
  IntegralError::IntegralTransformError(message)
}
