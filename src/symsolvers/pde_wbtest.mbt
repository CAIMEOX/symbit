///|
fn wb_same_expr(lhs : Expr, rhs : Expr) -> Bool {
  expr_is_zeroish(
    canonical_expr(
      @symsimplify.simplify(
        canonical_expr(
          @symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])]),
        ),
        max_passes=3,
      ),
    ),
  ) ==
  Some(true)
}

///|
fn wb_r() -> Expr {
  Expr::Symbol("r")
}

///|
fn wb_theta() -> Expr {
  Expr::Symbol("theta")
}

///|
fn wb_rfun(expr : Expr) -> Expr {
  @symcore.applied_undefined_function("R", [expr])
}

///|
fn wb_tfun(expr : Expr) -> Expr {
  @symcore.applied_undefined_function("T", [expr])
}

///|
test "pde wb: separation term exposes cylindrical angular factor" {
  let term = canonical_expr(
    @symcore.mul([
      @symcore.int(-1),
      @symcalculus.diff(
        @symcalculus.diff(wb_tfun(wb_theta()), wb_theta()),
        wb_theta(),
      ),
      @symcore.pow(
        @symcore.mul([wb_r() ^ @symcore.int(2), wb_tfun(wb_theta())]),
        @symcore.int(-1),
      ),
    ]),
  )
  let (ext, sep) = solver_pde_as_independent_mul(term, wb_theta())
  assert_true(
    wb_same_expr(
      ext,
      canonical_expr(
        @symcore.mul([@symcore.int(-1), wb_r() ^ @symcore.int(-2)]),
      ),
    ),
  )
  assert_true(
    wb_same_expr(
      sep,
      canonical_expr(
        @symcore.mul([
          @symcalculus.diff(
            @symcalculus.diff(wb_tfun(wb_theta()), wb_theta()),
            wb_theta(),
          ),
          @symcore.pow(wb_tfun(wb_theta()), @symcore.int(-1)),
        ]),
      ),
    ),
  )
}

///|
test "pde wb: simple separate handles cylindrical reduced equation" {
  let c = Expr::Symbol("C")
  let reduced = canonical_expr(
    @symcore.add([
      c * (wb_r() ^ @symcore.int(2)),
      @symcore.mul([
        wb_r() ^ @symcore.int(2),
        @symcalculus.diff(@symcalculus.diff(wb_rfun(wb_r()), wb_r()), wb_r()),
        @symcore.pow(wb_rfun(wb_r()), @symcore.int(-1)),
      ]),
      @symcore.mul([
        wb_r(),
        @symcalculus.diff(wb_rfun(wb_r()), wb_r()),
        @symcore.pow(wb_rfun(wb_r()), @symcore.int(-1)),
      ]),
      @symcore.mul([
        @symcalculus.diff(
          @symcalculus.diff(wb_tfun(wb_theta()), wb_theta()),
          wb_theta(),
        ),
        @symcore.pow(wb_tfun(wb_theta()), @symcore.int(-1)),
      ]),
    ]),
  )
  let separated = solver_simple_pde_separate(reduced, [wb_theta()], [wb_r()]).unwrap_or([],
  )
  assert_true(separated.length() == 2)
  assert_true(
    wb_same_expr(
      separated[0],
      canonical_expr(
        @symcore.mul([
          @symcalculus.diff(
            @symcalculus.diff(wb_tfun(wb_theta()), wb_theta()),
            wb_theta(),
          ),
          @symcore.pow(wb_tfun(wb_theta()), @symcore.int(-1)),
        ]),
      ),
    ),
  )
  assert_true(
    wb_same_expr(
      separated[1],
      canonical_expr(
        @symcore.add([
          @symcore.mul([@symcore.int(-1), c, wb_r() ^ @symcore.int(2)]),
          @symcore.mul([
            @symcore.int(-1),
            wb_r() ^ @symcore.int(2),
            @symcalculus.diff(
              @symcalculus.diff(wb_rfun(wb_r()), wb_r()),
              wb_r(),
            ),
            @symcore.pow(wb_rfun(wb_r()), @symcore.int(-1)),
          ]),
          @symcore.mul([
            @symcore.int(-1),
            wb_r(),
            @symcalculus.diff(wb_rfun(wb_r()), wb_r()),
            @symcore.pow(wb_rfun(wb_r()), @symcore.int(-1)),
          ]),
        ]),
      ),
    ),
  )
}

