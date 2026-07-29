<?php
/**
 * Hiraaj Sahm Marketplace Bridge
 *
 * Add this file as one Code Snippets snippet (without the opening PHP tag), or
 * install it as part of the custom site plugin. It provides server-backed
 * follows, private messages, vendor-scoped products, and zero-price orders.
 */

add_action('init', 'hiraaj_marketplace_register_conversation_type');
function hiraaj_marketplace_register_conversation_type()
{
    register_post_type('hiraaj_conversation', [
        'label' => 'محادثات التطبيق',
        'public' => false,
        'show_ui' => true,
        'show_in_menu' => false,
        'supports' => ['title', 'author'],
        'capability_type' => 'post',
        'map_meta_cap' => true,
    ]);
}

if (!function_exists('hiraaj_product_has_completed_marketplace_sale')) {
    function hiraaj_product_has_completed_marketplace_sale($product_id)
    {
        $sale_type = sanitize_key(get_post_meta($product_id, '_hiraaj_final_sale_type', true));
        $sale_id = (int) get_post_meta($product_id, '_hiraaj_final_sale_id', true);
        if (!$sale_id) {
            return false;
        }
        if ($sale_type === 'public') {
            return sanitize_key(get_comment_meta($sale_id, '_hiraaj_bid_status', true)) === 'purchased'
                || (int) get_comment_meta($sale_id, '_hiraaj_bid_order_id', true) > 0;
        }
        if ($sale_type === 'private') {
            return sanitize_key(get_comment_meta($sale_id, '_hiraaj_private_offer_status', true)) === 'purchased'
                || (int) get_comment_meta($sale_id, '_hiraaj_private_offer_order_id', true) > 0;
        }
        return false;
    }
}

add_action('rest_api_init', 'hiraaj_marketplace_register_routes');
function hiraaj_marketplace_register_routes()
{
    register_rest_route('custom/v1', '/follows/(?P<vendor_id>\d+)', [
        [
            'methods' => 'GET',
            'callback' => 'hiraaj_marketplace_follow_status',
            'permission_callback' => '__return_true',
        ],
        [
            'methods' => 'POST',
            'callback' => 'hiraaj_marketplace_update_follow',
            'permission_callback' => 'is_user_logged_in',
        ],
    ]);
    register_rest_route('custom/v1', '/favorites', [
        [
            'methods' => 'GET',
            'callback' => 'hiraaj_marketplace_get_favorites',
            'permission_callback' => 'is_user_logged_in',
        ],
        [
            'methods' => 'POST',
            'callback' => 'hiraaj_marketplace_update_favorite',
            'permission_callback' => 'is_user_logged_in',
        ],
    ]);

    register_rest_route('custom/v1', '/vendor/products', [
        'methods' => 'GET',
        'callback' => 'hiraaj_marketplace_vendor_products',
        'permission_callback' => 'is_user_logged_in',
    ]);
    register_rest_route('custom/v1', '/vendors/(?P<vendor_id>\d+)/products', [
        'methods' => 'GET',
        'callback' => 'hiraaj_marketplace_public_vendor_products',
        'permission_callback' => '__return_true',
    ]);
    register_rest_route('custom/v1', '/vendor/products/(?P<product_id>\d+)', [
        'methods' => 'DELETE',
        'callback' => 'hiraaj_marketplace_delete_vendor_product',
        'permission_callback' => 'is_user_logged_in',
    ]);

    register_rest_route('custom/v1', '/messages/conversations', [
        'methods' => 'GET',
        'callback' => 'hiraaj_marketplace_get_conversations',
        'permission_callback' => 'is_user_logged_in',
    ]);
    register_rest_route('custom/v1', '/messages/unread-count', [
        'methods' => 'GET',
        'callback' => 'hiraaj_marketplace_get_unread_count',
        'permission_callback' => 'is_user_logged_in',
    ]);
    register_rest_route('custom/v1', '/messages/start', [
        'methods' => 'POST',
        'callback' => 'hiraaj_marketplace_start_conversation',
        'permission_callback' => 'is_user_logged_in',
    ]);
    register_rest_route('custom/v1', '/messages/(?P<conversation_id>\d+)', [
        [
            'methods' => 'GET',
            'callback' => 'hiraaj_marketplace_get_messages',
            'permission_callback' => 'is_user_logged_in',
        ],
        [
            'methods' => 'POST',
            'callback' => 'hiraaj_marketplace_send_message',
            'permission_callback' => 'is_user_logged_in',
        ],
    ]);
}

function hiraaj_marketplace_follow_status(WP_REST_Request $request)
{
    $vendor_id = absint($request['vendor_id']);
    if (!$vendor_id || !get_userdata($vendor_id)) {
        return new WP_Error('vendor_not_found', 'Vendor not found', ['status' => 404]);
    }
    $user_id = get_current_user_id();
    $followed = $user_id
        ? array_map('intval', (array) get_user_meta($user_id, '_hiraaj_followed_vendors', true))
        : [];

    return new WP_REST_Response([
        'following' => in_array($vendor_id, $followed, true),
        'count' => (int) get_user_meta($vendor_id, '_hiraaj_follower_count', true),
    ], 200);
}

