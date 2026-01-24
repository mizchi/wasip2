/// Sandbox Security Configuration

/// Capability flags for operations
pub struct Capabilities {
  // File operations
  can_read : Bool
  can_write : Bool
  can_create : Bool
  can_delete : Bool

  // Directory operations
  can_mkdir : Bool
  can_rmdir : Bool
  can_list : Bool

  // Execution
  can_exec : Bool
  allowed_commands : Array[String]?  // None = all, Some([]) = none

  // Path restrictions
  allowed_paths : Array[String]?      // None = all paths allowed
  denied_paths : Array[String]        // Always denied (higher priority)

  // Resource limits
  max_file_size : Int?         // bytes, None = unlimited
  max_total_size : Int?        // bytes
  max_open_files : Int?        // count
  max_path_depth : Int?        // directory depth

  // Time/Resource limits
  max_exec_time_ms : Int64?    // execution timeout
  max_memory_bytes : Int?      // memory limit
}

/// Preset security profiles
pub fn Capabilities::unrestricted() -> Capabilities {
  {
    can_read: true,
    can_write: true,
    can_create: true,
    can_delete: true,
    can_mkdir: true,
    can_rmdir: true,
    can_list: true,
    can_exec: true,
    allowed_commands: None,
    allowed_paths: None,
    denied_paths: [],
    max_file_size: None,
    max_total_size: None,
    max_open_files: None,
    max_path_depth: None,
    max_exec_time_ms: None,
    max_memory_bytes: None,
  }
}

/// Read-only sandbox (safe for untrusted code)
pub fn Capabilities::read_only() -> Capabilities {
  {
    can_read: true,
    can_write: false,
    can_create: false,
    can_delete: false,
    can_mkdir: false,
    can_rmdir: false,
    can_list: true,
    can_exec: false,
    allowed_commands: Some([]),
    allowed_paths: None,
    denied_paths: [],
    max_file_size: None,
    max_total_size: None,
    max_open_files: Some(16),
    max_path_depth: Some(10),
    max_exec_time_ms: Some(5000L),
    max_memory_bytes: None,
  }
}

/// Restricted write (e.g., for build tools)
pub fn Capabilities::build_sandbox() -> Capabilities {
  {
    can_read: true,
    can_write: true,
    can_create: true,
    can_delete: true,
    can_mkdir: true,
    can_rmdir: true,
    can_list: true,
    can_exec: true,
    allowed_commands: Some(["moon", "moonc", "moonrun", "ls", "cat", "echo"]),
    allowed_paths: Some(["/tmp", "/build", "/src"]),
    denied_paths: ["/etc", "/bin", "/home"],
    max_file_size: Some(10 * 1024 * 1024),  // 10MB
    max_total_size: Some(100 * 1024 * 1024), // 100MB
    max_open_files: Some(64),
    max_path_depth: Some(20),
    max_exec_time_ms: Some(60000L),  // 1 minute
    max_memory_bytes: Some(256 * 1024 * 1024), // 256MB
  }
}

/// Minimal sandbox for untrusted plugins
pub fn Capabilities::plugin_sandbox() -> Capabilities {
  {
    can_read: true,
    can_write: true,
    can_create: true,
    can_delete: false,
    can_mkdir: true,
    can_rmdir: false,
    can_list: true,
    can_exec: false,
    allowed_commands: Some([]),
    allowed_paths: Some(["/tmp/plugin"]),
    denied_paths: [],
    max_file_size: Some(1024 * 1024),  // 1MB
    max_total_size: Some(10 * 1024 * 1024), // 10MB
    max_open_files: Some(8),
    max_path_depth: Some(5),
    max_exec_time_ms: Some(1000L),  // 1 second
    max_memory_bytes: Some(16 * 1024 * 1024), // 16MB
  }
}

