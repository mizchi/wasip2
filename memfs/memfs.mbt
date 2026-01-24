/// MemFS - In-memory filesystem for sandboxed operations

/// Entry type in the filesystem
pub(all) enum FsEntry {
  File(Bytes)
  Dir
  Symlink(String)
}

/// Error types for MemFS operations
pub(all) suberror MemFSError {
  NotFound(String)
  AlreadyExists(String)
  NotAFile(String)
  NotADirectory(String)
  InvalidPath(String)
  SymlinkLoop(String)
} derive(Show, Eq)

/// In-memory filesystem
pub struct MemFS {
  entries : Map[String, FsEntry]
  mut current_size : Int
  max_total_size : Int?
  max_file_count : Int?
}

/// Create a new MemFS
pub fn MemFS::new(
  max_total_size? : Int,
  max_file_count? : Int
) -> MemFS {
  let fs : MemFS = {
    entries: {},
    current_size: 0,
    max_total_size,
    max_file_count,
  }
  // Create root directory
  fs.entries.set("/", Dir)
  fs
}

/// Default MemFS with standard directories
pub fn MemFS::default() -> MemFS {
  let fs = MemFS::new()
  try {
    fs.mkdir("/bin")
    fs.mkdir("/home")
    fs.mkdir("/tmp")
  } catch {
    _ => ()
  }
  fs
}

/// Normalize path (remove . and ..)
fn normalize_path(path : String) -> String {
  if path == "" {
    return "/"
  }
  let parts = split_path(path)
  let result : Array[String] = []
  for part in parts {
    if part == "" || part == "." {
      continue
    } else if part == ".." {
      if result.length() > 0 {
        ignore(result.pop())
      }
    } else {
      result.push(part)
    }
  }
  if result.length() == 0 {
    "/"
  } else {
    "/" + result.join("/")
  }
}

fn split_path(path : String) -> Array[String] {
  let result : Array[String] = []
  let mut current = StringBuilder::new()
  for c in path {
    if c == '/' {
      if current.to_string().length() > 0 {
        result.push(current.to_string())
        current = StringBuilder::new()
      }
    } else {
      current.write_char(c)
    }
  }
  if current.to_string().length() > 0 {
    result.push(current.to_string())
  }
  result
}

fn parent_path(path : String) -> String {
  let normalized = normalize_path(path)
  if normalized == "/" {
    return "/"
  }
  match normalized.rev_find("/") {
    None => "/"
    Some(0) => "/"
    Some(i) => {
      let result = StringBuilder::new()
      let chars = normalized.to_array()
      for j in 0..<i {
        result.write_char(chars[j])
      }
      result.to_string()
    }
  }
}

/// Resolve symlinks (up to max depth)
fn MemFS::resolve_symlinks(
  self : MemFS,
  path : String,
  max_depth : Int
) -> String raise MemFSError {
  if max_depth <= 0 {
    raise SymlinkLoop(path)
  }
  match self.entries.get(path) {
    Some(Symlink(target)) => {
      let resolved = if target.has_prefix("/") {
        normalize_path(target)
      } else {
        normalize_path(parent_path(path) + "/" + target)
      }
      self.resolve_symlinks(resolved, max_depth - 1)
    }
    _ => path
  }
}

/// Resolve path following symlinks
pub fn MemFS::resolve_path(self : MemFS, path : String) -> String raise MemFSError {
  self.resolve_symlinks(normalize_path(path), 40)
}

/// Check if path exists
pub fn MemFS::exists(self : MemFS, path : String) -> Bool {
  let normalized = normalize_path(path)
  self.entries.contains(normalized)
}

/// Check if path is a directory
pub fn MemFS::is_dir(self : MemFS, path : String) -> Bool {
  let normalized = normalize_path(path)
  match self.entries.get(normalized) {
    Some(Dir) => true
    Some(Symlink(_)) => {
      let resolved = try { self.resolve_path(normalized) } catch { _ => return false }
      match self.entries.get(resolved) {
        Some(Dir) => true
        _ => false
      }
    }
    _ => false
  }
}

/// Check if path is a file
pub fn MemFS::is_file(self : MemFS, path : String) -> Bool {
  let normalized = normalize_path(path)
  match self.entries.get(normalized) {
    Some(File(_)) => true
    Some(Symlink(_)) => {
      let resolved = try { self.resolve_path(normalized) } catch { _ => return false }
      match self.entries.get(resolved) {
        Some(File(_)) => true
        _ => false
      }
    }
    _ => false
  }
}

/// Check if path is a symlink
pub fn MemFS::is_symlink(self : MemFS, path : String) -> Bool {
  let normalized = normalize_path(path)
  match self.entries.get(normalized) {
    Some(Symlink(_)) => true
    _ => false
  }
}

/// Create a directory
pub fn MemFS::mkdir(self : MemFS, path : String) -> Unit raise MemFSError {
  let normalized = normalize_path(path)
  if normalized == "/" {
    return
  }
  // Check parent exists
  let parent = parent_path(normalized)
  if not(self.is_dir(parent)) {
    raise NotADirectory(parent)
  }
  // Check path doesn't exist
  if self.exists(normalized) {
    raise AlreadyExists(normalized)
  }
  self.entries.set(normalized, Dir)
}

