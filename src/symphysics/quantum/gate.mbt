///|
/// Computational-basis gate operators aligned with the central concrete gate
/// families from `sympy.physics.quantum.gate`.
///
/// This slice covers single-qubit `H/X/Y/Z/S/T`, `SWAP`, and `CNOT`, together
/// with exact action on basis qubits and exact matrix representations in the
/// Z basis.

///|
pub enum GateKind {
  Identity
  Hadamard
  X
  Y
  Z
  Phase
  T
  Swap
  CNot
} derive(Eq)

///|
pub struct GateExpr {
  kind : GateKind
  args : Array[Int]
} derive(Eq)

///|
fn gate_alias_name(kind : GateKind) -> String {
  match kind {
    GateKind::Identity => "1"
    GateKind::Hadamard => "H"
    GateKind::X => "X"
    GateKind::Y => "Y"
    GateKind::Z => "Z"
    GateKind::Phase => "S"
    GateKind::T => "T"
    GateKind::Swap => "SWAP"
    GateKind::CNot => "CNOT"
  }
}

///|
fn gate_class_name(kind : GateKind) -> String {
  match kind {
    GateKind::Identity => "IdentityGate"
    GateKind::Hadamard => "HadamardGate"
    GateKind::X => "XGate"
    GateKind::Y => "YGate"
    GateKind::Z => "ZGate"
    GateKind::Phase => "PhaseGate"
    GateKind::T => "TGate"
    GateKind::Swap => "SwapGate"
    GateKind::CNot => "CNotGate"
  }
}

///|
pub fn identity_gate(target : Int) -> GateExpr {
  GateExpr::{ kind: GateKind::Identity, args: [target] }
}

///|
pub fn hadamard_gate(target : Int) -> GateExpr {
  GateExpr::{ kind: GateKind::Hadamard, args: [target] }
}

///|
pub fn x_gate(target : Int) -> GateExpr {
  GateExpr::{ kind: GateKind::X, args: [target] }
}

///|
pub fn y_gate(target : Int) -> GateExpr {
  GateExpr::{ kind: GateKind::Y, args: [target] }
}

///|
pub fn z_gate(target : Int) -> GateExpr {
  GateExpr::{ kind: GateKind::Z, args: [target] }
}

///|
pub fn phase_gate(target : Int) -> GateExpr {
  GateExpr::{ kind: GateKind::Phase, args: [target] }
}

///|
pub fn t_gate(target : Int) -> GateExpr {
  GateExpr::{ kind: GateKind::T, args: [target] }
}

///|
pub fn swap_gate(target1 : Int, target2 : Int) -> GateExpr {
  GateExpr::{ kind: GateKind::Swap, args: [target1, target2] }
}

///|
pub fn cnot_gate(control : Int, target : Int) -> GateExpr {
  GateExpr::{ kind: GateKind::CNot, args: [control, target] }
}

///|
fn gate_tuple_expr(items : Array[Int]) -> @symcore.Expr {
  @symcore.raw_function("Tuple", items.map(@symcore.int))
}

