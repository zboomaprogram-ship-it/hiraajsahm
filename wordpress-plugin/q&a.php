<?php


/* ===========================================================================
 * PART 1: REST API FOR FLUTTER APP (Must include this for App to work)
 * =========================================================================== */
add_action('rest_api_init', function () {
    // 1. Ask a Question
    register_rest_route('custom/v1', '/qa/ask', [
        'methods' => 'POST',
        'callback' => 'handle_qa_ask',
        'permission_callback' => 'is_user_logged_in',
    ]);
    // 2. Reply (Vendor)
    register_rest_route('custom/v1', '/qa/reply', [
        'methods' => 'POST',
        'callback' => 'handle_qa_reply',
        'permission_callback' => 'is_user_logged_in',
    ]);
    // 3. Get Product Q&A
    register_rest_route('custom/v1', '/qa/product', [
        'methods' => 'GET',
        'callback' => 'handle_get_product_qa',
        'permission_callback' => '__return_true',
    ]);
    // 4. Get Vendor Dashboard Q&A
    register_rest_route('custom/v1', '/qa/vendor', [
        'methods' => 'GET',
        'callback' => 'handle_get_vendor_qa',
        'permission_callback' => 'is_user_logged_in',
    ]);
    register_rest_route('custom/v1', '/product-reviews', [
        'methods' => 'GET',
        'callback' => 'get_public_product_reviews',
        'permission_callback' => '__return_true', // Completely Public
    ]);
});


// --- API Callback Functions ---

function handle_qa_ask($request)
{
    $params = $request->get_json_params();
    $user_id = get_current_user_id();
    $product_id = absint($params['product_id'] ?? 0);
    $question = sanitize_textarea_field($params['question'] ?? '');
    $product = get_post($product_id);
    if (!$product || $product->post_type !== 'product' || $product->post_status !== 'publish') {
        return new WP_Error('product_not_found', 'Product not found', ['status' => 404]);
    }
    if ($question === '') {
        return new WP_Error('question_required', 'Question is required', ['status' => 400]);
    }
    $user = get_userdata($user_id);
    $comment_id = wp_insert_comment([
        'comment_post_ID' => $product_id,
        'comment_content' => $question,
        'user_id' => $user_id,
        'comment_author' => $user ? $user->display_name : '',
        'comment_author_email' => $user ? $user->user_email : '',
        'comment_type' => 'product_question',
        'comment_approved' => 1,
    ]);
    if (is_wp_error($comment_id))
        return $comment_id;
    return new WP_REST_Response(['success' => true, 'id' => $comment_id], 200);
}

function handle_qa_reply($request)
{
    $params = $request->get_json_params();
    $user_id = get_current_user_id();
    $question = get_comment(absint($params['question_id'] ?? 0));
    if (!$question || $question->comment_type !== 'product_question') {
        return new WP_Error('question_not_found', 'Question not found', ['status' => 404]);
    }
    $product = get_post($question->comment_post_ID);
    if (!$product || $product->post_type !== 'product' || $product->post_status !== 'publish') {
        return new WP_Error('product_not_found', 'Product not found', ['status' => 404]);
    }
    if ((int) $product->post_author !== (int) $user_id && !current_user_can('manage_options')) {
        return new WP_Error('forbidden', 'Not your product', ['status' => 403]);
    }
    $answer = sanitize_textarea_field($params['answer'] ?? '');
    if ($answer === '') {
        return new WP_Error('answer_required', 'Answer is required', ['status' => 400]);
    }
    $user = get_userdata($user_id);
    $comment_id = wp_insert_comment([
        'comment_post_ID' => $question->comment_post_ID,
        'comment_content' => $answer,
        'user_id' => $user_id,
        'comment_author' => $user ? $user->display_name : '',
        'comment_author_email' => $user ? $user->user_email : '',
        'comment_parent' => $question->comment_ID,
        'comment_type' => 'product_question',
        'comment_approved' => 1,
    ]);
    return new WP_REST_Response(['success' => true, 'id' => $comment_id], 200);
}

