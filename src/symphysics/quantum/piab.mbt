///|
/// One-dimensional particle-in-a-box eigenstates and Hamiltonian.
///
/// This models the core `sympy.physics.quantum.piab` contracts used by the
/// rest of the package: energy eigenkets `PIABKet/PIABBra`, the Hamiltonian,
/// their Kronecker-delta overlaps, and the standard position-space wavefunction
/// `sqrt(2/L) * sin(n*pi*x/L)`.

///|
pub let piab_m : Expr = Expr::Symbol("m")

///|
pub let piab_l : Expr = Expr::Symbol("L")

///|
pub fn piab_hamiltonian(label? : Expr = Expr::Symbol("H")) -> Expr {
  @symcore.raw_function("PIABHamiltonian", [label])
}

///|
pub fn piab_ket(n : Expr) -> Expr {
  @symcore.raw_function("PIABKet", [n])
}

///|
pub fn piab_bra(n : Expr) -> Expr {
  @symcore.raw_function("PIABBra", [n])
}

///|
pub fn piab_apply_operator_to_ket(op_expr : Expr, ket_expr : Expr) -> Expr? {
  match @symcore.application_args(ket_expr) {
    Some(args) if @symcore.application_has_name(op_expr, "PIABHamiltonian") &&
      @symcore.application_has_name(ket_expr, "PIABKet", arity=1) => {
      let n = args[0]
      let coeff = (n ^ int(2)) *
        (@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) ^ int(2)) *
        (hbar ^ int(2)) *
        @symcore.raw_pow(int(2) * piab_m * (piab_l ^ int(2)), int(-1))
      Some(coeff * ket_expr)
    }
    _ => None
  }
}

///|
pub fn piab_represent(expr : Expr) -> Expr? {
  match @symcore.application_args(expr) {
    Some(args) if @symcore.application_has_name(expr, "PIABKet", arity=1) ||
      @symcore.application_has_name(expr, "PIABBra", arity=1) => {
      let x = Expr::Symbol("x")
      let prefactor = @symcore.raw_function("sqrt", [
        int(2) * @symcore.raw_pow(piab_l, int(-1)),
      ])
      Some(
        prefactor *
        @symcore.raw_function("sin", [
          args[0] *
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
          x *
          @symcore.raw_pow(piab_l, int(-1)),
        ]),
      )
    }
    _ => None
  }
}
