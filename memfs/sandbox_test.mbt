// Sandbox security tests

test "unrestricted sandbox allows all" {
  let sandbox = Sandbox::new(Capabilities::unrestricted())

  // Should be able to create and write
  let fd = sandbox.open("/test.txt", OpenFlags::from([O_RDWR, O_CREAT]), FileMode::default_file())
  let written = sandbox.write(fd, Bytes::from_array([b'h', b'i']))
  assert_eq(written, 2)
  sandbox.close(fd)
}

test "read_only sandbox blocks writes" {
  let sandbox = Sandbox::new(Capabilities::read_only())

  // Pre-create a file
  sandbox.get_ctx().get_fs().write_string("/test.txt", "content")

  // Can read
  let fd = sandbox.open("/test.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
  let data = sandbox.read(fd, 10)
  assert_eq(data.length(), 7)
  sandbox.close(fd)

  // Cannot write
  let result : Result[Fd, _] = try {
    Ok(sandbox.open("/new.txt", OpenFlags::from([O_WRONLY, O_CREAT]), FileMode::default_file()))
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

test "path restrictions" {
  let caps = Capabilities::unrestricted().with_allowed_paths(["/allowed"])
  let sandbox = Sandbox::new(caps)
  sandbox.get_ctx().get_fs().mkdir("/allowed")
  sandbox.get_ctx().get_fs().mkdir("/denied")

  // Can access allowed path
  sandbox.mkdir("/allowed/sub")
  assert_true(sandbox.get_ctx().get_fs().exists("/allowed/sub"))

  // Cannot access other paths
  let result : Result[Unit, _] = try {
    Ok(sandbox.mkdir("/denied/sub"))
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

test "denied paths have priority" {
  let caps = Capabilities::unrestricted()
    .with_allowed_paths(["/data"])
    .with_denied_paths(["/data/secret"])
  let sandbox = Sandbox::new(caps)
  sandbox.get_ctx().get_fs().mkdir("/data")
  sandbox.get_ctx().get_fs().mkdir("/data/secret")
  sandbox.get_ctx().get_fs().mkdir("/data/public")

  // Can access /data/public
  sandbox.mkdir("/data/public/sub")

  // Cannot access /data/secret even though /data is allowed
  let result : Result[Unit, _] = try {
    Ok(sandbox.mkdir("/data/secret/sub"))
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

test "command restrictions" {
  let caps = Capabilities::unrestricted().with_allowed_commands(["echo", "ls"])
  let sandbox = Sandbox::new(caps)

  // Allowed command
  let pid1 = sandbox.exec("echo", ["hello"])
  assert_true(pid1.to_int() > 0)

  // Denied command
  let result : Result[Pid, _] = try {
    Ok(sandbox.exec("rm", ["-rf", "/"]))
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

test "exec disabled" {
  let caps = Capabilities::unrestricted().with_exec(false)
  let sandbox = Sandbox::new(caps)

  let result : Result[Pid, _] = try {
    Ok(sandbox.exec("ls", []))
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

test "file size limit" {
  let caps = Capabilities::unrestricted().with_max_file_size(10)  // 10 bytes max
  let sandbox = Sandbox::new(caps)

  let fd = sandbox.open("/test.txt", OpenFlags::from([O_RDWR, O_CREAT]), FileMode::default_file())

  // Small write OK
  let written = sandbox.write(fd, Bytes::from_array([b'a', b'b', b'c']))
  assert_eq(written, 3)

  // Large write blocked
  let large_data = Bytes::make(20, b'x')
  let result : Result[Int, _] = try {
    Ok(sandbox.write(fd, large_data))
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))

  sandbox.close(fd)
}

test "max open files limit" {
  let caps = Capabilities::unrestricted().with_max_open_files(2)
  let sandbox = Sandbox::new(caps)

  // Create test files
  sandbox.get_ctx().get_fs().write_string("/a.txt", "a")
  sandbox.get_ctx().get_fs().write_string("/b.txt", "b")
  sandbox.get_ctx().get_fs().write_string("/c.txt", "c")

  // Open first two files OK
  let fd1 = sandbox.open("/a.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
  let fd2 = sandbox.open("/b.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())

  // Third file blocked
  let result : Result[Fd, _] = try {
    Ok(sandbox.open("/c.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file()))
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))

  // Close one, now can open another
  sandbox.close(fd1)
  let fd3 = sandbox.open("/c.txt", OpenFlags::from([O_RDONLY]), FileMode::default_file())
  ignore(fd3)

  sandbox.close(fd2)
}

test "path depth limit" {
  let caps = Capabilities::unrestricted().with_max_path_depth(3)  // /a/b/c max
  let sandbox = Sandbox::new(caps)

  // Setup directories
  sandbox.get_ctx().get_fs().mkdir_p("/a/b/c/d/e")

  // Shallow path OK
  sandbox.mkdir("/a/b/x")

  // Deep path blocked
  let result : Result[Unit, _] = try {
    Ok(sandbox.mkdir("/a/b/c/d/e/f"))
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

test "build sandbox preset" {
  let sandbox = Sandbox::new(Capabilities::build_sandbox())

  // Setup allowed directories
  sandbox.get_ctx().get_fs().mkdir("/tmp")
  sandbox.get_ctx().get_fs().mkdir("/build")
  sandbox.get_ctx().get_fs().mkdir("/src")

  // Can write to /tmp
  sandbox.mkdir("/tmp/output")
  assert_true(sandbox.get_ctx().get_fs().exists("/tmp/output"))

  // Can exec allowed commands
  let pid = sandbox.exec("moon", ["build"])
  assert_true(pid.to_int() > 0)

  // Cannot exec disallowed commands
  let result : Result[Pid, _] = try {
    Ok(sandbox.exec("curl", ["http://evil.com"]))
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

test "plugin sandbox preset" {
  let sandbox = Sandbox::new(Capabilities::plugin_sandbox())

  // Setup plugin directory
  sandbox.get_ctx().get_fs().mkdir("/tmp")
  sandbox.get_ctx().get_fs().mkdir("/tmp/plugin")

  // Can create in plugin dir
  sandbox.mkdir("/tmp/plugin/data")

  // Cannot delete (delete disabled)
  sandbox.get_ctx().get_fs().write_string("/tmp/plugin/file.txt", "test")
  let result : Result[Unit, _] = try {
    Ok(sandbox.remove("/tmp/plugin/file.txt"))
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))

  // Cannot exec (exec disabled)
  let exec_result : Result[Pid, _] = try {
    Ok(sandbox.exec("anything", []))
  } catch {
    e => Err(e)
  }
  assert_true(exec_result is Err(_))
}

test "delete restriction" {
  let caps = Capabilities::unrestricted().with_delete(false)
  let sandbox = Sandbox::new(caps)

  // Create file
  sandbox.get_ctx().get_fs().write_string("/test.txt", "content")

  // Cannot delete
  let result : Result[Unit, _] = try {
    Ok(sandbox.remove("/test.txt"))
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))

  // File still exists
  assert_true(sandbox.get_ctx().get_fs().exists("/test.txt"))
}
