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
  { name, is_annihilation: annihilation }
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
pub impl Show for BosonOpExpr with fn to_string(self) {
  if self.is_annihilation {
    @symprint.pretty_string(self.name)
  } else {
    "Dagger(\{@symprint.pretty_string(self.name)})"
  }
}

///|
pub impl Show for BosonOpExpr with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
pub fn BosonOpExpr::dagger(self : BosonOpExpr) -> BosonOpExpr {
  boson_op(self.name, annihilation=!self.is_annihilation)
}

///|
fn boson_secondquant_operator(expr : Expr) -> (Expr, Bool)? {
  match @symcore.application_args(expr) {
    Some([name, flag]) if @symcore.application_has_name(
        expr,
        "BosonOp",
        arity=2,
      ) => Some((name, flag != int(0)))
    Some([name]) if @symcore.application_has_name(
        expr,
        "AnnihilateBoson",
        arity=1,
      ) => Some((name, true))
    Some([name]) if @symcore.application_has_name(expr, "CreateBoson", arity=1) =>
      Some((name, false))
    _ => None
  }
}

///|
fn boson_secondquant_tuple_state(
  expr : Expr,
  ket? : Bool = true,
) -> Array[Expr]? {
  let expected = if ket { "FockStateBosonKet" } else { "FockStateBosonBra" }
  match @symcore.application_args(expr) {
    Some([arg]) if @symcore.application_has_name(expr, expected, arity=1) =>
      @symcore.tuple_items(arg)
    _ => None
  }
}

///|
fn boson_secondquant_state_expr(
  items : Array[Expr],
  ket? : Bool = true,
) -> Expr {
  let class_name = if ket { "FockStateBosonKet" } else { "FockStateBosonBra" }
  @symcore.raw_function(class_name, [Tuple(items)])
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
  match
    (@symcore.application_args(op_expr), @symcore.application_args(ket_expr)) {
    (Some(oargs), Some(kargs)) if @symcore.application_has_name(
        op_expr,
        "BosonOp",
        arity=2,
      ) &&
      @symcore.application_has_name(ket_expr, "BosonFockKet", arity=1) => {
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
    (Some(oargs), Some(kargs)) if @symcore.application_has_name(
        op_expr,
        "BosonOp",
        arity=2,
      ) &&
      @symcore.application_has_name(ket_expr, "BosonCoherentKet", arity=1) => {
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
  match
    (@symcore.application_args(bra_expr), @symcore.application_args(op_expr)) {
    (Some(bargs), Some(oargs)) if @symcore.application_has_name(
        bra_expr,
        "BosonCoherentBra",
        arity=1,
      ) &&
      @symcore.application_has_name(op_expr, "BosonOp", arity=2) => {
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
