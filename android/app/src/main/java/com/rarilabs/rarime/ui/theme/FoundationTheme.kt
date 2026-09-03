package com.rarilabs.rarime.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable

object FoundationTheme {
    val colors: FoundationColors
        @Composable
        @ReadOnlyComposable
        get() = LocalColors.current

    val typography: FoundationTypography
        @Composable
        @ReadOnlyComposable
        get() = LocalTypography.current
}