function hiraaj_marketplace_update_follow(WP_REST_Request $request)
{
    $user_id = get_current_user_id();
    $vendor_id = absint($request['vendor_id']);
    if (!$vendor_id || !get_userdata($vendor_id)) {
        return new WP_Error('vendor_not_found', 'Vendor not found', ['status' => 404]);
    }
    if ($vendor_id === $user_id) {
        return new WP_Error('cannot_follow_self', 'You cannot follow yourself', ['status' => 400]);
    }

    $params = $request->get_json_params();
    $should_follow = rest_sanitize_boolean($params['follow'] ?? true);
    $followed = array_values(array_unique(array_map(
        'intval',
        (array) get_user_meta($user_id, '_hiraaj_followed_vendors', true)
    )));
    $was_following = in_array($vendor_id, $followed, true);

    if ($should_follow && !$was_following) {
        $followed[] = $vendor_id;
    } elseif (!$should_follow && $was_following) {
        $followed = array_values(array_diff($followed, [$vendor_id]));
    }
    update_user_meta($user_id, '_hiraaj_followed_vendors', $followed);

    if ($was_following !== $should_follow) {
        $count = (int) get_user_meta($vendor_id, '_hiraaj_follower_count', true);
        update_user_meta(
            $vendor_id,
            '_hiraaj_follower_count',
            max(0, $count + ($should_follow ? 1 : -1))
        );
        if ($should_follow && function_exists('hiraaj_send_notification_to_users')) {
            $follower = get_userdata($user_id);
            hiraaj_send_notification_to_users(
                [$vendor_id],
                '👤 متابع جديد',
                ($follower ? $follower->display_name : 'مستخدم') . ' بدأ بمتابعة متجرك',
                ['type' => 'follow', 'id' => (string) $user_id]
            );
        }
    }

    return hiraaj_marketplace_follow_status($request);
}

function hiraaj_marketplace_get_favorites()
{
    $ids = array_values(array_unique(array_filter(array_map(
        'absint',
        (array) get_user_meta(
            get_current_user_id(),
            '_hiraaj_favorite_products',
            true
        )
    ))));
    $ids = array_values(array_filter($ids, function ($product_id) {
        return get_post_status($product_id) === 'publish'
            && get_post_type($product_id) === 'product';
    }));
    return new WP_REST_Response(['product_ids' => $ids], 200);
}

function hiraaj_marketplace_update_favorite(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    $product_id = absint($params['product_id'] ?? 0);
    $favorite = rest_sanitize_boolean($params['favorite'] ?? true);
    if (
        !$product_id
        || get_post_type($product_id) !== 'product'
        || get_post_status($product_id) !== 'publish'
    ) {
        return new WP_Error('product_not_found', 'Product not found', ['status' => 404]);
    }
    $user_id = get_current_user_id();
    $ids = array_values(array_unique(array_filter(array_map(
        'absint',
        (array) get_user_meta($user_id, '_hiraaj_favorite_products', true)
    ))));
    if ($favorite && !in_array($product_id, $ids, true)) {
        $ids[] = $product_id;
    } elseif (!$favorite) {
        $ids = array_values(array_diff($ids, [$product_id]));
    }
    update_user_meta($user_id, '_hiraaj_favorite_products', $ids);
    return new WP_REST_Response([
        'success' => true,
        'favorite' => $favorite,
        'product_ids' => $ids,
    ], 200);
}

function hiraaj_marketplace_vendor_products(WP_REST_Request $request)
{
    if (!class_exists('WooCommerce') || !class_exists('WC_REST_Products_Controller')) {
        return new WP_Error('woocommerce_required', 'WooCommerce is required', ['status' => 500]);
    }

    $user_id = get_current_user_id();
    $per_page = min(100, max(1, absint($request->get_param('per_page') ?: 20)));
    $page = max(1, absint($request->get_param('page') ?: 1));
    $requested_status = sanitize_key($request->get_param('status') ?: 'any');
    $allowed_statuses = ['publish', 'pending', 'draft', 'private'];
    $post_status = $requested_status === 'any'
        ? $allowed_statuses
        : (in_array($requested_status, $allowed_statuses, true) ? [$requested_status] : $allowed_statuses);

    $query = new WP_Query([
        'post_type' => 'product',
        'post_status' => $post_status,
        'author' => $user_id,
        'posts_per_page' => $per_page,
        'paged' => $page,
        'orderby' => 'date',
        'order' => 'DESC',
        'fields' => 'ids',
    ]);

    $controller = new WC_REST_Products_Controller();
    $product_request = new WP_REST_Request('GET');
    $product_request->set_param('context', 'edit');
    $items = [];
    foreach ($query->posts as $product_id) {
        $product = wc_get_product($product_id);
        if (!$product) {
            continue;
        }
        $prepared = $controller->prepare_item_for_response($product, $product_request);
        $items[] = $prepared instanceof WP_REST_Response ? $prepared->get_data() : $prepared;
    }

    $response = new WP_REST_Response($items, 200);
    $response->header('X-WP-Total', (int) $query->found_posts);
    $response->header('X-WP-TotalPages', (int) $query->max_num_pages);
    return $response;
}

