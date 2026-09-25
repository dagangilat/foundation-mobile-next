package com.rarilabs.rarime.modules.passportScan.guide

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rarilabs.rarime.R
import com.rarilabs.rarime.foundation.ui.FoundationButton
import com.rarilabs.rarime.foundation.ui.FoundationNavHeader
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationType

/**
 * Shared pieces of the passport verify flow (approved mockups VerifyGuide,
 * GuideChip, GuideProof and the explainer / confirmation screens): the
 * three-segment stepper, the task guide, and the frame, card and rows the
 * step screens are built from.
 */

/** Text styles the verify screens use beyond [FoundationType]. */
internal object VerifyText {
    val small = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 20.sp,
    )
    val rowTitle = FoundationType.body.copy(fontWeight = FontWeight.SemiBold, lineHeight = 22.sp)
    val badge = FoundationType.footnote.copy(fontWeight = FontWeight.SemiBold, lineHeight = 18.sp)
    val stepperLabel = TextStyle(
        fontFamily = FontFamily.Default,
        fontSize = 12.sp,
        lineHeight = 16.sp,
    )
    val marker = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold,
        fontSize = 15.sp,
        lineHeight = 18.sp,
    )
    val mono = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp,
        lineHeight = 22.sp,
    )
}

private val StepperLabels = listOf(
    R.string.verify_stepper_photo,
    R.string.verify_stepper_chip,
    R.string.verify_stepper_proof,
)

/**
 * "1. Photo page / 2. Chip / 3. Proof". Segments before [currentStep] are
 * done (deep green), [currentStep] is current (light green), later ones are
 * still to come. A [currentStep] past 3 shows all three done.
 */
@Composable
fun VerifyStepper(currentStep: Int, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        StepperLabels.forEachIndexed { index, labelRes ->
            val step = index + 1
            val barColor: Color
            val labelColor: Color
            val labelWeight: FontWeight
            when {
                step < currentStep -> {
                    barColor = FoundationBrand.Accent
                    labelColor = FoundationBrand.Accent
                    labelWeight = FontWeight.SemiBold
                }

                step == currentStep -> {
                    barColor = FoundationBrand.BrandFill
                    labelColor = FoundationBrand.Text
                    labelWeight = FontWeight.Bold
                }

                else -> {
                    barColor = FoundationBrand.Border
                    labelColor = FoundationBrand.Muted
                    labelWeight = FontWeight.Medium
                }
            }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(5.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(barColor)
                )
                Text(
                    text = stringResource(labelRes),
                    style = VerifyText.stepperLabel.copy(fontWeight = labelWeight),
                    color = labelColor,
                    maxLines = 1,
                )
            }
        }
    }
}

/**
 * The page every verify screen sits on: back chevron with "Verify", then
 * [content] scrolling under it, and [actions] pinned to the bottom.
 */
@Composable
internal fun VerifyScreenFrame(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    actions: @Composable ColumnScope.() -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(FoundationBrand.Bg)
            .padding(top = 12.dp)
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            FoundationNavHeader(
                title = stringResource(R.string.verify_nav_title),
                onBack = onBack,
                modifier = Modifier.offset(x = (-12).dp),
            )
            content()
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            content = actions,
        )
    }
}

/** Title and lead paragraph. */
@Composable
internal fun VerifyHeading(
    title: String,
    lead: String,
    modifier: Modifier = Modifier,
    centered: Boolean = false,
) {
    val align = if (centered) TextAlign.Center else TextAlign.Start
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = title,
            style = FoundationType.title,
            color = FoundationBrand.Text,
            textAlign = align,
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
            text = lead,
            style = FoundationType.body,
            color = FoundationBrand.Muted,
            textAlign = align,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/** White card, 12 radius, hairline border, with its own padding and spacing. */
@Composable
internal fun VerifyCard(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(18.dp),
    spacing: Dp = 16.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(FoundationBrand.Surface, shape)
            .border(1.dp, FoundationBrand.Border, shape)
            .padding(contentPadding),
        verticalArrangement = Arrangement.spacedBy(spacing),
        content = content,
    )
}

