///|
/// Type C simple Lie algebra data.

///|
pub fn type_c_dimension(n : Int) -> Int {
  n
}

///|
pub fn type_c_basic_root(n : Int, i : Int, j : Int) -> RootVector {
  let root = vec_zero(n)
  root[i] = br_int(1)
  root[j] = br_int(-1)
  root
}

///|
pub fn type_c_simple_root(n : Int, i : Int) -> RootVector raise {
  if i < 1 || i > n {
    fail("simple root index out of range")
  }
  if i < n {
    type_c_basic_root(n, i - 1, i)
  } else {
    let root = vec_zero(n)
    root[n - 1] = br_int(2)
    root
  }
}

///|
pub fn type_c_positive_roots(n : Int) -> Map[Int, RootVector] {
  let posroots : Map[Int, RootVector] = {}
  let mut k = 0
  for i in 0..<(n - 1) {
    for j in (i + 1)..<n {
      k += 1
      let root = type_c_basic_root(n, i, j)
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
    root[i] = br_int(2)
    posroots[k] = root
  }
  posroots
}

///|
pub fn type_c_roots(n : Int) -> Int {
  2 * (n * n)
}

///|
pub fn type_c_basis(n : Int) -> Int {
  n * (2 * n + 1)
}

///|
pub fn type_c_lie_algebra(n : Int) -> String {
  let dim = 2 * n
  "sp(\{dim.to_string()})"
}

///|
pub fn type_c_dynkin_diagram(n : Int) -> String {
  dynkin_type_c(n)
}
