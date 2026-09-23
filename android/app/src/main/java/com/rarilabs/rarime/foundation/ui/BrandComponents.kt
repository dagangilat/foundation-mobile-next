package com.rarilabs.rarime.foundation.ui

import android.provider.Settings
import androidx.annotation.DrawableRes
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rarilabs.rarime.R
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationType
import kotlin.math.PI
import kotlin.math.sin

/**
 * False when the user has turned animations off (Developer options /
 * Accessibility "Remove animations" set the animator duration scale to 0),
 * and in previews. The Android counterpart of iOS's Reduce Motion check.
 */
@Composable
internal fun rememberAnimationsEnabled(): Boolean {
    val context = LocalContext.current
    val inPreview = LocalInspectionMode.current
    return remember(context, inPreview) {
        if (inPreview) {
            false
        } else {
            try {
                Settings.Global.getFloat(
                    context.contentResolver,
                    Settings.Global.ANIMATOR_DURATION_SCALE,
                    1f,
                ) != 0f
            } catch (e: Exception) {
                true
            }
        }
    }
}

/**
 * The Foundation wordmark: a half-filled shield, then "Found" in the text
 * colour and "ation" in the accent. Ported from the pre-fork iOS shell's
 * `BrandLockup` (PillarsHero.swift).
 */
@Composable
fun BrandLockup(
    modifier: Modifier = Modifier,
    iconSize: Dp = 24.dp,
    textSize: TextUnit = 22.sp,
    spacing: Dp = 10.dp,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(spacing),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_brand_shield),
            contentDescription = null,
            tint = FoundationBrand.Accent,
            modifier = Modifier.size(iconSize),
        )
        Row {
            val style = FoundationType.headline.copy(
                fontSize = textSize,
                lineHeight = textSize,
                fontWeight = FontWeight.Bold,
            )
            Text(text = "Found", style = style, color = FoundationBrand.Text)
            Text(text = "ation", style = style, color = FoundationBrand.Accent)
        }
    }
}

/**
 * The angled-cut trapezoid the mesh hero is clipped to: full width along the
 * top, the right edge running down to 62% of the height, then a diagonal to
 * the bottom-left corner. iOS `AngledCutShape`.
 */
private fun angledCutPath(size: Size): Path = Path().apply {
    moveTo(0f, 0f)
    lineTo(size.width, 0f)
    lineTo(size.width, size.height * 0.62f)
    lineTo(0f, size.height)
    close()
}

/**
 * A living gradient mesh behind [content], clipped by the angled cut.
 *
 * iOS draws this with `MeshGradient` (iOS 18). Compose has no mesh gradient
 * and `Modifier.blur` is a no-op below API 31 (minSdk is 27), so the blobs
 * are radial gradients that fade to transparent over the mesh base: the
 * same four blob colours at the same four edge midpoints, drifting on slow
 * independent sine phases. Static when animations are off.
 */
@Composable
fun FoundationMeshHero(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val animate = rememberAnimationsEnabled()
    val phase = if (animate) {
        val transition = rememberInfiniteTransition(label = "mesh_hero")
        val animatedPhase by transition.animateFloat(
            initialValue = 0f,
            targetValue = (2 * PI).toFloat(),
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 25_000, easing = LinearEasing),
                repeatMode = RepeatMode.Restart,
            ),
            label = "mesh_hero_phase",
        )
        animatedPhase
    } else {
        0f
    }

    Box(
        modifier = modifier.drawBehind {
            fun wobble(seed: Float, amplitude: Float = 0.06f): Float =
                amplitude * sin(phase + seed)

            // (colour, x, y) in unit space - top, left, right, bottom edge
            // midpoints, as in the iOS mesh's control grid.
            val blobs = listOf(
                Triple(FoundationBrand.MeshBlobs[0], 0.55f + wobble(0.0f, 0.04f), 0f + wobble(1.4f, 0.04f)),
                Triple(FoundationBrand.MeshBlobs[1], 0f + wobble(2.1f, 0.04f), 0.55f + wobble(0.7f)),
                Triple(FoundationBrand.MeshBlobs[2], 1f + wobble(1.9f, 0.04f), 0.5f + wobble(2.8f)),
                Triple(FoundationBrand.MeshBlobs[3], 0.4f + wobble(5.0f, 0.04f), 1f + wobble(0.3f, 0.04f)),
            )
            val radius = size.maxDimension * 0.52f

            clipPath(angledCutPath(size)) {
                drawRect(color = FoundationBrand.MeshBase)
                blobs.forEach { (color, x, y) ->
                    val center = Offset(x * size.width, y * size.height)
                    drawCircle(
                        brush = Brush.radialGradient(
                            0f to color,
                            0.45f to color.copy(alpha = 0.5f),
                            1f to color.copy(alpha = 0f),
                            center = center,
                            radius = radius,
                        ),
                        radius = radius,
                        center = center,
                    )
                }
            }
        },
    ) {
        content()
    }
}

/**
 * "Your / Voice. / Share. / Market." in the mesh hero. Ported from the
 * pre-fork iOS `PillarsHero`: 40-unit icon plus 48-unit bold label per row,
 * in the pillar colour, left-aligned.
 */
