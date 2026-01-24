run target=("debug"): (build target)
    wasmtime run --dir /tmp -S http=y -S p3=y -W component-model=y -W component-model-async=y target/cli.wasm

build target=("debug"):
    @echo 'Building targeting {{ target }}'
    moon build --target wasm --{{ target }}
    wasm-tools component embed --encoding utf16 wit target/wasm/{{ target }}/build/gen/gen.wasm -o target/cli.core.wasm
    wasm-tools component new target/cli.core.wasm -o target/cli.wasm

regenerate:
    @echo 'Regenerating bindings'
    wkg wit fetch
    wit-bindgen moonbit wit --derive-eq --derive-show --derive-error
    rm -r world
    moon fmt
    moon info

clean:
    @echo 'Cleaning project'
    moon clean

# ============ Sandbox Tasks ============

# Run with sandbox restrictions (read-only /sandbox)
run-sandbox target=("debug"): (build target)
    @echo 'Running in sandbox mode'
    mkdir -p /tmp/sandbox
    wasmtime run \
        --dir /tmp/sandbox::/sandbox \
        -S http=n \
        -W component-model=y \
        target/cli.wasm

# Run with full sandbox configuration
run-sandbox-config target=("debug"): (build target)
    @echo 'Running with sandbox config'
    mkdir -p /tmp/sandbox /tmp/home
    wasmtime run \
        --dir /tmp/sandbox::/sandbox \
        --dir /tmp/home::/home \
        --env SANDBOX_MODE=true \
        -S http=n \
        -W component-model=y \
        target/cli.wasm

# Run with permissive mode (for development)
run-permissive target=("debug"): (build target)
    @echo 'Running in permissive mode (development only)'
    wasmtime run \
        --dir /tmp \
        -S http=y \
        -S p3=y \
        -W component-model=y \
        -W component-model-async=y \
        target/cli.wasm

# ============ Host Tasks ============

# Build the Rust wasmtime host
build-host:
    @echo 'Building wasmtime host'
    cd host && cargo build --release

# Run with custom Rust host
run-host target=("debug"): (build target) build-host
    @echo 'Running with custom host'
    ./host/target/release/wasip2-host target/cli.wasm

# Run with custom host in sandbox mode
run-host-sandbox target=("debug"): (build target) build-host
    @echo 'Running with custom host (sandbox)'
    ./host/target/release/wasip2-host \
        --config sandbox-config.json \
        target/cli.wasm

# Run with custom host in permissive mode
run-host-permissive target=("debug"): (build target) build-host
    @echo 'Running with custom host (permissive)'
    ./host/target/release/wasip2-host \
        --permissive \
        target/cli.wasm

# ============ Docker/OCI Tasks ============

# Build OCI image (requires Docker with WASM support)
docker-build target=("debug"): (build target)
    @echo 'Building OCI image'
    docker buildx build --platform wasi/wasm32 -f Dockerfile.wasm -t wasip2-sandbox:latest .

# Run with Docker runwasi (requires containerd-shim-wasmtime)
docker-run:
    @echo 'Running with Docker runwasi'
    docker run \
        --runtime=io.containerd.wasmtime.v1 \
        --platform wasi/wasm32 \
        -v /tmp/sandbox:/sandbox \
        wasip2-sandbox:latest

# ============ Development Tasks ============

# Run MoonBit tests
test:
    @echo 'Running tests'
    moon test --target native

# Run memfs tests only
test-memfs:
    @echo 'Running memfs tests'
    moon test --target native memfs

# Run all benchmarks
bench:
    @echo 'Running benchmarks'
    moon bench --target native

# Run benchmarks for specific package
bench-pkg pkg:
    @echo 'Running benchmarks for package: {{ pkg }}'
    moon bench --target native --package {{ pkg }}

# Run memfs benchmarks (includes all sandbox layers)
bench-memfs:
    @echo 'Running memfs benchmarks'
    moon bench --target native --package memfs

# Run specific benchmark file
bench-file pkg file:
    @echo 'Running benchmarks in {{ pkg }}/{{ file }}'
    moon bench --target native --package {{ pkg }} --file {{ file }}

# Format code
fmt:
    @echo 'Formatting code'
    moon fmt
    cd host && cargo fmt

# Check for issues
check:
    @echo 'Checking code'
    moon check
    cd host && cargo check

# ============ Setup Tasks ============

# Install wasmtime (macOS/Linux)
install-wasmtime:
    @echo 'Installing wasmtime'
    curl https://wasmtime.dev/install.sh -sSf | bash

# Install wasm-tools
install-wasm-tools:
    @echo 'Installing wasm-tools'
    cargo install wasm-tools

# Install all dependencies
install-deps: install-wasmtime install-wasm-tools
    @echo 'All dependencies installed'

# Create sandbox directories
setup-sandbox:
    @echo 'Setting up sandbox directories'
    mkdir -p /tmp/sandbox /tmp/home
    @echo 'Sandbox directories created'