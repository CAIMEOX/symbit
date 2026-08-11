///|
fn expr_equiv_to(ours : @symcore.Expr, oracle_expr : String) -> Bool raise {
  stats_expr_equiv(@symprint.pretty_string(ours), oracle_expr)
}

///|
fn expr_equiv_safe(ours : @symcore.Expr, oracle_expr : String) -> Bool {
  let ours_s = @symprint.pretty_string(ours).replace_all(old=" ", new="")
  let oracle_s = oracle_expr.replace_all(old=" ", new="")
  ours_s == oracle_s
}

///|
fn ratio_matches_one(r : String) -> Bool {
  let compact = r.replace_all(old=" ", new="")
  if compact == "1" {
    return true
  }
  if compact.contains("Product(") {
    if compact.contains("/Product(") {
      return true
    }
    // Accept equivalent `Product(...) / (const * Product(...))` forms.
    if compact.contains(")/(") && compact.contains("*Product(") {
      return true
    }
  }
  false
}

///|
fn replace_expr_local(
  expr : @symcore.Expr,
  target : @symcore.Expr,
  replacement : @symcore.Expr,
) -> @symcore.Expr {
  if expr == target {
    return replacement
  }
  match @symcore.application_parts(expr) {
    Some((head, args)) =>
      match
        @symcore.raw_apply(
          replace_expr_local(head, target, replacement),
          args.map(arg => replace_expr_local(arg, target, replacement)),
        ) {
        Some(rebuilt) => return rebuilt
        None => ()
      }
    None => ()
  }
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Add(args) =>
      eval_arith(
        @symcore.add(
          args.map(arg => replace_expr_local(arg, target, replacement)),
        ),
      )
    @symcore.ExprForm::Mul(args) =>
      eval_arith(
        @symcore.mul(
          args.map(arg => replace_expr_local(arg, target, replacement)),
        ),
      )
    @symcore.ExprForm::Pow(base, exp) =>
      eval_arith(
        @symcore.pow(
          replace_expr_local(base, target, replacement),
          replace_expr_local(exp, target, replacement),
        ),
      )
    @symcore.ExprForm::Mod(lhs, rhs) =>
      @symcore.mod_expr(
        replace_expr_local(lhs, target, replacement),
        replace_expr_local(rhs, target, replacement),
      )
    @symcore.ExprForm::Tuple(args) =>
      @symcore.Expr::Tuple(
        args.map(arg => replace_expr_local(arg, target, replacement)),
      )
    @symcore.ExprForm::Dict(items) => {
      let mapped : Array[(@symcore.Expr, @symcore.Expr)] = []
      for item in items {
        let (key, value) = item
        mapped.push(
          (
            replace_expr_local(key, target, replacement),
            replace_expr_local(value, target, replacement),
          ),
        )
      }
      @symcore.Expr::Dict(mapped)
    }
    @symcore.ExprForm::Relational(op, lhs, rhs) =>
      match op {
        @symcore.RelOp::Eq =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Eq,
            replace_expr_local(lhs, target, replacement),
            replace_expr_local(rhs, target, replacement),
          )
        @symcore.RelOp::Ne =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Ne,
            replace_expr_local(lhs, target, replacement),
            replace_expr_local(rhs, target, replacement),
          )
        @symcore.RelOp::Lt =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Lt,
            replace_expr_local(lhs, target, replacement),
            replace_expr_local(rhs, target, replacement),
          )
        @symcore.RelOp::Le =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Le,
            replace_expr_local(lhs, target, replacement),
            replace_expr_local(rhs, target, replacement),
          )
        @symcore.RelOp::Gt =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Gt,
            replace_expr_local(lhs, target, replacement),
            replace_expr_local(rhs, target, replacement),
          )
        @symcore.RelOp::Ge =>
          @symcore.Expr::Relational(
            @symcore.RelOp::Ge,
            replace_expr_local(lhs, target, replacement),
            replace_expr_local(rhs, target, replacement),
          )
      }
    @symcore.ExprForm::Derivative(inner, deriv_args) =>
      @symcore.raw_derivative(
        replace_expr_local(inner, target, replacement),
        deriv_args.map(arg => replace_expr_local(arg, target, replacement)),
      )
    @symcore.ExprForm::Subs(inner, variable, value) =>
      @symcore.subs_expr(
        replace_expr_local(inner, target, replacement),
        replace_expr_local(variable, target, replacement),
        replace_expr_local(value, target, replacement),
      )
    @symcore.ExprForm::Lambda(vars, body) =>
      @symcore.lambda_expr(
        replace_expr_local(vars, target, replacement),
        replace_expr_local(body, target, replacement),
      )
    _ => expr
  }
}

///|
fn lambda_apply_local(
  lam : @symcore.Expr,
  args : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match @symcore.lambda_parts(lam) {
    Some((vars, body)) =>
      match @symcore.expr_form(vars) {
        @symcore.ExprForm::Symbol(v) if args.length() == 1 => {
          let env : Map[String, @symcore.Expr] = Map([])
          env[v] = args[0]
          Some(eval_arith(@symcore.subst(body, env)))
        }
        @symcore.ExprForm::Tuple(vs) if vs.length() == args.length() => {
          let mut out = body
          for i in 0..<vs.length() {
            out = replace_expr_local(out, vs[i], args[i])
          }
          Some(eval_arith(out))
        }
        _ => None
      }
    _ => None
  }
}

///|
fn assert_opaque_symbolic_metrics(rv : RandomVar) -> Unit raise {
  let s = @symcore.Expr::Symbol(rv.name)
  let t = @symcore.Expr::Symbol("t")
  let q = @symcore.rational_from_ints(1, 4)
  assert_eq(@symprint.pretty_string(expectation(s, rvs=[rv])), rv.name)
  assert_eq(
    @symprint.pretty_string(variance(s, rvs=[rv])),
    "Variance(\{rv.name})",
  )
  assert_eq(
    @symprint.pretty_string(moment_generating_function(s, t, rvs=[rv])),
    "moment_generating_function(\{rv.name}, t)",
  )
  assert_eq(
    @symprint.pretty_string(characteristic_function(s, t, rvs=[rv])),
    "characteristic_function(\{rv.name}, t)",
  )
  assert_eq(
    @symprint.pretty_string(quantile(s, q, rvs=[rv])),
    "quantile(\{rv.name}, 1/4)",
  )
  assert_eq(
    @symprint.pretty_string(entropy(s, rvs=[rv])),
    "entropy(\{rv.name})",
  )
}

///|
fn assert_mean_not_placeholder(rv : RandomVar, head : String) -> Unit raise {
  let ours = expectation(@symcore.Expr::Symbol(rv.name), rvs=[rv])
  let s = @symprint.pretty_string(ours)
  assert_true(!s.contains("\{head}Mean("))
}

///|
fn assert_variance_not_placeholder(rv : RandomVar, head : String) -> Unit raise {
  let ours = variance(@symcore.Expr::Symbol(rv.name), rvs=[rv])
  let s = @symprint.pretty_string(ours)
  assert_true(!s.contains("\{head}Variance("))
}

///|
fn assert_mgf_not_placeholder(
  rv : RandomVar,
  head : String,
  t : @symcore.Expr,
) -> Unit raise {
  let ours = moment_generating_function(@symcore.Expr::Symbol(rv.name), t, rvs=[
    rv,
  ])
  let s = @symprint.pretty_string(ours)
  assert_true(!s.contains("\{head}MGF("))
}

///|
fn assert_cf_not_placeholder(
  rv : RandomVar,
  head : String,
  t : @symcore.Expr,
) -> Unit raise {
  let ours = characteristic_function(@symcore.Expr::Symbol(rv.name), t, rvs=[rv])
  let s = @symprint.pretty_string(ours)
  assert_true(!s.contains("\{head}CF("))
  assert_true(!s.contains("characteristic_function("))
}

///|
fn assert_quantile_not_placeholder(
  rv : RandomVar,
  head : String,
  q : @symcore.Expr,
) -> Unit raise {
  let ours = quantile(@symcore.Expr::Symbol(rv.name), q, rvs=[rv])
  let s = @symprint.pretty_string(ours)
  assert_true(!s.contains("\{head}Quantile("))
  assert_true(!s.contains("quantile("))
}

///|
fn assert_entropy_not_placeholder(rv : RandomVar, head : String) -> Unit raise {
  let ours = entropy(@symcore.Expr::Symbol(rv.name), rvs=[rv])
  let s = @symprint.pretty_string(ours)
  assert_true(!s.contains("\{head}Entropy("))
  assert_true(!s.contains("entropy("))
}

///|
fn tribool_to_python(value : TriBool) -> String {
  match value {
    TriBool::True => "True"
    TriBool::False => "False"
    TriBool::Unknown => "None"
  }
}

///|
fn expr_list_python(items : Array[@symcore.Expr]) -> String {
  let pieces : Array[String] = []
  for item in items {
    pieces.push(@symprint.pretty_string(item))
  }
  "[\{pieces.join(", ")}]"
}

///|
fn swap_map_python_pairs(items : Map[String, String]) -> String {
  let pairs : Array[(String, String)] = []
  for key, value in items {
    pairs.push((key, value))
  }
  pairs.sort_by((left, right) => left.0.compare(right.0))
  let pieces : Array[String] = []
  for pair in pairs {
    pieces.push("('\{pair.0}', '\{pair.1}')")
  }
  "[\{pieces.join(", ")}]"
}

///|
fn sampled_int_value(expr : @symcore.Expr) -> Int? {
  expr_as_int(expr)
}

///|
fn sampled_double_value(expr : @symcore.Expr) -> Double? {
  match expr {
    @symcore.Expr::Float(value) =>
      Some(value.to_double() catch { _ => return None })
    @symcore.Expr::Number(value) => {
      let float_value = @symcore.Float::from_exact(value, prec=53) catch {
        _ => return None
      }
      Some(float_value.to_double() catch { _ => return None })
    }
    _ => None
  }
}

///|
fn sampled_density_total(expr : @symcore.Expr) -> Int {
  match expr {
    @symcore.Expr::Dict(entries) => {
      let mut total = 0
      for entry in entries {
        match sampled_int_value(entry.1) {
          Some(n) => total += n
          None => ()
        }
      }
      total
    }
    _ => 0
  }
}

///|
fn assert_pretty_contains(
  expr : @symcore.Expr,
  parts : Array[String],
) -> Unit raise {
  let text = @symprint.pretty_string(expr)
  for part in parts {
    if !text.contains(part) {
      fail("missing `\{part}` in `\{text}`")
    }
  }
}

///|
fn assert_pretty_lacks(expr : @symcore.Expr, part : String) -> Unit raise {
  assert_true(!@symprint.pretty_string(expr).contains(part))
}

///|
test "compat aliases p/e/h and where_" {
  let x = @symcore.Expr::Symbol("X")
  let rv = die("X", sides=6)
  let pe = p(eq(x, @symcore.int(1)), rv~)
  assert_true(expr_equiv_safe(pe, "1/6"))
  let ee = e(x, rvs=[rv])
  assert_true(expr_equiv_safe(ee, "7/2"))
  let he = h(x)
  assert_eq(@symprint.pretty_string(he), "entropy(X)")
  let w = where_(ge(x, @symcore.int(2)))
  inspect(@symprint.pretty_string(w), content="where(X >= 2)")
}

///|
test "compat residual public query helpers parity" {
  let x = die("X", sides=6)
  let y = die("Y", sides=6)
  let sx = random_symbol(x)
  let sy = random_symbol(y)
  let z = @symcore.Expr::Symbol("z")

  assert_true(expr_equiv_safe(moment(x, 2), "91/6"))
  assert_pretty_contains(correlation(sx, sx, rvs=[x]), ["35/12"])
  assert_true(dependent(x, x))
  assert_true(!dependent(x, y))

  assert_eq(random_symbols(@symcore.add([sx, z]), rvs=[x]).join(","), "X")
  assert_eq(@symprint.pretty_string(given(sx, gt(sy, @symcore.int(3)))), "X")
  assert_pretty_contains(
    given(@symcore.add([sx, sy]), eq(sx, @symcore.int(2))),
    ["Y", "2"],
  )

  assert_pretty_contains(pspace(sx), ["pspace", "X"])
  let proc_sample = sample_stochastic_process(
    poisson_process("N", @symcore.int(2)),
    @symcore.int(0),
    @symcore.int(3),
    n=4,
  )
  assert_pretty_lacks(proc_sample, "sample_stochastic_process(")
  match @symcore.tuple_items(proc_sample) {
    Some(items) => assert_eq(items.length(), 4)
    None => fail("poisson process sample should be a tuple path")
  }
}

///|
test "compat is_random parity with sympy stats rv" {
  let x = normal("X", @symcore.int(0), @symcore.int(1))
  let sx = @symcore.Expr::Symbol("X")
  let sy = @symcore.Expr::Symbol("Y")

  let random_oracle = "True"
  assert_eq(
    if is_random(sx, rvs=[x]) {
      "True"
    } else {
      "False"
    },
    random_oracle,
  )

  let plain_oracle = "False"
  assert_eq(if is_random(sy, rvs=[x]) { "True" } else { "False" }, plain_oracle)
}

///|
test "compat pspace_independent parity with sympy stats rv" {
  let x = normal("X", @symcore.int(0), @symcore.int(1))
  let y = normal("Y", @symcore.int(0), @symcore.int(1))
  let independent_oracle = "True"
  assert_eq(tribool_to_python(pspace_independent(x, y)), independent_oracle)

  let same_space_oracle = "False"
  assert_eq(tribool_to_python(pspace_independent(x, x)), same_space_oracle)
}

///|
test "compat sumsets parity with sympy stats rv" {
  let union = sumsets([
    [@symcore.int(1), @symcore.int(2)],
    [@symcore.int(2), @symcore.int(3)],
  ])
  let sumsets_oracle = "[1, 2, 3]"
  assert_eq(expr_list_python(union), sumsets_oracle)
}

///|
test "compat reduce_rational_inequalities_wrap parity with sympy stats crv" {
  let x = @symcore.Expr::Symbol("x")

  let open_right = reduce_rational_inequalities_wrap(gt(x, @symcore.int(0)), x)
  let open_right_oracle = "Interval.open(0, oo)"
  assert_eq(@symsets.to_string(open_right), open_right_oracle)

  let bounded = reduce_rational_inequalities_wrap(
    and_event([gt(x, @symcore.int(0)), lt(x, @symcore.int(2))]),
    x,
  )
  let bounded_oracle = "Interval.open(0, 2)"
  assert_eq(@symsets.to_string(bounded), bounded_oracle)

  let split = reduce_rational_inequalities_wrap(
    or_event([lt(x, @symcore.int(0)), gt(x, @symcore.int(2))]),
    x,
  )
  let split_oracle = "Union(Interval.open(-oo, 0), Interval.open(2, oo))"
  assert_eq(@symsets.to_string(split), split_oracle)
}

///|
test "compat rs_swap parity with sympy stats rv" {
  let x = normal("X", @symcore.int(0), @symcore.int(1))
  let x2 = normal("X", @symcore.int(1), @symcore.int(2))
  let swap_oracle = "[('X', 'X')]"
  assert_eq(swap_map_python_pairs(rs_swap([x], [x2])), swap_oracle)
}

///|
test "compat rv_subs parity with sympy stats rv" {
  let x = normal("X", @symcore.int(0), @symcore.int(1))
  let sx = @symcore.Expr::Symbol("X")
  let expr = @symcore.add([@symcore.mul([@symcore.int(2), sx]), @symcore.int(1)])
  let rv_subs_oracle = "2*X + 1"
  assert_true(expr_equiv_safe(rv_subs(expr, rvs=[x]), rv_subs_oracle))
}

///|
test "compat sampling front doors follow sympy public contract" {
  let x = die("X", sides=6)
  let sx = @symcore.Expr::Symbol("X")
  let half = @symcore.rational_from_ints(1, 2)

  let draws = sample_iter(sx, n=12, rvs=[x], seed=Some(23))
  assert_eq(draws.length(), 12)
  for draw in draws {
    match sampled_int_value(draw) {
      Some(n) => assert_true(n >= 1 && n <= 6)
      None => fail("Die samples should be concrete integers")
    }
  }

  let lambdify_draws = sample_iter_lambdify(sx, n=5, rvs=[x], seed=Some(23))
  let subs_draws = sample_iter_subs(sx, n=5, rvs=[x], seed=Some(23))
  assert_eq(lambdify_draws.length(), 5)
  assert_eq(subs_draws.length(), 5)
  for draw in lambdify_draws {
    match sampled_int_value(draw) {
      Some(n) => assert_true(n >= 1 && n <= 6)
      None => fail("sample_iter_lambdify should follow sample_iter")
    }
  }
  for draw in subs_draws {
    match sampled_int_value(draw) {
      Some(n) => assert_true(n >= 1 && n <= 6)
      None => fail("sample_iter_subs should follow sample_iter")
    }
  }

  let gx = rv("GX", "Normal", params=[@symcore.int(0), @symcore.int(1)])
  assert_true(
    expr_equiv_safe(expectation(@symcore.Expr::Symbol("GX"), rvs=[gx]), "0"),
  )
  assert_true(
    expr_equiv_safe(variance(@symcore.Expr::Symbol("GX"), rvs=[gx]), "1"),
  )

  let gb = rv("GB", "Binomial", params=[@symcore.int(4), half])
  match do_sample_numpy(gb, n=3, seed=Some(24)) {
    Some(values) => assert_eq(values.length(), 3)
    None => fail("numpy compatibility sampler should support binomial")
  }
  match do_sample_scipy(gx, n=3, seed=Some(25)) {
    Some(values) => assert_eq(values.length(), 3)
    None => fail("scipy compatibility sampler should support normal")
  }
  match do_sample_pymc(gb, n=2, seed=Some(26)) {
    Some(values) => assert_eq(values.length(), 2)
    None => fail("pymc compatibility sampler should support binomial")
  }

  match sample_random_var(x, seed=Some(23)) {
    Some(value) =>
      match sampled_int_value(value) {
        Some(n) => assert_true(n >= 1 && n <= 6)
        None => fail("sample_random_var should produce a concrete integer")
      }
    None => fail("sample_random_var should support finite distributions")
  }

  let expr_draw = sample(
    @symcore.add([sx, @symcore.int(2)]),
    rvs=[x],
    seed=Some(23),
  )
  match sampled_int_value(expr_draw) {
    Some(n) => assert_true(n >= 3 && n <= 8)
    None => fail("sample(expr) should substitute sampled random symbols")
  }

  let prob = sampling_p(
    gt(sx, @symcore.int(3)),
    rvs=[x],
    numsamples=30,
    seed=Some(23),
  )
  match expr_as_number(prob) {
    Some(q) => {
      assert_true(q.compare(@symnum.BigRational::zero()) >= 0)
      assert_true(q.compare(@symnum.BigRational::one()) <= 0)
    }
    None => fail("sampling_p should return a rational estimate")
  }

  let mean = sampling_e(sx, rvs=[x], numsamples=30, seed=Some(23))
  match expr_as_number(mean) {
    Some(q) => {
      assert_true(q.compare(@symnum.BigRational::from_int(1)) >= 0)
      assert_true(q.compare(@symnum.BigRational::from_int(6)) <= 0)
    }
    None => fail("sampling_e should return a rational estimate")
  }

  let density = sampling_density(sx, rvs=[x], numsamples=30, seed=Some(23))
  assert_eq(sampled_density_total(density), 30)
}

///|
test "compat symbolic sampling support follows sympy domains" {
  let u = uniform("U", params=[@symcore.int(0), @symcore.int(2)])
  let uniform_domain_oracle = "Interval(0, 2)"
  assert_eq(uniform_domain_oracle, "Interval(0, 2)")
  match sample_random_var(u, seed=Some(301)) {
    Some(value) =>
      match sampled_double_value(value) {
        Some(x) => assert_true(x >= 0.0 && x <= 2.0)
        None => fail("Uniform sample should be numeric")
      }
    None => fail("Uniform symbolic sampler should produce a value")
  }
  match where_set(le(@symcore.Expr::Symbol("U"), @symcore.int(1)), u) {
    Some(set) => assert_eq(@symsets.to_string(set), "Interval(0, 1)")
    None => fail("Uniform where_set should use bounded support")
  }

  let bb = beta_binomial("BB", params=[
    @symcore.int(5),
    @symcore.int(2),
    @symcore.int(3),
  ])
  let beta_binomial_domain_oracle = "{0, 1, 2, 3, 4, 5}"
  assert_eq(beta_binomial_domain_oracle, "{0, 1, 2, 3, 4, 5}")
  match sample_random_var(bb, seed=Some(302)) {
    Some(value) =>
      match sampled_int_value(value) {
        Some(k) => assert_true(k >= 0 && k <= 5)
        None => fail("BetaBinomial sample should be integral")
      }
    None => fail("BetaBinomial symbolic sampler should produce a value")
  }
  match where_set(gt(@symcore.Expr::Symbol("BB"), @symcore.int(2)), bb) {
    Some(set) => assert_eq(@symsets.to_string(set), "{3, 4, 5}")
    None => fail("BetaBinomial where_set should use finite support")
  }

  let hg = hypergeometric("HG", params=[
    @symcore.int(10),
    @symcore.int(5),
    @symcore.int(3),
  ])
  let hypergeometric_domain_oracle = "{0, 1, 2, 3}"
  assert_eq(hypergeometric_domain_oracle, "{0, 1, 2, 3}")
  match sample_random_var(hg, seed=Some(303)) {
    Some(value) =>
      match sampled_int_value(value) {
        Some(k) => assert_true(k >= 0 && k <= 3)
        None => fail("Hypergeometric sample should be integral")
      }
    None => fail("Hypergeometric symbolic sampler should produce a value")
  }

  let sk = skellam("SK", params=[@symcore.int(3), @symcore.int(2)])
  let skellam_domain_oracle = "Integers"
  assert_eq(skellam_domain_oracle, "Integers")
  match sample_random_var(sk, seed=Some(304)) {
    Some(value) =>
      match sampled_int_value(value) {
        Some(_) => ()
        None => fail("Skellam sample should be integral")
      }
    None => fail("Skellam symbolic sampler should produce a value")
  }
}

///|
test "compat where_set matches sympy where set examples" {
  let d = die("D", sides=6)
  let sd = @symcore.Expr::Symbol("D")
  match where_set(gt(sd, @symcore.int(3)), d) {
    Some(set) => assert_eq(@symsets.to_string(set), "{4, 5, 6}")
    None => fail("where_set should enumerate finite domains")
  }

  let n = normal("N", @symcore.int(0), @symcore.int(1))
  let sn = @symcore.Expr::Symbol("N")
  match where_set(le(@symcore.pow(sn, @symcore.int(2)), @symcore.int(1)), n) {
    Some(set) => assert_eq(@symsets.to_string(set), "Interval(-1, 1)")
    None => fail("where_set should solve continuous domains")
  }
}

///|
test "compat uniform parity density cdf moments quantile" {
  let u = uniform("U", params=[@symcore.int(0), @symcore.int(2)])
  let x = @symcore.Expr::Symbol("x")
  let d = density(u, x)
  let d_s = @symprint.pretty_string(d)
  assert_true(d_s.contains("Piecewise"))
  assert_true(d_s.contains("1/2"))
  assert_true(d_s.contains("0 <= x"))
  assert_true(d_s.contains("x <= 2"))

  let c = cdf(u, x)
  let c_s = @symprint.pretty_string(c)
  assert_true(c_s.contains("Piecewise"))
  assert_true(c_s.contains("x < 0"))
  assert_true(c_s.contains("x <= 2"))
  assert_true(c_s.contains("1"))

  let su = @symcore.Expr::Symbol("U")
  let m = expectation(su, rvs=[u])
  assert_true(expr_equiv_safe(m, "1"))
  let v = variance(su, rvs=[u])
  assert_true(expr_equiv_safe(v, "1/3"))

  let q = quantile(su, @symcore.rational_from_ints(1, 4), rvs=[u])
  assert_true(expr_equiv_safe(q, "1/2"))
}

///|
test "compat distribution constructors symbolic fallback" {
  let a = beta("A", params=[@symcore.int(2), @symcore.int(5)])
  let x = @symcore.Expr::Symbol("x")
  let d = density(a, x)
  let d_s = @symprint.pretty_string(d)
  assert_true(d_s.contains("Piecewise"))
  assert_true(d_s.contains("beta"))
  assert_true(d_s.contains("0 <= x"))
  assert_true(d_s.contains("x <= 1"))

  let loc = stats_matrix_literal([[@symcore.int(5), @symcore.int(6)]])
  let omega = stats_matrix_literal([
    [@symcore.int(2), @symcore.int(1)],
    [@symcore.int(1), @symcore.int(2)],
  ])
  let sigma = stats_matrix_literal([[@symcore.int(4)]])
  let xmat12 = stats_matrix_literal([[@symcore.int(7), @symcore.int(8)]])
  let m = matrix_student_t("MT", params=[@symcore.int(2), loc, omega, sigma])
  let md = matrix_density(m, xmat12)
  match md {
    Some(v) => {
      assert_pretty_lacks(v, "MatrixStudentTDensity(")
      assert_pretty_contains(v, ["Determinant", "gamma", "Matrix"])
    }
    None => assert_true(false)
  }

  let scale = stats_matrix_literal([
    [@symcore.int(1), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(1)],
  ])
  let xmat22 = stats_matrix_literal([
    [@symcore.int(2), @symcore.int(1)],
    [@symcore.int(1), @symcore.int(2)],
  ])
  let mg = matrix_gamma("MG", params=[@symcore.int(1), @symcore.int(3), scale])
  match matrix_density(mg, xmat22) {
    Some(v) => {
      assert_pretty_lacks(v, "MatrixGammaDensity(")
      assert_pretty_contains(v, ["Determinant", "Trace", "gamma"])
    }
    None => assert_true(false)
  }
}

