/*
jk64 ReportMap v1.5 Jan 2021
https://github.com/jeffreykemp/jk64-plugin-reportmap
Copyright (c) 2016 - 2021 Jeffrey Kemp
Released under the MIT licence: http://opensource.org/licenses/mit-license
*/

$( function() {
  $.widget( "jk64.reportmap", {

    // default options
    options: {
        regionId               : "",
        ajaxIdentifier         : "",
        ajaxItems              : "",
        pluginResourcePath     : "",
        pluginFilePrefix       : "",
        expectData             : true,
        maximumRows            : null,
        rowsPerBatch           : null,
        initialCenter          : {lat:0,lng:0},
        minZoom                : 1,
        maxZoom                : null,
        initialZoom            : 2,
        visualisation          : "pins",
        mapType                : "roadmap", //google.maps.MapTypeId
        clickZoomLevel         : null,
        isDraggable            : false,
        heatmapDissipating     : false,
        heatmapOpacity         : 0.6,
        heatmapRadius          : 5,
        panOnClick             : true,
        restrictCountry        : "",
        mapStyle               : "",
        travelMode             : "DRIVING", //google.maps.TravelMode
        unitSystem             : "METRIC", //google.maps.UnitSystem
        optimizeWaypoints      : false,
        allowZoom              : true,
        allowPan               : true,
        gestureHandling        : "auto",
        initFn                 : null,
        markerFormatFn         : null,
        drawingModes           : null,
        featureColor           : '#cc66ff',
        featureColorSelected   : '#ff6600',
        featureSelectable      : true,
        featureHoverable       : true,
        featureStyleFn         : null,
        dragDropGeoJSON        : false,
		autoFitBounds          : true,
        directionsPanel        : null,
        spiderfier             : {},
        spiderfyFormatFn       : null,
        showPins               : true,  //show the Pins (pin type visualisations only)
        showInfoPopups         : true,  //show the Info popup when pin is clicked
        showInfoLayer          : false, //show the Info layer (pin type visualisations only)
        infoLayerFormatFn      : null,
        showSpinner            : true,
        detailedMouseEvents    : false,
        iconBasePath           : "",
        noDataMessage          : "",
        noAddressResults       : "Address not found",
        directionsNotFound     : "At least one of the origin, destination, or waypoints could not be geocoded.",
        directionsZeroResults  : "No route could be found between the origin and destination.",

        // Callbacks
        addOverlay             : null, //add an overlay (e.g. map or info box) on top of the map
        click                  : null, //simulate a click on a marker
        deleteAllFeatures      : null, //delete all features (drawing manager)
        deleteSelectedFeatures : null, //delete selected features (drawing manager)
        fitBounds              : null, //pan/zoom the map to the given bounds
        geolocate              : null, //find the user's device location
        getAddressByPos        : null, //get closest address to the given location
        gotoAddress            : null, //search by address and place the pin there
        gotoPos                : null, //place the pin at a given position {lat,lng}
        gotoPosByString        : null, //place the pin at a given position (lat,lng provided as a string or LatLngLiteral)
        hideMessage            : null, //hide the warning/error message
        loadGeoJsonString      : null, //load features from a GeoJSON document
        panTo                  : null, //pan map to given location (lat,lng)
        panToByString          : null, //pan map to given position (lat,lng provided as a string or LatLngLiteral)
        parseLatLng            : null, //parse a lat,lng string into a google.maps.LatLng
        refresh                : null, //refresh the map (re-run the query)
        showDirections         : null, //show route between two locations
		showInfoWindow         : null, //set and show info window (popup) for a pin
        showMessage            : null  //show a warning/error message
    },

    //return google maps LatLng based on parsing the given string
    //the delimiter may be a space ( ) or a semicolon (;) or a comma (,) with one exception:
    //if the decimal point is indicated by a comma (,) the separator must be a space ( ) or semicolon (;)
    //e.g.:
    //    -17.9609 122.2122
    //    -17.9609,122.2122
    //    -17.9609;122.2122
    //    -17,9609 122,2122
    //    -17,9609;122,2122
    //Also accepts and parses a LatLngLiteral, e.g.
    //    {"lat":-17.9609, "lng":122.2122}
    parseLatLng: function (v) {
        apex.debug("reportmap.parseLatLng", v);
        var pos;
        if (v !== null && v !== undefined) {
            if (v.hasOwnProperty("lat")&&v.hasOwnProperty("lng")) {
                // parse as google.maps.LatLngLiteral
                pos = new google.maps.LatLng(v);
            } else {
                var arr;
                if (v.indexOf(";")>-1) {
                    arr = v.split(";");
                } else if (v.indexOf(" ")>-1) {
                    arr = v.split(" ");
                } else if (v.indexOf(",")>-1) {
                    arr = v.split(",");
                }
                if (arr && arr.length==2) {
                    //convert to use period (.) for decimal point
                    arr[0] = arr[0].replace(/,/g, ".");
                    arr[1] = arr[1].replace(/,/g, ".");
                    apex.debug("parsed", arr);
                    pos = new google.maps.LatLng(parseFloat(arr[0]),parseFloat(arr[1]));
                } else {
                    apex.debug('no LatLng found', v);
                }
            }
        }
        return pos;
    },
    
    /*
     *
     * Map Overlay
     *
     */
    addOverlay: function (content, options) {
        apex.debug("addOverlay", content, options);
        var overlayOptions = $.extend({
                //default options
                bounds           : null,     // scale the object to match this range of lat,long coordinates (e.g. to show a map image on top of the map)
                pos              : null,     // (pos only) position the object at this point (don't scale it)
                horizontalAlign  : "center", // (pos only) left, center, right
                verticalAlign    : "middle", // (pos only) top, middle, bottom
                horizontalOffset : 0,        // (pos only) pixel offset (x)
                verticalOffset   : 0,        // (pos only) pixel offset (y)
                minZoom          : 0,        // hide if zoomed out past this level
                maxZoom          : 99,       // hide if zoomed in past this level
                onClickHandler   : null      // function to call if overlay clicked (null to make not clickable)
            }, options);
        var overlay = new MapOverlay(content, overlayOptions);
        overlay.setMap(this.map);
        return overlay;
    },

	/*
	 *
	 * MESSAGE POPUP
	 *
	 */
    showMessage: function (msg) {
        apex.debug("reportmap.showMessage", msg);

        this.hideMessage();

        this.msgDiv = document.createElement('div');

        var messageUI = document.createElement('div');
        messageUI.className = 'reportmap-messageUI';
        this.msgDiv.appendChild(messageUI);

        var messageInner = document.createElement('div');
        messageInner.className = 'reportmap-messageInner';
        messageInner.innerHTML = msg;
        messageUI.appendChild(messageInner);

        this.msgDiv.addEventListener('click', function() {
            apex.debug("on click - hide message");
            this.remove();
        });

        this.map.controls[google.maps.ControlPosition.LEFT_CENTER].push(this.msgDiv);
        return this.msgDiv;
    },

    hideMessage: function() {
        apex.debug("reportmap.hideMessage");
        if (this.msgDiv) {
            this.msgDiv.remove();
        }
    },

	/*
	 *
	 * REPORT PINS
	 *
	 */

    _eventPinData: function (marker) {
        //get pin data for passing to an event handler
        var d = {
            map    : this.map,
            lat    : marker.position.lat(),
            lng    : marker.position.lng(),
			marker : marker
        };
        if (marker.overlay&&marker.overlay.div) {
            d.infoDiv = marker.overlay.div;
        }
        $.extend(d, marker.data);
        return d;
    },

    _unescapeInfo: function(info) {
		//unescape the html for the info window contents
		var ht = new DOMParser().parseFromString(info, "text/html");
		return ht.documentElement.textContent;
    },

	//show the info window for a pin; set the content for it
	showInfoWindow: function (marker) {
		apex.debug("reportmap.showInfoWindow", marker);
		//show info window for this pin
		if (!this.infoWindow) {
			this.infoWindow = new google.maps.InfoWindow();
		}
		this.infoWindow.setContent(this._unescapeInfo(marker.data.info));
		//associate the info window with the marker and show on the map
		this.infoWindow.open(this.map, marker);
        return this.infoWindow;
	},

    //place a report pin on the map
    _newMarker: function (pinData) {
        var _this = this,
            marker = new google.maps.Marker({
              map       : this.map,
              position  : new google.maps.LatLng(pinData.x, pinData.y),
              title     : pinData.n,
              icon      : (pinData.c?(this.options.iconBasePath + pinData.c):null),
              label     : pinData.l,
              draggable : this.options.isDraggable
            });

        //load our own data into the marker
        marker.data = {
            id   : pinData.d,
            info : pinData.i,
            name : pinData.n
		};
        for (var i = 1; i <= 10; i++) {
            if (pinData.f&&pinData.f["a"+i]) {
                //f.a1, f.a2, ... f.a10 converted to marker.data.attr01, marker.data.attr02, ... marker.data.attr10
                marker.data["attr"+('0'+i).slice(-2)] = pinData.f["a"+i];
            }
        }

        if (!this.options.showPins) {
            marker.setVisible(false);
        }

        //if a marker formatting function has been supplied, call it
        if (this.options.markerFormatFn) {
            this.options.markerFormatFn(marker);
        }

        if (marker.data.info && this.options.showInfoLayer) {
            marker.overlay = this.addOverlay(this._unescapeInfo(marker.data.info), {
                pos            : marker.position,
                onClickHandler : function () {
                    apex.debug("infoLayer clicked", marker.data.id);
                    if (_this.options.panOnClick) {
                        _this.map.panTo(marker.position);
                    }
                    if (_this.options.clickZoomLevel) {
                        _this.map.setZoom(_this.options.clickZoomLevel);
                    }
                    apex.jQuery("#"+_this.options.regionId).trigger("markerclick", _this._eventPinData(marker));
                }
            });
            if (this.options.infoLayerFormatFn) {
                this.options.infoLayerFormatFn(marker.overlay, marker);
            }
        }

        google.maps.event.addListener(marker,
            (this.options.visualisation=="spiderfier"?"spider_click":"click"),
            function () {
                apex.debug("marker clicked", marker.data.id);
                var pos = this.getPosition();
                if (marker.data.info && _this.options.showInfoPopups) {
                    _this.showInfoWindow(this);
                }
                if (_this.options.panOnClick) {
                    _this.map.panTo(pos);
                }
                if (_this.options.clickZoomLevel) {
                    _this.map.setZoom(_this.options.clickZoomLevel);
                }
                apex.jQuery("#"+_this.options.regionId).trigger("markerclick", _this._eventPinData(marker));
            });

        google.maps.event.addListener(marker, "dragend", function () {
            var pos = this.getPosition();
            apex.debug("marker moved", marker.data.id, JSON.stringify(pos));
            apex.jQuery("#"+_this.options.regionId).trigger("markerdrag", _this._eventPinData(marker));
        });

		if (["pins","infolayer","cluster","spiderfier"].indexOf(this.options.visualisation) > -1) {
			// if the marker was not previously shown in the last refresh, raise the marker added event
			if (!this.idMap||!this.idMap.has(marker.data.id)) {
				apex.jQuery("#"+_this.options.regionId).trigger("markeradded", _this._eventPinData(marker));
			}
		}
        return marker;
    },

    // set up the Spiderfier visualisation
    _spiderfy: function() {
        apex.debug("reportmap._spiderfy");
        // refer to: https://github.com/jawj/OverlappingMarkerSpiderfier

        var _this = this,
            opt = {
                keepSpiderfied    : true,
                basicFormatEvents : true,
                markersWontMove   : !this.options.isDraggable,
                markersWontHide   : true
            };

        // allow the developer to set / override spiderfy options
        $.extend(opt, this.options.spiderfier);

        this.oms = new OverlappingMarkerSpiderfier(this.map, opt);

        // format the markers using the provided format function (options.spiderfyFormatFn),
        // or if not specified, provide a default function
        this.oms.addListener('format',
            this.options.spiderfyFormatFn
            ||  function(marker, status) {
                    // if basicFormatEvents = true, status will be SPIDERFIED, SPIDERFIABLE, or UNSPIDERFIABLE
                    // if basicFormatEvents = false, status will be SPIDERFIED or UNSPIDERFIED
                    var iconURL = _this._getWindowPath() + "/" + _this.options.pluginFilePrefix +
                        (status == OverlappingMarkerSpiderfier.markerStatus.SPIDERFIED ?
                                   'images/spotlight-waypoint-blue.png' :
                         status == OverlappingMarkerSpiderfier.markerStatus.SPIDERFIABLE ?
                                   'images/spotlight-waypoint-a.png' :
                                   'images/spotlight-poi.png');
                    //apex.debug("spiderfy.format", marker, status, iconURL);
                    marker.setIcon({url: iconURL});
                });

        // register the markers with the OverlappingMarkerSpiderfier
        for (var i = 0; i < this.markers.length; i++) {
            this.oms.addMarker(this.markers[i]);
        }

        this.oms.addListener('spiderfy', function(markers) {
            apex.debug("spiderfy", markers);
			apex.jQuery("#"+_this.options.regionId).trigger("spiderfy", { map:_this.map, markers:markers });
        });

        this.oms.addListener('unspiderfy', function(markers) {
            apex.debug("unspiderfy", markers);
			apex.jQuery("#"+_this.options.regionId).trigger("unspiderfy", { map:_this.map, markers:markers });
        });

        return this.oms;
    },

    _removeMarkers: function() {
        apex.debug("reportmap._removeMarkers");
        this.totalRows = 0;
        if (this.bounds) { this.bounds.delete; }
        if (this.markers) {
            for (var i = 0; i < this.markers.length; i++) {
                this.markers[i].setMap(null);
            }
            this.markers.delete;
        }
    },

    //call this to simulate a mouse click on the marker for the given id value
    //e.g. this will show the info window for the given marker and trigger the markerclick event
    click: function (id) {
        apex.debug("reportmap.click");
        var marker = this.markers.find( function(p){ return p.data.id==id; });
        if (marker) {
            new google.maps.event.trigger(marker,"click");
        } else {
            apex.debug("id not found", id);
        }
        return marker;
    },

	/*
	 *
	 * USER PIN
	 *
	 */

    //place or move the user pin to the given location
    gotoPos: function (lat,lng) {
        apex.debug("reportmap.gotoPos",lat,lng);
        if (lat!==null && lng!==null) {
            var oldpos = this.userpin?this.userpin.getPosition():(new google.maps.LatLng(0,0));
            if (oldpos && lat==oldpos.lat() && lng==oldpos.lng()) {
                apex.debug("userpin not changed");
            } else {
                var pos = new google.maps.LatLng(lat,lng);
                if (this.userpin) {
                    apex.debug("move existing pin to new position on map",pos);
                    this.userpin.setMap(this.map);
                    this.userpin.setPosition(pos);
                } else {
                    apex.debug("create userpin",pos);
                    this.userpin = new google.maps.Marker({
                        map       : this.map,
                        position  : pos,
                        draggable : this.options.isDraggable
                    });
                    var _this = this;
                    google.maps.event.addListener(this.userpin, "dragend", function () {
                        var pos = this.getPosition();
                        apex.debug("userpin moved", JSON.stringify(pos));
                        apex.jQuery("#"+_this.options.regionId).trigger("markerdrag",{
                            map    : _this.map,
                            lat    : pos.lat(),
                            lng    : pos.lng(),
                            marker : this
                        })
                    });
                }
            }
        } else if (this.userpin) {
            apex.debug("move existing pin off the map");
            this.userpin.setMap(null);
        }
    },

    //parse the given string as a lat,long pair, put a pin at that location
    gotoPosByString: function (v) {
        apex.debug("reportmap.gotoPosByString", v);
        var latlng = this.parseLatLng(v);
        if (latlng) {
            this.gotoPos(latlng.lat(),latlng.lng());
        }
        return latlng;
    },

    //place or move the user pin to the given location
    panTo: function (lat,lng) {
        apex.debug("reportmap.panTo",lat,lng);
        var pos;
        if (lat!==null && lng!==null) {
            pos = new google.maps.LatLng(lat,lng);
            this.map.panTo(pos);
        }
        return pos;
    },

    //parse the given string as a lat,long pair, pan to that location
    panToByString: function (v) {
        apex.debug("reportmap.panToByString", v);
        var latlng = this.parseLatLng(v);
        if (latlng) {
            this.panTo(latlng.lat(),latlng.lng());
        }
        return latlng;
    },

    //pan/zoom the map to the given bounds
    fitBounds: function (v) {
        apex.debug("reportmap.fitBounds", v);
        var bounds;
        if (v !== null && v !== undefined) {
            if (v.hasOwnProperty("east")&&v.hasOwnProperty("north")&&v.hasOwnProperty("south")&&v.hasOwnProperty("west")) {
                // parse as google.maps.LatLngBoundsLiteral
                bounds = new google.maps.LatLngBoundsLiteral(v);
            } else {
                bounds = JSON.parse(v);
            }

            if (bounds) {
                this.map.fitBounds(bounds);
            }
        }
        return bounds;
    },

	/*
	 *
	 * GEOCODING
	 *
	 */

    //search the map for an address; if found, put a pin at that location and raise addressfound trigger
    gotoAddress: function (addressText) {
        apex.debug("reportmap.gotoAddress", addressText);
        var geocoder = new google.maps.Geocoder;
        this.hideMessage();
        var _this = this;
        geocoder.geocode({
            address               : addressText,
            componentRestrictions : _this.options.restrictCountry!==""?{country:_this.options.restrictCountry}:{}
        }, function(results, status) {
            if (status === google.maps.GeocoderStatus.OK) {
                var pos = results[0].geometry.location;
                apex.debug("geocode ok", pos);
                _this.map.setCenter(pos);
                _this.map.panTo(pos);
                if (_this.options.clickZoomLevel) {
                    _this.map.setZoom(_this.options.clickZoomLevel);
                }
                _this.gotoPos(pos.lat(), pos.lng());
                apex.debug("addressfound", results);
                apex.jQuery("#"+_this.options.regionId).trigger("addressfound", {
                    map    : _this.map,
                    lat    : pos.lat(),
                    lng    : pos.lng(),
                    result : results[0]
                });
            } else if (status === google.maps.GeocoderStatus.ZERO_RESULTS) {
                apex.debug("getAddressByPos: ZERO_RESULTS");
                _this.showMessage(_this.options.noAddressResults);
            } else {
                apex.debug("Geocoder failed", status);
            }
        });
    },

    //get the closest address to a given location by lat/long
    getAddressByPos: function (lat,lng) {
        apex.debug("reportmap.getAddressByPos", lat,lng);
        var geocoder = new google.maps.Geocoder;
        this.hideMessage();
        var _this = this;
        geocoder.geocode({'location': {lat: lat, lng: lng}}, function(results, status) {
            if (status === google.maps.GeocoderStatus.OK) {
                if (results[0]) {
                  apex.debug("addressfound", results);
                  apex.jQuery("#"+_this.options.regionId).trigger("addressfound", {
                      map    : _this.map,
                      lat    : lat,
                      lng    : lng,
                      result : results[0]
                  });
                } else {
                    apex.debug("getAddressByPos: No results returned");
                    _this.showMessage(_this.options.noAddressResults);
                }
            } else if (status === google.maps.GeocoderStatus.ZERO_RESULTS) {
                apex.debug("getAddressByPos: ZERO_RESULTS");
                _this.showMessage(_this.options.noAddressResults);
            } else {
                apex.debug("Geocoder failed", status);
            }
        });
    },

    //search for the user device's location if possible
    geolocate: function () {
        apex.debug("reportmap.geolocate");
        if (navigator.geolocation) {
            var _this = this;
            navigator.geolocation.getCurrentPosition(function(position) {
                var pos = {
                    lat : position.coords.latitude,
                    lng : position.coords.longitude
                };
                _this.map.panTo(pos);
                if (_this.options.clickZoomLevel) {
                    _this.map.setZoom(_this.options.clickZoomLevel);
                }
                apex.jQuery("#"+_this.options.regionId).trigger("geolocate", {map:_this.map, lat:pos.lat, lng:pos.lng});
            });
        } else {
            apex.debug("browser does not support geolocation");
        }
    },

	/*
	 *
	 * DIRECTIONS
	 *
	 */

	 //this is called when directions are requested
    _directionsResponse: function (response,status) {
        apex.debug("reportmap._directionsResponse",response,status);
        switch(status) {
        case google.maps.DirectionsStatus.OK:
            this.directionsDisplay.setDirections(response);
            var totalDistance = 0, totalDuration = 0, legCount = 0, units = "meters";
            for (var i=0; i < response.routes.length; i++) {
                legCount = legCount + response.routes[i].legs.length;
                for (var j=0; j < response.routes[i].legs.length; j++) {
                    var leg = response.routes[i].legs[j];
                    totalDistance = totalDistance + leg.distance.value;
                    totalDuration = totalDuration + leg.duration.value;
                }
            }
            if (this.options.unitSystem === "IMPERIAL") {
                //convert meters to miles
                totalDistance *= 0.00062137119224;
                units = "miles";
            }
            var _this = this;
            apex.jQuery("#"+this.options.regionId).trigger("directions",{
                map        : _this.map,
                distance   : totalDistance,
                units      : units,
                duration   : totalDuration,
                legs       : legCount,
                directions : response
            });
            break;
        case google.maps.DirectionsStatus.NOT_FOUND:
            this.showMessage(this.options.directionsNotFound);
            break;
        case google.maps.DirectionsStatus.ZERO_RESULTS:
            this.showMessage(this.options.directionsZeroResults);
            break;
        default:
            apex.debug("Directions request failed", status);
        }
    },

    //show simple route between two points
    showDirections: function (origin, destination, travelMode) {
        apex.debug("reportmap.showDirections", origin, destination, travelMode);
        this.origin = origin;
        this.destination = destination;
        this.hideMessage();
        if (this.origin&&this.destination) {
            if (!this.directionsDisplay) {
                this.directionsDisplay = new google.maps.DirectionsRenderer;
                this.directionsService = new google.maps.DirectionsService;
                this.directionsDisplay.setMap(this.map);
                if (this.options.directionsPanel) {
                    this.directionsDisplay.setPanel(document.getElementById(this.options.directionsPanel));
                }
            }
            //simple directions between two locations
            this.origin = this.parseLatLng(this.origin)||this.origin;
            this.destination = this.parseLatLng(this.destination)||this.destination;
            if (this.origin !== "" && this.destination !== "") {
                var _this = this;
                this.directionsService.route({
                    origin      : this.origin,
                    destination : this.destination,
                    travelMode  : google.maps.TravelMode[travelMode?travelMode:this.options.travelMode],
                    unitSystem  : google.maps.UnitSystem[this.options.unitSystem]
                }, function(response,status){
                    _this._directionsResponse(response,status)
                });
            } else {
                apex.debug("No directions to show - need both origin and destination location");
            }
        } else {
            apex.debug("Unable to show directions: no data, no origin/destination");
        }
    },

    //directions visualisation based on query data
    _directions: function () {
        apex.debug("reportmap._directions "+this.markers.length+" waypoints");
        if (this.markers.length>1) {
            if (!this.directionsDisplay) {
                this.directionsDisplay = new google.maps.DirectionsRenderer;
                this.directionsService = new google.maps.DirectionsService;
                this.directionsDisplay.setMap(this.map);
                if (this.options.directionsPanel) {
                    this.directionsDisplay.setPanel(document.getElementById(this.options.directionsPanel));
                }
            }
            var origin = this.markers[0].position,
                dest = this.markers[this.markers.length-1].position,
                waypoints = [];
            for (var i = 1; i < this.markers.length-1; i++) {
                waypoints.push({
                    location : this.markers[i].position,
                    stopover : true
                });
            }
            apex.debug(origin, dest, waypoints, this.options.travelMode);
            var _this = this;
            this.directionsService.route({
                origin            : origin,
                destination       : dest,
                waypoints         : waypoints,
                optimizeWaypoints : this.options.optimizeWaypoints,
                travelMode        : google.maps.TravelMode[this.options.travelMode],
                unitSystem        : google.maps.UnitSystem[this.options.unitSystem]
            }, function(response,status){
                _this._directionsResponse(response,status)
            });
        } else {
            apex.debug("not enough waypoints - need at least an origin and a destination point");
        }
    },

	/*
	 *
	 * DRAWING LAYER
	 *
	 */

    deleteSelectedFeatures: function() {
        apex.debug("reportmap.deleteSelectedFeatures");
        var dataLayer = this.map.data;
        dataLayer.forEach(function(feature) {
            if (feature.getProperty('isSelected')) {
                apex.debug("remove",feature);
                dataLayer.remove(feature);
            }
        });
    },

    deleteAllFeatures: function() {
        apex.debug("reportmap.deleteAllFeatures");
        var dataLayer = this.map.data;
        dataLayer.forEach(function(feature) {
            apex.debug("remove",feature);
            dataLayer.remove(feature);
        });
    },

    _addControl: function(icon, hint, callback) {

        var controlDiv = document.createElement('div');

        // Set CSS for the control border.
        var controlUI = document.createElement('div');
        controlUI.className = 'reportmap-controlUI';
        controlUI.title = hint;
        controlDiv.appendChild(controlUI);

        // Set CSS for the control interior.
        var controlInner = document.createElement('div');
        controlInner.className = 'reportmap-controlInner';
        controlInner.style.backgroundImage = icon;

        controlUI.appendChild(controlInner);

        // Setup the click event listener
        controlUI.addEventListener('click', callback);

        this.map.controls[google.maps.ControlPosition.TOP_CENTER].push(controlDiv);

        return controlDiv;
    },

    _addCheckbox: function(name, label, hint) {

        var controlDiv = document.createElement('div');

        // Set CSS for the control border.
        var controlUI = document.createElement('div');
        controlUI.className = 'reportmap-controlUI';
        controlUI.title = hint;
        controlDiv.appendChild(controlUI);

        // Set CSS for the control interior.
        var controlInner = document.createElement('div');
        controlInner.className = 'reportmap-controlInner';

        controlUI.appendChild(controlInner);

        var controlCheckbox = document.createElement('input');
        controlCheckbox.setAttribute('type', 'checkbox');
        controlCheckbox.setAttribute('id', name+'_'+this.options.regionId);
        controlCheckbox.setAttribute('name', name);
        controlCheckbox.setAttribute('value', 'Y');
        controlCheckbox.className = 'reportmap-controlCheckbox';

        controlCheckbox.className = 'reportmap-checkbox';

        controlInner.appendChild(controlCheckbox);

        var controlLabel = document.createElement('label');
        controlLabel.setAttribute('for',name+'_'+this.options.regionId);
        controlLabel.innerHTML = label;
        controlLabel.className = 'reportmap-controlCheckboxLabel';

        controlInner.appendChild(controlLabel);

        this.map.controls[google.maps.ControlPosition.TOP_CENTER].push(controlDiv);

        return controlDiv;
    },

    _addPoint: function(dataLayer, pos) {
        apex.debug("reportmap._addPoint",dataLayer,pos);
        var feature = new google.maps.Data.Feature({
            geometry: new google.maps.Data.Point(pos)
        });
        dataLayer.add(feature);
        return feature;
    },

    _addPolygon: function(dataLayer, arr) {
        apex.debug("reportmap._addPolygon",dataLayer,arr);

        if ($("#hole_"+this.options.regionId).prop("checked")) {
            dataLayer.forEach(function(feature) {
                if (feature.getProperty('isSelected')) {
                    var geom = feature.getGeometry();
                    if (geom.getType() == "Polygon") {
                        //append the new hole to the existing polygon
                        var poly = geom.getArray();
                        //the polygon will now be an array of LinearRings
                        poly.push(new google.maps.Data.LinearRing(arr));
                        feature.setGeometry(new google.maps.Data.Polygon(poly));
                    }
                }
            });
        } else {
            dataLayer.add(new google.maps.Data.Feature({
                geometry: new google.maps.Data.Polygon([arr])
            }));
        }
    },

    // initialisation for data layer when not in drawing mode
    _initFeatures: function() {
        apex.debug("reportmap._initFeatures");

        var _this = this,
            dataLayer = this.map.data;

        // Change the color when the isSelected property is set to true.
        dataLayer.setStyle(this.options.featureStyleFn||function(feature) {
            var color = _this.options.featureColor;
            if (feature.getProperty('isSelected')) {
                color = _this.options.featureColorSelected;
            }
            return /** @type {!google.maps.Data.StyleOptions} */({
                fillColor    : color,
                strokeColor  : color,
                strokeWeight : 1,
                draggable    : _this.options.isDraggable,
                editable     : false
            });
        });

        if (this.options.featureSelectable) {
            // When the user clicks, set 'isSelected', changing the color of the shape.
            dataLayer.addListener('click', function(event) {
                apex.debug("reportmap.map.data - click",event);
                if (event.feature.getProperty('isSelected')) {
                    apex.debug("isSelected","false");
                    event.feature.removeProperty('isSelected');
                    apex.jQuery("#"+_this.options.regionId).trigger("unselectfeature", {map:_this.map, feature:event.feature});
                } else {
                    apex.debug("isSelected","true");
                    event.feature.setProperty('isSelected', true);
                    apex.jQuery("#"+_this.options.regionId).trigger("selectfeature", {map:_this.map, feature:event.feature});
                }
            });
        }

        if (this.options.featureHoverable) {

            // When the user hovers, tempt them to click by outlining the shape.
            // Call revertStyle() to remove all overrides. This will use the style rules
            // defined in the function passed to setStyle()

            dataLayer.addListener('mouseover', function(event) {
                apex.debug("reportmap.map.data","mouseover",event);
                dataLayer.revertStyle();
                dataLayer.overrideStyle(event.feature, {strokeWeight: 4});
                apex.jQuery("#"+_this.options.regionId).trigger("mouseoverfeature", {map:_this.map, feature:event.feature});
            });

            dataLayer.addListener('mouseout', function(event) {
                apex.debug("reportmap.map.data","mouseout",event);
                dataLayer.revertStyle();
                apex.jQuery("#"+_this.options.regionId).trigger("mouseoutfeature", {map:_this.map, feature:event.feature});
            });
        }

    },

    // initialisation for data layer when in drawing mode
    _initDrawing: function() {
        apex.debug("reportmap._initDrawing",this.options.drawingModes);
        var _this = this,
            dataLayer = this.map.data;

        if (this.options.drawingModes.indexOf("polygon")>-1) {
            this._addCheckbox(
                'hole', //name
                'Hole', //label
                'Subtract hole from polygon', //hint
            );
        }

        this._addControl(
			//trashcan icon
            "url('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAA5ElEQVQ4jc3UP0oDQRTH8U9URGSx9ASewcoz5AAL9rYexc4T2FhY6gEE0TMIQS2VFEHEgCYpfMU62cz+0SI/GPbxfr/58mYYlnXXoMEvcZD0HnGxasNWBnaEY5wl/VM847YrcB93uEn6h+G10gjzjmuUAw57AIc54AamEXzBddT3fo4/j95T1NPY8wtQ1QzjqMe4jPohFlwlmVkOCG/x3cOkxp+EV83+GVj0ARb/PeE2vmr8T+z0AZJceEN2JfC1AdI5W2r/qMs2Ey4dI6OlbN3vq8AJdiu9TXwnuQ+c473DAGugBV7oWWGmvidcAAAAAElFTkSuQmCC')",
            'Delete selected features', //hint
            function(e) {
                _this.deleteSelectedFeatures();
            });

        // from https://jsfiddle.net/geocodezip/ezfe2wLg/57/

        var drawingManager = new google.maps.drawing.DrawingManager({
            drawingControlOptions: {
              /*https://developers.google.com/maps/documentation/javascript/reference/control#ControlPosition*/
              position     : google.maps.ControlPosition.TOP_CENTER,
              drawingModes : this.options.drawingModes
            }
        });
        drawingManager.setMap(this.map);

        // from http://stackoverflow.com/questions/25072069/export-geojson-data-from-google-maps
        // from http://jsfiddle.net/doktormolle/5F88D/
        google.maps.event.addListener(drawingManager, 'overlaycomplete', function(event) {
            apex.debug("reportmap.overlaycomplete",event);
            switch (event.type) {
            case google.maps.drawing.OverlayType.MARKER:
                _this._addPoint(dataLayer, event.overlay.getPosition());
                break;
            case google.maps.drawing.OverlayType.POLYGON:
                var p = event.overlay.getPath().getArray();
                _this._addPolygon(dataLayer, p);
                break;
            case google.maps.drawing.OverlayType.RECTANGLE:
                var b = event.overlay.getBounds(),
                    p = [b.getSouthWest(),
                         {lat : b.getSouthWest().lat(),
                          lng : b.getNorthEast().lng()
                         },
                         b.getNorthEast(),
                         {lng : b.getSouthWest().lng(),
                          lat : b.getNorthEast().lat()
                         }];
                _this._addPolygon(dataLayer, p);
                break;
            case google.maps.drawing.OverlayType.POLYLINE:
                dataLayer.add(new google.maps.Data.Feature({
                    geometry: new google.maps.Data.LineString(event.overlay.getPath().getArray())
                }));
                break;
            case google.maps.drawing.OverlayType.CIRCLE:
                //todo: find some way of showing the circle, along with editable radius?
                dataLayer.add(new google.maps.Data.Feature({
                    properties: {
                        radius: event.overlay.getRadius()
                    },
                    geometry: new google.maps.Data.Point(event.overlay.getCenter())
                }));
                break;
            }
            event.overlay.setMap(null);
        });

        // Change the color when the isSelected property is set to true.
        dataLayer.setStyle(function(feature) {
            var color = _this.options.featureColor,
                editable = false,
                styleOptions;
            if (feature.getProperty('isSelected')) {
                color = _this.options.featureColorSelected;
                // if we're drawing a hole, we don't want to drag/edit the existing feature
                editable = !($("#hole_"+_this.options.regionId).prop("checked"));
            }
            styleOptions = /** @type {!google.maps.Data.StyleOptions} */{
                fillColor    : color,
                strokeColor  : color,
                strokeWeight : 1
            };
            if (_this.options.featureStyleFn) {
                $.extend(styleOptions, _this.options.featureStyleFn(feature));
            }
            return $.extend(styleOptions, {draggable:editable, editable:editable});
        });

        dataLayer.addListener('addfeature', function(event) {
            apex.debug("reportmap.map.data","addfeature",event);
            apex.jQuery("#"+_this.options.regionId).trigger("addfeature", {map:_this.map, feature:event.feature});
        });

        dataLayer.addListener('removefeature', function(event) {
            apex.debug("reportmap.map.data","removefeature",event);
            apex.jQuery("#"+_this.options.regionId).trigger("removefeature", {map:_this.map, feature:event.feature});
        });

        dataLayer.addListener('setgeometry', function(event) {
            apex.debug("reportmap.map.data","setgeometry",event);
            apex.jQuery("#"+_this.options.regionId).trigger("setgeometry", {
				map         : _this.map,
				feature     : event.feature,
				newGeometry : event.newGeometry,
				oldGeometry : event.oldGeometry
			});
        });

        document.addEventListener('keydown', function(event) {
            if (event.key === "Delete") {
                _this.deleteSelectedFeatures();
            }
        });

    },

	/*
	 *
	 * GEOJSON
	 *
	 */

    /**
     * Process each point in a Geometry, regardless of how deep the points may lie.
     * @param {google.maps.Data.Geometry} geometry - structure to process
     * @param {function(google.maps.LatLng)} callback function to call on each
     *     LatLng point encountered
     * @param {Object} thisArg - value of 'this' as provided to 'callback'
     */
    _processPoints : function (geometry, callback, thisArg) {
        var _this = this;
        if (geometry instanceof google.maps.LatLng) {
            callback.call(thisArg, geometry);
        } else if (geometry instanceof google.maps.Data.Point) {
            callback.call(thisArg, geometry.get());
        } else {
            geometry.getArray().forEach(function(g) {
                _this._processPoints(g, callback, thisArg);
            });
        }
    },

    _loadGeoJson : function (geojson, filename, options) {
        apex.debug("_loadGeoJson", geojson);

        // render the features on the map
        let features = this.map.data.addGeoJson(geojson, options);

        //Update a map's viewport to fit each geometry in a dataset
        var _this = this;
        this.map.data.forEach(function(feature) {
            _this._processPoints(feature.getGeometry(), _this.bounds.extend, _this.bounds);
        });
        if (this.options.autoFitBounds) {
            this.map.fitBounds(this.bounds);
        }

        apex.jQuery("#"+this.options.regionId).trigger("loadedgeojson", {
            map      : this.map,
            geoJson  : geojson,
            features : features,
            filename : filename
        });
    },

    loadGeoJsonString : function (geoString, filename) {
        apex.debug("reportmap.loadGeoJsonString", geoString, filename);
        if (geoString) {
            var geojson = JSON.parse(geoString);
            this.bounds = new google.maps.LatLngBounds;
            this._loadGeoJson(geojson, filename);
        }
    },

    _initDragDropGeoJSON : function () {
        apex.debug("reportmap._initDragDropGeoJSON");
        var _this = this;
        // set up the drag & drop events
        var mapContainer = document.getElementById('map_'+this.options.regionId),
            dropContainer = document.getElementById('drop_'+this.options.regionId);

        var showPanel = function (e) {
                e.stopPropagation();
                e.preventDefault();
                dropContainer.style.display = 'block';
                return false;
            };

        // map-specific events
        mapContainer.addEventListener('dragenter', showPanel, false);

        // overlay specific events (since it only appears once drag starts)
        dropContainer.addEventListener('dragover', showPanel, false);

        dropContainer.addEventListener('dragleave', function() {
            dropContainer.style.display = 'none';
        }, false);

        dropContainer.addEventListener('drop', function(e) {
            apex.debug("reportmap.drop",e);
            e.preventDefault();
            e.stopPropagation();
            dropContainer.style.display = 'none';

            var files = e.dataTransfer.files;
            if (files.length) {
                // process file(s) being dropped
                // grab the file data from each file
                for (var i = 0, file; file = files[i]; i++) {
                    var reader = new FileReader(),
                        filename = file.name;
                    reader.onload = function(e) {
                        _this.loadGeoJsonString(e.target.result, filename);
                    };
                    reader.onerror = function(e) {
                        apex.error('reading failed');
                    };
                    reader.readAsText(file);
                }
            } else {
                // process non-file (e.g. text or html) content being dropped
                // grab the plain text version of the data
                var plainText = e.dataTransfer.getData('text/plain');
                if (plainText) {
                    _this.loadGeoJsonString(plainText);
                }
            }

            // prevent drag event from bubbling further
            return false;
        }, false);
    },

	/*
	 *
	 * UTILITIES
	 *
	 */

	_initDebug: function() {
        apex.debug("reportmap._initDebug");
        var _this = this;

        var controlUI = document.createElement('div');
        controlUI.className = 'reportmap-debugPanel';
        controlUI.innerHTML = '[debug mode]';
        this.map.controls[google.maps.ControlPosition.BOTTOM_LEFT].push(controlUI);

        // as mouse is moved over the map, show the current coordinates in the debug panel
        google.maps.event.addListener(this.map, "mousemove", function (event) {
            controlUI.innerHTML = 'mouse position ' + JSON.stringify(event.latLng);
        });

        // as map is panned or zoomed, show the current map bounds in the debug panel
        google.maps.event.addListener(this.map, "bounds_changed", function (event) {
            controlUI.innerHTML = 'map bounds ' + JSON.stringify(_this.map.getBounds());
        });
    },

    _getWindowPath: function() {
        apex.debug("reportmap._getWindowPath");
        
        var path = this.options.pluginResourcePath;
        
        if (path !== "") {
            apex.debug("Using supplied plugin resource path");
        } else {

            path = window.location.origin + window.location.pathname;

            if (path.indexOf("/ords/r/") > -1) {
                // hack to handle hosted cloud instance URL?
                apex.debug("Friendly URL detected (hosted cloud)", path);

                // Expected: https://prefix.adb.eu-frankfurt-1.oraclecloudapps.com/ords/r/hms_fire/appalias/pagealias?session=12345

                // strip off everything including and after the "/r/" bit
                path = path.substring(0, path.lastIndexOf("/r/"));

                // now it is something like:
                // https://prefix.adb.eu-frankfurt-1.oraclecloudapps.com/ords

            } else if (path.indexOf("/r/") > -1) {
                // Friendly URLs in use
                apex.debug("Friendly URL detected", path);

                // Expected: https://apex.oracle.com/pls/apex/jk64/r/jk64_report_map_dev/clustering

                // strip off everything including and after the "/r/" bit
                path = path.substring(0, path.lastIndexOf("/r/"));

                // now it is something like:
                // https://apex.oracle.com/pls/apex/jk64

                // strip off the path prefix
                path = path.substring(0, path.lastIndexOf("/"));

                // now it is something like:
                // https://apex.oracle.com/pls/apex
            } else {
                // Legacy URLs in use
                apex.debug("Legacy URL detected", path);

                // Expected: https://apex.oracle.com/pls/apex/f

                // strip off the "/f" bit
                path = path.substring(0, path.lastIndexOf("/"));

                // now it is something like:
                // https://apex.oracle.com/pls/apex
            }
        }

        apex.debug("path", path);

        return path;
    },

    // add a listener for each Map event that raises a plugin event
    _initMapEvents: function() {
        var _this = this;

        ["bounds_changed"
        ,"center_changed"
        ,"heading_changed"
        ,"idle"
        ,"maptypeid_changed"
        ,"projection_changed"
        ,"tilesloaded"
        ,"tilt_changed"
        ,"zoom_changed"
        ].forEach(function(eventName) {
            apex.debug("add listener for map "+eventName);
            google.maps.event.addListener(_this.map, eventName, function() {
                apex.debug("map "+eventName);
                var bounds = _this.map.getBounds();
                apex.jQuery("#"+_this.options.regionId).trigger("map"+eventName, {
                    map       : _this.map,
                    center    : _this.map.getCenter().toJSON(),
                    southwest : bounds.getSouthWest().toJSON(),
                    northeast : bounds.getNorthEast().toJSON(),
                    zoom      : _this.map.getZoom(),
                    heading   : _this.map.getHeading(),
                    tilt      : _this.map.getTilt(),
                    mapType   : _this.map.getMapTypeId()
                });
            });
        });

        if(this.options.detailedMouseEvents) {

            ["drag"
            ,"dragend"
            ,"dragstart"
            ].forEach(function(eventName) {
                apex.debug("add listener for map "+eventName);
                google.maps.event.addListener(_this.map, eventName, function() {
                    apex.debug("map "+eventName);
                    var bounds = _this.map.getBounds();
                    apex.jQuery("#"+_this.options.regionId).trigger("map"+eventName, {
                        map       : _this.map,
                        center    : _this.map.getCenter().toJSON(),
                        southwest : bounds.getSouthWest().toJSON(),
                        northeast : bounds.getNorthEast().toJSON(),
                        zoom      : _this.map.getZoom(),
                        heading   : _this.map.getHeading(),
                        tilt      : _this.map.getTilt(),
                        mapType   : _this.map.getMapTypeId()
                    });
                });
            });

            // these events get a MapMouseEvent object
            ["contextmenu"
            ,"dblclick"
            ,"mousemove"
            ,"mouseout"
            ,"mouseover"
            ].forEach(function(eventName) {
                apex.debug("add listener for map "+eventName);
                google.maps.event.addListener(_this.map, eventName, function(mapMouseEvent) {
                    apex.debug("map "+eventName, mapMouseEvent.latLng);
                    apex.jQuery("#"+_this.options.regionId).trigger("map"+eventName, {
                        map : _this.map,
                        lat : mapMouseEvent.latLng.lat(),
                        lng : mapMouseEvent.latLng.lng()
                    });
                });
            });

        }

        apex.debug("add listener for map click");
        google.maps.event.addListener(this.map, "click", function (mapMouseEvent) {
            apex.debug("map click", mapMouseEvent.latLng);
            if (_this.options.clickZoomLevel) {
                if (_this.options.panOnClick) {
                    _this.map.panTo(mapMouseEvent.latLng);
                }
                _this.map.setZoom(_this.options.clickZoomLevel);
            }
            apex.jQuery("#"+_this.options.regionId).trigger("mapclick", {
				map : _this.map,
				lat : mapMouseEvent.latLng.lat(),
				lng : mapMouseEvent.latLng.lng()
			});
        });

    },

	/*
	 *
	 * MAIN
	 *
	 */

    // The constructor
    _create: function() {
        apex.debug("reportmap._create", this.element.prop("id"));
        apex.debug(JSON.stringify(this.options));
        var _this = this;

        // get absolute URL for this site, including /apex/ or /ords/ (this is required by some google maps APIs)
        this.imagePrefix = this._getWindowPath() + "/" + this.options.pluginFilePrefix + "images/m";
        apex.debug('imagePrefix', this.imagePrefix);

        var mapOptions = {
            minZoom                : this.options.minZoom,
            maxZoom                : this.options.maxZoom,
            zoom                   : this.options.initialZoom,
            center                 : this.options.initialCenter,
            mapTypeId              : this.options.mapType,
            draggable              : this.options.allowPan,
            zoomControl            : this.options.allowZoom,
            scrollwheel            : this.options.allowZoom,
            disableDoubleClickZoom : !(this.options.allowZoom),
            gestureHandling        : this.options.gestureHandling
        };

        if (this.options.mapStyle) {
            mapOptions.styles = this.options.mapStyle;
        }

        this.map = new google.maps.Map(document.getElementById(this.element.prop("id")),mapOptions);

        if (this.options.visualisation=="infolayer") {
            this.options.showPins = false;
            this.options.showInfoPopups = false;
            this.options.showInfoLayer = true;
        }

        if (this.options.initFn) {
            apex.debug("init_javascript_code running...");
            //inside the init() function we want "this" to refer to this
            this.init=this.options.initFn;
            this.init();
            this.init.delete;
            apex.debug("init_javascript_code finished.");
        }

        this._initFeatures();

        if (this.options.drawingModes) {
            this._initDrawing();
        }

        if (this.options.dragDropGeoJSON) {
            this._initDragDropGeoJSON();
        }

        if (apex.debug.getLevel()>0) {
            this._initDebug();
        }

        if (this.options.expectData) {
            this.refresh();
        }

        this._initMapEvents();

        apex.jQuery("#"+this.options.regionId).bind("apexrefresh",function(){
            $("#map_"+_this.options.regionId).reportmap("refresh");
        });

        // put some useful info in the console log for developers to have fun with
        if (apex.debug.getLevel()>0) {

            // pretty it up (for browsers that support this)
            var console_css = 'font-size:18px;background-color:#0076ff;color:white;line-height:30px;display:block;padding:10px;'
               ,sample_code = '$("#map_' + _this.options.regionId + '").reportmap("instance").map';

            apex.debug("%cThank you for using the jk64 Report Map plugin!\n"
                + "To access the Google Map object on this page, use:\n"
                + sample_code + "\n"
                + "More info: https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki",
                console_css);

        }

        apex.debug("reportmap._create finished");
    },

    _afterRefresh: function() {
        apex.debug("_afterRefresh");

        if (this.spinner) {
            apex.debug("remove spinner");
            this.spinner.remove();
        }

        apex.jQuery("#"+this.options.regionId).trigger("apexafterrefresh");

        // Trigger a callback/event
        this._trigger( "change" );
    },

    _renderPage: function(pData, startRow) {
        apex.debug("_renderPage", startRow);

        if (pData.mapdata) {
            apex.debug("pData.mapdata length:", pData.mapdata.length);

            var errorMsg;

            // render the map data
            if (pData.mapdata.length>0) {

                for (var i = 0; i < pData.mapdata.length; i++) {

                    if (pData.mapdata[i].error) {
                        errorMsg = pData.mapdata[i].error;
                        break;
                    }

                    var row = pData.mapdata[i];

                    if (this.options.visualisation=="heatmap") {
                        // each row is an array [x,y,weight]

                        if(row[0]&&row[1]) {
                            this.bounds.extend({lat:row[0],lng:row[1]});

                            this.weightedLocations.push({
                                location:new google.maps.LatLng(row[0], row[1]),
                                weight:row[2]
                            });
                        }

                    } else if (this.options.visualisation=="geojson") {
                        // the data should have a GeoJson document, along with optional name, id and flex fields
                        // the name, id and flex fields will be added to the geoJson properties
                        // (alternatively, the geojson might already have the properties embedded in it)

                        var properties = {};

                        if (row.n) {
                            properties.name = row.n;
                        }

                        if (row.d) {
                            properties.id = row.d;
                        }

                        if (row.f) {
                            for (var j = 1; j <= 10; j++) {
                                if (row.f["a"+j]) {
                                    //attr01..attr10
                                    properties["attr"+('0'+j).slice(-2)] = row.f["a"+j];
                                }
                            }
                        }

                        $.extend(row.geojson, {"properties":properties});

                        this._loadGeoJson(row.geojson, null, {"idPropertyName":"id"});

                    } else {
                        // each row is a pin info structure with x, y, etc. attributes

                        if(row.x&&row.y) {
                            this.bounds.extend({lat:row.x,lng:row.y});

                            var marker = this._newMarker(row);

                            // put the marker into the array of markers
                            this.markers.push(marker);

                            if (row.d) {
                                // also put the id into the ID Map
                                this.newIdMap.set(row.d, i);
                            }
                        }
                    }
                }

                if (this.options.autoFitBounds) {

                    apex.debug("fitBounds",
                        this.bounds.getSouthWest().toJSON(),
                        this.bounds.getNorthEast().toJSON());

                    this.map.fitBounds(this.bounds);

                }

                this.totalRows += pData.mapdata.length;

            }

            if (errorMsg) {

                apex.debug.error(errorMsg);
                this.showMessage(errorMsg);

                delete this.newIdMap;
                this._afterRefresh();

            } else if ((this.totalRows < this.options.maximumRows)
                && (pData.mapdata.length == this.options.rowsPerBatch)) {
                // get the next page of data

                apex.jQuery("#"+this.options.regionId).trigger(
                    "batchloaded", {
                    map       : this.map,
                    countPins : this.totalRows,
                    southwest : this.bounds.getSouthWest().toJSON(),
                    northeast : this.bounds.getNorthEast().toJSON()
                });

                startRow += this.options.rowsPerBatch;

                var batchSize = this.options.rowsPerBatch;

                // don't exceed the maximum rows
                if (this.totalRows + batchSize > this.options.maximumRows) {
                    batchSize = this.options.maximumRows - this.totalRows;
                }

                var _this = this;

                apex.server.plugin(
                    this.options.ajaxIdentifier,
                    { pageItems : this.options.ajaxItems,
                      x01       : startRow,
                      x02       : batchSize
                    },
                    { dataType : "json",
                      success: function(pData) {
                          apex.debug("next batch received");
                          _this._renderPage(pData, startRow);
                      }
                    });

            } else {
                // no more data to render, finish rendering

                if (this.totalRows == 0) {

                    delete this.idMap;

                    if (this.options.noDataMessage !== "") {
                        apex.debug("show No Data Found infowindow");
                        this.showMessage(this.options.noDataMessage);
                    }

                } else {

                    switch (this.options.visualisation) {
                    case "directions":
                        this._directions();

                        break;
                    case "cluster":
                        // More info: https://developers.google.com/maps/documentation/javascript/marker-clustering

                        if (this.markerClusterer) {
                            apex.debug("markerClusterer.clearMarkers");
                            this.markerClusterer.clearMarkers();
                        }

                        apex.debug("create markerClusterer");
                        this.markerClusterer = new MarkerClusterer(this.map, this.markers, {imagePath:this.imagePrefix});

                        break;
                    case "spiderfier":
                        this._spiderfy();

                        break;
                    case "heatmap":

                        if (this.heatmapLayer) {
                            apex.debug("remove heatmapLayer");
                            this.heatmapLayer.setMap(null);
                            this.heatmapLayer.delete;
                        }

                        this.heatmapLayer = new google.maps.visualization.HeatmapLayer({
                            data        : this.weightedLocations,
                            map         : this.map,
                            dissipating : this.options.heatmapDissipating,
                            opacity     : this.options.heatmapOpacity,
                            radius      : this.options.heatmapRadius
                        });

                        this.weightedLocations.delete;

                        break;
                    }

                }

                apex.jQuery("#"+this.options.regionId).trigger(
                    (this.maploaded?"maprefreshed":"maploaded"), {
                    map       : this.map,
                    countPins : this.totalRows,
                    southwest : this.bounds.getSouthWest().toJSON(),
                    northeast : this.bounds.getNorthEast().toJSON()
                });

                this.maploaded = true;

                // rememember the ID Map for the next refresh
                this.idMap = this.newIdMap;
                delete this.newIdMap;

                this._afterRefresh();
            }

        } else {
            this._afterRefresh();
        }

    },

    // Called when created, or if the refresh event is called
    refresh: function() {
        apex.debug("reportmap.refresh");
        this.hideMessage();
        if (this.options.expectData) {
            apex.jQuery("#"+this.options.regionId).trigger("apexbeforerefresh");

            if (this.options.showSpinner) {
                if (this.spinner) {
                    this.spinner.remove();
                }
                apex.debug("show spinner");
                this.spinner = apex.util.showSpinner($("#"+this.options.regionId));
            }

            var _this = this,
                batchSize = this.options.rowsPerBatch;

            if (this.options.maximumRows < batchSize) {
                batchSize = this.options.maximumRows;
            }

            apex.server.plugin(
                this.options.ajaxIdentifier,
                { pageItems : this.options.ajaxItems,
                  x01       : 1,
                  x02       : batchSize
                },
                { dataType : "json",
                  success: function(pData) {
                      apex.debug("first batch received");

                      _this._removeMarkers();

                      _this.weightedLocations = [];
                      _this.markers = [];
                      _this.bounds = new google.maps.LatLngBounds;

                      // idMap is a data map of id to the data for a pin
                      _this.newIdMap = new Map();

                        if (pData.mapdata&&pData.mapdata[0]&&pData.mapdata[0].error) {

                            _this.showMessage(pData.mapdata[0].error);
                            _this._afterRefresh();

                        } else {

                            _this._renderPage(pData, 1);

                        }
                  }
                });
        } else {
            this._afterRefresh();
        }
    },

    // Events bound via _on are removed automatically
    // revert other modifications here
    _destroy: function() {
        // remove generated elements
        if (this.heatmapLayer) { this.heatmapLayer.remove(); }
        if (this.userpin) { delete this.userpin; }
        if (this.directionsDisplay) { delete this.directionsDisplay; }
        if (this.directionsService) { delete this.directionsService; }
        this._removeMarkers();
        this.hideMessage();
        this.map.remove();
    },

    // _setOptions is called with a hash of all options that are changing
    // always refresh when changing options
    _setOptions: function() {
        // _super and _superApply handle keeping the right this-context
        this._superApply( arguments );
    },

    // _setOption is called for each individual option that is changing
    _setOption: function( key, value ) {
        apex.debug(key, value);

        // dev note: to get a boolean from a value which might be a string
        // ("true" or "false") or already a boolean, we use value+''=='true'
        switch (key) {
        case "clickableIcons":
            this.map.setOptions({clickableIcons:(value+''=='true')});

            break;
        case "disableDefaultUI":
            this.map.setOptions({disableDefaultUI:(value+''=='true')});

            break;
        case "fullscreenControl":
            this.map.setOptions({fullscreenControl:(value+''=='true')});

            break;
        case "heading":
            this.map.setOptions({heading:parseInt(value)});

            break;
        case "keyboardShortcuts":
            this.map.setOptions({keyboardShortcuts:(value+''=='true')});

            break;
        case "mapType":
            this.map.setMapTypeId(value.toLowerCase());
            this._super( key, value );

            break;
        case "mapTypeControl":
            this.map.setOptions({mapTypeControl:(value+''=='true')});

            break;
        case "maxZoom":
            this.map.setOptions({maxZoom:parseInt(value)});
            this._super( key, value );

            break;
        case "minZoom":
            this.map.setOptions({minZoom:parseInt(value)});
            this._super( key, value );

            break;
        case "rotateControl":
            this.map.setOptions({rotateControl:(value+''=='true')});

            break;
        case "scaleControl":
            this.map.setOptions({scaleControl:(value+''=='true')});

            break;
        case "streetViewControl":
            this.map.setOptions({streetViewControl:(value+''=='true')});

            break;
        case "styles":
            this.map.setOptions({styles:value});
            this._super( "mapStyle", value );

            break;
        case "zoomControl":
            this.map.setOptions({zoomControl:(value+''=='true')});

            break;
        case "tilt":
            this.map.setTilt(parseInt(value));

            break;
        case "zoom":
            this.map.setZoom(parseInt(value));

            break;
        default:
            this._super( key, value );
        }
    }

  });

    class MapOverlay extends google.maps.OverlayView {
        constructor(content, options) {
            super();
            this._content = content;
            this._options = options;
        }
        get options() { return this._options; }
        set options(o) { this._options = o; }
        get content() { return this._content; }
        set content(c) { this._content = c; }
        get pos() { return this._options.pos; }
        set pos(p) { this._options.pos = p; }
        get bounds() { return this._options.bounds; }
        set bounds(b) { this._options.bounds = b; }
        get div() { return this._div; }
        onAdd() {
            // this is called when the map's panes are ready and the overlay has been added to the map.
            this._div = document.createElement("div");
            this._div.style.borderStyle = "none";
            this._div.style.borderWidth = "0px";
            this._div.style.position = "absolute";
            this._div.innerHTML = this._content;
            // there are 5 panes we may add content to - refer: https://developers.google.com/maps/documentation/javascript/reference/overlay-view#MapPanes
            const panes = this.getPanes();
            if (this._options.onClickHandler) {
                // overlayMouseTarget (pane 3): overlays that receive DOM events
                // https://stackoverflow.com/questions/3361823/make-custom-overlay-clickable-google-maps-api-v3
                panes.overlayMouseTarget.appendChild(this._div);
                google.maps.OverlayView.preventMapHitsFrom(this._div);
                apex.debug("add listener for overlay click");
                google.maps.event.addDomListener(this._div, "click", this._options.onClickHandler);
            } else {
                // overlayLayer (pane 1): overlays that do not receive DOM events
                panes.overlayLayer.appendChild(this._div);
            }
        }
        draw() {
            if (this._div) {
                const overlayProjection = this.getProjection(),
                      map = this.getMap(),
                      zoom = map.getZoom();
                if ((zoom >= (this._options.minZoom||0)) && (zoom <= (this._options.maxZoom||99))) {
                    if (this._options.bounds) {
                        const sw = overlayProjection.fromLatLngToDivPixel(
                            this._options.bounds.getSouthWest()
                        );
                        const ne = overlayProjection.fromLatLngToDivPixel(
                            this._options.bounds.getNorthEast()
                        );
                        // Resize the div to fit the indicated dimensions.
                        if (this._div) {
                            this._div.style.left = sw.x + "px";
                            this._div.style.top = ne.y + "px";
                            this._div.style.width = (ne.x - sw.x) + "px";
                            this._div.style.height = (sw.y - ne.y) + "px";
                        }
                    } else if (this._options.pos) {
                        const projPos = overlayProjection.fromLatLngToDivPixel(this._options.pos);
                        var offsetX, offsetY;
                        switch(this._options.horizontalAlign.toLowerCase()) {
                        case 'center':
                            offsetX = -this._div.offsetWidth/2;
                            break;
                        case 'right':
                            offsetX = -this._div.offsetWidth;
                            break;
                        default: //left
                            offsetX = 0;
                        }
                        switch(this._options.verticalAlign.toLowerCase()) {
                        case 'bottom':
                            offsetY = -this._div.offsetHeight;
                            break;
                        case 'middle':
                            offsetY = -this._div.offsetHeight/2;
                            break;
                        default: //top
                            offsetY = 0;
                        }
                        offsetX += this._options.horizontalOffset||0;
                        offsetY += this._options.verticalOffset||0;
                        this._div.style.left = (projPos.x + offsetX) + "px";
                        this._div.style.top = (projPos.y + offsetY) + "px";
                    } else {
                        apex.debug("error: unable to show overlay (no pos or bounds defined)");
                    }
                }
            }
        }
        onRemove() {
            if (this._div) {
                this._div.parentNode.removeChild(this._div);
                delete this._div;
            }
        }
        hide() {
            if (this._div) {
                this._div.style.visibility = "hidden";
            }
        }
        show() {
            if (this._div) {
                this._div.style.visibility = "visible";
            }
        }
        toggle() {
            if (this._div) {
                if (this._div.style.visibility === "hidden") {
                    this.show();
                } else {
                    this.hide();
                }
            }
        }
        toggleDOM(map) {
            if (this.getMap()) {
                this.setMap(null);
            } else {
                this.setMap(map);
            }
        }
    }

});