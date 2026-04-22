<?php
add_action('rest_api_init', function () {
    register_rest_route('custom/v1', '/register-vendor', [
        'methods' => 'POST',
        'callback' => 'handle_vendor_request', // Renamed function
        'permission_callback' => '__return_true',
    ]);
});

function handle_vendor_request($request)
{
    $params = $request->get_json_params();

    // 1. Check if this is an UPGRADE (User ID provided) or REGISTRATION
    $user_id = isset($params['user_id']) ? intval($params['user_id']) : 0;

    $store_name = sanitize_text_field($params['store_name']);
    $phone = sanitize_text_field($params['phone']);
    $pack_id = isset($params['pack_id']) ? intval($params['pack_id']) : 0; // Default or pass 0

    // --- MODE 1: UPGRADE EXISTING USER ---
    if ($user_id > 0) {
        // Ensure the logged-in user can only upgrade themselves
        if (!is_user_logged_in()) {
            return new WP_Error('not_logged_in', 'Authentication required', ['status' => 401]);
        }
        if (get_current_user_id() !== $user_id && !current_user_can('manage_options')) {
            return new WP_Error('forbidden', 'You can only upgrade your own account', ['status' => 403]);
        }
        $user = get_userdata($user_id);
        if (!$user) {
            return new WP_Error('invalid_user', 'User ID not found', ['status' => 404]);
        }

        $email = $user->user_email;
        $username = $user->user_login;
        $first_name = $user->first_name;
        $last_name = $user->last_name;

        // Change Role to Seller
        $u = new WP_User($user_id);
        $u->set_role('seller');
    }
    // --- MODE 2: REGISTER NEW USER ---
    else {
        $email = sanitize_email($params['email']);
        if (empty($email)) {
            return new WP_Error('missing_email', 'Email is required for new registration', ['status' => 400]);
        }

        $password = $params['password'];
        if (strlen($password) < 8) {
            return new WP_Error('weak_password', 'Password must be at least 8 characters', ['status' => 400]);
        }
        $username = sanitize_user(explode('@', $email)[0], true);
        $first_name = sanitize_text_field($params['first_name']);
        $last_name = sanitize_text_field($params['last_name']);

        // Check if user exists
        if (username_exists($username) || email_exists($email)) {
            return new WP_Error('user_exists', 'User already exists', ['status' => 400]);
        }

        // Create User
        $user_id = wp_create_user($username, $password, $email);
        if (is_wp_error($user_id)) {
            return $user_id;
        }

        // Set Role
        wp_update_user(['ID' => $user_id, 'role' => 'seller', 'first_name' => $first_name, 'last_name' => $last_name]);
    }

    // --- SHARED LOGIC (Dokan Setup for Both Modes) ---

    // Generate Store Slug
    $store_slug = sanitize_title($store_name);
    if (username_exists($store_slug) || get_user_by('slug', $store_slug)) {
        $store_slug .= '-' . rand(100, 999);
    }

    // Save Meta Data
    update_user_meta($user_id, 'billing_phone', $phone);
    update_user_meta($user_id, 'dokan_store_name', $store_name);
    update_user_meta($user_id, 'dokan_store_phone', $phone);
    update_user_meta($user_id, 'dokan_enable_selling', 'yes');
    update_user_meta($user_id, 'dokan_publishing', 'yes');

    // Dokan Settings
    $dokan_settings = [
        'store_name' => $store_name,
        'store_slug' => $store_slug,
        'phone' => $phone,
        'show_email' => 'no',
        'location' => '',
        'enable_tnc' => 'off',
    ];
    update_user_meta($user_id, 'dokan_profile_settings', $dokan_settings);

    // Initialize Vendor in Dokan
    do_action('dokan_new_seller_created', $user_id, $dokan_settings);

    // Get Store URL
    $store_url = function_exists('dokan_get_store_url') ? dokan_get_store_url($user_id) : home_url('/store/' . $store_slug . '/');

    return new WP_REST_Response([
        'success' => true,
        'id' => $user_id,
        'role' => 'seller',
        'is_vendor' => true,
        'store_url' => $store_url
    ], 200);
}