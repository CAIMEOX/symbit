///|
/// Shared helpers for symtensor.

///|
pub fn clone_int_array(values : Array[Int]) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for v in values {
    out.push(v)
  }
  out
}

///|
pub fn product_ints(values : Array[Int]) -> Int {
  let mut p = 1
  for v in values {
    p = p * v
  }
  p
}

///|
pub fn shape_key(values : Array[Int]) -> String {
  if values.is_empty() {
    return ""
  }
  let parts = values.map((v) => "\{v}")
  parts.join(",")
}
