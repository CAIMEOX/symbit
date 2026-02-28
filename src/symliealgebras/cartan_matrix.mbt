///|
/// Cartan matrix accessors.

///|
/// Compute the Cartan matrix for a Cartan type string such as `A3`.
pub fn cartan_matrix(ct : CartanType) -> Matrix raise {
  ct.cartan_matrix()
}

///|
/// Compute the Cartan matrix from a Cartan type string.
pub fn cartan_matrix_from_string(ct : String) -> Matrix raise {
  cartan_type_from_string(ct).cartan_matrix()
}

///|
/// Compute the Cartan matrix from `(series, rank)`.
pub fn cartan_matrix_from_parts(series : String, n : Int) -> Matrix raise {
  cartan_type_from_parts(series, n).cartan_matrix()
}
