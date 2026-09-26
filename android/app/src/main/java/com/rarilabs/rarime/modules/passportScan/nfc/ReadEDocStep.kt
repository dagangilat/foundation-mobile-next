package com.rarilabs.rarime.modules.passportScan.nfc

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.rarilabs.rarime.R
import com.rarilabs.rarime.foundation.ui.FoundationButton
import com.rarilabs.rarime.manager.NfcAvailability
import com.rarilabs.rarime.manager.NfcDisabledException
import com.rarilabs.rarime.manager.NfcNotSupportedException
import com.rarilabs.rarime.manager.ScanNFCState
import com.rarilabs.rarime.modules.passportScan.ScanPassportLayout
import com.rarilabs.rarime.modules.passportScan.components.ScanGuidesTrigger
import com.rarilabs.rarime.modules.passportScan.components.SpecificPassportGuide
import com.rarilabs.rarime.modules.passportScan.models.EDocument
import com.rarilabs.rarime.modules.passportScan.models.ReadEDocStepViewModel
import com.rarilabs.rarime.ui.base.ButtonSize
import com.rarilabs.rarime.ui.components.AppAnimation
import com.rarilabs.rarime.ui.components.AppBottomSheet
import com.rarilabs.rarime.ui.components.PrimaryButton
import com.rarilabs.rarime.ui.components.rememberAppSheetState
import com.rarilabs.rarime.ui.theme.FoundationTheme
import okio.IOException
import org.jmrtd.lds.icao.MRZInfo


/**
 * The chip read. [autoStartScan] opens the scan sheet (which starts the NFC
 * read) as soon as the screen appears, for callers whose previous screen
 * already had a "Start chip scan" button; the Scan button stays for retries.
 *
 * Neither starts a scan unless NFC is usable: on a phone without NFC, or with
 * NFC off, the screen shows [NfcUnavailableCard] (and "Open NFC settings"
 * when it's only off) instead. NFC is re-checked on every ON_RESUME, so
 * coming back from settings with NFC on clears the message.
 */
@Composable
fun ReadEDocStep(
    mrzInfo: MRZInfo,
    onNext: (eDocument: EDocument) -> Unit,
    onClose: () -> Unit,
    onError: (e: Exception) -> Unit,
    readEDocStepViewModel: ReadEDocStepViewModel = hiltViewModel(),
    autoStartScan: Boolean = false,
) {
    val context = LocalContext.current
    val state by readEDocStepViewModel.state.collectAsState()
    val scanExceptionInstance = readEDocStepViewModel.scanExceptionInstance.collectAsState()

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

    @Composable
    fun handleScanPassportLayoutError() {
        // Null until this attempt's exception arrives (startScanning clears
        // the last one); reading it here recomposes once it does.
        val exception = scanExceptionInstance.value ?: return
        readEDocStepViewModel.resetState()
        readEDocStepViewModel.resetNfcScanStep()

        when (exception) {
            // No NFC, or NFC off: not a failed read. NfcManager has already
            // set nfcAvailability, so the screen now shows the matching
            // message ("This phone can't read passport chips" / "Turn on
            // NFC"). No toast, and no onError: that would send the person
            // into the failure flow for something a retry can't fix.
            is NfcNotSupportedException, is NfcDisabledException -> Unit

            else -> {
                val errorMessage = when (exception) {
                    is IOException -> stringResource(id = R.string.nfc_error_interrupt)
                    else -> stringResource(id = R.string.nfc_error_unknown)
                }

                Toast.makeText(
                    context,
                    errorMessage,
                    Toast.LENGTH_SHORT
                ).show()
                // IllegalStateException here is Android refusing to start
                // NFC dispatch (e.g. the activity wasn't resumed yet): the
                // chip was never touched, so "Try again" and the Scan button
                // are enough - it isn't a failed read either.
                if (exception !is IllegalStateException) {
                    onError(exception)
                }
            }
        }
    }

    ReadEDocStepContent(
        handleScanPassportLayoutClose = { handleScanPassportLayoutClose() },
        handleScanPassportLayoutScanned = { handleScanPassportLayoutScanned() },
        handleScanPassportLayoutError = { handleScanPassportLayoutError() },
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
    )
}

@Composable
private fun ReadEDocStepContent(
    handleScanPassportLayoutClose: () -> Unit,
    handleScanPassportLayoutScanned: () -> Unit,
    handleScanPassportLayoutError: @Composable () -> Unit,
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

    LaunchedEffect(Unit) {
        if (autoStartScan) {
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
                    if (isNfcReady) {
                        AppAnimation(
                            modifier = Modifier
                                .scale(1.4f)
                                .size(240.dp),
                            id = R.raw.anim_passport_nfc,
                        )
                    } else {
                        NfcUnavailableCard(
                            availability = nfcAvailability,
                            modifier = Modifier.padding(horizontal = 20.dp),
                        )
                    }

                    // Outside the NFC check on purpose: SCANNED and ERROR
                    // must still be handled when NFC has just gone away.
                    when (state) {
                        ScanNFCState.NOT_SCANNING -> if (isNfcReady) {
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

                        ScanNFCState.ERROR -> {
                            scanSheetState.hide()
                            handleScanPassportLayoutError()
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

                    when (nfcAvailability) {
                        NfcAvailability.READY -> {
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

                        NfcAvailability.DISABLED -> FoundationButton(
                            modifier = Modifier.padding(top = 24.dp),
                            text = stringResource(R.string.nfc_open_settings),
                            onClick = onOpenNfcSettings,
                        )

                        // No NFC: nothing to press here. The back chevron
                        // leaves the flow.
                        NfcAvailability.NOT_SUPPORTED -> Unit
                    }
                }
            }
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
        handleScanPassportLayoutError = {},
        state = ScanNFCState.NOT_SCANNING,
        currentNfcScanStep = NfcScanStep.PREPARING,
        stopScanning = {},
        startScanning = {},
        resetNFCScanState = {},
        hintType = SpecificPassportGuide.Other
    )
}