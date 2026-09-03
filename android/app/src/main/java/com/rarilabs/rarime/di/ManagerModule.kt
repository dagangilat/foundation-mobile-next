package com.rarilabs.rarime.di

import android.content.Context
import com.rarilabs.rarime.BaseConfig
import com.rarilabs.rarime.api.auth.AuthAPI
import com.rarilabs.rarime.api.auth.AuthAPIManager
import com.rarilabs.rarime.api.auth.RefreshTokenInterceptor
import com.rarilabs.rarime.api.ext_integrator.ExtIntegratorAPI
import com.rarilabs.rarime.api.ext_integrator.ExtIntegratorApiManager
import com.rarilabs.rarime.api.registration.RegistrationAPI
import com.rarilabs.rarime.api.registration.RegistrationAPIManager
import com.rarilabs.rarime.manager.AuthManager
import com.rarilabs.rarime.manager.DriveBackupManager
import com.rarilabs.rarime.manager.IdentityManager
import com.rarilabs.rarime.manager.NfcManager
import com.rarilabs.rarime.manager.NotificationManager
import com.rarilabs.rarime.manager.PassportManager
import com.rarilabs.rarime.manager.ProofGenerationManager
import com.rarilabs.rarime.manager.RarimoContractManager
import com.rarilabs.rarime.manager.RegistrationManager
import com.rarilabs.rarime.manager.SecurityManager
import com.rarilabs.rarime.manager.SettingsManager
import com.rarilabs.rarime.store.SecureSharedPrefsManager
import com.rarilabs.rarime.store.SecureSharedPrefsManagerImpl
import com.rarilabs.rarime.store.room.notifications.AppDatabase
import com.rarilabs.rarime.store.room.notifications.NotificationsDao
import com.rarilabs.rarime.store.room.notifications.NotificationsRepository
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import dagger.Binds
import dagger.Lazy
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import org.web3j.protocol.Web3j
import org.web3j.protocol.http.HttpService
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import javax.inject.Named
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class ManagerModule {
    @Binds
    @Singleton
    abstract fun dataStoreManager(dataStoreManagerImpl: SecureSharedPrefsManagerImpl): SecureSharedPrefsManager
}

@Module
@InstallIn(SingletonComponent::class)
class APIModule {
    @Provides
    @Singleton
    fun provideNfcManager(
        @ApplicationContext context: Context
    ): NfcManager {
        return NfcManager(context)
    }

    @Provides
    @Singleton
    @Named("authRetrofit")
    fun provideAuthRetrofit(): Retrofit {
        return Retrofit.Builder().addConverterFactory(
            MoshiConverterFactory.create(
                Moshi.Builder().add(KotlinJsonAdapterFactory()).build()
            )
        ).baseUrl(BaseConfig.RELAYER_URL).client(
            OkHttpClient.Builder()
                .addInterceptor(HttpLoggingInterceptor().setLevel(HttpLoggingInterceptor.Level.BODY))
                .build()
        ).build()
    }

    @Provides
    @Singleton
    @Named("jsonApiRetrofit")
    fun provideJsonApiRetrofit(
        authManager: Lazy<AuthManager>, // Use Lazy injection to break the cycle
        @Named("authRetrofit") authRetrofit: Retrofit
    ): Retrofit {
        val okHttpClient = OkHttpClient.Builder()
            .addInterceptor(
                RefreshTokenInterceptor(authManager, authRetrofit)
            )
            .addInterceptor(HttpLoggingInterceptor().setLevel(HttpLoggingInterceptor.Level.BODY))
            .build()

        val moshi = Moshi.Builder()
            .add(KotlinJsonAdapterFactory())
            .build()

        return Retrofit.Builder()
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .baseUrl(BaseConfig.RELAYER_URL)
            .client(okHttpClient)
            .build()
    }

    @Provides
    @Singleton
    fun provideAuthAPIManager(
        @Named("authRetrofit") retrofit: Retrofit
    ): AuthAPIManager = AuthAPIManager(retrofit.create(AuthAPI::class.java))

    @Provides
    @Singleton
    fun provideAuthManager(
        @ApplicationContext context: Context,
        authAPIManager: AuthAPIManager,
        identityManager: IdentityManager,
        dataStoreManager: SecureSharedPrefsManager
    ): AuthManager {
        return AuthManager(
            context, authAPIManager, identityManager, dataStoreManager
        )
    }

    @Provides
    @Singleton
    fun providerRegistrationAPIManager(
        @Named("jsonApiRetrofit") retrofit: Retrofit
    ): RegistrationAPIManager = RegistrationAPIManager(retrofit.create(RegistrationAPI::class.java))

