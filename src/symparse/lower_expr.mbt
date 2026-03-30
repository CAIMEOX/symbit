///|
fn make_add(args : Array[Expr], options : ParseOptions) -> Expr {
  @symcore.with_evaluate(options.evaluate, fn() { @symcore.add(args) })
}

///|
fn make_mul(args : Array[Expr], options : ParseOptions) -> Expr {
  @symcore.with_evaluate(options.evaluate, fn() { @symcore.mul(args) })
}

///|
fn make_pow(base : Expr, exp : Expr, options : ParseOptions) -> Expr {
  @symcore.with_evaluate(options.evaluate, fn() { @symcore.pow(base, exp) })
}

///|
fn canonicalize_constructor_expr(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => @symcore.add(args.map(canonicalize_constructor_expr))
    Expr::Mul(args) => @symcore.mul(args.map(canonicalize_constructor_expr))
    Expr::Pow(base, exp) =>
      @symcore.pow(
        canonicalize_constructor_expr(base),
        canonicalize_constructor_expr(exp),
      )
    Expr::Mod(lhs, rhs) =>
      @symcore.mod_expr(
        canonicalize_constructor_expr(lhs),
        canonicalize_constructor_expr(rhs),
      )
    Expr::Tuple(args) => Expr::Tuple(args.map(canonicalize_constructor_expr))
    Expr::Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push(
          (
            canonicalize_constructor_expr(key),
            canonicalize_constructor_expr(value),
          ),
        )
      }
      Expr::Dict(out)
    }
    Expr::Relational(op, lhs, rhs) =>
      Expr::Relational(
        op,
        canonicalize_constructor_expr(lhs),
        canonicalize_constructor_expr(rhs),
      )
    Expr::Derivative(inner, deriv_args) =>
      @symcore.raw_derivative(
        canonicalize_constructor_expr(inner),
        deriv_args.map(canonicalize_constructor_expr),
      )
    Expr::Subs(inner, variable, value) =>
      @symcore.subs_expr(
        canonicalize_constructor_expr(inner),
        canonicalize_constructor_expr(variable),
        canonicalize_constructor_expr(value),
      )
    Expr::Lambda(vars, body) =>
      @symcore.lambda_expr(
        canonicalize_constructor_expr(vars),
        canonicalize_constructor_expr(body),
      )
    Expr::Apply(head, args) => {
      let head = canonicalize_constructor_expr(head)
      let args = args.map(canonicalize_constructor_expr)
      @symcore.apply(head, args).unwrap_or(Expr::Apply(head, args))
    }
    _ => @symcore.normalize_legacy_expr(expr)
  }
}

