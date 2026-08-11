///|
/// Oracle helpers for SymPy ntheory.

///|
priv enum OracleArg {
  Int(Int)
  Bool(Bool)
  IntList(Array[Int])
}

///|
priv struct RecipeCallable {
  builder : @recipe.Builder
  value : @recipe.ValueRef
}

///|
priv struct RecipeResult {
  builder : @recipe.Builder
  value : @recipe.ValueRef
}

///|
fn int_arg(value : Int) -> @recipe.RecipeArg {
  DecimalInt(Show::to_string(value))
}

///|
fn OracleArg::materialize(
  self : OracleArg,
  builder : @recipe.Builder,
) -> @recipe.RecipeArg raise {
  match self {
    Int(value) => int_arg(value)
    Bool(value) => Bool(value)
    IntList(values) => {
      let items : Array[@recipe.RecipeArg] = values.map(int_arg)
      Ref(builder.list(items))
    }
  }
}

///|
fn py_eval_callable(source : String) -> RecipeCallable raise {
  let builder = @recipe.Builder::new()
  let builtins = builder.import_module("builtins")
  let scope = builder.dict([(Str("__builtins__"), Ref(builtins))])
  let callable = builder.eval(scope, source)
  let callable = builder.require_non_none(callable, message="py-eval-none")
  { builder, value: callable }
}

///|
fn recipe_call(
  callable : RecipeCallable,
  args : Array[OracleArg],
) -> RecipeResult raise {
  let call_args : Array[@recipe.RecipeArg] = []
  for arg in args {
    call_args.push(arg.materialize(callable.builder))
  }
  let result = callable.builder.call(callable.value, call_args)
  { builder: callable.builder, value: result }
}

///|
fn py_call_with_args(
  callable : RecipeCallable,
  args : Array[OracleArg],
) -> RecipeResult raise {
  let result = recipe_call(callable, args)
  let value = result.builder.require_non_none(
    result.value,
    message="py-call-none",
  )
  { builder: result.builder, value }
}

///|
fn py_call_with_args_opt(
  callable : RecipeCallable,
  args : Array[OracleArg],
) -> RecipeResult raise {
  recipe_call(callable, args)
}

///|
fn py_str_enum(result : RecipeResult) -> String raise {
  result.builder.request_str(result.value)
}

///|
fn py_str_enum_opt(result : RecipeResult) -> String raise {
  result.builder.request_str(result.value)
}

///|
pub fn isprime_str(n : Int) -> String raise {
  let fn_isprime = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.primetest', fromlist=['isprime']).isprime(n)",
  )
  let res = py_call_with_args(fn_isprime, [Int(n)])
  py_str_enum(res)
}

///|
pub fn prime_str(n : Int) -> String raise {
  let fn_prime = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.generate', fromlist=['prime']).prime(n)",
  )
  let res = py_call_with_args(fn_prime, [Int(n)])
  py_str_enum(res)
}

///|
pub fn symmetric_residue_str(a : Int, m : Int) -> String raise {
  let fn_sr = py_eval_callable(
    "lambda a, m: __import__('sympy.ntheory.modular', fromlist=['symmetric_residue']).symmetric_residue(a, m)",
  )
  let res = py_call_with_args(fn_sr, [Int(a), Int(m)])
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
    IntList(moduli),
    IntList(residues),
    Bool(symmetric),
    Bool(check),
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
    IntList(remainders),
    IntList(moduli),
    Bool(symmetric),
    Bool(check),
  ])
  py_str_enum_opt(res)
}

///|
pub fn n_order_str(a : Int, n : Int) -> String raise {
  let fn_n_order = py_eval_callable(
    "lambda a, n: __import__('sympy.ntheory.residue_ntheory', fromlist=['n_order']).n_order(a, n)",
  )
  let res = py_call_with_args(fn_n_order, [Int(a), Int(n)])
  py_str_enum(res)
}

///|
pub fn is_primitive_root_str(a : Int, n : Int) -> String raise {
  let fn_ipr = py_eval_callable(
    "lambda a, n: __import__('sympy.ntheory.residue_ntheory', fromlist=['is_primitive_root']).is_primitive_root(a, n)",
  )
  let res = py_call_with_args(fn_ipr, [Int(a), Int(n)])
  py_str_enum(res)
}

