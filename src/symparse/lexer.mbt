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
  let mut has_dot = false
  let mut has_exponent = false
  if char_at(src, i) is Some('.') {
    has_dot = true
    i += 1
  }
  while is_ascii_digit_at(src, i) {
    i += 1
  }
  if char_at(src, i) is Some('.') {
    has_dot = true
    i += 1
    while is_ascii_digit_at(src, i) {
      i += 1
    }
  }
  if has_dot && char_at(src, i) is Some('[') {
    let mut j = i + 1
    while is_ascii_digit_at(src, j) {
      j += 1
    }
    if j > i + 1 && char_at(src, j) is Some(']') {
      i = j + 1
    }
  }
  match char_at(src, i) {
    Some('e') | Some('E') => {
      let exponent_start = i
      let mut j = i + 1
      match char_at(src, j) {
        Some('+') | Some('-') => j += 1
        _ => ()
      }
      let digit_start = j
      while is_ascii_digit_at(src, j) {
        j += 1
      }
      if j > digit_start {
        has_exponent = true
        i = j
      } else {
        i = exponent_start
      }
    }
    _ => ()
  }
  if has_dot || has_exponent {
    (TokenKind::DecimalLit(src.unsafe_substring(start~, end=i)), i)
  } else {
    (TokenKind::IntLit(src.unsafe_substring(start~, end=i)), i)
  }
}

///|
fn starts_decimal(src : String, index : Int) -> Bool {
  match char_at(src, index) {
    Some('.') => is_ascii_digit_at(src, index + 1)
    _ => false
  }
}

///|
fn decimal_parts(text : String) -> (String, String, String) {
  match text.split_once(".") {
    Some((whole, frac_part)) =>
      match frac_part.to_string().split_once("[") {
        Some((nonrepeat, repeat_part)) =>
          (
            whole.to_string(),
            nonrepeat.to_string(),
            repeat_part
            .to_string()
            .unsafe_substring(start=0, end=repeat_part.length() - 1),
          )
        None => (whole.to_string(), frac_part.to_string(), "")
      }
    None => (text, "", "")
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
      '!' =>
        match char_at(src, index + 1) {
          Some('=') => (TokenKind::Ne, index + 2)
          Some('!') => (TokenKind::BangBang, index + 2)
          _ => (TokenKind::Bang, index + 1)
        }
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
      '.' if starts_decimal(src, index) => scan_number(src, start)
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
