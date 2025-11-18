use notify::{Config, Event, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::Path;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{error, info, warn};

lazy_static::lazy_static! {
    static ref CERT_RELOAD_SIGNAL: Arc<RwLock<bool>> = Arc::new(RwLock::new(false));
}

pub async fn watch_certificates(cert_path: String, key_path: String) {
    info!("Starting certificate watcher for {} and {}", cert_path, key_path);

    let (tx, mut rx) = tokio::sync::mpsc::channel(100);

    // Start file watcher in a separate thread
    std::thread::spawn(move || {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            let tx = tx.clone();
            
            let mut watcher = RecommendedWatcher::new(
                move |res: Result<Event, notify::Error>| {
                    match res {
                        Ok(event) => {
                            if event.kind.is_modify() || event.kind.is_create() {
                                let _ = tx.blocking_send(event);
                            }
                        }
                        Err(e) => error!("Watch error: {:?}", e),
                    }
                },
                Config::default(),
            ).unwrap();

            // Watch the directory containing the certificates
            if let Some(cert_dir) = Path::new(&cert_path).parent() {
                if let Err(e) = watcher.watch(cert_dir, RecursiveMode::NonRecursive) {
                    error!("Failed to watch certificate directory: {}", e);
                    return;
                }
                info!("Watching directory: {:?}", cert_dir);
            }

            // Keep the watcher alive
            loop {
                tokio::time::sleep(tokio::time::Duration::from_secs(60)).await;
            }
        });
    });

    // Handle file change events
    while let Some(event) = rx.recv().await {
        info!("Certificate file changed: {:?}", event);
        
        // Set reload signal
        {
            let mut signal = CERT_RELOAD_SIGNAL.write().await;
            *signal = true;
        }

        // In a real implementation, we would:
        // 1. Load new certificates from disk
        // 2. Validate them
        // 3. Update the TLS configuration
        // 4. Gracefully reload database connections with new certs
        
        info!("Certificate reload triggered (graceful reload not yet fully implemented)");
        warn!("Manual restart may be required for full certificate rotation");

        // Reset signal after processing
        tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
        {
            let mut signal = CERT_RELOAD_SIGNAL.write().await;
            *signal = false;
        }
    }
}

pub async fn is_cert_reload_pending() -> bool {
    *CERT_RELOAD_SIGNAL.read().await
}
