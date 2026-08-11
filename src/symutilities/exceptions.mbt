///|\
/// Deprecation helpers aligned with `sympy.utilities.exceptions`.

///|
pub struct SymPyDeprecationWarning {
  message : String
  deprecated_since_version : String
  active_deprecations_target : String
} derive(Eq)

///|
fn validate_deprecation_target(target : String) -> Unit raise UtilitiesError {
  if target.contains("(") || target.contains(")") || target.contains("=") {
    raise InvalidArgument(
      "active_deprecations_target should be the anchor fragment without '(...)=' syntax",
    )
  }
}

///|
pub fn SymPyDeprecationWarning::full_message(
  self : SymPyDeprecationWarning,
) -> String {
  let body = filldedent(self.message).trim().to_owned()
  "\n\n" +
  body +
  "\n\n" +
  "See https://docs.sympy.org/latest/explanation/active-deprecations.html#" +
  self.active_deprecations_target +
  "\nfor details.\n\n" +
  "This has been deprecated since SymPy version " +
  self.deprecated_since_version +
  ". It\nwill be removed in a future version of SymPy.\n"
}

///|
pub impl Show for SymPyDeprecationWarning with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.full_message())
}

///|
pub fn sympy_deprecation_warning(
  message : String,
  deprecated_since_version : String,
  active_deprecations_target : String,
) -> SymPyDeprecationWarning raise UtilitiesError {
  if deprecated_since_version.length() == 0 {
    raise InvalidArgument(
      "deprecated_since_version should be a non-empty string",
    )
  }
  validate_deprecation_target(active_deprecations_target)
  { message, deprecated_since_version, active_deprecations_target }
}