@Composable
fun PillarsHero(
    modifier: Modifier = Modifier,
    textSize: TextUnit = 48.sp,
    iconSize: Dp = 40.dp,
    rowSpacing: Dp = 4.dp,
) {
    val labelStyle = FoundationType.largeTitle.copy(
        fontSize = textSize,
        lineHeight = textSize * 1.12f,
        letterSpacing = (-1).sp,
        fontWeight = FontWeight.Bold,
    )
    FoundationMeshHero(modifier = modifier) {
        Column(verticalArrangement = Arrangement.spacedBy(rowSpacing)) {
            Text(text = "Your", style = labelStyle, color = FoundationBrand.Text, maxLines = 1)
            PillarRow(R.drawable.ic_pillar_voice, "Voice.", FoundationBrand.Voice, labelStyle, iconSize)
            PillarRow(R.drawable.ic_pillar_share, "Share.", FoundationBrand.Share, labelStyle, iconSize)
            PillarRow(R.drawable.ic_pillar_market, "Market.", FoundationBrand.Market, labelStyle, iconSize)
        }
    }
}

@Composable
private fun PillarRow(
    @DrawableRes icon: Int,
    label: String,
    color: Color,
    style: TextStyle,
    iconSize: Dp,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            painter = painterResource(icon),
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(iconSize),
        )
        Text(text = label, style = style, color = color, maxLines = 1)
    }
}

/**
 * A slim 2-unit capsule with a green segment sweeping across it: honest
 * about not knowing the ETA. iOS `LoadingView.IndeterminateBar`.
 */
@Composable
fun FoundationIndeterminateBar(
    modifier: Modifier = Modifier,
    width: Dp = 200.dp,
) {
    val animate = rememberAnimationsEnabled()
    val sweep = if (animate) {
        val transition = rememberInfiniteTransition(label = "loading_bar")
        val animatedSweep by transition.animateFloat(
            initialValue = -0.4f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 1400, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Restart,
            ),
            label = "loading_bar_sweep",
        )
        animatedSweep
    } else {
        0.3f
    }

    Canvas(
        modifier = modifier
            .width(width)
            .height(2.dp)
            .clip(RoundedCornerShape(1.dp)),
    ) {
        drawRoundRect(
            color = FoundationBrand.Accent,
            topLeft = Offset(sweep * size.width, 0f),
            size = Size(size.width * 0.4f, size.height),
            cornerRadius = CornerRadius(size.height / 2f, size.height / 2f),
        )
    }
}

/** Surface card: white, 12 radius, 1 border. */
@Composable
fun FoundationCard(
    modifier: Modifier = Modifier,
    contentPadding: Dp = 20.dp,
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
        verticalArrangement = Arrangement.spacedBy(12.dp),
        content = content,
    )
}

enum class FoundationButtonStyle { Primary, Secondary, Text }

/**
 * Full-width Foundation button: green fill (primary), white with a hairline
 * border and green label (secondary), or a bare green label (text). Radius 8,
 * drawn at 0.7 opacity when disabled, as in the iOS sign-in button.
 */
@Composable
fun FoundationButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: FoundationButtonStyle = FoundationButtonStyle.Primary,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    @DrawableRes leadingIcon: Int? = null,
) {
    val shape = RoundedCornerShape(8.dp)
    val background = when (style) {
        FoundationButtonStyle.Primary -> FoundationBrand.Accent
        FoundationButtonStyle.Secondary -> FoundationBrand.Surface
        FoundationButtonStyle.Text -> Color.Transparent
    }
    val contentColor = when (style) {
        FoundationButtonStyle.Primary -> FoundationBrand.OnAccent
        else -> FoundationBrand.Accent
    }
    val borderColor =
        if (style == FoundationButtonStyle.Secondary) FoundationBrand.Border else Color.Transparent

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp)
            .alpha(if (enabled) 1f else 0.7f)
            .clip(shape)
            .background(background, shape)
            .border(1.dp, borderColor, shape)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                color = contentColor,
                strokeWidth = 2.dp,
            )
        } else if (leadingIcon != null) {
            Icon(
                painter = painterResource(leadingIcon),
                contentDescription = null,
                tint = contentColor,
                modifier = Modifier.size(20.dp),
            )
        }
        Text(
            text = text,
            style = FoundationType.button,
            color = contentColor,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
    }
}

/** 44-unit round tap target holding a 26-unit icon. */
@Composable
fun FoundationIconButton(
    @DrawableRes icon: Int,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tint: Color = FoundationBrand.Text,
    enabled: Boolean = true,
    iconSize: Dp = 26.dp,
) {
    Box(
        modifier = modifier
            .size(44.dp)
            .clip(CircleShape)
            .alpha(if (enabled) 1f else 0.5f)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            painter = painterResource(icon),
            contentDescription = contentDescription,
            tint = tint,
            modifier = Modifier.size(iconSize),
        )
    }
}

/** Back chevron plus a small title: the header of pushed Foundation screens. */
@Composable
fun FoundationNavHeader(
    title: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(44.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FoundationIconButton(
            icon = R.drawable.ic_fnd_chevron_left,
            contentDescription = "Back",
            onClick = onBack,
        )
        Text(text = title, style = FoundationType.navTitle, color = FoundationBrand.Text)
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun BrandLockupPreview() {
    BrandLockup(modifier = Modifier.padding(20.dp))
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun PillarsHeroPreview() {
    Column(
        modifier = Modifier.padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        BrandLockup()
        PillarsHero()
        FoundationButton(text = "Scan passport", onClick = {}, leadingIcon = R.drawable.ic_fnd_passport)
        FoundationButton(
            text = "Scan QR code",
            onClick = {},
            style = FoundationButtonStyle.Secondary,
            leadingIcon = R.drawable.ic_fnd_qr_code,
        )
        FoundationIndeterminateBar()
    }
}