///|
pub fn primitive_root_str(n : Int, smallest? : Bool = true) -> String raise {
  let fn_pr = py_eval_callable(
    "lambda n, smallest: __import__('sympy.ntheory.residue_ntheory', fromlist=['primitive_root']).primitive_root(n, smallest=smallest)",
  )
  let res = py_call_with_args_opt(fn_pr, [Int(n), Bool(smallest)])
  py_str_enum_opt(res)
}

///|
pub fn legendre_symbol_str(a : Int, p : Int) -> String raise {
  let fn_ls = py_eval_callable(
    "lambda a, p: __import__('sympy.functions.combinatorial.numbers', fromlist=['legendre_symbol']).legendre_symbol(a, p)",
  )
  let res = py_call_with_args(fn_ls, [Int(a), Int(p)])
  py_str_enum(res)
}

///|
pub fn jacobi_symbol_str(a : Int, n : Int) -> String raise {
  let fn_js = py_eval_callable(
    "lambda a, n: __import__('sympy.functions.combinatorial.numbers', fromlist=['jacobi_symbol']).jacobi_symbol(a, n)",
  )
  let res = py_call_with_args(fn_js, [Int(a), Int(n)])
  py_str_enum(res)
}

///|
pub fn is_quad_residue_str(a : Int, n : Int) -> String raise {
  let fn_iqr = py_eval_callable(
    "lambda a, n: __import__('sympy.ntheory.residue_ntheory', fromlist=['is_quad_residue']).is_quad_residue(a, n)",
  )
  let res = py_call_with_args(fn_iqr, [Int(a), Int(n)])
  py_str_enum(res)
}

///|
pub fn quadratic_residues_str(n : Int) -> String raise {
  let fn_qr = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.residue_ntheory', fromlist=['quadratic_residues']).quadratic_residues(n)",
  )
  let res = py_call_with_args(fn_qr, [Int(n)])
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
  let res = py_call_with_args_opt(fn_sqrt, [Int(a), Int(n), Bool(all_roots)])
  py_str_enum_opt(res)
}

///|
pub fn is_nthpow_residue_str(a : Int, n : Int, m : Int) -> String raise {
  let fn_inr = py_eval_callable(
    "lambda a, n, m: __import__('sympy.ntheory.residue_ntheory', fromlist=['is_nthpow_residue']).is_nthpow_residue(a, n, m)",
  )
  let res = py_call_with_args(fn_inr, [Int(a), Int(n), Int(m)])
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
    Int(a),
    Int(n),
    Int(m),
    Bool(all_roots),
  ])
  py_str_enum_opt(res)
}

///|
pub fn mobius_str(n : Int) -> String raise {
  let fn_mobius = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['mobius']).mobius(n)",
  )
  let res = py_call_with_args(fn_mobius, [Int(n)])
  py_str_enum(res)
}

///|
pub fn discrete_log_str(n : Int, a : Int, b : Int) -> String raise {
  let fn_dl = py_eval_callable(
    "lambda n, a, b: __import__('sympy.ntheory.residue_ntheory', fromlist=['discrete_log']).discrete_log(n, a, b)",
  )
  let res = py_call_with_args_opt(fn_dl, [Int(n), Int(a), Int(b)])
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
  let res = py_call_with_args(fn_qc, [Int(a), Int(b), Int(c), Int(n)])
  py_str_enum(res)
}

///|
pub fn polynomial_congruence_str(coeffs : Array[Int], m : Int) -> String raise {
  let fn_pc = py_eval_callable(
    "lambda coeffs, m: (lambda x: __import__('sympy.ntheory.residue_ntheory', fromlist=['polynomial_congruence']).polynomial_congruence(sum((__import__('sympy', fromlist=['Integer']).Integer(c)) * x**(len(coeffs) - i - 1) for i, c in enumerate(coeffs)), m))(__import__('sympy', fromlist=['symbols']).symbols('x'))",
  )
  let res = py_call_with_args(fn_pc, [IntList(coeffs), Int(m)])
  py_str_enum(res)
}

