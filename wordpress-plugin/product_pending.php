<?php
add_action('rest_api_init', function () {
    register_rest_route('custom/v1', '/add-product', [
        'methods' => 'POST',
        'callback' => 'handle_custom_add_product',
        'permission_callback' => function () {
            return is_user_logged_in(); // Requires JWT Token
        }
    ]);
});

function handle_custom_add_product($request)
{
    $user_id = get_current_user_id(); // The Vendor

    $pack_id = get_user_meta($user_id, 'product_package_id', true);
    $allowed_packs = [29028, 29030, 29318]; // Silver, Gold and Zabayeh only
    if (!in_array((int)$pack_id, $allowed_packs) && !current_user_can('manage_options')) {
        return new WP_REST_Response([
            'success' => false,
            'message' => 'يجب الاشتراك في باقة فضية أو ذهبية لإضافة منتجات'
        ], 403);
    }

    $params = $request->get_json_params();

    // 1. Sanitize Input with Null-Coalescing
    $title = sanitize_text_field($params['name'] ?? '');
    $price = sanitize_text_field($params['regular_price'] ?? '0');
    $sale_price = sanitize_text_field($params['sale_price'] ?? '');
    $description = wp_kses_post($params['description'] ?? '');
    $cat_id = intval($params['category_id'] ?? 0);
    $stock = intval($params['stock_quantity'] ?? 0);
    $image_ids = $params['images'] ?? []; // Array of Image IDs

    // 2. Create the Product Post
    $post_data = [
        'post_title' => $title,
        'post_content' => $description,
        'post_status' => 'pending', // 🔒 FORCE PENDING STATUS
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
    if (!empty($image_ids) && is_array($image_ids)) {
        // Set first image as Main Thumbnail
        set_post_thumbnail($product_id, $image_ids[0]);

        // Remove first image and set the rest as Gallery
        array_shift($image_ids);
        if (!empty($image_ids)) {
            update_post_meta($product_id, '_product_image_gallery', implode(',', $image_ids));
        }
    }

    return new WP_REST_Response([
        'success' => true,
        'product_id' => $product_id,
        'message' => 'Product created successfully'
    ], 200);
}