///|\
/// Deprecation helper corresponding to `sympy.utilities.pytest`.

///|
pub fn pytest_deprecation_warning() -> SymPyDeprecationWarning {
  try! sympy_deprecation_warning(
    "The sympy.utilities.pytest submodule is deprecated. Use sympy.testing.pytest instead.",
    "1.6", "deprecated-sympy-utilities-submodules",
  )
}
