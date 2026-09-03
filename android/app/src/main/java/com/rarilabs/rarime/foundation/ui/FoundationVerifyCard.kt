package com.rarilabs.rarime.foundation.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.rarilabs.rarime.api.ext_integrator.ext_int_action_preview.handlers.ext_int_query_proof_handler.ExtIntQueryProofHandler
import com.rarilabs.rarime.foundation.FoundationAuthManager
import com.rarilabs.rarime.foundation.FoundationVerificationManager
import com.rarilabs.rarime.foundation.VerificationState
import com.rarilabs.rarime.ui.base.ButtonSize
import com.rarilabs.rarime.ui.components.PrimaryButton
import com.rarilabs.rarime.ui.theme.FoundationTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class FoundationVerifyCardViewModel @Inject constructor(
    private val verificationManager: FoundationVerificationManager,
    authManager: FoundationAuthManager,
) : ViewModel() {
    val state: StateFlow<VerificationState> = verificationManager.state

    init {
        // A `Verified` state describes one Foundation member identity. Signing
        // out has to take it with it, or the next person to use this device
        // sees themselves as a verified member having verified nothing.
        viewModelScope.launch {
            authManager.uid.collect { uid ->
                if (uid == null) verificationManager.reset()
            }
        }
        resumePollingIfInterrupted()
    }

    /**
     * Restart the poller when this ViewModel is rebuilt while the flow is still
     * `Polling`.
     *
     * `MainScreen.navigateWithPopUp` pops with `popUpTo(graph.id) { inclusive =
     * true }`, so leaving Home - a bottom-bar tap, say - can destroy Home's
     * NavBackStackEntry and with it this ViewModel. That cancels `viewModelScope`
     * and kills a running `pollUntilVerified()`. The manager is a @Singleton, so
     * `state` survives at `Polling` with nothing left to advance it, and the card
     * would sit disabled on "Working…" until the process dies.
     *
     * `pollUntilVerified()` guards on `Polling` itself, so this is a no-op in
     * every other state.
     */
    private fun resumePollingIfInterrupted() {
        if (verificationManager.state.value !is VerificationState.Polling) return
        viewModelScope.launch { verificationManager.pollUntilVerified() }
    }

    fun beginVerification() {
        viewModelScope.launch { verificationManager.beginVerification() }
    }

    /**
     * Claims the success synchronously before launching the poller -
     * `proofRequestSucceeded()` is what tells a real success apart from an
     * abandoned sheet, and it must not lose that race to a dismissal.
     */
    fun onProofSucceeded() {
        if (!verificationManager.proofRequestSucceeded()) return
        viewModelScope.launch { verificationManager.pollUntilVerified() }
    }

    fun onProofDismissed() = verificationManager.proofFlowDismissed()

    fun onProofFailed() = verificationManager.proofFlowFailed()
}

/**
 * The Home entry point into Foundation verification. It lives on Home rather
 * than behind the QR tab because, unlike Rarimo's flow, ours is not started by
 * scanning someone else's code - the app asks our own backend for it.
 *
 * Mirrors iOS's `FoundationVerifyCardView`.
 */
@Composable
fun FoundationVerifyCard(
    modifier: Modifier = Modifier,
    viewModel: FoundationVerifyCardViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()

    FoundationVerifyCardContent(
        state = state,
        onVerify = viewModel::beginVerification,
        modifier = modifier,
    )

    // AD-2: the params URL goes straight into Rarimo's own proof flow, with no
    // deep link built or parsed. The handler is composed only while the state
    // holds a URL, so the sheet's lifetime is the state's lifetime.
    val awaitingProof = state as? VerificationState.AwaitingProof
    if (awaitingProof != null) {
        ExtIntQueryProofHandler(
            queryParams = null,
            proofParamsUrl = awaitingProof.proofParamsUrl,
            onSuccess = { viewModel.onProofSucceeded() },
            onFail = { viewModel.onProofFailed() },
            onCancel = { viewModel.onProofDismissed() },
        )
    }
}

@Composable
private fun FoundationVerifyCardContent(
    state: VerificationState,
    onVerify: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .background(
                color = FoundationTheme.colors.componentPrimary,
                shape = RoundedCornerShape(16.dp),
            )
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = "Verify with Foundation",
            style = FoundationTheme.typography.subtitle5,
            color = FoundationTheme.colors.textPrimary,
        )
        Text(
            text = captionFor(state),
            style = FoundationTheme.typography.body4,
            color = FoundationTheme.colors.textSecondary,
        )
        if (state.isBusy) {
            CircularProgressIndicator(
                modifier = Modifier.size(24.dp),
                color = FoundationTheme.colors.primaryMain,
            )
        }
        PrimaryButton(
            modifier = Modifier.fillMaxWidth(),
            text = buttonTitleFor(state),
            size = ButtonSize.Large,
            enabled = !state.isBusy && state !is VerificationState.Verified,
            onClick = onVerify,
        )
    }
}

private val VerificationState.isBusy: Boolean
    get() = this is VerificationState.Starting ||
        this is VerificationState.AwaitingProof ||
        this is VerificationState.Polling

private fun captionFor(state: VerificationState): String = when (state) {
    is VerificationState.NotRegistered ->
        "Scan your passport first, then come back here."

    is VerificationState.Verified -> "You're a verified Foundation member."
    is VerificationState.Failed -> state.message
    else -> "Prove you're a unique human, without revealing who you are."
}

private fun buttonTitleFor(state: VerificationState): String = when (state) {
    is VerificationState.Verified -> "Verified"
    is VerificationState.Starting,
    is VerificationState.AwaitingProof,
    is VerificationState.Polling,
    -> "Working…"

    is VerificationState.Failed -> "Try again"
    else -> "Verify"
}

@Preview(showBackground = true)
@Composable
private fun FoundationVerifyCardIdlePreview() {
    FoundationVerifyCardContent(state = VerificationState.Idle, onVerify = {})
}

@Preview(showBackground = true)
@Composable
private fun FoundationVerifyCardVerifiedPreview() {
    FoundationVerifyCardContent(
        state = VerificationState.Verified(memberNumber = 42),
        onVerify = {},
    )
}