function hiraaj_marketplace_public_vendor_products(WP_REST_Request $request)
{
    $vendor_id = absint($request['vendor_id']);
    if (!$vendor_id || !get_userdata($vendor_id)) {
        return new WP_Error('vendor_not_found', 'Vendor not found', ['status' => 404]);
    }
    if (!class_exists('WooCommerce') || !class_exists('WC_REST_Products_Controller')) {
        return new WP_Error('woocommerce_required', 'WooCommerce is required', ['status' => 500]);
    }
    $per_page = min(100, max(1, absint($request->get_param('per_page') ?: 20)));
    $page = max(1, absint($request->get_param('page') ?: 1));
    $query = new WP_Query([
        'post_type' => 'product',
        'post_status' => 'publish',
        'author' => $vendor_id,
        'posts_per_page' => $per_page,
        'paged' => $page,
        'orderby' => 'date',
        'order' => 'DESC',
        'fields' => 'ids',
    ]);
    $controller = new WC_REST_Products_Controller();
    $product_request = new WP_REST_Request('GET');
    $product_request->set_param('context', 'view');
    $items = [];
    foreach ($query->posts as $product_id) {
        $product = wc_get_product($product_id);
        if ($product) {
            $prepared = $controller->prepare_item_for_response($product, $product_request);
            $items[] = $prepared instanceof WP_REST_Response ? $prepared->get_data() : $prepared;
        }
    }
    $response = new WP_REST_Response($items, 200);
    $response->header('X-WP-Total', (int) $query->found_posts);
    $response->header('X-WP-TotalPages', (int) $query->max_num_pages);
    return $response;
}

function hiraaj_marketplace_delete_vendor_product(WP_REST_Request $request)
{
    $product_id = absint($request['product_id']);
    $post = get_post($product_id);
    if (!$post || $post->post_type !== 'product') {
        return new WP_Error('product_not_found', 'Product not found', ['status' => 404]);
    }
    if ((int) $post->post_author !== get_current_user_id() && !current_user_can('manage_woocommerce')) {
        return new WP_Error('forbidden', 'This product does not belong to you', ['status' => 403]);
    }
    $accepted_bid_id = (int) get_post_meta($product_id, '_hiraaj_accepted_bid_id', true);
    $accepted_bid_status = $accepted_bid_id
        ? sanitize_key(get_comment_meta($accepted_bid_id, '_hiraaj_bid_status', true))
        : '';
    if ($accepted_bid_status === 'accepted') {
        return new WP_Error(
            'accepted_sale_pending',
            'This product has an accepted bid waiting for checkout and cannot be deleted',
            ['status' => 409]
        );
    }
    $conversations = get_posts([
        'post_type' => 'hiraaj_conversation',
        'post_status' => 'private',
        'numberposts' => -1,
        'fields' => 'ids',
        'meta_key' => '_hiraaj_product_id',
        'meta_value' => $product_id,
    ]);
    foreach ($conversations as $conversation_id) {
        $accepted_offers = get_comments([
            'post_id' => $conversation_id,
            'type' => 'hiraaj_message',
            'status' => 'approve',
            'meta_key' => '_hiraaj_private_offer_status',
            'meta_value' => 'accepted',
            'number' => 1,
        ]);
        if (!empty($accepted_offers)) {
            return new WP_Error(
                'accepted_sale_pending',
                'This product has an accepted private offer waiting for checkout and cannot be deleted',
                ['status' => 409]
            );
        }
    }

    $force = rest_sanitize_boolean($request->get_param('force'));
    $deleted = wp_delete_post($product_id, $force);
    if (!$deleted) {
        return new WP_Error('delete_failed', 'Could not delete product', ['status' => 500]);
    }
    return new WP_REST_Response(['deleted' => true, 'id' => $product_id], 200);
}

function hiraaj_marketplace_conversation_participants($conversation_id)
{
    return [
        (int) get_post_meta($conversation_id, '_hiraaj_buyer_id', true),
        (int) get_post_meta($conversation_id, '_hiraaj_vendor_id', true),
    ];
}

function hiraaj_marketplace_can_access_conversation($conversation_id, $user_id = 0)
{
    $user_id = $user_id ?: get_current_user_id();
    $post = get_post($conversation_id);
    return $post
        && $post->post_type === 'hiraaj_conversation'
        && (in_array((int) $user_id, hiraaj_marketplace_conversation_participants($conversation_id), true)
            || current_user_can('manage_options'));
}

function hiraaj_marketplace_find_conversation($buyer_id, $vendor_id, $product_id)
{
    $ids = get_posts([
        'post_type' => 'hiraaj_conversation',
        'post_status' => 'private',
        'numberposts' => 1,
        'fields' => 'ids',
        'meta_query' => [
            'relation' => 'AND',
            ['key' => '_hiraaj_buyer_id', 'value' => $buyer_id, 'compare' => '='],
            ['key' => '_hiraaj_vendor_id', 'value' => $vendor_id, 'compare' => '='],
            ['key' => '_hiraaj_product_id', 'value' => $product_id, 'compare' => '='],
        ],
    ]);
    return empty($ids) ? 0 : (int) $ids[0];
}

