#[link(name = "winmycelium.dll", kind = "dylib")]
extern "C" {
    fn generate_secret_key() -> Vec<u8>;
    fn address_from_secret_key(data: Vec<u8>) -> String;
    fn start_mycelium(peers: Vec<String>, priv_key: Vec<u8>);
    fn stop_mycelium() -> String;
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

#[flutter_rust_bridge::frb(sync)]
pub fn mycel_address_from_secret_key(data: Vec<u8>) -> String {
    unsafe { address_from_secret_key(data) }
}

#[flutter_rust_bridge::frb(sync)]
pub fn mycel_generate_secret_key() -> Vec<u8> {
    unsafe { generate_secret_key() }
}

#[flutter_rust_bridge::frb(sync)]
pub fn mycel_start_mycelium(peers: Vec<String>, priv_key: Vec<u8>) {
    unsafe {
        start_mycelium(peers, priv_key);
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn mycel_stop_mycelium() -> String {
    unsafe { stop_mycelium() }
}
