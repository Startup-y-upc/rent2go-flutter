# Stripe push provisioning classes referenced by react-native-stripe-sdk / stripe-android
# but not present unless the optional Google Pay push provisioning dependency is included.
-dontwarn com.stripe.android.pushProvisioning.**
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.reactnativestripesdk.pushprovisioning.**
