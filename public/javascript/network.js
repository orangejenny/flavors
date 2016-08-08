// Modified from https://bl.ocks.org/mbostock/4062045
jQuery(document).ready(function() {
    var selector = ".chart-container",
        svg = d3.select(selector + " svg"),
        width = +svg.attr("width"),
        height = +svg.attr("height");
    
    var color = d3.scaleOrdinal(d3.schemeCategory20);
    
    var simulation = d3.forceSimulation()
        .force("link", d3.forceLink().id(function(d) { return d.id; }))
        .force("charge", d3.forceManyBody())
        .force("center", d3.forceCenter(width / 2, height / 2));
    
    CallRemote({
        SUB: 'Flavors::Data::Tag::NetworkStats',
        ARGS: {
            STRENGTH: 1,
            CATEGORY: "people",
        },
        SPINNER: ".chart-container",
        FINISH: function(data) {
            console.log("# nodes: " + data.nodes.length);
            data.nodes = _.map(data.nodes, function(node) {
                return _.extend(node, {
                    count: +node.count,
                    description: node.id + "<br />" + node.count + " " + Pluralize(+node.count, "song"),
                });
            });

            console.log("# links: " + data.links.length);
            data.links = _.map(data.links, function(link) {
                return _.extend(link, {
                    description: link.source + " and " + link.target + "<br />" + link.value + " " + Pluralize(link.value, "song"),
                });
            });

            var link = svg.append("g")
                          .attr("class", "links")
                          .selectAll("line")
                          .data(data.links)
                          .enter().append("line")
                                  .attr("stroke-width", function(d) { return Math.sqrt(d.value); });
        
            var node = svg.append("g")
                          .attr("class", "nodes")
                          .selectAll("circle")
                          .data(data.nodes)
                          .enter().append("circle")
                                  .attr("r", 5)
                                  .attr("fill", function(d) { return color(d.group); })
                                  .call(d3.drag()
                                          .on("start", function(d) { dragStarted(d, simulation); })
                                          .on("drag", function(d) { dragged(d, simulation); })
                                          .on("end", function(d) { dragEnded(d, simulation); }));
        
            simulation.nodes(data.nodes)
                      .on("tick", function() { ticked(link, node); });
            simulation.force("link").links(data.links);
        
            attachTooltip(selector + " g circle, " + selector + " g line");
        },
    });
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
