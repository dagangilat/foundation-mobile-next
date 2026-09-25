package com.rarilabs.rarime.modules.profile

import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.Scope
import com.google.api.services.drive.DriveScopes
import com.rarilabs.rarime.R
import com.rarilabs.rarime.manager.DriveState
import com.rarilabs.rarime.modules.recoveryMethod.RecoveryMethodDetailScreen
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationType
import kotlinx.coroutines.launch

/**
 * Backup and recovery (Profile's second level): the private key and its
 * Google Drive backup, then Delete account as the last item in its own
 * danger section, away from Profile's Sign out.
 */
@Composable
fun ExportKeysScreen(
    onBack: () -> Unit,
    viewModel: ExportKeysViewModel = hiltViewModel(),
    profileViewModel: ProfileViewModel = hiltViewModel(),
) {
    val context = LocalContext.current
    val privateKey by viewModel.privateKey.collectAsState()
    val driveState by viewModel.driveState.collectAsState()
    val isDriveButtonEnabled by viewModel.isDriveButtonEnabled.collectAsState()
    val isInit by viewModel.isInit.collectAsState()
    val isDeletingAccount by profileViewModel.isDeletingAccount.collectAsState()
    val deleteAccountError by profileViewModel.deleteAccountError.collectAsState()


    val scope = rememberCoroutineScope()

    // A failed backup has to be seen where the switch is, so these errors
    // show on this screen rather than behind Home's bell.
    val signInErrorText = stringResource(R.string.drive_error_cant_sign_in_google_identity_account)
    val backupErrorText = stringResource(R.string.drive_error_cant_back_up_your_private_key)
    val deleteErrorText = stringResource(R.string.drive_error_cant_delete_backup)
    var backupError by remember { mutableStateOf<String?>(null) }

    // Leaving mid-deletion would cancel it half way (the ViewModel's scope
    // goes with this screen), so back waits for the server's answer.
    BackHandler(enabled = isDeletingAccount) {}

    val googleSignInClient = remember(context) {
        GoogleSignIn.getClient(
            context,
            GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN).requestEmail()
                .requestScopes(Scope(DriveScopes.DRIVE_APPDATA)).build()
        )
    }

    val signInResultLauncher =
        rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
            viewModel.handleSignInResult(task) { error ->
                backupError = signInErrorText
            }
        }


    val signIn: () -> Unit = remember(googleSignInClient, signInResultLauncher) {
        { signInResultLauncher.launch(googleSignInClient.signInIntent) }
    }

    LaunchedEffect(Unit) {
        viewModel.userRecoverableAuthException.collect { exception ->
            signInResultLauncher.launch(exception.intent)
        }
    }

    val backUp: () -> Unit = remember {
        {
            scope.launch {
                backupError = null
                try {
                    viewModel.backupPrivateKey()
                } catch (e: Exception) {
                    backupError = backupErrorText
                }
            }
        }
    }

    val delete: () -> Unit = remember {
        {
            scope.launch {
                backupError = null
                try {
                    viewModel.deleteBackup()
                } catch (e: Exception) {
                    backupError = deleteErrorText
                }
            }
        }
    }

    ExportKeysContent(
        onBack = { if (!isDeletingAccount) onBack() },
        privateKey = privateKey!!,
        driveState = driveState,
        isDriveButtonEnabled = isDriveButtonEnabled,
        isInit = isInit,
        signIn = signIn,
        backUp = backUp,
        delete = delete,
        backupError = backupError,
        isDeletingAccount = isDeletingAccount,
        deleteAccountError = deleteAccountError,
        onConfirmDeleteAccount = { profileViewModel.clearAllData(context) },
    )
}


@Composable
fun ExportKeysContent(
    onBack: () -> Unit,
    privateKey: String,
    driveState: DriveState,
    isDriveButtonEnabled: Boolean,
    isInit: Boolean,
    signIn: () -> Unit,
    backUp: () -> Unit,
    delete: () -> Unit,
    backupError: String? = null,
    isDeletingAccount: Boolean = false,
    deleteAccountError: String = "",
    onConfirmDeleteAccount: () -> Unit = {},
) {

    ProfileRouteLayout(
        title = stringResource(R.string.recovery_method_details_screen_title),
        paddingHorizontal = 0.dp,
        onBack = onBack
    ) {

        RecoveryMethodDetailScreen(
            driveState = driveState,
            onClose = { onBack.invoke() },
            privateKey = privateKey,
            backupPrivateKey = backUp,
            isSwitchEnabled = isDriveButtonEnabled,
            deleteBackup = delete,
            signIn = {
                signIn.invoke()
            },
            isInit = isInit,
            isHeaderEnabled = false
        )

        if (!backupError.isNullOrBlank()) {
            Text(
                text = backupError,
                style = FoundationType.callout,
                color = FoundationBrand.Danger,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp),
            )
        }

        // Last, and set apart from the backup options above.
        DeleteAccountSection(
            isDeletingAccount = isDeletingAccount,
            deleteAccountError = deleteAccountError,
            onConfirmDelete = onConfirmDeleteAccount,
            modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 40.dp, bottom = 24.dp),
        )
    }
}


@Preview
@Composable
private fun ExportKeysScreenPreview() {
    Surface {
        ExportKeysContent(
            onBack = {},
            privateKey = "adasdladalkawl;dklawkadakdl;wdl;,al;wd,law,l;d,awl;d,dl;aw",
            driveState = DriveState.NOT_SIGNED_IN,
            isDriveButtonEnabled = false,
            isInit = true,
            {},
            {},
            {})
    }

}
