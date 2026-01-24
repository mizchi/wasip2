/// POSIX Types and Constants

// ============ Error Codes ============

pub(all) enum Errno {
  EPERM    // Operation not permitted
  ENOENT   // No such file or directory
  ESRCH    // No such process
  EINTR    // Interrupted system call
  EIO      // I/O error
  ENXIO    // No such device or address
  E2BIG    // Argument list too long
  ENOEXEC  // Exec format error
  EBADF    // Bad file descriptor
  ECHILD   // No child processes
  EAGAIN   // Resource temporarily unavailable
  ENOMEM   // Out of memory
  EACCES   // Permission denied
  EFAULT   // Bad address
  EBUSY    // Device or resource busy
  EEXIST   // File exists
  EXDEV    // Cross-device link
  ENODEV   // No such device
  ENOTDIR  // Not a directory
  EISDIR   // Is a directory
  EINVAL   // Invalid argument
  ENFILE   // File table overflow
  EMFILE   // Too many open files
  ENOTTY   // Not a typewriter
  EFBIG    // File too large
  ENOSPC   // No space left on device
  ESPIPE   // Illegal seek
  EROFS    // Read-only file system
  EMLINK   // Too many links
  EPIPE    // Broken pipe
  EDOM     // Math argument out of domain
  ERANGE   // Math result not representable
  EDEADLK  // Resource deadlock would occur
  ENAMETOOLONG  // File name too long
  ENOLCK   // No record locks available
  ENOSYS   // Function not implemented
  ENOTEMPTY  // Directory not empty
  ELOOP    // Too many symbolic links
  ETIMEDOUT  // Connection timed out
  ECONNREFUSED  // Connection refused
} derive(Show, Eq)

pub fn Errno::code(self : Errno) -> Int {
  match self {
    EPERM => 1
    ENOENT => 2
    ESRCH => 3
    EINTR => 4
    EIO => 5
    ENXIO => 6
    E2BIG => 7
    ENOEXEC => 8
    EBADF => 9
    ECHILD => 10
    EAGAIN => 11
    ENOMEM => 12
    EACCES => 13
    EFAULT => 14
    EBUSY => 16
    EEXIST => 17
    EXDEV => 18
    ENODEV => 19
    ENOTDIR => 20
    EISDIR => 21
    EINVAL => 22
    ENFILE => 23
    EMFILE => 24
    ENOTTY => 25
    EFBIG => 27
    ENOSPC => 28
    ESPIPE => 29
    EROFS => 30
    EMLINK => 31
    EPIPE => 32
    EDOM => 33
    ERANGE => 34
    EDEADLK => 35
    ENAMETOOLONG => 36
    ENOLCK => 37
    ENOSYS => 38
    ENOTEMPTY => 39
    ELOOP => 40
    ETIMEDOUT => 110
    ECONNREFUSED => 111
  }
}

// ============ File Descriptor ============

/// File descriptor (non-negative integer)
pub struct Fd(Int) derive(Show, Eq, Compare, Hash)

pub fn Fd::to_int(self : Fd) -> Int {
  self.0
}

pub fn Fd::from_int(n : Int) -> Fd {
  Fd(n)
}

/// Standard file descriptors
pub fn stdin_fileno() -> Fd { Fd(0) }
pub fn stdout_fileno() -> Fd { Fd(1) }
pub fn stderr_fileno() -> Fd { Fd(2) }

// ============ Open Flags ============

/// Flags for open()
pub(all) enum OpenFlag {
  O_RDONLY    // Read only
  O_WRONLY    // Write only
  O_RDWR      // Read and write
  O_CREAT     // Create if not exists
  O_EXCL      // Fail if exists (with O_CREAT)
  O_TRUNC     // Truncate to zero length
  O_APPEND    // Append mode
  O_NONBLOCK  // Non-blocking mode
  O_SYNC      // Synchronous writes
  O_DIRECTORY // Must be a directory
  O_NOFOLLOW  // Don't follow symlinks
  O_CLOEXEC   // Close on exec
} derive(Show, Eq)

/// Open flags as a set
pub struct OpenFlags {
  flags : Array[OpenFlag]
}

pub fn OpenFlags::new() -> OpenFlags {
  { flags: [], }
}

pub fn OpenFlags::from(flags : Array[OpenFlag]) -> OpenFlags {
  { flags, }
}

pub fn OpenFlags::has(self : OpenFlags, flag : OpenFlag) -> Bool {
  self.flags.contains(flag)
}

pub fn OpenFlags::add(self : OpenFlags, flag : OpenFlag) -> OpenFlags {
  if not(self.has(flag)) {
    self.flags.push(flag)
  }
  self
}

pub fn OpenFlags::is_readable(self : OpenFlags) -> Bool {
  self.has(O_RDONLY) || self.has(O_RDWR)
}

pub fn OpenFlags::is_writable(self : OpenFlags) -> Bool {
  self.has(O_WRONLY) || self.has(O_RDWR)
}

// ============ File Mode (Permissions) ============

/// File permission bits
pub struct FileMode {
  bits : Int
}

// Permission constants
pub fn s_irwxu() -> Int { 0o700 }  // User: rwx
pub fn s_irusr() -> Int { 0o400 }  // User: read
pub fn s_iwusr() -> Int { 0o200 }  // User: write
pub fn s_ixusr() -> Int { 0o100 }  // User: execute

pub fn s_irwxg() -> Int { 0o070 }  // Group: rwx
pub fn s_irgrp() -> Int { 0o040 }  // Group: read
pub fn s_iwgrp() -> Int { 0o020 }  // Group: write
pub fn s_ixgrp() -> Int { 0o010 }  // Group: execute

