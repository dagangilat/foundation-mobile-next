package com.rarilabs.rarime.modules.hiddenPrize

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.rarilabs.rarime.R
import com.rarilabs.rarime.ui.base.ButtonSize
import com.rarilabs.rarime.ui.components.CircledBadge
import com.rarilabs.rarime.ui.components.HorizontalDivider
import com.rarilabs.rarime.ui.components.PrimaryButton
import com.rarilabs.rarime.ui.theme.FoundationTheme


data class AddScanProps(
    val idTitle: Int,
    val idDescription: Int,
    val color: Color,
    val idIcon: Int,
    val iconTitleColor: Color,
    val iconBackgroundTitleColor: Color
)

@Composable
fun AddScanBottomSheet(
    isInviteEnable: Boolean = true,
    isShareEnable: Boolean = true,
    currentInvite: Int,
    maxInvite: Int,
    onShare: () -> Unit,
    onInvite: () -> Unit,
) {
    val enabledColor = FoundationTheme.colors.textPrimary
    val disabledColor = FoundationTheme.colors.textDisabled
    val enabledIconTitleColor = FoundationTheme.colors.hiddenPrizeAccent
    val enabledIconBackgroundTitleColor = FoundationTheme.colors.hiddenPrizeAccent.copy(alpha = 0.1f)
    val disabledIconTitleColor = FoundationTheme.colors.textSecondary
    val disabledIconBackgroundTitleColor = FoundationTheme.colors.componentPrimary
    val props = remember(isInviteEnable, isShareEnable) {
        if (isInviteEnable || isShareEnable) {
            AddScanProps(
                idIcon = R.drawable.ic_flashlight_fill,
                idTitle = R.string.add_scans_bottom_sheet_title_enebled,
                idDescription = R.string.hidden_prize_add_scans_description_enabled,
                color = enabledColor,
                iconTitleColor = enabledIconTitleColor,
                iconBackgroundTitleColor = enabledIconBackgroundTitleColor
            )
        } else {
            AddScanProps(
                idIcon = R.drawable.ic_question,
                idTitle = R.string.add_scans_bottom_sheet_title_disablet,
                idDescription = R.string.hidden_prize_add_scans_description_disablet,
                color = disabledColor,
                iconTitleColor = disabledIconTitleColor,
                iconBackgroundTitleColor = disabledIconBackgroundTitleColor
            )
        }
    }
    Box(
        modifier = Modifier
    ) {
        Column {
            Box(
                modifier = Modifier.padding(
                    start = 24.dp, bottom = 20.dp
                )
            ) {
                CircledBadge(
                    iconId = props.idIcon,
                    containerSize = 56,
                    contentColor = props.iconTitleColor,
                    contentSize = 24,
                    containerColor = props.iconBackgroundTitleColor,
                )
            }
            Text(
                text = stringResource(props.idTitle),
                style = FoundationTheme.typography.h3,
                color = FoundationTheme.colors.textPrimary,
                modifier = Modifier.padding(
                    bottom = 8.dp, start = 24.dp
                )
            )
            Text(
                text = stringResource(props.idDescription),
                style = FoundationTheme.typography.body3,
                color = FoundationTheme.colors.textSecondary,
                modifier = Modifier.padding(
                    horizontal = 24.dp
                )
            )
            HorizontalDivider(
                modifier = Modifier.padding(
                    horizontal = 24.dp, vertical = 32.dp
                )
            )
            RowAddScans(
                props = props,
                rowTitle = stringResource(R.string.hidden_prize_title_share_row),
                rowDescription = if (isShareEnable) stringResource(R.string.hidden_prize_share_row_description)
                else stringResource(R.string.shared),
                modifier = Modifier,
                buttonLabel = stringResource(R.string.hidden_prize_share_row_button_label),
                idIcon = R.drawable.ic_share_line,
                onClick = onShare
            )
            Spacer(
                Modifier
                    .fillMaxWidth()
                    .size(20.dp)
            )
            RowAddScans(
                props = props,
                rowTitle = stringResource(R.string.hidden_prize_invite_row_title),
                rowDescription = "$currentInvite / $maxInvite invited",
                modifier = Modifier,
                buttonLabel = stringResource(R.string.hidden_prize_invite_row_button_label),
                idIcon = R.drawable.ic_user_add_line,
                onClick = onInvite
            )
            Spacer(
                Modifier
                    .fillMaxWidth()
                    .size(20.dp)
            )
        }
    }
}

@Composable
private fun RowAddScans(
    isEnabled: Boolean = true,
    props: AddScanProps,
    idIcon: Int,
    rowTitle: String,
    rowDescription: String,
    buttonLabel: String,
    modifier: Modifier,
    onClick: () -> Unit
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier.padding(end = 16.dp)
        ) {
            CircledBadge(
                modifier = Modifier,
                iconId = idIcon,
                containerSize = 40,
                contentColor = props.color,
                contentSize = 20,
                containerColor = FoundationTheme.colors.componentPrimary
            )
        }

        Column {
            Text(
                text = rowTitle, style = FoundationTheme.typography.subtitle5, color = props.color
            )
            Text(
                text = rowDescription,
                style = FoundationTheme.typography.body5,
                color = if (isEnabled) FoundationTheme.colors.textSecondary else props.color
            )
        }
        Spacer(Modifier.weight(weight = 1.0f))

        PrimaryButton(
            onClick = onClick,
            enabled = isEnabled,
            modifier = Modifier,
            text = buttonLabel,
            size = ButtonSize.Small
        )
    }
}

@Preview(showBackground = true)
@Composable
fun AddScansBottomSheetEnabledPreview() {
    Box(modifier = Modifier) {
        AddScanBottomSheet(
            onShare = {}, onInvite = {},
            currentInvite = 0,
            maxInvite = 5
        )
    }

}


