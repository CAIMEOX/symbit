///|
fn pow_int(base : Int, exp : Int) -> Int {
  if exp < 0 {
    return 0
  }
  let mut result = 1
  let mut b = base
  let mut e = exp
  while e > 0 {
    if (e & 1) == 1 {
      result = result * b
    }
    b = b * b
    e = e >> 1
  }
  result
}

///|
fn string_to_chars(s : String) -> Array[Char] {
  let chars : Array[Char] = Array::new()
  for c in s {
    chars.push(c)
  }
  chars
}

///|
fn chars_to_string(chars : Array[Char]) -> String {
  let sb = StringBuilder::new()
  for c in chars {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
fn bin_to_int(bits : String) -> Int {
  let mut value = 0
  for c in bits {
    value = value * 2 + (if c == '1' { 1 } else { 0 })
  }
  value
}

///|
fn int_to_bin(value : Int, width : Int) -> String {
  if width <= 0 {
    return ""
  }
  let mut v = value
  let chars : Array[Char] = Array::make(width, '0')
  for i in 0..<width {
    let bit = v & 1
    let idx = width - 1 - i
    chars.set(idx, if bit == 1 { '1' } else { '0' })
    v = v >> 1
  }
  chars_to_string(chars)
}

///|
fn[T] array_reverse(values : Array[T]) -> Array[T] {
  let out : Array[T] = Array::new()
  if values.is_empty() {
    return out
  }
  let mut i = values.length() - 1
  while i >= 0 {
    out.push(values[i])
    i = i - 1
  }
  out
}
