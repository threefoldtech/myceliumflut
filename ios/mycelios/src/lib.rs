uniffi::setup_scaffolding!();
#[uniffi::export]
pub fn hello_mycelios() -> String {
    "Hello, Mycelios!".to_string()
}

#[uniffi::export]
pub fn hello_int() -> i32 {
    123
}