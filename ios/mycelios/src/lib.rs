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
pub fn start_mycelium() {
    let endpoints = vec!["tcp://65.21.231.58:9651".to_string()];
    mobile::start_mycelium(endpoints, 0, vec![]);
}