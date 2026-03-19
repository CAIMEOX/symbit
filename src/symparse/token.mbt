///|
pub enum TokenKind {
  IntLit(String)
  DecimalLit(String)
  Ident(String)
  Plus
  Minus
  Star
  Slash
  Pow
  Caret
  Bang
  LParen
  RParen
  Comma
  Eq
  EqEq
  Lt
  Le
  Gt
  Ge
  Eof
} derive(Eq, Show)

///|
pub struct Token {
  kind : TokenKind
  span : Span
} derive(Eq, Show)

///|
pub fn token(kind : TokenKind, span : Span) -> Token {
  Token::{ kind, span }
}

///|
pub fn token_kind_name(kind : TokenKind) -> String {
  match kind {
    TokenKind::IntLit(_) => "integer"
    TokenKind::DecimalLit(_) => "decimal"
    TokenKind::Ident(_) => "identifier"
    TokenKind::Plus => "`+`"
    TokenKind::Minus => "`-`"
    TokenKind::Star => "`*`"
    TokenKind::Slash => "`/`"
    TokenKind::Pow => "`**`"
    TokenKind::Caret => "`^`"
    TokenKind::Bang => "`!`"
    TokenKind::LParen => "`(`"
    TokenKind::RParen => "`)`"
    TokenKind::Comma => "`,`"
    TokenKind::Eq => "`=`"
    TokenKind::EqEq => "`==`"
    TokenKind::Lt => "`<`"
    TokenKind::Le => "`<=`"
    TokenKind::Gt => "`>`"
    TokenKind::Ge => "`>=`"
    TokenKind::Eof => "end of input"
  }
}

///|
fn token_tag_eq(lhs : TokenKind, rhs : TokenKind) -> Bool {
  token_kind_name(lhs) == token_kind_name(rhs)
}

///|
fn token_is_compare(kind : TokenKind) -> Bool {
  match kind {
    TokenKind::EqEq
    | TokenKind::Lt
    | TokenKind::Le
    | TokenKind::Gt
    | TokenKind::Ge => true
    _ => false
  }
}
