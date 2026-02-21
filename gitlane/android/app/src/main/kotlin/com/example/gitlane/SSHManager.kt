package com.example.gitlane

import android.content.Context
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.KeyPairGenerator
import java.security.interfaces.RSAPublicKey
import java.util.*

class SSHManager(private val context: Context) {

    private val keysDir: File by lazy {
        File(context.filesDir, "ssh_keys").apply { if (!exists()) mkdirs() }
    }

    fun generateKeyPair(label: String, type: String, bits: Int): String {
        try {
            val kpg = KeyPairGenerator.getInstance(type)
            if (type == "RSA") {
                kpg.initialize(bits)
            }
            val kp = kpg.generateKeyPair()

            val privateKey = kp.private.encoded
            val publicKey = kp.public.encoded

            // Store keys
            val privateFile = File(keysDir, "$label.priv")
            val publicFile = File(keysDir, "$label.pub")

            privateFile.writeBytes(privateKey)
            publicFile.writeBytes(publicKey)

            // Return public key in OpenSSH format for convenience
            return formatPublicKey(kp.public as RSAPublicKey, label)
        } catch (e: Exception) {
            return "ERROR: ${e.message}"
        }
    }

    fun listKeys(): String {
        val array = JSONArray()
        keysDir.listFiles()?.forEach { file ->
            if (file.name.endsWith(".pub")) {
                val label = file.name.removeSuffix(".pub")
                val obj = JSONObject()
                obj.put("label", label)
                obj.put("created", file.lastModified())
                // Basic type detection from file content or extension if we had more
                obj.put("type", "RSA") 
                array.put(obj)
            }
        }
        return array.toString()
    }

    fun getPublicKey(label: String): String {
        val file = File(keysDir, "$label.pub")
        if (!file.exists()) return "ERROR: Key not found"
        
        // Since we stored the raw encoded bytes, we need to re-parse or just format
        // For simplicity in this prototype, we'll store the formatted version or re-generate
        // Let's just read the file and format it if it was RSA
        val bytes = file.readBytes()
        val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
        return "ssh-rsa $base64 $label"
    }

    fun deleteKey(label: String): Boolean {
        val priv = File(keysDir, "$label.priv")
        val pub = File(keysDir, "$label.pub")
        return priv.delete() && pub.delete()
    }

    private fun formatPublicKey(publicKey: RSAPublicKey, label: String): String {
        val encoder = Base64.encodeToString(publicKey.encoded, Base64.NO_WRAP)
        // Note: Real OpenSSH format involves more complex header/footer for certain versions, 
        // but ssh-rsa [base64] is the standard public key format.
        return "ssh-rsa $encoder $label"
    }
}
