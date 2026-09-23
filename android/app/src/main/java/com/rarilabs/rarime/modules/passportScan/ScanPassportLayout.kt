package com.rarilabs.rarime.modules.passportScan

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.rarilabs.rarime.R
import com.rarilabs.rarime.foundation.ui.FoundationNavHeader
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationTheme
import com.rarilabs.rarime.ui.theme.FoundationType

const val totalSteps = 3

/**
 * Frame for each passport-scan step, in the Foundation look (approved
 * mockups ScanPhotoPage / TapChip): a back chevron with "Verify", the step's
 * title, "Step N of 3", then its one-line instruction. [onClose] is what the
 * old close button did; the chevron now triggers it.
 */
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
            .background(FoundationBrand.Bg)
            .fillMaxSize()
            .padding(top = 12.dp)
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier
                .padding(horizontal = 24.dp)
                .padding(bottom = 20.dp)
        ) {
            FoundationNavHeader(
                title = "Verify",
                onBack = onClose,
                modifier = Modifier.offset(x = (-12).dp),
            )
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = title,
                    style = FoundationType.title,
                    color = FoundationBrand.Text
                )
                Text(
                    text = stringResource(R.string.step_indicator, step, totalSteps),
                    style = FoundationType.body,
                    color = FoundationBrand.Muted
                )
            }
            Text(
                text = text,
                style = FoundationType.body,
                color = FoundationBrand.Muted
            )
        }
        content()
    }
}

@Preview
@Composable
fun PreviewScanPassportLayout() {
    ScanPassportLayout(
        step = 1,
        title = "Scan the photo page",
        text = "Lay your passport flat in good light, with no glare.",
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
