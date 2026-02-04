///|
/// Cartan types for simple Lie algebras.

///|
pub struct CartanType {
  series : String
  n : Int
}

///|
fn cartan_type_validate(series : String, n : Int) -> Unit raise {
  if n < 0 {
    fail("Lie algebra rank cannot be negative")
  }
  match series {
    "A" => if n < 1 { fail("n cannot be less than 1") }
    "B" => if n < 2 { fail("n cannot be less than 2") }
    "C" => if n < 3 { fail("n cannot be less than 3") }
    "D" => if n < 3 { fail("n cannot be less than 3") }
    "E" => if n < 6 || n > 8 { fail("Invalid value of n") }
    "F" => if n != 4 { fail("n should be 4") }
    "G" => if n != 2 { fail("n should be 2") }
    _ => fail("Unknown Cartan series")
  }
}

///|
pub fn cartan_type_from_parts(series : String, n : Int) -> CartanType raise {
  cartan_type_validate(series, n)
  CartanType::{ series, n }
}

///|
pub fn cartan_type_from_string(ct : String) -> CartanType raise {
  if ct.is_empty() {
    fail("Argument must be a string like 'A3'")
  }
  let first = match ct.get_char(0) {
    Some(c) => c
    None => fail("Argument must be a string like 'A3'")
  }
  let series = "\{first}"
  let len = ct.length()
  if len <= 1 {
    fail("Argument must be a string like 'A3'")
  }
  let num_str = (try! ct[1:len]).to_string()
  let n = @strconv.parse_int(num_str, base=10)
  cartan_type_from_parts(series, n)
}

///|
pub fn CartanType::rank(self : CartanType) -> Int {
  self.n
}

///|
pub fn CartanType::series(self : CartanType) -> String {
  self.series
}

///|
pub fn CartanType::dimension(self : CartanType) -> Int {
  match self.series {
    "A" => type_a_dimension(self.n)
    "B" => type_b_dimension(self.n)
    "C" => type_c_dimension(self.n)
    "D" => type_d_dimension(self.n)
    "E" => type_e_dimension(self.n)
    "F" => type_f_dimension(self.n)
    "G" => type_g_dimension(self.n)
    _ => panic()
  }
}

///|
pub fn CartanType::simple_root(self : CartanType, i : Int) -> RootVector raise {
  match self.series {
    "A" => type_a_simple_root(self.n, i)
    "B" => type_b_simple_root(self.n, i)
    "C" => type_c_simple_root(self.n, i)
    "D" => type_d_simple_root(self.n, i)
    "E" => type_e_simple_root(self.n, i)
    "F" => type_f_simple_root(self.n, i)
    "G" => type_g_simple_root(self.n, i)
    _ => fail("Unknown Cartan series")
  }
}

///|
pub fn CartanType::positive_roots(self : CartanType) -> Map[Int, RootVector] {
  match self.series {
    "A" => type_a_positive_roots(self.n)
    "B" => type_b_positive_roots(self.n)
    "C" => type_c_positive_roots(self.n)
    "D" => type_d_positive_roots(self.n)
    "E" => type_e_positive_roots(self.n)
    "F" => type_f_positive_roots(self.n)
    "G" => type_g_positive_roots(self.n)
    _ => panic()
  }
}

///|
pub fn CartanType::highest_root(self : CartanType) -> RootVector raise {
  match self.series {
    "A" => type_a_highest_root(self.n)
    _ => fail("highest root only defined for A series")
  }
}

///|
pub fn CartanType::roots(self : CartanType) -> Int {
  match self.series {
    "A" => type_a_roots(self.n)
    "B" => type_b_roots(self.n)
    "C" => type_c_roots(self.n)
    "D" => type_d_roots(self.n)
    "E" => type_e_roots(self.n)
    "F" => type_f_roots(self.n)
    "G" => type_g_roots(self.n)
    _ => panic()
  }
}

