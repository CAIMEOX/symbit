///|
/// Shared helpers for lie algebras.

///|
pub type RootVector = Array[@symnum.BigRational]

///|
pub fn br_int(value : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_int(value)
}

///|
pub fn br_rat(num : Int, den : Int) -> @symnum.BigRational {
  let n = @bigint.BigInt::from_int(num)
  let d = @bigint.BigInt::from_int(den)
  try! @symnum.BigRational::new(n, d)
}

///|
pub fn vec_from_ints(values : Array[Int]) -> RootVector {
  let out : RootVector = Array::new()
  for v in values {
    out.push(br_int(v))
  }
  out
}

///|
pub fn vec_zero(length : Int) -> RootVector {
  Array::make(length, br_int(0))
}

///|
pub fn vec_copy(values : RootVector) -> RootVector {
  values.copy()
}

///|
pub fn vec_add(lhs : RootVector, rhs : RootVector) -> RootVector {
  let len = lhs.length()
  let out = Array::make(len, br_int(0))
  for i in 0..<len {
    out[i] = lhs[i] + rhs[i]
  }
  out
}

///|
pub fn vec_neg(values : RootVector) -> RootVector {
  let len = values.length()
  let out = Array::make(len, br_int(0))
  for i in 0..<len {
    out[i] = -values[i]
  }
  out
}

///|
pub fn vec_equal(lhs : RootVector, rhs : RootVector) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for i in 0..<lhs.length() {
    if lhs[i] != rhs[i] {
      return false
    }
  }
  true
}

///|
pub fn vec_to_string_list(values : RootVector) -> Array[String] {
  let out : Array[String] = Array::new()
  for v in values {
    out.push(v.to_string())
  }
  out
}

///|
pub fn vec_string(values : RootVector) -> String {
  if values.is_empty() {
    return "[]"
  }
  let parts = vec_to_string_list(values)
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
pub fn roots_map_string(roots : Map[Int, RootVector]) -> String {
  if roots.is_empty() {
    return "{}"
  }
  let keys : Array[Int] = Array::new()
  for k, _ in roots {
    keys.push(k)
  }
  keys.sort()
  let parts : Array[String] = Array::new()
  for k in keys {
    parts.push("\{k}: \{vec_string(roots[k])}")
  }
  let joined = parts.join(", ")
  "{\{joined}}"
}