/// Create directories recursively
pub fn MemFS::mkdir_p(self : MemFS, path : String) -> Unit raise MemFSError {
  let normalized = normalize_path(path)
  if normalized == "/" {
    return
  }
  let parts = split_path(normalized)
  let mut current = ""
  for part in parts {
    current = current + "/" + part
    if not(self.exists(current)) {
      self.entries.set(current, Dir)
    } else if not(self.is_dir(current)) {
      raise NotADirectory(current)
    }
  }
}

/// Read file contents
pub fn MemFS::read_file(self : MemFS, path : String) -> Bytes raise MemFSError {
  let resolved = self.resolve_path(path)
  match self.entries.get(resolved) {
    Some(File(content)) => content
    Some(Dir) => raise NotAFile(resolved)
    Some(Symlink(_)) => raise NotAFile(resolved)
    None => raise NotFound(path)
  }
}

/// Write file contents
pub fn MemFS::write_file(self : MemFS, path : String, content : Bytes) -> Unit raise MemFSError {
  let normalized = normalize_path(path)
  // Check parent exists
  let parent = parent_path(normalized)
  if not(self.is_dir(parent)) {
    raise NotADirectory(parent)
  }
  // Get old size for quota tracking
  let old_size = match self.entries.get(normalized) {
    Some(File(old)) => old.length()
    Some(Dir) => raise NotAFile(normalized)
    _ => 0
  }
  self.current_size = self.current_size - old_size + content.length()
  self.entries.set(normalized, File(content))
}

/// Write string to file
pub fn MemFS::write_string(self : MemFS, path : String, content : String) -> Unit raise MemFSError {
  self.write_file(path, Bytes::from_iter(content.iter().map(fn(c) { c.to_int().to_byte() })))
}

/// Read file as string
pub fn MemFS::read_string(self : MemFS, path : String) -> String raise MemFSError {
  let bytes = self.read_file(path)
  let result = StringBuilder::new()
  for b in bytes {
    result.write_char(b.to_int().unsafe_to_char())
  }
  result.to_string()
}

/// Create symlink
pub fn MemFS::symlink(self : MemFS, path : String, target : String) -> Unit raise MemFSError {
  let normalized = normalize_path(path)
  let parent = parent_path(normalized)
  if not(self.is_dir(parent)) {
    raise NotADirectory(parent)
  }
  if self.exists(normalized) {
    raise AlreadyExists(normalized)
  }
  self.entries.set(normalized, Symlink(target))
}

/// Read symlink target
pub fn MemFS::read_link(self : MemFS, path : String) -> String raise MemFSError {
  let normalized = normalize_path(path)
  match self.entries.get(normalized) {
    Some(Symlink(target)) => target
    Some(_) => raise NotAFile(normalized)
    None => raise NotFound(path)
  }
}

/// Remove file or symlink
pub fn MemFS::remove(self : MemFS, path : String) -> Unit raise MemFSError {
  let normalized = normalize_path(path)
  match self.entries.get(normalized) {
    Some(File(content)) => {
      self.current_size -= content.length()
      self.entries.remove(normalized)
    }
    Some(Symlink(_)) => {
      self.entries.remove(normalized)
    }
    Some(Dir) => raise NotAFile(normalized)
    None => raise NotFound(path)
  }
}

/// Remove directory (must be empty)
pub fn MemFS::rmdir(self : MemFS, path : String) -> Unit raise MemFSError {
  let normalized = normalize_path(path)
  if normalized == "/" {
    raise InvalidPath("/")
  }
  if not(self.is_dir(normalized)) {
    raise NotADirectory(normalized)
  }
  // Check if empty
  for entry_path, _ in self.entries {
    if entry_path != normalized && entry_path.has_prefix(normalized + "/") {
      raise NotADirectory(normalized + " is not empty")
    }
  }
  self.entries.remove(normalized)
}

/// List directory contents
pub fn MemFS::readdir(self : MemFS, path : String) -> Array[String] raise MemFSError {
  let resolved = self.resolve_path(path)
  if not(self.is_dir(resolved)) {
    raise NotADirectory(path)
  }
  let prefix = if resolved == "/" { "/" } else { resolved + "/" }
  let result : Array[String] = []
  for entry_path, _ in self.entries {
    if entry_path.has_prefix(prefix) {
      let rest = substring_from(entry_path, prefix.length())
      if rest.length() > 0 && not(string_contains(rest, "/")) {
        result.push(rest)
      }
    }
  }
  result
}

/// Get file size
pub fn MemFS::size(self : MemFS, path : String) -> Int? {
  let resolved = try { self.resolve_path(path) } catch { _ => return None }
  match self.entries.get(resolved) {
    Some(File(content)) => Some(content.length())
    _ => None
  }
}

/// Get total size of all files
pub fn MemFS::total_size(self : MemFS) -> Int {
  self.current_size
}

/// Get file count
pub fn MemFS::file_count(self : MemFS) -> Int {
  let mut count = 0
  for _, entry in self.entries {
    match entry {
      File(_) => count += 1
      _ => ()
    }
  }
  count
}

fn substring_from(s : String, start : Int) -> String {
  if start >= s.length() {
    return ""
  }
  let result = StringBuilder::new()
  let chars = s.to_array()
  for i in start..<chars.length() {
    result.write_char(chars[i])
  }
  result.to_string()
}

fn string_contains(s : String, sub : String) -> Bool {
  s.find(sub) is Some(_)
}
