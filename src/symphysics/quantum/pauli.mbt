///|
/// Pauli operators, computational two-level states, and the local
/// simplification rules from `sympy.physics.quantum.pauli`.
///
/// This covers `SigmaX/Y/Z`, `SigmaPlus/Minus`, `SigmaZKet/Bra`, exact action
/// on the two-level basis, exact 2x2 matrix representations, and the
/// `qsimplify_pauli` product rules for same-label Pauli operators.

///|
pub enum PauliKind {
  X
  Y
  Z
  Plus
  Minus
} derive(Eq)

///|
pub struct PauliExpr {
  kind : PauliKind
  name : Expr?
} derive(Eq)

///|
fn pauli_class_name(kind : PauliKind) -> String {
  match kind {
    PauliKind::X => "SigmaX"
    PauliKind::Y => "SigmaY"
    PauliKind::Z => "SigmaZ"
    PauliKind::Plus => "SigmaPlus"
    PauliKind::Minus => "SigmaMinus"
  }
}

///|
pub fn sigma_x(name? : Expr? = None) -> PauliExpr {
  PauliExpr::{ kind: PauliKind::X, name }
}

///|
pub fn sigma_y(name? : Expr? = None) -> PauliExpr {
  PauliExpr::{ kind: PauliKind::Y, name }
}

///|
pub fn sigma_z(name? : Expr? = None) -> PauliExpr {
  PauliExpr::{ kind: PauliKind::Z, name }
}

///|
pub fn sigma_plus(name? : Expr? = None) -> PauliExpr {
  PauliExpr::{ kind: PauliKind::Plus, name }
}

///|
pub fn sigma_minus(name? : Expr? = None) -> PauliExpr {
  PauliExpr::{ kind: PauliKind::Minus, name }
}

///|
pub fn PauliExpr::as_expr(self : PauliExpr) -> Expr {
  match self.name {
    Some(name) => @symcore.raw_function(pauli_class_name(self.kind), [name])
    None => @symcore.raw_function(pauli_class_name(self.kind), [])
  }
}

///|
pub fn PauliExpr::repr(self : PauliExpr) -> String {
  match self.name {
    Some(name) => "\{pauli_class_name(self.kind)}(\{quantum_repr_expr(name)})"
    None => "\{pauli_class_name(self.kind)}()"
  }
}

///|
pub impl Show for PauliExpr with to_string(self) {
  match self.name {
    Some(name) => "\{pauli_class_name(self.kind)}(\{@symprint.to_string(name)})"
    None => "\{pauli_class_name(self.kind)}()"
  }
}

///|
pub impl Show for PauliExpr with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
fn pauli_kind_from_name(name : String) -> PauliKind? {
  match name {
    "SigmaX" => Some(PauliKind::X)
    "SigmaY" => Some(PauliKind::Y)
    "SigmaZ" => Some(PauliKind::Z)
    "SigmaPlus" => Some(PauliKind::Plus)
    "SigmaMinus" => Some(PauliKind::Minus)
    _ => None
  }
}

///|
fn pauli_name_equal(lhs : Expr?, rhs : Expr?) -> Bool {
  match (lhs, rhs) {
    (None, None) => true
    (Some(a), Some(b)) => a == b
    _ => false
  }
}

///|
fn pauli_exact_rational(num : Int, den : Int) -> Expr {
  let result : Result[Expr, @symnum.RationalError] = try? @symcore.rational_from_ints(
    num, den,
  )
  match result {
    Ok(value) => value
    Err(_) => int(num) * @symcore.raw_pow(int(den), int(-1))
  }
}

///|
fn pauli_half() -> Expr {
  pauli_exact_rational(1, 2)
}

///|
pub fn pauli_from_expr(expr : Expr) -> PauliExpr? {
  match expr {
    Expr::Function(name, args) =>
      match pauli_kind_from_name(name) {
        Some(kind) =>
          match args.length() {
            0 => Some(PauliExpr::{ kind, name: None })
            1 => Some(PauliExpr::{ kind, name: Some(args[0]) })
            _ => None
          }
        None => None
      }
    _ => None
  }
}

///|
pub struct SigmaZState {
  n : Int
  is_bra : Bool
} derive(Eq)

///|
pub fn sigma_z_ket(n : Int) -> SigmaZState raise @symphysics.PhysicsError {
  guard n == 0 || n == 1 else {
    raise @symphysics.PhysicsError::ValueError("SigmaZKet expects n in {0, 1}")
  }
  SigmaZState::{ n, is_bra: false }
}

///|
pub fn sigma_z_bra(n : Int) -> SigmaZState raise @symphysics.PhysicsError {
  guard n == 0 || n == 1 else {
    raise @symphysics.PhysicsError::ValueError("SigmaZBra expects n in {0, 1}")
  }
  SigmaZState::{ n, is_bra: true }
}

