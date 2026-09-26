package com.rarilabs.rarime.modules.passportScan.nfc

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.rarilabs.rarime.R
import com.rarilabs.rarime.foundation.ui.FoundationButton
import com.rarilabs.rarime.foundation.ui.FoundationButtonStyle
import com.rarilabs.rarime.manager.NfcAvailability
import com.rarilabs.rarime.manager.NfcDisabledException
import com.rarilabs.rarime.manager.NfcNotSupportedException
import com.rarilabs.rarime.manager.ScanNFCState
import com.rarilabs.rarime.modules.passportScan.ScanPassportLayout
import com.rarilabs.rarime.modules.passportScan.components.ScanGuidesTrigger
import com.rarilabs.rarime.modules.passportScan.components.SpecificPassportGuide
import com.rarilabs.rarime.modules.passportScan.guide.VerifyCard
import com.rarilabs.rarime.modules.passportScan.guide.VerifyIcons
import com.rarilabs.rarime.modules.passportScan.models.EDocument
import com.rarilabs.rarime.modules.passportScan.models.ReadEDocStepViewModel
import com.rarilabs.rarime.ui.base.ButtonSize
import com.rarilabs.rarime.ui.components.AppAnimation
import com.rarilabs.rarime.ui.components.AppBottomSheet
import com.rarilabs.rarime.ui.components.PrimaryButton
import com.rarilabs.rarime.ui.components.rememberAppSheetState
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationTheme
import com.rarilabs.rarime.ui.theme.FoundationType
import org.jmrtd.lds.icao.MRZInfo


/**
 * The chip read. [autoStartScan] opens the scan sheet (which starts the NFC
 * read) as soon as the screen appears, for callers whose previous screen
 * already had a "Start chip scan" button; the Scan button stays for retries.
 *
 * Neither starts a scan unless NFC is usable: on a phone without NFC, or with
 * NFC off, the screen shows [NfcUnavailableCard] (and "Open NFC settings"
 * when it's only off) instead. NFC is re-checked on every ON_RESUME, so
 * coming back from settings with NFC on clears the message. That is not a
 * failed read: it never reaches [onError].
 *
 * A failed read keeps the person on this step. [onError] reports it, and the
 * caller passes it back as [chipFailure] (the caller owns it, so it can count
 * attempts and record a failure only if the flow is left without a read).
 * The screen then offers "Try again" ([onRetry], then the chip read alone,
 * with fresh NFC state) and "Scan passport page again" ([onScanPageAgain]);
 * when the chip refused the key made from the photo page
 * ([ChipReadFailure.KEY_REJECTED]) the page comes first. [onGetInTouch],
 * when set, adds a way to ask for help.
 */
