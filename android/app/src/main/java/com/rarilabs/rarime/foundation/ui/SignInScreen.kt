package com.rarilabs.rarime.foundation.ui

import androidx.annotation.DrawableRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.rarilabs.rarime.R
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationType
import com.rarilabs.rarime.util.Constants

private const val CODE_LENGTH = 6

/**
 * Email + 6-digit-code sign-in, styled after the pre-fork iOS `SignInView`:
 * the lockup header, "Sign in" title, a white email field that locks behind
 * a pencil once the code is sent, a monospace code field with a paste
 * button, one full-width green button, and "Check your inbox" + "Resend".
 *
 * Foundation's callables all run requireAuth, so this is the first screen a
 * new install sees - it sits above the passcode/intro flow, not inside it.
 * All state transitions and backend calls are [SignInViewModel]'s, unchanged.
 */
@Composable
fun SignInScreen(
    viewModel: SignInViewModel = hiltViewModel(),
) {
    val codeSent by viewModel.codeSent.collectAsState()
    val isBusy by viewModel.isBusy.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()

    var email by rememberSaveable { mutableStateOf("") }
    var code by rememberSaveable { mutableStateOf("") }

    SignInContent(
        email = email,
        code = code,
        codeSent = codeSent,
        isBusy = isBusy,
        errorMessage = errorMessage,
        onEmailChange = { email = it },
        onCodeChange = { code = it.filter(Char::isDigit).take(CODE_LENGTH) },
        onSendCode = { viewModel.sendCode(email) },
        onSubmitCode = { viewModel.submitCode(code) },
        onEditEmail = {
            code = ""
            viewModel.editEmail()
        },
    )
}

@Composable
private fun SignInContent(
    email: String,
    code: String,
    codeSent: Boolean,
    isBusy: Boolean,
    errorMessage: String,
    onEmailChange: (String) -> Unit,
    onCodeChange: (String) -> Unit,
    onSendCode: () -> Unit,
    onSubmitCode: () -> Unit,
    onEditEmail: () -> Unit,
) {
    val clipboardManager = LocalClipboardManager.current
    val uriHandler = LocalUriHandler.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FoundationBrand.Bg)
            .safeDrawingPadding()
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 20.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BrandLockup()
            Spacer(modifier = Modifier.weight(1f))
            if (codeSent) {
                FoundationIconButton(
                    icon = R.drawable.ic_fnd_x,
                    contentDescription = "Cancel",
                    tint = FoundationBrand.Muted,
                    enabled = !isBusy,
                    onClick = onEditEmail,
                )
            }
        }

        Spacer(modifier = Modifier.height(48.dp))

        Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Text(text = "Sign in", style = FoundationType.largeTitle, color = FoundationBrand.Text)
            Text(
                text = if (codeSent) {
                    "We emailed a $CODE_LENGTH-digit code to ${email.trim()}. Enter it below to sign in."
                } else {
                    "Enter your email. We'll send you a $CODE_LENGTH-digit code."
                },
                style = FoundationType.body,
                color = FoundationBrand.Muted,
            )

            SignInField(
                value = email,
                onValueChange = onEmailChange,
                placeholder = "Email",
                enabled = !codeSent && !isBusy,
                keyboardType = KeyboardType.Email,
                textStyle = FoundationType.bodyLarge.copy(color = FoundationBrand.Text),
                trailingIcon = if (codeSent) R.drawable.ic_fnd_pencil else null,
                trailingDescription = "Edit email",
                trailingEnabled = !isBusy,
                onTrailingClick = onEditEmail,
            )

            if (codeSent) {
                SignInField(
                    value = code,
                    onValueChange = onCodeChange,
                    placeholder = "$CODE_LENGTH-digit code",
                    enabled = !isBusy,
                    keyboardType = KeyboardType.Number,
                    textStyle = FoundationType.code.copy(color = FoundationBrand.Text),
                    trailingIcon = R.drawable.ic_fnd_clipboard,
                    trailingDescription = "Paste code from clipboard",
                    trailingEnabled = !isBusy,
                    onTrailingClick = {
                        // Accept anything holding at least six digits, e.g. a
                        // whole "Your code is 123456" line copied from the email.
                        val digits = clipboardManager.getText()?.text.orEmpty().filter(Char::isDigit)
                        if (digits.length >= CODE_LENGTH) onCodeChange(digits.take(CODE_LENGTH))
                    },
                )
            }

            if (codeSent) {
                FoundationButton(
                    text = if (isBusy) "Verifying…" else "Verify and sign in",
                    isLoading = isBusy,
                    enabled = !isBusy && code.trim().length == CODE_LENGTH,
                    onClick = onSubmitCode,
                )
            } else {
                FoundationButton(
                    text = if (isBusy) "Sending…" else "Send code",
                    isLoading = isBusy,
                    enabled = !isBusy && email.trim().contains("@"),
                    onClick = onSendCode,
                )
            }

            if (errorMessage.isNotEmpty()) {
                Text(
                    text = errorMessage,
                    style = FoundationType.body,
                    color = FoundationBrand.Danger,
                )
            } else if (codeSent) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Check your inbox for the $CODE_LENGTH-digit code.",
                        style = FoundationType.body,
                        color = FoundationBrand.Accent,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = "Resend",
                        style = FoundationType.button,
                        color = FoundationBrand.Accent,
                        modifier = Modifier
                            .alpha(if (isBusy) 0.5f else 1f)
                            .clickable(enabled = !isBusy, role = Role.Button, onClick = onSendCode)
                            .padding(vertical = 8.dp),
                    )
                }
            }

            if (!codeSent) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "By continuing you agree to the",
                        style = FoundationType.footnote,
                        color = FoundationBrand.Muted,
                        textAlign = TextAlign.Center,
                    )
                    Row {
                        LegalLink(text = "Terms") { uriHandler.openUri(Constants.TERMS_URL) }
                        Text(text = " and ", style = FoundationType.footnote, color = FoundationBrand.Muted)
                        LegalLink(text = "Privacy Policy") { uriHandler.openUri(Constants.PRIVACY_URL) }
                        Text(text = ".", style = FoundationType.footnote, color = FoundationBrand.Muted)
                    }
                }
            }
        }
    }
}