function handle_get_product_qa($request)
{
    $product_id = absint($request->get_param('product_id'));
    $comments = get_comments(['post_id' => $product_id, 'type' => 'product_question', 'parent' => 0, 'status' => 'approve']);
    $data = [];
    foreach ($comments as $comment) {
        $replies = get_comments([
            'parent' => $comment->comment_ID,
            'type' => 'product_question',
            'status' => 'approve',
            'order' => 'ASC',
            'number' => 1,
        ]);
        $data[] = [
            'id' => $comment->comment_ID,
            'author_id' => (int) $comment->user_id,
            'author' => $comment->comment_author,
            'question' => $comment->comment_content,
            'date' => $comment->comment_date,
            'answer' => !empty($replies) ? $replies[0]->comment_content : null,
            'answer_date' => !empty($replies) ? $replies[0]->comment_date : null,
            'is_answered' => !empty($replies),
            'bid_amount' => ($amount = get_comment_meta(
                $comment->comment_ID,
                '_hiraaj_bid_amount',
                true
            )) === '' ? null : (float) $amount,
            'bid_status' => sanitize_key(get_comment_meta(
                $comment->comment_ID,
                '_hiraaj_bid_status',
                true
            )),
        ];
    }
    return $data;
}

function hiraaj_qa_get_highest_pending_bid($product_id)
{
    $bids = get_comments([
        'post_id' => $product_id,
        'type' => 'product_question',
        'parent' => 0,
        'status' => 'approve',
        'meta_key' => '_hiraaj_bid_status',
        'meta_value' => 'pending',
        'number' => 200,
    ]);
    $highest = null;
    foreach ($bids as $bid) {
        $amount = (float) get_comment_meta($bid->comment_ID, '_hiraaj_bid_amount', true);
        if ($amount > 0 && (!$highest || $amount > $highest['amount'])) {
            $highest = ['comment' => $bid, 'amount' => $amount];
        }
    }
    return $highest;
}

/**
 * A product is sold only after an order has been created. Older versions wrote
 * the final-sale metadata as soon as an offer was accepted, which made an
 * abandoned checkout permanently close both the public and private auctions.
 */
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

function handle_qa_place_bid(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    $user_id = get_current_user_id();
    $product_id = absint($params['product_id'] ?? 0);
    $amount = isset($params['amount']) ? (float) wc_format_decimal($params['amount']) : 0;
    $note = sanitize_textarea_field($params['note'] ?? '');
    $product = get_post($product_id);
    if (!$product || $product->post_type !== 'product' || $product->post_status !== 'publish') {
        return new WP_Error('product_not_found', 'Product not found', ['status' => 404]);
    }
    if ((int) $product->post_author === $user_id) {
        return new WP_Error('cannot_bid_own_product', 'You cannot bid on your own product', ['status' => 403]);
    }
    if ($amount <= 0 || $amount > 999999999) {
        return new WP_Error('invalid_bid_amount', 'Enter a valid bid greater than zero', ['status' => 400]);
    }
    $accepted_bid_id = (int) get_post_meta($product_id, '_hiraaj_accepted_bid_id', true);
    $accepted_bid_status = $accepted_bid_id
        ? sanitize_key(get_comment_meta($accepted_bid_id, '_hiraaj_bid_status', true))
        : '';
    if (
        hiraaj_product_has_completed_marketplace_sale($product_id)
        || $accepted_bid_status === 'accepted'
    ) {
        return new WP_Error('auction_closed', 'This product has already been sold', ['status' => 409]);
    }

    $highest = hiraaj_qa_get_highest_pending_bid($product_id);
    if ($highest && $amount <= (float) $highest['amount']) {
        return new WP_Error(
            'bid_too_low',
            'Your bid must be higher than the current highest bid',
            ['status' => 409, 'highest_bid' => (float) $highest['amount']]
        );
    }

    $previous = get_comments([
        'post_id' => $product_id,
        'type' => 'product_question',
        'parent' => 0,
        'user_id' => $user_id,
        'status' => 'approve',
        'meta_key' => '_hiraaj_bid_status',
        'meta_value' => 'pending',
        'number' => 100,
    ]);
    foreach ($previous as $old_bid) {
        update_comment_meta($old_bid->comment_ID, '_hiraaj_bid_status', 'superseded');
    }

    $formatted = number_format($amount, 2, '.', '');
    $user = get_userdata($user_id);
    $content = 'مزايدة: ' . $formatted . ' ر.س';
    if ($note !== '') {
        $content .= "\n" . $note;
    }
    // The bid has its own richer notification below. Suppress the generic
    // product-question hook while WordPress fires comment_post synchronously.
    $GLOBALS['hiraaj_inserting_public_bid'] = true;
    $comment_id = wp_insert_comment([
        'comment_post_ID' => $product_id,
        'comment_content' => $content,
        'user_id' => $user_id,
        'comment_author' => $user ? $user->display_name : '',
        'comment_author_email' => $user ? $user->user_email : '',
        'comment_type' => 'product_question',
        'comment_approved' => 1,
    ]);
    unset($GLOBALS['hiraaj_inserting_public_bid']);
    if (!$comment_id) {
        return new WP_Error('bid_failed', 'Could not add the bid', ['status' => 500]);
    }
    add_comment_meta($comment_id, '_hiraaj_bid_amount', $formatted, true);
    add_comment_meta($comment_id, '_hiraaj_bid_status', 'pending', true);

    if (function_exists('hiraaj_send_notification_to_users')) {
        hiraaj_send_notification_to_users(
            [(int) $product->post_author],
            '🔨 مزايدة جديدة',
            get_the_title($product_id) . ': ' . $formatted . ' ر.س',
            [
                'type' => 'product',
                'id' => (string) $product_id,
                'product_id' => (string) $product_id,
            ]
        );
    }
    return new WP_REST_Response([
        'success' => true,
        'id' => (int) $comment_id,
        'amount' => (float) $amount,
    ], 201);
}

