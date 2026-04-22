<?php
/**
 * Hiraaj Sahm: Service Provider API (User-Based)
 * Provides a REST endpoint for fetching inspectors and transporters from the WP User table.
 */

if (!defined('ABSPATH')) exit;

add_action('rest_api_init', function () {
    register_rest_route('custom/v1', '/service-providers', [
        'methods' => 'GET',
        'callback' => 'handle_get_service_providers',
        'permission_callback' => '__return_true',
    ]);
});

/**
 * GET /wp-json/custom/v1/service-providers
 * Query params: ?city=&type=[inspector|transporter]
 */
function handle_get_service_providers(WP_REST_Request $request) {
    $city = $request->get_param('city');
    $type = $request->get_param('type'); // 'inspector' or 'transporter'

    $meta_query = [
        'relation' => 'AND',
        [
            'key' => 'dokan_enable_selling',
            'value' => 'yes',
            'compare' => '='
        ]
    ];

    if (!empty($type)) {
        $meta_query[] = [
            'key' => 'seller_type',
            'value' => $type,
            'compare' => '='
        ];
    }

    if (!empty($city)) {
        $meta_query[] = [
            'key' => 'city', // Primary city field in user meta
            'value' => $city,
            'compare' => 'LIKE'
        ];
    }

    $args = [
        'role' => 'seller',
        'meta_query' => $meta_query,
        'number' => -1,
    ];

    $user_query = new WP_User_Query($args);
    $users = $user_query->get_results();

    $results = [];
    foreach ($users as $user) {
        $user_id = $user->ID;
        $store_info = dokan_get_store_info($user_id);
        
        $results[] = [
            'id' => $user_id,
            'store_name' => $store_info['store_name'] ?? $user->display_name,
            'phone' => get_user_meta($user_id, 'billing_phone', true) ?: get_user_meta($user_id, 'phone', true),
            'city' => get_user_meta($user_id, 'city', true),
            'type' => get_user_meta($user_id, 'seller_type', true),
            'store_url' => dokan_get_store_url($user_id),
            'image_url' => $store_info['gravatar'] ?? '',
        ];
    }

    return new WP_REST_Response($results, 200);
}
