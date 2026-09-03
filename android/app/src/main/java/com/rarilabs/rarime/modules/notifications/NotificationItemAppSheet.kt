package com.rarilabs.rarime.modules.notifications

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.rarilabs.rarime.R
import com.rarilabs.rarime.store.room.notifications.models.NotificationEntityData
import com.rarilabs.rarime.ui.base.BaseIconButton
import com.rarilabs.rarime.ui.components.AppBottomSheet
import com.rarilabs.rarime.ui.components.AppSheetState
import com.rarilabs.rarime.ui.components.rememberAppSheetState
import com.rarilabs.rarime.ui.theme.FoundationTheme
import com.rarilabs.rarime.util.DateUtil
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

@Composable
fun NotificationItemAppSheetContent(
    item: NotificationEntityData,
    state: AppSheetState = rememberAppSheetState()
) {
    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 20.dp)
    ) {
        HeaderSection(onClose = { state.hide() })
        Spacer(modifier = Modifier.height(16.dp))
        NotificationHeader(text = item.header)
        Spacer(modifier = Modifier.height(8.dp))
        NotificationTimestamp(timestamp = item.date, context = context)
        Spacer(modifier = Modifier.height(20.dp))
        NotificationDescription(text = item.description)
        Spacer(modifier = Modifier.weight(1f))
        // Upstream rendered a token reward-claim button here for `reward` and
        // `universal` notifications, backed by the points service. That
        // programme is removed, so a notification is now read-only. The
        // `NotificationType` values are kept because inbound pushes still carry
        // them.
    }
}

@Composable
fun HeaderSection(onClose: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End
    ) {
        BaseIconButton(
            onClick = onClose,
            icon = R.drawable.ic_close,
            colors = ButtonDefaults.buttonColors(
                containerColor = FoundationTheme.colors.componentPrimary,
                contentColor = FoundationTheme.colors.textPrimary
            )
        )
    }
}

@Composable
fun NotificationHeader(text: String) {
    Text(
        text = text,
        style = FoundationTheme.typography.h4,
        color = FoundationTheme.colors.textPrimary
    )
}

@Composable
fun NotificationTimestamp(timestamp: String, context: Context) {
    val instant = remember(timestamp) { Instant.ofEpochMilli(timestamp.toLong()) }
    val timeStr = remember(instant) {
        LocalDateTime.ofInstant(instant, ZoneId.systemDefault())
    }
    Text(
        text = "${DateUtil.getDurationString(DateUtil.duration(timeStr), context)} ${
            stringResource(
                id = R.string.time_ago
            )
        }",
        style = FoundationTheme.typography.body3,
        color = FoundationTheme.colors.textSecondary
    )
}

@Composable
fun NotificationDescription(text: String) {
    Text(
        text = text,
        style = FoundationTheme.typography.body4,
        color = FoundationTheme.colors.textSecondary
    )
}

@Composable
fun NotificationItemAppSheet(
    item: NotificationEntityData,
    state: AppSheetState = rememberAppSheetState()
) {
    AppBottomSheet(
        state = state,
        fullScreen = true,
        isHeaderEnabled = false,
    ) {
        NotificationItemAppSheetContent(item, state)
    }
}

@Preview
@Composable
fun NotificationItemAppSheetPreview() {

    val state = rememberAppSheetState(false)
    val notificationEntityData = NotificationEntityData(
        header = "A new release is available",
        description = "It is a long established fact that a reader will be distracted by the readable",
        date = "100000",
        isActive = true,
        type = "info",
        data = null
    )

    Surface(modifier = Modifier.fillMaxSize()) {
        NotificationItemAppSheetContent(notificationEntityData, state)
    }
}
