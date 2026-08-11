# SymPy oracle runtime

This package is private test infrastructure under the publication-excluded
`src/sympy` tree. It is deliberately not a general MoonBit binding to CPython.

Each native test executable lazily starts one persistent Python worker. MoonBit
and the worker exchange UTF-8 JSON frames over pipes using a four-byte
big-endian length prefix. A dedicated protocol descriptor keeps direct writes
to Python stdout away from framing, and the native transport serializes all
requests. Python exceptions are returned as structured errors; if a request
exceeds the 30-second deadline or the worker exits, crashes, or violates the
protocol, the MoonBit test process stays alive and the next request starts a
fresh worker. Evaluation globals are fresh for every request.

Configuration:

- `SYMBIT_PYTHON=/absolute/path/to/python` selects the interpreter. The default
  is `python3` from `PATH`.

The worker script and sibling SymPy checkout are resolved from the runtime's
source location, so there are no independent path knobs that can silently point
the two sides at different installations.

Migrating an oracle package should add a fixed program to `PROGRAMS`, expose a
narrow serializable MoonBit wrapper, and remove that package's Kaida, CPython,
GIL, and `Python.h` dependencies. Programs should finish all Python object work
inside one request; do not add global remote-object handles without a concrete
case that cannot be expressed as request-scoped work.

Current migrated programs:

- `oracle.recipe.v1` evaluates a request-scoped, schema-versioned JSON DAG.
  Nodes are fully validated before execution, may reference only earlier node
  ids, are evaluated at most once, and only nodes reachable from `result` run.
- `integrals.eval_str` evaluates one expression with the integrals helper
  profile.
- `unify.exec_result_str` executes one request-scoped parity script and returns
  its `__result__` value as a string.
- `utilities.eval_str` evaluates one expression with the legacy utilities
  aliases and returns its string value.

## Recipe protocol v1

A recipe has exactly `schema`, `nodes`, and `result` fields. `schema` is `1`;
node ids are consecutive array indexes; a reference is `{"ref": id}` and must
point to an earlier node. The result is
`{"ref": id, "codec": codec}`. Unknown fields, operations, profiles, codecs,
and invalid references are protocol errors discovered before any node runs.

Supported nodes are:

- `const` with `none`, `bool`, `str`, decimal-string `int`, or string `float`;
- `import`, `getattr`, lazy `getattr_or`, `getitem`, and `call`;
- `collection` with `list`, `tuple`, `set`, `frozenset`, or key/value-pair
  `dict` items;
- request-local `scope` with the `sympy.base` profile, plus `bind`, `exec`, and
  `eval` returning or using that same scope;
- `require_non_none` for turning an unexpected `None` into a Python error.

`getattr_or` evaluates its fallback reference only when Python attribute lookup
raises `AttributeError`; an attribute whose value is `None` is still present.

Scalar result codecs are `discard`, `none`, `str`, `repr`, `srepr`, `bool`,
decimal-string `int`, string `float`, and `json`. `bool` accepts only Python or
SymPy booleans; `int` uses Python's index protocol and never truncates floats.
The `json` codec recursively rejects Python integers outside
`[-(2^53-1), 2^53-1]`, including nested container values, so MoonBit's JSON
number representation cannot silently lose integer precision.
Recursive codecs use `{"kind":"optional|list","item": codec}`, fixed tuples
use `{"kind":"tuple","items":[codec, ...]}`, and dictionaries use
`{"kind":"dict_pairs","key": codec,"value": codec}`. Recipe state, scope, and
the scope's builtins mapping never survive the request, and no Python object
handles cross the process boundary. Imported Python modules (including SymPy)
remain process-global, so recipes must not mutate module state unless the same
request restores it before returning.

The runtime and the first migrated package can be checked with:

```sh
SYMBIT_PYTHON=/absolute/path/to/python moon test --target native src/sympy/runtime
SYMBIT_PYTHON=/absolute/path/to/python moon test --target native src/sympy/integrals
SYMBIT_PYTHON=/absolute/path/to/python moon test --target native src/sympy/unify
SYMBIT_PYTHON=/absolute/path/to/python moon test --target native src/sympy/utilities
```
