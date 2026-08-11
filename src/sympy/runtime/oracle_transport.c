#define _POSIX_C_SOURCE 200809L

#include "moonbit.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <spawn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

extern char **environ;

enum {
  SYMBIT_PROTOCOL_FD = 3,
  SYMBIT_MAX_FRAME_SIZE = 64 * 1024 * 1024,
  SYMBIT_DEFAULT_TIMEOUT_MS = 30000,
  SYMBIT_TERMINATION_GRACE_MS = 200,
};

enum symbit_transport_status {
  SYMBIT_TRANSPORT_OK = 0,
  SYMBIT_TRANSPORT_WORKER_NOT_FOUND = 1,
  SYMBIT_TRANSPORT_SPAWN_FAILED = 2,
  SYMBIT_TRANSPORT_REQUEST_TOO_LARGE = 3,
  SYMBIT_TRANSPORT_WRITE_FAILED = 4,
  SYMBIT_TRANSPORT_READ_FAILED = 5,
  SYMBIT_TRANSPORT_INVALID_FRAME = 6,
  SYMBIT_TRANSPORT_TIMEOUT = 7,
};

enum symbit_io_result {
  SYMBIT_IO_OK = 0,
  SYMBIT_IO_ERROR = -1,
  SYMBIT_IO_TIMEOUT = 1,
};

static pthread_mutex_t symbit_worker_mutex = PTHREAD_MUTEX_INITIALIZER;
static pid_t symbit_worker_pid = -1;
static int symbit_worker_input = -1;
static int symbit_worker_output = -1;
static int symbit_cleanup_registered = 0;
static int symbit_timeout_ms = SYMBIT_DEFAULT_TIMEOUT_MS;
static int32_t symbit_next_id = 1;

static int64_t symbit_now_ms(void) {
  struct timespec now;
  if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
    return 0;
  }
  return (int64_t)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

static void symbit_close_fd(int *fd) {
  if (*fd >= 0) {
    close(*fd);
    *fd = -1;
  }
}

static pid_t symbit_waitpid_nohang(pid_t pid, int *status) {
  pid_t result;
  do {
    result = waitpid(pid, status, WNOHANG);
  } while (result < 0 && errno == EINTR);
  return result;
}

static void symbit_terminate_pid(pid_t pid) {
  int status = 0;
  pid_t waited = symbit_waitpid_nohang(pid, &status);
  if (waited == pid || (waited < 0 && errno == ECHILD)) {
    return;
  }

  if (kill(pid, SIGTERM) != 0 && errno == ESRCH) {
    return;
  }
  int64_t deadline = symbit_now_ms() + SYMBIT_TERMINATION_GRACE_MS;
  while (symbit_now_ms() < deadline) {
    waited = symbit_waitpid_nohang(pid, &status);
    if (waited == pid || (waited < 0 && errno == ECHILD)) {
      return;
    }
    struct timespec pause = { .tv_sec = 0, .tv_nsec = 10000000 };
    while (nanosleep(&pause, &pause) != 0 && errno == EINTR) {
    }
  }

  if (kill(pid, SIGKILL) != 0 && errno == ESRCH) {
    return;
  }
  do {
    waited = waitpid(pid, &status, 0);
  } while (waited < 0 && errno == EINTR);
}

static void symbit_reset_worker(int terminate) {
  symbit_close_fd(&symbit_worker_input);
  symbit_close_fd(&symbit_worker_output);
  if (symbit_worker_pid > 0) {
    if (terminate) {
      symbit_terminate_pid(symbit_worker_pid);
    } else {
      int status = 0;
      symbit_waitpid_nohang(symbit_worker_pid, &status);
    }
  }
  symbit_worker_pid = -1;
}

static void symbit_cleanup_worker(void) {
  symbit_reset_worker(1);
}

static int symbit_readable_file(const char *path) {
  return path != NULL && path[0] != '\0' && access(path, R_OK) == 0;
}