///|
test "pde wb: multiplicative preprocessing matches cylindrical reduced equation" {
  let phi = @symcore.applied_undefined_function("Phi", [
    wb_r(),
    wb_theta(),
    Expr::Symbol("z"),
  ])
  let zfun = @symcore.applied_undefined_function("Z", [Expr::Symbol("z")])
  let ufun = @symcore.applied_undefined_function("u", [wb_theta(), wb_r()])
  let laplace_eq = Expr::Relational(
    @symcore.RelOp::Eq,
    canonical_expr(
      @symcore.add([
        @symcore.mul([
          @symcore.pow(wb_r(), @symcore.int(-1)),
          @symcalculus.diff(phi, wb_r()),
        ]),
        @symcalculus.diff(@symcalculus.diff(phi, wb_r()), wb_r()),
        @symcore.mul([
          @symcore.pow(wb_r() ^ @symcore.int(2), @symcore.int(-1)),
          @symcalculus.diff(@symcalculus.diff(phi, wb_theta()), wb_theta()),
        ]),
        @symcalculus.diff(
          @symcalculus.diff(phi, Expr::Symbol("z")),
          Expr::Symbol("z"),
        ),
      ]),
    ),
    @symcore.int(0),
  )
  let first_stage = pde_separate_mul(laplace_eq, phi, [zfun, ufun]).unwrap_or([])
  assert_true(first_stage.length() == 2)
  assert_true(
    wb_same_expr(
      first_stage[1],
      canonical_expr(
        @symcore.add([
          @symcore.mul([
            @symcore.int(-1),
            @symcalculus.diff(@symcalculus.diff(ufun, wb_r()), wb_r()),
            @symcore.pow(ufun, @symcore.int(-1)),
          ]),
          @symcore.mul([
            @symcore.int(-1),
            @symcalculus.diff(ufun, wb_r()),
            @symcore.pow(@symcore.mul([wb_r(), ufun]), @symcore.int(-1)),
          ]),
          @symcore.mul([
            @symcore.int(-1),
            @symcalculus.diff(@symcalculus.diff(ufun, wb_theta()), wb_theta()),
            @symcore.pow(
              @symcore.mul([wb_r() ^ @symcore.int(2), ufun]),
              @symcore.int(-1),
            ),
          ]),
        ]),
      ),
    ),
  )
}

///|
test "pde wb: poly times exp helper integrates eq_c4 characteristic source" {
  let xi = Expr::Symbol("xi")
  let eta = Expr::Symbol("eta")
  let integrand = canonical_expr(
    @symcore.mul([
      @symcore.int(-1),
      @symcore.add([
        xi ^ @symcore.int(2),
        @symcore.mul([@symcore.int(-1), eta ^ @symcore.int(2)]),
      ]),
      @symcore.int(4) ^ @symcore.int(-1),
      @symcore.function("exp", [
        @symcore.mul([@symcore.int(1), xi, @symcore.int(2) ^ @symcore.int(-1)]),
      ]),
    ]),
  )
  let normalized = solver_combine_exp_product(canonical_expr(integrand))
  let (factor, exponent) = match normalized {
    Expr::Mul(args) => {
      let other_args : Array[Expr] = []
      let exp_args : Array[Expr] = []
      for arg in args {
        match @symcore.application_parts(arg) {
          Some((head, [inner])) if @symcore.function_head_name(head) ==
            Some("exp") => exp_args.push(inner)
          _ => other_args.push(arg)
        }
      }
      (canonical_expr(@symcore.mul(other_args)), exp_args[0])
    }
    _ => panic()
  }
  assert_true(
    wb_same_expr(
      exponent,
      canonical_expr(@symcore.mul([xi, @symcore.int(2) ^ @symcore.int(-1)])),
    ),
  )
  assert_true(
    wb_same_expr(
      factor,
      canonical_expr(
        @symcore.mul([
          @symcore.int(-1),
          @symcore.add([
            xi ^ @symcore.int(2),
            @symcore.mul([@symcore.int(-1), eta ^ @symcore.int(2)]),
          ]),
          @symcore.int(4) ^ @symcore.int(-1),
        ]),
      ),
    ),
  )
  let expanded_factor = canonical_expr(
    @symsimplify.numer_expand(solver_expand_expr(factor)),
  )
  assert_true(
    wb_same_expr(
      expanded_factor,
      canonical_expr(
        @symcore.add([
          @symcore.mul([
            @symcore.int(-1),
            xi ^ @symcore.int(2),
            @symcore.int(4) ^ @symcore.int(-1),
          ]),
          @symcore.mul([
            eta ^ @symcore.int(2),
            @symcore.int(4) ^ @symcore.int(-1),
          ]),
        ]),
      ),
    ),
  )
  let helper_hit = match solver_try_integrate_poly_linear_exp(integrand, xi) {
    Some(_) => true
    None => false
  }
  assert_true(helper_hit)
  let antiderivative = solver_try_integrate_poly_linear_exp(integrand, xi).unwrap()
  assert_true(
    wb_same_expr(
      canonical_expr(@symcalculus.diff(antiderivative, xi)),
      integrand,
    ),
  )
}