///|
pub fn CartanType::basis(self : CartanType) -> Int {
  match self.series {
    "A" => type_a_basis(self.n)
    "B" => type_b_basis(self.n)
    "C" => type_c_basis(self.n)
    "D" => type_d_basis(self.n)
    "E" => type_e_basis(self.n)
    "F" => type_f_basis(self.n)
    "G" => type_g_basis(self.n)
    _ => panic()
  }
}

///|
pub fn CartanType::lie_algebra(self : CartanType) -> String {
  match self.series {
    "A" => type_a_lie_algebra(self.n)
    "B" => type_b_lie_algebra(self.n)
    "C" => type_c_lie_algebra(self.n)
    "D" => type_d_lie_algebra(self.n)
    _ => panic()
  }
}

///|
pub fn CartanType::cartan_matrix(self : CartanType) -> Matrix raise {
  match self.series {
    "A" => cartan_matrix_type_a(self.n)
    "B" => cartan_matrix_type_b(self.n)
    "C" => cartan_matrix_type_c(self.n)
    "D" => cartan_matrix_type_d(self.n)
    "E" => cartan_matrix_type_e(self.n)
    "F" => cartan_matrix_type_f()
    "G" => cartan_matrix_type_g()
    _ => fail("Unknown Cartan series")
  }
}

///|
pub fn CartanType::dynkin_diagram(self : CartanType) -> String raise {
  match self.series {
    "A" => dynkin_type_a(self.n)
    "B" => dynkin_type_b(self.n)
    "C" => dynkin_type_c(self.n)
    "D" => dynkin_type_d(self.n)
    "E" => dynkin_type_e(self.n)
    "F" => dynkin_type_f()
    "G" => dynkin_type_g()
    _ => fail("Unknown Cartan series")
  }
}

///|
fn cartan_matrix_type_a(n : Int) -> Matrix {
  let m = matrix_eye(n)
  for i in 0..<n {
    m.set(i, i, br_int(2))
  }
  if n > 1 {
    for i in 1..<(n - 1) {
      m.set(i, i + 1, br_int(-1))
      m.set(i, i - 1, br_int(-1))
    }
    m.set(0, 1, br_int(-1))
    m.set(n - 1, n - 2, br_int(-1))
  }
  m
}

///|
fn cartan_matrix_type_b(n : Int) -> Matrix {
  let m = matrix_eye(n)
  for i in 0..<n {
    m.set(i, i, br_int(2))
  }
  if n > 1 {
    for i in 1..<(n - 1) {
      m.set(i, i + 1, br_int(-1))
      m.set(i, i - 1, br_int(-1))
    }
    m.set(0, 1, br_int(-1))
    m.set(n - 2, n - 1, br_int(-2))
    m.set(n - 1, n - 2, br_int(-1))
  }
  m
}

///|
fn cartan_matrix_type_c(n : Int) -> Matrix {
  let m = matrix_eye(n)
  for i in 0..<n {
    m.set(i, i, br_int(2))
  }
  if n > 1 {
    for i in 1..<(n - 1) {
      m.set(i, i + 1, br_int(-1))
      m.set(i, i - 1, br_int(-1))
    }
    m.set(0, 1, br_int(-1))
    m.set(n - 1, n - 2, br_int(-2))
  }
  m
}

///|
fn cartan_matrix_type_d(n : Int) -> Matrix {
  let m = matrix_eye(n)
  for i in 0..<n {
    m.set(i, i, br_int(2))
  }
  if n > 2 {
    for i in 1..<(n - 2) {
      m.set(i, i + 1, br_int(-1))
      m.set(i, i - 1, br_int(-1))
    }
    m.set(n - 2, n - 3, br_int(-1))
    m.set(n - 3, n - 1, br_int(-1))
    m.set(n - 1, n - 3, br_int(-1))
    m.set(0, 1, br_int(-1))
  }
  m
}

