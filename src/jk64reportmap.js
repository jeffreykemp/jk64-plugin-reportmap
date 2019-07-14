//jk64 ReportMap v1.0 Jul 2019

$( function() {
  // widget definition
  $.widget( "jk64.reportmap", {
    
    // default options
    options: {
      regionId:"",
      ajaxIdentifier:"",
      ajaxItems:"",
      pluginFilePrefix:"",
      expectData:true,
      visualisation:"pins",
      maptype:"",
      latlng:"",
      markerZoom:null,
      isDraggable:false,
      dissipating:false,
      opacity:0.6,
      radius:5,
      panOnClick:false,
      country:"",
      southwest:{lat:-60,lng:-180},
      northeast:{lat:70,lng:180},
      mapstyle:"",
      noDataMessage:"No data to show",
      directions:"",
      optimizeWaypoints:false,
      originItem:"",
      destItem:"",
      zoom:true,
      pan:true,
      gestureHandling:"auto",

      // Callbacks
      parseLatLng: null,
      gotoPos: null,
      gotoPosByString: null,
      gotoAddress: null,
      click: null,
      searchAddress: null,
      geolocate: null
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
    parseLatLng : function (v) {
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

    //place a report pin on the map
    _repPin : function (pData) {
      var _this = this;
      var pos = new google.maps.LatLng(pData.lat, pData.lng);
      var reppin = new google.maps.Marker({
            map: _this.map,
            position: pos,
            title: pData.name,
            icon: pData.icon,
            label: pData.label,
            draggable: _this.options.isDraggable                                                                        
          });
      google.maps.event.addListener(reppin, "click", function () {
        apex.debug("repPin "+pData.id+" clicked");
        if (pData.info) {
          if (_this.iw) {
            _this.iw.close();
          } else {
            _this.iw = new google.maps.InfoWindow();
          }
          _this.iw.setOptions({
             content: pData.info
            });
          _this.iw.open(_this.map, this);
        }
        if (_this.options.panOnClick) {
          _this.map.panTo(this.getPosition());
        }
        if (_this.options.markerZoom) {
          _this.map.setZoom(_this.options.markerZoom);
        }
        apex.jQuery("#"+_this.options.regionId).trigger("markerclick", {
          map:_this.map,
          id:pData.id,
          name:pData.name,
          lat:pData.lat,
          lng:pData.lng
        });	
      });
      google.maps.event.addListener(reppin, "dragend", function () {
        var pos = this.getPosition();
        apex.debug("repPin "+pData.id+" moved to position ("+pos.lat()+","+pos.lng()+")");
        apex.jQuery("#"+_this.options.regionId).trigger("markerdrag", {
          map:_this.map,
          id:pData.id,
          name:pData.name,
          lat:pos.lat(),
          lng:pos.lng()
        });	
      });
      if (!_this.reppin) { _this.reppin=[]; }
      _this.reppin.push({"id":pData.id,"marker":reppin});
      return reppin;
    },

    //put all the report pins on the map, or show the "no data found" message
    _repPins : function () {
      apex.debug("reportmap.repPins");
      var _this = this;
      if (_this.mapdata) {
        if (_this.mapdata.length>0) {
          if (_this.infoNoDataFound) {
            apex.debug("hide No Data Found infowindow");
            _this.infoNoDataFound.close();
          }
          var marker, markers = [];
          for (var i = 0; i < _this.mapdata.length; i++) {
            if (_this.options.visualisation=="heatmap") {
              markers.push({
                location:new google.maps.LatLng(_this.mapdata[i].a, _this.mapdata[i].b),
                weight:_this.mapdata[i].c
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
              apex.debug("hide heatmapLayer");
              _this.heatmapLayer.setMap(null);
              apex.debug("remove heatmapLayer");
              _this.heatmapLayer.delete;
              _this.heatmapLayer = null;
            }
            _this.heatmapLayer = new google.maps.visualization.HeatmapLayer({
              data: markers,
              map: _this.map,
              dissipating: _this.options.dissipating,
              opacity: _this.options.opacity,
              radius: _this.options.radius
            });
          }
        } else {
          if (_this.options.noDataMessage !== "") {
            apex.debug("show No Data Found infowindow");
            if (_this.infoNoDataFound) {
              _this.infoNoDataFound.close();
            } else {
              _this.infoNoDataFound = new google.maps.InfoWindow(
                {
                  content: _this.options.noDataMessage,
                  position: _this.parseLatLng(_this.options.latlng)
                });
            }
            _this.infoNoDataFound.open(_this.map);
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
    gotoPos : function (lat,lng) {
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
    gotoPosByString : function (v) {
      apex.debug("reportmap.gotoPosByString");
      var _this = this;
      var latlng = _this.parseLatLng(v);
      if (latlng) {
        apex.debug("item changed "+latlng.lat()+" "+latlng.lng());
        _this.gotoPos(latlng.lat(),latlng.lng());
      }
    },

    //search the map for an address; if found, put a pin at that location and raise addressfound trigger
    gotoAddress : function (addressText) {
      apex.debug("reportmap.gotoAddress");
      var _this = this;
      var geocoder = new google.maps.Geocoder;
      geocoder.geocode(
        {address: addressText
        ,componentRestrictions: _this.options.country!==""?{country:_this.options.country}:{}
      }, function(results, status) {
        if (status === google.maps.GeocoderStatus.OK) {
          var pos = results[0].geometry.location;
          apex.debug("geocode ok");
          _this.map.setCenter(pos);
          _this.map.panTo(pos);
          if (_this.options.markerZoom) {
            _this.map.setZoom(_this.options.markerZoom);
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
          apex.debug("geocode was unsuccessful for the following reason: "+status);
        }
      });
    },

    //call this to simulate a mouse click on the report pin for the given id value
    //e.g. this will show the info window for the given report pin and trigger the markerclick event
    click : function (id) {
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

    //search for the address at a given location by lat/long
    searchAddress : function (lat,lng) {
      apex.debug("reportmap.searchAddress");
      var _this = this;
      var latlng = {lat: lat, lng: lng};
      var geocoder = new google.maps.Geocoder;
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
            apex.debug("searchAddress: No results found");
            window.alert('No results found');
          }
        } else {
          apex.debug("Geocoder failed due to: " + status);
          window.alert("Geocoder failed due to: " + status);
        }
      });
    },

    //search for the user device's location if possible
    geolocate : function () {
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
    _directionsresp : function (response,status) {
      apex.debug("reportmap._directionsresp");
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
      } else {
        apex.debug("Directions request failed due to "+status);
        window.alert("Directions request failed due to "+status);
      }
    },

    //show directions on the map
    _directions : function () {
      apex.debug("reportmap._directions "+this.options.directions);
      var _this = this;
      var origin
         ,dest
         ,routeindex = _this.options.directions.indexOf("-ROUTE")
         ,travelmode;
      if (routeindex<0) {
        //simple directions between two items
        origin = $v(_this.options.originItem);
        dest   = $v(_this.options.destItem);
        origin = _this.parseLatLng(origin)||origin;
        dest   = _this.parseLatLng(dest)||dest;
        if (origin !== "" && dest !== "") {
          travelmode = _this.options.directions;
          _this.directionsService.route({
            origin:origin,
            destination:dest,
            travelMode:google.maps.TravelMode[travelmode]
          }, function(response,status){_this._directionsresp(response,status)});
        }
      } else {
        //route via waypoints
        travelmode = _this.options.directions.slice(0,routeindex);
        apex.debug("route via "+travelmode+" with "+_this.mapdata.length+" waypoints");
        var waypoints = [];
        for (var i = 0; i < _this.mapdata.length; i++) {
          if (i == 0) {
            origin = new google.maps.LatLng(_this.mapdata[i].lat, _this.mapdata[i].lng);
          } else if (i == _this.mapdata.length-1) {
            dest = new google.maps.LatLng(_this.mapdata[i].lat, _this.mapdata[i].lng);
          } else {
            waypoints.push({
              location: new google.maps.LatLng(_this.mapdata[i].lat, _this.mapdata[i].lng),
              stopover: true
            });
          }
        }
        apex.debug("origin="+origin+" dest="+dest+" waypoints:"+waypoints.length);
        _this.directionsService.route({
          origin:origin,
          destination:dest,
          waypoints:waypoints,
          optimizeWaypoints:this.options.optimizeWaypoints,
          travelMode:google.maps.TravelMode[travelmode]
        }, function(response,status){_this._directionsresp(response,status)});
      }
    },

    // The constructor
    _create: function() {
      apex.debug("reportmap._create "+this.element.prop("id"));
      var _this = this;
      var myOptions = {
        zoom: 1,
        center: _this.parseLatLng(_this.options.latlng),
        mapTypeId: _this.maptype
      };
      // get absolute URL for this site, including /apex/ or /ords/ (this is required by some google maps APIs)
      var filePath = window.location.origin + window.location.pathname;
      filePath = filePath.substring(0, filePath.lastIndexOf("/"));
      _this.imagePrefix = filePath + "/" + _this.options.pluginFilePrefix + "images/m";
      apex.debug('_this.imagePrefix="'+_this.imagePrefix+'"');
      _this.map = new google.maps.Map(document.getElementById(_this.element.prop("id")),myOptions);
      _this.map.setOptions({
           draggable: _this.options.pan
          ,zoomControl: _this.options.zoom
          ,scrollwheel: _this.options.zoom
          ,disableDoubleClickZoom: !(_this.options.zoom)
          ,gestureHandling: _this.options.gestureHandling
        });
      if (_this.mapstyle) {
        _this.map.setOptions({styles: _this.mapstyle});
      }
      _this.map.fitBounds(new google.maps.LatLngBounds(_this.options.southwest,_this.options.northeast));
      if (_this.options.directions) {
        //directions is DRIVING-ROUTE, WALKING-ROUTE, BICYCLING-ROUTE, TRANSIT-ROUTE,
        //              DRIVING, WALKING, BICYCLING, or TRANSIT
        _this.directionsDisplay = new google.maps.DirectionsRenderer;
        _this.directionsService = new google.maps.DirectionsService;
        _this.directionsDisplay.setMap(_this.map);
        //if the origin or dest item is changed for simple directions, recalc the directions
        if (_this.options.directions.indexOf("-ROUTE")<0) {
          $("#"+_this.options.originItem).change(function(){
            _this._directions();
          });
          $("#"+_this.options.destItem).change(function(){
            _this._directions();
          });
        }
      }
      google.maps.event.addListener(_this.map, "click", function (event) {
        var lat = event.latLng.lat()
           ,lng = event.latLng.lng();
        apex.debug("map clicked "+lat+","+lng);
        if (_this.options.markerZoom) {
          apex.debug("pan+zoom");
          if (_this.options.panOnClick) {
            _this.map.panTo(event.latLng);
          }
          _this.map.setZoom(_this.options.markerZoom);
        }
        apex.jQuery("#"+_this.options.regionId).trigger("mapclick", {map:_this.map, lat:lat, lng:lng});
      });
      apex.debug("reportmap.init finished");
      apex.jQuery("#"+_this.options.regionId).trigger("maploaded", {map:_this.map});
      if (_this.options.expectData) {
        _this._refresh();
      }
    },
    
          // Called when created, and later when changing options
    _refresh: function() {
      apex.debug("reportmap._refresh");
      var _this = this;
      if (_this.options.expectData) {
        apex.jQuery("#"+_this.options.regionId).trigger("apexbeforerefresh");
        apex.server.plugin
          (_this.options.ajaxIdentifier
          ,{ pageItems: _this.options.ajaxItems }
          ,{ dataType: "json"
            ,success: function( pData ) {
              apex.debug("success pData="+pData.southwest.lat+","+pData.southwest.lng+" "+pData.northeast.lat+","+pData.northeast.lng);
              _this.map.fitBounds(
                {south:pData.southwest.lat
                ,west: pData.southwest.lng
                ,north:pData.northeast.lat
                ,east: pData.northeast.lng});
              if (_this.iw) {
                _this.iw.close();
              }
              _this._removePins();
              apex.debug("pData.mapdata.length="+pData.mapdata.length);
              _this.mapdata = pData.mapdata;
              _this._repPins();
              if (_this.options.directions) {
                _this._directions();
              }
              apex.jQuery("#"+_this.options.regionId).trigger("apexafterrefresh");
            }
          } );
      }
      apex.debug("reportmap._refresh finished");
      // Trigger a callback/event
      _this._trigger( "change" );
    },

    // Events bound via _on are removed automatically
    // revert other modifications here
    _destroy: function() {
      // remove generated elements
      if (this.heatmapLayer) {
        this.heatmapLayer.remove();
      }
      this._removePins();
      this.map.remove();
    },

    // _setOptions is called with a hash of all options that are changing
    // always refresh when changing options
    _setOptions: function() {
      // _super and _superApply handle keeping the right this-context
      this._superApply( arguments );
      this._refresh();
    },

    // _setOption is called for each individual option that is changing
    _setOption: function( key, value ) {
      this._super( key, value );
    }      

  });
});