///|
/// Shared symbolic helpers for `symphysics/quantum`.

///|
fn quantum_reserved_operator_name(name : String) -> Bool {
  match name {
    "AntiCommutator" | "BosonCoherentBra" | "BosonCoherentKet" | "BosonFockBra" |
    "BosonFockKet" | "BosonOp" | "Bra" | "CGate" | "Commutator" | "Dagger" |
    "Density" | "DifferentialOperator" | "FermionFockBra" | "FermionFockKet" | "FermionOp" | "Gate" | "HadamardGate" |
    "HermitianOperator" | "IdentityGate" | "IdentityOperator" | "InnerProduct" |
    "JxBra" | "JxKet" | "JyBra" | "JyKet" | "JzBra" | "JzKet" |
    "Ket" | "OuterProduct" | "OrthogonalBra" | "OrthogonalKet" |
    "OracleGate" |
    "Operator" | "PhaseGate" | "PIABBra" | "PIABHamiltonian" | "PIABKet" |
    "PositionBra3D" | "PositionKet3D" | "PxBra" | "PxKet" | "PxOp" |
    "IQFT" | "QFT" | "Qubit" | "QubitBra" | "RaisingOp" | "RkGate" | "SHOBra" | "SHOKet" |
    "SigmaMinus" | "SigmaPlus" | "SigmaX" | "SigmaY" | "SigmaZ" |
    "SigmaZBra" | "SigmaZKet" | "SwapGate" | "TensorProduct" | "TGate" |
    "TimeDepBra" | "TimeDepKet" | "Tr" | "UGate" | "UnitaryOperator" |
    "Wavefunction" | "WGate" | "XBra" | "XGate" | "XKet" | "XOp" | "YGate" |
    "YOp" | "ZGate" | "ZOp" | "NumberOp" | "Hamiltonian" | "LoweringOp" => true
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
fn quantum_is_scalar_like(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(_) => true
    @symcore.Expr::Symbol(name) => quantum_symbol_is_scalar(name)
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) => args.all(quantum_is_scalar_like)
    @symcore.Expr::Pow(base, exp) => quantum_is_scalar_like(base) && quantum_is_scalar_like(exp)
    @symcore.Expr::Function(name, args) =>
      !quantum_reserved_operator_name(name) && args.all(quantum_is_scalar_like)
  }
}

///|
fn quantum_mul_from_args_preserve(args : Array[@symcore.Expr]) -> @symcore.Expr {
  match args.length() {
    0 => @symcore.int(1)
    1 => args[0]
    _ => @symcore.raw_mul(args)
  }
}

///|
fn quantum_add_from_args_preserve(args : Array[@symcore.Expr]) -> @symcore.Expr {
  match args.length() {
    0 => @symcore.int(0)
    1 => args[0]
    _ => @symcore.raw_add(args)
  }
}

///|
fn quantum_mul_slice(
  args : Array[@symcore.Expr],
  start : Int,
  stop : Int,
) -> @symcore.Expr {
  let out : Array[@symcore.Expr] = []
  for idx in start..<stop {
    out.push(args[idx])
  }
  quantum_mul_from_args_preserve(out)
}

///|
fn quantum_integer_value(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn quantum_tuple_expr(items : Array[Int]) -> @symcore.Expr {
  @symcore.raw_function("Tuple", items.map(@symcore.int))
}

///|
fn quantum_split_scalar_factors(
  expr : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr?) {
  if quantum_is_scalar_like(expr) {
    return (expr, None)
  }
  match expr {
    @symcore.Expr::Mul(args) => {
      let scalars : Array[@symcore.Expr] = []
      let nonscalars : Array[@symcore.Expr] = []
      for arg in args {
        if quantum_is_scalar_like(arg) {
          scalars.push(arg)
        } else {
          nonscalars.push(arg)
        }
      }
      let scalar = if scalars.is_empty() { @symcore.int(1) } else { @symcore.mul(scalars) }
      let body =
        if nonscalars.is_empty() {
          None
        } else {
          Some(quantum_mul_from_args_preserve(nonscalars))
        }
      (scalar, body)
    }
    _ => (@symcore.int(1), Some(expr))
  }
}
