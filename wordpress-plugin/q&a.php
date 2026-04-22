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
    $comment_id = wp_insert_comment([
        'comment_post_ID' => $params['product_id'],
        'comment_content' => sanitize_textarea_field($params['question']),
        'user_id' => $user_id,
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
    $question = get_comment($params['question_id']);
    $product = get_post($question->comment_post_ID);

    if ($product->post_author != $user_id && !current_user_can('manage_options')) {
        return new WP_Error('forbidden', 'Not your product', ['status' => 403]);
    }
    wp_insert_comment([
        'comment_post_ID' => $question->comment_post_ID,
        'comment_content' => sanitize_textarea_field($params['answer']),
        'user_id' => $user_id,
        'comment_parent' => $params['question_id'],
        'comment_type' => 'product_question',
        'comment_approved' => 1,
    ]);
    return new WP_REST_Response(['success' => true], 200);
}

function handle_get_product_qa($request)
{
    $product_id = $request->get_param('product_id');
    $comments = get_comments(['post_id' => $product_id, 'type' => 'product_question', 'parent' => 0, 'status' => 'approve']);
    $data = [];
    foreach ($comments as $comment) {
        $replies = get_comments(['parent' => $comment->comment_ID, 'type' => 'product_question', 'status' => 'approve']);
        $data[] = [
            'id' => $comment->comment_ID,
            'author' => $comment->comment_author,
            'question' => $comment->comment_content,
            'date' => $comment->comment_date,
            'answer' => !empty($replies) ? $replies[0]->comment_content : null,
            'answer_date' => !empty($replies) ? $replies[0]->comment_date : null,
        ];
    }
    return $data;
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
        $replies = get_comments(['parent' => $comment->comment_ID, 'count' => true]);
        $data[] = [
            'id' => $comment->comment_ID,
            'product_name' => get_the_title($comment->comment_post_ID),
            'question' => $comment->comment_content,
            'date' => $comment->comment_date,
            'is_answered' => $replies > 0,
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
        'title' => 'أسئلة وأجوبة',
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
    echo '<h3 style="margin-bottom:20px;">أسئلة العملاء</h3>';

    if (empty($comments)) {
        echo '<p style="color:#666;">لا توجد أسئلة لهذا المنتج بعد.</p>';
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
        'title' => 'أسئلة العملاء',
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

        echo '<div class="dokan-dashboard-wrap"><header class="dokan-dashboard-header"><h1 class="entry-title">أسئلة العملاء الواردة</h1></header><div class="dokan-dashboard-content" style="background:#fff; padding:20px; border:1px solid #eee;">';

        if (empty($products)) {
            echo '<p>لا توجد منتجات.</p>';
        } else {
            $questions = get_comments(['post__in' => $products, 'type' => 'product_question', 'parent' => 0, 'status' => 'all']);
            if (empty($questions)) {
                echo '<div class="dokan-alert dokan-alert-info">لا توجد أسئلة جديدة.</div>';
            } else {
                echo '<table class="dokan-table dokan-table-striped"><thead><tr><th>المنتج</th><th>السؤال</th><th>الحالة</th><th>إجراء</th></tr></thead><tbody>';
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