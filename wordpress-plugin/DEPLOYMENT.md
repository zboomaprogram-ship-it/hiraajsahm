# WordPress deployment

Use **Code Snippets → Add New** and set every snippet to run everywhere.

1. Deactivate the existing notification snippet, replace its content with
   `notification.php`, remove the opening `<?php`, then activate it.
2. Deactivate the existing product Q&A/comment snippet, replace its content
   with `q&a.php`, remove the opening `<?php`, then activate it.
3. Add one new snippet using `marketplace_bridge.php`, remove the opening
   `<?php`, then activate it.
4. Keep only one active copy of each snippet. Duplicate copies cause PHP
   “Cannot redeclare function” fatal errors.
5. Clear the WordPress/Hostinger cache and test with two accounts: one vendor
   and one buyer.

The marketplace bridge provides authenticated vendor products, follows,
private conversations/messages, and zero-price order handling. The
notification snippet sends order, comment/reply, rating, message, product
approval, and followed-vendor product notifications.

## 2026-07-28 QA/security update

Deploy the current contents of these files to the matching active snippets or
plugins:

- `functions.php`
- `get_service_provider_api.php`
- `hiraaj-iap-verify.php`
- `marketplace_bridge.php`
- `notification.php`
- `product_pending.php`
- `q&a.php`
- `telr-gateway-api/telr-gateway-api.php`
- `user.php`

Before enabling the updated code:

1. Deactivate older snippets that declare any of the same functions. Never
   keep the Telr gateway plugin and a copied Telr snippet active together.
2. Rotate the OneSignal REST API key that was previously embedded in source,
   then set the new key in the notification settings or `wp-config.php`.
3. Set the Apple shared secret in the `hiraaj_apple_shared_secret` WordPress
   option. IAP verification intentionally fails until this is configured.
4. Clear all WordPress, Hostinger, and CDN caches.

After deployment, verify with separate buyer and vendor accounts:

- new order and zero-price enquiry;
- Telr success, cancellation, and rejected-payment paths;
- comment, reply, rating, private message, follow, and new-product
  notifications;
- Silver and Al-Zabayeh IAP purchase/restore;
- product creation, editing, pagination, and ownership isolation.

The Flutter app still creates and completes WooCommerce orders directly by
explicit product requirement. Therefore its WooCommerce credentials remain in
the app and must be restricted to only the required order operations.

## Public and private price flows

The current `marketplace_bridge.php` adds:

- authenticated image, video, and PDF chat attachments (maximum 15 MB);
- vendor-only private price offers inside a buyer conversation;
- buyer-only acceptance and checkout of the private offer;
- validation and one-time order binding for private offers.

The current `q&a.php` adds:

- public bids under the product comments;
- a rule that each new bid must be higher than the current highest bid;
- vendor-only acceptance of the highest bid;
- winner-only checkout at the accepted price;
- server validation of buyer, vendor, product, price, and bid;
- one-time binding of the winning bid to its WooCommerce order.

The two flows are available at the same time, but only one final agreement can
be selected for a single marketplace listing. Accepting a private offer closes
the public bids; accepting the highest public bid closes pending private offers.

Replace both existing snippets with the complete current files. Do not activate
a second copy of either snippet. The matching Flutter build is required for the
public auction controls to appear.

## 2026-07-29 auction, quota, messages, and push update

Replace these three WordPress snippets with the complete current files:

- `product_pending.php` — resolves current and legacy Dokan package metadata,
  exposes the authenticated daily quota, and counts ads per seller so one
  seller can never consume another seller's allowance.
- `marketplace_bridge.php` — adds persistent unread message counts and marks a
  conversation read when its newest page is opened.
- `notification.php` — targets the OneSignal external user ID and retries with
  the saved push subscription ID when the alias does not yet have a subscribed
  device.

In **Settings → Hiraaj Notifications**, confirm the OneSignal App ID and a
current REST API key are saved. Push delivery cannot work with an empty,
expired, or rotated REST API key.

After replacing the snippets, clear the WordPress/Hostinger cache. Install the
matching Flutter build and test with two real devices/accounts: send one
message in each direction, add a product comment, add and accept a public bid,
and verify the recipient receives push while the app is both open and closed.
