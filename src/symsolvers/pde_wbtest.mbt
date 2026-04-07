///|
fn wb_same_expr(lhs : Expr, rhs : Expr) -> Bool {
  expr_is_zeroish(
    canonical_expr(
      @symsimplify.simplify(
        canonical_expr(@symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])])),
        max_passes=3,
      ),
    ),
  ) == Some(true)
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
      @symcalculus.diff(@symcalculus.diff(wb_tfun(wb_theta()), wb_theta()), wb_theta()),
      @symcore.pow(
        @symcore.mul([(wb_r() ^ @symcore.int(2)), wb_tfun(wb_theta())]),
        @symcore.int(-1),
      ),
    ]),
  )
  let (ext, sep) = solver_pde_as_independent_mul(term, wb_theta())
  assert_true(
    wb_same_expr(
      ext,
      canonical_expr(@symcore.mul([@symcore.int(-1), (wb_r() ^ @symcore.int(-2))])),
    ),
  )
  assert_true(
    wb_same_expr(
      sep,
      canonical_expr(
        @symcore.mul([
          @symcalculus.diff(@symcalculus.diff(wb_tfun(wb_theta()), wb_theta()), wb_theta()),
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
        (wb_r() ^ @symcore.int(2)),
        @symcalculus.diff(@symcalculus.diff(wb_rfun(wb_r()), wb_r()), wb_r()),
        @symcore.pow(wb_rfun(wb_r()), @symcore.int(-1)),
      ]),
      @symcore.mul([
        wb_r(),
        @symcalculus.diff(wb_rfun(wb_r()), wb_r()),
        @symcore.pow(wb_rfun(wb_r()), @symcore.int(-1)),
      ]),
      @symcore.mul([
        @symcalculus.diff(@symcalculus.diff(wb_tfun(wb_theta()), wb_theta()), wb_theta()),
        @symcore.pow(wb_tfun(wb_theta()), @symcore.int(-1)),
      ]),
    ]),
  )
  let separated = solver_simple_pde_separate(reduced, [wb_theta()], [wb_r()]).unwrap_or([])
  assert_eq(separated.length(), 2)
  assert_true(
    wb_same_expr(
      separated[0],
      canonical_expr(
        @symcore.mul([
          @symcalculus.diff(@symcalculus.diff(wb_tfun(wb_theta()), wb_theta()), wb_theta()),
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
          @symcore.mul([
            @symcore.int(-1),
            c,
            (wb_r() ^ @symcore.int(2)),
          ]),
          @symcore.mul([
            @symcore.int(-1),
            (wb_r() ^ @symcore.int(2)),
            @symcalculus.diff(@symcalculus.diff(wb_rfun(wb_r()), wb_r()), wb_r()),
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
  let phi = @symcore.applied_undefined_function("Phi", [wb_r(), wb_theta(), Expr::Symbol("z")])
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
        @symcalculus.diff(@symcalculus.diff(phi, Expr::Symbol("z")), Expr::Symbol("z")),
      ]),
    ),
    @symcore.int(0),
  )
  let first_stage = pde_separate_mul(
    laplace_eq,
    phi,
    [zfun, ufun],
  ).unwrap_or([])
  assert_eq(first_stage.length(), 2)
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
            @symcore.pow(@symcore.mul([(wb_r() ^ @symcore.int(2)), ufun]), @symcore.int(-1)),
          ]),
        ]),
      ),
    ),
  )
}
