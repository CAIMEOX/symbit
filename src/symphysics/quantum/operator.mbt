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
  label : Array[Expr]
  hilbert_space : HilbertSpace
} derive(Eq)

///|
fn default_operator_label() -> Array[Expr] {
  [symbol("O")]
}

///|
fn normalize_operator_label(label : Array[Expr]) -> Array[Expr] {
  if label.is_empty() {
    default_operator_label()
  } else {
    label
  }
}

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
  label : Array[Expr],
  flavor? : OperatorFlavor = OperatorFlavor::Generic,
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> OperatorExpr {
  OperatorExpr::{
    flavor,
    label: normalize_operator_label(label),
    hilbert_space,
  }
}

///|
pub fn operator(
  label : Array[Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> OperatorExpr {
  quantum_operator(label, hilbert_space~)
}

///|
pub fn hermitian_operator(
  label : Array[Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> OperatorExpr {
  quantum_operator(label, flavor=OperatorFlavor::Hermitian, hilbert_space~)
}

///|
pub fn unitary_operator(
  label : Array[Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> OperatorExpr {
  quantum_operator(label, flavor=OperatorFlavor::Unitary, hilbert_space~)
}

///|
pub fn identity_operator(
  dimension? : Expr = @symcore.oo(),
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> OperatorExpr {
  quantum_operator([dimension], flavor=OperatorFlavor::Identity, hilbert_space~)
}

///|
pub fn OperatorExpr::as_expr(self : OperatorExpr) -> Expr {
  @symcore.raw_function(operator_class_name(self.flavor), self.label)
}

///|
pub impl Show for OperatorExpr with to_string(self) {
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
pub impl Show for OperatorExpr with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn OperatorExpr::repr(self : OperatorExpr) -> String {
  let rendered = self.label.map(quantum_repr_expr).join(",")
  "\{operator_class_name(self.flavor)}(\{rendered})"
}

///|
pub fn OperatorExpr::inverse(self : OperatorExpr) -> Expr {
  match self.flavor {
    OperatorFlavor::Identity => self.as_expr()
    _ => @symcore.raw_pow(self.as_expr(), int(-1))
  }
}

///|
fn outer_product_raw(ket_expr : Expr, bra_expr : Expr) -> Expr {
  @symcore.raw_function("OuterProduct", [ket_expr, bra_expr])
}

///|
pub fn outer_product(ket_expr : Expr, bra_expr : Expr) -> Expr {
  match ket_expr {
    Expr::Add(args) =>
      quantum_add_from_args_preserve(
        args.map(term => outer_product(term, bra_expr)),
      )
    _ =>
      match bra_expr {
        Expr::Add(args) =>
          quantum_add_from_args_preserve(
            args.map(term => outer_product(ket_expr, term)),
          )
        _ => {
          let (ket_scalar, ket_body) = quantum_split_scalar_factors(ket_expr)
          let (bra_scalar, bra_body) = quantum_split_scalar_factors(bra_expr)
          match (ket_body, bra_body) {
            (Some(ket_core), Some(bra_core)) if quantum_is_ket_expr(ket_core) &&
              quantum_is_bra_expr(bra_core) => {
              let factors : Array[Expr] = []
              if ket_scalar != int(1) {
                factors.push(ket_scalar)
              }
              if bra_scalar != int(1) {
                factors.push(bra_scalar)
              }
              factors.push(outer_product_raw(ket_core, bra_core))
              quantum_mul_from_args_preserve(factors)
            }
            _ => outer_product_raw(ket_expr, bra_expr)
          }
        }
      }
  }
}

///|
pub fn operator_from_expr(expr : Expr) -> OperatorExpr? {
  match quantum_expr_name(expr) {
    Some(name) =>
      match quantum_expr_args(expr) {
        Some(args) =>
          match name {
            "Operator" => Some(operator(args))
            "HermitianOperator" => Some(hermitian_operator(args))
            "UnitaryOperator" => Some(unitary_operator(args))
            "IdentityOperator" => {
              let dimension = if args.is_empty() {
                @symcore.oo()
              } else {
                args[0]
              }
              Some(identity_operator(dimension~))
            }
            _ => None
          }
        None => None
      }
    None => None
  }
}
