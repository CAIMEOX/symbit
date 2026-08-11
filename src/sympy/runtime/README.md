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

The runtime and the first migrated package can be checked with:

```sh
SYMBIT_PYTHON=/absolute/path/to/python moon test --target native src/sympy/runtime
SYMBIT_PYTHON=/absolute/path/to/python moon test --target native src/sympy/integrals
```
