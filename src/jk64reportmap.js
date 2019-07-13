var reportmap = {
//jk64 ReportMap v1.0 Jul 2019

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

//search the map for an address; if found, put a pin at that location and raise addressfound trigger
gotoAddress : function (opt,addressText) {
	apex.debug(opt.regionId+" reportmap.gotoAddress");
  var geocoder = new google.maps.Geocoder;
  geocoder.geocode(
    {address: addressText
    ,componentRestrictions: opt.country!==""?{country:opt.country}:{}
  }, function(results, status) {
    if (status === google.maps.GeocoderStatus.OK) {
      var pos = results[0].geometry.location;
      apex.debug(opt.regionId+" geocode ok");
      if (opt.markerPan) {
        opt.map.setCenter(pos);
        opt.map.panTo(pos);
      }
      if (opt.markerZoom) {
        opt.map.setZoom(opt.markerZoom);
      }
      reportmap.userPin(opt,pos.lat(), pos.lng());
      apex.debug(opt.regionId+" addressfound '"+results[0].formatted_address+"'");
      apex.jQuery("#"+opt.regionId).trigger("addressfound", {
        map:opt.map,
        lat:pos.lat(),
        lng:pos.lng(),
        result:results[0]
      });
    } else {
      apex.debug(opt.regionId+" geocode was unsuccessful for the following reason: "+status);
    }
  });
},

//place a report pin on the map
repPin : function (opt,pData) {
	var pos = new google.maps.LatLng(pData.lat, pData.lng);
  var reppin = new google.maps.Marker({
        map: opt.map,
        position: pos,
        title: pData.name,
        icon: pData.icon,
        label: pData.label,
        draggable: opt.isDraggable                                                                        
      });
  google.maps.event.addListener(reppin, "click", function () {
    apex.debug(opt.regionId+" repPin "+pData.id+" clicked");
    if (pData.info) {
      if (opt.iw) {
        opt.iw.close();
      } else {
        opt.iw = new google.maps.InfoWindow();
      }
      opt.iw.setOptions({
         content: pData.info
        });
      opt.iw.open(opt.map, this);
    }
    if (opt.markerPan) {
      opt.map.panTo(this.getPosition());
    }
    if (opt.markerZoom) {
      opt.map.setZoom(opt.markerZoom);
    }
    apex.jQuery("#"+opt.regionId).trigger("markerclick", {
      map:opt.map,
      id:pData.id,
      name:pData.name,
      lat:pData.lat,
      lng:pData.lng
    });	
  });
  google.maps.event.addListener(reppin, "dragend", function () {
		apex.debug(opt.regionId+" repPin "+pData.id+" moved to position ("+this.getPosition().lat()+","+this.getPosition().lng()+")");
    apex.jQuery("#"+opt.regionId).trigger("markerdrag", {
      map:opt.map,
      id:pData.id,
      name:pData.name,
      lat:this.getPosition().lat(),
      lng:this.getPosition().lng()
    });	
  });
  if (!opt.reppin) { opt.reppin=[]; }
  opt.reppin.push({"id":pData.id,"marker":reppin});
  return reppin;
},

//put all the report pins on the map, or show the "no data found" message
repPins : function (opt) {
	apex.debug(opt.regionId+" reportmap.repPins");
	if (opt.mapdata.length>0) {
		if (opt.infoNoDataFound) {
			apex.debug(opt.regionId+" hide No Data Found infowindow");
			opt.infoNoDataFound.close();
		}
    var marker, markers = [];
		for (var i = 0; i < opt.mapdata.length; i++) {
      if (opt.heatmap) {
        markers.push({
          location:new google.maps.LatLng(opt.mapdata[i].a, opt.mapdata[i].b),
          weight:opt.mapdata[i].c
        });
      } else {
        marker = reportmap.repPin(opt,opt.mapdata[i]);
        if (opt.markerClustering) {
          markers.push(marker);
        }
      }
		}
    if (opt.markerClustering) {
      // Add a marker clusterer to manage the markers.
      // More info: https://developers.google.com/maps/documentation/javascript/marker-clustering
      var markerCluster = new MarkerClusterer(opt.map, markers,{imagePath:opt.imagePrefix});
    } else if (opt.heatmap) {
      if (opt.heatmapLayer) {
        apex.debug(opt.regionId+" hide heatmapLayer");
        opt.heatmapLayer.setMap(null);
        apex.debug(opt.regionId+" remove heatmapLayer");
        opt.heatmapLayer.delete;
        opt.heatmapLayer = null;
      }
      opt.heatmapLayer = new google.maps.visualization.HeatmapLayer({
        data: markers,
        map: opt.map,
        dissipating: opt.dissipating,
        opacity: opt.opacity,
        radius: opt.radius
      });
    }
  } else {
		if (opt.noDataMessage !== "") {
			apex.debug(opt.regionId+" show No Data Found infowindow");
			if (opt.infoNoDataFound) {
				opt.infoNoDataFound.close();
			} else {
				opt.infoNoDataFound = new google.maps.InfoWindow(
					{
						content: opt.noDataMessage,
						position: reportmap.parseLatLng(opt.latlng)
					});
			}
			opt.infoNoDataFound.open(opt.map);
		}
	}
},

//call this to simulate a mouse click on the report pin for the given id value
//e.g. this will show the info window for the given report pin and trigger the markerclick event
click : function (opt,id) {
	apex.debug(opt.regionId+" reportmap.click");
  var found = false;
  for (var i = 0; i < opt.reppin.length; i++) {
    if (opt.reppin[i].id==id) {
      new google.maps.event.trigger(opt.reppin[i].marker,"click");
      found = true;
      break;
    }
  }
  if (!found) {
    apex.debug(opt.regionId+" id not found:"+id);
  }
},

//parse the given string as a lat,long pair, put a pin at that location
gotoPosByString : function (opt,v) {
  apex.debug(opt.regionId+" reportmap.gotoPos");
  var latlng = parseLatLng(v);
  if (latlng) {
		apex.debug(opt.regionId+" item changed "+latlng.lat()+" "+latlng.lng());
		reportmap.userPin(opt,latlng.lat(),latlng.lng());
	}
},

//place or move the user pin to the given location
gotoPos : function (opt,lat,lng) {
	apex.debug(opt.regionId+" reportmap.userPin");
  if (lat!==null && lng!==null) {
    var oldpos = opt.userpin?opt.userpin.getPosition():(new google.maps.LatLng(0,0));
    if (oldpos && lat==oldpos.lat() && lng==oldpos.lng()) {
      apex.debug(opt.regionId+" userpin not changed");
    } else {
      var pos = new google.maps.LatLng(lat,lng);
      if (opt.userpin) {
        apex.debug(opt.regionId+" move existing pin to new position on map "+lat+","+lng);
        opt.userpin.setMap(opt.map);
        opt.userpin.setPosition(pos);
      } else {
        apex.debug(opt.regionId+" create userpin "+lat+","+lng);
        opt.userpin = new google.maps.Marker({map: opt.map, position: pos, icon: opt.icon});
      }
    }
  } else if (opt.userpin) {
    apex.debug(opt.regionId+" move existing pin off the map");
    opt.userpin.setMap(null);
    if (opt.distcircle) {
      apex.debug(opt.regionId+" move distcircle off the map");
      opt.distcircle.setMap(null);
    }
  }
},

//search for the address at a given location by lat/long
searchAddress : function (opt,lat,lng) {
	apex.debug(opt.regionId+" reportmap.searchAddress");
	var latlng = {lat: lat, lng: lng};
  var geocoder = new google.maps.Geocoder;
	geocoder.geocode({'location': latlng}, function(results, status) {
		if (status === google.maps.GeocoderStatus.OK) {
			if (results[0]) {
        apex.debug(opt.regionId+" addressfound '"+results[0].formatted_address+"'");
        var components = results[0].address_components;
        for (i=0; i<components.length; i++) {
          apex.debug(opt.regionId+" result[0] "+components[i].types+"="+components[i].short_name+" ("+components[i].long_name+")");
        }
        apex.jQuery("#"+opt.regionId).trigger("addressfound", {
          map:opt.map,
          lat:lat,
          lng:lng,
          result:results[0]
        });
			} else {
        apex.debug(opt.regionId+" searchAddress: No results found");
				window.alert('No results found');
			}
		} else {
      apex.debug(opt.regionId+' Geocoder failed due to: ' + status);
			window.alert('Geocoder failed due to: ' + status);
		}
	});
},

//search for the user device's location if possible
geolocate : function (opt) {
	apex.debug(opt.regionId+" reportmap.geolocate");
	if (navigator.geolocation) {
		apex.debug(opt.regionId+" geolocate");
		navigator.geolocation.getCurrentPosition(function(position) {
			var pos = {
				lat: position.coords.latitude,
				lng: position.coords.longitude
			};
			opt.map.panTo(pos);
			if (opt.geolocateZoom) {
			  opt.map.setZoom(opt.geolocateZoom);
			}
			apex.jQuery("#"+opt.regionId).trigger("geolocate", {map:opt.map, lat:pos.lat, lng:pos.lng});
		});
	} else {
		apex.debug(opt.regionId+" browser does not support geolocation");
	}
},

//this is called when directions are requested
directionsresp : function (response,status,opt) {
	apex.debug(opt.regionId+" reportmap.directionsresp");
  if (status == google.maps.DirectionsStatus.OK) {
    opt.directionsDisplay.setDirections(response);
    var totalDistance = 0, totalDuration = 0, legCount = 0;
    for (var i=0; i < response.routes.length; i++) {
      legCount = legCount + response.routes[i].legs.length;
      for (var j=0; j < response.routes[i].legs.length; j++) {
        var leg = response.routes[i].legs[j];
        totalDistance = totalDistance + leg.distance.value;
        totalDuration = totalDuration + leg.duration.value;
      }
    }
    apex.jQuery("#"+opt.regionId).trigger("directions",{
      map:opt.map,
      distance:totalDistance,
      duration:totalDuration,
      legs:legCount
    });
  } else {
    apex.debug(opt.regionId+' Directions request failed due to ' + status);
    window.alert('Directions request failed due to ' + status);
  }
},

//show directions on the map
directions : function (opt) {
	apex.debug(opt.regionId+" reportmap.directions "+opt.directions);
	var origin
	   ,dest
     ,routeindex = opt.directions.indexOf("-ROUTE")
     ,travelmode;
	if (routeindex<0) {
    //simple directions between two items
    origin = $v(opt.originItem);
    dest   = $v(opt.destItem);
    origin = reportmap.parseLatLng(origin)||origin;
    dest   = reportmap.parseLatLng(dest)||dest;
    if (origin !== "" && dest !== "") {
      travelmode = opt.directions;
	  	opt.directionsService.route({
		  	origin:origin,
			  destination:dest,
			  travelMode:google.maps.TravelMode[travelmode]
		  }, function(response,status){reportmap.directionsresp(response,status,opt)});
    }
  } else {
    //route via waypoints
    travelmode = opt.directions.slice(0,routeindex);
    apex.debug(opt.regionId+" route via "+travelmode+" with "+opt.mapdata.length+" waypoints");
    var waypoints = [];
 		for (var i = 0; i < opt.mapdata.length; i++) {
      if (i == 0) {
        origin = new google.maps.LatLng(opt.mapdata[i].lat, opt.mapdata[i].lng);
      } else if (i == opt.mapdata.length-1) {
        dest = new google.maps.LatLng(opt.mapdata[i].lat, opt.mapdata[i].lng);
      } else {
        waypoints.push({
          location: new google.maps.LatLng(opt.mapdata[i].lat, opt.mapdata[i].lng),
          stopover: true
        });
      }
		}
    apex.debug(opt.regionId+" origin="+origin);
    apex.debug(opt.regionId+" dest="+dest);
    apex.debug(opt.regionId+" waypoints:"+waypoints.length);
		opt.directionsService.route({
			origin:origin,
			destination:dest,
      waypoints:waypoints,
      optimizeWaypoints:opt.optimizeWaypoints,
			travelMode:google.maps.TravelMode[travelmode]
		}, function(response,status){reportmap.directionsresp(response,status,opt)});
	}
},

//initialise the map after page load
init : function (opt) {
	apex.debug(opt.regionId+" reportmap.init "+opt.maptype);
	var myOptions = {
		zoom: 1,
		center: reportmap.parseLatLng(opt.latlng),
		mapTypeId: opt.maptype
	};
  // get absolute URL for this site, including /apex/ or /ords/ (this is required by some google maps APIs)
  var filePath = window.location.origin + window.location.pathname;
  filePath = filePath.substring(0, filePath.lastIndexOf("/"));
  opt.imagePrefix = filePath + "/" + opt.pluginFilePrefix + "images/m";
  apex.debug('opt.imagePrefix="'+opt.imagePrefix+'"');
	opt.map = new google.maps.Map(document.getElementById(opt.container),myOptions);
  opt.map.setOptions({
       draggable: opt.pan
      ,zoomControl: opt.zoom
      ,scrollwheel: opt.zoom
      ,disableDoubleClickZoom: !(opt.zoom)
      ,gestureHandling: opt.gestureHandling
    });
	if (opt.mapstyle) {
		opt.map.setOptions({styles: opt.mapstyle});
	}
	opt.map.fitBounds(new google.maps.LatLngBounds(opt.southwest,opt.northeast));
	if (opt.expectData) {
		reportmap.repPins(opt);
	}
	if (opt.directions) {
    //directions is DRIVING-ROUTE, WALKING-ROUTE, BICYCLING-ROUTE, TRANSIT-ROUTE,
    //              DRIVING, WALKING, BICYCLING, or TRANSIT
		opt.directionsDisplay = new google.maps.DirectionsRenderer;
    opt.directionsService = new google.maps.DirectionsService;
		opt.directionsDisplay.setMap(opt.map);
		reportmap.directions(opt);
		//if the origin or dest item is changed for simple directions, recalc the directions
    if (opt.directions.indexOf("-ROUTE")<0) {
  		$("#"+opt.originItem).change(function(){
	  		reportmap.directions(opt);
		  });
		  $("#"+opt.destItem).change(function(){
			  reportmap.directions(opt);
	  	});
    }
	}
	google.maps.event.addListener(opt.map, "click", function (event) {
		var lat = event.latLng.lat()
		   ,lng = event.latLng.lng();
		apex.debug(opt.regionId+" map clicked "+lat+","+lng);
    if (opt.markerZoom) {
			apex.debug(opt.regionId+" pan+zoom");
      if (opt.markerPan) {
			  opt.map.panTo(event.latLng);
      }
			opt.map.setZoom(opt.markerZoom);
		}
		apex.jQuery("#"+opt.regionId).trigger("mapclick", {map:opt.map, lat:lat, lng:lng});
	});
	apex.debug(opt.regionId+" reportmap.init finished");
	apex.jQuery("#"+opt.regionId).trigger("maploaded", {map:opt.map});
},

//refresh the pins on the map based on the SQL query
refresh : function (opt) {
	apex.debug(opt.regionId+" reportmap.refresh");
	apex.jQuery("#"+opt.regionId).trigger("apexbeforerefresh");
	apex.server.plugin
		(opt.ajaxIdentifier
		,{ pageItems: opt.ajaxItems }
		,{ dataType: "json"
			,success: function( pData ) {
				apex.debug(opt.regionId+" success pData="+pData.southwest.lat+","+pData.southwest.lng+" "+pData.northeast.lat+","+pData.northeast.lng);
				opt.map.fitBounds(
					{south:pData.southwest.lat
					,west: pData.southwest.lng
					,north:pData.northeast.lat
					,east: pData.northeast.lng});
				if (opt.iw) {
					opt.iw.close();
				}
				if (opt.reppin) {
					apex.debug(opt.regionId+" remove all report pins");
					for (var i = 0; i < opt.reppin.length; i++) {
						opt.reppin[i].marker.setMap(null);
					}
					opt.reppin.delete;
				}
        if (opt.markers) {
          opt.markers.delete;
        }
				apex.debug(opt.regionId+" pData.mapdata.length="+pData.mapdata.length);
				opt.mapdata = pData.mapdata;
				if (opt.expectData) {
					reportmap.repPins(opt);
				}
				apex.jQuery("#"+opt.regionId).trigger("apexafterrefresh");
			}
		} );
	apex.debug(opt.regionId+" reportmap.refresh finished");
}

}