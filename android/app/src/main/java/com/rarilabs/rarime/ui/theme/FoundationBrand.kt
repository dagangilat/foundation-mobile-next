package com.rarilabs.rarime.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * The Foundation shell's own light palette (the pre-fork iOS `Theme.swift`
 * `ThemePalette.foundation`), used by the Foundation-styled screens: launch,
 * sign-in, intro, Home and Profile.
 *
 * Kept apart from [FoundationColors] on purpose: that class is the fork's
 * full inherited token set, locked by BrandColorsTest/TextContrastTest,
 * while these are the handful of flat values the Foundation design language
 * actually uses, byte-identical to iOS.
 */
object FoundationBrand {
    val Bg = Color(0xFFF6F9FC)
    val Surface = Color(0xFFFFFFFF)
    val Border = Color(0xFFE6EBF1)
    val Muted = Color(0xFF596171)
    val Text = Color(0xFF0A0E27)

    /** brandGreen: CTAs, active text, the lockup's "ation" and shield. */
    val Accent = Color(0xFF047857)

    /** Decorative only, never text. */
    val BrandFill = Color(0xFF34D399)
    val BrandCyan = Color(0xFF22D3EE)
    val OnAccent = Color(0xFFFFFFFF)

    /** Pale accent wash behind the "Verified" pill. */
    val AccentTint = Color(0xFFD1FAE5)

    /** Destructive rows (sign out, delete account) and inline errors. */
    val Danger = Color(0xFFB42318)

    // Pillars
    val Voice = Color(0xFF6366F1)
    val Share = Color(0xFF0D9488)
    val Market = Color(0xFF0891B2)

    // Mesh hero
    val MeshBase = Color(0xFFE8FBF4)
    val MeshBlobs = listOf(
        Color(0xFF34D399),
        Color(0xFF22D3EE),
        Color(0xFF60A5FA),
        Color(0xFFA78BFA),
    )
}

/**
 * Text styles for the Foundation screens. The platform system font
 * ([FontFamily.Default]) rather than the fork's Inter/Playfair, matching
 * iOS, where these screens use SF Pro.
 */
object FoundationType {
    val largeTitle = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold,
        fontSize = 32.sp,
        lineHeight = 38.sp,
        letterSpacing = (-0.4).sp,
    )
    val title = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold,
        fontSize = 28.sp,
        lineHeight = 34.sp,
        letterSpacing = (-0.4).sp,
    )
    val headline = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold,
        fontSize = 22.sp,
        lineHeight = 28.sp,
    )
    val navTitle = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp,
        lineHeight = 22.sp,
    )
    val body = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 23.sp,
    )
    val bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 17.sp,
        lineHeight = 22.sp,
    )
    val callout = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 15.sp,
        lineHeight = 22.sp,
    )
    val button = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp,
        lineHeight = 22.sp,
    )
    val footnote = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 13.sp,
        lineHeight = 19.sp,
    )
    val overline = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 13.sp,
        lineHeight = 18.sp,
        letterSpacing = 0.6.sp,
    )
    val code = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.SemiBold,
        fontSize = 22.sp,
        lineHeight = 28.sp,
    )
}
