function Chart(selector, width, height) {
	var self = this;
	self.selector = selector;
	self.svg = d3.select(self.selector + " svg");
}

Chart.prototype.attachEvents = function() {
	var self = this;
	attachSelectionHandlers(self.selector + " g");
	attachTooltip(self.selector + " g:not(.axis)");
};

Chart.prototype.draw = function(data) {
	var self = this;
	self.data = self.formatData(data);
    document.querySelector(self.selector + " svg").innerHTML = "";
	self.drawData();
	self.drawAxes();
	self.attachEvents();
};

Chart.prototype.formatData = function(data) {
	return data;
}

Chart.prototype.setDimensions = function(width, height) {
	var self = this;
	self.width = width;
	self.height = height;
	self.svg.attr("width", self.width)
			  .attr("height", self.height);
};
