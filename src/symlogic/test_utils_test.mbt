///|
fn normalize_model_string(s : String) -> String {
  let t = s.trim().to_string()
  if t == "False" {
    return "False"
  }
  if !t.has_prefix("{") || !t.has_suffix("}") {
    return t
  }
  let len = t.length()
  if len <= 2 {
    return "{}"
  }
  let inner = (try! t[1:len - 1]).to_string().trim().to_string()
  if inner.is_empty() {
    return "{}"
  }
  let parts : Array[String] = Array::new()
  for part in inner.split(", ") {
    parts.push(part.to_string())
  }
  parts.sort()
  let joined = parts.join(", ")
  "{\{joined}}"
}

///|
fn clauses_to_string(clauses : Array[BoolExpr]) -> String {
  if clauses.is_empty() {
    return "[]"
  }
  let parts : Array[String] = Array::new()
  for clause in clauses {
    parts.push(to_string(clause))
  }
  parts.sort()
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn bool_option_to_string(value : Bool?) -> String {
  match value {
    Some(true) => "True"
    Some(false) => "False"
    None => "None"
  }
}

///|
fn normalize_models_string(s : String) -> String {
  let t = s.trim().to_string()
  if !t.has_prefix("[") || !t.has_suffix("]") {
    return t
  }
  let len = t.length()
  if len <= 2 {
    return "[]"
  }
  let inner = (try! t[1:len - 1]).to_string().trim().to_string()
  if inner.is_empty() {
    return "[]"
  }
  let parts : Array[String] = Array::new()
  let mut depth = 0
  let mut skip_space = false
  let mut buf = StringBuilder::new()
  for ch in inner {
    if skip_space {
      if ch == ' ' {
        continue
      }
      skip_space = false
    }
    if ch == '{' {
      depth += 1
    } else if ch == '}' {
      depth -= 1
    }
    if ch == ',' && depth == 0 {
      parts.push(buf.to_string().trim().to_string())
      buf = StringBuilder::new()
      skip_space = true
      continue
    }
    buf.write_char(ch)
  }
  let tail = buf.to_string().trim().to_string()
  if !tail.is_empty() {
    parts.push(tail)
  }
  let norm : Array[String] = Array::new()
  for part in parts {
    norm.push(normalize_model_string(part))
  }
  norm.sort()
  let joined = norm.join(", ")
  "[\{joined}]"
}