/// Builder methods for customizing capabilities
pub fn Capabilities::with_allowed_paths(self : Capabilities, paths : Array[String]) -> Capabilities {
  {
    can_read: self.can_read,
    can_write: self.can_write,
    can_create: self.can_create,
    can_delete: self.can_delete,
    can_mkdir: self.can_mkdir,
    can_rmdir: self.can_rmdir,
    can_list: self.can_list,
    can_exec: self.can_exec,
    allowed_commands: self.allowed_commands,
    allowed_paths: Some(paths),
    denied_paths: self.denied_paths,
    max_file_size: self.max_file_size,
    max_total_size: self.max_total_size,
    max_open_files: self.max_open_files,
    max_path_depth: self.max_path_depth,
    max_exec_time_ms: self.max_exec_time_ms,
    max_memory_bytes: self.max_memory_bytes,
  }
}

pub fn Capabilities::with_denied_paths(self : Capabilities, paths : Array[String]) -> Capabilities {
  {
    can_read: self.can_read,
    can_write: self.can_write,
    can_create: self.can_create,
    can_delete: self.can_delete,
    can_mkdir: self.can_mkdir,
    can_rmdir: self.can_rmdir,
    can_list: self.can_list,
    can_exec: self.can_exec,
    allowed_commands: self.allowed_commands,
    allowed_paths: self.allowed_paths,
    denied_paths: paths,
    max_file_size: self.max_file_size,
    max_total_size: self.max_total_size,
    max_open_files: self.max_open_files,
    max_path_depth: self.max_path_depth,
    max_exec_time_ms: self.max_exec_time_ms,
    max_memory_bytes: self.max_memory_bytes,
  }
}

pub fn Capabilities::with_allowed_commands(self : Capabilities, cmds : Array[String]) -> Capabilities {
  {
    can_read: self.can_read,
    can_write: self.can_write,
    can_create: self.can_create,
    can_delete: self.can_delete,
    can_mkdir: self.can_mkdir,
    can_rmdir: self.can_rmdir,
    can_list: self.can_list,
    can_exec: self.can_exec,
    allowed_commands: Some(cmds),
    allowed_paths: self.allowed_paths,
    denied_paths: self.denied_paths,
    max_file_size: self.max_file_size,
    max_total_size: self.max_total_size,
    max_open_files: self.max_open_files,
    max_path_depth: self.max_path_depth,
    max_exec_time_ms: self.max_exec_time_ms,
    max_memory_bytes: self.max_memory_bytes,
  }
}

pub fn Capabilities::with_exec(self : Capabilities, can_exec : Bool) -> Capabilities {
  {
    can_read: self.can_read,
    can_write: self.can_write,
    can_create: self.can_create,
    can_delete: self.can_delete,
    can_mkdir: self.can_mkdir,
    can_rmdir: self.can_rmdir,
    can_list: self.can_list,
    can_exec,
    allowed_commands: self.allowed_commands,
    allowed_paths: self.allowed_paths,
    denied_paths: self.denied_paths,
    max_file_size: self.max_file_size,
    max_total_size: self.max_total_size,
    max_open_files: self.max_open_files,
    max_path_depth: self.max_path_depth,
    max_exec_time_ms: self.max_exec_time_ms,
    max_memory_bytes: self.max_memory_bytes,
  }
}

pub fn Capabilities::with_delete(self : Capabilities, can_delete : Bool) -> Capabilities {
  {
    can_read: self.can_read,
    can_write: self.can_write,
    can_create: self.can_create,
    can_delete,
    can_mkdir: self.can_mkdir,
    can_rmdir: self.can_rmdir,
    can_list: self.can_list,
    can_exec: self.can_exec,
    allowed_commands: self.allowed_commands,
    allowed_paths: self.allowed_paths,
    denied_paths: self.denied_paths,
    max_file_size: self.max_file_size,
    max_total_size: self.max_total_size,
    max_open_files: self.max_open_files,
    max_path_depth: self.max_path_depth,
    max_exec_time_ms: self.max_exec_time_ms,
    max_memory_bytes: self.max_memory_bytes,
  }
}

pub fn Capabilities::with_max_file_size(self : Capabilities, size : Int) -> Capabilities {
  {
    can_read: self.can_read,
    can_write: self.can_write,
    can_create: self.can_create,
    can_delete: self.can_delete,
    can_mkdir: self.can_mkdir,
    can_rmdir: self.can_rmdir,
    can_list: self.can_list,
    can_exec: self.can_exec,
    allowed_commands: self.allowed_commands,
    allowed_paths: self.allowed_paths,
    denied_paths: self.denied_paths,
    max_file_size: Some(size),
    max_total_size: self.max_total_size,
    max_open_files: self.max_open_files,
    max_path_depth: self.max_path_depth,
    max_exec_time_ms: self.max_exec_time_ms,
    max_memory_bytes: self.max_memory_bytes,
  }
}