///|
fn make_function(
  name : String,
  args : Array[Expr],
  _options : ParseOptions,
) -> Expr raise ParseError {
  let canonical_args = args.map(canonicalize_constructor_expr)
  let missing_constructor_error = fn(
    class_name : String,
    missing_names : Array[String],
  ) -> Expr raise ParseError {
    let missing_count = missing_names.length()
    let missing_text = if missing_count == 1 {
      "'" + missing_names[0] + "'"
    } else {
      missing_names.map(name => "'" + name + "'").join(" and ")
    }
    raise ParseError::UnsupportedConstruct(
      span=span(0, 0),
      "TypeError: \{class_name}.__new__() missing \{missing_count} required positional argument" +
      (if missing_count == 1 { "" } else { "s" }) +
      ": " +
      missing_text,
    )
  }
  let too_many_constructor_error = fn(
    class_name : String,
    arity : Int,
    given : Int,
  ) -> Expr raise ParseError {
    raise ParseError::UnsupportedConstruct(
      span=span(0, 0),
      "TypeError: \{class_name}.__new__() takes \{arity + 1} positional arguments but \{given + 1} were given",
    )
  }
  let exact_arity_error = fn(
    name : String,
    expected : Int,
    given : Int,
  ) -> Expr raise ParseError {
    raise ParseError::UnsupportedConstruct(
      span=span(0, 0),
      "TypeError: \{name} takes exactly \{expected} argument" +
      (if expected == 1 { "" } else { "s" }) +
      " (\{given} given)",
    )
  }
  let dict_item_error = fn(item : Expr) -> Expr raise ParseError {
    match @symcore.tuple_items(item) {
      Some([_, _]) => @symcore.function(name, canonical_args)
      Some(_) =>
        raise ParseError::UnsupportedConstruct(
          span=span(0, 0),
          "TypeError: Pass Dict args as Dict((k1, v1), ...) or Dict({k1: v1, ...})",
        )
      None => {
        let type_name = match @symcore.func(item) {
          Some(head) =>
            match @symcore.function_head_name(head) {
              Some(name) => name
              None => @symcore.head_name(head)
            }
          None => @symcore.head_name(item)
        }
        raise ParseError::UnsupportedConstruct(
          span=span(0, 0),
          "TypeError: object of type '\{type_name}' has no len()",
        )
      }
    }
  }
  let relation_constructor_error = fn(
    name : String,
    given : Int,
  ) -> Expr raise ParseError {
    let class_name = match name {
      "Eq" => "Equality"
      "Ne" => "Unequality"
      _ => "_Inequality"
    }
    if given == 0 {
      missing_constructor_error(class_name, ["lhs", "rhs"])
    } else if given == 1 {
      missing_constructor_error(class_name, ["rhs"])
    } else {
      too_many_constructor_error(class_name, 2, given)
    }
  }
  match (name, canonical_args) {
    ("Eq", [_, _])
    | ("Ne", [_, _])
    | ("Lt", [_, _])
    | ("Le", [_, _])
    | ("Gt", [_, _])
    | ("Ge", [_, _]) => @symcore.function(name, canonical_args)
    ("Eq", _) | ("Ne", _) | ("Lt", _) | ("Le", _) | ("Gt", _) | ("Ge", _) =>
      relation_constructor_error(name, canonical_args.length())
    ("Dict", items) => {
      for item in items {
        ignore(dict_item_error(item))
      }
      @symcore.function(name, canonical_args)
    }
    ("Mod", [_, _]) => @symcore.function(name, canonical_args)
    ("Mod", _) => exact_arity_error(name, 2, canonical_args.length())
    ("Lambda", [vars, _]) =>
      match @symcore.lambda_signature_error(vars) {
        Some(err) =>
          raise ParseError::UnsupportedConstruct(
            span=span(0, 0),
            "BadSignatureError: " + err,
          )
        None => @symcore.function(name, canonical_args)
      }
    ("Lambda", args) =>
      if args.length() < 2 {
        missing_constructor_error(
          "Lambda",
          if args.length() == 0 {
            ["signature", "expr"]
          } else {
            ["expr"]
          },
        )
      } else {
        too_many_constructor_error("Lambda", 2, args.length())
      }
    ("Subs", [_, variable, value]) =>
      match @symcore.subs_signature_error(variable, value) {
        Some(err) =>
          raise ParseError::UnsupportedConstruct(
            span=span(0, 0),
            "ValueError: " + err,
          )
        None => @symcore.function(name, canonical_args)
      }
    ("Subs", args) =>
      if args.length() < 3 {
        missing_constructor_error(
          "Subs",
          match args.length() {
            0 => ["expr", "variables", "point"]
            1 => ["variables", "point"]
            _ => ["point"]
          },
        )
      } else {
        too_many_constructor_error("Subs", 3, args.length())
      }
    ("Derivative", []) => missing_constructor_error("Derivative", ["expr"])
    ("Derivative", [expr]) => {
      let free = @symcore.free_symbols(expr)
      match free {
        [] => @symcore.int(0)
        [wrt] => @symcore.function(name, [expr, wrt])
        _ =>
          raise ParseError::UnsupportedConstruct(
            span=span(0, 0),
            "ValueError: \nSince there is more than one variable in the expression, the\n" +
            "variable(s) of differentiation must be supplied to differentiate the expression",
          )
      }
    }
    ("Derivative", args) =>
      match @symcore.derivative_signature_error(args[1:]) {
        Some(err) =>
          raise ParseError::UnsupportedConstruct(
            span=span(0, 0),
            if err.has_prefix("Can't calculate derivative wrt ") {
              "ValueError: \n" + err
            } else {
              "ValueError: " + err
            },
          )
        None => @symcore.function(name, canonical_args)
      }
    _ => @symcore.function(name, canonical_args)
  }
}

