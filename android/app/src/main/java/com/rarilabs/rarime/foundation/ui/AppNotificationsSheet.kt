package com.rarilabs.rarime.foundation.ui

import android.text.format.DateFormat
import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.rarilabs.rarime.R
import com.rarilabs.rarime.foundation.AppNotification
import com.rarilabs.rarime.foundation.AppNotificationStore
import com.rarilabs.rarime.foundation.FoundationVerificationManager
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationType
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.util.Date
import javax.inject.Inject

/** Home's bell: the list, reading it, and the "Try again" that needs Foundation. */
@HiltViewModel
class AppNotificationsViewModel @Inject constructor(
    private val store: AppNotificationStore,
    private val verificationManager: FoundationVerificationManager,
) : ViewModel() {
    val entries: StateFlow<List<AppNotification>> = store.entries

    fun markAllRead() = store.markAllRead()

    /** The card's own "Try again" after Foundation's check failed. */
    fun retryVerification() {
        viewModelScope.launch { verificationManager.beginVerification() }
    }
}

/**
 * The bell in Home's header: 44-unit tap target, a red dot while an error is
 * unread. Its accessibility label is "Notifications".
 */
@Composable
fun NotificationBellButton(
    hasUnread: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val label = stringResource(R.string.notifications_title)
    val unreadState = stringResource(R.string.notifications_unread_state)
    Box(
        modifier = modifier
            .size(44.dp)
            .clip(CircleShape)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics {
                contentDescription = label
                if (hasUnread) stateDescription = unreadState
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_fnd_bell),
            contentDescription = null,
            tint = FoundationBrand.Text,
            modifier = Modifier.size(24.dp),
        )
        if (hasUnread) {
            // 10-unit red dot inside a 2-unit page-coloured ring, top right.
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 9.dp, end = 10.dp)
                    .size(14.dp)
                    .clip(CircleShape)
                    .background(FoundationBrand.Bg)
                    .padding(2.dp)
                    .clip(CircleShape)
                    .background(FoundationBrand.AlertDot)
            )
        }
    }
}

/**
 * The sheet behind Home's bell: the app's own notifications, newest first.
 *
 * Opening it marks everything read (the bell's dot goes), while the entries
 * that were unread when it opened keep their dot for this viewing. A failed
 * verification entry offers "Try again" (the same retry as Home's card) and
 * "Share app log" (the same log file Profile's Help and feedback sends).
 *
 * Mirrors iOS's `AppNotificationsSheet`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppNotificationsSheet(
    entries: List<AppNotification>,
    onMarkAllRead: () -> Unit,
    onDismiss: () -> Unit,
    onRetry: (AppNotification.Retry) -> Unit,
    onShareLog: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    fun close(then: () -> Unit = {}) {
        scope.launch {
            sheetState.hide()
            onDismiss()
            then()
        }
    }

    ModalBottomSheet(
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp),
        dragHandle = null,
        containerColor = FoundationBrand.Surface,
        scrimColor = FoundationBrand.Text.copy(alpha = 0.35f),
        onDismissRequest = onDismiss,
    ) {
        AppNotificationsSheetContent(
            entries = entries,
            onMarkAllRead = onMarkAllRead,
            onDone = { close() },
            onRetry = { retry -> close { onRetry(retry) } },
            onShareLog = onShareLog,
        )
    }
}

@Composable
fun AppNotificationsSheetContent(
    entries: List<AppNotification>,
    onMarkAllRead: () -> Unit,
    onDone: () -> Unit,
    onRetry: (AppNotification.Retry) -> Unit,
    onShareLog: () -> Unit,
) {
    // Unread as of opening, so the dots stay while the person reads.
    val unreadAtOpen = remember { entries.filter { !it.isRead }.map { it.id }.toSet() }
    LaunchedEffect(Unit) { onMarkAllRead() }

    val maxHeight = (LocalConfiguration.current.screenHeightDp * 0.7f).dp

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(max = maxHeight)
            .padding(start = 24.dp, end = 24.dp, top = 12.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.CenterHorizontally)
                .width(40.dp)
                .height(5.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(FoundationBrand.Border)
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = stringResource(R.string.notifications_title),
                style = FoundationType.headline,
                color = FoundationBrand.Text,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = stringResource(R.string.notifications_done),
                style = FoundationType.button,
                color = FoundationBrand.Accent,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(role = Role.Button, onClick = onDone)
                    .padding(horizontal = 8.dp, vertical = 6.dp),
            )
        }

        if (entries.isEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 28.dp, bottom = 28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(
                    painter = painterResource(R.drawable.ic_fnd_bell),
                    contentDescription = null,
                    tint = FoundationBrand.Muted,
                    modifier = Modifier.size(28.dp),
                )
                Text(
                    text = stringResource(R.string.notifications_empty_title),
                    style = FoundationType.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                    color = FoundationBrand.Text,
                )
                Text(
                    text = stringResource(R.string.notifications_empty_message),
                    style = FoundationType.callout,
                    color = FoundationBrand.Muted,
                    textAlign = TextAlign.Center,
                )
            }
        } else {
            Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                entries.forEachIndexed { index, entry ->
                    if (index > 0) {
                        Box(
                            modifier = Modifier
                                .padding(vertical = 16.dp)
                                .fillMaxWidth()
                                .height(1.dp)
                                .background(FoundationBrand.Border)
                        )
                    }
                    AppNotificationRow(
                        entry = entry,
                        isUnread = entry.id in unreadAtOpen,
                        onRetry = onRetry,
                        onShareLog = onShareLog,
                    )
                }
            }
        }
    }
}

@Composable
private fun AppNotificationRow(
    entry: AppNotification,
    isUnread: Boolean,
    onRetry: (AppNotification.Retry) -> Unit,
    onShareLog: () -> Unit,
) {
    val isError = entry.isError
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(if (isError) FoundationBrand.DangerTint else FoundationBrand.AccentTint),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painter = painterResource(
                    if (isError) R.drawable.ic_fnd_alert_circle else R.drawable.ic_fnd_check
                ),
                contentDescription = null,
                tint = if (isError) FoundationBrand.DangerIcon else FoundationBrand.Accent,
                modifier = Modifier.size(18.dp),
            )
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = titleFor(entry),
                    style = FoundationType.body.copy(fontWeight = FontWeight.SemiBold),
                    color = FoundationBrand.Text,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = timeText(entry.timeMillis),
                    style = FoundationType.footnote,
                    color = FoundationBrand.Muted,
                    maxLines = 1,
                )
            }
            SelectionContainer {
                Text(
                    text = messageFor(entry),
                    style = FoundationType.callout.copy(fontSize = 14.sp, lineHeight = 20.sp),
                    color = FoundationBrand.Muted,
                )
            }
            val retry = entry.retry
            if (entry.isVerificationFailure && retry != null) {
                Row(
                    modifier = Modifier.padding(top = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    EntryButton(
                        text = stringResource(R.string.notification_try_again),
                        isPrimary = true,
                        onClick = { onRetry(retry) },
                    )
                    EntryButton(
                        text = stringResource(R.string.notification_share_app_log),
                        isPrimary = false,
                        onClick = onShareLog,
                    )
                }
            }
        }

        // Unread error dot; a same-width spacer keeps rows aligned.
        Box(
            modifier = Modifier
                .padding(top = 7.dp)
                .size(8.dp)
                .clip(CircleShape)
                .background(if (isUnread && isError) FoundationBrand.AlertDot else Color.Transparent)
        )
    }
}

/** The two small buttons on a failed verification entry (38 units high). */
@Composable
private fun EntryButton(text: String, isPrimary: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(8.dp)
    Box(
        modifier = Modifier
            .height(38.dp)
            .clip(shape)
            .background(if (isPrimary) FoundationBrand.Accent else FoundationBrand.Surface, shape)
            .border(1.dp, if (isPrimary) Color.Transparent else FoundationBrand.Border, shape)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = if (isPrimary) 16.dp else 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = FoundationType.button.copy(fontSize = 15.sp),
            color = if (isPrimary) FoundationBrand.OnAccent else FoundationBrand.Accent,
            maxLines = 1,
        )
    }
}

