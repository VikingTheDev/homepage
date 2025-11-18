use anyhow::{Context, Result};
use sqlx::postgres::{PgConnectOptions, PgPoolOptions, PgSslMode};
use sqlx::PgPool;
use std::time::Duration;
use tracing::info;

use crate::config::Config;
use crate::vault::DbCredentials;

pub async fn init_db_pool(credentials: &DbCredentials, config: &Config) -> Result<PgPool> {
    info!("Initializing database connection pool");

    let mut connect_options = PgConnectOptions::new()
        .host(&config.database_host)
        .port(config.database_port)
        .database(&config.database_name)
        .username(&credentials.username)
        .password(&credentials.password);

    // Configure TLS/mTLS if enabled
    if config.enable_mtls {
        info!("Enabling mTLS for database connection");
        connect_options = connect_options.ssl_mode(PgSslMode::Require);
        // Note: For full mTLS with client certificates, we would need to use
        // the postgres-native-tls or postgres-openssl features with custom TLS config
        // This is a simplified version
    } else {
        connect_options = connect_options.ssl_mode(PgSslMode::Prefer);
    }

    let pool = PgPoolOptions::new()
        .max_connections(20)
        .min_connections(5)
        .acquire_timeout(Duration::from_secs(30))
        .idle_timeout(Duration::from_secs(600))
        .connect_with(connect_options)
        .await
        .context("Failed to connect to database")?;

    info!("Database connection pool initialized successfully");
    Ok(pool)
}