/** Icon in a pale green circle, then a bold line and a muted one. */
@Composable
internal fun VerifyTipRow(icon: ImageVector, title: String, body: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(FoundationBrand.AccentTint),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = FoundationBrand.Accent,
                modifier = Modifier.size(22.dp),
            )
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(text = title, style = VerifyText.rowTitle, color = FoundationBrand.Text)
            Text(text = body, style = VerifyText.small, color = FoundationBrand.Muted)
        }
    }
}

/** A filled green check, then one line. */
@Composable
internal fun VerifyCheckRow(text: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(FoundationBrand.Accent),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = VerifyIcons.CheckBold,
                contentDescription = null,
                tint = FoundationBrand.OnAccent,
                modifier = Modifier.size(14.dp),
            )
        }
        Text(
            text = text,
            style = FoundationType.body,
            color = FoundationBrand.Text,
            modifier = Modifier.weight(1f),
        )
    }
}

/** Padlock and a short privacy line. */
@Composable
internal fun VerifyLockLine(
    text: String,
    modifier: Modifier = Modifier,
    centered: Boolean = false,
    iconSize: Dp = 18.dp,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = if (centered) {
            Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally)
        } else {
            Arrangement.spacedBy(10.dp)
        },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = VerifyIcons.Lock,
            contentDescription = null,
            tint = FoundationBrand.Muted,
            modifier = Modifier.size(iconSize),
        )
        Text(text = text, style = VerifyText.small, color = FoundationBrand.Muted)
    }
}

/** The big pale-green check at the top of a confirmation screen. */
@Composable
internal fun VerifySuccessBadge(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .size(96.dp)
            .clip(CircleShape)
            .background(FoundationBrand.AccentTint),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = VerifyIcons.CheckLarge,
            contentDescription = null,
            tint = FoundationBrand.Accent,
            modifier = Modifier.size(48.dp),
        )
    }
}

// ---- Task guide ----------------------------------------------------------

private enum class GuideStepStatus { Done, Next, Upcoming }

private data class GuideStep(@StringRes val title: Int, @StringRes val body: Int)

private val GuideSteps = listOf(
    GuideStep(R.string.verify_guide_step1_title, R.string.verify_guide_step1_body),
    GuideStep(R.string.verify_guide_step2_title, R.string.verify_guide_step2_body),
    GuideStep(R.string.verify_guide_step3_title, R.string.verify_guide_step3_body),
)

/**
 * The task guide between the verify steps: all three steps with Done / Next
 * marks. [completedSteps] 0 is the start ("Verify with your passport",
 * Start), 1 is after the photo page ("Photo page done", Continue), 2 is
 * after the chip ("Chip read", Build my proof).
 */
@Composable
fun VerifyGuideScreen(
    completedSteps: Int,
    onBack: () -> Unit,
    onContinue: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val titleRes: Int
    val leadRes: Int
    val buttonRes: Int
    when (completedSteps) {
        0 -> {
            titleRes = R.string.verify_guide_title
            leadRes = R.string.verify_guide_lead
            buttonRes = R.string.verify_guide_start
        }

        1 -> {
            titleRes = R.string.verify_guide_chip_title
            leadRes = R.string.verify_guide_chip_lead
            buttonRes = R.string.continue_btn
        }

        else -> {
            titleRes = R.string.verify_guide_proof_title
            leadRes = R.string.verify_guide_proof_lead
            buttonRes = R.string.verify_guide_build_proof
        }
    }

    VerifyScreenFrame(
        onBack = onBack,
        modifier = modifier,
        actions = {
            FoundationButton(text = stringResource(buttonRes), onClick = onContinue)
        },
    ) {
        VerifyHeading(title = stringResource(titleRes), lead = stringResource(leadRes))

        VerifyCard(contentPadding = PaddingValues(20.dp), spacing = 22.dp) {
            GuideSteps.forEachIndexed { index, step ->
                val number = index + 1
                val status = when {
                    number <= completedSteps -> GuideStepStatus.Done
                    number == completedSteps + 1 -> GuideStepStatus.Next
                    else -> GuideStepStatus.Upcoming
                }
                GuideStepRow(
                    number = number,
                    title = stringResource(step.title),
                    body = stringResource(step.body),
                    status = status,
                    showConnector = number < GuideSteps.size,
                )
            }
        }

        VerifyLockLine(text = stringResource(R.string.verify_guide_lock))
    }
}

