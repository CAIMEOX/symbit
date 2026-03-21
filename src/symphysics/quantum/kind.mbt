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
pub impl Show for QuantumKind with to_string(self) {
  match self {
    QuantumKind::QNumber => "NumberKind"
    QuantumKind::QKet => "KetKind"
    QuantumKind::QBra => "BraKind"
    QuantumKind::QOperator => "OperatorKind"
    QuantumKind::QUndefined => "UndefinedKind"
  }
}

///|
pub impl Show for QuantumKind with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
fn quantum_mul_kind(lhs : QuantumKind, rhs : QuantumKind) -> QuantumKind {
  match (lhs, rhs) {
    (QuantumKind::QNumber, other) => other
    (other, QuantumKind::QNumber) => other
    (QuantumKind::QBra, QuantumKind::QKet) => QuantumKind::QNumber
    (QuantumKind::QKet, QuantumKind::QBra) => QuantumKind::QOperator
    (QuantumKind::QOperator, QuantumKind::QOperator) => QuantumKind::QOperator
    _ => QuantumKind::QUndefined
  }
}

///|
pub fn quantum_kind(expr : Expr) -> QuantumKind {
  if quantum_is_scalar_like(expr) {
    return QuantumKind::QNumber
  }
  if quantum_is_ket_expr(expr) {
    return QuantumKind::QKet
  }
  if quantum_is_bra_expr(expr) {
    return QuantumKind::QBra
  }
  if quantum_is_operator_expr(expr) {
    return QuantumKind::QOperator
  }
  match expr {
    Expr::Add(args) => {
      guard !args.is_empty() else { return QuantumKind::QNumber }
      let first = quantum_kind(args[0])
      for idx in 1..<args.length() {
        if quantum_kind(args[idx]) != first {
          return QuantumKind::QUndefined
        }
      }
      first
    }
    Expr::Mul(args) => {
      guard !args.is_empty() else { return QuantumKind::QNumber }
      let mut acc = quantum_kind(args[0])
      for idx in 1..<args.length() {
        acc = quantum_mul_kind(acc, quantum_kind(args[idx]))
      }
      acc
    }
    Expr::Function("Dagger", args) if args.length() == 1 =>
      match quantum_kind(args[0]) {
        QuantumKind::QKet => QuantumKind::QBra
        QuantumKind::QBra => QuantumKind::QKet
        other => other
      }
    Expr::Function("InnerProduct", _) => QuantumKind::QNumber
    Expr::Function("OuterProduct", _) => QuantumKind::QOperator
    Expr::Function("Commutator", _) | Expr::Function("AntiCommutator", _) =>
      QuantumKind::QOperator
    Expr::Function("TensorProduct", args) => {
      let mut out = QuantumKind::QNumber
      for arg in args {
        let kind = quantum_kind(arg)
        match kind {
          QuantumKind::QNumber => ()
          QuantumKind::QUndefined => return QuantumKind::QUndefined
          _ =>
            match out {
              QuantumKind::QNumber => out = kind
              _ if out == kind => ()
              _ => return QuantumKind::QUndefined
            }
        }
      }
      out
    }
    _ => QuantumKind::QUndefined
  }
}
