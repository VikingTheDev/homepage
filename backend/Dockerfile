# Multi-stage Dockerfile for Rust backend

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

# Builder stage
FROM cgr.dev/chainguard/rust:latest AS builder
WORKDIR /app

# Copy dependency files
COPY Cargo.toml Cargo.lock ./

# Create dummy main to cache dependencies
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Copy actual source code
COPY src ./src
COPY migrations ./migrations

# Build the application
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
