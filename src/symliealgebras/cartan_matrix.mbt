///|
/// Cartan matrix accessors.

///|
pub fn cartan_matrix(ct : CartanType) -> Matrix raise {
  ct.cartan_matrix()
}

///|
pub fn cartan_matrix_from_string(ct : String) -> Matrix raise {
  cartan_type_from_string(ct).cartan_matrix()
}

///|
pub fn cartan_matrix_from_parts(series : String, n : Int) -> Matrix raise {
  cartan_type_from_parts(series, n).cartan_matrix()
}
