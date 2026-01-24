///|
/// Benchmarks for memfs, sandbox, and wasi_sandbox layers

// ============ MemFS Benchmarks ============

///|
test "bench: MemFS write small file" (b : @bench.T) {
  let fs = MemFS::new()
  let result = b.bench(fn() {
    try { fs.write_string("/test.txt", "hello world") } catch { _ => () }
  })
  b.keep(result)
}

///|
test "bench: MemFS write large file" (b : @bench.T) {
  let fs = MemFS::new()
  let data = String::make(1024 * 10, 'x')  // 10KB
  let result = b.bench(fn() {
    try { fs.write_string("/large.txt", data) } catch { _ => () }
  })
  b.keep(result)
}

///|
test "bench: MemFS read file" (b : @bench.T) {
  let fs = MemFS::new()
  fs.write_string("/test.txt", "hello world")
  let result = b.bench(fn() {
    let _ = try { fs.read_string("/test.txt") } catch { _ => "" }
  })
  b.keep(result)
}

///|
test "bench: MemFS mkdir" (b : @bench.T) {
  let fs = MemFS::new()
  let mut i = 0
  let result = b.bench(fn() {
    try { fs.mkdir("/dir" + i.to_string()) } catch { _ => () }
    i = i + 1
  })
  b.keep(result)
}

///|
test "bench: MemFS exists check" (b : @bench.T) {
  let fs = MemFS::new()
  fs.write_string("/test.txt", "hello")
  let result = b.bench(fn() {
    let _ = fs.exists("/test.txt")
  })
  b.keep(result)
}

///|
test "bench: MemFS path resolution" (b : @bench.T) {
  let fs = MemFS::new()
  fs.mkdir("/a")
  fs.mkdir("/a/b")
  fs.mkdir("/a/b/c")
  fs.write_string("/a/b/c/file.txt", "data")
  let result = b.bench(fn() {
    let _ = try { fs.resolve_path("/a/b/../b/c/./file.txt") } catch { _ => "" }
  })
  b.keep(result)
}

// ============ PosixContext Benchmarks ============

