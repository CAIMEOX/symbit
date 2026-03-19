///|
fn make_add(
  args : Array[@symcore.Expr],
  options : ParseOptions,
) -> @symcore.Expr {
  if options.evaluate {
    @symcore.add(args)
  } else {
    @symcore.raw_add(args)
  }
}

///|
fn make_mul(
  args : Array[@symcore.Expr],
  options : ParseOptions,
) -> @symcore.Expr {
  if options.evaluate {
    @symcore.mul(args)
  } else {
    @symcore.raw_mul(args)
  }
}

///|
fn make_pow(
  base : @symcore.Expr,
  exp : @symcore.Expr,
  options : ParseOptions,
) -> @symcore.Expr {
  if options.evaluate {
    @symcore.pow(base, exp)
  } else {
    @symcore.raw_pow(base, exp)
  }
}

///|
fn make_function(
  name : String,
  args : Array[@symcore.Expr],
  options : ParseOptions,
) -> @symcore.Expr {
  if options.evaluate {
    @symcore.function(name, args)
  } else {
    @symcore.raw_function(name, args)
  }
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
) -> @symcore.Expr raise ParseError {
  match text.split_once(".") {
    Some((whole, frac)) => {
      let whole_s = whole.to_string()
      let frac_s = frac.to_string()
      let digits = whole_s + frac_s
      let numerator = BigInt::from_string(digits)
      let denominator = pow10(frac_s.length())
      @symcore.number(@symnum.BigRational::new(numerator, denominator)) catch {
        _ => raise ParseError::InvalidNumber(span=source_span, text)
      }
    }
    None =>
      @symcore.number(
        @symnum.BigRational::from_bigint(BigInt::from_string(text)),
      )
  }
}

///|
fn compare_name(op : CompareOp) -> String {
  match op {
    CompareOp::Eq => "Eq"
    CompareOp::Lt => "Lt"
    CompareOp::Le => "Le"
    CompareOp::Gt => "Gt"
    CompareOp::Ge => "Ge"
  }
}

///|
pub fn lower_ast_with(
  ast : Ast,
  options : ParseOptions,
) -> @symcore.Expr raise ParseError {
  match ast {
    Ast::Number(span~, text) => number_from_literal(text, span)
    Ast::Symbol(span~, name) => {
      ignore(span)
      @symcore.symbol(name)
    }
    Ast::Unary(span~, UnaryOp::Plus, operand) => {
      ignore(span)
      lower_ast_with(operand, options)
    }
    Ast::Unary(span~, UnaryOp::Minus, operand) => {
      ignore(span)
      make_mul([@symcore.int(-1), lower_ast_with(operand, options)], options)
    }
    Ast::Binary(span~, BinaryOp::Add, lhs, rhs) => {
      ignore(span)
      make_add(
        [lower_ast_with(lhs, options), lower_ast_with(rhs, options)],
        options,
      )
    }
    Ast::Binary(span~, BinaryOp::Sub, lhs, rhs) => {
      ignore(span)
      make_add(
        [
          lower_ast_with(lhs, options),
          make_mul([@symcore.int(-1), lower_ast_with(rhs, options)], options),
        ],
        options,
      )
    }
    Ast::Binary(span~, BinaryOp::Mul, lhs, rhs) => {
      ignore(span)
      make_mul(
        [lower_ast_with(lhs, options), lower_ast_with(rhs, options)],
        options,
      )
    }
    Ast::Binary(span~, BinaryOp::Div, lhs, rhs) => {
      ignore(span)
      make_mul(
        [
          lower_ast_with(lhs, options),
          make_pow(lower_ast_with(rhs, options), @symcore.int(-1), options),
        ],
        options,
      )
    }
    Ast::Binary(span~, BinaryOp::Pow, lhs, rhs) => {
      ignore(span)
      make_pow(
        lower_ast_with(lhs, options),
        lower_ast_with(rhs, options),
        options,
      )
    }
    Ast::Call(span~, callee, args) =>
      match callee {
        Ast::Symbol(span~, name) => {
          ignore(span)
          make_function(
            name,
            args.map(arg => lower_ast_with(arg, options)),
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
        items.map(item => lower_ast_with(item, options)),
        options,
      )
    }
    Ast::Compare(span~, exprs, ops) => {
      ignore(span)
      let lowered : Array[@symcore.Expr] = []
      for i in 0..<ops.length() {
        lowered.push(
          make_function(
            compare_name(ops[i]),
            [
              lower_ast_with(exprs[i], options),
              lower_ast_with(exprs[i + 1], options),
            ],
            options,
          ),
        )
      }
      if lowered.length() == 1 {
        lowered[0]
      } else {
        make_function("And", lowered, options)
      }
    }
  }
}

///|
pub fn lower_ast(ast : Ast) -> @symcore.Expr raise ParseError {
  lower_ast_with(ast, default_parse_options())
}
