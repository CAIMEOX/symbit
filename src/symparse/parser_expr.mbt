///|
priv struct Parser {
  tokens : Array[Token]
  options : ParseOptions
  mut index : Int
}

///|
fn parser(tokens : Array[Token], options : ParseOptions) -> Parser {
  Parser::{ tokens, options, index: 0 }
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
fn compare_op(kind : TokenKind) -> CompareOp? {
  match kind {
    TokenKind::Eq | TokenKind::EqEq => Some(CompareOp::Eq)
    TokenKind::Lt => Some(CompareOp::Lt)
    TokenKind::Le => Some(CompareOp::Le)
    TokenKind::Gt => Some(CompareOp::Gt)
    TokenKind::Ge => Some(CompareOp::Ge)
    _ => None
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
fn Parser::parse_postfix(self : Parser, base : Ast) -> Ast raise ParseError {
  let mut expr = base
  while token_tag_eq(self.peek().kind, TokenKind::LParen) {
    let args = self.parse_call_args()
    let end_span = self.tokens[self.index - 1].span
    expr = Ast::Call(span=span_merge(ast_span(expr), end_span), expr, args)
  }
  expr
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
      self.parse_postfix(Ast::Symbol(span=tok.span, name))
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
      _ => return lhs
    }
  }
  lhs
}

///|
fn Parser::parse_compare(self : Parser) -> Ast raise ParseError {
  let first = self.parse_binary(0)
  if !token_is_compare(self.peek().kind) {
    return first
  }
  let exprs : Array[Ast] = [first]
  let ops : Array[CompareOp] = []
  let mut end_span = ast_span(first)
  while true {
    match compare_op(self.peek().kind) {
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
  let p = parser(lex(src), options)
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
