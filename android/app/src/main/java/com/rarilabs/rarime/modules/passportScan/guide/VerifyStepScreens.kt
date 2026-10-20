package com.rarilabs.rarime.modules.passportScan.guide

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rarilabs.rarime.R
import com.rarilabs.rarime.foundation.ui.FoundationButton
import com.rarilabs.rarime.foundation.ui.FoundationButtonStyle
import com.rarilabs.rarime.manager.NfcAvailability
import com.rarilabs.rarime.modules.passportScan.nfc.NfcUnavailableCard
import com.rarilabs.rarime.ui.theme.FoundationBrand
import java.util.Calendar

/**
 * The explainer before each passport step and the confirmation after it
 * (approved mockups PhotoExplainer, PhotoConfirm, ChipExplainer,
 * ChipConfirm). Pure UI: ScanPassportScreen decides where each button goes.
 */

// Illustration-only colours from the mockups (never text).
private val IllustrationGrey = Color(0xFFDBE4EE)
private val PassportCover = Color(0xFF0F766E)

// ---- Photo page ------------------------------------------------------------

@Composable
fun PhotoExplainerScreen(
    onBack: () -> Unit,
    onOpenCamera: () -> Unit,
    modifier: Modifier = Modifier,
) {
    VerifyScreenFrame(
        onBack = onBack,
        modifier = modifier,
        actions = {
            FoundationButton(
                text = stringResource(R.string.verify_photo_open_camera),
                onClick = onOpenCamera,
                leadingImage = VerifyIcons.ScanCamera,
            )
        },
    ) {
        VerifyStepper(currentStep = 1)
        PhotoPageIllustration()
        VerifyHeading(
            title = stringResource(R.string.verify_photo_title),
            lead = stringResource(R.string.verify_photo_lead),
        )
        VerifyCard {
            VerifyTipRow(
                icon = VerifyIcons.BookOpen,
                title = stringResource(R.string.verify_photo_tip1_title),
                body = stringResource(R.string.verify_photo_tip1_body),
            )
            VerifyTipRow(
                icon = VerifyIcons.Sun,
                title = stringResource(R.string.verify_photo_tip2_title),
                body = stringResource(R.string.verify_photo_tip2_body),
            )
            VerifyTipRow(
                icon = VerifyIcons.MoveHorizontal,
                title = stringResource(R.string.verify_photo_tip3_title),
                body = stringResource(R.string.verify_photo_tip3_body),
            )
        }
    }
}

/**
 * "Photo page read": the details the camera (or manual entry) produced, so
 * the person can catch a misread before the chip refuses them. Takes the MRZ
 * fields as read: [documentNumber] as printed, dates as YYMMDD.
 */
@Composable
fun PhotoConfirmScreen(
    documentNumber: String,
    dateOfBirth: String,
    dateOfExpiry: String,
    onBack: () -> Unit,
    onContinue: () -> Unit,
    onScanAgain: () -> Unit,
    modifier: Modifier = Modifier,
) {
    VerifyScreenFrame(
        onBack = onBack,
        modifier = modifier,
        actions = {
            FoundationButton(
                text = stringResource(R.string.verify_photo_confirm_yes),
                onClick = onContinue,
            )
            FoundationButton(
                text = stringResource(R.string.verify_photo_confirm_again),
                onClick = onScanAgain,
                style = FoundationButtonStyle.Text,
            )
        },
    ) {
        VerifyStepper(currentStep = 2)
        VerifySuccessBadge(modifier = Modifier.align(Alignment.CenterHorizontally))
        VerifyHeading(
            title = stringResource(R.string.verify_photo_confirm_title),
            lead = stringResource(R.string.verify_photo_confirm_lead),
            centered = true,
        )
        VerifyCard(
            contentPadding = PaddingValues(start = 18.dp, end = 18.dp, top = 6.dp, bottom = 4.dp),
            spacing = 0.dp,
        ) {
            DetailRow(
                label = stringResource(R.string.verify_photo_confirm_doc),
                value = maskDocumentNumber(documentNumber),
            )
            DetailDivider()
            DetailRow(
                label = stringResource(R.string.verify_photo_confirm_dob),
                value = formatMrzDate(dateOfBirth, isBirthDate = true),
            )
            DetailDivider()
            DetailRow(
                label = stringResource(R.string.verify_photo_confirm_expiry),
                value = formatMrzDate(dateOfExpiry, isBirthDate = false),
            )
        }
        VerifyLockLine(
            text = stringResource(R.string.verify_photo_confirm_kept),
            centered = true,
            iconSize = 16.dp,
        )
    }
}

