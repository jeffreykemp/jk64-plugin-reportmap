set define off

create or replace package plugin as
function render_map (
    p_region in apex_plugin.t_region,
    p_plugin in apex_plugin.t_plugin,
    p_is_printer_friendly in boolean )
return apex_plugin.t_region_render_result;
end plugin;
/
show errors

create or replace package body plugin as
function render_map (
    p_region in apex_plugin.t_region,
    p_plugin in apex_plugin.t_plugin,
    p_is_printer_friendly in boolean )
return apex_plugin.t_region_render_result
as
    subtype plugin_attr is varchar2(32767);
    
    -- Variables
    l_result       apex_plugin.t_region_render_result;
    l_lat          NUMBER;
    l_lng          NUMBER;
    l_html         VARCHAR2(32767);
    l_markers_data VARCHAR2(32767);
    l_lat_min      NUMBER;
    l_lat_max      NUMBER;
    l_lng_min      NUMBER;
    l_lng_max      NUMBER;
    l_southwest    VARCHAR2(200);
    l_northeast    VARCHAR2(200);
    l_icon         VARCHAR2(4000);

    l_column_value_list  apex_plugin_util.t_column_value_list;

    -- Component attributes
    l_map_height    plugin_attr := p_region.attribute_01;
    l_id_item       plugin_attr := p_region.attribute_02;
    l_click_zoom    plugin_attr := p_region.attribute_03;    
    l_sync_item     plugin_attr := p_region.attribute_04;
    l_markericon    plugin_attr := p_region.attribute_05;
    l_latlong       plugin_attr := p_region.attribute_06;
    l_dist_item     plugin_attr := p_region.attribute_07;
    
    PROCEDURE set_map_extents (p_lat IN NUMBER, p_lng IN NUMBER) IS
    BEGIN
        l_lat_min := LEAST   (NVL(l_lat_min, p_lat), p_lat);
        l_lat_max := GREATEST(NVL(l_lat_max, p_lat), p_lat);
        l_lng_min := LEAST   (NVL(l_lng_min, p_lng), p_lng);
        l_lng_max := GREATEST(NVL(l_lng_max, p_lng), p_lng);
    END set_map_extents;
BEGIN
    -- debug information will be included
    if apex_application.g_debug then
        apex_plugin_util.debug_region (
            p_plugin => p_plugin,
            p_region => p_region,
            p_is_printer_friendly => p_is_printer_friendly);
    end if;

    IF p_region.source IS NOT NULL THEN

        l_column_value_list := apex_plugin_util.get_data
            (p_sql_statement  => p_region.source
            ,p_min_columns    => 5
            ,p_max_columns    => 6
            ,p_component_name => p_region.name
            ,p_max_rows       => 1000);

        FOR i IN 1..l_column_value_list(1).count LOOP
    
            IF l_markers_data IS NOT NULL THEN
                l_markers_data := l_markers_data || ',';
            END IF;
            
            l_lat  := TO_NUMBER(l_column_value_list(1)(i));
            l_lng  := TO_NUMBER(l_column_value_list(2)(i));
            
            IF l_column_value_list.EXISTS(6) THEN
              l_icon := l_column_value_list(6)(i);
            END IF;
    
            l_markers_data := l_markers_data
              || '{id:'   || APEX_ESCAPE.js_literal(l_column_value_list(4)(i))
              || ',name:' || APEX_ESCAPE.js_literal(l_column_value_list(3)(i))
              || ',info:' || APEX_ESCAPE.js_literal(l_column_value_list(5)(i))
              || ',lat:'  || APEX_ESCAPE.js_literal(l_lat)
              || ',lng:'  || APEX_ESCAPE.js_literal(l_lng)
              || ',icon:' || APEX_ESCAPE.js_literal(l_icon)
              || '}';
        
            set_map_extents (p_lat => l_lat, p_lng => l_lng);
          
        END LOOP;
        
    END IF;
    
    l_lat := NULL;
    l_lng := NULL;
    
    -- if sync item is set, include its position in the initial map extent
    IF l_sync_item IS NOT NULL THEN
      l_latlong := NVL(v(l_sync_item),l_latlong);
    END IF;
    
    IF l_latlong IS NOT NULL THEN
      l_lat := TO_NUMBER(SUBSTR(l_latlong,1,INSTR(l_latlong,',')-1));
      l_lng := TO_NUMBER(SUBSTR(l_latlong,INSTR(l_latlong,',')+1));
    END IF;
    
    IF l_lat IS NOT NULL THEN
      set_map_extents (p_lat => l_lat, p_lng => l_lng);

    -- show entire map if no points to show
    ELSIF l_markers_data IS NULL THEN
      l_lat := 0;
      l_lng := 0;
      l_latlong := '0,0';
      l_lat_min := -90;
      l_lat_max := 90;
      l_lng_min := -180;
      l_lng_max := 180;

    END IF;
    
    l_southwest := '{lat:'||TO_CHAR(l_lat_min)||',lng:'||TO_CHAR(l_lng_min)||'}';
    l_northeast := '{lat:'||TO_CHAR(l_lat_max)||',lng:'||TO_CHAR(l_lng_max)||'}';
    
    l_html := q'[