///|
pub fn binomial_mod_str(n : Int, k : Int, m : Int) -> String raise {
  let fn_bm = py_eval_callable(
    "lambda n, k, m: __import__('sympy.ntheory.residue_ntheory', fromlist=['binomial_mod']).binomial_mod(n, k, m)",
  )
  let res = py_call_with_args(fn_bm, [Int(n), Int(k), Int(m)])
  py_str_enum(res)
}

///|
pub fn is_gaussian_prime_str(a : Int, b? : Int = 0) -> String raise {
  let fn_gp = py_eval_callable(
    "lambda a, b: __import__('sympy.ntheory.primetest', fromlist=['is_gaussian_prime']).is_gaussian_prime(a if b == 0 else a + b*__import__('sympy', fromlist=['I']).I)",
  )
  let res = py_call_with_args(fn_gp, [Int(a), Int(b)])
  py_str_enum(res)
}

///|
pub fn is_mersenne_prime_str(n : Int) -> String raise {
  let fn_mp = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.primetest', fromlist=['is_mersenne_prime']).is_mersenne_prime(n)",
  )
  let res = py_call_with_args(fn_mp, [Int(n)])
  py_str_enum(res)
}

///|
pub fn nextprime_str(n : Int) -> String raise {
  let fn_np = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.generate', fromlist=['nextprime']).nextprime(n)",
  )
  let res = py_call_with_args(fn_np, [Int(n)])
  py_str_enum(res)
}

///|
pub fn prevprime_str(n : Int) -> String raise {
  let fn_pp = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.generate', fromlist=['prevprime']).prevprime(n)",
  )
  let res = py_call_with_args(fn_pp, [Int(n)])
  py_str_enum(res)
}

///|
pub fn primepi_str(n : Int) -> String raise {
  let fn_ppi = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['primepi']).primepi(n)",
  )
  let res = py_call_with_args(fn_ppi, [Int(n)])
  py_str_enum(res)
}

///|
pub fn primerange_str(a : Int, b? : Int = 0) -> String raise {
  let fn_pr = py_eval_callable(
    "lambda a, b: list(__import__('sympy.ntheory.generate', fromlist=['primerange']).primerange(2, a) if b == 0 else __import__('sympy.ntheory.generate', fromlist=['primerange']).primerange(a, b))",
  )
  let res = py_call_with_args(fn_pr, [Int(a), Int(b)])
  py_str_enum(res)
}

///|
pub fn primorial_str(n : Int, nth? : Bool = true) -> String raise {
  let fn_pri = py_eval_callable(
    "lambda n, nth: __import__('sympy.ntheory.generate', fromlist=['primorial']).primorial(n, nth=nth)",
  )
  let res = py_call_with_args(fn_pri, [Int(n), Bool(nth)])
  py_str_enum(res)
}

///|
pub fn composite_str(n : Int) -> String raise {
  let fn_comp = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.generate', fromlist=['composite']).composite(n)",
  )
  let res = py_call_with_args(fn_comp, [Int(n)])
  py_str_enum(res)
}

///|
pub fn compositepi_str(n : Int) -> String raise {
  let fn_compi = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.generate', fromlist=['compositepi']).compositepi(n)",
  )
  let res = py_call_with_args(fn_compi, [Int(n)])
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
  let res = py_call_with_args(fn_cl, [Int(x0), Int(nmax), Bool(values)])
  py_str_enum(res)
}

///|
pub fn factorint_pairs_str(n : Int) -> String raise {
  let fn_fi = py_eval_callable(
    "lambda n: sorted(__import__('sympy.ntheory.factor_', fromlist=['factorint']).factorint(n).items())",
  )
  let res = py_call_with_args(fn_fi, [Int(n)])
  py_str_enum(res)
}

///|
pub fn divisors_str(n : Int) -> String raise {
  let fn_div = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['divisors']).divisors(n)",
  )
  let res = py_call_with_args(fn_div, [Int(n)])
  py_str_enum(res)
}

///|
pub fn proper_divisors_str(n : Int) -> String raise {
  let fn_div = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['proper_divisors']).proper_divisors(n)",
  )
  let res = py_call_with_args(fn_div, [Int(n)])
  py_str_enum(res)
}

