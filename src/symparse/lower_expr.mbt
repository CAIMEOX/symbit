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
  if options.evaluate {
    @symcore.function(name, args)
  } else {
    @symcore.raw_function(name, args)
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
fn lookup_callable_target_name(context : ParseContext, name : String) -> String {
  match lookup_binding(context, name) {
    Some(Expr::Symbol(target_name)) =>
      if context_has_callable_name(context, name) {
        target_name
      } else {
        name
      }
    Some(_) => name
    None =>
      match lookup_global_binding(context, name) {
        Some(Expr::Symbol(target_name)) =>
          if context_has_global_callable_name(context, name) {
            target_name
          } else {
            name
          }
        Some(_) | None => name
      }
  }
}

///|
fn bool_of_expr(expr : Expr) -> Bool? {
  match expr {
    Expr::Symbol("True") => Some(true)
    Expr::Symbol("False") => Some(false)
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
fn relation_name(op : CompareOp) -> String {
  match op {
    CompareOp::Eq | CompareOp::EqEq => "Eq"
    CompareOp::Lt => "Lt"
    CompareOp::Le => "Le"
    CompareOp::Gt => "Gt"
    CompareOp::Ge => "Ge"
  }
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
      return bool_expr(lhs_eval == rhs_eval)
    } else {
      return make_function("Eq", [lhs, rhs], options)
    }
  }
  if op is CompareOp::Eq {
    if lhs_eval == rhs_eval {
      return bool_expr(true)
    }
    match (lhs_eval, rhs_eval) {
      (Expr::Number(lhs_num), Expr::Number(rhs_num)) =>
        return bool_expr(compare_numeric(op, lhs_num, rhs_num))
      _ => ()
    }
    return make_function("Eq", [lhs, rhs], options)
  }
  if options.evaluate {
    match (lhs_eval, rhs_eval) {
      (Expr::Number(lhs_num), Expr::Number(rhs_num)) =>
        return bool_expr(compare_numeric(op, lhs_num, rhs_num))
      _ => ()
    }
  }
  make_function(relation_name(op), [lhs, rhs], options)
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
fn number_from_literal(
  text : String,
  source_span : Span,
) -> Expr raise ParseError {
  if text.contains(".") {
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
        BigInt::from_string(expanded_digits) -
        BigInt::from_string(prefix_digits),
        pow10(frac_s.length()) * repeated_scale,
      )
    }
    @symcore.number(@symnum.BigRational::new(numerator, denominator)) catch {
      _ => raise ParseError::InvalidNumber(span=source_span, text)
    }
  } else {
    @symcore.number(@symnum.BigRational::from_bigint(BigInt::from_string(text)))
  }
}

///|
fn bool_expr(value : Bool) -> Expr {
  symbol(if value { "True" } else { "False" })
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
      match lookup_effective_binding(context, name) {
        Some(bound) => bound
        None => symbol(name)
      }
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
    Ast::Call(span~, callee, args) =>
      match callee {
        Ast::Symbol(span~, name) => {
          ignore(span)
          make_function(
            lookup_callable_target_name(context, name),
            args.map(arg => lower_ast_in(arg, options, context)),
            options,
          )
        }
        _ =>
          raise ParseError::UnsupportedConstruct(
            span~,
            "stage-1 call lowering only accepts a simple function name",
          )
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