///|
test "bench: PosixContext open/close" (b : @bench.T) {
  let ctx = PosixContext::default()
  ctx.get_fs().write_string("/test.txt", "hello")
  let result = b.bench(fn() {
    try {
      let fd = ctx.open("/test.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
      ctx.close(fd)
    } catch { _ => () }
  })
  b.keep(result)
}

///|
test "bench: PosixContext read" (b : @bench.T) {
  let ctx = PosixContext::default()
  ctx.get_fs().write_string("/test.txt", "hello world test data")
  let fd = ctx.open("/test.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
  let result = b.bench(fn() {
    try {
      let _ = ctx.lseek(fd, 0L, SEEK_SET)
      let _ = ctx.read(fd, 100)
    } catch { _ => () }
  })
  b.keep(result)
}

///|
test "bench: PosixContext write" (b : @bench.T) {
  let ctx = PosixContext::default()
  let fd = ctx.open("/test.txt", OpenFlags::from([O_CREAT, O_RDWR]), FileMode::default_file())
  let data = b"hello world"
  let result = b.bench(fn() {
    let _ = try { ctx.write(fd, data) } catch { _ => 0 }
  })
  b.keep(result)
}

///|
test "bench: PosixContext resolve_path" (b : @bench.T) {
  let ctx = PosixContext::default()
  let result = b.bench(fn() {
    let _ = ctx.resolve_path("./a/b/../c/./d")
  })
  b.keep(result)
}

///|
test "bench: PosixContext stat" (b : @bench.T) {
  let ctx = PosixContext::default()
  ctx.get_fs().write_string("/test.txt", "hello")
  let result = b.bench(fn() {
    try { let _ = ctx.stat("/test.txt") } catch { _ => () }
  })
  b.keep(result)
}

// ============ Sandbox Benchmarks ============

///|
test "bench: Sandbox open with capability check" (b : @bench.T) {
  let sandbox = Sandbox::new(Capabilities::unrestricted())
  sandbox.get_ctx().get_fs().write_string("/test.txt", "hello")
  let result = b.bench(fn() {
    try {
      let fd = sandbox.open("/test.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
      sandbox.close(fd)
    } catch { _ => () }
  })
  b.keep(result)
}

///|
test "bench: Sandbox path check allowed" (b : @bench.T) {
  let caps = Capabilities::build_sandbox()
  let sandbox = Sandbox::new(caps)
  // Create /tmp directory
  sandbox.get_ctx().get_fs().mkdir("/tmp")
  let result = b.bench(fn() {
    // This will check if path is in allowed list
    let _ = try {
      sandbox.open("/tmp/test.txt", OpenFlags::from([O_CREAT, O_RDWR]), FileMode::default_file())
    } catch {
      _ => Fd(0)
    }
  })
  b.keep(result)
}

///|
test "bench: Sandbox capability check overhead" (b : @bench.T) {
  // Measure overhead of capability checks vs raw MemFS
  let sandbox = Sandbox::new(Capabilities::unrestricted())
  let ctx = sandbox.get_ctx()
  ctx.get_fs().write_string("/test.txt", "hello")

  // With sandbox (capability checks)
  let result = b.bench(fn() {
    try {
      let fd = sandbox.open("/test.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
      let _ = sandbox.read(fd, 100)
      sandbox.close(fd)
    } catch { _ => () }
  })
  b.keep(result)
}

///|
test "bench: Raw MemFS (no sandbox)" (b : @bench.T) {
  // Baseline without sandbox for comparison
  let ctx = PosixContext::default()
  ctx.get_fs().write_string("/test.txt", "hello")

  let result = b.bench(fn() {
    try {
      let fd = ctx.open("/test.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
      let _ = ctx.read(fd, 100)
      ctx.close(fd)
    } catch { _ => () }
  })
  b.keep(result)
}

// ============ WasiSandbox Benchmarks ============

///|
test "bench: WasiSandbox open with mapping" (b : @bench.T) {
  let config = WasiSandboxConfig::default()
    .with_caps(Capabilities::unrestricted())
    .with_path_mapping("/sandbox", "/tmp")
  let wasi = WasiSandbox::new(config)
  wasi.get_sandbox().get_ctx().get_fs().mkdir("/tmp")
  wasi.get_sandbox().get_ctx().get_fs().write_string("/tmp/test.txt", "hello")

  let result = b.bench(fn() {
    try {
      let fd = wasi.open("/sandbox/test.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
      wasi.close(fd)
    } catch { _ => () }
  })
  b.keep(result)
}

///|
test "bench: WasiSandbox path mapping" (b : @bench.T) {
  let config = WasiSandboxConfig::default()
    .with_path_mapping("/sandbox", "/tmp/sandbox")
    .with_path_mapping("/home", "/tmp/home")
    .with_path_mapping("/app", "/var/app")
  let wasi = WasiSandbox::new(config)

  let result = b.bench(fn() {
    let _ = wasi.map_path("/sandbox/deep/nested/path/file.txt")
  })
  b.keep(result)
}

///|
test "bench: WasiSandbox host check" (b : @bench.T) {
  let config = WasiSandboxConfig::default()
    .with_network(true)
    .with_allowed_hosts(["localhost", "example.com", "api.example.com", "cdn.example.org"])
  let wasi = WasiSandbox::new(config)

  let result = b.bench(fn() {
    let _ = wasi.check_host("api.example.com")
  })
  b.keep(result)
}

///|
test "bench: WasiSandbox full operation" (b : @bench.T) {
  // Full WASI sandbox operation: map path + capability check + open + read + close
  let config = WasiSandboxConfig::default()
    .with_caps(Capabilities::unrestricted())
    .with_path_mapping("/sandbox", "/tmp")
  let wasi = WasiSandbox::new(config)
  wasi.get_sandbox().get_ctx().get_fs().mkdir("/tmp")
  wasi.get_sandbox().get_ctx().get_fs().write_string("/tmp/test.txt", "hello world data")

  let result = b.bench(fn() {
    try {
      let fd = wasi.open("/sandbox/test.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
      let _ = wasi.read(fd, 100)
      wasi.close(fd)
    } catch { _ => () }
  })
  b.keep(result)
}

// ============ Capabilities Benchmarks ============

///|
test "bench: Capabilities creation" (b : @bench.T) {
  let result = b.bench(fn() {
    let _ = Capabilities::build_sandbox()
  })
  b.keep(result)
}

///|
test "bench: Capabilities with_allowed_paths" (b : @bench.T) {
  let caps = Capabilities::build_sandbox()
  let result = b.bench(fn() {
    let _ = caps.with_allowed_paths(["/tmp", "/home", "/var", "/sandbox", "/app"])
  })
  b.keep(result)
}

// ============ Comparison: Layer Overhead ============

///|
test "bench: Layer 0 - Direct MemFS" (b : @bench.T) {
  let fs = MemFS::new()
  fs.write_string("/test.txt", "benchmark data")
  let result = b.bench(fn() {
    let _ = try { fs.read_string("/test.txt") } catch { _ => "" }
  })
  b.keep(result)
}

///|
test "bench: Layer 1 - PosixContext" (b : @bench.T) {
  let ctx = PosixContext::default()
  ctx.get_fs().write_string("/test.txt", "benchmark data")
  let fd = ctx.open("/test.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
  let result = b.bench(fn() {
    try {
      let _ = ctx.lseek(fd, 0L, SEEK_SET)
      let _ = ctx.read(fd, 100)
    } catch { _ => () }
  })
  b.keep(result)
}

///|
test "bench: Layer 2 - Sandbox" (b : @bench.T) {
  let sandbox = Sandbox::new(Capabilities::unrestricted())
  sandbox.get_ctx().get_fs().write_string("/test.txt", "benchmark data")
  let fd = sandbox.open("/test.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
  let result = b.bench(fn() {
    try {
      // Re-seek and read
      let _ = sandbox.get_ctx().lseek(fd, 0L, SEEK_SET)
      let _ = sandbox.read(fd, 100)
    } catch { _ => () }
  })
  b.keep(result)
}

///|
test "bench: Layer 3 - WasiSandbox" (b : @bench.T) {
  let config = WasiSandboxConfig::default().with_caps(Capabilities::unrestricted())
  let wasi = WasiSandbox::new(config)
  wasi.get_sandbox().get_ctx().get_fs().write_string("/test.txt", "benchmark data")
  let fd = wasi.open("/test.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
  let result = b.bench(fn() {
    try {
      let _ = wasi.get_sandbox().get_ctx().lseek(fd, 0L, SEEK_SET)
      let _ = wasi.read(fd, 100)
    } catch { _ => () }
  })
  b.keep(result)
}
