package com.rarilabs.rarime.modules.you

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.ripple.rememberRipple
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.rarilabs.rarime.R
import com.rarilabs.rarime.ui.components.AppIcon
import com.rarilabs.rarime.ui.theme.FoundationTheme

@Composable
fun IdentityCardTypeItem(
    modifier: Modifier = Modifier,
    isActive: Boolean,
    iconId: Int,
    iconSize: Int = 24,
    name: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .then(
                if (isActive) {
                    Modifier.clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = rememberRipple(bounded = true),
                        onClick = onClick
                    )
                } else {
                    Modifier
                }
            )
            .padding(horizontal = 16.dp, vertical = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Box(
            modifier = if (isActive) {
                Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(brush = FoundationTheme.colors.gradient1)
            } else {
                Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(FoundationTheme.colors.componentDisabled)

            },
            contentAlignment = Alignment.Center
        ) {
            AppIcon(
                id = iconId,
                tint = if (isActive) FoundationTheme.colors.baseBlack else FoundationTheme.colors.textDisabled.copy(
                    alpha = 0.28f
                ),
                size = iconSize.dp,
            )
        }

        Text(
            name,
            style = FoundationTheme.typography.buttonLarge,
            color = if (isActive) FoundationTheme.colors.textPrimary else FoundationTheme.colors.textDisabled
        )
        Spacer(modifier = Modifier.weight(1f))

        if (isActive) {
            AppIcon(
                id = R.drawable.ic_caret_right,
                size = 16.dp,
                tint = FoundationTheme.colors.textSecondary
            )
        } else {
            Text(
                text = "SOON",
                color = FoundationTheme.colors.textSecondary,
                style = FoundationTheme.typography.overline2
            )
        }

    }
}

@Preview
@Composable
private fun IdentityCardTypeItemPreview() {
    Surface {
        Column {
            IdentityCardTypeItem(
                isActive = true,
                iconId = R.drawable.ic_foundation_token,
                name = "Identity Card",
                onClick = {}
            )
            Spacer(Modifier.height(16.dp))
            IdentityCardTypeItem(
                isActive = false,
                iconId = R.drawable.ic_foundation_token,
                name = "Identity Card",
                onClick = {}
            )
        }

    }
}