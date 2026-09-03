package com.rarilabs.rarime.foundation

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.rarilabs.rarime.ui.theme.darkColors
import com.rarilabs.rarime.ui.theme.lightColors
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WCAG 2.x contrast guards for the translucent text tiers.
 *
 * Task B3 remapped iOS's `TextSecondary` base colour from Rarimo's `#141614`
 * to Foundation's lighter `muted #596171` but kept Rarimo's `0.56` alpha, and
 * Task C3 inherited the same `0x8F596171` here for cross-platform hex parity.
 * The result read 2.38:1 against `backgroundPrimary #F6F9FC` - below WCAG AA's
 * 4.5:1 for normal text, and below even the 3:1 large-text floor. Nothing
 * caught it, because every colour test in this package asserts a *value*
 * rather than a *relationship*, and a value assertion cannot know that a
 * legal-looking hex has become illegible against the surface it sits on.
 *
 * So these tests compute the real contrast ratio - sRGB linearisation, source
 * -over compositing of the translucent fill onto the actual background token,
 * relative luminance, `(L1 + 0.05) / (L2 + 0.05)` - rather than comparing
 * hexes. They read both the text token AND the background token out of the
 * palette, so they also fail if a future change moves the *background* under
 * text that is currently fine.
 *
 * The maths is deliberately hand-rolled rather than delegated to Compose's
 * `Color.luminance()`, so it is provably the same formula the iOS counterpart
 * (`AssetBrandingTests.testSecondaryTextClearsWcagAaOnEveryAppearance`) uses.
 * Note the trap: the neighbouring `0.2126*r + 0.7152*g + 0.0722*b` weighting
 * on raw sRGB components is NOT relative luminance - it skips the gamma
 * linearisation, and using it here would report ~2.1:1 for a passing colour.
 */
class TextContrastTest {

    private companion object {
        /** WCAG 1.4.3 AA, normal-size text. */
        const val AA_NORMAL = 4.5

        /**
         * The floor conventionally accepted for placeholder text, which is
         * transient hint copy rather than primary content (and matches WCAG's
         * 1.4.11 non-text / 1.4.3 large-text threshold).
         */
        const val PLACEHOLDER_FLOOR = 3.0

        /**
         * Disabled text is explicitly exempt from 1.4.3 ("Incidental: text
         * that is part of an inactive user interface component"). This is a
         * regression floor, NOT a compliance claim: it pins the perceptual
         * weight the pre-fork `#141614 @ 0.28` had (1.86:1) so a future base
         * -colour swap cannot silently erode disabled text to invisibility
         * again, the way the B3 swap took it to 1.49:1.
         */
        const val DISABLED_REGRESSION_FLOOR = 1.8
    }

    /** sRGB electro-optical transfer function - the gamma step WCAG requires. */
    private fun linearize(channel8: Double): Double {
        val c = channel8 / 255.0
        return if (c <= 0.03928) c / 12.92 else Math.pow((c + 0.055) / 1.055, 2.4)
    }

    /** WCAG relative luminance of an opaque 8-bit sRGB triple. */
    private fun luminance(rgb: Triple<Double, Double, Double>): Double =
        0.2126 * linearize(rgb.first) +
            0.7152 * linearize(rgb.second) +
            0.0722 * linearize(rgb.third)

    private fun Int.channels(): Triple<Double, Double, Double> = Triple(
        ((this shr 16) and 0xFF).toDouble(),
        ((this shr 8) and 0xFF).toDouble(),
        (this and 0xFF).toDouble()
    )

    private fun Int.alpha(): Double = ((this shr 24) and 0xFF) / 255.0

    /** Source-over compositing of a translucent fill onto an opaque backdrop. */
    private fun composite(fg: Int, bg: Int): Triple<Double, Double, Double> {
        val a = fg.alpha()
        val (fr, fg2, fb) = fg.channels()
        val (br, bg2, bb) = bg.channels()
        return Triple(
            a * fr + (1 - a) * br,
            a * fg2 + (1 - a) * bg2,
            a * fb + (1 - a) * bb
        )
    }

    private fun contrast(foreground: Color, background: Color): Double {
        val bgArgb = background.toArgb()
        require(bgArgb.alpha() == 1.0) { "background token must be opaque" }
        val l1 = luminance(composite(foreground.toArgb(), bgArgb))
        val l2 = luminance(bgArgb.channels())
        val (hi, lo) = if (l1 >= l2) l1 to l2 else l2 to l1
        return (hi + 0.05) / (lo + 0.05)
    }

    private fun assertContrast(label: String, fg: Color, bg: Color, floor: Double) {
        val ratio = contrast(fg, bg)
        assertTrue(
            "$label: %.3f:1, needs >= %.1f:1".format(ratio, floor),
            ratio >= floor
        )
    }

