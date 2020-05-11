<?php
/**
 * Plugin Name: Widget Population
 */

namespace Widget_Population;

use WP_Widget;
use WP_Widget_Factory;

if ( defined( 'WP_CLI' ) ) {
	\WP_CLI::add_command(
		'populate-initial-widgets',
		function () {
			/**
			 * @var WP_Widget_Factory $wp_widget_factory
			 */
			global $wp_widget_factory;
			foreach ( $wp_widget_factory->widgets as $widget ) {
				/**
				 * @var WP_Widget $widget
				 */
				ensure_first_widget_setting_populated( $widget );
				\WP_CLI::line( $widget->id_base );
			}
		}
	);
}

/**
 * Populate initial widgets.
 *
 * @param WP_Widget $widget
 */
function ensure_first_widget_setting_populated( WP_Widget $widget ) {
	$settings = $widget->get_settings();

	if ( isset( $settings[2] ) && ! empty( $settings[2]['title'] ) ) {
		return;
	}

	switch ( $widget->id_base ) {
		case 'calendar':
			$settings[2] = [ 'title' => 'Calendar' ];
			break;
		case 'rss':
			$settings[2] = [
				'title' => 'RSS',
				'url'   => get_feed_link(),
			];
			break;
		case 'nav_menu':
			$menu = wp_get_nav_menu_object( 'Testing Menu' );
			if ( $menu ) {
				$settings[2] = [
					'title'    => 'Nav Menu Widget',
					'nav_menu' => $menu->term_id,
				];
			}
			break;
		case 'custom_html':
			$settings[2] = [
				'title'   => 'Custom HTML',
				'content' => '<p>Hello World!</p>'
			];
			break;
		case 'text':
			$page = get_page_by_title( 'Page Markup And Formatting', OBJECT, 'page' );
			if ( $page ) {
				$settings[2] = [
					'title'  => 'Text',
					'visual' => true,
					'filter' => true,
					'text'   => preg_replace_callback(
						'#<pre>(.+?)</pre>#s',
						function ( $matches ) {
							// Fixup ASCII art for sake of libxml.
							// TODO: The "Page Markup And Formatting" unit test data has this problem, as the ASCII art causes libxml to incorrectly parse the content.
							$fixed = $matches[1];
							$fixed = preg_replace( '#<(?!\w|/)#', '&lt;', $fixed );
							return sprintf( '<pre>%s</pre>', $fixed );
						},
						$page->post_content
					),
				];
			}
			break;
		case 'media_audio':
			$attachment = get_page_by_title( 'St. Louis Blues', OBJECT, 'attachment' );
			if ( $attachment ) {
				$settings[2] = [
					'attachment_id' => $attachment->ID,
					'title' => 'Audio',
				];
			}
			break;
		case 'media_image':
			$attachment = get_page_by_title( 'Golden Gate Bridge', OBJECT, 'attachment' );
			if ( $attachment ) {
				$settings[2] = [
					'attachment_id' => $attachment->ID,
					'title' => 'Image',
					'size' => 'medium',
					'caption' => 'This is a caption!',
					'link_type' => 'post',
				];
			}
			break;
		case 'media_gallery':
			$attachments = get_posts(
				[
					'post_type'      => 'attachment',
					'fields'         => 'ids',
					'numberposts'    => 3,
					'post_mime_type' => 'image'
				]
			);
			if ( ! empty( $attachments ) ) {
				$settings[2] = [
					'title' => 'Gallery',
					'ids'   => $attachments,
				];
			}
			break;
		case 'media_video':
			$attachment = get_page_by_title( 'Accelerated Mobile Pages is now just AMP', OBJECT, 'attachment' );
			if ( $attachment ) {
				$settings[2] = [
					'title'         => 'Video',
					'attachment_id' => $attachment->ID,
				];
			}
			break;
	}

	$widget->save_settings( $settings );
}
