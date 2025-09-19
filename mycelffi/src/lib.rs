use mobile::{proxy_connect, proxy_disconnect, generate_secret_key, address_from_secret_key, start_mycelium, stop_mycelium, get_peer_status};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;


#[no_mangle]
pub extern "C" fn ff_generate_secret_key(out_ptr: *mut *mut u8, out_len: *mut usize) {
    let secret_key = generate_secret_key();
    let len = secret_key.len();
    let ptr = secret_key.as_ptr();

    // Transfer ownership to the caller
    std::mem::forget(secret_key);

    unsafe {
        *out_ptr = ptr as *mut u8;
        *out_len = len;
    }
}

#[no_mangle]
pub extern "C" fn free_secret_key(ptr: *mut u8, len: usize) {
    unsafe {
        if ptr.is_null() {
            return;
        }
        Vec::from_raw_parts(ptr, len, len);
    }
}

#[no_mangle]
pub extern "C" fn ff_address_from_secret_key(data: *const u8, len: usize) -> *mut c_char {
    let slice = unsafe { std::slice::from_raw_parts(data, len) };
    let vec = slice.to_vec();
    let address = address_from_secret_key(vec);
    let c_string = CString::new(address).unwrap();
    c_string.into_raw()
}

#[no_mangle]
pub extern "C" fn free_c_string(s: *mut c_char) {
    unsafe {
        if s.is_null() {
            return;
        }
        let _ = CString::from_raw(s);
    };
}

#[no_mangle]
pub extern "C" fn ff_start_mycelium(
    peers_ptr: *const *const c_char,
    peers_len: usize,
    priv_key_ptr: *const u8,
    priv_key_len: usize,
) {
    let peers: Vec<String> = unsafe {
        (0..peers_len)
            .map(|i| {
                let c_str = CStr::from_ptr(*peers_ptr.add(i));
                c_str.to_string_lossy().into_owned()
            })
            .collect()
    };

    let priv_key: Vec<u8> =
        unsafe { std::slice::from_raw_parts(priv_key_ptr, priv_key_len).to_vec() };

    start_mycelium(peers, 0, priv_key);
}

#[no_mangle]
pub extern "C" fn ff_stop_mycelium() -> bool {
    let result = stop_mycelium();
    result == "ok"
}

#[no_mangle]
pub extern "C" fn ff_get_peer_status(out_ptr: *mut *mut *mut c_char, out_len: *mut usize) {
    let peer_status = get_peer_status();
    let len = peer_status.len();
    
    // Convert Vec<String> to Vec<*mut c_char>
    let c_strings: Vec<*mut c_char> = peer_status
        .into_iter()
        .map(|s| CString::new(s).unwrap().into_raw())
        .collect();
    
    let ptr = c_strings.as_ptr() as *mut *mut c_char;
    
    // Transfer ownership to the caller
    std::mem::forget(c_strings);
    
    unsafe {
        *out_ptr = ptr;
        *out_len = len;
    }
}

#[no_mangle]
pub extern "C" fn free_peer_status(ptr: *mut *mut c_char, len: usize) {
    unsafe {
        if ptr.is_null() {
            return;
        }
        
        // Free each C string
        for i in 0..len {
            let c_str_ptr = *ptr.add(i);
            if !c_str_ptr.is_null() {
                let _ = CString::from_raw(c_str_ptr);
            }
        }
        
        // Free the array of pointers
        Vec::from_raw_parts(ptr, len, len);
    }
}

#[no_mangle]
pub extern "C" fn ff_proxy_connect(remote_str: *const c_char, out_ptr: *mut *mut *mut c_char, out_len: *mut usize) {
    let c_str = unsafe { CStr::from_ptr(remote_str) };
    let remote_string = c_str.to_string_lossy().into_owned();
    let result = proxy_connect(remote_string);
    let len = result.len();
    
    // Convert Vec<String> to Vec<*mut c_char>
    let c_strings: Vec<*mut c_char> = result
        .into_iter()
        .map(|s| CString::new(s).unwrap().into_raw())
        .collect();
    
    let ptr = c_strings.as_ptr() as *mut *mut c_char;
    
    // Transfer ownership to the caller
    std::mem::forget(c_strings);
    
    unsafe {
        *out_ptr = ptr;
        *out_len = len;
    }
}

#[no_mangle]
pub extern "C" fn ff_proxy_disconnect(out_ptr: *mut *mut *mut c_char, out_len: *mut usize) {
    let result = proxy_disconnect();
    let len = result.len();
    
    // Convert Vec<String> to Vec<*mut c_char>
    let c_strings: Vec<*mut c_char> = result
        .into_iter()
        .map(|s| CString::new(s).unwrap().into_raw())
        .collect();
    
    let ptr = c_strings.as_ptr() as *mut *mut c_char;
    
    // Transfer ownership to the caller
    std::mem::forget(c_strings);
    
    unsafe {
        *out_ptr = ptr;
        *out_len = len;
    }
}
