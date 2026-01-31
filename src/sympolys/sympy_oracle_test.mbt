///|
enum OracleArg {
  Str(String)
  Int(Int)
  Bool(Bool)
  StrList(Array[String])
  IntList(Array[Int])
}

///|
const ORACLE_PATH : String =
  "/Users/caimeo/code/learning/sym-workspace/symbit:/Users/caimeo/code/learning/sym-workspace"

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
fn normalize_spaces(s : String) -> String {
  s.replace_all(old=" ", new="")
}

///|
fn canonical_cmp(s : String) -> String {
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
fn sympy_normalize(expr_str : String) -> String raise {
  sympy_oracle_call("normalize_expr_str", [OracleArg::Str(expr_str)])
}

///|
/// Call into the local Python shim `sympy_oracle.py` and return its string result.
fn sympy_oracle_call_json(
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
fn sympy_oracle_call(
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

///|
fn poly_canon_str(p : Poly) -> String raise {
  sympy_normalize(p.to_string())
}

///|
fn factor_list_to_string(
  content_str : String,
  factors : Array[(Poly, Int)],
) -> String raise {
  let c_norm = content_str
  let triples : Array[(Int, String, Int)] = Array::new()
  for pair in factors {
    let (f, m) = pair
    let s = f.to_string()
    if s == "1" || s == "-1" {
      continue
    }
    triples.push((f.degree(0), s, m))
  }
  // Sort by degree descending, then lexicographic string to stabilize order.
  for i in 0..<triples.length() {
    for j in (i + 1)..<triples.length() {
      let (di, si, mi) = triples[i]
      let (dj, sj, mj) = triples[j]
      if dj > di || (dj == di && sj.compare(si) < 0) {
        triples.set(i, (dj, sj, mj))
        triples.set(j, (di, si, mi))
      }
    }
  }
  let formatted = triples.map(t => {
    let (_, s, m) = t
    "(\{s}, \{m})"
  })
  let joined = formatted.join(",")
  "(\{c_norm}, [\{joined}])"
}

///|
fn groebner_to_string(basis : Array[Poly]) -> String raise {
  let parts : Array[String] = {
    let arr = Array::new()
    for p in basis {
      arr.push(p.to_string())
    }
    arr
  }
  parts.sort()
  parts.join(" | ")
}

///|
fn div_pair_to_string(quo : Poly, rem : Poly) -> String raise {
  "\{poly_canon_str(quo)}||\{poly_canon_str(rem)}"
}

///|
fn oracle_factor_list_over_zz() -> Unit raise {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(4)),
      @symcore.int(-1),
    ]),
  ) catch { e => fail("poly build failed: \{e.to_string()}") }
  let (content, factors) = try poly.factor_list() catch {
    e => fail("factor_list error: \{e.to_string()}")
  } noraise { v => v }
  let ours_raw = try factor_list_to_string(content.to_string(), factors) catch {
    err => fail("format factor_list failed: \{err}")
  } noraise { v => v }
  let ours = canonical_cmp(sympy_oracle_call("sort_factor_repr", [OracleArg::Str(ours_raw)]))

  let args : Array[OracleArg] = [OracleArg::Str("x**4 - 1")]
  let oracle = canonical_cmp(
    sympy_oracle_call("sort_factor_repr", [
      OracleArg::Str(sympy_oracle_call("factor_list_str", args)),
    ]),
  )
  guard ours == oracle else {
    fail("mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn oracle_factor_list_over_gf5() -> Unit raise {
  let builder = PolyBuilder::new(["x"], Domain::GF(5))
  let poly = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(1),
    ]),
  ) catch { e => fail("poly build failed: \{e.to_string()}") }
  let (_, factors) = try poly.factor_list() catch {
    e => fail("factor_list error: \{e.to_string()}")
  } noraise { v => v }
  // Reconstruct product and ensure equality in GF(5).
  let mut prod = Poly::one(poly.gens, poly.domain) catch { e => fail(e.to_string()) }
  for pair in factors {
    let (f, m) = pair
    let mut acc = Poly::one(poly.gens, poly.domain) catch { e => fail(e.to_string()) }
    for _i in 0..<m {
      acc = acc.mul(f) catch { e => fail(e.to_string()) }
    }
    prod = prod.mul(acc) catch { e => fail(e.to_string()) }
  }
  inspect(prod.to_string(), content=poly.to_string())
}