///|
fn make_application(
  callee : Expr,
  args : Array[Expr],
  options : ParseOptions,
) -> Expr raise ParseError {
  let apply_named = fn(name : String, args : Array[Expr]) -> Expr {
    @symcore.with_evaluate(options.evaluate, fn() { @symcore.function(name, args) })
  }
  let exact_arity_error = fn(
    name : String,
    expected : Int,
    given : Int,
  ) -> Expr raise ParseError {
    raise ParseError::UnsupportedConstruct(
      span=span(0, 0),
      "TypeError: \{name} takes exactly \{expected} argument" +
      (if expected == 1 { "" } else { "s" }) +
      " (\{given} given)",
    )
  }
  let apply_builtin = fn(name : String) -> Expr raise ParseError {
    let integer_constructor_result = fn(args : Array[Expr]) -> Expr raise ParseError {
      let lowered = apply_named(name, args)
      match lowered {
        @symcore.Expr::Apply(@symcore.Expr::FunctionHead("Integer"), [arg]) =>
          raise ParseError::UnsupportedConstruct(
            span=span(0, 0),
            "TypeError: Argument of Integer should be of numeric type, got " +
            @symprint.to_string(arg) +
            ".",
          )
        _ => lowered
      }
    }
    let rational_constructor_result = fn(args : Array[Expr]) -> Expr raise ParseError {
      let lowered = apply_named(name, args)
      match lowered {
        @symcore.Expr::Apply(@symcore.Expr::FunctionHead("Rational"), [arg]) =>
          raise ParseError::UnsupportedConstruct(
            span=span(0, 0),
            "TypeError: invalid input: " + @symprint.to_string(arg),
          )
        @symcore.Expr::Apply(@symcore.Expr::FunctionHead("Rational"), [lhs, rhs]) =>
          if @symcore.is_zero(rhs) {
            if @symcore.is_zero(lhs) {
              raise ParseError::UnsupportedConstruct(
                span=span(0, 0),
                "ValueError: Indeterminate 0/0",
              )
            } else {
              @symcore.Expr::NumberSymbol(
                @symcore.NumberSymbolKind::ComplexInfinity,
              )
            }
          } else {
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "TypeError: invalid input: " + @symprint.to_string(rhs),
            )
          }
        _ => lowered
      }
    }
    match name {
      "log" =>
        match args.length() {
          0 =>
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "TypeError: log takes at least 1 argument (0 given)",
            )
          1 => apply_named(name, args)
          2 =>
            if options.evaluate {
              make_mul(
                [
                  @symcore.function("log", [args[0]]),
                  make_pow(
                    @symcore.function("log", [args[1]]),
                    int(-1),
                    options,
                  ),
                ],
                options,
              )
            } else {
              apply_named(name, args)
            }
          given =>
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "TypeError: log takes at least 1 argument (\{given} given)",
            )
        }
      "sqrt" =>
        match args.length() {
          0 =>
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "TypeError: sqrt() missing 1 required positional argument: 'arg'",
            )
          1 => apply_named(name, args)
          2 =>
            if options.evaluate {
              apply_named(name, [args[0]])
            } else {
              raise ParseError::UnsupportedConstruct(
                span=span(0, 0),
                "TypeError: sqrt() got multiple values for argument 'evaluate'",
              )
            }
          given =>
            if options.evaluate {
              raise ParseError::UnsupportedConstruct(
                span=span(0, 0),
                "TypeError: sqrt() takes from 1 to 2 positional arguments but \{given} were given",
              )
            } else {
              raise ParseError::UnsupportedConstruct(
                span=span(0, 0),
                "TypeError: sqrt() got multiple values for argument 'evaluate'",
              )
            }
        }
      "Min" =>
        match args.length() {
          0 => @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
          1 => args[0]
          _ => apply_named(name, args)
        }
      "Max" =>
        match args.length() {
          0 =>
            @symcore.Expr::NumberSymbol(
              @symcore.NumberSymbolKind::NegativeInfinity,
            )
          1 => args[0]
          _ => apply_named(name, args)
        }
      "besselj" | "bessely" | "besseli" | "besselk" =>
        if args.length() == 2 {
          apply_named(name, args)
        } else {
          exact_arity_error(name, 2, args.length())
        }
      "atan2" | "binomial" =>
        if args.length() == 2 {
          apply_named(name, args)
        } else {
          exact_arity_error(name, 2, args.length())
        }
      "beta" =>
        match args.length() {
          0 =>
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "TypeError: beta takes at least 1 argument (0 given)",
            )
          1 => apply_named(name, [args[0], args[0]])
          2 => apply_named(name, args)
          given =>
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "TypeError: beta takes at least 1 argument (\{given} given)",
            )
        }
      "S" =>
        match args.length() {
          0 =>
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "TypeError: SingletonRegistry.__call__() missing 1 required positional argument: 'a'",
            )
          given if given <= 6 => @symcore.normalize_legacy_expr(args[0])
          given =>
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "TypeError: SingletonRegistry.__call__() takes from 2 to 7 positional arguments but \{given + 1} were given",
            )
        }
      "Integer" =>
        match args.length() {
          0 =>
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "TypeError: Integer.__new__() missing 1 required positional argument: 'i'",
            )
          1 => integer_constructor_result(args)
          given => exact_arity_error(name, 1, given)
        }
      "Rational" =>
        match args.length() {
          0 =>
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "TypeError: Rational.__new__() missing 1 required positional argument: 'p'",
            )
          1 | 2 => rational_constructor_result(args)
          given => exact_arity_error(name, 2, given)
        }
      "Float" =>
        match args.length() {
          0 =>
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "TypeError: Float.__new__() missing 1 required positional argument: 'num'",
            )
          1 | 2 => apply_named(name, args)
          3 =>
            raise ParseError::UnsupportedConstruct(
              span=span(0, 0),
              "ValueError: Both decimal and binary precision supplied. Supply only one.",
            )
          given => exact_arity_error(name, 2, given)
        }
      _ =>
        if args.length() == 1 {
          apply_named(name, args)
        } else {
          exact_arity_error(name, 1, args.length())
        }
    }
  }
  match callee {
    @symcore.Expr::FunctionHead(name) if is_builtin_core_head_name(name) =>
      return make_function(name, args, options)
    @symcore.Expr::FunctionHead(name) if is_builtin_callable_name(name) =>
      return apply_builtin(name)
    _ => ()
  }
  let lowered = @symcore.with_evaluate(options.evaluate, fn() {
    @symcore.apply(callee, args)
  })
  match lowered {
    Some(expr) => expr
    None =>
      match callee {
        @symcore.Expr::IdentityFunction =>
          raise ParseError::UnsupportedConstruct(
            span=span(0, 0),
            "BadArgumentsError: Lambda(_x, _x) takes exactly 1 argument (" +
            args.length().to_string() +
            " given)",
          )
        @symcore.Expr::Lambda(vars, _) =>
          match @symcore.lambda_arity(vars) {
            Some(expected) =>
              raise ParseError::UnsupportedConstruct(
                span=span(0, 0),
                "BadArgumentsError: " +
                @symprint.to_string(callee) +
                " takes exactly " +
                expected.to_string() +
                " argument" +
                (if expected == 1 { "" } else { "s" }) +
                " (" +
                args.length().to_string() +
                " given)",
              )
            None =>
              raise ParseError::UnsupportedConstruct(
                span=span(0, 0),
                "TypeError: object is not callable",
              )
          }
        _ =>
          raise ParseError::UnsupportedConstruct(
            span=span(0, 0),
            match @symcore.func(callee) {
              Some(@symcore.Expr::FunctionHead(name)) =>
                "TypeError: '\{name}' object is not callable"
              _ => "TypeError: object is not callable"
            },
          )
      }
  }
}

