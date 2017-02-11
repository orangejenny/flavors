jQuery(document).ready(function() {
    jQuery(".playlists a").click(function() {
        var $link = jQuery(this);
        var $form = jQuery("#complex-filter form");
        $form.find("textarea").val($link.text());
        $form.submit();
    });
});