@Composable
private fun titleFor(entry: AppNotification): String = stringResource(
    when (entry.type) {
        AppNotification.Type.ERROR -> R.string.notification_title_error
        AppNotification.Type.VERIFICATION_FAILED -> R.string.notification_title_verification_failed
        AppNotification.Type.PASSPORT_CHECKED -> R.string.notification_title_passport_checked
        AppNotification.Type.VERIFIED -> R.string.notification_title_verified
    }
)

@Composable
private fun messageFor(entry: AppNotification): String {
    if (entry.message.isNotBlank()) return entry.message
    return stringResource(
        when (entry.type) {
            AppNotification.Type.PASSPORT_CHECKED -> R.string.notification_message_passport_checked
            AppNotification.Type.VERIFIED -> R.string.notification_message_verified
            AppNotification.Type.VERIFICATION_FAILED -> R.string.notification_reason_registration_failed
            AppNotification.Type.ERROR -> R.string.notification_error_fallback
        }
    )
}

/** "2:18 PM" today, with the date before that, in the phone's own format. */
@Composable
private fun timeText(timeMillis: Long): String {
    val context = LocalContext.current
    return if (DateUtils.isToday(timeMillis)) {
        DateFormat.getTimeFormat(context).format(Date(timeMillis))
    } else {
        DateUtils.formatDateTime(
            context,
            timeMillis,
            DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_ABBREV_MONTH or DateUtils.FORMAT_SHOW_TIME,
        )
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFFFFFFF)
@Composable
private fun AppNotificationsSheetPreview() {
    val now = System.currentTimeMillis()
    AppNotificationsSheetContent(
        entries = listOf(
            AppNotification(
                id = "1",
                type = AppNotification.Type.VERIFICATION_FAILED,
                message = "Foundation couldn't confirm this passport is unique. Your passport and phone are fine. Try again, or send us the app log.",
                timeMillis = now,
                isRead = false,
                retry = AppNotification.Retry.FINISH_VERIFICATION,
            ),
            AppNotification(
                id = "2",
                type = AppNotification.Type.PASSPORT_CHECKED,
                message = "",
                timeMillis = now - 180_000,
                isRead = true,
                retry = null,
            ),
        ),
        onMarkAllRead = {},
        onDone = {},
        onRetry = {},
        onShareLog = {},
    )
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F9FC)
@Composable
private fun NotificationBellButtonPreview() {
    Row {
        NotificationBellButton(hasUnread = true, onClick = {})
        Spacer(modifier = Modifier.width(8.dp))
        NotificationBellButton(hasUnread = false, onClick = {})
    }
}
