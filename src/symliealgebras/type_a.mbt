///|
/// Type A simple Lie algebra data.

///|
/// Ambient-space dimension for the `A_n` root realization.
pub fn type_a_dimension(n : Int) -> Int {
  n + 1
}

///|
/// Build the coordinate root `e_i - e_j` in `A_n`.
pub fn type_a_basic_root(n : Int, i : Int, j : Int) -> RootVector {
  let root = vec_zero(n + 1)
  root[i] = br_int(1)
  root[j] = br_int(-1)
  root
}

///|
/// Return the `i`-th simple root of `A_n`.
pub fn type_a_simple_root(n : Int, i : Int) -> RootVector raise {
  if i < 1 || i > n {
    fail("simple root index out of range")
  }
  type_a_basic_root(n, i - 1, i)
}

///|
/// Enumerate positive roots of `A_n`, indexed from `1`.
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
/// Return the total number of roots in `A_n`.
pub fn type_a_roots(n : Int) -> Int {
  n * (n + 1)
}

///|
/// Return `dim(sl_{n+1})`.
pub fn type_a_basis(n : Int) -> Int {
  n * n - 1
}

///|
/// Return the compact real-form label used for `A_n`.
pub fn type_a_lie_algebra(n : Int) -> String {
  let dim = n + 1
  "su(\{dim.to_string()})"
}

///|
/// Return the Dynkin diagram text for `A_n`.
pub fn type_a_dynkin_diagram(n : Int) -> String {
  dynkin_type_a(n)
}
