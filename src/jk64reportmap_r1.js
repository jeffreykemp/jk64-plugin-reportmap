//jk64 ReportMap v1.1 Nov 2019

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
      initFn:null,
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
      apex.debug("reportmap._showMessage '"+msg+"'");
      if (this.infoWindow) {
        this.infoWindow.close();
      } else {
        this.infoWindow = new google.maps.InfoWindow(
          {
            content: msg,
            position: this.map.getCenter()
          });
      }
      this.infoWindow.open(this.map);
    },
    
    _hideMessage: function() {
      apex.debug("reportmap._hideMessage ");
      if (this.infoWindow) {
        this.infoWindow.close();
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
    _marker: function (pData) {
      var marker = new google.maps.Marker({
            map: this.map,
            position: new google.maps.LatLng(pData.x, pData.y),
            title: pData.n,
            icon: pData.c,
            label: pData.l,
            draggable: this.options.isDraggable
          });
      //load our own data into the marker
      marker.reportmapId = pData.d;
      var _this = this;
      google.maps.event.addListener(marker, "click", function () {
        apex.debug("marker "+pData.d+" clicked");
        var pos = this.getPosition();
        if (pData.i) {
          //show info window for this pin
          if (_this.infoWindow) {
            _this.infoWindow.close();
          } else {
            _this.infoWindow = new google.maps.InfoWindow();
          }
          //unescape the html for the info window contents
          var ht = new DOMParser().parseFromString(pData.i, "text/html");
          _this.infoWindow.setOptions({ content: ht.documentElement.textContent });
          _this.infoWindow.open(_this.map, this);
        }
        if (_this.options.panOnClick) {
          _this.map.panTo(pos);
        }
        if (_this.options.clickZoomLevel) {
          _this.map.setZoom(_this.options.clickZoomLevel);
        }
        apex.jQuery("#"+_this.options.regionId).trigger("markerclick", _this._pinData(pData, pos));	
      });
      google.maps.event.addListener(marker, "dragend", function () {
        var pos = this.getPosition();
        apex.debug("marker "+pData.d+" moved to "+JSON.stringify(pos));
        apex.jQuery("#"+_this.options.regionId).trigger("markerdrag", _this._pinData(pData, pos));
      });
      return marker;
    },

    //put all the report pins on the map, or show the "no data found" message
    _showData: function (mapData) {
      apex.debug("reportmap._showData");
      if (mapData.length>0) {
        this._hideMessage();
        var weightedLocations = [];
        this.markers = [];
        for (var i = 0; i < mapData.length; i++) {
          if (this.options.visualisation=="heatmap") {
            // each data point is an array [x,y,weight]
            weightedLocations.push({
              location:new google.maps.LatLng(mapData[i][0], mapData[i][1]),
              weight:mapData[i][2]
            });
          } else {
            // each data point is a pin info structure with x, y, etc. attributes
            this.markers.push(this._marker(mapData[i]));
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
              data: weightedLocations,
              map: this.map,
              dissipating: this.options.heatmapDissipating,
              opacity: this.options.heatmapOpacity,
              radius: this.options.heatmapRadius
            });
            break;
        }
      } else {
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

    //place or move the user pin to the given location
    gotoPos: function (lat,lng) {
      apex.debug("reportmap.gotoPos "+lat+" "+lng);
      if (lat!==null && lng!==null) {
        var oldpos = this.userpin?this.userpin.getPosition():(new google.maps.LatLng(0,0));
        if (oldpos && lat==oldpos.lat() && lng==oldpos.lng()) {
          apex.debug("userpin not changed");
        } else {
          var pos = new google.maps.LatLng(lat,lng);
          if (this.userpin) {
            apex.debug("move existing pin to new position on map "+lat+","+lng);
            this.userpin.setMap(this.map);
            this.userpin.setPosition(pos);
          } else {
            apex.debug("create userpin "+lat+","+lng);
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

    //search the map for an address; if found, put a pin at that location and raise addressfound trigger
    gotoAddress: function (addressText) {
      apex.debug("reportmap.gotoAddress");
      var geocoder = new google.maps.Geocoder;
      this._hideMessage();
      var _this = this;
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
      if (navigator.geolocation) {
        apex.debug("geolocate");
        var _this = this;
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
            map:_this.map,
            distance:totalDistance,
            duration:totalDuration,
            legs:legCount
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
            origin:this.origin,
            destination:this.destination,
            travelMode:google.maps.TravelMode[travelMode?travelMode:"DRIVING"]
          }, function(response,status){_this._directionsResponse(response,status)});
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
              location: latLng,
              stopover: true
            });
          }
        }
        apex.debug("origin="+origin+" dest="+dest+" waypoints:"+waypoints.length+" via:"+this.options.travelMode);
        var _this = this;
        this.directionsService.route({
          origin:origin,
          destination:dest,
          waypoints:waypoints,
          optimizeWaypoints:this.options.optimizeWaypoints,
          travelMode:google.maps.TravelMode[this.options.travelMode]
        }, function(response,status){_this._directionsResponse(response,status)});
      } else {
        apex.debug("not enough waypoints - need at least an origin and a destination point");
      }
    },

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
        minZoom: this.options.minZoom,
        maxZoom: this.options.maxZoom,
        zoom: this.options.initialZoom,
        center: this.options.initialCenter,
        mapTypeId: this.options.mapType,
        draggable: this.options.allowPan,
        zoomControl: this.options.allowZoom,
        scrollwheel: this.options.allowZoom,
        disableDoubleClickZoom: !(this.options.allowZoom),
        gestureHandling: this.options.gestureHandling
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
        apex.jQuery("#"+_this.options.regionId).trigger("mapclick", {map:_this.map, lat:event.latLng.lat(), lng:event.latLng.lng()});
      });
      apex.jQuery("#"+this.options.regionId).bind("apexrefresh",function(){
        $("#map_"+_this.options.regionId).reportmap("refresh");
      });
      if (this.options.initFn) {
        apex.debug("running init_javascript_code...");
        //inside the init() function we want "this" to refer to this
        this.init=this.options.initFn;
        this.init();
      }
      if (this.options.expectData) {
        this.refresh();
      }
      apex.jQuery("#"+this.options.regionId).trigger("maploaded", {map:this.map});
      apex.debug("reportmap.init finished");
    },
    
    // Called when created, and later when changing options
    refresh: function() {
      apex.debug("reportmap.refresh");
      this._hideMessage();
      if (this.options.expectData) {
        apex.jQuery("#"+this.options.regionId).trigger("apexbeforerefresh");
        var _this = this;
        apex.server.plugin
          (this.options.ajaxIdentifier
          ,{ pageItems: this.options.ajaxItems }
          ,{ dataType: "json"
            ,success: function( pData ) {
              apex.debug("success southwest="+JSON.stringify(pData.southwest)+" northeast="+JSON.stringify(pData.northeast));
              _this.map.fitBounds(
                {south:pData.southwest.lat
                ,west: pData.southwest.lng
                ,north:pData.northeast.lat
                ,east: pData.northeast.lng});
              if (_this.infoWindow) {
                _this.infoWindow.close();
              }
              apex.debug("pData.mapdata.length="+pData.mapdata.length);
              _this._removeMarkers();
              if (pData.mapdata) {
                _this._showData(pData.mapdata);
                if (_this.options.visualisation=="directions") {
                  _this._directions(pData.mapdata);
                }
              }
              apex.jQuery("#"+_this.options.regionId).trigger("apexafterrefresh");
            }
          } );
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