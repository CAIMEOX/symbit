///|
/// Half-open source span measured in UTF-16 code units.
pub struct Span {
  start : Int
  stop : Int
} derive(Eq, Debug)

///|
/// Build a half-open source span `[start, stop)`.
pub fn span(start : Int, stop : Int) -> Span {
  Span::{ start, stop }
}

///|
/// Merge two spans into the smallest span covering both.
///
/// This assumes `lhs` begins no later than `rhs`, which matches how the parser
/// constructs compound syntax nodes from left to right.
pub fn span_merge(lhs : Span, rhs : Span) -> Span {
  Span::{ start: lhs.start, stop: rhs.stop }
}

///|
/// Errors raised while tokenizing, parsing, or lowering source text.
///
/// Every variant carries a [`Span`](#span) so callers can highlight the failing
/// region in the original source string.
pub(all) suberror ParseError {
  UnexpectedChar(span~ : Span, Char)
  UnexpectedToken(span~ : Span, String, String)
  UnexpectedEof(span~ : Span, String)
  InvalidNumber(span~ : Span, String)
  UnsupportedConstruct(span~ : Span, String)
} derive(Eq, Debug)
