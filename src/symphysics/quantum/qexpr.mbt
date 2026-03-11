///|
/// Core symbolic metadata helpers for `symphysics/quantum`.
///
/// SymPy models all quantum objects as noncommutative `QExpr` subclasses.
/// MoonBit does not have that inheritance stack, so this package uses a small
/// explicit record plus predicate helpers over `@symcore.Expr` constructor
/// forms like `Ket(...)`, `Operator(...)`, and `BosonOp(...)`.

///|
pub struct QExpr {
  class_name : String
  args : Array[@symcore.Expr]
  hilbert_space : HilbertSpace
} derive(Eq)

///|
fn quantum_repr_expr(expr : @symcore.Expr) -> String {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() =>
      "Integer(\{n.numerator().to_string()})"
    @symcore.Expr::Number(n) =>
      "Rational(\{n.numerator().to_string()}, \{n.denominator().to_string()})"
    @symcore.Expr::Symbol(name) if name == "oo" => "oo"
    @symcore.Expr::Symbol(name) => "Symbol('\{name}')"
    @symcore.Expr::Function(name, args) => {
      let rendered = args.map(quantum_repr_expr).join(",")
      "\{name}(\{rendered})"
    }
    @symcore.Expr::Pow(base, exp) =>
      "Pow(\{quantum_repr_expr(base)},\{quantum_repr_expr(exp)})"
    _ => @symprint.to_string(expr)
  }
}

///|
pub fn quantum_join_label(args : Array[@symcore.Expr], separator? : String = "") -> String {
  args.map(@symprint.to_string).join(separator)
}

///|
pub fn qexpr(
  args : Array[@symcore.Expr],
  class_name? : String = "QExpr",
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> QExpr {
  QExpr::{ class_name, args, hilbert_space }
}

///|
pub fn QExpr::label(self : QExpr) -> Array[@symcore.Expr] {
  self.args
}

///|
pub fn QExpr::as_expr(self : QExpr) -> @symcore.Expr {
  @symcore.raw_function(self.class_name, self.args)
}

///|
pub fn QExpr::to_string(self : QExpr) -> String {
  quantum_join_label(self.args)
}

///|
pub fn QExpr::repr(self : QExpr) -> String {
  let rendered = self.args.map(quantum_repr_expr).join(",")
  "\{self.class_name}(\{rendered})"
}

///|
pub fn quantum_expr_name(expr : @symcore.Expr) -> String? {
  match expr {
    @symcore.Expr::Function(name, _) => Some(name)
    _ => None
  }
}

///|
pub fn quantum_expr_args(expr : @symcore.Expr) -> Array[@symcore.Expr]? {
  match expr {
    @symcore.Expr::Function(_, args) => Some(args)
    _ => None
  }
}

///|
pub fn quantum_expr_has_name(expr : @symcore.Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Function(expr_name, _) => expr_name == name
    _ => false
  }
}

///|
pub fn quantum_expr_has_any_name(expr : @symcore.Expr, names : Array[String]) -> Bool {
  match quantum_expr_name(expr) {
    Some(name) => names.contains(name)
    None => false
  }
}

///|
pub fn quantum_is_ket_expr(expr : @symcore.Expr) -> Bool {
  quantum_expr_has_any_name(expr, [
    "Ket",
    "TimeDepKet",
    "OrthogonalKet",
    "BosonFockKet",
    "BosonCoherentKet",
    "FermionFockKet",
    "Qubit",
    "IntQubit",
    "JxKet",
    "JyKet",
    "JzKet",
  ])
}

///|
pub fn quantum_is_bra_expr(expr : @symcore.Expr) -> Bool {
  quantum_expr_has_any_name(expr, [
    "Bra",
    "TimeDepBra",
    "OrthogonalBra",
    "BosonFockBra",
    "BosonCoherentBra",
    "FermionFockBra",
    "QubitBra",
    "IntQubitBra",
    "JxBra",
    "JyBra",
    "JzBra",
  ])
}

///|
pub fn quantum_is_state_expr(expr : @symcore.Expr) -> Bool {
  quantum_is_ket_expr(expr) || quantum_is_bra_expr(expr) ||
    quantum_expr_has_name(expr, "Wavefunction")
}

///|
pub fn quantum_is_operator_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Symbol(name) =>
      ["Jplus", "Jminus", "Jx", "Jy", "Jz", "J2"].contains(name)
    _ =>
      quantum_expr_has_any_name(expr, [
        "Operator",
        "HermitianOperator",
        "UnitaryOperator",
        "IdentityOperator",
        "DifferentialOperator",
        "OuterProduct",
        "BosonOp",
        "FermionOp",
        "Gate",
        "CGate",
        "UGate",
        "IdentityGate",
        "HadamardGate",
        "XGate",
        "YGate",
        "ZGate",
        "TGate",
        "PhaseGate",
        "SwapGate",
        "CNotGate",
        "Rotation",
        "WignerD",
        "Density",
      ])
  }
}

///|
pub fn quantum_state_or_operator(expr : @symcore.Expr) -> Bool {
  quantum_is_state_expr(expr) || quantum_is_operator_expr(expr)
}
