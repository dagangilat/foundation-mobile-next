package com.rarilabs.rarime.modules.passportScan.nfc

import net.sf.scuba.smartcards.CardServiceException
import org.jmrtd.BACDeniedException
import java.io.IOException

/**
 * Why a chip read failed, as far as the chip-read step needs to know: it
 * keeps the person on that step either way, and only changes which way out
 * it puts first. Mirrors iOS's `ChipReadFailure`.
 */
enum class ChipReadFailure {
    /** Tag lost, timeout, a bad response...: another try usually works. */
    READ_FAILED,

    /**
     * The chip refused the access key made from the photo page (MRZ): most
     * likely a misread page, so scanning the page again comes first.
     */
    KEY_REJECTED;

    companion object {
        fun from(error: Throwable): ChipReadFailure =
            if (isAccessKeyRejected(error)) KEY_REJECTED else READ_FAILED
    }
}

/** ISO 7816 "authentication failed": what a chip answers BAC with a wrong key. */
private const val SW_AUTHENTICATION_FAILED = 0x6300

/**
 * True when [error] means the chip rejected the BAC/PACE key derived from
 * the MRZ, rather than the read breaking off.
 *
 * jmrtd reports a wrong key from BAC's MUTUAL AUTHENTICATE as a
 * CardServiceException carrying SW 0x6300 (and "Mutual authentication
 * failed, received empty data..."), wrapped in "BAC failed in MUTUAL AUTH".
 * That wrapper alone is not enough: a tag lost mid-BAC gets the same wrapper
 * around an IOException, and is a read failure. A failed PACE never gets
 * here, since NfcUseCase falls back to BAC.
 */
internal fun isAccessKeyRejected(error: Throwable): Boolean {
    val chain = generateSequence(error) { it.cause }.take(10).toList()

    // The connection broke: whatever it was doing, the key wasn't judged.
    if (chain.any { it is IOException }) return false

    return chain.any { e ->
        e is BACDeniedException ||
            (e is CardServiceException && e.getSW() == SW_AUTHENTICATION_FAILED) ||
            e.message.orEmpty().let { message ->
                message.contains("Mutual authentication failed", ignoreCase = true) &&
                    !message.contains("null response", ignoreCase = true)
            }
    }
}
