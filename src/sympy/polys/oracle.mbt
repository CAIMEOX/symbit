///|
fn json_sympy_str(value : Json) -> String raise {
  match value {
    String(s) => s
    Object(obj) =>
      match obj.get("str") {
        Some(String(s)) => s
        _ => value.stringify()
      }
    _ => value.stringify()
  }
}

///|
fn json_str_list(value : Json) -> Array[String] raise {
  match value {
    Array(items) => {
      let out : Array[String] = Array::make(items.length(), "")
      for i in 0..<items.length() {
        out.set(i, json_sympy_str(items[i]))
      }
      out
    }
    _ => fail("expected json array")
  }
}

///|
fn build_kwargs_base(
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> Map[String, @sympy.OracleArg] {
  let kwargs : Map[String, @sympy.OracleArg] = {}
  if !gens.is_empty() {
    kwargs["gens"] = @sympy.OracleArg::StrList(gens)
  }
  if domain != "" {
    kwargs["domain"] = @sympy.OracleArg::Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = @sympy.OracleArg::Int(modulus)
  }
  kwargs
}

///|
fn build_kwargs_order(
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
  order? : String = "",
) -> Map[String, @sympy.OracleArg] {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  if order != "" {
    kwargs["order"] = @sympy.OracleArg::Str(order)
  }
  kwargs
}

///|
fn build_kwargs_var(
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
  var_name? : String = "",
) -> Map[String, @sympy.OracleArg] {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  if var_name != "" {
    kwargs["var"] = @sympy.OracleArg::Str(var_name)
  }
  kwargs
}

///|
pub fn gcd_json(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> Json raise {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  @sympy.sympy_polys_call_json(
    "gcd",
    [@sympy.OracleArg::Str(p), @sympy.OracleArg::Str(q)],
    kwargs~,
  )
}

///|
pub fn gcd(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  json_sympy_str(gcd_json(p, q, gens=gens, domain=domain, modulus=modulus))
}

///|
pub fn resultant_json(
  p : String,
  q : String,
  var_name? : String = "",
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> Json raise {
  let kwargs = build_kwargs_var(
    gens=gens,
    domain=domain,
    modulus=modulus,
    var_name=var_name,
  )
  @sympy.sympy_polys_call_json(
    "resultant",
    [@sympy.OracleArg::Str(p), @sympy.OracleArg::Str(q)],
    kwargs~,
  )
}

///|
pub fn resultant(
  p : String,
  q : String,
  var_name? : String = "",
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  json_sympy_str(
    resultant_json(p, q, var_name=var_name, gens=gens, domain=domain, modulus=modulus),
  )
}

///|
pub fn groebner_json(
  exprs : Array[String],
  gens? : Array[String] = [],
  order? : String = "",
  domain? : String = "",
  modulus? : Int = 0,
) -> Json raise {
  let kwargs = build_kwargs_order(
    gens=gens,
    domain=domain,
    modulus=modulus,
    order=order,
  )
  @sympy.sympy_polys_call_json(
    "groebner",
    [@sympy.OracleArg::StrList(exprs)],
    kwargs~,
  )
}

///|
pub fn groebner_list(
  exprs : Array[String],
  gens? : Array[String] = [],
  order? : String = "",
  domain? : String = "",
  modulus? : Int = 0,
) -> Array[String] raise {
  json_str_list(
    groebner_json(exprs, gens=gens, order=order, domain=domain, modulus=modulus),
  )
}

///|
pub fn factor_list_json(
  expr : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> Json raise {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  @sympy.sympy_polys_call_json("factor", [@sympy.OracleArg::Str(expr)], kwargs~)
}

///|
pub fn sqf_list_json(
  expr : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> Json raise {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  @sympy.sympy_polys_call_json("sqf", [@sympy.OracleArg::Str(expr)], kwargs~)
}

///|
pub fn div_json(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> Json raise {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  @sympy.sympy_polys_call_json(
    "div",
    [@sympy.OracleArg::Str(p), @sympy.OracleArg::Str(q)],
    kwargs~,
  )
}

///|
pub fn div_pair_str(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let value = div_json(p, q, gens=gens, domain=domain, modulus=modulus)
  match value {
    Array(items) =>
      if items.length() == 2 {
        "\{json_sympy_str(items[0])}||\{json_sympy_str(items[1])}"
      } else {
        fail("expected div result [quo, rem]")
      }
    _ => fail("expected div result array")
  }
}

///|
pub fn monic_expr_str(expr : String, modulus? : Int = 0) -> String raise {
  let args : Array[@sympy.OracleArg] =
    if modulus == 0 {
      [@sympy.OracleArg::Str(expr)]
    } else {
      [@sympy.OracleArg::Str(expr), @sympy.OracleArg::Int(modulus)]
    }
  @sympy.sympy_oracle_call("monic_expr_str", args)
}

///|
pub fn factor_list_str(expr : String, modulus? : Int = 0) -> String raise {
  let args : Array[@sympy.OracleArg] =
    if modulus == 0 {
      [@sympy.OracleArg::Str(expr)]
    } else {
      [@sympy.OracleArg::Str(expr), @sympy.OracleArg::Int(modulus)]
    }
  @sympy.sympy_oracle_call("factor_list_str", args)
}

///|
pub fn sqf_list_str(expr : String, modulus? : Int = 0) -> String raise {
  let args : Array[@sympy.OracleArg] =
    if modulus == 0 {
      [@sympy.OracleArg::Str(expr)]
    } else {
      [@sympy.OracleArg::Str(expr), @sympy.OracleArg::Int(modulus)]
    }
  @sympy.sympy_oracle_call("sqf_list_str", args)
}

///|
pub fn groebner_str(
  exprs : Array[String],
  ord? : String = "lex",
) -> String raise {
  let args : Array[@sympy.OracleArg] = [
    @sympy.OracleArg::StrList(exprs),
    @sympy.OracleArg::Str(ord),
  ]
  @sympy.sympy_oracle_call("groebner_str", args)
}

///|
pub fn sort_factor_repr(repr_str : String) -> String raise {
  @sympy.sympy_oracle_call("sort_factor_repr", [@sympy.OracleArg::Str(repr_str)])
}

///|
pub fn sqf_part_str(expr : String) -> String raise {
  @sympy.sympy_oracle_call("sqf_part_str", [@sympy.OracleArg::Str(expr)])
}

///|
pub fn expr_equal(lhs : String, rhs : String) -> Bool raise {
  @sympy.sympy_oracle_call("expr_equal", [
    @sympy.OracleArg::Str(lhs),
    @sympy.OracleArg::Str(rhs),
  ]) ==
  "True"
}

///|
pub fn normalize_spaces(s : String) -> String {
  @sympy.normalize_spaces(s)
}

///|
pub fn sympy_normalize(expr_str : String) -> String raise {
  @sympy.sympy_normalize(expr_str)
}

///|
pub fn canonical_cmp(s : String) -> String {
  @sympy.canonical_cmp(s)
}
