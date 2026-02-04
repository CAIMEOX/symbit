///|
/// Dynkin diagram helpers.

///|
pub fn dynkin_diagram(ct : CartanType) -> String raise {
  ct.dynkin_diagram()
}

///|
pub fn dynkin_diagram_from_string(ct : String) -> String raise {
  cartan_type_from_string(ct).dynkin_diagram()
}

///|
pub fn dynkin_diagram_from_parts(series : String, n : Int) -> String raise {
  cartan_type_from_parts(series, n).dynkin_diagram()
}
