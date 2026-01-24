/// Backend abstraction for switching between sandbox (MemFS) and real WASI

/// Backend mode
pub(all) enum BackendMode {
  Sandbox    // Use MemFS (in-memory, isolated)
  Native     // Use real WASI filesystem
  WasiNative // Use WASI with host-enforced sandbox
} derive(Show, Eq)

/// Runtime configuration
pub struct RuntimeConfig {
  mode : BackendMode
  fs : MemFS?  // Only used in Sandbox mode
  wasi_config : WasiSandboxConfig?  // Only used in WasiNative mode
}

pub fn RuntimeConfig::sandbox() -> RuntimeConfig {
  { mode: Sandbox, fs: Some(MemFS::default()), wasi_config: None }
}

pub fn RuntimeConfig::sandbox_with(fs : MemFS) -> RuntimeConfig {
  { mode: Sandbox, fs: Some(fs), wasi_config: None }
}

pub fn RuntimeConfig::native() -> RuntimeConfig {
  { mode: Native, fs: None, wasi_config: None }
}

/// Create a WASI-native configuration with host-enforced sandbox
pub fn RuntimeConfig::wasi_native() -> RuntimeConfig {
  { mode: WasiNative, fs: None, wasi_config: Some(WasiSandboxConfig::default()) }
}

/// Create a WASI-native configuration with custom config
pub fn RuntimeConfig::wasi_native_with(config : WasiSandboxConfig) -> RuntimeConfig {
  { mode: WasiNative, fs: None, wasi_config: Some(config) }
}

pub fn RuntimeConfig::get_fs(self : RuntimeConfig) -> MemFS? {
  self.fs
}

pub fn RuntimeConfig::get_wasi_config(self : RuntimeConfig) -> WasiSandboxConfig? {
  self.wasi_config
}

pub fn RuntimeConfig::is_sandbox(self : RuntimeConfig) -> Bool {
  match self.mode {
    Sandbox => true
    _ => false
  }
}

pub fn RuntimeConfig::is_native(self : RuntimeConfig) -> Bool {
  match self.mode {
    Native => true
    _ => false
  }
}

pub fn RuntimeConfig::is_wasi_native(self : RuntimeConfig) -> Bool {
  match self.mode {
    WasiNative => true
    _ => false
  }
}

/// Create a PosixContext with the given runtime configuration
pub fn PosixContext::with_config(config : RuntimeConfig) -> PosixContext {
  match config.mode {
    Sandbox => {
      match config.fs {
        Some(fs) => PosixContext::new(fs)
        None => PosixContext::new(MemFS::default())
      }
    }
    Native => {
      // For now, fallback to sandbox mode
      // Future: use real WASI filesystem
      PosixContext::new(MemFS::default())
    }
    WasiNative => {
      // WASI-native mode with host-enforced sandbox
      // Creates a MemFS that can be populated from host mappings
      PosixContext::new(MemFS::default())
    }
  }
}

/// Create a WasiSandbox with the given runtime configuration
pub fn WasiSandbox::with_config(config : RuntimeConfig) -> WasiSandbox {
  match config.wasi_config {
    Some(wasi_config) => WasiSandbox::new(wasi_config)
    None => WasiSandbox::new(WasiSandboxConfig::default())
  }
}
