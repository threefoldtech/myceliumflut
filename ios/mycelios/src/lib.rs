use mobile;

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
pub fn start_mycelium(tun_fd: i32, secret_key: Vec<u8>){
    let endpoints = vec!["tcp://[2a01:4f9:6a:1dc5::2]:9651".to_string()];
    mobile::start_mycelium(endpoints, tun_fd, secret_key);
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