//! Capability-based filesystem wrapper for sandbox enforcement

use crate::config::SandboxConfig;
use anyhow::{bail, Result};
use std::path::PathBuf;
use std::sync::Mutex;

/// Sandbox state tracking
#[derive(Debug)]
pub struct SandboxState {
    config: SandboxConfig,
    open_files: Mutex<usize>,
    total_written: Mutex<usize>,
}

impl SandboxState {
    pub fn new(config: SandboxConfig) -> Self {
        Self {
            config,
            open_files: Mutex::new(0),
            total_written: Mutex::new(0),
        }
    }

    /// Check if a file operation is allowed
    pub fn check_file_access(&self, guest_path: &str, write: bool) -> Result<PathBuf> {
        // Check path allowlist/denylist
        if !self.config.is_path_allowed(guest_path) {
            bail!("Access denied: path not in allowed list: {}", guest_path);
        }

        // Map to host path
        let host_path = self
            .config
            .map_path(guest_path)
            .ok_or_else(|| anyhow::anyhow!("Cannot map path: {}", guest_path))?;

        // Check read-only status
        if write {
            for mapping in &self.config.allowed_paths {
                if guest_path.starts_with(&mapping.guest) && mapping.read_only {
                    bail!("Write denied: path is read-only: {}", guest_path);
                }
            }
        }

        Ok(host_path)
    }

    /// Track file open
    pub fn track_open(&self) -> Result<()> {
        let mut count = self.open_files.lock().unwrap();
        if let Some(max) = self.config.max_open_files {
            if *count >= max {
                bail!("Too many open files (max: {})", max);
            }
        }
        *count += 1;
        Ok(())
    }

    /// Track file close
    pub fn track_close(&self) {
        let mut count = self.open_files.lock().unwrap();
        if *count > 0 {
            *count -= 1;
        }
    }

    /// Track bytes written
    pub fn track_write(&self, bytes: usize) -> Result<()> {
        // Check single file size
        if let Some(max) = self.config.max_file_size {
            if bytes > max {
                bail!("File size exceeds limit: {} > {}", bytes, max);
            }
        }

        // Check total size
        let mut total = self.total_written.lock().unwrap();
        if let Some(max) = self.config.max_total_size {
            if *total + bytes > max {
                bail!("Total write size exceeds limit");
            }
        }
        *total += bytes;
        Ok(())
    }

    /// Check network access
    pub fn check_network(&self, host: &str, port: u16) -> Result<()> {
        if !self.config.allow_network {
            bail!("Network access denied");
        }

        if !self.config.is_host_allowed(host) {
            bail!("Host not allowed: {}", host);
        }

        if !self.config.is_port_allowed(port) {
            bail!("Port not allowed: {}", port);
        }

        Ok(())
    }

    /// Get filtered environment variables
    pub fn get_filtered_env(&self) -> Vec<(String, String)> {
        match &self.config.env_whitelist {
            None => self.config.env.clone(),
            Some(whitelist) => self
                .config
                .env
                .iter()
                .filter(|(k, _)| whitelist.contains(k))
                .cloned()
                .collect(),
        }
    }

    /// Get the sandbox configuration
    pub fn config(&self) -> &SandboxConfig {
        &self.config
    }
}

/// Create directory mappings for WASI
pub fn create_dir_mappings(config: &SandboxConfig) -> Vec<(String, PathBuf)> {
    config
        .allowed_paths
        .iter()
        .map(|m| (m.guest.clone(), m.host.clone()))
        .collect()
}

/// Ensure sandbox directories exist
pub fn ensure_sandbox_dirs(config: &SandboxConfig) -> Result<()> {
    for mapping in &config.allowed_paths {
        if !mapping.host.exists() {
            std::fs::create_dir_all(&mapping.host)?;
            tracing::info!("Created sandbox directory: {:?}", mapping.host);
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sandbox_state() {
        let config = SandboxConfig::default();
        let state = SandboxState::new(config);

        // Test file tracking
        assert!(state.track_open().is_ok());
        state.track_close();

        // Test write tracking
        assert!(state.track_write(1024).is_ok());
    }

    #[test]
    fn test_path_access() {
        let config = SandboxConfig::default();
        let state = SandboxState::new(config);

        // Allowed path
        assert!(state.check_file_access("/sandbox/file.txt", false).is_ok());

        // Denied path
        assert!(state.check_file_access("/etc/passwd", false).is_err());
    }

    #[test]
    fn test_network_access() {
        let config = SandboxConfig::default();
        let state = SandboxState::new(config);

        // Network disabled by default
        assert!(state.check_network("example.com", 80).is_err());
    }
}
