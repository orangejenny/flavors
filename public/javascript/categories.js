jQuery(document).ready(function() {
    jQuery('.tag').css("cursor", "move").draggable();

    jQuery('.category .header').click(function() {
        jQuery(this).closest(".category").addClass("enlarged");
    });

    jQuery('.category').droppable({
        drop: function(event, ui) {
            var $container = jQuery('.category-tags', this);
            jQuery(ui.draggable).remove().css('position', 'static').appendTo($container);
            var args = {
                VALUE: ui.draggable.text(),
                CATEGORY: jQuery(this).attr("category")
            };

            args.TABLE = jQuery(this).closest(".category").data("table");
            if (args.TABLE === "flavors_tagcategory") {
                args.VALUECOLUMN = "tag";
                args.CATEGORYCOLUMN = "category";
            }
            else if (args.TABLE === "flavors_artistgenre") {
                args.VALUECOLUMN = "artist";
                args.CATEGORYCOLUMN = "genre";
            }
            else {
                alert("Confused, this is neither a tag nor an artist");
                return;
            }
            CallRemote({
                SUB: 'Flavors::Data::Tag::UpdateCategory',
                ARGS: args,
            });
        }
    });
});
