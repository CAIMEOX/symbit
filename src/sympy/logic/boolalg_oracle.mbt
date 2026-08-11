///|
fn boolalg_call(
  builder : @recipe.Builder,
  name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  logic_call(builder, "sympy.logic.boolalg", name, args, kwargs~)
}

///|
fn boolalg_expr_call(
  builder : @recipe.Builder,
  name : String,
  expression : String,
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let expression = logic_sympy_expr(builder, expression)
  boolalg_call(builder, name, [Ref(expression)], kwargs~)
}

///|
fn boolalg_request_expr_call(
  name : String,
  expression : String,
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> String raise {
  let builder = @recipe.Builder::new()
  let result = boolalg_expr_call(builder, name, expression, kwargs~)
  builder.request_str(result)
}

///|
/// Parse a boolean expression string with SymPy and return its string form.
pub fn boolalg_str(expr : String) -> String raise {
  let builder = @recipe.Builder::new()
  let expression = logic_sympy_expr(builder, expr)
  builder.request_str(expression)
}

///|
pub fn boolalg_to_nnf(
  expr : String,
  simplify? : Bool = true,
  form? : String,
) -> String raise {
  let _ = form
  boolalg_request_expr_call("to_nnf", expr, kwargs={
    "simplify": Bool(simplify),
  })
}

///|
pub fn boolalg_to_cnf(
  expr : String,
  simplify? : Bool = false,
  force? : Bool = false,
) -> String raise {
  boolalg_request_expr_call("to_cnf", expr, kwargs={
    "simplify": Bool(simplify),
    "force": Bool(force),
  })
}

///|
pub fn boolalg_to_dnf(
  expr : String,
  simplify? : Bool = false,
  force? : Bool = false,
) -> String raise {
  boolalg_request_expr_call("to_dnf", expr, kwargs={
    "simplify": Bool(simplify),
    "force": Bool(force),
  })
}

///|
pub fn boolalg_to_anf(expr : String, deep? : Bool = true) -> String raise {
  boolalg_request_expr_call("to_anf", expr, kwargs={ "deep": Bool(deep) })
}

///|
pub fn boolalg_eliminate_implications(
  expr : String,
  form? : String,
) -> String raise {
  let _ = form
  boolalg_request_expr_call("eliminate_implications", expr)
}

///|
pub fn boolalg_is_cnf(expr : String) -> String raise {
  boolalg_request_expr_call("is_cnf", expr)
}

///|
pub fn boolalg_is_dnf(expr : String) -> String raise {
  boolalg_request_expr_call("is_dnf", expr)
}

///|
pub fn boolalg_is_nnf(expr : String, simplified? : Bool = true) -> String raise {
  boolalg_request_expr_call("is_nnf", expr, kwargs={
    "simplified": Bool(simplified),
  })
}

///|
pub fn boolalg_is_anf(expr : String) -> String raise {
  boolalg_request_expr_call("is_anf", expr)
}

///|
pub fn boolalg_distribute_and_over_or(expr : String) -> String raise {
  boolalg_request_expr_call("distribute_and_over_or", expr)
}

///|
pub fn boolalg_distribute_or_over_and(expr : String) -> String raise {
  boolalg_request_expr_call("distribute_or_over_and", expr)
}

///|
pub fn boolalg_distribute_xor_over_and(expr : String) -> String raise {
  boolalg_request_expr_call("distribute_xor_over_and", expr)
}

///|
fn boolalg_form_ints(
  name : String,
  variables : Array[String],
  minterms : Array[Int],
  dontcares : Array[Int]?,
) -> String raise {
  let builder = @recipe.Builder::new()
  let variables = logic_expr_list(builder, variables)
  let minterms = logic_int_list(builder, minterms)
  let args : Array[@recipe.RecipeArg] = [Ref(variables), Ref(minterms)]
  match dontcares {
    Some(values) => args.push(Ref(logic_int_list(builder, values)))
    None => ()
  }
  let result = boolalg_call(builder, name, args)
  builder.request_str(result)
}

///|
pub fn boolalg_sop_form_ints(
  variables : Array[String],
  minterms : Array[Int],
  dontcares? : Array[Int],
) -> String raise {
  boolalg_form_ints("SOPform", variables, minterms, dontcares)
}

///|
pub fn boolalg_pos_form_ints(
  variables : Array[String],
  minterms : Array[Int],
  dontcares? : Array[Int],
) -> String raise {
  boolalg_form_ints("POSform", variables, minterms, dontcares)
}

///|
pub fn boolalg_anf_form(
  variables : Array[String],
  truthvalues : Array[Int],
) -> String raise {
  let builder = @recipe.Builder::new()
  let variables = logic_expr_list(builder, variables)
  let truthvalues = logic_int_list(builder, truthvalues)
  let result = boolalg_call(builder, "ANFform", [
    Ref(variables),
    Ref(truthvalues),
  ])
  builder.request_str(result)
}

///|
pub fn boolalg_simplify_logic(
  expr : String,
  form? : String,
  deep? : Bool = true,
  force? : Bool = false,
  dontcare? : String,
) -> String raise {
  let builder = @recipe.Builder::new()
  let kwargs : Map[String, @recipe.RecipeArg] = {
    "deep": Bool(deep),
    "force": Bool(force),
  }
  match form {
    Some(value) => kwargs["form"] = Str(value)
    None => ()
  }
  match dontcare {
    Some(value) => kwargs["dontcare"] = Ref(logic_sympy_expr(builder, value))
    None => ()
  }
  let result = boolalg_expr_call(builder, "simplify_logic", expr, kwargs~)
  builder.request_str(result)
}

///|
pub fn boolalg_gateinputcount(expr : String) -> String raise {
  boolalg_request_expr_call("gateinputcount", expr)
}

///|
pub fn boolalg_bool_map(expr1 : String, expr2 : String) -> String raise {
  let builder = @recipe.Builder::new()
  let left = logic_sympy_expr(builder, expr1)
  let right = logic_sympy_expr(builder, expr2)
  let result = boolalg_call(builder, "bool_map", [Ref(left), Ref(right)])
  builder.request_str(result)
}

///|
fn boolalg_term(
  name : String,
  variables : Array[String],
  term : @recipe.RecipeArg,
) -> String raise {
  let builder = @recipe.Builder::new()
  let variables = logic_expr_list(builder, variables)
  let result = boolalg_call(builder, name, [term, Ref(variables)])
  builder.request_str(result)
}

///|
fn boolalg_term_bits(
  name : String,
  variables : Array[String],
  bits : Array[Int],
) -> String raise {
  let builder = @recipe.Builder::new()
  let variables = logic_expr_list(builder, variables)
  let bits = logic_int_list(builder, bits)
  let result = boolalg_call(builder, name, [Ref(bits), Ref(variables)])
  builder.request_str(result)
}

///|
pub fn boolalg_bool_minterm_int(
  variables : Array[String],
  k : Int,
) -> String raise {
  boolalg_term("bool_minterm", variables, DecimalInt(Show::to_string(k)))
}

///|
pub fn boolalg_bool_minterm_bits(
  variables : Array[String],
  bits : Array[Int],
) -> String raise {
  boolalg_term_bits("bool_minterm", variables, bits)
}

///|
pub fn boolalg_bool_maxterm_int(
  variables : Array[String],
  k : Int,
) -> String raise {
  boolalg_term("bool_maxterm", variables, DecimalInt(Show::to_string(k)))
}

///|
pub fn boolalg_bool_maxterm_bits(
  variables : Array[String],
  bits : Array[Int],
) -> String raise {
  boolalg_term_bits("bool_maxterm", variables, bits)
}

///|
pub fn boolalg_bool_monomial_int(
  variables : Array[String],
  k : Int,
) -> String raise {
  boolalg_term("bool_monomial", variables, DecimalInt(Show::to_string(k)))
}

///|
pub fn boolalg_bool_monomial_bits(
  variables : Array[String],
  bits : Array[Int],
) -> String raise {
  boolalg_term_bits("bool_monomial", variables, bits)
}
