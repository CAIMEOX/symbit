import json
import sympy as sp

def _fmt_mod(poly, modulus):
    p = sp.Poly(poly, modulus=modulus)
    expr = 0
    for mon, coeff in p.terms():
        c = int(coeff) % modulus
        term = c
        for g, e in zip(p.gens, mon):
            term *= g ** e
        expr += term
    return str(sp.expand(expr))

def factor_list_str(expr_str: str, modulus=None) -> str:
    if isinstance(modulus, str):
        modulus = int(modulus)
    expr = sp.sympify(expr_str)
    if modulus is None:
        content, factors = sp.factor_list(expr)
    else:
        content, factors = sp.factor_list(expr, modulus=modulus)
    # sort factors deterministically by string form
    def _fmt(poly):
        if modulus is None:
            return str(sp.Poly(poly).as_expr())
        return _fmt_mod(poly, modulus)
    factors = sorted(factors, key=lambda p: (sp.srepr(p[0]), p[1]))
    factors_str = ",".join(f"({_fmt(p)}, {m})" for p, m in factors if p != 1)
    return f"({content}, [{factors_str}])"

def gcd_str(a_str: str, b_str: str) -> str:
    a = sp.sympify(a_str)
    b = sp.sympify(b_str)
    syms = sorted(a.free_symbols | b.free_symbols, key=lambda s: s.name)
    if syms:
        pa = sp.Poly(a, *syms)
        pb = sp.Poly(b, *syms)
        return str(pa.gcd(pb).as_expr())
    return str(sp.gcd(a, b))

def resultant_str(p_str: str, q_str: str, var_str: str) -> str:
    p = sp.sympify(p_str)
    q = sp.sympify(q_str)
    v = sp.sympify(var_str)
    return str(sp.resultant(p, q, v))

def groebner_str(exprs, order="lex") -> str:
    polys = [sp.sympify(e) for e in exprs]
    symbols = sorted({s for p in polys for s in p.free_symbols}, key=lambda s: s.name)
    g = sp.groebner(polys, *symbols, order=order)
    basis = [str(p.monic().as_expr()) for p in g.polys]
    basis.sort()
    return " | ".join(basis)

def sqf_list_str(expr_str: str, modulus=None) -> str:
    if isinstance(modulus, str):
        modulus = int(modulus)
    expr = sp.sympify(expr_str)
    if modulus is None:
        content, factors = sp.sqf_list(expr)
    else:
        poly = sp.Poly(expr, modulus=modulus)
        content, factors = poly.sqf_list()
    def _fmt(poly):
        if isinstance(poly, sp.Poly):
            if modulus is None:
                return str(poly.as_expr())
            return _fmt_mod(poly.as_expr(), modulus)
        if modulus is None:
            return str(sp.Poly(poly).as_expr())
        return _fmt_mod(poly, modulus)
    factors = sorted(factors, key=lambda p: (sp.srepr(p[0]), p[1]))
    factors_str = ",".join(f"({_fmt(p)}, {m})" for p, m in factors if p != 1)
    return f"({content}, [{factors_str}])"

def sqf_part_str(expr_str: str) -> str:
    expr = sp.sympify(expr_str)
    part = sp.Poly(expr).sqf_part()
    return str(part.as_expr())

def expr_equal(lhs: str, rhs: str) -> str:
    a = sp.sympify(lhs)
    b = sp.sympify(rhs)
    return str(bool(sp.simplify(a - b) == 0))

def normalize_expr_str(expr_str: str) -> str:
    expr = sp.sympify(expr_str)
    return str(expr)

def factor_list_json(expr_str: str, modulus=None):
    if isinstance(modulus, str):
        modulus = int(modulus)
    expr = sp.sympify(expr_str)
    if modulus is None:
        return sp.factor_list(expr)
    return sp.factor_list(expr, modulus=modulus)

def sympify_list_json(exprs):
    return [sp.sympify(s) for s in exprs]

def monic_expr_str(expr_str: str, modulus=None) -> str:
    if isinstance(modulus, str):
        modulus = int(modulus)
    expr = sp.sympify(expr_str)
    if modulus is None:
        return str(sp.Poly(expr).monic().as_expr())
    return str(sp.Poly(expr, modulus=modulus).monic().as_expr())

def div_str(p_str: str, q_str: str) -> str:
    p = sp.sympify(p_str)
    q = sp.sympify(q_str)
    quo, rem = sp.div(p, q)
    return f"{quo}||{rem}"

def echo_args(*args) -> str:
    return "|".join(str(a) for a in args)


# Normalize a factor_list-style string "(content, [(factor, exp), ...])"
# by making factors monic and sorting by srepr, so MoonBit results can be
# compared against SymPy's canonical order/units.
def normalize_factor_list_repr(repr_str: str, modulus=None) -> str:
    if isinstance(modulus, str):
        modulus = int(modulus)
    content, factors = sp.sympify(repr_str)
    normed = []
    for expr, mult in factors:
        poly = sp.Poly(expr, modulus=modulus) if modulus is not None else sp.Poly(expr)
        expr_norm = poly.monic().as_expr()
        normed.append((expr_norm, mult))
    normed = sorted(normed, key=lambda p: (sp.srepr(p[0]), p[1]))
    factors_str = ",".join(f"({str(p)}, {m})" for p, m in normed)
    return f"({content}, [{factors_str}])"

def sort_factor_repr(repr_str: str) -> str:
    content, factors = sp.sympify(repr_str)
    factors = sorted(factors, key=lambda p: (sp.srepr(p[0]), p[1]))
    factors_str = ",".join(f"({str(p)}, {m})" for p, m in factors)
    return f"({content}, [{factors_str}])"

def echo_int(n: int) -> str:
    if isinstance(n, str):
        n = int(n)
    return str(n)


def _decode_arg(val):
    if isinstance(val, list):
        return [_decode_arg(v) for v in val]
    if isinstance(val, dict):
        return {k: _decode_arg(v) for k, v in val.items()}
    return val


def _encode_result(val):
    if val is None or isinstance(val, (bool, int, float, str)):
        return val
    if isinstance(val, (list, tuple)):
        return [_encode_result(v) for v in val]
    if isinstance(val, dict):
        return {str(k): _encode_result(v) for k, v in val.items()}
    if isinstance(val, sp.Poly):
        return {
            "__sympy__": True,
            "str": str(val.as_expr()),
            "srepr": sp.srepr(val.as_expr()),
        }
    if isinstance(val, sp.Basic):
        return {
            "__sympy__": True,
            "str": str(val),
            "srepr": sp.srepr(val),
        }
    return {"__repr__": repr(val)}


def dispatch_json(payload_json: str) -> str:
    try:
        data = json.loads(payload_json)
        func = getattr(__import__(__name__), data["func"])
        args = [_decode_arg(a) for a in data.get("args", [])]
        kwargs = {k: _decode_arg(v) for k, v in data.get("kwargs", {}).items()}
        res = func(*args, **kwargs)
        return json.dumps({"ok": True, "value": _encode_result(res)})
    except Exception as exc:  # pylint: disable=broad-except
        return json.dumps({"ok": False, "error": str(exc), "type": type(exc).__name__})