///|
fn options_with_evaluate(
  options : ParseOptions,
  evaluate : Bool,
) -> ParseOptions {
  ParseOptions::{
    evaluate,
    transformations: options.transformations.map(x => x),
  }
}

///|
fn lookup_binding(context : ParseContext, name : String) -> Expr? {
  context.bindings.get(name)
}

///|
fn lookup_global_binding(context : ParseContext, name : String) -> Expr? {
  context.global_bindings.get(name)
}

///|
fn lookup_effective_binding(context : ParseContext, name : String) -> Expr? {
  match lookup_binding(context, name) {
    Some(bound) => Some(bound)
    None => lookup_global_binding(context, name)
  }
}

///|
fn builtin_number_symbol_kind(name : String) -> @symcore.NumberSymbolKind? {
  match name {
    "I" => Some(@symcore.NumberSymbolKind::ImaginaryUnit)
    "pi" => Some(@symcore.NumberSymbolKind::Pi)
    "E" => Some(@symcore.NumberSymbolKind::Exp1)
    "EulerGamma" => Some(@symcore.NumberSymbolKind::EulerGamma)
    "GoldenRatio" => Some(@symcore.NumberSymbolKind::GoldenRatio)
    "Catalan" => Some(@symcore.NumberSymbolKind::Catalan)
    "oo" => Some(@symcore.NumberSymbolKind::Infinity)
    "zoo" => Some(@symcore.NumberSymbolKind::ComplexInfinity)
    "nan" => Some(@symcore.NumberSymbolKind::NaN)
    _ => None
  }
}