///|
pub fn multiplicity_str(p : Int, n : Int) -> String raise {
  let fn_mul = py_eval_callable(
    "lambda p, n: __import__('sympy.ntheory.factor_', fromlist=['multiplicity']).multiplicity(p, n)",
  )
  let res = py_call_with_args(fn_mul, [Int(p), Int(n)])
  py_str_enum(res)
}

///|
pub fn multiplicity_in_factorial_str(p : Int, n : Int) -> String raise {
  let fn_mf = py_eval_callable(
    "lambda p, n: __import__('sympy.ntheory.factor_', fromlist=['multiplicity_in_factorial']).multiplicity_in_factorial(p, n)",
  )
  let res = py_call_with_args(fn_mf, [Int(p), Int(n)])
  py_str_enum(res)
}

///|
pub fn perfect_power_str(n : Int) -> String raise {
  let fn_pp = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['perfect_power']).perfect_power(n)",
  )
  let res = py_call_with_args_opt(fn_pp, [Int(n)])
  py_str_enum_opt(res)
}

///|
pub fn primefactors_str(n : Int) -> String raise {
  let fn_pf = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['primefactors']).primefactors(n)",
  )
  let res = py_call_with_args(fn_pf, [Int(n)])
  py_str_enum(res)
}

///|
pub fn totient_str(n : Int) -> String raise {
  let fn_tot = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['totient']).totient(n)",
  )
  let res = py_call_with_args(fn_tot, [Int(n)])
  py_str_enum(res)
}

///|
pub fn divisor_count_str(n : Int) -> String raise {
  let fn_dc = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['divisor_count']).divisor_count(n)",
  )
  let res = py_call_with_args(fn_dc, [Int(n)])
  py_str_enum(res)
}

///|
pub fn proper_divisor_count_str(n : Int) -> String raise {
  let fn_dc = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['proper_divisor_count']).proper_divisor_count(n)",
  )
  let res = py_call_with_args(fn_dc, [Int(n)])
  py_str_enum(res)
}

///|
pub fn divisor_sigma_str(n : Int, k? : Int = 1) -> String raise {
  let fn_ds = py_eval_callable(
    "lambda n, k: __import__('sympy.functions.combinatorial.numbers', fromlist=['divisor_sigma']).divisor_sigma(n, k)",
  )
  let res = py_call_with_args(fn_ds, [Int(n), Int(k)])
  py_str_enum(res)
}

///|
pub fn factorrat_pairs_str(num : Int, den? : Int = 1) -> String raise {
  let fn_fr = py_eval_callable(
    "lambda num, den: sorted(__import__('sympy.ntheory.factor_', fromlist=['factorrat']).factorrat(__import__('sympy', fromlist=['Rational']).Rational(num, den)).items())",
  )
  let res = py_call_with_args(fn_fr, [Int(num), Int(den)])
  py_str_enum(res)
}

///|
pub fn reduced_totient_str(n : Int) -> String raise {
  let fn_rt = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['reduced_totient']).reduced_totient(n)",
  )
  let res = py_call_with_args(fn_rt, [Int(n)])
  py_str_enum(res)
}

///|
pub fn primenu_str(n : Int) -> String raise {
  let fn_pn = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['primenu']).primenu(n)",
  )
  let res = py_call_with_args(fn_pn, [Int(n)])
  py_str_enum(res)
}

///|
pub fn primeomega_str(n : Int) -> String raise {
  let fn_po = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['primeomega']).primeomega(n)",
  )
  let res = py_call_with_args(fn_po, [Int(n)])
  py_str_enum(res)
}

///|
pub fn mersenne_prime_exponent_str(n : Int) -> String raise {
  let fn_mpe = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['mersenne_prime_exponent']).mersenne_prime_exponent(n)",
  )
  let res = py_call_with_args(fn_mpe, [Int(n)])
  py_str_enum(res)
}

///|
pub fn is_perfect_str(n : Int) -> String raise {
  let fn_ip = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['is_perfect']).is_perfect(n)",
  )
  let res = py_call_with_args(fn_ip, [Int(n)])
  py_str_enum(res)
}

///|
pub fn abundance_str(n : Int) -> String raise {
  let fn_ab = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['abundance']).abundance(n)",
  )
  let res = py_call_with_args(fn_ab, [Int(n)])
  py_str_enum(res)
}

