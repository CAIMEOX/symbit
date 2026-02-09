///|
/// Matrix distribution and random matrix model starter APIs.

///|
pub fn wishart_rv(
  name : String,
  df : @symcore.Expr,
  scale : @symcore.Expr,
) -> RandomVar {
  random_var(name, RVKind::Matrix(MatrixKind::Wishart(df~, scale~)))
}

///|
pub fn matrix_normal_rv(
  name : String,
  mean : @symcore.Expr,
  rowcov : @symcore.Expr,
  colcov : @symcore.Expr,
) -> RandomVar {
  random_var(name, RVKind::Matrix(MatrixKind::MatrixNormal(mean~, rowcov~, colcov~)))
}

///|
pub fn goe_matrix(name : String, size : @symcore.Expr) -> RandomVar {
  random_var(name, RVKind::Matrix(MatrixKind::GOE(size~)))
}

///|
pub fn gue_matrix(name : String, size : @symcore.Expr) -> RandomVar {
  random_var(name, RVKind::Matrix(MatrixKind::GUE(size~)))
}

///|
fn matrix_tuple_expr(items : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.function("Tuple", items)
}

///|
fn matrix_lambda_args(args : Array[@symcore.Expr]) -> @symcore.Expr {
  if args.length() == 1 {
    args[0]
  } else {
    matrix_tuple_expr(args)
  }
}

///|
fn matrix_indexed(base : String, idx : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Indexed", [
    @symcore.function("IndexedBase", [@symcore.symbol(base)]),
    idx,
  ])
}

///|
fn gaussian_joint_normalization(beta : Int, n : Int) -> @symcore.Expr {
  let beta_e = @symcore.int(beta)
  let n_e = @symcore.int(n)
  let half = try! @symcore.rational_from_ints(1, 2)
  let quarter = try! @symcore.rational_from_ints(1, 4)
  let gamma_den = @symcore.function("gamma", [
    eval_arith(@symcore.add([@symcore.int(1), eval_arith(@symcore.mul([half, beta_e]))])),
  ])
  let gamma_terms : Array[@symcore.Expr] = Array::new()
  for j in 1..=n {
    gamma_terms.push(@symcore.function("gamma", [
      eval_arith(@symcore.add([
        @symcore.int(1),
        eval_arith(@symcore.mul([half, beta_e, @symcore.int(j)])),
      ])),
    ]))
  }
  let gamma_prod =
    if gamma_terms.is_empty() {
      @symcore.int(1)
    } else {
      eval_arith(@symcore.mul(gamma_terms))
    }
  let term1 = eval_arith(@symcore.mul([
    gamma_prod,
    @symcore.pow(gamma_den, @symcore.int(-n)),
  ]))
  let ratio = eval_arith(@symcore.mul([
    @symcore.int(2),
    @symcore.pow(eval_arith(@symcore.mul([beta_e, n_e])), @symcore.int(-1)),
  ]))
  let ratio_pow = eval_arith(@symcore.add([
    eval_arith(@symcore.mul([
      quarter,
      beta_e,
      n_e,
      eval_arith(@symcore.add([n_e, @symcore.int(-1)])),
    ])),
    eval_arith(@symcore.mul([half, n_e])),
  ]))
  let term2 = eval_arith(@symcore.pow(ratio, ratio_pow))
  let term3 = eval_arith(@symcore.pow(
    eval_arith(@symcore.mul([@symcore.int(2), @symcore.symbol("pi")])),
    eval_arith(@symcore.mul([half, n_e])),
  ))
  eval_arith(@symcore.mul([term1, term2, term3]))
}