pub fn s_irwxo() -> Int { 0o007 }  // Other: rwx
pub fn s_iroth() -> Int { 0o004 }  // Other: read
pub fn s_iwoth() -> Int { 0o002 }  // Other: write
pub fn s_ixoth() -> Int { 0o001 }  // Other: execute

pub fn FileMode::new(bits : Int) -> FileMode {
  { bits, }
}

pub fn FileMode::default_file() -> FileMode {
  FileMode::new(0o644)  // rw-r--r--
}

pub fn FileMode::default_dir() -> FileMode {
  FileMode::new(0o755)  // rwxr-xr-x
}

pub fn FileMode::to_int(self : FileMode) -> Int {
  self.bits
}

pub fn FileMode::has(self : FileMode, perm : Int) -> Bool {
  (self.bits.land(perm)) == perm
}

// ============ Seek Whence ============

pub(all) enum Whence {
  SEEK_SET  // From beginning
  SEEK_CUR  // From current position
  SEEK_END  // From end
} derive(Show, Eq)

// ============ File Type ============

pub(all) enum FileType {
  S_IFREG   // Regular file
  S_IFDIR   // Directory
  S_IFLNK   // Symbolic link
  S_IFCHR   // Character device
  S_IFBLK   // Block device
  S_IFIFO   // FIFO (named pipe)
  S_IFSOCK  // Socket
} derive(Show, Eq)

// ============ Stat Structure ============

/// File status information
pub struct Stat {
  st_dev : Int        // Device ID
  st_ino : Int        // Inode number
  st_mode : FileMode  // File mode (type + permissions)
  st_nlink : Int      // Number of hard links
  st_uid : Int        // User ID of owner
  st_gid : Int        // Group ID of owner
  st_rdev : Int       // Device ID (if special file)
  st_size : Int64     // Total size in bytes
  st_blksize : Int    // Block size for I/O
  st_blocks : Int64   // Number of 512B blocks
  st_atime : Int64    // Last access time
  st_mtime : Int64    // Last modification time
  st_ctime : Int64    // Last status change time
  st_type : FileType  // File type
}

pub fn Stat::new_file(size : Int64, mode : FileMode, mtime : Int64) -> Stat {
  {
    st_dev: 0,
    st_ino: 0,
    st_mode: mode,
    st_nlink: 1,
    st_uid: 0,
    st_gid: 0,
    st_rdev: 0,
    st_size: size,
    st_blksize: 4096,
    st_blocks: (size + 511L) / 512L,
    st_atime: mtime,
    st_mtime: mtime,
    st_ctime: mtime,
    st_type: S_IFREG,
  }
}

pub fn Stat::new_dir(mode : FileMode, mtime : Int64) -> Stat {
  {
    st_dev: 0,
    st_ino: 0,
    st_mode: mode,
    st_nlink: 2,
    st_uid: 0,
    st_gid: 0,
    st_rdev: 0,
    st_size: 4096L,
    st_blksize: 4096,
    st_blocks: 8L,
    st_atime: mtime,
    st_mtime: mtime,
    st_ctime: mtime,
    st_type: S_IFDIR,
  }
}

pub fn Stat::new_symlink(target_len : Int, mtime : Int64) -> Stat {
  {
    st_dev: 0,
    st_ino: 0,
    st_mode: FileMode::new(0o777),
    st_nlink: 1,
    st_uid: 0,
    st_gid: 0,
    st_rdev: 0,
    st_size: target_len.to_int64(),
    st_blksize: 4096,
    st_blocks: 0L,
    st_atime: mtime,
    st_mtime: mtime,
    st_ctime: mtime,
    st_type: S_IFLNK,
  }
}

pub fn Stat::is_file(self : Stat) -> Bool {
  self.st_type == S_IFREG
}

pub fn Stat::is_dir(self : Stat) -> Bool {
  self.st_type == S_IFDIR
}

pub fn Stat::is_symlink(self : Stat) -> Bool {
  self.st_type == S_IFLNK
}

// ============ Process Types ============

/// Process ID
pub struct Pid(Int) derive(Show, Eq, Compare, Hash)

pub fn Pid::to_int(self : Pid) -> Int {
  self.0
}

pub fn Pid::from_int(n : Int) -> Pid {
  Pid(n)
}

// ============ Time Types ============

/// Time in seconds and nanoseconds
pub struct Timespec {
  tv_sec : Int64   // Seconds
  tv_nsec : Int64  // Nanoseconds (0-999999999)
}

pub fn Timespec::new(sec : Int64, nsec : Int64) -> Timespec {
  { tv_sec: sec, tv_nsec: nsec }
}

pub fn Timespec::from_seconds(sec : Int64) -> Timespec {
  { tv_sec: sec, tv_nsec: 0L }
}

pub fn Timespec::from_millis(ms : Int64) -> Timespec {
  { tv_sec: ms / 1000L, tv_nsec: (ms % 1000L) * 1000000L }
}

pub fn Timespec::to_millis(self : Timespec) -> Int64 {
  self.tv_sec * 1000L + self.tv_nsec / 1000000L
}

pub fn Timespec::to_nanos(self : Timespec) -> Int64 {
  self.tv_sec * 1000000000L + self.tv_nsec
}

/// Clock IDs for clock_gettime
pub(all) enum ClockId {
  CLOCK_REALTIME           // Wall clock time
  CLOCK_MONOTONIC          // Monotonic time since boot
  CLOCK_PROCESS_CPUTIME_ID // CPU time for this process
  CLOCK_THREAD_CPUTIME_ID  // CPU time for this thread
} derive(Show, Eq)

// ============ Pipe ============

/// Pipe file descriptors
pub struct PipeFds {
  read_fd : Fd   // Read end
  write_fd : Fd  // Write end
}
