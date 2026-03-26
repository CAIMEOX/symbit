///|
/// Shor-order-finding helpers aligned with the algorithmic surface of
/// `sympy.physics.quantum.shor`.
///
/// The original SymPy module models the `CMod` gate symbolically but leaves
/// large parts of the gate API unfinished. The MoonBit port keeps the exact
/// modular-action semantics of `CMod` on computational basis states, and uses
/// an exact classical multiplicative-order computation for `period_find`.
/// This preserves the mathematical output that the quantum subroutine is
/// intended to recover while keeping the implementation executable.

///|
pub struct CModExpr {
  t : Int
  a : Int
  modulus : Int
} derive(Eq)

///|
fn shor_int_gcd(lhs : Int, rhs : Int) -> Int {
  let mut a = lhs.abs()
  let mut b = rhs.abs()
  while b != 0 {
    let next = a % b
    a = b
    b = next
  }
  a
}

///|
fn shor_int_pow(base : Int, exp : Int) -> Int {
  let mut result = 1
  let mut factor = base
  let mut power = exp
  while power > 0 {
    if (power & 1) == 1 {
      result = result * factor
    }
    factor = factor * factor
    power = power >> 1
  }
  result
}

///|
fn shor_pow_mod(base : Int, exp : Int, modulus : Int) -> Int {
  let mut result = 1 % modulus
  let mut factor = (base % modulus + modulus) % modulus
  let mut power = exp
  while power > 0 {
    if (power & 1) == 1 {
      result = result * factor % modulus
    }
    factor = factor * factor % modulus
    power = power >> 1
  }
  result
}

///|
fn shor_continued_fraction_terms(
  num : Int,
  den : Int,
) -> Array[Int] raise @symphysics.PhysicsError {
  guard den != 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "getr expects a nonzero denominator",
    )
  }
  let out : Array[Int] = []
  let mut a = num
  let mut b = den
  while b != 0 {
    out.push(a / b)
    let next = a % b
    a = b
    b = next
  }
  out
}

///|
pub fn ratioize(items : Array[Int], n : Int) -> Int {
  guard !items.is_empty() else { return 0 }
  if items[0] > n {
    return 0
  }
  if items.length() == 1 {
    return items[0]
  }
  items[0] + ratioize(items[1:items.length()].to_array(), n)
}

///|
pub fn getr(x : Int, y : Int, n : Int) -> Int raise @symphysics.PhysicsError {
  ratioize(shor_continued_fraction_terms(x, y), n)
}

///|
pub fn cmod(
  t : Int,
  a : Int,
  modulus : Int,
) -> Expr raise @symphysics.PhysicsError {
  guard t > 0 else {
    raise @symphysics.PhysicsError::ValueError("CMod expects t > 0")
  }
  guard modulus > 0 else {
    raise @symphysics.PhysicsError::ValueError("CMod expects modulus > 0")
  }
  guard modulus <= shor_int_pow(2, t) else {
    raise @symphysics.PhysicsError::ValueError(
      "CMod expects modulus to fit in t output qubits",
    )
  }
  @symcore.raw_function("CMod", [int(t), int(a), int(modulus)])
}

///|
pub fn CModExpr::as_expr(self : CModExpr) -> Expr {
  @symcore.raw_function("CMod", [int(self.t), int(self.a), int(self.modulus)])
}

///|
fn cmod_from_expr(expr : Expr) -> CModExpr? {
  match expr {
    Expr::Function("CMod", args) if args.length() == 3 =>
      match
        (
          quantum_integer_value(args[0]),
          quantum_integer_value(args[1]),
          quantum_integer_value(args[2]),
        ) {
        (Some(t), Some(a), Some(modulus)) => Some(CModExpr::{ t, a, modulus })
        _ => None
      }
    _ => None
  }
}

