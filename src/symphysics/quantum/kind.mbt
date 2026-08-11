///|
/// Lightweight kind inference for quantum expressions.
///
/// SymPy attaches `kind` metadata to compound expressions so that products like
/// `x*|k>` still behave as kets, `|k><b|` behaves as an operator, and
/// `<b|k>` behaves as a scalar. This module mirrors that semantic layer on top
/// of the explicit expression constructors used in `symphysics/quantum`.

///|
pub(all) enum QuantumKind {
  QNumber
  QKet
  QBra
  QOperator
  QUndefined
} derive(Eq)

///|
pub impl Show for QuantumKind with fn to_string(self) {
  match self {
    QNumber => "NumberKind"
    QKet => "KetKind"
    QBra => "BraKind"
    QOperator => "OperatorKind"
    QUndefined => "UndefinedKind"
  }
}

///|
pub impl Show for QuantumKind with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
fn quantum_mul_kind(lhs : QuantumKind, rhs : QuantumKind) -> QuantumKind {
  match (lhs, rhs) {
    (QNumber, other) => other
    (other, QNumber) => other
    (QBra, QKet) => QNumber
    (QKet, QBra) => QOperator
    (QOperator, QOperator) => QOperator
    _ => QUndefined
  }
}

///|
pub fn quantum_kind(expr : Expr) -> QuantumKind {
  if quantum_is_scalar_like(expr) {
    return QNumber
  }
  if quantum_is_ket_expr(expr) {
    return QKet
  }
  if quantum_is_bra_expr(expr) {
    return QBra
  }
  if quantum_is_operator_expr(expr) {
    return QOperator
  }
  match expr {
    Add(args) => {
      guard !args.is_empty() else { return QNumber }
      let first = quantum_kind(args[0])
      for idx in 1..<args.length() {
        if quantum_kind(args[idx]) != first {
          return QUndefined
        }
      }
      first
    }
    Mul(args) => {
      guard !args.is_empty() else { return QNumber }
      let mut acc = quantum_kind(args[0])
      for idx in 1..<args.length() {
        acc = quantum_mul_kind(acc, quantum_kind(args[idx]))
      }
      acc
    }
    _ if quantum_expr_has_name(expr, "Dagger") =>
      match quantum_expr_args(expr) {
        Some([arg]) =>
          match quantum_kind(arg) {
            QKet => QBra
            QBra => QKet
            other => other
          }
        _ => QUndefined
      }
    _ if quantum_expr_has_name(expr, "InnerProduct") => QNumber
    _ if quantum_expr_has_any_name(expr, [
        "OuterProduct", "Commutator", "AntiCommutator",
      ]) => QOperator
    _ if quantum_expr_has_name(expr, "TensorProduct") =>
      match quantum_expr_args(expr) {
        Some(args) => {
          let mut out = QuantumKind::QNumber
          for arg in args {
            let kind = quantum_kind(arg)
            match kind {
              QNumber => ()
              QUndefined => return QUndefined
              _ =>
                match out {
                  QNumber => out = kind
                  _ if out == kind => ()
                  _ => return QUndefined
                }
            }
          }
          out
        }
        None => QUndefined
      }
    _ => QUndefined
  }
}
