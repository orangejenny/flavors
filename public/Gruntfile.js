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
				"./css/songs.css": "./css/songs.less",
				"./css/collections.css": "./css/collections.less",
				"./css/tags.css": "./css/tags.less",
				"./css/categories.css": "./css/categories.less",
				"./css/lab.css": "./css/lab.less"
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
