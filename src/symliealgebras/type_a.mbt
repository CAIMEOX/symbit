///|
/// Type A simple Lie algebra data.

///|
pub fn type_a_dimension(n : Int) -> Int {
  n + 1
}

///|
pub fn type_a_basic_root(n : Int, i : Int, j : Int) -> RootVector {
  let root = vec_zero(n + 1)
  root[i] = br_int(1)
  root[j] = br_int(-1)
  root
}

///|
pub fn type_a_simple_root(n : Int, i : Int) -> RootVector raise {
  if i < 1 || i > n {
    fail("simple root index out of range")
  }
  type_a_basic_root(n, i - 1, i)
}

///|
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
pub fn type_a_highest_root(n : Int) -> RootVector {
  type_a_basic_root(n, 0, n)
}

///|
pub fn type_a_roots(n : Int) -> Int {
  n * (n + 1)
}

///|
pub fn type_a_basis(n : Int) -> Int {
  n * n - 1
}

///|
pub fn type_a_lie_algebra(n : Int) -> String {
  let dim = n + 1
  "su(\{dim.to_string()})"
}

///|
pub fn type_a_dynkin_diagram(n : Int) -> String {
  dynkin_type_a(n)
}
