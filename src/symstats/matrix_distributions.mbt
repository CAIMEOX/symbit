///|
/// Matrix distribution and random matrix model starter APIs.

///|
pub fn wishart_rv(
  name : String,
  df : @symcore.Expr,
  scale : @symcore.Expr,
) -> RandomVar {
  random_var(name, Matrix(Wishart(df~, scale~)))
}

///|
pub fn matrix_normal_rv(
  name : String,
  mean : @symcore.Expr,
  rowcov : @symcore.Expr,
  colcov : @symcore.Expr,
) -> RandomVar {
  random_var(name, Matrix(MatrixNormal(mean~, rowcov~, colcov~)))
}

///|
pub fn goe_matrix(name : String, size : @symcore.Expr) -> RandomVar {
  random_var(name, Matrix(GOE(size~)))
}

///|
pub fn gue_matrix(name : String, size : @symcore.Expr) -> RandomVar {
  random_var(name, Matrix(GUE(size~)))
}

///|

///|
fn matrix_lambda_args(args : Array[@symcore.Expr]) -> @symcore.Expr {
  if args.length() == 1 {
    args[0]
  } else {
    Tuple(args)
  }
}

///|
fn matrix_indexed(base : String, idx : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Indexed", [
    @symcore.function("IndexedBase", [Symbol(base)]),
    idx,
  ])
}

///|
fn matrix_expr_sub(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.add([a, @symcore.mul([@symcore.int(-1), b])])
}

///|
fn matrix_inverse(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Inverse", [expr])
}

///|
fn matrix_transpose(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Transpose", [expr])
}

///|
fn matrix_trace(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Trace", [expr])
}

///|
fn matrix_determinant(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Determinant", [expr])
}

///|
fn matrix_product(args : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.raw_mul(args)
}

///|
fn matrix_tuple_shape(expr : @symcore.Expr) -> (@symcore.Expr, @symcore.Expr)? {
  match @symcore.tuple_items(expr) {
    Some(rows) if !rows.is_empty() => {
      let col_count = match @symcore.tuple_items(rows[0]) {
        Some(cols) => cols.length()
        None => 1
      }
      Some((@symcore.int(rows.length()), @symcore.int(col_count)))
    }
    _ => None
  }
}

///|
fn matrix_shape_expr(expr : @symcore.Expr) -> (@symcore.Expr, @symcore.Expr)? {
  match (@symcore.application_name(expr), @symcore.application_args(expr)) {
    (Some("MatrixSymbol"), Some([_, rows, cols])) => Some((rows, cols))
    (Some("Matrix"), Some([body])) | (Some("ImmutableMatrix"), Some([body])) =>
      matrix_tuple_shape(body)
    _ => matrix_tuple_shape(expr)
  }
}

///|
fn matrix_shape_with_fallback(
  primary : @symcore.Expr,
  fallback : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr) {
  match matrix_shape_expr(primary) {
    Some(shape) => shape
    None =>
      match matrix_shape_expr(fallback) {
        Some(shape) => shape
        None =>
          (
            @symcore.function("MatrixRows", [primary]),
            @symcore.function("MatrixCols", [primary]),
          )
      }
  }
}

///|
fn matrix_identity_expr(n : @symcore.Expr) -> @symcore.Expr {
  match expr_as_int(n) {
    Some(size) if size > 0 => {
      let rows : Array[@symcore.Expr] = []
      for i in 0..<size {
        let row : Array[@symcore.Expr] = []
        for j in 0..<size {
          row.push(if i == j { @symcore.int(1) } else { @symcore.int(0) })
        }
        rows.push(Tuple(row))
      }
      @symcore.function("Matrix", [Tuple(rows)])
    }
    _ => @symcore.function("Identity", [n])
  }
}

