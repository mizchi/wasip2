/// Simple shell interpreter for testing POSIX layer

/// Command execution result
pub struct ExecResult {
  exit_code : Int
  stdout : String
  stderr : String
}

/// Shell interpreter
pub struct Shell {
  ctx : PosixContext
  commands : Map[String, (PosixContext, Array[String], StringBuilder, StringBuilder) -> Int]
  mut last_exit_code : Int
}

pub fn Shell::new(ctx : PosixContext) -> Shell {
  let shell : Shell = {
    ctx,
    commands: {},
    last_exit_code: 0,
  }
  // Register built-in commands
  shell.register_builtins()
  shell
}

pub fn Shell::default() -> Shell {
  Shell::new(PosixContext::default())
}

fn Shell::register_builtins(self : Shell) -> Unit {
  self.commands.set("echo", cmd_echo)
  self.commands.set("cat", cmd_cat)
  self.commands.set("ls", cmd_ls)
  self.commands.set("pwd", cmd_pwd)
  self.commands.set("cd", cmd_cd)
  self.commands.set("mkdir", cmd_mkdir)
  self.commands.set("touch", cmd_touch)
  self.commands.set("rm", cmd_rm)
  self.commands.set("true", cmd_true)
  self.commands.set("false", cmd_false)
  self.commands.set("exit", cmd_exit)
  self.commands.set("export", cmd_export)
  self.commands.set("env", cmd_env)
}

/// Register a custom command
pub fn Shell::register(
  self : Shell,
  name : String,
  handler : (PosixContext, Array[String], StringBuilder, StringBuilder) -> Int
) -> Unit {
  self.commands.set(name, handler)
}

/// Execute a single command line
pub fn Shell::exec_line(self : Shell, line : String) -> ExecResult {
  let stdout = StringBuilder::new()
  let stderr = StringBuilder::new()

  let trimmed = trim_string(line)
  if trimmed.length() == 0 || trimmed.has_prefix("#") {
    return { exit_code: 0, stdout: "", stderr: "" }
  }

  let parts = parse_command_line(trimmed)
  if parts.length() == 0 {
    return { exit_code: 0, stdout: "", stderr: "" }
  }

  let cmd = parts[0]
  let args = array_slice(parts, 1, parts.length())

  let exit_code = match self.commands.get(cmd) {
    Some(handler) => handler(self.ctx, args, stdout, stderr)
    None => {
      stderr.write_string(cmd + ": command not found\n")
      127
    }
  }

  self.last_exit_code = exit_code
  {
    exit_code,
    stdout: stdout.to_string(),
    stderr: stderr.to_string(),
  }
}

/// Execute a script (multiple lines)
pub fn Shell::exec_script(self : Shell, script : String) -> ExecResult {
  let stdout = StringBuilder::new()
  let stderr = StringBuilder::new()
  let mut last_code = 0

  let lines = split_lines(script)
  for line in lines {
    let result = self.exec_line(line)
    stdout.write_string(result.stdout)
    stderr.write_string(result.stderr)
    last_code = result.exit_code
  }

  { exit_code: last_code, stdout: stdout.to_string(), stderr: stderr.to_string() }
}

/// Get the context
pub fn Shell::get_ctx(self : Shell) -> PosixContext {
  self.ctx
}

// ============ Built-in Commands ============

fn cmd_echo(
  _ctx : PosixContext,
  args : Array[String],
  stdout : StringBuilder,
  _stderr : StringBuilder
) -> Int {
  stdout.write_string(args.join(" "))
  stdout.write_string("\n")
  0
}

fn cmd_cat(
  ctx : PosixContext,
  args : Array[String],
  stdout : StringBuilder,
  stderr : StringBuilder
) -> Int {
  if args.length() == 0 {
    return 0
  }
  for path in args {
    let abs_path = ctx.resolve_path(path)
    try {
      let content = ctx.get_fs().read_string(abs_path)
      stdout.write_string(content)
    } catch {
      _ => {
        stderr.write_string("cat: " + path + ": No such file or directory\n")
        return 1
      }
    }
  }
  0
}

fn cmd_ls(
  ctx : PosixContext,
  args : Array[String],
  stdout : StringBuilder,
  stderr : StringBuilder
) -> Int {
  let path = if args.length() > 0 { args[0] } else { "." }
  let abs_path = ctx.resolve_path(path)

  try {
    let entries = ctx.get_fs().readdir(abs_path)
    for entry in entries {
      stdout.write_string(entry)
      stdout.write_string("\n")
    }
    0
  } catch {
    _ => {
      stderr.write_string("ls: cannot access '" + path + "'\n")
      1
    }
  }
}

fn cmd_pwd(
  ctx : PosixContext,
  _args : Array[String],
  stdout : StringBuilder,
  _stderr : StringBuilder
) -> Int {
  stdout.write_string(ctx.getcwd())
  stdout.write_string("\n")
  0
}

fn cmd_cd(
  ctx : PosixContext,
  args : Array[String],
  _stdout : StringBuilder,
  stderr : StringBuilder
) -> Int {
  let path = if args.length() > 0 { args[0] } else { "~" }
  try {
    ctx.chdir(path)
    0
  } catch {
    _ => {
      stderr.write_string("cd: " + path + ": No such directory\n")
      1
    }
  }
}

