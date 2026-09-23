package com.rarilabs.rarime.ui.theme

import androidx.compose.material3.ProvideTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import com.rarilabs.rarime.data.enums.AppColorScheme

@Composable
fun AppTheme(
    colorScheme: AppColorScheme = AppColorScheme.SYSTEM,
    content: @Composable () -> Unit,
) {
    // Foundation ships light only, app-wide (MainActivity also pins AppCompat
    // to MODE_NIGHT_NO). [colorScheme] is still accepted so existing call sites
    // and the stored preference stay untouched, but it no longer switches the
    // palette. darkColors() is kept: BrandColorsTest/TextContrastTest lock it.
    val currentColors = lightColors()
    val rememberedColors =
        remember { currentColors.copy() }.apply { updateColorsFrom(currentColors) }
    CompositionLocalProvider(
        LocalColors provides rememberedColors,
        LocalTypography provides FoundationTypography(),
    ) {
        ProvideTextStyle(
            value = FoundationTheme.typography.body3.copy(color = FoundationTheme.colors.textPrimary),
            content = content
        )
    }
}