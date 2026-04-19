///|
/// Token types and token helpers for the parser.
///
/// Current Limits:
/// - Tokens cover the expression grammar currently supported by `symparse`.
/// - Literal payloads preserve source spelling for later numeric lowering.

///|
/// Token categories produced by the lexer.
///
/// Literal and identifier variants retain their source spelling so later stages
/// can preserve numeric details such as decimal or repeated-decimal syntax.
///
/// - Does: Classifies one lexical item.
/// - Input: Produced by `lex`.
/// - Returns: A `TokenKind` variant, sometimes carrying source text.
/// - Limits: Only tokens used by the current expression parser are represented.
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
  BangBang
  LParen
  RParen
  Comma
  Colon
  Eq
  EqEq
  Ne
  Lt
  Le
  Gt
  Ge
  Eof
} derive(Eq, Debug)

///|
/// A single token with its source span.
///
/// - Does: Pairs a token kind with the source interval it came from.
/// - Input: A `TokenKind` and `Span`.
/// - Returns: A `Token` value.
/// - Limits: Does not validate that the span text matches the token kind.
pub struct Token {
  kind : TokenKind
  span : Span
} derive(Eq, Debug)

///|
/// Build a token from a kind and source span.
///
/// - Does: Constructs a `Token`.
/// - Input: A token kind and source span.
/// - Returns: A `Token` value.
/// - Limits: Performs no source-text validation.
pub fn token(kind : TokenKind, span : Span) -> Token {
  Token::{ kind, span }
}

///|
/// Return a human-readable name for a token kind.
///
/// This text is used in parse errors, so the names are written for diagnostics
/// rather than for serialization.
///
/// - Does: Converts a token kind to a diagnostic display name.
/// - Input: One `TokenKind`.
/// - Returns: A human-readable string.
/// - Limits: Literal payloads are not included in the returned name.
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
    TokenKind::BangBang => "`!!`"
    TokenKind::LParen => "`(`"
    TokenKind::RParen => "`)`"
    TokenKind::Comma => "`,`"
    TokenKind::Colon => "`:`"
    TokenKind::Eq => "`=`"
    TokenKind::EqEq => "`==`"
    TokenKind::Ne => "`!=`"
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
