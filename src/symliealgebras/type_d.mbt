///|
/// Type D simple Lie algebra data.

///|
/// Dimension of the ambient Euclidean realization for this Cartan family.
pub fn type_d_dimension(n : Int) -> Int {
  n
}

///|
/// Internal helper that builds a basic coordinate root vector.
pub fn type_d_basic_root(n : Int, i : Int, j : Int) -> RootVector {
  let root = vec_zero(n)
  root[i] = br_int(1)
  root[j] = br_int(-1)
  root
}

///|
/// Return the `i`-th simple root in the family-specific realization.
pub fn type_d_simple_root(n : Int, i : Int) -> RootVector raise {
  if i < 1 || i > n {
    fail("simple root index out of range")
  }
  if i < n {
    type_d_basic_root(n, i - 1, i)
  } else {
    let root = vec_zero(n)
    root[n - 2] = br_int(1)
    root[n - 1] = br_int(1)
    root
  }
}

///|
/// Enumerate positive roots indexed from `1`.
pub fn type_d_positive_roots(n : Int) -> Map[Int, RootVector] {
  let posroots : Map[Int, RootVector] = {}
  let mut k = 0
  for i in 0..<(n - 1) {
    for j in (i + 1)..<n {
      k += 1
      let root = type_d_basic_root(n, i, j)
      posroots[k] = root
      k += 1
      let root2 = vec_copy(root)
      root2[j] = br_int(1)
      posroots[k] = root2
    }
  }
  posroots
}

///|
/// Total number of roots in the root system.
pub fn type_d_roots(n : Int) -> Int {
  2 * n * (n - 1)
}

///|
/// Dimension of the corresponding Lie algebra.
pub fn type_d_basis(n : Int) -> Int {
  n * (n - 1) / 2
}

///|
/// Conventional Lie algebra name for this Cartan family.
pub fn type_d_lie_algebra(n : Int) -> String {
  let dim = 2 * n
  "so(\{dim.to_string()})"
}

///|
/// Text form of the family Dynkin diagram.
pub fn type_d_dynkin_diagram(n : Int) -> String {
  dynkin_type_d(n)
}