///|
fn matrix_multigamma(a : @symcore.Expr, p : @symcore.Expr) -> @symcore.Expr {
  let pi = @symcore.Expr::NumberSymbol(Pi)
  let quarter = stats_exact_rational(1, 4)
  match expr_as_int(p) {
    Some(size) if size > 0 => {
      let terms : Array[@symcore.Expr] = [
        @symcore.pow(pi, @symcore.int(size * (size - 1) / 4)),
      ]
      if size * (size - 1) % 4 != 0 {
        terms.clear()
        terms.push(@symcore.pow(pi, stats_exact_rational(size * (size - 1), 4)))
      }
      for k in 1..<=size {
        terms.push(
          @symcore.function("gamma", [
            eval_arith(@symcore.add([a, stats_exact_rational(1 - k, 2)])),
          ]),
        )
      }
      eval_arith(@symcore.mul(terms))
    }
    _ => {
      let k = @symcore.Expr::Symbol("_k")
      let exponent = eval_arith(
        @symcore.mul([
          quarter,
          p,
          eval_arith(@symcore.add([p, @symcore.int(-1)])),
        ]),
      )
      let gamma_arg = eval_arith(
        @symcore.add([
          a,
          stats_exact_rational(1, 2),
          eval_arith(@symcore.mul([stats_exact_rational(-1, 2), k])),
        ]),
      )
      eval_arith(
        @symcore.mul([
          @symcore.pow(pi, exponent),
          @symcore.function("Product", [
            @symcore.function("gamma", [gamma_arg]),
            Tuple([k, @symcore.int(1), p]),
          ]),
        ]),
      )
    }
  }
}

///|
fn gaussian_joint_normalization(beta : Int, n : Int) -> @symcore.Expr {
  let beta_e = @symcore.int(beta)
  let n_e = @symcore.int(n)
  let half = stats_exact_rational(1, 2)
  let quarter = stats_exact_rational(1, 4)
  let gamma_den = @symcore.function("gamma", [
    eval_arith(
      @symcore.add([@symcore.int(1), eval_arith(@symcore.mul([half, beta_e]))]),
    ),
  ])
  let gamma_terms : Array[@symcore.Expr] = Array::new()
  for j in 1..<=n {
    gamma_terms.push(
      @symcore.function("gamma", [
        eval_arith(
          @symcore.add([
            @symcore.int(1),
            eval_arith(@symcore.mul([half, beta_e, @symcore.int(j)])),
          ]),
        ),
      ]),
    )
  }
  let gamma_prod = if gamma_terms.is_empty() {
    @symcore.int(1)
  } else {
    eval_arith(@symcore.mul(gamma_terms))
  }
  let term1 = eval_arith(
    @symcore.mul([gamma_prod, @symcore.pow(gamma_den, @symcore.int(-n))]),
  )
  let ratio = eval_arith(
    @symcore.mul([
      @symcore.int(2),
      @symcore.pow(eval_arith(@symcore.mul([beta_e, n_e])), @symcore.int(-1)),
    ]),
  )
  let ratio_pow = eval_arith(
    @symcore.add([
      eval_arith(
        @symcore.mul([
          quarter,
          beta_e,
          n_e,
          eval_arith(@symcore.add([n_e, @symcore.int(-1)])),
        ]),
      ),
      eval_arith(@symcore.mul([half, n_e])),
    ]),
  )
  let term2 = eval_arith(@symcore.pow(ratio, ratio_pow))
  let term3 = eval_arith(
    @symcore.pow(
      eval_arith(@symcore.mul([@symcore.int(2), NumberSymbol(Pi)])),
      eval_arith(@symcore.mul([half, n_e])),
    ),
  )
  eval_arith(@symcore.mul([term1, term2, term3]))
}

///|
fn circular_joint_normalization(beta : Int, n : Int) -> @symcore.Expr {
  let beta_e = @symcore.int(beta)
  let n_e = @symcore.int(n)
  let half = stats_exact_rational(1, 2)
  let term1 = eval_arith(
    @symcore.pow(
      eval_arith(@symcore.mul([@symcore.int(2), NumberSymbol(Pi)])),
      n_e,
    ),
  )
  let term2 = @symcore.function("gamma", [
    eval_arith(
      @symcore.add([
        eval_arith(@symcore.mul([half, beta_e, n_e])),
        @symcore.int(1),
      ]),
    ),
  ])
  let term3 = eval_arith(
    @symcore.pow(
      @symcore.function("gamma", [
        eval_arith(
          @symcore.add([
            eval_arith(@symcore.mul([half, beta_e])),
            @symcore.int(1),
          ]),
        ),
      ]),
      n_e,
    ),
  )
  eval_arith(
    @symcore.mul([term1, term2, @symcore.pow(term3, @symcore.int(-1))]),
  )
}

