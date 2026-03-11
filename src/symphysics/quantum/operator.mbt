///|
/// Operator constructors aligned with the most-used symbolic layer of
/// `sympy.physics.quantum.operator`.
///
/// Generic, Hermitian, unitary, and identity operators are represented by
/// constructor expressions such as `Operator(A)` or `IdentityOperator(3)` and
/// keep noncommutative ordering when embedded in `@symcore.raw_mul(...)`.

///|
pub enum OperatorFlavor {
  Generic
  Hermitian
  Unitary
  Identity
} derive(Eq)

///|
pub struct OperatorExpr {
  flavor : OperatorFlavor
  label : Array[@symcore.Expr]
  hilbert_space : HilbertSpace
} derive(Eq)

///|
fn operator_class_name(flavor : OperatorFlavor) -> String {
  match flavor {
    OperatorFlavor::Generic => "Operator"
    OperatorFlavor::Hermitian => "HermitianOperator"
    OperatorFlavor::Unitary => "UnitaryOperator"
    OperatorFlavor::Identity => "IdentityOperator"
  }
}

///|
pub fn quantum_operator(
  label : Array[@symcore.Expr],
  flavor? : OperatorFlavor = OperatorFlavor::Generic,
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> OperatorExpr {
  OperatorExpr::{ flavor, label, hilbert_space }
}

///|
pub fn operator(
  label : Array[@symcore.Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> OperatorExpr {
  quantum_operator(label, hilbert_space=hilbert_space)
}

///|
pub fn hermitian_operator(
  label : Array[@symcore.Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> OperatorExpr {
  quantum_operator(label, flavor=OperatorFlavor::Hermitian, hilbert_space=hilbert_space)
}

///|
pub fn unitary_operator(
  label : Array[@symcore.Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> OperatorExpr {
  quantum_operator(label, flavor=OperatorFlavor::Unitary, hilbert_space=hilbert_space)
}

///|
pub fn identity_operator(
  dimension? : @symcore.Expr = @symcore.symbol("oo"),
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> OperatorExpr {
  quantum_operator([dimension], flavor=OperatorFlavor::Identity, hilbert_space=hilbert_space)
}

///|
pub fn OperatorExpr::as_expr(self : OperatorExpr) -> @symcore.Expr {
  @symcore.raw_function(operator_class_name(self.flavor), self.label)
}

///|
pub fn OperatorExpr::to_string(self : OperatorExpr) -> String {
  match self.flavor {
    OperatorFlavor::Identity => "I"
    _ => {
      let rendered = self.label.map(@symprint.to_string).join(", ")
      if self.label.length() == 1 {
        @symprint.to_string(self.label[0])
      } else {
        "\{operator_class_name(self.flavor)}(\{rendered})"
      }
    }
  }
}

///|
pub fn OperatorExpr::repr(self : OperatorExpr) -> String {
  let rendered = self.label.map(quantum_repr_expr).join(",")
  "\{operator_class_name(self.flavor)}(\{rendered})"
}

///|
pub fn OperatorExpr::inverse(self : OperatorExpr) -> @symcore.Expr {
  match self.flavor {
    OperatorFlavor::Identity => self.as_expr()
    _ => @symcore.raw_pow(self.as_expr(), @symcore.int(-1))
  }
}

///|
pub fn outer_product(ket_expr : @symcore.Expr, bra_expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("OuterProduct", [ket_expr, bra_expr])
}

///|
pub fn operator_from_expr(expr : @symcore.Expr) -> OperatorExpr? {
  match expr {
    @symcore.Expr::Function(name, args) =>
      match name {
        "Operator" => Some(operator(args))
        "HermitianOperator" => Some(hermitian_operator(args))
        "UnitaryOperator" => Some(unitary_operator(args))
        "IdentityOperator" => {
          let dimension = if args.is_empty() { @symcore.symbol("oo") } else { args[0] }
          Some(identity_operator(dimension=dimension))
        }
        _ => None
      }
    _ => None
  }
}
