///|\
/// String and integer helpers aligned with `sympy.utilities.misc`.

///|
pub enum IntLike {
  Int(Int)
  Double(Double)
  Bool(Bool)
  Expr(Expr)
} derive(Eq)

///|
pub fn int_like_int(value : Int) -> IntLike {
  IntLike::Int(value)
}

///|
pub fn int_like_double(value : Double) -> IntLike {
  IntLike::Double(value)
}

///|
pub fn int_like_bool(value : Bool) -> IntLike {
  IntLike::Bool(value)
}

///|
pub fn int_like_expr(value : Expr) -> IntLike {
  IntLike::Expr(value)
}

///|
fn count_leading_spaces(line : String) -> Int {
  let mut count = 0
  for ch in line {
    if ch == ' ' {
      count += 1
    } else {
      break
    }
  }
  count
}

///|
fn trim_blank_lines(lines : Array[String]) -> Array[String] {
  let mut start = 0
  while start < lines.length() && lines[start].trim() == "" {
    start += 1
  }
  let mut stop = lines.length()
  while stop > start && lines[stop - 1].trim() == "" {
    stop -= 1
  }
  let out : Array[String] = []
  for i in start..<stop {
    out.push(lines[i])
  }
  out
}

///|
fn dedent_lines(lines : Array[String]) -> Array[String] {
  let mut indent : Int? = None
  for line in lines {
    if line.trim() == "" {
      continue
    }
    let spaces = count_leading_spaces(line)
    indent = match indent {
      Some(current) => Some(if spaces < current { spaces } else { current })
      None => Some(spaces)
    }
  }
  let width = match indent {
    Some(v) => v
    None => 0
  }
  lines.map(line => {
    if width == 0 || line.length() < width {
      line
    } else {
      line[width:line.length()].to_string()
    }
  })
}

///|
fn split_words(text : String) -> Array[String] {
  let words : Array[String] = []
  let mut current = ""
  for ch in text {
    if ch.is_whitespace() {
      if current.length() > 0 {
        words.push(current)
        current = ""
      }
    } else {
      current = current + ch.to_string()
    }
  }
  if current.length() > 0 {
    words.push(current)
  }
  words
}

///|
fn wrap_paragraph(text : String, width : Int) -> String {
  if width <= 0 {
    return text
  }
  let words = split_words(text)
  if words.is_empty() {
    return ""
  }
  let out = StringBuilder::new()
  let mut wrote = false
  let mut line = words[0]
  for i in 1..<words.length() {
    let word = words[i]
    if line.length() + 1 + word.length() <= width {
      line = line + " " + word
    } else {
      if wrote {
        out.write_char('\n')
      }
      out.write_string(line)
      wrote = true
      line = word
    }
  }
  if wrote {
    out.write_char('\n')
  }
  out.write_string(line)
  out.to_string()
}

///|
/// Strip leading/trailing blank lines, dedent the body, then wrap it to
/// `w` columns. The result matches the SymPy helper convention of starting
/// with a leading newline so that it can be dropped into docstrings directly.
pub fn filldedent(s : String, w? : Int = 70) -> String {
  let raw_lines = Array::from_iter(s.split("\n")).map(part => part.to_string())
  let trimmed = trim_blank_lines(raw_lines)
  let dedented = dedent_lines(trimmed)
  let body = wrap_paragraph(dedented.join(" "), w)
  "\n" + body
}

///|
fn quote_style(s : String) -> String {
  if s.contains("\"") && !s.contains("'") {
    "\""
  } else {
    "'"
  }
}

///|
fn repr_like(s : String) -> String {
  let quote = quote_style(s)
  let escaped = s
    .replace_all(old="\\", new="\\\\")
    .replace_all(old="\n", new="\\n")
  if quote == "'" {
    quote + escaped.replace_all(old="'", new="\\'") + quote
  } else {
    quote + escaped.replace_all(old="\"", new="\\\"") + quote
  }
}

///|
/// Return a copy-pastable string literal layout for single-line strings.
pub fn strlines(s : String, c? : Int = 64, short? : Bool = false) -> String {
  if s.contains("\n") {
    return rawlines(s)
  }
  let quote = quote_style(s)
  let raw = s.contains("\\")
  let prefix = if raw { "r" } else { "" }
  let overhead = if raw { 3 } else { 2 }
  let chunk = if c > overhead { c - overhead } else { 1 }
  let parts : Array[String] = []
  let mut i = 0
  while i < s.length() {
    let stop = if i + chunk > s.length() { s.length() } else { i + chunk }
    let part = s[i:stop].to_string()
    let escaped = if raw {
      part
    } else if quote == "'" {
      part.replace_all(old="'", new="\\'")
    } else {
      part.replace_all(old="\"", new="\\\"")
    }
    parts.push(prefix + quote + escaped + quote)
    i = stop
  }
  if short && parts.length() == 1 {
    return parts[0]
  }
  "(\n" + parts.join("\n") + "\n)"
}