function hiraaj_marketplace_unread_meta_key($user_id)
{
    return '_hiraaj_last_read_message_' . absint($user_id);
}

function hiraaj_marketplace_conversation_unread_count($conversation_id, $user_id)
{
    global $wpdb;
    $last_read_id = (int) get_post_meta(
        $conversation_id,
        hiraaj_marketplace_unread_meta_key($user_id),
        true
    );

    return (int) $wpdb->get_var($wpdb->prepare(
        "SELECT COUNT(*)
         FROM {$wpdb->comments}
         WHERE comment_post_ID = %d
           AND comment_type = 'hiraaj_message'
           AND comment_approved = '1'
           AND comment_ID > %d
           AND user_id <> %d",
        $conversation_id,
        $last_read_id,
        $user_id
    ));
}

function hiraaj_marketplace_get_unread_count()
{
    $user_id = get_current_user_id();
    $conversation_ids = get_posts([
        'post_type' => 'hiraaj_conversation',
        'post_status' => 'private',
        'posts_per_page' => 100,
        'fields' => 'ids',
        'meta_query' => [
            'relation' => 'OR',
            ['key' => '_hiraaj_buyer_id', 'value' => $user_id, 'compare' => '='],
            ['key' => '_hiraaj_vendor_id', 'value' => $user_id, 'compare' => '='],
        ],
    ]);

    $count = 0;
    foreach ($conversation_ids as $conversation_id) {
        $count += hiraaj_marketplace_conversation_unread_count(
            (int) $conversation_id,
            $user_id
        );
    }
    return new WP_REST_Response(['unread_count' => $count], 200);
}

function hiraaj_marketplace_start_conversation(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    $buyer_id = get_current_user_id();
    $vendor_id = absint($params['vendor_id'] ?? 0);
    $product_id = absint($params['product_id'] ?? 0);
    $product = get_post($product_id);

    if (!$vendor_id || !$product || $product->post_type !== 'product' || (int) $product->post_author !== $vendor_id) {
        return new WP_Error('invalid_product_vendor', 'Invalid product or vendor', ['status' => 400]);
    }
    if ($buyer_id === $vendor_id) {
        return new WP_Error('cannot_message_self', 'You cannot message yourself', ['status' => 400]);
    }

    $conversation_id = hiraaj_marketplace_find_conversation($buyer_id, $vendor_id, $product_id);
    if (!$conversation_id) {
        $conversation_id = wp_insert_post([
            'post_type' => 'hiraaj_conversation',
            'post_status' => 'private',
            'post_author' => $buyer_id,
            'post_title' => 'محادثة حول: ' . get_the_title($product_id),
        ], true);
        if (is_wp_error($conversation_id)) {
            return $conversation_id;
        }
        update_post_meta($conversation_id, '_hiraaj_buyer_id', $buyer_id);
        update_post_meta($conversation_id, '_hiraaj_vendor_id', $vendor_id);
        update_post_meta($conversation_id, '_hiraaj_product_id', $product_id);
    }

    $message = sanitize_textarea_field($params['message'] ?? '');
    if ($message !== '') {
        $message_request = new WP_REST_Request('POST');
        $message_request->set_param('conversation_id', $conversation_id);
        $message_request->set_body_params(['message' => $message]);
        $sent = hiraaj_marketplace_send_message($message_request);
        if (is_wp_error($sent)) {
            return $sent;
        }
    }

    return new WP_REST_Response([
        'conversation_id' => (int) $conversation_id,
        'product_id' => $product_id,
        'other_user_id' => $vendor_id,
        'other_user_name' => get_the_author_meta('display_name', $vendor_id),
    ], 200);
}

function hiraaj_marketplace_get_conversations()
{
    $user_id = get_current_user_id();
    $query = new WP_Query([
        'post_type' => 'hiraaj_conversation',
        'post_status' => 'private',
        'posts_per_page' => 100,
        'orderby' => 'modified',
        'order' => 'DESC',
        'meta_query' => [
            'relation' => 'OR',
            ['key' => '_hiraaj_buyer_id', 'value' => $user_id, 'compare' => '='],
            ['key' => '_hiraaj_vendor_id', 'value' => $user_id, 'compare' => '='],
        ],
    ]);

    $items = [];
    foreach ($query->posts as $conversation) {
        [$buyer_id, $vendor_id] = hiraaj_marketplace_conversation_participants($conversation->ID);
        $other_user_id = $user_id === $buyer_id ? $vendor_id : $buyer_id;
        $product_id = (int) get_post_meta($conversation->ID, '_hiraaj_product_id', true);
        $messages = get_comments([
            'post_id' => $conversation->ID,
            'type' => 'hiraaj_message',
            'status' => 'approve',
            'number' => 1,
            'orderby' => 'comment_ID',
            'order' => 'DESC',
        ]);
        $items[] = [
            'id' => (int) $conversation->ID,
            'product_id' => $product_id,
            'product_name' => get_the_title($product_id),
            'buyer_id' => $buyer_id,
            'vendor_id' => $vendor_id,
            'other_user_id' => $other_user_id,
            'other_user_name' => get_the_author_meta('display_name', $other_user_id),
            'last_message' => empty($messages) ? '' : $messages[0]->comment_content,
            'unread_count' => hiraaj_marketplace_conversation_unread_count(
                (int) $conversation->ID,
                $user_id
            ),
            'updated_at' => get_post_modified_time(DATE_ATOM, true, $conversation),
        ];
    }
    return new WP_REST_Response($items, 200);
}

