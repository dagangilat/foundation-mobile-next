package com.rarilabs.rarime.foundation.ui

import androidx.annotation.DrawableRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.rarilabs.rarime.R
import com.rarilabs.rarime.api.ext_integrator.ext_int_action_preview.handlers.ext_int_query_proof_handler.ExtIntQueryProofHandler
import com.rarilabs.rarime.foundation.AppNotification
import com.rarilabs.rarime.foundation.AppNotificationStore
import com.rarilabs.rarime.foundation.FoundationAuthManager
import com.rarilabs.rarime.foundation.FoundationVerificationManager
import com.rarilabs.rarime.foundation.VerificationState
import com.rarilabs.rarime.foundation.hasUnreadVerificationFailure
import com.rarilabs.rarime.manager.IdentityManager
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationType
import com.rarilabs.rarime.util.data.UniversalProof
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class FoundationVerifyCardViewModel @Inject constructor(
    private val verificationManager: FoundationVerificationManager,
    authManager: FoundationAuthManager,
    identityManager: IdentityManager,
    notificationStore: AppNotificationStore,
) : ViewModel() {
    val state: StateFlow<VerificationState> = verificationManager.state

    /** Home's bell list: an unread failed try turns the card's copy calm. */
    val notifications: StateFlow<List<AppNotification>> = notificationStore.entries

    /**
     * Non-null once the passport is registered (the passport flow has run to
     * completion). Until then the card's action is "Verify with passport", because
     * `beginVerification()` could only answer `NotRegistered`.
     */
    val registrationProof: StateFlow<UniversalProof?> = identityManager.registrationProof

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

    fun onProofFailed(message: String) = verificationManager.proofFlowFailed(message)
}

/**
 * Home's status card: whether this person is verified, and the one next step.
 *
 * After a failed try the card stays calm: "Not verified yet", "Your last try
 * didn't finish. The bell has the details." and Try again. The reason and
 * "Share app log" are in the bell's entry (Home's notifications sheet).
 *
 * - Passport not registered yet: "Not verified yet" + "Verify with passport",
 *   which opens the passport flow (its task guide first) through
 *   [onScanPassport].
 * - Registered but not yet verified with Foundation: "Finish verification",
 *   which runs the existing `beginVerification()` -> proof -> poll flow.
 * - Verified: the "Verified" pill and what that lets you prove.
 *
 * Under the card sits "Scan QR code" ([onScanQr]): the app's existing QR scan
 * sheet, so a partner site can request a proof. It becomes the primary action
 * once the person is verified.
 *
 * Mirrors iOS's `FoundationVerifyCardView`.
 */
@Composable
fun FoundationVerifyCard(
    onScanPassport: () -> Unit,
    onScanQr: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: FoundationVerifyCardViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val registrationProof by viewModel.registrationProof.collectAsState()
    val notifications by viewModel.notifications.collectAsState()

    FoundationVerifyCardContent(
        state = state,
        isPassportRegistered = registrationProof != null,
        hasUnreadFailure = notifications.hasUnreadVerificationFailure,
        onVerify = viewModel::beginVerification,
        onScanPassport = onScanPassport,
        onScanQr = onScanQr,
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
            onCancel = { viewModel.onProofDismissed() },
            // One report per failure: the manager's Failed state, which the
            // bell shows as "Verification didn't finish" with this reason.
            onFailMessage = { message -> viewModel.onProofFailed(message) },
        )
    }
}

