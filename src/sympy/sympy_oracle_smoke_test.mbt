///|
test "sympy oracle smoke: resultant_str" {
  let res = sympy_oracle_call("resultant_str", [
    OracleArg::Str("x**2 + 1"),
    OracleArg::Str("x - 1"),
    OracleArg::Str("x"),
  ])
  inspect(res, content="2")
}

///|
test "sympy oracle smoke: echo args" {
  let res = sympy_oracle_call("echo_args", [
    OracleArg::Str("x**2 + 1"),
    OracleArg::Str("x - 1"),
    OracleArg::Str("x"),
  ])
  inspect(res, content="x**2 + 1|x - 1|x")
}

///|
test "sympy oracle smoke: gf2 factor_list_str" {
  let echo = sympy_oracle_call("echo_int", [OracleArg::Int(2)])
  inspect(echo, content="2")
  let _ = sympy_oracle_call("factor_list_str", [
    OracleArg::Str("x**6 + x**3 + 1"),
    OracleArg::Int(2),
  ])

}

///|
test "sympy oracle smoke: normalize then resultant" {
  let _ = sympy_normalize("2")
  let res = sympy_oracle_call("resultant_str", [
    OracleArg::Str("x**2 + 1"),
    OracleArg::Str("x - 1"),
    OracleArg::Str("x"),
  ])
  inspect(res, content="2")
}

///|
test "sympy oracle kwargs: factor_list_json" {
  let kwargs : Map[String, OracleArg] = {}
  kwargs["modulus"] = OracleArg::Int(2)
  let res = sympy_oracle_call_json(
    "factor_list_json",
    [OracleArg::Str("x**2 + 1")],
    kwargs~,
  )
  match res {
    Array(items) => {
      guard items.length() == 2 else { fail("expected [content, factors]") }
      guard items[1] is Array(factors) && factors.length() >= 1 else {
        fail("expected factors array")
      }
    }
    _ => fail("expected JSON array")
  }
}

///|
test "sympy oracle JSON: sympify_list_json" {
  let res = sympy_oracle_call_json("sympify_list_json", [
    OracleArg::StrList(["x", "x**2 + 1"]),
  ])
  match res {
    Array(items) => {
      guard items.length() == 2 else { fail("expected two items") }
      guard items[0] is Object(obj0) else { fail("expected object for x") }
      guard obj0.get("__sympy__") is Some(True) else {
        fail("missing __sympy__")
      }
      guard obj0.get("str") is Some(String(s0)) && s0 == "x" else {
        fail("unexpected str for x")
      }
      guard items[1] is Object(obj1) else {
        fail("expected object for x**2 + 1")
      }
      guard obj1.get("__sympy__") is Some(True) else {
        fail("missing __sympy__")
      }
      guard obj1.get("str") is Some(String(s1)) && s1 == "x**2 + 1" else {
        fail("unexpected str for x**2 + 1")
      }
    }
    _ => fail("expected JSON array")
  }
}

///|
test "sympy oracle polys_call_json: gcd/div/factor/sqf/groebner" {
  let gcd_res = sympy_polys_call_json("gcd", [
    OracleArg::Str("x**2 - 1"),
    OracleArg::Str("x - 1"),
  ])
  match gcd_res {
    Object(obj) => {
      guard obj.get("__sympy__") is Some(True) else { fail("gcd missing __sympy__") }
      guard obj.get("str") is Some(String(s)) && s == "x - 1" else {
        fail("unexpected gcd result")
      }
    }
    _ => fail("expected gcd object")
  }

  let div_res = sympy_polys_call_json("div", [
    OracleArg::Str("x**2 - 1"),
    OracleArg::Str("x - 1"),
  ])
  match div_res {
    Array(items) => {
      guard items.length() == 2 else { fail("expected div [quo, rem]") }
    }
    _ => fail("expected div array")
  }

  let factor_res = sympy_polys_call_json("factor", [
    OracleArg::Str("x**2 - 1"),
  ])
  match factor_res {
    Array(items) => {
      guard items.length() == 2 else { fail("expected factor_list [content, factors]") }
    }
    _ => fail("expected factor_list array")
  }

  let sqf_res = sympy_polys_call_json("sqf", [
    OracleArg::Str("x**2*(x + 1)"),
  ])
  match sqf_res {
    Array(items) => {
      guard items.length() == 2 else { fail("expected sqf_list [content, factors]") }
    }
    _ => fail("expected sqf_list array")
  }

  let kwargs : Map[String, OracleArg] = {}
  kwargs["order"] = OracleArg::Str("lex")
  let gb_res = sympy_polys_call_json(
    "groebner",
    [OracleArg::StrList(["x*y - 1", "x - y"])],
    kwargs~,
  )
  match gb_res {
    Array(items) => {
      guard items.length() >= 1 else { fail("expected groebner basis list") }
    }
    _ => fail("expected groebner basis list")
  }
}