@Composable
fun ReadEDocStep(
    mrzInfo: MRZInfo,
    onNext: (eDocument: EDocument) -> Unit,
    onClose: () -> Unit,
    onError: (e: Exception, failure: ChipReadFailure) -> Unit,
    onScanPageAgain: () -> Unit,
    chipFailure: ChipReadFailure? = null,
    onRetry: () -> Unit = {},
    onGetInTouch: (() -> Unit)? = null,
    readEDocStepViewModel: ReadEDocStepViewModel = hiltViewModel(),
    autoStartScan: Boolean = false,
) {
    val context = LocalContext.current
    val state by readEDocStepViewModel.state.collectAsState()
    val scanException by readEDocStepViewModel.scanExceptionInstance.collectAsState()

    val currentStep by readEDocStepViewModel.currentNfcScanStep.collectAsState()
    val nfcAvailability by readEDocStepViewModel.nfcAvailability.collectAsState()

    OnResumeEffect { readEDocStepViewModel.refreshNfcAvailability() }

    val hintType = remember {
        when (mrzInfo.nationality) {
            "USA" -> SpecificPassportGuide.USA
            else -> SpecificPassportGuide.Other
        }

    }

    fun handleScanPassportLayoutClose() {
        readEDocStepViewModel.resetState()
        readEDocStepViewModel.resetNfcScanStep()
        onClose()
    }

    fun handleScanPassportLayoutScanned() {
        readEDocStepViewModel.resetState()
        onNext(readEDocStepViewModel.eDocument)
    }

    val currentOnError by rememberUpdatedState(onError)

    fun handleScanPassportLayoutError(exception: Exception) {
        readEDocStepViewModel.resetState()
        readEDocStepViewModel.resetNfcScanStep()

        when (exception) {
            // No NFC, or NFC off: not a failed read. NfcManager has already
            // set nfcAvailability, so the screen now shows the matching
            // message ("This phone can't read passport chips" / "Turn on
            // NFC"). Not reported: it is no failed try, for the bell or the
            // attempt count.
            is NfcNotSupportedException, is NfcDisabledException -> Unit

            // Anything else (tag lost, timeout, a refused key, NFC dispatch
            // refused): the screen shows it and offers another try.
            else -> currentOnError(exception, ChipReadFailure.from(exception))
        }
    }

    // After composition, once per failure: ERROR can arrive a moment before
    // its exception (a read error is reported from a background thread), so
    // this waits for both. startScanning clears the last exception, so it
    // is never the previous attempt's.
    LaunchedEffect(state, scanException) {
        val exception = scanException
        if (state == ScanNFCState.ERROR && exception != null) {
            handleScanPassportLayoutError(exception)
        }
    }

    ReadEDocStepContent(
        handleScanPassportLayoutClose = { handleScanPassportLayoutClose() },
        handleScanPassportLayoutScanned = { handleScanPassportLayoutScanned() },
        state = state,
        startScanning = { readEDocStepViewModel.startScanning(mrzInfo) },
        stopScanning = { readEDocStepViewModel.resetState() },
        currentNfcScanStep = currentStep,
        resetNFCScanState = { readEDocStepViewModel.resetNfcScanStep() },
        hintType = hintType,
        autoStartScan = autoStartScan,
        nfcAvailability = nfcAvailability,
        checkNfcAvailability = { readEDocStepViewModel.refreshNfcAvailability() },
        onOpenNfcSettings = { openNfcSettings(context) },
        chipFailure = chipFailure,
        onRetry = onRetry,
        onScanPageAgain = {
            readEDocStepViewModel.resetState()
            readEDocStepViewModel.resetNfcScanStep()
            onScanPageAgain()
        },
        onGetInTouch = onGetInTouch,
    )
}

