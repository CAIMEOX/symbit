///|
fn make_add(args : Array[Expr], options : ParseOptions) -> Expr {
  if options.evaluate {
    @symcore.add(args)
  } else {
    @symcore.raw_add(args)
  }
}

///|
fn make_mul(args : Array[Expr], options : ParseOptions) -> Expr {
  if options.evaluate {
    @symcore.mul(args)
  } else {
    @symcore.raw_mul(args)
  }
}

///|
fn make_pow(base : Expr, exp : Expr, options : ParseOptions) -> Expr {
  if options.evaluate {
    @symcore.pow(base, exp)
  } else {
    @symcore.raw_pow(base, exp)
  }
}

///|
fn make_function(
  name : String,
  args : Array[Expr],
  options : ParseOptions,
) -> Expr {
  match (name, args) {
    ("Tuple", _) =>
      if options.evaluate {
        @symcore.Expr::Tuple(args)
      } else {
        @symcore.raw_function(name, args)
      }
    ("Eq", [lhs, rhs]) =>
      if options.evaluate {
        @symcore.Expr::Relational(@symcore.RelOp::Eq, lhs, rhs)
      } else {
        @symcore.raw_function(name, args)
      }
    ("Ne", [lhs, rhs]) =>
      if options.evaluate {
        @symcore.Expr::Relational(@symcore.RelOp::Ne, lhs, rhs)
      } else {
        @symcore.raw_function(name, args)
      }
    ("Lt", [lhs, rhs]) =>
      if options.evaluate {
        @symcore.Expr::Relational(@symcore.RelOp::Lt, lhs, rhs)
      } else {
        @symcore.raw_function(name, args)
      }
    ("Le", [lhs, rhs]) =>
      if options.evaluate {
        @symcore.Expr::Relational(@symcore.RelOp::Le, lhs, rhs)
      } else {
        @symcore.raw_function(name, args)
      }
    ("Gt", [lhs, rhs]) =>
      if options.evaluate {
        @symcore.Expr::Relational(@symcore.RelOp::Gt, lhs, rhs)
      } else {
        @symcore.raw_function(name, args)
      }
    ("Ge", [lhs, rhs]) =>
      if options.evaluate {
        @symcore.Expr::Relational(@symcore.RelOp::Ge, lhs, rhs)
      } else {
        @symcore.raw_function(name, args)
      }
    _ =>
      match (
        if options.evaluate {
          @symcore.apply(@symcore.Expr::FunctionHead(name), args)
        } else {
          @symcore.raw_apply(@symcore.Expr::FunctionHead(name), args)
        }
      ) {
        Some(expr) => expr
        None =>
          if options.evaluate {
            @symcore.function(name, args)
          } else {
            @symcore.raw_function(name, args)
          }
      }
  }
}

///|
fn make_application(
  callee : Expr,
  args : Array[Expr],
  options : ParseOptions,
) -> Expr raise ParseError {
  let lowered = if options.evaluate {
    @symcore.apply(callee, args)
  } else {
    @symcore.raw_apply(callee, args)
  }
  match lowered {
    Some(expr) => expr
    None =>
      raise ParseError::UnsupportedConstruct(
        span=span(0, 0),
        "call lowering only accepts a function head",
      )
  }
}

///|
fn options_with_evaluate(
  options : ParseOptions,
  evaluate : Bool,
) -> ParseOptions {
  ParseOptions::{
    caret_as_power: options.caret_as_power,
    evaluate,
    implicit_multiplication: options.implicit_multiplication,
    implicit_application: options.implicit_application,
    function_exponentiation: options.function_exponentiation,
    factorial_notation: options.factorial_notation,
    convert_equals_signs: options.convert_equals_signs,
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
fn lower_symbol_name(context : ParseContext, name : String) -> Expr {
  match lookup_effective_binding(context, name) {
    Some(bound) => bound
    None =>
      if context_has_callable_name(context, name) ||
        context_has_global_callable_name(context, name) {
        @symcore.Expr::UndefinedFunction(name)
      } else if is_builtin_callable_name(name) {
        @symcore.Expr::FunctionHead(name)
      } else {
        Expr::Symbol(name)
      }
  }
}

///|
fn coerce_callable_target(bound : Expr) -> Expr? {
  match bound {
    Expr::FunctionHead(_) | Expr::UndefinedFunction(_) => Some(bound)
    Expr::Symbol(target_name) => Some(@symcore.Expr::FunctionHead(target_name))
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
          None => lower_symbol_name(context, name)
        }
      } else {
        lower_symbol_name(context, name)
      }
    None =>
      match lookup_global_binding(context, name) {
        Some(bound) =>
          if context_has_global_callable_name(context, name) {
            match coerce_callable_target(bound) {
              Some(target) => target
              None => lower_symbol_name(context, name)
            }
          } else {
            lower_symbol_name(context, name)
          }
        None => lower_symbol_name(context, name)
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
  if op is CompareOp::EqEq {
    if options.evaluate {
      return @symcore.Expr::Boolean(lhs_eval == rhs_eval)
    } else {
      return make_function("Eq", [lhs, rhs], options)
    }
  }
  if op is CompareOp::Ne {
    if options.evaluate {
      return @symcore.Expr::Boolean(lhs_eval != rhs_eval)
    } else {
      return make_function("Ne", [lhs, rhs], options)
    }
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
) -> Expr raise ParseError {
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
  @symcore.Expr::Number(value)
}

///|
pub fn lower_ast_in(
  ast : Ast,
  options : ParseOptions,
  context : ParseContext,
) -> Expr raise ParseError {
  match ast {
    Ast::Number(span~, text) => number_from_literal(text, span)
    Ast::Symbol(span~, name) => {
      ignore(span)
      lower_symbol_name(context, name)
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
        make_mul(
          [
            lower_ast_in(lhs, options, context),
            make_pow(lower_ast_in(rhs, options, context), int(-1), options),
          ],
          options,
        )
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
      let lowered_args = args.map(arg => lower_ast_in(arg, options, context))
      match callee {
        Ast::Symbol(span~, name) => {
          ignore(span)
          let lowered_callee = lookup_callable_target(context, name)
          make_application(lowered_callee, lowered_args, options)
        }
        _ =>
          raise ParseError::UnsupportedConstruct(
            span~,
            "call lowering only accepts a simple function name",
          )
      }
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
