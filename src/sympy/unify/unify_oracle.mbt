///|
fn exec_result_str(script : String) -> String raise {
  @runtime.eval_str("unify.exec_result_str", script)
}

///|
pub fn core_parity_summary() -> String raise {
  let script = "from sympy.unify.core import Compound, Variable, CondVariable, allcombinations\n" +
    "from sympy.unify import core\n" +
    "a, b, c = 'a', 'b', 'c'\n" +
    "w, x, y, z = map(Variable, 'wxyz')\n" +
    "C = Compound\n" +
    "def is_associative(term):\n" +
    "    return isinstance(term, Compound) and (term.op in ('Add', 'Mul', 'CAdd', 'CMul'))\n" +
    "def is_commutative(term):\n" +
    "    return isinstance(term, Compound) and (term.op in ('CAdd', 'CMul'))\n" +
    "def unify(lhs, rhs, subst=None):\n" +
    "    if subst is None:\n" +
    "        subst = {}\n" +
    "    return list(core.unify(lhs, rhs, s=subst, is_associative=is_associative, is_commutative=is_commutative))\n" +
    "def render_term(term):\n" +
    "    if isinstance(term, Compound):\n" +
    "        return f'{term.op}[' + ', '.join(render_term(arg) for arg in term.args) + ']'\n" +
    "    if isinstance(term, Variable):\n" +
    "        return f'Variable({term.arg})'\n" +
    "    if isinstance(term, CondVariable):\n" +
    "        return f'CondVariable({term.arg})'\n" +
    "    if isinstance(term, tuple):\n" +
    "        return '(' + ', '.join(render_term(item) for item in term) + ')'\n" +
    "    return str(term)\n" +
    "def render_subst(subst):\n" +
    "    return '{' + ', '.join(sorted(f'{render_term(k)}: {render_term(v)}' for k, v in subst.items())) + '}'\n" +
    "def render_substs(items):\n" +
    "    return '[' + ', '.join(sorted(render_subst(item) for item in items)) + ']'\n" +
    "even = CondVariable('y', lambda a: a % 2 == 0)\n" +
    "__result__ = '\\n'.join([\n" +
    "    render_substs(unify(a, x)),\n" +
    "    render_substs(unify(a, x, {x: 10})),\n" +
    "    render_substs(unify(C('Add', (a, b, c)), C('Add', (a, x, y)))),\n" +
    "    render_substs(unify(C('Add', (1, 2, 3)), C('Add', (x, y)))),\n" +
    "    str(len(unify(C('CAdd', (1, 2, 3)), C('CAdd', (x, y))))),\n" +
    "    render_substs(unify(C('CAdd', (1, 2)), C('CAdd', (x, even)))),\n" +
    "    str(len(list(allcombinations((1, 2), (1, 2), 'commutative')))),\n" +
    "])\n"
  exec_result_str(script)
}

///|
pub fn usympy_parity_summary() -> String raise {
  let script = "from sympy.core.add import Add\n" +
    "from sympy.core.basic import Basic\n" +
    "from sympy.core.singleton import S\n" +
    "from sympy.core.symbol import Symbol, Str\n" +
    "from sympy.logic.boolalg import And\n" +
    "from sympy.matrices.expressions.matexpr import MatrixSymbol\n" +
    "from sympy.sets.sets import FiniteSet\n" +
    "from sympy.unify.core import Compound, Variable, CondVariable\n" +
    "from sympy.unify.usympy import deconstruct, construct, unify\n" +
    "from sympy.abc import x, y, z, n\n" +
    "def render_term(term):\n" +
    "    if isinstance(term, Compound):\n" +
    "        name = term.op.__name__\n" +
    "        label = name if name in ('Add', 'Mul', 'Pow', 'Number', 'Symbol') else f'Function({name})'\n" +
    "        return label + '[' + ', '.join(render_term(arg) for arg in term.args) + ']'\n" +
    "    if isinstance(term, Variable):\n" +
    "        return f'Variable({term.arg})'\n" +
    "    if isinstance(term, CondVariable):\n" +
    "        return f'CondVariable({term.arg})'\n" +
    "    if isinstance(term, tuple):\n" +
    "        return '(' + ', '.join(render_term(item) for item in term) + ')'\n" +
    "    return str(term)\n" +
    "def render_subst(subst):\n" +
    "    return '{' + ', '.join(sorted(f'{k}: {v}' for k, v in subst.items())) + '}'\n" +
    "def render_substs(items):\n" +
    "    return '[' + ', '.join(sorted(render_subst(item) for item in items)) + ']'\n" +
    "expr = Basic(S(1), S(2), S(3))\n" +
    "a, b, c = map(Symbol, 'abc')\n" +
    "p, q = map(Symbol, 'pq')\n" +
    "X = MatrixSymbol('X', n, n)\n" +
    "Y = MatrixSymbol('Y', 2, 2)\n" +
    "__result__ = '\\n'.join([\n" +
    "    render_term(deconstruct(expr)),\n" +
    "    str(construct(deconstruct(Basic(S(1), Basic(S(2)), S(3))))),\n" +
    "    render_substs(list(unify(expr, Basic(a, b, c), variables=(a, b, c)))),\n" +
    "    str(len(list(unify(Add(1, 2, 3, evaluate=False), Add(p, q, evaluate=False), variables=(p, q))))),\n" +
    "    render_substs(list(unify(X, Y, variables=[n, Str('X')]))),\n" +
    "    str(len(list(unify(FiniteSet(a, b, c), FiniteSet(x, y), variables=(x, y)))) > 0),\n" +
    "    render_substs(list(unify((z > 0) & (n < 3), And(x, y), variables=(x, y)))),\n" +
    "])\n"
  exec_result_str(script)
}

///|
pub fn rewrite_parity_summary() -> String raise {
  let script = "from sympy.assumptions import Q\n" +
    "from sympy.core.basic import Basic\n" +
    "from sympy.core.singleton import S\n" +
    "from sympy.core.symbol import Symbol\n" +
    "from sympy.unify.rewrite import rewriterule\n" +
    "from sympy.abc import x, y\n" +
    "p, q = Symbol('p'), Symbol('q')\n" +
    "a, b = map(Symbol, 'ab')\n" +
    "def render(items):\n" +
    "    return '[' + ', '.join(str(item) for item in items) + ']'\n" +
    "__result__ = '\\n'.join([\n" +
    "    render(list(rewriterule(Basic(p, S(1)), Basic(p, S(2)), variables=(p,))(Basic(S(3), S(1))))),\n" +
    "    render(list(rewriterule(p**2, p**3, variables=(p,))(x**2))),\n" +
    "    render(list(rewriterule(p**2 + q**3, (p*q)**4, (p, q))(x**2 + y**3))),\n" +
    "    render(list(rewriterule(x, x + 1, [x], lambda value: value < 10)(S(5)))),\n" +
    "    render(list(rewriterule(x + y, x**y, [x, y], assume=Q.integer(x))(a + b, Q.integer(b)))),\n" +
    "])\n"
  exec_result_str(script)
}
