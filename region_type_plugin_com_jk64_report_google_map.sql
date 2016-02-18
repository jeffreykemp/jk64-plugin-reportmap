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
,p_supported_ui_types=>'DESKTOP'
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
'    l_item_name     plugin_attr := p_region.attribute_02;',
'    l_click_zoom    plugin_attr := p_region.attribute_03;    ',
'BEGIN',
'    -- debug information will be included',
'    if apex_application.g_debug then',
'        apex_plugin_util.debug_region (',
'            p_plugin => p_plugin,',
'            p_region => p_region,',
'            p_is_printer_friendly => p_is_printer_friendly);',
'    end if;',
'    ',
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
'            l_lat_min := LEAST   (NVL(l_lat_min, l_lat), l_lat);',
'            l_lat_max := GREATEST(NVL(l_lat_max, l_lat), l_lat);',
'            l_lng_min := LEAST   (NVL(l_lng_min, l_lng), l_lng);',
'            l_lng_max := GREATEST(NVL(l_lng_max, l_lng), l_lng);',
'          ',
'        END LOOP;',
'        ',
'    END IF;',
'    ',
'    -- show entire map if no points to show',
'    IF l_markers_data IS NULL THEN',
'      l_lat_min := -90;',
'      l_lat_max := 90;',
'      l_lng_min := -180;',
'      l_lng_max := 180;',
'    END IF;',
'    ',
'    l_southwest := ''{lat:''||TO_CHAR(l_lat_min)||'',lng:''||TO_CHAR(l_lng_min)||''}'';',
'    l_northeast := ''{lat:''||TO_CHAR(l_lat_max)||'',lng:''||TO_CHAR(l_lng_max)||''}'';',
'    ',
'    l_html := q''[',
'<script>',
'var map, iw, marker, mapdata;',
'function addMarker(map,pData) {',
'  marker = new google.maps.Marker({',
'                map: map,',
'                position: new google.maps.LatLng(pData.lat, pData.lng),',
'                title: pData.name,',
'                icon: pData.icon',
'            });',
' ',
'  google.maps.event.addListener(marker, ''click'', function () {',
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
'    if ("#ITEMNAME#" !== "") {',
'      $s("#ITEMNAME#",pData.id);',
'    }',
'    apex.jQuery("##REGION_ID#").trigger("mapclick", {id:pData.id, name:pData.name, lat:pData.lat, lng:pData.lng});',
'  });',
'}',
'function initMap() {',
'  var bounds = new google.maps.LatLngBounds(#SOUTHWEST#,#NORTHEAST#);',
'  var myOptions = {',
'    mapTypeId: google.maps.MapTypeId.ROADMAP',
'  };',
'  map = new google.maps.Map(document.getElementById("#REGION_ID#_map"),myOptions);',
'  for (var i = 0; i < mapdata.length; i++) {',
'    addMarker(map,mapdata[i]);',
'  }',
'  map.fitBounds(bounds);',
'}',
'window.onload = function() {',
'  mapdata = [#MAPDATA#];',
'  initMap();',
'}',
'</script>',
'<div id="#REGION_ID#_map" style="min-height:#MAPHEIGHT#px"></div>]'';',
'',
'    l_html := REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(l_html',
'      ,''#SOUTHWEST#'', l_southwest)',
'      ,''#NORTHEAST#'', l_northeast)',
'      ,''#MAPDATA#'',   l_markers_data)',
'      ,''#MAPHEIGHT#'', l_map_height)',
'      ,''#ITEMNAME#'',  l_item_name)',
'      ,''#CLICKZOOM#'', l_click_zoom)',
'      ,''#REGION_ID#'', CASE',
'                      WHEN p_region.static_id IS NOT NULL',
'                      THEN p_region.static_id',
'                      ELSE ''R''||p_region.id',
'                      END);',
'      ',
'    sys.htp.p(l_html);',
'  ',
'    return l_result;',
'END render_map;    '))
,p_render_function=>'render_map'
,p_standard_attributes=>'SOURCE_SQL:SOURCE_REQUIRED:AJAX_ITEMS_TO_SUBMIT'
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
,p_version_identifier=>'0.2'
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
,p_supported_ui_types=>'DESKTOP'
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
,p_supported_ui_types=>'DESKTOP'
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
,p_supported_ui_types=>'DESKTOP'
,p_is_translatable=>false
,p_help_text=>'When the user clicks on a map marker, zoom the map to this level. Set to blank to not zoom on click.'
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