@Composable
private fun ReadEDocStepContent(
    handleScanPassportLayoutClose: () -> Unit,
    handleScanPassportLayoutScanned: () -> Unit,
    currentNfcScanStep: NfcScanStep,
    startScanning: () -> Unit,
    stopScanning: () -> Unit,
    state: ScanNFCState,
    resetNFCScanState: () -> Unit,
    hintType: SpecificPassportGuide,
    autoStartScan: Boolean = false,
    nfcAvailability: NfcAvailability = NfcAvailability.READY,
    checkNfcAvailability: () -> NfcAvailability = { NfcAvailability.READY },
    onOpenNfcSettings: () -> Unit = {},
    chipFailure: ChipReadFailure? = null,
    onRetry: () -> Unit = {},
    onScanPageAgain: () -> Unit = {},
    onGetInTouch: (() -> Unit)? = null,
) {
    val scanSheetState = rememberAppSheetState(showSheet = false)
    val isNfcReady = nfcAvailability == NfcAvailability.READY

    // Opening the sheet is what starts the NFC read, so every way in checks
    // NFC first (fresh, not the last known value) and stays put if it isn't
    // usable; the screen then shows why.
    fun openScanSheet() {
        if (checkNfcAvailability() == NfcAvailability.READY) {
            scanSheetState.show()
        }
    }

    // "Try again": the chip read only, from a clean NFC state; the photo
    // page details (MRZ) stay as they are.
    fun retryChipRead() {
        onRetry()
        stopScanning()
        resetNFCScanState()
        openScanSheet()
    }

    LaunchedEffect(Unit) {
        if (autoStartScan && chipFailure == null) {
            openScanSheet()
        }
    }

    // NFC went away while the sheet was up (switched off, then back to the
    // app): close it rather than leave it waiting for a chip it can't read.
    LaunchedEffect(isNfcReady) {
        if (!isNfcReady && scanSheetState.showSheet) {
            scanSheetState.hide()
            resetNFCScanState()
            stopScanning()
        }
    }


    AppBottomSheet(state = scanSheetState) {
        NfcScanBottomSheet(
            currentStep = currentNfcScanStep,
            onStart = startScanning,
            scanSheetState = scanSheetState,
            onClose = { scanSheetState.hide(); resetNFCScanState();stopScanning() }
        )
    }


    ScanPassportLayout(
        step = 2,
        title = stringResource(R.string.nfc_reader_title),
        text = stringResource(R.string.nfc_reader_text),
        onClose = { handleScanPassportLayoutClose() }
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(top = 50.dp),
                verticalArrangement = Arrangement.Top,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    when {
                        !isNfcReady -> NfcUnavailableCard(
                            availability = nfcAvailability,
                            modifier = Modifier.padding(horizontal = 20.dp),
                        )

                        chipFailure != null -> ChipReadFailureCard(
                            failure = chipFailure,
                            modifier = Modifier.padding(horizontal = 20.dp),
                        )

                        else -> AppAnimation(
                            modifier = Modifier
                                .scale(1.4f)
                                .size(240.dp),
                            id = R.raw.anim_passport_nfc,
                        )
                    }

                    // Outside the checks above on purpose: SCANNED and ERROR
                    // must still be handled when NFC has just gone away.
                    when (state) {
                        ScanNFCState.NOT_SCANNING -> if (isNfcReady && chipFailure == null) {
                            Column(
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Text(
                                    text = stringResource(R.string.nfc_reader_hint_1),
                                    style = FoundationTheme.typography.body4,
                                    color = FoundationTheme.colors.textSecondary,
                                    modifier = Modifier.width(250.dp),
                                    textAlign = TextAlign.Center
                                )
                            }
                        }

                        ScanNFCState.SCANNING -> {
//                            Text(
//                                text = stringResource(R.string.nfc_reader_scanning),
//                                style = FoundationTheme.typography.body4,
//                                color = FoundationTheme.colors.textSecondary,
//                                modifier = Modifier.width(250.dp),
//                                textAlign = TextAlign.Center
//                            )
                        }

                        ScanNFCState.SCANNED -> {
                            handleScanPassportLayoutScanned()
                        }

                        // The failure itself is handled once, after
                        // composition (ReadEDocStep's LaunchedEffect).
                        ScanNFCState.ERROR -> {
                            scanSheetState.hide()
                        }
                    }

                }
                Spacer(modifier = Modifier.weight(1f))
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(FoundationTheme.colors.backgroundPure)
                        .padding(bottom = 20.dp)
                        .padding(horizontal = 20.dp)
                ) {
                    when {
                        nfcAvailability == NfcAvailability.DISABLED -> FoundationButton(
                            modifier = Modifier.padding(top = 24.dp),
                            text = stringResource(R.string.nfc_open_settings),
                            onClick = onOpenNfcSettings,
                        )

                        // No NFC: nothing to press here. The back chevron
                        // leaves the flow.
                        nfcAvailability == NfcAvailability.NOT_SUPPORTED -> Unit

                        chipFailure != null -> ChipReadFailureActions(
                            failure = chipFailure,
                            onTryAgain = { retryChipRead() },
                            onScanPageAgain = onScanPageAgain,
                            onGetInTouch = onGetInTouch,
                        )

                        else -> {
                            ScanGuidesTrigger(
                                type = hintType,
                            )
                            PrimaryButton(
                                modifier = Modifier
                                    .padding(top = 24.dp)
                                    .fillMaxWidth(),
                                onClick = { openScanSheet() },
                                size = ButtonSize.Large,
                                text = stringResource(R.string.scan)
                            )
                        }
                    }
                }
            }
        }

    }

}