function handle_qa_accept_bid(WP_REST_Request $request)
{
    $bid_id = absint($request['bid_id']);
    $vendor_id = get_current_user_id();
    $bid = get_comment($bid_id);
    if (!$bid || $bid->comment_type !== 'product_question') {
        return new WP_Error('bid_not_found', 'Bid not found', ['status' => 404]);
    }
    $product = get_post($bid->comment_post_ID);
    if (!$product || $product->post_type !== 'product') {
        return new WP_Error('product_not_found', 'Product not found', ['status' => 404]);
    }
    if ((int) $product->post_author !== $vendor_id && !current_user_can('manage_options')) {
        return new WP_Error('vendor_only', 'Only the product vendor can accept a bid', ['status' => 403]);
    }
    if (hiraaj_product_has_completed_marketplace_sale($product->ID)) {
        return new WP_Error('sale_already_finalized', 'This product has already been sold', ['status' => 409]);
    }
    $status = sanitize_key(get_comment_meta($bid_id, '_hiraaj_bid_status', true));
    $amount = (float) get_comment_meta($bid_id, '_hiraaj_bid_amount', true);
    $highest = hiraaj_qa_get_highest_pending_bid($product->ID);
    if (
        $status !== 'pending'
        || $amount <= 0
        || !$highest
        || (int) $highest['comment']->comment_ID !== $bid_id
    ) {
        return new WP_Error('bid_not_highest', 'Only the current highest bid can be accepted', ['status' => 409]);
    }

    $pending_bids = get_comments([
        'post_id' => $product->ID,
        'type' => 'product_question',
        'parent' => 0,
        'status' => 'approve',
        'meta_key' => '_hiraaj_bid_status',
        'meta_value' => 'pending',
        'number' => 200,
    ]);
    foreach ($pending_bids as $pending_bid) {
        update_comment_meta(
            $pending_bid->comment_ID,
            '_hiraaj_bid_status',
            (int) $pending_bid->comment_ID === $bid_id ? 'accepted' : 'superseded'
        );
    }
    update_post_meta($product->ID, '_hiraaj_accepted_bid_id', $bid_id);
    update_post_meta($product->ID, '_hiraaj_accepted_bid_amount', $amount);
    update_post_meta($product->ID, '_hiraaj_accepted_bid_buyer_id', (int) $bid->user_id);
    if (function_exists('hiraaj_send_notification_to_users')) {
        hiraaj_send_notification_to_users(
            [(int) $bid->user_id],
            '✅ تم قبول مزايدتك',
            get_the_title($product->ID) . ': ' . number_format($amount, 2, '.', '') . ' ر.س',
            [
                'type' => 'product',
                'id' => (string) $product->ID,
                'product_id' => (string) $product->ID,
            ]
        );
    }
    return new WP_REST_Response(['success' => true], 200);
}