///|
fn matrix_ensemble_spec(rv : RandomVar) -> (Int, @symcore.Expr, Bool)? {
  match rv.kind {
    Matrix(GOE(size~)) => Some((1, size, false))
    Matrix(GUE(size~)) => Some((2, size, false))
    Symbolic(kind~, params~) if kind is Matrix(tag) =>
      if params.length() == 1 {
        match tag {
          GaussianOrthogonalEnsemble => Some((1, params[0], false))
          GaussianUnitaryEnsemble => Some((2, params[0], false))
          GaussianSymplecticEnsemble => Some((4, params[0], false))
          CircularOrthogonalEnsemble => Some((1, params[0], true))
          CircularUnitaryEnsemble => Some((2, params[0], true))
          CircularSymplecticEnsemble => Some((4, params[0], true))
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
          for i in 1..<=n {
            vars.push(matrix_indexed(base, @symcore.int(i)))
          }
          let beta_e = @symcore.int(beta)
          let pair = if circular {
            let j = @symcore.Expr::Symbol("_j")
            let k = @symcore.Expr::Symbol("_k")
            let tj = matrix_indexed("t", j)
            let tk = matrix_indexed("t", k)
            let abs_term = eval_arith(
              @symcore.pow(
                @symcore.function("Abs", [
                  eval_arith(
                    @symcore.add([
                      @symcore.function("exp", [
                        eval_arith(
                          @symcore.mul([NumberSymbol(ImaginaryUnit), tj]),
                        ),
                      ]),
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("exp", [
                          eval_arith(
                            @symcore.mul([NumberSymbol(ImaginaryUnit), tk]),
                          ),
                        ]),
                      ]),
                    ]),
                  ),
                ]),
                beta_e,
              ),
            )
            @symcore.function("Product", [
              abs_term,
              Tuple([
                j,
                eval_arith(@symcore.add([k, @symcore.int(1)])),
                @symcore.int(n),
              ]),
              Tuple([k, @symcore.int(1), @symcore.int(n - 1)]),
            ])
          } else {
            let i = @symcore.Expr::Symbol("_i")
            let j = @symcore.Expr::Symbol("_j")
            let li = matrix_indexed("l", i)
            let lj = matrix_indexed("l", j)
            let abs_term = eval_arith(
              @symcore.pow(
                @symcore.function("Abs", [
                  eval_arith(
                    @symcore.add([li, @symcore.mul([@symcore.int(-1), lj])]),
                  ),
                ]),
                beta_e,
              ),
            )
            @symcore.function("Product", [
              abs_term,
              Tuple([
                j,
                eval_arith(@symcore.add([i, @symcore.int(1)])),
                @symcore.int(n),
              ]),
              Tuple([i, @symcore.int(1), @symcore.int(n - 1)]),
            ])
          }
          let numer = if circular {
            pair
          } else {
            let half = stats_exact_rational(1, 2)
            let n_e = @symcore.int(n)
            let squares = vars.map(v => {
              eval_arith(@symcore.pow(v, @symcore.int(2)))
            })
            let sum_sq = if squares.is_empty() {
              @symcore.int(0)
            } else {
              eval_arith(@symcore.add(squares))
            }
            let exp_term = @symcore.function("exp", [
              eval_arith(@symcore.mul([@symcore.int(-1), half, n_e, sum_sq])),
            ])
            eval_arith(@symcore.mul([exp_term, pair]))
          }
          let z = if circular {
            circular_joint_normalization(beta, n)
          } else {
            gaussian_joint_normalization(beta, n)
          }
          let density = eval_arith(
            @symcore.mul([numer, @symcore.pow(z, @symcore.int(-1))]),
          )
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
        let s = @symcore.Expr::Symbol("_s")
        let half = stats_exact_rational(1, 2)
        let quarter = stats_exact_rational(1, 4)
        let density = match beta {
          1 =>
            eval_arith(
              @symcore.mul([
                half,
                NumberSymbol(Pi),
                s,
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-1),
                      quarter,
                      NumberSymbol(Pi),
                      @symcore.pow(s, @symcore.int(2)),
                    ]),
                  ),
                ]),
              ]),
            )
          2 =>
            eval_arith(
              @symcore.mul([
                @symcore.int(32),
                @symcore.pow(NumberSymbol(Pi), @symcore.int(-2)),
                @symcore.pow(s, @symcore.int(2)),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-4),
                      @symcore.pow(NumberSymbol(Pi), @symcore.int(-1)),
                      @symcore.pow(s, @symcore.int(2)),
                    ]),
                  ),
                ]),
              ]),
            )
          4 =>
            eval_arith(
              @symcore.mul([
                @symcore.pow(@symcore.int(2), @symcore.int(18)),
                @symcore.pow(@symcore.int(3), @symcore.int(-6)),
                @symcore.pow(NumberSymbol(Pi), @symcore.int(-3)),
                @symcore.pow(s, @symcore.int(4)),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-64),
                      @symcore.pow(
                        eval_arith(
                          @symcore.mul([@symcore.int(9), NumberSymbol(Pi)]),
                        ),
                        @symcore.int(-1),
                      ),
                      @symcore.pow(s, @symcore.int(2)),
                    ]),
                  ),
                ]),
              ]),
            )
          _ => return None
        }
        Some(@symcore.function("Lambda", [s, density]))
      }
    None => None
  }
}

