///|\
/// Deprecation helper corresponding to `sympy.utilities.randtest`.

///|
pub fn randtest_deprecation_warning() -> SymPyDeprecationWarning raise UtilitiesError {
  sympy_deprecation_warning(
    "The sympy.utilities.randtest submodule is deprecated. Use sympy.core.random instead.",
    "1.6", "deprecated-sympy-utilities-submodules",
  )
}
