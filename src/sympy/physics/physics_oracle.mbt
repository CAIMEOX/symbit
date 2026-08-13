///|
fn quantum_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.quantum import *\n",
    "from sympy.physics.quantum.qexpr import QExpr\n", "from sympy.physics.quantum.identitysearch import generate_gate_rules, generate_equivalent_ids, GateIdentity, bfs_identity_search, random_identity_search, is_scalar_sparse_matrix, is_scalar_nonsparse_matrix, is_degenerate, is_reducible\n",
    "from sympy.physics.quantum.state import Ket, Bra, TimeDepKet, TimeDepBra, OrthogonalKet, OrthogonalBra, Wavefunction\n",
    "from sympy.physics.quantum.operator import Operator, HermitianOperator, UnitaryOperator, IdentityOperator, OuterProduct, DifferentialOperator\n",
    "from sympy.physics.quantum.boson import BosonOp, BosonFockKet, BosonFockBra, BosonCoherentKet, BosonCoherentBra\n",
    "from sympy.physics.quantum.fermion import FermionOp, FermionFockKet, FermionFockBra\n",
    "from sympy.physics.quantum.cartesian import XOp, YOp, ZOp, PxOp, XKet, XBra, PxKet, PxBra, PositionKet3D, PositionBra3D\n",
    "from sympy.physics.quantum.operatorset import operators_to_state, state_to_operators\n",
    "from sympy.physics.quantum.piab import PIABHamiltonian, PIABKet, PIABBra, m, L\n",
    "from sympy.physics.quantum.qubit import Qubit, QubitBra, IntQubit, IntQubitBra, measure_all, measure_partial, measure_all_oneshot, measure_partial_oneshot\n",
    "from sympy.physics.quantum.sho1d import RaisingOp, LoweringOp, NumberOp, Hamiltonian, SHOKet, SHOBra\n",
    "from sympy.physics.quantum.gate import IdentityGate, HadamardGate, XGate, YGate, ZGate, PhaseGate, TGate, SwapGate, CNotGate, CNOT, SWAP, H, X, Y, Z, T, S, UGate, CGate, CPHASE, gate_simp, gate_sort\n",
    "from sympy.physics.quantum.spin import Jplus, Jminus, Jx, Jy, Jz, J2, JxKet, JxBra, JyKet, JyBra, JzKet, JzBra, JxKetCoupled, JxBraCoupled, JyKetCoupled, JyBraCoupled, JzKetCoupled, JzBraCoupled, couple, uncouple, Rotation, WignerD\n",
    "from sympy.physics.quantum.pauli import SigmaX, SigmaY, SigmaZ, SigmaMinus, SigmaPlus, SigmaZKet, SigmaZBra, qsimplify_pauli\n",
    "from sympy.physics.quantum.qft import QFT, IQFT, RkGate, Rk\n", "from sympy.physics.quantum.shor import ratioize, getr\n",
    "from sympy.physics.quantum.qasm import Qasm, flip_index, trim, get_index, get_indices, fixcommand, stripquotes\n",
    "from sympy.physics.quantum.circuitplot import CircuitPlot, render_label, labeller, Mz, Mx, CreateOneQubitGate, CreateCGate\n",
    "from sympy.physics.quantum.density import Density, entropy, fidelity\n", "from sympy.physics.quantum.matrixcache import matrix_cache\n",
    "from sympy.physics.quantum.circuitutils import kmp_table, find_subcircuit, replace_subcircuit, convert_to_symbolic_indices, convert_to_real_indices, random_reduce, random_insert\n",
    "from sympy.physics.quantum.grover import OracleGate, WGate, superposition_basis, grover_iteration, apply_grover\n",
    "from sympy.physics.quantum.represent import represent, rep_innerproduct, rep_expectation, get_basis, enumerate_states, integrate_result\n",
    "from sympy.physics.quantum.trace import Tr\n", "from sympy.physics.quantum.commutator import Commutator\n",
    "from sympy.physics.quantum.anticommutator import AntiCommutator\n", "a, b, c, d, f, n, u, v, x, y, z = symbols('a b c d f n u v x y z', commutative=True)\n",
    "alpha, beta, gamma, theta, phi = symbols('alpha beta gamma theta phi', commutative=True)\n",
    "A, B, C, D, X, Y, Z = symbols('A B C D X Y Z', commutative=False)\n", "wf = Function('wf')\n",
    "def grover_oracle_from_marks(nqubits, marks):\n", "    return OracleGate(nqubits, lambda qubits: any(qubits == IntQubit(idx, nqubits=nqubits) for idx in marks))\n",
  ].join("")
}

///|
pub fn quantum_eval_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()))\n",
    ].join(""),
  )
}

///|
pub fn quantum_srepr_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(srepr(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn quantum_doit_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).doit())\n",
    ].join(""),
  )
}

///|
pub fn quantum_decompose_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).decompose())\n",
    ].join(""),
  )
}

