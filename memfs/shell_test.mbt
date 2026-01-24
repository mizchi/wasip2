// Shell integration tests

test "echo command" {
  let shell = Shell::default()
  let result = shell.exec_line("echo hello world")
  assert_eq(result.exit_code, 0)
  assert_eq(result.stdout, "hello world\n")
}

test "pwd command" {
  let shell = Shell::default()
  let result = shell.exec_line("pwd")
  assert_eq(result.exit_code, 0)
  assert_eq(result.stdout, "/\n")
}

test "mkdir and ls" {
  let shell = Shell::default()

  let r1 = shell.exec_line("mkdir /testdir")
  assert_eq(r1.exit_code, 0)

  let r2 = shell.exec_line("ls /")
  assert_eq(r2.exit_code, 0)
  assert_true(r2.stdout.find("testdir") is Some(_))
}

test "touch and cat" {
  let shell = Shell::default()

  ignore(shell.exec_line("touch /file.txt"))
  assert_true(shell.get_ctx().get_fs().exists("/file.txt"))

  // Write content via fs directly for now
  shell.get_ctx().get_fs().write_string("/file.txt", "content here")

  let result = shell.exec_line("cat /file.txt")
  assert_eq(result.exit_code, 0)
  assert_eq(result.stdout, "content here")
}

test "cd and pwd" {
  let shell = Shell::default()

  ignore(shell.exec_line("mkdir /subdir"))
  ignore(shell.exec_line("cd /subdir"))

  let result = shell.exec_line("pwd")
  assert_eq(result.stdout, "/subdir\n")
}

test "rm command" {
  let shell = Shell::default()

  ignore(shell.exec_line("touch /todelete.txt"))
  assert_true(shell.get_ctx().get_fs().exists("/todelete.txt"))

  ignore(shell.exec_line("rm /todelete.txt"))
  assert_false(shell.get_ctx().get_fs().exists("/todelete.txt"))
}

test "export and env" {
  let shell = Shell::default()

  ignore(shell.exec_line("export MY_VAR=my_value"))
  assert_eq(shell.get_ctx().getenv("MY_VAR"), Some("my_value"))
}

test "true and false" {
  let shell = Shell::default()

  let r1 = shell.exec_line("true")
  assert_eq(r1.exit_code, 0)

  let r2 = shell.exec_line("false")
  assert_eq(r2.exit_code, 1)
}

test "command not found" {
  let shell = Shell::default()
  let result = shell.exec_line("nonexistent_cmd")
  assert_eq(result.exit_code, 127)
  assert_true(result.stderr.find("command not found") is Some(_))
}

test "script execution" {
  let shell = Shell::default()

  let script =
    #|mkdir /project
    #|cd /project
    #|touch main.mbt
    #|touch lib.mbt
    #|pwd

  let result = shell.exec_script(script)
  assert_eq(result.exit_code, 0)
  assert_eq(result.stdout, "/project\n")

  // Verify files were created
  assert_true(shell.get_ctx().get_fs().exists("/project/main.mbt"))
  assert_true(shell.get_ctx().get_fs().exists("/project/lib.mbt"))
}

test "complex script" {
  let shell = Shell::default()

  let script =
    #|# Create project structure
    #|mkdir /app
    #|mkdir /app/src
    #|mkdir /app/test
    #|touch /app/src/main.mbt
    #|touch /app/test/main_test.mbt
    #|
    #|# List contents
    #|ls /app

  let result = shell.exec_script(script)
  assert_eq(result.exit_code, 0)
  assert_true(result.stdout.find("src") is Some(_))
  assert_true(result.stdout.find("test") is Some(_))
}

test "quoted arguments" {
  let shell = Shell::default()

  let result = shell.exec_line("echo \"hello world\" foo")
  assert_eq(result.stdout, "hello world foo\n")

  let result2 = shell.exec_line("echo 'single quotes'")
  assert_eq(result2.stdout, "single quotes\n")
}

test "custom command registration" {
  let shell = Shell::default()

  // Register a custom command
  shell.register("greet", fn(ctx, args, stdout, _stderr) {
    let name = if args.length() > 0 { args[0] } else { "world" }
    stdout.write_string("Hello, " + name + "!\n")
    ignore(ctx)
    0
  })

  let result = shell.exec_line("greet MoonBit")
  assert_eq(result.exit_code, 0)
  assert_eq(result.stdout, "Hello, MoonBit!\n")
}

test "home directory" {
  let shell = Shell::default()

  ignore(shell.exec_line("cd ~"))
  let result = shell.exec_line("pwd")
  assert_eq(result.stdout, "/home\n")
}

test "relative paths" {
  let shell = Shell::default()

  ignore(shell.exec_line("mkdir /base"))
  ignore(shell.exec_line("mkdir /base/sub"))
  ignore(shell.exec_line("cd /base"))
  ignore(shell.exec_line("touch sub/file.txt"))

  assert_true(shell.get_ctx().get_fs().exists("/base/sub/file.txt"))
}
