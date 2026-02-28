///|
/// Type F simple Lie algebra data.

///|
/// Ambient-space dimension for the exceptional `F_4` realization.
pub fn type_f_dimension(_n : Int) -> Int {
  4
}

///|
/// Build the coordinate root `e_i - e_j` in the `F_4` model.
pub fn type_f_basic_root(n : Int, i : Int, j : Int) -> RootVector {
  let root = vec_zero(n)
  root[i] = br_int(1)
  root[j] = br_int(-1)
  root
}

///|
/// Return the `i`-th simple root of `F_4`.
pub fn type_f_simple_root(_n : Int, i : Int) -> RootVector raise {
  if i < 1 || i > 4 {
    fail("simple root index out of range")
  }
  if i < 3 {
    return type_f_basic_root(4, i - 1, i)
  }
  if i == 3 {
    let root = vec_zero(4)
    root[3] = br_int(1)
    return root
  }
  Array::make(4, br_rat(-1, 2))
}

///|
/// Enumerate positive roots of `F_4`, indexed from `1`.
pub fn type_f_positive_roots(n : Int) -> Map[Int, RootVector] {
  let posroots : Map[Int, RootVector] = {}
  let mut k = 0
  for i in 0..<(n - 1) {
    for j in (i + 1)..<n {
      k += 1
      let root = type_f_basic_root(n, i, j)
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
  let half = br_rat(1, 2)
  let neg_half = br_rat(-1, 2)
  k += 1
  posroots[k] = Array::make(n, half)
  for i in 1..<4 {
    k += 1
    let root = Array::make(n, half)
    root[i] = neg_half
    posroots[k] = root
  }
  posroots[k + 1] = [half, half, neg_half, neg_half]
  posroots[k + 2] = [half, neg_half, half, neg_half]
  posroots[k + 3] = [half, neg_half, neg_half, half]
  posroots[k + 4] = [half, neg_half, neg_half, neg_half]
  posroots
}

///|
/// Return the total number of roots in `F_4`.
pub fn type_f_roots(_n : Int) -> Int {
  48
}

///|
/// Return `dim(F_4)`.
pub fn type_f_basis(_n : Int) -> Int {
  52
}

///|
/// Return the Dynkin diagram text for `F_4`.
pub fn type_f_dynkin_diagram(_n : Int) -> String {
  dynkin_type_f()
}