///|
/// Return a multi-line literal layout for `s`, using `dedent('''...''')`
/// when that form is cleaner and tuple-of-lines syntax otherwise.
pub fn rawlines(s : String) -> String {
  let lines = Array::from_iter(s.split("\n")).map(part => part.to_string())
  if lines.length() == 1 {
    return repr_like(lines[0])
  }
  let trailing = s.has_suffix("\n")
  let has_backslash = s.contains("\\")
  let has_triple_single = s.contains("'''")
  let has_triple_double = s.contains("\"\"\"")
  let has_trailing_space = lines.any(line => line.has_suffix(" "))
  if has_trailing_space ||
    has_backslash ||
    (has_triple_single && has_triple_double) {
    let pieces : Array[String] = []
    for i in 0..<lines.length() {
      let line = lines[i]
      let need_newline = i != lines.length() - 1 || trailing
      pieces.push(repr_like(if need_newline { line + "\n" } else { line }))
    }
    return "(\n    " + pieces.join("\n    ") + "\n)"
  }
  let indented = lines.join("\n    ")
  if has_triple_single {
    return "dedent(\"\"\"\\\n    " + indented + "\"\"\")"
  }
  "dedent('''\\\n    " + indented + "''')"
}

///|
fn normalize_replacements(
  reps : Array[(String, String)],
) -> Array[(String, String)] {
  let out = reps.map(pair => pair)
  out.sort_by((a, b) => {
    let len_cmp = b.0.length() - a.0.length()
    if len_cmp != 0 {
      len_cmp
    } else {
      a.0.compare(b.0)
    }
  })
  out
}

///|
/// Replace multiple substrings in one pass, preferring longer keys first.
pub fn replace(string : String, reps : Array[(String, String)]) -> String {
  if reps.is_empty() {
    return string
  }
  let ordered = normalize_replacements(reps)
  let out = StringBuilder::new()
  let mut i = 0
  while i < string.length() {
    let rest = string[i:string.length()].to_string()
    let mut matched : (String, String)? = None
    for item in ordered {
      if rest.has_prefix(item.0) {
        matched = Some(item)
        break
      }
    }
    match matched {
      Some((old, new)) => {
        out.write_string(new)
        i += old.length()
      }
      None => {
        out.write_string(string[i:i + 1].to_string())
        i += 1
      }
    }
  }
  out.to_string()
}

///|
/// Translation helper aligned with `sympy.utilities.misc.translate`.
pub fn translate(
  s : String,
  oldchars? : String? = None,
  newchars? : String? = None,
  deletechars? : String? = None,
  multimap? : Array[(String, String)] = [],
) -> String raise UtilitiesError {
  let mut out = s
  match deletechars {
    Some(chars) =>
      for ch in chars {
        out = out.replace_all(old=ch.to_string(), new="")
      }
    None => ()
  }
  out = replace(out, multimap)
  match oldchars {
    None =>
      if newchars is Some(_) {
        raise UtilitiesError::InvalidArgument(
          "newchars should be None when oldchars is None",
        )
      }
    Some(old0) => {
      let new0 = match newchars {
        Some(v) => v
        None => ""
      }
      if old0.length() != new0.length() {
        raise UtilitiesError::InvalidArgument(
          "oldchars and newchars must have the same length",
        )
      }
      let olds : Array[Char] = []
      let news : Array[Char] = []
      for ch in old0 {
        olds.push(ch)
      }
      for ch in new0 {
        news.push(ch)
      }
      for i in 0..<olds.length() {
        out = out.replace_all(old=olds[i].to_string(), new=news[i].to_string())
      }
    }
  }
  out
}

///|
/// Return the ordinal suffix form of `num`, e.g. `1 -> 1st`.
pub fn ordinal(num : Int) -> String {
  let k = (if num < 0 { -num } else { num }) % 100
  let suffix = if k >= 11 && k <= 13 {
    "th"
  } else if k % 10 == 1 {
    "st"
  } else if k % 10 == 2 {
    "nd"
  } else if k % 10 == 3 {
    "rd"
  } else {
    "th"
  }
  num.to_string() + suffix
}

///|
/// Return a display name for a callable or path-like string. With
/// `short=true`, only the tail after the final `.` or `::` is kept.
pub fn func_name(name : String, short? : Bool = false) -> String {
  if !short {
    return name
  }
  let mut dot : Int? = None
  let mut colon : Int? = None
  for i in 0..<name.length() {
    if name[i:i + 1] == "." {
      dot = Some(i)
    }
    if i + 1 < name.length() && name[i:i + 2] == "::" {
      colon = Some(i)
    }
  }
  let start = match (dot, colon) {
    (Some(i), Some(j)) => if i > j { i + 1 } else { j + 2 }
    (Some(i), None) => i + 1
    (None, Some(j)) => j + 2
    (None, None) => 0
  }
  if start <= 0 || start >= name.length() {
    name
  } else {
    name[start:name.length()].to_string()
  }
}

///|
/// Convert a supported numeric value to a builtin `Int`.
pub fn as_int(
  value : IntLike,
  strict? : Bool = true,
) -> Int raise UtilitiesError {
  match value {
    IntLike::Int(n) => n
    IntLike::Bool(_) if strict =>
      raise UtilitiesError::InvalidArgument(
        "True/False are not accepted as integers in strict mode",
      )
    IntLike::Bool(b) => if b { 1 } else { 0 }
    IntLike::Double(d) => {
      if strict {
        raise UtilitiesError::InvalidArgument(
          "double value is not an integer in strict mode",
        )
      }
      let n = d.to_int()
      if d != n.to_double() {
        raise UtilitiesError::InvalidArgument(
          d.to_string() + " is not an integer",
        )
      }
      n
    }
    IntLike::Expr(Expr::Number(n)) if n.is_integral() => n.numerator().to_int()
    IntLike::Expr(expr) =>
      raise UtilitiesError::InvalidArgument(
        @symprint.pretty_string(expr) + " is not an integer",
      )
  }
}