@Composable
private fun FoundationVerifyCardContent(
    state: VerificationState,
    isPassportRegistered: Boolean,
    hasUnreadFailure: Boolean = false,
    onVerify: () -> Unit,
    onScanPassport: () -> Unit,
    onScanQr: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val isVerified = state is VerificationState.Verified
    // NotRegistered is the manager's own "no registration proof (or signed
    // out)" answer, so it routes back to the passport scan as well.
    val needsPassport = !isVerified &&
        (!isPassportRegistered || state is VerificationState.NotRegistered)
    // A failed try: Foundation's check failed (state), or a passport/proof
    // try failed and its bell entry is still unread. Either way the card
    // only says so calmly; the reason is behind the bell.
    val showsFailedTry = !isVerified && !state.isBusy &&
        (state is VerificationState.Failed || hasUnreadFailure)

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        FoundationCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "STATUS",
                    style = FoundationType.overline,
                    color = FoundationBrand.Muted,
                )
                Spacer(modifier = Modifier.weight(1f))
                if (isVerified) VerifiedPill()
            }
            Text(
                text = if (showsFailedTry) {
                    stringResource(R.string.home_card_not_verified_title)
                } else {
                    titleFor(state, needsPassport)
                },
                style = FoundationType.headline,
                color = FoundationBrand.Text,
            )
            Text(
                text = if (showsFailedTry) {
                    stringResource(R.string.home_card_failed_try_caption)
                } else {
                    captionFor(state, needsPassport)
                },
                style = FoundationType.callout,
                color = FoundationBrand.Muted,
            )
            when {
                isVerified -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CheckChip("Passport chip")
                    CheckChip("Unique person")
                }

                // Same action as the state's own button, worded as a retry:
                // the passport flow while no proof exists, else Foundation's
                // check again.
                showsFailedTry -> FoundationButton(
                    text = stringResource(R.string.home_card_try_again),
                    leadingIcon = R.drawable.ic_fnd_passport,
                    onClick = if (needsPassport) onScanPassport else onVerify,
                )

                // Opens the verify task guide (ScanPassportScreen starts on
                // it), so the label names the whole job, not the camera step.
                needsPassport -> FoundationButton(
                    text = "Verify with passport",
                    leadingIcon = R.drawable.ic_fnd_passport,
                    onClick = onScanPassport,
                )

                else -> FoundationButton(
                    text = buttonTitleFor(state),
                    isLoading = state.isBusy,
                    enabled = !state.isBusy,
                    onClick = onVerify,
                )
            }
        }

        FoundationButton(
            text = "Scan QR code",
            style = if (isVerified) FoundationButtonStyle.Primary else FoundationButtonStyle.Secondary,
            leadingIcon = R.drawable.ic_fnd_qr_code,
            onClick = onScanQr,
        )
    }
}

@Composable
private fun VerifiedPill() {
    Text(
        text = "Verified",
        style = FoundationType.footnote.copy(fontWeight = FontWeight.Bold),
        color = FoundationBrand.Accent,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(FoundationBrand.AccentTint)
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
private fun CheckChip(label: String, @DrawableRes icon: Int = R.drawable.ic_fnd_check) {
    val shape = RoundedCornerShape(8.dp)
    Row(
        modifier = Modifier
            .clip(shape)
            .background(FoundationBrand.Bg, shape)
            .border(1.dp, FoundationBrand.Border, shape)
            .padding(horizontal = 10.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            painter = painterResource(icon),
            contentDescription = null,
            tint = FoundationBrand.Accent,
            modifier = Modifier.size(14.dp),
        )
        Text(text = label, style = FoundationType.callout, color = FoundationBrand.Text)
    }
}

private val VerificationState.isBusy: Boolean
    get() = this is VerificationState.Starting ||
        this is VerificationState.AwaitingProof ||
        this is VerificationState.Polling

private fun titleFor(state: VerificationState, needsPassport: Boolean): String = when {
    state is VerificationState.Verified -> "You're a verified person"
    needsPassport -> "Not verified yet"
    else -> "Passport added"
}

private fun captionFor(state: VerificationState, needsPassport: Boolean): String = when {
    state is VerificationState.Verified ->
        "When a site asks, you can prove this without sharing your name or passport details."

    needsPassport ->
        "Verify once with your passport's chip to show you're a real, unique person. " +
            "Your name, photo and passport number stay on this phone."

    else -> "One last step: confirm you're a unique person. Your name, photo and passport number stay on this phone."
}

private fun buttonTitleFor(state: VerificationState): String = when (state) {
    is VerificationState.Starting,
    is VerificationState.AwaitingProof,
    is VerificationState.Polling,
    -> "Working…"

    is VerificationState.Failed -> "Try again"
    else -> "Finish verification"
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun FoundationVerifyCardNotVerifiedPreview() {
    FoundationVerifyCardContent(
        state = VerificationState.Idle,
        isPassportRegistered = false,
        onVerify = {},
        onScanPassport = {},
        onScanQr = {},
        modifier = Modifier.padding(24.dp),
    )
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun FoundationVerifyCardRegisteredPreview() {
    FoundationVerifyCardContent(
        state = VerificationState.Idle,
        isPassportRegistered = true,
        onVerify = {},
        onScanPassport = {},
        onScanQr = {},
        modifier = Modifier.padding(24.dp),
    )
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun FoundationVerifyCardVerifiedPreview() {
    FoundationVerifyCardContent(
        state = VerificationState.Verified(memberNumber = 42),
        isPassportRegistered = true,
        onVerify = {},
        onScanPassport = {},
        onScanQr = {},
        modifier = Modifier.padding(24.dp),
    )
}
