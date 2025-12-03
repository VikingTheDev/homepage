# Multi-stage Dockerfile for Rust backend

# Chef stage - prepare dependency recipe
FROM cgr.dev/chainguard/rust:latest AS chef
WORKDIR /app
RUN cargo install cargo-chef

# Planner stage - analyze dependencies
FROM chef AS planner
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo chef prepare --recipe-path recipe.json

# Development stage
FROM cgr.dev/chainguard/rust:latest AS development
WORKDIR /app

# Install cargo-watch for hot reload
RUN cargo install cargo-watch

# Copy dependency files
COPY --chown=nonroot:nonroot Cargo.toml Cargo.lock ./

# Copy source code
COPY --chown=nonroot:nonroot src ./src
COPY --chown=nonroot:nonroot migrations ./migrations

# Development command (will be overridden in docker-compose)
CMD ["cargo", "watch", "-x", "run"]

# Builder stage with cargo-chef
FROM chef AS builder

# Copy the recipe from planner
COPY --from=planner /app/recipe.json recipe.json

# Build dependencies only (this layer is cached unless dependencies change)
RUN cargo chef cook --release --recipe-path recipe.json

# Copy actual source code
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY migrations ./migrations

# Build the application (only compiles your code since deps are cached)
RUN cargo build --release

# Production runtime stage
FROM cgr.dev/chainguard/wolfi-base:latest
WORKDIR /app

USER nonroot

# Copy the binary from builder
COPY --from=builder --chown=nonroot:nonroot /app/target/release/homepage-backend /app/homepage-backend

# Copy migrations
COPY --chown=nonroot:nonroot migrations ./migrations

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/app/homepage-backend", "health"] || exit 1

# Run the application
CMD ["/app/homepage-backend"]
