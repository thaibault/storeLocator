#!/usr/bin/env coffee
# -*- coding: utf-8 -*-

# region header

###
[Project page](https://thaibault.github.com/jQuery-storeLocator)

This plugin provides a google api based store locator.

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
            # Saves currently opened window instance.
            this.currentlyOpenWindow = null
            # Saves all seen locations to recognize duplicates.
            this.seenLocations = []
            # Saves all recognized markers.
            this.markers = []
            # Saves all plugin interface options.
            this._options =
                # URL to retrieve stores, list of stores or object describing
                # bounds to create random stores within.
                stores: {
                    northEast: latitude: 85, longitude: 180
                    southWest: latitude: -85, longitude: -180
                    number: 100
                },
                # Function or string returning or representing the info box
                infoBox: null
                # Path prefix to search for marker icons.
                iconPath: '/webAsset/image/storeLocator/'
                # Specifies a fallback marker icon (if no store specific icon
                # was set). If set to "null" google will place a fallback icon.
                defaultMarkerIconFileName: null
                # If not provided we initialize the map with center in current
                # location determined by internet protocol address.
                startLocation: null
                # Fallback location if automatic detection fails.
                fallbackLocation: latitude: 51.124213, longitude: 10.147705
                # Determine ip dynamically
                ip: null
                # IP to location determination api url. {1} and {2} represents
                # currently used protocoll and potentially given ip.
                ipToLocationAPIURL: '{1}://freegeoip.net/json/{2}'
                # Initial view properties.
                map: zoom: 3
                # Delay before we show search input field.
                showInputAfterLoadedDelayInMilliseconds: 500
                # Transition to show search input field.
                inputFadeInOption: duration: 'fast'
                # Distance to move if stores are determined with same latitude
                # and longitude.
                distanceToMoveByDuplicatedEntries: 0.0001
                # Options passed to the marker cluster.
                markerCluster: gridSize: 100, maxZoom : 14
                # Search result precision tolerance (smaller means less
                # precision).
                searchResultPrecisionTolerance: 2
                # Specifies a zoom value wich will be adjusted after
                # successfully picked a search result. If set to "null" no zoom
                # change happens.
                successfulSearchZoom: 12
                # Additional move to bottom relative to the marker if an info
                # window has been opened.
                infoWindowAdditionalMoveToBottomInPixel: 100
                # Function to call if map is fully initialized.
                onLoaded: $.noop
                # Triggers if a marker info window will be opened.
                onInfoWindowOpen: $.noop
                # Triggers if a marker info window has finished opening.
                onInfoWindowOpened: $.noop
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
                        this._options.ipToLocationAPIURL
                        document.location.protocol.substring(
                            0, document.location.protocol.length - 1
                        ), this._options.ip or ''
                    )
                    dataType: 'jsonp'
                }).done((currentLocation) =>
                    this._options.startLocation = currentLocation
                ).complete => this.initializeMap()
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
                    markerCluster.addMarker this.createMarker store
            else if $.type(this._options.stores) is 'string'
                $.getJSON this._options.stores, (stores) =>
                    for store in stores
                        markerCluster.addMarker this.createMarker store
            else
                southWest = new window.google.maps.LatLng(
                    this._options.stores.southWest.latitude
                    this._options.stores.southWest.longitude)
                northEast = new window.google.maps.LatLng(
                    this._options.stores.northEast.latitude
                    this._options.stores.northEast.longitude)
                for index in [0...this._options.stores.number]
                    markerCluster.addMarker this.createMarker
                        latitude: southWest.lat() + (northEast.lat(
                        ) - southWest.lat()) * window.Math.random()
                        longitude: southWest.lng() + (northEast.lng(
                        ) - southWest.lng()) * window.Math.random()
            # Create the search box and link it to the UI element.
            searchInputDomNode = this.$domNode.find('input')[0]
            this.map.controls[window.google.maps.ControlPosition.TOP_LEFT]
            .push searchInputDomNode
            searchBox = new window.google.maps.places.SearchBox(
                searchInputDomNode)
            # Listen for the event fired when the user selects an item from the
            # pick list. Retrieve the matching places for that item.
            window.google.maps.event.addListener(
                searchBox, 'places_changed', =>
                    foundPlaces = searchBox.getPlaces()
                    if foundPlaces.length
                        foundPlace = foundPlaces[0]
                        for marker in this.markers
                            if(this.round(marker.position.lat(
                            ) * window.Math.pow(
                                10
                                this._options.searchResultPrecisionTolerance
                            )) is this.round(foundPlace.geometry.location.lat(
                            ) * window.Math.pow(
                                10
                                this._options.searchResultPrecisionTolerance
                            )) and this.round(marker.position.lng(
                            ) * window.Math.pow(
                                10
                                this._options.searchResultPrecisionTolerance
                            )) is this.round(foundPlace.geometry.location.lng(
                            ) * window.Math.pow(
                                10
                                this._options.searchResultPrecisionTolerance
                            )))
                                if this._options.successfulSearchZoom?
                                    this.map.setZoom(
                                        this._options.successfulSearchZoom)
                                return this.openMarker(
                                    foundPlace, this.openMarker, marker)
                        if this.currentlyOpenWindow?
                            this.currentlyOpenWindow.close()
                        this.map.setCenter foundPlace.geometry.location
                        if this._options.successfulSearchZoom?
                            this.map.setZoom this._options.successfulSearchZoom
            )
            # Bias the search box results towards places that are within the
            # bounds of the current map's viewport.
            window.google.maps.event.addListener this.map, 'bounds_changed', =>
                searchBox.setBounds this.map.getBounds()
            this.fireEvent 'loaded'
            this
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
            this.fireEvent 'infoWindowOpen', marker
            infoWindow = this.makeInfoWindow marker.data
            marker.infoWindow.setContent infoWindow
            this.currentlyOpenWindow.close() if this.currentlyOpenWindow?
            this.currentlyOpenWindow = marker.infoWindow
            marker.infoWindow.open this.map, marker.googleMarker
            this.map.panTo marker.googleMarker.position
            this.map.panBy(
                0, -this._options.infoWindowAdditionalMoveToBottomInPixel)
            this.fireEvent 'infoWindowOpened', marker
            this
        makeInfoWindow: (store) ->
            ###
                Takes the info window data for a store and creates the HTML
                content of the info window.
            ###
            if $.isFunction this._options.infoBox
                return this._options.infoBox store
            if this._options.infoBox?
                return this._options.infoBox
            content = '<div>'
            for name, value of store
                content += "#{name}: #{value}<br />"
            "#{content}</div>"

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