pub fn Capabilities::with_max_open_files(self : Capabilities, count : Int) -> Capabilities {
  {
    can_read: self.can_read,
    can_write: self.can_write,
    can_create: self.can_create,
    can_delete: self.can_delete,
    can_mkdir: self.can_mkdir,
    can_rmdir: self.can_rmdir,
    can_list: self.can_list,
    can_exec: self.can_exec,
    allowed_commands: self.allowed_commands,
    allowed_paths: self.allowed_paths,
    denied_paths: self.denied_paths,
    max_file_size: self.max_file_size,
    max_total_size: self.max_total_size,
    max_open_files: Some(count),
    max_path_depth: self.max_path_depth,
    max_exec_time_ms: self.max_exec_time_ms,
    max_memory_bytes: self.max_memory_bytes,
  }
}

pub fn Capabilities::with_max_path_depth(self : Capabilities, depth : Int) -> Capabilities {
  {
    can_read: self.can_read,
    can_write: self.can_write,
    can_create: self.can_create,
    can_delete: self.can_delete,
    can_mkdir: self.can_mkdir,
    can_rmdir: self.can_rmdir,
    can_list: self.can_list,
    can_exec: self.can_exec,
    allowed_commands: self.allowed_commands,
    allowed_paths: self.allowed_paths,
    denied_paths: self.denied_paths,
    max_file_size: self.max_file_size,
    max_total_size: self.max_total_size,
    max_open_files: self.max_open_files,
    max_path_depth: Some(depth),
    max_exec_time_ms: self.max_exec_time_ms,
    max_memory_bytes: self.max_memory_bytes,
  }
}

/// Security violation error
pub(all) suberror SandboxError {
  PermissionDenied(String)     // Operation not allowed
  PathDenied(String)           // Path access denied
  CommandDenied(String)        // Command not allowed
  ResourceLimitExceeded(String) // Limit exceeded
  IOError(String)              // Underlying IO error
} derive(Show, Eq)

/// Sandboxed POSIX context
pub struct Sandbox {
  ctx : PosixContext
  caps : Capabilities
  mut open_file_count : Int
}

pub fn Sandbox::new(caps : Capabilities) -> Sandbox {
  let fs = MemFS::new()
  {
    ctx: PosixContext::new(fs),
    caps,
    open_file_count: 0,
  }
}

pub fn Sandbox::with_fs(fs : MemFS, caps : Capabilities) -> Sandbox {
  {
    ctx: PosixContext::new(fs),
    caps,
    open_file_count: 0,
  }
}

/// Check if path is allowed
fn Sandbox::check_path(self : Sandbox, path : String) -> Unit raise SandboxError {
  let abs_path = self.ctx.resolve_path(path)

  // Check denied paths first (higher priority)
  for denied in self.caps.denied_paths {
    if abs_path.has_prefix(denied) {
      raise PathDenied("Access denied: " + abs_path)
    }
  }

  // Check allowed paths
  match self.caps.allowed_paths {
    Some(allowed) => {
      let mut is_allowed = false
      for prefix in allowed {
        if abs_path.has_prefix(prefix) || abs_path == prefix {
          is_allowed = true
          break
        }
      }
      if not(is_allowed) {
        raise PathDenied("Path not in allowed list: " + abs_path)
      }
    }
    None => ()  // All paths allowed
  }

  // Check path depth
  match self.caps.max_path_depth {
    Some(max_depth) => {
      let depth = count_path_depth(abs_path)
      if depth > max_depth {
        raise ResourceLimitExceeded("Path depth exceeds limit: " + depth.to_string())
      }
    }
    None => ()
  }
}

