jQuery(document).ready(function() {
    // Controls: clear anything selected
    jQuery(".clear-button").click(function() {
        d3.selectAll(".selected").classed("selected", false);
        setClearVisibility();
    });

    // Controls: open selection in songs.pl
    jQuery(".songs-button").click(function() {
        var condition = getSelectionCondition();
        if (condition) {
            showSongModal({
                TITLE: getSelectionFilename(),
                SUB: 'Flavors::Data::Song::List', 
                FILTER: augmentFilter(condition),
                SIMPLEFILTER: jQuery("#filter").val(),
                STARRED: jQuery("#simple-filter .fas.fa-star").length,
            });
        }
    });

    // Controls: export selections
    jQuery(".export-dropdown a").click(function() {
        var condition = getSelectionCondition();
        if (condition) {
            ExportPlaylist({
                CONFIG: jQuery(this).data("name"),
                FILTER: augmentFilter(condition),
                SIMPLEFILTER: jQuery("#filter").val(),
                STARRED: jQuery("#simple-filter .fas.fa-star").length,
            });
        }
    });

    jQuery("#song-list").on("hide hide.bs.modal", function() {
        d3.selectAll('.selected').classed("selected", false);
        setClearVisibility();
    });
});

function setClearVisibility() {
    if (jQuery(".selected").length) {
        jQuery(".selection-buttons").removeClass("hide");
    }
    else {
        jQuery(".selection-buttons").addClass("hide");
    }
}

function attachTooltip(selector) {
    var positionTooltip = function() {
        var $tooltip = jQuery("#tooltip");
        if (!$tooltip.is(":visible")) {
            return;
        }
        if (d3.event.pageX + 10 + $tooltip.width() > jQuery("body").width()) {
            $tooltip.css("left", d3.event.pageX - $tooltip.width() - 10);
        }
        else {
            $tooltip.css("left", d3.event.pageX + 10);
        }
        if (d3.event.pageY + $tooltip.height() > jQuery("body").height() - jQuery(".post-nav").scrollTop()) {
            $tooltip.css("top", d3.event.pageY - $tooltip.height());
        }
        else {
            $tooltip.css("top", d3.event.pageY);
        }
    };

    d3.selectAll(selector).on("mouseenter.tooltip", function() {
        var data = d3.select(this).data()[0];
        var $tooltip = jQuery("#tooltip");
        var show = false;

        $tooltip.html("");
        if (data.description) {
            show = true;
            var description = data.description;
            $tooltip.html(description);
        }

        if (show) {
            $tooltip.removeClass("hide");
            positionTooltip();
        }
    });
    d3.selectAll(selector).on("mouseleave.tooltip", function() {
        jQuery("#tooltip").addClass("hide");
    });
    d3.selectAll(selector).on("mousemove.tooltip", function() {
        positionTooltip();
    });
}

function attachSelectionHandlers(selector, actsOn) {
    if (!actsOn) {
        actsOn = function(obj) {
            return d3.select(obj);
        };
    }

    jQuery(selector).css("cursor", "pointer");
    highlightOnHover(selector, actsOn);
    selectOnClick(selector, actsOn);
    viewOnDoubleClick(selector, actsOn);
}

function highlightOnHover(selector, actsOn) {
    d3.selectAll(selector).on("mouseenter.highlight", function() {
        actsOn(this).classed("highlighted", true);
        actsOn(this).selectAll("rect, circle").classed("highlighted", true);
    });
    d3.selectAll(selector).on("mouseleave.highlight", function() {
        actsOn(this).classed("highlighted", false);
        actsOn(this).selectAll(".highlighted").classed("highlighted", false);
    });
}

function selectOnClick(selector, actsOn) {
    d3.selectAll(selector).on("click", function() {
        selectData(actsOn(this));
    });
}

function selectData(obj) {
    var isSelected = obj.classed("selected");
    obj.classed("selected", !isSelected);
    obj.selectAll("rect, circle").classed("selected", !isSelected);
    setClearVisibility();
}

function viewOnDoubleClick(selector, actsOn) {
    d3.selectAll(selector).on("dblclick", function(e) {
        var obj = actsOn(this),
            data = obj.data()[0];
        var condition = data.condition;
        if (condition) {
            showSongModal({
                TITLE: data.filename,
                SUB: 'Flavors::Data::Song::List', 
                FILTER: augmentFilter(condition),
                SIMPLEFILTER: jQuery("#filter").val(),
                STARRED: jQuery("#simple-filter .fas.fa-star").length,
            }, function() {
                selectData(obj);
            });
        }
        d3.event.preventDefault();
    });
}

function getSelectionFilename() {
    var filenames = _.uniq(_.pluck(d3.selectAll("svg .selected").data(), 'filename'));
    if (filenames.length === 1) {
        return filenames[0];
    }
    return "";
}

function getSelectionCondition() {
    var selected = d3.selectAll("svg .selected");
    if (!selected.data().length) {
        alert("Nothing selected");
        return '';
    }
    return _.map(_.uniq(_.pluck(selected.data(), 'condition')), function(c) { return "(" + c + ")"; }).join(" or ");
}; 
