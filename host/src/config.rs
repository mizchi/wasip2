//! Sandbox configuration for the WASI host runtime

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Sandbox configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SandboxConfig {
    /// Allowed paths for file system access
    #[serde(default)]
    pub allowed_paths: Vec<PathMapping>,

    /// Denied paths (takes precedence over allowed_paths)
    #[serde(default)]
    pub denied_paths: Vec<String>,

    /// Whether to allow network access
    #[serde(default)]
    pub allow_network: bool,

    /// Allowed network hosts (None = all, empty = none)
    #[serde(default)]
    pub allowed_hosts: Option<Vec<String>>,

    /// Allowed network ports (None = all, empty = none)
    #[serde(default)]
    pub allowed_ports: Option<Vec<u16>>,

    /// Environment variables to pass to the guest
    #[serde(default)]
    pub env: Vec<(String, String)>,

    /// Environment variable whitelist (None = all)
    #[serde(default)]
    pub env_whitelist: Option<Vec<String>>,

    /// Maximum memory in bytes (None = unlimited)
    #[serde(default)]
    pub max_memory_bytes: Option<usize>,

    /// Maximum execution time in milliseconds (None = unlimited)
    #[serde(default)]
    pub max_exec_time_ms: Option<u64>,

    /// Maximum file size in bytes
    #[serde(default)]
    pub max_file_size: Option<usize>,

    /// Maximum total size of all files
    #[serde(default)]
    pub max_total_size: Option<usize>,

    /// Maximum open file handles
    #[serde(default)]
    pub max_open_files: Option<usize>,
}

/// Path mapping from guest to host
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PathMapping {
    /// Guest path (virtual path seen by WASM module)
    pub guest: String,
    /// Host path (real path on the host system)
    pub host: PathBuf,
    /// Whether the path is read-only
    #[serde(default)]
    pub read_only: bool,
}

impl Default for SandboxConfig {
    fn default() -> Self {
        Self {
            allowed_paths: vec![PathMapping {
                guest: "/sandbox".to_string(),
                host: PathBuf::from("/tmp/sandbox"),
                read_only: false,
            }],
            denied_paths: vec![
                "/etc".to_string(),
                "/bin".to_string(),
                "/usr".to_string(),
                "/var".to_string(),
            ],
            allow_network: false,
            allowed_hosts: Some(vec![]),
            allowed_ports: Some(vec![]),
            env: vec![],
            env_whitelist: None,
            max_memory_bytes: Some(256 * 1024 * 1024), // 256MB
            max_exec_time_ms: Some(60_000),            // 1 minute
            max_file_size: Some(10 * 1024 * 1024),     // 10MB
            max_total_size: Some(100 * 1024 * 1024),   // 100MB
            max_open_files: Some(64),
        }
    }
}

impl SandboxConfig {
    /// Create a permissive configuration for development
    pub fn permissive() -> Self {
        Self {
            allowed_paths: vec![
                PathMapping {
                    guest: "/".to_string(),
                    host: PathBuf::from("/"),
                    read_only: false,
                },
            ],
            denied_paths: vec![],
            allow_network: true,
            allowed_hosts: None,
            allowed_ports: None,
            env: std::env::vars().collect(),
            env_whitelist: None,
            max_memory_bytes: None,
            max_exec_time_ms: None,
            max_file_size: None,
            max_total_size: None,
            max_open_files: None,
        }
    }

    /// Create a restrictive configuration for untrusted code
    pub fn restrictive() -> Self {
        Self {
            allowed_paths: vec![],
            denied_paths: vec!["/".to_string()],
            allow_network: false,
            allowed_hosts: Some(vec![]),
            allowed_ports: Some(vec![]),
            env: vec![],
            env_whitelist: Some(vec![]),
            max_memory_bytes: Some(16 * 1024 * 1024), // 16MB
            max_exec_time_ms: Some(5_000),            // 5 seconds
            max_file_size: Some(1024 * 1024),         // 1MB
            max_total_size: Some(10 * 1024 * 1024),   // 10MB
            max_open_files: Some(8),
        }
    }

    /// Load configuration from a JSON file
    pub fn from_file(path: &std::path::Path) -> anyhow::Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let config: SandboxConfig = serde_json::from_str(&content)?;
        Ok(config)
    }

    /// Check if a guest path is allowed
    pub fn is_path_allowed(&self, guest_path: &str) -> bool {
        // Check denied paths first
        for denied in &self.denied_paths {
            if guest_path.starts_with(denied) {
                return false;
            }
        }

        // Check allowed paths
        for mapping in &self.allowed_paths {
            if guest_path.starts_with(&mapping.guest) {
                return true;
            }
        }

        false
    }

    /// Map guest path to host path
    pub fn map_path(&self, guest_path: &str) -> Option<PathBuf> {
        for mapping in &self.allowed_paths {
            if guest_path.starts_with(&mapping.guest) {
                let relative = guest_path.strip_prefix(&mapping.guest).unwrap_or("");
                let relative = relative.trim_start_matches('/');
                return Some(mapping.host.join(relative));
            }
        }
        None
    }

    /// Check if a host is allowed for network access
    pub fn is_host_allowed(&self, host: &str) -> bool {
        if !self.allow_network {
            return false;
        }
        match &self.allowed_hosts {
            None => true,
            Some(hosts) => hosts.iter().any(|h| h == host),
        }
    }

    /// Check if a port is allowed for network access
    pub fn is_port_allowed(&self, port: u16) -> bool {
        if !self.allow_network {
            return false;
        }
        match &self.allowed_ports {
            None => true,
            Some(ports) => ports.contains(&port),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = SandboxConfig::default();
        assert!(!config.allow_network);
        assert!(config.is_path_allowed("/sandbox/file.txt"));
        assert!(!config.is_path_allowed("/etc/passwd"));
    }

    #[test]
    fn test_path_mapping() {
        let config = SandboxConfig::default();
        let mapped = config.map_path("/sandbox/test/file.txt");
        assert_eq!(
            mapped,
            Some(PathBuf::from("/tmp/sandbox/test/file.txt"))
        );
    }

    #[test]
    fn test_permissive_config() {
        let config = SandboxConfig::permissive();
        assert!(config.allow_network);
        assert!(config.is_host_allowed("example.com"));
    }

    #[test]
    fn test_restrictive_config() {
        let config = SandboxConfig::restrictive();
        assert!(!config.allow_network);
        assert!(!config.is_path_allowed("/sandbox"));
    }
}
