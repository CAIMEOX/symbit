///|
fn sample_int_value(expr : @symcore.Expr) -> Int? {
  expr_as_int(expr)
}

///|
fn sample_double_value(expr : @symcore.Expr) -> Double? {
  match expr {
    Float(value) => Some(value.to_double() catch { _ => return None })
    Number(value) => {
      let float_value = @symcore.Float::from_exact(value, prec=53) catch {
        _ => return None
      }
      Some(float_value.to_double() catch { _ => return None })
    }
    _ => None
  }
}

///|
fn rational(n : Int, d : Int) -> @symcore.Expr {
  @symcore.rational_from_ints(n, d) catch {
    _ => @symcore.int(0)
  }
}

///|
fn sample_dict_count_total(expr : @symcore.Expr) -> Int {
  match expr {
    Dict(entries) => {
      let mut total = 0
      for entry in entries {
        match sample_int_value(entry.1) {
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
test "symstats concrete sampling finite and expressions" {
  let x = die("X", sides=6)
  let sx = @symcore.Expr::Symbol("X")
  let samples = sample_iter(sx, n=20, rvs=[x], seed=Some(7))
  assert_eq(samples.length(), 20)
  for value in samples {
    match sample_int_value(value) {
      Some(n) => assert_true(n >= 1 && n <= 6)
      None => fail("die sample should be an integer")
    }
  }
  match sample_random_var(x, seed=Some(17)) {
    Some(value) =>
      assert_true(
        @symcore.compare_expr(sample(sx, rvs=[x], seed=Some(17)), value) == 0,
      )
    None => fail("direct random variable sample should be available")
  }

  let shifted = sample(
    @symcore.add([sx, @symcore.int(1)]),
    rvs=[x],
    seed=Some(7),
  )
  match sample_int_value(shifted) {
    Some(n) => assert_true(n >= 2 && n <= 7)
    None => fail("sampled expression should be an integer")
  }
}

///|
test "symstats concrete sampling discrete and continuous families" {
  let b = binomial(
    "B",
    @symcore.int(5),
    @symcore.rational_from_ints(1, 2) catch {
      _ => @symcore.int(0)
    },
  )
  match sample_random_var(b, seed=Some(3)) {
    Some(value) =>
      match sample_int_value(value) {
        Some(n) => assert_true(n >= 0 && n <= 5)
        None => fail("binomial sample should be integral")
      }
    None => fail("binomial sampler should produce a value")
  }

  let p = poisson("P", @symcore.int(3))
  match sample_random_var(p, seed=Some(4)) {
    Some(value) =>
      match sample_int_value(value) {
        Some(n) => assert_true(n >= 0)
        None => fail("poisson sample should be integral")
      }
    None => fail("poisson sampler should produce a value")
  }

  let n = normal("N", @symcore.int(0), @symcore.int(1))
  match sample_random_var(n, seed=Some(5)) {
    Some(Float(_)) => ()
    _ => fail("normal sampler should produce a floating value")
  }
}

///|
test "symstats sampling compatibility aliases and backend helpers" {
  let d = rv("D2", "Die", params=[@symcore.int(6)])
  let sd = @symcore.Expr::Symbol("D2")
  let via_lambdify = sample_iter_lambdify(sd, n=8, rvs=[d], seed=Some(21))
  let via_subs = sample_iter_subs(sd, n=8, rvs=[d], seed=Some(21))
  assert_eq(via_lambdify.length(), 8)
  assert_eq(via_subs.length(), 8)
  for value in via_lambdify {
    match sample_int_value(value) {
      Some(n) => assert_true(n >= 1 && n <= 6)
      None => fail("sample_iter_lambdify should return die samples")
    }
  }
  for value in via_subs {
    match sample_int_value(value) {
      Some(n) => assert_true(n >= 1 && n <= 6)
      None => fail("sample_iter_subs should return die samples")
    }
  }

  let nrv = rv("RN", "Normal", params=[@symcore.int(0), @symcore.int(1)])
  match do_sample_scipy(nrv, n=3, seed=Some(22)) {
    Some(values) => {
      assert_eq(values.length(), 3)
      for value in values {
        match sample_double_value(value) {
          Some(_) => ()
          None => fail("scipy compatibility sampler should return floats")
        }
      }
    }
    None => fail("scipy compatibility sampler should produce values")
  }

  let b = rv("RB", "Binomial", params=[@symcore.int(4), rational(1, 2)])
  match do_sample_numpy(b, n=4, seed=Some(23)) {
    Some(values) => {
      assert_eq(values.length(), 4)
      for value in values {
        match sample_int_value(value) {
          Some(k) => assert_true(k >= 0 && k <= 4)
          None => fail("numpy compatibility sampler should return integers")
        }
      }
    }
    None => fail("numpy compatibility sampler should produce values")
  }

  match do_sample_pymc(b, n=2, seed=Some(24)) {
    Some(values) => assert_eq(values.length(), 2)
    None => fail("pymc compatibility sampler should produce values")
  }
}

///|
fn assert_process_path_length(
  expr : @symcore.Expr,
  n : Int,
) -> Array[@symcore.Expr] raise {
  match @symcore.tuple_items(expr) {
    Some(items) => {
      assert_eq(items.length(), n)
      items
    }
    None => fail("process sample should be a tuple path")
  }
}

///|
fn process_path_value(pair : @symcore.Expr) -> @symcore.Expr? {
  match @symcore.tuple_items(pair) {
    Some(items) if items.length() == 2 => Some(items[1])
    _ => None
  }
}

///|
test "symstats stochastic process sampling returns concrete paths" {
  let pp_path = sample_stochastic_process(
    poisson_process("NP", @symcore.int(2)),
    @symcore.int(0),
    @symcore.int(3),
    n=5,
  )
  let pp_items = assert_process_path_length(pp_path, 5)
  let mut previous = 0
  for pair in pp_items {
    match process_path_value(pair) {
      Some(value) =>
        match sample_int_value(value) {
          Some(k) => {
            assert_true(k >= previous)
            previous = k
          }
          None => fail("poisson process sample should be integral")
        }
      None => fail("poisson process path entry should be a pair")
    }
  }

  let wp_path = sample_stochastic_process(
    wiener_process("WP"),
    @symcore.int(0),
    @symcore.int(2),
    n=4,
  )
  let wp_items = assert_process_path_length(wp_path, 4)
  for pair in wp_items {
    match process_path_value(pair) {
      Some(value) =>
        match sample_double_value(value) {
          Some(_) => ()
          None => fail("wiener process sample should be numeric")
        }
      None => fail("wiener process path entry should be a pair")
    }
  }

  let bp = bernoulli_process("BP", params=[rational(1, 3)])
  let bp_path = sample_stochastic_process(
    bp,
    @symcore.int(0),
    @symcore.int(3),
    n=4,
  )
  let bp_items = assert_process_path_length(bp_path, 4)
  for pair in bp_items {
    match process_path_value(pair) {
      Some(value) =>
        match sample_int_value(value) {
          Some(k) => assert_true(k == 0 || k == 1)
          None => fail("bernoulli process sample should be integral")
        }
      None => fail("bernoulli process path entry should be a pair")
    }
  }

  let gp = gamma_process("GP", params=[@symcore.int(2), @symcore.int(3)])
  let gp_path = sample_stochastic_process(
    gp,
    @symcore.int(0),
    @symcore.int(2),
    n=4,
  )
  let gp_items = assert_process_path_length(gp_path, 4)
  for pair in gp_items {
    match process_path_value(pair) {
      Some(value) =>
        match sample_double_value(value) {
          Some(x) => assert_true(x >= 0.0)
          None => fail("gamma process sample should be numeric")
        }
      None => fail("gamma process path entry should be a pair")
    }
  }

  let generic = sample_stochastic_process(
    stochastic_process("SP"),
    @symcore.int(0),
    @symcore.int(1),
    n=2,
  )
  assert_true(
    @symcore.application_has_name(generic, "sample_stochastic_process"),
  )
}

///|
test "symstats symbolic continuous samplers respect support" {
  let samples : Array[(RandomVar, Double, Double)] = [
    (uniform("U", params=[@symcore.int(0), @symcore.int(2)]), 0.0, 2.0),
    (beta("BE", params=[@symcore.int(2), @symcore.int(5)]), 0.0, 1.0),
    (log_normal("LN", params=[@symcore.int(0), @symcore.int(1)]), 0.0, 1.0e300),
    (pareto("PA", params=[@symcore.int(2), @symcore.int(3)]), 2.0, 1.0e300),
    (rayleigh("RA", params=[@symcore.int(2)]), 0.0, 1.0e300),
    (
      triangular("TR", params=[
        @symcore.int(0),
        @symcore.int(4),
        @symcore.int(1),
      ]),
      0.0,
      4.0,
    ),
    (
      trapezoidal("TZ", params=[
        @symcore.int(0),
        @symcore.int(1),
        @symcore.int(3),
        @symcore.int(4),
      ]),
      0.0,
      4.0,
    ),
    (weibull("WB", params=[@symcore.int(2), @symcore.int(3)]), 0.0, 1.0e300),
  ]
  for i in 0..<samples.length() {
    let (rv, lo, hi) = samples[i]
    match sample_random_var(rv, seed=Some(100 + i)) {
      Some(value) =>
        match sample_double_value(value) {
          Some(x) => {
            assert_true(x >= lo)
            assert_true(x <= hi)
          }
          None => fail("symbolic continuous sampler should return numeric")
        }
      None => fail("symbolic continuous sampler should produce a value")
    }
  }
}

///|
test "symstats symbolic discrete samplers respect support" {
  let beta_bin = beta_binomial("BB", params=[
    @symcore.int(5),
    @symcore.int(2),
    @symcore.int(3),
  ])
  match sample_random_var(beta_bin, seed=Some(201)) {
    Some(value) =>
      match sample_int_value(value) {
        Some(k) => assert_true(k >= 0 && k <= 5)
        None => fail("beta-binomial sample should be integral")
      }
    None => fail("beta-binomial sampler should produce a value")
  }

  let hyper = hypergeometric("HG", params=[
    @symcore.int(10),
    @symcore.int(5),
    @symcore.int(3),
  ])
  match sample_random_var(hyper, seed=Some(202)) {
    Some(value) =>
      match sample_int_value(value) {
        Some(k) => assert_true(k >= 0 && k <= 3)
        None => fail("hypergeometric sample should be integral")
      }
    None => fail("hypergeometric sampler should produce a value")
  }

  let handmade = finite_distribution_handmade("FDH", params=[
    Tuple([
      Tuple([@symcore.int(1), rational(1, 4)]),
      Tuple([@symcore.int(2), rational(3, 4)]),
    ]),
  ])
  match sample_random_var(handmade, seed=Some(203)) {
    Some(value) =>
      match sample_int_value(value) {
        Some(k) => assert_true(k == 1 || k == 2)
        None => fail("finite handmade sample should be integral")
      }
    None => fail("finite handmade sampler should produce a value")
  }

  let herm = hermite("HE", params=[@symcore.int(2), @symcore.int(3)])
  match sample_random_var(herm, seed=Some(204)) {
    Some(value) =>
      match sample_int_value(value) {
        Some(k) => assert_true(k >= 0)
        None => fail("hermite sample should be integral")
      }
    None => fail("hermite sampler should produce a value")
  }

  let sk = skellam("SK", params=[@symcore.int(3), @symcore.int(2)])
  match sample_random_var(sk, seed=Some(205)) {
    Some(value) =>
      match sample_int_value(value) {
        Some(_) => ()
        None => fail("skellam sample should be integral")
      }
    None => fail("skellam sampler should produce a value")
  }
}

///|
test "symstats sampling probability expectation and density" {
  let x = die("X", sides=6)
  let sx = @symcore.Expr::Symbol("X")
  let prob = sampling_p(
    gt(sx, @symcore.int(3)),
    rvs=[x],
    numsamples=40,
    seed=Some(11),
  )
  match expr_as_number(prob) {
    Some(q) => {
      assert_true(q.compare(@symnum.BigRational::zero()) >= 0)
      assert_true(q.compare(@symnum.BigRational::one()) <= 0)
    }
    None => fail("sampling_p should return a rational estimate")
  }

  let mean = sampling_e(sx, rvs=[x], numsamples=40, seed=Some(11))
  match expr_as_number(mean) {
    Some(q) => {
      assert_true(q.compare(@symnum.BigRational::from_int(1)) >= 0)
      assert_true(q.compare(@symnum.BigRational::from_int(6)) <= 0)
    }
    None => fail("sampling_e should return a rational estimate")
  }

  let density = sampling_density(sx, rvs=[x], numsamples=40, seed=Some(11))
  assert_eq(sample_dict_count_total(density), 40)
}

///|
test "symstats where_set computes finite and continuous domains" {
  let d = die("D", sides=6)
  let sd = @symcore.Expr::Symbol("D")
  match where_set(gt(sd, @symcore.int(3)), d) {
    Some(set) => inspect(@symsets.to_string(set), content="{4, 5, 6}")
    None => fail("finite where_set should enumerate support")
  }

  let n = normal("N", @symcore.int(0), @symcore.int(1))
  let sn = @symcore.Expr::Symbol("N")
  let condition = le(@symcore.pow(sn, @symcore.int(2)), @symcore.int(1))
  match where_set(condition, n) {
    Some(set) => inspect(@symsets.to_string(set), content="Interval(-1, 1)")
    None => fail("continuous where_set should solve rational inequalities")
  }
}