///|
pub fn quantum_qapply_str(
  expr : String,
  dagger? : Bool = false,
  ip_doit? : Bool = true,
  sum_doit? : Bool = false,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(qapply(sympify(",
      python_string_literal(expr),
      ", locals=locals()), dagger=",
      if dagger {
        "True"
      } else {
        "False"
      },
      ", ip_doit=",
      if ip_doit {
        "True"
      } else {
        "False"
      },
      ", sum_doit=",
      if sum_doit {
        "True"
      } else {
        "False"
      },
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qapply_srepr(
  expr : String,
  dagger? : Bool = false,
  ip_doit? : Bool = true,
  sum_doit? : Bool = false,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(srepr(qapply(sympify(",
      python_string_literal(expr),
      ", locals=locals()), dagger=",
      if dagger {
        "True"
      } else {
        "False"
      },
      ", ip_doit=",
      if ip_doit {
        "True"
      } else {
        "False"
      },
      ", sum_doit=",
      if sum_doit {
        "True"
      } else {
        "False"
      },
      ")))\n",
    ].join(""),
  )
}

///|
fn python_int_tuple(items : Array[Int]) -> String {
  if items.length() == 1 {
    "(" + items[0].to_string() + ",)"
  } else {
    "(" + items.map(item => item.to_string()).join(", ") + ")"
  }
}

///|
fn python_string_list_literal(items : Array[String]) -> String {
  "[" + items.map(python_string_literal).join(", ") + "]"
}

///|
pub fn quantum_measure_all_oneshot_str(
  expr : String,
  sample : Double,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "import random\n",
      "_old_random = random.random\n",
      "random.random = lambda: ",
      sample.to_string(),
      "\n",
      "try:\n",
      "    print(measure_all_oneshot(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
      "finally:\n",
      "    random.random = _old_random\n",
    ].join(""),
  )
}

///|
pub fn quantum_measure_partial_oneshot_str(
  expr : String,
  bits : Array[Int],
  sample : Double,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "import random\n",
      "_old_random = random.random\n",
      "random.random = lambda: ",
      sample.to_string(),
      "\n",
      "try:\n",
      "    print(measure_partial_oneshot(sympify(",
      python_string_literal(expr),
      ", locals=locals()), ",
      python_int_tuple(bits),
      "))\n",
      "finally:\n",
      "    random.random = _old_random\n",
    ].join(""),
  )
}

///|
pub fn quantum_hadamard_normalized_qapply(
  normalize : Bool,
  expr : String,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "from sympy.physics.quantum.gate import normalized\n",
      "_old = True\n",
      "normalized(",
      if normalize {
        "True"
      } else {
        "False"
      },
      ")\n",
      "try:\n",
      "    print(qapply(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
      "finally:\n",
      "    normalized(True)\n",
    ].join(""),
  )
}

