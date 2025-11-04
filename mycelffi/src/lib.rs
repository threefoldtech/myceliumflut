use mobile::{
    generate_secret_key, address_from_secret_key, start_mycelium, stop_mycelium, get_peer_status,
    start_proxy_probe, stop_proxy_probe, list_proxies, proxy_connect, proxy_disconnect
};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

#[cfg(target_os = "windows")]
use winreg::RegKey;
#[cfg(target_os = "windows")]
use winreg::enums::*;


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

// Proxy functions for Windows FFI
#[no_mangle]
pub extern "C" fn ff_start_proxy_probe(out_ptr: *mut *mut *mut c_char, out_len: *mut usize) {
    let result = start_proxy_probe();
    convert_vec_string_to_c(result, out_ptr, out_len);
}

#[no_mangle]
pub extern "C" fn ff_stop_proxy_probe(out_ptr: *mut *mut *mut c_char, out_len: *mut usize) {
    let result = stop_proxy_probe();
    convert_vec_string_to_c(result, out_ptr, out_len);
}

#[no_mangle]
pub extern "C" fn ff_list_proxies(out_ptr: *mut *mut *mut c_char, out_len: *mut usize) {
    let result = list_proxies();
    convert_vec_string_to_c(result, out_ptr, out_len);
}

#[no_mangle]
pub extern "C" fn ff_proxy_connect(
    remote: *const c_char,
    out_ptr: *mut *mut *mut c_char,
    out_len: *mut usize,
) {
    let remote_str = if remote.is_null() {
        String::new()
    } else {
        unsafe { CStr::from_ptr(remote).to_string_lossy().into_owned() }
    };
    
    let result = proxy_connect(remote_str);
    convert_vec_string_to_c(result, out_ptr, out_len);
}

#[no_mangle]
pub extern "C" fn ff_proxy_disconnect(out_ptr: *mut *mut *mut c_char, out_len: *mut usize) {
    let result = proxy_disconnect();
    convert_vec_string_to_c(result, out_ptr, out_len);
}