///|
fn circular_joint_normalization(beta : Int, n : Int) -> @symcore.Expr {
  let beta_e = @symcore.int(beta)
  let n_e = @symcore.int(n)
  let half = try! @symcore.rational_from_ints(1, 2)
  let term1 = eval_arith(@symcore.pow(
    eval_arith(@symcore.mul([@symcore.int(2), @symcore.symbol("pi")])),
    n_e,
  ))
  let term2 = @symcore.function("gamma", [
    eval_arith(@symcore.add([
      eval_arith(@symcore.mul([half, beta_e, n_e])),
      @symcore.int(1),
    ])),
  ])
  let term3 = eval_arith(@symcore.pow(
    @symcore.function("gamma", [
      eval_arith(@symcore.add([
        eval_arith(@symcore.mul([half, beta_e])),
        @symcore.int(1),
      ])),
    ]),
    n_e,
  ))
  eval_arith(@symcore.mul([
    term1,
    term2,
    @symcore.pow(term3, @symcore.int(-1)),
  ]))
}

///|
fn matrix_ensemble_spec(rv : RandomVar) -> (Int, @symcore.Expr, Bool)? {
  match rv.kind {
    RVKind::Matrix(MatrixKind::GOE(size~)) => Some((1, size, false))
    RVKind::Matrix(MatrixKind::GUE(size~)) => Some((2, size, false))
    RVKind::Symbolic(tag~, params~) =>
      if params.length() == 1 {
        match symbolic_tag_name(tag) {
          "GaussianOrthogonalEnsemble" => Some((1, params[0], false))
          "GaussianUnitaryEnsemble" => Some((2, params[0], false))
          "GaussianSymplecticEnsemble" => Some((4, params[0], false))
          "CircularOrthogonalEnsemble" => Some((1, params[0], true))
          "CircularUnitaryEnsemble" => Some((2, params[0], true))
          "CircularSymplecticEnsemble" => Some((4, params[0], true))
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn joint_eigen_distribution_of(rv : RandomVar) -> @symcore.Expr? {
  match matrix_ensemble_spec(rv) {
    Some((beta, n_expr, circular)) =>
      match expr_as_int(n_expr) {
        Some(n) if n > 0 => {
          let vars : Array[@symcore.Expr] = Array::new()
          let base = if circular { "t" } else { "l" }
          for i in 1..=n {
            vars.push(matrix_indexed(base, @symcore.int(i)))
          }
          let beta_e = @symcore.int(beta)
          let pair = if circular {
            let j = @symcore.symbol("_j")
            let k = @symcore.symbol("_k")
            let tj = matrix_indexed("t", j)
            let tk = matrix_indexed("t", k)
            let abs_term = eval_arith(@symcore.pow(
              @symcore.function("Abs", [
                eval_arith(@symcore.add([
                  @symcore.function("exp", [eval_arith(@symcore.mul([@symcore.symbol("I"), tj]))]),
                  @symcore.mul([@symcore.int(-1), @symcore.function("exp", [eval_arith(@symcore.mul([@symcore.symbol("I"), tk]))])]),
                ])),
              ]),
              beta_e,
            ))
            @symcore.function("Product", [
              abs_term,
              matrix_tuple_expr([j, eval_arith(@symcore.add([k, @symcore.int(1)])), @symcore.int(n)]),
              matrix_tuple_expr([k, @symcore.int(1), @symcore.int(n - 1)]),
            ])
          } else {
            let i = @symcore.symbol("_i")
            let j = @symcore.symbol("_j")
            let li = matrix_indexed("l", i)
            let lj = matrix_indexed("l", j)
            let abs_term = eval_arith(@symcore.pow(
              @symcore.function("Abs", [eval_arith(@symcore.add([li, @symcore.mul([@symcore.int(-1), lj])]))]),
              beta_e,
            ))
            @symcore.function("Product", [
              abs_term,
              matrix_tuple_expr([j, eval_arith(@symcore.add([i, @symcore.int(1)])), @symcore.int(n)]),
              matrix_tuple_expr([i, @symcore.int(1), @symcore.int(n - 1)]),
            ])
          }
          let numer =
            if circular {
              pair
            } else {
              let half = try! @symcore.rational_from_ints(1, 2)
              let n_e = @symcore.int(n)
              let squares = vars.map(v => eval_arith(@symcore.pow(v, @symcore.int(2))))
              let sum_sq =
                if squares.is_empty() {
                  @symcore.int(0)
                } else {
                  eval_arith(@symcore.add(squares))
                }
              let exp_term = @symcore.function("exp", [
                eval_arith(@symcore.mul([
                  @symcore.int(-1),
                  half,
                  n_e,
                  sum_sq,
                ])),
              ])
              eval_arith(@symcore.mul([exp_term, pair]))
            }
          let z =
            if circular {
              circular_joint_normalization(beta, n)
            } else {
              gaussian_joint_normalization(beta, n)
            }
          let density = eval_arith(@symcore.mul([numer, @symcore.pow(z, @symcore.int(-1))]))
          Some(@symcore.function("Lambda", [matrix_lambda_args(vars), density]))
        }
        _ => None
      }
    None => None
  }
}

///|
pub fn level_spacing_distribution_of(rv : RandomVar) -> @symcore.Expr? {
  match matrix_ensemble_spec(rv) {
    Some((beta, _, circular)) =>
      if circular {
        None
      } else {
        let s = @symcore.symbol("_s")
        let half = try! @symcore.rational_from_ints(1, 2)
        let quarter = try! @symcore.rational_from_ints(1, 4)
        let density =
          match beta {
            1 =>
              eval_arith(@symcore.mul([
                half,
                @symcore.symbol("pi"),
                s,
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([
                    @symcore.int(-1),
                    quarter,
                    @symcore.symbol("pi"),
                    @symcore.pow(s, @symcore.int(2)),
                  ])),
                ]),
              ]))
            2 =>
              eval_arith(@symcore.mul([
                @symcore.int(32),
                @symcore.pow(@symcore.symbol("pi"), @symcore.int(-2)),
                @symcore.pow(s, @symcore.int(2)),
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([
                    @symcore.int(-4),
                    @symcore.pow(@symcore.symbol("pi"), @symcore.int(-1)),
                    @symcore.pow(s, @symcore.int(2)),
                  ])),
                ]),
              ]))
            4 =>
              eval_arith(@symcore.mul([
                @symcore.pow(@symcore.int(2), @symcore.int(18)),
                @symcore.pow(@symcore.int(3), @symcore.int(-6)),
                @symcore.pow(@symcore.symbol("pi"), @symcore.int(-3)),
                @symcore.pow(s, @symcore.int(4)),
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([
                    @symcore.int(-64),
                    @symcore.pow(eval_arith(@symcore.mul([@symcore.int(9), @symcore.symbol("pi")])), @symcore.int(-1)),
                    @symcore.pow(s, @symcore.int(2)),
                  ])),
                ]),
              ]))
            _ => return None
          }
        Some(@symcore.function("Lambda", [s, density]))
      }
    None => None
  }
}