///|
pub fn quantum_shor_ratioize(items : Array[Int], n : Int) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(ratioize(",
      python_int_tuple(items),
      ", ",
      n.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_shor_getr(x : Int, y : Int, n : Int) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(getr(",
      x.to_string(),
      ", ",
      y.to_string(),
      ", ",
      n.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_fixcommand(command : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(fixcommand(",
      python_string_literal(command),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_stripquotes(text : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(stripquotes(",
      python_string_literal(text),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_trim(text : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(trim(",
      python_string_literal(text),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_index(
  target : String,
  labels : Array[String],
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(get_index(",
      python_string_literal(target),
      ", ",
      python_string_list_literal(labels),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_indices(
  targets : Array[String],
  labels : Array[String],
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(chr(31).join(str(v) for v in get_indices(",
      python_string_list_literal(targets),
      ", ",
      python_string_list_literal(labels),
      ")))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_owned())
  }
}

///|
pub fn quantum_render_label(
  label : String,
  init? : String? = None,
) -> String raise {
  let init_code = match init {
    Some(value) =>
      "{" +
      python_string_literal(label) +
      ": " +
      python_string_literal(value) +
      "}"
    None => "{}"
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(render_label(",
      python_string_literal(label),
      ", ",
      init_code,
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_labeller(n : Int, symbol? : String = "q") -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(chr(31).join(labeller(",
      n.to_string(),
      ", ",
      python_string_literal(symbol),
      ")))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_owned())
  }
}

///|
pub fn quantum_create_one_qubit_gate_str(
  name : String,
  target : Int,
  latexname? : String? = None,
) -> String raise {
  let latex_code = match latexname {
    Some(value) => ", " + python_string_literal(value)
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(CreateOneQubitGate(",
      python_string_literal(name),
      latex_code,
      ")(",
      target.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_create_cgate_str(
  name : String,
  controls : Array[Int],
  target : Int,
  latexname? : String? = None,
) -> String raise {
  let latex_code = match latexname {
    Some(value) => ", " + python_string_literal(value)
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(CreateCGate(",
      python_string_literal(name),
      latex_code,
      ")(",
      python_int_tuple(controls),
      ", ",
      target.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_circuitplot_summary(
  expr : String,
  nqubits : Int,
  labels? : Array[String] = [],
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "plot = CircuitPlot(sympify(",
      python_string_literal(expr),
      ", locals=locals()), ",
      nqubits.to_string(),
      ", labels=",
      python_string_list_literal(labels),
      ")\n",
      "_meas = plot._measurements()\n",
      "_mkeys = sorted(_meas)\n",
      "_ms = '-' if not _mkeys else ','.join(f'{k}:{_meas[k]}' for k in _mkeys)\n",
      "print('ngates=' + str(plot.ngates) + ';nqubits=' + str(plot.nqubits) + ';gate_count=' + str(len(plot._gates())) + ';measurements=' + _ms + ';labels=' + ','.join(plot.labels))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_circuit(lines : Array[String]) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(Qasm(*",
      python_string_list_literal(lines),
      ").get_circuit())\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_labels(lines : Array[String]) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(chr(31).join(Qasm(*",
      python_string_list_literal(lines),
      ").get_labels()))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_owned())
  }
}

///|
pub fn quantum_represent_str(
  expr : String,
  basis? : String? = None,
) -> String raise {
  let basis_code = match basis {
    Some(value) => ", basis=" + value
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(represent(sympify(",
      python_string_literal(expr),
      ", locals=locals())",
      basis_code,
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_represent_matrix(
  expr : String,
  basis : String,
  ndim : Int,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "mat = represent(sympify(",
      python_string_literal(expr),
      ", locals=locals()), basis=sympify(",
      python_string_literal(basis),
      ", locals=locals()), ndim=",
      ndim.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    if isinstance(row, (list, tuple)):\n",
      "        for item in row:\n",
      "            print(item)\n",
      "    else:\n",
      "        print(row)\n",
    ].join(""),
  )
  txt.split("\n").map(StringView::to_owned).filter(line => line != "").collect()
}

///|
pub fn quantum_get_basis_str(
  expr : String,
  basis? : String? = None,
) -> String raise {
  let basis_code = match basis {
    Some(value) =>
      ", basis=sympify(" + python_string_literal(value) + ", locals=locals())"
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(get_basis(sympify(",
      python_string_literal(expr),
      ", locals=locals())",
      basis_code,
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_enumerate_states_str(
  expr : String,
  start_index : Int,
  count : Int,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "states = enumerate_states(sympify(",
      python_string_literal(expr),
      ", locals=locals()), ",
      start_index.to_string(),
      ", ",
      count.to_string(),
      ")\n",
      "print('[' + ', '.join(str(item) for item in states) + ']')\n",
    ].join(""),
  )
}

///|
pub fn quantum_rep_innerproduct_str(
  expr : String,
  basis? : String? = None,
) -> String raise {
  let basis_code = match basis {
    Some(value) =>
      ", basis=sympify(" + python_string_literal(value) + ", locals=locals())"
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(rep_innerproduct(sympify(",
      python_string_literal(expr),
      ", locals=locals())",
      basis_code,
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_rep_expectation_str(
  expr : String,
  basis? : String? = None,
) -> String raise {
  let basis_code = match basis {
    Some(value) =>
      ", basis=sympify(" + python_string_literal(value) + ", locals=locals())"
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(rep_expectation(sympify(",
      python_string_literal(expr),
      ", locals=locals())",
      basis_code,
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_integrate_result_str(
  orig_expr : String,
  result_expr : String,
  basis? : String? = None,
  unities? : Array[Int] = [],
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "kwargs = {'unities': ",
      python_int_tuple(unities),
      "}\n",
      match basis {
        Some(value) =>
          "kwargs['basis'] = sympify(" +
          python_string_literal(value) +
          ", locals=locals())\n"
        None => ""
      },
      "print(integrate_result(sympify(",
      python_string_literal(orig_expr),
      ", locals=locals()), sympify(",
      python_string_literal(result_expr),
      ", locals=locals()), **kwargs))\n",
    ].join(""),
  )
}

///|
pub fn quantum_identitysearch_rules_summary(
  gates : Array[String],
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "_seq = [sympify(item, locals=locals()) for item in ",
      python_string_list_literal(gates),
      "]\n",
      "_rules = generate_gate_rules(tuple(_seq))\n",
      "def _fmt_side(side):\n",
      "    return str(Mul(*side)) if len(side) else '1'\n",
      "print(chr(31).join(sorted(_fmt_side(l) + ' == ' + _fmt_side(r) for l, r in _rules)))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(StringView::to_owned)
  }
}

///|
pub fn quantum_identitysearch_equivalent_ids(
  gates : Array[String],
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "_seq = [sympify(item, locals=locals()) for item in ",
      python_string_list_literal(gates),
      "]\n",
      "_ids = generate_equivalent_ids(tuple(_seq))\n",
      "print(chr(31).join(sorted(str(Mul(*item)) if isinstance(item, tuple) else str(item) for item in _ids)))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(StringView::to_owned)
  }
}

///|
pub fn quantum_identitysearch_bfs_summary(
  gates : Array[String],
  nqubits : Int,
  max_depth : Int,
  identity_only : Bool,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "_gates = [sympify(item, locals=locals()) for item in ",
      python_string_list_literal(gates),
      "]\n",
      "_ids = bfs_identity_search(_gates, ",
      nqubits.to_string(),
      ", max_depth=",
      max_depth.to_string(),
      ", identity_only=",
      if identity_only {
        "True"
      } else {
        "False"
      },
      ")\n",
      "print(chr(31).join(sorted(str(item.circuit) for item in _ids)))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(StringView::to_owned)
  }
}

///|
pub fn quantum_identitysearch_is_scalar(
  gates : Array[String],
  nqubits : Int,
  identity_only : Bool,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "_seq = [sympify(item, locals=locals()) for item in ",
      python_string_list_literal(gates),
      "]\n",
      "print(is_scalar_nonsparse_matrix(Mul(*_seq), ",
      nqubits.to_string(),
      ", ",
      if identity_only {
        "True"
      } else {
        "False"
      },
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_matrixcache_matrix(name : String) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "mat = matrix_cache.get_matrix(",
      python_string_literal(name),
      ", 'sympy')\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt.split("\n").map(StringView::to_owned).filter(line => line != "").collect()
}

///|
pub fn quantum_circuitutils_kmp_table(expr : String) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "word = sympify(",
      python_string_literal(expr),
      ", locals=locals())\n",
      "if isinstance(word, Mul):\n",
      "    word = word.args\n",
      "elif word == 1:\n",
      "    word = ()\n",
      "else:\n",
      "    word = (word,)\n",
      "print(chr(31).join(str(v) for v in kmp_table(word)))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_owned())
  }
}

///|
pub fn quantum_circuitutils_find_subcircuit(
  circuit : String,
  subcircuit : String,
  start? : Int = 0,
  end? : Int = 0,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(find_subcircuit(sympify(",
      python_string_literal(circuit),
      ", locals=locals()), sympify(",
      python_string_literal(subcircuit),
      ", locals=locals()), start=",
      start.to_string(),
      ", end=",
      end.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_circuitutils_replace_subcircuit(
  circuit : String,
  subcircuit : String,
  replace? : String? = None,
  pos? : Int = 0,
) -> String raise {
  let replace_code = match replace {
    Some(expr) =>
      "sympify(" + python_string_literal(expr) + ", locals=locals())"
    None => "None"
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "out = replace_subcircuit(sympify(",
      python_string_literal(circuit),
      ", locals=locals()), sympify(",
      python_string_literal(subcircuit),
      ", locals=locals()), replace=",
      replace_code,
      ", pos=",
      pos.to_string(),
      ")\n",
      "print(srepr(Mul(*out)))\n",
    ].join(""),
  )
}

///|
pub fn quantum_circuitutils_convert_to_symbolic(
  expr : String,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "seq = sympify(",
      python_string_literal(expr),
      ", locals=locals())\n",
      "out, mapping, _, _ = convert_to_symbolic_indices(seq)\n",
      "print(srepr(Mul(*out)))\n",
      "for key in sorted(mapping, key=str):\n",
      "    print(f\"{key}={mapping[key]}\")\n",
    ].join(""),
  )
  txt.split("\n").map(StringView::to_owned).filter(line => line != "").collect()
}

///|
pub fn quantum_circuitutils_convert_to_real(
  expr : String,
  mapping_code : String,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "out = convert_to_real_indices(sympify(",
      python_string_literal(expr),
      ", locals=locals()), sympify(",
      python_string_literal(mapping_code),
      ", locals=locals()))\n",
      "print(srepr(Mul(*out)))\n",
    ].join(""),
  )
}

///|
fn grover_marks_literal(marks : Array[Int]) -> String {
  "[" + marks.map(value => value.to_string()).join(", ") + "]"
}

///|
pub fn quantum_grover_superposition_matrix(
  nqubits : Int,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "mat = represent(superposition_basis(",
      nqubits.to_string(),
      "), nqubits=",
      nqubits.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt.split("\n").map(StringView::to_owned).filter(line => line != "").collect()
}

///|
pub fn quantum_grover_oracle_matrix(
  nqubits : Int,
  marks : Array[Int],
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "mat = represent(grover_oracle_from_marks(",
      nqubits.to_string(),
      ", ",
      grover_marks_literal(marks),
      "), nqubits=",
      nqubits.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt.split("\n").map(StringView::to_owned).filter(line => line != "").collect()
}

///|
pub fn quantum_grover_w_matrix(nqubits : Int) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "from sympy import Matrix\n",
      "cols = []\n",
      "for idx in range(2**",
      nqubits.to_string(),
      "):\n",
      "    state = IntQubit(idx, nqubits=",
      nqubits.to_string(),
      ")\n",
      "    cols.append(represent(qapply(WGate(",
      nqubits.to_string(),
      ")*state), nqubits=",
      nqubits.to_string(),
      "))\n",
      "mat = Matrix.hstack(*cols)\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt.split("\n").map(StringView::to_owned).filter(line => line != "").collect()
}

///|
pub fn quantum_grover_oracle_state_matrix(
  nqubits : Int,
  marks : Array[Int],
  state : Int,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "op = grover_oracle_from_marks(",
      nqubits.to_string(),
      ", ",
      grover_marks_literal(marks),
      ")\n",
      "state = IntQubit(",
      state.to_string(),
      ", nqubits=",
      nqubits.to_string(),
      ")\n",
      "mat = represent(qapply(op*state), nqubits=",
      nqubits.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt.split("\n").map(StringView::to_owned).filter(line => line != "").collect()
}

///|
pub fn quantum_grover_w_state_matrix(
  nqubits : Int,
  state : Int,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "state = IntQubit(",
      state.to_string(),
      ", nqubits=",
      nqubits.to_string(),
      ")\n",
      "mat = represent(qapply(WGate(",
      nqubits.to_string(),
      ")*state), nqubits=",
      nqubits.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt.split("\n").map(StringView::to_owned).filter(line => line != "").collect()
}

///|
pub fn quantum_grover_apply_matrix(
  nqubits : Int,
  marks : Array[Int],
  iterations : Int,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "oracle = lambda qubits: any(qubits == IntQubit(idx, nqubits=",
      nqubits.to_string(),
      ") for idx in ",
      grover_marks_literal(marks),
      ")\n",
      "mat = represent(qapply(apply_grover(oracle, ",
      nqubits.to_string(),
      ", iterations=",
      iterations.to_string(),
      ")), nqubits=",
      nqubits.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt.split("\n").map(StringView::to_owned).filter(line => line != "").collect()
}

///|
pub fn quantum_kind_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).kind)\n",
    ].join(""),
  )
}

///|
pub fn quantum_density_states_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).states())\n",
    ].join(""),
  )
}

///|
pub fn quantum_density_probs_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).probs())\n",
    ].join(""),
  )
}

///|
pub fn quantum_density_get_state_str(
  expr : String,
  index : Int,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).get_state(",
      index.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_density_get_prob_str(expr : String, index : Int) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).get_prob(",
      index.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_density_apply_op_str(expr : String, op : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "obj = sympify(",
      python_string_literal(expr),
      ", locals=locals())\n",
      "print(obj.apply_op(sympify(",
      python_string_literal(op),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn quantum_entropy_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(entropy(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn quantum_fidelity_str(lhs : String, rhs : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(fidelity(sympify(",
      python_string_literal(lhs),
      ", locals=locals()), sympify(",
      python_string_literal(rhs),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn quantum_expand_commutator_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).expand(commutator=True))\n",
    ].join(""),
  )
}

///|
pub fn quantum_normal_order_str(
  expr : String,
  ordered_form? : Bool = true,
  independent? : Bool = false,
) -> String raise {
  let fn_name = if ordered_form {
    "normal_ordered_form"
  } else {
    "normal_order"
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "from sympy.physics.quantum.operatorordering import normal_order, normal_ordered_form\n",
      "print(",
      fn_name,
      "(sympify(",
      python_string_literal(expr),
      ", locals=locals()), independent=",
      if independent {
        "True"
      } else {
        "False"
      },
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_trace_permute_str(expr : String, pos : Int) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).permute(",
      pos.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn paulialgebra_delta(i : Int, j : Int) -> Int raise {
  physics_int_call("sympy.physics.paulialgebra", "delta", [i, j])
}

///|
pub fn paulialgebra_epsilon(i : Int, j : Int, k : Int) -> Int raise {
  physics_int_call("sympy.physics.paulialgebra", "epsilon", [i, j, k])
}

///|
pub fn paulialgebra_evaluate(expr : String) -> String raise {
  physics_source_pauli(expr, false)
}

///|
pub fn physics_srepr(expr : String) -> String raise {
  physics_source_srepr(expr)
}

///|
pub fn physics_eval_str(expr : String) -> String raise {
  physics_source_eval_str(expr)
}

///|
pub fn physics_expr_str(expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let value = @exprcodec.encode_expr(builder, expr)
  builder.request_str(value)
}

///|
pub fn physics_expr_srepr(expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let value = @exprcodec.encode_expr(builder, expr)
  builder.request_srepr(value)
}

///|
pub fn physics_eval_matrix(expr : String) -> Array[String] raise {
  physics_source_matrix(expr)
}

///|
pub fn optics_polarization_matrix(
  name : String,
  args : Array[@symcore.Expr],
) -> Array[String] raise {
  optics_polarization_matrix_recipe(name, args)
}

///|
fn python_string_literal(value : String) -> String {
  let escaped_backslashes = value.replace_all(old="\\", new="\\\\")
  let escaped_quotes = escaped_backslashes.replace_all(old="'", new="\\'")
  let escaped_newlines = escaped_quotes.replace_all(old="\n", new="\\n")
  let escaped_returns = escaped_newlines.replace_all(old="\r", new="\\r")
  let escaped_tabs = escaped_returns.replace_all(old="\t", new="\\t")
  "'" + escaped_tabs + "'"
}

///|
fn python_script_stdout(script : String) -> String raise {
  let builder = @recipe.Builder::new()
  let builtins = builder.import_module("builtins")
  let scope = builder.dict([(Str("__builtins__"), Ref(builtins))])
  let scope = builder.bind(scope, "__symbit_script__", Str(script))
  let wrapped = [
    "import io\n", "import sys\n", "__symbit_stdout__ = io.StringIO()\n", "__symbit_prev_stdout__ = sys.stdout\n",
    "sys.stdout = __symbit_stdout__\n", "try:\n", "    exec(__symbit_script__, globals(), locals())\n",
    "finally:\n", "    sys.stdout = __symbit_prev_stdout__\n", "__symbit_out__ = __symbit_stdout__.getvalue()\n",
  ].join("")
  let executed = builder.exec(scope, wrapped)
  let output = builder.getitem(executed, Str("__symbit_out__"))
  builder.request_str(output).trim().to_owned()
}

///|
fn secondquant_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.secondquant import *\n",
    "from sympy.physics.quantum.operatorordering import normal_ordered_form\n", "a, b, c, d = symbols('a b c d', above_fermi=True)\n",
    "i, j, k, l, m, n = symbols('i j k l m n', below_fermi=True)\n", "p, q, r, s = symbols('p q r s')\n",
    "v = Symbol('v')\n", "T = Function('T')\n", "f = Function('f')\n", "g = Function('g')\n",
  ].join("")
}

///|
fn continuum_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.continuum_mechanics.beam import Beam\n",
    "from sympy.physics.continuum_mechanics.column import Column\n", "from sympy.physics.continuum_mechanics.cable import Cable\n",
    "from sympy.physics.continuum_mechanics.arch import Arch\n", "x = Symbol('x')\n",
    "y = Symbol('y')\n", "t = Symbol('t')\n", "E = Symbol('E')\n", "I = Symbol('I')\n",
    "A = Symbol('A')\n", "R1, R2 = symbols('R1 R2')\n",
  ].join("")
}

///|
pub fn continuum_exec_stdout(script : String) -> String raise {
  python_script_stdout(continuum_subprocess_prelude() + script)
}

///|
pub fn secondquant_eval_str(expr : String) -> String raise {
  python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()))\n",
    ].join(""),
  )
}

///|
pub fn secondquant_exec_str(expr : String) -> String raise {
  python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "print(eval(",
      python_string_literal(expr),
      ", globals(), locals()))\n",
    ].join(""),
  )
}

///|
pub fn secondquant_apply_str(expr : String) -> String raise {
  python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "print(apply_operators(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn secondquant_normal_order_str(expr : String) -> String raise {
  python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "print(normal_ordered_form(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn secondquant_basis_str(expr : String) -> String raise {
  python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()))\n",
    ].join(""),
  )
}

///|
pub fn secondquant_matrix_rows(
  op_expr : String,
  basis_expr : String,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "m = matrix_rep(sympify(",
      python_string_literal(op_expr),
      ", locals=locals()), sympify(",
      python_string_literal(basis_expr),
      ", locals=locals()))\n",
      "print(chr(31).join('[' + ', '.join(str(c) for c in row) + ']' for row in m.tolist()))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_owned())
  }
}

///|
fn control_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.control.lti import *\n",
    "a, b, c, d, s, p, g, k, tau, zeta, wn, T, z, x, y = symbols('a b c d s p g k tau zeta wn T z x y')\n",
  ].join("")
}

///|
pub fn control_exec_stdout(script : String) -> String raise {
  python_script_stdout(control_subprocess_prelude() + script)
}

///|
fn control_routh_script(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
  command : String,
) -> String {
  let poly_txt = @symprint.pretty_string(polynomial)
  let var_txt = @symprint.pretty_string(variable)
  [
    "import sys\n",
    "from sympy import Symbol, sympify\n",
    "from sympy.physics.control.routh_table import RouthHurwitz\n",
    "var = Symbol(",
    python_string_literal(var_txt),
    ")\n",
    "poly = sympify(",
    python_string_literal(poly_txt),
    ", locals={",
    python_string_literal(var_txt),
    ": var})\n",
    "obj = RouthHurwitz(poly, var)\n",
    command,
  ].join("")
}

///|
pub fn control_routh_table_matrix(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
) -> Array[String] raise {
  let txt = python_script_stdout(
    control_routh_script(
      polynomial, variable, "print(chr(31).join(str(c) for row in obj.tolist() for c in row))",
    ),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_owned())
  }
}

///|
pub fn control_routh_zero_col_infos(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
) -> String raise {
  python_script_stdout(
    control_routh_script(polynomial, variable, "print(obj.zero_col_infos)"),
  )
}

///|
pub fn control_routh_zero_row_case(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
) -> String raise {
  python_script_stdout(
    control_routh_script(polynomial, variable, "print(obj.zero_row_case)"),
  )
}

///|
pub fn control_routh_auxiliary_expr(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
  index : Int,
) -> String raise {
  python_script_stdout(
    control_routh_script(
      polynomial,
      variable,
      "print(obj.auxiliary_polynomials[\{index}].as_expr())",
    ),
  )
}

///|
pub fn control_expr_equivalent(lhs : @symcore.Expr, rhs : String) -> Bool raise {
  let lhs_txt = @symprint.pretty_string(lhs)
  let txt = python_script_stdout(
    [
      "import sys\n",
      "from sympy import N, Symbol, simplify, sympify\n",
      "names = ['z', 'b0', 'b1', 'b2', 'b3', 'b4', 'f', 'u', 'v', 'N', 'c', 'x', 'y', 'n']\n",
      "locals_map = {name: Symbol(name) for name in names}\n",
      "lhs = sympify(",
      python_string_literal(lhs_txt),
      ", locals=locals_map)\n",
      "rhs = sympify(",
      python_string_literal(rhs),
      ", locals=locals_map)\n",
      "diff = simplify(lhs - rhs)\n",
      "if diff == 0:\n",
      "    print(True)\n",
      "elif lhs.free_symbols or rhs.free_symbols:\n",
      "    print(False)\n",
      "else:\n",
      "    try:\n",
      "        print(abs(complex(N(diff, 50))) < 1e-12)\n",
      "    except Exception:\n",
      "        print(False)\n",
    ].join(""),
  )
  txt == "True"
}

///|
pub fn physics_expr_equivalent(lhs : @symcore.Expr, rhs : String) -> Bool raise {
  let lhs_txt = @symprint.pretty_string(lhs)
  let txt = python_script_stdout(
    [
      "import sys\n",
      "from sympy import N, simplify, sympify\n",
      "lhs = sympify(",
      python_string_literal(lhs_txt),
      ")\n",
      "rhs = sympify(",
      python_string_literal(rhs),
      ")\n",
      "diff = simplify(lhs - rhs)\n",
      "if diff == 0:\n",
      "    print(True)\n",
      "elif lhs.free_symbols or rhs.free_symbols:\n",
      "    print(False)\n",
      "else:\n",
      "    try:\n",
      "        print(abs(complex(N(diff, 50))) < 1e-12)\n",
      "    except Exception:\n",
      "        print(False)\n",
    ].join(""),
  )
  txt == "True"
}

///|
pub fn paulialgebra_evaluate_srepr(expr : String) -> String raise {
  physics_source_pauli(expr, true)
}

///|
pub fn optics_medium_property(
  property : String,
  name : String,
  permittivity? : @symcore.Expr? = None,
  permeability? : @symcore.Expr? = None,
  n? : @symcore.Expr? = None,
) -> String raise {
  optics_medium_property_recipe(property, name, permittivity, permeability, n)
}

///|
pub fn optics_utils_eval(expr : String) -> String raise {
  python_script_stdout(
    [
      "from sympy import *\n", "from sympy.physics.optics.utils import *\n", "from sympy.physics.optics.medium import Medium\n",
      "from sympy.physics.units import e0\n", "f, u, v, N, c, n = symbols('f u v N c n')\n",
      "print(", expr, ")\n",
    ].join(""),
  )
}

///|
pub fn optics_waves_eval(expr : String) -> String raise {
  python_script_stdout(
    [
      "from sympy import *\n", "from sympy.physics.optics.waves import TWave\n",
      "from sympy.physics.units import meter, second, speed_of_light\n", "A, A1, A2, phi, phi1, phi2, f, n = symbols('A A1 A2 phi phi1 phi2 f n')\n",
      "print(", expr, ")\n",
    ].join(""),
  )
}

///|
pub fn optics_gaussopt_eval(expr : String) -> String raise {
  python_script_stdout(
    [
      "from sympy import *\n", "from sympy.physics.optics.gaussopt import *\n", "d, f, h, angle, n1, n2, R, w, wavelen, z_r, a, b, s_in, z_r_in, l, w_i, w_o, z, w_0 = symbols('d f h angle n1 n2 R w wavelen z_r a b s_in z_r_in l w_i w_o z w_0')\n",
      "print(", expr, ")\n",
    ].join(""),
  )
}

///|
pub fn optics_gaussopt_matrix(expr : String) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      "from sympy import *\n", "from sympy.physics.optics.gaussopt import *\n", "d, f, h, angle, n1, n2, R, w, wavelen, z_r, a, b, s_in, z_r_in, l, w_i, w_o, z, w_0 = symbols('d f h angle n1 n2 R w wavelen z_r a b s_in z_r_in l w_i w_o z w_0')\n",
      "obj = ", expr, "\n", "print(chr(31).join(str(c) for row in obj.tolist() for c in row))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(StringView::to_owned)
  }
}

///|
fn vector_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.vector import *\n",
    "from sympy.physics.vector.fieldfunctions import *\n", "t = dynamicsymbols._t\n",
    "def _symbit_vector_summary(obj):\n", "    if isinstance(obj, (Vector, Dyadic)):\n",
    "        return vsprint(obj)\n", "    if isinstance(obj, list):\n", "        return '[' + ', '.join(_symbit_vector_summary(x) for x in obj) + ']'\n",
    "    if isinstance(obj, tuple):\n", "        items = ', '.join(_symbit_vector_summary(x) for x in obj)\n",
    "        if len(obj) == 1:\n", "            items += ','\n", "        return '(' + items + ')'\n",
    "    return str(obj)\n",
  ].join("")
}

///|
fn mechanics_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.vector import *\n",
    "from sympy.physics.vector.fieldfunctions import *\n", "from sympy.physics.mechanics import *\n",
    "from sympy.physics.mechanics.functions import *\n", "from sympy.physics.mechanics.loads import *\n",
    "t = dynamicsymbols._t\n", "def _symbit_mechanics_summary(obj):\n", "    if isinstance(obj, (Vector, Dyadic)):\n",
    "        return vsprint(obj)\n", "    if isinstance(obj, (Particle, RigidBody, Body, Inertia, Force, Torque)):\n",
    "        return repr(obj)\n", "    if isinstance(obj, list):\n", "        return '[' + ', '.join(_symbit_mechanics_summary(x) for x in obj) + ']'\n",
    "    if isinstance(obj, tuple):\n", "        items = ', '.join(_symbit_mechanics_summary(x) for x in obj)\n",
    "        if len(obj) == 1:\n", "            items += ','\n", "        return '(' + items + ')'\n",
    "    return str(obj)\n",
  ].join("")
}

///|
fn vector_python_result_script(
  expr : String,
  prefix : String,
  suffix : String,
) -> String {
  let pieces = expr
    .split(";")
    .to_array()
    .map(s => s.trim().to_owned())
    .filter(s => s != "")
  if pieces.is_empty() {
    return [vector_subprocess_prelude(), prefix, "None", suffix, "\n"].join("")
  }
  let body : Array[String] = [vector_subprocess_prelude()]
  for piece in pieces[:pieces.length() - 1] {
    body.push(piece.to_string())
    body.push("\n")
  }
  body.push(prefix)
  body.push(pieces[pieces.length() - 1].to_string())
  body.push(suffix)
  body.push("\n")
  body.join("")
}

///|
fn mechanics_python_result_script(
  expr : String,
  prefix : String,
  suffix : String,
) -> String {
  let pieces = expr
    .split(";")
    .to_array()
    .map(s => s.trim().to_owned())
    .filter(s => s != "")
  if pieces.is_empty() {
    return [mechanics_subprocess_prelude(), prefix, "None", suffix, "\n"].join(
      "",
    )
  }
  let body : Array[String] = [mechanics_subprocess_prelude()]
  for piece in pieces[:pieces.length() - 1] {
    body.push(piece.to_string())
    body.push("\n")
  }
  body.push(prefix)
  body.push(pieces[pieces.length() - 1].to_string())
  body.push(suffix)
  body.push("\n")
  body.join("")
}

///|
pub fn vector_eval(expr : String) -> String raise {
  python_script_stdout(vector_python_result_script(expr, "print(", ")"))
}

///|
pub fn vector_summary(expr : String) -> String raise {
  python_script_stdout(
    vector_python_result_script(expr, "print(_symbit_vector_summary(", "))"),
  )
}

///|
pub fn mechanics_eval(expr : String) -> String raise {
  python_script_stdout(mechanics_python_result_script(expr, "print(", ")"))
}

///|
pub fn mechanics_summary(expr : String) -> String raise {
  python_script_stdout(
    mechanics_python_result_script(
      expr, "print(_symbit_mechanics_summary(", "))",
    ),
  )
}

///|
pub fn mechanics_expr_equal(lhs_expr : String, rhs_expr : String) -> Bool raise {
  let combined = lhs_expr + ";" + rhs_expr
  let body : Array[String] = [
    mechanics_subprocess_prelude(),
    "import re\n",
    "_locals = {'t': t}\n",
    "for _name in set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\\(t\\)', ",
    python_string_literal(combined),
    ")):\n",
    "    _locals[_name] = Function(_name)\n",
    "lhs = sympify(",
    python_string_literal(lhs_expr),
    ", locals=_locals)\n",
    "rhs = sympify(",
    python_string_literal(rhs_expr),
    ", locals=_locals)\n",
    "ok = simplify(expand_func(lhs - rhs)) == 0\n",
    "print(ok)\n",
  ]
  python_script_stdout(body.join("")) == "True"
}

///|
pub fn vector_expr_equal(lhs_expr : String, rhs_expr : String) -> Bool raise {
  let pieces = rhs_expr
    .split(";")
    .to_array()
    .map(s => s.trim().to_owned())
    .filter(s => s != "")
  let body : Array[String] = [
    vector_subprocess_prelude(),
    "import re\n",
    "_locals = {'t': t}\n",
    "for _name in set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\\(t\\)', ",
  ]
  body.push(python_string_literal(lhs_expr))
  body.push(")):\n")
  body.push("    _locals[_name] = Function(_name)\n")
  body.push(
    "for _frame_name in set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\\.[xyz]', ",
  )
  body.push(python_string_literal(lhs_expr))
  body.push(")):\n")
  body.push("    _locals[_frame_name] = ReferenceFrame(_frame_name)\n")
  body.push("lhs = sympify(")
  body.push(python_string_literal(lhs_expr))
  body.push(", locals=_locals)\n")
  if pieces.is_empty() {
    body.push("rhs = 0\n")
  } else {
    for piece in pieces[:pieces.length() - 1] {
      body.push(piece.to_string())
      body.push("\n")
    }
    body.push("rhs = ")
    body.push(pieces[pieces.length() - 1].to_string())
    body.push("\n")
  }
  body.push("delta = lhs - rhs\n")
  body.push("if isinstance(delta, (Vector, Dyadic)):\n")
  body.push("    ok = delta.simplify() == 0\n")
  body.push("else:\n")
  body.push("    ok = simplify(delta) == 0\n")
  body.push("print(ok)\n")
  python_script_stdout(body.join("")) == "True"
}

///|
pub fn vector_bool(expr : String) -> Bool raise {
  vector_eval(expr) == "True"
}

///|
pub fn vector_matrix_rows(expr : String) -> Array[String] raise {
  let txt = python_script_stdout(
    vector_python_result_script(expr, "m = ", "") +
    "print(chr(31).join('[' + ', '.join(str(c) for c in row) + ']' for row in m.tolist()))\n",
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_owned())
  }
}

///|
pub fn vector_matrix_equal(lhs_rows : String, rhs_expr : String) -> Bool raise {
  let pieces = rhs_expr
    .split(";")
    .to_array()
    .map(s => s.trim().to_owned())
    .filter(s => s != "")
  let body : Array[String] = [
    vector_subprocess_prelude(),
    "import re\n",
    "_locals = {'t': t}\n",
    "for _name in set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\\(t\\)', ",
  ]
  body.push(python_string_literal(lhs_rows))
  body.push(")):\n")
  body.push("    _locals[_name] = Function(_name)\n")
  body.push("lhs = Matrix(sympify(")
  body.push(python_string_literal(lhs_rows))
  body.push(", locals=_locals))\n")
  if pieces.is_empty() {
    body.push("rhs = Matrix([[0]])\n")
  } else {
    for piece in pieces[:pieces.length() - 1] {
      body.push(piece.to_string())
      body.push("\n")
    }
    body.push("rhs = ")
    body.push(pieces[pieces.length() - 1].to_string())
    body.push("\n")
  }
  body.push(
    "ok = lhs.shape == rhs.shape and all(simplify(lhs[i, j] - rhs[i, j]) == 0 for i in range(lhs.rows) for j in range(lhs.cols))\n",
  )
  body.push("print(ok)\n")
  python_script_stdout(body.join("")) == "True"
}

///|
pub fn mechanics_matrix_equal(
  lhs_rows : String,
  rhs_expr : String,
) -> Bool raise {
  let pieces = rhs_expr
    .split(";")
    .to_array()
    .map(s => s.trim().to_owned())
    .filter(s => s != "")
  let body : Array[String] = [
    mechanics_subprocess_prelude(),
    "import re\n",
    "_locals = {'t': t}\n",
    "for _name in set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\\(t\\)', ",
  ]
  body.push(python_string_literal(lhs_rows))
  body.push(")):\n")
  body.push("    _locals[_name] = Function(_name)\n")
  body.push("lhs = Matrix(sympify(")
  body.push(python_string_literal(lhs_rows))
  body.push(", locals=_locals))\n")
  if pieces.is_empty() {
    body.push("rhs = Matrix([[0]])\n")
  } else {
    for piece in pieces[:pieces.length() - 1] {
      body.push(piece.to_string())
      body.push("\n")
    }
    body.push("rhs = ")
    body.push(pieces[pieces.length() - 1].to_string())
    body.push("\n")
  }
  body.push(
    "ok = lhs.shape == rhs.shape and all(simplify(lhs[i, j] - rhs[i, j]) == 0 for i in range(lhs.rows) for j in range(lhs.cols))\n",
  )
  body.push("print(ok)\n")
  python_script_stdout(body.join("")) == "True"
}
