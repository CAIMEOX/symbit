///|
/// Computational-basis qubits aligned with the core of
/// `sympy.physics.quantum.qubit`.
///
/// This file provides symbolic `Qubit(...)` / `QubitBra(...)` constructors,
/// bit manipulation, and exact conversion to and from explicit column/row
/// vectors in the computational basis.

///|
pub struct QubitExpr {
  bits : Array[Int]
  is_bra : Bool
  int_form : Bool
} derive(Eq)

///|
fn qubit_bits_to_string(bits : Array[Int]) -> String {
  bits.map(bit => bit.to_string()).join("")
}

///|
fn qubit_parse_bits(bits : String) -> Array[Int] raise @symphysics.PhysicsError {
  let out : Array[Int] = []
  for ch in bits.to_array() {
    match ch {
      '0' => out.push(0)
      '1' => out.push(1)
      _ =>
        raise @symphysics.PhysicsError::ValueError(
          "Qubit bits must be a string of 0/1 digits",
        )
    }
  }
  guard !out.is_empty() else {
    raise @symphysics.PhysicsError::ValueError("Qubit needs at least one bit")
  }
  out
}

///|
fn int_to_bits(
  number : Int,
  nqubits : Int,
) -> Array[Int] raise @symphysics.PhysicsError {
  guard number >= 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "IntQubit expects a nonnegative integer",
    )
  }
  guard nqubits > 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "IntQubit expects a positive number of qubits",
    )
  }
  let bits : Array[Int] = Array::make(nqubits, 0)
  for idx in 0..<nqubits {
    let shift = nqubits - 1 - idx
    bits[idx] = (number >> shift) & 1
  }
  bits
}

///|
pub fn qubit(bits : String) -> QubitExpr raise @symphysics.PhysicsError {
  QubitExpr::{ bits: qubit_parse_bits(bits), is_bra: false, int_form: false }
}

///|
pub fn qubit_bra(bits : String) -> QubitExpr raise @symphysics.PhysicsError {
  QubitExpr::{ bits: qubit_parse_bits(bits), is_bra: true, int_form: false }
}

///|
pub fn int_qubit(
  number : Int,
  nqubits : Int,
) -> QubitExpr raise @symphysics.PhysicsError {
  QubitExpr::{
    bits: int_to_bits(number, nqubits),
    is_bra: false,
    int_form: true,
  }
}

///|
pub fn int_qubit_bra(
  number : Int,
  nqubits : Int,
) -> QubitExpr raise @symphysics.PhysicsError {
  QubitExpr::{
    bits: int_to_bits(number, nqubits),
    is_bra: true,
    int_form: true,
  }
}

///|
pub fn qubit_from_bits(
  bits : Array[Int],
  bra? : Bool = false,
  int_form? : Bool = false,
) -> QubitExpr raise @symphysics.PhysicsError {
  for bit in bits {
    guard bit == 0 || bit == 1 else {
      raise @symphysics.PhysicsError::ValueError("Qubit bits must be 0 or 1")
    }
  }
  guard !bits.is_empty() else {
    raise @symphysics.PhysicsError::ValueError("Qubit needs at least one bit")
  }
  QubitExpr::{ bits: bits.copy(), is_bra: bra, int_form }
}

///|
fn bits_to_int(bits : Array[Int]) -> Int {
  let mut out = 0
  for bit in bits {
    out = out * 2 + bit
  }
  out
}

///|
fn int_to_minimal_bits(
  number : Int,
) -> Array[Int] raise @symphysics.PhysicsError {
  guard number >= 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "IntQubit expects a nonnegative integer",
    )
  }
  let nqubits = if number <= 1 {
    1
  } else {
    let mut width = 0
    let mut value = number
    while value > 0 {
      width += 1
      value = value >> 1
    }
    width
  }
  int_to_bits(number, nqubits)
}

///|
fn qubit_exact_rational(num : Int, den : Int) -> Expr {
  let result : Result[Expr, @symnum.RationalError] = try?
    @symcore.rational_from_ints(num, den)
  match result {
    Ok(value) => value
    Err(_) => int(num) * @symcore.raw_pow(int(den), int(-1))
  }
}