    @Provides
    @Singleton
    @Named("EXT_INTEGRATOR")
    fun provideExtIntegratorRetrofit(): Retrofit {
        return Retrofit.Builder().addConverterFactory(
            MoshiConverterFactory.create(
                Moshi.Builder().add(KotlinJsonAdapterFactory()).build()
            )
        ).baseUrl("http://NONE").client(
            OkHttpClient.Builder()
                .addInterceptor(HttpLoggingInterceptor().setLevel(HttpLoggingInterceptor.Level.BODY))
                .build()
        ).build()
    }

    @Provides
    @Singleton
    fun provideExtIntegratorAPIManager(
        @Named("EXT_INTEGRATOR") retrofit: Retrofit,
        contractManager: RarimoContractManager,
        sharedPreferences: SecureSharedPrefsManager,
        passportManager: PassportManager,
        identityManager: IdentityManager,
    ): ExtIntegratorApiManager = ExtIntegratorApiManager(
        retrofit.create(ExtIntegratorAPI::class.java),
        contractManager,
        sharedPreferences,
        passportManager,
        identityManager,
    )

    @Provides
    @Singleton
    fun provideRegistrationManager(
        registrationAPIManager: RegistrationAPIManager,
        rarimoContractManager: RarimoContractManager,
        passportManager: PassportManager,
        identityManager: IdentityManager
    ): RegistrationManager = RegistrationManager(
        registrationAPIManager, rarimoContractManager, passportManager, identityManager
    )

    @Provides
    @Singleton
    fun providePassportManager(
        dataStoreManager: SecureSharedPrefsManager, identityManager: IdentityManager
    ): PassportManager = PassportManager(dataStoreManager, identityManager)


    @Provides
    @Singleton
    fun provideProofGenerationManager(
        @ApplicationContext context: Context,
        identityManager: IdentityManager,
        registrationManager: RegistrationManager,
        rarimoContractManager: RarimoContractManager,
        passportManager: PassportManager
    ): ProofGenerationManager = ProofGenerationManager(
        context,
        identityManager,
        registrationManager,
        passportManager,
        rarimoContractManager
    )

    @Provides
    @Singleton
    @Named("jsonApiCosmosRetrofit")
    fun provideCosmosRetrofit(
        authManager: Lazy<AuthManager>, // Use Lazy injection to break the cycle
        @Named("authRetrofit") authRetrofit: Retrofit
    ): Retrofit {
        val okHttpClient = OkHttpClient.Builder().addInterceptor(
            RefreshTokenInterceptor(
                authManager, authRetrofit
            )
        ).addInterceptor(HttpLoggingInterceptor().setLevel(HttpLoggingInterceptor.Level.BODY))
            .build()

        return Retrofit.Builder().addConverterFactory(
            MoshiConverterFactory.create(
                Moshi.Builder().add(KotlinJsonAdapterFactory()).build()
            )
        ).baseUrl(BaseConfig.COSMOS_RPC_URL).client(okHttpClient).build()
    }

    @Provides
    @Singleton
    fun provideSettingsManager(
        dataStoreManager: SecureSharedPrefsManager
    ): SettingsManager {
        return SettingsManager(
            dataStoreManager
        )
    }

    @Provides
    @Singleton
    fun provideSecurityManager(
        dataStoreManager: SecureSharedPrefsManager
    ): SecurityManager {
        return SecurityManager(dataStoreManager)
    }

    @Provides
    @Singleton
    fun provideIdentityManager(
        dataStoreManager: SecureSharedPrefsManager, rarimoContractManager: RarimoContractManager
    ): IdentityManager {
        return IdentityManager(dataStoreManager, rarimoContractManager)
    }

    @Provides
    @Singleton
    @Named("RARIMO")
    fun web3(): Web3j {
        return Web3j.build(HttpService(BaseConfig.EVM_RPC_URL))
    }

    @Provides
    @Singleton
    fun provideAppDatabase(@ApplicationContext appContext: Context): AppDatabase {
        return AppDatabase.getDatabase(appContext)
    }

    @Provides
    @Singleton
    fun provideNotificationDao(appDatabase: AppDatabase): NotificationsDao {
        return appDatabase.notificationsDao()
    }

    @Provides
    @Singleton
    fun provideNotificationsRepository(notificationsDao: NotificationsDao): NotificationsRepository {
        return NotificationsRepository(notificationsDao)
    }

    @Provides
    @Singleton
    fun provideDriveBackupRepository(
        @ApplicationContext context: Context
    ): DriveBackupManager = DriveBackupManager(context)

    @Provides
    @Singleton
    fun provideNotificationManager(
        notificationsRepository: NotificationsRepository, passportManager: PassportManager
    ): NotificationManager {
        return NotificationManager(notificationsRepository, passportManager)
    }
}
