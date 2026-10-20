package com.rarilabs.rarime.modules.passportScan.nfc

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.rarilabs.rarime.R
import com.rarilabs.rarime.foundation.ui.FoundationButton
import com.rarilabs.rarime.manager.NfcAvailability
import com.rarilabs.rarime.modules.passportScan.guide.VerifyCard
import com.rarilabs.rarime.modules.passportScan.guide.VerifyIcons
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationType
import com.rarilabs.rarime.util.ErrorHandler

/**
 * Why the chip can't be read on this phone right now, shown in place of a
 * scan that would only fail: no NFC at all ("This phone can't read passport
 * chips"), or NFC switched off ("Turn on NFC"). Draws nothing when
 * [availability] is [NfcAvailability.READY].
 *
 * Text only: each screen puts the "Open NFC settings" button where its own
 * primary action goes (see [NfcUnavailableNotice] for the card plus button).
 * Mirrors iOS's `NFCUnavailableCard`, which only has the no-NFC case: iOS has
 * no user-facing NFC switch.
 */
@Composable
fun NfcUnavailableCard(
    availability: NfcAvailability,
    modifier: Modifier = Modifier,
) {
    if (availability == NfcAvailability.READY) return

    val isDisabled = availability == NfcAvailability.DISABLED
    val title = stringResource(
        if (isDisabled) R.string.nfc_unavailable_disabled_title
        else R.string.nfc_unavailable_not_supported_title
    )
    val body = stringResource(
        if (isDisabled) R.string.nfc_unavailable_disabled_body
        else R.string.nfc_unavailable_not_supported_body
    )

    VerifyCard(modifier = modifier) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.Top,
        ) {
            // Green when the person can fix it (switch NFC on), red when
            // this phone simply can't do it.
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(if (isDisabled) FoundationBrand.AccentTint else FoundationBrand.DangerTint),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = VerifyIcons.Nfc,
                    contentDescription = null,
                    tint = if (isDisabled) FoundationBrand.Accent else FoundationBrand.DangerIcon,
                    modifier = Modifier.size(22.dp),
                )
            }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(text = title, style = FoundationType.headline, color = FoundationBrand.Text)
                Text(text = body, style = FoundationType.callout, color = FoundationBrand.Muted)
            }
        }
    }
}

/**
 * [NfcUnavailableCard] with, when NFC is only switched off, an "Open NFC
 * settings" button under it. For screens with no separate action area.
 */
@Composable
fun NfcUnavailableNotice(
    availability: NfcAvailability,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    if (availability == NfcAvailability.READY) return

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        NfcUnavailableCard(availability = availability)
        if (availability == NfcAvailability.DISABLED) {
            FoundationButton(
                text = stringResource(R.string.nfc_open_settings),
                onClick = onOpenSettings,
            )
        }
    }
}

/**
 * Opens the system NFC settings page, or the wireless settings page on
 * phones that don't have a separate NFC one.
 */
fun openNfcSettings(context: Context) {
    val intents = listOf(
        Intent(Settings.ACTION_NFC_SETTINGS),
        Intent(Settings.ACTION_WIRELESS_SETTINGS),
    )
    for (intent in intents) {
        if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
            return
        } catch (e: ActivityNotFoundException) {
            ErrorHandler.logDebug("NfcUnavailableNotice", "No activity for ${intent.action}")
        }
    }
    ErrorHandler.logError("NfcUnavailableNotice", "No settings screen to turn on NFC")
}

/**
 * Runs [onResume] on every ON_RESUME of the screen's lifecycle. An observer
 * added to an already-resumed lifecycle gets ON_RESUME replayed, so this
 * also runs once when the screen first appears. Used to re-check NFC when
 * the person comes back from system settings.
 */
@Composable
fun OnResumeEffect(onResume: () -> Unit) {
    val currentOnResume by rememberUpdatedState(onResume)
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) currentOnResume()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun NfcUnavailableNotSupportedPreview() {
    NfcUnavailableNotice(
        availability = NfcAvailability.NOT_SUPPORTED,
        onOpenSettings = {},
        modifier = Modifier.padding(24.dp),
    )
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun NfcUnavailableDisabledPreview() {
    NfcUnavailableNotice(
        availability = NfcAvailability.DISABLED,
        onOpenSettings = {},
        modifier = Modifier.padding(24.dp),
    )
}
