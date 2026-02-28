///|
/// Type B simple Lie algebra data.

///|
/// Ambient-space dimension for the `B_n` root realization.
pub fn type_b_dimension(n : Int) -> Int {
  n
}

///|
/// Build the coordinate root `e_i - e_j` in `B_n`.
pub fn type_b_basic_root(n : Int, i : Int, j : Int) -> RootVector {
  let root = vec_zero(n)
  root[i] = br_int(1)
  root[j] = br_int(-1)
  root
}

///|
/// Return the `i`-th simple root of `B_n`.
pub fn type_b_simple_root(n : Int, i : Int) -> RootVector raise {
  if i < 1 || i > n {
    fail("simple root index out of range")
  }
  if i < n {
    type_b_basic_root(n, i - 1, i)
  } else {
    let root = vec_zero(n)
    root[n - 1] = br_int(1)
    root
  }
}

///|
/// Enumerate positive roots of `B_n`, indexed from `1`.
pub fn type_b_positive_roots(n : Int) -> Map[Int, RootVector] {
  let posroots : Map[Int, RootVector] = {}
  let mut k = 0
  for i in 0..<(n - 1) {
    for j in (i + 1)..<n {
      k += 1
      let root = type_b_basic_root(n, i, j)
      posroots[k] = root
      k += 1
      let root2 = vec_copy(root)
      root2[j] = br_int(1)
      posroots[k] = root2
    }
  }
  for i in 0..<n {
    k += 1
    let root = vec_zero(n)
    root[i] = br_int(1)
    posroots[k] = root
  }
  posroots
}

///|
/// Return the total number of roots in `B_n`.
pub fn type_b_roots(n : Int) -> Int {
  2 * (n * n)
}

///|
/// Return `dim(so_{2n+1})`.
pub fn type_b_basis(n : Int) -> Int {
  (n * n - n) / 2
}

///|
/// Return the compact real-form label used for `B_n`.
pub fn type_b_lie_algebra(n : Int) -> String {
  let dim = 2 * n
  "so(\{dim.to_string()})"
}

///|
/// Return the Dynkin diagram text for `B_n`.
pub fn type_b_dynkin_diagram(n : Int) -> String {
  dynkin_type_b(n)
}
