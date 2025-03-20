package tech.threefold.mycelium

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {

    companion object {
        const val BOOT_EVENT = "tech.threefold.mycelium.BOOT_EVENT"
        private const val tag = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            try {
                val preferencesManager = PreferencesManager(context)
                val secretKey = preferencesManager.getSecretKey()
                val peers = preferencesManager.getPeers()

                //Log.i("BootReceiver","SECRET_KEY = $secretKey")
                //Log.i("BootReceiver","PEERS = $peers")


                // Start your service here
                /*val serviceIntent = Intent(context, TunService::class.java)
                serviceIntent.action = TunService.ACTION_START
                intent.putExtra("secret_key", secretKey)
                intent.putStringArrayListExtra("peers", ArrayList(peers))
                Log.i("BootReceiver","Starting service")
                context.startService(serviceIntent)*/
                /*
                Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK BootReceiver creating activity intent")
                    val activityIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_FROM_BACKGROUND)
                putExtra("from_boot_receiver", true)
            }
            
            Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK BootReceiver starting activity")
            context.startActivity(activityIntent)
            Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK BootReceiver activity started")*/
                Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK BootReceiver received BOOT_COMPLETED")

                val activityIntent = Intent()
                activityIntent.setClassName(context.packageName,
                    "tech.threefold.mycelium.MainActivity")
                activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activityIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                activityIntent.putExtra("from_boot_receiver", true)

                Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK BootReceiver starting activity with package: ${context.packageName}")
                context.startActivity(activityIntent)
                Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK BootReceiver activity started")


                // Wait for activity to initialize
                Thread.sleep(1000)

                Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK BootReceiver sending broadcast")
                val bootIntent = Intent(BOOT_EVENT)
                context.sendBroadcast(bootIntent)
                Log.e(tag, ">>>>>>>>>>>>>>>>>>>>>> IBK BootReceiver broadcast sent")
            } catch (e: Exception) {
                Log.e(tag, "Error in BootReceiver: ${e.message}")
            }
        } else {
            Log.e(tag, "IBK Unknown intent action: ${intent.action}")
        }
    }
}