package com.rarilabs.rarime.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.ClickableText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.rarilabs.rarime.R
import com.rarilabs.rarime.ui.theme.FoundationTheme
import com.rarilabs.rarime.util.Constants

@Composable
fun UiPrivacyCheckbox(
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    termsAcceptedState: AppCheckboxState = rememberAppCheckboxState(),
) {
    val uriHandler = LocalUriHandler.current

    // Deviation (Task C4): the upstream 3-link composition (Terms, Privacy, and an
    // Airdrop-Program-Terms link) is dropped to 2. The airdrop-terms link only makes
    // sense on the earn/claim/airdrop screens Task C5 deletes wholesale, but this
    // composable is ALSO used on VerifyPassportScreen.kt - a core, retained passport-
    // verification screen with no airdrop concept at all. Keeping a 3rd "Airdrop
    // Program Terms" link live there would be a real, user-visible product bug (not
    // just a branding one), so it's removed here rather than merely re-pointed.
    val termsAnnotation = buildAnnotatedString {
        append(stringResource(R.string.terms_check_agreement))
        pushStringAnnotation("URL", Constants.TERMS_URL)
        withStyle(SpanStyle(textDecoration = TextDecoration.Underline)) {
            append(stringResource(R.string.foundation_general_terms_conditions))
        }
        pop()
        append(stringResource(R.string.and))
        pushStringAnnotation("URL", Constants.PRIVACY_URL)
        withStyle(SpanStyle(textDecoration = TextDecoration.Underline)) {
            append(stringResource(R.string.foundation_privacy_notice))
        }
        pop()
    }

    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        AppCheckbox(state = termsAcceptedState, enabled = enabled)
        ClickableText(
            text = termsAnnotation,
            style = FoundationTheme.typography.body5.copy(color = FoundationTheme.colors.textSecondary),
            onClick = {
                termsAnnotation
                    .getStringAnnotations("URL", it, it)
                    .firstOrNull()?.let { stringAnnotation ->
                        uriHandler.openUri(stringAnnotation.item)
                    }
            }
        )
    }
}

@Preview
@Composable
fun UiPrivacyCheckboxPreview() {
    Column(
        modifier = Modifier
            .background(FoundationTheme.colors.backgroundPrimary)
            .padding(24.dp)
    ) {
        UiPrivacyCheckbox()
    }
}