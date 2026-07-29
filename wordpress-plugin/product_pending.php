<?php
add_action('rest_api_init', function () {
    register_rest_route('custom/v1', '/add-product-v2', [
        'methods' => 'POST',
        'callback' => 'handle_custom_add_product_v2',
        'permission_callback' => function () {
            if (!is_user_logged_in()) {
                return false;
            }
            $user = wp_get_current_user();
            return current_user_can('manage_options') || in_array('seller', (array) $user->roles, true);
        }
    ]);
    register_rest_route('custom/v1', '/add-product-quota', [
        'methods' => 'GET',
        'callback' => 'hiraaj_sahm_get_add_product_quota',
        'permission_callback' => function () {
            if (!is_user_logged_in()) {
                return false;
            }
            $user = wp_get_current_user();
            return current_user_can('manage_options') || in_array('seller', (array) $user->roles, true);
        }
    ]);
});

/**
 * Resolve the active package across current and legacy Dokan metadata.
 * Existing sellers created before product_package_id was introduced retain
 * the free Bronze entitlement instead of being incorrectly blocked.
 */
function hiraaj_sahm_resolve_seller_pack_id($user_id)
{
    $allowed_packs = [29026, 29028, 29030, 29318];
    $meta_keys = [
        'product_package_id',
        'dokan_feature_seller_package_id',
        '_dokan_subscription_pack_id',
        'dokan_subscription_pack_id',
        'dokan_subscription_pack',
    ];
    foreach ($meta_keys as $meta_key) {
        $candidate = absint(get_user_meta($user_id, $meta_key, true));
        if (in_array($candidate, $allowed_packs, true)) {
            return $candidate;
        }
    }

    $profile = get_user_meta($user_id, 'dokan_profile_settings', true);
    if (is_array($profile)) {
        $candidate = absint(
            $profile['assigned_subscription']
            ?? $profile['assigned_subscription_info']['subscription_id']
            ?? 0
        );
        if (in_array($candidate, $allowed_packs, true)) {
            return $candidate;
        }
    }

    if (get_user_meta($user_id, 'sacrifices_verified', true) === 'yes') {
        return 29318;
    }

    $user = get_userdata($user_id);
    if ($user && in_array('seller', (array) $user->roles, true)) {
        update_user_meta($user_id, 'product_package_id', 29026);
        return 29026;
    }
    return 0;
}

function hiraaj_sahm_get_add_product_quota()
{
    $user_id = get_current_user_id();
    $pack_id = hiraaj_sahm_resolve_seller_pack_id($user_id);
    if (!$pack_id && !current_user_can('manage_options')) {
        return new WP_Error('subscription_required', 'يجب الاشتراك في باقة لإضافة منتجات', ['status' => 403]);
    }

    $daily_limit = current_user_can('manage_options')
        ? -1
        : hiraaj_sahm_daily_ad_limit($pack_id);
    $ads_today = current_user_can('manage_options')
        ? 0
        : hiraaj_sahm_count_seller_ads_today($user_id, $daily_limit);

    return new WP_REST_Response([
        'pack_id' => (int) $pack_id,
        'daily_limit' => (int) $daily_limit,
        'ads_today' => (int) $ads_today,
        'remaining_today' => $daily_limit < 0
            ? -1
            : max(0, $daily_limit - $ads_today),
        'can_add' => $daily_limit < 0 || $ads_today < $daily_limit,
        'resets_at' => (new DateTimeImmutable('tomorrow', wp_timezone()))->format(DATE_ATOM),
    ], 200);
}

