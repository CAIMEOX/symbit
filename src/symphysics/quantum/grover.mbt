///|
/// Grover search helpers aligned with `sympy.physics.quantum.grover`.
///
/// SymPy models `OracleGate` with a Python callable. MoonBit cannot transport
/// Python callables into the runtime expression tree, so the port uses an
/// explicit marked-state model: `oracle_gate(nqubits, [targets...])` marks the
/// computational-basis states whose phase should flip. This is the same search
/// operator, but expressed as an explicit finite dispatch table.
///
/// Covered semantics:
///
/// - `superposition_basis(n)` builds the uniform computational superposition;
/// - `oracle_gate(n, marks)` flips the phase of the marked basis states;
/// - `w_gate(n)` is the Grover diffusion operator `2|phi><phi| - I`;
/// - `grover_iteration(state, oracle)` builds the `W*V*state` circuit;
/// - `apply_grover(marks, n, iterations)` iterates and evaluates the search.

///|
pub struct OracleGateExpr {
  nqubits : Int
  marked : Array[Int]
} derive(Eq)

///|
pub struct WGateExpr {
  nqubits : Int
} derive(Eq)

///|
fn grover_marked_tuple(marked : Array[Int]) -> Expr {
  @symcore.raw_function("Tuple", marked.map(@symcore.int))
}