///|
fn cartan_matrix_type_e(n : Int) -> Matrix {
  let m = matrix_eye(n)
  for i in 0..<n {
    m.set(i, i, br_int(2))
  }
  for i in 3..<(n - 1) {
    m.set(i, i + 1, br_int(-1))
    m.set(i, i - 1, br_int(-1))
  }
  m.set(0, 2, br_int(-1))
  m.set(2, 0, br_int(-1))
  m.set(1, 3, br_int(-1))
  m.set(3, 1, br_int(-1))
  m.set(2, 3, br_int(-1))
  m.set(n - 1, n - 2, br_int(-1))
  m
}

///|
fn cartan_matrix_type_f() -> Matrix {
  matrix_from_ints([
    [2, -1, 0, 0],
    [-1, 2, -2, 0],
    [0, -1, 2, -1],
    [0, 0, -1, 2],
  ])
}

///|
fn cartan_matrix_type_g() -> Matrix {
  matrix_from_ints([[2, -1], [-3, 2]])
}

///|
fn dynkin_type_a(n : Int) -> String {
  let zeros : Array[String] = Array::new()
  let nums : Array[String] = Array::new()
  for i in 1..<=n {
    zeros.push("0")
    nums.push(i.to_string())
  }
  let top = zeros.join("---")
  let bottom = nums.join("   ")
  "\{top}\n\{bottom}"
}

///|
fn dynkin_type_b(n : Int) -> String {
  let zeros : Array[String] = Array::new()
  let nums : Array[String] = Array::new()
  for i in 1..<n {
    zeros.push("0")
  }
  for i in 1..<=n {
    nums.push(i.to_string())
  }
  let chain = zeros.join("---")
  let top = "\{chain}=>=0"
  let bottom = nums.join("   ")
  "\{top}\n\{bottom}"
}

///|
fn dynkin_type_c(n : Int) -> String {
  let zeros : Array[String] = Array::new()
  let nums : Array[String] = Array::new()
  for i in 1..<n {
    zeros.push("0")
  }
  for i in 1..<=n {
    nums.push(i.to_string())
  }
  let chain = zeros.join("---")
  let top = "\{chain}=<=0"
  let bottom = nums.join("   ")
  "\{top}\n\{bottom}"
}

///|
fn dynkin_type_d(n : Int) -> String {
  let pad = StringBuilder::new()
  for _ in 0..<(4 * (n - 3)) {
    pad.write_char(' ')
  }
  let pad_str = pad.to_string()
  let mut diag = "\{pad_str}\{(n - 1).to_string()}\n"
  diag = diag + "\{pad_str}0\n"
  diag = diag + "\{pad_str}|\n"
  diag = diag + "\{pad_str}|\n"
  let zeros : Array[String] = Array::new()
  for _ in 1..<n {
    zeros.push("0")
  }
  let chain = zeros.join("---")
  diag = diag + "\{chain}\n"
  let nums : Array[String] = Array::new()
  for i in 1..<(n - 1) {
    nums.push(i.to_string())
  }
  let bottom = nums.join("   ")
  diag = diag + "\{bottom}   \{n.to_string()}"
  diag
}

///|
fn dynkin_type_e(n : Int) -> String {
  let mut diag = "        2\n"
  diag = diag + "        0\n"
  diag = diag + "        |\n"
  diag = diag + "        |\n"
  let zeros : Array[String] = Array::new()
  for _ in 1..<n {
    zeros.push("0")
  }
  let chain = zeros.join("---")
  diag = diag + "\{chain}\n"
  let tail : Array[String] = Array::new()
  for i in 3..<=n {
    tail.push(i.to_string())
  }
  let tail_joined = tail.join("   ")
  diag + "1   \{tail_joined}"
}

///|
fn dynkin_type_f() -> String {
  let mut diag = "0---0=>=0---0\n"
  let nums : Array[String] = Array::new()
  for i in 1..<=4 {
    nums.push(i.to_string())
  }
  diag = diag + nums.join("   ")
  diag
}

///|
fn dynkin_type_g() -> String {
  "0≡<≡0\n1   2"
}
