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
    register_rest_route('hiraajsahm/v1', '/service-providers', [
        'methods' => 'GET',
        'callback' => 'handle_get_service_providers',
        'permission_callback' => '__return_true',
    ]);
    register_rest_route('hiraajsahm/v1', '/service-providers/register', [
        'methods' => 'POST',
        'callback' => 'handle_register_service_provider',
        'permission_callback' => function () {
            if (!is_user_logged_in()) {
                return false;
            }
            $user = wp_get_current_user();
            return current_user_can('manage_options') || in_array('seller', (array) $user->roles, true);
        },
    ]);
});

function handle_register_service_provider(WP_REST_Request $request) {
    $type = sanitize_key($request->get_param('type'));
    if (!in_array($type, ['inspector', 'transporter'], true)) {
        return new WP_Error('invalid_provider_type', 'Invalid provider type', ['status' => 400]);
    }
    $user_id = get_current_user_id();
    update_user_meta($user_id, 'seller_type', $type);
    update_user_meta($user_id, 'dokan_enable_selling', 'yes');
    return new WP_REST_Response([
        'success' => true,
        'type' => $type,
        'message' => 'Service provider registration updated',
    ], 200);
}

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
        
        $seller_type = get_user_meta($user_id, 'seller_type', true);
        $results[] = [
            'id' => $user_id,
            'name' => $store_info['store_name'] ?? $user->display_name,
            'store_name' => $store_info['store_name'] ?? $user->display_name,
            'phone' => get_user_meta($user_id, 'billing_phone', true) ?: get_user_meta($user_id, 'phone', true),
            'city' => get_user_meta($user_id, 'city', true),
            'role' => ($seller_type === 'transporter') ? 'ناقل' : 'معاين',
            'type' => $seller_type,
            'vehicle_details' => get_user_meta($user_id, 'vehicle_details', true) ?: (($seller_type === 'transporter') ? '🚛 ناقل (نقل مركبات)' : '🔍 معاين (فحص مركبات)'),
            'price_per_kilo' => get_user_meta($user_id, 'price_per_kilo', true) ?: '0',
            'store_url' => dokan_get_store_url($user_id),
            'image_url' => $store_info['gravatar'] ?? '',
        ];
    }

    return new WP_REST_Response($results, 200);
}
