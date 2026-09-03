package com.rarilabs.rarime.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.rarilabs.rarime.R
import com.rarilabs.rarime.ui.theme.FoundationTheme

@Composable
fun ErrorView(
    title: String = "Error",
    subtitle: String = "Something went wrong",
    iconId: Int = R.drawable.ic_globe_simple_x
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(4.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            AppIcon(id = iconId, size = 100.dp, tint = FoundationTheme.colors.errorDarker)

            Text(
                text = title,
                style = FoundationTheme.typography.h2,
                color = FoundationTheme.colors.textPrimary
            )
            Text(
                text = subtitle,
                textAlign = TextAlign.Center,
                style = FoundationTheme.typography.subtitle4,
                color = FoundationTheme.colors.textSecondary
            )
        }

    }
}

@Preview(showBackground = true)
@Composable
private fun ErrorViewPreview() {
    ErrorView()
}