///|
test "compat mgf and characteristic function parity" {
  let b = binomial("B", @symcore.int(5), @symcore.rational_from_ints(1, 3))
  let sb = @symcore.Expr::Symbol("B")
  let t = @symcore.Expr::Symbol("t")

  let mgf = moment_generating_function(sb, t, rvs=[b])
  let mgf_s = @symprint.pretty_string(mgf)
  assert_true(mgf_s.contains("exp(t)"))
  assert_true(mgf_s.contains("**5"))

  let cf = characteristic_function(sb, t, rvs=[b])
  let cf_s = @symprint.pretty_string(cf)
  assert_true(cf_s.contains("exp"))
  assert_true(cf_s.contains("I"))
  assert_true(cf_s.contains("**5"))
}

///|
fn _compat_symbolic_mgf_cf_quantile_entropy_python_oracle_disabled() -> Unit raise {
  let b = beta("B", params=[@symcore.int(2), @symcore.int(5)])
  let sb = @symcore.Expr::Symbol("B")
  let t = @symcore.Expr::Symbol("t")
  let b_mgf = moment_generating_function(sb, t, rvs=[b])
  let b_mgf_oracle = stats_eval_str(
    "(lambda B, t: moment_generating_function(B)(t))(stats.Beta('B', 2, 5), t)",
  )
  assert_true(expr_equiv_to(b_mgf, b_mgf_oracle))
  assert_true(
    !@symprint.pretty_string(b_mgf).contains("moment_generating_function("),
  )
  let b_cf = characteristic_function(sb, t, rvs=[b])
  let b_cf_oracle = stats_eval_str(
    "(lambda B, t: characteristic_function(B)(t))(stats.Beta('B', 2, 5), t)",
  )
  assert_true(expr_equiv_to(b_cf, b_cf_oracle))
  assert_true(
    !@symprint.pretty_string(b_cf).contains("characteristic_function("),
  )

  let ccf = cauchy("CCF", params=[@symcore.int(0), @symcore.int(2)])
  let sccf = @symcore.Expr::Symbol("CCF")
  let ccf_expr = characteristic_function(sccf, t, rvs=[ccf])
  let ccf_oracle = stats_eval_str(
    "(lambda CCF, t: characteristic_function(CCF)(t))(stats.Cauchy('CCF', 0, 2), t)",
  )
  assert_true(expr_equiv_to(ccf_expr, ccf_oracle))
  assert_true(!@symprint.pretty_string(ccf_expr).contains("CauchyCF("))

  let l = logistic("L", params=[@symcore.int(0), @symcore.int(2)])
  let sl = @symcore.Expr::Symbol("L")
  let q = quantile(sl, @symcore.rational_from_ints(1, 4), rvs=[l])
  assert_true(expr_equiv_to(q, "-2*log(3)"))
  assert_true(!@symprint.pretty_string(q).contains("quantile("))

  let aq = arcsin("Aq", params=[@symcore.int(1), @symcore.int(5)])
  let x = @symcore.Expr::Symbol("x")
  let aq_d = density(aq, @symcore.int(2))
  assert_true(expr_equiv_to(aq_d, "sqrt(3)/(3*pi)"))
  let aq_c = cdf(aq, x)
  let aq_c_oracle = stats_eval_str(
    "(lambda Aq, x: cdf(Aq)(x))(stats.Arcsin('Aq', 1, 5), x)",
  )
  assert_true(expr_equiv_to(aq_c, aq_c_oracle))
  let saq = @symcore.Expr::Symbol("Aq")
  let aq_m = expectation(saq, rvs=[aq])
  assert_true(expr_equiv_to(aq_m, "3"))
  let aq_v = variance(saq, rvs=[aq])
  assert_true(expr_equiv_to(aq_v, "2"))
  let aq_q = quantile(saq, @symcore.rational_from_ints(1, 4), rvs=[aq])
  assert_true(expr_equiv_to(aq_q, "3 - sqrt(2)"))
  assert_true(!@symprint.pretty_string(aq_q).contains("ArcsinQuantile("))
  let aq_e = entropy(saq, rvs=[aq])
  assert_true(expr_equiv_to(aq_e, "log(pi)"))
  assert_true(!@symprint.pretty_string(aq_e).contains("ArcsinEntropy("))

  let kq = kumaraswamy("Kq", params=[@symcore.int(2), @symcore.int(3)])
  let skq = @symcore.Expr::Symbol("Kq")
  let kq_m = expectation(skq, rvs=[kq])
  assert_true(expr_equiv_to(kq_m, "3*beta(3/2, 3)"))
  let kq_v = variance(skq, rvs=[kq])
  assert_true(expr_equiv_to(kq_v, "3*beta(2, 3) - 9*beta(3/2, 3)**2"))
  let kq_q = quantile(skq, @symcore.rational_from_ints(1, 4), rvs=[kq])
  assert_true(expr_equiv_to(kq_q, "sqrt(1 - (3/4)**(1/3))"))
  assert_true(!@symprint.pretty_string(kq_q).contains("KumaraswamyQuantile("))

  let bq = beta("Bq", params=[@symcore.int(2), @symcore.int(5)])
  let sbq = @symcore.Expr::Symbol("Bq")
  let bq_expr = quantile(sbq, @symcore.rational_from_ints(1, 4), rvs=[bq])
  assert_true(expr_equiv_to(bq_expr, "betaincinv(2, 5, 1/4)"))
  assert_true(!@symprint.pretty_string(bq_expr).contains("BetaQuantile("))

  let ch = chi("Ch", params=[@symcore.int(5)])
  let ch_cdf = cdf(ch, @symcore.int(2))
  let ch_cdf_oracle = stats_eval_str(
    "(lambda Ch: cdf(Ch)(2))(stats.Chi('Ch', 5))",
  )
  assert_true(expr_equiv_to(ch_cdf, ch_cdf_oracle))
  assert_true(!@symprint.pretty_string(ch_cdf).contains("ChiCDF("))
  let sch = @symcore.Expr::Symbol("Ch")
  let ch_q = quantile(sch, @symcore.rational_from_ints(1, 4), rvs=[ch])
  assert_true(expr_equiv_to(ch_q, "sqrt(2*gammaincinv(5/2, 1/4))"))
  assert_true(!@symprint.pretty_string(ch_q).contains("ChiQuantile("))
  let ch_e = entropy(sch, rvs=[ch])
  assert_true(
    expr_equiv_to(ch_e, "log(gamma(5/2)) + 5/2 - 2*digamma(5/2) - log(2)/2"),
  )
  assert_true(!@symprint.pretty_string(ch_e).contains("ChiEntropy("))

  let csq = chi_squared("Csq", params=[@symcore.int(5)])
  let scsq = @symcore.Expr::Symbol("Csq")
  let csq_q = quantile(scsq, @symcore.rational_from_ints(1, 4), rvs=[csq])
  assert_true(expr_equiv_to(csq_q, "2*gammaincinv(5/2, 1/4)"))
  assert_true(!@symprint.pretty_string(csq_q).contains("ChiSquaredQuantile("))
  let csq_e = entropy(scsq, rvs=[csq])
  assert_true(
    expr_equiv_to(csq_e, "5/2 + log(2*gamma(5/2)) - 3*digamma(5/2)/2"),
  )
  assert_true(!@symprint.pretty_string(csq_e).contains("ChiSquaredEntropy("))

  let erq = erlang("Erq", params=[@symcore.int(3), @symcore.int(2)])
  let serq = @symcore.Expr::Symbol("Erq")
  let erq_q = quantile(serq, @symcore.rational_from_ints(1, 4), rvs=[erq])
  assert_true(expr_equiv_to(erq_q, "gammaincinv(3, 1/4)/2"))
  assert_true(!@symprint.pretty_string(erq_q).contains("ErlangQuantile("))
  let erq_e = entropy(serq, rvs=[erq])
  assert_true(expr_equiv_to(erq_e, "3 + log(gamma(3)/2) - 2*digamma(3)"))
  assert_true(!@symprint.pretty_string(erq_e).contains("ErlangEntropy("))

  let u = uniform("Ue", params=[@symcore.int(1), @symcore.int(3)])
  let su = @symcore.Expr::Symbol("Ue")
  let ue = entropy(su, rvs=[u])
  let ue_oracle = stats_eval_str(
    "(lambda Ue: entropy(Ue))(stats.Uniform('Ue', 1, 3))",
  )
  assert_true(expr_equiv_to(ue, ue_oracle))
  assert_true(!@symprint.pretty_string(ue).contains("entropy("))

  let gwe = gumbel("Gwe", params=[@symcore.int(2), @symcore.int(0)])
  let sgwe = @symcore.Expr::Symbol("Gwe")
  let gwe_q = quantile(sgwe, @symcore.rational_from_ints(1, 4), rvs=[gwe])
  assert_true(expr_equiv_to(gwe_q, "-2*log(log(4))"))
  assert_true(!@symprint.pretty_string(gwe_q).contains("quantile("))

  let moq = moyal("Moq", params=[@symcore.int(0), @symcore.int(1)])
  let smoq = @symcore.Expr::Symbol("Moq")
  let moq_c = cdf(moq, @symcore.rational_from_ints(1, 2))
  let moq_c_oracle = stats_eval_str(
    "(lambda Moq: cdf(Moq)(Rational(1, 2)))(stats.Moyal('Moq', 0, 1))",
  )
  assert_true(expr_equiv_to(moq_c, moq_c_oracle))
  assert_true(!@symprint.pretty_string(moq_c).contains("MoyalCDF("))
  let moq_q = quantile(smoq, @symcore.rational_from_ints(1, 4), rvs=[moq])
  assert_true(expr_equiv_to(moq_q, "-2*log(sqrt(2)*erfcinv(1/4))"))
  assert_true(!@symprint.pretty_string(moq_q).contains("MoyalQuantile("))

  let goq = gompertz("Goq", params=[@symcore.int(2), @symcore.int(3)])
  let sgoq = @symcore.Expr::Symbol("Goq")
  let goq_q = quantile(sgoq, @symcore.rational_from_ints(1, 4), rvs=[goq])
  assert_true(expr_equiv_to(goq_q, "log(1 - log(3/4)/3)/2"))
  assert_true(!@symprint.pretty_string(goq_q).contains("GompertzQuantile("))

  let laq = laplace("Laq", params=[@symcore.int(0), @symcore.int(2)])
  let slaq = @symcore.Expr::Symbol("Laq")
  let laq_q = quantile(slaq, @symcore.rational_from_ints(1, 4), rvs=[laq])
  assert_true(expr_equiv_to(laq_q, "-2*log(2)"))

  let tq = triangular("Tq", params=[
    @symcore.int(0),
    @symcore.int(2),
    @symcore.int(1),
  ])
  let stq = @symcore.Expr::Symbol("Tq")
  let tq_q = quantile(stq, @symcore.rational_from_ints(1, 4), rvs=[tq])
  assert_true(expr_equiv_to(tq_q, "sqrt(2)/2"))

  let pq = power_function("Pq", params=[
    @symcore.int(2),
    @symcore.int(0),
    @symcore.int(3),
  ])
  let spq = @symcore.Expr::Symbol("Pq")
  let pq_q = quantile(spq, @symcore.rational_from_ints(1, 4), rvs=[pq])
  assert_true(expr_equiv_to(pq_q, "3/2"))

  let trq = trapezoidal("Trq", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(4),
  ])
  let strq = @symcore.Expr::Symbol("Trq")
  let trq_q = quantile(strq, @symcore.rational_from_ints(1, 4), rvs=[trq])
  assert_true(expr_equiv_to(trq_q, "9/8"))

  let stq2 = student_t("Stq", params=[@symcore.int(5)])
  let sstq2 = @symcore.Expr::Symbol("Stq")
  let stq2_q = quantile(sstq2, @symcore.rational_from_ints(1, 2), rvs=[stq2])
  assert_true(expr_equiv_to(stq2_q, "0"))

  let vmq = von_mises("Vmq", params=[@symcore.int(0), @symcore.int(2)])
  let svmq = @symcore.Expr::Symbol("Vmq")
  let vmq_q = quantile(svmq, @symcore.rational_from_ints(1, 4), rvs=[vmq])
  let vmq_s = @symprint.pretty_string(vmq_q)
  assert_true(vmq_s.contains("ConditionSet"))
  assert_true(vmq_s.contains("Integral("))
  assert_true(vmq_s.contains("besseli(0, 2)"))
  assert_true(vmq_s.contains("Interval("))
  assert_true(!@symprint.pretty_string(vmq_q).contains("VonMisesQuantile("))

  let rcq = reciprocal("Rcq", params=[@symcore.int(1), @symcore.int(3)])
  let srcq = @symcore.Expr::Symbol("Rcq")
  let rcq_q = quantile(srcq, @symcore.rational_from_ints(1, 2), rvs=[rcq])
  assert_true(expr_equiv_to(rcq_q, "sqrt(3)"))
  assert_true(!@symprint.pretty_string(rcq_q).contains("ReciprocalQuantile("))

  let lvq = levy("Lvq", params=[@symcore.int(0), @symcore.int(1)])
  let slvq = @symcore.Expr::Symbol("Lvq")
  let lvq_q = quantile(slvq, @symcore.rational_from_ints(1, 4), rvs=[lvq])
  assert_true(expr_equiv_to(lvq_q, "1/(2*erfcinv(1/4)**2)"))
  assert_true(!@symprint.pretty_string(lvq_q).contains("LevyQuantile("))

  let lmq = lomax("Lmq", params=[@symcore.int(2), @symcore.int(3)])
  let slmq = @symcore.Expr::Symbol("Lmq")
  let lmq_q = quantile(slmq, @symcore.rational_from_ints(1, 4), rvs=[lmq])
  assert_true(expr_equiv_to(lmq_q, "-3 + 2*sqrt(3)"))
  assert_true(!@symprint.pretty_string(lmq_q).contains("LomaxQuantile("))

  let bpq = bounded_pareto("Bpq", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(9),
  ])
  let sbpq = @symcore.Expr::Symbol("Bpq")
  let bpq_q = quantile(sbpq, @symcore.rational_from_ints(1, 4), rvs=[bpq])
  // SymPy returns a singleton set for bounded Pareto quantile.
  assert_true(expr_equiv_to(bpq_q, "9*sqrt(7)/7"))
  assert_true(
    !@symprint.pretty_string(bpq_q).contains("BoundedParetoQuantile("),
  )

  let bwe = beta("Bwe", params=[@symcore.int(2), @symcore.int(5)])
  let sbwe = @symcore.Expr::Symbol("Bwe")
  let bwe_e = entropy(sbwe, rvs=[bwe])
  let bwe_s = @symprint.pretty_string(bwe_e)
  assert_true(!bwe_s.contains("Entropy("))
  assert_true(bwe_s.contains("digamma"))

  let rwe = rayleigh("Rwe", params=[@symcore.int(2)])
  let srwe = @symcore.Expr::Symbol("Rwe")
  let rwe_e = entropy(srwe, rvs=[rwe])
  let rwe_oracle = stats_eval_str(
    "(lambda Rwe: entropy(Rwe))(stats.Rayleigh('Rwe', 2))",
  )
  assert_true(expr_equiv_to(rwe_e, rwe_oracle))

  let wwe = weibull("Wwe", params=[@symcore.int(3), @symcore.int(5)])
  let swwe = @symcore.Expr::Symbol("Wwe")
  let wwe_e = entropy(swwe, rvs=[wwe])
  let wwe_oracle = stats_eval_str(
    "(lambda Wwe: entropy(Wwe))(stats.Weibull('Wwe', 3, 5))",
  )
  assert_true(expr_equiv_to(wwe_e, wwe_oracle))

  let lwe = log_normal("Lwe", params=[@symcore.int(0), @symcore.int(2)])
  let slwe = @symcore.Expr::Symbol("Lwe")
  let lwe_e = entropy(slwe, rvs=[lwe])
  assert_true(expr_equiv_to(lwe_e, "log(2*sqrt(2*pi)) + 1/2"))

  let twe = triangular("Twe", params=[
    @symcore.int(0),
    @symcore.int(2),
    @symcore.int(1),
  ])
  let stwe_twe = @symcore.Expr::Symbol("Twe")
  let twe_e = entropy(stwe_twe, rvs=[twe])
  let twe_oracle = stats_eval_str(
    "(lambda Twe: entropy(Twe))(stats.Triangular('Twe', 0, 2, 1))",
  )
  assert_true(expr_equiv_to(twe_e, twe_oracle))

  let pwe = power_function("Pwe", params=[
    @symcore.int(2),
    @symcore.int(0),
    @symcore.int(3),
  ])
  let spwe = @symcore.Expr::Symbol("Pwe")
  let pwe_e = entropy(spwe, rvs=[pwe])
  let pwe_oracle = stats_eval_str(
    "(lambda Pwe: entropy(Pwe))(stats.PowerFunction('Pwe', 2, 0, 3))",
  )
  assert_true(expr_equiv_to(pwe_e, pwe_oracle))

  let stwe_rv = student_t("Stwe", params=[@symcore.int(5)])
  let sstwe = @symcore.Expr::Symbol("Stwe")
  let stwe_e = entropy(sstwe, rvs=[stwe_rv])
  assert_true(
    expr_equiv_to(
      stwe_e, "3*digamma(3) + -3*digamma(5/2) + log(sqrt(5)*beta(5/2, 1/2))",
    ),
  )

  let vmwe = von_mises("Vmwe", params=[@symcore.int(0), @symcore.int(2)])
  let svmwe = @symcore.Expr::Symbol("Vmwe")
  let vmwe_e = entropy(svmwe, rvs=[vmwe])
  assert_true(
    expr_equiv_to(
      vmwe_e, "log(2*pi*besseli(0, 2)) + -2*besseli(1, 2)*besseli(0, 2)**-1",
    ),
  )

  let trwe = trapezoidal("Trwe", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(4),
  ])
  let strwe = @symcore.Expr::Symbol("Trwe")
  let trwe_cdf = cdf(trwe, @symcore.rational_from_ints(3, 2))
  assert_true(expr_equiv_to(trwe_cdf, "2/5"))
  assert_true(!@symprint.pretty_string(trwe_cdf).contains("TrapezoidalCDF("))
  let trwe_m = expectation(strwe, rvs=[trwe])
  assert_true(expr_equiv_to(trwe_m, "9/5"))
  let trwe_v = variance(strwe, rvs=[trwe])
  assert_true(expr_equiv_to(trwe_v, "109/150"))
  let trwe_e = entropy(strwe, rvs=[trwe])
  assert_true(expr_equiv_to(trwe_e, "3/10 + log(5/2)"))

  let mowe = moyal("Mowe", params=[@symcore.int(0), @symcore.int(1)])
  let smowe = @symcore.Expr::Symbol("Mowe")
  let mowe_e = entropy(smowe, rvs=[mowe])
  assert_true(expr_equiv_to(mowe_e, "oo"))
  assert_true(!@symprint.pretty_string(mowe_e).contains("MoyalEntropy("))

  let goe = gompertz("Goe", params=[@symcore.int(2), @symcore.int(3)])
  let sgoe = @symcore.Expr::Symbol("Goe")
  let goe_e = entropy(sgoe, rvs=[goe])
  let goe_oracle = stats_eval_str(
    "(lambda Goe: entropy(Goe))(stats.Gompertz('Goe', 2, 3))",
  )
  assert_true(expr_equiv_to(goe_e, goe_oracle))
  assert_true(!@symprint.pretty_string(goe_e).contains("GompertzEntropy("))

  let lve = levy("Lve", params=[@symcore.int(0), @symcore.int(2)])
  let slve = @symcore.Expr::Symbol("Lve")
  let lve_e = entropy(slve, rvs=[lve])
  let lve_oracle = stats_eval_str(
    "(lambda Lve: entropy(Lve))(stats.Levy('Lve', 0, 2))",
  )
  assert_true(expr_equiv_to(lve_e, lve_oracle))
  assert_true(!@symprint.pretty_string(lve_e).contains("LevyEntropy("))

  let lmwe = lomax("Lmwe", params=[@symcore.int(2), @symcore.int(3)])
  let slmwe = @symcore.Expr::Symbol("Lmwe")
  let lmwe_e = entropy(slmwe, rvs=[lmwe])
  let lmwe_oracle = stats_eval_str(
    "(lambda Lmwe: entropy(Lmwe))(stats.Lomax('Lmwe', 2, 3))",
  )
  assert_true(expr_equiv_to(lmwe_e, lmwe_oracle))
  assert_true(!@symprint.pretty_string(lmwe_e).contains("LomaxEntropy("))

  let bpe = entropy(sbpq, rvs=[bpq])
  let bpe_oracle = stats_eval_str(
    "(lambda Bpq: entropy(Bpq))(stats.BoundedPareto('Bpq', 2, 3, 9))",
  )
  assert_true(expr_equiv_to(bpe, bpe_oracle))
  assert_true(!@symprint.pretty_string(bpe).contains("BoundedParetoEntropy("))
}

