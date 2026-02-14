///|
pub type OracleArg = @sympy.OracleArg

///|
fn sympy_call(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum? raise {
  @sympy.sympy_call(path, args, kwargs~)
}

///|
fn sympy_call_must(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum raise {
  match sympy_call(path, args, kwargs~) {
    Some(obj) => obj
    None => fail("sympy-call-none:\{path}")
  }
}

///|
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  @sympy.objenum_to_obj(obj)
}

///|
fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise {
  @sympy.expr_to_sympy(expr)
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
  let out = obj.to_string()
  py_gil_release(state)
  out
}

///|
fn srepr_obj(obj : @py.PyObject) -> String raise {
  let rep = sympy_call_must("sympy.srepr", [OracleArg::PyObj(obj)])
  py_str_obj(objenum_to_obj(rep))
}

///|
pub fn expr_srepr(expr : @symcore.Expr) -> String raise {
  srepr_obj(expr_to_sympy(expr))
}

///|
fn unary_simplify_srepr(path : String, expr : @symcore.Expr) -> String raise {
  let out = sympy_call_must(path, [OracleArg::PyObj(expr_to_sympy(expr))])
  srepr_obj(objenum_to_obj(out))
}

///|
pub fn simplify_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify", expr)
}

///|
pub fn powsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.powsimp", expr)
}

///|
pub fn trigsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.trigsimp", expr)
}

///|
pub fn signsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.signsimp", expr)
}

///|
pub fn radsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.radsimp", expr)
}

///|
pub fn ratsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.ratsimp", expr)
}

///|
fn expr_list_arg(exprs : Array[@symcore.Expr]) -> OracleArg raise {
  let items : Array[OracleArg] = Array::new()
  for expr in exprs {
    items.push(OracleArg::PyObj(expr_to_sympy(expr)))
  }
  OracleArg::List(items)
}

///|
pub fn ratsimpmodprime_srepr(
  expr : @symcore.Expr,
  basis : Array[@symcore.Expr],
  gens : Array[@symcore.Expr],
  quick? : Bool = true,
  polynomial? : Bool = false,
) -> String raise {
  let args : Array[OracleArg] = [
    OracleArg::PyObj(expr_to_sympy(expr)),
    expr_list_arg(basis),
  ]
  for gen in gens {
    args.push(OracleArg::PyObj(expr_to_sympy(gen)))
  }
  let out = sympy_call_must(
    "sympy.ratsimpmodprime",
    args,
    kwargs={
      "quick": OracleArg::Bool(quick),
      "polynomial": OracleArg::Bool(polynomial),
    },
  )
  srepr_obj(objenum_to_obj(out))
}

///|
pub fn sqrtdenest_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.sqrtdenest", expr)
}

///|
pub fn combsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.combsimp", expr)
}

///|
pub fn hyperexpand_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.hyperexpand", expr)
}

///|
fn unary_equivalent(
  path : String,
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  let oracle_enum = sympy_call_must(path, [OracleArg::PyObj(expr_to_sympy(input_expr))])
  let oracle_obj = objenum_to_obj(oracle_enum)
  let cand_obj = expr_to_sympy(candidate)
  let neg_oracle = sympy_call_must("sympy.Mul", [
    OracleArg::Int(-1),
    OracleArg::PyObj(oracle_obj),
  ])
  let diff = sympy_call_must("sympy.Add", [
    OracleArg::PyObj(cand_obj),
    OracleArg::PyObj(objenum_to_obj(neg_oracle)),
  ])
  let simp = sympy_call_must("sympy.simplify", [OracleArg::PyObj(objenum_to_obj(diff))])
  srepr_obj(objenum_to_obj(simp)) == "Integer(0)"
}

///|
pub fn radsimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.radsimp", input_expr, candidate)
}

///|
pub fn ratsimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.ratsimp", input_expr, candidate)
}

///|
pub fn ratsimpmodprime_equivalent(
  input_expr : @symcore.Expr,
  basis : Array[@symcore.Expr],
  gens : Array[@symcore.Expr],
  candidate : @symcore.Expr,
  quick? : Bool = true,
  polynomial? : Bool = false,
) -> Bool raise {
  let args : Array[OracleArg] = [
    OracleArg::PyObj(expr_to_sympy(input_expr)),
    expr_list_arg(basis),
  ]
  for gen in gens {
    args.push(OracleArg::PyObj(expr_to_sympy(gen)))
  }
  let oracle_enum = sympy_call_must(
    "sympy.ratsimpmodprime",
    args,
    kwargs={
      "quick": OracleArg::Bool(quick),
      "polynomial": OracleArg::Bool(polynomial),
    },
  )
  let oracle_obj = objenum_to_obj(oracle_enum)
  let cand_obj = expr_to_sympy(candidate)
  let neg_oracle = sympy_call_must("sympy.Mul", [
    OracleArg::Int(-1),
    OracleArg::PyObj(oracle_obj),
  ])
  let diff = sympy_call_must("sympy.Add", [
    OracleArg::PyObj(cand_obj),
    OracleArg::PyObj(objenum_to_obj(neg_oracle)),
  ])
  let simp = sympy_call_must("sympy.simplify", [OracleArg::PyObj(objenum_to_obj(diff))])
  srepr_obj(objenum_to_obj(simp)) == "Integer(0)"
}

