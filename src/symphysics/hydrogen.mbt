///|
/// Hydrogen-atom radial, angular, and energy formulas.

///|
pub fn hydrogen_r_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  r : @symcore.Expr,
  z? : @symcore.Expr = @symcore.int(1),
) -> @symcore.Expr {
  let n_r = n - l - @symcore.int(1)
  let r0 = expr_div((@symcore.int(2) * z * r), n)
  let coeff = @symelem.sqrt(
    expr_div(
      ((expr_div((@symcore.int(2) * z), n)) ^ @symcore.int(3)) *
        @symcomb.factorial(n_r),
      (@symcore.int(2) * n) * @symcomb.factorial(n + l),
    ),
  )
  coeff *
    (r0 ^ l) *
    @symspec.assoc_laguerre(n_r, (@symcore.int(2) * l) + @symcore.int(1), r0) *
    @symelem.exp(@symcore.int(-1) * r0 * rational_expr(1, 2))
}

///|
pub fn hydrogen_y_lm(
  l : @symcore.Expr,
  m : @symcore.Expr,
  phi : @symcore.Expr,
  theta : @symcore.Expr,
) -> @symcore.Expr {
  @symspec.ynm(l, m, theta, phi)
}

///|
pub fn hydrogen_z_lm(
  l : @symcore.Expr,
  m : @symcore.Expr,
  phi : @symcore.Expr,
  theta : @symcore.Expr,
) -> @symcore.Expr {
  @symspec.znm(l, m, theta, phi)
}

///|
pub fn hydrogen_psi_nlm(
  n : @symcore.Expr,
  l : @symcore.Expr,
  m : @symcore.Expr,
  r : @symcore.Expr,
  phi : @symcore.Expr,
  theta : @symcore.Expr,
  z? : @symcore.Expr = @symcore.int(1),
) -> @symcore.Expr raise PhysicsError {
  match expr_integer_value(n) {
    Some(ni) if ni < 1 =>
      raise PhysicsError::ValueError("'n' must be positive integer")
    _ => ()
  }
  match (expr_integer_value(n), expr_integer_value(l)) {
    (Some(ni), Some(li)) if ni <= li =>
      raise PhysicsError::ValueError("'n' must be greater than 'l'")
    _ => ()
  }
  match (expr_integer_value(m), expr_integer_value(l)) {
    (Some(mi), Some(li)) if mi.abs() > li =>
      raise PhysicsError::ValueError("|'m'| must be less or equal 'l'")
    _ => ()
  }
  hydrogen_r_nl(n, l, r, z=z) * hydrogen_y_lm(l, m, phi, theta)
}

///|
pub fn hydrogen_e_nl(
  n : @symcore.Expr,
  z? : @symcore.Expr = @symcore.int(1),
) -> @symcore.Expr raise PhysicsError {
  match expr_integer_value(n) {
    Some(ni) if ni < 1 =>
      raise PhysicsError::ValueError("'n' must be positive integer")
    _ => ()
  }
  @symcore.int(-1) * expr_div(z ^ @symcore.int(2), @symcore.int(2) * (n ^ @symcore.int(2)))
}

///|
fn hydrogen_dirac_default_c() -> @symcore.Expr {
  @symcore.number(
    try! @symnum.BigRational::new(
      @bigint.BigInt::from_string("137035999037"),
      @bigint.BigInt::from_int(1000000000),
    ),
  )
}

///|
pub fn hydrogen_e_nl_dirac(
  n : @symcore.Expr,
  l : @symcore.Expr,
  spin_up? : Bool = true,
  z? : @symcore.Expr = @symcore.int(1),
  c? : @symcore.Expr = hydrogen_dirac_default_c(),
) -> @symcore.Expr raise PhysicsError {
  match expr_integer_value(l) {
    Some(li) if li < 0 =>
      raise PhysicsError::ValueError("'l' must be positive or zero")
    _ => ()
  }
  match (expr_integer_value(n), expr_integer_value(l)) {
    (Some(ni), Some(li)) if ni <= li =>
      raise PhysicsError::ValueError("'n' must be greater than 'l'")
    _ => ()
  }
  match expr_integer_value(l) {
    Some(0) if !spin_up =>
      raise PhysicsError::ValueError("Spin must be up for l==0.")
    _ => ()
  }
  let skappa = if spin_up { @symcore.int(-1) * l - @symcore.int(1) } else { @symcore.int(-1) * l }
  let c2 = c ^ @symcore.int(2)
  let beta = @symelem.sqrt((skappa ^ @symcore.int(2)) - expr_div(z ^ @symcore.int(2), c2))
  expr_div(
    c2,
    @symelem.sqrt(
      @symcore.int(1) +
        expr_div(z ^ @symcore.int(2), ((n + skappa + beta) ^ @symcore.int(2)) * c2),
    ),
  ) - c2
}