function handle_custom_add_product_v2($request)
{
    $user_id = get_current_user_id(); // The Vendor

    $pack_id = hiraaj_sahm_resolve_seller_pack_id($user_id);
    $allowed_packs = [29026, 29028, 29030, 29318]; // Bronze, Silver, Gold and Zabayeh
    if (!in_array((int) $pack_id, $allowed_packs) && !current_user_can('manage_options')) {
        return new WP_REST_Response([
            'success' => false,
            'message' => 'يجب الاشتراك في باقة لإضافة منتجات'
        ], 403);
    }

    // Enforce the daily limit on the server, using the authenticated seller's
    // ID. Do not trust a client-provided user ID or a client-side product count:
    // either can result in one seller affecting another seller's ability to post.
    if (!current_user_can('manage_options')) {
        $daily_limit = hiraaj_sahm_daily_ad_limit((int) $pack_id);
        $ads_today = hiraaj_sahm_count_seller_ads_today($user_id, $daily_limit);

        if ($ads_today >= $daily_limit) {
            return new WP_REST_Response([
                'success' => false,
                'message' => sprintf('لقد وصلت للحد الأقصى للإعلانات اليومية (%d إعلانات)', $daily_limit),
                'code' => 'daily_ad_limit_reached',
                'daily_limit' => $daily_limit,
                'ads_today' => $ads_today,
            ], 429);
        }
    }

    $params = $request->get_json_params();

    // 1. Sanitize Input with Null-Coalescing
    $title = sanitize_text_field($params['name'] ?? '');
    $price = sanitize_text_field($params['regular_price'] ?? '0');
    $sale_price = sanitize_text_field($params['sale_price'] ?? '');
    $description = wp_kses_post($params['description'] ?? '');
    $cat_id = intval($params['category_id'] ?? 0);
    $stock = intval($params['stock_quantity'] ?? 0);
    $image_ids = array_values(array_filter(array_map('absint', (array) ($params['images'] ?? [])))); // Array of Image IDs
    if ($title === '' || $cat_id <= 0) {
        return new WP_REST_Response([
            'success' => false,
            'message' => 'Product name and category are required',
        ], 400);
    }
    foreach ($image_ids as $image_id) {
        $attachment = get_post($image_id);
        if (
            !$attachment ||
            $attachment->post_type !== 'attachment' ||
            (!current_user_can('manage_options') && (int) $attachment->post_author !== (int) $user_id)
        ) {
            return new WP_REST_Response([
                'success' => false,
                'message' => 'One or more uploaded files are invalid',
            ], 403);
        }
    }

    $can_publish = current_user_can('manage_options') ||
        (
            get_user_meta($user_id, 'dokan_enable_selling', true) === 'yes' &&
            get_user_meta($user_id, 'dokan_publishing', true) === 'yes'
        );

    // 2. Create the Product Post
    $post_data = [
        'post_title' => $title,
        'post_content' => $description,
        // The server, not the mobile app, decides whether this vendor may publish.
        'post_status' => $can_publish ? 'publish' : 'pending',
        'post_type' => 'product',
        'post_author' => $user_id,  // 👤 ASSIGN TO VENDOR
    ];

    $product_id = wp_insert_post($post_data);

    if (is_wp_error($product_id)) {
        return $product_id;
    }

    // 3. Set Category & Type
    wp_set_object_terms($product_id, 'simple', 'product_type');
    if ($cat_id > 0) {
        wp_set_object_terms($product_id, $cat_id, 'product_cat');
    }

    // 4. Set Prices & Stock
    update_post_meta($product_id, '_regular_price', $price);

    if (!empty($sale_price)) {
        update_post_meta($product_id, '_sale_price', $sale_price);
        update_post_meta($product_id, '_price', $sale_price);
    } else {
        update_post_meta($product_id, '_price', $price);
    }

    update_post_meta($product_id, '_manage_stock', 'yes');
    update_post_meta($product_id, '_stock', $stock);
    update_post_meta($product_id, '_stock_status', $stock > 0 ? 'instock' : 'outofstock');
    update_post_meta($product_id, '_visibility', 'visible');

    // 5. Handle Images (Thumbnail + Gallery)
    if (!empty($image_ids)) {
        foreach ($image_ids as $image_id) {
            if (function_exists('hiraaj_sahm_watermark_attachment')) {
                hiraaj_sahm_watermark_attachment($image_id);
            }
        }

        // Set first image as Main Thumbnail
        set_post_thumbnail($product_id, $image_ids[0]);

        // Remove first image and set the rest as Gallery
        $gallery_image_ids = array_slice($image_ids, 1);
        if (!empty($gallery_image_ids)) {
            update_post_meta($product_id, '_product_image_gallery', implode(',', $gallery_image_ids));
        }
    }

    // 6. Handle Meta Data (including Video)
    if (!empty($params['meta_data']) && is_array($params['meta_data'])) {
        $allowed_meta_keys = [
            '_product_location',
            '_product_region',
            '_product_city',
            'add_down_payment_field',
            '_product_video_id',
        ];
        foreach ($params['meta_data'] as $meta) {
            if (
                isset($meta['key'], $meta['value']) &&
                in_array($meta['key'], $allowed_meta_keys, true)
            ) {
                if ($meta['key'] === '_product_video_id') {
                    $video_id = absint($meta['value']);
                    $video = get_post($video_id);
                    if (
                        !$video ||
                        $video->post_type !== 'attachment' ||
                        (!current_user_can('manage_options') && (int) $video->post_author !== (int) $user_id)
                    ) {
                        continue;
                    }
                }
                update_post_meta($product_id, sanitize_text_field($meta['key']), sanitize_text_field($meta['value']));

                // If the app sent a video ID, convert it to a URL for the theme/app to read
                if ($meta['key'] === '_product_video_id') {
                    $video_url = wp_get_attachment_url((int) $meta['value']);
                    if ($video_url) {
                        update_post_meta($product_id, '_product_video', $video_url);
                        // Also Dokan uses _video_url sometimes
                        update_post_meta($product_id, '_video_url', $video_url);
                    }
                }
            }
        }
    }

    return new WP_REST_Response([
        'success' => true,
        'product_id' => $product_id,
        'status' => get_post_status($product_id),
        'message' => 'Product created successfully'
    ], 200);
}

/**
 * Returns the number of ads a package may create per WordPress calendar day.
 * Keep this policy on the server; the filter permits a future plugin/settings
 * page to change it without releasing a new mobile build.
 */
function hiraaj_sahm_daily_ad_limit($pack_id)
{
    $limits = [
        29026 => 1, // Bronze
        29028 => 5, // Silver
        29030 => 5, // Gold
        29318 => 5, // Al-Zabayeh
    ];

    $limit = $limits[$pack_id] ?? 1;
    return max(1, (int) apply_filters('hiraaj_sahm_daily_ad_limit', $limit, $pack_id));
}

/**
 * Counts this seller's ads from WordPress midnight onward. Pending posts are
 * included because this endpoint creates ads as pending before approval.
 */
function hiraaj_sahm_count_seller_ads_today($user_id, $limit)
{
    $day_start = current_time('Y-m-d') . ' 00:00:00';

    $query = new WP_Query([
        'author' => (int) $user_id,
        'post_type' => 'product',
        'post_status' => ['publish', 'pending', 'draft', 'private'],
        'date_query' => [[
            'after' => $day_start,
            'inclusive' => true,
        ]],
        'fields' => 'ids',
        'posts_per_page' => (int) $limit,
        'no_found_rows' => true,
        'ignore_sticky_posts' => true,
    ]);

    return count($query->posts);
}
