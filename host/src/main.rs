//! WASI P2 Sandbox Host
//!
//! A wasmtime-based host that runs WASM components with capability-based sandboxing.

mod config;
mod sandbox_fs;

use anyhow::{Context, Result};
use clap::Parser;
use config::SandboxConfig;
use sandbox_fs::{ensure_sandbox_dirs, SandboxState};
use std::path::PathBuf;
use std::sync::Arc;
use wasmtime::component::{Component, Linker, ResourceTable, Val};
use wasmtime::{Config, Engine, Store};
use wasmtime_wasi::{WasiCtx, WasiCtxBuilder, WasiView};

/// WASI P2 Sandbox Host
#[derive(Parser, Debug)]
#[command(name = "wasip2-host")]
#[command(about = "Run WASM components with capability-based sandboxing")]
#[command(version)]
struct Args {
    /// Path to the WASM component file
    #[arg(required = true)]
    wasm_file: PathBuf,

    /// Path to sandbox configuration file (JSON)
    #[arg(short, long)]
    config: Option<PathBuf>,

    /// Use permissive mode (development only)
    #[arg(long)]
    permissive: bool,

    /// Directory mappings (guest:host format)
    #[arg(short, long, value_parser = parse_dir_mapping)]
    dir: Vec<(String, PathBuf)>,

    /// Enable network access
    #[arg(long)]
    network: bool,

    /// Arguments to pass to the WASM module
    #[arg(last = true)]
    args: Vec<String>,
}

fn parse_dir_mapping(s: &str) -> Result<(String, PathBuf), String> {
    let parts: Vec<&str> = s.splitn(2, ':').collect();
    if parts.len() != 2 {
        return Err("Directory mapping must be in format 'guest:host'".to_string());
    }
    Ok((parts[0].to_string(), PathBuf::from(parts[1])))
}

/// Host state for the WASM runtime
struct HostState {
    wasi: WasiCtx,
    table: ResourceTable,
    #[allow(dead_code)]
    sandbox: Arc<SandboxState>,
}

impl WasiView for HostState {
    fn ctx(&mut self) -> &mut WasiCtx {
        &mut self.wasi
    }
    fn table(&mut self) -> &mut ResourceTable {
        &mut self.table
    }
}

