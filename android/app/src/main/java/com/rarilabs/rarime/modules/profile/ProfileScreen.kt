package com.rarilabs.rarime.modules.profile

import android.graphics.Bitmap
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.rarilabs.rarime.BuildConfig
import com.rarilabs.rarime.R
import com.rarilabs.rarime.data.enums.AppColorScheme
import com.rarilabs.rarime.data.enums.AppIcon
import com.rarilabs.rarime.foundation.ui.FoundationNavHeader
import com.rarilabs.rarime.ui.components.ConfirmationDialog
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationType
import com.rarilabs.rarime.util.Screen
import com.rarilabs.rarime.util.SendEmailUtil
import com.rarilabs.rarime.util.WalletUtil
import kotlinx.coroutines.launch

@Composable
fun ProfileScreen(
    appIcon: AppIcon,
    navigate: (String) -> Unit,
    onBack: () -> Unit = {},
    viewModel: ProfileViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    var isFeedbackDialogShown by remember { mutableStateOf(false) }

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult(), onResult = {
            isFeedbackDialogShown = false
        })

    val image = remember {
        viewModel.getImage()
    }

    val colorScheme by viewModel.colorScheme.collectAsState()

    ProfileScreenContent(
        evmAddress = WalletUtil.formatAddress(viewModel.evmAddress),
        passportImage = image,
        navigate = navigate,
        colorScheme = colorScheme,
        appIcon = appIcon,
        email = viewModel.signedInEmail,
        onBack = onBack,
        onSignOut = viewModel::signOut,
        onFeedbackConfirm = {
            val decryptedFile = viewModel.getDecryptedFeedbackFile()
            launcher.launch(SendEmailUtil.sendEmail(decryptedFile, context))
        })
}

/**
 * Foundation Profile (approved mockup "Profile"): who is signed in, then
 * grouped rows - backup and recovery, passcode and biometrics; privacy,
 * terms, help and feedback; sign out.
 *
 * Delete account is not here: it is the last item of Backup and recovery
 * ([ExportKeysScreen]), in its own danger section, away from Sign out.
 *
 * Hidden, not deleted: the theme and app-icon rows (Foundation is light-only
 * with one icon), the Ethereum address line and passport thumbnail. Their
 * routes still exist in MainScreenRoutes; nothing links to them from here.
 * [evmAddress], [passportImage], [colorScheme] and [appIcon] are still
 * accepted so the call site is unchanged.
 */
@Composable
fun ProfileScreenContent(
    appIcon: AppIcon,
    evmAddress: String,
    passportImage: Bitmap?,
    navigate: (String) -> Unit,
    colorScheme: AppColorScheme,
    email: String? = null,
    onBack: () -> Unit = {},
    onSignOut: () -> Unit = {},
    onFeedbackConfirm: suspend () -> Unit = {},
) {
    val scope = rememberCoroutineScope()

    Column(
        verticalArrangement = Arrangement.spacedBy(24.dp),
        modifier = Modifier
            .fillMaxSize()
            .background(FoundationBrand.Bg)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 12.dp)
    ) {
        FoundationNavHeader(
            title = stringResource(R.string.profile),
            onBack = onBack,
            modifier = Modifier.offset(x = (-12).dp),
        )

        if (!email.isNullOrBlank()) {
            ProfileGroup(contentPadding = 16.dp) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "SIGNED IN AS",
                        style = FoundationType.overline,
                        color = FoundationBrand.Muted,
                    )
                    Text(text = email, style = FoundationType.bodyLarge, color = FoundationBrand.Text)
                }
            }
        }

        ProfileGroup {
            ProfileRow(
                title = "Backup and recovery",
                onClick = { navigate(Screen.Main.Profile.ExportKeys.route) },
            )
            ProfileRow(
                title = "Passcode and biometrics",
                showDivider = false,
                onClick = { navigate(Screen.Main.Profile.AuthMethod.route) },
            )
        }

        ProfileGroup {
            ProfileRow(
                title = "Privacy policy",
                onClick = { navigate(Screen.Main.Profile.Privacy.route) },
            )
            ProfileRow(
                title = "Terms of use",
                onClick = { navigate(Screen.Main.Profile.Terms.route) },
            )
            ProfileRow(
                title = "Help and feedback",
                showDivider = false,
                onClick = {
                    scope.launch {
                        onFeedbackConfirm.invoke()
                    }
                },
            )
        }

        ProfileGroup {
            ProfileRow(
                title = "Sign out",
                titleColor = FoundationBrand.Danger,
                showChevron = false,
                showDivider = false,
                onClick = onSignOut,
            )
        }

        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Foundation ${BuildConfig.VERSION_NAME}",
            style = FoundationType.footnote,
            color = FoundationBrand.Muted,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/**
 * The danger section at the bottom of Backup and recovery: its own caption,
 * a line on what goes, and a red Delete account row. Tapping the row opens
 * the same "Delete your account?" confirmation as before; [onConfirmDelete]
 * runs `ProfileViewModel.clearAllData`.
 */
