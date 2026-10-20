package com.rarilabs.rarime.modules.passportScan

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.rarilabs.rarime.BuildConfig
import com.rarilabs.rarime.R
import com.rarilabs.rarime.manager.NfcAvailability
import com.rarilabs.rarime.modules.main.LocalMainViewModel
import com.rarilabs.rarime.modules.main.ScreenInsets
import com.rarilabs.rarime.modules.passportScan.camera.ScanMRZStep
import com.rarilabs.rarime.modules.passportScan.guide.ChipConfirmScreen
import com.rarilabs.rarime.modules.passportScan.guide.ChipExplainerScreen
import com.rarilabs.rarime.modules.passportScan.guide.PhotoConfirmScreen
import com.rarilabs.rarime.modules.passportScan.guide.PhotoExplainerScreen
import com.rarilabs.rarime.modules.passportScan.guide.VerifyGuideScreen
import com.rarilabs.rarime.modules.passportScan.models.EDocument
import com.rarilabs.rarime.modules.passportScan.models.ScanPassportScreenViewModel
import com.rarilabs.rarime.modules.passportScan.nfc.ChipReadFailure
import com.rarilabs.rarime.modules.passportScan.nfc.OnResumeEffect
import com.rarilabs.rarime.modules.passportScan.nfc.ReadEDocStep
import com.rarilabs.rarime.modules.passportScan.nfc.RevocationStep
import com.rarilabs.rarime.modules.passportScan.nfc.openNfcSettings
import com.rarilabs.rarime.modules.passportScan.unsupportedPassports.NotAllowedPassportScreen
import com.rarilabs.rarime.modules.passportScan.unsupportedPassports.WaitlistPassportScreen
import com.rarilabs.rarime.util.Constants.NOT_ALLOWED_COUNTRIES
import com.rarilabs.rarime.util.ErrorHandler
import org.jmrtd.lds.icao.MRZInfo

/**
 * The verify flow, in order (approved mockups VerifyGuide ... GuideProof):
 * VERIFY_GUIDE -> PHOTO_EXPLAINER -> SCAN_MRZ -> PHOTO_CONFIRM -> GUIDE_CHIP
 * -> CHIP_EXPLAINER -> READ_NFC -> CHIP_CONFIRM -> GUIDE_PROOF, whose
 * "Build my proof" saves the passport and so starts registration. The rest
 * are the inherited side paths.
 *
 * A failed chip read stays on READ_NFC ("Try again", or "Scan passport page
 * again" back to SCAN_MRZ); the MRZ already read is kept for the retry.
 */
enum class ScanPassportState {
    VERIFY_GUIDE, PHOTO_EXPLAINER, SCAN_MRZ, PHOTO_CONFIRM, GUIDE_CHIP, CHIP_EXPLAINER, READ_NFC,
    CHIP_CONFIRM, GUIDE_PROOF,
    PASSPORT_DATA, GENERATE_PROOF, FINISH_PASSPORT_FLOW, UNSUPPORTED_PASSPORT, NOT_ALLOWED_PASSPORT,
    REVOCATION_PROCESS,
    GET_IN_TOUCH,
}

/**
 * Where the back chevron (and the system back gesture) goes from each verify
 * screen, per the mockups' back links. Null means leave the flow via
 * onClose: the three guide screens go back to Home. READ_NFC is null here
 * because its own chevron resets the NFC reader first; the system back
 * gesture there keeps closing the flow as before.
 */
internal fun verifyBackTarget(state: ScanPassportState): ScanPassportState? = when (state) {
    ScanPassportState.PHOTO_EXPLAINER -> ScanPassportState.VERIFY_GUIDE
    ScanPassportState.SCAN_MRZ -> ScanPassportState.PHOTO_EXPLAINER
    ScanPassportState.PHOTO_CONFIRM -> ScanPassportState.SCAN_MRZ
    ScanPassportState.CHIP_EXPLAINER -> ScanPassportState.GUIDE_CHIP
    ScanPassportState.CHIP_CONFIRM -> ScanPassportState.READ_NFC
    else -> null
}

/** Failed chip reads before the chip step also offers "Get in touch". */
private const val GET_IN_TOUCH_AFTER_ATTEMPTS = 3

