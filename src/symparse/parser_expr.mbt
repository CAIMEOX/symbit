///|
priv struct Parser {
  tokens : Array[Token]
  options : ParseOptions
  context : ParseContext
  mut index : Int
}

///|
fn parser(
  tokens : Array[Token],
  options : ParseOptions,
  context : ParseContext,
) -> Parser {
  Parser::{ tokens, options, context, index: 0 }
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.index]
}

///|
fn Parser::advance(self : Parser) -> Token {
  let tok = self.tokens[self.index]
  self.index += 1
  tok
}

///|
fn unexpected_token(tok : Token, expected : String) -> ParseError {
  match tok.kind {
    TokenKind::Eof => ParseError::UnexpectedEof(span=tok.span, expected)
    _ =>
      ParseError::UnexpectedToken(
        span=tok.span,
        expected,
        token_kind_name(tok.kind),
      )
  }
}

///|
fn Parser::match_kind(self : Parser, expected : TokenKind) -> Token? {
  let tok = self.peek()
  if token_tag_eq(tok.kind, expected) {
    self.index += 1
    Some(tok)
  } else {
    None
  }
}

///|
fn Parser::expect_kind(
  self : Parser,
  expected_kind : TokenKind,
  expected_name : String,
) -> Token raise ParseError {
  match self.match_kind(expected_kind) {
    Some(tok) => tok
    None => raise unexpected_token(self.peek(), expected_name)
  }
}

///|
fn binary_info(
  kind : TokenKind,
  options : ParseOptions,
) -> (BinaryOp, Int, Bool)? {
  match kind {
    TokenKind::Plus => Some((BinaryOp::Add, 10, false))
    TokenKind::Minus => Some((BinaryOp::Sub, 10, false))
    TokenKind::Star => Some((BinaryOp::Mul, 20, false))
    TokenKind::Slash => Some((BinaryOp::Div, 20, false))
    TokenKind::Pow => Some((BinaryOp::Pow, 40, true))
    TokenKind::Caret if options.caret_as_power =>
      Some((BinaryOp::Pow, 40, true))
    _ => None
  }
}

///|
fn compare_op(kind : TokenKind, options : ParseOptions) -> CompareOp? {
  match kind {
    TokenKind::Eq if options.convert_equals_signs => Some(CompareOp::Eq)
    TokenKind::EqEq => Some(CompareOp::EqEq)
    TokenKind::Ne => Some(CompareOp::Ne)
    TokenKind::Lt => Some(CompareOp::Lt)
    TokenKind::Le => Some(CompareOp::Le)
    TokenKind::Gt => Some(CompareOp::Gt)
    TokenKind::Ge => Some(CompareOp::Ge)
    _ => None
  }
}

///|
fn token_can_start_primary(kind : TokenKind) -> Bool {
  match kind {
    TokenKind::IntLit(_)
    | TokenKind::DecimalLit(_)
    | TokenKind::Ident(_)
    | TokenKind::LParen => true
    _ => false
  }
}

///|
fn is_builtin_callable_name(name : String) -> Bool {
  match name {
    "sin"
    | "cos"
    | "tan"
    | "cot"
    | "sec"
    | "csc"
    | "asin"
    | "acos"
    | "atan"
    | "sinh"
    | "cosh"
    | "tanh"
    | "asinh"
    | "acosh"
    | "atanh"
    | "exp"
    | "log"
    | "sqrt"
    | "Abs"
    | "factorial"
    | "factorial2"
    | "gamma"
    | "erf"
    | "erfc"
    | "Ei"
    | "Si"
    | "Ci"
    | "Shi"
    | "Chi"
    | "besselj"
    | "bessely"
    | "besseli"
    | "besselk"
    | "Min"
    | "Max" => true
    _ => false
  }
}

///|
fn context_has_callable_name(context : ParseContext, name : String) -> Bool {
  for callable_name in context.callable_names {
    if callable_name == name {
      return true
    }
  }
  false
}

///|
fn context_has_global_callable_name(
  context : ParseContext,
  name : String,
) -> Bool {
  for callable_name in context.global_callable_names {
    if callable_name == name {
      return true
    }
  }
  false
}

///|
fn context_has_binding(context : ParseContext, name : String) -> Bool {
  context.bindings.get(name) is Some(_)
}

///|
fn context_has_global_binding(context : ParseContext, name : String) -> Bool {
  context.global_bindings.get(name) is Some(_)
}

///|
fn ast_is_known_callable(ast : Ast, context : ParseContext) -> Bool {
  match ast {
    Ast::Symbol(span~, name) => {
      ignore(span)
      if context_has_binding(context, name) {
        context_has_callable_name(context, name)
      } else if context_has_callable_name(context, name) {
        true
      } else if context_has_global_binding(context, name) {
        context_has_global_callable_name(context, name)
      } else if context_has_global_callable_name(context, name) {
        true
      } else {
        is_builtin_callable_name(name)
      }
    }
    _ => false
  }
}

