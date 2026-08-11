///|
/// Source-span and parser error types.
///
/// Current Limits:
/// - Spans are byte/string-index oriented according to MoonBit string indexing
///   used by this parser.
/// - Parse errors carry diagnostic text but do not yet expose structured
///   recovery suggestions.

///|
/// Half-open source span measured in UTF-16 code units.
///
/// - Does: Stores the source interval for a token, AST node, or parse error.
/// - Input: Start and stop offsets.
/// - Returns: A `Span` value.
/// - Limits: Does not validate that offsets are inside a particular source
///   string.
pub struct Span {
  start : Int
  stop : Int
} derive(Eq, Debug)

///|
/// Build a half-open source span `[start, stop)`.
///
/// - Does: Constructs a `Span` from two offsets.
/// - Input: Start and stop offsets.
/// - Returns: A `Span` value.
/// - Limits: Does not reorder or validate offsets.
pub fn span(start : Int, stop : Int) -> Span {
  { start, stop }
}

///|
/// Merge two spans into the smallest span covering both.
///
/// This assumes `lhs` begins no later than `rhs`, which matches how the parser
/// constructs compound syntax nodes from left to right.
///
/// - Does: Combines two spans into one covering interval.
/// - Input: Two `Span` values.
/// - Returns: A `Span` from `lhs.start` to `rhs.stop`.
/// - Limits: Assumes caller passes spans in source order.
pub fn span_merge(lhs : Span, rhs : Span) -> Span {
  { start: lhs.start, stop: rhs.stop }
}

///|
/// Errors raised while tokenizing, parsing, or lowering source text.
///
/// Every variant carries a [`Span`](#span) so callers can highlight the failing
/// region in the original source string.
///
/// - Does: Groups lexer, parser, and lowering failures.
/// - Input: Raised by parsing front doors with a source span and diagnostic
///   payload.
/// - Returns: A `ParseError` variant.
/// - Limits: Error categories are intentionally coarse and do not include
///   recovery metadata.
pub(all) suberror ParseError {
  UnexpectedChar(span~ : Span, Char)
  UnexpectedToken(span~ : Span, String, String)
  UnexpectedEof(span~ : Span, String)
  InvalidNumber(span~ : Span, String)
  UnsupportedConstruct(span~ : Span, String)
} derive(Eq, Debug)
