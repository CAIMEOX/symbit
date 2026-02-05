///|
/// Index helpers for arrays.

///|
fn index_key(index : Array[Int]) -> String {
  if index.is_empty() {
    return ""
  }
  let parts = index.map((v) => "\{v}")
  parts.join(",")
}

///|
fn index_in_bounds(shape : Array[Int], index : Array[Int]) -> Bool {
  if shape.length() != index.length() {
    return false
  }
  for i in 0..<shape.length() {
    let dim = shape[i]
    let idx = index[i]
    if idx < 0 || idx >= dim {
      return false
    }
  }
  true
}

///|
fn linear_index(shape : Array[Int], index : Array[Int]) -> Int {
  let mut idx = 0
  for i in 0..<shape.length() {
    idx = idx * shape[i] + index[i]
  }
  idx
}

///|
fn parse_int_simple(s : StringView) -> Int {
  let text = s.to_string()
  if text.is_empty() {
    return 0
  }
  let mut sign = 1
  let mut start = 0
  if text[0] == '-' {
    sign = -1
    start = 1
  }
  let mut value = 0
  for i in start..<text.length() {
    let c = text[i]
    if c >= '0' && c <= '9' {
      value = value * 10 + (c.to_int() - '0'.to_int())
    }
  }
  sign * value
}

///|
fn compute_strides(shape : Array[Int]) -> Array[Int] {
  let n = shape.length()
  let strides : Array[Int] = Array::new()
  for _ in 0..<n {
    strides.push(0)
  }
  if n == 0 {
    return strides
  }
  let mut acc = 1
  let mut i = n - 1
  while true {
    strides[i] = acc
    acc = acc * shape[i]
    if i == 0 {
      break
    }
    i = i - 1
  }
  strides
}

///|
fn all_indices(shape : Array[Int]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = Array::new()
  if shape.is_empty() {
    out.push([])
    return out
  }
  fn go(shape : Array[Int], dim : Int, prefix : Array[Int], out : Array[Array[Int]]) -> Unit {
    if dim == shape.length() {
      out.push(prefix)
      return
    }
    for i in 0..<shape[dim] {
      let next : Array[Int] = Array::new()
      for v in prefix {
        next.push(v)
      }
      next.push(i)
      go(shape, dim + 1, next, out)
    }
  }
  go(shape, 0, [], out)
  out
}