fn build_wasi_ctx(config: &SandboxConfig, args: &[String]) -> Result<WasiCtx> {
    let mut builder = WasiCtxBuilder::new();

    // Set up stdio
    builder.inherit_stdio();

    // Set up environment variables
    for (key, value) in &config.env {
        builder.env(key, value);
    }

    // Set up arguments
    builder.args(args);

    // Set up directory mappings
    // wasmtime_wasi 29 API: preopened_dir(host_path, guest_path, dir_perms, file_perms)
    for mapping in &config.allowed_paths {
        if mapping.host.exists() {
            if mapping.read_only {
                builder.preopened_dir(
                    &mapping.host,
                    &mapping.guest,
                    wasmtime_wasi::DirPerms::READ,
                    wasmtime_wasi::FilePerms::READ,
                )?;
            } else {
                builder.preopened_dir(
                    &mapping.host,
                    &mapping.guest,
                    wasmtime_wasi::DirPerms::all(),
                    wasmtime_wasi::FilePerms::all(),
                )?;
            }
        }
    }

    // Network access
    if config.allow_network {
        builder.inherit_network();
    }

    Ok(builder.build())
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive(tracing::Level::INFO.into()),
        )
        .init();

    let args = Args::parse();

    // Load or create sandbox configuration
    let mut sandbox_config = if args.permissive {
        tracing::warn!("Running in permissive mode - not recommended for untrusted code");
        SandboxConfig::permissive()
    } else if let Some(config_path) = &args.config {
        SandboxConfig::from_file(config_path)
            .with_context(|| format!("Failed to load config from {:?}", config_path))?
    } else {
        SandboxConfig::default()
    };

    // Apply CLI overrides
    for (guest, host) in &args.dir {
        sandbox_config.allowed_paths.push(config::PathMapping {
            guest: guest.clone(),
            host: host.clone(),
            read_only: false,
        });
    }

    if args.network {
        sandbox_config.allow_network = true;
        sandbox_config.allowed_hosts = None;
        sandbox_config.allowed_ports = None;
    }

    // Ensure sandbox directories exist
    ensure_sandbox_dirs(&sandbox_config)?;

    // Configure wasmtime engine
    let mut engine_config = Config::new();
    engine_config.wasm_component_model(true);
    engine_config.async_support(true);

    // Apply resource limits
    if let Some(max_memory) = sandbox_config.max_memory_bytes {
        // Note: wasmtime doesn't directly expose memory limits in Config
        // Memory limits are typically enforced at the module level
        tracing::info!("Memory limit configured: {} bytes", max_memory);
    }

    let engine = Engine::new(&engine_config)?;

    // Load WASM component
    tracing::info!("Loading WASM component: {:?}", args.wasm_file);
    let component = Component::from_file(&engine, &args.wasm_file)
        .with_context(|| format!("Failed to load WASM component from {:?}", args.wasm_file))?;

    // Create linker
    let mut linker = Linker::new(&engine);
    wasmtime_wasi::add_to_linker_async(&mut linker)?;

    // Create host state
    let sandbox = Arc::new(SandboxState::new(sandbox_config.clone()));
    let wasi = build_wasi_ctx(&sandbox_config, &args.args)?;
    let state = HostState {
        wasi,
        table: ResourceTable::new(),
        sandbox,
    };

    // Create store
    let mut store = Store::new(&engine, state);

    // Apply execution timeout
    if let Some(timeout_ms) = sandbox_config.max_exec_time_ms {
        store.set_epoch_deadline(1);
        let engine_clone = engine.clone();
        std::thread::spawn(move || {
            std::thread::sleep(std::time::Duration::from_millis(timeout_ms));
            engine_clone.increment_epoch();
        });
        tracing::info!("Execution timeout set: {} ms", timeout_ms);
    }

    // Instantiate and run
    tracing::info!("Instantiating component...");
    let instance = linker.instantiate_async(&mut store, &component).await?;

    // Try to find and call the run function
    // WASI CLI components typically export wasi:cli/run#run
    if let Some(run) = instance.get_func(&mut store, "wasi:cli/run@0.2.0#run") {
        tracing::info!("Calling wasi:cli/run@0.2.0#run...");
        let mut results: Vec<Val> = vec![];
        run.call_async(&mut store, &[], &mut results).await?;
        let exit_code = results.first().map(|v| {
            match v {
                Val::S32(code) => *code,
                Val::U32(code) => *code as i32,
                _ => 0,
            }
        }).unwrap_or(0);
        tracing::info!("Component exited with code: {}", exit_code);
        std::process::exit(exit_code);
    }

    // Try wasi:cli/run@0.2.9
    if let Some(run) = instance.get_func(&mut store, "wasi:cli/run@0.2.9#run") {
        tracing::info!("Calling wasi:cli/run@0.2.9#run...");
        let mut results: Vec<Val> = vec![];
        run.call_async(&mut store, &[], &mut results).await?;
        let exit_code = results.first().map(|v| {
            match v {
                Val::S32(code) => *code,
                Val::U32(code) => *code as i32,
                _ => 0,
            }
        }).unwrap_or(0);
        tracing::info!("Component exited with code: {}", exit_code);
        std::process::exit(exit_code);
    }

    // Fallback: try _start
    if let Some(start) = instance.get_func(&mut store, "_start") {
        tracing::info!("Calling _start...");
        let mut results: Vec<Val> = vec![];
        start.call_async(&mut store, &[], &mut results).await?;
        tracing::info!("Component completed");
        return Ok(());
    }

    tracing::warn!("No entry point found in component");
    Ok(())
}
