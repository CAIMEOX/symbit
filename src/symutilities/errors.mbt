///|\
/// Error values for `symutilities` helpers.

///|
pub(all) suberror UtilitiesError {
  InvalidArgument(String)
  Unsupported(String)
  MissingValue(String)
} derive(Show, Eq)
