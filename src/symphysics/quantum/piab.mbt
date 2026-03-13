///|
/// One-dimensional particle-in-a-box eigenstates and Hamiltonian.
///
/// This models the core `sympy.physics.quantum.piab` contracts used by the
/// rest of the package: energy eigenkets `PIABKet/PIABBra`, the Hamiltonian,
/// their Kronecker-delta overlaps, and the standard position-space wavefunction
/// `sqrt(2/L) * sin(n*pi*x/L)`.

///|
pub let piab_m : @symcore.Expr = @symcore.symbol("m")

///|
pub let piab_l : @symcore.Expr = @symcore.symbol("L")

///|
pub fn piab_hamiltonian(
  label? : @symcore.Expr = @symcore.symbol("H"),
) -> @symcore.Expr {
  @symcore.raw_function("PIABHamiltonian", [label])
}

///|
pub fn piab_ket(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("PIABKet", [n])
}

///|
pub fn piab_bra(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("PIABBra", [n])
}

///|
pub fn piab_apply_operator_to_ket(
  op_expr : @symcore.Expr,
  ket_expr : @symcore.Expr,
) -> @symcore.Expr? {
  match (op_expr, ket_expr) {
    (
      @symcore.Expr::Function("PIABHamiltonian", _),
      @symcore.Expr::Function("PIABKet", args),
    ) if args.length() == 1 => {
      let n = args[0]
      let coeff = (n ^ @symcore.int(2)) *
        (@symcore.symbol("pi") ^ @symcore.int(2)) *
        (hbar ^ @symcore.int(2)) *
        @symcore.raw_pow(
          @symcore.int(2) * piab_m * (piab_l ^ @symcore.int(2)),
          @symcore.int(-1),
        )
      Some(coeff * ket_expr)
    }
    _ => None
  }
}

///|
pub fn piab_represent(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function("PIABKet", args)
    | @symcore.Expr::Function("PIABBra", args) if args.length() == 1 => {
      let x = @symcore.symbol("x")
      let prefactor = @symcore.raw_function("sqrt", [
        @symcore.int(2) * @symcore.raw_pow(piab_l, @symcore.int(-1)),
      ])
      Some(
        prefactor *
        @symcore.raw_function("sin", [
          args[0] *
          @symcore.symbol("pi") *
          x *
          @symcore.raw_pow(piab_l, @symcore.int(-1)),
        ]),
      )
    }
    _ => None
  }
}