@Composable
private fun GuideStepRow(
    number: Int,
    title: String,
    body: String,
    status: GuideStepStatus,
    showConnector: Boolean,
) {
    val connectorColor =
        if (status == GuideStepStatus.Done) FoundationBrand.Accent else FoundationBrand.Border

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .drawBehind {
                // The line down to the next step's marker, as in the mockup:
                // from under this marker into the gap before the next row.
                if (showConnector) {
                    val x = 16.dp.toPx()
                    drawLine(
                        color = connectorColor,
                        start = Offset(x, 40.dp.toPx()),
                        end = Offset(x, size.height + 12.dp.toPx()),
                        strokeWidth = 2.dp.toPx(),
                    )
                }
            },
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.Top,
    ) {
        GuideStepMarker(number = number, status = status)
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = title,
                    style = FoundationType.navTitle,
                    color = if (status == GuideStepStatus.Upcoming) FoundationBrand.Muted else FoundationBrand.Text,
                    modifier = Modifier.weight(1f),
                )
                when (status) {
                    GuideStepStatus.Done -> GuideStatusBadge(
                        text = stringResource(R.string.verify_guide_done),
                        textColor = FoundationBrand.Accent,
                        background = FoundationBrand.AccentTint,
                    )

                    GuideStepStatus.Next -> GuideStatusBadge(
                        text = stringResource(R.string.verify_guide_next),
                        textColor = FoundationBrand.Text,
                        background = FoundationBrand.Border,
                    )

                    GuideStepStatus.Upcoming -> Unit
                }
            }
            Text(text = body, style = VerifyText.small, color = FoundationBrand.Muted)
        }
    }
}

@Composable
private fun GuideStepMarker(number: Int, status: GuideStepStatus) {
    val base = Modifier
        .size(32.dp)
        .clip(CircleShape)
    when (status) {
        GuideStepStatus.Done -> Box(
            modifier = base.background(FoundationBrand.Accent),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = VerifyIcons.CheckBold,
                contentDescription = null,
                tint = FoundationBrand.OnAccent,
                modifier = Modifier.size(18.dp),
            )
        }

        GuideStepStatus.Next -> Box(
            modifier = base.background(FoundationBrand.Text),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = number.toString(), style = VerifyText.marker, color = FoundationBrand.OnAccent)
        }

        GuideStepStatus.Upcoming -> Box(
            modifier = base.border(2.dp, FoundationBrand.Border, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = number.toString(), style = VerifyText.marker, color = FoundationBrand.Muted)
        }
    }
}

@Composable
private fun GuideStatusBadge(text: String, textColor: Color, background: Color) {
    Text(
        text = text,
        style = VerifyText.badge,
        color = textColor,
        maxLines = 1,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(background)
            .padding(horizontal = 10.dp, vertical = 3.dp),
    )
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun VerifyGuideStartPreview() {
    VerifyGuideScreen(completedSteps = 0, onBack = {}, onContinue = {})
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun VerifyGuideChipPreview() {
    VerifyGuideScreen(completedSteps = 1, onBack = {}, onContinue = {})
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun VerifyGuideProofPreview() {
    VerifyGuideScreen(completedSteps = 2, onBack = {}, onContinue = {})
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun VerifyStepperPreview() {
    Column(
        modifier = Modifier.padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        VerifyStepper(currentStep = 1)
        VerifyStepper(currentStep = 2)
        VerifyStepper(currentStep = 3)
        VerifyStepper(currentStep = 4)
    }
}
