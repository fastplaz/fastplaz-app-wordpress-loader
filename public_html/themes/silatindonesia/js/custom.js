jQuery.noConflict()(function($){
	"use strict";
	$(document).ready(function() {

	$('a[data-rel]').each(function() {
		$(this).attr('rel', $(this).data('rel'));
	});		

		$("a[rel^='prettyPhoto']").prettyPhoto({
			animationSpeed: 'normal', 
			opacity: 0.80, 
			showTitle: true,
			deeplinking: false,
			theme:'light_square'
		});

		$('p:empty').remove();
		
		
		$('.sf-menu').css({'display':'block'});
		
		$('.comment-form-email, .comment-form-url, .comment-form-comment').before('<div class="clear"></div>');

	});
});

	
jQuery.noConflict()(function($){
	"use strict";
	$(document).ready(function() {
		$("<select />").appendTo(".navigation");
		$("<option />",{
			"selected":"selected",
			"value":"",
			"text":"Go to..."
		}).appendTo(".navigation select");
		$(".navigation li a").each(function() {
			var el = $(this);
			$("<option />",{
				"value":el.attr("href"),
				"text":el.text()
			}).appendTo(".navigation select");
		});
		$(".navigation select").change(function() {
			window.location = $(this).find("option:selected").val();
		});
	});
});


		
/***************************************************
			SuperFish Menu
***************************************************/	
jQuery.noConflict()(function(){
		"use strict";
		jQuery('ul.sf-menu').superfish({
			delay:400,
			autoArrows:false,
			dropShadows:false,
			animation:{height:'show'}
		});
});

/*jQuery.noConflict()(function($){
	"use strict";
	$(window).load(function(){
		var $window = $(window);
		window.prettyPrint() && prettyPrint();
	});
});*/