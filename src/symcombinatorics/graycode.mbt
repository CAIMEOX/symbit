///|
/// Gray code utilities.

///|
pub struct GrayCode {
  n : Int
  mut current_val : Int
  mut skip_next : Bool
  mut rank_cache : Int?
}

///|
pub fn GrayCode::new(
  n : Int,
  start? : String,
  rank? : Int,
) -> GrayCode raise CombinatoricsError {
  if n < 1 {
    raise CombinatoricsError::ValueError(
      "Gray code dimension must be a positive integer",
    )
  }
  let mut current_str = int_to_bin(0, n)
  let mut rank_cache : Int? = None
  if start is Some(start_str) {
    if start_str.length() > n {
      raise CombinatoricsError::ValueError(
        "Gray code start has length \{start_str.length()} but should not be greater than \{n}",
      )
    }
    current_str = start_str
  } else if rank is Some(r) {
    if r < 0 {
      raise CombinatoricsError::ValueError(
        "Gray code rank must be non-negative",
      )
    }
    let selections = pow_int(2, n)
    let rr = if selections == 0 { 0 } else { r % selections }
    current_str = GrayCode::unrank(n, rr)
    rank_cache = Some(rr)
  }
  let current_val = bin_to_int(current_str)
  { n, current_val, skip_next: false, rank_cache }
}

///|
pub fn GrayCode::selections(self : GrayCode) -> Int {
  pow_int(2, self.n)
}

///|
pub fn GrayCode::current(self : GrayCode) -> String {
  int_to_bin(self.current_val, self.n)
}

///|
pub fn GrayCode::rank(self : GrayCode) -> Int {
  match self.rank_cache {
    Some(r) => r
    None => {
      let bin = gray_to_bin(self.current())
      let r = bin_to_int(bin)
      r
    }
  }
}

///|
pub fn GrayCode::next(
  self : GrayCode,
  delta? : Int = 1,
) -> GrayCode raise CombinatoricsError {
  let selections = self.selections()
  let mut next_rank = self.rank() + delta
  if selections > 0 {
    next_rank = (next_rank % selections + selections) % selections
  }
  GrayCode::new(self.n, rank=next_rank)
}

///|
pub fn GrayCode::skip(self : GrayCode) -> Unit {
  self.skip_next = true
}

///|
pub fn GrayCode::generate_gray(
  self : GrayCode,
  start? : String,
  rank? : Int,
) -> Array[String] raise CombinatoricsError {
  let bits = self.n
  let mut start_str = self.current()
  if start is Some(start_str_hint) {
    start_str = start_str_hint
  } else if rank is Some(rank_hint) {
    start_str = GrayCode::unrank(bits, rank_hint)
  }
  let graycode_bin = gray_to_bin(start_str)
  if graycode_bin.length() > bits {
    raise CombinatoricsError::ValueError(
      "Gray code start has length \{graycode_bin.length()} but should not be greater than \{bits}",
    )
  }
  self.current_val = bin_to_int(start_str)
  let start_rank = bin_to_int(graycode_bin)
  let out : Array[String] = Array::new()
  let mut skip_once = self.skip_next
  self.skip_next = false
  let mut i = start_rank
  let limit = 1 << bits
  let mut current_val = self.current_val
  while i < limit {
    if skip_once {
      skip_once = false
    } else {
      out.push(int_to_bin(current_val, bits))
    }
    let bbtc = i ^ (i + 1)
    let gbtc = bbtc ^ (bbtc >> 1)
    current_val = current_val ^ gbtc
    i = i + 1
  }
  self.current_val = 0
  self.rank_cache = None
  out
}

///|
pub fn GrayCode::unrank(n : Int, rank : Int) -> String {
  fn rec(k : Int, n : Int) -> String {
    if n == 1 {
      return if (k & 1) == 1 { "1" } else { "0" }
    }
    let m = 1 << (n - 1)
    if k < m {
      return "0" + rec(k, n - 1)
    }
    "1" + rec(m - k % m - 1, n - 1)
  }

  rec(rank, n)
}

///|
pub fn gray_to_bin(bits : String) -> String {
  if bits.is_empty() {
    return ""
  }
  let chars = string_to_chars(bits)
  let out : Array[Char] = Array::new()
  out.push(chars[0])
  for i in 1..<chars.length() {
    let prev = out[i - 1]
    let bit = if prev != chars[i] { '1' } else { '0' }
    out.push(bit)
  }
  chars_to_string(out)
}

///|
pub fn bin_to_gray(bits : String) -> String {
  if bits.is_empty() {
    return ""
  }
  let chars = string_to_chars(bits)
  let out : Array[Char] = Array::new()
  out.push(chars[0])
  for i in 1..<chars.length() {
    let bit = if chars[i] == chars[i - 1] { '0' } else { '1' }
    out.push(bit)
  }
  chars_to_string(out)
}

///|
pub fn random_bitstring(n : Int, seed? : Int) -> String {
  let mut state = match seed {
    Some(v) => v
    None => n * 1103515245 + 12345
  }
  let chars : Array[Char] = Array::make(n, '0')
  for i in 0..<n {
    state = (state * 1103515245 + 12345) & 0x7fffffff
    chars.set(i, if (state & 1) == 1 { '1' } else { '0' })
  }
  chars_to_string(chars)
}

///|
pub fn[T] get_subset_from_bitstring(
  super_set : Array[T],
  bitstring : String,
) -> Array[T] raise CombinatoricsError {
  if super_set.length() != bitstring.length() {
    raise CombinatoricsError::ValueError("The sizes of the lists are not equal")
  }
  let bits = string_to_chars(bitstring)
  let out : Array[T] = Array::new()
  for i in 0..<bits.length() {
    if bits[i] == '1' {
      out.push(super_set[i])
    }
  }
  out
}

///|
pub fn[T] graycode_subsets(
  gray_code_set : Array[T],
) -> Array[Array[T]] raise CombinatoricsError {
  let codes = GrayCode::new(gray_code_set.length()).generate_gray()
  let out : Array[Array[T]] = Array::new()
  for bitstring in codes {
    out.push(get_subset_from_bitstring(gray_code_set, bitstring))
  }
  out
}
