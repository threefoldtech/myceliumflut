#[cfg(any(target_os = "macos", target_os = "windows"))]
use mobile;

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(any(target_os = "macos", target_os = "windows"))]
#[flutter_rust_bridge::frb(sync)]
pub fn address_from_secret_key(data: Vec<u8>) -> String {
    return mobile::address_from_secret_key(data);
}