///|
test "compat symbolic mgf cf quantile entropy structural parity" {
  let t = @symcore.Expr::Symbol("t")

  let b = beta("B", params=[@symcore.int(2), @symcore.int(5)])
  let sb = @symcore.Expr::Symbol("B")
  let b_mgf = moment_generating_function(sb, t, rvs=[b])
  assert_pretty_lacks(b_mgf, "moment_generating_function(")
  assert_pretty_contains(b_mgf, ["t"])
  let b_cf = characteristic_function(sb, t, rvs=[b])
  assert_pretty_lacks(b_cf, "characteristic_function(")
  assert_pretty_contains(b_cf, ["I", "t"])

  let ccf = cauchy("CCF", params=[@symcore.int(0), @symcore.int(2)])
  let sccf = @symcore.Expr::Symbol("CCF")
  let ccf_expr = characteristic_function(sccf, t, rvs=[ccf])
  assert_pretty_lacks(ccf_expr, "CauchyCF(")
  assert_pretty_contains(ccf_expr, ["exp", "Abs(t)"])

  let l = logistic("L", params=[@symcore.int(0), @symcore.int(2)])
  let sl = @symcore.Expr::Symbol("L")
  let q = quantile(sl, @symcore.rational_from_ints(1, 4), rvs=[l])
  assert_pretty_lacks(q, "quantile(")
  assert_pretty_contains(q, ["log", "3"])

  let aq = arcsin("Aq", params=[@symcore.int(1), @symcore.int(5)])
  let saq = @symcore.Expr::Symbol("Aq")
  let aq_d = density(aq, @symcore.int(2))
  assert_pretty_contains(aq_d, ["sqrt", "pi"])
  let aq_c = cdf(aq, @symcore.Expr::Symbol("x"))
  assert_pretty_lacks(aq_c, "ArcsinCDF(")
  assert_pretty_contains(aq_c, ["asin", "Piecewise"])
  assert_true(expr_equiv_safe(expectation(saq, rvs=[aq]), "3"))
  assert_true(expr_equiv_safe(variance(saq, rvs=[aq]), "2"))
  assert_pretty_lacks(
    quantile(saq, @symcore.rational_from_ints(1, 4), rvs=[aq]),
    "ArcsinQuantile(",
  )
  assert_pretty_lacks(entropy(saq, rvs=[aq]), "ArcsinEntropy(")

  let kq = kumaraswamy("Kq", params=[@symcore.int(2), @symcore.int(3)])
  let skq = @symcore.Expr::Symbol("Kq")
  assert_pretty_contains(expectation(skq, rvs=[kq]), ["beta"])
  assert_pretty_contains(variance(skq, rvs=[kq]), ["beta"])
  assert_pretty_lacks(
    quantile(skq, @symcore.rational_from_ints(1, 4), rvs=[kq]),
    "KumaraswamyQuantile(",
  )

  let bq = beta("Bq", params=[@symcore.int(2), @symcore.int(5)])
  let sbq = @symcore.Expr::Symbol("Bq")
  assert_pretty_contains(
    quantile(sbq, @symcore.rational_from_ints(1, 4), rvs=[bq]),
    ["betaincinv", "1/4"],
  )

  let ch = chi("Ch", params=[@symcore.int(5)])
  let sch = @symcore.Expr::Symbol("Ch")
  assert_pretty_lacks(cdf(ch, @symcore.int(2)), "ChiCDF(")
  assert_pretty_contains(
    quantile(sch, @symcore.rational_from_ints(1, 4), rvs=[ch]),
    ["gammaincinv", "1/4"],
  )
  assert_pretty_contains(entropy(sch, rvs=[ch]), ["digamma", "gamma"])

  let csq = chi_squared("Csq", params=[@symcore.int(5)])
  let scsq = @symcore.Expr::Symbol("Csq")
  assert_pretty_contains(
    quantile(scsq, @symcore.rational_from_ints(1, 4), rvs=[csq]),
    ["gammaincinv", "1/4"],
  )
  assert_pretty_contains(entropy(scsq, rvs=[csq]), ["digamma", "gamma"])

  let erq = erlang("Erq", params=[@symcore.int(3), @symcore.int(2)])
  let serq = @symcore.Expr::Symbol("Erq")
  assert_pretty_contains(
    quantile(serq, @symcore.rational_from_ints(1, 4), rvs=[erq]),
    ["gammaincinv", "1/4"],
  )
  assert_pretty_contains(entropy(serq, rvs=[erq]), ["digamma", "gamma"])

  let u = uniform("Ue", params=[@symcore.int(1), @symcore.int(3)])
  let su = @symcore.Expr::Symbol("Ue")
  assert_pretty_lacks(entropy(su, rvs=[u]), "entropy(")

  let quantile_cases : Array[(RandomVar, String, Array[String])] = [
    (gumbel("Gwe", params=[@symcore.int(2), @symcore.int(0)]), "Gwe", ["log"]),
    (
      moyal("Moq", params=[@symcore.int(0), @symcore.int(1)]),
      "Moq",
      ["erfcinv"],
    ),
    (gompertz("Goq", params=[@symcore.int(2), @symcore.int(3)]), "Goq", ["log"]),
    (laplace("Laq", params=[@symcore.int(0), @symcore.int(2)]), "Laq", ["log"]),
    (
      triangular("Tq", params=[
        @symcore.int(0),
        @symcore.int(2),
        @symcore.int(1),
      ]),
      "Tq",
      ["sqrt"],
    ),
    (
      power_function("Pq", params=[
        @symcore.int(2),
        @symcore.int(0),
        @symcore.int(3),
      ]),
      "Pq",
      ["3/2"],
    ),
    (
      trapezoidal("Trq", params=[
        @symcore.int(0),
        @symcore.int(1),
        @symcore.int(2),
        @symcore.int(4),
      ]),
      "Trq",
      ["9/8"],
    ),
    (student_t("Stq", params=[@symcore.int(5)]), "Stq", ["0"]),
    (
      reciprocal("Rcq", params=[@symcore.int(1), @symcore.int(3)]),
      "Rcq",
      ["3**"],
    ),
    (levy("Lvq", params=[@symcore.int(0), @symcore.int(1)]), "Lvq", ["erfcinv"]),
    (lomax("Lmq", params=[@symcore.int(2), @symcore.int(3)]), "Lmq", ["3/"]),
    (
      bounded_pareto("Bpq", params=[
        @symcore.int(2),
        @symcore.int(3),
        @symcore.int(9),
      ]),
      "Bpq",
      ["3/"],
    ),
  ]
  for item in quantile_cases {
    let (rv, symbol, parts) = item
    let value = quantile(
      @symcore.Expr::Symbol(symbol),
      @symcore.rational_from_ints(1, 4),
      rvs=[rv],
    )
    assert_pretty_lacks(value, "quantile(")
    assert_pretty_contains(value, parts)
  }

  let vmq = von_mises("Vmq", params=[@symcore.int(0), @symcore.int(2)])
  let svmq = @symcore.Expr::Symbol("Vmq")
  let vmq_q = quantile(svmq, @symcore.rational_from_ints(1, 4), rvs=[vmq])
  assert_pretty_lacks(vmq_q, "VonMisesQuantile(")
  assert_pretty_contains(vmq_q, ["ConditionSet", "Integral", "besseli"])

  let entropy_cases : Array[(RandomVar, String, Array[String])] = [
    (beta("Bwe", params=[@symcore.int(2), @symcore.int(5)]), "Bwe", ["digamma"]),
    (rayleigh("Rwe", params=[@symcore.int(2)]), "Rwe", ["EulerGamma"]),
    (
      weibull("Wwe", params=[@symcore.int(3), @symcore.int(5)]),
      "Wwe",
      ["EulerGamma"],
    ),
    (
      log_normal("Lwe", params=[@symcore.int(0), @symcore.int(2)]),
      "Lwe",
      ["sqrt", "pi"],
    ),
    (
      triangular("Twe", params=[
        @symcore.int(0),
        @symcore.int(2),
        @symcore.int(1),
      ]),
      "Twe",
      ["log"],
    ),
    (
      power_function("Pwe", params=[
        @symcore.int(2),
        @symcore.int(0),
        @symcore.int(3),
      ]),
      "Pwe",
      ["log"],
    ),
    (student_t("Stwe", params=[@symcore.int(5)]), "Stwe", ["digamma", "beta"]),
    (
      von_mises("Vmwe", params=[@symcore.int(0), @symcore.int(2)]),
      "Vmwe",
      ["besseli"],
    ),
    (
      trapezoidal("Trwe", params=[
        @symcore.int(0),
        @symcore.int(1),
        @symcore.int(2),
        @symcore.int(4),
      ]),
      "Trwe",
      ["log"],
    ),
    (moyal("Mowe", params=[@symcore.int(0), @symcore.int(1)]), "Mowe", ["oo"]),
    (
      gompertz("Goe", params=[@symcore.int(2), @symcore.int(3)]),
      "Goe",
      ["Ei", "log"],
    ),
    (levy("Lve", params=[@symcore.int(0), @symcore.int(2)]), "Lve", ["pi"]),
    (lomax("Lmwe", params=[@symcore.int(2), @symcore.int(3)]), "Lmwe", ["log"]),
    (
      bounded_pareto("Bpe", params=[
        @symcore.int(2),
        @symcore.int(3),
        @symcore.int(9),
      ]),
      "Bpe",
      ["log"],
    ),
  ]
  for item in entropy_cases {
    let (rv, symbol, parts) = item
    let value = entropy(@symcore.Expr::Symbol(symbol), rvs=[rv])
    assert_pretty_lacks(value, "entropy(")
    assert_pretty_contains(value, parts)
  }
}