///|
fn Parser::parse_call_args(self : Parser) -> Array[Ast] raise ParseError {
  ignore(self.expect_kind(TokenKind::LParen, "`(`"))
  let args : Array[Ast] = []
  if self.match_kind(TokenKind::RParen) is Some(_) {
    return args
  }
  while true {
    args.push(self.parse_compare())
    if self.match_kind(TokenKind::Comma) is Some(_) {
      if self.match_kind(TokenKind::RParen) is Some(_) {
        return args
      }
    } else {
      ignore(self.expect_kind(TokenKind::RParen, "`)`"))
      return args
    }
  }
  args
}

///|
fn Parser::parse_group_or_tuple(
  self : Parser,
  start_tok : Token,
) -> Ast raise ParseError {
  if self.match_kind(TokenKind::RParen) is Some(tok) {
    return Ast::Tuple(span=span_merge(start_tok.span, tok.span), [])
  }
  let first = self.parse_compare()
  if self.match_kind(TokenKind::Comma) is Some(_) {
    let items : Array[Ast] = [first]
    if self.match_kind(TokenKind::RParen) is Some(tok) {
      return Ast::Tuple(span=span_merge(start_tok.span, tok.span), items)
    }
    while true {
      items.push(self.parse_compare())
      if self.match_kind(TokenKind::Comma) is Some(_) {
        if self.match_kind(TokenKind::RParen) is Some(tok) {
          return Ast::Tuple(span=span_merge(start_tok.span, tok.span), items)
        }
      } else {
        let end_tok = self.expect_kind(TokenKind::RParen, "`)`")
        return Ast::Tuple(span=span_merge(start_tok.span, end_tok.span), items)
      }
    }
    Ast::Tuple(span=start_tok.span, items)
  } else {
    ignore(self.expect_kind(TokenKind::RParen, "`)`"))
    first
  }
}

///|
fn Parser::should_parse_explicit_call(self : Parser, callee : Ast) -> Bool {
  if !token_tag_eq(self.peek().kind, TokenKind::LParen) {
    return false
  }
  if !self.options.implicit_multiplication {
    return true
  }
  ast_is_known_callable(callee, self.context) ||
  self.parenthesized_args_require_call()
}

///|
fn Parser::parenthesized_args_require_call(self : Parser) -> Bool {
  let mut depth = 0
  let mut i = self.index
  while i < self.tokens.length() {
    match self.tokens[i].kind {
      TokenKind::LParen => {
        depth += 1
        if depth == 1 &&
          i + 1 < self.tokens.length() &&
          token_tag_eq(self.tokens[i + 1].kind, TokenKind::RParen) {
          return true
        }
      }
      TokenKind::RParen => {
        depth -= 1
        if depth == 0 {
          return false
        }
      }
      TokenKind::Comma if depth == 1 => return true
      _ => ()
    }
    i += 1
  }
  false
}

///|
fn Parser::should_parse_implicit_application(
  self : Parser,
  callee : Ast,
) -> Bool {
  self.options.implicit_application &&
  ast_is_known_callable(callee, self.context) &&
  token_can_start_primary(self.peek().kind)
}

///|
fn Parser::should_parse_implicit_multiplication(
  self : Parser,
  min_prec : Int,
) -> Bool {
  self.options.implicit_multiplication &&
  20 >= min_prec &&
  token_can_start_primary(self.peek().kind)
}

///|
fn Parser::parse_postfix(self : Parser, base : Ast) -> Ast raise ParseError {
  let mut expr = base
  while true {
    if self.should_parse_explicit_call(expr) {
      let args = self.parse_call_args()
      let end_span = self.tokens[self.index - 1].span
      expr = Ast::Call(span=span_merge(ast_span(expr), end_span), expr, args)
    } else if self.options.factorial_notation &&
      self.match_kind(TokenKind::BangBang) is Some(tok) {
      let callee = Ast::Symbol(span=tok.span, "factorial2")
      expr = Ast::Call(span=span_merge(ast_span(expr), tok.span), callee, [expr])
    } else if self.options.factorial_notation &&
      self.match_kind(TokenKind::Bang) is Some(tok) {
      let callee = Ast::Symbol(span=tok.span, "factorial")
      expr = Ast::Call(span=span_merge(ast_span(expr), tok.span), callee, [expr])
    } else if self.should_parse_implicit_application(expr) {
      let arg = self.parse_binary(20)
      expr = Ast::Call(span=span_merge(ast_span(expr), ast_span(arg)), expr, [
        arg,
      ])
    } else {
      return expr
    }
  }
  expr
}

