use anyhow::{Context, Result};
use notify::{Event, EventKind, RecursiveMode, Watcher};
use reqwest::{Client, multipart};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};
use tokio::sync::mpsc;
use tokio::time::sleep;

#[tokio::main]
async fn main() -> Result<()> {
    dotenvy::dotenv().ok();

    let server_url = std::env::var("SERVER_URL").context(
        "SERVER_URL must be set in .env (e.g., https://etl.ram-service-excellence.com/api/upload)",
    )?;
    let secret_token = std::env::var("SECRET_TOKEN")
        .context("SECRET_TOKEN must be set in .env to match server UPLOAD_SECRET_TOKEN")?;

    let download_dir = dirs::download_dir().context("Could not find Downloads directory")?;
    println!("👀 Watching directory: {:?}", download_dir);
    println!("🎯 Target Cloudflare endpoint: {}", server_url);

    let (tx, mut rx) = mpsc::channel(100);

    let mut watcher = notify::recommended_watcher(move |res: notify::Result<Event>| {
        if let Ok(event) = res {
            let _ = tx.blocking_send(event);
        }
    })?;

    watcher.watch(&download_dir, RecursiveMode::NonRecursive)?;

    let http_client = Client::builder()
        .user_agent("sf-watcher/0.1.0 (macOS)")
        .connect_timeout(Duration::from_secs(15))
        .timeout(Duration::from_secs(90))
        .build()?;

    let mut recent_uploads: HashMap<PathBuf, Instant> = HashMap::new();

    while let Some(event) = rx.recv().await {
        if !matches!(
            event.kind,
            EventKind::Create(_) | EventKind::Modify(notify::event::ModifyKind::Name(_))
        ) {
            continue;
        }

        for path in event.paths {
            if !is_target_file(&path) {
                continue;
            }

            if let Some(last_seen) = recent_uploads.get(&path) {
                if last_seen.elapsed() < Duration::from_secs(10) {
                    continue;
                }
            }
            recent_uploads.insert(path.clone(), Instant::now());

            println!(
                "📄 Detected new file: {:?}",
                path.file_name().unwrap_or_default()
            );

            // Give the browser 10 seconds to release the file lock and finish writing
            sleep(Duration::from_secs(10)).await;

            if !path.is_file() {
                continue;
            }

            match upload_file(&http_client, &server_url, &secret_token, &path).await {
                Ok(_) => {
                    println!("✅ Successfully uploaded to server.");
                    // Optional: Delete the file locally after successful upload
                    let _ = tokio::fs::remove_file(&path).await;
                }
                Err(e) => {
                    eprintln!("❌ Failed to upload file: {:?}", e);
                }
            }
        }
    }

    Ok(())
}

/// Filter for Salesforce Excel exports and contract PDFs matching server tunnels.rs
fn is_target_file(path: &Path) -> bool {
    if !path.is_file() {
        return false;
    }

    path.file_name()
        .and_then(|n| n.to_str())
        .map_or(false, |name| {
            if name.starts_with("~$") || name.starts_with('.') {
                return false;
            }

            let is_salesforce_xlsx = name.ends_with(".xlsx")
                && (name.starts_with("Case Basic Details Database")
                    || name.starts_with("Case Emails Database")
                    || name.starts_with("Case Comments Database")
                    || name.starts_with("Case Operator Details Database")
                    || name.starts_with("Case Customer Details Database")
                    || name.starts_with("Case History Database"));

            let is_pdf = name.ends_with(".pdf")
                && (name.starts_with("重要事項説明書")
                    || name.starts_with("全保連保証委託契約書")
                    || name.starts_with("GTN保証委託契約書")
                    || name.starts_with("賃貸借契約書"));

            is_salesforce_xlsx || is_pdf
        })
}

/// Securely POST the file to the Cloudflare Tunnel endpoint using multipart/form-data
async fn upload_file(
    client: &Client,
    server_url: &str,
    secret_token: &str,
    path: &Path,
) -> Result<()> {
    let file_name = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown_file")
        .to_string();

    let mime_type = if file_name.ends_with(".pdf") {
        "application/pdf"
    } else if file_name.ends_with(".xlsx") {
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    } else {
        "application/octet-stream"
    };

    let file_bytes = tokio::fs::read(path).await.context("Failed to read file")?;

    let file_part = multipart::Part::bytes(file_bytes)
        .file_name(file_name)
        .mime_str(mime_type)?;

    let form = multipart::Form::new().part("file", file_part);

    println!("🚀 Uploading {}...", path.display());

    let device_user = std::env::var("USER").unwrap_or_else(|_| "Unknown User".to_string());

    let response = client
        .post(server_url)
        .header("Authorization", format!("Bearer {}", secret_token))
        .header("x-device-user", device_user)
        .multipart(form)
        .send()
        .await?;

    if response.status().is_success() {
        Ok(())
    } else {
        let status = response.status();
        let error_text = response.text().await.unwrap_or_default();
        Err(anyhow::anyhow!(
            "Server returned {}: {}",
            status,
            error_text
        ))
    }
}
