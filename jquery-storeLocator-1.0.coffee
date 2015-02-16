#!/usr/bin/env coffee
# -*- coding: utf-8 -*-

# region header

###
[Project page](https://thaibault.github.com/jQuery-storeLocator)

This plugin provides a google application interface based store locator.

Copyright Torben Sickert 16.12.2012

License
-------

This library written by Torben Sickert stand under a creative commons naming
3.0 unported license. see http://creativecommons.org/licenses/by/3.0/deed.de

Extending this module
---------------------

For conventions see require on https://github.com/thaibault/require

Author
------

t.sickert["~at~"]gmail.com (Torben Sickert)

Version
-------

1.0 stable
###

main = ($) ->

# endregion

# region plugins/classes

    class StoreLocator extends $.Tools.class
        ###
            A jQuery storelocator plugin.

            Expected store data format:

            {latitude: NUMBER, longitude: NUMBER, markerIconFileName: STRING}
        ###
        __name__: 'StoreLocator'
        initialize: (options={}) ->
            ###Entry point for object orientated jQuery plugin.###

    # region properties

            # Saves currently opened results dom node or null if no results
            # exists yet.
            this.resultsDomNode = null
            # Saves currently opened window instance.
            this.currentlyOpenWindow = null
            # Saves all seen locations to recognize duplicates.
            this.seenLocations = []
            # Saves all recognized markers.
            this.markers = []
            # Saves all plugin interface options.
            this._options =
                ###
                    URL to retrieve stores, list of stores or object describing
                    bounds to create random stores within. If a
                    "generateProperties" function is given it will be called to
                    retrieve additional properties for each store. The
                    specified store will be given to the function.
                ###
                stores: {
                    northEast: latitude: 85, longitude: 180
                    southWest: latitude: -85, longitude: -180
                    number: 100, generateProperties: (store) -> {}
                }
                # Additional static store properties which will be available to
                # each store.
                addtionalStoreProperties: {}
                # Path prefix to search for marker icons.
                iconPath: '/webAsset/image/storeLocator/'
                ###
                    Specifies a fallback marker icon (if no store specific icon
                    was set). If set to "null" google will place a fallback
                    icon.
                ###
                defaultMarkerIconFileName: null
                ###
                    If not provided we initialize the map with center in
                    current location determined by internet protocol address.
                ###
                startLocation: null
                # Fallback location if automatic detection fails.
                fallbackLocation: latitude: 51.124213, longitude: 10.147705
                ###
                    Current ip. If set to "null" ip will be determined
                    dynamically
                ###
                ip: null
                ipToLocation:
                    ###
                        IP to location determination application interface url.
                        {1} and {2} represents currently used protocol and
                        potentially given ip.
                    ###
                    applicationInterfaceURL: '{1}://freegeoip.net/json/{2}'
                    ###
                        Time to wait for ip resolve. If time is up initialize
                        on given fallback location.
                    ###
                    timeoutInMilliseconds: 5000
                # Initial view properties.
                map: zoom: 3
                # Delay before we show search input field.
                showInputAfterLoadedDelayInMilliseconds: 500
                # Transition to show search input field.
                inputFadeInOption: duration: 'fast'
                ###
                    Distance to move if stores are determined with same
                    latitude and longitude.
                ###
                distanceToMoveByDuplicatedEntries: 0.0001
                # Options passed to the marker cluster.
                markerCluster: gridSize: 100, maxZoom : 11
                ###
                    Specifies a zoom value wich will be adjusted after
                    successfully picked a search result. If set to "null" no
                    zoom change happens.
                ###
                successfulSearchZoom: 12
                infoWindow:
                    ###
                        Function or string returning or representing the info
                        box. If a function is given and a promise is returned
                        the info box will be filled with the given loading
                        content and updated with the resolved data. The
                        function becomes the corresponding marker as first
                        argument and the store locator instance as second
                        argument. If nothing is provided all available data
                        will be listed in a generic info window.
                    ###
                    content: null
                    ###
                        Additional move to bottom relative to the marker if an
                        info window has been opened.
                    ###
                    additionalMoveToBottomInPixel: 100
                    ###
                        Content to show in the info window during info window
                        load.
                    ###
                    loadingContent: 'loading...'
                # Function to call if map is fully initialized.
                onLoaded: $.noop
                # Triggers if a marker info window will be opened.
                onInfoWindowOpen: $.noop
                # Triggers if a marker info window has finished opening.
                onInfoWindowOpened: $.noop
                ###
                    If a number is given a generic search will be provided and
                    given number will be interpret as search result precision
                    tolerance to identify a marker as search result.
                    If an object is given it indicates what should be search
                    for. The object can hold four keys. "properties" to
                    specify which store data should contain given search text,
                    "maximumNumberOfResults" to limit the auto complete result,
                    "loadingContent" to display while the results are loading
                    and "content" to render the search results. "content" can
                    be a function or string returning or representing the
                    search results. If a function is given and a promise is
                    returned the info box will be filled with the given loading
                    content and updated with the resolved data. The function
                    becomes search results as first argument, a boolean
                    value as second argument indicating if the maximum number
                    of search results was reached and the store locator
                    instance as third argument. If nothing is provided all
                    available data will be listed in a generic info window.
                ###
                searchBox: 50

    # endregion

            # Merges given options with default options recursively.
            super options
            # Grab dom nodes
            this.$domNodes = this.grabDomNode this._options.domNode
            if this._options.startLocation?
                this.initializeMap()
            else
                this._options.startLocation = this._options.fallbackLocation
                $.ajax({
                    url: this.stringFormat(
                        this._options.ipToLocation.applicationInterfaceURL
                        document.location.protocol.substring(
                            0, document.location.protocol.length - 1
                        ), this._options.ip or ''
                    ),
                    timeout: this._options.ipToLocation.timeoutInMilliseconds
                    dataType: 'jsonp'
                }).done((currentLocation) =>
                    this._options.startLocation = currentLocation
                ).always =>
                    this.initializeMap()
            this.$domNode or this
        initializeMap: ->
            ###Initializes cluster, info windows and marker.###
            this._options.map.center = new window.google.maps.LatLng(
                this._options.startLocation.latitude
                this._options.startLocation.longitude)
            this.map = new window.google.maps.Map $('<div>').appendTo(
                this.$domNode
            )[0], this._options.map
            markerCluster = new window.MarkerClusterer(
                this.map, [], this._options.markerCluster)
            # Add a marker for each retrieved store.
            if $.isArray this._options.stores
                for store in this._options.stores
                    $.extend(
                        true, store, this._options.addtionalStoreProperties)
                    markerCluster.addMarker this.createMarker store
            else if $.type(this._options.stores) is 'string'
                $.getJSON this._options.stores, (stores) =>
                    for store in stores
                        $.extend(
                            true, store
                            this._options.addtionalStoreProperties)
                        markerCluster.addMarker this.createMarker store
            else
                southWest = new window.google.maps.LatLng(
                    this._options.stores.southWest.latitude
                    this._options.stores.southWest.longitude)
                northEast = new window.google.maps.LatLng(
                    this._options.stores.northEast.latitude
                    this._options.stores.northEast.longitude)
                for index in [0...this._options.stores.number]
                    store = $.extend {
                        latitude: southWest.lat() + (northEast.lat(
                        ) - southWest.lat()) * window.Math.random()
                        longitude: southWest.lng() + (northEast.lng(
                        ) - southWest.lng()) * window.Math.random()
                    }, this._options.addtionalStoreProperties
                    markerCluster.addMarker this.createMarker $.extend(
                        store, this._options.stores.generateProperties store)
            # Create the search box and link it to the UI element.
            searchInputDomNode = this.$domNode.find 'input'
            this.map.controls[window.google.maps.ControlPosition.TOP_LEFT]
            .push searchInputDomNode[0]
            if $.type(this._options.searchBox) is 'number'
                this.initializeGenericSearchBox searchInputDomNode
            else
                this._options.searchBox = $.extend {
                    maximumNumberOfResults: 50
                    loadingContent: this._options.infoWindow.loadingContent
                }, this._options.searchBox
                this.initializeDataSourceSearchBox searchInputDomNode
            this.fireEvent 'loaded'
            this
        initializeDataSourceSearchBox: (searchInputDomNode) ->
            ###
                Initializes a data source based search box to open and focus
                them matching marker.
            ###
            this.on searchInputDomNode, 'keyup', =>
                searchResults = []
                searchText = searchInputDomNode.val()
                limitReached = false
                for marker in this.markers
                    for key in this._options.searchBox.properties
                        if (
                            marker.data[key] or marker.data[key] is 0
                        ) and "#{marker.data[key]}".toLowerCase().indexOf(
                            searchText.toLowerCase()
                        ) isnt -1
                            if searchResults.length is this._options.searchBox
                            .maximumNumberOfResults
                                limitReached = true
                                break
                            do (marker) => marker.open = => this.openMarker(
                                null, this.openMarker, marker)
                            searchResults.push marker
                            break
                    break if limitReached
                this.closeSearchResults()
                cssProperties = {}
                for propertyName in [
                    'position', 'width', 'top', 'left', 'border'
                ]
                    cssProperties[propertyName] = searchInputDomNode.css(
                        propertyName)
                cssProperties.marginTop = searchInputDomNode.outerHeight true
                resultsDomNode = $('<div>').css cssProperties
                resultsRepresentation = this.makeSearchResults(
                    searchResults, limitReached)
                if $.type(resultsRepresentation) is 'string'
                    resultsDomNode.html resultsRepresentation
                else
                    resultsDomNode.html this._options.searchBox.loadingContent
                    resultsRepresentation.then (resultsRepresentation) ->
                        resultsDomNode.html resultsRepresentation
                searchInputDomNode.after resultsDomNode
                this.resultsDomNode = resultsDomNode
            this
        closeSearchResults: (event) ->
            event?.stopPropagation()
            if this.resultsDomNode
                this.resultsDomNode.remove()
                this.resultsDomNode = null
            this
        initializeGenericSearchBox: (searchInputDomNode) ->
            ###
                Initializes googles generic search box and tries to match to
                open and focus them.
            ###
            searchBox = new window.google.maps.places.SearchBox(
                searchInputDomNode[0])
            # Bias the search box results towards places that are within the
            # bounds of the current map's viewport.
            window.google.maps.event.addListener this.map, 'bounds_changed', =>
                searchBox.setBounds this.map.getBounds()
            # Listen for the event fired when the user selects an item from the
            # pick list. Retrieve the matching places for that item.
            window.google.maps.event.addListener(
                searchBox, 'places_changed', => this.ensurePlaceLocations(
                    searchBox.getPlaces(), (places) =>
                        foundPlace = this.determineBestSearchResult places
                        if foundPlace?
                            shortestDistanceInMeter = window.Number.MAX_VALUE
                            matchingMarker = null
                            for marker in this.markers
                                distanceInMeter = window.google.maps.geometry
                                .spherical.computeDistanceBetween(
                                    foundPlace.geometry.location
                                    marker.position)
                                if distanceInMeter < shortestDistanceInMeter
                                    shortestDistanceInMeter = distanceInMeter
                                    matchingMarker = marker
                            if(
                                matchingMarker and shortestDistanceInMeter <=
                                this._options.searchBox
                            )
                                if this._options.successfulSearchZoom?
                                    this.map.setZoom(
                                        this._options.successfulSearchZoom)
                                return this.openMarker(
                                    foundPlace, this.openMarker
                                    matchingMarker)
                            if this.currentlyOpenWindow?
                                this.currentlyOpenWindow.close()
                            this.map.setCenter foundPlace.geometry.location
                            if this._options.successfulSearchZoom?
                                this.map.setZoom(
                                    this._options.successfulSearchZoom)
                )
            )
            this
        ensurePlaceLocations: (places, onSuccess) ->
            ###Ensures that every given place have a location property.###
            runningGeocodes = 0
            for place in places
                if not place.geometry?.location?
                    this.warn(
                        'Found place "{1}" doesn\'t have a location. ' +
                        'Full object:', place.name)
                    this.warn place
                    this.info(
                        'Geocode will be determined separately. With ' +
                        'address "{1}".', place.name)
                    if not geocoder?
                        geocoder = new window.google.maps.Geocoder()
                    runningGeocodes += 1
                    geocoder.geocode {address: place.name}, (
                        results, status
                    ) ->
                        runningGeocodes -= 1
                        if status is window.google.maps.GeocoderStatus.OK
                            place.geometry = results[0].geometry
                        else
                            delete places[places.indexOf place]
                            this.warn(
                                'Found place "{1}" couldn\'t be geocoded by '
                                'google. Removing it from the places list.')
                        if runningGeocodes is 0
                            onSuccess places
            this
        determineBestSearchResult: (candidates) ->
            ###
                Determines the best search result from given list of
                candidates. Currently the nearest result to current viewport
                will be preferred.
            ###
            result = null
            if candidates.length
                shortestDistanceInMeter = window.Number.MAX_VALUE
                for candidate in candidates
                    distanceInMeter = window.google.maps.geometry
                    .spherical.computeDistanceBetween(
                        candidate.geometry.location, this.map.getCenter())
                    if distanceInMeter < shortestDistanceInMeter
                        result = candidate
                        shortestDistanceInMeter = distanceInMeter
            result
        onLoaded: ->
            ###Is triggered if the complete map ist loaded.###
            window.setTimeout (=>
                this.$domNode.find('input').fadeIn(
                    this._options.inputFadeInOption)
            ), this._options.showInputAfterLoadedDelayInMilliseconds
            this
        createMarker: (store) ->
            ###Registers given store to the google maps canvas.###
            index = 0
            while "#{store.latitude}-#{store.longitude}" in this.seenLocations
                if index % 2
                    store.latitude +=
                        this._options.distanceToMoveByDuplicatedEntries
                else
                    store.longitude +=
                        this._options.distanceToMoveByDuplicatedEntries
                index += 1
            this.seenLocations.push "#{store.latitude}-#{store.longitude}"
            marker =
                position: new window.google.maps.LatLng(
                    store.latitude, store.longitude)
                map: this.map
                data: store
            if store.markerIconFileName
                marker.icon = this._options.iconPath + store.markerIconFileName
            else if this._options.defaultMarkerIconFileName
                marker.icon = this._options.iconPath +
                    this._options.defaultMarkerIconFileName
            marker.title = store.title if store.title
            marker.infoWindow = new window.google.maps.InfoWindow content: ''
            marker.googleMarker = new window.google.maps.Marker marker
            window.google.maps.event.addListener(
                marker.googleMarker, 'click', this.getMethod(
                    'openMarker', this, marker))
            this.markers.push marker
            marker.googleMarker
        openMarker: (place, thisFunction, marker) ->
            ###
                Opens given marker info window. And closes a potential opened
                windows.
            ###
            this.closeSearchResults()
            return this if this.currentlyOpenWindow is marker.infoWindow
            this.fireEvent 'infoWindowOpen', marker
            marker.refreshSize = ->
                ###
                    Simulates a content update to enforce info box size
                    adjusting.
                ###
                marker.infoWindow.setContent marker.infoWindow.getContent()
            infoWindow = this.makeInfoWindow marker
            if $.type(infoWindow) is 'string'
                marker.infoWindow.setContent infoWindow
            else
                marker.infoWindow.setContent(
                    this._options.infoWindow.loadingContent)
                infoWindow.then (infoWindow) ->
                    marker.infoWindow.setContent infoWindow
            this.currentlyOpenWindow.close() if this.currentlyOpenWindow?
            this.currentlyOpenWindow = marker.infoWindow
            marker.infoWindow.open this.map, marker.googleMarker
            this.map.panTo marker.googleMarker.position
            this.map.panBy(
                0, -this._options.infoWindow.additionalMoveToBottomInPixel)
            this.fireEvent 'infoWindowOpened', marker
            this
        makeInfoWindow: (marker) ->
            ###
                Takes the marker for a store and creates the HTML content of
                the info window.
            ###
            if $.isFunction this._options.infoWindow.content
                return this._options.infoWindow.content.apply this, arguments
            if this._options.infoWindow.content?
                return this._options.infoWindow.content
            content = '<div>'
            for name, value of marker.data
                content += "#{name}: #{value}<br />"
            "#{content}</div>"
        makeSearchResults: (searchResults) ->
            ###
                Takes the search results and creates the HTML content of the
                search results.
            ###
            if $.isFunction this._options.searchBox.content
                return this._options.searchBox.content.apply this, arguments
            if this._options.searchBox.content?
                return this._options.searchBox.content
            content = ''
            for result in searchResults
                content += '<div>'
                for name, value of result.data
                    content += "#{name}: #{value}<br />"
                content += '</div>'
            content

    $.fn.StoreLocator = -> $.Tools().controller StoreLocator, arguments, this

# endregion

# region dependencies

if this.require?
    this.require.scopeIndicator = 'jQuery.fn.StoreLocator'
    this.require 'jquery-tools-1.0.coffee', main
else
    main this.jQuery

# endregion

# region vim modline

# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:

# endregion
