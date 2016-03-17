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
,p_default_application_id=>15181
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
 p_id=>wwv_flow_api.id(293857912426657344)
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
'    l_markers_data   VARCHAR2(32767);',
'    l_lat            NUMBER;',
'    l_lng            NUMBER;',
'    l_icon           VARCHAR2(4000);',
'    l_radius_km      NUMBER; -- e.g. 5.5(km)',
'    l_circle_color   VARCHAR2(100);',
'    l_circle_transp  NUMBER; -- e.g. 0.10 for 10% transparency',
'',
'    l_column_value_list  APEX_PLUGIN_UTIL.t_column_value_list;',
'',
'BEGIN',
'',
'    l_column_value_list := APEX_PLUGIN_UTIL.get_data',
'        (p_sql_statement  => p_region.source',
'        ,p_min_columns    => 5',
'        ,p_max_columns    => 9',
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
'        -- default values if not supplied in query',
'        l_icon          := NULL;',
'        l_radius_km     := NULL;',
'        l_circle_color  := ''#0000cc'';',
'        l_circle_transp := ''0.30'';',
'        ',
'        IF l_column_value_list.EXISTS(6) THEN',
'          l_icon := l_column_value_list(6)(i);',
'        IF l_column_value_list.EXISTS(7) THEN',
'          l_radius_km := TO_NUMBER(l_column_value_list(7)(i));',
'        IF l_column_value_list.EXISTS(8) THEN',
'          l_circle_color := l_column_value_list(8)(i);',
'        IF l_column_value_list.EXISTS(9) THEN',
'          l_circle_transp := TO_NUMBER(l_column_value_list(9)(i));',
'        END IF; END IF; END IF; END IF;',
'  ',
'        l_markers_data := l_markers_data',
'          || ''{"id":''   || APEX_ESCAPE.js_literal(l_column_value_list(4)(i),''"'')',
'          || '',"name":'' || APEX_ESCAPE.js_literal(l_column_value_list(3)(i),''"'')',
'          || '',"info":'' || APEX_ESCAPE.js_literal(l_column_value_list(5)(i),''"'')',
'          || '',''        || latlng2ch(l_lat,l_lng)',
'          || '',"icon":'' || APEX_ESCAPE.js_literal(l_icon,''"'')',
'		  || CASE WHEN l_radius_km IS NOT NULL THEN',
'		     '',"rad":'' || TO_CHAR(l_radius_km,''fm99999999999990.09999999999999'')',
'		  || '',"col":'' || APEX_ESCAPE.js_literal(l_circle_color,''"'')',
'		  || '',"trns":''|| l_circle_transp',
'		     END',
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
'    l_lat          number;',
'    l_lng          number;',
'    l_region       varchar2(100);',
'    l_script       varchar2(32767);',
'    l_markers_data varchar2(32767);',
'    l_lat_min      number;',
'    l_lat_max      number;',
'    l_lng_min      number;',
'    l_lng_max      number;',
'    l_ajax_items   varchar2(1000);',
'    l_js_params    varchar2(1000);',
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
'      ,p_skip_extension => true);',
'',
'    APEX_JAVASCRIPT.add_library',
'      (p_name           => ''jk64plugin'' --TODO ''.min''',
'      ,p_directory      => p_plugin.file_prefix);',
'',
'    l_region := CASE',
'                WHEN p_region.static_id IS NOT NULL',
'                THEN p_region.static_id',
'                ELSE ''R''||p_region.id',
'                END;',
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
'    l_script := ''',
'var opt_#REGION# = {',
'   container:      "map_#REGION#_container"',
'  ,regionId:       "#REGION#"',
'  ,ajaxIdentifier: "''||APEX_PLUGIN.get_ajax_identifier||''"',
'  ,ajaxItems:      "''||l_ajax_items||''"',
'  ,latlng:         "''||l_latlong||''"',
'  ,markerZoom:     ''||l_click_zoom||''',
'  ,icon:           "''||l_markericon||''"',
'  ,idItem:         "''||l_id_item||''"',
'  ,syncItem:       "''||l_sync_item||''"',
'  ,distItem:       "''||l_dist_item||''"',
'  ,geocodeItem:    "''||l_geocode_item||''"',
'  ,country:        "''||l_country||''"',
'  ,southwest:      {''||latlng2ch(l_lat_min,l_lng_min)||''}',
'  ,northeast:      {''||latlng2ch(l_lat_max,l_lng_max)||''}',
'};',
'function click_#REGION#(id) {',
'  jk64plugin_click(opt_#REGION#,id);',
'}',
'function r_#REGION#(f){/in/.test(document.readyState)?setTimeout("r_#REGION#("+f+")",9):f()}',
'r_#REGION#(function(){',
'  opt_#REGION#.mapdata = [''||l_markers_data||''];',
'  jk64plugin_initMap(opt_#REGION#);',
'  apex.jQuery("#"+opt_#REGION#.regionId).bind("apexrefresh", function(){jk64plugin_refreshMap(opt_#REGION#);});',
'});'';',
'',
'    l_script := REPLACE(l_script,''#REGION#'',l_region);',
'      ',
'    sys.htp.p(''<script>''||l_script||''</script>'');',
'    sys.htp.p(''<div id="map_''||l_region||''_container" style="min-height:''||l_map_height||''px"></div>'');',
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
,p_sql_max_column_count=>9
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
'</pre>',
'<p>',
'<em>Population map (show circles instead of pins):</em>',
'<p>',
'<pre>SELECT lat, lng, name, id, info, '''' AS icon,',
'       radius_km, ''#cc0000'' AS color, ''0.05'' as transparency',
'FROM mydata;</pre>',
''))
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
,p_files_version=>7
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(150472854827312366)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
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
 p_id=>wwv_flow_api.id(293858704639664868)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
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
 p_id=>wwv_flow_api.id(293859049510668429)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
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
 p_id=>wwv_flow_api.id(293859386683673614)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
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
 p_id=>wwv_flow_api.id(298943812133075048)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'Synchronize with Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_help_text=>'Position of the marker will be retrieved from and stored in this item as a Lat,Long value. Also, if the item value is changed, the marker will be moved on the map.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(298947124145121503)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
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
 p_id=>wwv_flow_api.id(298953745534910560)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
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
 p_id=>wwv_flow_api.id(298956108845610854)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Circle Radius Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(298943812133075048)
,p_depending_on_condition_type=>'NOT_NULL'
,p_help_text=>'Set to an item which contains the distance (in Kilometres) to draw a circle around the click point. Leave blank to not draw a circle. If the item is changed, the circle will be updated. If you set this attribute, you must also set Synchronize with It'
||'em.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(150474616221398208)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
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
 p_id=>wwv_flow_api.id(150483559266040382)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
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
 p_id=>wwv_flow_api.id(150484791040210952)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>10
,p_display_sequence=>100
,p_prompt=>'Restrict to Country code'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_display_length=>10
,p_max_length=>2
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(150483559266040382)
,p_depending_on_condition_type=>'NOT_NULL'
,p_text_case=>'UPPER'
,p_examples=>'AU'
,p_help_text=>'Leave blank to allow geocoding to find any place on earth. Set to country code (see https://developers.google.com/public-data/docs/canonical/countries_csv for valid values) to restrict geocoder to that country.'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(293858228998660627)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
,p_name=>'mapclick'
,p_display_name=>'mapClick'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(150477471635682273)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
,p_name=>'maploaded'
,p_display_name=>'mapLoaded'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(300574808276676743)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
,p_name=>'markerclick'
,p_display_name=>'markerClick'
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '66756E6374696F6E206A6B3634706C7567696E5F67656F636F6465286F70742C67656F636F64657229207B0D0A202067656F636F6465722E67656F636F6465280D0A202020207B616464726573733A202476286F70742E67656F636F64654974656D290D';
wwv_flow_api.g_varchar2_table(2) := '0A202020202C636F6D706F6E656E745265737472696374696F6E733A206F70742E636F756E747279213D3D22223F7B636F756E7472793A6F70742E636F756E7472797D3A7B7D0D0A20207D2C2066756E6374696F6E28726573756C74732C207374617475';
wwv_flow_api.g_varchar2_table(3) := '7329207B0D0A2020202069662028737461747573203D3D3D20676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B29207B0D0A20202020202076617220706F73203D20726573756C74735B305D2E67656F6D657472792E6C6F636174';
wwv_flow_api.g_varchar2_table(4) := '696F6E3B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B222067656F636F6465206F6B22293B0D0A2020202020206F70742E6D61702E73657443656E74657228706F73293B0D0A2020202020206F70742E6D61702E7061';
wwv_flow_api.g_varchar2_table(5) := '6E546F28706F73293B0D0A202020202020696620286F70742E6D61726B65725A6F6F6D29207B0D0A20202020202020206F70742E6D61702E7365745A6F6F6D286F70742E6D61726B65725A6F6F6D293B0D0A2020202020207D0D0A2020202020206A6B36';
wwv_flow_api.g_varchar2_table(6) := '34706C7567696E5F7573657250696E286F70742C706F732E6C617428292C20706F732E6C6E672829290D0A202020207D20656C7365207B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B222067656F636F646520776173';
wwv_flow_api.g_varchar2_table(7) := '20756E7375636365737366756C20666F722074686520666F6C6C6F77696E6720726561736F6E3A20222B737461747573293B0D0A202020207D0D0A20207D293B0D0A7D0D0A66756E6374696F6E206A6B3634706C7567696E5F72657050696E286F70742C';
wwv_flow_api.g_varchar2_table(8) := '704461746129207B0D0A0976617220706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E672870446174612E6C61742C2070446174612E6C6E67293B0D0A096966202870446174612E72616429207B0D0A09097661722063697263203D20';
wwv_flow_api.g_varchar2_table(9) := '6E657720676F6F676C652E6D6170732E436972636C65287B0D0A202020202020202020207374726F6B65436F6C6F723A2070446174612E636F6C2C0D0A202020202020202020207374726F6B654F7061636974793A20312E302C0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(10) := '20207374726F6B655765696768743A20312C0D0A2020202020202020202066696C6C436F6C6F723A2070446174612E636F6C2C0D0A2020202020202020202066696C6C4F7061636974793A2070446174612E74726E732C0D0A2020202020202020202063';
wwv_flow_api.g_varchar2_table(11) := '6C69636B61626C653A20747275652C0D0A202020202020202020206D61703A206F70742E6D61702C0D0A2020202020202020202063656E7465723A20706F732C0D0A202020202020202020207261646975733A2070446174612E7261642A313030300D0A';
wwv_flow_api.g_varchar2_table(12) := '09097D293B0D0A0909676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228636972632C2022636C69636B222C2066756E6374696F6E202829207B0D0A090909617065782E6465627567286F70742E726567696F6E49642B22206369';
wwv_flow_api.g_varchar2_table(13) := '72636C6520636C69636B656420222B70446174612E6964293B0D0A090909696620286F70742E697729207B0D0A090909096F70742E69772E636C6F736528293B0D0A0909097D20656C7365207B0D0A090909096F70742E6977203D206E657720676F6F67';
wwv_flow_api.g_varchar2_table(14) := '6C652E6D6170732E496E666F57696E646F7728293B0D0A0909097D0D0A0909096F70742E69772E7365744F7074696F6E73287B0D0A090909202020636F6E74656E743A2070446174612E696E666F0D0A09090920207D293B0D0A0909096F70742E69772E';
wwv_flow_api.g_varchar2_table(15) := '6F70656E286F70742E6D61702C2074686973293B0D0A090909696620286F70742E69644974656D213D3D222229207B0D0A090909092473286F70742E69644974656D2C70446174612E6964293B0D0A0909097D0D0A090909617065782E6A517565727928';
wwv_flow_api.g_varchar2_table(16) := '2223222B6F70742E726567696F6E4964292E7472696767657228226D61726B6572636C69636B222C207B6D61703A6F70742E6D61702C2069643A70446174612E69642C206E616D653A70446174612E6E616D652C206C61743A70446174612E6C61742C20';
wwv_flow_api.g_varchar2_table(17) := '6C6E673A70446174612E6C6E672C207261643A70446174612E7261647D293B0D0A09097D293B0D0A090969662028216F70742E636972636C657329207B206F70742E636972636C65733D5B5D3B207D0D0A09096F70742E636972636C65732E7075736828';
wwv_flow_api.g_varchar2_table(18) := '7B226964223A70446174612E69642C2263697263223A636972637D293B0D0A097D20656C7365207B0D0A09097661722072657070696E203D206E657720676F6F676C652E6D6170732E4D61726B6572287B0D0A0909090909206D61703A206F70742E6D61';
wwv_flow_api.g_varchar2_table(19) := '702C0D0A090909090920706F736974696F6E3A20706F732C0D0A0909090909207469746C653A2070446174612E6E616D652C0D0A09090909092069636F6E3A2070446174612E69636F6E0D0A090909092020207D293B0D0A0909676F6F676C652E6D6170';
wwv_flow_api.g_varchar2_table(20) := '732E6576656E742E6164644C697374656E65722872657070696E2C2022636C69636B222C2066756E6374696F6E202829207B0D0A090909617065782E6465627567286F70742E726567696F6E49642B222072657050696E20636C69636B656420222B7044';
wwv_flow_api.g_varchar2_table(21) := '6174612E6964293B0D0A090909696620286F70742E697729207B0D0A090909096F70742E69772E636C6F736528293B0D0A0909097D20656C7365207B0D0A090909096F70742E6977203D206E657720676F6F676C652E6D6170732E496E666F57696E646F';
wwv_flow_api.g_varchar2_table(22) := '7728293B0D0A0909097D0D0A0909096F70742E69772E7365744F7074696F6E73287B0D0A090909202020636F6E74656E743A2070446174612E696E666F0D0A09090920207D293B0D0A0909096F70742E69772E6F70656E286F70742E6D61702C20746869';
wwv_flow_api.g_varchar2_table(23) := '73293B0D0A0909096F70742E6D61702E70616E546F28746869732E676574506F736974696F6E2829293B0D0A090909696620286F70742E6D61726B65725A6F6F6D29207B0D0A090909096F70742E6D61702E7365745A6F6F6D286F70742E6D61726B6572';
wwv_flow_api.g_varchar2_table(24) := '5A6F6F6D293B0D0A0909097D0D0A090909696620286F70742E69644974656D213D3D222229207B0D0A090909092473286F70742E69644974656D2C70446174612E6964293B0D0A0909097D0D0A090909617065782E6A5175657279282223222B6F70742E';
wwv_flow_api.g_varchar2_table(25) := '726567696F6E4964292E7472696767657228226D61726B6572636C69636B222C207B6D61703A6F70742E6D61702C2069643A70446174612E69642C206E616D653A70446174612E6E616D652C206C61743A70446174612E6C61742C206C6E673A70446174';
wwv_flow_api.g_varchar2_table(26) := '612E6C6E672C207261643A70446174612E7261647D293B0D0A09097D293B0D0A090969662028216F70742E72657070696E29207B206F70742E72657070696E3D5B5D3B207D0D0A09096F70742E72657070696E2E70757368287B226964223A7044617461';
wwv_flow_api.g_varchar2_table(27) := '2E69642C226D61726B6572223A72657070696E7D293B0D0A097D0D0A7D0D0A66756E6374696F6E206A6B3634706C7567696E5F72657050696E73286F707429207B0D0A2020666F7220287661722069203D20303B2069203C206F70742E6D617064617461';
wwv_flow_api.g_varchar2_table(28) := '2E6C656E6774683B20692B2B29207B0D0A202020206A6B3634706C7567696E5F72657050696E286F70742C6F70742E6D6170646174615B695D293B0D0A20207D0D0A7D0D0A66756E6374696F6E206A6B3634706C7567696E5F636C69636B286F70742C69';
wwv_flow_api.g_varchar2_table(29) := '6429207B0D0A202076617220666F756E64203D2066616C73653B0D0A2020666F7220287661722069203D20303B2069203C206F70742E72657070696E2E6C656E6774683B20692B2B29207B0D0A20202020696620286F70742E72657070696E5B695D2E69';
wwv_flow_api.g_varchar2_table(30) := '643D3D696429207B0D0A2020202020206E657720676F6F676C652E6D6170732E6576656E742E74726967676572286F70742E72657070696E5B695D2E6D61726B65722C22636C69636B22293B0D0A202020202020666F756E64203D20747275653B0D0A20';
wwv_flow_api.g_varchar2_table(31) := '2020202020627265616B3B0D0A202020207D0D0A20207D0D0A20206966202821666F756E6429207B0D0A20202020617065782E6465627567286F70742E726567696F6E49642B22206964206E6F7420666F756E643A222B6964293B0D0A20207D0D0A7D0D';
wwv_flow_api.g_varchar2_table(32) := '0A66756E6374696F6E206A6B3634706C7567696E5F736574436972636C65286F70742C706F7329207B0D0A2020696620286F70742E646973744974656D213D3D222229207B0D0A20202020696620286F70742E64697374636972636C6529207B0D0A2020';
wwv_flow_api.g_varchar2_table(33) := '20202020617065782E6465627567286F70742E726567696F6E49642B22206D6F766520636972636C6522293B0D0A2020202020206F70742E64697374636972636C652E73657443656E74657228706F73293B0D0A2020202020206F70742E646973746369';
wwv_flow_api.g_varchar2_table(34) := '72636C652E7365744D6170286F70742E6D6170293B0D0A202020207D20656C7365207B0D0A202020202020766172207261646975735F6B6D203D207061727365466C6F6174282476286F70742E646973744974656D29293B0D0A20202020202061706578';
wwv_flow_api.g_varchar2_table(35) := '2E6465627567286F70742E726567696F6E49642B222063726561746520636972636C65207261646975733D222B7261646975735F6B6D293B0D0A2020202020206F70742E64697374636972636C65203D206E657720676F6F676C652E6D6170732E436972';
wwv_flow_api.g_varchar2_table(36) := '636C65287B0D0A202020202020202020207374726F6B65436F6C6F723A202223353035304646222C0D0A202020202020202020207374726F6B654F7061636974793A20302E352C0D0A202020202020202020207374726F6B655765696768743A20322C0D';
wwv_flow_api.g_varchar2_table(37) := '0A2020202020202020202066696C6C436F6C6F723A202223303030304646222C0D0A2020202020202020202066696C6C4F7061636974793A20302E30352C0D0A20202020202020202020636C69636B61626C653A2066616C73652C0D0A20202020202020';
wwv_flow_api.g_varchar2_table(38) := '2020206564697461626C653A20747275652C0D0A202020202020202020206D61703A206F70742E6D61702C0D0A2020202020202020202063656E7465723A20706F732C0D0A202020202020202020207261646975733A207261646975735F6B6D2A313030';
wwv_flow_api.g_varchar2_table(39) := '300D0A20202020202020207D293B0D0A202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286F70742E64697374636972636C652C20227261646975735F6368616E676564222C2066756E6374696F6E20286576656E';
wwv_flow_api.g_varchar2_table(40) := '7429207B0D0A2020202020202020766172207261646975735F6B6D203D206F70742E64697374636972636C652E67657452616469757328292F313030303B0D0A2020202020202020617065782E6465627567286F70742E726567696F6E49642B22206369';
wwv_flow_api.g_varchar2_table(41) := '72636C6520726164697573206368616E67656420222B7261646975735F6B6D293B0D0A20202020202020202473286F70742E646973744974656D2C207261646975735F6B6D293B0D0A20202020202020206A6B3634706C7567696E5F726566726573684D';
wwv_flow_api.g_varchar2_table(42) := '6170286F7074293B0D0A2020202020207D293B0D0A202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286F70742E64697374636972636C652C202263656E7465725F6368616E676564222C2066756E6374696F6E20';
wwv_flow_api.g_varchar2_table(43) := '286576656E7429207B0D0A202020202020202076617220637472203D206F70742E64697374636972636C652E67657443656E74657228290D0A20202020202020202020202C6C61746C6E67203D206374722E6C617428292B222C222B6374722E6C6E6728';
wwv_flow_api.g_varchar2_table(44) := '293B0D0A2020202020202020617065782E6465627567286F70742E726567696F6E49642B2220636972636C652063656E746572206368616E67656420222B6C61746C6E67293B0D0A2020202020202020696620286F70742E73796E634974656D213D3D22';
wwv_flow_api.g_varchar2_table(45) := '2229207B0D0A202020202020202020202473286F70742E73796E634974656D2C6C61746C6E67293B0D0A202020202020202020206A6B3634706C7567696E5F726566726573684D6170286F7074293B0D0A20202020202020207D0D0A2020202020207D29';
wwv_flow_api.g_varchar2_table(46) := '3B0D0A202020207D0D0A20207D0D0A7D0D0A66756E6374696F6E206A6B3634706C7567696E5F7573657250696E286F70742C6C61742C6C6E6729207B0D0A2020696620286C6174213D3D6E756C6C202626206C6E67213D3D6E756C6C29207B0D0A202020';
wwv_flow_api.g_varchar2_table(47) := '20766172206F6C64706F73203D206F70742E7573657270696E3F6F70742E7573657270696E2E676574506F736974696F6E28293A6E657720676F6F676C652E6D6170732E4C61744C6E6728302C30293B0D0A20202020696620286C61743D3D6F6C64706F';
wwv_flow_api.g_varchar2_table(48) := '732E6C61742829202626206C6E673D3D6F6C64706F732E6C6E67282929207B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B22207573657270696E206E6F74206368616E67656422293B0D0A202020207D20656C736520';
wwv_flow_api.g_varchar2_table(49) := '7B0D0A20202020202076617220706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E67286C61742C6C6E67293B0D0A202020202020696620286F70742E7573657270696E29207B0D0A2020202020202020617065782E6465627567286F70';
wwv_flow_api.g_varchar2_table(50) := '742E726567696F6E49642B22206D6F7665206578697374696E672070696E20746F206E657720706F736974696F6E206F6E206D617020222B6C61742B222C222B6C6E67293B0D0A20202020202020206F70742E7573657270696E2E7365744D6170286F70';
wwv_flow_api.g_varchar2_table(51) := '742E6D6170293B0D0A20202020202020206F70742E7573657270696E2E736574506F736974696F6E28706F73293B0D0A20202020202020206A6B3634706C7567696E5F736574436972636C65286F70742C706F73293B0D0A2020202020207D20656C7365';
wwv_flow_api.g_varchar2_table(52) := '207B0D0A2020202020202020617065782E6465627567286F70742E726567696F6E49642B2220637265617465207573657270696E20222B6C61742B222C222B6C6E67293B0D0A20202020202020206F70742E7573657270696E203D206E657720676F6F67';
wwv_flow_api.g_varchar2_table(53) := '6C652E6D6170732E4D61726B6572287B6D61703A206F70742E6D61702C20706F736974696F6E3A20706F732C2069636F6E3A206F70742E69636F6E7D293B0D0A20202020202020206A6B3634706C7567696E5F736574436972636C65286F70742C706F73';
wwv_flow_api.g_varchar2_table(54) := '293B0D0A2020202020207D0D0A202020207D0D0A20207D20656C736520696620286F70742E7573657270696E29207B0D0A20202020617065782E6465627567286F70742E726567696F6E49642B22206D6F7665206578697374696E672070696E206F6666';
wwv_flow_api.g_varchar2_table(55) := '20746865206D617022293B0D0A202020206F70742E7573657270696E2E7365744D6170286E756C6C293B0D0A20202020696620286F70742E64697374636972636C6529207B0D0A202020202020617065782E6465627567286F70742E726567696F6E4964';
wwv_flow_api.g_varchar2_table(56) := '2B22206D6F76652064697374636972636C65206F666620746865206D617022293B0D0A2020202020206F70742E64697374636972636C652E7365744D6170286E756C6C293B0D0A202020207D0D0A20207D0D0A7D0D0A66756E6374696F6E206A6B363470';
wwv_flow_api.g_varchar2_table(57) := '6C7567696E5F696E69744D6170286F707429207B0D0A2020617065782E6465627567286F70742E726567696F6E49642B2220696E69744D617022293B0D0A2020766172206D794F7074696F6E73203D207B0D0A202020207A6F6F6D3A20312C0D0A202020';
wwv_flow_api.g_varchar2_table(58) := '2063656E7465723A206E657720676F6F676C652E6D6170732E4C61744C6E67286F70742E6C61746C6E67292C0D0A202020206D61705479706549643A20676F6F676C652E6D6170732E4D61705479706549642E524F41444D41500D0A20207D3B0D0A2020';
wwv_flow_api.g_varchar2_table(59) := '6F70742E6D6170203D206E657720676F6F676C652E6D6170732E4D617028646F63756D656E742E676574456C656D656E7442794964286F70742E636F6E7461696E6572292C6D794F7074696F6E73293B0D0A20206F70742E6D61702E666974426F756E64';
wwv_flow_api.g_varchar2_table(60) := '73286E657720676F6F676C652E6D6170732E4C61744C6E67426F756E6473286F70742E736F757468776573742C6F70742E6E6F7274686561737429293B0D0A2020696620286F70742E73796E634974656D213D3D222229207B0D0A202020207661722076';
wwv_flow_api.g_varchar2_table(61) := '616C203D202476286F70742E73796E634974656D293B0D0A202020206966202876616C20213D3D206E756C6C2026262076616C2E696E6465784F6628222C2229203E202D3129207B0D0A20202020202076617220617272203D2076616C2E73706C697428';
wwv_flow_api.g_varchar2_table(62) := '222C22293B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B2220696E69742066726F6D206974656D20222B76616C293B0D0A20202020202076617220706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E';
wwv_flow_api.g_varchar2_table(63) := '67286172725B305D2C6172725B315D293B0D0A2020202020206F70742E7573657270696E203D206E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A206F70742E6D61702C20706F736974696F6E3A20706F732C2069636F6E3A206F70';
wwv_flow_api.g_varchar2_table(64) := '742E69636F6E7D293B0D0A2020202020206A6B3634706C7567696E5F736574436972636C65286F70742C706F73293B0D0A202020207D0D0A202020202F2F696620746865206C61742F6C6F6E67206974656D206973206368616E6765642C206D6F766520';
wwv_flow_api.g_varchar2_table(65) := '7468652070696E0D0A2020202024282223222B6F70742E73796E634974656D292E6368616E67652866756E6374696F6E28297B200D0A202020202020766172206C61746C6E67203D20746869732E76616C75653B0D0A202020202020696620286C61746C';
wwv_flow_api.g_varchar2_table(66) := '6E6720213D3D206E756C6C202626206C61746C6E6720213D3D20756E646566696E6564202626206C61746C6E672E696E6465784F6628222C2229203E202D3129207B0D0A2020202020202020617065782E6465627567286F70742E726567696F6E49642B';
wwv_flow_api.g_varchar2_table(67) := '22206974656D206368616E67656420222B6C61746C6E67293B0D0A202020202020202076617220617272203D206C61746C6E672E73706C697428222C22293B0D0A20202020202020206A6B3634706C7567696E5F7573657250696E286F70742C6172725B';
wwv_flow_api.g_varchar2_table(68) := '305D2C6172725B315D293B0D0A2020202020207D0D0A202020207D293B0D0A20207D0D0A2020696620286F70742E646973744974656D213D222229207B0D0A202020202F2F6966207468652064697374616E6365206974656D206973206368616E676564';
wwv_flow_api.g_varchar2_table(69) := '2C207265647261772074686520636972636C650D0A2020202024282223222B6F70742E646973744974656D292E6368616E67652866756E6374696F6E28297B0D0A20202020202069662028746869732E76616C756529207B0D0A20202020202020207661';
wwv_flow_api.g_varchar2_table(70) := '72207261646975735F6D6574726573203D207061727365466C6F617428746869732E76616C7565292A313030303B0D0A2020202020202020696620286F70742E64697374636972636C652E676574526164697573282920213D3D207261646975735F6D65';
wwv_flow_api.g_varchar2_table(71) := '7472657329207B0D0A20202020202020202020617065782E6465627567286F70742E726567696F6E49642B2220646973746974656D206368616E67656420222B746869732E76616C7565293B0D0A202020202020202020206F70742E6469737463697263';
wwv_flow_api.g_varchar2_table(72) := '6C652E736574526164697573287261646975735F6D6574726573293B0D0A20202020202020207D0D0A2020202020207D20656C7365207B0D0A2020202020202020696620286F70742E64697374636972636C6529207B0D0A202020202020202020206170';
wwv_flow_api.g_varchar2_table(73) := '65782E6465627567286F70742E726567696F6E49642B2220646973746974656D20636C656172656422293B0D0A202020202020202020206F70742E64697374636972636C652E7365744D6170286E756C6C293B0D0A20202020202020207D0D0A20202020';
wwv_flow_api.g_varchar2_table(74) := '20207D0D0A202020207D293B0D0A20207D0D0A20206A6B3634706C7567696E5F72657050696E73286F7074293B0D0A2020676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286F70742E6D61702C2022636C69636B222C2066756E';
wwv_flow_api.g_varchar2_table(75) := '6374696F6E20286576656E7429207B0D0A20202020766172206C6174203D206576656E742E6C61744C6E672E6C617428290D0A202020202020202C6C6E67203D206576656E742E6C61744C6E672E6C6E6728293B0D0A20202020617065782E6465627567';
wwv_flow_api.g_varchar2_table(76) := '286F70742E726567696F6E49642B22206D617020636C69636B656420222B6C61742B222C222B6C6E67293B0D0A20202020696620286F70742E73796E634974656D20213D3D20222229207B0D0A2020202020206A6B3634706C7567696E5F757365725069';
wwv_flow_api.g_varchar2_table(77) := '6E286F70742C6C61742C6C6E67293B0D0A2020202020202473286F70742E73796E634974656D2C6C61742B222C222B6C6E67293B0D0A2020202020206A6B3634706C7567696E5F726566726573684D6170286F7074293B0D0A202020207D0D0A20202020';
wwv_flow_api.g_varchar2_table(78) := '617065782E6A5175657279282223222B6F70742E726567696F6E4964292E7472696767657228226D6170636C69636B222C207B6D61703A6F70742E6D61702C206C61743A6C61742C206C6E673A6C6E677D293B0D0A20207D293B0D0A2020696620286F70';
wwv_flow_api.g_varchar2_table(79) := '742E67656F636F64654974656D213D222229207B0D0A202020207661722067656F636F646572203D206E657720676F6F676C652E6D6170732E47656F636F64657228293B0D0A2020202024282223222B6F70742E67656F636F64654974656D292E636861';
wwv_flow_api.g_varchar2_table(80) := '6E67652866756E6374696F6E28297B0D0A2020202020206A6B3634706C7567696E5F67656F636F6465286F70742C67656F636F646572293B0D0A202020207D293B0D0A20207D0D0A2020617065782E6465627567286F70742E726567696F6E49642B2220';
wwv_flow_api.g_varchar2_table(81) := '696E69744D61702066696E697368656422293B0D0A2020617065782E6A5175657279282223222B6F70742E726567696F6E4964292E7472696767657228226D61706C6F61646564222C207B6D61703A6F70742E6D61707D293B0D0A7D0D0A66756E637469';
wwv_flow_api.g_varchar2_table(82) := '6F6E206A6B3634706C7567696E5F726566726573684D6170286F707429207B0D0A2020617065782E6465627567286F70742E726567696F6E49642B2220726566726573684D617022293B0D0A2020617065782E6A5175657279282223222B6F70742E7265';
wwv_flow_api.g_varchar2_table(83) := '67696F6E4964292E747269676765722822617065786265666F72657265667265736822293B0D0A2020617065782E7365727665722E706C7567696E0D0A20202020286F70742E616A61784964656E7469666965720D0A202020202C7B2070616765497465';
wwv_flow_api.g_varchar2_table(84) := '6D733A206F70742E616A61784974656D73207D0D0A202020202C7B2064617461547970653A20226A736F6E220D0A2020202020202C737563636573733A2066756E6374696F6E282070446174612029207B0D0A20202020202020202020617065782E6465';
wwv_flow_api.g_varchar2_table(85) := '627567286F70742E726567696F6E49642B2220737563636573732070446174613D222B70446174612E736F757468776573742E6C61742B222C222B70446174612E736F757468776573742E6C6E672B2220222B70446174612E6E6F727468656173742E6C';
wwv_flow_api.g_varchar2_table(86) := '61742B222C222B70446174612E6E6F727468656173742E6C6E67293B0D0A202020202020202020206F70742E6D61702E666974426F756E6473280D0A2020202020202020202020207B736F7574683A70446174612E736F757468776573742E6C61740D0A';
wwv_flow_api.g_varchar2_table(87) := '2020202020202020202020202C776573743A2070446174612E736F757468776573742E6C6E670D0A2020202020202020202020202C6E6F7274683A70446174612E6E6F727468656173742E6C61740D0A2020202020202020202020202C656173743A2070';
wwv_flow_api.g_varchar2_table(88) := '446174612E6E6F727468656173742E6C6E677D293B0D0A20202020202020202020696620286F70742E697729207B0D0A2020202020202020202020206F70742E69772E636C6F736528293B0D0A202020202020202020207D0D0A20202020202020202020';
wwv_flow_api.g_varchar2_table(89) := '617065782E6465627567286F70742E726567696F6E49642B222072656D6F766520616C6C207265706F72742070696E7322293B0D0A20202020202020202020666F7220287661722069203D20303B2069203C206F70742E72657070696E2E6C656E677468';
wwv_flow_api.g_varchar2_table(90) := '3B20692B2B29207B0D0A2020202020202020202020206F70742E72657070696E5B695D2E6D61726B65722E7365744D6170286E756C6C293B0D0A202020202020202020207D0D0A20202020202020202020617065782E6465627567286F70742E72656769';
wwv_flow_api.g_varchar2_table(91) := '6F6E49642B222070446174612E6D6170646174612E6C656E6774683D222B70446174612E6D6170646174612E6C656E677468293B0D0A202020202020202020206F70742E6D617064617461203D2070446174612E6D6170646174613B0D0A202020202020';
wwv_flow_api.g_varchar2_table(92) := '202020206A6B3634706C7567696E5F72657050696E73286F7074293B0D0A20202020202020202020696620286F70742E73796E634974656D213D3D222229207B0D0A2020202020202020202020207661722076616C203D202476286F70742E73796E6349';
wwv_flow_api.g_varchar2_table(93) := '74656D293B0D0A2020202020202020202020206966202876616C213D3D6E756C6C2026262076616C2E696E6465784F6628222C2229203E202D3129207B0D0A202020202020202020202020202076617220617272203D2076616C2E73706C697428222C22';
wwv_flow_api.g_varchar2_table(94) := '293B0D0A2020202020202020202020202020617065782E6465627567286F70742E726567696F6E49642B2220696E69742066726F6D206974656D20222B76616C293B0D0A20202020202020202020202020206A6B3634706C7567696E5F7573657250696E';
wwv_flow_api.g_varchar2_table(95) := '286F70742C6172725B305D2C6172725B315D293B0D0A2020202020202020202020207D0D0A202020202020202020207D0D0A20202020202020202020617065782E6A5175657279282223222B6F70742E726567696F6E4964292E74726967676572282261';
wwv_flow_api.g_varchar2_table(96) := '70657861667465727265667265736822293B0D0A202020202020207D0D0A20202020207D20293B0D0A2020617065782E6465627567286F70742E726567696F6E49642B2220726566726573684D61702066696E697368656422293B0D0A7D0D0A';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(75357362657382878)
,p_plugin_id=>wwv_flow_api.id(293857912426657344)
,p_file_name=>'jk64plugin.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
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
