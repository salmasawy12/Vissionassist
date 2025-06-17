package com.example.visionassist

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import android.view.KeyEvent

import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import java.util.concurrent.Executor

class MainActivity : FlutterFragmentActivity() {

    private val VOLUME_CHANNEL = "com.example.volume_button"
    private val FINGERPRINT_CHANNEL = "com.example.fingerprint"

    private var volumeMethodChannel: MethodChannel? = null
    private var authCallbackInvoked = false
    private val KEY_NAME = "com.example.fingerprint_key"

    private var biometricPrompt: BiometricPrompt? = null  // ✅ Needed for cancelPrompt support

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Volume button channel
        volumeMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL)

        // Fingerprint authentication + ID channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FINGERPRINT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "authenticateOnce" -> authenticateOnce(result)
                "getFingerprintId" -> {
                    try {
                        val id = generateOrGetFingerprintId()
                        result.success(id)
                    } catch (e: Exception) {
                        result.error("KEY_ERROR", "Failed to get fingerprint ID: ${e.message}", null)
                    }
                }
                "cancelPrompt" -> {
                    cancelPrompt()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN && event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            volumeMethodChannel?.invokeMethod("volumeUpPressed", null)
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    private fun authenticateOnce(result: MethodChannel.Result) {
        authCallbackInvoked = false

        val executor: Executor = ContextCompat.getMainExecutor(this)

        biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    if (!authCallbackInvoked) {
                        authCallbackInvoked = true
                        result.success(true)
                    }
                }

                override fun onAuthenticationFailed() {
                    if (!authCallbackInvoked) {
                        authCallbackInvoked = true
                        result.success(false)
                        biometricPrompt?.cancelAuthentication() // ✅ Closes prompt after first fail
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    if (!authCallbackInvoked) {
                        authCallbackInvoked = true
                        result.error("AUTH_ERROR", errString.toString(), null)
                    }
                }
            })

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Authenticate")
            .setSubtitle("Place your finger on the sensor")
            .setNegativeButtonText("Cancel")
            .build()

        biometricPrompt?.authenticate(promptInfo)
    }

    private fun cancelPrompt() {
        biometricPrompt?.cancelAuthentication()
    }

    private fun generateOrGetFingerprintId(): String {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)

        if (!keyStore.containsAlias(KEY_NAME)) {
            val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            val keyGenParameterSpec = KeyGenParameterSpec.Builder(
                KEY_NAME,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_CBC)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
                .setUserAuthenticationRequired(true)
                .setInvalidatedByBiometricEnrollment(true)
                .build()
            keyGenerator.init(keyGenParameterSpec)
            keyGenerator.generateKey()
        }

        val secretKeyEntry = keyStore.getEntry(KEY_NAME, null) as KeyStore.SecretKeyEntry
        val secretKey = secretKeyEntry.secretKey
        val encoded = secretKey.encoded

        return if (encoded != null) {
            Base64.encodeToString(encoded, Base64.NO_WRAP)
        } else {
            "KEY:$KEY_NAME"
        }
    }
}
