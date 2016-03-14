set define off

create or replace package plugin as
function render_map (
    p_region in apex_plugin.t_region,
    p_plugin in apex_plugin.t_plugin,
    p_is_printer_friendly in boolean )
return apex_plugin.t_region_render_result;
function ajax
    (p_region in apex_plugin.t_region
    ,p_plugin in apex_plugin.t_plugin )
return apex_plugin.t_region_ajax_result
end plugin;
/
show errors

create or replace package body plugin as
PROCEDURE set_map_extents
    (p_lat     IN NUMBER
    ,p_lng     IN NUMBER
    ,p_lat_min IN OUT NUMBER
    ,p_lat_max IN OUT NUMBER
    ,p_lng_min IN OUT NUMBER
    ,p_lng_max IN OUT NUMBER
    ) IS
BEGIN
    p_lat_min := LEAST   (NVL(p_lat_min, p_lat), p_lat);
    p_lat_max := GREATEST(NVL(p_lat_max, p_lat), p_lat);
    p_lng_min := LEAST   (NVL(p_lng_min, p_lng), p_lng);
    p_lng_max := GREATEST(NVL(p_lng_max, p_lng), p_lng);
END set_map_extents;

FUNCTION latlng2ch (lat IN NUMBER, lng IN NUMBER) RETURN VARCHAR2 IS
BEGIN
  RETURN '"lat":'
      || TO_CHAR(lat, 'fm999D9999999999999999')
      || ',"lng":'
      || TO_CHAR(lng, 'fm999D9999999999999999');
END latlng2ch;

FUNCTION get_markers
    (p_region  IN APEX_PLUGIN.t_region
    ,p_lat_min IN OUT NUMBER
    ,p_lat_max IN OUT NUMBER
    ,p_lng_min IN OUT NUMBER
    ,p_lng_max IN OUT NUMBER
    ) RETURN VARCHAR2 IS

    l_markers_data       VARCHAR2(32767);
    l_lat                NUMBER;
    l_lng                NUMBER;
    l_icon               VARCHAR2(4000);
    l_column_value_list  APEX_PLUGIN_UTIL.t_column_value_list;

BEGIN

    l_column_value_list := APEX_PLUGIN_UTIL.get_data
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
          || '{"id":'   || APEX_ESCAPE.js_literal(l_column_value_list(4)(i),'"')
          || ',"name":' || APEX_ESCAPE.js_literal(l_column_value_list(3)(i),'"')
          || ',"info":' || APEX_ESCAPE.js_literal(l_column_value_list(5)(i),'"')
          || ','        || latlng2ch(l_lat,l_lng)
          || ',"icon":' || APEX_ESCAPE.js_literal(l_icon,'"')
          || '}';
    
        set_map_extents
          (p_lat     => l_lat
          ,p_lng     => l_lng
          ,p_lat_min => p_lat_min
          ,p_lat_max => p_lat_max
          ,p_lng_min => p_lng_min
          ,p_lng_max => p_lng_max
          );
      
    END LOOP;

    RETURN l_markers_data;
END get_markers;

FUNCTION render_map
    (p_region IN APEX_PLUGIN.t_region
    ,p_plugin IN APEX_PLUGIN.t_plugin
    ,p_is_printer_friendly IN BOOLEAN
    ) RETURN APEX_PLUGIN.t_region_render_result IS

    SUBTYPE plugin_attr is VARCHAR2(32767);
    
    l_result       APEX_PLUGIN.t_region_render_result;

    l_lat          NUMBER;
    l_lng          NUMBER;
    l_html         VARCHAR2(32767);
    l_markers_data VARCHAR2(32767);
    l_lat_min      NUMBER;
    l_lat_max      NUMBER;
    l_lng_min      NUMBER;
    l_lng_max      NUMBER;

    -- Component attributes
    l_map_height    plugin_attr := p_region.attribute_01;
    l_id_item       plugin_attr := p_region.attribute_02;
    l_click_zoom    plugin_attr := p_region.attribute_03;    
    l_sync_item     plugin_attr := p_region.attribute_04;
    l_markericon    plugin_attr := p_region.attribute_05;
    l_latlong       plugin_attr := p_region.attribute_06;
    l_dist_item     plugin_attr := p_region.attribute_07;
    l_api_key       plugin_attr := p_region.attribute_08;
    
