///|
let sympy_oracle_code : String =
  #|import json
  #|import sympy as sp
  #|
  #|def _fmt_mod(poly, modulus):
  #|    p = sp.Poly(poly, modulus=modulus)
  #|    expr = 0
  #|    for mon, coeff in p.terms():
  #|        c = int(coeff) % modulus
  #|        term = c
  #|        for g, e in zip(p.gens, mon):
  #|            term *= g ** e
  #|        expr += term
  #|    return str(sp.expand(expr))
  #|
  #|def factor_list_str(expr_str: str, modulus=None) -> str:
  #|    if isinstance(modulus, str):
  #|        modulus = int(modulus)
  #|    expr = sp.sympify(expr_str)
  #|    if modulus is None:
  #|        content, factors = sp.factor_list(expr)
  #|    else:
  #|        content, factors = sp.factor_list(expr, modulus=modulus)
  #|    # sort factors deterministically by string form
  #|    def _fmt(poly):
  #|        if modulus is None:
  #|            return str(sp.Poly(poly).as_expr())
  #|        return _fmt_mod(poly, modulus)
  #|    factors = sorted(factors, key=lambda p: (sp.srepr(p[0]), p[1]))
  #|    factors_str = ",".join(f"({_fmt(p)}, {m})" for p, m in factors if p != 1)
  #|    return f"({content}, [{factors_str}])"
  #|
  #|def gcd_str(a_str: str, b_str: str) -> str:
  #|    a = sp.sympify(a_str)
  #|    b = sp.sympify(b_str)
  #|    syms = sorted(a.free_symbols | b.free_symbols, key=lambda s: s.name)
  #|    if syms:
  #|        pa = sp.Poly(a, *syms)
  #|        pb = sp.Poly(b, *syms)
  #|        return str(pa.gcd(pb).as_expr())
  #|    return str(sp.gcd(a, b))
  #|
  #|def resultant_str(p_str: str, q_str: str, var_str: str) -> str:
  #|    p = sp.sympify(p_str)
  #|    q = sp.sympify(q_str)
  #|    v = sp.sympify(var_str)
  #|    return str(sp.resultant(p, q, v))
  #|
  #|def groebner_str(exprs, order="lex") -> str:
  #|    polys = [sp.sympify(e) for e in exprs]
  #|    symbols = sorted({s for p in polys for s in p.free_symbols}, key=lambda s: s.name)
  #|    g = sp.groebner(polys, *symbols, order=order)
  #|    basis = [str(p.monic().as_expr()) for p in g.polys]
  #|    basis.sort()
  #|    return " | ".join(basis)
  #|
  #|def sqf_list_str(expr_str: str, modulus=None) -> str:
  #|    if isinstance(modulus, str):
  #|        modulus = int(modulus)
  #|    expr = sp.sympify(expr_str)
  #|    if modulus is None:
  #|        content, factors = sp.sqf_list(expr)
  #|    else:
  #|        poly = sp.Poly(expr, modulus=modulus)
  #|        content, factors = poly.sqf_list()
  #|    def _fmt(poly):
  #|        if isinstance(poly, sp.Poly):
  #|            if modulus is None:
  #|                return str(poly.as_expr())
  #|            return _fmt_mod(poly.as_expr(), modulus)
  #|        if modulus is None:
  #|            return str(sp.Poly(poly).as_expr())
  #|        return _fmt_mod(poly, modulus)
  #|    factors = sorted(factors, key=lambda p: (sp.srepr(p[0]), p[1]))
  #|    factors_str = ",".join(f"({_fmt(p)}, {m})" for p, m in factors if p != 1)
  #|    return f"({content}, [{factors_str}])"
  #|
  #|def sqf_part_str(expr_str: str) -> str:
  #|    expr = sp.sympify(expr_str)
  #|    part = sp.Poly(expr).sqf_part()
  #|    return str(part.as_expr())
  #|
  #|def expr_equal(lhs: str, rhs: str) -> str:
  #|    a = sp.sympify(lhs)
  #|    b = sp.sympify(rhs)
  #|    return str(bool(sp.simplify(a - b) == 0))
  #|
  #|def normalize_expr_str(expr_str: str) -> str:
  #|    expr = sp.sympify(expr_str)
  #|    return str(expr)
  #|
  #|def factor_list_json(expr_str: str, modulus=None):
  #|    if isinstance(modulus, str):
  #|        modulus = int(modulus)
  #|    expr = sp.sympify(expr_str)
  #|    if modulus is None:
  #|        return sp.factor_list(expr)
  #|    return sp.factor_list(expr, modulus=modulus)
  #|
  #|def sympify_list_json(exprs):
  #|    return [sp.sympify(s) for s in exprs]
  #|
  #|def monic_expr_str(expr_str: str, modulus=None) -> str:
  #|    if isinstance(modulus, str):
  #|        modulus = int(modulus)
  #|    expr = sp.sympify(expr_str)
  #|    if modulus is None:
  #|        return str(sp.Poly(expr).monic().as_expr())
  #|    return str(sp.Poly(expr, modulus=modulus).monic().as_expr())
  #|
  #|def div_str(p_str: str, q_str: str) -> str:
  #|    p = sp.sympify(p_str)
  #|    q = sp.sympify(q_str)
  #|    quo, rem = sp.div(p, q)
  #|    return f"{quo}||{rem}"
  #|
  #|def echo_args(*args) -> str:
  #|    return "|".join(str(a) for a in args)
  #|
  #|
  #|# Normalize a factor_list-style string "(content, [(factor, exp), ...])"
  #|# by making factors monic and sorting by srepr, so MoonBit results can be
  #|# compared against SymPy's canonical order/units.
  #|def normalize_factor_list_repr(repr_str: str, modulus=None) -> str:
  #|    if isinstance(modulus, str):
  #|        modulus = int(modulus)
  #|    content, factors = sp.sympify(repr_str)
  #|    normed = []
  #|    for expr, mult in factors:
  #|        poly = sp.Poly(expr, modulus=modulus) if modulus is not None else sp.Poly(expr)
  #|        expr_norm = poly.monic().as_expr()
  #|        normed.append((expr_norm, mult))
  #|    normed = sorted(normed, key=lambda p: (sp.srepr(p[0]), p[1]))
  #|    factors_str = ",".join(f"({str(p)}, {m})" for p, m in normed)
  #|    return f"({content}, [{factors_str}])"
  #|
  #|def sort_factor_repr(repr_str: str) -> str:
  #|    content, factors = sp.sympify(repr_str)
  #|    factors = sorted(factors, key=lambda p: (sp.srepr(p[0]), p[1]))
  #|    factors_str = ",".join(f"({str(p)}, {m})" for p, m in factors)
  #|    return f"({content}, [{factors_str}])"
  #|
  #|def echo_int(n: int) -> str:
  #|    if isinstance(n, str):
  #|        n = int(n)
  #|    return str(n)
  #|
  #|def _coerce_modulus(modulus):
  #|    if isinstance(modulus, str):
  #|        return int(modulus)
  #|    return modulus
  #|
  #|def _sympify_expr(expr):
  #|    return sp.sympify(expr) if isinstance(expr, str) else expr
  #|
  #|def _coerce_gens(gens):
  #|    if gens is None:
  #|        return None
  #|    if isinstance(gens, (list, tuple)):
  #|        out = []
  #|        for g in gens:
  #|            if isinstance(g, str):
  #|                out.append(sp.symbols(g))
  #|            else:
  #|                out.append(g)
  #|        return out
  #|    if isinstance(gens, str):
  #|        syms = sp.symbols(gens)
  #|        if isinstance(syms, tuple):
  #|            return list(syms)
  #|        return [syms]
  #|    return [gens]
  #|
  #|def _default_gens(*exprs):
  #|    syms = set()
  #|    for e in exprs:
  #|        if e is None:
  #|            continue
  #|        if hasattr(e, "free_symbols"):
  #|            syms |= set(e.free_symbols)
  #|    return sorted(syms, key=lambda s: s.name)
  #|
  #|def _poly(expr, gens, domain, modulus):
  #|    if gens is None:
  #|        return sp.Poly(expr, domain=domain, modulus=modulus)
  #|    return sp.Poly(expr, *gens, domain=domain, modulus=modulus)
  #|
  #|def polys_gcd_json(a, b, gens=None, domain=None, modulus=None):
  #|    modulus = _coerce_modulus(modulus)
  #|    a = _sympify_expr(a)
  #|    b = _sympify_expr(b)
  #|    gens = _coerce_gens(gens)
  #|    if gens is None:
  #|        gens = _default_gens(a, b)
  #|    if gens and (domain is not None or modulus is not None):
  #|        pa = _poly(a, gens, domain, modulus)
  #|        pb = _poly(b, gens, domain, modulus)
  #|        return pa.gcd(pb)
  #|    return sp.gcd(a, b)
  #|
  #|def polys_resultant_json(p, q, var=None, gens=None, domain=None, modulus=None):
  #|    modulus = _coerce_modulus(modulus)
  #|    p = _sympify_expr(p)
  #|    q = _sympify_expr(q)
  #|    var = _sympify_expr(var) if var is not None else None
  #|    gens = _coerce_gens(gens)
  #|    if gens is None:
  #|        gens = _default_gens(p, q, var)
  #|    if gens and (domain is not None or modulus is not None):
  #|        pa = _poly(p, gens, domain, modulus)
  #|        pb = _poly(q, gens, domain, modulus)
  #|        if var is None:
  #|            return pa.resultant(pb)
  #|        return pa.resultant(pb, var=var)
  #|    if var is None:
  #|        if gens:
  #|            var = gens[0]
  #|        else:
  #|            raise ValueError("resultant requires a variable")
  #|    if modulus is None:
  #|        return sp.resultant(p, q, var)
  #|    return sp.resultant(p, q, var, modulus=modulus)
  #|
  #|def polys_groebner_json(exprs, gens=None, order="lex", domain=None, modulus=None):
  #|    polys = [_sympify_expr(e) for e in exprs]
  #|    gens = _coerce_gens(gens)
  #|    if gens is None:
  #|        gens = _default_gens(*polys)
  #|    g = sp.groebner(polys, *gens, order=order, domain=domain, modulus=modulus)
  #|    return list(g.polys)
  #|
  #|def polys_factor_json(expr, gens=None, domain=None, modulus=None):
  #|    modulus = _coerce_modulus(modulus)
  #|    expr = _sympify_expr(expr)
  #|    if gens is not None or domain is not None or modulus is not None:
  #|        gens = _coerce_gens(gens)
  #|        if gens is None:
  #|            gens = _default_gens(expr)
  #|        poly = _poly(expr, gens, domain, modulus)
  #|        return poly.factor_list()
  #|    if modulus is None:
  #|        return sp.factor_list(expr)
  #|    return sp.factor_list(expr, modulus=modulus)
  #|
  #|def polys_sqf_list_json(expr, gens=None, domain=None, modulus=None):
  #|    modulus = _coerce_modulus(modulus)
  #|    expr = _sympify_expr(expr)
  #|    if gens is not None or domain is not None or modulus is not None:
  #|        gens = _coerce_gens(gens)
  #|        if gens is None:
  #|            gens = _default_gens(expr)
  #|        poly = _poly(expr, gens, domain, modulus)
  #|        return poly.sqf_list()
  #|    return sp.sqf_list(expr)
  #|
  #|def polys_div_json(p, q, gens=None, domain=None, modulus=None):
  #|    modulus = _coerce_modulus(modulus)
  #|    p = _sympify_expr(p)
  #|    q = _sympify_expr(q)
  #|    gens = _coerce_gens(gens)
  #|    if gens is None:
  #|        gens = _default_gens(p, q)
  #|    if gens and (domain is not None or modulus is not None):
  #|        pa = _poly(p, gens, domain, modulus)
  #|        pb = _poly(q, gens, domain, modulus)
  #|        return pa.div(pb)
  #|    return sp.div(p, q)
  #|
  #|def polys_call_json(op, *args, **kwargs):
  #|    op = str(op)
  #|    if op == "gcd":
  #|        return polys_gcd_json(*args, **kwargs)
  #|    if op == "resultant":
  #|        return polys_resultant_json(*args, **kwargs)
  #|    if op == "groebner":
  #|        return polys_groebner_json(*args, **kwargs)
  #|    if op == "factor":
  #|        return polys_factor_json(*args, **kwargs)
  #|    if op == "sqf":
  #|        return polys_sqf_list_json(*args, **kwargs)
  #|    if op == "div":
  #|        return polys_div_json(*args, **kwargs)
  #|    raise ValueError(f"unknown polys op: {op}")
  #|
  #|def _decode_arg(val):
  #|    if isinstance(val, list):
  #|        return [_decode_arg(v) for v in val]
  #|    if isinstance(val, dict):
  #|        return {k: _decode_arg(v) for k, v in val.items()}
  #|    return val
  #|
  #|
  #|def _encode_result(val):
  #|    if val is None or isinstance(val, (bool, int, float, str)):
  #|        return val
  #|    if isinstance(val, (list, tuple)):
  #|        return [_encode_result(v) for v in val]
  #|    if isinstance(val, dict):
  #|        return {str(k): _encode_result(v) for k, v in val.items()}
  #|    if isinstance(val, sp.Poly):
  #|        return {
  #|            "__sympy__": True,
  #|            "str": str(val.as_expr()),
  #|            "srepr": sp.srepr(val.as_expr()),
  #|        }
  #|    if isinstance(val, sp.Basic):
  #|        return {
  #|            "__sympy__": True,
  #|            "str": str(val),
  #|            "srepr": sp.srepr(val),
  #|        }
  #|    return {"__repr__": repr(val)}
  #|
  #|
  #|def dispatch_json(payload_json: str) -> str:
  #|    try:
  #|        data = json.loads(payload_json)
  #|        func = globals()[data["func"]]
  #|        args = [_decode_arg(a) for a in data.get("args", [])]
  #|        kwargs = {k: _decode_arg(v) for k, v in data.get("kwargs", {}).items()}
  #|        res = func(*args, **kwargs)
  #|        return json.dumps({"ok": True, "value": _encode_result(res)})
  #|    except Exception as exc:  # pylint: disable=broad-except
  #|        return json.dumps({"ok": False, "error": str(exc), "type": type(exc).__name__})
  #|