///|
fn oracle_gcd_over_zz() -> Unit raise {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let p = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(3)),
      @symcore.mul([@symcore.int(-1), @symcore.symbol("x")]),
    ]),
  ) catch { e => fail("poly p failed: \{e.to_string()}") }
  let q = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(-1),
    ]),
  ) catch { e => fail("poly q failed: \{e.to_string()}") }
  let g = try p.gcd_univar(q) catch {
    e => fail("gcd_univar error: \{e.to_string()}")
  } noraise { v => v }
  let ours = normalize_spaces(
    try poly_canon_str(g) catch { err => fail("canon gcd failed: \{err}") } noraise { v => v },
  )

  let args : Array[OracleArg] = [
    OracleArg::Str("x**3 - x"),
    OracleArg::Str("x**2 - 1"),
  ]
  let oracle = normalize_spaces(sympy_oracle_call("gcd_str", args))
  guard ours == oracle else {
    fail("mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn oracle_resultant_over_zz() -> Unit raise {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let p = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      @symcore.int(1),
    ]),
  ) catch { e => fail("poly p failed: \{e.to_string()}") }
  let q = builder.from_expr(
    @symcore.add([@symcore.symbol("x"), @symcore.int(-1)]),
  ) catch { e => fail("poly q failed: \{e.to_string()}") }
  let res = try p.resultant(q, 0) catch {
    e => fail("resultant error: \{e.to_string()}")
  } noraise { v => v }
  let ours = normalize_spaces(
    try sympy_normalize(res.to_string()) catch {
      err => fail("canon resultant failed: \{err}")
    } noraise { v => v },
  )

  let args : Array[OracleArg] = [
    OracleArg::Str("x**2 + 1"),
    OracleArg::Str("x - 1"),
    OracleArg::Str("x"),
  ]
  let oracle = normalize_spaces(sympy_oracle_call("resultant_str", args))
  guard ours == oracle else {
    fail("mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn oracle_groebner_basis_matches() -> Unit raise {
  let builder = PolyBuilder::new(["x", "y"], Domain::QQ)
  let f1 = builder.from_expr(
    @symcore.add([
      @symcore.mul([@symcore.symbol("x"), @symcore.symbol("y")]),
      @symcore.int(-1),
    ]),
  ) catch { e => fail("f1 failed: \{e.to_string()}") }
  let f2 = builder.from_expr(
    @symcore.add([@symcore.symbol("x"), @symcore.int(-1)]),
  ) catch { e => fail("f2 failed: \{e.to_string()}") }
  let basis = try Poly::groebner([f1, f2], order=TermOrder::Lex) catch {
    e => fail("groebner error: \{e.to_string()}")
  } noraise { v => v }
  let ours = canonical_cmp(
    try groebner_to_string(basis) catch {
      err => fail("canon groebner failed: \{err}")
    } noraise { v => v },
  )

  let args : Array[OracleArg] = [
    OracleArg::StrList(["x*y - 1", "x - 1"]),
  ]
  let oracle = canonical_cmp(sympy_oracle_call("groebner_str", args))
  guard ours == oracle else {
    fail("mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn oracle_sqf_list_over_zz() -> Unit raise {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let poly = builder.from_expr(
    @symcore.mul([
      @symcore.pow(@symcore.add([@symcore.symbol("x"), @symcore.int(-1)]), @symcore.int(2)),
      @symcore.pow(@symcore.add([@symcore.symbol("x"), @symcore.int(2)]), @symcore.int(3)),
    ]),
  ) catch { e => fail("poly build failed: \{e.to_string()}") }
  let (content, parts) = try poly.sqf_list() catch {
    e => fail("sqf_list error: \{e.to_string()}")
  } noraise { v => v }
  let ours_raw = try factor_list_to_string(content.to_string(), parts) catch {
    err => fail("format sqf_list failed: \{err}")
  } noraise { v => v }
  let ours = canonical_cmp(sympy_oracle_call("sort_factor_repr", [OracleArg::Str(ours_raw)]))

  let args : Array[OracleArg] = [
    OracleArg::Str("(x - 1)**2 * (x + 2)**3"),
  ]
  let oracle = canonical_cmp(
    sympy_oracle_call("sort_factor_repr", [
      OracleArg::Str(sympy_oracle_call("sqf_list_str", args)),
    ]),
  )
  guard ours == oracle else {
    fail("mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn oracle_divmod_over_zz() -> Unit raise {
  let builder = PolyBuilder::new(["x"], Domain::ZZ)
  let p = builder.from_expr(
    @symcore.add([
      @symcore.pow(@symcore.symbol("x"), @symcore.int(3)),
      @symcore.int(-1),
    ]),
  ) catch { e => fail("p failed: \{e.to_string()}") }
  let q = builder.from_expr(
    @symcore.add([@symcore.symbol("x"), @symcore.int(-1)]),
  ) catch { e => fail("q failed: \{e.to_string()}") }
  let (quo, rem) = try p.divmod_univar(q) catch {
    e => fail("divmod_univar error: \{e.to_string()}")
  } noraise { v => v }
  let ours = normalize_spaces(
    try div_pair_to_string(quo, rem) catch {
      err => fail("canon divmod failed: \{err}")
    } noraise { v => v },
  )

  let args : Array[OracleArg] = [
    OracleArg::Str("x**3 - 1"),
    OracleArg::Str("x - 1"),
  ]
  let oracle = normalize_spaces(sympy_oracle_call("div_str", args))
  guard ours == oracle else {
    fail("mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}
