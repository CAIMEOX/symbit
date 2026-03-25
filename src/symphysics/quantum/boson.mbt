///|
/// Bosonic operators and state families aligned with
/// `sympy.physics.quantum.boson`.

///|
pub struct BosonOpExpr {
  name : Expr
  is_annihilation : Bool
} derive(Eq)

///|
pub fn boson_op(name : Expr, annihilation? : Bool = true) -> BosonOpExpr {
  BosonOpExpr::{ name, is_annihilation: annihilation }
}

///|
pub fn BosonOpExpr::as_expr(self : BosonOpExpr) -> Expr {
  @symcore.raw_function("BosonOp", [
    self.name,
    if self.is_annihilation {
      int(1)
    } else {
      int(0)
    },
  ])
}

///|
pub impl Show for BosonOpExpr with to_string(self) {
  if self.is_annihilation {
    @symprint.to_string(self.name)
  } else {
    "Dagger(\{@symprint.to_string(self.name)})"
  }
}

///|
pub impl Show for BosonOpExpr with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn BosonOpExpr::dagger(self : BosonOpExpr) -> BosonOpExpr {
  boson_op(self.name, annihilation=!self.is_annihilation)
}

///|
fn boson_secondquant_operator(expr : Expr) -> (Expr, Bool)? {
  match expr {
    Expr::Function("BosonOp", args) if args.length() == 2 =>
      Some((args[0], args[1] != int(0)))
    Expr::Function("AnnihilateBoson", args) if args.length() == 1 =>
      Some((args[0], true))
    Expr::Function("CreateBoson", args) if args.length() == 1 =>
      Some((args[0], false))
    _ => None
  }
}

///|
fn boson_secondquant_tuple_state(
  expr : Expr,
  ket? : Bool = true,
) -> Array[Expr]? {
  let expected = if ket { "FockStateBosonKet" } else { "FockStateBosonBra" }
  match expr {
    Expr::Function(name, args) if name == expected && args.length() == 1 =>
      @symcore.tuple_items(args[0])
    _ => None
  }
}

///|
fn boson_secondquant_state_expr(
  items : Array[Expr],
  ket? : Bool = true,
) -> Expr {
  let class_name = if ket { "FockStateBosonKet" } else { "FockStateBosonBra" }
  @symcore.raw_function(class_name, [@symcore.raw_function("Tuple", items)])
}

///|
pub fn boson_fock_ket(n : Expr) -> Expr {
  @symcore.raw_function("BosonFockKet", [n])
}

///|
pub fn boson_fock_bra(n : Expr) -> Expr {
  @symcore.raw_function("BosonFockBra", [n])
}

///|
pub fn boson_coherent_ket(alpha : Expr) -> Expr {
  @symcore.raw_function("BosonCoherentKet", [alpha])
}

///|
pub fn boson_coherent_bra(alpha : Expr) -> Expr {
  @symcore.raw_function("BosonCoherentBra", [alpha])
}

///|
pub fn boson_apply_operator_to_ket(op_expr : Expr, ket_expr : Expr) -> Expr? {
  match
    (
      boson_secondquant_operator(op_expr),
      boson_secondquant_tuple_state(ket_expr),
    ) {
    (Some((state_index, is_ann)), Some(items)) =>
      match quantum_integer_value(state_index) {
        Some(level) if level >= 0 && level < items.length() => {
          let updated = items.copy()
          if is_ann {
            if updated[level] == int(0) {
              return Some(int(0))
            }
            return Some(
              @symcore.raw_function("sqrt", [updated[level]]) *
              boson_secondquant_state_expr(
                {
                  updated[level] = updated[level] - int(1)
                  updated
                },
              ),
            )
          } else {
            return Some(
              @symcore.raw_function("sqrt", [updated[level] + int(1)]) *
              boson_secondquant_state_expr(
                {
                  updated[level] = updated[level] + int(1)
                  updated
                },
              ),
            )
          }
        }
        _ => ()
      }
    _ => ()
  }
  match (op_expr, ket_expr) {
    (Expr::Function("BosonOp", oargs), Expr::Function("BosonFockKet", kargs)) if oargs.length() ==
      2 &&
      kargs.length() == 1 => {
      let is_ann = oargs[1] != int(0)
      let n = kargs[0]
      if is_ann {
        Some(@symcore.raw_function("sqrt", [n]) * boson_fock_ket(n - int(1)))
      } else {
        Some(
          @symcore.raw_function("sqrt", [n + int(1)]) *
          boson_fock_ket(n + int(1)),
        )
      }
    }
    (Expr::Function("BosonOp", oargs), Expr::Function("BosonCoherentKet", kargs)
    ) if oargs.length() == 2 && kargs.length() == 1 => {
      let is_ann = oargs[1] != int(0)
      if is_ann {
        Some(kargs[0] * ket_expr)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
pub fn boson_apply_operator_to_bra(bra_expr : Expr, op_expr : Expr) -> Expr? {
  match (bra_expr, op_expr) {
    (Expr::Function("BosonCoherentBra", bargs), Expr::Function("BosonOp", oargs)
    ) if bargs.length() == 1 && oargs.length() == 2 => {
      let is_ann = oargs[1] != int(0)
      if !is_ann {
        Some(bargs[0] * bra_expr)
      } else {
        None
      }
    }
    _ => None
  }
}
