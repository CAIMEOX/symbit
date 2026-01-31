#include "moonbit.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *mb_str_to_c_str(moonbit_string_t ms) {
  int32_t len = Moonbit_array_length(ms);
  char *ptr = (char *)malloc((size_t)len + 1);
  if (!ptr) {
    return NULL;
  }
  for (int32_t i = 0; i < len; i++) {
    uint16_t c = ms[i];
    ptr[i] = (c < 0x80) ? (char)c : '?';
  }
  ptr[len] = '\0';
  return ptr;
}

static moonbit_string_t mb_string_from_bytes(const char *buf, size_t len) {
  moonbit_string_t ms = moonbit_make_string((int32_t)len, 0);
  for (size_t i = 0; i < len; i++) {
    ms[i] = (uint16_t)((unsigned char)buf[i]);
  }
  return ms;
}

static char *dup_cstr(const char *s) {
  size_t len = strlen(s);
  char *out = (char *)malloc(len + 1);
  if (!out) {
    return NULL;
  }
  memcpy(out, s, len + 1);
  return out;
}

moonbit_string_t sympy_oracle_exec(moonbit_string_t payload_json,
                                   moonbit_string_t oracle_path) {
  char *payload_c = mb_str_to_c_str(payload_json);
  char *path_c = mb_str_to_c_str(oracle_path);
  if (!payload_c || !path_c) {
    const char *msg = "PYERR: failed to allocate payload/path";
    if (payload_c)
      free(payload_c);
    if (path_c)
      free(path_c);
    return mb_string_from_bytes(msg, strlen(msg));
  }

  // Ensure sympy_oracle.py is importable.
  const char *existing = getenv("PYTHONPATH");
  char *combined = NULL;
  if (existing && existing[0]) {
    size_t len = strlen(path_c) + 1 + strlen(existing) + 1;
    combined = (char *)malloc(len);
    if (combined) {
      snprintf(combined, len, "%s:%s", path_c, existing);
    }
  } else {
    combined = dup_cstr(path_c);
  }
  if (combined) {
    setenv("PYTHONPATH", combined, 1);
  }
  setenv("SYMPY_ORACLE_JSON", payload_c, 1);

  const char *cmd =
      "python3 -c \"import os, sympy_oracle; "
      "print(sympy_oracle.dispatch_json(os.environ['SYMPY_ORACLE_JSON']))\" 2>&1";

  FILE *fp = popen(cmd, "r");
  if (!fp) {
    const char *msg = "PYERR: popen failed";
    free(payload_c);
    free(path_c);
    if (combined)
      free(combined);
    return mb_string_from_bytes(msg, strlen(msg));
  }

  size_t cap = 4096;
  size_t len = 0;
  char *buf = (char *)malloc(cap);
  if (!buf) {
    pclose(fp);
    const char *msg = "PYERR: alloc failed";
    free(payload_c);
    free(path_c);
    if (combined)
      free(combined);
    return mb_string_from_bytes(msg, strlen(msg));
  }

  while (!feof(fp)) {
    if (len + 256 >= cap) {
      cap *= 2;
      char *next = (char *)realloc(buf, cap);
      if (!next) {
        free(buf);
        pclose(fp);
        const char *msg = "PYERR: realloc failed";
        free(payload_c);
        free(path_c);
        if (combined)
          free(combined);
        return mb_string_from_bytes(msg, strlen(msg));
      }
      buf = next;
    }
    size_t n = fread(buf + len, 1, cap - len - 1, fp);
    len += n;
    if (n == 0) {
      break;
    }
  }

  int status = pclose(fp);
  while (len > 0 && (buf[len - 1] == '\n' || buf[len - 1] == '\r')) {
    len--;
  }

  moonbit_string_t out;
  if (status != 0) {
    const char *prefix = "PYERR: ";
    size_t plen = strlen(prefix);
    moonbit_string_t ms = moonbit_make_string((int32_t)(plen + len), 0);
    for (size_t i = 0; i < plen; i++) {
      ms[i] = (uint16_t)prefix[i];
    }
    for (size_t i = 0; i < len; i++) {
      ms[plen + i] = (uint16_t)((unsigned char)buf[i]);
    }
    out = ms;
  } else {
    out = mb_string_from_bytes(buf, len);
  }

  free(buf);
  free(payload_c);
  free(path_c);
  if (combined)
    free(combined);
  return out;
}