BEGIN
    -- debug information will be included
    IF APEX_APPLICATION.g_debug then
        APEX_PLUGIN_UTIL.debug_region
          (p_plugin => p_plugin
          ,p_region => p_region
          ,p_is_printer_friendly => p_is_printer_friendly);
    END IF;

    APEX_JAVASCRIPT.add_library
      (p_name           => 'js' || CASE WHEN l_api_key IS NOT NULL THEN '?key=' || l_api_key END
      ,p_directory      => 'https://maps.googleapis.com/maps/api/'
      ,p_version        => null
      ,p_skip_extension => true);

    IF p_region.source IS NOT NULL THEN

      l_markers_data := get_markers
        (p_region  => p_region
        ,p_lat_min => l_lat_min
        ,p_lat_max => l_lat_max
        ,p_lng_min => l_lng_min
        ,p_lng_max => l_lng_max
        );
        
    END IF;
    
    -- if sync item is set, include its position in the initial map extent
    IF l_sync_item IS NOT NULL THEN
      l_latlong := NVL(v(l_sync_item),l_latlong);
    END IF;
    
    IF l_latlong IS NOT NULL THEN
      l_lat := TO_NUMBER(SUBSTR(l_latlong,1,INSTR(l_latlong,',')-1));
      l_lng := TO_NUMBER(SUBSTR(l_latlong,INSTR(l_latlong,',')+1));
    END IF;
    
    IF l_lat IS NOT NULL THEN
      set_map_extents
        (p_lat     => l_lat
        ,p_lng     => l_lng
        ,p_lat_min => l_lat_min
        ,p_lat_max => l_lat_max
        ,p_lng_min => l_lng_min
        ,p_lng_max => l_lng_max
        );

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
    
    l_html := q'[
