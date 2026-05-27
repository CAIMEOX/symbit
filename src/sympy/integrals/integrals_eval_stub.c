#include "moonbit.h"
#include <stdlib.h>
#include <string.h>

typedef struct _object PyObject;

extern PyObject *PyDict_New(void);
extern int PyDict_SetItemString(PyObject *, const char *, PyObject *);
extern PyObject *PyEval_GetBuiltins(void);
extern PyObject *PyImport_ImportModule(const char *);
extern void Py_DecRef(PyObject *);
extern PyObject *PyRun_StringFlags(
  const char *,
  int,
  PyObject *,
  PyObject *,
  void *
);
extern PyObject *PyObject_Str(PyObject *);
extern void PyErr_Print(void);
extern moonbit_string_t py_unicode_as_moonbit_string(PyObject *);

enum { SYMBIT_PY_EVAL_INPUT = 258 };

static char *symbit_moonbit_string_to_c(moonbit_string_t ms) {
  int32_t len = Moonbit_array_length(ms);
  char *ptr = (char *)malloc((size_t)len + 1);
  if (ptr == NULL) {
    return NULL;
  }
  for (int32_t i = 0; i < len; i++) {
    ptr[i] = ms[i] < 0x80 ? (char)ms[i] : '?';
  }
  ptr[len] = '\0';
  return ptr;
}

static moonbit_string_t symbit_c_string_to_moonbit(const char *s) {
  int32_t len = (int32_t)strlen(s);
  moonbit_string_t ms = moonbit_make_string(len, 0);
  for (int32_t i = 0; i < len; i++) {
    ms[i] = (uint16_t)s[i];
  }
  return ms;
}

static PyObject *symbit_integrals_globals(void) {
  static PyObject *globals = NULL;
  if (globals != NULL) {
    return globals;
  }

  globals = PyDict_New();
  if (globals == NULL) {
    PyErr_Print();
    return NULL;
  }

  PyObject *builtins = PyEval_GetBuiltins();
  if (
    builtins == NULL ||
    PyDict_SetItemString(globals, "__builtins__", builtins) != 0
  ) {
    PyErr_Print();
    return NULL;
  }

  PyObject *sympy = PyImport_ImportModule("sympy");
  if (sympy == NULL) {
    PyErr_Print();
    return NULL;
  }
  if (PyDict_SetItemString(globals, "sympy", sympy) != 0) {
    Py_DecRef(sympy);
    PyErr_Print();
    return NULL;
  }
  Py_DecRef(sympy);

  PyObject *json = PyImport_ImportModule("json");
  if (json == NULL) {
    PyErr_Print();
    return NULL;
  }
  if (PyDict_SetItemString(globals, "json", json) != 0) {
    Py_DecRef(json);
    PyErr_Print();
    return NULL;
  }
  Py_DecRef(json);

  return globals;
}

moonbit_string_t symbit_integrals_eval_string(moonbit_string_t expr) {
  PyObject *globals = symbit_integrals_globals();
  if (globals == NULL) {
    return symbit_c_string_to_moonbit("__SYMBIT_PY_EVAL_NONE__");
  }

  char *code = symbit_moonbit_string_to_c(expr);
  if (code == NULL) {
    return symbit_c_string_to_moonbit("__SYMBIT_PY_EVAL_NONE__");
  }

  PyObject *result = PyRun_StringFlags(
    code,
    SYMBIT_PY_EVAL_INPUT,
    globals,
    globals,
    NULL
  );
  free(code);
  if (result == NULL) {
    PyErr_Print();
    return symbit_c_string_to_moonbit("__SYMBIT_PY_EVAL_NONE__");
  }

  PyObject *text = PyObject_Str(result);
  Py_DecRef(result);
  if (text == NULL) {
    PyErr_Print();
    return symbit_c_string_to_moonbit("__SYMBIT_PY_EVAL_NONE__");
  }

  moonbit_string_t out = py_unicode_as_moonbit_string(text);
  Py_DecRef(text);
  return out;
}
