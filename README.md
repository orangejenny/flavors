This repository has been superseded by [Rhyme](https://github.com/orangejenny/dj-orange/#rhyme)

# Flavors

Flavors is a web app to manage a user's music collection and generate highly individualized playlists, combining standard metadata with a user's individual ratings and tagging.

## Songs

Flavors stores basic metadata; user-specific ratings for quality, mood, and energy; and user-specific tags.

![screenshot of song list](https://github.com/orangejenny/flavors/blob/master/readme/songs.png?raw=true)

## Collections

Songs are grouped into collections - albums and/or mixes. Some usage data is tracked per collection.

![screenshot of track list for collection](https://github.com/orangejenny/flavors/blob/master/readme/collections.png?raw=true)

![screenshot of track list for collection](https://github.com/orangejenny/flavors/blob/master/readme/collections_song_list.png?raw=true)

## Filtering and Playlists

Songs can be filtered by simple attributes or by complex query.

![screenshot of complex filtering](https://github.com/orangejenny/flavors/blob/master/readme/complex_filter.png?raw=true)

Any filtered set of songs can then be exported into a playlist, an M3U file based on local filenames. Different devices with different file hierarchies can be configured.

![screenshot of export actions](https://github.com/orangejenny/flavors/blob/master/readme/export.png?raw=true)

## Tags

The user can browse tags and related tags.

![screenshot of tags display](https://github.com/orangejenny/flavors/blob/master/readme/tags.png?raw=true)

![screenshot of related tags dialog](https://github.com/orangejenny/flavors/blob/master/readme/tags_related.png?raw=true)

Tags can be grouped into categories that enable higher-level querying and certain visualizations.

![screenshot of tag categorizing workflow](https://github.com/orangejenny/flavors/blob/master/readme/tag_categories.png?raw=true)

## Visualizations

Visualizations allow exploration of data and the generation of novel playlists.

### Network: interactive exploration of tags that appear together

![animated screenshot of network visualization](https://github.com/orangejenny/flavors/blob/master/readme/network.gif?raw=true)

### Matrix: combining mood and energy

![screenshot of matrix visualization](https://github.com/orangejenny/flavors/blob/master/readme/matrix.png?raw=true)

### Ratings: quality, mood, and energy, at a high level and broken down by tag category

![screenshot of mood visualization broken down by year tags](https://github.com/orangejenny/flavors/blob/master/readme/facet_mood_years.png?raw=true)

### Time-Based

Collections by date acquired

![screenshot of acquisitions visualization](https://github.com/orangejenny/flavors/blob/master/readme/acquisitions.png?raw=true)

Songs by year and season tagged

![screenshot of timeline visualization](https://github.com/orangejenny/flavors/blob/master/readme/timeline.png?raw=true)