///|
pub fn QubitExpr::as_expr(self : QubitExpr) -> Expr {
  if self.int_form {
    let class_name = if self.is_bra { "IntQubitBra" } else { "IntQubit" }
    @symcore.raw_function(class_name, [int(bits_to_int(self.bits))])
  } else {
    let args = self.bits.map(@symcore.int)
    if self.is_bra {
      @symcore.raw_function("QubitBra", args)
    } else {
      @symcore.raw_function("Qubit", args)
    }
  }
}

///|
pub fn QubitExpr::to_string(self : QubitExpr) -> String {
  let contents = if self.int_form {
    bits_to_int(self.bits).to_string()
  } else {
    qubit_bits_to_string(self.bits)
  }
  if self.is_bra {
    "<\{contents}|"
  } else {
    "|\{contents}>"
  }
}

///|
pub fn QubitExpr::repr(self : QubitExpr) -> String {
  if self.int_form {
    let class_name = if self.is_bra { "IntQubitBra" } else { "IntQubit" }
    "\{class_name}(Integer(\{bits_to_int(self.bits).to_string()}))"
  } else {
    let class_name = if self.is_bra { "QubitBra" } else { "Qubit" }
    let rendered = self.bits.map(bit => "Integer(\{bit.to_string()})").join(",")
    "\{class_name}(\{rendered})"
  }
}

///|
pub fn QubitExpr::dual(self : QubitExpr) -> QubitExpr {
  QubitExpr::{ bits: self.bits, is_bra: !self.is_bra, int_form: self.int_form }
}

///|
pub fn QubitExpr::nqubits(self : QubitExpr) -> Int {
  self.bits.length()
}

///|
pub fn QubitExpr::dimension(self : QubitExpr) -> Int {
  self.bits.length()
}

///|
pub fn QubitExpr::bit(
  self : QubitExpr,
  index : Int,
) -> Int raise @symphysics.PhysicsError {
  guard index >= 0 && index < self.bits.length() else {
    raise @symphysics.PhysicsError::IndexError("qubit index out of range")
  }
  self.bits[self.bits.length() - 1 - index]
}

///|
pub fn QubitExpr::flip(
  self : QubitExpr,
  index : Int,
) -> QubitExpr raise @symphysics.PhysicsError {
  guard index >= 0 && index < self.bits.length() else {
    raise @symphysics.PhysicsError::IndexError("qubit index out of range")
  }
  let bits = self.bits.copy()
  let pos = bits.length() - 1 - index
  bits[pos] = if bits[pos] == 0 { 1 } else { 0 }
  QubitExpr::{ bits, is_bra: self.is_bra, int_form: self.int_form }
}

