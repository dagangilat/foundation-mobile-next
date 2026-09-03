package com.rarilabs.rarime.ui.theme

import androidx.compose.material3.ProvideTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import com.rarilabs.rarime.data.enums.AppColorScheme
import com.rarilabs.rarime.data.enums.isDark

@Composable
fun AppTheme(
    colorScheme: AppColorScheme = AppColorScheme.SYSTEM,
    content: @Composable () -> Unit,
) {
    val currentColors = if (colorScheme.isDark()) darkColors() else lightColors()
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