@Composable
private fun DetailRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = VerifyText.small.copy(fontSize = 15.sp, lineHeight = 20.sp),
            color = FoundationBrand.Muted,
            modifier = Modifier.weight(1f),
        )
        Text(text = value, style = VerifyText.mono, color = FoundationBrand.Text, maxLines = 1)
    }
}

@Composable
private fun DetailDivider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(FoundationBrand.Border)
    )
}

/** A passport photo page with its two machine-readable lines outlined. */
@Composable
private fun PhotoPageIllustration() {
    val mrzStyle = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontSize = 9.sp,
        lineHeight = 11.sp,
        letterSpacing = 1.sp,
    )
    IllustrationPanel {
        val pageShape = RoundedCornerShape(10.dp)
        Column(
            modifier = Modifier
                .size(width = 240.dp, height = 160.dp)
                .shadow(elevation = 6.dp, shape = pageShape, clip = false)
                .clip(pageShape)
                .background(FoundationBrand.Surface)
                .border(1.dp, FoundationBrand.Border, pageShape)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(
                    modifier = Modifier
                        .size(width = 58.dp, height = 72.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(IllustrationGrey)
                )
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .padding(top = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(9.dp),
                ) {
                    listOf(1f, 0.7f, 0.85f).forEach { fraction ->
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(fraction)
                                .height(7.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(FoundationBrand.Border)
                        )
                    }
                }
            }
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .border(2.dp, FoundationBrand.Accent, RoundedCornerShape(6.dp))
                    .padding(horizontal = 6.dp, vertical = 5.dp),
                verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                listOf(
                    "P<XXX<<<<<<<<<<<<<<<<<<<<",
                    "0000000<0XXX<<<<<<<<<<",
                ).forEach { line ->
                    Text(
                        text = line,
                        style = mrzStyle,
                        color = FoundationBrand.Text,
                        maxLines = 1,
                        softWrap = false,
                        overflow = TextOverflow.Clip,
                    )
                }
            }
        }
    }
}

// ---- Chip ------------------------------------------------------------------

/**
 * "Now, the chip". When this phone can't read the chip right now
 * ([nfcAvailability] not READY) it says so before the scan step instead of
 * offering "Start chip scan": no NFC at all (no action; back leaves), or NFC
 * switched off ("Open NFC settings", [onOpenNfcSettings]).
 */
@Composable
fun ChipExplainerScreen(
    onBack: () -> Unit,
    onStartChipScan: () -> Unit,
    modifier: Modifier = Modifier,
    nfcAvailability: NfcAvailability = NfcAvailability.READY,
    onOpenNfcSettings: () -> Unit = {},
) {
    VerifyScreenFrame(
        onBack = onBack,
        modifier = modifier,
        actions = {
            when (nfcAvailability) {
                NfcAvailability.READY -> FoundationButton(
                    text = stringResource(R.string.verify_chip_start),
                    onClick = onStartChipScan,
                    leadingImage = VerifyIcons.Nfc,
                )

                NfcAvailability.DISABLED -> FoundationButton(
                    text = stringResource(R.string.nfc_open_settings),
                    onClick = onOpenNfcSettings,
                )

                NfcAvailability.NOT_SUPPORTED -> Unit
            }
        },
    ) {
        VerifyStepper(currentStep = 2)
        ChipIllustration()
        VerifyHeading(
            title = stringResource(R.string.verify_chip_title),
            lead = stringResource(R.string.verify_chip_lead),
        )
        NfcUnavailableCard(availability = nfcAvailability)
        // Scanning tips are no use on a phone that can't scan at all.
        if (nfcAvailability != NfcAvailability.NOT_SUPPORTED) {
            VerifyCard {
                VerifyTipRow(
                    icon = VerifyIcons.Smartphone,
                    title = stringResource(R.string.verify_chip_tip1_title),
                    body = stringResource(R.string.verify_chip_tip1_body),
                )
                VerifyTipRow(
                    icon = VerifyIcons.Chip,
                    title = stringResource(R.string.verify_chip_tip2_title),
                    body = stringResource(R.string.verify_chip_tip2_body),
                )
                VerifyTipRow(
                    icon = VerifyIcons.Plug,
                    title = stringResource(R.string.verify_chip_tip3_title),
                    body = stringResource(R.string.verify_chip_tip3_body),
                )
            }
        }
    }
}

/** "Chip read": the chip answered, on to the proof. */
@Composable
fun ChipConfirmScreen(
    onBack: () -> Unit,
    onContinue: () -> Unit,
    modifier: Modifier = Modifier,
) {
    VerifyScreenFrame(
        onBack = onBack,
        modifier = modifier,
        actions = {
            FoundationButton(text = stringResource(R.string.continue_btn), onClick = onContinue)
        },
    ) {
        VerifyStepper(currentStep = 3)
        VerifySuccessBadge(modifier = Modifier.align(Alignment.CenterHorizontally))
        VerifyHeading(
            title = stringResource(R.string.verify_chip_confirm_title),
            lead = stringResource(R.string.verify_chip_confirm_lead),
            centered = true,
        )
        VerifyCard(spacing = 14.dp) {
            VerifyCheckRow(stringResource(R.string.verify_chip_confirm_check1))
            VerifyCheckRow(stringResource(R.string.verify_chip_confirm_check2))
            VerifyCheckRow(stringResource(R.string.verify_chip_confirm_check3))
        }
    }
}