function handle_qa_checkout_bid(WP_REST_Request $request)
{
    $bid_id = absint($request['bid_id']);
    $buyer_id = get_current_user_id();
    $bid = get_comment($bid_id);
    $amount = (float) get_comment_meta($bid_id, '_hiraaj_bid_amount', true);
    $status = sanitize_key(get_comment_meta($bid_id, '_hiraaj_bid_status', true));
    $product = $bid ? get_post($bid->comment_post_ID) : null;
    if (
        !$bid
        || !$product
        || $product->post_type !== 'product'
        || $product->post_status !== 'publish'
        || (int) $bid->user_id !== $buyer_id
        || !in_array($status, ['accepted'], true)
        || $amount <= 0
        || (int) get_post_meta($bid->comment_post_ID, '_hiraaj_accepted_bid_id', true) !== $bid_id
        || hiraaj_product_has_completed_marketplace_sale($bid->comment_post_ID)
    ) {
        return new WP_Error('bid_unavailable', 'This accepted bid is not available to this buyer', ['status' => 409]);
    }
    return new WP_REST_Response([
        'success' => true,
        'bid_id' => $bid_id,
        'product_id' => (int) $bid->comment_post_ID,
        'amount' => $amount,
    ], 200);
}

add_filter('woocommerce_rest_pre_insert_shop_order_object', 'hiraaj_validate_bid_order', 11, 3);
function hiraaj_validate_bid_order($order, $request, $creating)
{
    if (!$creating || !is_a($order, 'WC_Order')) {
        return $order;
    }
    foreach ($order->get_items() as $item) {
        $bid_id = (int) $item->get_meta('_hiraaj_bid_comment_id', true);
        if (!$bid_id) {
            continue;
        }
        $bid = get_comment($bid_id);
        $status = sanitize_key(get_comment_meta($bid_id, '_hiraaj_bid_status', true));
        $amount = (float) get_comment_meta($bid_id, '_hiraaj_bid_amount', true);
        if (
            !$bid
            || $status !== 'accepted'
            || (int) $bid->user_id !== (int) $order->get_customer_id()
            || (int) $bid->comment_post_ID !== (int) $item->get_product_id()
            || hiraaj_product_has_completed_marketplace_sale($bid->comment_post_ID)
            || abs($amount - (float) $item->get_total()) > 0.01
        ) {
            return new WP_Error(
                'invalid_auction_bid',
                'The accepted auction bid is invalid or has already been used',
                ['status' => 409]
            );
        }
        $lock_key = '_hiraaj_bid_checkout_lock_' . $bid_id;
        $locked_at = (int) get_option($lock_key, 0);
        if ($locked_at && $locked_at > time() - 300) {
            return new WP_Error(
                'auction_bid_in_use',
                'An order is already being created for this accepted bid',
                ['status' => 409]
            );
        }
        if ($locked_at) {
            delete_option($lock_key);
        }
        if (!add_option($lock_key, time(), '', false)) {
            return new WP_Error(
                'auction_bid_in_use',
                'An order is already being created for this accepted bid',
                ['status' => 409]
            );
        }
        $product_lock_key = '_hiraaj_product_checkout_lock_' . (int) $item->get_product_id();
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

add_action('woocommerce_rest_insert_shop_order_object', 'hiraaj_mark_bid_order_created', 11, 3);
function hiraaj_mark_bid_order_created($order, $request, $creating)
{
    if (!$creating || !is_a($order, 'WC_Order')) {
        return;
    }
    foreach ($order->get_items() as $item) {
        $bid_id = (int) $item->get_meta('_hiraaj_bid_comment_id', true);
        if (!$bid_id) {
            continue;
        }
        update_comment_meta($bid_id, '_hiraaj_bid_status', 'purchased');
        update_comment_meta($bid_id, '_hiraaj_bid_order_id', $order->get_id());
        update_post_meta($item->get_product_id(), '_hiraaj_final_sale_type', 'public');
        update_post_meta($item->get_product_id(), '_hiraaj_final_sale_id', $bid_id);
        if (function_exists('hiraaj_marketplace_close_private_offers_for_product')) {
            hiraaj_marketplace_close_private_offers_for_product($item->get_product_id());
        }
        delete_option('_hiraaj_bid_checkout_lock_' . $bid_id);
        delete_option('_hiraaj_product_checkout_lock_' . (int) $item->get_product_id());
    }
}

function handle_qa_my_bids(WP_REST_Request $request)
{
    $buyer_id = get_current_user_id();
    $comments = get_comments([
        'type' => 'product_question',
        'parent' => 0,
        'user_id' => $buyer_id,
        'status' => 'approve',
        'meta_key' => '_hiraaj_bid_amount',
        'number' => 500,
        'orderby' => 'comment_date_gmt',
        'order' => 'DESC',
    ]);
    $seen_products = [];
    $result = [];
    foreach ($comments as $bid) {
        $product_id = (int) $bid->comment_post_ID;
        if (isset($seen_products[$product_id])) {
            continue;
        }
        $seen_products[$product_id] = true;
        $product_post = get_post($product_id);
        $product = function_exists('wc_get_product') ? wc_get_product($product_id) : null;
        $status = sanitize_key(get_comment_meta($bid->comment_ID, '_hiraaj_bid_status', true));
        $amount = (float) get_comment_meta($bid->comment_ID, '_hiraaj_bid_amount', true);
        $image_id = $product ? $product->get_image_id() : 0;
        $available = $product_post
            && $product_post->post_type === 'product'
            && $product_post->post_status === 'publish'
            && !hiraaj_product_has_completed_marketplace_sale($product_id);
        $result[] = [
            'bid_id' => (int) $bid->comment_ID,
            'product_id' => $product_id,
            'product_name' => $product_post ? $product_post->post_title : 'إعلان غير متاح',
            'product_image' => $image_id ? (string) wp_get_attachment_image_url($image_id, 'woocommerce_thumbnail') : '',
            'vendor_id' => $product_post ? (int) $product_post->post_author : 0,
            'amount' => $amount,
            'status' => $status,
            'date' => mysql_to_rfc3339($bid->comment_date),
            'available' => (bool) $available,
            'can_checkout' => (bool) (
                $available
                && $status === 'accepted'
                && (int) get_post_meta($product_id, '_hiraaj_accepted_bid_id', true) === (int) $bid->comment_ID
            ),
        ];
    }
    return new WP_REST_Response($result, 200);
}

function handle_get_vendor_qa($request)
{
    $vendor_id = get_current_user_id();
    $products = get_posts(['author' => $vendor_id, 'post_type' => 'product', 'numberposts' => -1, 'fields' => 'ids']);
    if (empty($products))
        return [];

    $comments = get_comments(['post__in' => $products, 'type' => 'product_question', 'parent' => 0, 'status' => 'approve']);
    $data = [];
    foreach ($comments as $comment) {
        $replies = get_comments([
            'parent' => $comment->comment_ID,
            'type' => 'product_question',
            'status' => 'approve',
            'order' => 'ASC',
        ]);
        $data[] = [
            'id' => $comment->comment_ID,
            'product_name' => get_the_title($comment->comment_post_ID),
            'question' => $comment->comment_content,
            'date' => $comment->comment_date,
            'answer' => !empty($replies) ? $replies[0]->comment_content : null,
            'answer_date' => !empty($replies) ? $replies[0]->comment_date : null,
            'is_answered' => !empty($replies),
        ];
    }
    return $data;
}

/* ===========================================================================
 * PART 2: WEBSITE DISPLAY (Product Tab)
 * =========================================================================== */
add_filter('woocommerce_product_tabs', 'add_custom_qa_tab', 98);

function add_custom_qa_tab($tabs)
{
    $tabs['custom_qa'] = [
        'title' => 'التعليقات',
        'priority' => 30,
        'callback' => 'render_custom_qa_content'
    ];
    return $tabs;
}

function render_custom_qa_content()
{
    global $product;
    if (!$product)
        return;
    $comments = get_comments(['post_id' => $product->get_id(), 'type' => 'product_question', 'parent' => 0, 'status' => 'approve']);

    echo '<div class="custom-qa-container" style="padding:20px;">';
    echo '<h3 style="margin-bottom:20px;">تعليقات العملاء</h3>';

    if (empty($comments)) {
        echo '<p style="color:#666;">لا توجد تعليقات لهذا المنتج بعد.</p>';
    } else {
        echo '<ul style="list-style:none; padding:0;">';
        foreach ($comments as $comment) {
            echo '<li style="background:#f9f9f9; padding:15px; margin-bottom:15px; border-radius:8px; border:1px solid #eee;">';
            echo '<div style="font-weight:bold; color:#333;">' . get_comment_author($comment->comment_ID) . ':</div>';
            echo '<div style="margin:5px 0;">' . esc_html($comment->comment_content) . '</div>';
            echo '<small style="color:#999;">' . get_comment_date('', $comment->comment_ID) . '</small>';

            $replies = get_comments(['parent' => $comment->comment_ID, 'type' => 'product_question', 'status' => 'approve']);
            if ($replies) {
                foreach ($replies as $reply) {
                    echo '<div style="margin-top:15px; padding:12px; background:#e3f2fd; border-right: 4px solid #2196F3; border-radius:4px;">';
                    echo '<strong style="color:#0d47a1;">رد البائع:</strong> <br>' . esc_html($reply->comment_content) . '</div>';
                }
            }
            echo '</li>';
        }
        echo '</ul>';
    }
    echo '</div>';
}

/* ===========================================================================
 * PART 3: DOKAN DASHBOARD INTEGRATION
 * =========================================================================== */
add_action('init', function () {
    add_rewrite_endpoint('product-qa', EP_PAGES); });

add_filter('dokan_get_dashboard_nav', function ($urls) {
    $urls['product-qa'] = [
        'title' => 'تعليقات العملاء',
        'icon' => '<i class="fas fa-question-circle"></i>',
        'url' => dokan_get_navigation_url('product-qa'),
        'pos' => 55
    ];
    return $urls;
});

add_action('dokan_load_custom_template', function ($query_vars) {
    if (isset($query_vars['product-qa'])) {
        $vendor_id = get_current_user_id();
        $products = get_posts(['author' => $vendor_id, 'post_type' => 'product', 'fields' => 'ids', 'numberposts' => -1]);

        echo '<div class="dokan-dashboard-wrap"><header class="dokan-dashboard-header"><h1 class="entry-title">تعليقات العملاء الواردة</h1></header><div class="dokan-dashboard-content" style="background:#fff; padding:20px; border:1px solid #eee;">';

        if (empty($products)) {
            echo '<p>لا توجد منتجات.</p>';
        } else {
            $questions = get_comments(['post__in' => $products, 'type' => 'product_question', 'parent' => 0, 'status' => 'all']);
            if (empty($questions)) {
                echo '<div class="dokan-alert dokan-alert-info">لا توجد تعليقات جديدة.</div>';
            } else {
                echo '<table class="dokan-table dokan-table-striped"><thead><tr><th>المنتج</th><th>التعليق</th><th>الحالة</th><th>إجراء</th></tr></thead><tbody>';
                foreach ($questions as $q) {
                    $prod_link = get_permalink($q->comment_post_ID);
                    $prod_title = get_the_title($q->comment_post_ID);
                    $is_answered = get_comments(['parent' => $q->comment_ID, 'count' => true]);
                    $status = $is_answered ? '<span style="color:green; font-weight:bold;">تم الرد</span>' : '<span style="color:red; font-weight:bold;">انتظار</span>';
                    echo "<tr><td><a href='$prod_link'>$prod_title</a></td><td>" . wp_trim_words($q->comment_content, 10) . "</td><td>$status</td><td><a href='$prod_link' target='_blank' class='dokan-btn dokan-btn-sm dokan-btn-theme'>الذهاب للرد</a></td></tr>";
                }
                echo '</tbody></table>';
            }
        }
        echo '</div></div>';
    }
});






function get_public_product_reviews($request)
{
    $product_id = $request->get_param('product_id');

    $args = [
        'post_id' => $product_id,
        'status' => 'approve',
        'type' => 'review',
    ];

    $comments = get_comments($args);
    $reviews = [];

    foreach ($comments as $comment) {
        $reviews[] = [
            'id' => $comment->comment_ID,
            'review' => $comment->comment_content,
            'rating' => get_comment_meta($comment->comment_ID, 'rating', true),
            'reviewer' => $comment->comment_author,
            'date_created' => $comment->comment_date,
            'reviewer_avatar_urls' => ['96' => get_avatar_url($comment->comment_author_email)],
        ];
    }

    return new WP_REST_Response($reviews, 200);
}