///|
fn cmod_apply(
  op : CModExpr,
  ket : QubitExpr,
) -> Expr raise @symphysics.PhysicsError {
  guard ket.nqubits() == 2 * op.t else {
    raise @symphysics.PhysicsError::ShapeError(
      "CMod operates on exactly 2*t qubits",
    )
  }
  let mut exponent = 0
  for i in 0..<op.t {
    exponent += (1 << i) * ket.bit(op.t + i)
  }
  let out = shor_pow_mod(op.a, exponent, op.modulus)
  let out_bits = int_to_bits(out, op.t)
  let result_bits : Array[Int] = []
  for idx in 0..<op.t {
    result_bits.push(ket.bits[idx])
  }
  for bit in out_bits {
    result_bits.push(bit)
  }
  // `CMod` acts on a fixed-width register, so preserve the explicit bit-width
  // instead of collapsing back to `IntQubit`'s minimal-width encoding.
  qubit_from_bits(result_bits, bra=ket.is_bra).as_expr()
}

///|
pub fn shor_apply_operator_to_ket(
  op_expr : Expr,
  ket_expr : Expr,
) -> Expr? raise @symphysics.PhysicsError {
  match (cmod_from_expr(op_expr), qubit_from_expr(ket_expr)) {
    (Some(op), Some(ket)) => Some(cmod_apply(op, ket))
    _ => None
  }
}

///|
fn cmod_matrix(
  op : CModExpr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let size = 1 << (2 * op.t)
  let rows : Array[Array[Expr]] = []
  for _ in 0..<size {
    rows.push(Array::make(size, int(0)))
  }
  for col in 0..<size {
    let bits = int_to_bits(col, 2 * op.t)
    let input = qubit_from_bits(bits)
    let out = cmod_apply(op, input)
    let q = match qubit_from_expr(out) {
      Some(value) => value
      None =>
        raise @symphysics.PhysicsError::ValueError(
          "CMod matrix expects basis-state output",
        )
    }
    rows[bits_to_int(q.bits)][col] = int(1)
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
pub fn shor_represent(
  expr : Expr,
  nqubits : Int,
) -> MatrixScalarValue? raise @symphysics.PhysicsError {
  match cmod_from_expr(expr) {
    Some(op) => {
      let expected = 2 * op.t
      guard nqubits == 0 || nqubits == expected else {
        raise @symphysics.PhysicsError::ShapeError(
          "CMod representation size mismatch",
        )
      }
      Some(MatrixScalarValue::Matrix(cmod_matrix(op)))
    }
    None => None
  }
}

///|
pub fn period_find(a : Int, n : Int) -> Int raise @symphysics.PhysicsError {
  guard n > 1 else {
    raise @symphysics.PhysicsError::ValueError("period_find expects n > 1")
  }
  guard a > 0 else {
    raise @symphysics.PhysicsError::ValueError("period_find expects a > 0")
  }
  guard shor_int_gcd(a, n) == 1 else {
    raise @symphysics.PhysicsError::ValueError(
      "period_find expects gcd(a, n) == 1",
    )
  }
  let reduced = a % n
  let mut r = 1
  let mut value = reduced % n
  while value != 1 {
    r += 1
    value = value * reduced % n
    if r > n * n {
      raise @symphysics.PhysicsError::ValueError(
        "period_find failed to detect a multiplicative order",
      )
    }
  }
  r
}

///|
fn shor_factor_pair(a : Int, r : Int, n : Int) -> (Int, Int) {
  let half_power = shor_int_pow(a, r / 2)
  let left = shor_int_gcd(half_power - 1, n)
  let right = shor_int_gcd(half_power + 1, n)
  if left <= right {
    (left, right)
  } else {
    (right, left)
  }
}

///|
pub fn shor(n : Int) -> Expr raise @symphysics.PhysicsError {
  guard n > 1 else {
    raise @symphysics.PhysicsError::ValueError("shor expects n > 1")
  }
  for a in 2..<n {
    let divisor = shor_int_gcd(n, a)
    if divisor != 1 {
      return int(divisor)
    }
    let r = period_find(a, n)
    if (r & 1) == 1 {
      continue
    }
    let factors = shor_factor_pair(a, r, n)
    if factors.0 > 1 && factors.0 < n && factors.1 > 1 && factors.1 < n {
      return @symcore.Expr::Tuple([int(factors.0), int(factors.1)])
    }
  }
  raise @symphysics.PhysicsError::ValueError(
    "shor failed to find a nontrivial factor",
  )
}
