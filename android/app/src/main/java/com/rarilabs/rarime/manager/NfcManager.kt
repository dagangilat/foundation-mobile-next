package com.rarilabs.rarime.manager

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import com.rarilabs.rarime.util.ErrorHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class ScanNFCState {
    NOT_SCANNING, SCANNING, SCANNED, ERROR
}

/**
 * Whether this phone can read a passport chip right now. The UI checks it
 * before opening a scan, so a phone without NFC (or with NFC switched off)
 * gets a clear message instead of a failed scan.
 */
enum class NfcAvailability {
    /** No NFC hardware. Play hides the app from these phones (the manifest
     *  requires android.hardware.nfc), but a USB install still gets here. */
    NOT_SUPPORTED,

    /** NFC hardware present but switched off in system settings. */
    DISABLED,

    READY;

    companion object {
        fun of(context: Context): NfcAvailability {
            val adapter = try {
                NfcAdapter.getDefaultAdapter(context)
            } catch (e: UnsupportedOperationException) {
                // Some builds throw instead of returning null without the feature.
                null
            } ?: return NOT_SUPPORTED
            return if (adapter.isEnabled) READY else DISABLED
        }
    }
}

/** A chip read could not start: NFC can't be used on this phone right now. */
sealed class NfcUnavailableException(message: String) : Exception(message)

/** This phone has no NFC hardware. */
class NfcNotSupportedException : NfcUnavailableException("NFC is not supported on this device.")

/** NFC is switched off in system settings. */
class NfcDisabledException : NfcUnavailableException("NFC is disabled.")

class NfcManager @Inject constructor(
    private val context: Context
) {
    /** Set once foreground dispatch has been enabled on it; null before that
     *  and on a phone without NFC. */
    private var adapter: NfcAdapter? = null

    lateinit var activity: Activity

    private var handleTags: ((Tag) -> Unit)? = null
    private var onError: ((Exception) -> Unit)? = null

    private var _state = MutableStateFlow(ScanNFCState.NOT_SCANNING)
    val state: StateFlow<ScanNFCState>
        get() = _state.asStateFlow()

    private val _availability = MutableStateFlow(NfcAvailability.of(context))

    /** Last known [NfcAvailability]; screens re-check with [refreshAvailability]. */
    val availabilityState: StateFlow<NfcAvailability>
        get() = _availability.asStateFlow()

    /** Checks NFC now, without changing [availabilityState]. */
    fun availability(): NfcAvailability = NfcAvailability.of(context)

    /** Checks NFC now and publishes the result on [availabilityState]. */
    fun refreshAvailability(): NfcAvailability =
        availability().also { _availability.value = it }

    fun resetState() {
        _state.value = ScanNFCState.NOT_SCANNING
        disableForegroundDispatch()
    }

    /* ENABLE SCANNING */
    private fun enableForegroundDispatch() {
        ErrorHandler.logDebug("NfcManager", "Enabling NFC foreground dispatch")
        // Nullable on purpose: on a phone without NFC this is null, and the
        // old lateinit non-null field threw a NullPointerException here
        // before the null check could run.
        val nfcAdapter: NfcAdapter = try {
            NfcAdapter.getDefaultAdapter(activity)
        } catch (e: UnsupportedOperationException) {
            null
        } ?: throw NfcNotSupportedException()
        if (!nfcAdapter.isEnabled) {
            throw NfcDisabledException()
        }
        adapter = nfcAdapter
        val intent = Intent(context, activity.javaClass)
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        val pendingIntent =
            PendingIntent.getActivity(activity, 0, intent, PendingIntent.FLAG_MUTABLE)
        val filter = arrayOf(arrayOf("android.nfc.tech.IsoDep"))
        nfcAdapter.enableForegroundDispatch(activity, pendingIntent, null, filter)
    }

    /* DISABLE SCANNING */
    fun disableForegroundDispatch() {
        ErrorHandler.logDebug("NfcManager", "Disabling NFC foreground dispatch")

        val nfcAdapter = adapter ?: return
        try {
            nfcAdapter.disableForegroundDispatch(activity)
        } catch (e: IllegalStateException) {
            // Thrown when the activity is no longer resumed. The dispatch is
            // cleared before that check, and Android also drops it on pause.
            ErrorHandler.logDebug("NfcManager", "disableForegroundDispatch after pause: ${e.message}")
        }
    }

    /* SCAN HANDLING */
    fun handleNewIntent(intent: Intent) {
        ErrorHandler.logDebug("NfcManager", "Handling new NFC intent")
        if (NfcAdapter.ACTION_TAG_DISCOVERED == intent.action || NfcAdapter.ACTION_TECH_DISCOVERED == intent.action) {
            val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)
            tag?.let {
                // Handle the tag here or pass it to a ViewModel or other handler
                CoroutineScope(Dispatchers.Default).launch {
                    try {
                        _state.value = ScanNFCState.SCANNING

                        ErrorHandler.logDebug("NfcManager", "Handling tag: $it")
                        handleTags?.invoke(it)

                        _state.value = ScanNFCState.SCANNED
                    } catch (e: Exception) {
                        ErrorHandler.logError("NfcManager", "Error handling tag", e)
                        e.printStackTrace()

                        _state.value = ScanNFCState.ERROR

                        disableForegroundDispatch()

                        onError?.invoke(e)
                    }
                }
            }
        }
    }

    fun startScanning(customTagsHandler: (Tag) -> Unit, onError: (Exception) -> Unit) {
        try {
            enableForegroundDispatch()
            this.handleTags = customTagsHandler
            this.onError = onError
        } catch (e: Exception) {
            ErrorHandler.logError("NfcManager", "Error starting NFC scanning", e)
            // Published before ERROR, so a screen reacting to ERROR already
            // sees why and can show its NFC message instead of a failure.
            when (e) {
                is NfcNotSupportedException -> _availability.value = NfcAvailability.NOT_SUPPORTED
                is NfcDisabledException -> _availability.value = NfcAvailability.DISABLED
            }
            _state.value = ScanNFCState.ERROR
            onError(e)
            disableForegroundDispatch()
        }
    }
}