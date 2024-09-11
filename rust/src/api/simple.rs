#[link(name = "winmycelium.dll", kind = "dylib")]
extern "C" {
    fn generate_secret_key() -> Vec<u8>;
    fn address_from_secret_key(data: Vec<u8>) -> String;
    fn start_mycelium(peers: Vec<String>, priv_key: Vec<u8>);
}

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
pub fn mycel_address_from_secret_key(data: Vec<u8>) -> String {
    unsafe { address_from_secret_key(data) }
}
