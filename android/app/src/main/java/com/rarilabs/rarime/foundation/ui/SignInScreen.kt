package com.rarilabs.rarime.foundation.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.rarilabs.rarime.ui.base.ButtonSize
import com.rarilabs.rarime.ui.components.AppTextField
import com.rarilabs.rarime.ui.components.PrimaryButton
import com.rarilabs.rarime.ui.components.TransparentButton
import com.rarilabs.rarime.ui.components.rememberAppTextFieldState
import com.rarilabs.rarime.ui.theme.FoundationTheme

private const val CODE_LENGTH = 6

/**
 * Email + 6-digit-code sign-in, mirroring iOS's `SignInView`.
 *
 * Foundation's callables all run requireAuth, so this is the first screen a
 * new install sees - it sits above the passcode/intro flow, not inside it.
 */
@Composable
fun SignInScreen(
    viewModel: SignInViewModel = hiltViewModel(),
) {
    val codeSent by viewModel.codeSent.collectAsState()
    val isBusy by viewModel.isBusy.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()

    val emailState = rememberAppTextFieldState("")
    val codeState = rememberAppTextFieldState("")

    // The view model owns the error; mirror it onto whichever field is showing
    // so the user reads it next to the input that produced it.
    LaunchedEffect(errorMessage, codeSent) {
        emailState.updateErrorMessage(if (!codeSent) errorMessage else "")
        codeState.updateErrorMessage(if (codeSent) errorMessage else "")
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FoundationTheme.colors.backgroundPrimary)
            .safeDrawingPadding()
            .imePadding()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        Text(
            text = "Sign in to Foundation",
            style = FoundationTheme.typography.h5,
            color = FoundationTheme.colors.textPrimary,
        )

        if (codeSent) {
            Text(
                text = "We emailed a $CODE_LENGTH-digit code to ${emailState.text}.",
                style = FoundationTheme.typography.body4,
                color = FoundationTheme.colors.textSecondary,
            )
            AppTextField(
                state = codeState,
                enabled = !isBusy,
                placeholder = "000000",
            )
            PrimaryButton(
                modifier = Modifier.fillMaxWidth(),
                size = ButtonSize.Large,
                text = if (isBusy) "Verifying…" else "Verify",
                enabled = !isBusy && codeState.text.trim().length == CODE_LENGTH,
                onClick = { viewModel.submitCode(codeState.text) },
            )
            TransparentButton(
                size = ButtonSize.Medium,
                text = "Use a different email",
                enabled = !isBusy,
                onClick = {
                    codeState.updateText("")
                    viewModel.editEmail()
                },
            )
        } else {
            AppTextField(
                state = emailState,
                enabled = !isBusy,
                placeholder = "you@example.com",
            )
            PrimaryButton(
                modifier = Modifier.fillMaxWidth(),
                size = ButtonSize.Large,
                text = if (isBusy) "Sending…" else "Send code",
                enabled = !isBusy && emailState.text.trim().contains("@"),
                onClick = { viewModel.sendCode(emailState.text) },
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun SignInScreenPreview() {
    Column(
        modifier = Modifier.padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        Text(
            text = "Sign in to Foundation",
            style = FoundationTheme.typography.h5,
            color = FoundationTheme.colors.textPrimary,
        )
        AppTextField(
            state = rememberAppTextFieldState(""),
            placeholder = "you@example.com",
        )
        PrimaryButton(
            modifier = Modifier.fillMaxWidth(),
            size = ButtonSize.Large,
            text = "Send code",
            onClick = {},
        )
    }
}
