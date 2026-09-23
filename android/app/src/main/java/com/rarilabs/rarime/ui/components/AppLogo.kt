package com.rarilabs.rarime.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import com.rarilabs.rarime.foundation.ui.BrandLockup

/**
 * The app's logo. Once the fork's black rounded tile with a gradient mark;
 * now the Foundation [BrandLockup] (half-filled shield + "Foundation"), so
 * any screen still asking for the logo gets the Foundation one.
 *
 * The sizing parameters belonged to the tile and are kept only so existing
 * call sites compile unchanged; the lockup has its own proportions.
 */
@Preview(showBackground = true)
@Composable
fun AppLogo(
    modifier: Modifier = Modifier,
    @Suppress("UNUSED_PARAMETER") scale: Float = 1f,
    @Suppress("UNUSED_PARAMETER") radius: Int = 48,
    @Suppress("UNUSED_PARAMETER") wrapperSize: Int = 187,
    @Suppress("UNUSED_PARAMETER") iconSize: Int = 96
) {
    BrandLockup(modifier = modifier)
}
