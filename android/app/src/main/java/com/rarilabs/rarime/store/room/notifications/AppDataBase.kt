package com.rarilabs.rarime.store.room.notifications

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.rarilabs.rarime.store.room.notifications.models.NotificationEntityData

val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE notifications ADD COLUMN type TEXT")
        db.execSQL("ALTER TABLE notifications ADD COLUMN data TEXT")
    }
}


val MIGRATION_2_3 = object : Migration(2, 3) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS voting (
                proposalId INTEGER NOT NULL PRIMARY KEY
            )
            """.trimIndent()
        )
    }
}

val MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE voting ADD COLUMN votingBlob TEXT NOT NULL DEFAULT ''")
    }
}

val MIGRATION_4_5 = object : Migration(4, 5) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS transactions (
                id INTEGER NOT NULL PRIMARY KEY,
                tokenType TEXT NOT NULL,
                operationType INTEGER NOT NULL,
                "from" TEXT NOT NULL,
                "to" TEXT NOT NULL,
                amount REAL NOT NULL,
                date INTEGER NOT NULL,
                state TEXT NOT NULL
            )
            """.trimIndent()
        )
    }
}

/**
 * Drops the two tables that backed the stripped Freedom Tool voting and EVM
 * wallet features. Room derives an identity hash from the entity set, so
 * removing `VotingEntityData`/`TransactionEntityData` from `@Database` is a
 * schema change: without this migration and the version bump, every upgrading
 * install would fail its first database open with "Room cannot verify the data
 * integrity". The rows themselves belong to removed products, so dropping them
 * is the intended outcome; `notifications` is untouched.
 */
val MIGRATION_5_6 = object : Migration(5, 6) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("DROP TABLE IF EXISTS voting")
        db.execSQL("DROP TABLE IF EXISTS transactions")
    }
}

@Database(
    entities = [NotificationEntityData::class],
    version = 6,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun notificationsDao(): NotificationsDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getDatabase(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext, AppDatabase::class.java, "room_database"
                ).addMigrations(
                    MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6
                ).build()

                INSTANCE = instance
                instance
            }
        }
    }
}