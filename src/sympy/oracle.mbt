///|
pub(all) enum OracleArg {
  Str(String)
  Int(Int)
  Bool(Bool)
  StrList(Array[String])
  IntList(Array[Int])
}

///|
const ORACLE_PATH : String =
  "/Users/caimeo/code/learning/sym-workspace/symbit/src/sympy:/Users/caimeo/code/learning/sym-workspace/symbit:/Users/caimeo/code/learning/sym-workspace"

///|
#borrow(payload_json, oracle_path)
extern "C" fn sympy_oracle_exec(payload_json : String, oracle_path : String) -> String = "sympy_oracle_exec"

///| JSON-escape a string (minimal subset needed for test payloads).
fn json_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for ch in s {
    match ch {
      '"' => sb.write_view("\\\"")
      '\\' => sb.write_view("\\\\")
      '\n' => sb.write_view("\\n")
      '\r' => sb.write_view("\\r")
      '\t' => sb.write_view("\\t")
      _ => sb.write_char(ch)
    }
  }
  sb.to_string()
}

///|
fn json_string(s : String) -> String {
  let escaped = json_escape(s)
  let sb = StringBuilder::new()
  sb..write_char('"')..write_view(escaped)..write_char('"')
  sb.to_string()
}

///|
fn oracle_arg_json(arg : OracleArg) -> String {
  match arg {
    OracleArg::Str(s) => json_string(s)
    OracleArg::Int(n) => n.to_string()
    OracleArg::Bool(b) => if b { "true" } else { "false" }
    OracleArg::StrList(list) => {
      let sb = StringBuilder::new()
      sb.write_char('[')
      for i in 0..<list.length() {
        if i > 0 {
          sb.write_char(',')
        }
        sb.write_view(json_string(list[i]))
      }
      sb.write_char(']')
      sb.to_string()
    }
    OracleArg::IntList(list) => {
      let sb = StringBuilder::new()
      sb.write_char('[')
      for i in 0..<list.length() {
        if i > 0 {
          sb.write_char(',')
        }
        sb.write_view(list[i].to_string())
      }
      sb.write_char(']')
      sb.to_string()
    }
  }
}

///| Build the JSON payload passed to the external SymPy oracle process.
fn oracle_payload_json(
  func : String,
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> String {
  let sb = StringBuilder::new()
  sb..write_char('{')
    ..write_view("\"func\":")
    ..write_view(json_string(func))
    ..write_view(",\"args\":[")
  for i in 0..<args.length() {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_view(oracle_arg_json(args[i]))
  }
  sb..write_view("],\"kwargs\":{")
  let mut first = true
  for k, v in kwargs {
    if first {
      first = false
    } else {
      sb.write_char(',')
    }
    sb..write_view(json_string(k))..write_char(':')..write_view(oracle_arg_json(v))
  }
  sb..write_view("}}")
  sb.to_string()
}

///|
fn strip_trailing_newline(s : String) -> String {
  s.trim_end(chars="\r\n").to_string()
}

///|
let oracle_lock : Ref[Bool] = { val: false }
let oracle_seq : Ref[Int] = { val: 0 }

///| Serialize oracle calls to avoid concurrent Python access.
fn with_oracle_lock[T](f : () -> T raise) -> T raise {
  while oracle_lock.val {
    ()
  }
  oracle_lock.val = true
  try f() catch {
    e => {
      oracle_lock.val = false
      raise e
    }
  } noraise {
    v => {
      oracle_lock.val = false
      v
    }
  }
}

///|
/// Remove all spaces to make string comparison insensitive to formatting.
pub fn normalize_spaces(s : String) -> String {
  s.replace_all(old=" ", new="")
}

///|
pub fn canonical_cmp(s : String) -> String {
  let mut t = normalize_spaces(s)
  t = t.replace_all(old="2+x", new="x+2")
  t = t.replace_all(old="3+x", new="x+3")
  t = t.replace_all(old="-1+x", new="x-1")
  t = t.replace_all(old="1+x", new="x+1")
  t = t.replace_all(old="1+x**2", new="x**2+1")
  t = t.replace_all(old="-1+y", new="y-1")
  t = t.replace_all(old="1+y", new="y+1")
  t
}

///|
/// Canonicalise an expression string via `str(sympy.sympify(expr))` so that
/// ordering matches SymPy’s printer (helps when our printer orders constants
/// first).
pub fn sympy_normalize(expr_str : String) -> String raise {
  sympy_oracle_call("normalize_expr_str", [OracleArg::Str(expr_str)])
}

///|
/// Call into the local Python shim `sympy_oracle.py` and return its string result.
pub fn sympy_oracle_call_json(
  func : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> Json raise {
  with_oracle_lock(fn () raise {
    oracle_seq.val = oracle_seq.val + 1
    println("oracle[\{oracle_seq.val}]: \{func}")
    let payload = oracle_payload_json(func, args, kwargs)
    let out = strip_trailing_newline(sympy_oracle_exec(payload, ORACLE_PATH))
    if out.has_prefix("PYERR:") {
      fail(out)
    }
    let parsed = @json.parse(out)
    match parsed {
      Object(obj) => {
        match obj.get("ok") {
          Some(True) => match obj.get("value") {
            Some(value) => value
            None => fail("oracle JSON missing value")
          }
          Some(False) => {
            let msg = match obj.get("error") {
              Some(String(s)) => s
              _ => "oracle error"
            }
            fail(msg)
          }
          _ => fail("oracle JSON missing ok flag")
        }
      }
      _ => fail("oracle JSON not an object")
    }
  })
}

///|
pub fn sympy_oracle_call(
  func : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> String raise {
  let value = sympy_oracle_call_json(func, args, kwargs=kwargs)
  match value {
    String(s) => s
    _ => value.stringify()
  }
}
