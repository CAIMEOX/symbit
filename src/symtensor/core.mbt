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
/// Multiply all integers in `values`.
///
/// This is commonly used to turn a tensor shape into a total element count.
pub fn product_ints(values : Array[Int]) -> Int {
  let mut p = 1
  for v in values {
    p = p * v
  }
  p
}

///|
/// Render an integer shape as a comma-separated cache key.
///
/// For example, `[2, 3, 4]` becomes `"2,3,4"`.
pub fn shape_key(values : Array[Int]) -> String {
  if values.is_empty() {
    return ""
  }
  let parts = values.map(v => "\{v}")
  parts.join(",")
}
