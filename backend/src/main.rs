use axum::{extract::State, http::StatusCode, response::IntoResponse, routing::get, Json, Router};
use prometheus::{Encoder, TextEncoder};
use serde::Serialize;
use std::sync::Arc;
use tower_http::trace::TraceLayer;
use tracing::{info, warn};

mod cert_watcher;
mod config;
mod db;
mod vault;

use config::Config;

#[derive(Clone)]
struct AppState {
    db: sqlx::PgPool,
    #[allow(dead_code)]
    redis: redis::aio::ConnectionManager,
    #[allow(dead_code)]
    config: Arc<Config>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "homepage_backend=debug,tower_http=debug".into()),
        )
        .json()
        .init();

    info!("Starting homepage backend");

    // Load configuration
    let config = Config::from_env()?;
    info!("Configuration loaded");

    // Initialize Vault client and fetch secrets
    let vault_client = vault::init_vault_client(&config).await?;
    let db_credentials = vault::fetch_db_credentials(&vault_client, &config).await?;
    info!("Secrets fetched from Vault");

    // Initialize database connection
    let db_pool = db::init_db_pool(&db_credentials, &config).await?;
    info!("Database connection established");

    // Run migrations
    sqlx::migrate!("./migrations").run(&db_pool).await?;
    info!("Database migrations completed");

    // Initialize Redis/ValKey connection
    let redis_client = redis::Client::open(config.redis_url.as_str())?;
    let redis_conn = redis::aio::ConnectionManager::new(redis_client).await?;
    info!("ValKey connection established");

    // Start certificate watcher for graceful reload
    if config.enable_mtls {
        tokio::spawn(cert_watcher::watch_certificates(
            config.tls_cert_path.clone(),
            config.tls_key_path.clone(),
        ));
        info!("Certificate watcher started");
    }

    // Create application state
    let state = AppState {
        db: db_pool,
        redis: redis_conn,
        config: Arc::new(config.clone()),
    };

    // Build router
    let app = Router::new()
        .route("/", get(root_handler))
        .route("/health", get(health_handler))
        .route("/api/health", get(health_handler))  // Add /api/health for ingress
        .route("/metrics", get(metrics_handler))
        .route("/api/example", get(example_handler))
        .with_state(state)
        .layer(TraceLayer::new_for_http());

    // Start server
    let addr = format!("0.0.0.0:{}", config.server_port);
    info!("Server listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(&addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

async fn root_handler() -> &'static str {
    "Homepage Backend API"
}

async fn health_handler(State(state): State<AppState>) -> impl IntoResponse {
    // Check database connection
    match sqlx::query("SELECT 1").fetch_one(&state.db).await {
        Ok(_) => (
            StatusCode::OK,
            Json(serde_json::json!({
                "status": "healthy",
                "database": "connected",
            })),
        ),
        Err(e) => {
            warn!("Health check failed: {}", e);
            (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(serde_json::json!({
                    "status": "unhealthy",
                    "database": "disconnected",
                })),
            )
        }
    }
}

async fn metrics_handler() -> impl IntoResponse {
    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    let mut buffer = vec![];
    encoder.encode(&metric_families, &mut buffer).unwrap();

    (
        StatusCode::OK,
        [("content-type", "text/plain; version=0.0.4")],
        buffer,
    )
}

#[derive(Serialize)]
struct ExampleResponse {
    message: String,
    timestamp: chrono::DateTime<chrono::Utc>,
}

async fn example_handler() -> impl IntoResponse {
    Json(ExampleResponse {
        message: "Hello from Axum backend!".to_string(),
        timestamp: chrono::Utc::now(),
    })
}