///|
fn gaussian_unitary_density_expr(
  n : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  let half = stats_exact_rational(1, 2)
  let trace_x2 = matrix_trace(@symcore.pow(x, @symcore.int(2)))
  let numerator = @symcore.function("exp", [
    eval_arith(@symcore.mul([@symcore.int(-1), half, n, trace_x2])),
  ])
  let denominator = eval_arith(
    @symcore.mul([
      @symcore.pow(@symcore.int(2), eval_arith(@symcore.mul([half, n]))),
      @symcore.pow(
        NumberSymbol(Pi),
        eval_arith(@symcore.mul([half, @symcore.pow(n, @symcore.int(2))])),
      ),
    ]),
  )
  eval_arith(
    @symcore.mul([numerator, @symcore.pow(denominator, @symcore.int(-1))]),
  )
}

///|
fn gaussian_orthogonal_density_expr(
  n : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  let quarter = stats_exact_rational(1, 4)
  let h = @symcore.function("MatrixSymbol", [Symbol("_H"), n, n])
  let trace_x2 = matrix_trace(@symcore.pow(x, @symcore.int(2)))
  let trace_h2 = matrix_trace(@symcore.pow(h, @symcore.int(2)))
  let numerator = @symcore.function("exp", [
    eval_arith(@symcore.mul([@symcore.int(-1), quarter, n, trace_x2])),
  ])
  let denominator = @symcore.function("Integral", [
    @symcore.function("exp", [
      eval_arith(@symcore.mul([@symcore.int(-1), quarter, n, trace_h2])),
    ]),
    h,
  ])
  eval_arith(
    @symcore.mul([numerator, @symcore.pow(denominator, @symcore.int(-1))]),
  )
}

///|
fn gaussian_symplectic_density_expr(
  n : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  let h = @symcore.function("MatrixSymbol", [Symbol("_H"), n, n])
  let trace_x2 = matrix_trace(@symcore.pow(x, @symcore.int(2)))
  let trace_h2 = matrix_trace(@symcore.pow(h, @symcore.int(2)))
  let numerator = @symcore.function("exp", [
    eval_arith(@symcore.mul([@symcore.int(-1), n, trace_x2])),
  ])
  let denominator = @symcore.function("Integral", [
    @symcore.function("exp", [
      eval_arith(@symcore.mul([@symcore.int(-1), n, trace_h2])),
    ]),
    h,
  ])
  eval_arith(
    @symcore.mul([numerator, @symcore.pow(denominator, @symcore.int(-1))]),
  )
}