///|
fn lower_symbol_name(
  context : ParseContext,
  name : String,
  options : ParseOptions,
) -> Expr raise ParseError {
  match lookup_effective_binding(context, name) {
    Some(bound) => bound
    None =>
      if context_has_callable_name(context, name) ||
        context_has_global_callable_name(context, name) {
        @symcore.Expr::UndefinedFunction(name)
      } else if name == "True" {
        @symcore.Expr::Boolean(true)
      } else if name == "False" {
        @symcore.Expr::Boolean(false)
      } else {
        match builtin_number_symbol_kind(name) {
          Some(kind) => @symcore.Expr::NumberSymbol(kind)
          None =>
            if is_builtin_head_name(name) {
              @symcore.Expr::FunctionHead(name)
            } else if option_has_auto_symbol(options) {
              Expr::Symbol(name)
            } else {
              raise ParseError::UnsupportedConstruct(
                span=span(0, 0),
                "unknown identifier: " + name,
              )
            }
        }
      }
  }
}

///|
fn coerce_callable_target(bound : Expr) -> Expr? {
  match bound {
    Expr::FunctionHead(_) | Expr::UndefinedFunction(_) => Some(bound)
    Expr::Symbol(target_name) =>
      Some(@symcore.Expr::UndefinedFunction(target_name))
    _ => None
  }
}

///|
fn lookup_callable_target(context : ParseContext, name : String) -> Expr {
  match lookup_binding(context, name) {
    Some(bound) =>
      if context_has_callable_name(context, name) {
        match coerce_callable_target(bound) {
          Some(target) => target
          None => bound
        }
      } else {
        bound
      }
    None =>
      match lookup_global_binding(context, name) {
        Some(bound) =>
          if context_has_global_callable_name(context, name) {
            match coerce_callable_target(bound) {
              Some(target) => target
              None => bound
            }
          } else {
            bound
          }
        None =>
          if context_has_callable_name(context, name) ||
            context_has_global_callable_name(context, name) {
            @symcore.Expr::UndefinedFunction(name)
          } else {
            match builtin_number_symbol_kind(name) {
              Some(kind) => @symcore.Expr::NumberSymbol(kind)
              None =>
                if is_builtin_head_name(name) {
                  @symcore.Expr::FunctionHead(name)
                } else {
                  @symcore.Expr::UndefinedFunction(name)
                }
            }
          }
      }
  }
}

///|
fn bool_of_expr(expr : Expr) -> Bool? {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Boolean(value) => Some(value)
    _ => None
  }
}

///|
fn raw_add_or_identity(args : Array[Expr]) -> Expr {
  match args.length() {
    0 => int(0)
    1 => args[0]
    _ => @symcore.raw_add(args)
  }
}

///|
fn raw_mul_or_identity(args : Array[Expr]) -> Expr {
  match args.length() {
    0 => int(1)
    1 => args[0]
    _ => @symcore.raw_mul(args)
  }
}

///|
fn negate_expr(expr : Expr, options : ParseOptions) -> Expr {
  make_mul([int(-1), expr], options)
}

///|
fn compare_numeric(
  op : CompareOp,
  lhs : @symnum.BigRational,
  rhs : @symnum.BigRational,
) -> Bool {
  let cmp = lhs.compare(rhs)
  match op {
    CompareOp::Eq | CompareOp::EqEq => cmp == 0
    CompareOp::Ne => cmp != 0
    CompareOp::Lt => cmp < 0
    CompareOp::Le => cmp <= 0
    CompareOp::Gt => cmp > 0
    CompareOp::Ge => cmp >= 0
  }
}

///|
fn lower_raw_add_terms(
  ast : Ast,
  options : ParseOptions,
  context : ParseContext,
) -> Array[Expr] raise ParseError {
  match ast {
    Ast::Binary(span~, BinaryOp::Add, lhs, rhs) => {
      ignore(span)
      let out = lower_raw_add_terms(lhs, options, context)
      for term in lower_raw_add_terms(rhs, options, context) {
        out.push(term)
      }
      out
    }
    Ast::Binary(span~, BinaryOp::Sub, lhs, rhs) => {
      ignore(span)
      let out = lower_raw_add_terms(lhs, options, context)
      out.push(negate_expr(lower_ast_in(rhs, options, context), options))
      out
    }
    _ => [lower_ast_in(ast, options, context)]
  }
}

