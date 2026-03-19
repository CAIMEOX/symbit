///|
/// Fermionic operators and Fock-state families aligned with
/// `sympy.physics.quantum.fermion`.

///|
pub struct FermionOpExpr {
  name : Expr
  is_annihilation : Bool
} derive(Eq)

///|
pub fn fermion_op(
  name : Expr,
  annihilation? : Bool = true,
) -> FermionOpExpr {
  FermionOpExpr::{ name, is_annihilation: annihilation }
}

///|
pub fn FermionOpExpr::as_expr(self : FermionOpExpr) -> Expr {
  @symcore.raw_function("FermionOp", [
    self.name,
    if self.is_annihilation {
      int(1)
    } else {
      int(0)
    },
  ])
}

///|
pub fn FermionOpExpr::to_string(self : FermionOpExpr) -> String {
  if self.is_annihilation {
    @symprint.to_string(self.name)
  } else {
    "Dagger(\{@symprint.to_string(self.name)})"
  }
}

///|
pub fn FermionOpExpr::dagger(self : FermionOpExpr) -> FermionOpExpr {
  fermion_op(self.name, annihilation=!self.is_annihilation)
}

///|
pub fn fermion_fock_ket(
  n : Expr,
) -> Expr raise @symphysics.PhysicsError {
  guard n == int(0) || n == int(1) else {
    raise @symphysics.PhysicsError::ValueError(
      "FermionFockKet expects occupation 0 or 1",
    )
  }
  @symcore.raw_function("FermionFockKet", [n])
}

///|
pub fn fermion_fock_bra(
  n : Expr,
) -> Expr raise @symphysics.PhysicsError {
  guard n == int(0) || n == int(1) else {
    raise @symphysics.PhysicsError::ValueError(
      "FermionFockBra expects occupation 0 or 1",
    )
  }
  @symcore.raw_function("FermionFockBra", [n])
}

///|
pub fn fermion_apply_operator_to_ket(
  op_expr : Expr,
  ket_expr : Expr,
) -> Expr? {
  match (op_expr, ket_expr) {
    (
      Expr::Function("FermionOp", oargs),
      Expr::Function("FermionFockKet", kargs),
    ) if oargs.length() == 2 && kargs.length() == 1 => {
      let is_ann = oargs[1] != int(0)
      let n = kargs[0]
      if is_ann {
        Some(
          if n == int(1) {
            try! fermion_fock_ket(int(0))
          } else {
            int(0)
          },
        )
      } else {
        Some(
          if n == int(0) {
            try! fermion_fock_ket(int(1))
          } else {
            int(0)
          },
        )
      }
    }
    _ => None
  }
}
