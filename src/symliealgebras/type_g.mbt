///|
/// Type G simple Lie algebra data.

///|
pub fn type_g_dimension(_n : Int) -> Int {
  3
}

///|
pub fn type_g_simple_root(_n : Int, i : Int) -> RootVector raise {
  if i < 1 || i > 2 {
    fail("simple root index out of range")
  }
  if i == 1 {
    return vec_from_ints([0, 1, -1])
  }
  vec_from_ints([1, -2, 1])
}

///|
pub fn type_g_positive_roots(_n : Int) -> Map[Int, RootVector] {
  let roots : Map[Int, RootVector] = {}
  roots[1] = vec_from_ints([0, 1, -1])
  roots[2] = vec_from_ints([1, -2, 1])
  roots[3] = vec_from_ints([1, -1, 0])
  roots[4] = vec_from_ints([1, 0, 1])
  roots[5] = vec_from_ints([1, 1, -2])
  roots[6] = vec_from_ints([2, -1, -1])
  roots
}

///|
pub fn type_g_roots(_n : Int) -> Int {
  12
}

///|
pub fn type_g_basis(_n : Int) -> Int {
  14
}

///|
pub fn type_g_dynkin_diagram(_n : Int) -> String {
  dynkin_type_g()
}