    @Test
    fun secondaryTextClearsWcagAaInBothThemes() {
        val light = lightColors()
        assertContrast(
            "light textSecondary on backgroundPrimary",
            light.textSecondary, light.backgroundPrimary, AA_NORMAL
        )
        // Cards and sheets paint on backgroundSurface1 (#FFFFFF), a lighter
        // backdrop than backgroundPrimary and therefore a second, independent
        // surface the same token has to clear.
        assertContrast(
            "light textSecondary on backgroundSurface1",
            light.textSecondary, light.backgroundSurface1, AA_NORMAL
        )

        // The dark theme passes today (white base on near-black). Locked here
        // so it cannot regress the way the light theme silently did.
        val dark = darkColors()
        assertContrast(
            "dark textSecondary on backgroundPrimary",
            dark.textSecondary, dark.backgroundPrimary, AA_NORMAL
        )
        assertContrast(
            "dark textSecondary on backgroundSurface1",
            dark.textSecondary, dark.backgroundSurface1, AA_NORMAL
        )
    }

    @Test
    fun placeholderTextClearsPlaceholderFloorInBothThemes() {
        val light = lightColors()
        assertContrast(
            "light textPlaceholder on backgroundPrimary",
            light.textPlaceholder, light.backgroundPrimary, PLACEHOLDER_FLOOR
        )
        assertContrast(
            "light textPlaceholder on backgroundSurface1",
            light.textPlaceholder, light.backgroundSurface1, PLACEHOLDER_FLOOR
        )

        val dark = darkColors()
        assertContrast(
            "dark textPlaceholder on backgroundPrimary",
            dark.textPlaceholder, dark.backgroundPrimary, PLACEHOLDER_FLOOR
        )
        assertContrast(
            "dark textPlaceholder on backgroundSurface1",
            dark.textPlaceholder, dark.backgroundSurface1, PLACEHOLDER_FLOOR
        )
    }

    @Test
    fun disabledTextHoldsItsPreForkPerceptualWeight() {
        // Regression floor only - see DISABLED_REGRESSION_FLOOR. Applies to
        // the light theme, whose base colour is the one B3 swapped; the dark
        // theme keeps Rarimo's white base and is out of that blast radius.
        val light = lightColors()
        assertContrast(
            "light textDisabled on backgroundPrimary",
            light.textDisabled, light.backgroundPrimary, DISABLED_REGRESSION_FLOOR
        )
        assertContrast(
            "light textDisabled on backgroundSurface1",
            light.textDisabled, light.backgroundSurface1, DISABLED_REGRESSION_FLOOR
        )
    }

    @Test
    fun textTiersStayVisuallyOrdered() {
        // The compliance fix must not flatten the hierarchy: raising secondary
        // to clear AA is only safe if it still reads as lighter than primary
        // and heavier than placeholder and disabled. A future "just make it
        // opaque" fix would trip this.
        val light = lightColors()
        val bg = light.backgroundPrimary
        val primary = contrast(light.textPrimary, bg)
        val secondary = contrast(light.textSecondary, bg)
        val placeholder = contrast(light.textPlaceholder, bg)
        val disabled = contrast(light.textDisabled, bg)

        assertTrue(
            "primary (%.2f) must out-contrast secondary (%.2f)".format(primary, secondary),
            primary > secondary * 1.2
        )
        assertTrue(
            "secondary (%.2f) must out-contrast placeholder (%.2f)".format(secondary, placeholder),
            secondary > placeholder
        )
        assertTrue(
            "placeholder (%.2f) must out-contrast disabled (%.2f)".format(placeholder, disabled),
            placeholder > disabled
        )
    }

    @Test
    fun lightTextTokensStayHexIdenticalToIos() {
        // The cross-platform contract this whole rebrand is built on: the
        // Android light palette must be byte-identical to the iOS colorsets.
        // Re-tuning alpha on one platform only would silently reopen the gap
        // this file exists to close.
        // ios/.../Colors/TextSecondary.colorset   alpha 0.886 = 0xE2
        // ios/.../Colors/TextPlaceholder.colorset alpha 0.690 = 0xB0
        // ios/.../Colors/TextDisabled.colorset    alpha 0.420 = 0x6B
        val light = lightColors()
        assertTrue(
            "textSecondary = %08X".format(light.textSecondary.toArgb()),
            light.textSecondary.toArgb() == 0xE2596171.toInt()
        )
        assertTrue(
            "textPlaceholder = %08X".format(light.textPlaceholder.toArgb()),
            light.textPlaceholder.toArgb() == 0xB0596171.toInt()
        )
        assertTrue(
            "textDisabled = %08X".format(light.textDisabled.toArgb()),
            light.textDisabled.toArgb() == 0x6B596171.toInt()
        )
    }
}