///|
pub fn is_abundant_str(n : Int) -> String raise {
  let fn_ab = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['is_abundant']).is_abundant(n)",
  )
  let res = py_call_with_args(fn_ab, [Int(n)])
  py_str_enum(res)
}

///|
pub fn is_deficient_str(n : Int) -> String raise {
  let fn_df = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['is_deficient']).is_deficient(n)",
  )
  let res = py_call_with_args(fn_df, [Int(n)])
  py_str_enum(res)
}

///|
pub fn is_amicable_str(m : Int, n : Int) -> String raise {
  let fn_am = py_eval_callable(
    "lambda m, n: __import__('sympy.ntheory.factor_', fromlist=['is_amicable']).is_amicable(m, n)",
  )
  let res = py_call_with_args(fn_am, [Int(m), Int(n)])
  py_str_enum(res)
}

///|
pub fn is_carmichael_str(n : Int) -> String raise {
  let fn_ic = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.factor_', fromlist=['is_carmichael']).is_carmichael(n)",
  )
  let res = py_call_with_args(fn_ic, [Int(n)])
  py_str_enum(res)
}

///|
pub fn dra_str(n : Int, b : Int) -> String raise {
  let fn_dra = py_eval_callable(
    "lambda n, b: __import__('sympy.ntheory.factor_', fromlist=['dra']).dra(n, b)",
  )
  let res = py_call_with_args(fn_dra, [Int(n), Int(b)])
  py_str_enum(res)
}

///|
pub fn drm_str(n : Int, b : Int) -> String raise {
  let fn_drm = py_eval_callable(
    "lambda n, b: __import__('sympy.ntheory.factor_', fromlist=['drm']).drm(n, b)",
  )
  let res = py_call_with_args(fn_drm, [Int(n), Int(b)])
  py_str_enum(res)
}

///|
pub fn digits_str(n : Int, b? : Int = 10, digits? : Int = -1) -> String raise {
  let fn_digits = py_eval_callable(
    "lambda n, b, d: __import__('sympy.ntheory.digits', fromlist=['digits']).digits(n, b=b, digits=None if d < 0 else d)",
  )
  let res = py_call_with_args(fn_digits, [Int(n), Int(b), Int(digits)])
  py_str_enum(res)
}

///|
pub fn count_digits_pairs_str(n : Int, b? : Int = 10) -> String raise {
  let fn_cd = py_eval_callable(
    "lambda n, b: sorted(__import__('sympy.ntheory.digits', fromlist=['count_digits']).count_digits(n, b=b).items())",
  )
  let res = py_call_with_args(fn_cd, [Int(n), Int(b)])
  py_str_enum(res)
}

///|
pub fn is_palindromic_str(n : Int, b? : Int = 10) -> String raise {
  let fn_ip = py_eval_callable(
    "lambda n, b: __import__('sympy.ntheory.digits', fromlist=['is_palindromic']).is_palindromic(n, b=b)",
  )
  let res = py_call_with_args(fn_ip, [Int(n), Int(b)])
  py_str_enum(res)
}

///|
pub fn binomial_coefficients_str(n : Int) -> String raise {
  let fn_bc = py_eval_callable(
    "lambda n: sorted(__import__('sympy.ntheory.multinomial', fromlist=['binomial_coefficients']).binomial_coefficients(n).items())",
  )
  let res = py_call_with_args(fn_bc, [Int(n)])
  py_str_enum(res)
}

///|
pub fn binomial_coefficients_list_str(n : Int) -> String raise {
  let fn_bcl = py_eval_callable(
    "lambda n: __import__('sympy.ntheory.multinomial', fromlist=['binomial_coefficients_list']).binomial_coefficients_list(n)",
  )
  let res = py_call_with_args(fn_bcl, [Int(n)])
  py_str_enum(res)
}

///|
pub fn multinomial_coefficients_str(n : Int, m : Int) -> String raise {
  let fn_mc = py_eval_callable(
    "lambda n, m: sorted(__import__('sympy.ntheory.multinomial', fromlist=['multinomial_coefficients']).multinomial_coefficients(n, m).items())",
  )
  let res = py_call_with_args(fn_mc, [Int(n), Int(m)])
  py_str_enum(res)
}

