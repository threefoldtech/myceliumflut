package tech.threefold.mycelium

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.util.Log

private const val tag = "NetworkStateCallback"

class NetworkStateCallback(val context: Context): ConnectivityManager.NetworkCallback() {
    override fun onAvailable(network: Network) {
        super.onAvailable(network)
        Log.e(tag, "Network available ${network}")
    }
    override fun onBlockedStatusChanged(network: Network, blocked: Boolean) {
        super.onBlockedStatusChanged(network, blocked)
        Log.e(tag, "Network blocked ${network.toString()} blocked: $blocked")
    }
    override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
        super.onCapabilitiesChanged(network, networkCapabilities)
        Log.e(tag, "Network $network capabilities changed $networkCapabilities ")
    }

    override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
        super.onLinkPropertiesChanged(network, linkProperties)
        Log.e(tag, "Network ${network.toString()} link properties changed $linkProperties ")
    }

    override fun onLosing(network: Network, maxMsToLive: Int) {
        super.onLosing(network, maxMsToLive)
        Log.e(tag, "Network losing ${network.toString()} maxMsToLive: $maxMsToLive")
    }

    override fun onLost(network: Network) {
        super.onLost(network)
        Log.e(tag, "Network lost ${network.toString()}")
    }

    override fun onUnavailable() {
        super.onUnavailable()
        Log.e(tag, "Network unavailable ")
    }

    fun register() {
        /*val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            .addTransportType(NetworkCapabilities.TRANSPORT_ETHERNET)
            .addTransportType(NetworkCapabilities.TRANSPORT_USB)
            .addTransportType(NetworkCapabilities.TRANSPORT_VPN)
            .build()*/

        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        //manager.registerNetworkCallback(request, this)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Log.i(tag, "Registering default network callback");
            manager.registerDefaultNetworkCallback(this)
        }

        Log.e(tag, "NetworkStateCallback registered")
    }
}