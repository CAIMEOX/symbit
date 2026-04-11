///|
/// Public error surface for `symintegrals` entrypoints that validate runtime
/// objects such as parametric curves.
pub suberror IntegralError {
  ValueError(String)
  IntegralTransformError(String)
} derive(Debug)

///|
/// Build the transform-specific `IntegralError` variant.
///
/// This helper keeps call sites readable when wrapping failures from Laplace,
/// Mellin, Fourier, and related transform front-ends.
pub fn integral_transform_error(message : String) -> IntegralError {
  IntegralError::IntegralTransformError(message)
}
