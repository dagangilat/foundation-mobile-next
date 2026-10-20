package com.rarilabs.rarime.modules.passportScan.nfc

import net.sf.scuba.smartcards.CardServiceException
import org.jmrtd.BACDeniedException
import org.jmrtd.BACKey
import org.jmrtd.CardServiceProtocolException
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.IOException

/**
 * Which failed chip reads put "Scan passport page again" first: only the
 * chip refusing the key made from the photo page, not the read breaking off.
 * The exceptions are shaped the way jmrtd's BAC throws them.
 */
class ChipReadFailureTest {
    /** BACProtocol wraps whatever MUTUAL AUTHENTICATE threw in this. */
    private fun bacMutualAuthFailed(cause: Throwable) =
        CardServiceProtocolException("BAC failed in MUTUAL AUTH", 2, cause)

    @Test
    fun wrongKeyStatusWordIsKeyRejected() {
        val chipAnswer = CardServiceException(
            "Mutual authentication failed, received empty data in response APDU",
            0x6300,
        )
        assertEquals(ChipReadFailure.KEY_REJECTED, ChipReadFailure.from(bacMutualAuthFailed(chipAnswer)))
    }

    @Test
    fun wrongKeyStatusWordAloneIsKeyRejected() {
        val chipAnswer = CardServiceException("Sending External Authenticate failed.", 0x6300)
        assertEquals(ChipReadFailure.KEY_REJECTED, ChipReadFailure.from(bacMutualAuthFailed(chipAnswer)))
    }

    @Test
    fun bacDeniedIsKeyRejected() {
        val denied = BACDeniedException("BAC denied", BACKey("X1234567", "800314", "310902"), 0x6300)
        assertEquals(ChipReadFailure.KEY_REJECTED, ChipReadFailure.from(denied))
    }

    @Test
    fun tagLostDuringBacIsReadFailed() {
        // Same wrapper as a refused key, but the connection broke.
        val lost = CardServiceException("Could not transmit", IOException("Tag was lost."))
        assertEquals(ChipReadFailure.READ_FAILED, ChipReadFailure.from(bacMutualAuthFailed(lost)))
    }

    @Test
    fun noResponseDuringMutualAuthIsReadFailed() {
        val noAnswer = CardServiceException("Mutual authentication failed, received null response APDU")
        assertEquals(ChipReadFailure.READ_FAILED, ChipReadFailure.from(bacMutualAuthFailed(noAnswer)))
    }

    @Test
    fun otherErrorsAreReadFailed() {
        assertEquals(ChipReadFailure.READ_FAILED, ChipReadFailure.from(IOException("Tag was lost.")))
        assertEquals(ChipReadFailure.READ_FAILED, ChipReadFailure.from(IllegalStateException("Cryptogram wrong length")))
        assertEquals(
            ChipReadFailure.READ_FAILED,
            ChipReadFailure.from(CardServiceProtocolException("BAC failed in GET CHALLENGE", 1)),
        )
        assertEquals(ChipReadFailure.READ_FAILED, ChipReadFailure.from(CardServiceException("File not found", 0x6A82)))
    }
}
