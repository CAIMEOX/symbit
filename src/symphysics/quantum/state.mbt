///|
/// Dirac state constructors aligned with the commonly used surface of
/// `sympy.physics.quantum.state`.
///
/// The symbolic carrier is `Ket(...)`, `Bra(...)`, `TimeDepKet(...)`, and
/// `TimeDepBra(...)`, while this wrapper provides MoonBit-friendly methods for
/// labels, duals, Hilbert-space metadata, and SymPy-style `srepr` output.

///|
pub enum StateFlavor {
  Ket
  Bra
  TimeDepKet
  TimeDepBra
  OrthogonalKet
  OrthogonalBra
} derive(Eq)

///|
pub struct StateExpr {
  flavor : StateFlavor
  label : Array[@symcore.Expr]
  time : @symcore.Expr?
  hilbert_space : HilbertSpace
} derive(Eq)

///|
fn default_state_label() -> Array[@symcore.Expr] {
  [@symcore.symbol("psi")]
}

///|
fn default_time_expr() -> @symcore.Expr {
  @symcore.symbol("t")
}

///|
fn normalize_state_label(label : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  if label.is_empty() {
    default_state_label()
  } else {
    label
  }
}

///|
fn state_class_name(flavor : StateFlavor) -> String {
  match flavor {
    StateFlavor::Ket => "Ket"
    StateFlavor::Bra => "Bra"
    StateFlavor::TimeDepKet => "TimeDepKet"
    StateFlavor::TimeDepBra => "TimeDepBra"
    StateFlavor::OrthogonalKet => "OrthogonalKet"
    StateFlavor::OrthogonalBra => "OrthogonalBra"
  }
}

///|
fn state_brackets(flavor : StateFlavor) -> (String, String, String) {
  match flavor {
    StateFlavor::Ket => ("|", ">", ", ")
    StateFlavor::Bra => ("<", "|", ", ")
    StateFlavor::TimeDepKet => ("|", ">", ";")
    StateFlavor::TimeDepBra => ("<", "|", ";")
    StateFlavor::OrthogonalKet => ("|", ">", ", ")
    StateFlavor::OrthogonalBra => ("<", "|", ", ")
  }
}

///|
pub fn ket(
  label : Array[@symcore.Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> StateExpr {
  StateExpr::{
    flavor: StateFlavor::Ket,
    label: normalize_state_label(label),
    time: None,
    hilbert_space,
  }
}

///|
pub fn bra(
  label : Array[@symcore.Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> StateExpr {
  StateExpr::{
    flavor: StateFlavor::Bra,
    label: normalize_state_label(label),
    time: None,
    hilbert_space,
  }
}

///|
pub fn time_dep_ket(
  label : Array[@symcore.Expr],
  time? : @symcore.Expr = default_time_expr(),
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> StateExpr {
  StateExpr::{
    flavor: StateFlavor::TimeDepKet,
    label: normalize_state_label(label),
    time: Some(time),
    hilbert_space,
  }
}

///|
pub fn time_dep_bra(
  label : Array[@symcore.Expr],
  time? : @symcore.Expr = default_time_expr(),
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> StateExpr {
  StateExpr::{
    flavor: StateFlavor::TimeDepBra,
    label: normalize_state_label(label),
    time: Some(time),
    hilbert_space,
  }
}

///|
pub fn orthogonal_ket(
  label : Array[@symcore.Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> StateExpr {
  StateExpr::{
    flavor: StateFlavor::OrthogonalKet,
    label: normalize_state_label(label),
    time: None,
    hilbert_space,
  }
}

///|
pub fn orthogonal_bra(
  label : Array[@symcore.Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> StateExpr {
  StateExpr::{
    flavor: StateFlavor::OrthogonalBra,
    label: normalize_state_label(label),
    time: None,
    hilbert_space,
  }
}

///|
pub fn StateExpr::as_expr(self : StateExpr) -> @symcore.Expr {
  let args = self.label.copy()
  match self.time {
    Some(time) => {
      args.push(time)
      @symcore.raw_function(state_class_name(self.flavor), args)
    }
    None => @symcore.raw_function(state_class_name(self.flavor), args)
  }
}

///|
pub fn StateExpr::dual(self : StateExpr) -> StateExpr {
  let time = self.time.unwrap_or(default_time_expr())
  match self.flavor {
    StateFlavor::Ket => bra(self.label, hilbert_space=self.hilbert_space)
    StateFlavor::Bra => ket(self.label, hilbert_space=self.hilbert_space)
    StateFlavor::TimeDepKet =>
      time_dep_bra(self.label, time=time, hilbert_space=self.hilbert_space)
    StateFlavor::TimeDepBra =>
      time_dep_ket(self.label, time=time, hilbert_space=self.hilbert_space)
    StateFlavor::OrthogonalKet =>
      orthogonal_bra(self.label, hilbert_space=self.hilbert_space)
    StateFlavor::OrthogonalBra =>
      orthogonal_ket(self.label, hilbert_space=self.hilbert_space)
  }
}

///|
pub fn StateExpr::to_string(self : StateExpr) -> String {
  let (left, right, sep) = state_brackets(self.flavor)
  let contents = quantum_join_label(self.label, separator=", ")
  match self.time {
    Some(time) => "\{left}\{contents}\{sep}\{@symprint.to_string(time)}\{right}"
    None => "\{left}\{contents}\{right}"
  }
}

///|
pub fn StateExpr::repr(self : StateExpr) -> String {
  let args = self.label.copy()
  let class_name = state_class_name(self.flavor)
  match self.time {
    Some(time) => {
      args.push(time)
      let rendered = args.map(quantum_repr_expr).join(",")
      "\{class_name}(\{rendered})"
    }
    None => {
      let rendered = args.map(quantum_repr_expr).join(",")
      "\{class_name}(\{rendered})"
    }
  }
}

///|
pub fn state_from_expr(expr : @symcore.Expr) -> StateExpr? {
  match expr {
    @symcore.Expr::Function(name, args) =>
      match name {
        "Ket" => Some(ket(args))
        "Bra" => Some(bra(args))
        "TimeDepKet" if args.is_empty() =>
          Some(time_dep_ket([], time=default_time_expr()))
        "TimeDepKet" if args.length() >= 1 => {
          let label : Array[@symcore.Expr] = []
          for idx in 0..<(args.length() - 1) {
            label.push(args[idx])
          }
          Some(time_dep_ket(label, time=args[args.length() - 1]))
        }
        "TimeDepBra" if args.is_empty() =>
          Some(time_dep_bra([], time=default_time_expr()))
        "TimeDepBra" if args.length() >= 1 => {
          let label : Array[@symcore.Expr] = []
          for idx in 0..<(args.length() - 1) {
            label.push(args[idx])
          }
          Some(time_dep_bra(label, time=args[args.length() - 1]))
        }
        "OrthogonalKet" => Some(orthogonal_ket(args))
        "OrthogonalBra" => Some(orthogonal_bra(args))
        _ => None
      }
    _ => None
  }
}
