use anyhow::Result;
use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct Config {
    pub server_port: u16,
    pub database_host: String,
    pub database_port: u16,
    pub database_name: String,
    pub redis_url: String,
    pub vault_addr: String,
    pub vault_role_id: String,
    pub vault_secret_id: String,
    pub enable_mtls: bool,
    pub tls_cert_path: String,
    pub tls_key_path: String,
    #[allow(dead_code)]
    pub tls_ca_path: String,
}

impl Config {
    pub fn from_env() -> Result<Self> {
        dotenvy::dotenv().ok();

        Ok(Config {
            server_port: std::env::var("SERVER_PORT")
                .unwrap_or_else(|_| "8000".to_string())
                .parse()?,
            database_host: std::env::var("DATABASE_HOST")
                .unwrap_or_else(|_| "localhost".to_string()),
            database_port: std::env::var("DATABASE_PORT")
                .unwrap_or_else(|_| "5432".to_string())
                .parse()?,
            database_name: std::env::var("DATABASE_NAME")
                .unwrap_or_else(|_| "homepage".to_string()),
            redis_url: std::env::var("REDIS_URL")
                .unwrap_or_else(|_| "redis://valkey:6379".to_string()),
            vault_addr: std::env::var("VAULT_ADDR")
                .unwrap_or_else(|_| "http://vault:8200".to_string()),
            vault_role_id: std::env::var("VAULT_ROLE_ID").unwrap_or_else(|_| "".to_string()),
            vault_secret_id: std::env::var("VAULT_SECRET_ID").unwrap_or_else(|_| "".to_string()),
            enable_mtls: std::env::var("ENABLE_MTLS")
                .unwrap_or_else(|_| "false".to_string())
                .parse()
                .unwrap_or(false),
            tls_cert_path: std::env::var("TLS_CERT_PATH")
                .unwrap_or_else(|_| "/vault/secrets/tls.crt".to_string()),
            tls_key_path: std::env::var("TLS_KEY_PATH")
                .unwrap_or_else(|_| "/vault/secrets/tls.key".to_string()),
            tls_ca_path: std::env::var("TLS_CA_PATH")
                .unwrap_or_else(|_| "/vault/secrets/ca.crt".to_string()),
        })
    }
}
