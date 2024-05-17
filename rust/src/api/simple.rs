// FRB_INTERNAL_GENERATOR: {"forbiddenDuplicatorModes": ["sync", "rustAsync", "sse", "sync sse", "rustAsync sse"]}

use crate::frb_generated::{FLUTTER_RUST_BRIDGE_HANDLER};

#[cfg(target_os = "android")]
use mobile;

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

pub async fn start_mycelium(peers: Vec<String>, tun_fd: i32, priv_key: Vec<u8>)  {
    #[cfg(target_os = "ios")]
    {
    }

    #[cfg(target_os = "android")]
    {
        // ref demo in https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html
        let handle = flutter_rust_bridge::spawn_blocking_with(
            move || mobile::start_mycelium(peers, tun_fd, priv_key),
            FLUTTER_RUST_BRIDGE_HANDLER.thread_pool(),
        );
        handle.await.unwrap()
    }
}

pub async fn stop_mycelium()  {
    #[cfg(target_os = "ios")]
    {
    }

    #[cfg(target_os = "android")]
    {
        let handle = flutter_rust_bridge::spawn_blocking_with(
            move || mobile::stop_mycelium(),
            FLUTTER_RUST_BRIDGE_HANDLER.thread_pool(),
        );
        handle.await.unwrap()
    }
}



#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
