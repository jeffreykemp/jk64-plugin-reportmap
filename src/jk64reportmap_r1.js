//jk64 ReportMap v1.0 Jul 2019

$( function() {
  $.widget( "jk64.reportmap", {
    
    // default options
    options: {
      regionId:"",
      ajaxIdentifier:"",
      ajaxItems:"",
      pluginFilePrefix:"",
      expectData:true,
      initialCenter:{lat:0,lng:0},
      minZoom:1,
      maxZoom:null,
      initialZoom:2,
      southwest:null,
      northeast:null,
      visualisation:"pins",
      mapType:"roadmap",
      clickZoomLevel:null,
      isDraggable:false,
      heatmapDissipating:false,
      heatmapOpacity:0.6,
      heatmapRadius:5,
      panOnClick:true,
      restrictCountry:"",
      mapStyle:"",
      travelMode:"DRIVING",
      optimizeWaypoints:false,
      allowZoom:true,
      allowPan:true,
      gestureHandling:"auto",
      noDataMessage:"No data to show",
      noAddressResults:"Address not found",
      directionsNotFound:"At least one of the origin, destination, or waypoints could not be geocoded.",
      directionsZeroResults:"No route could be found between the origin and destination.",

      // Callbacks
      parseLatLng: null,      //parse a lat,lng string into a google.maps.LatLng
      click: null,            //simulate a click on a marker
      geolocate: null,        //find the user's device location
      gotoAddress: null,      //search by address and place the pin there
      gotoPos: null,          //place the pin at a given position {lat,lng}
      gotoPosByString: null,  //place the pin at a given position (lat,lng provided as a string)
      refresh: null,          //refresh the map (re-run the query)
      getAddressByPos: null,  //get closest address to the given location
      showDirections: null    //show route between two locations
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
    
    _showMessage: function (msg) {
      apex.debug("reportmap._showMessage ");
      var _this = this;
      if (_this.infoWindow) {
        _this.infoWindow.close();
      } else {
        _this.infoWindow = new google.maps.InfoWindow(
          {
            content: msg,
            position: _this.map.getCenter()
          });
      }
      _this.infoWindow.open(_this.map);
    },
    
    _hideMessage: function() {
      apex.debug("reportmap._hideMessage ");
      var _this = this;
      if (_this.infoWindow) {
        _this.infoWindow.close();
      }
    },
    
    _pinData: function (pData, pos) {
      var d = {
        map:this.map,
        id:pData.d,
        name:pData.n,
        lat:pos.lat(),
        lng:pos.lng()
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

    //place a report pin on the map
    _repPin: function (pData) {
      var _this = this;
      var pos = new google.maps.LatLng(pData.x, pData.y);
      var reppin = new google.maps.Marker({
            map: _this.map,
            position: pos,
            title: pData.n,
            icon: pData.c,
            label: pData.l,
            draggable: _this.options.isDraggable                                                                        
          });
      google.maps.event.addListener(reppin, "click", function () {
        apex.debug("repPin "+pData.d+" clicked");
        var pos = this.getPosition();
        if (pData.i) {
          //show info window for this pin
          if (_this.iw) {
            _this.iw.close();
          } else {
            _this.iw = new google.maps.InfoWindow();
          }
          _this.iw.setOptions({ content: pData.i });
          _this.iw.open(_this.map, this);
        }
        if (_this.options.panOnClick) {
          _this.map.panTo(pos);
        }
        if (_this.options.clickZoomLevel) {
          _this.map.setZoom(_this.options.clickZoomLevel);
        }
        apex.jQuery("#"+_this.options.regionId).trigger("markerclick", _this._pinData(pData, pos));	
      });
      google.maps.event.addListener(reppin, "dragend", function () {
        var pos = this.getPosition();
        apex.debug("repPin "+pData.d+" moved to position ("+pos.lat()+","+pos.lng()+")");
        apex.jQuery("#"+_this.options.regionId).trigger("markerdrag", _this._pinData(pData, pos));
      });
      if (!_this.reppin) { _this.reppin=[]; }
      _this.reppin.push({"id":pData.d,"marker":reppin});
      return reppin;
    },

    //put all the report pins on the map, or show the "no data found" message
    _repPins: function () {
      apex.debug("reportmap._repPins");
      var _this = this;
      if (_this.mapdata) {
        if (_this.mapdata.length>0) {
          _this._hideMessage();
          var marker, markers = [];
          for (var i = 0; i < _this.mapdata.length; i++) {
            if (_this.options.visualisation=="heatmap") {
              markers.push({
                location:new google.maps.LatLng(_this.mapdata[i].x, _this.mapdata[i].y),
                weight:_this.mapdata[i].d
              });
            } else {
              marker = _this._repPin(_this.mapdata[i]);
              if (_this.options.visualisation=="cluster") {
                markers.push(marker);
              }
            }
          }
          if (_this.options.visualisation=="cluster") {
            // Add a marker clusterer to manage the markers.
            // More info: https://developers.google.com/maps/documentation/javascript/marker-clustering
            var markerCluster = new MarkerClusterer(_this.map, markers,{imagePath:_this.imagePrefix});
          } else if (_this.options.visualisation=="heatmap") {
            if (_this.heatmapLayer) {
              apex.debug("remove heatmapLayer");
              _this.heatmapLayer.setMap(null);
              _this.heatmapLayer.delete;
              _this.heatmapLayer = null;
            }
            _this.heatmapLayer = new google.maps.visualization.HeatmapLayer({
              data: markers,
              map: _this.map,
              dissipating: _this.options.heatmapDissipating,
              opacity: _this.options.heatmapOpacity,
              radius: _this.options.heatmapRadius
            });
          }
        } else {
          if (_this.options.noDataMessage !== "") {
            apex.debug("show No Data Found infowindow");
            _this._showMessage(_this.options.noDataMessage);
          }
        }
      }
    },

    _removePins: function() {
      apex.debug("reportmap._removePins");
      var _this = this;
      if (_this.reppin) {
        for (var i = 0; i < _this.reppin.length; i++) {
          _this.reppin[i].marker.setMap(null);
        }
        _this.reppin.delete;
      }
    },

    //place or move the user pin to the given location
    gotoPos: function (lat,lng) {
      apex.debug("reportmap.gotoPos");
      var _this = this;
      if (lat!==null && lng!==null) {
        var oldpos = _this.userpin?_this.userpin.getPosition():(new google.maps.LatLng(0,0));
        if (oldpos && lat==oldpos.lat() && lng==oldpos.lng()) {
          apex.debug("userpin not changed");
        } else {
          var pos = new google.maps.LatLng(lat,lng);
          if (_this.userpin) {
            apex.debug("move existing pin to new position on map "+lat+","+lng);
            _this.userpin.setMap(_this.map);
            _this.userpin.setPosition(pos);
          } else {
            apex.debug("create userpin "+lat+","+lng);
            _this.userpin = new google.maps.Marker({map: _this.map, position: pos});
          }
        }
      } else if (_this.userpin) {
        apex.debug("move existing pin off the map");
        _this.userpin.setMap(null);
      }
    },

    //parse the given string as a lat,long pair, put a pin at that location
    gotoPosByString: function (v) {
      apex.debug("reportmap.gotoPosByString");
      var _this = this;
      var latlng = _this.parseLatLng(v);
      if (latlng) {
        _this.gotoPos(latlng.lat(),latlng.lng());
      }
    },

    //search the map for an address; if found, put a pin at that location and raise addressfound trigger
    gotoAddress: function (addressText) {
      apex.debug("reportmap.gotoAddress");
      var _this = this;
      var geocoder = new google.maps.Geocoder;
      _this._hideMessage();
      geocoder.geocode(
        {address: addressText
        ,componentRestrictions: _this.options.restrictCountry!==""?{country:_this.options.restrictCountry}:{}
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
            map:_this.map,
            lat:pos.lat(),
            lng:pos.lng(),
            result:results[0]
          });
        } else {
          apex.debug("Geocoder failed: "+status);
        }
      });
    },

    //call this to simulate a mouse click on the report pin for the given id value
    //e.g. this will show the info window for the given report pin and trigger the markerclick event
    click: function (id) {
      apex.debug("reportmap.click");
      var _this = this;
      var found = false;
      for (var i = 0; i < _this.reppin.length; i++) {
        if (_this.reppin[i].id==id) {
          new google.maps.event.trigger(_this.reppin[i].marker,"click");
          found = true;
          break;
        }
      }
      if (!found) {
        apex.debug("id not found:"+id);
      }
    },

    //get the closest address to a given location by lat/long
    getAddressByPos: function (lat,lng) {
      apex.debug("reportmap.getAddressByPos");
      var _this = this;
      var latlng = {lat: lat, lng: lng};
      var geocoder = new google.maps.Geocoder;
      _this._hideMessage();
      geocoder.geocode({'location': latlng}, function(results, status) {
        if (status === google.maps.GeocoderStatus.OK) {
          if (results[0]) {
            apex.debug("addressfound '"+results[0].formatted_address+"'");
            var components = results[0].address_components;
            for (i=0; i<components.length; i++) {
              apex.debug("result[0] "+components[i].types+"="+components[i].short_name+" ("+components[i].long_name+")");
            }
            apex.jQuery("#"+_this.options.regionId).trigger("addressfound", {
              map:_this.map,
              lat:lat,
              lng:lng,
              result:results[0]
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
      var _this = this;
      if (navigator.geolocation) {
        apex.debug("geolocate");
        navigator.geolocation.getCurrentPosition(function(position) {
          var pos = {
            lat: position.coords.latitude,
            lng: position.coords.longitude
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

    //this is called when directions are requested
    _directionsResponse: function (response,status) {
      apex.debug("reportmap._directionsResponse "+status);
      var _this = this;
      if (status == google.maps.DirectionsStatus.OK) {
        _this.directionsDisplay.setDirections(response);
        var totalDistance = 0, totalDuration = 0, legCount = 0;
        for (var i=0; i < response.routes.length; i++) {
          legCount = legCount + response.routes[i].legs.length;
          for (var j=0; j < response.routes[i].legs.length; j++) {
            var leg = response.routes[i].legs[j];
            totalDistance = totalDistance + leg.distance.value;
            totalDuration = totalDuration + leg.duration.value;
          }
        }
        apex.jQuery("#"+this.options.regionId).trigger("directions",{
          map:_this.map,
          distance:totalDistance,
          duration:totalDuration,
          legs:legCount
        });
      } else if (status == google.maps.DirectionsStatus.NOT_FOUND) {
        _this._showMessage(_this.options.directionsNotFound);
      } else if (status == google.maps.DirectionsStatus.ZERO_RESULTS) {
        _this._showMessage(_this.options.directionsZeroResults);
      } else {
        apex.debug("Directions request failed: "+status);
      }
    },
    
    //show simple route between two points
    showDirections: function (origin, destination, travelMode = "DRIVING") {
      apex.debug("reportmap.showDirections");
      var _this = this;
      _this.origin = origin;
      _this.destination = destination;
      _this._hideMessage();
      if (_this.origin&&_this.destination) {
        if (!_this.directionsDisplay) {
          _this.directionsDisplay = new google.maps.DirectionsRenderer;
          _this.directionsService = new google.maps.DirectionsService;
          _this.directionsDisplay.setMap(_this.map);
        }
        //simple directions between two locations
        _this.origin = _this.parseLatLng(_this.origin)||_this.origin;
        _this.destination = _this.parseLatLng(_this.destination)||_this.destination;
        if (_this.origin !== "" && _this.destination !== "") {
          _this.directionsService.route({
            origin:_this.origin,
            destination:_this.destination,
            travelMode:google.maps.TravelMode[travelMode]
          }, function(response,status){_this._directionsResponse(response,status)});
        } else {
          apex.debug("No directions to show - need both origin and destination location");
        }
      } else {
        apex.debug("Unable to show directions: no data, no origin/destination");
      }
    },

    //directions visualisation based on query data
    _directions: function () {
      apex.debug("reportmap._directions");
      var _this = this;
      if (_this.mapdata) {
        apex.debug("route "+_this.mapdata.length+" waypoints");
        if (_this.mapdata.length>1) {
          var origin
             ,dest;
          if (!_this.directionsDisplay) {
            _this.directionsDisplay = new google.maps.DirectionsRenderer;
            _this.directionsService = new google.maps.DirectionsService;
            _this.directionsDisplay.setMap(_this.map);
          }
          var waypoints = [], latLng;
          for (var i = 0; i < _this.mapdata.length; i++) {
            latLng = new google.maps.LatLng(_this.mapdata[i].x, _this.mapdata[i].y);
            if (i == 0) {
              origin = latLng;
            } else if (i == _this.mapdata.length-1) {
              dest = latLng;
            } else {
              waypoints.push({
                location: latLng,
                stopover: true
              });
            }
          }
          apex.debug("origin="+origin+" dest="+dest+" waypoints:"+waypoints.length+" via:"+_this.options.travelMode);
          _this.directionsService.route({
            origin:origin,
            destination:dest,
            waypoints:waypoints,
            optimizeWaypoints:_this.options.optimizeWaypoints,
            travelMode:google.maps.TravelMode[_this.options.travelMode]
          }, function(response,status){_this._directionsResponse(response,status)});
        } else {
          apex.debug("not enough waypoints - need at least an origin and a destination point");
        }
      } else {
        apex.debug("Unable to show directions: no data");
      }
    },

    // The constructor
    _create: function() {
      var _this = this;
      apex.debug("reportmap._create "+_this.element.prop("id"));
      apex.debug("options: "+JSON.stringify(_this.options));
      // get absolute URL for this site, including /apex/ or /ords/ (this is required by some google maps APIs)
      var filePath = window.location.origin + window.location.pathname;
      filePath = filePath.substring(0, filePath.lastIndexOf("/"));
      _this.imagePrefix = filePath + "/" + _this.options.pluginFilePrefix + "images/m";
      apex.debug('_this.imagePrefix="'+_this.imagePrefix+'"');
      var myOptions = {
        minZoom: _this.options.minZoom,
        maxZoom: _this.options.maxZoom,
        zoom: _this.options.initialZoom,
        center: _this.options.initialCenter,
        mapTypeId: _this.mapType,
        draggable: _this.options.allowPan,
        zoomControl: _this.options.allowZoom,
        scrollwheel: _this.options.allowZoom,
        disableDoubleClickZoom: !(_this.options.allowZoom),
        gestureHandling: _this.options.gestureHandling
      };
      if (_this.options.mapStyle) {
        myOptions["styles"] = _this.options.mapStyle;
      }
      _this.map = new google.maps.Map(document.getElementById(_this.element.prop("id")),myOptions);
      if (_this.options.southwest&&_this.options.northeast) {
        _this.map.fitBounds(new google.maps.LatLngBounds(_this.options.southwest,_this.options.northeast));
      }
      google.maps.event.addListener(_this.map, "click", function (event) {
        var lat = event.latLng.lat()
           ,lng = event.latLng.lng();
        apex.debug("map clicked "+lat+","+lng);
        if (_this.options.clickZoomLevel) {
          apex.debug("pan+zoom");
          if (_this.options.panOnClick) {
            _this.map.panTo(event.latLng);
          }
          _this.map.setZoom(_this.options.clickZoomLevel);
        }
        apex.jQuery("#"+_this.options.regionId).trigger("mapclick", {map:_this.map, lat:lat, lng:lng});
      });
      apex.jQuery("#"+_this.options.regionId).trigger("maploaded", {map:_this.map});
      if (_this.options.expectData) {
        _this.refresh();
      }
      apex.debug("reportmap.init finished");
    },
    
    // Called when created, and later when changing options
    refresh: function() {
      apex.debug("reportmap.refresh");
      var _this = this;
      _this._hideMessage();
      if (_this.options.expectData) {
        apex.jQuery("#"+_this.options.regionId).trigger("apexbeforerefresh");
        apex.server.plugin
          (_this.options.ajaxIdentifier
          ,{ pageItems: _this.options.ajaxItems }
          ,{ dataType: "json"
            ,success: function( pData ) {
              apex.debug("success pData="+pData.southwest.lat+","+pData.southwest.lng+" "+pData.northeast.lat+","+pData.northeast.lng);
              if (pData.southwest.lat&&pData.southwest.lng&&pData.northeast.lat&&pData.northeast.lng) {
                _this.map.fitBounds(
                  {south:pData.southwest.lat
                  ,west: pData.southwest.lng
                  ,north:pData.northeast.lat
                  ,east: pData.northeast.lng});
              }
              if (_this.iw) {
                _this.iw.close();
              }
              _this._removePins();
              apex.debug("pData.mapdata.length="+pData.mapdata.length);
              _this.mapdata = pData.mapdata;
              _this._repPins();
              if (_this.options.visualisation=="directions") {
                _this._directions();
              }
              apex.jQuery("#"+_this.options.regionId).trigger("apexafterrefresh");
            }
          } );
      }
      apex.debug("reportmap.refresh finished");
      // Trigger a callback/event
      _this._trigger( "change" );
    },

    // Events bound via _on are removed automatically
    // revert other modifications here
    _destroy: function() {
      // remove generated elements
      var _this = this;
      if (_this.heatmapLayer) {
        _this.heatmapLayer.remove();
      }
      if (_this.iw) {
        _this.iw.close();
      }
      _this._removePins();
      _this.map.remove();
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