///|
pub fn npartitions_str(n : Int) -> String raise {
  let fn_np = py_eval_callable(
    "lambda n: __import__('sympy.functions.combinatorial.numbers', fromlist=['partition']).partition(n)",
  )
  let res = py_call_with_args(fn_np, [Int(n)])
  py_str_enum(res)
}

///|
pub fn continued_fraction_str(num : Int, den? : Int = 1) -> String raise {
  let fn_cf = py_eval_callable(
    "lambda num, den: __import__('sympy.ntheory.continued_fraction', fromlist=['continued_fraction']).continued_fraction(__import__('sympy', fromlist=['Rational']).Rational(num, den))",
  )
  let res = py_call_with_args(fn_cf, [Int(num), Int(den)])
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
  let res = py_call_with_args(fn_cfp, [Int(p), Int(q), Int(d), Int(s)])
  py_str_enum(res)
}

///|
pub fn continued_fraction_reduce_str(terms : Array[Int]) -> String raise {
  let fn_cfr = py_eval_callable(
    "lambda terms: __import__('sympy.ntheory.continued_fraction', fromlist=['continued_fraction_reduce']).continued_fraction_reduce(terms)",
  )
  let res = py_call_with_args(fn_cfr, [IntList(terms)])
  py_str_enum(res)
}

///|
pub fn continued_fraction_convergents_str(terms : Array[Int]) -> String raise {
  let fn_cfc = py_eval_callable(
    "lambda terms: list(__import__('sympy.ntheory.continued_fraction', fromlist=['continued_fraction_convergents']).continued_fraction_convergents(terms))",
  )
  let res = py_call_with_args(fn_cfc, [IntList(terms)])
  py_str_enum(res)
}

///|
pub fn egyptian_fraction_str(num : Int, den : Int) -> String raise {
  let fn_ef = py_eval_callable(
    "lambda num, den: __import__('sympy.ntheory.egyptian_fraction', fromlist=['egyptian_fraction']).egyptian_fraction(__import__('sympy', fromlist=['Rational']).Rational(num, den))",
  )
  let res = py_call_with_args(fn_ef, [Int(num), Int(den)])
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
    Int(a4),
    Int(a6),
    Int(a1),
    Int(a2),
    Int(a3),
    Int(modulus),
  ])
  py_str_enum(res)
}

///|
pub fn ecm_factors_str(n : Int) -> String raise {
  let fn_ecm = py_eval_callable(
    "lambda n: sorted(__import__('sympy.ntheory.factor_', fromlist=['factorint']).factorint(n).keys())",
  )
  let res = py_call_with_args(fn_ecm, [Int(n)])
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
    "lambda n, pb, m, err, seed: (lambda mod: sorted(mod.qs_factor(n, pb, m, ERROR_TERM=err, seed=seed).items()) if hasattr(mod, 'qs_factor') else sorted(__import__('sympy.ntheory.factor_', fromlist=['factorint']).factorint(n).items()))(__import__('sympy.ntheory.qs', fromlist=['qs_factor']))",
  )
  let res = py_call_with_args(fn_qsf, [
    Int(n),
    Int(prime_bound),
    Int(m),
    Int(error_term),
    Int(seed),
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
    "lambda n, pb, m, err, seed: (lambda mod: sorted(mod.qs(n, pb, m, ERROR_TERM=err, seed=seed)) if hasattr(mod, 'qs') else sorted(k for k in __import__('sympy.ntheory.factor_', fromlist=['factorint']).factorint(n).keys() if k != -1))(__import__('sympy.ntheory.qs', fromlist=['qs']))",
  )
  let res = py_call_with_args(fn_qs, [
    Int(n),
    Int(prime_bound),
    Int(m),
    Int(error_term),
    Int(seed),
  ])
  py_str_enum(res)
}

///|
pub fn pi_hex_digits_str(n : Int, prec? : Int = 14) -> String raise {
  let fn_pi = py_eval_callable(
    "lambda n, prec: __import__('sympy.ntheory.bbp_pi', fromlist=['pi_hex_digits']).pi_hex_digits(n, prec)",
  )
  let res = py_call_with_args(fn_pi, [Int(n), Int(prec)])
  py_str_enum(res)
}
