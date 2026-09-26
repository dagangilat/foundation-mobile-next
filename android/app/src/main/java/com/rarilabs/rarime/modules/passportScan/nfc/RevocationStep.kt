package com.rarilabs.rarime.modules.passportScan.nfc

import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.hilt.navigation.compose.hiltViewModel
import com.rarilabs.rarime.R
import com.rarilabs.rarime.manager.NfcAvailability
import com.rarilabs.rarime.manager.ScanNFCState
import com.rarilabs.rarime.modules.passportScan.ScanPassportLayout
import com.rarilabs.rarime.modules.passportScan.models.RevocationStepViewModel
import com.rarilabs.rarime.ui.components.AppAnimation
import com.rarilabs.rarime.ui.theme.FoundationTheme
import com.rarilabs.rarime.util.ErrorHandler
import kotlinx.coroutines.launch
import org.jmrtd.lds.icao.MRZInfo

/**
 * One more chip read, to sign the revocation challenge. It starts by itself,
 * but only once NFC is usable: on a phone without NFC, or with NFC off, it
 * shows [NfcUnavailableNotice] instead, and starts when the person comes
 * back from settings with NFC on (re-checked on every ON_RESUME).
 */
@Composable
fun RevocationStep(
    mrzData: MRZInfo,
    onNext: () -> Unit,
    onClose: () -> Unit,
    onError: () -> Unit,
    revocationStepViewModel: RevocationStepViewModel = hiltViewModel()
) {
    val scope = rememberCoroutineScope()
    val state by revocationStepViewModel.state.collectAsState()

    val revocationCallData by revocationStepViewModel.revocationCallData.collectAsState()
    val nfcAvailability by revocationStepViewModel.nfcAvailability.collectAsState()
    val isNfcReady = nfcAvailability == NfcAvailability.READY
    val context = LocalContext.current

    // Started once, when NFC is usable: straight away normally, or after the
    // person turns NFC on and comes back (OnResumeEffect re-checks it).
    var hasStartedScan by remember { mutableStateOf(false) }

    OnResumeEffect { revocationStepViewModel.refreshNfcAvailability() }

    LaunchedEffect(isNfcReady) {
        if (hasStartedScan) return@LaunchedEffect
        // Fresh check, not the last known value, before touching NFC.
        if (revocationStepViewModel.refreshNfcAvailability() != NfcAvailability.READY) {
            return@LaunchedEffect
        }
        hasStartedScan = true
        try {
            revocationStepViewModel.startScanning(mrzData = mrzData)
            // NFC went off between the check and the start: NfcManager has
            // published that, the notice shows, and this effect runs again
            // once NFC is back on.
            if (revocationStepViewModel.nfcAvailability.value != NfcAvailability.READY) {
                hasStartedScan = false
            }
        } catch (e: Exception) {
            ErrorHandler.logError("RevocationStep", "Error startScanning", e)
            onClose()
        }
    }

    LaunchedEffect(revocationCallData) {
        if (revocationCallData != null) {
            scope.launch {
                try {
                    revocationStepViewModel.invokeRevocation()

                    revocationStepViewModel.resetState()

                    onNext()
                } catch (e: Exception) {
                    revocationStepViewModel.resetState()
                    ErrorHandler.logError("RevocationStep", "Error revocation invoke", e)

                    onError()
                }
            }
        }
    }

    ScanPassportLayout(
        step = 2,
        title = stringResource(R.string.nfc_reader_title),
        text = stringResource(R.string.nfc_reader_text),
        onClose = {
            revocationStepViewModel.resetState()
            onClose()
        }) {
        Column(
            verticalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxSize()
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(48.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                if (isNfcReady) {
                    AppAnimation(
                        modifier = Modifier
                            .fillMaxWidth()
                            .zIndex(2f)
                            .padding(horizontal = 10.dp),
                        id = R.raw.anim_passport_nfc
                    )
                } else {
                    NfcUnavailableNotice(
                        availability = nfcAvailability,
                        onOpenSettings = { openNfcSettings(context) },
                        modifier = Modifier.padding(horizontal = 20.dp),
                    )
                }

                when (state) {
                    ScanNFCState.NOT_SCANNING -> if (isNfcReady) {
                        Text(
                            text = stringResource(R.string.nfc_reader_hint),
                            style = FoundationTheme.typography.body4,
                            color = FoundationTheme.colors.textSecondary,
                            modifier = Modifier.width(250.dp),
                            textAlign = TextAlign.Center
                        )
                    }

                    ScanNFCState.SCANNING -> {
                        Text(
                            text = stringResource(R.string.nfc_reader_scanning),
                            style = FoundationTheme.typography.body4,
                            color = FoundationTheme.colors.textSecondary,
                            modifier = Modifier.width(250.dp),
                            textAlign = TextAlign.Center
                        )
                    }

                    ScanNFCState.SCANNED -> {
                        Text(
                            text = stringResource(R.string.nfc_reader_revoke),
                            style = FoundationTheme.typography.body4,
                            color = FoundationTheme.colors.textSecondary,
                            modifier = Modifier.width(250.dp),
                            textAlign = TextAlign.Center
                        )
                    }

                    ScanNFCState.ERROR -> {
                        revocationStepViewModel.resetState()

                        // No NFC, or NFC off: NfcManager has already set
                        // nfcAvailability, so the notice above says so. Not a
                        // failed revocation, so no toast and no onError.
                        // Read the flow itself, not the collected value: it is
                        // set just before ERROR, so it is never stale here.
                        if (revocationStepViewModel.nfcAvailability.value == NfcAvailability.READY) {
                            Toast.makeText(context, R.string.nfc_reader_error, Toast.LENGTH_SHORT)
                                .show()

                            onError()
                        }
                    }
                }

            }
        }
    }
}