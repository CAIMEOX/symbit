///|
/// Public error surface for `symintegrals` entrypoints that validate runtime
/// objects such as parametric curves.
pub suberror IntegralError {
  ValueError(String)
  IntegralTransformError(String)
} derive(Show)

///|
pub fn integral_transform_error(message : String) -> IntegralError {
  IntegralError::IntegralTransformError(message)
}