///|
pub fn qubit_from_expr(expr : Expr) -> QubitExpr? {
  match expr {
    Expr::Function(name, args) if name == "Qubit" || name == "QubitBra" => {
      let bits : Array[Int] = []
      for arg in args {
        match arg {
          Expr::Number(n) if n.is_integral() =>
            bits.push(n.numerator().to_int())
          _ => return None
        }
      }
      Some(QubitExpr::{ bits, is_bra: name == "QubitBra", int_form: false })
    }
    Expr::Function(name, args) if (
        name == "IntQubit" || name == "IntQubitBra"
      ) &&
      args.length() == 1 =>
      match args[0] {
        Expr::Number(n) if n.is_integral() &&
          n.numerator().to_int() >= 0 => {
          let bits_result : Result[Array[Int], @symphysics.PhysicsError] = try?
            int_to_minimal_bits(n.numerator().to_int())
          match bits_result {
            Ok(bits) =>
              Some(QubitExpr::{
                bits,
                is_bra: name == "IntQubitBra",
                int_form: true,
              })
            Err(_) => None
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn qubit_basis_vector(
  q : QubitExpr,
  nqubits : Int,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  guard q.nqubits() == nqubits else {
    raise @symphysics.PhysicsError::ShapeError(
      "Qubit size does not match requested basis",
    )
  }
  let size = 1 << nqubits
  if q.is_bra {
    let row = Array::make(size, int(0))
    row[bits_to_int(q.bits)] = int(1)
    @symphysics.explicit_matrix_from_rows([row])
  } else {
    let rows : Array[Array[Expr]] = []
    for idx in 0..<size {
      rows.push([
        if idx == bits_to_int(q.bits) {
          int(1)
        } else {
          int(0)
        },
      ])
    }
    @symphysics.explicit_matrix_from_rows(rows)
  }
}

///|
fn qubit_expr_nqubits(expr : Expr) -> Int? {
  match qubit_from_expr(expr) {
    Some(q) => Some(q.nqubits())
    None =>
      match expr {
        Expr::Add(args) => {
          let sizes = args.map(qubit_expr_nqubits)
          for size in sizes {
            match size {
              Some(v) => return Some(v)
              None => ()
            }
          }
          None
        }
        Expr::Mul(args) => {
          for arg in args {
            match qubit_expr_nqubits(arg) {
              Some(v) => return Some(v)
              None => ()
            }
          }
          None
        }
        _ => None
      }
  }
}

///|
fn matrix_add_or_scalar(
  lhs : @symphysics.ExplicitMatrix,
  rhs : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  lhs.add(rhs)
}

///|
pub fn qubit_to_matrix(
  expr : Expr,
  nqubits? : Int = 0,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let effective_nqubits = if nqubits > 0 {
    nqubits
  } else {
    match qubit_expr_nqubits(expr) {
      Some(v) => v
      None =>
        raise @symphysics.PhysicsError::ValueError(
          "Expression does not contain a qubit state",
        )
    }
  }
  match expr {
    Expr::Add(args) => {
      guard !args.is_empty() else {
        raise @symphysics.PhysicsError::ValueError("Empty qubit sum")
      }
      let mut acc = qubit_to_matrix(args[0], nqubits=effective_nqubits)
      for idx in 1..<args.length() {
        acc = matrix_add_or_scalar(
          acc,
          qubit_to_matrix(args[idx], nqubits=effective_nqubits),
        )
      }
      acc
    }
    Expr::Mul(_) => {
      let (scalar, body) = quantum_split_scalar_factors(expr)
      match body {
        Some(body_expr) => {
          let base = qubit_to_matrix(body_expr, nqubits=effective_nqubits)
          base.scale(scalar)
        }
        None =>
          raise @symphysics.PhysicsError::ValueError(
            "Pure scalar is not a qubit state",
          )
      }
    }
    _ =>
      match qubit_from_expr(expr) {
        Some(q) => qubit_basis_vector(q, effective_nqubits)
        None =>
          raise @symphysics.PhysicsError::ValueError(
            "Expected a qubit expression",
          )
      }
  }
}

///|
pub fn matrix_to_qubit(
  matrix : @symphysics.ExplicitMatrix,
) -> Expr raise @symphysics.PhysicsError {
  let is_bra = matrix.height() == 1
  let size = if is_bra { matrix.width() } else { matrix.height() }
  let mut nqubits = 0
  let mut width = 1
  while width < size {
    width = width * 2
    nqubits += 1
  }
  guard width == size else {
    raise @symphysics.PhysicsError::ShapeError(
      "Matrix size is not a power-of-two qubit basis",
    )
  }
  let terms : Array[Expr] = []
  for idx in 0..<size {
    let coeff = if is_bra { matrix.get(0, idx) } else { matrix.get(idx, 0) }
    if coeff != int(0) {
      let q = qubit_from_bits(int_to_bits(idx, nqubits), bra=is_bra)
      let qexpr = q.as_expr()
      if coeff == int(1) {
        terms.push(qexpr)
      } else {
        terms.push(coeff * qexpr)
      }
    }
  }
  quantum_add_from_args_preserve(terms)
}

///|
fn qubit_matrix_norm_squared(
  matrix : @symphysics.ExplicitMatrix,
) -> Expr raise @symphysics.PhysicsError {
  let is_bra = matrix.height() == 1
  let size = if is_bra { matrix.width() } else { matrix.height() }
  let mut acc = int(0)
  for idx in 0..<size {
    let coeff = if is_bra { matrix.get(0, idx) } else { matrix.get(idx, 0) }
    acc = acc + expr_conjugate(coeff) * coeff
  }
  acc
}

///|
fn qubit_normalize_matrix(
  matrix : @symphysics.ExplicitMatrix,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let norm_sq = qubit_matrix_norm_squared(matrix)
  if norm_sq == int(0) || norm_sq == int(1) {
    matrix
  } else {
    let half = qubit_exact_rational(-1, 2)
    matrix.scale(@symcore.raw_pow(norm_sq, half))
  }
}

///|
fn qubit_matrix_size(
  matrix : @symphysics.ExplicitMatrix,
) -> Int raise @symphysics.PhysicsError {
  let is_bra = matrix.height() == 1
  let size = if is_bra { matrix.width() } else { matrix.height() }
  let mut width = 1
  while width < size {
    width = width * 2
  }
  guard width == size else {
    raise @symphysics.PhysicsError::ShapeError(
      "Matrix size is not a power-of-two qubit basis",
    )
  }
  size
}

///|
fn qubit_partial_outcome_matrix(
  matrix : @symphysics.ExplicitMatrix,
  bits : Array[Int],
  outcome : Int,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  guard matrix.width() == 1 else {
    raise @symphysics.PhysicsError::ShapeError(
      "Measurements currently expect qubit kets",
    )
  }
  let size = qubit_matrix_size(matrix)
  let rows : Array[Array[Expr]] = []
  for idx in 0..<size {
    let mut key = 0
    for pos in 0..<bits.length() {
      if ((idx >> bits[pos]) & 1) == 1 {
        key = key | (1 << pos)
      }
    }
    rows.push([
      if key == outcome {
        matrix.get(idx, 0)
      } else {
        int(0)
      },
    ])
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
fn qubit_probability_terms(
  matrix : @symphysics.ExplicitMatrix,
) -> Array[(Expr, Expr)] raise @symphysics.PhysicsError {
  guard matrix.width() == 1 else {
    raise @symphysics.PhysicsError::ShapeError(
      "Measurements currently expect qubit kets",
    )
  }
  let size = qubit_matrix_size(matrix)
  let mut nqubits = 0
  let mut width = 1
  while width < size {
    width = width * 2
    nqubits += 1
  }
  let out : Array[(Expr, Expr)] = []
  for idx in 0..<size {
    let coeff = matrix.get(idx, 0)
    if coeff != int(0) {
      let state = qubit_from_bits(int_to_bits(idx, nqubits)).as_expr()
      out.push((state, expr_conjugate(coeff) * coeff))
    }
  }
  out
}

///|
pub fn measure_all(
  expr : Expr,
  nqubits? : Int = 0,
  normalize? : Bool = true,
) -> Array[(Expr, Expr)] raise @symphysics.PhysicsError {
  let matrix = qubit_to_matrix(expr, nqubits~)
  let effective = if normalize {
    qubit_normalize_matrix(matrix)
  } else {
    matrix
  }
  qubit_probability_terms(effective)
}

///|
pub fn measure_partial(
  expr : Expr,
  bits : Array[Int],
  nqubits? : Int = 0,
  normalize? : Bool = true,
) -> Array[(Expr, Expr)] raise @symphysics.PhysicsError {
  let matrix = qubit_to_matrix(expr, nqubits~)
  let effective = if normalize {
    qubit_normalize_matrix(matrix)
  } else {
    matrix
  }
  let out : Array[(Expr, Expr)] = []
  for outcome in 0..<(1 << bits.length()) {
    let next_matrix = qubit_partial_outcome_matrix(effective, bits, outcome)
    let prob = qubit_matrix_norm_squared(next_matrix)
    if prob != int(0) {
      let state = if normalize {
        matrix_to_qubit(qubit_normalize_matrix(next_matrix))
      } else {
        matrix_to_qubit(next_matrix)
      }
      out.push((state, prob))
    }
  }
  out
}
