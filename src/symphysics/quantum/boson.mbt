///|
/// Bosonic operators and state families aligned with
/// `sympy.physics.quantum.boson`.

///|
pub struct BosonOpExpr {
  name : @symcore.Expr
  is_annihilation : Bool
} derive(Eq)

///|
pub fn boson_op(
  name : @symcore.Expr,
  annihilation? : Bool = true,
) -> BosonOpExpr {
  BosonOpExpr::{ name, is_annihilation: annihilation }
}

///|
pub fn BosonOpExpr::as_expr(self : BosonOpExpr) -> @symcore.Expr {
  @symcore.raw_function("BosonOp", [
    self.name,
    if self.is_annihilation {
      @symcore.int(1)
    } else {
      @symcore.int(0)
    },
  ])
}

///|
pub fn BosonOpExpr::to_string(self : BosonOpExpr) -> String {
  if self.is_annihilation {
    @symprint.to_string(self.name)
  } else {
    "Dagger(\{@symprint.to_string(self.name)})"
  }
}

///|
pub fn BosonOpExpr::dagger(self : BosonOpExpr) -> BosonOpExpr {
  boson_op(self.name, annihilation=!self.is_annihilation)
}

///|
pub fn boson_fock_ket(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("BosonFockKet", [n])
}

///|
pub fn boson_fock_bra(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("BosonFockBra", [n])
}

///|
pub fn boson_coherent_ket(alpha : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("BosonCoherentKet", [alpha])
}

///|
pub fn boson_coherent_bra(alpha : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("BosonCoherentBra", [alpha])
}

///|
pub fn boson_apply_operator_to_ket(
  op_expr : @symcore.Expr,
  ket_expr : @symcore.Expr,
) -> @symcore.Expr? {
  match (op_expr, ket_expr) {
    (
      @symcore.Expr::Function("BosonOp", oargs),
      @symcore.Expr::Function("BosonFockKet", kargs),
    ) if oargs.length() == 2 && kargs.length() == 1 => {
      let is_ann = oargs[1] != @symcore.int(0)
      let n = kargs[0]
      if is_ann {
        Some(
          @symcore.raw_function("sqrt", [n]) *
          boson_fock_ket(n - @symcore.int(1)),
        )
      } else {
        Some(
          @symcore.raw_function("sqrt", [n + @symcore.int(1)]) *
          boson_fock_ket(n + @symcore.int(1)),
        )
      }
    }
    (
      @symcore.Expr::Function("BosonOp", oargs),
      @symcore.Expr::Function("BosonCoherentKet", kargs),
    ) if oargs.length() == 2 && kargs.length() == 1 => {
      let is_ann = oargs[1] != @symcore.int(0)
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
pub fn boson_apply_operator_to_bra(
  bra_expr : @symcore.Expr,
  op_expr : @symcore.Expr,
) -> @symcore.Expr? {
  match (bra_expr, op_expr) {
    (
      @symcore.Expr::Function("BosonCoherentBra", bargs),
      @symcore.Expr::Function("BosonOp", oargs),
    ) if bargs.length() == 1 && oargs.length() == 2 => {
      let is_ann = oargs[1] != @symcore.int(0)
      if !is_ann {
        Some(bargs[0] * bra_expr)
      } else {
        None
      }
    }
    _ => None
  }
}