///|
fn lower_raw_mul_factors(
  ast : Ast,
  options : ParseOptions,
  context : ParseContext,
) -> Array[Expr] raise ParseError {
  match ast {
    Ast::Binary(span~, BinaryOp::Mul, lhs, rhs) => {
      ignore(span)
      let out = lower_raw_mul_factors(lhs, options, context)
      for factor in lower_raw_mul_factors(rhs, options, context) {
        out.push(factor)
      }
      out
    }
    Ast::Binary(span~, BinaryOp::Div, lhs, rhs) => {
      ignore(span)
      let out = lower_raw_mul_factors(lhs, options, context)
      out.push(make_pow(lower_ast_in(rhs, options, context), int(-1), options))
      out
    }
    _ => [lower_ast_in(ast, options, context)]
  }
}

///|
fn lower_compare_pair(
  lhs_ast : Ast,
  op : CompareOp,
  rhs_ast : Ast,
  options : ParseOptions,
  context : ParseContext,
) -> Expr raise ParseError {
  let lhs = lower_ast_in(lhs_ast, options, context)
  let rhs = lower_ast_in(rhs_ast, options, context)
  let eval_options = options_with_evaluate(options, true)
  let lhs_eval = lower_ast_in(lhs_ast, eval_options, context)
  let rhs_eval = lower_ast_in(rhs_ast, eval_options, context)
  if !options.evaluate {
    return match op {
      CompareOp::Lt => @symcore.raw_function("Lt", [lhs, rhs])
      CompareOp::Le => @symcore.raw_function("Le", [lhs, rhs])
      CompareOp::Gt => @symcore.raw_function("Gt", [lhs, rhs])
      CompareOp::Ge => @symcore.raw_function("Ge", [lhs, rhs])
      CompareOp::Eq | CompareOp::EqEq => @symcore.raw_function("Eq", [lhs, rhs])
      CompareOp::Ne => @symcore.raw_function("Ne", [lhs, rhs])
    }
  }
  if op is CompareOp::EqEq {
    return @symcore.Expr::Boolean(lhs_eval == rhs_eval)
  }
  if op is CompareOp::Ne {
    return @symcore.Expr::Boolean(lhs_eval != rhs_eval)
  }
  if op is CompareOp::Eq {
    if lhs_eval == rhs_eval {
      return @symcore.Expr::Boolean(true)
    }
    match (lhs_eval, rhs_eval) {
      (Expr::Number(lhs_num), Expr::Number(rhs_num)) =>
        return @symcore.Expr::Boolean(compare_numeric(op, lhs_num, rhs_num))
      _ => ()
    }
    return make_function("Eq", [lhs, rhs], options)
  }
  if options.evaluate {
    match (lhs_eval, rhs_eval) {
      (Expr::Number(lhs_num), Expr::Number(rhs_num)) =>
        return @symcore.Expr::Boolean(compare_numeric(op, lhs_num, rhs_num))
      _ => ()
    }
  }
  match op {
    CompareOp::Lt => make_function("Lt", [lhs, rhs], options)
    CompareOp::Le => make_function("Le", [lhs, rhs], options)
    CompareOp::Gt => make_function("Gt", [lhs, rhs], options)
    CompareOp::Ge => make_function("Ge", [lhs, rhs], options)
    CompareOp::Eq | CompareOp::EqEq => make_function("Eq", [lhs, rhs], options)
    CompareOp::Ne => make_function("Ne", [lhs, rhs], options)
  }
}

///|
fn lower_compare_chain(
  span : Span,
  exprs : Array[Ast],
  ops : Array[CompareOp],
  options : ParseOptions,
  context : ParseContext,
) -> Expr raise ParseError {
  if ops.is_empty() {
    return lower_ast_in(exprs[0], options, context)
  }
  if !options.evaluate {
    return lower_compare_pair(exprs[0], ops[0], exprs[1], options, context)
  }
  let mut last = lower_compare_pair(
    exprs[0],
    ops[0],
    exprs[1],
    options,
    context,
  )
  if ops.length() == 1 {
    return last
  }
  match bool_of_expr(last) {
    Some(false) => return last
    Some(true) => ()
    None =>
      raise ParseError::UnsupportedConstruct(
        span~,
        "cannot determine truth value of Relational",
      )
  }
  for i in 1..<ops.length() {
    last = lower_compare_pair(exprs[i], ops[i], exprs[i + 1], options, context)
    if i + 1 < ops.length() {
      match bool_of_expr(last) {
        Some(false) => return last
        Some(true) => ()
        None =>
          raise ParseError::UnsupportedConstruct(
            span~,
            "cannot determine truth value of Relational",
          )
      }
    }
  }
  last
}

