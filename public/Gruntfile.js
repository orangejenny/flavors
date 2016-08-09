// Run "grunt watch" from public/ directory
module.exports = function(grunt) {
	grunt.initConfig({
		// running `grunt less` will compile once
		less: {
			development: {
				options: {
					paths: ["./css"],
					yuicompress: true
				},
			files: {
				"./css/flavors.css": "./css/flavors.less",

				"./css/base.css": "./css/base.less",
				"./css/collections.css": "./css/collections.less",
				"./css/data.css": "./css/data.less",
				"./css/facet.css": "./css/facet.less",
				"./css/filters.css": "./css/filters.less",
				"./css/matrix.css": "./css/matrix.less",
				"./css/network.css": "./css/network.less",
				"./css/songs.css": "./css/songs.less",
			}
		}
	},
	watch: {
		files: "./css/*.less",
		tasks: ["less"]
	}
});
	grunt.loadNpmTasks('grunt-contrib-less');
	grunt.loadNpmTasks('grunt-contrib-watch');
};