<script>
var map_#REGION#, iw_#REGION#, reppin_#REGION#, userpin_#REGION#, distcircle_#REGION#, mapdata_#REGION#;
function r_#REGION#(f){/in/.test(document.readyState)?setTimeout("r_#REGION#("+f+")",9):f()}
function repPin_#REGION#(pData) {
  var reppin = new google.maps.Marker({
                 map: map_#REGION#,
                 position: new google.maps.LatLng(pData.lat, pData.lng),
                 title: pData.name,
                 icon: pData.icon
               });
  google.maps.event.addListener(reppin, "click", function () {
    console.log("#REGION# repPin clicked "+pData.id);
    if (iw_#REGION#) {
      iw_#REGION#.close();
    } else {
      iw_#REGION# = new google.maps.InfoWindow();
    }
    iw_#REGION#.setOptions({
       content: pData.info
      });
    iw_#REGION#.open(map_#REGION#, this);
    map_#REGION#.panTo(this.getPosition());
    if ("#CLICKZOOM#" != "") {
      map_#REGION#.setZoom(#CLICKZOOM#);
    }
    if ("#IDITEM#" !== "") {
      $s("#IDITEM#",pData.id);
    }
    apex.jQuery("##REGION#").trigger("markerclick", {id:pData.id, name:pData.name, lat:pData.lat, lng:pData.lng});
  });
  if (!reppin_#REGION#) { reppin_#REGION# = []; }
  reppin_#REGION#.push({"id":pData.id,"marker":reppin});
}
function repPins_#REGION#() {
  for (var i = 0; i < mapdata_#REGION#.length; i++) {
    repPin_#REGION#(mapdata_#REGION#[i]);
  }
}
function click_#REGION#(id) {
  var found = false;
  for (var i = 0; i < reppin_#REGION#.length; i++) {
    if (reppin_#REGION#[i].id == id) {
      new google.maps.event.trigger(reppin_#REGION#[i].marker,"click");
      found = true;
      break;
    }
  }
  if (!found) {
    console.log("#REGION# id not found:"+id);
  }
}
function setCircle_#REGION#(pos) {
  if ("#DISTITEM#" !== "") {
    if (distcircle_#REGION#) {
      console.log("#REGION# move circle");
      distcircle_#REGION#.setCenter(pos);
      distcircle_#REGION#.setMap(map_#REGION#);
    } else {
      var radius_km = parseFloat($v("#DISTITEM#"));
      console.log("#REGION# create circle radius="+radius_km);
      distcircle_#REGION# = new google.maps.Circle({
          strokeColor: "#5050FF",
          strokeOpacity: 0.5,
          strokeWeight: 2,
          fillColor: "#0000FF",
          fillOpacity: 0.05,
          clickable: false,
          editable: true,
          map: map_#REGION#,
          center: pos,
          radius: radius_km*1000
        });
      google.maps.event.addListener(distcircle_#REGION#, "radius_changed", function (event) {
        var radius_km = distcircle_#REGION#.getRadius()/1000;
        console.log("#REGION# circle radius changed "+radius_km);
        $s("#DISTITEM#", radius_km);
        refreshMap_#REGION#();
      });
      google.maps.event.addListener(distcircle_#REGION#, "center_changed", function (event) {
        var latlng = distcircle_#REGION#.getCenter().lat()+","+distcircle_#REGION#.getCenter().lng();
        console.log("#REGION# circle center changed "+latlng);
        if ("#SYNCITEM#" !== "") {
          $s("#SYNCITEM#",latlng);
          refreshMap_#REGION#();
        }
      });
    }
  }
}
function userPin_#REGION#(lat,lng) {
  if (lat !== null && lng !== null) {
    var oldpos = userpin_#REGION#?userpin_#REGION#.getPosition():new google.maps.LatLng(0,0);
    if (lat == oldpos.lat() && lng == oldpos.lng()) {
      console.log("#REGION# userpin not changed");
    } else {
      var pos = new google.maps.LatLng(lat,lng);
      if (userpin_#REGION#) {
        console.log("#REGION# move existing pin to new position on map "+lat+","+lng);
        userpin_#REGION#.setMap(map_#REGION#);
        userpin_#REGION#.setPosition(pos);
        setCircle_#REGION#(pos);
      } else {
        console.log("#REGION# create userpin "+lat+","+lng);
        userpin_#REGION# = new google.maps.Marker({map: map_#REGION#, position: pos, icon: "#ICON#"});
        setCircle_#REGION#(pos);
      }
    }
  } else if (userpin_#REGION#) {
    console.log("#REGION# move existing pin off the map");
    userpin_#REGION#.setMap(null);
    if (distcircle_#REGION#) {
      console.log("#REGION# move distcircle off the map");
      distcircle_#REGION#.setMap(null);
    }
  }
}
function initMap_#REGION#() {
  console.log("#REGION# initMap");
  var myOptions = {
    zoom: 1,
    center: new google.maps.LatLng(#LATLNG#),
    mapTypeId: google.maps.MapTypeId.ROADMAP
  };
  map_#REGION# = new google.maps.Map(document.getElementById("map_#REGION#_container"),myOptions);
  map_#REGION#.fitBounds(new google.maps.LatLngBounds({#SOUTHWEST#},{#NORTHEAST#}));
  if ("#SYNCITEM#" !== "") {
    var val = $v("#SYNCITEM#");
    if (val !== null && val.indexOf(",") > -1) {
      var arr = val.split(",");
      console.log("#REGION# init from item "+val);
      var pos = new google.maps.LatLng(arr[0],arr[1]);
      userpin_#REGION# = new google.maps.Marker({map: map_#REGION#, position: pos, icon: "#ICON#"});
      setCircle_#REGION#(pos);
    }
    //if the lat/long item is changed, move the pin
    $("##SYNCITEM#").change(function(){ 
      var latlng = this.value;
      if (latlng !== null && latlng !== undefined && latlng.indexOf(",") > -1) {
        console.log("#REGION# item changed "+latlng);
        var arr = latlng.split(",");
        userPin_#REGION#(arr[0],arr[1]);
      }
    });
  }
  if ("#DISTITEM#" != "") {
    //if the distance item is changed, redraw the circle
    $("##DISTITEM#").change(function(){
      var radius_metres = parseFloat(this.value)*1000;
      if (distcircle_#REGION#.getRadius() !== radius_metres) {
        console.log("#REGION# distitem changed "+this.value);
        distcircle_#REGION#.setRadius(radius_metres);
      }
    });
  }
  repPins_#REGION#();
  google.maps.event.addListener(map_#REGION#, "click", function (event) {
    var lat = event.latLng.lat()
       ,lng = event.latLng.lng();
    console.log("#REGION# map clicked "+lat+","+lng);
    userPin_#REGION#(lat,lng);
    if ("#SYNCITEM#" !== "") {
      $s("#SYNCITEM#",lat+","+lng);
      refreshMap_#REGION#();
    }
    apex.jQuery("##REGION#").trigger("mapclick", {lat:lat, lng:lng});
  });
  console.log("#REGION# initMap finished");
}
function refreshMap_#REGION#() {
  console.log("#REGION# refreshMap");
  apex.jQuery("##REGION#").trigger("apexbeforerefresh");
  apex.server.plugin
    ("#AJAX_IDENTIFIER#"
    ,{ pageItems: "##SYNCITEM#,##DISTITEM#" }
    ,{ dataType: "json"
      ,success: function( pData ) {
          console.log("#REGION# success pData="+pData.southwest.lat+","+pData.southwest.lng+" "+pData.northeast.lat+","+pData.northeast.lng);
          map_#REGION#.fitBounds(
            {south:pData.southwest.lat
            ,west:pData.southwest.lng
            ,north:pData.northeast.lat
            ,east:pData.northeast.lng});
          if (iw_#REGION#) {
            iw_#REGION#.close();
          }
          console.log("#REGION# remove all report pins");
          for (var i = 0; i < reppin_#REGION#.length; i++) {
            var marker = reppin_#REGION#[i].marker; 
            marker.setMap(null);
          }
          console.log("pData.mapdata.length="+pData.mapdata.length);
          mapdata_#REGION# = pData.mapdata;
          repPins_#REGION#();
          if ("#SYNCITEM#" !== "") {
            var val = $v("#SYNCITEM#");
            if (val !== null && val.indexOf(",") > -1) {
              var arr = val.split(",");
              console.log("#REGION# init from item "+val);
              userPin_#REGION#(arr[0],arr[1]);
            }
          }
          apex.jQuery("##REGION#").trigger("apexafterrefresh");
       }
     } );
  console.log("#REGION# refreshMap finished");
}
r_#REGION#(function(){
  mapdata_#REGION# = [#MAPDATA#];
  initMap_#REGION#();
  apex.jQuery("##REGION#").bind("apexrefresh", function(){refreshMap_#REGION#();});
});
</script>
<div id="map_#REGION#_container" style="min-height:#MAPHEIGHT#px"></div>]';

    l_html := REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
              REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
              REPLACE(REPLACE(
      l_html
      ,'#SOUTHWEST#', latlng2ch(l_lat_min,l_lng_min))
      ,'#NORTHEAST#', latlng2ch(l_lat_max,l_lng_max))
      ,'#MAPDATA#',   l_markers_data)
      ,'#MAPHEIGHT#', l_map_height)
      ,'#IDITEM#',    l_id_item)
      ,'#CLICKZOOM#', l_click_zoom)
      ,'#REGION#',    CASE
                      WHEN p_region.static_id IS NOT NULL
                      THEN p_region.static_id
                      ELSE 'R'||p_region.id
                      END)
      ,'#LATLNG#',    l_latlong)
      ,'#SYNCITEM#',  l_sync_item)
      ,'#ICON#',      l_markericon)
      ,'#DISTITEM#',  l_dist_item)
      ,'#AJAX_IDENTIFIER#', APEX_PLUGIN.get_ajax_identifier);
      
    SYS.HTP.p(l_html);
  
    RETURN l_result;
