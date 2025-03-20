package tech.threefold.mycelium

import android.content.Context
import android.util.Base64

class PreferencesManager(context: Context) {
    private val sharedPreferences = context.getSharedPreferences("mycelium_prefs", Context.MODE_PRIVATE)

    fun saveSecretKey(secretKey: ByteArray) {
        val base64Key = Base64.encodeToString(secretKey, Base64.DEFAULT)
        sharedPreferences.edit().putString("secret_key", base64Key).apply()
    }

    fun getSecretKey(): ByteArray? {
        val base64Key = sharedPreferences.getString("secret_key", null)
        return if (base64Key != null) {
            Base64.decode(base64Key, Base64.DEFAULT)
        } else {
            null
        }
    }

    fun savePeers(peers: List<String>) {
        val peersString = peers.joinToString(separator = "\n")
        sharedPreferences.edit().putString("peers", peersString).apply()
    }

    fun getPeers(): List<String> {
        val peersString = sharedPreferences.getString("peers", "") ?: ""
        return if (peersString.isNotEmpty()) {
            peersString.split("\n")
        } else {
            emptyList()
        }
    }

    fun clear() {
        sharedPreferences.edit().clear().apply()
    }
}