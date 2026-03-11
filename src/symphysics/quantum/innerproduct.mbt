///|
/// Unevaluated and evaluated inner-product helpers for `Bra * Ket` pairs.
///
/// Generic `Bra`/`Ket` combinations stay symbolic, while concrete state
/// families such as qubits, bosonic Fock/coherent states, and fermionic Fock
/// states evaluate to the same closed forms that SymPy uses.

///|
pub fn inner_product(
  bra_expr : @symcore.Expr,
  ket_expr : @symcore.Expr,
  evaluate? : Bool = true,
) -> @symcore.Expr {
  guard quantum_is_bra_expr(bra_expr) else {
    return @symcore.raw_function("InnerProduct", [bra_expr, ket_expr])
  }
  guard quantum_is_ket_expr(ket_expr) else {
    return @symcore.raw_function("InnerProduct", [bra_expr, ket_expr])
  }
  if !evaluate {
    return @symcore.raw_function("InnerProduct", [bra_expr, ket_expr])
  }
  match (bra_expr, ket_expr) {
    (@symcore.Expr::Function("QubitBra", bargs), @symcore.Expr::Function("Qubit", kargs)) =>
      if bargs == kargs { @symcore.int(1) } else { @symcore.int(0) }
    (@symcore.Expr::Function("BosonFockBra", bargs), @symcore.Expr::Function("BosonFockKet", kargs)) if bargs.length() == 1 && kargs.length() == 1 =>
      if bargs[0] == kargs[0] {
        @symcore.int(1)
      } else {
        @symcore.raw_function("KroneckerDelta", [bargs[0], kargs[0]])
      }
    (@symcore.Expr::Function("FermionFockBra", bargs), @symcore.Expr::Function("FermionFockKet", kargs)) if bargs.length() == 1 && kargs.length() == 1 =>
      if bargs[0] == kargs[0] {
        @symcore.int(1)
      } else {
        @symcore.raw_function("KroneckerDelta", [bargs[0], kargs[0]])
      }
    (@symcore.Expr::Function("BosonCoherentBra", bargs), @symcore.Expr::Function("BosonCoherentKet", kargs)) if bargs.length() == 1 && kargs.length() == 1 => {
      let bra_alpha = bargs[0]
      let ket_alpha = kargs[0]
      if bra_alpha == ket_alpha {
        @symcore.int(1)
      } else {
        let half = try! @symcore.rational_from_ints(1, 2)
        let exponent = @symcore.int(-1) * half * (
          expr_conjugate(bra_alpha) * bra_alpha + expr_conjugate(ket_alpha) * ket_alpha -
          @symcore.int(2) * expr_conjugate(bra_alpha) * ket_alpha
        )
        @symcore.raw_function("exp", [exponent])
      }
    }
    _ => @symcore.raw_function("InnerProduct", [bra_expr, ket_expr])
  }
}

///|
pub fn inner_product_doit(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("InnerProduct", args) if args.length() == 2 =>
      inner_product(args[0], args[1])
    _ => expr
  }
}
