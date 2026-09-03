package com.rarilabs.rarime.modules.passportScan

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.rarilabs.rarime.R
import com.rarilabs.rarime.ui.components.PrimaryTextButton
import com.rarilabs.rarime.ui.theme.FoundationTheme

const val totalSteps = 3

@Composable
fun ScanPassportLayout(
    modifier: Modifier = Modifier,
    step: Int,
    title: String,
    text: String,
    onClose: () -> Unit,
    content: @Composable () -> Unit = {}
) {
    Column(
        modifier = modifier
            .background(FoundationTheme.colors.backgroundPrimary)
            .fillMaxSize()
            .padding(top = 24.dp)
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(24.dp),
            modifier = Modifier
                .padding(horizontal = 20.dp)
                .padding(bottom = 20.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = stringResource(R.string.step_indicator, step, totalSteps),
                    style = FoundationTheme.typography.body4,
                    color = FoundationTheme.colors.textSecondary
                )
                PrimaryTextButton(leftIcon = R.drawable.ic_close, onClick = onClose)
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = title,
                    style = FoundationTheme.typography.subtitle4,
                    color = FoundationTheme.colors.textPrimary
                )
                Text(
                    text = text,
                    style = FoundationTheme.typography.body4,
                    color = FoundationTheme.colors.textSecondary
                )
            }
        }
        content()
    }
}

@Preview
@Composable
fun PreviewScanPassportLayout() {
    ScanPassportLayout(
        step = 1,
        title = "Scan Passport",
        text = "Scan your passport to continue",
        onClose = {}
    ) {
        Box(
            modifier = Modifier
                .background(FoundationTheme.colors.baseBlack, RectangleShape)
                .fillMaxWidth()
                .fillMaxHeight(0.5f)
        )
    }
}