fn cmd_mkdir(
  ctx : PosixContext,
  args : Array[String],
  _stdout : StringBuilder,
  stderr : StringBuilder
) -> Int {
  if args.length() == 0 {
    stderr.write_string("mkdir: missing operand\n")
    return 1
  }
  for path in args {
    let abs_path = ctx.resolve_path(path)
    try {
      ctx.get_fs().mkdir(abs_path)
    } catch {
      _ => {
        stderr.write_string("mkdir: cannot create directory '" + path + "'\n")
        return 1
      }
    }
  }
  0
}

fn cmd_touch(
  ctx : PosixContext,
  args : Array[String],
  _stdout : StringBuilder,
  stderr : StringBuilder
) -> Int {
  if args.length() == 0 {
    stderr.write_string("touch: missing operand\n")
    return 1
  }
  for path in args {
    let abs_path = ctx.resolve_path(path)
    if not(ctx.get_fs().exists(abs_path)) {
      try {
        ctx.get_fs().write_string(abs_path, "")
      } catch {
        _ => {
          stderr.write_string("touch: cannot touch '" + path + "'\n")
          return 1
        }
      }
    }
  }
  0
}

fn cmd_rm(
  ctx : PosixContext,
  args : Array[String],
  _stdout : StringBuilder,
  stderr : StringBuilder
) -> Int {
  if args.length() == 0 {
    stderr.write_string("rm: missing operand\n")
    return 1
  }
  for path in args {
    let abs_path = ctx.resolve_path(path)
    try {
      ctx.get_fs().remove(abs_path)
    } catch {
      _ => {
        stderr.write_string("rm: cannot remove '" + path + "'\n")
        return 1
      }
    }
  }
  0
}

fn cmd_true(
  _ctx : PosixContext,
  _args : Array[String],
  _stdout : StringBuilder,
  _stderr : StringBuilder
) -> Int {
  0
}

fn cmd_false(
  _ctx : PosixContext,
  _args : Array[String],
  _stdout : StringBuilder,
  _stderr : StringBuilder
) -> Int {
  1
}

fn cmd_exit(
  _ctx : PosixContext,
  args : Array[String],
  _stdout : StringBuilder,
  _stderr : StringBuilder
) -> Int {
  if args.length() > 0 {
    parse_int_simple(args[0])
  } else {
    0
  }
}

fn parse_int_simple(s : String) -> Int {
  let mut result = 0
  let mut negative = false
  let mut started = false

  for c in s {
    if c == '-' && not(started) {
      negative = true
      started = true
    } else if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
      started = true
    }
  }

  if negative { -result } else { result }
}

fn cmd_export(
  ctx : PosixContext,
  args : Array[String],
  _stdout : StringBuilder,
  stderr : StringBuilder
) -> Int {
  for arg in args {
    match arg.find("=") {
      Some(i) => {
        let name = substring_range(arg, 0, i)
        let value = substring_range(arg, i + 1, arg.length())
        ctx.setenv(name, value)
      }
      None => {
        stderr.write_string("export: invalid argument: " + arg + "\n")
        return 1
      }
    }
  }
  0
}

fn cmd_env(
  ctx : PosixContext,
  _args : Array[String],
  stdout : StringBuilder,
  _stderr : StringBuilder
) -> Int {
  // Print known environment variables
  let vars = ["HOME", "PATH", "USER", "SHELL", "PWD"]
  for name in vars {
    match ctx.getenv(name) {
      Some(value) => {
        stdout.write_string(name + "=" + value + "\n")
      }
      None => ()
    }
  }
  0
}

// ============ Helpers ============

fn parse_command_line(line : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  let mut in_quote = false
  let mut quote_char : Char = '"'

  for c in line {
    if in_quote {
      if c == quote_char {
        in_quote = false
      } else {
        current.write_char(c)
      }
    } else if c == '"' || c == '\'' {
      in_quote = true
      quote_char = c
    } else if c == ' ' || c == '\t' {
      if current.to_string().length() > 0 {
        result.push(current.to_string())
        current.reset()
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

fn split_lines(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()

  for c in s {
    if c == '\n' {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }

  if current.to_string().length() > 0 {
    result.push(current.to_string())
  }

  result
}

fn trim_string(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length()

  // Trim leading whitespace
  while start < end {
    let c = chars[start]
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      start += 1
    } else {
      break
    }
  }

  // Trim trailing whitespace
  while end > start {
    let c = chars[end - 1]
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      end -= 1
    } else {
      break
    }
  }

  substring_range(s, start, end)
}

fn array_slice(arr : Array[String], start : Int, end : Int) -> Array[String] {
  let result : Array[String] = []
  for i in start..<end {
    result.push(arr[i])
  }
  result
}

fn substring_range(s : String, start : Int, end : Int) -> String {
  let chars = s.to_array()
  let result = StringBuilder::new()
  for i in start..<end {
    if i < chars.length() {
      result.write_char(chars[i])
    }
  }
  result.to_string()
}
