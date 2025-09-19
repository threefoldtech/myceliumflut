use mobile;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

uniffi::setup_scaffolding!();

#[uniffi::export]
pub fn hello_mycelios() -> String {
    "Hello, Mycelios!".to_string()
}

#[uniffi::export]
pub fn hello_int() -> i32 {
    123
}

#[uniffi::export]
pub fn start_mycelium(peers: Vec<String>, tun_fd: i32, secret_key: Vec<u8>) {
    mobile::start_mycelium(peers, tun_fd, secret_key);
}

#[uniffi::export]
pub fn stop_mycelium() {
    mobile::stop_mycelium();
}

#[uniffi::export]
pub fn generate_secret_key() -> Vec<u8> {
    mobile::generate_secret_key()
}

#[uniffi::export]
pub fn address_from_secret_key(data: Vec<u8>) -> String {
    mobile::address_from_secret_key(data)
}

#[uniffi::export]
pub fn get_peer_status() -> Vec<String> {
    mobile::get_peer_status()
}

#[uniffi::export]
pub fn start_proxy_probe() -> Vec<String> {
    mobile::start_proxy_probe()
}

#[uniffi::export]
pub fn stop_proxy_probe() -> Vec<String> {
    mobile::stop_proxy_probe()
}

#[uniffi::export]
pub fn list_proxies() -> Vec<String> {
    mobile::list_proxies()
}

#[uniffi::export]
pub fn proxy_connect(remote: String) -> Vec<String> {
    mobile::proxy_connect(remote)
}

#[uniffi::export]
pub fn proxy_disconnect() -> Vec<String> {
    mobile::proxy_disconnect()
}

#[no_mangle]
pub extern "C" fn ffi_proxy_connect(remote: *const c_char) -> *mut c_char {
    let remote_str = unsafe {
        assert!(!remote.is_null());
        CStr::from_ptr(remote).to_string_lossy().into_owned()
    };

    // No async runtime needed, this is a synchronous call
    let result = proxy_connect(remote_str);
    let joined = result.join(",");

    CString::new(joined).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn ffi_proxy_disconnect() -> *mut c_char {
    let result = proxy_disconnect();
    let joined = result.join(",");

    CString::new(joined).unwrap().into_raw()
}

/// Helper to free strings allocated by Rust
#[no_mangle]
pub extern "C" fn ffi_free_string(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(s));
    }
}
