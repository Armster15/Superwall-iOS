# Getting Started with Superwall

Configuring the SDK.

## Overview

To get up and running, you need to get your **API Key** from the Superwall Dashboard. You then configure the SDK using ``Superwall/configure(apiKey:purchaseController:options:completion:)-52tke`` and then present your paywall.

## Getting your API Key

As soon as your app is launched, you need to configure the SDK with your **Public API Key**. You can retrieve this from the Superwall settings page.
If you haven't already, [sign up for a free Superwall account](https://superwall.com/sign-up). Then, when you're through to the **Dashboard**, click the **Settings icon** in the top right corner, and select **Keys**:

![Retrieving your API key from the Superwall Dashboard](apiKey.png)

On that page, you will see your **Public API Key**. Copy this for the next step.

### Configuring the SDK

To configure the SDK, you must call ``Superwall/configure(apiKey:purchaseController:options:completion:)-52tke`` as soon as your app launches from `application(_:didFinishLaunchingWithOptions:)`:

```swift
import SuperwallKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication, 
    didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?
  ) -> Bool {
    Superwall.configure(apiKey: "MYAPIKEY")  // Replace this with your API Key
  )
}
```

This configures a shared instance of ``Superwall``. Make sure to replace the `apiKey` with your public API key that you just retrieved.

Superwall handles all the subscription-related logic for you. However, if you'd like greater control over this process (e.g. if you're using RevenueCat), you'll want to pass in a delegate. You can also pass in ``SuperwallOptions`` to customize paywall presentation and appearance. See <doc:AdvancedConfiguration> for more.

## Identity Management

We generate a random user ID that persists internally until the user deletes/reinstalls your app.

If you use your own user management system, call ``Superwall/identify(userId:options:)`` when a user creates or logs in to an account. This will alias your `userId` with the anonymous Superwall ID enabling us to load the user's assigned paywalls.

Calling ``Superwall/reset()`` will reset the on-device `userId` to a random ID and clear the on-device paywall assignments. You should do this when logging out or wanting to reset the identity of anonymous users.

- Note: You can pass an ``IdentityOptions`` object to ``Superwall/identify(userId:options:)``. This should only be used in advanced use cases. By setting the ``IdentityOptions/restorePaywallAssignments`` property of ``IdentityOptions`` to `true`, paywalls are prevented from showing until after paywall assignments have been restored. If you expect users of your app to switch accounts or delete/reinstall a lot, you'd set this when users log in to an existing account.

You're now ready to track an event to present your first paywall. See <doc:TrackingEvents> for next steps.

## Topics

### The Delegate
- ``SuperwallDelegate``
- <doc:CustomPaywallButtons>
- <doc:ThirdPartyAnalytics>

### Customising Superwall
- ``SuperwallOptions``