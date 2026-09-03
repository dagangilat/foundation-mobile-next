package com.rarilabs.rarime.modules.earn.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.absolutePadding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.rarilabs.rarime.BaseConfig
import com.rarilabs.rarime.R
import com.rarilabs.rarime.api.points.models.ReferralCode
import com.rarilabs.rarime.api.points.models.ReferralCodeStatuses
import com.rarilabs.rarime.ui.components.AppIcon
import com.rarilabs.rarime.ui.theme.FoundationTheme
import com.rarilabs.rarime.util.InvitationUtil

enum class RewardsEventItemInvitesCardContainerVariants(val value: String) {
    FILLED("filled"),
    OUTLINED("outlined"),
}

@Composable
private fun RewardsEventItemInvitesCardContainer(
    modifier: Modifier = Modifier,
    isCodeDisabled: Boolean = false,
    title: String,
    description: String,
    variant: RewardsEventItemInvitesCardContainerVariants = RewardsEventItemInvitesCardContainerVariants.FILLED,
    columnContent: @Composable () -> Unit = {},
    actionContent: @Composable () -> Unit = {},
) {
    val boxBackground = when (variant) {
        RewardsEventItemInvitesCardContainerVariants.FILLED -> FoundationTheme.colors.componentPrimary
        RewardsEventItemInvitesCardContainerVariants.OUTLINED -> Color.Transparent
    }


    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(boxBackground)
            .then(
                if (isCodeDisabled) Modifier.border(
                    1.dp,
                    FoundationTheme.colors.componentPrimary,
                    RoundedCornerShape(16.dp)
                ) else Modifier
            )
    ) {
        Row(
            modifier = Modifier.padding(vertical = 12.dp, horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .absolutePadding(right = 16.dp)
                    .alpha(if (isCodeDisabled) 0.5f else 1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    textDecoration = if (isCodeDisabled) TextDecoration.LineThrough else null,
                    text = title,
                    style = if (isCodeDisabled) FoundationTheme.typography.subtitle6 else FoundationTheme.typography.h5,
                    color = FoundationTheme.colors.textPrimary,
                )
                Text(
                    text = description,
                    style = FoundationTheme.typography.body4,
                    color = FoundationTheme.colors.textSecondary,
                )
                columnContent()
            }

            actionContent()
        }
    }
}

@Composable
fun RewardsEventItemInvitesCard(
    code: ReferralCode,
    isVerifiedPointsBalance: Boolean
) {
    val context = LocalContext.current

    val notActiveActionContent = @Composable {
        if (isVerifiedPointsBalance) {
            RewardAmount(
                amount = 3,
            )
        }
    }

    Column {
        when (code.status) {
            ReferralCodeStatuses.REWARDED.value -> {
                RewardsEventItemInvitesCardContainer(
                    title = code.id,
                    isCodeDisabled = true,
                    variant = RewardsEventItemInvitesCardContainerVariants.OUTLINED,
                    description = stringResource(id = R.string.invite_status_rewarded_card_desc),
                    actionContent = {
                        notActiveActionContent()
                    }
                )
            }

            ReferralCodeStatuses.CONSUMED.value -> {
                RewardsEventItemInvitesCardContainer(
                    title = code.id,
                    variant = RewardsEventItemInvitesCardContainerVariants.OUTLINED,
                    isCodeDisabled = true,
                    description = stringResource(id = R.string.invite_status_consumed_card_desc),
                    actionContent = {
                        notActiveActionContent()
                    }
                )
            }

            ReferralCodeStatuses.ACTIVE.value -> {
                val invitationUrl = "${BaseConfig.INVITATION_BASE_URL}/r/${code.id}"

                RewardsEventItemInvitesCardContainer(
                    title = code.id,

                    description = invitationUrl.replace("https://", ""),
                    actionContent = {
                        IconButton(
                            onClick = {
                                InvitationUtil.shareInvitation(context, invitationUrl)
                            }
                        ) {
                            AppIcon(id = R.drawable.ic_share, tint = FoundationTheme.colors.textPrimary)
                        }
                    },
                    columnContent = {
                        Text(
                            text = stringResource(id = R.string.invite_status_active_card_desc),
                            style = FoundationTheme.typography.subtitle7,
                            color = FoundationTheme.colors.successDarker,
                        )
                    }
                )
            }

            ReferralCodeStatuses.BANNED.value -> {
                RewardsEventItemInvitesCardContainer(
                    title = code.id,
                    variant = RewardsEventItemInvitesCardContainerVariants.OUTLINED,
                    isCodeDisabled = true,
                    description = stringResource(id = R.string.invite_status_banned_card_desc),
                    actionContent = {
                        notActiveActionContent()
                    }
                )
            }

            ReferralCodeStatuses.LIMITED.value -> {
                RewardsEventItemInvitesCardContainer(
                    title = code.id,
                    variant = RewardsEventItemInvitesCardContainerVariants.OUTLINED,

                    isCodeDisabled = true,
                    description = stringResource(id = R.string.invite_status_limited_card_desc),
                    actionContent = {
                        notActiveActionContent()
                    }
                )
            }

            ReferralCodeStatuses.AWAITING.value -> {
                RewardsEventItemInvitesCardContainer(
                    title = code.id,
                    variant = RewardsEventItemInvitesCardContainerVariants.OUTLINED,

                    isCodeDisabled = true,
                    description = stringResource(id = R.string.invite_status_awaiting_card_desc),
                    actionContent = {
                        notActiveActionContent()
                    }
                )
            }

        }
    }
}