/// Check if command is allowed
fn Sandbox::check_command(self : Sandbox, cmd : String) -> Unit raise SandboxError {
  if not(self.caps.can_exec) {
    raise PermissionDenied("Execution not allowed")
  }

  match self.caps.allowed_commands {
    Some(allowed) => {
      if not(allowed.contains(cmd)) {
        raise CommandDenied("Command not allowed: " + cmd)
      }
    }
    None => ()  // All commands allowed
  }
}

/// Check resource limits
fn Sandbox::check_file_size(self : Sandbox, size : Int) -> Unit raise SandboxError {
  match self.caps.max_file_size {
    Some(max_size) => {
      if size > max_size {
        raise ResourceLimitExceeded("File size exceeds limit: " + size.to_string() + " bytes")
      }
    }
    None => ()
  }
}

fn Sandbox::check_open_files(self : Sandbox) -> Unit raise SandboxError {
  match self.caps.max_open_files {
    Some(max_files) => {
      if self.open_file_count >= max_files {
        raise ResourceLimitExceeded("Too many open files")
      }
    }
    None => ()
  }
}

// ============ Sandboxed Operations ============

pub fn Sandbox::open(
  self : Sandbox,
  path : String,
  flags : OpenFlags,
  mode : FileMode
) -> Fd raise SandboxError {
  // Check permissions
  if flags.is_readable() && not(self.caps.can_read) {
    raise PermissionDenied("Read not allowed")
  }
  if flags.is_writable() && not(self.caps.can_write) {
    raise PermissionDenied("Write not allowed")
  }
  if flags.has(O_CREAT) && not(self.caps.can_create) {
    raise PermissionDenied("Create not allowed")
  }

  self.check_path(path)
  self.check_open_files()

  try {
    let fd = self.ctx.open(path, flags, mode)
    self.open_file_count += 1
    fd
  } catch {
    _ => raise IOError("Failed to open file")
  }
}

pub fn Sandbox::close(self : Sandbox, fd : Fd) -> Unit raise SandboxError {
  try {
    self.ctx.close(fd)
    if self.open_file_count > 0 {
      self.open_file_count -= 1
    }
  } catch {
    _ => raise IOError("Failed to close file")
  }
}

pub fn Sandbox::read(self : Sandbox, fd : Fd, count : Int) -> Bytes raise SandboxError {
  if not(self.caps.can_read) {
    raise PermissionDenied("Read not allowed")
  }
  try {
    self.ctx.read(fd, count)
  } catch {
    _ => raise IOError("Failed to read")
  }
}

pub fn Sandbox::write(self : Sandbox, fd : Fd, data : Bytes) -> Int raise SandboxError {
  if not(self.caps.can_write) {
    raise PermissionDenied("Write not allowed")
  }
  self.check_file_size(data.length())
  try {
    self.ctx.write(fd, data)
  } catch {
    _ => raise IOError("Failed to write")
  }
}

pub fn Sandbox::mkdir(self : Sandbox, path : String) -> Unit raise SandboxError {
  if not(self.caps.can_mkdir) {
    raise PermissionDenied("mkdir not allowed")
  }
  self.check_path(path)
  try {
    self.ctx.get_fs().mkdir(self.ctx.resolve_path(path))
  } catch {
    _ => raise IOError("mkdir failed")
  }
}

pub fn Sandbox::remove(self : Sandbox, path : String) -> Unit raise SandboxError {
  if not(self.caps.can_delete) {
    raise PermissionDenied("Delete not allowed")
  }
  self.check_path(path)
  try {
    self.ctx.get_fs().remove(self.ctx.resolve_path(path))
  } catch {
    _ => raise IOError("remove failed")
  }
}

pub fn Sandbox::exec(
  self : Sandbox,
  cmd : String,
  args : Array[String]
) -> Pid raise SandboxError {
  self.check_command(cmd)
  self.ctx.spawn(cmd, args)
}

/// Get the underlying context (for advanced operations)
pub fn Sandbox::get_ctx(self : Sandbox) -> PosixContext {
  self.ctx
}

/// Get capabilities
pub fn Sandbox::get_caps(self : Sandbox) -> Capabilities {
  self.caps
}

// ============ Helpers ============

fn count_path_depth(path : String) -> Int {
  let mut depth = 0
  for c in path {
    if c == '/' {
      depth += 1
    }
  }
  depth
}
