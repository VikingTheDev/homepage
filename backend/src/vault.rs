use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use tracing::info;
use vaultrs::client::{VaultClient, VaultClientSettingsBuilder};
use vaultrs::auth::approle;

use crate::config::Config;

#[derive(Debug, Deserialize, Serialize)]
pub struct DbCredentials {
    pub username: String,
    pub password: String,
}

pub async fn init_vault_client(config: &Config) -> Result<VaultClient> {
    let settings = VaultClientSettingsBuilder::default()
        .address(&config.vault_addr)
        .build()
        .context("Failed to build Vault client settings")?;

    let client = VaultClient::new(settings)
        .context("Failed to create Vault client")?;

    // Authenticate using AppRole
    if !config.vault_role_id.is_empty() && !config.vault_secret_id.is_empty() {
        info!("Authenticating to Vault using AppRole");
        let _auth = approle::login(
            &client,
            "approle",
            &config.vault_role_id,
            &config.vault_secret_id,
        )
        .await
        .context("Failed to authenticate with Vault using AppRole")?;

        // Note: Token is automatically set by vaultrs
        info!("Successfully authenticated to Vault");
    } else {
        info!("Using token from VAULT_TOKEN environment variable");
        // Token should be set via VAULT_TOKEN env var for dev mode
    }

    Ok(client)
}

pub async fn fetch_db_credentials(
    client: &VaultClient,
    config: &Config,
) -> Result<DbCredentials> {
    info!("Fetching database credentials from Vault");

    // For production: use dynamic database credentials
    // For development: use static KV secrets
    match vaultrs::kv2::read::<serde_json::Value>(client, "secret", &format!("database/{}", config.database_name)).await {
        Ok(secret) => {
            let username = secret["username"]
                .as_str()
                .context("Missing username in Vault secret")?
                .to_string();
            let password = secret["password"]
                .as_str()
                .context("Missing password in Vault secret")?
                .to_string();

            Ok(DbCredentials { username, password })
        }
        Err(e) => {
            // Fallback to environment variables for local development
            tracing::warn!("Failed to fetch credentials from Vault: {}. Using fallback.", e);
            Ok(DbCredentials {
                username: std::env::var("DATABASE_USER").unwrap_or_else(|_| "postgres".to_string()),
                password: std::env::var("DATABASE_PASSWORD").unwrap_or_else(|_| "postgres".to_string()),
            })
        }
    }
}
