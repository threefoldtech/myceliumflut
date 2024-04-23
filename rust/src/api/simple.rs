// FRB_INTERNAL_GENERATOR: {"forbiddenDuplicatorModes": ["sync", "rustAsync", "sse", "sync sse", "rustAsync sse"]}

use mycelium;
use crate::frb_generated::{FLUTTER_RUST_BRIDGE_HANDLER};

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(sync)]
pub fn generate_secret_key() -> Vec<u8> {
    mycelium::generate_secret_key()
}

#[flutter_rust_bridge::frb(sync)]
pub fn address_from_secret_key(data: Vec<u8>) -> String {
    mycelium::address_from_secret_key(data)
}

pub async fn start_mycelium(peer: String, tun_fd: i32, priv_key: Vec<u8>)  {
    // ref demo in https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html
    let handle = flutter_rust_bridge::spawn_blocking_with(
        move || mycelium::start_mycelium(peer, tun_fd, priv_key),
        FLUTTER_RUST_BRIDGE_HANDLER.thread_pool(),
    );
    handle.await.unwrap()
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
