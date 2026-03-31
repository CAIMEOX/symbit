///|
/// Shared symbolic helpers for `symphysics/quantum`.

///|
fn quantum_reserved_operator_name(name : String) -> Bool {
  match name {
    "AntiCommutator"
    | "BosonCoherentBra"
    | "BosonCoherentKet"
    | "BosonFockBra"
    | "BosonFockKet"
    | "BosonOp"
    | "CreateBoson"
    | "Bra"
    | "CGate"
    | "Commutator"
    | "Dagger"
    | "CMod"
    | "Density"
    | "DifferentialOperator"
    | "FockStateBosonBra"
    | "FockStateBosonKet"
    | "FockStateFermionBra"
    | "FockStateFermionKet"
    | "FermionFockBra"
    | "FermionFockKet"
    | "FermionOp"
    | "Gate"
    | "HadamardGate"
    | "HermitianOperator"
    | "IdentityGate"
    | "IdentityOperator"
    | "InnerProduct"
    | "JxBra"
    | "JxKet"
    | "JxBraCoupled"
    | "JxKetCoupled"
    | "JyBra"
    | "JyKet"
    | "JyBraCoupled"
    | "JyKetCoupled"
    | "JzBra"
    | "JzKet"
    | "JzBraCoupled"
    | "JzKetCoupled"
    | "Ket"
    | "OuterProduct"
    | "OrthogonalBra"
    | "OrthogonalKet"
    | "OracleGate"
    | "Operator"
    | "PhaseGate"
    | "PIABBra"
    | "PIABHamiltonian"
    | "PIABKet"
    | "PositionBra3D"
    | "PositionKet3D"
    | "PxBra"
    | "PxKet"
    | "PxOp"
    | "IQFT"
    | "QFT"
    | "Qubit"
    | "QubitBra"
    | "RaisingOp"
    | "RkGate"
    | "SHOBra"
    | "SHOKet"
    | "SigmaMinus"
    | "SigmaPlus"
    | "SigmaX"
    | "SigmaY"
    | "SigmaZ"
    | "SigmaZBra"
    | "SigmaZKet"
    | "SwapGate"
    | "TensorProduct"
    | "TGate"
    | "TimeDepBra"
    | "TimeDepKet"
    | "Tr"
    | "AnnihilateBoson"
    | "UGate"
    | "UnitaryOperator"
    | "Wavefunction"
    | "WGate"
    | "XBra"
    | "XGate"
    | "XKet"
    | "XOp"
    | "YGate"
    | "YOp"
    | "ZGate"
    | "ZOp"
    | "NumberOp"
    | "Hamiltonian"
    | "LoweringOp" => true
    _ => false
  }
}

///|
fn quantum_symbol_is_scalar(name : String) -> Bool {
  if name == "I" || name == "oo" || name == "pi" || name == "zoo" {
    return true
  }
  let chars = name.to_array()
  if chars.is_empty() {
    return false
  }
  for ch in chars {
    if !((ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_') {
      return false
    }
  }
  true
}

///|
fn quantum_is_unitary_like_operator(expr : Expr) -> Bool {
  match @symcore.applied_parts(expr) {
    Some((name, _)) =>
      [
        "UnitaryOperator", "IdentityOperator", "Gate", "CGate", "UGate", "IdentityGate",
        "HadamardGate", "XGate", "YGate", "ZGate", "TGate", "PhaseGate", "SwapGate",
        "CNotGate", "QFT", "IQFT", "RkGate", "Rotation",
      ].contains(name)
    _ => false
  }
}

///|
fn quantum_is_scalar_like(expr : Expr) -> Bool {
  match @symcore.application_parts(expr) {
    Some((head, args)) =>
      return match @symcore.function_head_name(head) {
        Some(name) =>
          !quantum_reserved_operator_name(name) &&
          args.all(quantum_is_scalar_like)
        None => false
      }
    None => ()
  }
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_)
    | @symcore.ExprForm::Float(_)
    | @symcore.ExprForm::ComplexFloat(_) => true
    @symcore.ExprForm::NumberSymbol(_) => true
    @symcore.ExprForm::Symbol(name) => quantum_symbol_is_scalar(name)
    @symcore.ExprForm::Dummy(name, _) =>
      quantum_symbol_is_scalar(@symcore.dummy_display_name(name))
    @symcore.ExprForm::Wild(name, _, _) =>
      quantum_symbol_is_scalar(@symcore.wild_display_name(name))
    @symcore.ExprForm::FunctionHead(_) => false
    @symcore.ExprForm::UndefinedFunction(_) => false
    @symcore.ExprForm::Boolean(_) => true
    @symcore.ExprForm::Add(args) | @symcore.ExprForm::Mul(args) =>
      args.all(quantum_is_scalar_like)
    @symcore.ExprForm::Pow(base, exp) =>
      quantum_is_scalar_like(base) && quantum_is_scalar_like(exp)
    @symcore.ExprForm::Mod(lhs, rhs) =>
      quantum_is_scalar_like(lhs) && quantum_is_scalar_like(rhs)
    @symcore.ExprForm::Tuple(args) => args.all(quantum_is_scalar_like)
    @symcore.ExprForm::Dict(_) => false
    @symcore.ExprForm::Relational(_, lhs, rhs) =>
      quantum_is_scalar_like(lhs) && quantum_is_scalar_like(rhs)
    @symcore.ExprForm::Derivative(inner, deriv_args) =>
      quantum_is_scalar_like(inner) && deriv_args.all(quantum_is_scalar_like)
    @symcore.ExprForm::Subs(inner, sub_var, value) =>
      quantum_is_scalar_like(inner) &&
      quantum_is_scalar_like(sub_var) &&
      quantum_is_scalar_like(value)
    @symcore.ExprForm::Lambda(vars, body) =>
      quantum_is_scalar_like(vars) && quantum_is_scalar_like(body)
    _ => false
  }
}

