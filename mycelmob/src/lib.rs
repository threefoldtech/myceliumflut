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
pub fn start_mycelium(peers: Vec<String>, tun_fd: i32, secret_key: Vec<u8>){
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