static int symbit_join_worker_path(
  char *output,
  size_t output_size,
  const char *base,
  const char *suffix
) {
  int written = snprintf(output, output_size, "%s/%s", base, suffix);
  return written > 0 && (size_t)written < output_size;
}

static const char *symbit_worker_path(void) {
  static char resolved[PATH_MAX];
  const char *source_file = __FILE__;
  const char *slash = strrchr(source_file, '/');
  if (slash != NULL) {
    size_t directory_length = (size_t)(slash - source_file);
    const char *worker_name = "/oracle_worker.py";
    size_t worker_name_length = strlen(worker_name);
    if (directory_length + worker_name_length + 1 < sizeof(resolved)) {
      memcpy(resolved, source_file, directory_length);
      memcpy(
        resolved + directory_length,
        worker_name,
        worker_name_length + 1
      );
      if (symbit_readable_file(resolved)) {
        return resolved;
      }
    }
  }

  char current[PATH_MAX];
  if (getcwd(current, sizeof(current)) == NULL) {
    return NULL;
  }
  while (1) {
    if (
      symbit_join_worker_path(
        resolved,
        sizeof(resolved),
        current,
        "src/sympy/runtime/oracle_worker.py"
      ) &&
      symbit_readable_file(resolved)
    ) {
      return resolved;
    }
    if (
      symbit_join_worker_path(
        resolved,
        sizeof(resolved),
        current,
        "symbit/src/sympy/runtime/oracle_worker.py"
      ) &&
      symbit_readable_file(resolved)
    ) {
      return resolved;
    }
    char *parent_slash = strrchr(current, '/');
    if (parent_slash == NULL || parent_slash == current) {
      break;
    }
    *parent_slash = '\0';
  }
  return NULL;
}

static int symbit_set_cloexec(int fd) {
  int flags = fcntl(fd, F_GETFD);
  return flags < 0 ? -1 : fcntl(fd, F_SETFD, flags | FD_CLOEXEC);
}