/** A closed passport with the chip symbol, a phone over it, and its signal. */
@Composable
private fun ChipIllustration() {
    IllustrationPanel {
        Box(modifier = Modifier.size(width = 250.dp, height = 168.dp)) {
            val coverShape = RoundedCornerShape(10.dp)
            Box(
                modifier = Modifier
                    .offset(x = 10.dp, y = 36.dp)
                    .size(width = 170.dp, height = 120.dp)
                    .shadow(elevation = 6.dp, shape = coverShape, clip = false)
                    .clip(coverShape)
                    .background(PassportCover)
            )
            Box(
                modifier = Modifier
                    .offset(x = 70.dp, y = 76.dp)
                    .size(width = 42.dp, height = 34.dp)
                    .border(2.dp, FoundationBrand.AccentTint, RoundedCornerShape(6.dp))
            )
            val phoneShape = RoundedCornerShape(16.dp)
            Box(
                modifier = Modifier
                    .offset(x = 110.dp, y = 4.dp)
                    .size(width = 84.dp, height = 160.dp)
                    .clip(phoneShape)
                    .background(FoundationBrand.Surface)
                    .border(3.dp, FoundationBrand.Text, phoneShape)
            )
            Box(
                modifier = Modifier
                    .offset(x = 150.dp, y = 10.dp)
                    .size(96.dp)
                    .border(2.dp, FoundationBrand.Market.copy(alpha = 0.35f), CircleShape)
            )
            Box(
                modifier = Modifier
                    .offset(x = 166.dp, y = 26.dp)
                    .size(64.dp)
                    .border(2.dp, FoundationBrand.Market.copy(alpha = 0.6f), CircleShape)
            )
        }
    }
}

/** The pale green, rounded panel an explainer illustration sits in. */
@Composable
private fun IllustrationPanel(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(168.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(FoundationBrand.MeshBase),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}

// ---- MRZ display -----------------------------------------------------------

private val MonthAbbreviations = listOf(
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
)

/** "•••••" and the last four characters, without the MRZ's `<` filler. */
internal fun maskDocumentNumber(documentNumber: String): String {
    val clean = documentNumber.replace("<", "").trim()
    return "•••••" + clean.takeLast(4)
}

/**
 * An MRZ date (YYMMDD) as "14 Mar 1980". The MRZ carries no century: a birth
 * year later than this year's two digits is 19xx, an expiry is always 20xx.
 * Anything that isn't a valid YYMMDD is shown as it came.
 */
internal fun formatMrzDate(
    yymmdd: String,
    isBirthDate: Boolean,
    currentYear: Int = Calendar.getInstance().get(Calendar.YEAR),
): String {
    val raw = yymmdd.trim()
    if (raw.length != 6 || !raw.all { it.isDigit() }) return raw
    val yy = raw.substring(0, 2).toInt()
    val month = raw.substring(2, 4).toInt()
    val day = raw.substring(4, 6)
    if (month !in 1..12 || day.toInt() !in 1..31) return raw
    val century = if (isBirthDate && yy > currentYear % 100) 1900 else 2000
    return "$day ${MonthAbbreviations[month - 1]} ${century + yy}"
}

// ---- Previews --------------------------------------------------------------

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun PhotoExplainerPreview() {
    PhotoExplainerScreen(onBack = {}, onOpenCamera = {})
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun PhotoConfirmPreview() {
    PhotoConfirmScreen(
        documentNumber = "X1234567<",
        dateOfBirth = "800314",
        dateOfExpiry = "310902",
        onBack = {},
        onContinue = {},
        onScanAgain = {},
    )
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun ChipExplainerPreview() {
    ChipExplainerScreen(onBack = {}, onStartChipScan = {})
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun ChipExplainerNfcOffPreview() {
    ChipExplainerScreen(
        onBack = {},
        onStartChipScan = {},
        nfcAvailability = NfcAvailability.DISABLED,
    )
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun ChipExplainerNoNfcPreview() {
    ChipExplainerScreen(
        onBack = {},
        onStartChipScan = {},
        nfcAvailability = NfcAvailability.NOT_SUPPORTED,
    )
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun ChipConfirmPreview() {
    ChipConfirmScreen(onBack = {}, onContinue = {})
}
