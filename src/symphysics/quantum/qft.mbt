///|
/// Quantum Fourier transform gates aligned with the practical core of
/// `sympy.physics.quantum.qft`.
///
/// This module implements:
/// - `RkGate` / `Rk` phase rotations;
/// - `QFT` and `IQFT` constructor expressions;
/// - exact decomposition into elementary gates;
/// - exact Z-basis matrix representations;
/// - exact action on concrete computational-basis qubits.

///|
pub struct RkExpr {
  target : Int
  k : Int
} derive(Eq)

///|
pub struct FourierExpr {
  inverse : Bool
  start : Int
  finish : Int
} derive(Eq)

///|
pub fn rk_gate(target : Int, k : Int) -> Expr {
  match k {
    1 => z_gate(target).as_expr()
    2 => phase_gate(target).as_expr()
    3 => t_gate(target).as_expr()
    _ => @symcore.raw_function("RkGate", [int(target), int(k)])
  }
}

///|
pub fn rk(target : Int, k : Int) -> Expr {
  rk_gate(target, k)
}

///|
pub fn qft(
  start : Int,
  finish : Int,
) -> FourierExpr raise @symphysics.PhysicsError {
  guard start < finish else {
    raise @symphysics.PhysicsError::ValueError(
      "QFT start must be smaller than finish",
    )
  }
  FourierExpr::{ inverse: false, start, finish }
}

///|
pub fn iqft(
  start : Int,
  finish : Int,
) -> FourierExpr raise @symphysics.PhysicsError {
  guard start < finish else {
    raise @symphysics.PhysicsError::ValueError(
      "IQFT start must be smaller than finish",
    )
  }
  FourierExpr::{ inverse: true, start, finish }
}

///|
pub fn FourierExpr::as_expr(self : FourierExpr) -> Expr {
  let name = if self.inverse { "IQFT" } else { "QFT" }
  @symcore.raw_function(name, [int(self.start), int(self.finish)])
}

///|
pub fn FourierExpr::inverse(self : FourierExpr) -> FourierExpr {
  FourierExpr::{
    inverse: !self.inverse,
    start: self.start,
    finish: self.finish,
  }
}

///|
fn fourier_from_expr(expr : Expr) -> FourierExpr? {
  match expr {
    Expr::Function(name, args) if (name == "QFT" || name == "IQFT") &&
      args.length() == 2 =>
      match (quantum_integer_value(args[0]), quantum_integer_value(args[1])) {
        (Some(start), Some(finish)) if start < finish =>
          Some(FourierExpr::{ inverse: name == "IQFT", start, finish })
        _ => None
      }
    _ => None
  }
}

///|
fn rk_from_expr(expr : Expr) -> RkExpr? {
  match expr {
    Expr::Function("RkGate", args) if args.length() == 2 =>
      match (quantum_integer_value(args[0]), quantum_integer_value(args[1])) {
        (Some(target), Some(k)) => Some(RkExpr::{ target, k })
        _ => None
      }
    _ => None
  }
}

///|
fn qft_exact_rational(num : Int, den : Int) -> Expr {
  let result : Result[Expr, @symnum.RationalError] = try? @symcore.rational_from_ints(
    num, den,
  )
  match result {
    Ok(value) => value
    Err(_) => int(num) * @symcore.raw_pow(int(den), int(-1))
  }
}

///|
fn rk_phase(k : Int) -> Expr {
  let sign = if k > 0 { int(1) } else if k < 0 { int(-1) } else { int(0) }
  let two = int(2)
  let denom = @symcore.raw_pow(two, int(Int::abs(k)))
  let angle = sign *
    two *
    @symcore.pi() *
    @symcore.imag_unit() *
    @symcore.raw_pow(denom, int(-1))
  @symcore.raw_function("exp", [angle])
}

///|
fn rk_target_matrix(
  expr : RkExpr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  @symphysics.explicit_matrix_from_rows([
    [int(1), int(0)],
    [int(0), rk_phase(expr.k)],
  ])
}

///|
fn qft_norm(size : Int) -> Expr {
  @symcore.raw_pow(int(size), qft_exact_rational(-1, 2))
}

///|
fn qft_omega(expr : FourierExpr) -> Expr {
  let exponent = if expr.inverse { int(-1) } else { int(1) }
  let denom = int(1 << (expr.finish - expr.start))
  @symcore.raw_function("exp", [
    exponent *
    int(2) *
    @symcore.pi() *
    @symcore.imag_unit() *
    @symcore.raw_pow(denom, int(-1)),
  ])
}