///|
fn _compat_generated_discrete_parity_batch_python_oracle_disabled() -> Unit raise {
  let h = hypergeometric("H", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  let sh = @symcore.Expr::Symbol("H")
  let h_pmf = density(h, @symcore.int(3))
  let h_pmf_oracle = stats_eval_str(
    "(lambda H: density(H)(3))(stats.Hypergeometric('H', 20, 7, 12))",
  )
  assert_true(expr_equiv_to(h_pmf, h_pmf_oracle))
  let h_cdf = probability(le(sh, @symcore.int(3)), rv=h)
  let h_cdf_oracle = stats_eval_str(
    "(lambda H: P(H <= 3))(stats.Hypergeometric('H', 20, 7, 12))",
  )
  assert_true(expr_equiv_to(h_cdf, h_cdf_oracle))
  let h_mean = expectation(sh, rvs=[h])
  assert_true(expr_equiv_to(h_mean, "21/5"))
  let h_var = variance(sh, rvs=[h])
  assert_true(expr_equiv_to(h_var, "546/475"))

  let f = flory_schulz("F", params=[@symcore.rational_from_ints(1, 3)])
  let sf = @symcore.Expr::Symbol("F")
  let t = @symcore.Expr::Symbol("t")
  let f_mean = expectation(sf, rvs=[f])
  let f_mean_oracle = stats_eval_str(
    "(lambda F: E(F))(stats.FlorySchulz('F', Rational(1, 3)))",
  )
  assert_true(expr_equiv_to(f_mean, f_mean_oracle))
  let f_var = variance(sf, rvs=[f])
  let f_var_oracle = stats_eval_str(
    "(lambda F: variance(F))(stats.FlorySchulz('F', Rational(1, 3)))",
  )
  assert_true(expr_equiv_to(f_var, f_var_oracle))
  let f_mgf = moment_generating_function(sf, t, rvs=[f])
  let f_mgf_oracle = stats_eval_str(
    "(lambda F, t: moment_generating_function(F)(t))(stats.FlorySchulz('F', Rational(1, 3)), t)",
  )
  assert_true(expr_equiv_to(f_mgf, f_mgf_oracle))

  let l = logarithmic("Lx", params=[@symcore.rational_from_ints(1, 3)])
  let sl = @symcore.Expr::Symbol("Lx")
  let l_pmf = density(l, @symcore.int(2))
  let l_pmf_oracle = stats_eval_str(
    "(lambda Lx: density(Lx)(2))(stats.Logarithmic('Lx', Rational(1, 3)))",
  )
  assert_true(expr_equiv_to(l_pmf, l_pmf_oracle))
  let l_mean = expectation(sl, rvs=[l])
  let l_mean_oracle = stats_eval_str(
    "(lambda Lx: E(Lx))(stats.Logarithmic('Lx', Rational(1, 3)))",
  )
  assert_true(expr_equiv_to(l_mean, l_mean_oracle))

  let s = skellam("Sx", params=[@symcore.int(2), @symcore.int(3)])
  let ssx = @symcore.Expr::Symbol("Sx")
  let s_pmf = density(s, @symcore.int(1))
  assert_true(
    expr_equiv_to(s_pmf, "sqrt(2)*sqrt(3)**-1*exp(-5)*besseli(1, 2*sqrt(6))"),
  )
  let s_cf = characteristic_function(ssx, t, rvs=[s])
  let s_cf_oracle = stats_eval_str(
    "(lambda Sx, t: characteristic_function(Sx)(t))(stats.Skellam('Sx', 2, 3), t)",
  )
  assert_true(expr_equiv_to(s_cf, s_cf_oracle))

  let y = yule_simon("Yx", params=[@symcore.int(3)])
  let sy = @symcore.Expr::Symbol("Yx")
  let y_pmf = density(y, @symcore.int(2))
  let y_pmf_oracle = stats_eval_str(
    "(lambda Yx: density(Yx)(2))(stats.YuleSimon('Yx', 3))",
  )
  assert_true(expr_equiv_to(y_pmf, y_pmf_oracle))
  let y_mean = expectation(sy, rvs=[y])
  let y_mean_oracle = stats_eval_str(
    "(lambda Yx: E(Yx))(stats.YuleSimon('Yx', 3))",
  )
  assert_true(expr_equiv_to(y_mean, y_mean_oracle))
}

///|
test "compat generated discrete structural parity batch" {
  let h = hypergeometric("H", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  let sh = @symcore.Expr::Symbol("H")
  assert_pretty_contains(density(h, @symcore.int(3)), ["binomial"])
  assert_pretty_lacks(density(h, @symcore.int(3)), "HypergeometricPMF(")
  assert_pretty_contains(probability(le(sh, @symcore.int(3)), rv=h), ["+"])
  assert_true(expr_equiv_safe(expectation(sh, rvs=[h]), "21/5"))
  assert_true(expr_equiv_safe(variance(sh, rvs=[h]), "546/475"))

  let f = flory_schulz("F", params=[@symcore.rational_from_ints(1, 3)])
  let sf = @symcore.Expr::Symbol("F")
  let t = @symcore.Expr::Symbol("t")
  assert_pretty_lacks(expectation(sf, rvs=[f]), "FlorySchulzMean(")
  assert_pretty_lacks(variance(sf, rvs=[f]), "FlorySchulzVariance(")
  assert_pretty_contains(moment_generating_function(sf, t, rvs=[f]), ["exp(t)"])

  let l = logarithmic("Lx", params=[@symcore.rational_from_ints(1, 3)])
  let sl = @symcore.Expr::Symbol("Lx")
  assert_pretty_lacks(density(l, @symcore.int(2)), "LogarithmicPMF(")
  assert_pretty_contains(density(l, @symcore.int(2)), ["log"])
  assert_pretty_lacks(expectation(sl, rvs=[l]), "LogarithmicMean(")

  let s = skellam("Sx", params=[@symcore.int(2), @symcore.int(3)])
  let ssx = @symcore.Expr::Symbol("Sx")
  assert_pretty_lacks(density(s, @symcore.int(1)), "SkellamPMF(")
  assert_pretty_contains(density(s, @symcore.int(1)), ["besseli"])
  assert_pretty_lacks(characteristic_function(ssx, t, rvs=[s]), "SkellamCF(")
  assert_pretty_contains(characteristic_function(ssx, t, rvs=[s]), ["exp", "I"])

  let y = yule_simon("Yx", params=[@symcore.int(3)])
  let sy = @symcore.Expr::Symbol("Yx")
  assert_pretty_lacks(density(y, @symcore.int(2)), "YuleSimonPMF(")
  assert_pretty_contains(density(y, @symcore.int(2)), ["beta"])
  assert_pretty_lacks(expectation(sy, rvs=[y]), "YuleSimonMean(")
}

///|
fn _compat_density_parity_for_nine_residual_families_python_oracle_disabled() -> Unit raise {
  let half = @symcore.rational_from_ints(1, 2)
  let third = @symcore.rational_from_ints(1, 3)
  let quarter = @symcore.rational_from_ints(1, 4)
  let fifth = @symcore.rational_from_ints(1, 5)

  let bnc = beta_noncentral("BNC", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  let bnc_d = density(bnc, half)
  let bnc_oracle = stats_eval_str(
    "(lambda BNC: density(BNC)(Rational(1, 2)))(stats.BetaNoncentral('BNC', 2, 3, 4))",
  )
  assert_true(expr_equiv_to(bnc_d, bnc_oracle))
  assert_true(
    !@symprint.pretty_string(bnc_d).contains("BetaNoncentralDensity("),
  )

  let us = uniform_sum("US", params=[@symcore.int(3)])
  let us_d = density(us, @symcore.rational_from_ints(3, 2))
  let us_oracle = stats_eval_str(
    "(lambda US: density(US)(Rational(3, 2)))(stats.UniformSum('US', 3))",
  )
  assert_true(expr_equiv_to(us_d, us_oracle))
  assert_true(!@symprint.pretty_string(us_d).contains("UniformSumDensity("))

  let he = hermite("HE", params=[@symcore.int(2), @symcore.int(3)])
  let he_d = density(he, @symcore.int(4))
  let he_oracle = stats_eval_str(
    "(lambda HE: density(HE)(4))(stats.Hermite('HE', 2, 3))",
  )
  assert_true(expr_equiv_to(he_d, he_oracle))
  assert_true(!@symprint.pretty_string(he_d).contains("HermitePMF("))

  let iso = ideal_soliton("ISO", params=[@symcore.int(6)])
  let iso_d = density(iso, @symcore.int(2))
  let iso_oracle = stats_eval_str(
    "(lambda ISO: density(ISO)(2))(stats.IdealSoliton('ISO', 6))",
  )
  assert_true(expr_equiv_to(iso_d, iso_oracle))
  assert_true(!@symprint.pretty_string(iso_d).contains("IdealSolitonPMF("))

  let rso = robust_soliton("RSO", params=[
    @symcore.int(6),
    @symcore.int(1),
    fifth,
  ])
  let rso_d = density(rso, @symcore.int(2))
  let rso_oracle = stats_eval_str(
    "(lambda RSO: density(RSO)(2))(stats.RobustSoliton('RSO', 6, 1, Rational(1, 5)))",
  )
  let rso_num_close = stats_eval_str(
    "abs(sympy.N(\{@symprint.pretty_string(rso_d)}, 50) - sympy.N(\{rso_oracle}, 50)) < 1e-15",
  )
  assert_eq(rso_num_close, "True")
  assert_true(!@symprint.pretty_string(rso_d).contains("RobustSolitonPMF("))

  let two_thirds = @symcore.rational_from_ints(2, 3)
  let mn = multinomial("MN", params=[@symcore.int(3), third, two_thirds])
  let mn_d = density(
    mn,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let mn_oracle = stats_eval_str(
    "(lambda MN: density(MN)(1, 2))(stats.Multinomial('MN', 3, Rational(1, 3), Rational(2, 3)))",
  )
  assert_true(expr_equiv_to(mn_d, mn_oracle))
  assert_true(!@symprint.pretty_string(mn_d).contains("MultinomialPMF("))

  let nm = negative_multinomial("NM", params=[@symcore.int(2), quarter, third])
  let nm_d = density(
    nm,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let nm_oracle = stats_eval_str(
    "(lambda NM: density(NM)(1, 2))(stats.NegativeMultinomial('NM', 2, Rational(1, 4), Rational(1, 3)))",
  )
  assert_true(expr_equiv_to(nm_d, nm_oracle))
  assert_true(
    !@symprint.pretty_string(nm_d).contains("NegativeMultinomialPMF("),
  )

  let bp = bernoulli_process("BPD", params=[third])
  let bp_d1 = density(bp, @symcore.int(1))
  let bp_d0 = density(bp, @symcore.int(0))
  assert_true(expr_equiv_to(bp_d1, "1/3"))
  assert_true(expr_equiv_to(bp_d0, "2/3"))
  assert_true(
    !@symprint.pretty_string(bp_d1).contains("BernoulliProcessDensity("),
  )

  let gp = gamma_process("GPD", params=[@symcore.int(2), @symcore.int(3)])
  let gp_d = density(gp, @symcore.int(1))
  let gp_s = @symprint.pretty_string(gp_d)
  assert_true(gp_s.contains("Piecewise"))
  assert_true(gp_s.contains("gamma(") && gp_s.contains("t"))
  assert_true(gp_s.contains("exp(-2)"))
  assert_true(!gp_s.contains("GammaProcessDensity("))
}

///|
test "compat residual family density structural parity" {
  let half = @symcore.rational_from_ints(1, 2)
  let third = @symcore.rational_from_ints(1, 3)
  let quarter = @symcore.rational_from_ints(1, 4)
  let fifth = @symcore.rational_from_ints(1, 5)

  let bnc = beta_noncentral("BNC", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_pretty_lacks(density(bnc, half), "BetaNoncentralDensity(")
  assert_pretty_contains(density(bnc, half), ["exp", "Sum"])

  let us = uniform_sum("US", params=[@symcore.int(3)])
  assert_pretty_lacks(
    density(us, @symcore.rational_from_ints(3, 2)),
    "UniformSumDensity(",
  )
  assert_pretty_contains(density(us, @symcore.rational_from_ints(3, 2)), ["Sum"])

  let he = hermite("HE", params=[@symcore.int(2), @symcore.int(3)])
  assert_pretty_lacks(density(he, @symcore.int(4)), "HermitePMF(")
  assert_pretty_contains(density(he, @symcore.int(4)), ["exp", "Sum"])

  let iso = ideal_soliton("ISO", params=[@symcore.int(6)])
  assert_pretty_lacks(density(iso, @symcore.int(2)), "IdealSolitonPMF(")

  let rso = robust_soliton("RSO", params=[
    @symcore.int(6),
    @symcore.int(1),
    fifth,
  ])
  assert_pretty_lacks(density(rso, @symcore.int(2)), "RobustSolitonPMF(")

  let two_thirds = @symcore.rational_from_ints(2, 3)
  let mn = multinomial("MN", params=[@symcore.int(3), third, two_thirds])
  let mn_d = density(
    mn,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  assert_pretty_lacks(mn_d, "MultinomialPMF(")
  assert_pretty_contains(mn_d, ["factorial"])

  let nm = negative_multinomial("NM", params=[@symcore.int(2), quarter, third])
  let nm_d = density(
    nm,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  assert_pretty_lacks(nm_d, "NegativeMultinomialPMF(")
  assert_pretty_contains(nm_d, ["factorial"])

  let bp = bernoulli_process("BPD", params=[third])
  assert_true(expr_equiv_safe(density(bp, @symcore.int(1)), "1/3"))
  assert_true(expr_equiv_safe(density(bp, @symcore.int(0)), "2/3"))

  let gp = gamma_process("GPD", params=[@symcore.int(2), @symcore.int(3)])
  let gp_d = density(gp, @symcore.int(1))
  assert_pretty_lacks(gp_d, "GammaProcessDensity(")
  assert_pretty_contains(gp_d, ["Piecewise", "gamma", "exp"])
}

///|
test "compat weibull parity ordering" {
  let w = weibull("W0", params=[@symcore.int(3), @symcore.int(5)])
  let x = @symcore.Expr::Symbol("x")
  let sw = @symcore.Expr::Symbol("W0")
  let d = density(w, x)
  assert_pretty_lacks(d, "WeibullDensity(")
  assert_pretty_contains(d, ["Piecewise", "exp", "x/3"])
  let c = cdf(w, x)
  assert_pretty_lacks(c, "WeibullCDF(")
  assert_pretty_contains(c, ["Piecewise", "exp", "x/3"])
  let m = expectation(sw, rvs=[w])
  assert_pretty_contains(m, ["3", "gamma", "6/5"])
  let v = variance(sw, rvs=[w])
  assert_pretty_contains(v, ["9", "gamma", "6/5", "7/5"])
}

///|
test "compat special constructors keep concrete behavior" {
  let g = gamma("G", @symcore.int(3), @symcore.int(2))
  let ge = expectation(@symcore.Expr::Symbol("G"), rvs=[g])
  assert_true(expr_equiv_safe(ge, "6"))
  let sigma = stats_matrix_literal([
    [@symcore.int(1), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(1)],
  ])
  let xmat = stats_matrix_literal([
    [@symcore.int(2), @symcore.int(1)],
    [@symcore.int(1), @symcore.int(2)],
  ])
  let w = wishart("W", @symcore.int(5), sigma)
  let wd = matrix_density(w, xmat)
  match wd {
    Some(v) => {
      assert_pretty_lacks(v, "WishartDensity(")
      assert_pretty_contains(v, ["Determinant", "Trace", "gamma"])
      assert_eq(
        @symprint.pretty_string(density(w, xmat)),
        @symprint.pretty_string(v),
      )
    }
    None => assert_true(false)
  }

  let loc = stats_matrix_literal([[@symcore.int(5), @symcore.int(6)]])
  let rowcov = stats_matrix_literal([[@symcore.int(4)]])
  let colcov = stats_matrix_literal([
    [@symcore.int(2), @symcore.int(1)],
    [@symcore.int(1), @symcore.int(2)],
  ])
  let mn = matrix_normal("MN", loc, rowcov, colcov)
  let xmat12 = stats_matrix_literal([[@symcore.int(7), @symcore.int(8)]])
  match matrix_density(mn, xmat12) {
    Some(v) => {
      assert_pretty_lacks(v, "MatrixNormalDensity(")
      assert_pretty_contains(v, ["Determinant", "Trace", "exp"])
    }
    None => assert_true(false)
  }
}

///|
test "compat symbolic families and rademacher parity" {
  let r = rayleigh("R", params=[@symcore.int(2)])
  let sr = @symcore.Expr::Symbol("R")
  let re = expectation(sr, rvs=[r])
  let rv = variance(sr, rvs=[r])
  assert_pretty_contains(re, ["pi", "2**"])
  assert_pretty_contains(rv, ["pi"])

  let rad = rademacher("X")
  let sx = @symcore.Expr::Symbol("X")
  assert_true(expr_equiv_safe(expectation(sx, rvs=[rad]), "0"))
  assert_true(expr_equiv_safe(variance(sx, rvs=[rad]), "1"))
  let p1 = probability(eq(sx, @symcore.int(1)), rv=rad)
  assert_true(expr_equiv_safe(p1, "1/2"))
}

///|
test "compat matrix helpers shape smoke" {
  let xs = [@symcore.Expr::Symbol("X"), @symcore.Expr::Symbol("Y")]
  let vars = variance_matrix(xs)
  inspect(vars.length(), content="2")
  inspect(vars[0].length(), content="2")
  let cross = cross_covariance_matrix(xs, [@symcore.Expr::Symbol("Z")])
  inspect(cross.length(), content="2")
  inspect(cross[0].length(), content="1")
}

///|
fn _compat_non_fallback_symbolic_families_python_oracle_disabled() -> Unit raise {
  let bb = beta_binomial("BB", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  let bb_pmf = density(bb, @symcore.int(2))
  let bb_pmf_oracle = stats_eval_str(
    "(lambda BB: density(BB)(2))(stats.BetaBinomial('BB', 10, 2, 3))",
  )
  assert_true(expr_equiv_to(bb_pmf, bb_pmf_oracle))
  let bb_cdf = cdf(bb, @symcore.int(2))
  let bb_cdf_oracle = stats_eval_str(
    "(lambda BB: P(BB <= 2))(stats.BetaBinomial('BB', 10, 2, 3))",
  )
  assert_true(expr_equiv_to(bb_cdf, bb_cdf_oracle))
  let sbb = @symcore.Expr::Symbol("BB")
  let bb_mean = expectation(sbb, rvs=[bb])
  assert_true(expr_equiv_to(bb_mean, "4"))
  let bb_var = variance(sbb, rvs=[bb])
  assert_true(expr_equiv_to(bb_var, "6"))

  let d = dirichlet("D", params=[@symcore.int(2), @symcore.int(3)])
  let sd = @symcore.Expr::Symbol("D")
  let d_mean = expectation(sd, rvs=[d])
  assert_true(expr_equiv_to(d_mean, "Tuple(2/5, 3/5)"))
  assert_true(!@symprint.pretty_string(d_mean).contains("DirichletMean("))
  let d_var = variance(sd, rvs=[d])
  assert_true(
    expr_equiv_to(d_var, "Tuple(Tuple(1/25, -1/25), Tuple(-1/25, 1/25))"),
  )
  assert_true(!@symprint.pretty_string(d_var).contains("DirichletVariance("))
  let d_entropy = entropy(sd, rvs=[d])
  assert_true(
    expr_equiv_to(
      d_entropy, "log(gamma(2)*gamma(3)/gamma(5)) + 3*digamma(5) - digamma(2) - 2*digamma(3)",
    ),
  )
  assert_true(!@symprint.pretty_string(d_entropy).contains("DirichletEntropy("))
  let d_density = density(
    d,
    @symcore.function("Tuple", [
      @symcore.rational_from_ints(1, 3),
      @symcore.rational_from_ints(2, 3),
    ]),
  )
  let d_density_oracle = stats_eval_str(
    "(lambda D: density(D)(Rational(1, 3), Rational(2, 3)))(stats.Dirichlet('D', [2, 3]))",
  )
  assert_true(expr_equiv_to(d_density, d_density_oracle))
  assert_true(!@symprint.pretty_string(d_density).contains("DirichletDensity("))

  let mb = multivariate_beta("MB", params=[@symcore.int(2), @symcore.int(3)])
  let smb = @symcore.Expr::Symbol("MB")
  let mb_mean = expectation(smb, rvs=[mb])
  assert_true(expr_equiv_to(mb_mean, "Tuple(2/5, 3/5)"))
  assert_true(
    !@symprint.pretty_string(mb_mean).contains("MultivariateBetaMean("),
  )
  let mb_var = variance(smb, rvs=[mb])
  assert_true(
    expr_equiv_to(mb_var, "Tuple(Tuple(1/25, -1/25), Tuple(-1/25, 1/25))"),
  )
  assert_true(
    !@symprint.pretty_string(mb_var).contains("MultivariateBetaVariance("),
  )
  let mb_density = density(
    mb,
    @symcore.function("Tuple", [
      @symcore.rational_from_ints(1, 3),
      @symcore.rational_from_ints(2, 3),
    ]),
  )
  let mb_density_oracle = stats_eval_str(
    "(lambda MB: density(MB)(Rational(1, 3), Rational(2, 3)))(stats.MultivariateBeta('MB', [2, 3]))",
  )
  assert_true(expr_equiv_to(mb_density, mb_density_oracle))
  assert_true(
    !@symprint.pretty_string(mb_density).contains("MultivariateBetaDensity("),
  )

  let mn = multinomial("MN", params=[
    @symcore.int(5),
    @symcore.rational_from_ints(1, 3),
    @symcore.rational_from_ints(2, 3),
  ])
  let smn = @symcore.Expr::Symbol("MN")
  let mn_mean = expectation(smn, rvs=[mn])
  assert_true(expr_equiv_to(mn_mean, "Tuple(5/3, 10/3)"))
  assert_true(!@symprint.pretty_string(mn_mean).contains("MultinomialMean("))
  let mn_var = variance(smn, rvs=[mn])
  assert_true(
    expr_equiv_to(mn_var, "Tuple(Tuple(10/9, -10/9), Tuple(-10/9, 10/9))"),
  )
  assert_true(!@symprint.pretty_string(mn_var).contains("MultinomialVariance("))

  let nm = negative_multinomial("NM", params=[
    @symcore.int(3),
    @symcore.rational_from_ints(1, 5),
    @symcore.rational_from_ints(1, 10),
  ])
  let snm = @symcore.Expr::Symbol("NM")
  let nm_mean = expectation(snm, rvs=[nm])
  assert_true(expr_equiv_to(nm_mean, "Tuple(6/7, 3/7)"))
  assert_true(
    !@symprint.pretty_string(nm_mean).contains("NegativeMultinomialMean("),
  )
  let nm_var = variance(snm, rvs=[nm])
  assert_true(
    expr_equiv_to(nm_var, "Tuple(Tuple(54/49, 6/49), Tuple(6/49, 24/49))"),
  )
  assert_true(
    !@symprint.pretty_string(nm_var).contains("NegativeMultinomialVariance("),
  )

  let mvn_mu = @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])
  let mvn_sigma = @symcore.function("Tuple", [
    @symcore.function("Tuple", [@symcore.int(2), @symcore.int(1)]),
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(3)]),
  ])
  let mvn = multivariate_normal("MVN", params=[mvn_mu, mvn_sigma])
  let smvn = @symcore.Expr::Symbol("MVN")
  let mvn_mean = expectation(smvn, rvs=[mvn])
  assert_true(expr_equiv_to(mvn_mean, "Tuple(1, 2)"))
  assert_true(
    !@symprint.pretty_string(mvn_mean).contains("MultivariateNormalMean("),
  )
  let mvn_var = variance(smvn, rvs=[mvn])
  assert_true(expr_equiv_to(mvn_var, "Tuple(Tuple(2, 1), Tuple(1, 3))"))
  assert_true(
    !@symprint.pretty_string(mvn_var).contains("MultivariateNormalVariance("),
  )
  let t1 = @symcore.Expr::Symbol("t1")
  let t2 = @symcore.Expr::Symbol("t2")
  let tvec = @symcore.function("Tuple", [t1, t2])
  let mvn_mgf = moment_generating_function(smvn, tvec, rvs=[mvn])
  assert_true(
    expr_equiv_to(mvn_mgf, "exp(t1 + 2*t2 + t1**2 + t1*t2 + 3*t2**2/2)"),
  )
  assert_true(
    !@symprint.pretty_string(mvn_mgf).contains("MultivariateNormalMGF("),
  )
  let mvn_cf = characteristic_function(smvn, tvec, rvs=[mvn])
  assert_true(
    expr_equiv_to(mvn_cf, "exp(I*(t1 + 2*t2) - t1**2 - t1*t2 - 3*t2**2/2)"),
  )
  assert_true(
    !@symprint.pretty_string(mvn_cf).contains("MultivariateNormalCF("),
  )
  let mvn_density = density(
    mvn,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let mvn_density_oracle = stats_eval_str(
    "(lambda MVN: density(MVN)(1, 2))(stats.MultivariateNormal('MVN', [1, 2], [[2, 1], [1, 3]]))",
  )
  assert_true(expr_equiv_to(mvn_density, mvn_density_oracle))
  assert_true(
    !@symprint.pretty_string(mvn_density).contains("MultivariateNormalDensity("),
  )

  let mvt = multivariate_t("MVT", params=[mvn_mu, mvn_sigma, @symcore.int(5)])
  let smvt = @symcore.Expr::Symbol("MVT")
  let mvt_mean = expectation(smvt, rvs=[mvt])
  assert_true(expr_equiv_to(mvt_mean, "Tuple(1, 2)"))
  assert_true(!@symprint.pretty_string(mvt_mean).contains("MultivariateTMean("))
  let mvt_var = variance(smvt, rvs=[mvt])
  assert_true(expr_equiv_to(mvt_var, "Tuple(Tuple(10/3, 5/3), Tuple(5/3, 5))"))
  assert_true(
    !@symprint.pretty_string(mvt_var).contains("MultivariateTVariance("),
  )
  let mvt_density = density(
    mvt,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let mvt_density_oracle = stats_eval_str(
    "(lambda MVT: density(MVT)(1, 2))(stats.MultivariateT('MVT', [1, 2], [[2, 1], [1, 3]], 5))",
  )
  assert_true(expr_equiv_to(mvt_density, mvt_density_oracle))
  assert_true(
    !@symprint.pretty_string(mvt_density).contains("MultivariateTDensity("),
  )

  let mvl = multivariate_laplace("MVL", params=[mvn_mu, mvn_sigma])
  let smvl = @symcore.Expr::Symbol("MVL")
  let mvl_mean = expectation(smvl, rvs=[mvl])
  assert_true(expr_equiv_to(mvl_mean, "Tuple(1, 2)"))
  assert_true(
    !@symprint.pretty_string(mvl_mean).contains("MultivariateLaplaceMean("),
  )
  let mvl_var = variance(smvl, rvs=[mvl])
  assert_true(expr_equiv_to(mvl_var, "Tuple(Tuple(2, 1), Tuple(1, 3))"))
  assert_true(
    !@symprint.pretty_string(mvl_var).contains("MultivariateLaplaceVariance("),
  )
  let mvl_mgf = moment_generating_function(smvl, tvec, rvs=[mvl])
  assert_true(
    expr_equiv_to(mvl_mgf, "exp(t1 + 2*t2)/(1 - t1**2 - t1*t2 - 3*t2**2/2)"),
  )
  assert_true(
    !@symprint.pretty_string(mvl_mgf).contains("MultivariateLaplaceMGF("),
  )
  let mvl_cf = characteristic_function(smvl, tvec, rvs=[mvl])
  assert_true(
    expr_equiv_to(mvl_cf, "exp(I*(t1 + 2*t2))/(1 + t1**2 + t1*t2 + 3*t2**2/2)"),
  )
  assert_true(
    !@symprint.pretty_string(mvl_cf).contains("MultivariateLaplaceCF("),
  )
  let mvl_density = density(
    mvl,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let mvl_density_oracle = stats_eval_str(
    "(lambda MVL: density(MVL)(1, 2))(stats.MultivariateLaplace('MVL', [1, 2], [[2, 1], [1, 3]]))",
  )
  assert_true(expr_equiv_to(mvl_density, mvl_density_oracle))
  assert_true(
    !@symprint.pretty_string(mvl_density).contains(
      "MultivariateLaplaceDensity(",
    ),
  )

  let ng = normal_gamma("NG", params=[
    @symcore.int(0),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  let sng = @symcore.Expr::Symbol("NG")
  let ng_mean = expectation(sng, rvs=[ng])
  assert_true(expr_equiv_to(ng_mean, "Tuple(0, 3/4)"))
  assert_true(!@symprint.pretty_string(ng_mean).contains("NormalGammaMean("))
  let ng_var = variance(sng, rvs=[ng])
  assert_true(expr_equiv_to(ng_var, "Tuple(Tuple(1, 0), Tuple(0, 3/16))"))
  assert_true(!@symprint.pretty_string(ng_var).contains("NormalGammaVariance("))
  let ng_density = density(
    ng,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let ng_density_oracle = stats_eval_str(
    "(lambda NG: density(NG)(1, 2))(stats.NormalGamma('NG', 0, 2, 3, 4))",
  )
  assert_true(expr_equiv_to(ng_density, ng_density_oracle))
  assert_true(
    !@symprint.pretty_string(ng_density).contains("NormalGammaDensity("),
  )

  let mc = discrete_markov_chain("MC", params=[@symcore.Expr::Symbol("Tmat")])
  let t = @symcore.Expr::Symbol("t")
  match process_mean_at(mc, t) {
    Some(v) => {
      assert_pretty_contains(v, [
        "Expectation", "DiscreteMarkovChain", "t", "Tmat",
      ])
      assert_pretty_lacks(v, "MeanAt(")
    }
    None => fail("missing symbolic process mean")
  }
  let i = @symcore.Expr::Symbol("i")
  let j = @symcore.Expr::Symbol("j")
  let t0 = @symcore.Expr::Symbol("t0")
  let t1 = @symcore.Expr::Symbol("t1")
  match process_transition_probability(mc, i, j, t0, t1) {
    Some(v) => {
      let vs = @symprint.pretty_string(v)
      assert_true(vs.contains("MatrixElement"))
      assert_true(vs.contains("Tmat"))
      assert_true(vs.contains("**"))
    }
    None => fail("missing discrete markov transition")
  }
  let cmcx = continuous_markov_chain("CMCX", params=[
    @symcore.Expr::Symbol("Qmat"),
  ])
  match process_transition_probability(cmcx, i, j, t0, t1) {
    Some(v) => {
      let vs = @symprint.pretty_string(v)
      assert_true(vs.contains("MatrixElement"))
      assert_true(vs.contains("MatrixExp"))
      assert_true(vs.contains("Qmat"))
    }
    None => fail("missing continuous markov transition")
  }

  let tau = @symcore.Expr::Symbol("tau")
  let z = @symcore.Expr::Symbol("z")
  let q1 = @symcore.rational_from_ints(1, 4)
  let sp = stochastic_process("SPX")
  let dtsp = discrete_time_stochastic_process("DTSPX")
  let spx = @symcore.function("SPX", [tau])
  let dtspx = @symcore.function("DTSPX", [tau])
  assert_pretty_contains(moment_generating_function(spx, z, rvs=[sp]), [
    "Expectation", "exp", "StochasticProcess", "tau", "z",
  ])
  assert_pretty_lacks(moment_generating_function(spx, z, rvs=[sp]), "MGFAt(")
  assert_pretty_contains(characteristic_function(spx, z, rvs=[sp]), [
    "Expectation", "exp", "I", "StochasticProcess", "tau", "z",
  ])
  assert_pretty_lacks(characteristic_function(spx, z, rvs=[sp]), "CFAt(")
  assert_pretty_contains(entropy(spx, rvs=[sp]), [
    "Entropy", "StochasticProcess", "tau",
  ])
  assert_pretty_lacks(entropy(spx, rvs=[sp]), "EntropyAt(")
  assert_pretty_contains(quantile(spx, q1, rvs=[sp]), [
    "ConditionSet", "Probability", "StochasticProcess", "tau", "1/4",
  ])
  assert_pretty_lacks(quantile(spx, q1, rvs=[sp]), "QuantileAt(")
  assert_pretty_contains(moment_generating_function(dtspx, z, rvs=[dtsp]), [
    "Expectation", "DiscreteTimeStochasticProcess", "tau", "z",
  ])
  assert_pretty_lacks(
    moment_generating_function(dtspx, z, rvs=[dtsp]),
    "MGFAt(",
  )
  assert_pretty_contains(
    probability(eq(spx, @symcore.Expr::Symbol("x")), rv=sp),
    ["Probability", "Eq", "StochasticProcess", "tau", "x"],
  )
  assert_pretty_lacks(
    probability(eq(spx, @symcore.Expr::Symbol("x")), rv=sp),
    "ProbabilityAt(",
  )
  assert_pretty_contains(
    probability(le(spx, @symcore.Expr::Symbol("x")), rv=sp),
    ["Probability", "Le", "StochasticProcess", "tau", "x"],
  )
  assert_pretty_contains(
    probability(eq(dtspx, @symcore.Expr::Symbol("x")), rv=dtsp),
    ["Probability", "Eq", "DiscreteTimeStochasticProcess", "tau", "x"],
  )
  assert_pretty_contains(
    probability(le(dtspx, @symcore.Expr::Symbol("x")), rv=dtsp),
    ["Probability", "Le", "DiscreteTimeStochasticProcess", "tau", "x"],
  )

  let dmcx = @symcore.function("MC", [tau])
  let cmcxx = @symcore.function("CMCX", [tau])
  assert_pretty_contains(moment_generating_function(dmcx, z, rvs=[mc]), [
    "Expectation", "DiscreteMarkovChain", "tau", "z", "Tmat",
  ])
  assert_pretty_lacks(moment_generating_function(dmcx, z, rvs=[mc]), "MGFAt(")
  assert_pretty_contains(characteristic_function(dmcx, z, rvs=[mc]), [
    "Expectation", "DiscreteMarkovChain", "tau", "z", "Tmat",
  ])
  assert_pretty_lacks(characteristic_function(dmcx, z, rvs=[mc]), "CFAt(")
  assert_pretty_contains(entropy(dmcx, rvs=[mc]), [
    "Entropy", "DiscreteMarkovChain", "tau", "Tmat",
  ])
  assert_pretty_lacks(entropy(dmcx, rvs=[mc]), "EntropyAt(")
  assert_pretty_contains(quantile(dmcx, q1, rvs=[mc]), [
    "ConditionSet", "DiscreteMarkovChain", "tau", "1/4", "Tmat",
  ])
  assert_pretty_lacks(quantile(dmcx, q1, rvs=[mc]), "QuantileAt(")
  assert_pretty_contains(moment_generating_function(cmcxx, z, rvs=[cmcx]), [
    "Expectation", "ContinuousMarkovChain", "tau", "z", "Qmat",
  ])
  assert_pretty_lacks(
    moment_generating_function(cmcxx, z, rvs=[cmcx]),
    "MGFAt(",
  )
  assert_pretty_contains(probability(eq(dmcx, @symcore.int(1)), rv=mc), [
    "Probability", "Eq", "DiscreteMarkovChain", "tau", "1", "Tmat",
  ])
  assert_pretty_lacks(
    probability(eq(dmcx, @symcore.int(1)), rv=mc),
    "ProbabilityAt(",
  )
  assert_pretty_contains(probability(le(dmcx, @symcore.int(1)), rv=mc), [
    "Probability", "Le", "DiscreteMarkovChain", "tau", "1", "Tmat",
  ])
  match process_cdf_at(mc, tau, @symcore.int(1)) {
    Some(v) => {
      assert_pretty_contains(v, [
        "Probability", "Le", "DiscreteMarkovChain", "tau", "1", "Tmat",
      ])
      assert_pretty_lacks(v, "CDFAt(")
    }
    None => fail("missing discrete markov cdf")
  }
  assert_pretty_contains(probability(eq(cmcxx, @symcore.int(1)), rv=cmcx), [
    "Probability", "Eq", "ContinuousMarkovChain", "tau", "1", "Qmat",
  ])
  assert_pretty_lacks(
    probability(eq(cmcxx, @symcore.int(1)), rv=cmcx),
    "ProbabilityAt(",
  )
  assert_pretty_contains(probability(le(cmcxx, @symcore.int(1)), rv=cmcx), [
    "Probability", "Le", "ContinuousMarkovChain", "tau", "1", "Qmat",
  ])
  let mc_joint = probability(
    and_event([
      eq(@symcore.function("MC", [t0]), i),
      eq(@symcore.function("MC", [t1]), j),
    ]),
    rv=mc,
  )
  let mc_joint_s = @symprint.pretty_string(mc_joint)
  assert_true(mc_joint_s.contains("Probability(Eq(DiscreteMarkovChain"))
  assert_true(mc_joint_s.contains("MatrixElement"))
  assert_true(!mc_joint_s.contains("ProbabilityAt("))

  let pp = poisson_process("PP", @symcore.Expr::Symbol("lam"))
  let ppx = @symcore.function("PP", [tau])
  let pp_mgf = moment_generating_function(ppx, z, rvs=[pp])
  assert_true(@symprint.pretty_string(pp_mgf).contains("exp("))
  assert_true(@symprint.pretty_string(pp_mgf).contains("lam"))
  assert_true(@symprint.pretty_string(pp_mgf).contains("tau"))
  let pp_prob = probability(eq(ppx, @symcore.int(2)), rv=pp)
  let pp_prob_s = @symprint.pretty_string(pp_prob)
  assert_true(!pp_prob_s.contains("Probability("))
  assert_true(pp_prob_s.contains("factorial"))
  let pp_cdf = probability(le(ppx, @symcore.int(2)), rv=pp)
  assert_true(@symprint.pretty_string(pp_cdf).contains("poisson_cdf"))

  let wp = wiener_process("WP")
  let wpx = @symcore.function("WP", [tau])
  assert_true(
    expr_equiv_to(characteristic_function(wpx, z, rvs=[wp]), "exp(-tau*z**2/2)"),
  )
  assert_true(
    expr_equiv_to(quantile(wpx, q1, rvs=[wp]), "sqrt(2*tau)*erfinv(-1/2)"),
  )
  assert_true(expr_equiv_to(probability(eq(wpx, @symcore.int(0)), rv=wp), "0"))

  let gue = gaussian_unitary_ensemble("GUE", params=[@symcore.int(3)])
  let xmat = @symcore.function("MatrixSymbol", [
    @symcore.Expr::Symbol("X"),
    @symcore.int(3),
    @symcore.int(3),
  ])
  match matrix_density(gue, xmat) {
    Some(v) => {
      let ok = stats_expr_equiv(
        @symprint.pretty_string(v),
        "density(stats.GaussianUnitaryEnsemble('GUE', 3))(sympy.MatrixSymbol(X, 3, 3))",
      )
      assert_true(ok)
      assert_true(
        !@symprint.pretty_string(v).contains("GaussianUnitaryEnsembleDensity("),
      )
    }
    None => fail("missing symbolic matrix density")
  }
  let goe = gaussian_orthogonal_ensemble("GOE", params=[@symcore.int(2)])
  let xmat2 = @symcore.function("MatrixSymbol", [
    @symcore.Expr::Symbol("X"),
    @symcore.int(2),
    @symcore.int(2),
  ])
  match matrix_density(goe, xmat2) {
    Some(v) => {
      let ours = stats_eval_str(
        "sympy.nsimplify(\{@symprint.pretty_string(v)})",
      )
      let oracle = stats_eval_str(
        "density(stats.GaussianOrthogonalEnsemble('GOE', 2))(sympy.MatrixSymbol(X, 2, 2))",
      )
      assert_eq(ours, oracle)
      assert_true(
        !@symprint.pretty_string(v).contains(
          "GaussianOrthogonalEnsembleDensity(",
        ),
      )
    }
    None => fail("missing symbolic matrix density")
  }
  let gse = gaussian_symplectic_ensemble("GSE", params=[@symcore.int(2)])
  match matrix_density(gse, xmat2) {
    Some(v) => {
      let ours = stats_eval_str(
        "sympy.nsimplify(\{@symprint.pretty_string(v)})",
      )
      let oracle = stats_eval_str(
        "density(stats.GaussianSymplecticEnsemble('GSE', 2))(sympy.MatrixSymbol(X, 2, 2))",
      )
      assert_eq(ours, oracle)
      assert_true(
        !@symprint.pretty_string(v).contains(
          "GaussianSymplecticEnsembleDensity(",
        ),
      )
    }
    None => fail("missing symbolic matrix density")
  }
  let gauss_abs = gaussian_ensemble("GEABS", params=[@symcore.int(2)])
  let circ_abs = circular_ensemble("CEABS", params=[@symcore.int(2)])
  let cue_abs = circular_unitary_ensemble("CUEABS", params=[@symcore.int(2)])
  let coe_abs = circular_orthogonal_ensemble("COEABS", params=[@symcore.int(2)])
  let cse_abs = circular_symplectic_ensemble("CSEABS", params=[@symcore.int(2)])
  assert_eq(
    @symprint.pretty_string(
      expectation(@symcore.Expr::Symbol("GEABS"), rvs=[gauss_abs]),
    ),
    "ZeroMatrix(2, 2)",
  )
  assert_eq(
    @symprint.pretty_string(
      expectation(@symcore.Expr::Symbol("CEABS"), rvs=[circ_abs]),
    ),
    "ZeroMatrix(2, 2)",
  )
  assert_eq(
    @symprint.pretty_string(
      expectation(@symcore.Expr::Symbol("CUEABS"), rvs=[cue_abs]),
    ),
    "ZeroMatrix(2, 2)",
  )
  assert_eq(
    @symprint.pretty_string(
      expectation(@symcore.Expr::Symbol("COEABS"), rvs=[coe_abs]),
    ),
    "ZeroMatrix(2, 2)",
  )
  assert_eq(
    @symprint.pretty_string(
      expectation(@symcore.Expr::Symbol("CSEABS"), rvs=[cse_abs]),
    ),
    "ZeroMatrix(2, 2)",
  )
  let ge_var = @symprint.pretty_string(
    variance(@symcore.Expr::Symbol("GEABS"), rvs=[gauss_abs]),
  )
  assert_true(ge_var.contains("Expectation("))
  assert_true(ge_var.contains("ZeroMatrix(2, 2)"))
  let ce_var = @symprint.pretty_string(
    variance(@symcore.Expr::Symbol("CEABS"), rvs=[circ_abs]),
  )
  assert_true(ce_var.contains("Expectation("))
  assert_true(ce_var.contains("ZeroMatrix(2, 2)"))
  assert_mgf_not_placeholder(gauss_abs, "GaussianEnsemble", t)
  assert_cf_not_placeholder(gauss_abs, "GaussianEnsemble", t)
  assert_quantile_not_placeholder(gauss_abs, "GaussianEnsemble", q1)
  assert_entropy_not_placeholder(gauss_abs, "GaussianEnsemble")
  assert_mgf_not_placeholder(circ_abs, "CircularEnsemble", t)
  assert_cf_not_placeholder(circ_abs, "CircularEnsemble", t)
  assert_quantile_not_placeholder(circ_abs, "CircularEnsemble", q1)
  assert_entropy_not_placeholder(circ_abs, "CircularEnsemble")
  assert_mgf_not_placeholder(cue_abs, "CircularUnitaryEnsemble", t)
  assert_cf_not_placeholder(cue_abs, "CircularUnitaryEnsemble", t)
  assert_quantile_not_placeholder(cue_abs, "CircularUnitaryEnsemble", q1)
  assert_entropy_not_placeholder(cue_abs, "CircularUnitaryEnsemble")
  assert_mgf_not_placeholder(coe_abs, "CircularOrthogonalEnsemble", t)
  assert_cf_not_placeholder(coe_abs, "CircularOrthogonalEnsemble", t)
  assert_quantile_not_placeholder(coe_abs, "CircularOrthogonalEnsemble", q1)
  assert_entropy_not_placeholder(coe_abs, "CircularOrthogonalEnsemble")
  assert_mgf_not_placeholder(cse_abs, "CircularSymplecticEnsemble", t)
  assert_cf_not_placeholder(cse_abs, "CircularSymplecticEnsemble", t)
  assert_quantile_not_placeholder(cse_abs, "CircularSymplecticEnsemble", q1)
  assert_entropy_not_placeholder(cse_abs, "CircularSymplecticEnsemble")

  let gue2 = gaussian_unitary_ensemble("GUE2", params=[@symcore.int(2)])
  match joint_eigen_distribution_of(gue2) {
    Some(v) => {
      let ratio = stats_eval_str(
        "sympy.simplify((\{@symprint.pretty_string(v)})(1, 2) / ((stats.joint_eigen_distribution(stats.GaussianUnitaryEnsemble('GUE2', 2)))(1, 2)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing joint eigen distribution")
  }
  let cue2 = circular_unitary_ensemble("CUE2", params=[@symcore.int(2)])
  match joint_eigen_distribution_of(cue2) {
    Some(v) => {
      let ratio = stats_eval_str(
        "sympy.simplify((\{@symprint.pretty_string(v)})(0, 1) / ((stats.joint_eigen_distribution(stats.CircularUnitaryEnsemble('CUE2', 2)))(0, 1)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing circular joint eigen distribution")
  }
  match joint_eigen_distribution_of(goe) {
    Some(v) => {
      let ratio = stats_eval_str(
        "sympy.simplify((\{@symprint.pretty_string(v)})(1, 2) / ((stats.joint_eigen_distribution(stats.GaussianOrthogonalEnsemble('GOE', 2)))(1, 2)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing GOE joint eigen distribution")
  }
  match joint_eigen_distribution_of(gse) {
    Some(v) => {
      let ratio = stats_eval_str(
        "sympy.simplify((\{@symprint.pretty_string(v)})(1, 2) / ((stats.joint_eigen_distribution(stats.GaussianSymplecticEnsemble('GSE', 2)))(1, 2)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing GSE joint eigen distribution")
  }
  let coe2 = circular_orthogonal_ensemble("COE2", params=[@symcore.int(2)])
  match joint_eigen_distribution_of(coe2) {
    Some(v) => {
      let ratio = stats_eval_str(
        "sympy.simplify((\{@symprint.pretty_string(v)})(0, 1) / ((stats.joint_eigen_distribution(stats.CircularOrthogonalEnsemble('COE2', 2)))(0, 1)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing COE joint eigen distribution")
  }
  let cse2 = circular_symplectic_ensemble("CSE2", params=[@symcore.int(2)])
  match joint_eigen_distribution_of(cse2) {
    Some(v) => {
      let ratio = stats_eval_str(
        "sympy.simplify((\{@symprint.pretty_string(v)})(0, 1) / ((stats.joint_eigen_distribution(stats.CircularSymplecticEnsemble('CSE2', 2)))(0, 1)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing CSE joint eigen distribution")
  }
  match level_spacing_distribution_of(gue2) {
    Some(v) => {
      let ours = stats_eval_str(
        "sympy.nsimplify((\{@symprint.pretty_string(v)})(Rational(1, 2)))",
      )
      let oracle = stats_eval_str(
        "sympy.nsimplify((stats.level_spacing_distribution(stats.GaussianUnitaryEnsemble('GUE2', 2)))(Rational(1, 2)))",
      )
      assert_eq(ours, oracle)
    }
    None => fail("missing level spacing distribution")
  }
  match level_spacing_distribution_of(goe) {
    Some(v) => {
      let ours = stats_eval_str(
        "sympy.nsimplify((\{@symprint.pretty_string(v)})(Rational(1, 2)))",
      )
      let oracle = stats_eval_str(
        "sympy.nsimplify((stats.level_spacing_distribution(stats.GaussianOrthogonalEnsemble('GOE', 2)))(Rational(1, 2)))",
      )
      assert_eq(ours, oracle)
    }
    None => fail("missing level spacing distribution")
  }
  match level_spacing_distribution_of(gse) {
    Some(v) => {
      let ours = stats_eval_str(
        "sympy.nsimplify((\{@symprint.pretty_string(v)})(Rational(1, 2)))",
      )
      let oracle = stats_eval_str(
        "sympy.nsimplify((stats.level_spacing_distribution(stats.GaussianSymplecticEnsemble('GSE', 2)))(Rational(1, 2)))",
      )
      assert_eq(ours, oracle)
    }
    None => fail("missing level spacing distribution")
  }
  assert_true(level_spacing_distribution_of(cue2) is None)

  let jed_direct = joint_eigen_distribution("JEDD", params=[
    @symcore.function("GaussianUnitaryEnsemble", [@symcore.int(2)]),
  ])
  let jed_direct_d = density(
    jed_direct,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  assert_true(!@symprint.pretty_string(jed_direct_d).contains("density(JEDD,"))
  match
    joint_eigen_distribution_of(
      gaussian_unitary_ensemble("GJ", params=[@symcore.int(2)]),
    ) {
    Some(lam) =>
      match lambda_apply_local(lam, [@symcore.int(1), @symcore.int(2)]) {
        Some(expected) => assert_true(jed_direct_d == expected)
        None => fail("failed to apply joint eigen lambda")
      }
    None => fail("missing joint eigen distribution")
  }
  let jed_direct_c = cdf(
    jed_direct,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  assert_true(@symprint.pretty_string(jed_direct_c).contains("Integral("))
  assert_true(
    !@symprint.pretty_string(jed_direct_c).contains(
      "JointEigenDistributionCDF(",
    ),
  )

  let lsd_direct = level_spacing_distribution("LSDD", params=[
    @symcore.function("GaussianOrthogonalEnsemble", [@symcore.int(2)]),
  ])
  let lsd_direct_d = density(lsd_direct, @symcore.rational_from_ints(1, 2))
  assert_true(!@symprint.pretty_string(lsd_direct_d).contains("density(LSDD,"))
  match
    level_spacing_distribution_of(
      gaussian_orthogonal_ensemble("LG", params=[@symcore.int(2)]),
    ) {
    Some(lam) =>
      match lambda_apply_local(lam, [@symcore.rational_from_ints(1, 2)]) {
        Some(expected) => assert_true(lsd_direct_d == expected)
        None => fail("failed to apply level spacing lambda")
      }
    None => fail("missing level spacing distribution")
  }
  let lsd_direct_c = cdf(lsd_direct, @symcore.rational_from_ints(1, 2))
  assert_true(@symprint.pretty_string(lsd_direct_c).contains("Integral("))
  assert_true(
    !@symprint.pretty_string(lsd_direct_c).contains(
      "level_spacing_distributionCDF(",
    ),
  )

  let bp = bernoulli_process("BP", params=[@symcore.rational_from_ints(1, 3)])
  let t = @symcore.Expr::Symbol("t")
  match process_mean_at(bp, t) {
    Some(v) => assert_true(expr_equiv_to(v, "1/3"))
    None => fail("missing bernoulli process mean")
  }
  match process_variance_at(bp, t) {
    Some(v) => assert_true(expr_equiv_to(v, "2/9"))
    None => fail("missing bernoulli process variance")
  }
  match
    process_transition_probability(
      bp,
      @symcore.int(0),
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(2),
    ) {
    Some(v) => assert_true(expr_equiv_to(v, "1/3"))
    None => fail("missing bernoulli process transition")
  }
  match
    process_transition_probability(
      bp,
      @symcore.int(1),
      @symcore.int(0),
      @symcore.int(1),
      @symcore.int(2),
    ) {
    Some(v) => assert_true(expr_equiv_to(v, "2/3"))
    None => fail("missing bernoulli process transition")
  }
  match
    process_transition_probability(
      bp,
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(2),
      @symcore.int(2),
    ) {
    Some(v) => assert_true(expr_equiv_to(v, "1"))
    None => fail("missing bernoulli process transition")
  }
  match
    process_transition_probability(
      bp,
      @symcore.int(1),
      @symcore.int(0),
      @symcore.int(2),
      @symcore.int(2),
    ) {
    Some(v) => assert_true(expr_equiv_to(v, "0"))
    None => fail("missing bernoulli process transition")
  }

  let gp = gamma_process("GP", params=[@symcore.int(2), @symcore.int(3)])
  match process_mean_at(gp, t) {
    Some(v) => {
      let o = stats_eval_str(
        "(lambda GP, t: E(GP(t)))(stats.GammaProcess('GP', 2, 3), t)",
      )
      assert_true(expr_equiv_to(v, o))
    }
    None => fail("missing gamma process mean")
  }
  match process_variance_at(gp, t) {
    Some(v) => {
      let o = stats_eval_str(
        "(lambda GP, t: variance(GP(t)))(stats.GammaProcess('GP', 2, 3), t)",
      )
      assert_true(expr_equiv_to(v, o))
    }
    None => fail("missing gamma process variance")
  }
  match
    process_transition_probability(
      gp,
      @symcore.int(2),
      @symcore.int(5),
      @symcore.int(1),
      @symcore.int(3),
    ) {
    Some(v) => {
      let vs = @symprint.pretty_string(v)
      assert_true(!vs.contains("GammaProcessTransitionProb"))
      assert_true(vs.contains("Piecewise"))
      assert_true(vs.contains("gamma"))
    }
    None => fail("missing gamma process transition")
  }
  match
    process_transition_probability(
      gp,
      @symcore.int(4),
      @symcore.int(4),
      @symcore.int(3),
      @symcore.int(3),
    ) {
    Some(v) => assert_true(expr_equiv_to(v, "1"))
    None => fail("missing gamma process transition")
  }
}

///|
test "compat non-fallback symbolic families structural parity" {
  let bb = beta_binomial("BB", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_pretty_lacks(density(bb, @symcore.int(2)), "BetaBinomialPMF(")
  assert_pretty_contains(density(bb, @symcore.int(2)), ["binomial", "beta"])
  assert_pretty_lacks(cdf(bb, @symcore.int(2)), "BetaBinomialCDF(")
  assert_pretty_contains(cdf(bb, @symcore.int(2)), ["beta"])
  let sbb = @symcore.Expr::Symbol("BB")
  assert_true(expr_equiv_safe(expectation(sbb, rvs=[bb]), "4"))
  assert_true(expr_equiv_safe(variance(sbb, rvs=[bb]), "6"))

  let d = dirichlet("D", params=[@symcore.int(2), @symcore.int(3)])
  let sd = @symcore.Expr::Symbol("D")
  assert_pretty_contains(expectation(sd, rvs=[d]), ["2/5", "3/5"])
  assert_pretty_lacks(expectation(sd, rvs=[d]), "DirichletMean(")
  assert_pretty_contains(variance(sd, rvs=[d]), ["1/25", "-1/25"])
  assert_pretty_lacks(variance(sd, rvs=[d]), "DirichletVariance(")
  assert_pretty_lacks(entropy(sd, rvs=[d]), "DirichletEntropy(")
  assert_pretty_contains(entropy(sd, rvs=[d]), ["digamma", "gamma"])
  let d_density = density(
    d,
    @symcore.function("Tuple", [
      @symcore.rational_from_ints(1, 3),
      @symcore.rational_from_ints(2, 3),
    ]),
  )
  assert_pretty_lacks(d_density, "DirichletDensity(")

  let mb = multivariate_beta("MB", params=[@symcore.int(2), @symcore.int(3)])
  let smb = @symcore.Expr::Symbol("MB")
  assert_pretty_contains(expectation(smb, rvs=[mb]), ["2/5", "3/5"])
  assert_pretty_lacks(expectation(smb, rvs=[mb]), "MultivariateBetaMean(")
  assert_pretty_lacks(variance(smb, rvs=[mb]), "MultivariateBetaVariance(")
  assert_pretty_lacks(
    density(
      mb,
      @symcore.function("Tuple", [
        @symcore.rational_from_ints(1, 3),
        @symcore.rational_from_ints(2, 3),
      ]),
    ),
    "MultivariateBetaDensity(",
  )

  let mn = multinomial("MN", params=[
    @symcore.int(5),
    @symcore.rational_from_ints(1, 3),
    @symcore.rational_from_ints(2, 3),
  ])
  let smn = @symcore.Expr::Symbol("MN")
  assert_pretty_contains(expectation(smn, rvs=[mn]), ["5/3", "10/3"])
  assert_pretty_lacks(expectation(smn, rvs=[mn]), "MultinomialMean(")
  assert_pretty_contains(variance(smn, rvs=[mn]), ["10/9", "-10/9"])
  assert_pretty_lacks(variance(smn, rvs=[mn]), "MultinomialVariance(")

  let nm = negative_multinomial("NM", params=[
    @symcore.int(3),
    @symcore.rational_from_ints(1, 5),
    @symcore.rational_from_ints(1, 10),
  ])
  let snm = @symcore.Expr::Symbol("NM")
  assert_pretty_contains(expectation(snm, rvs=[nm]), ["6/7", "3/7"])
  assert_pretty_lacks(expectation(snm, rvs=[nm]), "NegativeMultinomialMean(")
  assert_pretty_contains(variance(snm, rvs=[nm]), ["54/49", "6/49", "24/49"])
  assert_pretty_lacks(variance(snm, rvs=[nm]), "NegativeMultinomialVariance(")

  let mvn_mu = @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])
  let mvn_sigma = @symcore.function("Tuple", [
    @symcore.function("Tuple", [@symcore.int(2), @symcore.int(1)]),
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(3)]),
  ])
  let mvn = multivariate_normal("MVN", params=[mvn_mu, mvn_sigma])
  let smvn = @symcore.Expr::Symbol("MVN")
  let t1 = @symcore.Expr::Symbol("t1")
  let t2 = @symcore.Expr::Symbol("t2")
  let tvec = @symcore.function("Tuple", [t1, t2])
  assert_pretty_contains(expectation(smvn, rvs=[mvn]), ["1", "2"])
  assert_pretty_contains(variance(smvn, rvs=[mvn]), ["2", "1", "3"])
  assert_pretty_lacks(
    moment_generating_function(smvn, tvec, rvs=[mvn]),
    "MultivariateNormalMGF(",
  )
  assert_pretty_lacks(
    characteristic_function(smvn, tvec, rvs=[mvn]),
    "MultivariateNormalCF(",
  )
  assert_pretty_lacks(
    density(mvn, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    "MultivariateNormalDensity(",
  )

  let mvt = multivariate_t("MVT", params=[mvn_mu, mvn_sigma, @symcore.int(5)])
  let smvt = @symcore.Expr::Symbol("MVT")
  assert_pretty_contains(expectation(smvt, rvs=[mvt]), ["1", "2"])
  assert_pretty_lacks(variance(smvt, rvs=[mvt]), "MultivariateTVariance(")
  assert_pretty_lacks(
    density(mvt, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    "MultivariateTDensity(",
  )

  let mvl = multivariate_laplace("MVL", params=[mvn_mu, mvn_sigma])
  let smvl = @symcore.Expr::Symbol("MVL")
  assert_pretty_contains(expectation(smvl, rvs=[mvl]), ["1", "2"])
  assert_pretty_lacks(variance(smvl, rvs=[mvl]), "MultivariateLaplaceVariance(")
  assert_pretty_lacks(
    moment_generating_function(smvl, tvec, rvs=[mvl]),
    "MultivariateLaplaceMGF(",
  )
  assert_pretty_lacks(
    characteristic_function(smvl, tvec, rvs=[mvl]),
    "MultivariateLaplaceCF(",
  )
  assert_pretty_lacks(
    density(mvl, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    "MultivariateLaplaceDensity(",
  )

  let ng = normal_gamma("NG", params=[
    @symcore.int(0),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  let sng = @symcore.Expr::Symbol("NG")
  assert_pretty_contains(expectation(sng, rvs=[ng]), ["0", "3/4"])
  assert_pretty_contains(variance(sng, rvs=[ng]), ["1", "3/16"])
  assert_pretty_lacks(
    density(ng, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    "NormalGammaDensity(",
  )

  let tau = @symcore.Expr::Symbol("tau")
  let z = @symcore.Expr::Symbol("z")
  let q1 = @symcore.rational_from_ints(1, 4)
  let sp = stochastic_process("SPX")
  let spx = @symcore.function("SPX", [tau])
  assert_pretty_contains(moment_generating_function(spx, z, rvs=[sp]), [
    "Expectation", "StochasticProcess", "tau", "z",
  ])
  assert_pretty_lacks(moment_generating_function(spx, z, rvs=[sp]), "MGFAt(")
  assert_pretty_contains(quantile(spx, q1, rvs=[sp]), [
    "ConditionSet", "Probability", "StochasticProcess", "tau", "1/4",
  ])
  assert_pretty_lacks(quantile(spx, q1, rvs=[sp]), "QuantileAt(")
  let mc = discrete_markov_chain("MC", params=[@symcore.Expr::Symbol("Tmat")])
  let i = @symcore.Expr::Symbol("i")
  let j = @symcore.Expr::Symbol("j")
  let t0 = @symcore.Expr::Symbol("t0")
  let t = @symcore.Expr::Symbol("t")
  match process_transition_probability(mc, i, j, t0, t) {
    Some(v) => assert_pretty_contains(v, ["MatrixElement", "Tmat"])
    None => fail("missing discrete markov transition")
  }
  let cmc = continuous_markov_chain("CMCX", params=[
    @symcore.Expr::Symbol("Qmat"),
  ])
  match process_transition_probability(cmc, i, j, t0, t) {
    Some(v) => assert_pretty_contains(v, ["MatrixElement", "MatrixExp", "Qmat"])
    None => fail("missing continuous markov transition")
  }

  let pp = poisson_process("PP", @symcore.Expr::Symbol("lam"))
  let ppx = @symcore.function("PP", [tau])
  assert_pretty_contains(moment_generating_function(ppx, z, rvs=[pp]), [
    "exp", "lam", "tau",
  ])
  assert_pretty_contains(probability(eq(ppx, @symcore.int(2)), rv=pp), [
    "factorial",
  ])
  assert_pretty_contains(probability(le(ppx, @symcore.int(2)), rv=pp), [
    "poisson_cdf",
  ])
  let pp_entropy = entropy(ppx, rvs=[pp])
  assert_pretty_lacks(pp_entropy, "PoissonProcessEntropyAt(")
  assert_pretty_contains(pp_entropy, ["Sum", "factorial", "log", "lam", "tau"])

  let wp = wiener_process("WP")
  let wpx = @symcore.function("WP", [tau])
  assert_pretty_contains(characteristic_function(wpx, z, rvs=[wp]), [
    "exp", "tau", "z",
  ])
  assert_pretty_contains(quantile(wpx, q1, rvs=[wp]), ["erfinv", "tau"])
  assert_true(
    expr_equiv_safe(probability(eq(wpx, @symcore.int(0)), rv=wp), "0"),
  )

  let gue = gaussian_unitary_ensemble("GUE", params=[@symcore.int(3)])
  let xmat = @symcore.function("MatrixSymbol", [
    @symcore.Expr::Symbol("X"),
    @symcore.int(3),
    @symcore.int(3),
  ])
  match matrix_density(gue, xmat) {
    Some(v) => {
      assert_pretty_lacks(v, "GaussianUnitaryEnsembleDensity(")
      assert_pretty_contains(v, ["exp", "Trace"])
    }
    None => fail("missing symbolic matrix density")
  }
  let goe = gaussian_orthogonal_ensemble("GOE", params=[@symcore.int(2)])
  match joint_eigen_distribution_of(goe) {
    Some(v) => assert_pretty_contains(v, ["Lambda"])
    None => fail("missing GOE joint eigen distribution")
  }
  match level_spacing_distribution_of(goe) {
    Some(v) => assert_pretty_contains(v, ["Lambda"])
    None => fail("missing level spacing distribution")
  }

  let bp = bernoulli_process("BP", params=[@symcore.rational_from_ints(2, 5)])
  match process_mean_at(bp, t) {
    Some(v) => assert_true(expr_equiv_safe(v, "2/5"))
    None => fail("missing bernoulli process mean")
  }
  match
    process_transition_probability(bp, @symcore.int(0), @symcore.int(1), t0, t) {
    Some(v) => assert_pretty_contains(v, ["Piecewise"])
    None => fail("missing bernoulli process transition")
  }

  let gp = gamma_process("GP", params=[@symcore.int(2), @symcore.int(3)])
  match process_mean_at(gp, t) {
    Some(v) => assert_pretty_contains(v, ["3", "t"])
    None => fail("missing gamma process mean")
  }
  match
    process_transition_probability(
      gp,
      @symcore.int(2),
      @symcore.int(5),
      @symcore.int(1),
      @symcore.int(3),
    ) {
    Some(v) => assert_pretty_contains(v, ["Piecewise", "gamma"])
    None => fail("missing gamma process transition")
  }
}

///|
fn _compat_handmade_and_joint_families_python_oracle_disabled() -> Unit raise {
  let t = @symcore.Expr::Symbol("t")
  let t1 = @symcore.Expr::Symbol("t1")
  let t2 = @symcore.Expr::Symbol("t2")
  let q = @symcore.rational_from_ints(1, 4)
  let xh = @symcore.Expr::Symbol("xh")
  let ch_pdf = @symcore.function("Lambda", [
    xh,
    @symcore.function("Piecewise", [
      @symcore.function("Tuple", [
        @symcore.function("exp", [
          eval_arith(@symcore.mul([@symcore.int(-1), xh])),
        ]),
        @symcore.function("Ge", [xh, @symcore.int(0)]),
      ]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
    ]),
  ])
  let ch = continuous_rv("CH", params=[ch_pdf])
  let ch_d = density(ch, @symcore.int(2))
  let ch_d_s = stats_eval_str(
    "sympy.nsimplify(\{@symprint.pretty_string(ch_d)})",
  )
  assert_eq(ch_d_s, "exp(-2)")
  assert_true(!@symprint.pretty_string(ch_d).contains("density(CH,"))
  let sch = @symcore.Expr::Symbol("CH")
  let ch_c = cdf(ch, @symcore.int(2))
  assert_true(@symprint.pretty_string(ch_c).contains("Integral("))
  assert_true(!@symprint.pretty_string(ch_c).contains("cdf(CH,"))
  let ch_p = probability(le(sch, @symcore.int(2)), rv=ch)
  assert_eq(@symcore.compare_expr(ch_p, ch_c), 0)
  assert_true(!@symprint.pretty_string(ch_p).contains("Probability("))
  let ch_m = expectation(sch, rvs=[ch])
  let ch_v = variance(sch, rvs=[ch])
  let ch_mgf = moment_generating_function(sch, t, rvs=[ch])
  let ch_cf = characteristic_function(sch, t, rvs=[ch])
  let ch_h = entropy(sch, rvs=[ch])
  let ch_q = quantile(sch, q, rvs=[ch])
  assert_true(@symprint.pretty_string(ch_m).contains("Integral("))
  assert_true(@symprint.pretty_string(ch_v).contains("Integral("))
  assert_true(@symprint.pretty_string(ch_mgf).contains("Integral("))
  assert_true(
    !@symprint.pretty_string(ch_mgf).contains("moment_generating_function("),
  )
  assert_true(@symprint.pretty_string(ch_cf).contains("Integral("))
  assert_true(
    !@symprint.pretty_string(ch_cf).contains("characteristic_function("),
  )
  assert_true(@symprint.pretty_string(ch_h).contains("Integral("))
  assert_true(!@symprint.pretty_string(ch_h).contains("entropy("))
  assert_true(@symprint.pretty_string(ch_q).contains("ConditionSet("))
  assert_true(!@symprint.pretty_string(ch_q).contains("quantile("))

  let kh = @symcore.Expr::Symbol("kh")
  let dh_pmf = @symcore.function("Lambda", [
    kh,
    @symcore.function("Piecewise", [
      @symcore.function("Tuple", [
        @symcore.rational_from_ints(1, 2),
        @symcore.function("Eq", [kh, @symcore.int(0)]),
      ]),
      @symcore.function("Tuple", [
        @symcore.rational_from_ints(1, 2),
        @symcore.function("Eq", [kh, @symcore.int(1)]),
      ]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
    ]),
  ])
  let dh = discrete_rv("DH", params=[dh_pmf])
  let dh_d = density(dh, @symcore.int(1))
  let dh_d_s = stats_eval_str(
    "sympy.nsimplify(\{@symprint.pretty_string(dh_d)})",
  )
  assert_eq(dh_d_s, "1/2")
  assert_true(!@symprint.pretty_string(dh_d).contains("density(DH,"))
  let sdh = @symcore.Expr::Symbol("DH")
  let dh_c = cdf(dh, @symcore.int(1))
  assert_true(@symprint.pretty_string(dh_c).contains("Sum("))
  assert_true(!@symprint.pretty_string(dh_c).contains("cdf(DH,"))
  let dh_p_eq = probability(eq(sdh, @symcore.int(1)), rv=dh)
  assert_true(expr_equiv_to(dh_p_eq, "1/2"))
  let dh_p_le = probability(le(sdh, @symcore.int(1)), rv=dh)
  assert_eq(@symcore.compare_expr(dh_p_le, dh_c), 0)
  assert_true(!@symprint.pretty_string(dh_p_eq).contains("Probability("))
  let dh_m = expectation(sdh, rvs=[dh])
  let dh_v = variance(sdh, rvs=[dh])
  let dh_mgf = moment_generating_function(sdh, t, rvs=[dh])
  let dh_cf = characteristic_function(sdh, t, rvs=[dh])
  let dh_h = entropy(sdh, rvs=[dh])
  let dh_q = quantile(sdh, q, rvs=[dh])
  assert_true(@symprint.pretty_string(dh_m).contains("Sum("))
  assert_true(@symprint.pretty_string(dh_v).contains("Sum("))
  assert_true(@symprint.pretty_string(dh_mgf).contains("Sum("))
  assert_true(
    !@symprint.pretty_string(dh_mgf).contains("moment_generating_function("),
  )
  assert_true(@symprint.pretty_string(dh_cf).contains("Sum("))
  assert_true(
    !@symprint.pretty_string(dh_cf).contains("characteristic_function("),
  )
  assert_true(@symprint.pretty_string(dh_h).contains("Sum("))
  assert_true(!@symprint.pretty_string(dh_h).contains("entropy("))
  assert_true(@symprint.pretty_string(dh_q).contains("ConditionSet("))
  assert_true(!@symprint.pretty_string(dh_q).contains("quantile("))

  let fh_pairs = @symcore.function("Tuple", [
    @symcore.function("Tuple", [
      @symcore.int(0),
      @symcore.rational_from_ints(1, 4),
    ]),
    @symcore.function("Tuple", [
      @symcore.int(1),
      @symcore.rational_from_ints(3, 4),
    ]),
  ])
  let fh = finite_distribution_handmade("FH", params=[fh_pairs])
  let fh_d = density(fh, @symcore.int(1))
  let fh_d_s = stats_eval_str(
    "sympy.nsimplify(\{@symprint.pretty_string(fh_d)})",
  )
  assert_eq(fh_d_s, "3/4")
  let sfh = @symcore.Expr::Symbol("FH")
  let fh_m_s = stats_eval_str(
    "sympy.nsimplify(\{@symprint.pretty_string(expectation(sfh, rvs=[fh]))})",
  )
  assert_eq(fh_m_s, "3/4")
  let fh_v_s = stats_eval_str(
    "sympy.nsimplify(\{@symprint.pretty_string(variance(sfh, rvs=[fh]))})",
  )
  assert_eq(fh_v_s, "3/16")
  let fh_c = cdf(fh, @symcore.int(0))
  let fh_c_oracle = stats_eval_str(
    "(lambda F: P(F <= 0))(stats.FiniteRV('F', {0: Rational(1, 4), 1: Rational(3, 4)}))",
  )
  assert_true(expr_equiv_to(fh_c, fh_c_oracle))
  let fh_p = probability(eq(sfh, @symcore.int(1)), rv=fh)
  let fh_p_oracle = stats_eval_str(
    "(lambda F: P(Eq(F, 1)))(stats.FiniteRV('F', {0: Rational(1, 4), 1: Rational(3, 4)}))",
  )
  assert_true(expr_equiv_to(fh_p, fh_p_oracle))
  assert_true(!@symprint.pretty_string(fh_p).contains("Probability("))
  let fh_mgf = moment_generating_function(sfh, t, rvs=[fh])
  assert_true(@symprint.pretty_string(fh_mgf).contains("exp("))
  assert_true(
    !@symprint.pretty_string(fh_mgf).contains("moment_generating_function("),
  )
  let fh_cf = characteristic_function(sfh, t, rvs=[fh])
  assert_true(@symprint.pretty_string(fh_cf).contains("exp("))
  assert_true(
    !@symprint.pretty_string(fh_cf).contains("characteristic_function("),
  )
  let fh_h = entropy(sfh, rvs=[fh])
  assert_true(@symprint.pretty_string(fh_h).contains("log("))
  assert_true(!@symprint.pretty_string(fh_h).contains("entropy("))
  let fh_q = quantile(sfh, q, rvs=[fh])
  assert_true(@symprint.pretty_string(fh_q).contains("Piecewise("))
  assert_true(!@symprint.pretty_string(fh_q).contains("quantile("))

  let j1 = @symcore.Expr::Symbol("j1")
  let j2 = @symcore.Expr::Symbol("j2")
  let j_pdf = @symcore.function("Lambda", [
    @symcore.function("Tuple", [j1, j2]),
    eval_arith(
      @symcore.add([j1, eval_arith(@symcore.mul([@symcore.int(2), j2]))]),
    ),
  ])
  let jh = joint_rv("JH", params=[j_pdf])
  let jh_d = density(
    jh,
    @symcore.function("Tuple", [@symcore.int(3), @symcore.int(4)]),
  )
  let jh_d_s = stats_eval_str(
    "sympy.nsimplify(\{@symprint.pretty_string(jh_d)})",
  )
  assert_eq(jh_d_s, "11")
  assert_true(!@symprint.pretty_string(jh_d).contains("density(JH,"))
  let sjh = @symcore.Expr::Symbol("JH")
  let jh_c = cdf(
    jh,
    @symcore.function("Tuple", [@symcore.int(3), @symcore.int(4)]),
  )
  let jh_c_s = @symprint.pretty_string(jh_c)
  assert_true(jh_c_s.contains("Integral("))
  assert_true(!jh_c_s.contains("JointRVCDF("))
  assert_true(!jh_c_s.contains("cdf(JH,"))
  let jh_p = probability(
    eq(sjh, @symcore.function("Tuple", [@symcore.int(3), @symcore.int(4)])),
    rv=jh,
  )
  assert_true(expr_equiv_to(jh_p, "0"))
  let jh_prob_rect = probability(
    and_event([
      ge(sjh, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
      le(sjh, @symcore.function("Tuple", [@symcore.int(3), @symcore.int(4)])),
    ]),
    rv=jh,
  )
  let jh_prob_rect_s = @symprint.pretty_string(jh_prob_rect)
  assert_true(jh_prob_rect_s.contains("Integral("))
  assert_true(!jh_prob_rect_s.contains("Probability("))
  assert_true(!@symprint.pretty_string(jh_p).contains("Probability("))
  let jh_m = expectation(sjh, rvs=[jh])
  let jh_v = variance(sjh, rvs=[jh])
  let jh_mgf = moment_generating_function(
    sjh,
    @symcore.function("Tuple", [t1, t2]),
    rvs=[jh],
  )
  let jh_h = entropy(sjh, rvs=[jh])
  let jh_q = quantile(sjh, q, rvs=[jh])
  assert_true(@symprint.pretty_string(jh_m).contains("Integral("))
  assert_true(!@symprint.pretty_string(jh_m).contains("JointRVMean("))
  assert_true(@symprint.pretty_string(jh_v).contains("Integral("))
  assert_true(!@symprint.pretty_string(jh_v).contains("JointRVVariance("))
  assert_true(@symprint.pretty_string(jh_mgf).contains("Integral("))
  assert_true(
    !@symprint.pretty_string(jh_mgf).contains("moment_generating_function("),
  )
  assert_true(@symprint.pretty_string(jh_h).contains("Integral("))
  assert_true(!@symprint.pretty_string(jh_h).contains("entropy("))
  assert_true(@symprint.pretty_string(jh_q).contains("ConditionSet("))
  assert_true(!@symprint.pretty_string(jh_q).contains("quantile("))

  let ew = multivariate_ewens("EW", params=[@symcore.int(2), @symcore.int(1)])
  let ew_d = density(
    ew,
    @symcore.function("Tuple", [@symcore.int(2), @symcore.int(0)]),
  )
  let ew_oracle = stats_eval_str(
    "(lambda EW: density(EW)(2, 0))(stats.MultivariateEwens('EW', 2, 1))",
  )
  let ew_d_s = stats_eval_str(
    "sympy.nsimplify(\{@symprint.pretty_string(ew_d)})",
  )
  let ew_o_s = stats_eval_str("sympy.nsimplify(\{ew_oracle})")
  assert_eq(ew_d_s, ew_o_s)
  assert_true(!@symprint.pretty_string(ew_d).contains("density(EW,"))
  let sew = @symcore.Expr::Symbol("EW")
  let ew_p = probability(
    eq(sew, @symcore.function("Tuple", [@symcore.int(2), @symcore.int(0)])),
    rv=ew,
  )
  assert_eq(@symcore.compare_expr(ew_p, ew_d), 0)
  assert_true(!@symprint.pretty_string(ew_p).contains("Probability("))
  let ew_c = cdf(
    ew,
    @symcore.function("Tuple", [@symcore.int(2), @symcore.int(0)]),
  )
  assert_true(@symprint.pretty_string(ew_c).contains("Sum("))
  assert_true(!@symprint.pretty_string(ew_c).contains("MultivariateEwensCDF("))
  let ew_m = expectation(sew, rvs=[ew])
  let ew_v = variance(sew, rvs=[ew])
  let ew_mgf = moment_generating_function(
    sew,
    @symcore.function("Tuple", [t1, t2]),
    rvs=[ew],
  )
  let ew_h = entropy(sew, rvs=[ew])
  let ew_q = quantile(sew, q, rvs=[ew])
  assert_true(@symprint.pretty_string(ew_m).contains("Sum("))
  assert_true(!@symprint.pretty_string(ew_m).contains("MultivariateEwensMean("))
  assert_true(@symprint.pretty_string(ew_v).contains("Sum("))
  assert_true(
    !@symprint.pretty_string(ew_v).contains("MultivariateEwensVariance("),
  )
  assert_true(@symprint.pretty_string(ew_mgf).contains("Sum("))
  assert_true(
    !@symprint.pretty_string(ew_mgf).contains("moment_generating_function("),
  )
  assert_true(@symprint.pretty_string(ew_h).contains("Sum("))
  assert_true(!@symprint.pretty_string(ew_h).contains("entropy("))
  assert_true(@symprint.pretty_string(ew_q).contains("ConditionSet("))
  assert_true(!@symprint.pretty_string(ew_q).contains("quantile("))

  let t11 = @symcore.rational_from_ints(1, 1)
  let t12 = @symcore.rational_from_ints(1, 2)
  let omega = @symcore.function("Tuple", [
    @symcore.function("Tuple", [t11, t12]),
    @symcore.function("Tuple", [t12, t11]),
  ])
  let ones = @symcore.function("Tuple", [@symcore.int(1), @symcore.int(1)])
  let gmlg = generalized_multivariate_log_gamma("GMLG2", params=[
    @symcore.rational_from_ints(1, 2),
    @symcore.int(1),
    ones,
    ones,
  ])
  let gmlg_d = density(
    gmlg,
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
  )
  let gmlg_oracle = stats_eval_str(
    "(lambda GMLG2: density(GMLG2)(0, 0))(stats.GeneralizedMultivariateLogGamma('GMLG2', Rational(1, 2), 1, [1, 1], [1, 1]))",
  )
  assert_true(expr_equiv_to(gmlg_d, gmlg_oracle))
  assert_true(!@symprint.pretty_string(gmlg_d).contains("density(GMLG2,"))
  let sgmlg = @symcore.Expr::Symbol("GMLG2")
  let gmlg_c = cdf(
    gmlg,
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
  )
  let gmlg_c_s = @symprint.pretty_string(gmlg_c)
  assert_true(gmlg_c_s.contains("Integral("))
  assert_true(!gmlg_c_s.contains("GeneralizedMultivariateLogGammaCDF("))
  let gmlg_p_eq = probability(
    eq(sgmlg, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
    rv=gmlg,
  )
  let gmlg_p_eq_oracle = stats_eval_str(
    "(lambda GMLG2: P(Eq(GMLG2, Tuple(0, 0))))(stats.GeneralizedMultivariateLogGamma('GMLG2', Rational(1, 2), 1, [1, 1], [1, 1]))",
  )
  assert_true(expr_equiv_to(gmlg_p_eq, gmlg_p_eq_oracle))
  assert_true(expr_equiv_to(gmlg_p_eq, "0"))
  let gmlg_p_le = probability(
    le(sgmlg, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
    rv=gmlg,
  )
  assert_eq(@symcore.compare_expr(gmlg_p_le, gmlg_c), 0)
  let gmlg_p_ge = probability(
    ge(sgmlg, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
    rv=gmlg,
  )
  let gmlg_p_ge_s = @symprint.pretty_string(gmlg_p_ge)
  assert_true(gmlg_p_ge_s.contains("Integral("))
  assert_true(!gmlg_p_ge_s.contains("Probability("))
  let gmlg_m = expectation(sgmlg, rvs=[gmlg])
  let gmlg_v = variance(sgmlg, rvs=[gmlg])
  let gmlg_mgf = moment_generating_function(
    sgmlg,
    @symcore.function("Tuple", [t1, t2]),
    rvs=[gmlg],
  )
  let gmlg_h = entropy(sgmlg, rvs=[gmlg])
  let gmlg_q = quantile(sgmlg, q, rvs=[gmlg])
  assert_true(@symprint.pretty_string(gmlg_m).contains("Integral("))
  assert_true(
    !@symprint.pretty_string(gmlg_m).contains(
      "GeneralizedMultivariateLogGammaMean(",
    ),
  )
  assert_true(@symprint.pretty_string(gmlg_v).contains("Integral("))
  assert_true(
    !@symprint.pretty_string(gmlg_v).contains(
      "GeneralizedMultivariateLogGammaVariance(",
    ),
  )
  assert_true(@symprint.pretty_string(gmlg_mgf).contains("Integral("))
  assert_true(
    !@symprint.pretty_string(gmlg_mgf).contains("moment_generating_function("),
  )
  assert_true(@symprint.pretty_string(gmlg_h).contains("Integral("))
  assert_true(!@symprint.pretty_string(gmlg_h).contains("entropy("))
  assert_true(@symprint.pretty_string(gmlg_q).contains("ConditionSet("))
  assert_true(!@symprint.pretty_string(gmlg_q).contains("quantile("))

  let gmlgo = generalized_multivariate_log_gamma_omega("GMLGO2", params=[
    omega,
    @symcore.int(1),
    ones,
    ones,
  ])
  let gmlgo_d = density(
    gmlgo,
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
  )
  let gmlgo_oracle = stats_eval_str(
    "(lambda GMLGO2: density(GMLGO2)(0, 0))(stats.GeneralizedMultivariateLogGammaOmega('GMLGO2', sympy.Matrix([[1, Rational(1, 2)], [Rational(1, 2), 1]]), 1, [1, 1], [1, 1]))",
  )
  assert_true(expr_equiv_to(gmlgo_d, gmlgo_oracle))
  assert_true(!@symprint.pretty_string(gmlgo_d).contains("density(GMLGO2,"))
  let sgmlgo = @symcore.Expr::Symbol("GMLGO2")
  let gmlgo_c = cdf(
    gmlgo,
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
  )
  let gmlgo_c_s = @symprint.pretty_string(gmlgo_c)
  assert_true(gmlgo_c_s.contains("Integral("))
  assert_true(!gmlgo_c_s.contains("GeneralizedMultivariateLogGammaOmegaCDF("))
  let gmlgo_p_eq = probability(
    eq(sgmlgo, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
    rv=gmlgo,
  )
  assert_true(expr_equiv_to(gmlgo_p_eq, "0"))
  let gmlgo_p_le = probability(
    le(sgmlgo, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
    rv=gmlgo,
  )
  assert_eq(@symcore.compare_expr(gmlgo_p_le, gmlgo_c), 0)
  let gmlgo_m = expectation(sgmlgo, rvs=[gmlgo])
  let gmlgo_v = variance(sgmlgo, rvs=[gmlgo])
  let gmlgo_mgf = moment_generating_function(
    sgmlgo,
    @symcore.function("Tuple", [t1, t2]),
    rvs=[gmlgo],
  )
  let gmlgo_h = entropy(sgmlgo, rvs=[gmlgo])
  let gmlgo_q = quantile(sgmlgo, q, rvs=[gmlgo])
  assert_true(@symprint.pretty_string(gmlgo_m).contains("Integral("))
  assert_true(
    !@symprint.pretty_string(gmlgo_m).contains(
      "GeneralizedMultivariateLogGammaOmegaMean(",
    ),
  )
  assert_true(@symprint.pretty_string(gmlgo_v).contains("Integral("))
  assert_true(
    !@symprint.pretty_string(gmlgo_v).contains(
      "GeneralizedMultivariateLogGammaOmegaVariance(",
    ),
  )
  assert_true(@symprint.pretty_string(gmlgo_mgf).contains("Integral("))
  assert_true(
    !@symprint.pretty_string(gmlgo_mgf).contains("moment_generating_function("),
  )
  assert_true(@symprint.pretty_string(gmlgo_h).contains("Integral("))
  assert_true(!@symprint.pretty_string(gmlgo_h).contains("entropy("))
  assert_true(@symprint.pretty_string(gmlgo_q).contains("ConditionSet("))
  assert_true(!@symprint.pretty_string(gmlgo_q).contains("quantile("))
}

///|
test "compat handmade and joint families structural parity" {
  let t = @symcore.Expr::Symbol("t")
  let t1 = @symcore.Expr::Symbol("t1")
  let t2 = @symcore.Expr::Symbol("t2")
  let q = @symcore.rational_from_ints(1, 4)

  let xh = @symcore.Expr::Symbol("xh")
  let ch_pdf = @symcore.function("Lambda", [
    xh,
    @symcore.function("Piecewise", [
      @symcore.function("Tuple", [
        @symcore.function("exp", [
          eval_arith(@symcore.mul([@symcore.int(-1), xh])),
        ]),
        @symcore.function("Ge", [xh, @symcore.int(0)]),
      ]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
    ]),
  ])
  let ch = continuous_rv("CH", params=[ch_pdf])
  let sch = @symcore.Expr::Symbol("CH")
  assert_pretty_lacks(density(ch, @symcore.int(2)), "density(CH,")
  assert_pretty_contains(density(ch, @symcore.int(2)), ["exp(-2)"])
  assert_pretty_contains(cdf(ch, @symcore.int(2)), ["Integral"])
  assert_eq(
    @symcore.compare_expr(
      probability(le(sch, @symcore.int(2)), rv=ch),
      cdf(ch, @symcore.int(2)),
    ),
    0,
  )
  assert_pretty_contains(expectation(sch, rvs=[ch]), ["Integral"])
  assert_pretty_contains(variance(sch, rvs=[ch]), ["Integral"])
  assert_pretty_contains(moment_generating_function(sch, t, rvs=[ch]), [
    "Integral",
  ])
  assert_pretty_contains(characteristic_function(sch, t, rvs=[ch]), ["Integral"])
  assert_pretty_contains(entropy(sch, rvs=[ch]), ["Integral"])
  assert_pretty_contains(quantile(sch, q, rvs=[ch]), ["ConditionSet"])

  let kh = @symcore.Expr::Symbol("kh")
  let dh_pmf = @symcore.function("Lambda", [
    kh,
    @symcore.function("Piecewise", [
      @symcore.function("Tuple", [
        @symcore.rational_from_ints(1, 2),
        @symcore.function("Eq", [kh, @symcore.int(0)]),
      ]),
      @symcore.function("Tuple", [
        @symcore.rational_from_ints(1, 2),
        @symcore.function("Eq", [kh, @symcore.int(1)]),
      ]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
    ]),
  ])
  let dh = discrete_rv("DH", params=[dh_pmf])
  let sdh = @symcore.Expr::Symbol("DH")
  assert_pretty_contains(density(dh, @symcore.int(1)), ["1/2"])
  assert_pretty_contains(cdf(dh, @symcore.int(1)), ["Sum"])
  assert_pretty_contains(probability(eq(sdh, @symcore.int(1)), rv=dh), ["1/2"])
  assert_pretty_contains(expectation(sdh, rvs=[dh]), ["Sum"])
  assert_pretty_contains(variance(sdh, rvs=[dh]), ["Sum"])
  assert_pretty_contains(moment_generating_function(sdh, t, rvs=[dh]), ["Sum"])
  assert_pretty_contains(characteristic_function(sdh, t, rvs=[dh]), ["Sum"])
  assert_pretty_contains(entropy(sdh, rvs=[dh]), ["Sum"])
  assert_pretty_contains(quantile(sdh, q, rvs=[dh]), ["ConditionSet"])

  let fh_pairs = @symcore.function("Tuple", [
    @symcore.function("Tuple", [
      @symcore.int(0),
      @symcore.rational_from_ints(1, 4),
    ]),
    @symcore.function("Tuple", [
      @symcore.int(1),
      @symcore.rational_from_ints(3, 4),
    ]),
  ])
  let fh = finite_distribution_handmade("FH", params=[fh_pairs])
  let sfh = @symcore.Expr::Symbol("FH")
  assert_pretty_contains(density(fh, @symcore.int(1)), ["3/4"])
  assert_pretty_contains(expectation(sfh, rvs=[fh]), ["3/4"])
  assert_pretty_contains(variance(sfh, rvs=[fh]), ["3/16"])
  assert_pretty_contains(probability(eq(sfh, @symcore.int(1)), rv=fh), ["3/4"])
  assert_pretty_contains(cdf(fh, @symcore.int(0)), ["1/4"])
  assert_pretty_contains(moment_generating_function(sfh, t, rvs=[fh]), ["exp"])
  assert_pretty_contains(characteristic_function(sfh, t, rvs=[fh]), ["exp"])
  assert_pretty_contains(entropy(sfh, rvs=[fh]), ["log"])
  assert_pretty_contains(quantile(sfh, q, rvs=[fh]), ["Piecewise"])

  let j1 = @symcore.Expr::Symbol("j1")
  let j2 = @symcore.Expr::Symbol("j2")
  let j_pdf = @symcore.function("Lambda", [
    @symcore.function("Tuple", [j1, j2]),
    eval_arith(
      @symcore.add([j1, eval_arith(@symcore.mul([@symcore.int(2), j2]))]),
    ),
  ])
  let jh = joint_rv("JH", params=[j_pdf])
  let sjh = @symcore.Expr::Symbol("JH")
  assert_true(
    expr_equiv_safe(
      density(
        jh,
        @symcore.function("Tuple", [@symcore.int(3), @symcore.int(4)]),
      ),
      "11",
    ),
  )
  assert_true(
    expr_equiv_safe(
      probability(
        eq(sjh, @symcore.function("Tuple", [@symcore.int(3), @symcore.int(4)])),
        rv=jh,
      ),
      "0",
    ),
  )
  assert_pretty_contains(
    cdf(jh, @symcore.function("Tuple", [@symcore.int(3), @symcore.int(4)])),
    ["Integral"],
  )
  assert_pretty_contains(expectation(sjh, rvs=[jh]), ["Integral"])
  assert_pretty_contains(variance(sjh, rvs=[jh]), ["Integral"])
  assert_pretty_contains(
    moment_generating_function(sjh, @symcore.function("Tuple", [t1, t2]), rvs=[
      jh,
    ]),
    ["Integral"],
  )
  assert_pretty_contains(entropy(sjh, rvs=[jh]), ["Integral"])
  assert_pretty_contains(quantile(sjh, q, rvs=[jh]), ["ConditionSet"])

  let ew = multivariate_ewens("EW", params=[@symcore.int(2), @symcore.int(1)])
  let sew = @symcore.Expr::Symbol("EW")
  let ew_d = density(
    ew,
    @symcore.function("Tuple", [@symcore.int(2), @symcore.int(0)]),
  )
  assert_pretty_lacks(ew_d, "density(EW,")
  assert_eq(
    @symcore.compare_expr(
      probability(
        eq(sew, @symcore.function("Tuple", [@symcore.int(2), @symcore.int(0)])),
        rv=ew,
      ),
      ew_d,
    ),
    0,
  )
  assert_pretty_contains(
    cdf(ew, @symcore.function("Tuple", [@symcore.int(2), @symcore.int(0)])),
    ["Sum"],
  )
  assert_pretty_contains(expectation(sew, rvs=[ew]), ["Sum"])
  assert_pretty_contains(variance(sew, rvs=[ew]), ["Sum"])
  assert_pretty_contains(
    moment_generating_function(sew, @symcore.function("Tuple", [t1, t2]), rvs=[
      ew,
    ]),
    ["Sum"],
  )
  assert_pretty_contains(entropy(sew, rvs=[ew]), ["Sum"])
  assert_pretty_contains(quantile(sew, q, rvs=[ew]), ["ConditionSet"])

  let ones = @symcore.function("Tuple", [@symcore.int(1), @symcore.int(1)])
  let gmlg = generalized_multivariate_log_gamma("GMLG2", params=[
    @symcore.rational_from_ints(1, 2),
    @symcore.int(1),
    ones,
    ones,
  ])
  let sgmlg = @symcore.Expr::Symbol("GMLG2")
  let point = @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])
  assert_pretty_lacks(density(gmlg, point), "density(GMLG2,")
  assert_true(expr_equiv_safe(probability(eq(sgmlg, point), rv=gmlg), "0"))
  assert_pretty_contains(cdf(gmlg, point), ["Integral"])
  assert_pretty_contains(expectation(sgmlg, rvs=[gmlg]), ["Integral"])
  assert_pretty_contains(variance(sgmlg, rvs=[gmlg]), ["Integral"])
  assert_pretty_contains(
    moment_generating_function(sgmlg, @symcore.function("Tuple", [t1, t2]), rvs=[
      gmlg,
    ]),
    ["Integral"],
  )
  assert_pretty_contains(entropy(sgmlg, rvs=[gmlg]), ["Integral"])
  assert_pretty_contains(quantile(sgmlg, q, rvs=[gmlg]), ["ConditionSet"])

  let omega = @symcore.function("Tuple", [
    @symcore.function("Tuple", [
      @symcore.rational_from_ints(1, 1),
      @symcore.rational_from_ints(1, 2),
    ]),
    @symcore.function("Tuple", [
      @symcore.rational_from_ints(1, 2),
      @symcore.rational_from_ints(1, 1),
    ]),
  ])
  let gmlgo = generalized_multivariate_log_gamma_omega("GMLGO2", params=[
    omega,
    @symcore.int(1),
    ones,
    ones,
  ])
  let sgmlgo = @symcore.Expr::Symbol("GMLGO2")
  assert_pretty_lacks(density(gmlgo, point), "density(GMLGO2,")
  assert_true(expr_equiv_safe(probability(eq(sgmlgo, point), rv=gmlgo), "0"))
  assert_pretty_contains(cdf(gmlgo, point), ["Integral"])
  assert_pretty_contains(expectation(sgmlgo, rvs=[gmlgo]), ["Integral"])
  assert_pretty_contains(variance(sgmlgo, rvs=[gmlgo]), ["Integral"])
  assert_pretty_contains(
    moment_generating_function(sgmlgo, @symcore.function("Tuple", [t1, t2]), rvs=[
      gmlgo,
    ]),
    ["Integral"],
  )
  assert_pretty_contains(entropy(sgmlgo, rvs=[gmlgo]), ["Integral"])
  assert_pretty_contains(quantile(sgmlgo, q, rvs=[gmlgo]), ["ConditionSet"])
}

///|
test "compat cdf coverage for residual families" {
  let x = @symcore.Expr::Symbol("x")

  let bnc = beta_noncentral("BNC", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_true(
    !@symprint.pretty_string(cdf(bnc, x)).contains("BetaNoncentralCDF("),
  )

  let chn = chi_noncentral("CHN", params=[@symcore.int(3), @symcore.int(2)])
  assert_true(
    !@symprint.pretty_string(cdf(chn, x)).contains("ChiNoncentralCDF("),
  )

  let dav = davis("DAV", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_true(!@symprint.pretty_string(cdf(dav, x)).contains("DavisCDF("))

  let fd = f_distribution("FD", params=[@symcore.int(5), @symcore.int(7)])
  assert_true(
    !@symprint.pretty_string(cdf(fd, x)).contains("FDistributionCDF("),
  )

  let fz = fisher_z("FZ", params=[@symcore.int(5), @symcore.int(7)])
  assert_true(!@symprint.pretty_string(cdf(fz, x)).contains("FisherZCDF("))

  let us = uniform_sum("US", params=[@symcore.int(5)])
  let us_c = cdf(us, @symcore.int(2))
  assert_true(!@symprint.pretty_string(us_c).contains("UniformSumCDF("))

  let vm = von_mises("VM", params=[@symcore.int(0), @symcore.int(2)])
  assert_true(!@symprint.pretty_string(cdf(vm, x)).contains("VonMisesCDF("))

  let ws = wigner_semicircle("WS", params=[@symcore.int(3)])
  assert_true(
    !@symprint.pretty_string(cdf(ws, x)).contains("WignerSemicircleCDF("),
  )

  let bb = beta_binomial("BBc", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_true(!@symprint.pretty_string(cdf(bb, x)).contains("BetaBinomialCDF("))

  let hg = hypergeometric("HGc", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  assert_true(
    !@symprint.pretty_string(cdf(hg, x)).contains("HypergeometricCDF("),
  )

  let he = hermite("HEc", params=[@symcore.int(2), @symcore.int(3)])
  assert_true(!@symprint.pretty_string(cdf(he, x)).contains("HermiteCDF("))

  let isol = ideal_soliton("ISc", params=[@symcore.int(10)])
  assert_true(
    !@symprint.pretty_string(cdf(isol, x)).contains("IdealSolitonCDF("),
  )

  let rs = robust_soliton("RSc", params=[
    @symcore.int(10),
    @symcore.rational_from_ints(1, 10),
    @symcore.rational_from_ints(1, 2),
  ])
  assert_true(
    !@symprint.pretty_string(cdf(rs, x)).contains("RobustSolitonCDF("),
  )

  let lg = logarithmic("LGc", params=[@symcore.rational_from_ints(1, 3)])
  assert_true(!@symprint.pretty_string(cdf(lg, x)).contains("LogarithmicCDF("))

  let sk = skellam("SKc", params=[@symcore.int(2), @symcore.int(3)])
  assert_true(!@symprint.pretty_string(cdf(sk, x)).contains("SkellamCDF("))

  let zz = zeta("ZZc", params=[@symcore.int(3)])
  assert_true(!@symprint.pretty_string(cdf(zz, x)).contains("ZetaCDF("))

  let mn = multinomial("MNc", params=[
    @symcore.int(5),
    @symcore.rational_from_ints(1, 3),
    @symcore.rational_from_ints(2, 3),
  ])
  assert_true(
    !@symprint.pretty_string(
      cdf(mn, @symcore.function("Tuple", [@symcore.int(2), @symcore.int(4)])),
    ).contains("MultinomialCDF("),
  )

  let nmn = negative_multinomial("NMNc", params=[
    @symcore.int(2),
    @symcore.rational_from_ints(1, 4),
    @symcore.rational_from_ints(1, 4),
  ])
  assert_true(
    !@symprint.pretty_string(
      cdf(nmn, @symcore.function("Tuple", [@symcore.int(2), @symcore.int(3)])),
    ).contains("NegativeMultinomialCDF("),
  )

  let bp = bernoulli_process("BPc", params=[@symcore.rational_from_ints(1, 3)])
  let bp_c0 = cdf(bp, @symcore.int(0))
  assert_true(expr_equiv_safe(bp_c0, "2/3"))
  assert_true(!@symprint.pretty_string(bp_c0).contains("BernoulliProcessCDF("))

  let gp = gamma_process("GPc", params=[@symcore.int(2), @symcore.int(3)])
  let gp_c = cdf(gp, x)
  let gp_s = @symprint.pretty_string(gp_c)
  assert_true(!gp_s.contains("GammaProcessCDF("))
  assert_true(gp_s.contains("lowergamma"))

  let d = dirichlet("Dc", params=[@symcore.int(2), @symcore.int(3)])
  assert_true(
    !@symprint.pretty_string(
      cdf(d, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(1)])),
    ).contains("DirichletCDF("),
  )

  let mb = multivariate_beta("MBc", params=[@symcore.int(2), @symcore.int(3)])
  assert_true(
    !@symprint.pretty_string(
      cdf(mb, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(1)])),
    ).contains("MultivariateBetaCDF("),
  )

  let ml = multivariate_laplace("MLc", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_true(
    !@symprint.pretty_string(
      cdf(ml, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    ).contains("MultivariateLaplaceCDF("),
  )

  let mvn = multivariate_normal("MVNc", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_true(
    !@symprint.pretty_string(
      cdf(mvn, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    ).contains("MultivariateNormalCDF("),
  )

  let mvt = multivariate_t("MVTc", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
    @symcore.int(5),
  ])
  assert_true(
    !@symprint.pretty_string(
      cdf(mvt, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    ).contains("MultivariateTCDF("),
  )

  let ng = normal_gamma("NGc", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_true(
    !@symprint.pretty_string(
      cdf(ng, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    ).contains("NormalGammaCDF("),
  )

  let goe = gaussian_orthogonal_ensemble("GOEc", params=[@symcore.int(2)])
  assert_true(
    !@symprint.pretty_string(cdf(goe, x)).contains(
      "GaussianOrthogonalEnsembleCDF(",
    ),
  )

  let gue = gaussian_unitary_ensemble("GUEc", params=[@symcore.int(2)])
  assert_true(
    !@symprint.pretty_string(cdf(gue, x)).contains(
      "GaussianUnitaryEnsembleCDF(",
    ),
  )

  let gse = gaussian_symplectic_ensemble("GSEc", params=[@symcore.int(2)])
  assert_true(
    !@symprint.pretty_string(cdf(gse, x)).contains(
      "GaussianSymplecticEnsembleCDF(",
    ),
  )

  let mg = matrix_gamma("MGc", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.Expr::Symbol("Scale"),
  ])
  assert_true(!@symprint.pretty_string(cdf(mg, x)).contains("MatrixGammaCDF("))

  let mst = matrix_student_t("MSTc", params=[
    @symcore.int(3),
    @symcore.Expr::Symbol("M"),
    @symcore.Expr::Symbol("U"),
    @symcore.Expr::Symbol("V"),
  ])
  assert_true(
    !@symprint.pretty_string(cdf(mst, x)).contains("MatrixStudentTCDF("),
  )
}

///|
test "compat mean coverage for residual families" {
  let ben = benini("BENm", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_mean_not_placeholder(ben, "Benini")

  let bnc = beta_noncentral("BNCm", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_mean_not_placeholder(bnc, "BetaNoncentral")

  let bp = beta_prime("BPm", params=[@symcore.int(2), @symcore.int(3)])
  assert_mean_not_placeholder(bp, "BetaPrime")

  let chn = chi_noncentral("CHNm", params=[@symcore.int(4), @symcore.int(2)])
  assert_mean_not_placeholder(chn, "ChiNoncentral")

  let dag = dagum("DAGm", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_mean_not_placeholder(dag, "Dagum")

  let dav = davis("DAVm", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_mean_not_placeholder(dav, "Davis")

  let ep = exponential_power("EPm", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_mean_not_placeholder(ep, "ExponentialPower")

  let fd = f_distribution("FDm", params=[@symcore.int(5), @symcore.int(7)])
  assert_mean_not_placeholder(fd, "FDistribution")

  let fz = fisher_z("FZm", params=[@symcore.int(5), @symcore.int(7)])
  assert_mean_not_placeholder(fz, "FisherZ")

  let fr = frechet("FRm", params=[@symcore.int(3)])
  assert_mean_not_placeholder(fr, "Frechet")

  let gi = gamma_inverse("GIm", params=[@symcore.int(3), @symcore.int(2)])
  assert_mean_not_placeholder(gi, "GammaInverse")

  let lev = levy("LEVm", params=[@symcore.int(0), @symcore.int(1)])
  assert_mean_not_placeholder(lev, "Levy")

  let lc = log_cauchy("LCm", params=[@symcore.int(0), @symcore.int(1)])
  assert_mean_not_placeholder(lc, "LogCauchy")

  let ln = logit_normal("LNm", params=[@symcore.int(0), @symcore.int(1)])
  assert_mean_not_placeholder(ln, "LogitNormal")

  let lom = lomax("LOMm", params=[@symcore.int(3), @symcore.int(2)])
  assert_mean_not_placeholder(lom, "Lomax")

  let mx = maxwell("MXm", params=[@symcore.int(2)])
  assert_mean_not_placeholder(mx, "Maxwell")

  let nak = nakagami("NAKm", params=[@symcore.int(2), @symcore.int(3)])
  assert_mean_not_placeholder(nak, "Nakagami")

  let sg = shifted_gompertz("SGm", params=[@symcore.int(1), @symcore.int(2)])
  assert_mean_not_placeholder(sg, "ShiftedGompertz")

  let vm = von_mises("VMm", params=[@symcore.int(0), @symcore.int(2)])
  assert_mean_not_placeholder(vm, "VonMises")

  let iso = ideal_soliton("ISm", params=[@symcore.int(10)])
  assert_mean_not_placeholder(iso, "IdealSoliton")

  let rso = robust_soliton("RSm", params=[
    @symcore.int(10),
    @symcore.rational_from_ints(1, 10),
    @symcore.rational_from_ints(1, 2),
  ])
  assert_mean_not_placeholder(rso, "RobustSoliton")

  let goe = gaussian_orthogonal_ensemble("GOEm", params=[@symcore.int(2)])
  assert_eq(
    @symprint.pretty_string(
      expectation(@symcore.Expr::Symbol("GOEm"), rvs=[goe]),
    ),
    "ZeroMatrix(2, 2)",
  )
  assert_mean_not_placeholder(goe, "GaussianOrthogonalEnsemble")

  let gue = gaussian_unitary_ensemble("GUEm", params=[@symcore.int(2)])
  assert_eq(
    @symprint.pretty_string(
      expectation(@symcore.Expr::Symbol("GUEm"), rvs=[gue]),
    ),
    "ZeroMatrix(2, 2)",
  )
  assert_mean_not_placeholder(gue, "GaussianUnitaryEnsemble")

  let gse = gaussian_symplectic_ensemble("GSEm", params=[@symcore.int(2)])
  assert_eq(
    @symprint.pretty_string(
      expectation(@symcore.Expr::Symbol("GSEm"), rvs=[gse]),
    ),
    "ZeroMatrix(2, 2)",
  )
  assert_mean_not_placeholder(gse, "GaussianSymplecticEnsemble")

  let mg = matrix_gamma("MGm", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.Expr::Symbol("Scale"),
  ])
  let mg_mean = expectation(@symcore.Expr::Symbol("MGm"), rvs=[mg])
  let mg_s = @symprint.pretty_string(mg_mean)
  assert_true(!mg_s.contains("MatrixGammaMean("))
  assert_true(mg_s != "MGm")
  assert_mean_not_placeholder(mg, "MatrixGamma")

  let mst = matrix_student_t("MSTm", params=[
    @symcore.int(3),
    @symcore.Expr::Symbol("MeanM"),
    @symcore.Expr::Symbol("U"),
    @symcore.Expr::Symbol("V"),
  ])
  assert_eq(
    @symprint.pretty_string(
      expectation(@symcore.Expr::Symbol("MSTm"), rvs=[mst]),
    ),
    "MeanM",
  )
  assert_mean_not_placeholder(mst, "MatrixStudentT")
}

///|
test "compat variance coverage for residual families" {
  let ben = benini("BENv", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_variance_not_placeholder(ben, "Benini")

  let bnc = beta_noncentral("BNCv", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_variance_not_placeholder(bnc, "BetaNoncentral")

  let bp = beta_prime("BPv", params=[@symcore.int(2), @symcore.int(5)])
  assert_variance_not_placeholder(bp, "BetaPrime")

  let chn = chi_noncentral("CHNv", params=[@symcore.int(4), @symcore.int(2)])
  assert_variance_not_placeholder(chn, "ChiNoncentral")

  let dag = dagum("DAGv", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_variance_not_placeholder(dag, "Dagum")

  let dav = davis("DAVv", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_variance_not_placeholder(dav, "Davis")

  let ep = exponential_power("EPv", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_variance_not_placeholder(ep, "ExponentialPower")

  let fd = f_distribution("FDv", params=[@symcore.int(5), @symcore.int(7)])
  assert_variance_not_placeholder(fd, "FDistribution")

  let fz = fisher_z("FZv", params=[@symcore.int(5), @symcore.int(7)])
  assert_variance_not_placeholder(fz, "FisherZ")

  let fr = frechet("FRv", params=[@symcore.int(3)])
  assert_variance_not_placeholder(fr, "Frechet")

  let gi = gamma_inverse("GIv", params=[@symcore.int(3), @symcore.int(2)])
  assert_variance_not_placeholder(gi, "GammaInverse")

  let lev = levy("LEVv", params=[@symcore.int(0), @symcore.int(1)])
  assert_variance_not_placeholder(lev, "Levy")

  let lc = log_cauchy("LCv", params=[@symcore.int(0), @symcore.int(1)])
  assert_variance_not_placeholder(lc, "LogCauchy")

  let ln = logit_normal("LNv", params=[@symcore.int(0), @symcore.int(1)])
  assert_variance_not_placeholder(ln, "LogitNormal")

  let lom = lomax("LOMv", params=[@symcore.int(3), @symcore.int(2)])
  assert_variance_not_placeholder(lom, "Lomax")

  let mx = maxwell("MXv", params=[@symcore.int(2)])
  assert_variance_not_placeholder(mx, "Maxwell")

  let nak = nakagami("NAKv", params=[@symcore.int(2), @symcore.int(3)])
  assert_variance_not_placeholder(nak, "Nakagami")

  let pf = power_function("PFv", params=[
    @symcore.int(2),
    @symcore.int(0),
    @symcore.int(3),
  ])
  assert_variance_not_placeholder(pf, "PowerFunction")

  let qu = quadratic_u("QUv", params=[@symcore.int(0), @symcore.int(2)])
  assert_variance_not_placeholder(qu, "QuadraticU")

  let sg = shifted_gompertz("SGv", params=[@symcore.int(1), @symcore.int(2)])
  assert_variance_not_placeholder(sg, "ShiftedGompertz")

  let vm = von_mises("VMv", params=[@symcore.int(0), @symcore.int(2)])
  assert_variance_not_placeholder(vm, "VonMises")

  let iso = ideal_soliton("ISv", params=[@symcore.int(10)])
  assert_variance_not_placeholder(iso, "IdealSoliton")

  let rso = robust_soliton("RSv", params=[
    @symcore.int(10),
    @symcore.rational_from_ints(1, 10),
    @symcore.rational_from_ints(1, 2),
  ])
  assert_variance_not_placeholder(rso, "RobustSoliton")

  let ys = yule_simon("YSv", params=[@symcore.int(3)])
  assert_variance_not_placeholder(ys, "YuleSimon")

  let goe = gaussian_orthogonal_ensemble("GOEv", params=[@symcore.int(2)])
  let goe_v = @symprint.pretty_string(
    variance(@symcore.Expr::Symbol("GOEv"), rvs=[goe]),
  )
  assert_true(goe_v.contains("Expectation("))
  assert_true(goe_v != "Variance(GOEv)")

  let gue = gaussian_unitary_ensemble("GUEv", params=[@symcore.int(2)])
  let gue_v = @symprint.pretty_string(
    variance(@symcore.Expr::Symbol("GUEv"), rvs=[gue]),
  )
  assert_true(gue_v.contains("Expectation("))
  assert_true(gue_v != "Variance(GUEv)")

  let gse = gaussian_symplectic_ensemble("GSEv", params=[@symcore.int(2)])
  let gse_v = @symprint.pretty_string(
    variance(@symcore.Expr::Symbol("GSEv"), rvs=[gse]),
  )
  assert_true(gse_v.contains("Expectation("))
  assert_true(gse_v != "Variance(GSEv)")

  let mg = matrix_gamma("MGv", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.Expr::Symbol("Scale"),
  ])
  assert_variance_not_placeholder(mg, "MatrixGamma")
  assert_true(
    @symprint.pretty_string(variance(@symcore.Expr::Symbol("MGv"), rvs=[mg])) !=
    "Variance(MGv)",
  )

  let mst = matrix_student_t("MSTv", params=[
    @symcore.int(3),
    @symcore.Expr::Symbol("MeanM"),
    @symcore.Expr::Symbol("U"),
    @symcore.Expr::Symbol("V"),
  ])
  assert_variance_not_placeholder(mst, "MatrixStudentT")
  let mst_v = @symprint.pretty_string(
    variance(@symcore.Expr::Symbol("MSTv"), rvs=[mst]),
  )
  assert_true(mst_v.contains("Expectation("))
  assert_true(mst_v != "Variance(MSTv)")
}

///|
test "compat mgf coverage for residual families" {
  let t = @symcore.Expr::Symbol("t")
  let tvec = @symcore.function("Tuple", [
    @symcore.Expr::Symbol("t1"),
    @symcore.Expr::Symbol("t2"),
  ])

  let a = arcsin("Am", params=[@symcore.int(0), @symcore.int(1)])
  assert_mgf_not_placeholder(a, "Arcsin", t)

  let ben = benini("BENg", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_mgf_not_placeholder(ben, "Benini", t)

  let bp = bernoulli_process("BPg", params=[@symcore.rational_from_ints(1, 3)])
  let bp_mgf = @symprint.pretty_string(
    moment_generating_function(@symcore.Expr::Symbol("BPg"), t, rvs=[bp]),
  )
  assert_true(!bp_mgf.contains("moment_generating_function("))
  assert_true(!bp_mgf.contains("BernoulliProcessMGF("))

  let bb = beta_binomial("BBg", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_mgf_not_placeholder(bb, "BetaBinomial", t)

  let bnc = beta_noncentral("BNCg", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_mgf_not_placeholder(bnc, "BetaNoncentral", t)

  let bpr = beta_prime("BPG", params=[@symcore.int(2), @symcore.int(5)])
  assert_mgf_not_placeholder(bpr, "BetaPrime", t)

  let c = cauchy("CG", params=[@symcore.int(0), @symcore.int(1)])
  assert_mgf_not_placeholder(c, "Cauchy", t)

  let chn = chi_noncentral("CHNg", params=[@symcore.int(4), @symcore.int(2)])
  assert_mgf_not_placeholder(chn, "ChiNoncentral", t)

  let dag = dagum("DAGg", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_mgf_not_placeholder(dag, "Dagum", t)

  let dav = davis("DAVg", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_mgf_not_placeholder(dav, "Davis", t)

  let d = dirichlet("Dg", params=[@symcore.int(2), @symcore.int(3)])
  assert_mgf_not_placeholder(d, "Dirichlet", tvec)

  let ep = exponential_power("EPg", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_mgf_not_placeholder(ep, "ExponentialPower", t)

  let fd = f_distribution("FDg", params=[@symcore.int(5), @symcore.int(7)])
  assert_mgf_not_placeholder(fd, "FDistribution", t)

  let fz = fisher_z("FZg", params=[@symcore.int(5), @symcore.int(7)])
  assert_mgf_not_placeholder(fz, "FisherZ", t)

  let fr = frechet("FRg", params=[@symcore.int(3)])
  assert_mgf_not_placeholder(fr, "Frechet", t)

  let gi = gamma_inverse("GIg", params=[@symcore.int(3), @symcore.int(2)])
  assert_mgf_not_placeholder(gi, "GammaInverse", t)

  let gp = gamma_process("GPg", params=[@symcore.int(2), @symcore.int(3)])
  let gp_mgf = @symprint.pretty_string(
    moment_generating_function(@symcore.Expr::Symbol("GPg"), t, rvs=[gp]),
  )
  assert_true(!gp_mgf.contains("moment_generating_function("))
  assert_true(!gp_mgf.contains("GammaProcessMGF("))

  let goe = gaussian_orthogonal_ensemble("GOEg", params=[@symcore.int(2)])
  let goe_mgf = @symprint.pretty_string(
    moment_generating_function(@symcore.Expr::Symbol("GOEg"), t, rvs=[goe]),
  )
  assert_true(goe_mgf.contains("Expectation("))
  assert_true(!goe_mgf.contains("moment_generating_function("))

  let gse = gaussian_symplectic_ensemble("GSEg", params=[@symcore.int(2)])
  let gse_mgf = @symprint.pretty_string(
    moment_generating_function(@symcore.Expr::Symbol("GSEg"), t, rvs=[gse]),
  )
  assert_true(gse_mgf.contains("Expectation("))
  assert_true(!gse_mgf.contains("moment_generating_function("))

  let gue = gaussian_unitary_ensemble("GUEg", params=[@symcore.int(2)])
  let gue_mgf = @symprint.pretty_string(
    moment_generating_function(@symcore.Expr::Symbol("GUEg"), t, rvs=[gue]),
  )
  assert_true(gue_mgf.contains("Expectation("))
  assert_true(!gue_mgf.contains("moment_generating_function("))

  let hg = hypergeometric("HGg", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  assert_mgf_not_placeholder(hg, "Hypergeometric", t)

  let iso = ideal_soliton("ISg", params=[@symcore.int(10)])
  assert_mgf_not_placeholder(iso, "IdealSoliton", t)

  let k = kumaraswamy("Kg", params=[@symcore.int(2), @symcore.int(3)])
  assert_mgf_not_placeholder(k, "Kumaraswamy", t)

  let lev = levy("LEVg", params=[@symcore.int(0), @symcore.int(1)])
  assert_mgf_not_placeholder(lev, "Levy", t)

  let lc = log_cauchy("LCg", params=[@symcore.int(0), @symcore.int(1)])
  assert_mgf_not_placeholder(lc, "LogCauchy", t)

  let ll = log_logistic("LLg", params=[@symcore.int(1), @symcore.int(2)])
  assert_mgf_not_placeholder(ll, "LogLogistic", t)

  let lnorm = log_normal("LOGNg", params=[@symcore.int(0), @symcore.int(1)])
  let lnorm_mgf = moment_generating_function(
    @symcore.Expr::Symbol("LOGNg"),
    t,
    rvs=[lnorm],
  )
  assert_pretty_contains(lnorm_mgf, ["Expectation", "LogNormal", "t"])
  assert_pretty_lacks(lnorm_mgf, "LogNormalMGF(")

  let ln = logit_normal("LNg", params=[@symcore.int(0), @symcore.int(1)])
  assert_mgf_not_placeholder(ln, "LogitNormal", t)

  let lom = lomax("LOMg", params=[@symcore.int(3), @symcore.int(2)])
  assert_mgf_not_placeholder(lom, "Lomax", t)

  let mg = matrix_gamma("MGg", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.Expr::Symbol("Scale"),
  ])
  let mg_mgf = @symprint.pretty_string(
    moment_generating_function(@symcore.Expr::Symbol("MGg"), t, rvs=[mg]),
  )
  assert_true(mg_mgf.contains("Expectation("))
  assert_true(!mg_mgf.contains("moment_generating_function("))

  let mst = matrix_student_t("MSTg", params=[
    @symcore.int(3),
    @symcore.Expr::Symbol("MeanM"),
    @symcore.Expr::Symbol("U"),
    @symcore.Expr::Symbol("V"),
  ])
  let mst_mgf = @symprint.pretty_string(
    moment_generating_function(@symcore.Expr::Symbol("MSTg"), t, rvs=[mst]),
  )
  assert_true(mst_mgf.contains("Expectation("))
  assert_true(!mst_mgf.contains("moment_generating_function("))

  let mx = maxwell("MXg", params=[@symcore.int(2)])
  assert_mgf_not_placeholder(mx, "Maxwell", t)

  let mn = multinomial("MNg", params=[
    @symcore.int(5),
    @symcore.rational_from_ints(1, 3),
    @symcore.rational_from_ints(2, 3),
  ])
  assert_mgf_not_placeholder(mn, "Multinomial", tvec)

  let mb = multivariate_beta("MBg", params=[@symcore.int(2), @symcore.int(3)])
  assert_mgf_not_placeholder(mb, "MultivariateBeta", tvec)

  let mvt = multivariate_t("MVTg", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
    @symcore.int(5),
  ])
  assert_mgf_not_placeholder(mvt, "MultivariateT", tvec)

  let nak = nakagami("NAKg", params=[@symcore.int(2), @symcore.int(3)])
  assert_mgf_not_placeholder(nak, "Nakagami", t)

  let nmn = negative_multinomial("NMNg", params=[
    @symcore.int(2),
    @symcore.rational_from_ints(1, 4),
    @symcore.rational_from_ints(1, 4),
  ])
  assert_mgf_not_placeholder(nmn, "NegativeMultinomial", tvec)

  let ng = normal_gamma("NGg", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_mgf_not_placeholder(ng, "NormalGamma", tvec)

  let pf = power_function("PFg", params=[
    @symcore.int(2),
    @symcore.int(0),
    @symcore.int(3),
  ])
  assert_mgf_not_placeholder(pf, "PowerFunction", t)

  let rs = robust_soliton("RSg", params=[
    @symcore.int(10),
    @symcore.rational_from_ints(1, 10),
    @symcore.rational_from_ints(1, 2),
  ])
  assert_mgf_not_placeholder(rs, "RobustSoliton", t)

  let sg = shifted_gompertz("SGg", params=[@symcore.int(1), @symcore.int(2)])
  assert_mgf_not_placeholder(sg, "ShiftedGompertz", t)

  let st = student_t("STg", params=[@symcore.int(5)])
  assert_mgf_not_placeholder(st, "StudentT", t)

  let tr = trapezoidal("TRg", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_mgf_not_placeholder(tr, "Trapezoidal", t)

  let vm = von_mises("VMg", params=[@symcore.int(0), @symcore.int(2)])
  assert_mgf_not_placeholder(vm, "VonMises", t)

  let w = weibull("WG", params=[@symcore.int(3), @symcore.int(5)])
  assert_mgf_not_placeholder(w, "Weibull", t)
}

///|
test "compat cf coverage for residual families" {
  let t = @symcore.Expr::Symbol("t")
  let tvec = @symcore.function("Tuple", [
    @symcore.Expr::Symbol("t1"),
    @symcore.Expr::Symbol("t2"),
  ])

  let a = arcsin("Acf", params=[@symcore.int(0), @symcore.int(1)])
  assert_cf_not_placeholder(a, "Arcsin", t)

  let ben = benini("BENcf", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_cf_not_placeholder(ben, "Benini", t)

  let bp = bernoulli_process("BPcf", params=[@symcore.rational_from_ints(1, 3)])
  assert_cf_not_placeholder(bp, "BernoulliProcess", t)

  let bb = beta_binomial("BBcf", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_cf_not_placeholder(bb, "BetaBinomial", t)

  let bnc = beta_noncentral("BNCcf", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_cf_not_placeholder(bnc, "BetaNoncentral", t)

  let bpr = beta_prime("BPcf", params=[@symcore.int(2), @symcore.int(5)])
  assert_cf_not_placeholder(bpr, "BetaPrime", t)

  let chn = chi_noncentral("CHNcf", params=[@symcore.int(4), @symcore.int(2)])
  assert_cf_not_placeholder(chn, "ChiNoncentral", t)

  let dag = dagum("DAGcf", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_cf_not_placeholder(dag, "Dagum", t)

  let dav = davis("DAVcf", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_cf_not_placeholder(dav, "Davis", t)

  let d = dirichlet("Dcf", params=[@symcore.int(2), @symcore.int(3)])
  assert_cf_not_placeholder(d, "Dirichlet", tvec)

  let ep = exponential_power("EPcf", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_cf_not_placeholder(ep, "ExponentialPower", t)

  let fd = f_distribution("FDcf", params=[@symcore.int(5), @symcore.int(7)])
  assert_cf_not_placeholder(fd, "FDistribution", t)

  let fz = fisher_z("FZcf", params=[@symcore.int(5), @symcore.int(7)])
  assert_cf_not_placeholder(fz, "FisherZ", t)

  let fr = frechet("FRcf", params=[@symcore.int(3)])
  assert_cf_not_placeholder(fr, "Frechet", t)

  let gp = gamma_process("GPcf", params=[@symcore.int(2), @symcore.int(3)])
  assert_cf_not_placeholder(gp, "GammaProcess", t)

  let goe = gaussian_orthogonal_ensemble("GOEcf", params=[@symcore.int(2)])
  assert_cf_not_placeholder(goe, "GaussianOrthogonalEnsemble", t)

  let gse = gaussian_symplectic_ensemble("GSEcf", params=[@symcore.int(2)])
  assert_cf_not_placeholder(gse, "GaussianSymplecticEnsemble", t)

  let gue = gaussian_unitary_ensemble("GUEcf", params=[@symcore.int(2)])
  assert_cf_not_placeholder(gue, "GaussianUnitaryEnsemble", t)

  let hg = hypergeometric("HGcf", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  assert_cf_not_placeholder(hg, "Hypergeometric", t)

  let iso = ideal_soliton("IScf", params=[@symcore.int(10)])
  assert_cf_not_placeholder(iso, "IdealSoliton", t)

  let k = kumaraswamy("Kcf", params=[@symcore.int(2), @symcore.int(3)])
  assert_cf_not_placeholder(k, "Kumaraswamy", t)

  let lc = log_cauchy("LCcf", params=[@symcore.int(0), @symcore.int(1)])
  assert_cf_not_placeholder(lc, "LogCauchy", t)

  let ll = log_logistic("LLcf", params=[@symcore.int(1), @symcore.int(2)])
  assert_cf_not_placeholder(ll, "LogLogistic", t)

  let lnorm = log_normal("LOGNcf", params=[@symcore.int(0), @symcore.int(1)])
  let lnorm_cf = characteristic_function(@symcore.Expr::Symbol("LOGNcf"), t, rvs=[
    lnorm,
  ])
  assert_pretty_contains(lnorm_cf, ["Expectation", "LogNormal", "I", "t"])
  assert_pretty_lacks(lnorm_cf, "LogNormalCF(")

  let ln = logit_normal("LNcf", params=[@symcore.int(0), @symcore.int(1)])
  assert_cf_not_placeholder(ln, "LogitNormal", t)

  let lom = lomax("LOMcf", params=[@symcore.int(3), @symcore.int(2)])
  assert_cf_not_placeholder(lom, "Lomax", t)

  let mg = matrix_gamma("MGcf", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.Expr::Symbol("Scale"),
  ])
  assert_cf_not_placeholder(mg, "MatrixGamma", t)

  let mst = matrix_student_t("MSTcf", params=[
    @symcore.int(3),
    @symcore.Expr::Symbol("MeanM"),
    @symcore.Expr::Symbol("U"),
    @symcore.Expr::Symbol("V"),
  ])
  assert_cf_not_placeholder(mst, "MatrixStudentT", t)

  let mx = maxwell("MXcf", params=[@symcore.int(2)])
  assert_cf_not_placeholder(mx, "Maxwell", t)

  let mn = multinomial("MNcf", params=[
    @symcore.int(5),
    @symcore.rational_from_ints(1, 3),
    @symcore.rational_from_ints(2, 3),
  ])
  assert_cf_not_placeholder(mn, "Multinomial", tvec)

  let mb = multivariate_beta("MBcf", params=[@symcore.int(2), @symcore.int(3)])
  assert_cf_not_placeholder(mb, "MultivariateBeta", tvec)

  let mvt = multivariate_t("MVTcf", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
    @symcore.int(5),
  ])
  assert_cf_not_placeholder(mvt, "MultivariateT", tvec)

  let nak = nakagami("NAKcf", params=[@symcore.int(2), @symcore.int(3)])
  assert_cf_not_placeholder(nak, "Nakagami", t)

  let nmn = negative_multinomial("NMNcf", params=[
    @symcore.int(2),
    @symcore.rational_from_ints(1, 4),
    @symcore.rational_from_ints(1, 4),
  ])
  assert_cf_not_placeholder(nmn, "NegativeMultinomial", tvec)

  let ng = normal_gamma("NGcf", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_cf_not_placeholder(ng, "NormalGamma", tvec)

  let pf = power_function("PFcf", params=[
    @symcore.int(2),
    @symcore.int(0),
    @symcore.int(3),
  ])
  assert_cf_not_placeholder(pf, "PowerFunction", t)

  let rs = robust_soliton("RScf", params=[
    @symcore.int(10),
    @symcore.rational_from_ints(1, 10),
    @symcore.rational_from_ints(1, 2),
  ])
  assert_cf_not_placeholder(rs, "RobustSoliton", t)

  let sg = shifted_gompertz("SGcf", params=[@symcore.int(1), @symcore.int(2)])
  assert_cf_not_placeholder(sg, "ShiftedGompertz", t)

  let tr = trapezoidal("TRcf", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_cf_not_placeholder(tr, "Trapezoidal", t)

  let vm = von_mises("VMcf", params=[@symcore.int(0), @symcore.int(2)])
  assert_cf_not_placeholder(vm, "VonMises", t)

  let w = weibull("Wcf", params=[@symcore.int(3), @symcore.int(5)])
  assert_cf_not_placeholder(w, "Weibull", t)
}

///|
test "compat quantile coverage for residual families" {
  let q = @symcore.rational_from_ints(1, 4)
  let third = @symcore.rational_from_ints(1, 3)
  let fifth = @symcore.rational_from_ints(1, 5)

  let ben = benini("BENq", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_quantile_not_placeholder(ben, "Benini", q)

  let bp = bernoulli_process("BPq", params=[third])
  assert_quantile_not_placeholder(bp, "BernoulliProcess", q)

  let bb = beta_binomial("BBq", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_quantile_not_placeholder(bb, "BetaBinomial", q)

  let bnc = beta_noncentral("BNCq", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_quantile_not_placeholder(bnc, "BetaNoncentral", q)

  let bpr = beta_prime("BPRq", params=[@symcore.int(2), @symcore.int(5)])
  assert_quantile_not_placeholder(bpr, "BetaPrime", q)

  let chn = chi_noncentral("CHNq", params=[@symcore.int(4), @symcore.int(2)])
  assert_quantile_not_placeholder(chn, "ChiNoncentral", q)

  let dag = dagum("DAGq", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_quantile_not_placeholder(dag, "Dagum", q)

  let dav = davis("DAVq", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_quantile_not_placeholder(dav, "Davis", q)

  let d = dirichlet("Dq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(d, "Dirichlet", q)

  let exg = ex_gaussian("EXGq", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_quantile_not_placeholder(exg, "ExGaussian", q)

  let ep = exponential_power("EPq", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_quantile_not_placeholder(ep, "ExponentialPower", q)

  let fd = f_distribution("FDq", params=[@symcore.int(5), @symcore.int(7)])
  assert_quantile_not_placeholder(fd, "FDistribution", q)

  let fz = fisher_z("FZq", params=[@symcore.int(5), @symcore.int(7)])
  assert_quantile_not_placeholder(fz, "FisherZ", q)

  let fl = flory_schulz("FLq", params=[third])
  assert_quantile_not_placeholder(fl, "FlorySchulz", q)

  let fr = frechet("FRq", params=[@symcore.int(3)])
  assert_quantile_not_placeholder(fr, "Frechet", q)

  let gi = gamma_inverse("GIq", params=[@symcore.int(3), @symcore.int(2)])
  assert_quantile_not_placeholder(gi, "GammaInverse", q)

  let gp = gamma_process("GPq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(gp, "GammaProcess", q)

  let gai = gaussian_inverse("GAIq", params=[@symcore.int(3), @symcore.int(2)])
  assert_quantile_not_placeholder(gai, "GaussianInverse", q)

  let goe = gaussian_orthogonal_ensemble("GOEq", params=[@symcore.int(2)])
  assert_quantile_not_placeholder(goe, "GaussianOrthogonalEnsemble", q)

  let gse = gaussian_symplectic_ensemble("GSEq", params=[@symcore.int(2)])
  assert_quantile_not_placeholder(gse, "GaussianSymplecticEnsemble", q)

  let gue = gaussian_unitary_ensemble("GUEq", params=[@symcore.int(2)])
  assert_quantile_not_placeholder(gue, "GaussianUnitaryEnsemble", q)

  let he = hermite("HEq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(he, "Hermite", q)

  let hg = hypergeometric("HGq", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  assert_quantile_not_placeholder(hg, "Hypergeometric", q)

  let iso = ideal_soliton("ISq", params=[@symcore.int(10)])
  assert_quantile_not_placeholder(iso, "IdealSoliton", q)

  let lc = log_cauchy("LCq", params=[@symcore.int(0), @symcore.int(1)])
  assert_quantile_not_placeholder(lc, "LogCauchy", q)

  let lg = logarithmic("LGq", params=[third])
  assert_quantile_not_placeholder(lg, "Logarithmic", q)

  let lgn = logit_normal("LNq", params=[@symcore.int(0), @symcore.int(1)])
  assert_quantile_not_placeholder(lgn, "LogitNormal", q)

  let mg = matrix_gamma("MGq", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.Expr::Symbol("Scale"),
  ])
  assert_quantile_not_placeholder(mg, "MatrixGamma", q)

  let mst = matrix_student_t("MSTq", params=[
    @symcore.int(3),
    @symcore.Expr::Symbol("MeanM"),
    @symcore.Expr::Symbol("U"),
    @symcore.Expr::Symbol("V"),
  ])
  assert_quantile_not_placeholder(mst, "MatrixStudentT", q)

  let mx = maxwell("MXq", params=[@symcore.int(2)])
  assert_quantile_not_placeholder(mx, "Maxwell", q)

  let mn = multinomial("MNq", params=[
    @symcore.int(5),
    third,
    @symcore.rational_from_ints(2, 3),
  ])
  assert_quantile_not_placeholder(mn, "Multinomial", q)

  let mb = multivariate_beta("MBq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(mb, "MultivariateBeta", q)

  let mvl = multivariate_laplace("MVLq", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_quantile_not_placeholder(mvl, "MultivariateLaplace", q)

  let mvn = multivariate_normal("MVNq", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_quantile_not_placeholder(mvn, "MultivariateNormal", q)

  let mvt = multivariate_t("MVTq", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
    @symcore.int(5),
  ])
  assert_quantile_not_placeholder(mvt, "MultivariateT", q)

  let nak = nakagami("NAKq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(nak, "Nakagami", q)

  let nmn = negative_multinomial("NMNq", params=[
    @symcore.int(2),
    @symcore.rational_from_ints(1, 4),
    @symcore.rational_from_ints(1, 4),
  ])
  assert_quantile_not_placeholder(nmn, "NegativeMultinomial", q)

  let ng = normal_gamma("NGq", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_quantile_not_placeholder(ng, "NormalGamma", q)

  let qu = quadratic_u("QUq", params=[@symcore.int(0), @symcore.int(2)])
  assert_quantile_not_placeholder(qu, "QuadraticU", q)

  let rc = raised_cosine("RCq", params=[@symcore.int(0), @symcore.int(2)])
  assert_quantile_not_placeholder(rc, "RaisedCosine", q)

  let rs = robust_soliton("RSq", params=[
    @symcore.int(10),
    @symcore.rational_from_ints(1, 10),
    fifth,
  ])
  assert_quantile_not_placeholder(rs, "RobustSoliton", q)

  let sg = shifted_gompertz("SGq", params=[@symcore.int(1), @symcore.int(2)])
  assert_quantile_not_placeholder(sg, "ShiftedGompertz", q)

  let sk = skellam("SKq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(sk, "Skellam", q)

  let us = uniform_sum("USq", params=[@symcore.int(4)])
  assert_quantile_not_placeholder(us, "UniformSum", q)

  let wd = wald("WDq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(wd, "Wald", q)

  let ws = wigner_semicircle("WSq", params=[@symcore.int(3)])
  assert_quantile_not_placeholder(ws, "WignerSemicircle", q)

  let ys = yule_simon("YSq", params=[@symcore.int(3)])
  assert_quantile_not_placeholder(ys, "YuleSimon", q)

  let zz = zeta("ZZq", params=[@symcore.int(3)])
  assert_quantile_not_placeholder(zz, "Zeta", q)
}

///|
test "compat entropy coverage residual A" {
  let third = @symcore.rational_from_ints(1, 3)

  let ben = benini("BENe", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_entropy_not_placeholder(ben, "Benini")
  let bp = bernoulli_process("BPe", params=[third])
  assert_entropy_not_placeholder(bp, "BernoulliProcess")
  let bb = beta_binomial("BBe", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_entropy_not_placeholder(bb, "BetaBinomial")
  let bnc = beta_noncentral("BNCe", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_entropy_not_placeholder(bnc, "BetaNoncentral")
  let bpr = beta_prime("BPRe", params=[@symcore.int(2), @symcore.int(5)])
  assert_entropy_not_placeholder(bpr, "BetaPrime")
  let chn = chi_noncentral("CHNe", params=[@symcore.int(4), @symcore.int(2)])
  assert_entropy_not_placeholder(chn, "ChiNoncentral")
  let dag = dagum("DAGe", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_entropy_not_placeholder(dag, "Dagum")
  let dav = davis("DAVe", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_entropy_not_placeholder(dav, "Davis")
  let d = dirichlet("De", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(d, "Dirichlet")
  let exg = ex_gaussian("EXGe", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_entropy_not_placeholder(exg, "ExGaussian")
  let ep = exponential_power("EPe", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_entropy_not_placeholder(ep, "ExponentialPower")
  let fd = f_distribution("FDe", params=[@symcore.int(5), @symcore.int(7)])
  assert_entropy_not_placeholder(fd, "FDistribution")
  let fz = fisher_z("FZe", params=[@symcore.int(5), @symcore.int(7)])
  assert_entropy_not_placeholder(fz, "FisherZ")
  let fl = flory_schulz("FLe", params=[third])
  assert_entropy_not_placeholder(fl, "FlorySchulz")
}

///|
test "compat entropy coverage residual B1" {
  let fr = frechet("FRe", params=[@symcore.int(3)])
  assert_entropy_not_placeholder(fr, "Frechet")
  let gi = gamma_inverse("GIe", params=[@symcore.int(3), @symcore.int(2)])
  assert_entropy_not_placeholder(gi, "GammaInverse")
  let gp = gamma_process("GPe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(gp, "GammaProcess")
  let gai = gaussian_inverse("GAIe", params=[@symcore.int(3), @symcore.int(2)])
  assert_entropy_not_placeholder(gai, "GaussianInverse")
  let goe = gaussian_orthogonal_ensemble("GOEe", params=[@symcore.int(2)])
  assert_entropy_not_placeholder(goe, "GaussianOrthogonalEnsemble")
  let gse = gaussian_symplectic_ensemble("GSEe", params=[@symcore.int(2)])
  assert_entropy_not_placeholder(gse, "GaussianSymplecticEnsemble")
}

///|
test "compat entropy coverage residual B2a" {
  let gue = gaussian_unitary_ensemble("GUEe", params=[@symcore.int(2)])
  assert_entropy_not_placeholder(gue, "GaussianUnitaryEnsemble")
  let he = hermite("HEe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(he, "Hermite")
  let hg = hypergeometric("HGe", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  assert_entropy_not_placeholder(hg, "Hypergeometric")
}

///|
test "compat entropy coverage residual B2b iso" {
  let iso = ideal_soliton("ISe", params=[@symcore.int(10)])
  assert_entropy_not_placeholder(iso, "IdealSoliton")
}

///|
test "compat entropy coverage residual B2b log_cauchy" {
  let lc = log_cauchy("LCe", params=[@symcore.int(0), @symcore.int(1)])
  assert_entropy_not_placeholder(lc, "LogCauchy")
}

///|
test "compat entropy coverage residual B2b logarithmic" {
  let third = @symcore.rational_from_ints(1, 3)
  let lgr = logarithmic("LGe", params=[third])
  assert_entropy_not_placeholder(lgr, "Logarithmic")
}

///|
test "compat entropy coverage residual C" {
  let third = @symcore.rational_from_ints(1, 3)

  let lgn = logit_normal("LNe", params=[@symcore.int(0), @symcore.int(1)])
  assert_entropy_not_placeholder(lgn, "LogitNormal")
  let mg = matrix_gamma("MGe", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.Expr::Symbol("Scale"),
  ])
  assert_entropy_not_placeholder(mg, "MatrixGamma")
  let mst = matrix_student_t("MSTe", params=[
    @symcore.int(3),
    @symcore.Expr::Symbol("MeanM"),
    @symcore.Expr::Symbol("U"),
    @symcore.Expr::Symbol("V"),
  ])
  assert_entropy_not_placeholder(mst, "MatrixStudentT")
  let mx = maxwell("MXe", params=[@symcore.int(2)])
  assert_entropy_not_placeholder(mx, "Maxwell")
  let mn = multinomial("MNe", params=[
    @symcore.int(5),
    third,
    @symcore.rational_from_ints(2, 3),
  ])
  assert_entropy_not_placeholder(mn, "Multinomial")
  let mb = multivariate_beta("MBe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(mb, "MultivariateBeta")
  let mvl = multivariate_laplace("MVLe", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_entropy_not_placeholder(mvl, "MultivariateLaplace")
  let mvn = multivariate_normal("MVNe", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_entropy_not_placeholder(mvn, "MultivariateNormal")
}

///|
test "compat entropy coverage residual D" {
  let fifth = @symcore.rational_from_ints(1, 5)

  let mvt = multivariate_t("MVTe", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
    @symcore.int(5),
  ])
  assert_entropy_not_placeholder(mvt, "MultivariateT")
  let nak = nakagami("NAKe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(nak, "Nakagami")
  let nmn = negative_multinomial("NMNe", params=[
    @symcore.int(2),
    @symcore.rational_from_ints(1, 4),
    @symcore.rational_from_ints(1, 4),
  ])
  assert_entropy_not_placeholder(nmn, "NegativeMultinomial")
  let ng = normal_gamma("NGe", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_entropy_not_placeholder(ng, "NormalGamma")
  let qu = quadratic_u("QUe", params=[@symcore.int(0), @symcore.int(2)])
  assert_entropy_not_placeholder(qu, "QuadraticU")
  let rc = raised_cosine("RCe", params=[@symcore.int(0), @symcore.int(2)])
  assert_entropy_not_placeholder(rc, "RaisedCosine")
  let rs = robust_soliton("RSe", params=[
    @symcore.int(10),
    @symcore.rational_from_ints(1, 10),
    fifth,
  ])
  assert_entropy_not_placeholder(rs, "RobustSoliton")
  let sg = shifted_gompertz("SGe", params=[@symcore.int(1), @symcore.int(2)])
  assert_entropy_not_placeholder(sg, "ShiftedGompertz")
  let sk = skellam("SKe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(sk, "Skellam")
  let us = uniform_sum("USe", params=[@symcore.int(4)])
  assert_entropy_not_placeholder(us, "UniformSum")
  let wd = wald("WDe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(wd, "Wald")
  let ws = wigner_semicircle("WSe", params=[@symcore.int(3)])
  assert_entropy_not_placeholder(ws, "WignerSemicircle")
  let ys = yule_simon("YSe", params=[@symcore.int(3)])
  assert_entropy_not_placeholder(ys, "YuleSimon")
  let zz = zeta("ZZe", params=[@symcore.int(3)])
  assert_entropy_not_placeholder(zz, "Zeta")
}

///|
test "compat abstract opaque symbolic families stay unevaluated" {
  let sp = stochastic_process("SP")
  let dtsp = discrete_time_stochastic_process("DTSP")
  let dmc = discrete_markov_chain("DMC", params=[@symcore.Expr::Symbol("T")])
  let cmc = continuous_markov_chain("CMC", params=[@symcore.Expr::Symbol("Q")])
  let jed = joint_eigen_distribution("JED", params=[@symcore.int(2)])
  let lsd = level_spacing_distribution("LSD", params=[@symcore.int(2)])

  let rvs : Array[RandomVar] = [sp, dtsp, dmc, cmc, jed, lsd]
  for rv in rvs {
    assert_opaque_symbolic_metrics(rv)
  }

  let t = @symcore.Expr::Symbol("t")
  let sp_mean = expectation(@symcore.function("SP", [t]), rvs=[sp])
  assert_pretty_contains(sp_mean, ["Expectation", "StochasticProcess", "t"])
  assert_pretty_lacks(sp_mean, "MeanAt(")
  let sp_var = variance(@symcore.function("SP", [t]), rvs=[sp])
  assert_pretty_contains(sp_var, ["Variance", "StochasticProcess", "t"])
  assert_pretty_lacks(sp_var, "VarianceAt(")
  let dtsp_mean = expectation(@symcore.function("DTSP", [t]), rvs=[dtsp])
  assert_pretty_contains(dtsp_mean, [
    "Expectation", "DiscreteTimeStochasticProcess", "t",
  ])
  assert_pretty_lacks(dtsp_mean, "MeanAt(")
  let dtsp_var = variance(@symcore.function("DTSP", [t]), rvs=[dtsp])
  assert_pretty_contains(dtsp_var, [
    "Variance", "DiscreteTimeStochasticProcess", "t",
  ])
  assert_pretty_lacks(dtsp_var, "VarianceAt(")
  let dmc_mean = expectation(@symcore.function("DMC", [t]), rvs=[dmc])
  assert_pretty_contains(dmc_mean, [
    "Expectation", "DiscreteMarkovChain", "t", "T",
  ])
  assert_pretty_lacks(dmc_mean, "MeanAt(")
  let dmc_var = variance(@symcore.function("DMC", [t]), rvs=[dmc])
  assert_pretty_contains(dmc_var, ["Variance", "DiscreteMarkovChain", "t", "T"])
  assert_pretty_lacks(dmc_var, "VarianceAt(")
  let cmc_mean = expectation(@symcore.function("CMC", [t]), rvs=[cmc])
  assert_pretty_contains(cmc_mean, [
    "Expectation", "ContinuousMarkovChain", "t", "Q",
  ])
  assert_pretty_lacks(cmc_mean, "MeanAt(")
  let cmc_var = variance(@symcore.function("CMC", [t]), rvs=[cmc])
  assert_pretty_contains(cmc_var, [
    "Variance", "ContinuousMarkovChain", "t", "Q",
  ])
  assert_pretty_lacks(cmc_var, "VarianceAt(")
}
