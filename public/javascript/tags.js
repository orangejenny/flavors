jQuery(document).ready(function() {
    var selector = ".chart-container",
        $simpleFilter = $("#simple-filter"),
        tagTemplate = _.template("<<%= ELEMENT %> class='tag' category='<%= CATEGORY %>'>"
                                 + "<span class='tag-text'><%= TAG %></span>"
                                 + "<span class='tag-count'><%= COUNT %></span>"
                                 + "</<%= ELEMENT %>>");

    initSimpleFilter(function() {
        CallRemote({
            SUB: 'Flavors::Data::Util::TrySQL',
            ARGS: {
                INNERSUB: 'Flavors::Data::Tag::List',
                FILTER: $("textarea[name='filter']").val(),
                SIMPLEFILTER: $simpleFilter.find("input[type='text']").val(),
                STARRED: $simpleFilter.find(".fas.fa-star").length,
                UPDATEPLAYLIST: 1,
            },
            SPINNER: selector,
            FINISH: function(data) {
                handleComplexError(data, function(tags) {
                    var $list = $(".tags");
                    $list.html("");
                    _.each(tags, function(tag) {
                        $list.append(tagTemplate(_.extend(tag, { ELEMENT: 'div' })));
                    });
                    updateCount(tags.length);   // from filters.js
                });
            },
        });
    });

    jQuery(document).on('click', '.tag', function() {
        var tag = jQuery(this).find(".tag-text").text();
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
                    return tagTemplate(_.extend(d, { ELEMENT: 'li' }));
                }).join(""));
            }
        });
    });

    jQuery(".export-dropdown a").click(function() {
        var tag = jQuery("#item-detail").data("tag");
        ExportPlaylist({
            CONFIG: jQuery(this).data("name"),
            FILENAME: tag,
            FILTER: "taglist like concat('% ', '" + tag + "', ' %')",
        });
    });
});