static int symbit_set_nonblocking(int fd) {
  int flags = fcntl(fd, F_GETFL);
  return flags < 0 ? -1 : fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static void symbit_close_pipe(int pipe_fds[2]) {
  if (pipe_fds[0] >= 0) close(pipe_fds[0]);
  if (pipe_fds[1] >= 0) close(pipe_fds[1]);
  pipe_fds[0] = -1;
  pipe_fds[1] = -1;
}

static int symbit_add_close_action(
  posix_spawn_file_actions_t *actions,
  int fd
) {
  if (fd == STDIN_FILENO || fd == STDOUT_FILENO || fd == SYMBIT_PROTOCOL_FD) {
    return 0;
  }
  return posix_spawn_file_actions_addclose(actions, fd);
}

static enum symbit_transport_status symbit_spawn_worker(void) {
  const char *worker_path = symbit_worker_path();
  if (worker_path == NULL) {
    return SYMBIT_TRANSPORT_WORKER_NOT_FOUND;
  }
  const char *python = getenv("SYMBIT_PYTHON");
  if (python == NULL || python[0] == '\0') {
    python = "python3";
  }

  int child_input[2] = { -1, -1 };
  int child_output[2] = { -1, -1 };
  if (pipe(child_input) != 0 || pipe(child_output) != 0) {
    symbit_close_pipe(child_input);
    symbit_close_pipe(child_output);
    return SYMBIT_TRANSPORT_SPAWN_FAILED;
  }
  if (
    symbit_set_cloexec(child_input[0]) != 0 ||
    symbit_set_cloexec(child_input[1]) != 0 ||
    symbit_set_cloexec(child_output[0]) != 0 ||
    symbit_set_cloexec(child_output[1]) != 0
  ) {
    symbit_close_pipe(child_input);
    symbit_close_pipe(child_output);
    return SYMBIT_TRANSPORT_SPAWN_FAILED;
  }

  posix_spawn_file_actions_t actions;
  if (posix_spawn_file_actions_init(&actions) != 0) {
    symbit_close_pipe(child_input);
    symbit_close_pipe(child_output);
    return SYMBIT_TRANSPORT_SPAWN_FAILED;
  }
  int action_status = posix_spawn_file_actions_adddup2(
    &actions,
    child_input[0],
    STDIN_FILENO
  );
  if (action_status == 0) {
    action_status = posix_spawn_file_actions_adddup2(
      &actions,
      child_output[1],
      SYMBIT_PROTOCOL_FD
    );
  }
  if (action_status == 0) {
    action_status = posix_spawn_file_actions_addopen(
      &actions,
      STDOUT_FILENO,
      "/dev/null",
      O_WRONLY,
      0
    );
  }
  int pipe_fds[] = {
    child_input[0],
    child_input[1],
    child_output[0],
    child_output[1],
  };
  for (size_t i = 0; action_status == 0 && i < 4; i++) {
    action_status = symbit_add_close_action(&actions, pipe_fds[i]);
  }
  if (action_status != 0) {
    posix_spawn_file_actions_destroy(&actions);
    symbit_close_pipe(child_input);
    symbit_close_pipe(child_output);
    return SYMBIT_TRANSPORT_SPAWN_FAILED;
  }

  char *const arguments[] = {
    (char *)python,
    (char *)"-I",
    (char *)"-u",
    (char *)worker_path,
    (char *)"--protocol-fd",
    (char *)"3",
    NULL,
  };
  pid_t pid = -1;
  int spawn_status = posix_spawnp(
    &pid,
    python,
    &actions,
    NULL,
    arguments,
    environ
  );
  posix_spawn_file_actions_destroy(&actions);
  close(child_input[0]);
  child_input[0] = -1;
  close(child_output[1]);
  child_output[1] = -1;
  if (spawn_status != 0) {
    symbit_close_pipe(child_input);
    symbit_close_pipe(child_output);
    return SYMBIT_TRANSPORT_SPAWN_FAILED;
  }
  if (
    symbit_set_nonblocking(child_input[1]) != 0 ||
    symbit_set_nonblocking(child_output[0]) != 0
  ) {
    close(child_input[1]);
    close(child_output[0]);
    symbit_terminate_pid(pid);
    return SYMBIT_TRANSPORT_SPAWN_FAILED;
  }

  symbit_worker_pid = pid;
  symbit_worker_input = child_input[1];
  symbit_worker_output = child_output[0];
  if (!symbit_cleanup_registered) {
    atexit(symbit_cleanup_worker);
    symbit_cleanup_registered = 1;
  }
  return SYMBIT_TRANSPORT_OK;
}

static enum symbit_transport_status symbit_ensure_worker(void) {
  if (
    symbit_worker_pid > 0 &&
    symbit_worker_input >= 0 &&
    symbit_worker_output >= 0
  ) {
    return SYMBIT_TRANSPORT_OK;
  }
  symbit_reset_worker(1);
  return symbit_spawn_worker();
}

static int symbit_wait_fd(int fd, short events, int64_t deadline_ms) {
  while (1) {
    int64_t remaining = deadline_ms - symbit_now_ms();
    if (remaining <= 0) {
      return SYMBIT_IO_TIMEOUT;
    }
    int timeout = remaining > INT_MAX ? INT_MAX : (int)remaining;
    struct pollfd descriptor = { .fd = fd, .events = events, .revents = 0 };
    int result = poll(&descriptor, 1, timeout);
    if (result > 0) {
      if ((descriptor.revents & events) != 0) {
        return SYMBIT_IO_OK;
      }
      if ((descriptor.revents & (POLLERR | POLLHUP | POLLNVAL)) != 0) {
        return SYMBIT_IO_ERROR;
      }
      continue;
    }
    if (result == 0) {
      return SYMBIT_IO_TIMEOUT;
    }
    if (errno != EINTR) {
      return SYMBIT_IO_ERROR;
    }
  }
}

static int symbit_write_all(
  int fd,
  const uint8_t *data,
  size_t size,
  int64_t deadline_ms
) {
  while (size > 0) {
    int wait_result = symbit_wait_fd(fd, POLLOUT, deadline_ms);
    if (wait_result != SYMBIT_IO_OK) {
      return wait_result;
    }
    ssize_t written = write(fd, data, size);
    if (written < 0) {
      if (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK) {
        continue;
      }
      return SYMBIT_IO_ERROR;
    }
    if (written == 0) return SYMBIT_IO_ERROR;
    data += (size_t)written;
    size -= (size_t)written;
  }
  return SYMBIT_IO_OK;
}

static int symbit_read_all(
  int fd,
  uint8_t *data,
  size_t size,
  int64_t deadline_ms
) {
  while (size > 0) {
    int wait_result = symbit_wait_fd(fd, POLLIN, deadline_ms);
    if (wait_result != SYMBIT_IO_OK) {
      return wait_result;
    }
    ssize_t read_size = read(fd, data, size);
    if (read_size < 0) {
      if (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK) {
        continue;
      }
      return SYMBIT_IO_ERROR;
    }
    if (read_size == 0) return SYMBIT_IO_ERROR;
    data += (size_t)read_size;
    size -= (size_t)read_size;
  }
  return SYMBIT_IO_OK;
}

struct symbit_sigpipe_guard {
  sigset_t old_mask;
  int active;
  int pending_before;
};

static struct symbit_sigpipe_guard symbit_block_sigpipe(void) {
  struct symbit_sigpipe_guard guard = { .active = 0, .pending_before = 0 };
  sigset_t blocked;
  sigemptyset(&blocked);
  sigaddset(&blocked, SIGPIPE);
  sigset_t pending;
  if (sigpending(&pending) == 0) {
    guard.pending_before = sigismember(&pending, SIGPIPE) == 1;
  }
  if (pthread_sigmask(SIG_BLOCK, &blocked, &guard.old_mask) == 0) {
    guard.active = 1;
  }
  return guard;
}

static void symbit_restore_sigpipe(struct symbit_sigpipe_guard *guard) {
  if (!guard->active) {
    return;
  }
  sigset_t pending;
  if (
    !guard->pending_before &&
    sigpending(&pending) == 0 &&
    sigismember(&pending, SIGPIPE) == 1
  ) {
    sigset_t blocked;
    sigemptyset(&blocked);
    sigaddset(&blocked, SIGPIPE);
    int consumed_signal = 0;
    sigwait(&blocked, &consumed_signal);
  }
  pthread_sigmask(SIG_SETMASK, &guard->old_mask, NULL);
}

static moonbit_bytes_t symbit_status_result(
  enum symbit_transport_status status
) {
  moonbit_bytes_t result = moonbit_make_bytes(1, 0);
  result[0] = (uint8_t)status;
  return result;
}

MOONBIT_FFI_EXPORT int32_t symbit_oracle_next_request_id(void) {
  pthread_mutex_lock(&symbit_worker_mutex);
  int32_t id = symbit_next_id;
  symbit_next_id = id == INT32_MAX ? 1 : id + 1;
  pthread_mutex_unlock(&symbit_worker_mutex);
  return id;
}

MOONBIT_FFI_EXPORT void symbit_oracle_set_timeout_for_test(int32_t timeout_ms) {
  pthread_mutex_lock(&symbit_worker_mutex);
  symbit_timeout_ms = timeout_ms > 0 ? timeout_ms : SYMBIT_DEFAULT_TIMEOUT_MS;
  pthread_mutex_unlock(&symbit_worker_mutex);
}

MOONBIT_FFI_EXPORT void symbit_oracle_reset_worker(void) {
  pthread_mutex_lock(&symbit_worker_mutex);
  symbit_reset_worker(1);
  pthread_mutex_unlock(&symbit_worker_mutex);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t symbit_oracle_exchange(
  moonbit_bytes_t request
) {
  pthread_mutex_lock(&symbit_worker_mutex);
  enum symbit_transport_status status = symbit_ensure_worker();
  if (status != SYMBIT_TRANSPORT_OK) {
    moonbit_bytes_t result = symbit_status_result(status);
    pthread_mutex_unlock(&symbit_worker_mutex);
    return result;
  }

  int32_t signed_request_size = Moonbit_array_length(request);
  if (
    signed_request_size < 0 ||
    signed_request_size > SYMBIT_MAX_FRAME_SIZE
  ) {
    moonbit_bytes_t result = symbit_status_result(
      SYMBIT_TRANSPORT_REQUEST_TOO_LARGE
    );
    pthread_mutex_unlock(&symbit_worker_mutex);
    return result;
  }
  uint32_t request_size = (uint32_t)signed_request_size;
  uint8_t header[4] = {
    (uint8_t)(request_size >> 24),
    (uint8_t)(request_size >> 16),
    (uint8_t)(request_size >> 8),
    (uint8_t)request_size,
  };
  int64_t deadline_ms = symbit_now_ms() + symbit_timeout_ms;
  struct symbit_sigpipe_guard sigpipe_guard = symbit_block_sigpipe();
  int io_result = symbit_write_all(
    symbit_worker_input,
    header,
    sizeof(header),
    deadline_ms
  );
  if (io_result == SYMBIT_IO_OK) {
    io_result = symbit_write_all(
      symbit_worker_input,
      request,
      request_size,
      deadline_ms
    );
  }
  symbit_restore_sigpipe(&sigpipe_guard);
  if (io_result != SYMBIT_IO_OK) {
    symbit_reset_worker(1);
    status = io_result == SYMBIT_IO_TIMEOUT
      ? SYMBIT_TRANSPORT_TIMEOUT
      : SYMBIT_TRANSPORT_WRITE_FAILED;
    moonbit_bytes_t result = symbit_status_result(status);
    pthread_mutex_unlock(&symbit_worker_mutex);
    return result;
  }

  io_result = symbit_read_all(
    symbit_worker_output,
    header,
    sizeof(header),
    deadline_ms
  );
  if (io_result != SYMBIT_IO_OK) {
    symbit_reset_worker(1);
    status = io_result == SYMBIT_IO_TIMEOUT
      ? SYMBIT_TRANSPORT_TIMEOUT
      : SYMBIT_TRANSPORT_READ_FAILED;
    moonbit_bytes_t result = symbit_status_result(status);
    pthread_mutex_unlock(&symbit_worker_mutex);
    return result;
  }
  uint32_t response_size =
    ((uint32_t)header[0] << 24) |
    ((uint32_t)header[1] << 16) |
    ((uint32_t)header[2] << 8) |
    (uint32_t)header[3];
  if (response_size > SYMBIT_MAX_FRAME_SIZE) {
    symbit_reset_worker(1);
    moonbit_bytes_t result = symbit_status_result(
      SYMBIT_TRANSPORT_INVALID_FRAME
    );
    pthread_mutex_unlock(&symbit_worker_mutex);
    return result;
  }
  moonbit_bytes_t response = moonbit_make_bytes_raw(
    (int32_t)response_size + 1
  );
  response[0] = SYMBIT_TRANSPORT_OK;
  if (response_size > 0) {
    io_result = symbit_read_all(
      symbit_worker_output,
      response + 1,
      response_size,
      deadline_ms
    );
  }
  if (io_result != SYMBIT_IO_OK) {
    symbit_reset_worker(1);
    status = io_result == SYMBIT_IO_TIMEOUT
      ? SYMBIT_TRANSPORT_TIMEOUT
      : SYMBIT_TRANSPORT_READ_FAILED;
    response = symbit_status_result(status);
  }
  pthread_mutex_unlock(&symbit_worker_mutex);
  return response;
}