///|
fn wishart_density_expr(
  x : @symcore.Expr,
  df : @symcore.Expr,
  scale : @symcore.Expr,
) -> @symcore.Expr {
  let (p, _) = matrix_shape_with_fallback(scale, x)
  let half = stats_exact_rational(1, 2)
  let df_half = eval_arith(@symcore.mul([half, df]))
  let sigma_inv_x = matrix_product([
    stats_exact_rational(-1, 2),
    matrix_inverse(scale),
    x,
  ])
  let term1_den = eval_arith(
    @symcore.mul([
      @symcore.pow(@symcore.int(2), eval_arith(@symcore.mul([p, df_half]))),
      matrix_multigamma(df_half, p),
    ]),
  )
  let det_scale_pow = @symcore.pow(
    matrix_determinant(scale),
    @symcore.mul([@symcore.int(-1), df_half]),
  )
  let det_x_pow = @symcore.pow(
    matrix_determinant(x),
    eval_arith(
      @symcore.mul([
        half,
        eval_arith(
          @symcore.add([
            df,
            @symcore.mul([@symcore.int(-1), p]),
            @symcore.int(-1),
          ]),
        ),
      ]),
    ),
  )
  eval_arith(
    @symcore.mul([
      @symcore.function("exp", [matrix_trace(sigma_inv_x)]),
      @symcore.pow(term1_den, @symcore.int(-1)),
      det_scale_pow,
      det_x_pow,
    ]),
  )
}

///|
fn matrix_gamma_density_expr(
  x : @symcore.Expr,
  alpha : @symcore.Expr,
  beta : @symcore.Expr,
  scale : @symcore.Expr,
) -> @symcore.Expr {
  let (p, _) = matrix_shape_with_fallback(scale, x)
  let half = stats_exact_rational(1, 2)
  let sigma_inv_x = matrix_product([
    @symcore.int(-1),
    @symcore.pow(beta, @symcore.int(-1)),
    matrix_inverse(scale),
    x,
  ])
  let term1_den = eval_arith(
    @symcore.mul([
      @symcore.pow(beta, eval_arith(@symcore.mul([p, alpha]))),
      matrix_multigamma(alpha, p),
    ]),
  )
  let det_x_exp = eval_arith(
    @symcore.add([
      alpha,
      eval_arith(
        @symcore.mul([
          @symcore.int(-1),
          half,
          eval_arith(@symcore.add([p, @symcore.int(1)])),
        ]),
      ),
    ]),
  )
  eval_arith(
    @symcore.mul([
      @symcore.function("exp", [matrix_trace(sigma_inv_x)]),
      @symcore.pow(term1_den, @symcore.int(-1)),
      @symcore.pow(
        matrix_determinant(scale),
        @symcore.mul([@symcore.int(-1), alpha]),
      ),
      @symcore.pow(matrix_determinant(x), det_x_exp),
    ]),
  )
}

///|
fn matrix_normal_density_expr(
  x : @symcore.Expr,
  mean : @symcore.Expr,
  rowcov : @symcore.Expr,
  colcov : @symcore.Expr,
) -> @symcore.Expr {
  let (n, p) = matrix_shape_with_fallback(mean, x)
  let half = stats_exact_rational(1, 2)
  let diff = matrix_expr_sub(x, mean)
  let quad = matrix_product([
    matrix_inverse(colcov),
    matrix_transpose(diff),
    matrix_inverse(rowcov),
    diff,
  ])
  let numerator = @symcore.function("exp", [
    eval_arith(@symcore.mul([@symcore.int(-1), half, matrix_trace(quad)])),
  ])
  let two_pi = eval_arith(@symcore.mul([@symcore.int(2), NumberSymbol(Pi)]))
  let denominator = eval_arith(
    @symcore.mul([
      @symcore.pow(two_pi, eval_arith(@symcore.mul([half, n, p]))),
      @symcore.pow(
        matrix_determinant(rowcov),
        eval_arith(@symcore.mul([half, p])),
      ),
      @symcore.pow(
        matrix_determinant(colcov),
        eval_arith(@symcore.mul([half, n])),
      ),
    ]),
  )
  eval_arith(
    @symcore.mul([numerator, @symcore.pow(denominator, @symcore.int(-1))]),
  )
}