function hiraaj_marketplace_get_messages(WP_REST_Request $request)
{
    $conversation_id = absint($request['conversation_id']);
    if (!hiraaj_marketplace_can_access_conversation($conversation_id)) {
        return new WP_Error('forbidden', 'You cannot access this conversation', ['status' => 403]);
    }

    $page = max(1, absint($request->get_param('page')));
    $per_page = min(100, max(20, absint($request->get_param('per_page')) ?: 100));
    $messages = get_comments([
        'post_id' => $conversation_id,
        'type' => 'hiraaj_message',
        'status' => 'approve',
        'number' => $per_page,
        'offset' => ($page - 1) * $per_page,
        'orderby' => 'comment_ID',
        'order' => 'DESC',
    ]);
    // The query fetches the newest page first, while the chat renders oldest
    // to newest within each page.
    $messages = array_reverse($messages);
    if ($page === 1 && !empty($messages)) {
        $latest_message = end($messages);
        update_post_meta(
            $conversation_id,
            hiraaj_marketplace_unread_meta_key(get_current_user_id()),
            (int) $latest_message->comment_ID
        );
        reset($messages);
    }
    $items = array_map('hiraaj_marketplace_prepare_message', $messages);
    $response = new WP_REST_Response($items, 200);
    $response->header('X-Hiraaj-Has-More', count($messages) === $per_page ? '1' : '0');
    return $response;
}

function hiraaj_marketplace_send_message(WP_REST_Request $request)
{
    $conversation_id = absint($request['conversation_id'] ?: $request->get_param('conversation_id'));
    $sender_id = get_current_user_id();
    if (!hiraaj_marketplace_can_access_conversation($conversation_id, $sender_id)) {
        return new WP_Error('forbidden', 'You cannot access this conversation', ['status' => 403]);
    }

    $params = $request->get_json_params();
    if (empty($params)) {
        $params = $request->get_body_params();
    }
    $text = sanitize_textarea_field($params['message'] ?? '');
    if (function_exists('mb_strlen') && mb_strlen($text) > 2000) {
        return new WP_Error('message_too_long', 'Message is too long', ['status' => 400]);
    }

    $attachment_id = hiraaj_marketplace_handle_message_attachment();
    if (is_wp_error($attachment_id)) {
        return $attachment_id;
    }
    if ($text === '' && !$attachment_id) {
        return new WP_Error('message_required', 'Message or attachment is required', ['status' => 400]);
    }
    if ($text === '') {
        $text = '📎 مرفق';
    }

    $user = get_userdata($sender_id);
    $message_id = wp_insert_comment([
        'comment_post_ID' => $conversation_id,
        'comment_content' => $text,
        'comment_type' => 'hiraaj_message',
        'comment_approved' => 1,
        'user_id' => $sender_id,
        'comment_author' => $user ? $user->display_name : '',
        'comment_author_email' => $user ? $user->user_email : '',
    ]);
    if (!$message_id) {
        return new WP_Error('message_failed', 'Could not send message', ['status' => 500]);
    }
    if ($attachment_id) {
        add_comment_meta($message_id, '_hiraaj_attachment_id', $attachment_id, true);
    }

    wp_update_post(['ID' => $conversation_id, 'post_modified' => current_time('mysql')]);
    $participants = hiraaj_marketplace_conversation_participants($conversation_id);
    $recipient_id = $participants[0] === $sender_id ? $participants[1] : $participants[0];
    $product_id = (int) get_post_meta($conversation_id, '_hiraaj_product_id', true);

    if (function_exists('hiraaj_send_notification_to_users')) {
        hiraaj_send_notification_to_users(
            [$recipient_id],
            '💬 رسالة جديدة',
            ($user ? $user->display_name : 'مستخدم') . ': ' . wp_trim_words($text, 12),
            [
                'type' => 'message',
                'id' => (string) $conversation_id,
                'conversation_id' => (string) $conversation_id,
                'product_id' => (string) $product_id,
            ]
        );
    }

    return new WP_REST_Response([
        'success' => true,
        'id' => (int) $message_id,
        'conversation_id' => $conversation_id,
    ], 201);
}

