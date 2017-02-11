jQuery(document).ready(function() {
    var selector = ".chart-container",
        $simpleFilter = $("#simple-filter");

    initSimpleFilter(function() {
        CallRemote({
            SUB: 'Flavors::Data::Util::TrySQL',
            ARGS: {
                INNERSUB: 'Flavors::Data::Tag::List',
                FILTER: $("textarea[name='filter']").val(),
                SIMPLEFILTER: $simpleFilter.find("input[type='text']").val(),
                STARRED: $simpleFilter.find(".glyphicon-star").length,
                UPDATEPLAYLIST: 1,
            },
            SPINNER: selector,
            FINISH: function(data) {
                handleComplexError(data, function(tags) {
                    var $list = $(".tags"),
                        tagTemplate = _.template("<div class='tag' category='<%= CATEGORY %>'>"
                                                + "<%= TAG %>"
                                                + "<span class='tag-count'><%= COUNT %></span>"
                                                + "</div>");
                    $list.html("");
                    _.each(tags, function(tag) {
                        $list.append(tagTemplate(tag));
                    });
                });
            },
        });
    });

    jQuery(document).on('click', '.tag', function() {
        var tag = jQuery(this).text();
        tag = tag.replace(/\s*\(.*/, "");
        var $modal = jQuery("#item-detail");
        $modal.data("tag", tag);
        $modal.find('.modal-header h4 .modal-title').html(tag);
        $modal.modal();
        CallRemote({
            SUB: 'Flavors::Data::Tag::List', 
            ARGS: { RELATED: tag }, 
            SPINNER: ".modal-body .tags",
            FINISH: function(data) {
                $modal.find('.modal-body ul').html(_.map(data, function(d) {
                    return "<li class='tag'>" + d.TAG + " <span class='tag-count'>(" + d.COUNT + ")</span></li>";
                }).join(""));
            }
        });
    });

    jQuery(".export-dropdown a").click(function() {
        var tag = jQuery("#item-detail").data("tag");
        ExportPlaylist({
            PATH: jQuery(this).text(),
            FILENAME: tag,
            FILTER: "taglist like concat('% ', '" + tag + "', ' %')",
        });
    });
});