/** Why the last read failed, in the verify flow's card style. */
@Composable
private fun ChipReadFailureCard(failure: ChipReadFailure, modifier: Modifier = Modifier) {
    val isKeyRejected = failure == ChipReadFailure.KEY_REJECTED
    VerifyCard(modifier = modifier) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(FoundationBrand.DangerTint),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = VerifyIcons.Chip,
                    contentDescription = null,
                    tint = FoundationBrand.DangerIcon,
                    modifier = Modifier.size(22.dp),
                )
            }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = stringResource(
                        if (isKeyRejected) R.string.chip_key_rejected_title
                        else R.string.chip_read_failed_title
                    ),
                    style = FoundationType.headline,
                    color = FoundationBrand.Text,
                )
                Text(
                    text = stringResource(
                        if (isKeyRejected) R.string.chip_key_rejected_body
                        else R.string.chip_read_failed_body
                    ),
                    style = FoundationType.callout,
                    color = FoundationBrand.Muted,
                )
            }
        }
    }
}

/**
 * "Try again" and "Scan passport page again", the likelier fix first: the
 * chip read again after a read failure, the photo page when the chip refused
 * its details. The other one is the smaller text button.
 */
@Composable
private fun ChipReadFailureActions(
    failure: ChipReadFailure,
    onTryAgain: () -> Unit,
    onScanPageAgain: () -> Unit,
    onGetInTouch: (() -> Unit)?,
) {
    val tryAgain = stringResource(R.string.chip_try_again)
    val scanPageAgain = stringResource(R.string.chip_scan_page_again)
    val pageFirst = failure == ChipReadFailure.KEY_REJECTED

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 24.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        FoundationButton(
            text = if (pageFirst) scanPageAgain else tryAgain,
            onClick = if (pageFirst) onScanPageAgain else onTryAgain,
        )
        FoundationButton(
            text = if (pageFirst) tryAgain else scanPageAgain,
            onClick = if (pageFirst) onTryAgain else onScanPageAgain,
            style = FoundationButtonStyle.Text,
        )
        if (onGetInTouch != null) {
            FoundationButton(
                text = stringResource(R.string.chip_get_in_touch),
                onClick = onGetInTouch,
                style = FoundationButtonStyle.Text,
            )
        }
    }
}

@Preview
@Composable
private fun ReadEDocStepContentPreview() {
//    val mrzInfo = MRZInfo(
//        "P", "NNN", "", "", "", "NNN", "", Gender.UNSPECIFIED, "", ""
//    )
    ReadEDocStepContent(
        handleScanPassportLayoutClose = {},
        handleScanPassportLayoutScanned = {},
        state = ScanNFCState.NOT_SCANNING,
        currentNfcScanStep = NfcScanStep.PREPARING,
        stopScanning = {},
        startScanning = {},
        resetNFCScanState = {},
        hintType = SpecificPassportGuide.Other
    )
}

@Preview
@Composable
private fun ReadEDocStepReadFailedPreview() {
    ReadEDocStepContent(
        handleScanPassportLayoutClose = {},
        handleScanPassportLayoutScanned = {},
        state = ScanNFCState.NOT_SCANNING,
        currentNfcScanStep = NfcScanStep.PREPARING,
        stopScanning = {},
        startScanning = {},
        resetNFCScanState = {},
        hintType = SpecificPassportGuide.Other,
        chipFailure = ChipReadFailure.READ_FAILED,
        onGetInTouch = {},
    )
}

@Preview
@Composable
private fun ReadEDocStepKeyRejectedPreview() {
    ReadEDocStepContent(
        handleScanPassportLayoutClose = {},
        handleScanPassportLayoutScanned = {},
        state = ScanNFCState.NOT_SCANNING,
        currentNfcScanStep = NfcScanStep.PREPARING,
        stopScanning = {},
        startScanning = {},
        resetNFCScanState = {},
        hintType = SpecificPassportGuide.Other,
        chipFailure = ChipReadFailure.KEY_REJECTED,
    )
}
