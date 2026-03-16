///|\
/// Source-name helpers aligned with `sympy.utilities.source`.

///|
pub fn get_mod_func(callback : String) -> (String, String) {
  let chars : Array[Char] = []
  for ch in callback {
    chars.push(ch)
  }
  let mut dot : Int? = None
  for i in 0..<chars.length() {
    if chars[i] == '.' {
      dot = Some(i)
    }
  }
  match dot {
    Some(idx) => {
      let module_name = callback[:idx].to_string()
      let func_name = callback[idx + 1:callback.length()].to_string()
      (module_name, func_name)
    }
    None => (callback, "")
  }
}

///|
pub fn[T] get_class(
  path : String,
  registry : Map[String, T],
) -> T raise UtilitiesError {
  match registry.get(path) {
    Some(value) => value
    None =>
      raise UtilitiesError::MissingValue("no registered class for " + path)
  }
}