///|
fn Parser::match_power_token(self : Parser) -> Token? {
  match self.peek().kind {
    TokenKind::Pow => Some(self.advance())
    TokenKind::Caret if self.options.caret_as_power => Some(self.advance())
    _ => None
  }
}

///|
fn Parser::parse_function_exponentiation(
  self : Parser,
  base : Ast,
) -> Ast raise ParseError {
  let exponent = self.parse_binary(40)
  let called = self.parse_postfix(base)
  match called {
    Ast::Call(span~, _, _) =>
      Ast::Binary(
        span=span_merge(span, ast_span(exponent)),
        BinaryOp::Pow,
        called,
        exponent,
      )
    _ =>
      Ast::Binary(
        span=span_merge(ast_span(base), ast_span(exponent)),
        BinaryOp::Pow,
        base,
        exponent,
      )
  }
}

///|
fn Parser::parse_prefix(self : Parser) -> Ast raise ParseError {
  let tok = self.peek()
  match tok.kind {
    TokenKind::Plus => {
      ignore(self.advance())
      let operand = self.parse_binary(30)
      Ast::Unary(
        span=span_merge(tok.span, ast_span(operand)),
        UnaryOp::Plus,
        operand,
      )
    }
    TokenKind::Minus => {
      ignore(self.advance())
      let operand = self.parse_binary(30)
      Ast::Unary(
        span=span_merge(tok.span, ast_span(operand)),
        UnaryOp::Minus,
        operand,
      )
    }
    TokenKind::IntLit(text) => {
      ignore(self.advance())
      self.parse_postfix(Ast::Number(span=tok.span, text))
    }
    TokenKind::DecimalLit(text) => {
      ignore(self.advance())
      self.parse_postfix(Ast::Number(span=tok.span, text))
    }
    TokenKind::Ident(name) => {
      ignore(self.advance())
      let base = Ast::Symbol(span=tok.span, name)
      if self.options.function_exponentiation &&
        ast_is_known_callable(base, self.context) &&
        self.match_power_token() is Some(_) {
        self.parse_function_exponentiation(base)
      } else {
        self.parse_postfix(base)
      }
    }
    TokenKind::LParen => {
      let start = self.advance()
      let grouped = self.parse_group_or_tuple(start)
      self.parse_postfix(grouped)
    }
    _ => raise unexpected_token(tok, "expression")
  }
}

///|
fn Parser::parse_binary(self : Parser, min_prec : Int) -> Ast raise ParseError {
  let mut lhs = self.parse_prefix()
  while true {
    match binary_info(self.peek().kind, self.options) {
      Some((op, prec, right_assoc)) if prec >= min_prec => {
        ignore(self.advance())
        let next_min = if right_assoc { prec } else { prec + 1 }
        let rhs = self.parse_binary(next_min)
        lhs = Ast::Binary(
          span=span_merge(ast_span(lhs), ast_span(rhs)),
          op,
          lhs,
          rhs,
        )
      }
      _ if self.should_parse_implicit_multiplication(min_prec) => {
        let rhs = self.parse_binary(21)
        lhs = Ast::Binary(
          span=span_merge(ast_span(lhs), ast_span(rhs)),
          BinaryOp::Mul,
          lhs,
          rhs,
        )
      }
      _ => return lhs
    }
  }
  lhs
}

///|
fn Parser::parse_compare(self : Parser) -> Ast raise ParseError {
  let first = self.parse_binary(0)
  if compare_op(self.peek().kind, self.options) is None {
    return first
  }
  let exprs : Array[Ast] = [first]
  let ops : Array[CompareOp] = []
  let mut end_span = ast_span(first)
  while true {
    match compare_op(self.peek().kind, self.options) {
      Some(op) => {
        ignore(self.advance())
        let rhs = self.parse_binary(0)
        end_span = ast_span(rhs)
        ops.push(op)
        exprs.push(rhs)
      }
      None =>
        return Ast::Compare(
          span=span_merge(ast_span(first), end_span),
          exprs,
          ops,
        )
    }
  }
  first
}

///|
pub fn parse_ast_with(
  src : String,
  options : ParseOptions,
) -> Ast raise ParseError {
  parse_ast_in(src, options, default_parse_context())
}

///|
pub fn parse_ast_in(
  src : String,
  options : ParseOptions,
  context : ParseContext,
) -> Ast raise ParseError {
  let p = parser(lex(src), options, context)
  let expr = p.parse_compare()
  match p.peek().kind {
    TokenKind::Eof => expr
    _ => raise unexpected_token(p.peek(), "end of input")
  }
}

///|
/// Parse a source string into the typed parser AST.
pub fn parse_ast(src : String) -> Ast raise ParseError {
  parse_ast_with(src, default_parse_options())
}
