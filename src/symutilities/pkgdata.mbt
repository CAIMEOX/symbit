///|\
/// Resource-path helpers adapted from `sympy.utilities.pkgdata`.

///|
fn join_resource_path(base_dir : String, identifier : String) -> String {
  let base = if base_dir.has_suffix("/") {
    base_dir[:base_dir.length() - 1].to_string()
  } else {
    base_dir
  }
  let rel = if identifier.has_prefix("/") {
    identifier[1:identifier.length()].to_string()
  } else {
    identifier
  }
  if base.length() == 0 {
    rel
  } else {
    base + "/" + rel
  }
}

///|
pub fn pkgdata_deprecation_warning() -> SymPyDeprecationWarning {
  try! sympy_deprecation_warning(
    "The sympy.utilities.pkgdata module and its get_resource function are deprecated. Use the stdlib importlib.resources module instead.",
    "1.12", "pkgdata",
  )
}

///|
/// MoonBit adaptation of `get_resource`. Since the runtime utility layer does
/// not expose Python-style loader file objects, this returns the resolved path
/// string after emitting the deprecation warning.
pub fn get_resource(identifier : String, pkg_dir : String) -> String {
  ignore(pkgdata_deprecation_warning())
  join_resource_path(pkg_dir, identifier)
}