///|
pub fn sqrtdenest_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.sqrtdenest", input_expr, candidate)
}

///|
pub fn combsimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.combsimp", input_expr, candidate)
}

///|
pub fn hyperexpand_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.hyperexpand", input_expr, candidate)
}

///|
pub fn powdenest_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.powdenest", expr)
}

///|
pub fn exptrigsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.exptrigsimp", expr)
}

///|
pub fn gammasimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.gammasimp", expr)
}

///|
pub fn logcombine_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.logcombine", expr)
}

///|
pub fn besselsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.besselsimp", expr)
}

///|
pub fn kroneckersimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.kroneckersimp", expr)
}

///|
pub fn nsimplify_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.nsimplify", expr)
}

///|
pub fn collect_sqrt_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.radsimp.collect_sqrt", expr)
}

///|
pub fn collect_abs_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.radsimp.collect_abs", expr)
}

///|
pub fn fraction_expand_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.radsimp.fraction_expand", expr)
}

///|
pub fn numer_expand_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.radsimp.numer_expand", expr)
}

///|
pub fn denom_expand_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.radsimp.denom_expand", expr)
}

///|
pub fn powdenest_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.powdenest", input_expr, candidate)
}

///|
pub fn exptrigsimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.exptrigsimp", input_expr, candidate)
}

///|
pub fn gammasimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.gammasimp", input_expr, candidate)
}

///|
pub fn logcombine_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.logcombine", input_expr, candidate)
}

///|
pub fn besselsimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.besselsimp", input_expr, candidate)
}

///|
pub fn kroneckersimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.kroneckersimp", input_expr, candidate)
}

///|
pub fn nsimplify_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.nsimplify", input_expr, candidate)
}

///|
pub fn collect_sqrt_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.radsimp.collect_sqrt", input_expr, candidate)
}

///|
pub fn collect_abs_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.radsimp.collect_abs", input_expr, candidate)
}

///|
pub fn fraction_expand_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.radsimp.fraction_expand", input_expr, candidate)
}

///|
pub fn numer_expand_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.radsimp.numer_expand", input_expr, candidate)
}

///|
pub fn denom_expand_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.radsimp.denom_expand", input_expr, candidate)
}

///|
pub fn separatevars_srepr(
  expr : @symcore.Expr,
  force? : Bool = false,
) -> String raise {
  let out = sympy_call_must(
    "sympy.separatevars",
    [OracleArg::PyObj(expr_to_sympy(expr))],
    kwargs={ "force": OracleArg::Bool(force) },
  )
  srepr_obj(objenum_to_obj(out))
}

///|
pub fn hypersimp_srepr(
  f : @symcore.Expr,
  k : @symcore.Expr,
) -> String raise {
  let out = sympy_call_must("sympy.hypersimp", [
    OracleArg::PyObj(expr_to_sympy(f)),
    OracleArg::PyObj(expr_to_sympy(k)),
  ])
  srepr_obj(objenum_to_obj(out))
}

///|
pub fn hypersimilar_bool(
  f : @symcore.Expr,
  g : @symcore.Expr,
  k : @symcore.Expr,
) -> Bool raise {
  let out = sympy_call_must("sympy.hypersimilar", [
    OracleArg::PyObj(expr_to_sympy(f)),
    OracleArg::PyObj(expr_to_sympy(g)),
    OracleArg::PyObj(expr_to_sympy(k)),
  ])
  match out {
    PyBool(v) => {
      let s = py_str_obj(v.obj())
      s == "True"
    }
    _ => false
  }
}

///|
pub fn fu_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.fu", expr)
}

///|
pub fn fu_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.fu", input_expr, candidate)
}

///|
fn fu_rule_path(rule : String) -> String {
  "sympy.simplify.fu.\{rule}"
}

///|
pub fn futrig_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.trigsimp.futrig", expr)
}

///|
pub fn futrig_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.trigsimp.futrig", input_expr, candidate)
}

///|
pub fn tr_rule_equivalent(
  rule : String,
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent(fu_rule_path(rule), input_expr, candidate)
}

///|
pub fn sub_pre_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.cse_opts.sub_pre", expr)
}

///|
pub fn sub_post_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.cse_opts.sub_post", expr)
}

///|
pub fn sub_pre_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.cse_opts.sub_pre", input_expr, candidate)
}

///|
pub fn sub_post_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.cse_opts.sub_post", input_expr, candidate)
}
