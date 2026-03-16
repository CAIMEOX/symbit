///|\
/// Deprecation helper corresponding to `sympy.utilities.randtest`.

///|
pub fn randtest_deprecation_warning() -> SymPyDeprecationWarning {
  try! sympy_deprecation_warning(
    "The sympy.utilities.randtest submodule is deprecated. Use sympy.core.random instead.",
    "1.6",
    "deprecated-sympy-utilities-submodules",
  )
}