function hiraaj_marketplace_handle_message_attachment()
{
    if (empty($_FILES['attachment']) || empty($_FILES['attachment']['name'])) {
        return 0;
    }
    if (!empty($_FILES['attachment']['error'])) {
        return new WP_Error('attachment_upload_failed', 'Attachment upload failed', ['status' => 400]);
    }
    if ((int) $_FILES['attachment']['size'] > 15 * MB_IN_BYTES) {
        return new WP_Error('attachment_too_large', 'Attachment exceeds 15 MB', ['status' => 413]);
    }

    $allowed_mimes = [
        'jpg|jpeg|jpe' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'mp4|m4v' => 'video/mp4',
        'mov|qt' => 'video/quicktime',
        'pdf' => 'application/pdf',
    ];
    $checked = wp_check_filetype_and_ext(
        $_FILES['attachment']['tmp_name'],
        $_FILES['attachment']['name'],
        $allowed_mimes
    );
    if (empty($checked['type'])) {
        return new WP_Error('attachment_type_not_allowed', 'Attachment type is not allowed', ['status' => 415]);
    }

    require_once ABSPATH . 'wp-admin/includes/file.php';
    require_once ABSPATH . 'wp-admin/includes/media.php';
    require_once ABSPATH . 'wp-admin/includes/image.php';
    $attachment_id = media_handle_upload('attachment', 0, [], [
        'test_form' => false,
        'mimes' => $allowed_mimes,
    ]);
    if (is_wp_error($attachment_id)) {
        return $attachment_id;
    }
    update_post_meta($attachment_id, '_hiraaj_private_message_media', 'yes');
    return (int) $attachment_id;
}

function hiraaj_marketplace_prepare_message($message)
{
    $attachment_id = (int) get_comment_meta(
        $message->comment_ID,
        '_hiraaj_attachment_id',
        true
    );
    $offer_amount = get_comment_meta(
        $message->comment_ID,
        '_hiraaj_private_offer_amount',
        true
    );
    return [
        'id' => (int) $message->comment_ID,
        'sender_id' => (int) $message->user_id,
        'sender_name' => $message->comment_author,
        'message' => $message->comment_content,
        'created_at' => mysql_to_rfc3339($message->comment_date_gmt),
        'attachment_url' => $attachment_id ? wp_get_attachment_url($attachment_id) : '',
        'attachment_name' => $attachment_id ? get_the_title($attachment_id) : '',
        'attachment_mime' => $attachment_id ? get_post_mime_type($attachment_id) : '',
        'offer_amount' => $offer_amount === '' ? null : (float) $offer_amount,
        'offer_status' => sanitize_key(
            get_comment_meta($message->comment_ID, '_hiraaj_private_offer_status', true)
        ),
    ];
}

function hiraaj_marketplace_insert_system_message($conversation_id, $sender_id, $text)
{
    $user = get_userdata($sender_id);
    return wp_insert_comment([
        'comment_post_ID' => $conversation_id,
        'comment_content' => $text,
        'comment_type' => 'hiraaj_message',
        'comment_approved' => 1,
        'user_id' => $sender_id,
        'comment_author' => $user ? $user->display_name : '',
        'comment_author_email' => $user ? $user->user_email : '',
    ]);
}

function hiraaj_marketplace_close_private_offers_for_product($product_id)
{
    $conversations = get_posts([
        'post_type' => 'hiraaj_conversation',
        'post_status' => 'private',
        'numberposts' => -1,
        'fields' => 'ids',
        'meta_key' => '_hiraaj_product_id',
        'meta_value' => (int) $product_id,
    ]);
    foreach ($conversations as $conversation_id) {
        $offers = get_comments([
            'post_id' => $conversation_id,
            'type' => 'hiraaj_message',
            'status' => 'approve',
            'number' => 100,
        ]);
        foreach ($offers as $offer) {
            $status = sanitize_key(
                get_comment_meta($offer->comment_ID, '_hiraaj_private_offer_status', true)
            );
            if (in_array($status, ['pending', 'accepted'], true)) {
                update_comment_meta($offer->comment_ID, '_hiraaj_private_offer_status', 'superseded');
            }
        }
    }
}