///|
pub fn SigmaZState::as_expr(self : SigmaZState) -> Expr {
  let class_name = if self.is_bra { "SigmaZBra" } else { "SigmaZKet" }
  @symcore.raw_function(class_name, [int(self.n)])
}

///|
pub impl Show for SigmaZState with to_string(self) {
  if self.is_bra {
    "<\{self.n.to_string()}|"
  } else {
    "|\{self.n.to_string()}>"
  }
}

///|
pub impl Show for SigmaZState with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn SigmaZState::dual(self : SigmaZState) -> SigmaZState {
  SigmaZState::{ n: self.n, is_bra: !self.is_bra }
}

///|
pub fn sigma_z_state_from_expr(expr : Expr) -> SigmaZState? {
  match expr {
    Expr::Function(name, args) if (name == "SigmaZKet" || name == "SigmaZBra") &&
      args.length() == 1 =>
      match args[0] {
        Expr::Number(n) if n.is_integral() => {
          let value = n.numerator().to_int()
          if value == 0 || value == 1 {
            Some(SigmaZState::{ n: value, is_bra: name == "SigmaZBra" })
          } else {
            None
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
pub fn pauli_apply_operator_to_ket(op_expr : Expr, ket_expr : Expr) -> Expr? {
  match (pauli_from_expr(op_expr), sigma_z_state_from_expr(ket_expr)) {
    (Some(op), Some(state)) if !state.is_bra =>
      match op.kind {
        PauliKind::Z =>
          Some(if state.n == 0 { ket_expr } else { int(-1) * ket_expr })
        PauliKind::X =>
          Some(
            SigmaZState::{ n: if state.n == 0 { 1 } else { 0 }, is_bra: false }.as_expr(),
          )
        PauliKind::Y =>
          Some(
            if state.n == 0 {
              symbol("I") * SigmaZState::{ n: 1, is_bra: false }.as_expr()
            } else {
              int(-1) *
              symbol("I") *
              SigmaZState::{ n: 0, is_bra: false }.as_expr()
            },
          )
        PauliKind::Minus =>
          Some(
            if state.n == 0 {
              SigmaZState::{ n: 1, is_bra: false }.as_expr()
            } else {
              int(0)
            },
          )
        PauliKind::Plus =>
          Some(
            if state.n == 0 {
              int(0)
            } else {
              SigmaZState::{ n: 0, is_bra: false }.as_expr()
            },
          )
      }
    _ => None
  }
}

///|
pub fn represent_pauli_operator(
  expr : Expr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match pauli_from_expr(expr) {
    Some(op) =>
      match op.kind {
        PauliKind::X =>
          @symphysics.explicit_matrix_from_rows([
            [int(0), int(1)],
            [int(1), int(0)],
          ])
        PauliKind::Y =>
          @symphysics.explicit_matrix_from_rows([
            [int(0), int(-1) * symbol("I")],
            [symbol("I"), int(0)],
          ])
        PauliKind::Z =>
          @symphysics.explicit_matrix_from_rows([
            [int(1), int(0)],
            [int(0), int(-1)],
          ])
        PauliKind::Plus =>
          @symphysics.explicit_matrix_from_rows([
            [int(0), int(1)],
            [int(0), int(0)],
          ])
        PauliKind::Minus =>
          @symphysics.explicit_matrix_from_rows([
            [int(0), int(0)],
            [int(1), int(0)],
          ])
      }
    None =>
      raise @symphysics.PhysicsError::ValueError("Expected a Pauli operator")
  }
}

///|
pub fn represent_pauli_state(
  expr : Expr,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match sigma_z_state_from_expr(expr) {
    Some(state) =>
      if state.is_bra {
        @symphysics.explicit_matrix_from_rows([
          [
            if state.n == 0 {
              int(1)
            } else {
              int(0)
            },
            if state.n == 1 {
              int(1)
            } else {
              int(0)
            },
          ],
        ])
      } else {
        @symphysics.explicit_matrix_from_rows([
          [if state.n == 0 { int(1) } else { int(0) }],
          [if state.n == 1 { int(1) } else { int(0) }],
        ])
      }
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "Expected a SigmaZ basis state",
      )
  }
}

///|
fn pauli_product_pair(lhs : PauliExpr, rhs : PauliExpr) -> Expr {
  if !pauli_name_equal(lhs.name, rhs.name) {
    if lhs.as_expr().compare(rhs.as_expr()) <= 0 {
      return quantum_mul_from_args_preserve([lhs.as_expr(), rhs.as_expr()])
    } else {
      return quantum_mul_from_args_preserve([rhs.as_expr(), lhs.as_expr()])
    }
  }
  match (lhs.kind, rhs.kind) {
    (PauliKind::X, PauliKind::X)
    | (PauliKind::Y, PauliKind::Y)
    | (PauliKind::Z, PauliKind::Z) => int(1)
    (PauliKind::X, PauliKind::Y) =>
      symbol("I") * sigma_z(name=lhs.name).as_expr()
    (PauliKind::Y, PauliKind::X) =>
      int(-1) * symbol("I") * sigma_z(name=lhs.name).as_expr()
    (PauliKind::X, PauliKind::Z) =>
      int(-1) * symbol("I") * sigma_y(name=lhs.name).as_expr()
    (PauliKind::Z, PauliKind::X) =>
      symbol("I") * sigma_y(name=lhs.name).as_expr()
    (PauliKind::Y, PauliKind::Z) =>
      symbol("I") * sigma_x(name=lhs.name).as_expr()
    (PauliKind::Z, PauliKind::Y) =>
      int(-1) * symbol("I") * sigma_x(name=lhs.name).as_expr()
    (PauliKind::Z, PauliKind::Minus) =>
      int(-1) * sigma_minus(name=lhs.name).as_expr()
    (PauliKind::Minus, PauliKind::Z) => sigma_minus(name=lhs.name).as_expr()
    (PauliKind::Z, PauliKind::Plus) => sigma_plus(name=lhs.name).as_expr()
    (PauliKind::Plus, PauliKind::Z) =>
      int(-1) * sigma_plus(name=lhs.name).as_expr()
    (PauliKind::Minus, PauliKind::Minus) | (PauliKind::Plus, PauliKind::Plus) =>
      int(0)
    (PauliKind::Minus, PauliKind::Plus) =>
      pauli_half() - pauli_half() * sigma_z(name=lhs.name).as_expr()
    (PauliKind::Plus, PauliKind::Minus) =>
      pauli_half() + pauli_half() * sigma_z(name=lhs.name).as_expr()
    (PauliKind::X, PauliKind::Minus) =>
      pauli_half() + pauli_half() * sigma_z(name=lhs.name).as_expr()
    (PauliKind::Minus, PauliKind::X) =>
      pauli_half() - pauli_half() * sigma_z(name=lhs.name).as_expr()
    (PauliKind::X, PauliKind::Plus) =>
      pauli_half() - pauli_half() * sigma_z(name=lhs.name).as_expr()
    (PauliKind::Plus, PauliKind::X) =>
      pauli_half() + pauli_half() * sigma_z(name=lhs.name).as_expr()
    (PauliKind::Y, PauliKind::Minus) =>
      int(-1) *
      symbol("I") *
      (pauli_half() + pauli_half() * sigma_z(name=lhs.name).as_expr())
    (PauliKind::Minus, PauliKind::Y) =>
      int(-1) *
      symbol("I") *
      (pauli_half() - pauli_half() * sigma_z(name=lhs.name).as_expr())
    (PauliKind::Y, PauliKind::Plus) =>
      symbol("I") *
      (pauli_half() - pauli_half() * sigma_z(name=lhs.name).as_expr())
    (PauliKind::Plus, PauliKind::Y) =>
      symbol("I") *
      (pauli_half() + pauli_half() * sigma_z(name=lhs.name).as_expr())
  }
}

///|
pub fn qsimplify_pauli(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => quantum_add_from_args_preserve(args.map(qsimplify_pauli))
    Expr::Pow(base, exp) =>
      @symcore.raw_pow(qsimplify_pauli(base), qsimplify_pauli(exp))
    Expr::Function(name, args) if name == "exp" =>
      @symcore.raw_function(name, args.map(qsimplify_pauli))
    Expr::Mul(args) => {
      let factors = args.map(qsimplify_pauli)
      let scalars : Array[Expr] = []
      let nonscalars : Array[Expr] = []
      for factor in factors {
        if quantum_is_scalar_like(factor) {
          scalars.push(factor)
        } else {
          nonscalars.push(factor)
        }
      }
      let reduced : Array[Expr] = []
      let mut idx = 0
      while idx < nonscalars.length() {
        let current = nonscalars[idx]
        if idx + 1 < nonscalars.length() {
          match
            (pauli_from_expr(current), pauli_from_expr(nonscalars[idx + 1])) {
            (Some(lhs), Some(rhs)) if pauli_name_equal(lhs.name, rhs.name) => {
              let simplified = qsimplify_pauli(pauli_product_pair(lhs, rhs))
              for item in quantum_pair_to_factors(simplified) {
                if quantum_is_scalar_like(item) {
                  scalars.push(item)
                } else {
                  reduced.push(item)
                }
              }
              idx += 2
              continue
            }
            _ => ()
          }
        }
        reduced.push(current)
        idx += 1
      }
      let out = scalars.copy()
      for factor in reduced {
        out.push(factor)
      }
      quantum_mul_from_args_preserve(out)
    }
    _ => expr
  }
}
