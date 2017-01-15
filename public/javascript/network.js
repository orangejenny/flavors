// Modified from https://bl.ocks.org/mbostock/4062045
jQuery(document).ready(function() {
    jQuery(".category-select").change(draw);
    jQuery(".strength-select, .tag-select").keyup(_.debounce(draw, 500));
    jQuery(".strength-select .input-group-addon").click(function() {
        var $nudge = jQuery(this),
            $input = $nudge.siblings("input");
        $input.val(+$input.val() + +$nudge.data("increment")).change();
    });
    draw();
});

function dragStarted(d, simulation) {
    if (!d3.event.active) {
        simulation.alphaTarget(0.3).restart();
    }
    d.fx = d.x;
    d.fy = d.y;
}
    
function dragged(d, simulation) {
    d.fx = d3.event.x;
    d.fy = d3.event.y;
}
    
function dragEnded(d, simulation) {
    if (!d3.event.active) {
        simulation.alphaTarget(0);
    }
    d.fx = null;
    d.fy = null;
}

function ticked(link, node) {
    link.attr("x1", function(d) { return d.source.x; })
        .attr("y1", function(d) { return d.source.y; })
        .attr("x2", function(d) { return d.target.x; })
        .attr("y2", function(d) { return d.target.y; });
    node.attr("cx", function(d) { return d.x; })
        .attr("cy", function(d) { return d.y; });
}

function draw() {
    var condition = function(tags) {
        return _.map(_.uniq(_.compact(tags)), function(t) { return "taglist like '% " + t + " %'" }).join(" and ");
    };
    var filename = function(tags) {
        return _.map(_.uniq(_.compact(tags)), function(t) { return "[" + t + "]"; }).join("");
    };
    var selector = ".chart-container",
        svg = d3.select(selector + " svg"),
        width = +svg.attr("width"),
        height = +svg.attr("height");
    
    svg.html("");
    
    var simulation = d3.forceSimulation()
        .force("link", d3.forceLink().id(function(d) { return d.id; }))
        .force("charge", d3.forceManyBody())
        .force("center", d3.forceCenter(width / 2, height / 2));
    
    var category = jQuery(".category-select").val(),
        strength = jQuery(".strength-select input").val();
        tag = jQuery(".tag-select").val();
    CallRemote({
        SUB: 'Flavors::Data::Tag::NetworkStats',
        ARGS: {
            CATEGORY: category,
            FILTER: $("textarea[name='filter']").val(),
            STRENGTH: strength,
            TAG: tag,
        },
        SPINNER: ".chart-container",
        FINISH: function(data) {
            jQuery(".post-nav .label").text(data.nodes.length + Pluralize(data.nodes.length, " tag")
                                            + ", " + data.links.length + Pluralize(data.links.length, " link"));
            data.nodes = _.map(data.nodes, function(node) {
                return _.extend(node, {
                    count: +node.count,
                    description: node.id + "<br />" + node.count + " " + Pluralize(+node.count, "song"),
                    condition: condition([node.id, tag]),
                    filename: filename([node.id, tag]),
                });
            });

            data.links = _.map(data.links, function(link) {
                return _.extend(link, {
                    description: link.source + " and " + link.target + "<br />" + link.value + " " + Pluralize(link.value, "song"),
                    condition: condition([link.source, link.target, tag]),
                    filename: filename([link.source, link.target, tag]),
                });
            });

            var link = svg.append("g")
                          .attr("class", "links")
                          .selectAll("line")
                          .data(data.links)
                          .enter().append("line")
                                  .attr("stroke-width", function(d) { return Math.sqrt(d.value); });
        
            var count = function(n) { return n.count; },
                rScale = d3.scaleLinear()
                           .range([5, 15])
                           .domain([d3.min(data.nodes, count), d3.max(data.nodes, count)]);
            var node = svg.append("g")
                          .attr("class", "nodes")
                          .selectAll("circle")
                          .data(data.nodes)
                          .enter().append("circle")
                                  .attr("r", function(n) { return rScale(n.count); })
                                  .classed("tagged", function(d) { return d.id === tag; })
                                  .call(d3.drag()
                                          .on("start", function(d) { dragStarted(d, simulation); })
                                          .on("drag", function(d) { dragged(d, simulation); })
                                          .on("end", function(d) { dragEnded(d, simulation); }));
        
            simulation.nodes(data.nodes)
                      .on("tick", function() { ticked(link, node); });
            simulation.force("link").links(data.links);
        
            attachTooltip(selector + " g circle, " + selector + " g line");
            attachSelectionHandlers(selector + " g circle, " + selector + " g line");
        },
    });
}
