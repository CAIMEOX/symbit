///|
/// Core symbolic metadata helpers for `symphysics/quantum`.
///
/// SymPy models all quantum objects as noncommutative `QExpr` subclasses.
/// MoonBit does not have that inheritance stack, so this package uses a small
/// explicit record plus predicate helpers over `Expr` constructor
/// forms like `Ket(...)`, `Operator(...)`, and `BosonOp(...)`.

///|
pub struct QExpr {
  class_name : String
  args : Array[Expr]
  hilbert_space : HilbertSpace
} derive(Eq)

///|
fn quantum_repr_expr(expr : Expr) -> String {
  match expr {
    Expr::Number(n) if n.is_integral() =>
      "Integer(\{n.numerator().to_string()})"
    Expr::Number(n) =>
      "Rational(\{n.numerator().to_string()}, \{n.denominator().to_string()})"
    Expr::Symbol(name) if name == "oo" => "oo"
    Expr::Symbol(name) => "Symbol('\{name}')"
    Expr::Function(name, args) => {
      let rendered = args.map(quantum_repr_expr).join(",")
      "\{name}(\{rendered})"
    }
    Expr::Pow(base, exp) =>
      "Pow(\{quantum_repr_expr(base)},\{quantum_repr_expr(exp)})"
    _ => @symprint.to_string(expr)
  }
}

///|
pub fn quantum_join_label(
  args : Array[Expr],
  separator? : String = "",
) -> String {
  args.map(@symprint.to_string).join(separator)
}

///|
pub fn qexpr(
  args : Array[Expr],
  class_name? : String = "QExpr",
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> QExpr {
  QExpr::{ class_name, args, hilbert_space }
}

///|
pub fn QExpr::label(self : QExpr) -> Array[Expr] {
  self.args
}

///|
pub fn QExpr::as_expr(self : QExpr) -> Expr {
  @symcore.raw_function(self.class_name, self.args)
}

///|
pub impl Show for QExpr with to_string(self) {
  quantum_join_label(self.args)
}

///|
pub impl Show for QExpr with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn QExpr::repr(self : QExpr) -> String {
  let rendered = self.args.map(quantum_repr_expr).join(",")
  "\{self.class_name}(\{rendered})"
}

///|
pub fn quantum_expr_name(expr : Expr) -> String? {
  match expr {
    Expr::Function(name, _) => Some(name)
    _ => None
  }
}

///|
pub fn quantum_expr_args(expr : Expr) -> Array[Expr]? {
  match expr {
    Expr::Function(_, args) => Some(args)
    _ => None
  }
}

///|
pub fn quantum_expr_has_name(expr : Expr, name : String) -> Bool {
  match expr {
    Expr::Function(expr_name, _) => expr_name == name
    _ => false
  }
}

///|
pub fn quantum_expr_has_any_name(expr : Expr, names : Array[String]) -> Bool {
  match quantum_expr_name(expr) {
    Some(name) => names.contains(name)
    None => false
  }
}

///|
pub fn quantum_is_ket_expr(expr : Expr) -> Bool {
  quantum_expr_has_any_name(expr, [
    "Ket", "TimeDepKet", "OrthogonalKet", "BosonFockKet", "BosonCoherentKet", "FermionFockKet",
    "FockStateBosonKet", "FockStateFermionKet", "Qubit", "IntQubit", "JxKet", "JyKet",
    "JzKet", "JxKetCoupled", "JyKetCoupled", "JzKetCoupled", "PxKet", "PositionKet3D",
    "SHOKet", "PIABKet", "SigmaZKet", "XKet",
  ])
}

///|
pub fn quantum_is_bra_expr(expr : Expr) -> Bool {
  quantum_expr_has_any_name(expr, [
    "Bra", "TimeDepBra", "OrthogonalBra", "BosonFockBra", "BosonCoherentBra", "FermionFockBra",
    "FockStateBosonBra", "FockStateFermionBra", "QubitBra", "IntQubitBra", "JxBra",
    "JyBra", "JzBra", "JxBraCoupled", "JyBraCoupled", "JzBraCoupled", "PxBra", "PositionBra3D",
    "SHOBra", "PIABBra", "SigmaZBra", "XBra",
  ])
}

///|
pub fn quantum_is_state_expr(expr : Expr) -> Bool {
  quantum_is_ket_expr(expr) ||
  quantum_is_bra_expr(expr) ||
  quantum_expr_has_name(expr, "Wavefunction")
}

///|
pub fn quantum_is_operator_expr(expr : Expr) -> Bool {
  match expr {
    Expr::Symbol(name) =>
      ["Jplus", "Jminus", "Jx", "Jy", "Jz", "J2"].contains(name)
    _ =>
      quantum_expr_has_any_name(expr, [
        "Operator", "HermitianOperator", "UnitaryOperator", "IdentityOperator", "DifferentialOperator",
        "OuterProduct", "BosonOp", "CMod", "Commutator", "AntiCommutator", "FermionOp",
        "AnnihilateBoson", "CreateBoson", "Gate", "CGate", "UGate", "OracleGate",
        "WGate", "QFT", "IQFT", "RkGate", "IdentityGate", "HadamardGate", "XGate",
        "YGate", "ZGate", "TGate", "PhaseGate", "SwapGate", "CNotGate", "SigmaX",
        "SigmaY", "SigmaZ", "SigmaPlus", "SigmaMinus", "Rotation", "WignerD", "Density",
        "Hamiltonian", "LoweringOp", "NumberOp", "PIABHamiltonian", "PxOp", "RaisingOp",
        "XOp", "YOp", "ZOp",
      ])
  }
}

///|
pub fn quantum_state_or_operator(expr : Expr) -> Bool {
  quantum_is_state_expr(expr) || quantum_is_operator_expr(expr)
}