@Composable
fun DeleteAccountSection(
    isDeletingAccount: Boolean,
    /** Non-empty only when the server refused the delete - see below. */
    deleteAccountError: String,
    onConfirmDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var isDeleteAccountDialogShown by remember { mutableStateOf(false) }

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = stringResource(R.string.delete_account_section_title),
            style = FoundationType.overline,
            color = FoundationBrand.Muted,
        )
        Text(
            text = stringResource(R.string.delete_account_section_desc),
            style = FoundationType.callout,
            color = FoundationBrand.Muted,
        )
        ProfileGroup {
            ProfileRow(
                title = if (isDeletingAccount) {
                    stringResource(R.string.delete_account_in_progress)
                } else {
                    stringResource(R.string.delete_account)
                },
                titleColor = FoundationBrand.Danger,
                showChevron = false,
                showDivider = false,
                onClick = { if (!isDeletingAccount) isDeleteAccountDialogShown = true },
            )
        }

        // Only ever reached when the server refused: on success the process
        // restarts before this can recompose. Inline, not behind Home's bell:
        // the person is on this screen waiting for the answer.
        if (deleteAccountError.isNotEmpty()) {
            Text(
                text = deleteAccountError,
                style = FoundationType.callout,
                color = FoundationBrand.Danger,
            )
        }
    }

    if (isDeleteAccountDialogShown) {
        ConfirmationDialog(
            title = stringResource(R.string.delete_profile_title),
            subtitle = stringResource(R.string.delete_profile_desc),
            onConfirm = {
                // Dismiss FIRST. Deletion used to be unfailable from this
                // screen's point of view - it always ended in a process
                // restart - so leaving the dialog up cost nothing. Now that a
                // server refusal is a real outcome, an undismissed AlertDialog
                // would sit on top of the error above and the user would see
                // nothing happen at all.
                isDeleteAccountDialogShown = false
                onConfirmDelete()
            },
            onCancel = { isDeleteAccountDialogShown = false },
            cancelButtonText = stringResource(id = R.string.delete_profile_cancel_btn),
            confirmButtonText = stringResource(id = R.string.delete_profile_confirm_btn),
        )
    }
}

/** White grouped container: 12 radius, hairline border, rows inside. */
@Composable
private fun ProfileGroup(
    contentPadding: Dp = 0.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(FoundationBrand.Surface, shape)
            .border(1.dp, FoundationBrand.Border, shape)
            .padding(contentPadding),
        content = content,
    )
}

@Composable
private fun ProfileRow(
    title: String,
    onClick: () -> Unit,
    titleColor: Color = FoundationBrand.Text,
    showChevron: Boolean = true,
    showDivider: Boolean = true,
    enabled: Boolean = true,
) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = title,
                style = FoundationType.bodyLarge,
                color = titleColor,
                modifier = Modifier.weight(1f),
            )
            if (showChevron) {
                Icon(
                    painter = painterResource(R.drawable.ic_fnd_chevron_right),
                    contentDescription = null,
                    tint = FoundationBrand.Muted,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
        if (showDivider) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(FoundationBrand.Border)
            )
        }
    }
}

@Preview
@Composable
private fun ProfileScreenPreview() {
    ProfileScreenContent(
        evmAddress = "0xbF1823EF5Ca4484517F930c695b07544C2b43Efe",
        passportImage = null,
        navigate = {},
        colorScheme = AppColorScheme.LIGHT,
        appIcon = AppIcon.WHITE,
        email = "you@example.com",
    )
}
