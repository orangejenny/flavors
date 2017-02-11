jQuery(document).ready(function() {
    jQuery(".white-text button").click(function() {
        var $button = jQuery(this);
        UpdateColor(this, { WHITETEXT: $button.val() });
        $button.siblings("button").removeClass("active");
        $button.addClass("active");
    });

    jQuery(".minicolors-input").minicolors({
        control: 'wheel',
        position: 'bottom left',
        theme: 'bootstrap',
    });

    jQuery(".minicolors-input").change(function() {
        UpdateColor(this, { HEX: jQuery(this).val().replace("#", "") });
    });
});

function UpdateColor(obj, args) {
    var $color = jQuery(obj).closest(".color");
    var $input = $color.find("input:first");
    args.NAME = $color.children(".name").text();
    $color.addClass("update-in-progress");
    CallRemote({
        SUB: 'Flavors::Data::Tag::UpdateColor',
        ARGS: args,
        FINISH: function() {
            $color.removeClass("update-in-progress");
        }
    });
}