///|
pub fn matrix_density(rv : RandomVar, x : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Matrix(MatrixKind::Wishart(df~, scale~)) =>
      Some(@symcore.function("WishartDensity", [x, df, scale]))
    RVKind::Matrix(MatrixKind::MatrixNormal(mean~, rowcov~, colcov~)) =>
      Some(@symcore.function("MatrixNormalDensity", [x, mean, rowcov, colcov]))
    RVKind::Matrix(MatrixKind::GOE(size~)) =>
      Some(@symcore.function("GOEDensity", [x, size]))
    RVKind::Matrix(MatrixKind::GUE(size~)) =>
      Some(@symcore.function("GUEDensity", [x, size]))
    RVKind::Symbolic(tag~, params~) => {
      let name = symbolic_tag_name(tag)
      let family = symbolic_tag_family(tag)
      match name {
        "GaussianUnitaryEnsemble" if params.length() == 1 => {
          let n = params[0]
          let half = try! @symcore.rational_from_ints(1, 2)
          let trace_x2 = @symcore.function("Trace", [@symcore.pow(x, @symcore.int(2))])
          let numerator = @symcore.function("exp", [
            eval_arith(@symcore.mul([
              @symcore.int(-1),
              half,
              n,
              trace_x2,
            ])),
          ])
          let denominator = eval_arith(@symcore.mul([
            @symcore.pow(@symcore.int(2), eval_arith(@symcore.mul([half, n]))),
            @symcore.pow(
              @symcore.symbol("pi"),
              eval_arith(@symcore.mul([
                half,
                @symcore.pow(n, @symcore.int(2)),
              ])),
            ),
          ]))
          Some(eval_arith(@symcore.mul([
            numerator,
            @symcore.pow(denominator, @symcore.int(-1)),
          ])))
        }
        "GaussianOrthogonalEnsemble" if params.length() == 1 => {
          let n = params[0]
          let quarter = try! @symcore.rational_from_ints(1, 4)
          let h = @symcore.function("MatrixSymbol", [@symcore.symbol("_H"), n, n])
          let trace_x2 = @symcore.function("Trace", [@symcore.pow(x, @symcore.int(2))])
          let trace_h2 = @symcore.function("Trace", [@symcore.pow(h, @symcore.int(2))])
          let numerator = @symcore.function("exp", [
            eval_arith(@symcore.mul([
              @symcore.int(-1),
              quarter,
              n,
              trace_x2,
            ])),
          ])
          let denominator = @symcore.function("Integral", [
            @symcore.function("exp", [
              eval_arith(@symcore.mul([
                @symcore.int(-1),
                quarter,
                n,
                trace_h2,
              ])),
            ]),
            h,
          ])
          Some(eval_arith(@symcore.mul([
            numerator,
            @symcore.pow(denominator, @symcore.int(-1)),
          ])))
        }
        "GaussianSymplecticEnsemble" if params.length() == 1 => {
          let n = params[0]
          let h = @symcore.function("MatrixSymbol", [@symcore.symbol("_H"), n, n])
          let trace_x2 = @symcore.function("Trace", [@symcore.pow(x, @symcore.int(2))])
          let trace_h2 = @symcore.function("Trace", [@symcore.pow(h, @symcore.int(2))])
          let numerator = @symcore.function("exp", [
            eval_arith(@symcore.mul([
              @symcore.int(-1),
              n,
              trace_x2,
            ])),
          ])
          let denominator = @symcore.function("Integral", [
            @symcore.function("exp", [
              eval_arith(@symcore.mul([
                @symcore.int(-1),
                n,
                trace_h2,
              ])),
            ]),
            h,
          ])
          Some(eval_arith(@symcore.mul([
            numerator,
            @symcore.pow(denominator, @symcore.int(-1)),
          ])))
        }
        "MatrixStudentT" if params.length() == 4 => {
          let args : Array[@symcore.Expr] = [x]
          for p in params {
            args.push(p)
          }
          Some(@symcore.function("MatrixStudentTDensity", args))
        }
        "MatrixStudentT" =>
          Some(@symcore.function("MatrixStudentTDensity", [x, @symcore.symbol(rv.name)]))
        "MatrixGamma" if params.length() == 3 => {
          let args : Array[@symcore.Expr] = [x]
          for p in params {
            args.push(p)
          }
          Some(@symcore.function("MatrixGammaDensity", args))
        }
        "MatrixGamma" =>
          Some(@symcore.function("MatrixGammaDensity", [x, @symcore.symbol(rv.name)]))
        _ =>
          if family == "M" {
            let args : Array[@symcore.Expr] = [x]
            for p in params {
              args.push(p)
            }
            Some(@symcore.function("\{name}Density", args))
          } else {
            None
          }
      }
    }
    _ => None
  }
}
