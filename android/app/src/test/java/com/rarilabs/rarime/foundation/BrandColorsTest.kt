package com.rarilabs.rarime.foundation

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.rarilabs.rarime.ui.theme.FoundationColors
import com.rarilabs.rarime.ui.theme.darkColors
import com.rarilabs.rarime.ui.theme.lightColors
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Locks the Android palette to the same hex values the iOS fork uses, so the
 * two platforms cannot drift. Source of truth: the pre-fork shell's
 * Theme.swift `foundation` ThemePalette, mapped on iOS in Task B3 and pinned
 * there by `AssetBrandingTests`.
 *
 * Every assertion here compares a RENDERED value (the actual ARGB a Compose
 * surface would paint), never the mere existence of a property. That
 * distinction is the whole point of this file: on iOS, Task B3's first review
 * passed with the splash gradient still painting Rarimo's neon lime, because
 * the only check in place proved the property existed rather than what it
 * resolved to.
 */
class BrandColorsTest {

    // Foundation brand tokens (Theme.swift `foundation` ThemePalette).
    private val brandGreen = 0xFF047857.toInt()
    private val brandFill = 0xFF34D399.toInt()
    private val brandCyan = 0xFF22D3EE.toInt()

    /**
     * Hex values that are recognisably Rarimo's own brand identity: their
     * neon-lime family and their purple secondary. None of these may render
     * anywhere in the palette, in either theme.
     */
    private val rarimoBrandHexes = mapOf(
        0x9AFE8A to "Rarimo neon lime (iOS splash-gradient start, Critical finding in B3)",
        0x8AFECC to "Rarimo neon mint (iOS splash-gradient end)",
        0x84CC16 to "Rarimo lime, light secondaryMain",
        0x8CCD28 to "Rarimo lime, dark secondaryMain",
        0xA8E152 to "Rarimo lime, dark secondaryDarker",
        0x99D838 to "Rarimo lime, dark secondaryDark",
        0x4D7C0F to "Rarimo lime, light secondaryDarker",
        0x65A30D to "Rarimo lime, light secondaryDark",
        0x71BB1D to "Rarimo lime (likeness accent, dark)",
        0x72BB1D to "Rarimo lime (likeness accent, light)",
        0x518119 to "Rarimo olive (likeness accent, dark)",
        0x518219 to "Rarimo olive (likeness accent, light)",
        0x9D4EDD to "Rarimo purple (hidden-prize accent)",
        0x651C9F to "Rarimo deep purple (hidden-prize gradient start)",
        0x863AC4 to "Rarimo purple (tip-alert accent)"
    )

    private fun FoundationColors.gradients(): Map<String, Brush> = mapOf(
        "gradient1" to gradient1,
        "gradient2" to gradient2,
        "gradient3" to gradient3,
        "gradient4" to gradient4,
        "gradient5" to gradient5,
        "gradient6" to gradient6,
        "gradient7" to gradient7,
        "gradient8" to gradient8,
        "gradient9" to gradient9,
        "gradient10" to gradient10,
        "gradient11" to gradient11,
        "gradient12" to gradient12,
        "gradient13" to gradient13,
        "gradient14" to gradient14,
        "gradient15" to gradient15
    )

    /**
     * Pulls the actual colour stops out of a Compose [Brush]. `LinearGradient`
     * keeps them in a private field, so a rendered-value check has to reflect
     * on it - checking `gradientN != null` proves nothing at all.
     */
    private fun Brush.stopsArgb(): List<Int> {
        val stops = javaClass.declaredFields
            .mapNotNull { field ->
                field.isAccessible = true
                field.get(this) as? List<*>
            }
            .firstOrNull { list -> list.isNotEmpty() && list.first() is Color }
            ?: error("Could not read colour stops from ${javaClass.name}")
        return stops.map { (it as Color).toArgb() }
    }

    /** Every `Color`-typed property of the palette, by (mangled) getter name. */
    private fun FoundationColors.colorProperties(): Map<String, Int> =
        FoundationColors::class.java.methods
            .filter { it.parameterCount == 0 && it.returnType == java.lang.Long.TYPE }
            .associate { method ->
                method.name.substringBefore('-') to
                    Color((method.invoke(this) as Long).toULong()).toArgb()
            }

    private fun Int.rgb(): Int = this and 0x00FFFFFF

    private fun Int.hex(): String = String.format("#%06X", rgb())

    @Test
    fun primaryMainMatchesIos() {
        // iOS PrimaryMain.colorset: #047857 in BOTH the default and the dark
        // appearance. If these two ever disagree, one platform has drifted.
        assertEquals(brandGreen, lightColors().primaryMain.toArgb())
        assertEquals(brandGreen, darkColors().primaryMain.toArgb())
    }

    @Test
    fun secondaryMainMatchesIos() {
        // iOS SecondaryMain.colorset: #22D3EE (brandCyan) in both appearances.
        // Rarimo's own secondary was their brand lime, which must not ship.
        assertEquals(brandCyan, lightColors().secondaryMain.toArgb())
        assertEquals(brandCyan, darkColors().secondaryMain.toArgb())
    }

    @Test
    fun splashGradientRendersFoundationBrand() {
        // gradient1 is the Android counterpart of iOS's Gradients.gradientFirst
        // (AdditionalGradientFirstStart/End): the brand-mark tint, the identity
        // widget background and the auth-method chips. iOS's final resolved
        // values are brandGreen -> brandFill; Rarimo's were #9AFE8A -> #8AFECC.
        val expected = listOf(brandGreen, brandFill)
        assertEquals(expected, lightColors().gradient1.stopsArgb())
        assertEquals(expected, darkColors().gradient1.stopsArgb())
    }

    @Test
    fun noRarimoBrandHexRendersInAnyGradient() {
        val offenders = mutableListOf<String>()
        mapOf("light" to lightColors(), "dark" to darkColors()).forEach { (theme, colors) ->
            colors.gradients().forEach { (name, brush) ->
                brush.stopsArgb().forEach { argb ->
                    rarimoBrandHexes[argb.rgb()]?.let { why ->
                        offenders += "$theme.$name renders ${argb.hex()} - $why"
                    }
                }
            }
        }
        assertTrue(offenders.joinToString("\n"), offenders.isEmpty())
    }

    @Test
    fun noRarimoBrandHexRendersInAnyColor() {
        val offenders = mutableListOf<String>()
        mapOf("light" to lightColors(), "dark" to darkColors()).forEach { (theme, colors) ->
            colors.colorProperties().forEach { (name, argb) ->
                rarimoBrandHexes[argb.rgb()]?.let { why ->
                    offenders += "$theme.$name renders ${argb.hex()} - $why"
                }
            }
        }
        assertTrue(offenders.joinToString("\n"), offenders.isEmpty())
    }
}
