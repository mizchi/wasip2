/// WASI-native Sandbox Layer
///
/// This module provides a sandbox abstraction that can work with
/// host-provided capabilities through WASI interfaces.
///
/// Architecture:
/// - Guest side: Uses this interface for capability checks
/// - Host side: Implements actual capability enforcement via wasmtime

/// WASI Sandbox mode
pub(all) enum WasiSandboxMode {
  /// Pure guest-side sandbox (MemFS only, no host interaction)
  GuestOnly
  /// Host-enforced sandbox (capabilities checked by host runtime)
  HostEnforced
  /// Hybrid mode (guest pre-check + host enforcement)
  Hybrid
} derive(Show, Eq)

/// WASI Sandbox configuration
pub struct WasiSandboxConfig {
  mode : WasiSandboxMode
  caps : Capabilities
  // Path mappings: guest path -> host path
  path_mappings : Array[(String, String)]
  // Environment variable whitelist (None = all allowed)
  env_whitelist : Array[String]?
  // Network capabilities
  allow_network : Bool
  allowed_hosts : Array[String]?  // None = all, Some([]) = none
  allowed_ports : Array[Int]?     // None = all, Some([]) = none
}

/// Create default WASI sandbox config
pub fn WasiSandboxConfig::default() -> WasiSandboxConfig {
  {
    mode: GuestOnly,
    caps: Capabilities::build_sandbox(),
    path_mappings: [],
    env_whitelist: None,
    allow_network: false,
    allowed_hosts: Some([]),
    allowed_ports: Some([]),
  }
}

/// Create a restricted WASI sandbox config
pub fn WasiSandboxConfig::restricted() -> WasiSandboxConfig {
  {
    mode: HostEnforced,
    caps: Capabilities::read_only(),
    path_mappings: [],
    env_whitelist: Some([]),
    allow_network: false,
    allowed_hosts: Some([]),
    allowed_ports: Some([]),
  }
}

/// Create a permissive WASI sandbox config for development
pub fn WasiSandboxConfig::permissive() -> WasiSandboxConfig {
  {
    mode: Hybrid,
    caps: Capabilities::unrestricted(),
    path_mappings: [("/sandbox", "/tmp/sandbox"), ("/home", "/tmp/home")],
    env_whitelist: None,
    allow_network: true,
    allowed_hosts: None,
    allowed_ports: None,
  }
}

/// Builder methods
pub fn WasiSandboxConfig::with_mode(
  self : WasiSandboxConfig,
  mode : WasiSandboxMode
) -> WasiSandboxConfig {
  {
    mode,
    caps: self.caps,
    path_mappings: self.path_mappings,
    env_whitelist: self.env_whitelist,
    allow_network: self.allow_network,
    allowed_hosts: self.allowed_hosts,
    allowed_ports: self.allowed_ports,
  }
}

pub fn WasiSandboxConfig::with_caps(
  self : WasiSandboxConfig,
  caps : Capabilities
) -> WasiSandboxConfig {
  {
    mode: self.mode,
    caps,
    path_mappings: self.path_mappings,
    env_whitelist: self.env_whitelist,
    allow_network: self.allow_network,
    allowed_hosts: self.allowed_hosts,
    allowed_ports: self.allowed_ports,
  }
}

pub fn WasiSandboxConfig::with_path_mapping(
  self : WasiSandboxConfig,
  guest_path : String,
  host_path : String
) -> WasiSandboxConfig {
  let mappings = self.path_mappings.copy()
  mappings.push((guest_path, host_path))
  {
    mode: self.mode,
    caps: self.caps,
    path_mappings: mappings,
    env_whitelist: self.env_whitelist,
    allow_network: self.allow_network,
    allowed_hosts: self.allowed_hosts,
    allowed_ports: self.allowed_ports,
  }
}

pub fn WasiSandboxConfig::with_network(
  self : WasiSandboxConfig,
  allow : Bool
) -> WasiSandboxConfig {
  {
    mode: self.mode,
    caps: self.caps,
    path_mappings: self.path_mappings,
    env_whitelist: self.env_whitelist,
    allow_network: allow,
    allowed_hosts: self.allowed_hosts,
    allowed_ports: self.allowed_ports,
  }
}