@Composable
private fun LegalLink(text: String, onClick: () -> Unit) {
    Text(
        text = text,
        style = FoundationType.footnote.copy(fontWeight = FontWeight.SemiBold),
        color = FoundationBrand.Accent,
        modifier = Modifier.clickable(role = Role.Button, onClick = onClick),
    )
}

/**
 * White field with a hairline border and an optional trailing green action
 * (pencil / paste), as in the iOS sign-in screen.
 */
@Composable
private fun SignInField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    enabled: Boolean,
    keyboardType: KeyboardType,
    textStyle: TextStyle,
    @DrawableRes trailingIcon: Int?,
    trailingDescription: String,
    trailingEnabled: Boolean,
    onTrailingClick: () -> Unit,
) {
    val shape = RoundedCornerShape(8.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(60.dp)
            .clip(shape)
            .background(FoundationBrand.Surface, shape)
            .border(1.dp, FoundationBrand.Border, shape)
            .padding(start = 16.dp, end = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.weight(1f),
            enabled = enabled,
            singleLine = true,
            textStyle = textStyle,
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            cursorBrush = SolidColor(FoundationBrand.Accent),
            decorationBox = { innerTextField ->
                Box(contentAlignment = Alignment.CenterStart) {
                    if (value.isEmpty()) {
                        Text(
                            text = placeholder,
                            style = textStyle,
                            color = FoundationBrand.Muted,
                            maxLines = 1,
                        )
                    }
                    innerTextField()
                }
            },
        )
        if (trailingIcon != null) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .alpha(if (trailingEnabled) 1f else 0.5f)
                    .clickable(enabled = trailingEnabled, role = Role.Button, onClick = onTrailingClick),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    painter = painterResource(trailingIcon),
                    contentDescription = trailingDescription,
                    tint = FoundationBrand.Accent,
                    modifier = Modifier.size(22.dp),
                )
            }
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun SignInEmailPreview() {
    SignInContent(
        email = "you@example.com",
        code = "",
        codeSent = false,
        isBusy = false,
        errorMessage = "",
        onEmailChange = {},
        onCodeChange = {},
        onSendCode = {},
        onSubmitCode = {},
        onEditEmail = {},
    )
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun SignInCodePreview() {
    SignInContent(
        email = "you@example.com",
        code = "",
        codeSent = true,
        isBusy = false,
        errorMessage = "",
        onEmailChange = {},
        onCodeChange = {},
        onSendCode = {},
        onSubmitCode = {},
        onEditEmail = {},
    )
}
