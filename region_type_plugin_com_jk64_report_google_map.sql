set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- ORACLE Application Express (APEX) export file
--
-- You should run the script connected to SQL*Plus as the Oracle user
-- APEX_050000 or as the owner (parsing schema) of the application.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_api.import_begin (
 p_version_yyyy_mm_dd=>'2013.01.01'
,p_release=>'5.0.2.00.07'
,p_default_workspace_id=>20749515040658038
,p_default_application_id=>560
,p_default_owner=>'SAMPLE'
);
end;
/
prompt --application/ui_types
begin
null;
end;
/
prompt --application/shared_components/plugins/region_type/com_jk64_report_google_map
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(218512352878463408)
,p_plugin_type=>'REGION TYPE'
,p_name=>'COM.JK64.REPORT_GOOGLE_MAP'
,p_display_name=>'JK64 Report Google Map'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_plsql_code=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'PROCEDURE set_map_extents',
'    (p_lat     IN NUMBER',
'    ,p_lng     IN NUMBER',
'    ,p_lat_min IN OUT NUMBER',
'    ,p_lat_max IN OUT NUMBER',
'    ,p_lng_min IN OUT NUMBER',
'    ,p_lng_max IN OUT NUMBER',
'    ) IS',
'BEGIN',
'    p_lat_min := LEAST   (NVL(p_lat_min, p_lat), p_lat);',
'    p_lat_max := GREATEST(NVL(p_lat_max, p_lat), p_lat);',
'    p_lng_min := LEAST   (NVL(p_lng_min, p_lng), p_lng);',
'    p_lng_max := GREATEST(NVL(p_lng_max, p_lng), p_lng);',
'END set_map_extents;',
'',
'FUNCTION latlng2ch (lat IN NUMBER, lng IN NUMBER) RETURN VARCHAR2 IS',
'BEGIN',
'  RETURN ''"lat":''',
'      || TO_CHAR(lat, ''fm999.9999999999999999'')',
'      || '',"lng":''',
'      || TO_CHAR(lng, ''fm999.9999999999999999'');',
'END latlng2ch;',
'',
'FUNCTION get_markers',
'    (p_region  IN APEX_PLUGIN.t_region',
'    ,p_lat_min IN OUT NUMBER',
'    ,p_lat_max IN OUT NUMBER',
'    ,p_lng_min IN OUT NUMBER',
'    ,p_lng_max IN OUT NUMBER',
'    ) RETURN VARCHAR2 IS',
'',
'    l_markers_data       VARCHAR2(32767);',
'    l_lat                NUMBER;',
'    l_lng                NUMBER;',
'    l_icon               VARCHAR2(4000);',
'    l_column_value_list  APEX_PLUGIN_UTIL.t_column_value_list;',
'',
'BEGIN',
'',
'    l_column_value_list := APEX_PLUGIN_UTIL.get_data',
'        (p_sql_statement  => p_region.source',
'        ,p_min_columns    => 5',
'        ,p_max_columns    => 6',
'        ,p_component_name => p_region.name',
'        ,p_max_rows       => 1000);',
'  ',
'    FOR i IN 1..l_column_value_list(1).count LOOP',
'  ',
'        IF l_markers_data IS NOT NULL THEN',
'            l_markers_data := l_markers_data || '','';',
'        END IF;',
'        ',
'        l_lat  := TO_NUMBER(l_column_value_list(1)(i));',
'        l_lng  := TO_NUMBER(l_column_value_list(2)(i));',
'        ',
'        IF l_column_value_list.EXISTS(6) THEN',
'          l_icon := l_column_value_list(6)(i);',
'        END IF;',
'  ',
'        l_markers_data := l_markers_data',
'          || ''{"id":''   || APEX_ESCAPE.js_literal(l_column_value_list(4)(i),''"'')',
'          || '',"name":'' || APEX_ESCAPE.js_literal(l_column_value_list(3)(i),''"'')',
'          || '',"info":'' || APEX_ESCAPE.js_literal(l_column_value_list(5)(i),''"'')',
'          || '',''        || latlng2ch(l_lat,l_lng)',
'          || '',"icon":'' || APEX_ESCAPE.js_literal(l_icon,''"'')',
'          || ''}'';',
'    ',
'        set_map_extents',
'          (p_lat     => l_lat',
'          ,p_lng     => l_lng',
'          ,p_lat_min => p_lat_min',
'          ,p_lat_max => p_lat_max',
'          ,p_lng_min => p_lng_min',
'          ,p_lng_max => p_lng_max',
'          );',
'      ',
'    END LOOP;',
'',
'    RETURN l_markers_data;',
'END get_markers;',
'',
'FUNCTION render_map',
'    (p_region IN APEX_PLUGIN.t_region',
'    ,p_plugin IN APEX_PLUGIN.t_plugin',
'    ,p_is_printer_friendly IN BOOLEAN',
'    ) RETURN APEX_PLUGIN.t_region_render_result IS',
'',
'    SUBTYPE plugin_attr is VARCHAR2(32767);',
'    ',
'    l_result       APEX_PLUGIN.t_region_render_result;',
'',
'    l_lat          NUMBER;',
'    l_lng          NUMBER;',
'    l_html         VARCHAR2(32767);',
'    l_markers_data VARCHAR2(32767);',
'    l_lat_min      NUMBER;',
'    l_lat_max      NUMBER;',
'    l_lng_min      NUMBER;',
'    l_lng_max      NUMBER;',
'    l_ajax_items   VARCHAR2(1000);',
'    l_js_params    VARCHAR2(1000);',
'',
'    -- Plugin attributes (application level)',
'    l_api_key       plugin_attr := p_plugin.attribute_01;',
'',
'    -- Component attributes',
'    l_map_height    plugin_attr := p_region.attribute_01;',
'    l_id_item       plugin_attr := p_region.attribute_02;',
'    l_click_zoom    plugin_attr := p_region.attribute_03;    ',
'    l_sync_item     plugin_attr := p_region.attribute_04;',
'    l_markericon    plugin_attr := p_region.attribute_05;',
'    l_latlong       plugin_attr := p_region.attribute_06;',
'    l_dist_item     plugin_attr := p_region.attribute_07;',
'    l_sign_in       plugin_attr := p_region.attribute_08;',
'    l_geocode_item  plugin_attr := p_region.attribute_09;',
'    l_country       plugin_attr := p_region.attribute_10;',
'    ',
'BEGIN',
'    -- debug information will be included',
'    IF APEX_APPLICATION.g_debug then',
'        APEX_PLUGIN_UTIL.debug_region',
'          (p_plugin => p_plugin',
'          ,p_region => p_region',
'          ,p_is_printer_friendly => p_is_printer_friendly);',
'    END IF;',
'',
'    IF l_api_key IS NULL THEN',
'        l_sign_in      := ''N'';',
'        l_geocode_item := NULL;',
'    ELSE',
'        l_js_params := ''?key='' || l_api_key;',
'        IF l_sign_in = ''Y'' THEN',
'            l_js_params := l_js_params || ''&''||''signed_in=true'';',
'        END IF;',
'    END IF;',
'',
'    APEX_JAVASCRIPT.add_library',
'      (p_name           => ''js'' || l_js_params',
'      ,p_directory      => ''https://maps.googleapis.com/maps/api/''',
'      ,p_version        => null',
'      ,p_skip_extension => true);',
'    ',
'    IF p_region.source IS NOT NULL THEN',
'',
'      l_markers_data := get_markers',
'        (p_region  => p_region',
'        ,p_lat_min => l_lat_min',
'        ,p_lat_max => l_lat_max',
'        ,p_lng_min => l_lng_min',
'        ,p_lng_max => l_lng_max',
'        );',
'        ',
'    END IF;',
'    ',
'    -- if sync item is set, include its position in the initial map extent',
'    IF l_sync_item IS NOT NULL THEN',
'      l_latlong := NVL(v(l_sync_item),l_latlong);',
'    END IF;',
'    ',
'    IF l_latlong IS NOT NULL THEN',
'      l_lat := TO_NUMBER(SUBSTR(l_latlong,1,INSTR(l_latlong,'','')-1));',
'      l_lng := TO_NUMBER(SUBSTR(l_latlong,INSTR(l_latlong,'','')+1));',
'    END IF;',
'    ',
'    IF l_lat IS NOT NULL THEN',
'      set_map_extents',
'        (p_lat     => l_lat',
'        ,p_lng     => l_lng',
'        ,p_lat_min => l_lat_min',
'        ,p_lat_max => l_lat_max',
'        ,p_lng_min => l_lng_min',
'        ,p_lng_max => l_lng_max',
'        );',
'',
'    -- show entire map if no points to show',
'    ELSIF l_markers_data IS NULL THEN',
'      l_lat := 0;',
'      l_lng := 0;',
'      l_latlong := ''0,0'';',
'      l_lat_min := -90;',
'      l_lat_max := 90;',
'      l_lng_min := -180;',
'      l_lng_max := 180;',
'',
'    END IF;',
'    ',
'    IF l_sync_item IS NOT NULL THEN',
'      l_ajax_items := ''#'' || l_sync_item;',
'    END IF;',
'    IF l_dist_item IS NOT NULL THEN',
'      IF l_ajax_items IS NOT NULL THEN',
'        l_ajax_items := l_ajax_items || '','';',
'      END IF;',
'      l_ajax_items := l_ajax_items || ''#'' || l_dist_item;',
'    END IF;',
'    ',
'    l_html := q''[',
'<script>',
'var map_#REGION#, iw_#REGION#, reppin_#REGION#, userpin_#REGION#, distcircle_#REGION#, mapdata_#REGION#;',
'function r_#REGION#(f){/in/.test(document.readyState)?setTimeout("r_#REGION#("+f+")",9):f()}',
'function geocode_#REGION#(geocoder,map) {',
'  var address = $v("#GEOCODEITEM#");',
'  geocoder.geocode({"address": address#COUNTRY_RESTRICT#}',
'  , function(results, status) {',
'    if (status === google.maps.GeocoderStatus.OK) {',
'      var pos = results[0].geometry.location;',
'      console.log("#REGION# geocode ok");',
'      map.setCenter(pos);',
'      map.panTo(pos);',
'      if ("#CLICKZOOM#" != "") {',
'        map.setZoom(#CLICKZOOM#);',
'      }',
'      userPin_#REGION#(pos.lat(), pos.lng())',
'    } else {',
'      console.log("#REGION# geocode was unsuccessful for the following reason: "+status);',
'    }',
'  });',
'}',
'function repPin_#REGION#(pData) {',
'  var reppin = new google.maps.Marker({',
'                 map: map_#REGION#,',
'                 position: new google.maps.LatLng(pData.lat, pData.lng),',
'                 title: pData.name,',
'                 icon: pData.icon',
'               });',
'  google.maps.event.addListener(reppin, "click", function () {',
'    console.log("#REGION# repPin clicked "+pData.id);',
'    if (iw_#REGION#) {',
'      iw_#REGION#.close();',
'    } else {',
'      iw_#REGION# = new google.maps.InfoWindow();',
'    }',
'    iw_#REGION#.setOptions({',
'       content: pData.info',
'      });',
'    iw_#REGION#.open(map_#REGION#, this);',
'    map_#REGION#.panTo(this.getPosition());',
'    if ("#CLICKZOOM#" != "") {',
'      map_#REGION#.setZoom(#CLICKZOOM#);',
'    }',
'    if ("#IDITEM#" !== "") {',
'      $s("#IDITEM#",pData.id);',
'    }',
'    apex.jQuery("##REGION#").trigger("markerclick", {map:map_#REGION#, id:pData.id, name:pData.name, lat:pData.lat, lng:pData.lng});',
'  });',
'  if (!reppin_#REGION#) { reppin_#REGION# = []; }',
'  reppin_#REGION#.push({"id":pData.id,"marker":reppin});',
'}',
'function repPins_#REGION#() {',
'  for (var i = 0; i < mapdata_#REGION#.length; i++) {',
'    repPin_#REGION#(mapdata_#REGION#[i]);',
'  }',
'}',
'function click_#REGION#(id) {',
'  var found = false;',
'  for (var i = 0; i < reppin_#REGION#.length; i++) {',
'    if (reppin_#REGION#[i].id == id) {',
'      new google.maps.event.trigger(reppin_#REGION#[i].marker,"click");',
'      found = true;',
'      break;',
'    }',
'  }',
'  if (!found) {',
'    console.log("#REGION# id not found:"+id);',
'  }',
'}',
'function setCircle_#REGION#(pos) {',
'  if ("#DISTITEM#" !== "") {',
'    if (distcircle_#REGION#) {',
'      console.log("#REGION# move circle");',
'      distcircle_#REGION#.setCenter(pos);',
'      distcircle_#REGION#.setMap(map_#REGION#);',
'    } else {',
'      var radius_km = parseFloat($v("#DISTITEM#"));',
'      console.log("#REGION# create circle radius="+radius_km);',
'      distcircle_#REGION# = new google.maps.Circle({',
'          strokeColor: "#5050FF",',
'          strokeOpacity: 0.5,',
'          strokeWeight: 2,',
'          fillColor: "#0000FF",',
'          fillOpacity: 0.05,',
'          clickable: false,',
'          editable: true,',
'          map: map_#REGION#,',
'          center: pos,',
'          radius: radius_km*1000',
'        });',
'      google.maps.event.addListener(distcircle_#REGION#, "radius_changed", function (event) {',
'        var radius_km = distcircle_#REGION#.getRadius()/1000;',
'        console.log("#REGION# circle radius changed "+radius_km);',
'        $s("#DISTITEM#", radius_km);',
'        refreshMap_#REGION#();',
'      });',
'      google.maps.event.addListener(distcircle_#REGION#, "center_changed", function (event) {',
'        var latlng = distcircle_#REGION#.getCenter().lat()+","+distcircle_#REGION#.getCenter().lng();',
'        console.log("#REGION# circle center changed "+latlng);',
'        if ("#SYNCITEM#" !== "") {',
'          $s("#SYNCITEM#",latlng);',
'          refreshMap_#REGION#();',
'        }',
'      });',
'    }',
'  }',
'}',
'function userPin_#REGION#(lat,lng) {',
'  if (lat !== null && lng !== null) {',
'    var oldpos = userpin_#REGION#?userpin_#REGION#.getPosition():new google.maps.LatLng(0,0);',
'    if (lat == oldpos.lat() && lng == oldpos.lng()) {',
'      console.log("#REGION# userpin not changed");',
'    } else {',
'      var pos = new google.maps.LatLng(lat,lng);',
'      if (userpin_#REGION#) {',
'        console.log("#REGION# move existing pin to new position on map "+lat+","+lng);',
'        userpin_#REGION#.setMap(map_#REGION#);',
'        userpin_#REGION#.setPosition(pos);',
'        setCircle_#REGION#(pos);',
'      } else {',
'        console.log("#REGION# create userpin "+lat+","+lng);',
'        userpin_#REGION# = new google.maps.Marker({map: map_#REGION#, position: pos, icon: "#ICON#"});',
'        setCircle_#REGION#(pos);',
'      }',
'    }',
'  } else if (userpin_#REGION#) {',
'    console.log("#REGION# move existing pin off the map");',
'    userpin_#REGION#.setMap(null);',
'    if (distcircle_#REGION#) {',
'      console.log("#REGION# move distcircle off the map");',
'      distcircle_#REGION#.setMap(null);',
'    }',
'  }',
'}',
'function initMap_#REGION#() {',
'  console.log("#REGION# initMap");',
'  var myOptions = {',
'    zoom: 1,',
'    center: new google.maps.LatLng(#LATLNG#),',
'    mapTypeId: google.maps.MapTypeId.ROADMAP',
'  };',
'  map_#REGION# = new google.maps.Map(document.getElementById("map_#REGION#_container"),myOptions);',
'  map_#REGION#.fitBounds(new google.maps.LatLngBounds({#SOUTHWEST#},{#NORTHEAST#}));',
'  if ("#SYNCITEM#" !== "") {',
'    var val = $v("#SYNCITEM#");',
'    if (val !== null && val.indexOf(",") > -1) {',
'      var arr = val.split(",");',
'      console.log("#REGION# init from item "+val);',
'      var pos = new google.maps.LatLng(arr[0],arr[1]);',
'      userpin_#REGION# = new google.maps.Marker({map: map_#REGION#, position: pos, icon: "#ICON#"});',
'      setCircle_#REGION#(pos);',
'    }',
'    //if the lat/long item is changed, move the pin',
'    $("##SYNCITEM#").change(function(){ ',
'      var latlng = this.value;',
'      if (latlng !== null && latlng !== undefined && latlng.indexOf(",") > -1) {',
'        console.log("#REGION# item changed "+latlng);',
'        var arr = latlng.split(",");',
'        userPin_#REGION#(arr[0],arr[1]);',
'      }',
'    });',
'  }',
'  if ("#DISTITEM#" != "") {',
'    //if the distance item is changed, redraw the circle',
'    $("##DISTITEM#").change(function(){',
'      if (this.value) {',
'        var radius_metres = parseFloat(this.value)*1000;',
'        if (distcircle_#REGION#.getRadius() !== radius_metres) {',
'          console.log("#REGION# distitem changed "+this.value);',
'          distcircle_#REGION#.setRadius(radius_metres);',
'        }',
'      } else {',
'        if (distcircle_#REGION#) {',
'          console.log("#REGION# distitem cleared");',
'          distcircle_#REGION#.setMap(null);',
'        }',
'      }',
'    });',
'  }',
'  repPins_#REGION#();',
'  google.maps.event.addListener(map_#REGION#, "click", function (event) {',
'    var lat = event.latLng.lat()',
'       ,lng = event.latLng.lng();',
'    console.log("#REGION# map clicked "+lat+","+lng);',
'    if ("#SYNCITEM#" !== "") {',
'      userPin_#REGION#(lat,lng);',
'      $s("#SYNCITEM#",lat+","+lng);',
'      refreshMap_#REGION#();',
'    }',
'    apex.jQuery("##REGION#").trigger("mapclick", {map:map_#REGION#, lat:lat, lng:lng});',
'  });',
'  if ("#GEOCODEITEM#" != "") {',
'    var geocoder = new google.maps.Geocoder();',
'    $("##GEOCODEITEM#").change(function(){',
'      geocode_#REGION#(geocoder, map_#REGION#);',
'    });',
'  }',
'  console.log("#REGION# initMap finished");',
'  apex.jQuery("##REGION#").trigger("maploaded", {map:map_#REGION#});',
'}',
'function refreshMap_#REGION#() {',
'  console.log("#REGION# refreshMap");',
'  apex.jQuery("##REGION#").trigger("apexbeforerefresh");',
'  apex.server.plugin',
'    ("#AJAX_IDENTIFIER#"',
'    ,{ pageItems: "#AJAX_ITEMS#" }',
'    ,{ dataType: "json"',
'      ,success: function( pData ) {',
'          console.log("#REGION# success pData="+pData.southwest.lat+","+pData.southwest.lng+" "+pData.northeast.lat+","+pData.northeast.lng);',
'          map_#REGION#.fitBounds(',
'            {south:pData.southwest.lat',
'            ,west:pData.southwest.lng',
'            ,north:pData.northeast.lat',
'            ,east:pData.northeast.lng});',
'          if (iw_#REGION#) {',
'            iw_#REGION#.close();',
'          }',
'          console.log("#REGION# remove all report pins");',
'          for (var i = 0; i < reppin_#REGION#.length; i++) {',
'            var marker = reppin_#REGION#[i].marker; ',
'            marker.setMap(null);',
'          }',
'          console.log("pData.mapdata.length="+pData.mapdata.length);',
'          mapdata_#REGION# = pData.mapdata;',
'          repPins_#REGION#();',
'          if ("#SYNCITEM#" !== "") {',
'            var val = $v("#SYNCITEM#");',
'            if (val !== null && val.indexOf(",") > -1) {',
'              var arr = val.split(",");',
'              console.log("#REGION# init from item "+val);',
'              userPin_#REGION#(arr[0],arr[1]);',
'            }',
'          }',
'          apex.jQuery("##REGION#").trigger("apexafterrefresh");',
'       }',
'     } );',
'  console.log("#REGION# refreshMap finished");',
'}',
'r_#REGION#(function(){',
'  mapdata_#REGION# = [#MAPDATA#];',
'  initMap_#REGION#();',
'  apex.jQuery("##REGION#").bind("apexrefresh", function(){refreshMap_#REGION#();});',
'});',
'</script>',
'<div id="map_#REGION#_container" style="min-height:#MAPHEIGHT#px"></div>]'';',
'',
'    l_html := REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(',
'              REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(',
'              REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(',
'      l_html',
'      ,''#SOUTHWEST#'',        latlng2ch(l_lat_min,l_lng_min))',
'      ,''#NORTHEAST#'',        latlng2ch(l_lat_max,l_lng_max))',
'      ,''#MAPDATA#'',          l_markers_data)',
'      ,''#MAPHEIGHT#'',        l_map_height)',
'      ,''#IDITEM#'',           l_id_item)',
'      ,''#CLICKZOOM#'',        l_click_zoom)',
'      ,''#REGION#'',           CASE',
'                             WHEN p_region.static_id IS NOT NULL',
'                             THEN p_region.static_id',
'                             ELSE ''R''||p_region.id',
'                             END)',
'      ,''#LATLNG#'',           l_latlong)',
'      ,''#SYNCITEM#'',         l_sync_item)',
'      ,''#ICON#'',             l_markericon)',
'      ,''#DISTITEM#'',         l_dist_item)',
'      ,''#AJAX_IDENTIFIER#'',  APEX_PLUGIN.get_ajax_identifier)',
'      ,''#AJAX_ITEMS#'',       l_ajax_items)',
'      ,''#GEOCODEITEM#'',      l_geocode_item)',
'      ,''#COUNTRY_RESTRICT#'', CASE WHEN l_country IS NOT NULL',
'                             THEN '',componentRestrictions:{country:"''||l_country||''"}''',
'                             END);',
'      ',
'    SYS.HTP.p(l_html);',
'  ',
'    RETURN l_result;',
'END render_map;',
'',
'FUNCTION ajax',
'    (p_region IN APEX_PLUGIN.t_region',
'    ,p_plugin IN APEX_PLUGIN.t_plugin',
'    ) RETURN APEX_PLUGIN.t_region_ajax_result IS',
'',
'    SUBTYPE plugin_attr is VARCHAR2(32767);',
'',
'    l_result APEX_PLUGIN.t_region_ajax_result;',
'',
'    l_lat          NUMBER;',
'    l_lng          NUMBER;',
'    l_markers_data VARCHAR2(32767);',
'    l_lat_min      NUMBER;',
'    l_lat_max      NUMBER;',
'    l_lng_min      NUMBER;',
'    l_lng_max      NUMBER;',
'',
'    -- Component attributes',
'    l_sync_item     plugin_attr := p_region.attribute_04;',
'    l_latlong       plugin_attr := p_region.attribute_06;',
'',
'BEGIN',
'    -- debug information will be included',
'    IF APEX_APPLICATION.g_debug then',
'        APEX_PLUGIN_UTIL.debug_region',
'          (p_plugin => p_plugin',
'          ,p_region => p_region);',
'    END IF;',
'',
'    IF p_region.source IS NOT NULL THEN',
'',
'      l_markers_data := get_markers',
'        (p_region  => p_region',
'        ,p_lat_min => l_lat_min',
'        ,p_lat_max => l_lat_max',
'        ,p_lng_min => l_lng_min',
'        ,p_lng_max => l_lng_max',
'        );',
'        ',
'    END IF;',
'    ',
'    -- if sync item is set, include its position in the initial map extent',
'    IF l_sync_item IS NOT NULL THEN',
'      l_latlong := NVL(v(l_sync_item),l_latlong);',
'    END IF;',
'    ',
'    IF l_latlong IS NOT NULL THEN',
'      l_lat := TO_NUMBER(SUBSTR(l_latlong,1,INSTR(l_latlong,'','')-1));',
'      l_lng := TO_NUMBER(SUBSTR(l_latlong,INSTR(l_latlong,'','')+1));',
'    END IF;',
'    ',
'    IF l_lat IS NOT NULL THEN',
'      set_map_extents',
'        (p_lat     => l_lat',
'        ,p_lng     => l_lng',
'        ,p_lat_min => l_lat_min',
'        ,p_lat_max => l_lat_max',
'        ,p_lng_min => l_lng_min',
'        ,p_lng_max => l_lng_max',
'        );',
'',
'    -- show entire map if no points to show',
'    ELSIF l_markers_data IS NULL THEN',
'      l_lat := 0;',
'      l_lng := 0;',
'      l_latlong := ''0,0'';',
'      l_lat_min := -90;',
'      l_lat_max := 90;',
'      l_lng_min := -180;',
'      l_lng_max := 180;',
'',
'    END IF;',
'',
'    SYS.OWA_UTIL.mime_header(''text/plain'', false);',
'    SYS.HTP.p(''Cache-Control: no-cache'');',
'    SYS.HTP.p(''Pragma: no-cache'');',
'    SYS.OWA_UTIL.http_header_close;',
'    ',
'    SYS.HTP.p(''{"southwest":{''',
'      || latlng2ch(l_lat_min,l_lng_min)',
'      || ''},"northeast":{''',
'      || latlng2ch(l_lat_max,l_lng_max)',
'      || ''},"mapdata":[''',
'      || l_markers_data',
'      || '']}'');',
'',
'    RETURN l_result;',
'END ajax;'))
,p_render_function=>'render_map'
,p_ajax_function=>'ajax'
,p_standard_attributes=>'SOURCE_SQL:AJAX_ITEMS_TO_SUBMIT'
,p_sql_min_column_count=>5
,p_sql_max_column_count=>6
,p_sql_examples=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'<pre>SELECT lat, lng, name, id, info FROM mydata;</pre>',
'<p>',
'<em>Show each point with a selected icon:</em>',
'<p>',
'<pre>SELECT lat, lng, name, id, info, icon FROM mydata;</pre>',
'<p>',
'<em>Get only the data within a certain distance from a chosen point:</em>',
'<p>',
'<pre>',
'SELECT t.lat AS lat',
'      ,t.lng AS lng',
'      ,t.name',
'      ,t.id AS id',
'      ,t.info',
'      ,'''' AS icon',
'FROM   mytable t',
'WHERE  t.lat IS NOT NULL',
'AND    t.lng IS NOT NULL',
'AND    (:P1_LATLNG IS NULL',
'     OR :P1_RADIUS IS NULL',
'     OR SDO_GEOM.sdo_distance',
'          (geom1 => SDO_GEOMETRY',
'            (sdo_gtype     => 2001 /* 2-dimensional point */',
'            ,sdo_srid      => 8307 /* Longitude / Latitude (WGS 84) */',
'            ,sdo_point     => SDO_POINT_TYPE(t.lng, t.lat, NULL)',
'            ,sdo_elem_info => NULL',
'            ,sdo_ordinates => NULL)',
'          ,geom2 => SDO_GEOMETRY',
'            (sdo_gtype     => 2001 /* 2-dimensional point */',
'            ,sdo_srid      => 8307 /* Longitude / Latitude (WGS 84) */',
'            ,sdo_point     => SDO_POINT_TYPE',
'               (TO_NUMBER(SUBSTR(:P1_LATLNG,INSTR(:P1_LATLNG,'','')+1))',
'               ,TO_NUMBER(SUBSTR(:P1_LATLNG,1,INSTR(:P1_LATLNG,'','')-1)), NULL)',
'            ,sdo_elem_info => NULL',
'            ,sdo_ordinates => NULL)',
'          ,tol   => 0.0001 /*metres*/',
'          ,unit  => ''unit=KM'') < :P1_RADIUS)',
'</pre>'))
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_help_text=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'This plugin renders a Google Map, showing a number of pins based on a query you supply with Latitude, Longitude, Name (pin hovertext), id (returned to an item you specify, if required), and Info.',
'<P>',
'When the user clicks any pin, the map pans to that point, and (optionally) zooms into it. An info window pops up with the Info you supply in the query. This can include HTML code including links, for example. The markerClick event will be fired when '
||'this happens (you can create a dynamic action to respond to this if you want).',
'<P>',
'If you supply a Sync Item and a Distance item, the map will allow the user to click any point on the map, drag out the radius of a circle, and then re-run the query (e.g. to show only those pins within the indicated circle. Look at the SQL Query exam'
||'ples for how to do this.',
'<P>',
'If the query includes the 6th column (icon), it must refer to an image file that will be used instead of the standard red pin (<img src="http://maps.google.com/mapfiles/ms/icons/red-dot.png">). You can refer to pins like these, or refer to your own i'
||'mages.',
'<P>',
'If icons are supplied they need to be fully-qualified URIs to an icon image to be used. e.g.',
'<P>',
'http://maps.google.com/mapfiles/ms/icons/blue-dot.png',
'http://maps.google.com/mapfiles/ms/icons/red-dot.png',
'http://maps.google.com/mapfiles/ms/icons/purple-dot.png',
'http://maps.google.com/mapfiles/ms/icons/yellow-dot.png',
'http://maps.google.com/mapfiles/ms/icons/green-dot.png',
'http://maps.google.com/mapfiles/ms/icons/ylw-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/blue-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/grn-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/ltblu-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/pink-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/purple-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/red-pushpin.png'))
,p_version_identifier=>'0.4'
,p_about_url=>'https://github.com/jeffreykemp/jk64-plugin-reportmap'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(75127295279118430)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Google API Key'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_display_length=>60
,p_is_translatable=>false
,p_help_text=>'Optional. If you don''t set this, you may get a "Google Maps API warning: NoApiKeys" warning in the console log. You can add this later if required. Refer: https://developers.google.com/maps/documentation/javascript/get-api-key#get-an-api-key'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(218513145091470932)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Min. Map Height'
,p_attribute_type=>'NUMBER'
,p_is_required=>true
,p_default_value=>'400'
,p_unit=>'pixels'
,p_is_translatable=>false
,p_help_text=>'Desired height (in pixels) of the map region. Note: the width will adjust according to the available area of the containing window.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(218513489962474493)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'Set Item Name to ID on Click'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_help_text=>'When the user clicks on a map marker, the corresponding ID from your data will be copied to this page item.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(218513827135479678)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'Zoom Level on Click'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_default_value=>'13'
,p_unit=>'(0-23)'
,p_is_translatable=>false
,p_help_text=>'When the user clicks on a map marker, or adds a new marker, zoom the map to this level. Set to blank to not zoom on click.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(223598252584881112)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'Synchronize with Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_help_text=>'Position of the marker will be retrieved from and stored in this item as a Lat,Long value.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(223601564596927567)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_prompt=>'Marker Icon'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>false
,p_examples=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'http://maps.google.com/mapfiles/ms/icons/blue-dot.png',
'http://maps.google.com/mapfiles/ms/icons/red-dot.png',
'http://maps.google.com/mapfiles/ms/icons/purple-dot.png',
'http://maps.google.com/mapfiles/ms/icons/yellow-dot.png',
'http://maps.google.com/mapfiles/ms/icons/green-dot.png',
'http://maps.google.com/mapfiles/ms/icons/ylw-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/blue-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/grn-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/ltblu-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/pink-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/purple-pushpin.png',
'http://maps.google.com/mapfiles/ms/icons/red-pushpin.png'))
,p_help_text=>'URL to the icon to show for the marker. Leave blank for the default red Google pin.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(223608185986716624)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'Initial Map Position'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_unit=>'lat,long'
,p_is_translatable=>false
,p_help_text=>'Set the latitude and longitude as a pair of numbers to be used to position the map on page load, if no pin coordinates have been provided by the page item.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(223610549297416918)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Circle Radius Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(223598252584881112)
,p_depending_on_condition_type=>'NOT_NULL'
,p_help_text=>'Set to an item which contains the distance (in Kilometres) to draw a circle around the click point. Leave blank to not draw a circle. If the item is changed, the circle will be updated. If you set this attribute, you must also set Synchronize with It'
||'em.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(75129056673204272)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>8
,p_display_sequence=>80
,p_prompt=>'Enable Google Sign-In'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_default_value=>'N'
,p_is_translatable=>false
,p_help_text=>'Set to Yes to enable Google sign-in on the map. Only works if you set the Google API Key.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(75137999717846446)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>9
,p_display_sequence=>90
,p_prompt=>'Geocode Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_help_text=>'Set to a text item on the page. If the text item contains the name of a location or an address, a Google Maps Geocode search will be done and, if found, the map will be moved to that location and a pin shown. NOTE: requires a Google API key to be set'
||' at the application level.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(75139231492017016)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>10
,p_display_sequence=>100
,p_prompt=>'Restrict to Country code'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_display_length=>10
,p_max_length=>2
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(75137999717846446)
,p_depending_on_condition_type=>'NOT_NULL'
,p_text_case=>'UPPER'
,p_examples=>'AU'
,p_help_text=>'Leave blank to allow geocoding to find any place on earth. Set to country code (see https://developers.google.com/public-data/docs/canonical/countries_csv for valid values) to restrict geocoder to that country.'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(218512669450466691)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_name=>'mapclick'
,p_display_name=>'mapClick'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(75131912087488337)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_name=>'maploaded'
,p_display_name=>'mapLoaded'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(225229248728482807)
,p_plugin_id=>wwv_flow_api.id(218512352878463408)
,p_name=>'markerclick'
,p_display_name=>'markerClick'
);
end;
/
begin
wwv_flow_api.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false), p_is_component_import => true);
commit;
end;
/
set verify on feedback on define on
prompt  ...done