///|
fn qft_core_matrix(
  expr : FourierExpr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let size = 1 << (expr.finish - expr.start)
  let omega = qft_omega(expr)
  let norm = qft_norm(size)
  let rows : Array[Array[Expr]] = []
  for row in 0..<size {
    let entries : Array[Expr] = []
    for col in 0..<size {
      entries.push(norm * @symcore.raw_pow(omega, int(row * col % size)))
    }
    rows.push(entries)
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
fn embed_gate_matrix(
  core : @symphysics.ExplicitMatrix,
  start : Int,
  finish : Int,
  nqubits : Int,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let parts : Array[@symphysics.ExplicitMatrix] = []
  if start > 0 {
    parts.push(@symphysics.explicit_matrix_eye(1 << start))
  }
  parts.push(core)
  if finish < nqubits {
    parts.push(@symphysics.explicit_matrix_eye(1 << (nqubits - finish)))
  }
  if parts.length() == 1 {
    parts[0]
  } else {
    matrix_tensor_product(parts)
  }
}

///|
pub fn qft_decompose(expr : FourierExpr) -> Expr {
  let mut circuit = int(1)
  if expr.inverse {
    for i in 0..<((expr.finish - expr.start) / 2) {
      circuit = quantum_mul_from_args_preserve([
        swap_gate(i + expr.start, expr.finish - i - 1).as_expr(),
        circuit,
      ])
    }
    for level in expr.start..<expr.finish {
      let mut i = level - expr.start - 1
      while i >= 0 {
        circuit = quantum_mul_from_args_preserve([
          cgate([level - i - 1], rk_gate(level, -i - 2)),
          circuit,
        ])
        i -= 1
      }
      circuit = quantum_mul_from_args_preserve([
        hadamard_gate(level).as_expr(),
        circuit,
      ])
    }
  } else {
    let mut level = expr.finish - 1
    while level >= expr.start {
      circuit = quantum_mul_from_args_preserve([
        hadamard_gate(level).as_expr(),
        circuit,
      ])
      for i in 0..<(level - expr.start) {
        circuit = quantum_mul_from_args_preserve([
          cgate([level - i - 1], rk_gate(level, i + 2)),
          circuit,
        ])
      }
      level -= 1
    }
    for i in 0..<((expr.finish - expr.start) / 2) {
      circuit = quantum_mul_from_args_preserve([
        swap_gate(i + expr.start, expr.finish - i - 1).as_expr(),
        circuit,
      ])
    }
  }
  gate_simp(circuit)
}

///|
pub fn qft_represent(
  expr : Expr,
  nqubits : Int,
) -> MatrixScalarValue? raise @symphysics.PhysicsError {
  match fourier_from_expr(expr) {
    Some(fourier) => {
      let effective_nqubits = if nqubits > 0 { nqubits } else { fourier.finish }
      let core = qft_core_matrix(fourier)
      Some(
        MatrixScalarValue::Matrix(
          embed_gate_matrix(
            core,
            fourier.start,
            fourier.finish,
            effective_nqubits,
          ),
        ),
      )
    }
    None =>
      match rk_from_expr(expr) {
        Some(rk_expr) => {
          let effective_nqubits = if nqubits > 0 {
            nqubits
          } else {
            rk_expr.target + 1
          }
          Some(
            MatrixScalarValue::Matrix(
              embed_gate_matrix(
                rk_target_matrix(rk_expr),
                rk_expr.target,
                rk_expr.target + 1,
                effective_nqubits,
              ),
            ),
          )
        }
        None => None
      }
  }
}

///|
pub fn qft_apply_operator_to_ket(
  op_expr : Expr,
  ket_expr : Expr,
) -> Expr? raise @symphysics.PhysicsError {
  match (fourier_from_expr(op_expr), qubit_from_expr(ket_expr)) {
    (Some(_), Some(q)) => {
      let matrix = match qft_represent(op_expr, q.nqubits()) {
        Some(MatrixScalarValue::Matrix(matrix)) => matrix
        _ => return None
      }
      let vec = qubit_to_matrix(ket_expr, nqubits=q.nqubits())
      Some(matrix_to_qubit(matrix.mul(vec)))
    }
    (None, Some(q)) =>
      match rk_from_expr(op_expr) {
        Some(rk_expr) => {
          guard rk_expr.target >= 0 && rk_expr.target < q.nqubits() else {
            raise @symphysics.PhysicsError::IndexError(
              "Rk target index out of range",
            )
          }
          if q.bit(rk_expr.target) == 0 {
            Some(ket_expr)
          } else {
            Some(
              quantum_mul_from_args_preserve([rk_phase(rk_expr.k), ket_expr]),
            )
          }
        }
        None => None
      }
    _ => None
  }
}