@Composable
fun ScanPassportScreen(
    onClose: () -> Unit,
    scanPassportScreenViewModel: ScanPassportScreenViewModel = hiltViewModel(),
    initialEDocument: EDocument? = if (BuildConfig.isTestnet) scanPassportScreenViewModel.eDocument.value else null,
    innerPaddings: Map<ScreenInsets, Number> = mapOf(),
    setVisibilityOfBottomBar: (Boolean) -> Unit

) {
    val context = LocalContext.current
    val mainViewModel = LocalMainViewModel.current

    var state by remember { mutableStateOf(ScanPassportState.VERIFY_GUIDE) }
    var mrzData: MRZInfo? by remember { mutableStateOf(null) }

    var nfcAttempts by remember { mutableStateOf(0) }

    // Why the last chip read failed, shown on READ_NFC until the next try.
    var chipFailure: ChipReadFailure? by remember { mutableStateOf(null) }

    // Every way out of the flow goes through here, so a chip read that
    // failed and was never followed by a good one is recorded once, behind
    // Home's bell. (System back pops the route; the ViewModel's onCleared
    // covers that.)
    val leaveFlow: () -> Unit = {
        scanPassportScreenViewModel.reportUnrecoveredChipFailure()
        onClose()
    }

    val eDoc by scanPassportScreenViewModel.eDocument.collectAsState()

    LaunchedEffect(Unit) {
        setVisibilityOfBottomBar(false)
    }

    LaunchedEffect(Unit) {
        if (initialEDocument != null) {
            scanPassportScreenViewModel.setPassportTEMP(initialEDocument)
        }
    }

    // A failed chip read: stay on the chip step (it shows why and offers
    // another try). It used to restart the flow from the task guide, so the
    // photo page had to be scanned again for any chip hiccup. After a few
    // tries the step also offers "Get in touch", which this used to force.
    fun handleNFCError(e: Exception, failure: ChipReadFailure) {
        ErrorHandler.logError("NFC error", e.toString(), e)

        nfcAttempts++
        chipFailure = failure
        scanPassportScreenViewModel.onChipReadFailed(
            context.getString(
                when (failure) {
                    ChipReadFailure.KEY_REJECTED -> R.string.notification_reason_chip_key_rejected
                    ChipReadFailure.READ_FAILED -> R.string.notification_reason_chip_read_failed
                }
            )
        )
    }

    val backTarget = verifyBackTarget(state)
    BackHandler(enabled = backTarget != null) {
        backTarget?.let { state = it }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(
                // Null-safe: the ScanPassportPoints route passes no insets
                // (its ScreenInsetsContainer already pads for the bars).
                bottom = (innerPaddings[ScreenInsets.BOTTOM]?.toInt() ?: 0).dp,
                top = (innerPaddings[ScreenInsets.TOP]?.toInt() ?: 0).dp
            )
    ) {
        when (state) {
            ScanPassportState.VERIFY_GUIDE -> {
                VerifyGuideScreen(
                    completedSteps = 0,
                    onBack = leaveFlow,
                    onContinue = { state = ScanPassportState.PHOTO_EXPLAINER }
                )
            }

            ScanPassportState.PHOTO_EXPLAINER -> {
                PhotoExplainerScreen(
                    onBack = { state = ScanPassportState.VERIFY_GUIDE },
                    onOpenCamera = { state = ScanPassportState.SCAN_MRZ }
                )
            }

            ScanPassportState.SCAN_MRZ -> {
                ScanMRZStep(
                    onNext = {
                        mrzData = it
                        state = ScanPassportState.PHOTO_CONFIRM
                    },
                    onClose = { state = ScanPassportState.PHOTO_EXPLAINER }
                )
            }

            ScanPassportState.PHOTO_CONFIRM -> {
                val mrz = mrzData
                if (mrz != null) {
                    PhotoConfirmScreen(
                        documentNumber = mrz.documentNumber ?: "",
                        dateOfBirth = mrz.dateOfBirth ?: "",
                        dateOfExpiry = mrz.dateOfExpiry ?: "",
                        onBack = { state = ScanPassportState.SCAN_MRZ },
                        onContinue = { state = ScanPassportState.GUIDE_CHIP },
                        onScanAgain = { state = ScanPassportState.SCAN_MRZ }
                    )
                } else {
                    LaunchedEffect(Unit) { state = ScanPassportState.SCAN_MRZ }
                }
            }

            ScanPassportState.GUIDE_CHIP -> {
                VerifyGuideScreen(
                    completedSteps = 1,
                    onBack = leaveFlow,
                    onContinue = { state = ScanPassportState.CHIP_EXPLAINER }
                )
            }

            ScanPassportState.CHIP_EXPLAINER -> {
                // Say "no NFC" / "NFC is off" here, before the scan step,
                // and re-check when the person comes back from settings.
                val nfcAvailability by scanPassportScreenViewModel.nfcAvailability.collectAsState()
                OnResumeEffect { scanPassportScreenViewModel.refreshNfcAvailability() }

                ChipExplainerScreen(
                    onBack = { state = ScanPassportState.GUIDE_CHIP },
                    onStartChipScan = {
                        if (scanPassportScreenViewModel.refreshNfcAvailability() == NfcAvailability.READY) {
                            state = ScanPassportState.READ_NFC
                        }
                    },
                    nfcAvailability = nfcAvailability,
                    onOpenNfcSettings = { openNfcSettings(context) },
                )
            }

            ScanPassportState.READ_NFC -> {
                ReadEDocStep(
                    onNext = {
                        chipFailure = null
                        nfcAttempts = 0
                        scanPassportScreenViewModel.onChipReadSucceeded()
                        // Held, not saved yet: saving the passport is what
                        // starts registration (ZkIdentityScreen swaps to
                        // ZkIdentityPassport, which runs it), and that now
                        // waits for "Build my proof" on GUIDE_PROOF.
                        scanPassportScreenViewModel.setPassportTEMP(it)
                        state = ScanPassportState.CHIP_CONFIRM
                    },
                    onClose = {
                        chipFailure = null
                        state = ScanPassportState.CHIP_EXPLAINER
                    },
                    onError = { e, failure -> handleNFCError(e, failure) },
                    onScanPageAgain = {
                        chipFailure = null
                        state = ScanPassportState.SCAN_MRZ
                    },
                    chipFailure = chipFailure,
                    onRetry = { chipFailure = null },
                    onGetInTouch = if (nfcAttempts >= GET_IN_TOUCH_AFTER_ATTEMPTS) {
                        { state = ScanPassportState.GET_IN_TOUCH }
                    } else {
                        null
                    },
                    mrzInfo = mrzData!!,
                    autoStartScan = true
                )
            }

            ScanPassportState.CHIP_CONFIRM -> {
                ChipConfirmScreen(
                    onBack = { state = ScanPassportState.READ_NFC },
                    onContinue = { state = ScanPassportState.GUIDE_PROOF }
                )
            }

            ScanPassportState.GUIDE_PROOF -> {
                VerifyGuideScreen(
                    completedSteps = 2,
                    onBack = leaveFlow,
                    onContinue = {
                        // Exactly what a successful chip read used to do.
                        scanPassportScreenViewModel.savePassport()
                        setVisibilityOfBottomBar(true)
                    }
                )
            }

            ScanPassportState.PASSPORT_DATA -> {
                PassportDataStep(
                    onNext = {
                        state = ScanPassportState.GENERATE_PROOF

                    },
                    onClose = {
                        leaveFlow()
                        scanPassportScreenViewModel.resetPassportState()
                    },
                    eDocument = eDoc ?: throw IllegalStateException("No document")
                )
            }

            ScanPassportState.GENERATE_PROOF -> {}

            ScanPassportState.NOT_ALLOWED_PASSPORT -> {
                NotAllowedPassportScreen(
                    eDocument = eDoc ?: throw IllegalStateException("No Document"),
                    onClose = leaveFlow
                ) {
                    state = ScanPassportState.GENERATE_PROOF
                }
            }

            ScanPassportState.UNSUPPORTED_PASSPORT -> {
                WaitlistPassportScreen(
                    eDocument = eDoc ?: throw IllegalStateException("No Document"),
                    onClose = {
                        scanPassportScreenViewModel.savePassport()
                        leaveFlow()
                    }
                )
            }

            ScanPassportState.FINISH_PASSPORT_FLOW -> {
                // Upstream branched here on the user's points balance and sent
                // holders to the token-reservation screen. That programme and
                // its screen are removed, so the flow always takes what was the
                // no-balance path: persist the passport and close.
                leaveFlow()
                scanPassportScreenViewModel.savePassport()
            }

            ScanPassportState.REVOCATION_PROCESS -> {
                RevocationStep(mrzData = mrzData!!, onClose = {
                    scanPassportScreenViewModel.rejectRevocation()
                    leaveFlow()
                }, onNext = {
                    scanPassportScreenViewModel.finishRevocation()

                    if (!NOT_ALLOWED_COUNTRIES.contains(eDoc?.personDetails?.nationality)) {
                        state = ScanPassportState.FINISH_PASSPORT_FLOW
                    } else {
                        leaveFlow()
                    }
                }, onError = {
                    scanPassportScreenViewModel.finishRevocation()
                    state = ScanPassportState.UNSUPPORTED_PASSPORT
                })
            }

            ScanPassportState.GET_IN_TOUCH -> {
                GetInTouchScreen(
                    eDoc = eDoc,
                    onClose = {
                        scanPassportScreenViewModel.resetPassportState()
                        leaveFlow()
                    },
                    onSent = {
                        scanPassportScreenViewModel.resetPassportState()
                        leaveFlow()
                    }
                )
            }
        }
    }
}

@Preview
@Composable
private fun ScanPassportScreenPreview() {
    ScanPassportScreen(onClose = {}, setVisibilityOfBottomBar = {})
}