///|
/// Oracle helpers for SymPy ntheory.

///|
pub type OracleArg = @sympy.OracleArg

///|
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  @sympy.objenum_to_obj(obj)
}

///|
fn py_gil_ensure() -> Int {
  @sympy.py_gil_ensure()
}

///|
fn py_gil_release(state : Int) -> Unit {
  @sympy.py_gil_release(state)
}

///|
fn py_str_obj(obj : @py.PyObject) -> String {
  let state = py_gil_ensure()
  let s = obj.to_string()
  py_gil_release(state)
  s
}

///|
fn py_str_enum(obj : @py.PyObjectEnum) -> String {
  py_str_obj(objenum_to_obj(obj))
}

///|
fn py_eval(expr : String) -> @py.PyObjectEnum raise {
  let state = py_gil_ensure()
  let res = try {
    let builtins = match @py.pyimport("builtins") {
      Some(mod) => mod
      None => fail("py-builtins-missing")
    }
    let eval_obj = match builtins.get_attr("eval", print_err=true) {
      Some(obj) => obj
      None => fail("py-eval-missing")
    }
    let eval_callable = match eval_obj {
      PyCallable(callable) => callable
      PyClass(obj0) =>
        @py.PyCallable::create(obj0) catch {
          _ => fail("py-callable")
        }
      _ =>
        @py.PyCallable::create(objenum_to_obj(eval_obj)) catch {
          _ => fail("py-callable")
        }
    }
    let globals = @py.PyDict::new()
    globals.set("__builtins__", builtins.obj())
    let args = @sympy.py_pack_args([
      OracleArg::Str(expr),
      OracleArg::PyObj(globals.obj()),
      OracleArg::PyObj(globals.obj()),
    ])
    match @sympy.py_call_object(eval_callable, args, print_err=true) {
      Some(obj) => obj
      None => fail("py-eval-none")
    }
  } catch {
    err => {
      py_gil_release(state)
      raise err
    }
  } noraise {
    v => v
  }
  py_gil_release(state)
  res
}

///|
fn py_eval_callable(expr : String) -> @py.PyCallable raise {
  match py_eval(expr) {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("py-callable")
      }
    other =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("py-callable")
      }
  }
}

///|
fn py_call_with_args(
  callable : @py.PyCallable,
  args : Array[OracleArg],
) -> @py.PyObjectEnum raise {
  let tup = @sympy.py_pack_args(args)
  match @sympy.py_call_object(callable, tup, print_err=true) {
    Some(obj) => obj
    None => fail("py-call-none")
  }
}

///|
fn py_call_with_args_opt(
  callable : @py.PyCallable,
  args : Array[OracleArg],
) -> @py.PyObjectEnum? {
  let tup = @sympy.py_pack_args(args)
  @sympy.py_call_object(callable, tup, print_err=true)
}

///|
fn py_str_enum_opt(obj : @py.PyObjectEnum?) -> String {
  match obj {
    Some(value) => py_str_enum(value)
    None => "None"
  }
}