///|
test "pde wb: pdsolve eq_c4 terminates without Integral fallback" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let u = @symcore.applied_undefined_function("u", [x, y])
  let eq_c4 = canonical_expr(
    @symcore.add([
      u,
      @symcalculus.diff(u, x),
      @symcalculus.diff(u, y),
      @symcore.mul([x, y]),
    ]),
  )
  let sol = pdsolve(eq_c4, func=Some(u))
  let rhs = match sol {
    Expr::Relational(@symcore.RelOp::Eq, _, rhs) => rhs
    _ => panic()
  }
  assert_true(!solver_expr_has_application_name(rhs, "Integral"))
}

///|
test "pde wb: eq_c4 actual on-curve source hits poly exp helper" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let u = @symcore.applied_undefined_function("u", [x, y])
  let eq_c4 = canonical_expr(
    @symcore.add([
      u,
      @symcalculus.diff(u, x),
      @symcalculus.diff(u, y),
      @symcore.mul([x, y]),
    ]),
  )
  let matched = match solver_extract_pde_linear(eq_c4, u) {
    Some(value) => value
    None => panic()
  }
  let (_, _, coeff_x, coeff_y, coeff_f, source) = matched
  let denom = canonical_expr(
    @symcore.add([coeff_x ^ @symcore.int(2), coeff_y ^ @symcore.int(2)]),
  )
  let xi = Expr::Symbol("xi")
  let eta = Expr::Symbol("eta")
  let invariant = canonical_expr(
    @symcore.add([
      @symcore.mul([coeff_y, x]),
      @symcore.mul([@symcore.int(-1), coeff_x, y]),
    ]),
  )
  let x_sub = canonical_expr(
    @symcore.mul([
      @symcore.add([@symcore.mul([coeff_x, xi]), @symcore.mul([coeff_y, eta])]),
      @symcore.pow(denom, @symcore.int(-1)),
    ]),
  )
  let y_sub = canonical_expr(
    @symcore.mul([
      @symcore.add([
        @symcore.mul([@symcore.int(-1), coeff_x, eta]),
        @symcore.mul([coeff_y, xi]),
      ]),
      @symcore.pow(denom, @symcore.int(-1)),
    ]),
  )
  let xy_env : Map[String, Expr] = Map([])
  xy_env["x"] = x_sub
  xy_env["y"] = y_sub
  let transformed_source = canonical_expr(
    @symcore.subst(
      @symcore.mul([
        source,
        @symcore.function("exp", [
          @symcore.mul([coeff_f, xi, @symcore.pow(denom, @symcore.int(-1))]),
        ]),
      ]),
      xy_env,
    ),
  )
  let on_curve_source = solver_combine_exp_product(
    canonical_expr(
      @symsimplify.simplify(
        solver_symbol_subst(transformed_source, eta, invariant),
        max_passes=3,
      ),
    ),
  )
  let helper_hit = match
    solver_try_integrate_poly_linear_exp(on_curve_source, xi) {
    Some(_) => true
    None => false
  }
  assert_true(helper_hit)
}
