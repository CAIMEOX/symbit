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
fn json_sympy_str(value : Json) -> String {
  match value {
    Object(obj) =>
      match obj.get("str") {
        Some(String(s)) => s
        _ => value.stringify()
      }
    String(s) => s
    _ => value.stringify()
  }
}

///|
fn json_list_to_strings(value : Json) -> Array[String] raise {
  match value {
    Array(items) => {
      let out : Array[String] = Array::make(items.length(), "")
      for i in 0..<items.length() {
        out.set(i, json_sympy_str(items[i]))
      }
      out
    }
    _ => fail("expected JSON array")
  }
}

///|
pub fn gcd(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  let res = @sympy.sympy_polys_call_json(
    "gcd",
    [@sympy.OracleArg::Str(p), @sympy.OracleArg::Str(q)],
    kwargs~,
  )
  json_sympy_str(res)
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
  let kwargs = build_kwargs_var(
    gens=gens,
    domain=domain,
    modulus=modulus,
    var_name=var_name,
  )
  let res = @sympy.sympy_polys_call_json(
    "resultant",
    [@sympy.OracleArg::Str(p), @sympy.OracleArg::Str(q)],
    kwargs~,
  )
  json_sympy_str(res)
}

///|
pub fn groebner_list(
  exprs : Array[String],
  gens? : Array[String] = [],
  order? : String = "",
  domain? : String = "",
  modulus? : Int = 0,
) -> Array[String] raise {
  let kwargs = build_kwargs_order(
    gens=gens,
    domain=domain,
    modulus=modulus,
    order=order,
  )
  let res = @sympy.sympy_polys_call_json(
    "groebner",
    [@sympy.OracleArg::StrList(exprs)],
    kwargs~,
  )
  json_list_to_strings(res)
}

///|
pub fn div_pair_str(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  let res = @sympy.sympy_polys_call_json(
    "div",
    [@sympy.OracleArg::Str(p), @sympy.OracleArg::Str(q)],
    kwargs~,
  )
  match res {
    Array(items) =>
      if items.length() == 2 {
        let a = json_sympy_str(items[0])
        let b = json_sympy_str(items[1])
        "\{a}||\{b}"
      } else {
        fail("expected div result list")
      }
    _ => fail("expected div result")
  }
}

///|
pub fn monic_expr_str(expr : String, modulus? : Int = 0) -> String raise {
  let args =
    if modulus == 0 {
      [@sympy.OracleArg::Str(expr)]
    } else {
      [
        @sympy.OracleArg::Str(expr),
        @sympy.OracleArg::Int(modulus),
      ]
    }
  @sympy.sympy_oracle_call("monic_expr_str", args)
}

///|
pub fn factor_list_str(expr : String, modulus? : Int = 0) -> String raise {
  let args =
    if modulus == 0 {
      [@sympy.OracleArg::Str(expr)]
    } else {
      [
        @sympy.OracleArg::Str(expr),
        @sympy.OracleArg::Int(modulus),
      ]
    }
  @sympy.sympy_oracle_call("factor_list_str", args)
}

///|
pub fn sqf_list_str(expr : String, modulus? : Int = 0) -> String raise {
  let args =
    if modulus == 0 {
      [@sympy.OracleArg::Str(expr)]
    } else {
      [
        @sympy.OracleArg::Str(expr),
        @sympy.OracleArg::Int(modulus),
      ]
    }
  @sympy.sympy_oracle_call("sqf_list_str", args)
}

///|
pub fn groebner_str(exprs : Array[String], ord? : String = "lex") -> String raise {
  let args = [
    @sympy.OracleArg::StrList(exprs),
    @sympy.OracleArg::Str(ord),
  ]
  @sympy.sympy_oracle_call("groebner_str", args)
}

///|
pub fn sort_factor_repr(repr_str : String) -> String raise {
  let args = [@sympy.OracleArg::Str(repr_str)]
  @sympy.sympy_oracle_call("sort_factor_repr", args)
}

///|
pub fn sqf_part_str(expr : String) -> String raise {
  let args = [@sympy.OracleArg::Str(expr)]
  @sympy.sympy_oracle_call("sqf_part_str", args)
}

///|
pub fn expr_equal(lhs : String, rhs : String) -> Bool raise {
  let args = [
    @sympy.OracleArg::Str(lhs),
    @sympy.OracleArg::Str(rhs),
  ]
  @sympy.sympy_oracle_call("expr_equal", args) == "True"
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