pub fn WasiSandboxConfig::with_allowed_hosts(
  self : WasiSandboxConfig,
  hosts : Array[String]
) -> WasiSandboxConfig {
  {
    mode: self.mode,
    caps: self.caps,
    path_mappings: self.path_mappings,
    env_whitelist: self.env_whitelist,
    allow_network: self.allow_network,
    allowed_hosts: Some(hosts),
    allowed_ports: self.allowed_ports,
  }
}

/// WASI Sandbox runtime
pub struct WasiSandbox {
  config : WasiSandboxConfig
  sandbox : Sandbox  // Underlying guest sandbox
}

pub fn WasiSandbox::new(config : WasiSandboxConfig) -> WasiSandbox {
  { config, sandbox: Sandbox::new(config.caps) }
}

pub fn WasiSandbox::with_fs(
  fs : MemFS,
  config : WasiSandboxConfig
) -> WasiSandbox {
  { config, sandbox: Sandbox::with_fs(fs, config.caps) }
}

/// Map guest path to host path
pub fn WasiSandbox::map_path(self : WasiSandbox, guest_path : String) -> String {
  for mapping in self.config.path_mappings {
    let (prefix, target) = mapping
    if guest_path.has_prefix(prefix) {
      // Replace prefix with target
      if guest_path.length() == prefix.length() {
        return target
      }
      let rest = wasi_substring_from(guest_path, prefix.length())
      return target + rest
    }
  }
  guest_path
}

/// Extract substring from start index to end of string
fn wasi_substring_from(s : String, start : Int) -> String {
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

/// Check if host is allowed for network access
pub fn WasiSandbox::check_host(
  self : WasiSandbox,
  host : String
) -> Bool {
  if not(self.config.allow_network) {
    return false
  }
  match self.config.allowed_hosts {
    None => true
    Some(allowed) => allowed.contains(host)
  }
}

/// Check if port is allowed for network access
pub fn WasiSandbox::check_port(self : WasiSandbox, port : Int) -> Bool {
  if not(self.config.allow_network) {
    return false
  }
  match self.config.allowed_ports {
    None => true
    Some(allowed) => allowed.contains(port)
  }
}

/// Check environment variable access
pub fn WasiSandbox::check_env(self : WasiSandbox, name : String) -> Bool {
  match self.config.env_whitelist {
    None => true
    Some(allowed) => allowed.contains(name)
  }
}

// ============ Sandboxed Operations (delegating to underlying Sandbox) ============

pub fn WasiSandbox::open(
  self : WasiSandbox,
  path : String,
  flags : OpenFlags,
  mode : FileMode
) -> Fd raise SandboxError {
  // Map path for host-enforced mode
  let mapped_path = match self.config.mode {
    HostEnforced | Hybrid => self.map_path(path)
    GuestOnly => path
  }
  self.sandbox.open(mapped_path, flags, mode)
}

pub fn WasiSandbox::close(self : WasiSandbox, fd : Fd) -> Unit raise SandboxError {
  self.sandbox.close(fd)
}

pub fn WasiSandbox::read(
  self : WasiSandbox,
  fd : Fd,
  count : Int
) -> Bytes raise SandboxError {
  self.sandbox.read(fd, count)
}

pub fn WasiSandbox::write(
  self : WasiSandbox,
  fd : Fd,
  data : Bytes
) -> Int raise SandboxError {
  self.sandbox.write(fd, data)
}

pub fn WasiSandbox::mkdir(self : WasiSandbox, path : String) -> Unit raise SandboxError {
  let mapped_path = match self.config.mode {
    HostEnforced | Hybrid => self.map_path(path)
    GuestOnly => path
  }
  self.sandbox.mkdir(mapped_path)
}

pub fn WasiSandbox::remove(self : WasiSandbox, path : String) -> Unit raise SandboxError {
  let mapped_path = match self.config.mode {
    HostEnforced | Hybrid => self.map_path(path)
    GuestOnly => path
  }
  self.sandbox.remove(mapped_path)
}

pub fn WasiSandbox::exec(
  self : WasiSandbox,
  cmd : String,
  args : Array[String]
) -> Pid raise SandboxError {
  self.sandbox.exec(cmd, args)
}

/// Get underlying sandbox
pub fn WasiSandbox::get_sandbox(self : WasiSandbox) -> Sandbox {
  self.sandbox
}

/// Get config
pub fn WasiSandbox::get_config(self : WasiSandbox) -> WasiSandboxConfig {
  self.config
}
