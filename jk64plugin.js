function jk64plugin_geocode(opt,geocoder) {
  geocoder.geocode(
    {address: $v(opt.geocodeItem)
    ,componentRestrictions: opt.country!==""?{country:opt.country}:{}
  }, function(results, status) {
    if (status === google.maps.GeocoderStatus.OK) {
      var pos = results[0].geometry.location;
      apex.debug(opt.regionId+" geocode ok");
      opt.map.setCenter(pos);
      opt.map.panTo(pos);
      if (opt.markerZoom) {
        opt.map.setZoom(opt.markerZoom);
      }
      jk64plugin_userPin(opt,pos.lat(), pos.lng())
    } else {
      apex.debug(opt.regionId+" geocode was unsuccessful for the following reason: "+status);
    }
  });
}
function jk64plugin_repPin(opt,pData) {
	var pos = new google.maps.LatLng(pData.lat, pData.lng);
	if (pData.rad) {
		var circ = new google.maps.Circle({
          strokeColor: pData.col,
          strokeOpacity: 1.0,
          strokeWeight: 1,
          fillColor: pData.col,
          fillOpacity: pData.trns,
          clickable: true,
          map: opt.map,
          center: pos,
          radius: pData.rad*1000
		});
		google.maps.event.addListener(circ, "click", function () {
			apex.debug(opt.regionId+" circle clicked "+pData.id);
			if (opt.idItem!=="") {
				$s(opt.idItem,pData.id);
			}
			apex.jQuery("#"+opt.regionId).trigger("markerclick", {map:opt.map, id:pData.id, name:pData.name, lat:pData.lat, lng:pData.lng, rad:pData.rad});
		});
		if (!opt.circles) { opt.circles=[]; }
		opt.circles.push({"id":pData.id,"circ":circ});
	} else {
		var reppin = new google.maps.Marker({
					 map: opt.map,
					 position: pos,
					 title: pData.name,
					 icon: pData.icon
				   });
		google.maps.event.addListener(reppin, "click", function () {
			apex.debug(opt.regionId+" repPin clicked "+pData.id);
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
			opt.map.panTo(this.getPosition());
			if (opt.markerZoom) {
				opt.map.setZoom(opt.markerZoom);
			}
			if (opt.idItem!=="") {
				$s(opt.idItem,pData.id);
			}
			apex.jQuery("#"+opt.regionId).trigger("markerclick", {map:opt.map, id:pData.id, name:pData.name, lat:pData.lat, lng:pData.lng, rad:pData.rad});
		});
		if (!opt.reppin) { opt.reppin=[]; }
		opt.reppin.push({"id":pData.id,"marker":reppin});
	}
}
function jk64plugin_repPins(opt) {
  for (var i = 0; i < opt.mapdata.length; i++) {
    jk64plugin_repPin(opt,opt.mapdata[i]);
  }
}
function jk64plugin_click(opt,id) {
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
}
function jk64plugin_setCircle(opt,pos) {
  if (opt.distItem!=="") {
    if (opt.distcircle) {
      apex.debug(opt.regionId+" move circle");
      opt.distcircle.setCenter(pos);
      opt.distcircle.setMap(opt.map);
    } else {
      var radius_km = parseFloat($v(opt.distItem));
      apex.debug(opt.regionId+" create circle radius="+radius_km);
      opt.distcircle = new google.maps.Circle({
          strokeColor: "#5050FF",
          strokeOpacity: 0.5,
          strokeWeight: 2,
          fillColor: "#0000FF",
          fillOpacity: 0.05,
          clickable: false,
          editable: true,
          map: opt.map,
          center: pos,
          radius: radius_km*1000
        });
      google.maps.event.addListener(opt.distcircle, "radius_changed", function (event) {
        var radius_km = opt.distcircle.getRadius()/1000;
        apex.debug(opt.regionId+" circle radius changed "+radius_km);
        $s(opt.distItem, radius_km);
        jk64plugin_refreshMap(opt);
      });
      google.maps.event.addListener(opt.distcircle, "center_changed", function (event) {
        var ctr = opt.distcircle.getCenter()
           ,latlng = ctr.lat()+","+ctr.lng();
        apex.debug(opt.regionId+" circle center changed "+latlng);
        if (opt.syncItem!=="") {
          $s(opt.syncItem,latlng);
          jk64plugin_refreshMap(opt);
        }
      });
    }
  }
}
function jk64plugin_userPin(opt,lat,lng) {
  if (lat!==null && lng!==null) {
    var oldpos = opt.userpin?opt.userpin.getPosition():new google.maps.LatLng(0,0);
    if (lat==oldpos.lat() && lng==oldpos.lng()) {
      apex.debug(opt.regionId+" userpin not changed");
    } else {
      var pos = new google.maps.LatLng(lat,lng);
      if (opt.userpin) {
        apex.debug(opt.regionId+" move existing pin to new position on map "+lat+","+lng);
        opt.userpin.setMap(opt.map);
        opt.userpin.setPosition(pos);
        jk64plugin_setCircle(opt,pos);
      } else {
        apex.debug(opt.regionId+" create userpin "+lat+","+lng);
        opt.userpin = new google.maps.Marker({map: opt.map, position: pos, icon: opt.icon});
        jk64plugin_setCircle(opt,pos);
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
}
function jk64plugin_initMap(opt) {
  apex.debug(opt.regionId+" initMap");
  var myOptions = {
    zoom: 1,
    center: new google.maps.LatLng(opt.latlng),
    mapTypeId: google.maps.MapTypeId.ROADMAP
  };
  opt.map = new google.maps.Map(document.getElementById(opt.container),myOptions);
  opt.map.fitBounds(new google.maps.LatLngBounds(opt.southwest,opt.northeast));
  if (opt.syncItem!=="") {
    var val = $v(opt.syncItem);
    if (val !== null && val.indexOf(",") > -1) {
      var arr = val.split(",");
      apex.debug(opt.regionId+" init from item "+val);
      var pos = new google.maps.LatLng(arr[0],arr[1]);
      opt.userpin = new google.maps.Marker({map: opt.map, position: pos, icon: opt.icon});
      jk64plugin_setCircle(opt,pos);
    }
    //if the lat/long item is changed, move the pin
    $("#"+opt.syncItem).change(function(){ 
      var latlng = this.value;
      if (latlng !== null && latlng !== undefined && latlng.indexOf(",") > -1) {
        apex.debug(opt.regionId+" item changed "+latlng);
        var arr = latlng.split(",");
        jk64plugin_userPin(opt,arr[0],arr[1]);
      }
    });
  }
  if (opt.distItem!="") {
    //if the distance item is changed, redraw the circle
    $("#"+opt.distItem).change(function(){
      if (this.value) {
        var radius_metres = parseFloat(this.value)*1000;
        if (opt.distcircle.getRadius() !== radius_metres) {
          apex.debug(opt.regionId+" distitem changed "+this.value);
          opt.distcircle.setRadius(radius_metres);
        }
      } else {
        if (opt.distcircle) {
          apex.debug(opt.regionId+" distitem cleared");
          opt.distcircle.setMap(null);
        }
      }
    });
  }
  jk64plugin_repPins(opt);
  google.maps.event.addListener(opt.map, "click", function (event) {
    var lat = event.latLng.lat()
       ,lng = event.latLng.lng();
    apex.debug(opt.regionId+" map clicked "+lat+","+lng);
    if (opt.syncItem !== "") {
      jk64plugin_userPin(opt,lat,lng);
      $s(opt.syncItem,lat+","+lng);
      jk64plugin_refreshMap(opt);
    }
    apex.jQuery("#"+opt.regionId).trigger("mapclick", {map:opt.map, lat:lat, lng:lng});
  });
  if (opt.geocodeItem!="") {
    var geocoder = new google.maps.Geocoder();
    $("#"+opt.geocodeItem).change(function(){
      jk64plugin_geocode(opt,geocoder);
    });
  }
  apex.debug(opt.regionId+" initMap finished");
  apex.jQuery("#"+opt.regionId).trigger("maploaded", {map:opt.map});
}
function jk64plugin_refreshMap(opt) {
  apex.debug(opt.regionId+" refreshMap");
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
          apex.debug(opt.regionId+" remove all report pins");
          for (var i = 0; i < opt.reppin.length; i++) {
            opt.reppin[i].marker.setMap(null);
          }
          apex.debug(opt.regionId+" pData.mapdata.length="+pData.mapdata.length);
          opt.mapdata = pData.mapdata;
          jk64plugin_repPins(opt);
          if (opt.syncItem!=="") {
            var val = $v(opt.syncItem);
            if (val!==null && val.indexOf(",") > -1) {
              var arr = val.split(",");
              apex.debug(opt.regionId+" init from item "+val);
              jk64plugin_userPin(opt,arr[0],arr[1]);
            }
          }
          apex.jQuery("#"+opt.regionId).trigger("apexafterrefresh");
       }
     } );
  apex.debug(opt.regionId+" refreshMap finished");
}