function hiraaj_marketplace_send_private_offer(WP_REST_Request $request)
{
    $conversation_id = absint($request['conversation_id']);
    $vendor_id = get_current_user_id();
    if (!hiraaj_marketplace_can_access_conversation($conversation_id, $vendor_id)) {
        return new WP_Error('forbidden', 'You cannot access this conversation', ['status' => 403]);
    }
    [$buyer_id, $conversation_vendor_id] =
        hiraaj_marketplace_conversation_participants($conversation_id);
    if ($vendor_id !== $conversation_vendor_id && !current_user_can('manage_options')) {
        return new WP_Error('vendor_only', 'Only the vendor can send a private price offer', ['status' => 403]);
    }

    $params = $request->get_json_params();
    $amount = isset($params['amount']) ? (float) wc_format_decimal($params['amount']) : 0;
    if ($amount <= 0 || $amount > 999999999) {
        return new WP_Error('invalid_offer_amount', 'Enter a valid amount greater than zero', ['status' => 400]);
    }
    $product_id = (int) get_post_meta($conversation_id, '_hiraaj_product_id', true);
    $product = get_post($product_id);
    if (
        !$product
        || $product->post_type !== 'product'
        || $product->post_status !== 'publish'
        || (int) $product->post_author !== $conversation_vendor_id
    ) {
        return new WP_Error('invalid_offer_product', 'The conversation product is invalid', ['status' => 409]);
    }
    if (
        function_exists('hiraaj_product_has_completed_marketplace_sale')
        && hiraaj_product_has_completed_marketplace_sale($product_id)
    ) {
        return new WP_Error('sale_already_finalized', 'This product has already been sold', ['status' => 409]);
    }

    $previous = get_comments([
        'post_id' => $conversation_id,
        'type' => 'hiraaj_message',
        'status' => 'approve',
        'number' => 100,
    ]);
    foreach ($previous as $old_offer) {
        $old_status = sanitize_key(
            get_comment_meta($old_offer->comment_ID, '_hiraaj_private_offer_status', true)
        );
        if (in_array($old_status, ['pending', 'accepted'], true)) {
            update_comment_meta($old_offer->comment_ID, '_hiraaj_private_offer_status', 'superseded');
        }
    }

    $formatted = number_format($amount, 2, '.', '');
    $message_id = hiraaj_marketplace_insert_system_message(
        $conversation_id,
        $vendor_id,
        'عرض سعر خاص: ' . $formatted . ' ر.س'
    );
    if (!$message_id) {
        return new WP_Error('offer_failed', 'Could not create the private offer', ['status' => 500]);
    }
    add_comment_meta($message_id, '_hiraaj_private_offer_amount', $formatted, true);
    add_comment_meta($message_id, '_hiraaj_private_offer_status', 'pending', true);
    add_comment_meta($message_id, '_hiraaj_private_offer_product_id', $product_id, true);
    wp_update_post(['ID' => $conversation_id, 'post_modified' => current_time('mysql')]);

    if (function_exists('hiraaj_send_notification_to_users')) {
        hiraaj_send_notification_to_users(
            [$buyer_id],
            '🔒 عرض سعر خاص',
            get_the_title($product_id) . ': ' . $formatted . ' ر.س',
            [
                'type' => 'message',
                'id' => (string) $conversation_id,
                'conversation_id' => (string) $conversation_id,
                'product_id' => (string) $product_id,
            ]
        );
    }
    return new WP_REST_Response([
        'success' => true,
        'message' => hiraaj_marketplace_prepare_message(get_comment($message_id)),
    ], 201);
}

function hiraaj_marketplace_accept_private_offer(WP_REST_Request $request)
{
    $conversation_id = absint($request['conversation_id']);
    $message_id = absint($request['message_id']);
    $buyer_id = get_current_user_id();
    if (!hiraaj_marketplace_can_access_conversation($conversation_id, $buyer_id)) {
        return new WP_Error('forbidden', 'You cannot access this conversation', ['status' => 403]);
    }
    [$conversation_buyer_id, $vendor_id] =
        hiraaj_marketplace_conversation_participants($conversation_id);
    if ($buyer_id !== $conversation_buyer_id && !current_user_can('manage_options')) {
        return new WP_Error('buyer_only', 'Only the buyer can accept this private offer', ['status' => 403]);
    }

    $message = get_comment($message_id);
    $status = sanitize_key(get_comment_meta($message_id, '_hiraaj_private_offer_status', true));
    $amount = (float) get_comment_meta($message_id, '_hiraaj_private_offer_amount', true);
    $product_id = (int) get_comment_meta($message_id, '_hiraaj_private_offer_product_id', true);
    $accepted_by = (int) get_comment_meta(
        $message_id,
        '_hiraaj_private_offer_accepted_by',
        true
    );
    if (
        !$message
        || (int) $message->comment_post_ID !== $conversation_id
        || !in_array($status, ['pending', 'accepted'], true)
        || ($status === 'accepted' && $accepted_by !== $buyer_id)
        || $amount <= 0
        || $product_id !== (int) get_post_meta($conversation_id, '_hiraaj_product_id', true)
    ) {
        return new WP_Error('offer_unavailable', 'This private offer is no longer available', ['status' => 409]);
    }

    if ($status === 'pending') {
        if (
            function_exists('hiraaj_product_has_completed_marketplace_sale')
            && hiraaj_product_has_completed_marketplace_sale($product_id)
        ) {
            return new WP_Error('sale_already_finalized', 'This product has already been sold', ['status' => 409]);
        }
        update_comment_meta($message_id, '_hiraaj_private_offer_status', 'accepted');
        update_comment_meta($message_id, '_hiraaj_private_offer_accepted_by', $buyer_id);
        update_comment_meta($message_id, '_hiraaj_private_offer_accepted_at', current_time('mysql', true));
        hiraaj_marketplace_insert_system_message(
            $conversation_id,
            $buyer_id,
            'تم قبول عرض السعر الخاص والانتقال إلى الدفع'
        );
        wp_update_post(['ID' => $conversation_id, 'post_modified' => current_time('mysql')]);

        if (function_exists('hiraaj_send_notification_to_users')) {
            hiraaj_send_notification_to_users(
                [$vendor_id],
                '✅ تم قبول العرض الخاص',
                get_the_title($product_id) . ': ' . number_format($amount, 2, '.', '') . ' ر.س',
                [
                    'type' => 'message',
                    'id' => (string) $conversation_id,
                    'conversation_id' => (string) $conversation_id,
                    'product_id' => (string) $product_id,
                ]
            );
        }
    }

    return new WP_REST_Response([
        'success' => true,
        'conversation_id' => $conversation_id,
        'offer_message_id' => $message_id,
        'product_id' => $product_id,
        'amount' => $amount,
    ], 200);
}

