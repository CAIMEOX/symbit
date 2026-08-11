///|
test "exact-number helpers expose SymPy-like class views" {
  let zero = int(0)
  let one = int(1)
  let neg_one = int(-1)
  let half = rational_from_ints(1, 2)
  let two = int(2)
  let two_thirds = rational_from_ints(2, 3)
  match exact_number_kind(zero) {
    Some(Zero) => ()
    _ => fail("expected Zero kind")
  }
  match exact_number_kind(one) {
    Some(One) => ()
    _ => fail("expected One kind")
  }
  match exact_number_kind(neg_one) {
    Some(NegativeOne) => ()
    _ => fail("expected NegativeOne kind")
  }
  match exact_number_kind(half) {
    Some(Half) => ()
    _ => fail("expected Half kind")
  }
  match exact_number_kind(two) {
    Some(Integer) => ()
    _ => fail("expected Integer kind")
  }
  match exact_number_kind(two_thirds) {
    Some(Rational) => ()
    _ => fail("expected Rational kind")
  }
  inspect(
    @symprint.pretty_string(singleton_head(zero).unwrap_or(int(99))),
    content="<class 'sympy.core.numbers.Zero'>",
  )
  inspect(
    @symprint.pretty_string(singleton_head(half).unwrap_or(int(99))),
    content="<class 'sympy.core.numbers.Half'>",
  )
  match exact_number_num_den(two_thirds) {
    Some((num, den)) => {
      inspect(num.to_string(), content="2")
      inspect(den.to_string(), content="3")
    }
    None => fail("expected num/den pair")
  }
}

///|
test "expr_kind follows source-driven core kinds" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  inspect(kind_name(expr_kind(x)), content="NumberKind")
  inspect(kind_name(expr_kind(Boolean(true))), content="BooleanKind")
  inspect(kind_name(expr_kind(Relational(Eq, x, y))), content="BooleanKind")
  inspect(
    kind_name(expr_kind(Tuple([x, Boolean(true)]))),
    content="TupleKind(NumberKind, BooleanKind)",
  )
  inspect(kind_name(expr_kind(Dict([(x, y)]))), content="UndefinedKind")
  inspect(kind_name(expr_kind(FunctionHead("sin"))), content="UndefinedKind")
  inspect(kind_name(expr_kind(UndefinedFunction("f"))), content="UndefinedKind")
  inspect(kind_name(expr_kind(function("sin", [x]))), content="NumberKind")
  inspect(
    kind_name(expr_kind(applied_undefined_function("f", [x]))),
    content="NumberKind",
  )
  inspect(
    kind_name(expr_kind(function("And", [Boolean(true), Boolean(false)]))),
    content="BooleanKind",
  )
  inspect(
    kind_name(expr_kind(function("Or", [Boolean(true), x]))),
    content="BooleanKind",
  )
  inspect(kind_name(expr_kind(lambda_expr(x, x))), content="UndefinedKind")
  inspect(
    kind_name(common_kind([NumberKind, NumberKind])),
    content="NumberKind",
  )
  inspect(
    kind_name(common_kind([NumberKind, UndefinedKind])),
    content="UndefinedKind",
  )
  inspect(
    kind_name(expr_kind(add([Tuple([x]), Tuple([y])]))),
    content="TupleKind(NumberKind)",
  )
  inspect(
    kind_name(expr_kind(derivative(Tuple([x, y]), x))),
    content="TupleKind(NumberKind, NumberKind)",
  )
  inspect(
    kind_name(expr_kind(subs_expr(Tuple([x]), x, y))),
    content="TupleKind(NumberKind)",
  )
}
