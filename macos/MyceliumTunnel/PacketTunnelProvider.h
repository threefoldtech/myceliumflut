//
//  PacketTunnelProvider.h
//  MyceliumTunnel
//
//  Created by Iwan BK on 01/09/24.
//

#ifndef PacketTunnelProvider_h
#define PacketTunnelProvider_h

#include <stdint.h>
#include <sys/types.h>

// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.
// Original source location: https://github.com/WireGuard/wireguard-apple/blob/2fec12a6e1f6e3460b6ee483aa00ad29cddadab1/Sources/WireGuardKitC/WireGuardKitC.h

#define CTLIOCGINFO 0xc0644e03UL
struct ctl_info
{
    u_int32_t ctl_id;
    char ctl_name[96];
};
struct sockaddr_ctl
{
    u_char sc_len;
    u_char sc_family;
    u_int16_t ss_sysaddr;
    u_int32_t sc_id;
    u_int32_t sc_unit;
    u_int32_t sc_reserved[5];
};

#endif /* PacketTunnelProvider_h */