///|
fn grover_marked_values(expr : Expr) -> Array[Int]? {
  match expr {
    Expr::Function("Tuple", args) => {
      let out : Array[Int] = []
      for arg in args {
        match quantum_integer_value(arg) {
          Some(value) => out.push(value)
          None => return None
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
fn grover_exact_rational(num : Int, den : Int) -> Expr {
  let result : Result[Expr, @symnum.RationalError] = try?
    @symcore.rational_from_ints(num, den)
  match result {
    Ok(value) => value
    Err(_) => int(num) * @symcore.raw_pow(int(den), int(-1))
  }
}

///|
fn grover_superposition_amplitude(nqubits : Int) -> Expr {
  let size = 1 << nqubits
  @symcore.raw_pow(int(size), grover_exact_rational(-1, 2))
}

///|
fn grover_diffusion_weight(nqubits : Int) -> Expr {
  grover_exact_rational(2, 1 << nqubits)
}

///|
fn grover_default_iterations(nqubits : Int) -> Int {
  let size = (1 << nqubits).to_double()
  @math.floor(@math.pow(size, 0.5) * @math.PI / 4.0).to_int()
}

///|
fn grover_validate_nqubits(
  nqubits : Int,
) -> Unit raise @symphysics.PhysicsError {
  guard nqubits > 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "Grover search needs a positive number of qubits",
    )
  }
}

///|
fn grover_validate_marked(
  marked : Array[Int],
  nqubits : Int,
) -> Unit raise @symphysics.PhysicsError {
  let size = 1 << nqubits
  for value in marked {
    guard value >= 0 && value < size else {
      raise @symphysics.PhysicsError::ValueError(
        "Marked computational basis states must lie in [0, 2**nqubits)",
      )
    }
  }
}

///|
pub fn oracle_gate(
  nqubits : Int,
  marked : Array[Int],
) -> Expr raise @symphysics.PhysicsError {
  grover_validate_nqubits(nqubits)
  grover_validate_marked(marked, nqubits)
  @symcore.raw_function("OracleGate", [
    int(nqubits),
    grover_marked_tuple(marked),
  ])
}

///|
pub fn w_gate(nqubits : Int) -> Expr raise @symphysics.PhysicsError {
  grover_validate_nqubits(nqubits)
  @symcore.raw_function("WGate", [int(nqubits)])
}

///|
pub fn OracleGateExpr::as_expr(self : OracleGateExpr) -> Expr {
  @symcore.raw_function("OracleGate", [
    int(self.nqubits),
    grover_marked_tuple(self.marked),
  ])
}

///|
pub fn WGateExpr::as_expr(self : WGateExpr) -> Expr {
  @symcore.raw_function("WGate", [int(self.nqubits)])
}

///|
fn oracle_gate_from_expr(expr : Expr) -> OracleGateExpr? {
  match expr {
    Expr::Function("OracleGate", args) if args.length() == 2 =>
      match (quantum_integer_value(args[0]), grover_marked_values(args[1])) {
        (Some(nqubits), Some(marked)) =>
          Some(OracleGateExpr::{ nqubits, marked })
        _ => None
      }
    _ => None
  }
}

///|
fn w_gate_from_expr(expr : Expr) -> WGateExpr? {
  match expr {
    Expr::Function("WGate", args) if args.length() == 1 =>
      match quantum_integer_value(args[0]) {
        Some(nqubits) => Some(WGateExpr::{ nqubits, })
        None => None
      }
    _ => None
  }
}

///|
pub fn superposition_basis(
  nqubits : Int,
) -> Expr raise @symphysics.PhysicsError {
  grover_validate_nqubits(nqubits)
  let amp = grover_superposition_amplitude(nqubits)
  let terms : Array[Expr] = []
  for value in 0..<(1 << nqubits) {
    let bits = int_to_bits(value, nqubits)
    let state = qubit_from_bits(bits).as_expr()
    terms.push(amp * state)
  }
  quantum_add_from_args_preserve(terms)
}

///|
fn grover_is_marked(q : QubitExpr, marked : Array[Int]) -> Bool {
  marked.contains(bits_to_int(q.bits))
}

///|
fn grover_oracle_apply(
  oracle_expr : OracleGateExpr,
  ket : QubitExpr,
  ket_expr : Expr,
) -> Expr raise @symphysics.PhysicsError {
  guard ket.nqubits() == oracle_expr.nqubits else {
    raise @symphysics.PhysicsError::ShapeError(
      "OracleGate operates on \{oracle_expr.nqubits.to_string()} qubits",
    )
  }
  if grover_is_marked(ket, oracle_expr.marked) {
    int(-1) * ket_expr
  } else {
    ket_expr
  }
}

///|
fn grover_w_apply(
  w_expr : WGateExpr,
  ket : QubitExpr,
  _ket_expr : Expr,
) -> Expr raise @symphysics.PhysicsError {
  guard ket.nqubits() == w_expr.nqubits else {
    raise @symphysics.PhysicsError::ShapeError(
      "WGate operates on \{w_expr.nqubits.to_string()} qubits",
    )
  }
  let weight = grover_diffusion_weight(w_expr.nqubits)
  let marked_value = bits_to_int(ket.bits)
  let terms : Array[Expr] = []
  for value in 0..<(1 << w_expr.nqubits) {
    let coeff = if value == marked_value {
      weight - int(1)
    } else {
      weight
    }
    let bits = int_to_bits(value, w_expr.nqubits)
    let state = qubit_from_bits(bits).as_expr()
    if coeff == int(1) {
      terms.push(state)
    } else {
      terms.push(coeff * state)
    }
  }
  quantum_add_from_args_preserve(terms)
}

///|
pub fn grover_apply_operator_to_ket(
  op_expr : Expr,
  ket_expr : Expr,
) -> Expr? raise @symphysics.PhysicsError {
  match qubit_from_expr(ket_expr) {
    Some(ket) =>
      match oracle_gate_from_expr(op_expr) {
        Some(oracle_expr) => Some(grover_oracle_apply(oracle_expr, ket, ket_expr))
        None =>
          match w_gate_from_expr(op_expr) {
            Some(w_expr) => Some(grover_w_apply(w_expr, ket, ket_expr))
            None => None
          }
      }
    None => None
  }
}

///|
fn grover_oracle_matrix(
  expr : OracleGateExpr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let size = 1 << expr.nqubits
  let rows : Array[Array[Expr]] = []
  for row in 0..<size {
    let current : Array[Expr] = []
    for col in 0..<size {
      current.push(
        if row == col {
          if expr.marked.contains(row) {
            int(-1)
          } else {
            int(1)
          }
        } else {
          int(0)
        },
      )
    }
    rows.push(current)
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
fn grover_w_matrix(
  expr : WGateExpr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let size = 1 << expr.nqubits
  let weight = grover_diffusion_weight(expr.nqubits)
  let rows : Array[Array[Expr]] = []
  for row in 0..<size {
    let current : Array[Expr] = []
    for col in 0..<size {
      current.push(if row == col { weight - int(1) } else { weight })
    }
    rows.push(current)
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
pub fn grover_represent(
  expr : Expr,
  nqubits : Int,
) -> MatrixScalarValue? raise @symphysics.PhysicsError {
  match oracle_gate_from_expr(expr) {
    Some(oracle_expr) =>
      Some(MatrixScalarValue::Matrix(grover_oracle_matrix(oracle_expr)))
    None =>
      match w_gate_from_expr(expr) {
        Some(w_expr) =>
          Some(MatrixScalarValue::Matrix(grover_w_matrix(w_expr)))
        None =>
          if quantum_expr_has_name(expr, "Qubit") ||
            quantum_expr_has_name(expr, "QubitBra") {
            Some(MatrixScalarValue::Matrix(qubit_to_matrix(expr, nqubits~)))
          } else {
            None
          }
      }
  }
}

///|
pub fn grover_iteration(
  qstate : Expr,
  oracle_expr : Expr,
) -> Expr raise @symphysics.PhysicsError {
  let oracle = match oracle_gate_from_expr(oracle_expr) {
    Some(value) => value
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "grover_iteration expects an OracleGate expression",
      )
  }
  quantum_mul_from_args_preserve([
    w_gate(oracle.nqubits),
    oracle_expr,
    qstate,
  ])
}

///|
pub fn apply_grover(
  marked : Array[Int],
  nqubits : Int,
  iterations? : Int = -1,
) -> Expr raise @symphysics.PhysicsError {
  grover_validate_nqubits(nqubits)
  grover_validate_marked(marked, nqubits)
  let total_iterations = if iterations >= 0 {
    iterations
  } else {
    grover_default_iterations(nqubits)
  }
  let oracle_expr = oracle_gate(nqubits, marked)
  let mut iterated = superposition_basis(nqubits)
  for _ in 0..<total_iterations {
    let stepped = qapply(grover_iteration(iterated, oracle_expr))
    iterated = matrix_to_qubit(qubit_to_matrix(stepped, nqubits~))
  }
  iterated
}