<script>
var map, iw, reppin, userpin, distcircle, mapdata;
function repPin(map,pData) {
  var reppin = new google.maps.Marker({
                 map: map,
                 position: new google.maps.LatLng(pData.lat, pData.lng),
                 title: pData.name,
                 icon: pData.icon
               }); 
  google.maps.event.addListener(reppin, 'click', function () {
    console.log('reppin clicked '+pData.id);
    if (iw) {
      iw.close();
    } else {
      iw = new google.maps.InfoWindow();
    }
    iw.setOptions({
       content: pData.info
      });
    iw.open(map, this);
    map.panTo(this.getPosition());
    if ("#CLICKZOOM#" != "") {
      map.setZoom(#CLICKZOOM#);
    }
    if ("#IDITEM#" !== "") {
      $s("#IDITEM#",pData.id);
    }
    apex.jQuery("##REGION_ID#").trigger("markerclick", {id:pData.id, name:pData.name, lat:pData.lat, lng:pData.lng});
  });
}
function setCircle(map,pos) {
  var distitem = "#DISTITEM#";
  if (distitem!=="") {
    if (distcircle) {
      console.log('move circle');
      distcircle.setCenter(pos);
    } else {
      console.log('create circle');
      var radius_metres = parseFloat($v(distitem))*1000;
      distcircle = new google.maps.Circle({
          strokeColor: '#5050FF',
          strokeOpacity: 0.5,
          strokeWeight: 2,
          fillColor: '#0000FF',
          fillOpacity: 0.05,
          clickable: false,
          editable: true,
          map: map,
          center: pos,
          radius: radius_metres
        });
      google.maps.event.addListener(distcircle, 'radius_changed', function (event) {
        var km = distcircle.getRadius()/1000;
        console.log('circle radius changed '+km);
        $s("#DISTITEM#", km);
      });
    }
  }
}
function userPin(map,lat,lng) {
  if (lat !== null && lng !== null) {
    var oldpos = userpin?userpin.getPosition():new google.maps.LatLng(0,0);
    if (lat == oldpos.lat() && lng == oldpos.lng()) {
      console.log('not changed');
    } else {
      var pos = new google.maps.LatLng(lat,lng);
      if (userpin) {
        console.log('move existing pin to new position on map '+lat+','+lng);
        userpin.setMap(map);
        userpin.setPosition(pos);
        setCircle(map,pos);
      } else {
        console.log('create userpin '+lat+','+lng);
        userpin = new google.maps.Marker({map: map, position: pos, icon: "#ICON#"});
        setCircle(map,pos);
      }
    }
  } else if (userpin) {
    console.log('move existing pin off the map');
    userpin.setMap(null);
    if (distcircle) {
      distcircle.setMap(null);
    }
  }
}
function initMap() {
  console.log('initMap');
  var syncitem = "#SYNCITEM#"
     ,distitem = "#DISTITEM#"
     ,bounds = new google.maps.LatLngBounds(#SOUTHWEST#,#NORTHEAST#);
  var myOptions = {
    zoom: 1,
    center: new google.maps.LatLng(#LATLNG#),
    mapTypeId: google.maps.MapTypeId.ROADMAP
  };
  map = new google.maps.Map(document.getElementById("#REGION_ID#_map"),myOptions);
  if (syncitem !== "") {
    var val = $v(syncitem);
    if (val !== null && val.indexOf(",") > -1) {
      var arr = val.split(",");
      console.log('init from item '+val);
      var pos = new google.maps.LatLng(arr[0],arr[1]);
      userpin = new google.maps.Marker({map: map, position: pos, icon: "#ICON#"});
      setCircle(map,pos);
    }
    //if the lat/long item is changed, move the pin
    $("#"+syncitem).change(function(){ 
      var latlng = this.value;
      console.log('item changed '+latlng);
      if (latlng !== null && latlng !== undefined && latlng.indexOf(",") > -1) {
        var arr = latlng.split(",");
        userPin(map,arr[0],arr[1]);
      }    
    });
  }
  if (distitem) {
    //if the distance item is changed, redraw the circle
    $("#"+distitem).change(function(){
      console.log('distitem changed '+this.value);
      var radius_metres = parseFloat(this.value)*1000;
      if (distcircle.getRadius() !== radius_metres) {
        distcircle.setRadius(radius_metres);
      }
    });
  }
  for (var i = 0; i < mapdata.length; i++) {
    repPin(map,mapdata[i]);
  }
  map.fitBounds(bounds);
  google.maps.event.addListener(map, 'click', function (event) {
    var lat = event.latLng.lat()
       ,lng = event.latLng.lng();
    console.log('map clicked '+lat+','+lng);
    userPin(map,lat,lng);
    if ("#SYNCITEM#" !== "") {
      $s("#SYNCITEM#",lat+","+lng);
    }
    apex.jQuery("##REGION_ID#").trigger("mapclick", {lat:lat, lng:lng});
  });
  console.log('initMap finished');
}
window.onload = function() {
  mapdata = [#MAPDATA#];
  initMap();
}
</script>
<div id="#REGION_ID#_map" style="min-height:#MAPHEIGHT#px"></div>]';

    l_html := REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
              REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
              REPLACE(
      l_html
      ,'#SOUTHWEST#', l_southwest)
      ,'#NORTHEAST#', l_northeast)
      ,'#MAPDATA#',   l_markers_data)
      ,'#MAPHEIGHT#', l_map_height)
      ,'#IDITEM#',    l_id_item)
      ,'#CLICKZOOM#', l_click_zoom)
      ,'#REGION_ID#', CASE
                      WHEN p_region.static_id IS NOT NULL
                      THEN p_region.static_id
                      ELSE 'R'||p_region.id
                      END)
      ,'#LATLNG#',    l_latlong)
      ,'#SYNCITEM#',  l_sync_item)
      ,'#ICON#',      l_markericon)
      ,'#DISTITEM#',  l_dist_item);
      
    sys.htp.p(l_html);
  
    return l_result;
END render_map;
end plugin;
/
show errors