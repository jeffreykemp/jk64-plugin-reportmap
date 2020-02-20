//jk64 ReportMap v1.1 Jan 2020

$( function() {
  $.widget( "jk64.reportmap", {

    // default options
    options: {
        regionId               : "",
        ajaxIdentifier         : "",
        ajaxItems              : "",
        pluginFilePrefix       : "",
        expectData             : true,
        initialCenter          : {lat:0,lng:0},
        minZoom                : 1,
        maxZoom                : null,
        initialZoom            : 2,
        southwest              : null,
        northeast              : null,
        visualisation          : "pins",
        mapType                : "roadmap",
        clickZoomLevel         : null,
        isDraggable            : false,
        heatmapDissipating     : false,
        heatmapOpacity         : 0.6,
        heatmapRadius          : 5,
        panOnClick             : true,
        restrictCountry        : "",
        mapStyle               : "",
        travelMode             : "DRIVING",
        optimizeWaypoints      : false,
        allowZoom              : true,
        allowPan               : true,
        gestureHandling        : "auto",
        initFn                 : null,
        drawingModes           : null,
        featureColor           : '#cc66ff',
        featureColorSelected   : '#ff6600',
        dragDropGeoJSON        : false,
		autoFitBounds          : true,
        noDataMessage          : "No data to show",
        noAddressResults       : "Address not found",
        directionsNotFound     : "At least one of the origin, destination, or waypoints could not be geocoded.",
        directionsZeroResults  : "No route could be found between the origin and destination.",

        // Callbacks
        click                  : null, //simulate a click on a marker
        deleteAllFeatures      : null, //delete all features (drawing manager)
        deleteSelectedFeatures : null, //delete selected features (drawing manager)
        geolocate              : null, //find the user's device location
        getAddressByPos        : null, //get closest address to the given location
        gotoAddress            : null, //search by address and place the pin there
        gotoPos                : null, //place the pin at a given position {lat,lng}
        gotoPosByString        : null, //place the pin at a given position (lat,lng provided as a string)
        loadGeoJsonString      : null, //load features from a GeoJSON document
        parseLatLng            : null, //parse a lat,lng string into a google.maps.LatLng
        refresh                : null, //refresh the map (re-run the query)
        showDirections         : null, //show route between two locations
		showInfoWindow         : null  //set and show info window (popup) for a pin
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
    parseLatLng: function (v) {
        apex.debug("reportmap.parseLatLng "+v);
        var pos;
        if (v !== null && v !== undefined) {
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
                apex.debug("parsed "+arr[0]+" "+arr[1]);
                pos = new google.maps.LatLng(parseFloat(arr[0]),parseFloat(arr[1]));
            } else {
                apex.debug('no LatLng found in "'+v+'"');
            }
        }
        return pos;
    },

	/*
	 *
	 * MESSAGE POPUP
	 *
	 */
    
    _showMessage: function (msg) {
        apex.debug("reportmap._showMessage '"+msg+"'");
        if (!this.infoWindow) {
            this.infoWindow = new google.maps.InfoWindow();
        }
		this.infoWindow.setContent(msg);
		this.infoWindow.setPosition(this.map.getCenter());
        this.infoWindow.open(this.map);
    },
    
    _hideMessage: function() {
        apex.debug("reportmap._hideMessage ");
        if (this.infoWindow) {
            this.infoWindow.close();
        }
    },

	/*
	 *
	 * REPORT PINS
	 *
	 */
    
    _pinData: function (pData, marker) {
        //get pin data for passing to an event handler
        var d = {
            map    : this.map,
            id     : pData.d,
            name   : pData.n,
            lat    : marker.position.lat(),
            lng    : marker.position.lng(),
			marker : marker
        };
        if (pData.f) {
            if (pData.f.a1) { d["attr01"] = pData.f.a1; }
            if (pData.f.a2) { d["attr02"] = pData.f.a2; }
            if (pData.f.a3) { d["attr03"] = pData.f.a3; }
            if (pData.f.a4) { d["attr04"] = pData.f.a4; }
            if (pData.f.a5) { d["attr05"] = pData.f.a5; }
            if (pData.f.a6) { d["attr06"] = pData.f.a6; }
            if (pData.f.a7) { d["attr07"] = pData.f.a7; }
            if (pData.f.a8) { d["attr08"] = pData.f.a8; }
            if (pData.f.a9) { d["attr09"] = pData.f.a9; }
            if (pData.f.a10) { d["attr10"] = pData.f.a10; }
        }
        return d;
    },
	
	//show the info window for a pin; set the content for it
	showInfoWindow: function (marker) {
		apex.debug("reportmap.showInfoWindow", marker);
		//show info window for this pin
		if (!this.infoWindow) {
			this.infoWindow = new google.maps.InfoWindow();
		}
		//unescape the html for the info window contents
		var ht = new DOMParser().parseFromString(marker.info, "text/html");
		this.infoWindow.setContent(ht.documentElement.textContent);
		//associate the info window with the marker and show on the map
		this.infoWindow.open(this.map, marker);
	},

    //place a report pin on the map
    _newMarker: function (pinData) {
        var marker = new google.maps.Marker({
              map       : this.map,
              position  : new google.maps.LatLng(pinData.x, pinData.y),
              title     : pinData.n,
              icon      : pinData.c,
              label     : pinData.l,
              draggable : this.options.isDraggable
            });
        //load our own data into the marker
        marker.reportmapId = pinData.d;
		marker.info = pinData.i;
        var _this = this;
        google.maps.event.addListener(marker, "click", function () {
            apex.debug("marker "+pinData.d+" clicked");
            var pos = this.getPosition();
            if (pinData.i) {
				_this.showInfoWindow(this);
            }
            if (_this.options.panOnClick) {
                _this.map.panTo(pos);
            }
            if (_this.options.clickZoomLevel) {
                _this.map.setZoom(_this.options.clickZoomLevel);
            }
            apex.jQuery("#"+_this.options.regionId).trigger("markerclick", _this._pinData(pinData, marker));	
        });
        google.maps.event.addListener(marker, "dragend", function () {
            var pos = this.getPosition();
            apex.debug("marker "+pinData.d+" moved to "+JSON.stringify(pos));
            apex.jQuery("#"+_this.options.regionId).trigger("markerdrag", _this._pinData(pinData, marker));
        });
		if (this.options.visualisation=="pins") {
			// if the marker was not previously shown in the last refresh, raise the marker added event
			if (!this.idMap||!this.idMap.has(pinData.d)) {
				apex.jQuery("#"+_this.options.regionId).trigger("markeradded", _this._pinData(pinData, marker));
			}
		}
        return marker;
    },

    //put all the report pins on the map, or show the "no data found" message
    _showData: function (mapData) {
        apex.debug("reportmap._showData");		
        if (mapData.length>0) {
            this._hideMessage();
            var weightedLocations = [],
			    marker,
				newIdMap;

			this.markers = [];
			
			// idMap is a map of id to the data for a pin
			newIdMap = new Map();
			
            for (var i = 0; i < mapData.length; i++) {
                if (this.options.visualisation=="heatmap") {
                    // each data point is an array [x,y,weight]
                    weightedLocations.push({
                        location:new google.maps.LatLng(mapData[i][0], mapData[i][1]),
                        weight:mapData[i][2]
                    });
                } else {
                    // each data point is a pin info structure with x, y, etc. attributes
					marker = this._newMarker(mapData[i]);
					// put the marker into the array of markers
					this.markers.push(marker);
					// also put the id into the Map
                    newIdMap.set(mapData[i].d, i);
                }
            }

            switch (this.options.visualisation) {
            case "cluster":
                // Add a marker clusterer to manage the markers.
                // More info: https://developers.google.com/maps/documentation/javascript/marker-clustering
                var markerCluster = new MarkerClusterer(this.map, this.markers, {imagePath:this.imagePrefix});
                break;
            case "heatmap":
                if (this.heatmapLayer) {
                    apex.debug("remove heatmapLayer");
                    this.heatmapLayer.setMap(null);
                    this.heatmapLayer.delete;
                    this.heatmapLayer = null;
                }
                this.heatmapLayer = new google.maps.visualization.HeatmapLayer({
                    data        : weightedLocations,
                    map         : this.map,
                    dissipating : this.options.heatmapDissipating,
                    opacity     : this.options.heatmapOpacity,
                    radius      : this.options.heatmapRadius
                });
                break;
            }
			
			// rememember the ID map for the next refresh
			this.idMap = newIdMap;

        } else {
			
			delete this.idMap;
			
            if (this.options.noDataMessage !== "") {
                apex.debug("show No Data Found infowindow");
                this._showMessage(this.options.noDataMessage);
            }
			
        }
    },

    _removeMarkers: function() {
        apex.debug("reportmap._removeMarkers");
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
        var marker = this.markers.find( function(p){ return p.reportmapId==id; });
        if (marker) {
            new google.maps.event.trigger(marker,"click");
        } else {
            apex.debug("id not found:"+id);
        }
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
                    apex.debug("move existing pin to new position on map",lat+","+lng);
                    this.userpin.setMap(this.map);
                    this.userpin.setPosition(pos);
                } else {
                    apex.debug("create userpin",lat+","+lng);
                    this.userpin = new google.maps.Marker({map: this.map, position: pos});
                }
            }
        } else if (this.userpin) {
            apex.debug("move existing pin off the map");
            this.userpin.setMap(null);
        }
    },

    //parse the given string as a lat,long pair, put a pin at that location
    gotoPosByString: function (v) {
        apex.debug("reportmap.gotoPosByString");
        var latlng = this.parseLatLng(v);
        if (latlng) {
            this.gotoPos(latlng.lat(),latlng.lng());
        }
    },

	/*
	 *
	 * GEOCODING
	 *
	 */
	
    //search the map for an address; if found, put a pin at that location and raise addressfound trigger
    gotoAddress: function (addressText) {
        apex.debug("reportmap.gotoAddress");
        var geocoder = new google.maps.Geocoder;
        this._hideMessage();
        var _this = this;
        geocoder.geocode({
            address               : addressText,
            componentRestrictions : _this.options.restrictCountry!==""?{country:_this.options.restrictCountry}:{}
        }, function(results, status) {
            if (status === google.maps.GeocoderStatus.OK) {
                var pos = results[0].geometry.location;
                apex.debug("geocode ok");
                _this.map.setCenter(pos);
                _this.map.panTo(pos);
                if (_this.options.clickZoomLevel) {
                    _this.map.setZoom(_this.options.clickZoomLevel);
                }
                _this.gotoPos(pos.lat(), pos.lng());
                apex.debug("addressfound '"+results[0].formatted_address+"'");
                apex.jQuery("#"+_this.options.regionId).trigger("addressfound", {
                    map    : _this.map,
                    lat    : pos.lat(),
                    lng    : pos.lng(),
                    result : results[0]
                });
            } else {
                apex.debug("Geocoder failed: "+status);
            }
        });
    },

    //get the closest address to a given location by lat/long
    getAddressByPos: function (lat,lng) {
        apex.debug("reportmap.getAddressByPos");
        var geocoder = new google.maps.Geocoder;
        this._hideMessage();
        var _this = this;
        geocoder.geocode({'location': {lat: lat, lng: lng}}, function(results, status) {
            if (status === google.maps.GeocoderStatus.OK) {
                if (results[0]) {
                  apex.debug("addressfound '"+results[0].formatted_address+"'");
                  var components = results[0].address_components;
                  for (i=0; i<components.length; i++) {
                      apex.debug("result[0] "+components[i].types+"="+components[i].short_name+" ("+components[i].long_name+")");
                  }
                  apex.jQuery("#"+_this.options.regionId).trigger("addressfound", {
                      map    : _this.map,
                      lat    : lat,
                      lng    : lng,
                      result : results[0]
                  });
                } else {
                    apex.debug("getAddressByPos: No results found");
                    _this._showMessage(_this.options.noAddressResults);
                }
            } else {
                apex.debug("Geocoder failed: " + status);
            }
        });
    },

    //search for the user device's location if possible
    geolocate: function () {
        apex.debug("reportmap.geolocate");
        if (navigator.geolocation) {
            apex.debug("geolocate");
            var _this = this;
            navigator.geolocation.getCurrentPosition(function(position) {
                var pos = {
                    lat : position.coords.latitude,
                    lng : position.coords.longitude
                };
                _this.map.panTo(pos);
                if (_this.options.geolocateZoom) {
                    _this.map.setZoom(_this.options.geolocateZoom);
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
        apex.debug("reportmap._directionsResponse "+status);
        switch(status) {
        case google.maps.DirectionsStatus.OK:
            this.directionsDisplay.setDirections(response);
            var totalDistance = 0, totalDuration = 0, legCount = 0;
            for (var i=0; i < response.routes.length; i++) {
                legCount = legCount + response.routes[i].legs.length;
                for (var j=0; j < response.routes[i].legs.length; j++) {
                    var leg = response.routes[i].legs[j];
                    totalDistance = totalDistance + leg.distance.value;
                    totalDuration = totalDuration + leg.duration.value;
                }
            }
            var _this = this;
            apex.jQuery("#"+this.options.regionId).trigger("directions",{
                map      : _this.map,
                distance : totalDistance,
                duration : totalDuration,
                legs     : legCount
            });
            break;
        case google.maps.DirectionsStatus.NOT_FOUND:
            this._showMessage(this.options.directionsNotFound);
            break;
        case google.maps.DirectionsStatus.ZERO_RESULTS:
            this._showMessage(this.options.directionsZeroResults);
            break;
        default:
            apex.debug("Directions request failed: "+status);
        }
    },
    
    //show simple route between two points
    showDirections: function (origin, destination, travelMode) {
        apex.debug("reportmap.showDirections");
        this.origin = origin;
        this.destination = destination;
        this._hideMessage();
        if (this.origin&&this.destination) {
            if (!this.directionsDisplay) {
                this.directionsDisplay = new google.maps.DirectionsRenderer;
                this.directionsService = new google.maps.DirectionsService;
                this.directionsDisplay.setMap(this.map);
            }
            //simple directions between two locations
            this.origin = this.parseLatLng(this.origin)||this.origin;
            this.destination = this.parseLatLng(this.destination)||this.destination;
            if (this.origin !== "" && this.destination !== "") {
                var _this = this;
                this.directionsService.route({
                    origin      : this.origin,
                    destination : this.destination,
                    travelMode  : google.maps.TravelMode[travelMode?travelMode:"DRIVING"]
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
    _directions: function (mapData) {
        apex.debug("reportmap._directions "+mapData.length+" waypoints");
        if (mapData.length>1) {
            var origin
               ,dest;
            if (!this.directionsDisplay) {
                this.directionsDisplay = new google.maps.DirectionsRenderer;
                this.directionsService = new google.maps.DirectionsService;
                this.directionsDisplay.setMap(this.map);
            }
            var waypoints = [], latLng;
            for (var i = 0; i < mapData.length; i++) {
                latLng = new google.maps.LatLng(mapData[i].x, mapData[i].y);
                if (i == 0) {
                    origin = latLng;
                } else if (i == mapData.length-1) {
                    dest = latLng;
                } else {
                    waypoints.push({
                        location : latLng,
                        stopover : true
                    });
                }
            }
            apex.debug("origin="+origin+" dest="+dest+" waypoints:"+waypoints.length+" via:"+this.options.travelMode);
            var _this = this;
            this.directionsService.route({
                origin            : origin,
                destination       : dest,
                waypoints         : waypoints,
                optimizeWaypoints : this.options.optimizeWaypoints,
                travelMode        : google.maps.TravelMode[this.options.travelMode]
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
        
        //controlInner.innerHTML = label; // this would be for a text button
        controlUI.appendChild(controlInner);

        // Setup the click event listener
        controlUI.addEventListener('click', callback);
        
        this.map.controls[google.maps.ControlPosition.TOP_CENTER].push(controlDiv);

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
        
        //controlInner.innerHTML = label; // this would be for a text button
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

    },
    
    _addPoint: function(dataLayer, pos) {
        apex.debug("reportmap._addPoint",dataLayer,pos);
        
        dataLayer.add(new google.maps.Data.Feature({
            geometry: new google.maps.Data.Point(pos)
        }));
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
    
    _initDrawing: function() {
        apex.debug("reportmap._initDrawing",this.options.drawingModes);
        var _this = this;
        
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
        var dataLayer = this.map.data;

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
                editable = false;
            if (feature.getProperty('isSelected')) {
                color = _this.options.featureColorSelected;
                // if we're drawing a hole, we don't want to drag/edit the existing feature
                editable = !($("#hole_"+_this.options.regionId).prop("checked"));
            }
            return /** @type {!google.maps.Data.StyleOptions} */({
                fillColor    : color,
                strokeColor  : color,
                strokeWeight : 1,
                draggable    : editable,
                editable     : editable
            });
        });
        
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

        // When the user hovers, tempt them to click by outlining the shape.
        // Call revertStyle() to remove all overrides. This will use the style rules
        // defined in the function passed to setStyle()
        dataLayer.addListener('mouseover', function(event) {
            apex.debug("reportmap.map.data","mouseover",event);
            dataLayer.revertStyle();
            dataLayer.overrideStyle(event.feature, {strokeWeight: 4});
        });

        dataLayer.addListener('mouseout', function(event) {
            apex.debug("reportmap.map.data","mouseout",event);
            dataLayer.revertStyle();
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

	/*
	 *
	 * GEOJSON
	 *
	 */

    loadGeoJsonString : function (geoString) {
        apex.debug("reportmap.loadGeoJsonString");
        if (geoString) {
            var _this = this;
            var geojson = JSON.parse(geoString);
            this.map.data.addGeoJson(geojson);

            //Update a map's viewport to fit each geometry in a dataset
            var bounds = new google.maps.LatLngBounds();
            this.map.data.forEach(function(feature) {
                _this._processPoints(feature.getGeometry(), bounds.extend, bounds);
            });
            this.map.fitBounds(bounds);
            apex.jQuery("#"+this.options.regionId).trigger("loadedgeojson", {map:this.map, geoJson:geojson});
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
                    var reader = new FileReader();
                    reader.onload = function(e) {
                        _this.loadGeoJsonString(e.target.result);
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
	 * DEBUG WINDOW
	 *
	 */

	_initDebug: function() {
        apex.debug("reportmap._initDebug");
        var _this = this;
        
        var controlDiv = document.createElement('div');

        // Set CSS for the control border.
        var controlUI = document.createElement('div');
        controlUI.className = 'reportmap-debugPanel';
        controlUI.innerHTML = '[debug mode]';
        controlDiv.appendChild(controlUI);
        
        this.map.controls[google.maps.ControlPosition.BOTTOM_LEFT].push(controlDiv);
        
        // as mouse is moved over the map, show the current coordinates in the debug panel
        google.maps.event.addListener(this.map, "mousemove", function (event) {
            controlUI.innerHTML = 'mouse position ' + JSON.stringify(event.latLng);
        });

        // as map is panned or zoomed, show the current map bounds in the debug panel
        google.maps.event.addListener(this.map, "bounds_changed", function (event) {
            controlUI.innerHTML = 'map bounds ' + JSON.stringify(_this.map.getBounds());
        });
    },

	/*
	 *
	 * MAIN
	 *
	 */

    // The constructor
    _create: function() {
        apex.debug("reportmap._create "+this.element.prop("id"));
        apex.debug("options: "+JSON.stringify(this.options));
        var _this = this;

        // get absolute URL for this site, including /apex/ or /ords/ (this is required by some google maps APIs)
        var filePath = window.location.origin + window.location.pathname;
        filePath = filePath.substring(0, filePath.lastIndexOf("/"));
        this.imagePrefix = filePath + "/" + this.options.pluginFilePrefix + "images/m";
        apex.debug('this.imagePrefix="'+this.imagePrefix+'"');
        var myOptions = {
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
            myOptions["styles"] = this.options.mapStyle;
        }

        this.map = new google.maps.Map(document.getElementById(this.element.prop("id")),myOptions);

        if (this.options.southwest&&this.options.northeast) {
            this.map.fitBounds(new google.maps.LatLngBounds(this.options.southwest,this.options.northeast));
        }

        google.maps.event.addListener(this.map, "click", function (event) {
            apex.debug("map clicked "+JSON.stringify(event.latLng));
            if (_this.options.clickZoomLevel) {
                apex.debug("pan+zoom");
                if (_this.options.panOnClick) {
                    _this.map.panTo(event.latLng);
                }
                _this.map.setZoom(_this.options.clickZoomLevel);
            }
            apex.jQuery("#"+_this.options.regionId).trigger("mapclick", {
				map : _this.map,
				lat : event.latLng.lat(),
				lng : event.latLng.lng()
			});
        });

        apex.jQuery("#"+this.options.regionId).bind("apexrefresh",function(){
            $("#map_"+_this.options.regionId).reportmap("refresh");
        });

        if (this.options.drawingModes) {
            this._initDrawing();
        }
        
        if (this.options.dragDropGeoJSON) {
            this._initDragDropGeoJSON();
        }
        
        if (apex.debug.getLevel()>0) {
            this._initDebug();
        }

        if (this.options.initFn) {
            apex.debug("running init_javascript_code...");
            //inside the init() function we want "this" to refer to this
            this.init=this.options.initFn;
            this.init();
        }

        if (this.options.expectData) {
            this.refresh();
        }

        apex.debug("reportmap._create finished");
    },
    
    // Called when created, and later when changing options
    refresh: function() {
        apex.debug("reportmap.refresh");
        this._hideMessage();
        if (this.options.expectData) {
            apex.jQuery("#"+this.options.regionId).trigger("apexbeforerefresh");
            var _this = this;
            apex.server.plugin(
                this.options.ajaxIdentifier,
                { pageItems : this.options.ajaxItems },
                { dataType : "json",
                  success: function( pData ) {
                    apex.debug("success southwest="+JSON.stringify(pData.southwest)+" northeast="+JSON.stringify(pData.northeast));
					if (_this.options.autoFitBounds
						&& pData.southwest
						&& pData.northeast) {
						_this.map.fitBounds({
							south : pData.southwest.lat,
							west  : pData.southwest.lng,
							north : pData.northeast.lat,
							east  : pData.northeast.lng
						});
					}
                    if (_this.infoWindow) {
                        _this.infoWindow.close();
                    }
                    _this._removeMarkers();
					if (pData.mapdata) {
						apex.debug("pData.mapdata.length="+pData.mapdata.length);
						_this._showData(pData.mapdata);
						if (_this.options.visualisation=="directions") {
							_this._directions(pData.mapdata);
						}
						apex.jQuery("#"+_this.options.regionId).trigger(
							(_this.maploaded?"maprefreshed":"maploaded"), {
							map       : _this.map,
							countPins : pData.mapdata.length,
							southwest : pData.southwest,
							northeast : pData.northeast
						});
						_this.maploaded = true;
					}
                    apex.jQuery("#"+_this.options.regionId).trigger("apexafterrefresh");
                  }
                });
        }
        apex.debug("reportmap.refresh finished");
        // Trigger a callback/event
        this._trigger( "change" );
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
        this._hideMessage();
        this.map.remove();
    },

    // _setOptions is called with a hash of all options that are changing
    // always refresh when changing options
    _setOptions: function() {
        // _super and _superApply handle keeping the right this-context
        this._superApply( arguments );
        this.refresh();
    },

    // _setOption is called for each individual option that is changing
    _setOption: function( key, value ) {
        this._super( key, value );
    }      

  });
});