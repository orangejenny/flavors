jQuery(document).ready(function() {
	generateBubbleChart();
});

function generateBubbleChart() {
	CallRemote({
		SUB: 'FlavorsData::SongStats',
		ARGS: { GROUPBY: "rating, energy, mood" },
		FINISH: function(data) {
			console.log("got stuff");
		}
	});
}
