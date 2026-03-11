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
} derive(Eq)

///|
pub struct StateExpr {
  flavor : StateFlavor
  label : Array[@symcore.Expr]
  time : @symcore.Expr?
  hilbert_space : HilbertSpace
} derive(Eq)

///|
fn state_class_name(flavor : StateFlavor) -> String {
  match flavor {
    StateFlavor::Ket => "Ket"
    StateFlavor::Bra => "Bra"
    StateFlavor::TimeDepKet => "TimeDepKet"
    StateFlavor::TimeDepBra => "TimeDepBra"
  }
}

///|
fn state_brackets(flavor : StateFlavor) -> (String, String, String) {
  match flavor {
    StateFlavor::Ket => ("|", ">", ", ")
    StateFlavor::Bra => ("<", "|", ", ")
    StateFlavor::TimeDepKet => ("|", ">", ";")
    StateFlavor::TimeDepBra => ("<", "|", ";")
  }
}

///|
pub fn ket(
  label : Array[@symcore.Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> StateExpr {
  StateExpr::{ flavor: StateFlavor::Ket, label, time: None, hilbert_space }
}

///|
pub fn bra(
  label : Array[@symcore.Expr],
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> StateExpr {
  StateExpr::{ flavor: StateFlavor::Bra, label, time: None, hilbert_space }
}

///|
pub fn time_dep_ket(
  label : Array[@symcore.Expr],
  time : @symcore.Expr,
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> StateExpr {
  StateExpr::{ flavor: StateFlavor::TimeDepKet, label, time: Some(time), hilbert_space }
}

///|
pub fn time_dep_bra(
  label : Array[@symcore.Expr],
  time : @symcore.Expr,
  hilbert_space? : HilbertSpace = hilbert_space(),
) -> StateExpr {
  StateExpr::{ flavor: StateFlavor::TimeDepBra, label, time: Some(time), hilbert_space }
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
  let time = self.time.unwrap_or(@symcore.symbol("t"))
  match self.flavor {
    StateFlavor::Ket => bra(self.label, hilbert_space=self.hilbert_space)
    StateFlavor::Bra => ket(self.label, hilbert_space=self.hilbert_space)
    StateFlavor::TimeDepKet =>
      time_dep_bra(self.label, time, hilbert_space=self.hilbert_space)
    StateFlavor::TimeDepBra =>
      time_dep_ket(self.label, time, hilbert_space=self.hilbert_space)
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
        "TimeDepKet" if args.length() >= 1 => {
          let label : Array[@symcore.Expr] = []
          for idx in 0..<(args.length() - 1) {
            label.push(args[idx])
          }
          Some(time_dep_ket(label, args[args.length() - 1]))
        }
        "TimeDepBra" if args.length() >= 1 => {
          let label : Array[@symcore.Expr] = []
          for idx in 0..<(args.length() - 1) {
            label.push(args[idx])
          }
          Some(time_dep_bra(label, args[args.length() - 1]))
        }
        _ => None
      }
    _ => None
  }
}