// Helper function to convert Vec<String> to C array of strings
fn convert_vec_string_to_c(
    vec: Vec<String>,
    out_ptr: *mut *mut *mut c_char,
    out_len: *mut usize,
) {
    let len = vec.len();
    
    // Convert Vec<String> to Vec<*mut c_char>
    let c_strings: Vec<*mut c_char> = vec
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

// Windows-specific system proxy configuration
#[no_mangle]
#[cfg(target_os = "windows")]
pub extern "C" fn ff_enable_system_proxy(proxy_address: *const c_char) -> bool {
    let proxy_str = if proxy_address.is_null() {
        "127.0.0.1:1080".to_string()
    } else {
        unsafe { CStr::from_ptr(proxy_address).to_string_lossy().into_owned() }
    };
    
    match set_windows_proxy(&proxy_str, true) {
        Ok(_) => true,
        Err(e) => {
            eprintln!("Failed to enable Windows proxy: {}", e);
            false
        }
    }
}

#[no_mangle]
#[cfg(target_os = "windows")]
pub extern "C" fn ff_disable_system_proxy() -> bool {
    match set_windows_proxy("", false) {
        Ok(_) => true,
        Err(e) => {
            eprintln!("Failed to disable Windows proxy: {}", e);
            false
        }
    }
}

#[no_mangle]
#[cfg(target_os = "windows")]
pub extern "C" fn ff_get_system_proxy_status() -> bool {
    match get_windows_proxy_status() {
        Ok(enabled) => enabled,
        Err(_) => false,
    }
}

#[cfg(target_os = "windows")]
fn set_windows_proxy(proxy: &str, enable: bool) -> Result<(), std::io::Error> {
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    let internet_settings = hkcu.open_subkey_with_flags(
        "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
        KEY_WRITE,
    )?;
    
    if enable {
        // Enable proxy
        internet_settings.set_value("ProxyEnable", &1u32)?;
        // Set SOCKS5 proxy
        internet_settings.set_value("ProxyServer", &format!("socks={}", proxy))?;
        println!("Windows proxy enabled: socks={}", proxy);
    } else {
        // Disable proxy
        internet_settings.set_value("ProxyEnable", &0u32)?;
        println!("Windows proxy disabled");
    }
    
    // Notify Windows that proxy settings changed
    // For now, just setting registry is enough - apps will pick it up
    
    Ok(())
}

#[cfg(target_os = "windows")]
fn get_windows_proxy_status() -> Result<bool, std::io::Error> {
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    let internet_settings = hkcu.open_subkey(
        "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
    )?;
    
    let proxy_enable: u32 = internet_settings.get_value("ProxyEnable").unwrap_or(0);
    Ok(proxy_enable == 1)
}

// Stub implementations for non-Windows platforms
#[no_mangle]
#[cfg(not(target_os = "windows"))]
pub extern "C" fn ff_enable_system_proxy(_proxy_address: *const c_char) -> bool {
    eprintln!("System proxy configuration is only supported on Windows");
    false
}

#[no_mangle]
#[cfg(not(target_os = "windows"))]
pub extern "C" fn ff_disable_system_proxy() -> bool {
    eprintln!("System proxy configuration is only supported on Windows");
    false
}

#[no_mangle]
#[cfg(not(target_os = "windows"))]
pub extern "C" fn ff_get_system_proxy_status() -> bool {
    false
}

// Check if running as administrator on Windows
#[no_mangle]
#[cfg(target_os = "windows")]
pub extern "C" fn ff_is_running_as_admin() -> bool {
    is_running_as_admin()
}

#[cfg(target_os = "windows")]
fn is_running_as_admin() -> bool {
    use std::ptr;
    
    // Windows API types
    type BOOL = i32;
    type HANDLE = *mut std::ffi::c_void;
    type DWORD = u32;
    
    #[repr(C)]
    #[allow(non_camel_case_types)]
    struct SID_IDENTIFIER_AUTHORITY {
        value: [u8; 6],
    }
    
    const SECURITY_NT_AUTHORITY: SID_IDENTIFIER_AUTHORITY = SID_IDENTIFIER_AUTHORITY {
        value: [0, 0, 0, 0, 0, 5],
    };
    
    const SECURITY_BUILTIN_DOMAIN_RID: DWORD = 0x00000020;
    const DOMAIN_ALIAS_RID_ADMINS: DWORD = 0x00000220;
    
    #[link(name = "advapi32")]
    extern "system" {
        fn AllocateAndInitializeSid(
            pIdentifierAuthority: *const SID_IDENTIFIER_AUTHORITY,
            nSubAuthorityCount: u8,
            nSubAuthority0: DWORD,
            nSubAuthority1: DWORD,
            nSubAuthority2: DWORD,
            nSubAuthority3: DWORD,
            nSubAuthority4: DWORD,
            nSubAuthority5: DWORD,
            nSubAuthority6: DWORD,
            nSubAuthority7: DWORD,
            pSid: *mut *mut std::ffi::c_void,
        ) -> BOOL;
        
        fn CheckTokenMembership(
            TokenHandle: HANDLE,
            SidToCheck: *mut std::ffi::c_void,
            IsMember: *mut BOOL,
        ) -> BOOL;
        
        fn FreeSid(pSid: *mut std::ffi::c_void);
    }
    
    unsafe {
        let mut admin_sid: *mut std::ffi::c_void = ptr::null_mut();
        let mut is_member: BOOL = 0;
        
        // Create SID for administrators group
        let result = AllocateAndInitializeSid(
            &SECURITY_NT_AUTHORITY,
            2,
            SECURITY_BUILTIN_DOMAIN_RID,
            DOMAIN_ALIAS_RID_ADMINS,
            0, 0, 0, 0, 0, 0,
            &mut admin_sid,
        );
        
        if result == 0 {
            return false;
        }
        
        // Check if current token is member of administrators group
        let check_result = CheckTokenMembership(ptr::null_mut(), admin_sid, &mut is_member);
        
        // Free the SID
        FreeSid(admin_sid);
        
        check_result != 0 && is_member != 0
    }
}

#[no_mangle]
#[cfg(not(target_os = "windows"))]
pub extern "C" fn ff_is_running_as_admin() -> bool {
    // On non-Windows platforms, always return true (no admin check needed)
    true
}
