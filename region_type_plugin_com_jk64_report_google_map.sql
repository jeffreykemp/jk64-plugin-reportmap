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
 p_id=>wwv_flow_api.id(68313922569222353)
,p_plugin_type=>'REGION TYPE'
,p_name=>'COM.JK64.REPORT_GOOGLE_MAP'
,p_display_name=>'JK64 Report Google Map'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_javascript_file_urls=>'https://maps.googleapis.com/maps/api/js'
,p_plsql_code=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'function render_map (',
'    p_region in apex_plugin.t_region,',
'    p_plugin in apex_plugin.t_plugin,',
'    p_is_printer_friendly in boolean )',
'return apex_plugin.t_region_render_result',
'as',
'    subtype plugin_attr is varchar2(32767);',
'    ',
'    -- Variables',
'    l_result       apex_plugin.t_region_render_result;',
'    l_lat          NUMBER;',
'    l_lng          NUMBER;',
'    l_html         VARCHAR2(32767);',
'    l_markers_data VARCHAR2(32767);',
'    l_lat_min      NUMBER;',
'    l_lat_max      NUMBER;',
'    l_lng_min      NUMBER;',
'    l_lng_max      NUMBER;',
'    l_southwest    VARCHAR2(200);',
'    l_northeast    VARCHAR2(200);',
'    l_icon         VARCHAR2(4000);',
'',
'    l_column_value_list  apex_plugin_util.t_column_value_list;',
'',
'    -- Component attributes',
'    l_map_height    plugin_attr := p_region.attribute_01;',
'    l_id_item       plugin_attr := p_region.attribute_02;',
'    l_click_zoom    plugin_attr := p_region.attribute_03;    ',
'    l_sync_item     plugin_attr := p_region.attribute_04;',
'    l_markericon    plugin_attr := p_region.attribute_05;',
'    l_latlong       plugin_attr := p_region.attribute_06;',
'    l_dist_item     plugin_attr := p_region.attribute_07;',
'    ',
'    PROCEDURE set_map_extents (p_lat IN NUMBER, p_lng IN NUMBER) IS',
'    BEGIN',
'        l_lat_min := LEAST   (NVL(l_lat_min, p_lat), p_lat);',
'        l_lat_max := GREATEST(NVL(l_lat_max, p_lat), p_lat);',
'        l_lng_min := LEAST   (NVL(l_lng_min, p_lng), p_lng);',
'        l_lng_max := GREATEST(NVL(l_lng_max, p_lng), p_lng);',
'    END set_map_extents;',
'BEGIN',
'    -- debug information will be included',
'    if apex_application.g_debug then',
'        apex_plugin_util.debug_region (',
'            p_plugin => p_plugin,',
'            p_region => p_region,',
'            p_is_printer_friendly => p_is_printer_friendly);',
'    end if;',
'',
'    IF p_region.source IS NOT NULL THEN',
'',
'        l_column_value_list := apex_plugin_util.get_data',
'            (p_sql_statement  => p_region.source',
'            ,p_min_columns    => 5',
'            ,p_max_columns    => 6',
'            ,p_component_name => p_region.name',
'            ,p_max_rows       => 1000);',
'',
'        FOR i IN 1..l_column_value_list(1).count LOOP',
'    ',
'            IF l_markers_data IS NOT NULL THEN',
'                l_markers_data := l_markers_data || '','';',
'            END IF;',
'            ',
'            l_lat  := TO_NUMBER(l_column_value_list(1)(i));',
'            l_lng  := TO_NUMBER(l_column_value_list(2)(i));',
'            ',
'            IF l_column_value_list.EXISTS(6) THEN',
'              l_icon := l_column_value_list(6)(i);',
'            END IF;',
'    ',
'            l_markers_data := l_markers_data',
'              || ''{id:''   || APEX_ESCAPE.js_literal(l_column_value_list(4)(i))',
'              || '',name:'' || APEX_ESCAPE.js_literal(l_column_value_list(3)(i))',
'              || '',info:'' || APEX_ESCAPE.js_literal(l_column_value_list(5)(i))',
'              || '',lat:''  || APEX_ESCAPE.js_literal(l_lat)',
'              || '',lng:''  || APEX_ESCAPE.js_literal(l_lng)',
'              || '',icon:'' || APEX_ESCAPE.js_literal(l_icon)',
'              || ''}'';',
'        ',
'            set_map_extents (p_lat => l_lat, p_lng => l_lng);',
'          ',
'        END LOOP;',
'        ',
'    END IF;',
'    ',
'    l_lat := NULL;',
'    l_lng := NULL;',
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
'      set_map_extents (p_lat => l_lat, p_lng => l_lng);',
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
'    l_southwest := ''{lat:''||TO_CHAR(l_lat_min)||'',lng:''||TO_CHAR(l_lng_min)||''}'';',
'    l_northeast := ''{lat:''||TO_CHAR(l_lat_max)||'',lng:''||TO_CHAR(l_lng_max)||''}'';',
'    ',
'    l_html := q''[',
'<script>',
'var map, iw, reppin, userpin, distcircle, mapdata;',
'function repPin(map,pData) {',
'  var reppin = new google.maps.Marker({',
'                 map: map,',
'                 position: new google.maps.LatLng(pData.lat, pData.lng),',
'                 title: pData.name,',
'                 icon: pData.icon',
'               }); ',
'  google.maps.event.addListener(reppin, ''click'', function () {',
'    console.log(''reppin clicked ''+pData.id);',
'    if (iw) {',
'      iw.close();',
'    } else {',
'      iw = new google.maps.InfoWindow();',
'    }',
'    iw.setOptions({',
'       content: pData.info',
'      });',
'    iw.open(map, this);',
'    map.panTo(this.getPosition());',
'    if ("#CLICKZOOM#" != "") {',
'      map.setZoom(#CLICKZOOM#);',
'    }',
'    if ("#IDITEM#" !== "") {',
'      $s("#IDITEM#",pData.id);',
'    }',
'    apex.jQuery("##REGION_ID#").trigger("markerclick", {id:pData.id, name:pData.name, lat:pData.lat, lng:pData.lng});',
'  });',
'}',
'function setCircle(map,pos) {',
'  var distitem = "#DISTITEM#";',
'  if (distitem!=="") {',
'    if (distcircle) {',
'      console.log(''move circle'');',
'      distcircle.setCenter(pos);',
'    } else {',
'      console.log(''create circle'');',
'      var radius_metres = parseFloat($v(distitem))*1000;',
'      distcircle = new google.maps.Circle({',
'          strokeColor: ''#5050FF'',',
'          strokeOpacity: 0.5,',
'          strokeWeight: 2,',
'          fillColor: ''#0000FF'',',
'          fillOpacity: 0.05,',
'          clickable: false,',
'          editable: true,',
'          map: map,',
'          center: pos,',
'          radius: radius_metres',
'        });',
'      google.maps.event.addListener(distcircle, ''radius_changed'', function (event) {',
'        var km = distcircle.getRadius()/1000;',
'        console.log(''circle radius changed ''+km);',
'        $s("#DISTITEM#", km);',
'      });',
'    }',
'  }',
'}',
'function userPin(map,lat,lng) {',
'  if (lat !== null && lng !== null) {',
'    var oldpos = userpin?userpin.getPosition():new google.maps.LatLng(0,0);',
'    if (lat == oldpos.lat() && lng == oldpos.lng()) {',
'      console.log(''not changed'');',
'    } else {',
'      var pos = new google.maps.LatLng(lat,lng);',
'      if (userpin) {',
'        console.log(''move existing pin to new position on map ''+lat+'',''+lng);',
'        userpin.setMap(map);',
'        userpin.setPosition(pos);',
'        setCircle(map,pos);',
'      } else {',
'        console.log(''create userpin ''+lat+'',''+lng);',
'        userpin = new google.maps.Marker({map: map, position: pos, icon: "#ICON#"});',
'        setCircle(map,pos);',
'      }',
'    }',
'  } else if (userpin) {',
'    console.log(''move existing pin off the map'');',
'    userpin.setMap(null);',
'    if (distcircle) {',
'      distcircle.setMap(null);',
'    }',
'  }',
'}',
'function initMap() {',
'  console.log(''initMap'');',
'  var syncitem = "#SYNCITEM#"',
'     ,distitem = "#DISTITEM#"',
'     ,bounds = new google.maps.LatLngBounds(#SOUTHWEST#,#NORTHEAST#);',
'  var myOptions = {',
'    zoom: 1,',
'    center: new google.maps.LatLng(#LATLNG#),',
'    mapTypeId: google.maps.MapTypeId.ROADMAP',
'  };',
'  map = new google.maps.Map(document.getElementById("#REGION_ID#_map"),myOptions);',
'  if (syncitem !== "") {',
'    var val = $v(syncitem);',
'    if (val !== null && val.indexOf(",") > -1) {',
'      var arr = val.split(",");',
'      console.log(''init from item ''+val);',
'      var pos = new google.maps.LatLng(arr[0],arr[1]);',
'      userpin = new google.maps.Marker({map: map, position: pos, icon: "#ICON#"});',
'      setCircle(map,pos);',
'    }',
'    //if the lat/long item is changed, move the pin',
'    $("#"+syncitem).change(function(){ ',
'      var latlng = this.value;',
'      console.log(''item changed ''+latlng);',
'      if (latlng !== null && latlng !== undefined && latlng.indexOf(",") > -1) {',
'        var arr = latlng.split(",");',
'        userPin(map,arr[0],arr[1]);',
'      }    ',
'    });',
'  }',
'  if (distitem) {',
'    //if the distance item is changed, redraw the circle',
'    $("#"+distitem).change(function(){',
'      console.log(''distitem changed ''+this.value);',
'      var radius_metres = parseFloat(this.value)*1000;',
'      if (distcircle.getRadius() !== radius_metres) {',
'        distcircle.setRadius(radius_metres);',
'      }',
'    });',
'  }',
'  for (var i = 0; i < mapdata.length; i++) {',
'    repPin(map,mapdata[i]);',
'  }',
'  map.fitBounds(bounds);',
'  google.maps.event.addListener(map, ''click'', function (event) {',
'    var lat = event.latLng.lat()',
'       ,lng = event.latLng.lng();',
'    console.log(''map clicked ''+lat+'',''+lng);',
'    userPin(map,lat,lng);',
'    if ("#SYNCITEM#" !== "") {',
'      $s("#SYNCITEM#",lat+","+lng);',
'    }',
'    apex.jQuery("##REGION_ID#").trigger("mapclick", {lat:lat, lng:lng});',
'  });',
'  console.log(''initMap finished'');',
'}',
'window.onload = function() {',
'  mapdata = [#MAPDATA#];',
'  initMap();',
'}',
'</script>',
'<div id="#REGION_ID#_map" style="min-height:#MAPHEIGHT#px"></div>]'';',
'',
'    l_html := REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(',
'              REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(',
'              REPLACE(',
'      l_html',
'      ,''#SOUTHWEST#'', l_southwest)',
'      ,''#NORTHEAST#'', l_northeast)',
'      ,''#MAPDATA#'',   l_markers_data)',
'      ,''#MAPHEIGHT#'', l_map_height)',
'      ,''#IDITEM#'',    l_id_item)',
'      ,''#CLICKZOOM#'', l_click_zoom)',
'      ,''#REGION_ID#'', CASE',
'                      WHEN p_region.static_id IS NOT NULL',
'                      THEN p_region.static_id',
'                      ELSE ''R''||p_region.id',
'                      END)',
'      ,''#LATLNG#'',    l_latlong)',
'      ,''#SYNCITEM#'',  l_sync_item)',
'      ,''#ICON#'',      l_markericon)',
'      ,''#DISTITEM#'',  l_dist_item);',
'      ',
'    sys.htp.p(l_html);',
'  ',
'    return l_result;',
'END render_map;'))
,p_render_function=>'render_map'
,p_standard_attributes=>'SOURCE_SQL:AJAX_ITEMS_TO_SUBMIT'
,p_sql_min_column_count=>5
,p_sql_max_column_count=>6
,p_sql_examples=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'<pre>SELECT lat, lng, name, id, info FROM mydata;</pre>',
'<p>',
'<pre>SELECT lat, lng, name, id, info, icon FROM mydata;</pre>'))
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_help_text=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'This plugin renders a Google Map, showing a number of pins based on a query you supply with Latitude, Longitude, Name (pin hovertext), id (returned to an item you specify, if required), and Info.',
'<P>',
'When the user clicks any pin, the map pans to that point, and (optionally) zooms into it. An info window pops up with the Info you supply in the query. This can include HTML code including links, for example.',
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
,p_version_identifier=>'0.3'
,p_about_url=>'https://github.com/jeffreykemp/jk64-plugin-reportmap'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(68314714782229877)
,p_plugin_id=>wwv_flow_api.id(68313922569222353)
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
 p_id=>wwv_flow_api.id(68315059653233438)
,p_plugin_id=>wwv_flow_api.id(68313922569222353)
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
 p_id=>wwv_flow_api.id(68315396826238623)
,p_plugin_id=>wwv_flow_api.id(68313922569222353)
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
 p_id=>wwv_flow_api.id(73399822275640057)
,p_plugin_id=>wwv_flow_api.id(68313922569222353)
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
 p_id=>wwv_flow_api.id(73403134287686512)
,p_plugin_id=>wwv_flow_api.id(68313922569222353)
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
 p_id=>wwv_flow_api.id(73409755677475569)
,p_plugin_id=>wwv_flow_api.id(68313922569222353)
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
 p_id=>wwv_flow_api.id(73412118988175863)
,p_plugin_id=>wwv_flow_api.id(68313922569222353)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Circle Radius Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_help_text=>'Set to an item which contains the distance (in Kilometres) to draw a circle around the click point. Leave blank to not draw a circle. If the item is changed, the circle will be updated.'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(68314239141225636)
,p_plugin_id=>wwv_flow_api.id(68313922569222353)
,p_name=>'mapclick'
,p_display_name=>'mapClick'
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