///|
pub fn isprime_str(n : Int) -> String raise {
  let fn_isprime = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.primetest', fromlist=['isprime']).isprime(n)",
  )
  let res = py_call_with_args(fn_isprime, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn prime_str(n : Int) -> String raise {
  let fn_prime = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.generate', fromlist=['prime']).prime(n)",
  )
  let res = py_call_with_args(fn_prime, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn symmetric_residue_str(a : Int, m : Int) -> String raise {
  let fn_sr = py_eval_callable(
    "lambda a, m: __import__('sympy.ntheory.modular', fromlist=['symmetric_residue']).symmetric_residue(a, m)",
  )
  let res = py_call_with_args(fn_sr, [OracleArg::Int(a), OracleArg::Int(m)])
  py_str_enum(res)
}

///|
pub fn crt_str(
  moduli : Array[Int],
  residues : Array[Int],
  symmetric? : Bool = false,
  check? : Bool = true,
) -> String raise {
  let fn_crt = py_eval_callable(
    "lambda m, v, symmetric, check: __import__('sympy.ntheory.modular', fromlist=['crt']).crt(m, v, symmetric=symmetric, check=check)",
  )
  let res = py_call_with_args_opt(fn_crt, [
    OracleArg::IntList(moduli),
    OracleArg::IntList(residues),
    OracleArg::Bool(symmetric),
    OracleArg::Bool(check),
  ])
  py_str_enum_opt(res)
}

///|
pub fn solve_congruence_str(
  remainders : Array[Int],
  moduli : Array[Int],
  symmetric? : Bool = false,
  check? : Bool = true,
) -> String raise {
  let fn_sc = py_eval_callable(
    "lambda r, m, symmetric, check: __import__('sympy.ntheory.modular', fromlist=['solve_congruence']).solve_congruence(*list(zip(r, m)), symmetric=symmetric, check=check)",
  )
  let res = py_call_with_args_opt(fn_sc, [
    OracleArg::IntList(remainders),
    OracleArg::IntList(moduli),
    OracleArg::Bool(symmetric),
    OracleArg::Bool(check),
  ])
  py_str_enum_opt(res)
}

///|
pub fn n_order_str(a : Int, n : Int) -> String raise {
  let fn_n_order = py_eval_callable(
    "lambda a, n: __import__('sympy.ntheory.residue_ntheory', fromlist=['n_order']).n_order(a, n)",
  )
  let res = py_call_with_args(fn_n_order, [OracleArg::Int(a), OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn is_primitive_root_str(a : Int, n : Int) -> String raise {
  let fn_ipr = py_eval_callable(
    "lambda a, n: __import__('sympy.ntheory.residue_ntheory', fromlist=['is_primitive_root']).is_primitive_root(a, n)",
  )
  let res = py_call_with_args(fn_ipr, [OracleArg::Int(a), OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn primitive_root_str(n : Int, smallest? : Bool = true) -> String raise {
  let fn_pr = py_eval_callable(
    "lambda n, smallest: __import__('sympy.ntheory.residue_ntheory', fromlist=['primitive_root']).primitive_root(n, smallest=smallest)",
  )
  let res = py_call_with_args_opt(fn_pr, [
    OracleArg::Int(n),
    OracleArg::Bool(smallest),
  ])
  py_str_enum_opt(res)
}

///|
pub fn legendre_symbol_str(a : Int, p : Int) -> String raise {
  let fn_ls = py_eval_callable(
    "lambda a, p: __import__('sympy.functions.combinatorial.numbers', fromlist=['legendre_symbol']).legendre_symbol(a, p)",
  )
  let res = py_call_with_args(fn_ls, [OracleArg::Int(a), OracleArg::Int(p)])
  py_str_enum(res)
}

///|
pub fn jacobi_symbol_str(a : Int, n : Int) -> String raise {
  let fn_js = py_eval_callable(
    "lambda a, n: __import__('sympy.functions.combinatorial.numbers', fromlist=['jacobi_symbol']).jacobi_symbol(a, n)",
  )
  let res = py_call_with_args(fn_js, [OracleArg::Int(a), OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn is_quad_residue_str(a : Int, n : Int) -> String raise {
  let fn_iqr = py_eval_callable(
    "lambda a, n: __import__('sympy.ntheory.residue_ntheory', fromlist=['is_quad_residue']).is_quad_residue(a, n)",
  )
  let res = py_call_with_args(fn_iqr, [OracleArg::Int(a), OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn quadratic_residues_str(n : Int) -> String raise {
  let fn_qr = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.residue_ntheory', fromlist=['quadratic_residues']).quadratic_residues(n)",
  )
  let res = py_call_with_args(fn_qr, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn sqrt_mod_str(
  a : Int,
  n : Int,
  all_roots? : Bool = false,
) -> String raise {
  let fn_sqrt = py_eval_callable(
    "lambda a, n, all_roots: __import__('sympy.ntheory.residue_ntheory', fromlist=['sqrt_mod']).sqrt_mod(a, n, all_roots=all_roots)",
  )
  let res = py_call_with_args_opt(fn_sqrt, [
    OracleArg::Int(a),
    OracleArg::Int(n),
    OracleArg::Bool(all_roots),
  ])
  py_str_enum_opt(res)
}

///|
pub fn is_nthpow_residue_str(a : Int, n : Int, m : Int) -> String raise {
  let fn_inr = py_eval_callable(
    "lambda a, n, m: __import__('sympy.ntheory.residue_ntheory', fromlist=['is_nthpow_residue']).is_nthpow_residue(a, n, m)",
  )
  let res = py_call_with_args(fn_inr, [
    OracleArg::Int(a),
    OracleArg::Int(n),
    OracleArg::Int(m),
  ])
  py_str_enum(res)
}

///|
pub fn nthroot_mod_str(
  a : Int,
  n : Int,
  m : Int,
  all_roots? : Bool = false,
) -> String raise {
  let fn_nth = py_eval_callable(
    "lambda a, n, m, all_roots: __import__('sympy.ntheory.residue_ntheory', fromlist=['nthroot_mod']).nthroot_mod(a, n, m, all_roots=all_roots)",
  )
  let res = py_call_with_args_opt(fn_nth, [
    OracleArg::Int(a),
    OracleArg::Int(n),
    OracleArg::Int(m),
    OracleArg::Bool(all_roots),
  ])
  py_str_enum_opt(res)
}

///|
pub fn mobius_str(n : Int) -> String raise {
  let fn_mobius = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['mobius']).mobius(n)",
  )
  let res = py_call_with_args(fn_mobius, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn discrete_log_str(n : Int, a : Int, b : Int) -> String raise {
  let fn_dl = py_eval_callable(
    "lambda n, a, b: __import__('sympy.ntheory.residue_ntheory', fromlist=['discrete_log']).discrete_log(n, a, b)",
  )
  let res = py_call_with_args_opt(fn_dl, [
    OracleArg::Int(n),
    OracleArg::Int(a),
    OracleArg::Int(b),
  ])
  py_str_enum_opt(res)
}

///|
pub fn quadratic_congruence_str(
  a : Int,
  b : Int,
  c : Int,
  n : Int,
) -> String raise {
  let fn_qc = py_eval_callable(
    "lambda a, b, c, n: __import__('sympy.ntheory.residue_ntheory', fromlist=['quadratic_congruence']).quadratic_congruence(a, b, c, n)",
  )
  let res = py_call_with_args(fn_qc, [
    OracleArg::Int(a),
    OracleArg::Int(b),
    OracleArg::Int(c),
    OracleArg::Int(n),
  ])
  py_str_enum(res)
}

///|
pub fn polynomial_congruence_str(coeffs : Array[Int], m : Int) -> String raise {
  let fn_pc = py_eval_callable(
    "lambda coeffs, m: (lambda x: __import__('sympy.ntheory.residue_ntheory', fromlist=['polynomial_congruence']).polynomial_congruence(sum((__import__('sympy', fromlist=['Integer']).Integer(c)) * x**(len(coeffs) - i - 1) for i, c in enumerate(coeffs)), m))(__import__('sympy', fromlist=['symbols']).symbols('x'))",
  )
  let res = py_call_with_args(fn_pc, [
    OracleArg::IntList(coeffs),
    OracleArg::Int(m),
  ])
  py_str_enum(res)
}

///|
pub fn binomial_mod_str(n : Int, k : Int, m : Int) -> String raise {
  let fn_bm = py_eval_callable(
    "lambda n, k, m: __import__('sympy.ntheory.residue_ntheory', fromlist=['binomial_mod']).binomial_mod(n, k, m)",
  )
  let res = py_call_with_args(fn_bm, [
    OracleArg::Int(n),
    OracleArg::Int(k),
    OracleArg::Int(m),
  ])
  py_str_enum(res)
}

///|
pub fn is_gaussian_prime_str(a : Int, b? : Int = 0) -> String raise {
  let fn_gp = py_eval_callable(
    "lambda a, b: __import__('sympy.ntheory.primetest', fromlist=['is_gaussian_prime']).is_gaussian_prime(a if b == 0 else a + b*__import__('sympy', fromlist=['I']).I)",
  )
  let res = py_call_with_args(fn_gp, [OracleArg::Int(a), OracleArg::Int(b)])
  py_str_enum(res)
}

///|
pub fn is_mersenne_prime_str(n : Int) -> String raise {
  let fn_mp = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.primetest', fromlist=['is_mersenne_prime']).is_mersenne_prime(n)",
  )
  let res = py_call_with_args(fn_mp, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn nextprime_str(n : Int) -> String raise {
  let fn_np = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.generate', fromlist=['nextprime']).nextprime(n)",
  )
  let res = py_call_with_args(fn_np, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn prevprime_str(n : Int) -> String raise {
  let fn_pp = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.generate', fromlist=['prevprime']).prevprime(n)",
  )
  let res = py_call_with_args(fn_pp, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn primepi_str(n : Int) -> String raise {
  let fn_ppi = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['primepi']).primepi(n)",
  )
  let res = py_call_with_args(fn_ppi, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn primerange_str(a : Int, b? : Int = 0) -> String raise {
  let fn_pr = py_eval_callable(
    "lambda a, b: list(__import__('sympy.ntheory.generate', fromlist=['primerange']).primerange(2, a) if b == 0 else __import__('sympy.ntheory.generate', fromlist=['primerange']).primerange(a, b))",
  )
  let res = py_call_with_args(fn_pr, [OracleArg::Int(a), OracleArg::Int(b)])
  py_str_enum(res)
}

///|
pub fn primorial_str(n : Int, nth? : Bool = true) -> String raise {
  let fn_pri = py_eval_callable(
    "lambda n, nth: __import__('sympy.ntheory.generate', fromlist=['primorial']).primorial(n, nth=nth)",
  )
  let res = py_call_with_args(fn_pri, [OracleArg::Int(n), OracleArg::Bool(nth)])
  py_str_enum(res)
}

///|
pub fn composite_str(n : Int) -> String raise {
  let fn_comp = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.generate', fromlist=['composite']).composite(n)",
  )
  let res = py_call_with_args(fn_comp, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn compositepi_str(n : Int) -> String raise {
  let fn_compi = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.generate', fromlist=['compositepi']).compositepi(n)",
  )
  let res = py_call_with_args(fn_compi, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn cycle_length_str(
  x0 : Int,
  nmax? : Int = -1,
  values? : Bool = false,
) -> String raise {
  let fn_cl = py_eval_callable(
    "lambda x0, nmax, values: (list(__import__('sympy.ntheory.generate', fromlist=['cycle_length']).cycle_length(lambda i: (i*i + 1) % 51, x0, None if nmax < 0 else nmax, values=True)) if values else next(__import__('sympy.ntheory.generate', fromlist=['cycle_length']).cycle_length(lambda i: (i*i + 1) % 51, x0, None if nmax < 0 else nmax)))",
  )
  let res = py_call_with_args(fn_cl, [
    OracleArg::Int(x0),
    OracleArg::Int(nmax),
    OracleArg::Bool(values),
  ])
  py_str_enum(res)
}

///|
pub fn factorint_pairs_str(n : Int) -> String raise {
  let fn_fi = py_eval_callable(
    "lambda n: sorted(__import__('sympy.ntheory.factor_', fromlist=['factorint']).factorint(n).items())",
  )
  let res = py_call_with_args(fn_fi, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn divisors_str(n : Int) -> String raise {
  let fn_div = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['divisors']).divisors(n)",
  )
  let res = py_call_with_args(fn_div, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn proper_divisors_str(n : Int) -> String raise {
  let fn_div = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['proper_divisors']).proper_divisors(n)",
  )
  let res = py_call_with_args(fn_div, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn multiplicity_str(p : Int, n : Int) -> String raise {
  let fn_mul = py_eval_callable(
    "lambda p, n: __import__('sympy.ntheory.factor_', fromlist=['multiplicity']).multiplicity(p, n)",
  )
  let res = py_call_with_args(fn_mul, [OracleArg::Int(p), OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn multiplicity_in_factorial_str(p : Int, n : Int) -> String raise {
  let fn_mf = py_eval_callable(
    "lambda p, n: __import__('sympy.ntheory.factor_', fromlist=['multiplicity_in_factorial']).multiplicity_in_factorial(p, n)",
  )
  let res = py_call_with_args(fn_mf, [OracleArg::Int(p), OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn perfect_power_str(n : Int) -> String raise {
  let fn_pp = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['perfect_power']).perfect_power(n)",
  )
  let res = py_call_with_args_opt(fn_pp, [OracleArg::Int(n)])
  py_str_enum_opt(res)
}

///|
pub fn primefactors_str(n : Int) -> String raise {
  let fn_pf = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['primefactors']).primefactors(n)",
  )
  let res = py_call_with_args(fn_pf, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn totient_str(n : Int) -> String raise {
  let fn_tot = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['totient']).totient(n)",
  )
  let res = py_call_with_args(fn_tot, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn divisor_count_str(n : Int) -> String raise {
  let fn_dc = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['divisor_count']).divisor_count(n)",
  )
  let res = py_call_with_args(fn_dc, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn proper_divisor_count_str(n : Int) -> String raise {
  let fn_dc = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['proper_divisor_count']).proper_divisor_count(n)",
  )
  let res = py_call_with_args(fn_dc, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn divisor_sigma_str(n : Int, k? : Int = 1) -> String raise {
  let fn_ds = py_eval_callable(
    "lambda n, k: __import__('sympy.functions.combinatorial.numbers', fromlist=['divisor_sigma']).divisor_sigma(n, k)",
  )
  let res = py_call_with_args(fn_ds, [OracleArg::Int(n), OracleArg::Int(k)])
  py_str_enum(res)
}

///|
pub fn factorrat_pairs_str(num : Int, den? : Int = 1) -> String raise {
  let fn_fr = py_eval_callable(
    "lambda num, den: sorted(__import__('sympy.ntheory.factor_', fromlist=['factorrat']).factorrat(__import__('sympy', fromlist=['Rational']).Rational(num, den)).items())",
  )
  let res = py_call_with_args(fn_fr, [OracleArg::Int(num), OracleArg::Int(den)])
  py_str_enum(res)
}

///|
pub fn reduced_totient_str(n : Int) -> String raise {
  let fn_rt = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['reduced_totient']).reduced_totient(n)",
  )
  let res = py_call_with_args(fn_rt, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn primenu_str(n : Int) -> String raise {
  let fn_pn = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['primenu']).primenu(n)",
  )
  let res = py_call_with_args(fn_pn, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn primeomega_str(n : Int) -> String raise {
  let fn_po = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['primeomega']).primeomega(n)",
  )
  let res = py_call_with_args(fn_po, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn mersenne_prime_exponent_str(n : Int) -> String raise {
  let fn_mpe = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['mersenne_prime_exponent']).mersenne_prime_exponent(n)",
  )
  let res = py_call_with_args(fn_mpe, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn is_perfect_str(n : Int) -> String raise {
  let fn_ip = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['is_perfect']).is_perfect(n)",
  )
  let res = py_call_with_args(fn_ip, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn abundance_str(n : Int) -> String raise {
  let fn_ab = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['abundance']).abundance(n)",
  )
  let res = py_call_with_args(fn_ab, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn is_abundant_str(n : Int) -> String raise {
  let fn_ab = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['is_abundant']).is_abundant(n)",
  )
  let res = py_call_with_args(fn_ab, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn is_deficient_str(n : Int) -> String raise {
  let fn_df = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['is_deficient']).is_deficient(n)",
  )
  let res = py_call_with_args(fn_df, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn is_amicable_str(m : Int, n : Int) -> String raise {
  let fn_am = py_eval_callable(
    "lambda m, n: __import__('sympy.ntheory.factor_', fromlist=['is_amicable']).is_amicable(m, n)",
  )
  let res = py_call_with_args(fn_am, [OracleArg::Int(m), OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn is_carmichael_str(n : Int) -> String raise {
  let fn_ic = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['is_carmichael']).is_carmichael(n)",
  )
  let res = py_call_with_args(fn_ic, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn dra_str(n : Int, b : Int) -> String raise {
  let fn_dra = py_eval_callable(
    "lambda n, b: __import__('sympy.ntheory.factor_', fromlist=['dra']).dra(n, b)",
  )
  let res = py_call_with_args(fn_dra, [OracleArg::Int(n), OracleArg::Int(b)])
  py_str_enum(res)
}

///|
pub fn drm_str(n : Int, b : Int) -> String raise {
  let fn_drm = py_eval_callable(
    "lambda n, b: __import__('sympy.ntheory.factor_', fromlist=['drm']).drm(n, b)",
  )
  let res = py_call_with_args(fn_drm, [OracleArg::Int(n), OracleArg::Int(b)])
  py_str_enum(res)
}

///|
pub fn digits_str(n : Int, b? : Int = 10, digits? : Int = -1) -> String raise {
  let fn_digits = py_eval_callable(
    "lambda n, b, d: __import__('sympy.ntheory.digits', fromlist=['digits']).digits(n, b=b, digits=None if d < 0 else d)",
  )
  let res = py_call_with_args(fn_digits, [
    OracleArg::Int(n),
    OracleArg::Int(b),
    OracleArg::Int(digits),
  ])
  py_str_enum(res)
}

///|
pub fn count_digits_pairs_str(n : Int, b? : Int = 10) -> String raise {
  let fn_cd = py_eval_callable(
    "lambda n, b: sorted(__import__('sympy.ntheory.digits', fromlist=['count_digits']).count_digits(n, b=b).items())",
  )
  let res = py_call_with_args(fn_cd, [OracleArg::Int(n), OracleArg::Int(b)])
  py_str_enum(res)
}

///|
pub fn is_palindromic_str(n : Int, b? : Int = 10) -> String raise {
  let fn_ip = py_eval_callable(
    "lambda n, b: __import__('sympy.ntheory.digits', fromlist=['is_palindromic']).is_palindromic(n, b=b)",
  )
  let res = py_call_with_args(fn_ip, [OracleArg::Int(n), OracleArg::Int(b)])
  py_str_enum(res)
}

///|
pub fn binomial_coefficients_str(n : Int) -> String raise {
  let fn_bc = py_eval_callable(
    "lambda n: sorted(__import__('sympy.ntheory.multinomial', fromlist=['binomial_coefficients']).binomial_coefficients(n).items())",
  )
  let res = py_call_with_args(fn_bc, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn binomial_coefficients_list_str(n : Int) -> String raise {
  let fn_bcl = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.multinomial', fromlist=['binomial_coefficients_list']).binomial_coefficients_list(n)",
  )
  let res = py_call_with_args(fn_bcl, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn multinomial_coefficients_str(n : Int, m : Int) -> String raise {
  let fn_mc = py_eval_callable(
    "lambda n, m: sorted(__import__('sympy.ntheory.multinomial', fromlist=['multinomial_coefficients']).multinomial_coefficients(n, m).items())",
  )
  let res = py_call_with_args(fn_mc, [OracleArg::Int(n), OracleArg::Int(m)])
  py_str_enum(res)
}

///|
pub fn npartitions_str(n : Int) -> String raise {
  let fn_np = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['partition']).partition(n)",
  )
  let res = py_call_with_args(fn_np, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn continued_fraction_str(num : Int, den? : Int = 1) -> String raise {
  let fn_cf = py_eval_callable(
    "lambda num, den: __import__('sympy.ntheory.continued_fraction', fromlist=['continued_fraction']).continued_fraction(__import__('sympy', fromlist=['Rational']).Rational(num, den))",
  )
  let res = py_call_with_args(fn_cf, [OracleArg::Int(num), OracleArg::Int(den)])
  py_str_enum(res)
}

///|
pub fn continued_fraction_periodic_str(
  p : Int,
  q : Int,
  d? : Int = 0,
  s? : Int = 1,
) -> String raise {
  let fn_cfp = py_eval_callable(
    "lambda p, q, d, s: __import__('sympy.ntheory.continued_fraction', fromlist=['continued_fraction_periodic']).continued_fraction_periodic(p, q, d, s)",
  )
  let res = py_call_with_args(fn_cfp, [
    OracleArg::Int(p),
    OracleArg::Int(q),
    OracleArg::Int(d),
    OracleArg::Int(s),
  ])
  py_str_enum(res)
}

///|
pub fn continued_fraction_reduce_str(terms : Array[Int]) -> String raise {
  let fn_cfr = py_eval_callable(
    "lambda terms: __import__('sympy.ntheory.continued_fraction', fromlist=['continued_fraction_reduce']).continued_fraction_reduce(terms)",
  )
  let res = py_call_with_args(fn_cfr, [OracleArg::IntList(terms)])
  py_str_enum(res)
}

///|
pub fn continued_fraction_convergents_str(terms : Array[Int]) -> String raise {
  let fn_cfc = py_eval_callable(
    "lambda terms: list(__import__('sympy.ntheory.continued_fraction', fromlist=['continued_fraction_convergents']).continued_fraction_convergents(terms))",
  )
  let res = py_call_with_args(fn_cfc, [OracleArg::IntList(terms)])
  py_str_enum(res)
}

///|
pub fn egyptian_fraction_str(num : Int, den : Int) -> String raise {
  let fn_ef = py_eval_callable(
    "lambda num, den: __import__('sympy.ntheory.egyptian_fraction', fromlist=['egyptian_fraction']).egyptian_fraction(__import__('sympy', fromlist=['Rational']).Rational(num, den))",
  )
  let res = py_call_with_args(fn_ef, [OracleArg::Int(num), OracleArg::Int(den)])
  py_str_enum(res)
}

///|
pub fn elliptic_curve_points_str(
  a4 : Int,
  a6 : Int,
  a1? : Int = 0,
  a2? : Int = 0,
  a3? : Int = 0,
  modulus? : Int = 0,
) -> String raise {
  let fn_ec = py_eval_callable(
    "lambda a4, a6, a1, a2, a3, modulus: sorted(__import__('sympy.ntheory.elliptic_curve', fromlist=['EllipticCurve']).EllipticCurve(a4, a6, a1, a2, a3, modulus=modulus).points())",
  )
  let res = py_call_with_args(fn_ec, [
    OracleArg::Int(a4),
    OracleArg::Int(a6),
    OracleArg::Int(a1),
    OracleArg::Int(a2),
    OracleArg::Int(a3),
    OracleArg::Int(modulus),
  ])
  py_str_enum(res)
}

///|
pub fn ecm_factors_str(n : Int) -> String raise {
  let fn_ecm = py_eval_callable(
    "lambda n: sorted(__import__('sympy.ntheory.factor_', fromlist=['factorint']).factorint(n).keys())",
  )
  let res = py_call_with_args(fn_ecm, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn qs_factor_str(
  n : Int,
  prime_bound? : Int = 2000,
  m? : Int = 10000,
  error_term? : Int = 25,
  seed? : Int = 1234,
) -> String raise {
  let fn_qsf = py_eval_callable(
    "lambda n, pb, m, err, seed: sorted(__import__('sympy.ntheory.qs', fromlist=['qs_factor']).qs_factor(n, pb, m, ERROR_TERM=err, seed=seed).items())",
  )
  let res = py_call_with_args(fn_qsf, [
    OracleArg::Int(n),
    OracleArg::Int(prime_bound),
    OracleArg::Int(m),
    OracleArg::Int(error_term),
    OracleArg::Int(seed),
  ])
  py_str_enum(res)
}

///|
pub fn qs_str(
  n : Int,
  prime_bound? : Int = 2000,
  m? : Int = 10000,
  error_term? : Int = 25,
  seed? : Int = 1234,
) -> String raise {
  let fn_qs = py_eval_callable(
    "lambda n, pb, m, err, seed: sorted(__import__('sympy.ntheory.qs', fromlist=['qs']).qs(n, pb, m, ERROR_TERM=err, seed=seed))",
  )
  let res = py_call_with_args(fn_qs, [
    OracleArg::Int(n),
    OracleArg::Int(prime_bound),
    OracleArg::Int(m),
    OracleArg::Int(error_term),
    OracleArg::Int(seed),
  ])
  py_str_enum(res)
}

///|
pub fn pi_hex_digits_str(n : Int, prec? : Int = 14) -> String raise {
  let fn_pi = py_eval_callable(
    "lambda n, prec: __import__('sympy.ntheory.bbp_pi', fromlist=['pi_hex_digits']).pi_hex_digits(n, prec)",
  )
  let res = py_call_with_args(fn_pi, [OracleArg::Int(n), OracleArg::Int(prec)])
  py_str_enum(res)
}