add_filter(
    'woocommerce_rest_pre_insert_shop_order_object',
    'hiraaj_marketplace_validate_private_offer_order',
    10,
    3
);
function hiraaj_marketplace_validate_private_offer_order($order, $request, $creating)
{
    if (!$creating || !is_a($order, 'WC_Order')) {
        return $order;
    }
    foreach ($order->get_items() as $item) {
        $message_id = (int) $item->get_meta('_hiraaj_private_offer_message_id', true);
        if (!$message_id) {
            continue;
        }
        $conversation_id = (int) $item->get_meta('_hiraaj_private_conversation_id', true);
        $message = get_comment($message_id);
        $status = sanitize_key(get_comment_meta($message_id, '_hiraaj_private_offer_status', true));
        $amount = (float) get_comment_meta($message_id, '_hiraaj_private_offer_amount', true);
        $product_id = (int) get_comment_meta($message_id, '_hiraaj_private_offer_product_id', true);
        $buyer_id = (int) get_comment_meta($message_id, '_hiraaj_private_offer_accepted_by', true);
        if (
            !$message
            || (int) $message->comment_post_ID !== $conversation_id
            || $status !== 'accepted'
            || $buyer_id !== (int) $order->get_customer_id()
            || $product_id !== (int) $item->get_product_id()
            || (
                function_exists('hiraaj_product_has_completed_marketplace_sale')
                && hiraaj_product_has_completed_marketplace_sale($product_id)
            )
            || abs($amount - (float) $item->get_total()) > 0.01
        ) {
            return new WP_Error(
                'invalid_private_offer',
                'The private offer is invalid or has already been used',
                ['status' => 409]
            );
        }
        $lock_key = '_hiraaj_private_offer_checkout_lock_' . $message_id;
        $locked_at = (int) get_option($lock_key, 0);
        if ($locked_at && $locked_at > time() - 300) {
            return new WP_Error('private_offer_in_use', 'An order is already being created for this offer', ['status' => 409]);
        }
        if ($locked_at) {
            delete_option($lock_key);
        }
        if (!add_option($lock_key, time(), '', false)) {
            return new WP_Error('private_offer_in_use', 'An order is already being created for this offer', ['status' => 409]);
        }
        $product_lock_key = '_hiraaj_product_checkout_lock_' . $product_id;
        $product_locked_at = (int) get_option($product_lock_key, 0);
        if ($product_locked_at && $product_locked_at <= time() - 300) {
            delete_option($product_lock_key);
        }
        if (!add_option($product_lock_key, time(), '', false)) {
            delete_option($lock_key);
            return new WP_Error(
                'product_checkout_in_use',
                'Another accepted offer for this product is being checked out',
                ['status' => 409]
            );
        }
    }
    return $order;
}

add_action(
    'woocommerce_rest_insert_shop_order_object',
    'hiraaj_marketplace_mark_private_offer_order_created',
    10,
    3
);
function hiraaj_marketplace_mark_private_offer_order_created($order, $request, $creating)
{
    if (!$creating || !is_a($order, 'WC_Order')) {
        return;
    }
    foreach ($order->get_items() as $item) {
        $message_id = (int) $item->get_meta('_hiraaj_private_offer_message_id', true);
        if (!$message_id) {
            continue;
        }
        update_comment_meta($message_id, '_hiraaj_private_offer_status', 'purchased');
        update_comment_meta($message_id, '_hiraaj_private_offer_order_id', $order->get_id());
        update_post_meta($item->get_product_id(), '_hiraaj_final_sale_type', 'private');
        update_post_meta($item->get_product_id(), '_hiraaj_final_sale_id', $message_id);
        if (function_exists('hiraaj_marketplace_supersede_public_bids')) {
            hiraaj_marketplace_supersede_public_bids($item->get_product_id());
        } else {
            $public_bids = get_comments([
                'post_id' => $item->get_product_id(),
                'type' => 'product_question',
                'parent' => 0,
                'status' => 'approve',
                'number' => 200,
            ]);
            foreach ($public_bids as $public_bid) {
                $bid_status = sanitize_key(
                    get_comment_meta($public_bid->comment_ID, '_hiraaj_bid_status', true)
                );
                if (in_array($bid_status, ['pending', 'accepted'], true)) {
                    update_comment_meta($public_bid->comment_ID, '_hiraaj_bid_status', 'superseded');
                }
            }
        }
        delete_option('_hiraaj_private_offer_checkout_lock_' . $message_id);
        delete_option('_hiraaj_product_checkout_lock_' . (int) $item->get_product_id());
    }
}

// Products without a price are requests for negotiation, not failed Telr
// payments. Keep those orders on hold and notify both parties normally.
add_action('woocommerce_checkout_order_created', 'hiraaj_marketplace_handle_zero_total_order', 5, 1);
function hiraaj_marketplace_handle_zero_total_order($order)
{
    if (!is_a($order, 'WC_Order') || (float) $order->get_total() > 0) {
        return;
    }
    $order->set_payment_method('price_on_request');
    $order->set_payment_method_title('السعر عند التواصل مع البائع');
    $order->update_meta_data('_price_on_request', 'yes');
    if (!$order->has_status('on-hold')) {
        $order->set_status('on-hold', 'Order has no listed price; vendor must contact buyer.');
    }
    $order->save();
}