///|
fn pow10(count : Int) -> BigInt {
  let mut out = BigInt::from_int(1)
  for _ in 0..<count {
    out = out * BigInt::from_int(10)
  }
  out
}

///|
fn split_exponent_literal(text : String) -> (String, String)? {
  match text.split_once("e") {
    Some((mantissa, exponent)) =>
      Some((mantissa.to_string(), exponent.to_string()))
    None =>
      match text.split_once("E") {
        Some((mantissa, exponent)) =>
          Some((mantissa.to_string(), exponent.to_string()))
        None => None
      }
  }
}

///|
fn decimal_rational_from_literal(
  text : String,
  source_span : Span,
) -> @symnum.BigRational raise ParseError {
  let (whole_s0, frac_s, repeat_s) = decimal_parts(text)
  let whole_s = if whole_s0 == "" { "0" } else { whole_s0 }
  let (numerator, denominator) = if repeat_s == "" {
    let digits = whole_s + frac_s
    (BigInt::from_string(digits), pow10(frac_s.length()))
  } else {
    let prefix_digits = whole_s + frac_s
    let expanded_digits = prefix_digits + repeat_s
    let repeated_scale = pow10(repeat_s.length()) - BigInt::from_int(1)
    (
      BigInt::from_string(expanded_digits) - BigInt::from_string(prefix_digits),
      pow10(frac_s.length()) * repeated_scale,
    )
  }
  @symnum.BigRational::new(numerator, denominator) catch {
    _ => raise ParseError::InvalidNumber(span=source_span, text)
  }
}

///|
fn scale_rational_by_pow10(
  value : @symnum.BigRational,
  exponent : Int,
  source_span : Span,
  text : String,
) -> @symnum.BigRational raise ParseError {
  if exponent == 0 {
    return value
  }
  let factor = pow10(exponent.abs())
  if exponent > 0 {
    @symnum.BigRational::new(value.numerator() * factor, value.denominator()) catch {
      _ => raise ParseError::InvalidNumber(span=source_span, text)
    }
  } else {
    @symnum.BigRational::new(value.numerator(), value.denominator() * factor) catch {
      _ => raise ParseError::InvalidNumber(span=source_span, text)
    }
  }
}

///|
fn number_from_literal(
  text : String,
  source_span : Span,
  options : ParseOptions,
) -> Expr raise ParseError {
  let has_repeated = text.contains("[")
  if has_repeated && !option_has_repeated_decimals(options) {
    raise ParseError::InvalidNumber(span=source_span, text)
  }
  let value = match split_exponent_literal(text) {
    Some((mantissa_text, exponent_text)) => {
      let exponent = @strconv.parse_int(exponent_text, base=10) catch {
        _ => raise ParseError::InvalidNumber(span=source_span, text)
      }
      let mantissa = if mantissa_text.contains(".") {
        decimal_rational_from_literal(mantissa_text, source_span)
      } else {
        @symnum.BigRational::from_bigint(BigInt::from_string(mantissa_text))
      }
      scale_rational_by_pow10(mantissa, exponent, source_span, text)
    }
    None =>
      if text.contains(".") {
        decimal_rational_from_literal(text, source_span)
      } else {
        @symnum.BigRational::from_bigint(BigInt::from_string(text))
      }
  }
  let decimal_like = text.contains(".") ||
    split_exponent_literal(text) is Some(_)
  if has_repeated || (decimal_like && option_has_rationalize(options)) {
    return @symcore.Expr::Number(value)
  }
  if decimal_like {
    let float_value = @symcore.float_from_str(text, prec=53) catch {
      _ => raise ParseError::InvalidNumber(span=source_span, text)
    }
    return @symcore.Expr::Float(float_value)
  }
  @symcore.Expr::Number(value)
}