///|
fn matrix_student_t_density_expr(
  x : @symcore.Expr,
  nu : @symcore.Expr,
  mean : @symcore.Expr,
  omega : @symcore.Expr,
  sigma : @symcore.Expr,
) -> @symcore.Expr {
  let (n, p) = matrix_shape_with_fallback(mean, x)
  let half = stats_exact_rational(1, 2)
  let numerator_gamma_arg = eval_arith(
    @symcore.mul([half, eval_arith(@symcore.add([nu, n, p, @symcore.int(-1)]))]),
  )
  let denominator_gamma_arg = eval_arith(
    @symcore.mul([half, eval_arith(@symcore.add([nu, p, @symcore.int(-1)]))]),
  )
  let normalizer = eval_arith(
    @symcore.mul([
      matrix_multigamma(numerator_gamma_arg, p),
      @symcore.pow(
        matrix_determinant(omega),
        eval_arith(@symcore.mul([@symcore.int(-1), half, n])),
      ),
      @symcore.pow(
        matrix_determinant(sigma),
        eval_arith(@symcore.mul([@symcore.int(-1), half, p])),
      ),
      @symcore.pow(
        NumberSymbol(Pi),
        eval_arith(@symcore.mul([@symcore.int(-1), half, n, p])),
      ),
      @symcore.pow(
        matrix_multigamma(denominator_gamma_arg, p),
        @symcore.int(-1),
      ),
    ]),
  )
  let diff = matrix_expr_sub(x, mean)
  let inner_product = matrix_product([
    matrix_inverse(sigma),
    diff,
    matrix_inverse(omega),
    matrix_transpose(diff),
  ])
  let determinant = matrix_determinant(
    @symcore.raw_add([matrix_identity_expr(n), inner_product]),
  )
  eval_arith(
    @symcore.mul([
      normalizer,
      @symcore.pow(
        determinant,
        eval_arith(@symcore.mul([@symcore.int(-1), numerator_gamma_arg])),
      ),
    ]),
  )
}

///|
pub fn matrix_density(rv : RandomVar, x : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    Matrix(Wishart(df~, scale~)) => Some(wishart_density_expr(x, df, scale))
    Matrix(MatrixNormal(mean~, rowcov~, colcov~)) =>
      Some(matrix_normal_density_expr(x, mean, rowcov, colcov))
    Matrix(GOE(size~)) => Some(gaussian_orthogonal_density_expr(size, x))
    Matrix(GUE(size~)) => Some(gaussian_unitary_density_expr(size, x))
    Symbolic(kind~, params~) if kind is Matrix(tag) =>
      match tag {
        GaussianUnitaryEnsemble if params.length() == 1 =>
          Some(gaussian_unitary_density_expr(params[0], x))
        GaussianOrthogonalEnsemble if params.length() == 1 =>
          Some(gaussian_orthogonal_density_expr(params[0], x))
        GaussianSymplecticEnsemble if params.length() == 1 =>
          Some(gaussian_symplectic_density_expr(params[0], x))
        MatrixStudentT if params.length() == 4 =>
          Some(
            matrix_student_t_density_expr(
              x,
              params[0],
              params[1],
              params[2],
              params[3],
            ),
          )
        MatrixStudentT =>
          Some(@symcore.function("density", [Symbol(rv.name), x]))
        MatrixGamma if params.length() == 3 =>
          Some(matrix_gamma_density_expr(x, params[0], params[1], params[2]))
        MatrixGamma => Some(@symcore.function("density", [Symbol(rv.name), x]))
        _ => {
          let name = matrix_tag_name(tag)
          let args : Array[@symcore.Expr] = []
          for p in params {
            args.push(p)
          }
          Some(@symcore.function("density", [@symcore.function(name, args), x]))
        }
      }
    _ => None
  }
}
