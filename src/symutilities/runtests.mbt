///|\
/// Deprecation helper corresponding to `sympy.utilities.runtests`.

///|
pub fn runtests_deprecation_warning() -> SymPyDeprecationWarning raise UtilitiesError {
  sympy_deprecation_warning(
    "The sympy.utilities.runtests submodule is deprecated. Use sympy.testing.runtests instead.",
    "1.6", "deprecated-sympy-utilities-submodules",
  )
}