///|
pub fn lower_ast_in(
  ast : Ast,
  options : ParseOptions,
  context : ParseContext,
) -> Expr raise ParseError {
  match ast {
    Ast::Number(span~, text) => number_from_literal(text, span, options)
    Ast::Symbol(span~, name) => {
      ignore(span)
      lower_symbol_name(context, name, options)
    }
    Ast::Unary(span~, UnaryOp::Plus, operand) => {
      ignore(span)
      lower_ast_in(operand, options, context)
    }
    Ast::Unary(span~, UnaryOp::Minus, operand) => {
      ignore(span)
      make_mul([int(-1), lower_ast_in(operand, options, context)], options)
    }
    Ast::Binary(span~, BinaryOp::Add, lhs, rhs) => {
      ignore(span)
      if options.evaluate {
        make_add(
          [
            lower_ast_in(lhs, options, context),
            lower_ast_in(rhs, options, context),
          ],
          options,
        )
      } else {
        raw_add_or_identity(lower_raw_add_terms(ast, options, context))
      }
    }
    Ast::Binary(span~, BinaryOp::Sub, lhs, rhs) => {
      ignore(span)
      if options.evaluate {
        make_add(
          [
            lower_ast_in(lhs, options, context),
            make_mul([int(-1), lower_ast_in(rhs, options, context)], options),
          ],
          options,
        )
      } else {
        raw_add_or_identity(lower_raw_add_terms(ast, options, context))
      }
    }
    Ast::Binary(span~, BinaryOp::Mul, lhs, rhs) => {
      ignore(span)
      if options.evaluate {
        make_mul(
          [
            lower_ast_in(lhs, options, context),
            lower_ast_in(rhs, options, context),
          ],
          options,
        )
      } else {
        raw_mul_or_identity(lower_raw_mul_factors(ast, options, context))
      }
    }
    Ast::Binary(span~, BinaryOp::Div, lhs, rhs) => {
      ignore(span)
      if options.evaluate {
        let lowered_lhs = lower_ast_in(lhs, options, context)
        let lowered_rhs = lower_ast_in(rhs, options, context)
        match (lowered_lhs, lowered_rhs) {
          (Expr::Number(lhs_num), Expr::Number(rhs_num)) => {
            let value = lhs_num.div_r(rhs_num) catch {
              _ =>
                raise ParseError::UnsupportedConstruct(
                  span~,
                  "division by zero",
                )
            }
            @symcore.Expr::Number(value)
          }
          _ =>
            make_mul(
              [lowered_lhs, make_pow(lowered_rhs, int(-1), options)],
              options,
            )
        }
      } else {
        raw_mul_or_identity(lower_raw_mul_factors(ast, options, context))
      }
    }
    Ast::Binary(span~, BinaryOp::Pow, lhs, rhs) => {
      ignore(span)
      make_pow(
        lower_ast_in(lhs, options, context),
        lower_ast_in(rhs, options, context),
        options,
      )
    }
    Ast::Call(span~, callee, args) => {
      ignore(span)
      let lowered_args = args.map(arg => lower_ast_in(arg, options, context))
      let lowered_callee = match callee {
        Ast::Symbol(span~, name) => {
          ignore(span)
          lookup_callable_target(context, name)
        }
        _ => lower_ast_in(callee, options, context)
      }
      make_application(lowered_callee, lowered_args, options)
    }
    Ast::Tuple(span~, items) => {
      ignore(span)
      make_function(
        "Tuple",
        items.map(item => lower_ast_in(item, options, context)),
        options,
      )
    }
    Ast::Compare(span~, exprs, ops) =>
      lower_compare_chain(span, exprs, ops, options, context)
    Ast::Lambda(span~, names, body) => {
      ignore(span)
      let vars = names.map(name => Expr::Symbol(name))
      let vars_expr = if vars.length() == 1 {
        vars[0]
      } else {
        @symcore.Expr::Tuple(vars)
      }
      match @symcore.lambda_signature_error(vars_expr) {
        Some(err) =>
          raise ParseError::UnsupportedConstruct(
            span~,
            "BadSignatureError: " + err,
          )
        None =>
          @symcore.lambda_expr(vars_expr, lower_ast_in(body, options, context))
      }
    }
  }
}

///|
pub fn lower_ast_with(
  ast : Ast,
  options : ParseOptions,
) -> Expr raise ParseError {
  lower_ast_in(ast, options, default_parse_context())
}

///|
pub fn lower_ast(ast : Ast) -> Expr raise ParseError {
  lower_ast_in(ast, default_parse_options(), default_parse_context())
}
