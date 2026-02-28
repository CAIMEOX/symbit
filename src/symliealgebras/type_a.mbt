///|
/// Type A simple Lie algebra data.

///|
/// Dimension of the ambient Euclidean realization for this Cartan family.
pub fn type_a_dimension(n : Int) -> Int {
  n + 1
}

///|
/// Internal helper that builds a basic coordinate root vector.
pub fn type_a_basic_root(n : Int, i : Int, j : Int) -> RootVector {
  let root = vec_zero(n + 1)
  root[i] = br_int(1)
  root[j] = br_int(-1)
  root
}

///|
/// Return the `i`-th simple root in the family-specific realization.
pub fn type_a_simple_root(n : Int, i : Int) -> RootVector raise {
  if i < 1 || i > n {
    fail("simple root index out of range")
  }
  type_a_basic_root(n, i - 1, i)
}

///|
/// Enumerate positive roots indexed from `1`.
pub fn type_a_positive_roots(n : Int) -> Map[Int, RootVector] {
  let posroots : Map[Int, RootVector] = {}
  let mut k = 0
  for i in 0..<n {
    for j in (i + 1)..<=n {
      k += 1
      posroots[k] = type_a_basic_root(n, i, j)
    }
  }
  posroots
}

///|
/// Return the highest root in the selected realization.
pub fn type_a_highest_root(n : Int) -> RootVector {
  type_a_basic_root(n, 0, n)
}

///|
/// Total number of roots in the root system.
pub fn type_a_roots(n : Int) -> Int {
  n * (n + 1)
}

///|
/// Dimension of the corresponding Lie algebra.
pub fn type_a_basis(n : Int) -> Int {
  n * n - 1
}

///|
/// Conventional Lie algebra name for this Cartan family.
pub fn type_a_lie_algebra(n : Int) -> String {
  let dim = n + 1
  "su(\{dim.to_string()})"
}

///|
/// Text form of the family Dynkin diagram.
pub fn type_a_dynkin_diagram(n : Int) -> String {
  dynkin_type_a(n)
}