///|
fn quantum_inverse_base(expr : Expr) -> Expr? {
  match expr {
    Expr::Pow(base, exp) =>
      match quantum_integer_value(exp) {
        Some(-1) => Some(base)
        _ => None
      }
    _ if quantum_expr_has_name(expr, "Dagger") =>
      match quantum_expr_args(expr) {
        Some([arg]) if quantum_is_unitary_like_operator(arg) => Some(arg)
        _ => None
      }
    _ => None
  }
}

///|
fn quantum_operator_pair_simplify(lhs : Expr, rhs : Expr) -> Expr? {
  if quantum_expr_has_name(lhs, "IdentityOperator") {
    return Some(rhs)
  }
  if quantum_expr_has_name(rhs, "IdentityOperator") {
    return Some(lhs)
  }
  match quantum_inverse_base(lhs) {
    Some(base) if base == rhs => Some(int(1))
    _ =>
      match quantum_inverse_base(rhs) {
        Some(base) if base == lhs => Some(int(1))
        _ => None
      }
  }
}

///|
fn quantum_mul_from_args_preserve(args : Array[Expr]) -> Expr {
  match args.length() {
    0 => int(1)
    1 => args[0]
    _ => @symcore.raw_mul(args)
  }
}

///|
fn quantum_add_from_args_preserve(args : Array[Expr]) -> Expr {
  match args.length() {
    0 => int(0)
    1 => args[0]
    _ => @symcore.raw_add(args)
  }
}

///|
fn quantum_mul_slice(args : Array[Expr], start : Int, stop : Int) -> Expr {
  let out : Array[Expr] = []
  for idx in start..<stop {
    out.push(args[idx])
  }
  quantum_mul_from_args_preserve(out)
}

///|
fn quantum_integer_value(expr : Expr) -> Int? {
  match expr {
    Expr::Number(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn quantum_tuple_expr(items : Array[Int]) -> Expr {
  @symcore.Expr::Tuple(items.map(@symcore.int))
}

///|
fn quantum_split_scalar_factors(expr : Expr) -> (Expr, Expr?) {
  if quantum_is_scalar_like(expr) {
    return (expr, None)
  }
  match expr {
    Expr::Mul(args) => {
      let scalars : Array[Expr] = []
      let nonscalars : Array[Expr] = []
      for arg in args {
        if quantum_is_scalar_like(arg) {
          scalars.push(arg)
        } else {
          nonscalars.push(arg)
        }
      }
      let scalar = if scalars.is_empty() {
        int(1)
      } else {
        @symcore.mul(scalars)
      }
      let body = if nonscalars.is_empty() {
        None
      } else {
        Some(quantum_mul_from_args_preserve(nonscalars))
      }
      (scalar, body)
    }
    _ => (int(1), Some(expr))
  }
}
