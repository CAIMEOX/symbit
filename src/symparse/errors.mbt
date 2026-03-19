///|
/// Half-open source span measured in UTF-16 code units.
pub struct Span {
  start : Int
  stop : Int
} derive(Eq, Show)

///|
pub fn span(start : Int, stop : Int) -> Span {
  Span::{ start, stop }
}

///|
pub fn span_merge(lhs : Span, rhs : Span) -> Span {
  Span::{ start: lhs.start, stop: rhs.stop }
}

///|
pub(all) suberror ParseError {
  UnexpectedChar(span~ : Span, Char)
  UnexpectedToken(span~ : Span, String, String)
  UnexpectedEof(span~ : Span, String)
  InvalidNumber(span~ : Span, String)
  UnsupportedConstruct(span~ : Span, String)
} derive(Eq, Show)