///|
fn gate_tuple_ints(expr : @symcore.Expr) -> Array[Int]? {
  match expr {
    @symcore.Expr::Function("Tuple", args) => {
      let out : Array[Int] = []
      for arg in args {
        match arg {
          @symcore.Expr::Number(n) if n.is_integral() => out.push(n.numerator().to_int())
          _ => return None
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
pub fn cgate(controls : Array[Int], gate_expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("CGate", [gate_tuple_expr(controls), gate_expr])
}

///|
pub fn cphase(control : Int, target : Int) -> @symcore.Expr {
  cgate([control], z_gate(target).as_expr())
}

///|
pub fn GateExpr::as_expr(self : GateExpr) -> @symcore.Expr {
  @symcore.raw_function(gate_class_name(self.kind), self.args.map(@symcore.int))
}

///|
pub fn GateExpr::to_string(self : GateExpr) -> String {
  let rendered = self.args.map(arg => arg.to_string()).join(",")
  "\{gate_alias_name(self.kind)}(\{rendered})"
}

///|
pub fn GateExpr::repr(self : GateExpr) -> String {
  let rendered = self.args.map(arg => "Integer(\{arg.to_string()})").join(",")
  "\{gate_class_name(self.kind)}(\{rendered})"
}

///|
fn sqrt2_over_2() -> @symcore.Expr {
  try! @symcore.rational_from_ints(1, 2) * @symcore.raw_function("sqrt", [@symcore.int(2)])
}

///|
fn gate_phase_t() -> @symcore.Expr {
  let quarter = try! @symcore.rational_from_ints(1, 4)
  @symcore.raw_function("exp", [@symcore.symbol("I") * @symcore.symbol("pi") * quarter])
}

///|
pub fn GateExpr::target_matrix(self : GateExpr) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.kind {
    GateKind::Identity => @symphysics.explicit_matrix_from_rows([
      [@symcore.int(1), @symcore.int(0)],
      [@symcore.int(0), @symcore.int(1)],
    ])
    GateKind::Hadamard => {
      let s = sqrt2_over_2()
      @symphysics.explicit_matrix_from_rows([
        [s, s],
        [s, @symcore.int(-1) * s],
      ])
    }
    GateKind::X => @symphysics.explicit_matrix_from_rows([
      [@symcore.int(0), @symcore.int(1)],
      [@symcore.int(1), @symcore.int(0)],
    ])
    GateKind::Y => {
      let i = @symcore.symbol("I")
      @symphysics.explicit_matrix_from_rows([
        [@symcore.int(0), @symcore.int(-1) * i],
        [i, @symcore.int(0)],
      ])
    }
    GateKind::Z => @symphysics.explicit_matrix_from_rows([
      [@symcore.int(1), @symcore.int(0)],
      [@symcore.int(0), @symcore.int(-1)],
    ])
    GateKind::Phase => {
      let i = @symcore.symbol("I")
      @symphysics.explicit_matrix_from_rows([
        [@symcore.int(1), @symcore.int(0)],
        [@symcore.int(0), i],
      ])
    }
    GateKind::T => @symphysics.explicit_matrix_from_rows([
      [@symcore.int(1), @symcore.int(0)],
      [@symcore.int(0), gate_phase_t()],
    ])
    GateKind::Swap => @symphysics.explicit_matrix_from_rows([
      [@symcore.int(1), @symcore.int(0), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(0), @symcore.int(0), @symcore.int(1), @symcore.int(0)],
      [@symcore.int(0), @symcore.int(1), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(0), @symcore.int(0), @symcore.int(0), @symcore.int(1)],
    ])
    GateKind::CNot => @symphysics.explicit_matrix_from_rows([
      [@symcore.int(1), @symcore.int(0), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(0), @symcore.int(1), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(0), @symcore.int(0), @symcore.int(0), @symcore.int(1)],
      [@symcore.int(0), @symcore.int(0), @symcore.int(1), @symcore.int(0)],
    ])
  }
}

///|
pub fn gate_from_expr(expr : @symcore.Expr) -> GateExpr? {
  match expr {
    @symcore.Expr::Function(name, args) => {
      let ints : Array[Int] = []
      for arg in args {
        match arg {
          @symcore.Expr::Number(n) if n.is_integral() => ints.push(n.numerator().to_int())
          _ => return None
        }
      }
      match name {
        "IdentityGate" if ints.length() == 1 => Some(identity_gate(ints[0]))
        "HadamardGate" if ints.length() == 1 => Some(hadamard_gate(ints[0]))
        "XGate" if ints.length() == 1 => Some(x_gate(ints[0]))
        "YGate" if ints.length() == 1 => Some(y_gate(ints[0]))
        "ZGate" if ints.length() == 1 => Some(z_gate(ints[0]))
        "PhaseGate" if ints.length() == 1 => Some(phase_gate(ints[0]))
        "TGate" if ints.length() == 1 => Some(t_gate(ints[0]))
        "SwapGate" if ints.length() == 2 => Some(swap_gate(ints[0], ints[1]))
        "CNotGate" if ints.length() == 2 => Some(cnot_gate(ints[0], ints[1]))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn gate_apply_single_qubit(
  matrix : @symphysics.ExplicitMatrix,
  q : QubitExpr,
  target : Int,
) -> @symcore.Expr raise @symphysics.PhysicsError {
  let current = try! q.bit(target)
  let pos = q.bits.length() - 1 - target
  let terms : Array[@symcore.Expr] = []
  for row in 0..<2 {
    let coeff = matrix.get(row, current)
    if coeff != @symcore.int(0) {
      let bits = q.bits.copy()
      bits[pos] = row
      let next_q = try! qubit_from_bits(bits, bra=q.is_bra)
      if coeff == @symcore.int(1) {
        terms.push(next_q.as_expr())
      } else {
        terms.push(coeff * next_q.as_expr())
      }
    }
  }
  quantum_add_from_args_preserve(terms)
}

///|
fn gate_apply_concrete(
  gate : GateExpr,
  q : QubitExpr,
  qubit_expr : @symcore.Expr,
) -> @symcore.Expr? raise @symphysics.PhysicsError {
  for arg in gate.args {
    guard arg >= 0 && arg < q.nqubits() else {
      raise @symphysics.PhysicsError::IndexError("Gate target/control index out of range")
    }
  }
  match gate.kind {
    GateKind::Identity => Some(qubit_expr)
    GateKind::Hadamard | GateKind::X | GateKind::Y | GateKind::Z | GateKind::Phase | GateKind::T =>
      Some(try! gate_apply_single_qubit(try! gate.target_matrix(), q, gate.args[0]))
    GateKind::Swap => {
      let left = q.bits.length() - 1 - gate.args[0]
      let right = q.bits.length() - 1 - gate.args[1]
      let bits = q.bits.copy()
      let tmp = bits[left]
      bits[left] = bits[right]
      bits[right] = tmp
      Some((try! qubit_from_bits(bits, bra=q.is_bra, int_form=q.int_form)).as_expr())
    }
    GateKind::CNot => {
      let control = try! q.bit(gate.args[0])
      if control == 0 {
        Some(qubit_expr)
      } else {
        Some((try! q.flip(gate.args[1])).as_expr())
      }
    }
  }
}

///|
fn gate_support(expr : @symcore.Expr) -> Array[Int]? {
  match gate_from_expr(expr) {
    Some(gate) => Some(gate.args.copy())
    None =>
      match expr {
        @symcore.Expr::Function("CGate", args) if args.length() == 2 =>
          match gate_tuple_ints(args[0]) {
            Some(controls) =>
              match gate_support(args[1]) {
                Some(base) => {
                  let out = controls.copy()
                  for item in base {
                    out.push(item)
                  }
                  Some(out)
                }
                None => None
              }
            None => None
          }
        _ => None
      }
  }
}

///|
pub fn gate_apply_to_qubit_expr(
  gate_expr : @symcore.Expr,
  qubit_expr : @symcore.Expr,
) -> @symcore.Expr? raise @symphysics.PhysicsError {
  match qubit_from_expr(qubit_expr) {
    Some(q) =>
      match gate_from_expr(gate_expr) {
        Some(gate) => gate_apply_concrete(gate, q, qubit_expr)
        None =>
          match gate_expr {
            @symcore.Expr::Function("CGate", args) if args.length() == 2 =>
              match gate_tuple_ints(args[0]) {
                Some(controls) => {
                  for control in controls {
                    guard control >= 0 && control < q.nqubits() else {
                      raise @symphysics.PhysicsError::IndexError(
                        "Gate target/control index out of range",
                      )
                    }
                  }
                  let mut active = true
                  for control in controls {
                    active = active && (try! q.bit(control) == 1)
                  }
                  if active {
                    match gate_apply_to_qubit_expr(args[1], qubit_expr) {
                      Some(applied) => Some(applied)
                      None => try! qft_apply_operator_to_ket(args[1], qubit_expr)
                    }
                  } else {
                    Some(qubit_expr)
                  }
                }
                None => None
              }
            _ => None
          }
      }
    None => None
  }
}

///|
pub fn represent_gate_expr_zbasis(
  gate_expr : @symcore.Expr,
  nqubits : Int,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  let size = 1 << nqubits
  let rows : Array[Array[@symcore.Expr]] = []
  for _ in 0..<size {
    rows.push(Array::make(size, @symcore.int(0)))
  }
  for col in 0..<size {
    let basis_expr = (try! qubit_from_bits(int_to_bits(col, nqubits))).as_expr()
    let maybe_applied = gate_apply_to_qubit_expr(gate_expr, basis_expr)
    let applied = maybe_applied.unwrap_or_else(() => basis_expr)
    let vec = qubit_to_matrix(applied, nqubits=nqubits)
    for row in 0..<size {
      rows[row][col] = vec.get(row, 0)
    }
  }
  @symphysics.explicit_matrix_from_rows(rows)
}

///|
pub fn GateExpr::represent_zbasis(
  self : GateExpr,
  nqubits : Int,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  represent_gate_expr_zbasis(self.as_expr(), nqubits)
}

///|
fn gate_is_identity_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() && n.numerator().to_int() == 1 => true
    @symcore.Expr::Function("IdentityGate", _) => true
    _ => false
  }
}

///|
fn gate_is_involution(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Function("CGate", args) if args.length() == 2 => gate_is_involution(args[1])
    @symcore.Expr::Function(name, _) =>
      ["IdentityGate", "HadamardGate", "XGate", "YGate", "ZGate", "SwapGate", "CNotGate"].contains(name)
    _ => false
  }
}

///|
fn gate_compose_pair(lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr? {
  if gate_is_identity_expr(lhs) {
    return Some(rhs)
  }
  if gate_is_identity_expr(rhs) {
    return Some(lhs)
  }
  if lhs == rhs && gate_is_involution(lhs) {
    return Some(@symcore.int(1))
  }
  match (gate_from_expr(lhs), gate_from_expr(rhs)) {
    (Some(left), Some(right)) if left == right && left.kind == GateKind::Phase =>
      Some(z_gate(left.args[0]).as_expr())
    (Some(left), Some(right)) if left == right && left.kind == GateKind::T =>
      Some(phase_gate(left.args[0]).as_expr())
    _ => None
  }
}

///|
pub fn gate_simp(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Mul(args) => {
      let factors = args.copy()
      let mut changed = true
      while changed {
        changed = false
        if factors.length() <= 1 {
          break
        }
        for idx in 0..<(factors.length() - 1) {
          match gate_compose_pair(factors[idx], factors[idx + 1]) {
            Some(replacement) => {
              let rebuilt : Array[@symcore.Expr] = []
              for prefix in 0..<idx {
                rebuilt.push(factors[prefix])
              }
              if !gate_is_identity_expr(replacement) {
                rebuilt.push(replacement)
              }
              for suffix in (idx + 2)..<factors.length() {
                rebuilt.push(factors[suffix])
              }
              factors.clear()
              for item in rebuilt {
                factors.push(item)
              }
              changed = true
              break
            }
            None => ()
          }
        }
      }
      quantum_mul_from_args_preserve(factors)
    }
    _ => expr
  }
}

///|
fn supports_disjoint(lhs : Array[Int], rhs : Array[Int]) -> Bool {
  for item in lhs {
    if rhs.contains(item) {
      return false
    }
  }
  true
}

///|
pub fn gate_sort(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Mul(args) => {
      let factors = args.copy()
      if factors.length() <= 1 {
        return expr
      }
      let mut changed = true
      while changed {
        changed = false
        for idx in 0..<(factors.length() - 1) {
          match (gate_support(factors[idx]), gate_support(factors[idx + 1])) {
            (Some(lhs), Some(rhs)) if supports_disjoint(lhs, rhs) && factors[idx].compare(factors[idx + 1]) > 0 => {
              let tmp = factors[idx]
              factors[idx] = factors[idx + 1]
              factors[idx + 1] = tmp
              changed = true
            }
            _ => ()
          }
        }
      }
      quantum_mul_from_args_preserve(factors)
    }
    _ => expr
  }
}