END render_map;

FUNCTION ajax
    (p_region IN APEX_PLUGIN.t_region
    ,p_plugin IN APEX_PLUGIN.t_plugin
    ) RETURN APEX_PLUGIN.t_region_ajax_result IS

    SUBTYPE plugin_attr is VARCHAR2(32767);

    l_result APEX_PLUGIN.t_region_ajax_result;

    l_lat          NUMBER;
    l_lng          NUMBER;
    l_markers_data VARCHAR2(32767);
    l_lat_min      NUMBER;
    l_lat_max      NUMBER;
    l_lng_min      NUMBER;
    l_lng_max      NUMBER;

    -- Component attributes
    l_map_height    plugin_attr := p_region.attribute_01;
    l_id_item       plugin_attr := p_region.attribute_02;
    l_click_zoom    plugin_attr := p_region.attribute_03;    
    l_sync_item     plugin_attr := p_region.attribute_04;
    l_markericon    plugin_attr := p_region.attribute_05;
    l_latlong       plugin_attr := p_region.attribute_06;
    l_dist_item     plugin_attr := p_region.attribute_07;

BEGIN
    -- debug information will be included
    IF APEX_APPLICATION.g_debug then
        APEX_PLUGIN_UTIL.debug_region
          (p_plugin => p_plugin
          ,p_region => p_region);
    END IF;

    IF p_region.source IS NOT NULL THEN

      l_markers_data := get_markers
        (p_region  => p_region
        ,p_lat_min => l_lat_min
        ,p_lat_max => l_lat_max
        ,p_lng_min => l_lng_min
        ,p_lng_max => l_lng_max
        );
        
    END IF;
    
    -- if sync item is set, include its position in the initial map extent
    IF l_sync_item IS NOT NULL THEN
      l_latlong := NVL(v(l_sync_item),l_latlong);
    END IF;
    
    IF l_latlong IS NOT NULL THEN
      l_lat := TO_NUMBER(SUBSTR(l_latlong,1,INSTR(l_latlong,',')-1));
      l_lng := TO_NUMBER(SUBSTR(l_latlong,INSTR(l_latlong,',')+1));
    END IF;
    
    IF l_lat IS NOT NULL THEN
      set_map_extents
        (p_lat     => l_lat
        ,p_lng     => l_lng
        ,p_lat_min => l_lat_min
        ,p_lat_max => l_lat_max
        ,p_lng_min => l_lng_min
        ,p_lng_max => l_lng_max
        );

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

    SYS.OWA_UTIL.mime_header('text/plain', false);
    SYS.HTP.p('Cache-Control: no-cache');
    SYS.HTP.p('Pragma: no-cache');
    SYS.OWA_UTIL.http_header_close;
    
    SYS.HTP.p('{"southwest":{'
      || latlng2ch(l_lat_min,l_lng_min)
      || '},"northeast":{'
      || latlng2ch(l_lat_max,l_lng_max)
      || '},"mapdata":['
      || l_markers_data
      || ']}');

    RETURN l_result;
END ajax;
end plugin;
/
show errors