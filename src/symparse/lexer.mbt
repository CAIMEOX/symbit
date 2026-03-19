///|
fn char_at(src : String, index : Int) -> Char? {
  src.get_char(index)
}

///|
fn is_ident_start(ch : Char) -> Bool {
  ch == '_' || ch.is_ascii_alphabetic()
}

///|
fn is_ident_continue(ch : Char) -> Bool {
  is_ident_start(ch) || ch.is_ascii_digit()
}

///|
fn is_ascii_digit_at(src : String, index : Int) -> Bool {
  match char_at(src, index) {
    Some(ch) => ch.is_ascii_digit()
    None => false
  }
}

///|
fn scan_number(src : String, start : Int) -> (TokenKind, Int) {
  let mut i = start
  while is_ascii_digit_at(src, i) {
    i += 1
  }
  if is_ascii_digit_at(src, i + 1) {
    match char_at(src, i) {
      Some('.') => {
        i += 1
        while is_ascii_digit_at(src, i) {
          i += 1
        }
        (TokenKind::DecimalLit(src.unsafe_substring(start~, end=i)), i)
      }
      _ => (TokenKind::IntLit(src.unsafe_substring(start~, end=i)), i)
    }
  } else {
    (TokenKind::IntLit(src.unsafe_substring(start~, end=i)), i)
  }
}

///|
fn scan_ident(src : String, start : Int) -> (TokenKind, Int) {
  let mut i = start
  while (match char_at(src, i) {
          Some(ch) => is_ident_continue(ch)
          None => false
        }) {
    i += 1
  }
  (TokenKind::Ident(src.unsafe_substring(start~, end=i)), i)
}

///|
/// Convert a source string into a typed token stream.
pub fn lex(src : String) -> Array[Token] raise ParseError {
  let tokens : Array[Token] = []
  let mut index = 0
  let len = src.length()
  while index < len {
    let ch = match char_at(src, index) {
      Some(ch) => ch
      None => break
    }
    if ch.is_ascii_whitespace() {
      index += ch.utf16_len()
      continue
    }
    let start = index
    let (kind, next_index) = match ch {
      '+' => (TokenKind::Plus, index + 1)
      '-' => (TokenKind::Minus, index + 1)
      '/' => (TokenKind::Slash, index + 1)
      '(' => (TokenKind::LParen, index + 1)
      ')' => (TokenKind::RParen, index + 1)
      ',' => (TokenKind::Comma, index + 1)
      '^' => (TokenKind::Caret, index + 1)
      '<' =>
        match char_at(src, index + 1) {
          Some('=') => (TokenKind::Le, index + 2)
          _ => (TokenKind::Lt, index + 1)
        }
      '>' =>
        match char_at(src, index + 1) {
          Some('=') => (TokenKind::Ge, index + 2)
          _ => (TokenKind::Gt, index + 1)
        }
      '=' =>
        match char_at(src, index + 1) {
          Some('=') => (TokenKind::EqEq, index + 2)
          _ => (TokenKind::Eq, index + 1)
        }
      '*' =>
        match char_at(src, index + 1) {
          Some('*') => (TokenKind::Pow, index + 2)
          _ => (TokenKind::Star, index + 1)
        }
      ch if ch.is_ascii_digit() => scan_number(src, start)
      ch if is_ident_start(ch) => scan_ident(src, start)
      other =>
        raise ParseError::UnexpectedChar(
          span=span(start, start + other.utf16_len()),
          other,
        )
    }
    tokens.push(token(kind, span(start, next_index)))
    index = next_index
  }
  tokens.push(token(TokenKind::Eof, span(len, len)))
  tokens
}
