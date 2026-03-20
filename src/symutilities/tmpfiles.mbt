///|\
/// Deprecation helper corresponding to `sympy.utilities.tmpfiles`.

///|
pub fn tmpfiles_deprecation_warning() -> SymPyDeprecationWarning raise UtilitiesError {
  sympy_deprecation_warning(
    "The sympy.utilities.tmpfiles submodule is deprecated. Use sympy.testing.tmpfiles instead.",
    "1.6", "deprecated-sympy-utilities-submodules",
  )
}
