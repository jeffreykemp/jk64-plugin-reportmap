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
 p_id=>wwv_flow_api.id(369361923639784586)
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
'      || TO_CHAR(lat, ''fm990.0999999999999999'')',
'      || '',"lng":''',
'      || TO_CHAR(lng, ''fm990.0999999999999999'');',
'END latlng2ch;',
'',
'FUNCTION get_markers',
'    (p_region  IN APEX_PLUGIN.t_region',
'    ,p_lat_min IN OUT NUMBER',
'    ,p_lat_max IN OUT NUMBER',
'    ,p_lng_min IN OUT NUMBER',
'    ,p_lng_max IN OUT NUMBER',
'    ) RETURN APEX_APPLICATION_GLOBAL.VC_ARR2 IS',
'',
'    l_data           APEX_APPLICATION_GLOBAL.VC_ARR2;',
'    l_lat            NUMBER;',
'    l_lng            NUMBER;',
'    l_info           VARCHAR2(4000);',
'    l_icon           VARCHAR2(4000);',
'    l_radius_km      NUMBER;',
'    l_circle_color   VARCHAR2(100);',
'    l_circle_transp  NUMBER;',
'    ',
'    l_column_value_list  APEX_PLUGIN_UTIL.t_column_value_list;',
'',
'BEGIN',
'',
'    l_column_value_list := APEX_PLUGIN_UTIL.get_data',
'        (p_sql_statement  => p_region.source',
'        ,p_min_columns    => 4',
'        ,p_max_columns    => 9',
'        ,p_component_name => p_region.name',
'        ,p_max_rows       => p_region.fetched_rows);',
'  ',
'    FOR i IN 1..l_column_value_list(1).count LOOP',
'  ',
'        l_lat  := TO_NUMBER(l_column_value_list(1)(i));',
'        l_lng  := TO_NUMBER(l_column_value_list(2)(i));',
'        l_info := l_column_value_list(5)(i);',
'        ',
'        -- default values if not supplied in query',
'        l_icon          := NULL;',
'        l_radius_km     := NULL;',
'        l_circle_color  := ''#0000cc'';',
'        l_circle_transp := ''0.3'';',
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
'       ',
'        l_data(NVL(l_data.LAST,0)+1) :=',
'             ''{"id":''  || APEX_ESCAPE.js_literal(l_column_value_list(4)(i),''"'')',
'          || '',"name":''|| APEX_ESCAPE.js_literal(l_column_value_list(3)(i),''"'')',
'          || '',''       || latlng2ch(l_lat,l_lng)',
'          || CASE WHEN l_info IS NOT NULL THEN',
'             '',"info":''|| APEX_ESCAPE.js_literal(l_info,''"'')',
'             END',
'          || '',"icon":''|| APEX_ESCAPE.js_literal(l_icon,''"'')',
'          || CASE WHEN l_radius_km IS NOT NULL THEN',
'             '',"rad":'' || TO_CHAR(l_radius_km,''fm99999999999990.09999999999999'')',
'		      || '',"col":'' || APEX_ESCAPE.js_literal(l_circle_color,''"'')',
'		      ||   CASE WHEN l_circle_transp IS NOT NULL THEN',
'             '',"trns":''|| TO_CHAR(l_circle_transp,''fm990.099'')',
'               END',
'             END',
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
'    RETURN l_data;',
'END get_markers;',
'',
'PROCEDURE htp_arr (arr IN APEX_APPLICATION_GLOBAL.VC_ARR2) IS',
'BEGIN',
'    FOR i IN 1..arr.COUNT LOOP',
'        -- use prn to avoid loading a whole lot of unnecessary \n characters',
'        sys.htp.prn(CASE WHEN i > 1 THEN '','' END || arr(i));',
'    END LOOP;',
'END htp_arr;',
'',
'PROCEDURE fix_latlng',
'  (lat_min IN OUT NUMBER',
'  ,lat_max IN OUT NUMBER',
'  ,lng_min IN OUT NUMBER',
'  ,lng_max IN OUT NUMBER) IS',
'BEGIN',
'  lat_min := GREATEST(lat_min, -80);',
'  lat_max := LEAST(lat_max, 80);',
'  lng_min := MOD(lng_min + 360,180);',
'  lng_max := MOD(lng_max + 360,180);',
'END fix_latlng;',
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
'    l_data         APEX_APPLICATION_GLOBAL.VC_ARR2;',
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
'    l_mapstyle      plugin_attr := p_region.attribute_11;',
'    l_address_item  plugin_attr := p_region.attribute_12;',
'    l_geolocate     plugin_attr := p_region.attribute_13;',
'    l_geoloc_zoom   plugin_attr := p_region.attribute_14;',
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
'        -- these features require a Google API Key to work',
'        l_sign_in      := ''N'';',
'        l_geocode_item := NULL;',
'        l_country      := NULL;',
'        l_address_item := NULL;',
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
'      (p_name           => ''jk64plugin.min''',
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
'      l_data := get_markers',
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
'    IF l_lat IS NOT NULL AND l_data.COUNT > 0 THEN',
'      set_map_extents',
'        (p_lat     => l_lat',
'        ,p_lng     => l_lng',
'        ,p_lat_min => l_lat_min',
'        ,p_lat_max => l_lat_max',
'        ,p_lng_min => l_lng_min',
'        ,p_lng_max => l_lng_max',
'        );',
'',
'    ELSIF l_data.COUNT = 0 AND l_lat IS NOT NULL THEN',
'      l_lat_min := l_lat - 10;',
'      l_lat_max := l_lat + 10;',
'      l_lng_min := l_lng - 10;',
'      l_lng_max := l_lng + 10;',
'',
'    -- show entire map if no points to show',
'    ELSIF l_data.COUNT = 0 THEN',
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
'    fix_latlng(l_lat_min, l_lat_max, l_lng_min, l_lng_max);',
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
'    l_script := ''<script>',
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
'  ,northeast:      {''||latlng2ch(l_lat_max,l_lng_max)||''}''||',
'  CASE WHEN l_mapstyle IS NOT NULL THEN ''',
'  ,mapstyle:       ''||l_mapstyle END || ''',
'  ,addressItem:    "''||l_address_item||''"''||',
'  CASE WHEN l_geolocate = ''Y'' THEN ''',
'  ,geolocate: true'' ||',
'    CASE WHEN l_geoloc_zoom IS NOT NULL THEN ''',
'  ,geolocateZoom: ''||l_geoloc_zoom',
'    END',
'  END || ''',
'  ,noDataMessage:  "''||p_region.no_data_found_message||''"',
'};',
'function click_#REGION#(id) {',
'  jk64plugin_click(opt_#REGION#,id);',
'}',
'function r_#REGION#(f){/in/.test(document.readyState)?setTimeout("r_#REGION#("+f+")",9):f()}',
'r_#REGION#(function(){',
'  opt_#REGION#.mapdata = ['';',
'    sys.htp.p(REPLACE(l_script,''#REGION#'',l_region));',
'    htp_arr(l_data);',
'    l_script := ''];',
'  jk64plugin_initMap(opt_#REGION#);',
'  apex.jQuery("##REGION#").bind("apexrefresh", function(){jk64plugin_refreshMap(opt_#REGION#);});',
'});</script>'';',
'    sys.htp.p(REPLACE(l_script,''#REGION#'',l_region));',
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
'    l_data         APEX_APPLICATION_GLOBAL.VC_ARR2;',
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
'    APEX_DEBUG.message(''ajax'');',
'',
'    IF p_region.source IS NOT NULL THEN',
'',
'      l_data := get_markers',
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
'    IF l_lat IS NOT NULL AND l_data.COUNT > 0 THEN',
'      set_map_extents',
'        (p_lat     => l_lat',
'        ,p_lng     => l_lng',
'        ,p_lat_min => l_lat_min',
'        ,p_lat_max => l_lat_max',
'        ,p_lng_min => l_lng_min',
'        ,p_lng_max => l_lng_max',
'        );',
'',
'    ELSIF l_data.COUNT = 0 AND l_lat IS NOT NULL THEN',
'      l_lat_min := l_lat - 10;',
'      l_lat_max := l_lat + 10;',
'      l_lng_min := l_lng - 10;',
'      l_lng_max := l_lng + 10;',
'',
'    -- show entire map if no points to show',
'    ELSIF l_data.COUNT = 0 THEN',
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
'    fix_latlng(l_lat_min, l_lat_max, l_lng_min, l_lng_max);',
'',
'    sys.owa_util.mime_header(''text/plain'', false);',
'    sys.htp.p(''Cache-Control: no-cache'');',
'    sys.htp.p(''Pragma: no-cache'');',
'    sys.owa_util.http_header_close;',
'',
'    APEX_DEBUG.message(''l_lat_min=''||l_lat_min||'' data=''||l_data.COUNT);',
'    ',
'    sys.htp.p(''{"southwest":{''',
'      || latlng2ch(l_lat_min,l_lng_min)',
'      || ''},"northeast":{''',
'      || latlng2ch(l_lat_max,l_lng_max)',
'      || ''},"mapdata":['');',
'    htp_arr(l_data);',
'    sys.htp.p('']}'');',
'',
'    APEX_DEBUG.message(''ajax finished'');',
'    RETURN l_result;',
'EXCEPTION',
'    WHEN OTHERS THEN',
'        APEX_DEBUG.error(SQLERRM);',
'        sys.htp.p(''{"error":"''||sqlerrm||''"}'');',
'END ajax;'))
,p_render_function=>'render_map'
,p_ajax_function=>'ajax'
,p_standard_attributes=>'SOURCE_SQL:AJAX_ITEMS_TO_SUBMIT:FETCHED_ROWS:NO_DATA_FOUND_MESSAGE'
,p_sql_min_column_count=>4
,p_sql_max_column_count=>9
,p_sql_examples=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'<pre>SELECT lat, lng, name, id FROM mydata;</pre>',
'<p>',
'<em>Show a popup info window when a marker is clicked:</em>',
'<p>',
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
'<pre>',
'SELECT lat, lng, name, id, '''' AS info, '''' AS icon,',
'       radius_km, ''#cc0000'' AS color, ''0.05'' as transparency',
'FROM mydata;',
'</pre>'))
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_help_text=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'This plugin renders a Google Map, showing a number of pins based on a query you supply with Latitude, Longitude, Name (pin hovertext), id (returned to an item you specify, if required), and Info.',
'<p>',
'<strong>Don''t forget to set <em>Number of Rows</em> to a larger number than the default, this is the maximum number of records the report will fetch from your query.</strong>',
'<p>',
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
'http://maps.google.com/mapfiles/ms/icons/red-pushpin.png',
'<p>',
'To create a Population Map (i.e. draw circles of varying radii instead of pins), supply additional columns in the query to indicate radius (in km), and optionally circle colour and transparency.'))
,p_version_identifier=>'0.5'
,p_about_url=>'https://github.com/jeffreykemp/jk64-plugin-reportmap'
,p_files_version=>18
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(225976866040439608)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
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
 p_id=>wwv_flow_api.id(369362715852792110)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
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
 p_id=>wwv_flow_api.id(369363060723795671)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
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
 p_id=>wwv_flow_api.id(369363397896800856)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
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
 p_id=>wwv_flow_api.id(374447823346202290)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
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
 p_id=>wwv_flow_api.id(374451135358248745)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
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
 p_id=>wwv_flow_api.id(374457756748037802)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
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
 p_id=>wwv_flow_api.id(374460120058738096)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Circle Radius Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(374447823346202290)
,p_depending_on_condition_type=>'NOT_NULL'
,p_help_text=>'Set to an item which contains the distance (in Kilometres) to draw a circle around the click point. Leave blank to not draw a circle. If the item is changed, the circle will be updated. If you set this attribute, you must also set Synchronize with It'
||'em.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(225978627434525450)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
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
 p_id=>wwv_flow_api.id(225987570479167624)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
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
 p_id=>wwv_flow_api.id(225988802253338194)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>10
,p_display_sequence=>100
,p_prompt=>'Restrict to Country code'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_display_length=>10
,p_max_length=>40
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(225987570479167624)
,p_depending_on_condition_type=>'NOT_NULL'
,p_text_case=>'UPPER'
,p_examples=>'AU'
,p_help_text=>'Leave blank to allow geocoding to find any place on earth. Set to 2-character country code (see https://developers.google.com/public-data/docs/canonical/countries_csv for valid values) to restrict geocoder to that country. You can set this to a subst'
||'ition variable (e.g. &P1_COUNTRY.) but note that this will only apply if the page is refreshed.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(75480681859350761)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>11
,p_display_sequence=>110
,p_prompt=>'Map Style'
,p_attribute_type=>'TEXTAREA'
,p_is_required=>false
,p_is_translatable=>false
,p_examples=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'Here is an example, a light greyscale style map:',
'<pre>',
'[{"featureType":"water","elementType":"geometry","stylers":[{"color":"#e9e9e9"},{"lightness":17}]},{"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f5f5f5"},{"lightness":20}]},{"featureType":"road.highway","elementType":"geom'
||'etry.fill","stylers":[{"color":"#ffffff"},{"lightness":17}]},{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#ffffff"},{"lightness":29},{"weight":0.2}]},{"featureType":"road.arterial","elementType":"geometry","style'
||'rs":[{"color":"#ffffff"},{"lightness":18}]},{"featureType":"road.local","elementType":"geometry","stylers":[{"color":"#ffffff"},{"lightness":16}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#f5f5f5"},{"lightness":21}]},{"featu'
||'reType":"poi.park","elementType":"geometry","stylers":[{"color":"#dedede"},{"lightness":21}]},{"elementType":"labels.text.stroke","stylers":[{"visibility":"on"},{"color":"#ffffff"},{"lightness":16}]},{"elementType":"labels.text.fill","stylers":[{"sat'
||'uration":36},{"color":"#333333"},{"lightness":40}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#f2f2f2"},{"lightness":19}]},{"featureType":"administrative","el'
||'ementType":"geometry.fill","stylers":[{"color":"#fefefe"},{"lightness":20}]},{"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#fefefe"},{"lightness":17},{"weight":1.2}]}]',
'</pre>'))
,p_help_text=>'Easiest way is to copy one from a site like https://snazzymaps.com/'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(75543093056053301)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>12
,p_display_sequence=>120
,p_prompt=>'Address Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_help_text=>'Google API Key required. When the user clicks a point on the map, a Google Maps reverse geocode will be executed and the first result (usually the address) will be copied to the item you specify here.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(82046835037985797)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>13
,p_display_sequence=>130
,p_prompt=>'Geolocate'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_default_value=>'N'
,p_is_translatable=>false
,p_help_text=>'If set to Yes, on load the map will attempt to determine the user''s location (it will probably ask the user for permission first) and pan to that location. If successful, the geolocate event will be triggered.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(82048889651991149)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>14
,p_display_sequence=>140
,p_prompt=>'Geolocate Zoom'
,p_attribute_type=>'INTEGER'
,p_is_required=>true
,p_default_value=>'12'
,p_display_length=>2
,p_max_length=>2
,p_unit=>'(0-23)'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(82046835037985797)
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'Y'
,p_help_text=>'If Geolocate is Yes, if the map is able to determine the user''s location it will zoom to this level.'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(82051344740006614)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
,p_name=>'geolocate'
,p_display_name=>'geolocate'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(369362240211787869)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
,p_name=>'mapclick'
,p_display_name=>'mapClick'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(225981482848809515)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
,p_name=>'maploaded'
,p_display_name=>'mapLoaded'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(376078819489803985)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
,p_name=>'markerclick'
,p_display_name=>'markerClick'
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '66756E6374696F6E206A6B3634706C7567696E5F67656F636F646528652C69297B692E67656F636F6465287B616464726573733A247628652E67656F636F64654974656D292C636F6D706F6E656E745265737472696374696F6E733A2222213D3D652E63';
wwv_flow_api.g_varchar2_table(2) := '6F756E7472793F7B636F756E7472793A652E636F756E7472797D3A7B7D7D2C66756E6374696F6E28692C6E297B6966286E3D3D3D676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B297B766172206F3D695B305D2E67656F6D6574';
wwv_flow_api.g_varchar2_table(3) := '72792E6C6F636174696F6E3B617065782E646562756728652E726567696F6E49642B222067656F636F6465206F6B22292C652E6D61702E73657443656E746572286F292C652E6D61702E70616E546F286F292C652E6D61726B65725A6F6F6D2626652E6D';
wwv_flow_api.g_varchar2_table(4) := '61702E7365745A6F6F6D28652E6D61726B65725A6F6F6D292C6A6B3634706C7567696E5F7573657250696E28652C6F2E6C617428292C6F2E6C6E672829297D656C736520617065782E646562756728652E726567696F6E49642B222067656F636F646520';
wwv_flow_api.g_varchar2_table(5) := '77617320756E7375636365737366756C20666F722074686520666F6C6C6F77696E6720726561736F6E3A20222B6E297D297D66756E6374696F6E206A6B3634706C7567696E5F72657050696E28652C69297B766172206E3D6E657720676F6F676C652E6D';
wwv_flow_api.g_varchar2_table(6) := '6170732E4C61744C6E6728692E6C61742C692E6C6E67293B696628692E726164297B766172206F3D6E657720676F6F676C652E6D6170732E436972636C65287B7374726F6B65436F6C6F723A692E636F6C2C7374726F6B654F7061636974793A312C7374';
wwv_flow_api.g_varchar2_table(7) := '726F6B655765696768743A312C66696C6C436F6C6F723A692E636F6C2C66696C6C4F7061636974793A692E74726E732C636C69636B61626C653A21302C6D61703A652E6D61702C63656E7465723A6E2C7261646975733A3165332A692E7261647D293B67';
wwv_flow_api.g_varchar2_table(8) := '6F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286F2C22636C69636B222C66756E6374696F6E28297B617065782E646562756728652E726567696F6E49642B2220636972636C6520636C69636B656420222B692E6964292C222221';
wwv_flow_api.g_varchar2_table(9) := '3D3D652E69644974656D2626247328652E69644974656D2C692E6964292C617065782E6A5175657279282223222B652E726567696F6E4964292E7472696767657228226D61726B6572636C69636B222C7B6D61703A652E6D61702C69643A692E69642C6E';
wwv_flow_api.g_varchar2_table(10) := '616D653A692E6E616D652C6C61743A692E6C61742C6C6E673A692E6C6E672C7261643A692E7261647D297D292C652E636972636C65737C7C28652E636972636C65733D5B5D292C652E636972636C65732E70757368287B69643A692E69642C636972633A';
wwv_flow_api.g_varchar2_table(11) := '6F7D297D656C73657B76617220613D6E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A652E6D61702C706F736974696F6E3A6E2C7469746C653A692E6E616D652C69636F6E3A692E69636F6E7D293B676F6F676C652E6D6170732E65';
wwv_flow_api.g_varchar2_table(12) := '76656E742E6164644C697374656E657228612C22636C69636B222C66756E6374696F6E28297B617065782E646562756728652E726567696F6E49642B222072657050696E20636C69636B656420222B692E6964292C692E696E666F262628652E69773F65';
wwv_flow_api.g_varchar2_table(13) := '2E69772E636C6F736528293A652E69773D6E657720676F6F676C652E6D6170732E496E666F57696E646F772C652E69772E7365744F7074696F6E73287B636F6E74656E743A692E696E666F7D292C652E69772E6F70656E28652E6D61702C746869732929';
wwv_flow_api.g_varchar2_table(14) := '2C652E6D61702E70616E546F28746869732E676574506F736974696F6E2829292C652E6D61726B65725A6F6F6D2626652E6D61702E7365745A6F6F6D28652E6D61726B65725A6F6F6D292C2222213D3D652E69644974656D2626247328652E6964497465';
wwv_flow_api.g_varchar2_table(15) := '6D2C692E6964292C617065782E6A5175657279282223222B652E726567696F6E4964292E7472696767657228226D61726B6572636C69636B222C7B6D61703A652E6D61702C69643A692E69642C6E616D653A692E6E616D652C6C61743A692E6C61742C6C';
wwv_flow_api.g_varchar2_table(16) := '6E673A692E6C6E672C7261643A692E7261647D297D292C652E72657070696E7C7C28652E72657070696E3D5B5D292C652E72657070696E2E70757368287B69643A692E69642C6D61726B65723A617D297D7D66756E6374696F6E206A6B3634706C756769';
wwv_flow_api.g_varchar2_table(17) := '6E5F72657050696E732865297B696628652E6D6170646174612E6C656E6774683E30297B652E696E666F4E6F44617461466F756E64262628617065782E646562756728652E726567696F6E49642B222068696465204E6F204461746120466F756E642069';
wwv_flow_api.g_varchar2_table(18) := '6E666F77696E646F7722292C652E696E666F4E6F44617461466F756E642E636C6F73652829293B666F722876617220693D303B693C652E6D6170646174612E6C656E6774683B692B2B296A6B3634706C7567696E5F72657050696E28652C652E6D617064';
wwv_flow_api.g_varchar2_table(19) := '6174615B695D297D656C73652222213D3D652E6E6F446174614D657373616765262628617065782E646562756728652E726567696F6E49642B222073686F77204E6F204461746120466F756E6420696E666F77696E646F7722292C652E696E666F4E6F44';
wwv_flow_api.g_varchar2_table(20) := '617461466F756E643F652E696E666F4E6F44617461466F756E642E636C6F736528293A652E696E666F4E6F44617461466F756E643D6E657720676F6F676C652E6D6170732E496E666F57696E646F77287B636F6E74656E743A652E6E6F446174614D6573';
wwv_flow_api.g_varchar2_table(21) := '736167652C706F736974696F6E3A7B6C61743A302C6C6E673A307D7D292C652E696E666F4E6F44617461466F756E642E6F70656E28652E6D617029297D66756E6374696F6E206A6B3634706C7567696E5F636C69636B28652C69297B666F722876617220';
wwv_flow_api.g_varchar2_table(22) := '6E3D21312C6F3D303B6F3C652E72657070696E2E6C656E6774683B6F2B2B29696628652E72657070696E5B6F5D2E69643D3D69297B6E657720676F6F676C652E6D6170732E6576656E742E7472696767657228652E72657070696E5B6F5D2E6D61726B65';
wwv_flow_api.g_varchar2_table(23) := '722C22636C69636B22292C6E3D21303B627265616B7D6E7C7C617065782E646562756728652E726567696F6E49642B22206964206E6F7420666F756E643A222B69297D66756E6374696F6E206A6B3634706C7567696E5F736574436972636C6528652C69';
wwv_flow_api.g_varchar2_table(24) := '297B6966282222213D3D652E646973744974656D29696628652E64697374636972636C6529617065782E646562756728652E726567696F6E49642B22206D6F766520636972636C6522292C652E64697374636972636C652E73657443656E746572286929';
wwv_flow_api.g_varchar2_table(25) := '2C652E64697374636972636C652E7365744D617028652E6D6170293B656C73657B766172206E3D7061727365466C6F617428247628652E646973744974656D29293B617065782E646562756728652E726567696F6E49642B222063726561746520636972';
wwv_flow_api.g_varchar2_table(26) := '636C65207261646975733D222B6E292C652E64697374636972636C653D6E657720676F6F676C652E6D6170732E436972636C65287B7374726F6B65436F6C6F723A2223353035304646222C7374726F6B654F7061636974793A2E352C7374726F6B655765';
wwv_flow_api.g_varchar2_table(27) := '696768743A322C66696C6C436F6C6F723A2223303030304646222C66696C6C4F7061636974793A2E30352C636C69636B61626C653A21312C6564697461626C653A21302C6D61703A652E6D61702C63656E7465723A692C7261646975733A3165332A6E7D';
wwv_flow_api.g_varchar2_table(28) := '292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228652E64697374636972636C652C227261646975735F6368616E676564222C66756E6374696F6E2869297B766172206E3D652E64697374636972636C652E67657452616469';
wwv_flow_api.g_varchar2_table(29) := '757328292F3165333B617065782E646562756728652E726567696F6E49642B2220636972636C6520726164697573206368616E67656420222B6E292C247328652E646973744974656D2C6E292C6A6B3634706C7567696E5F726566726573684D61702865';
wwv_flow_api.g_varchar2_table(30) := '297D292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228652E64697374636972636C652C2263656E7465725F6368616E676564222C66756E6374696F6E2869297B766172206E3D652E64697374636972636C652E6765744365';
wwv_flow_api.g_varchar2_table(31) := '6E74657228292C6F3D6E2E6C617428292B222C222B6E2E6C6E6728293B617065782E646562756728652E726567696F6E49642B2220636972636C652063656E746572206368616E67656420222B6F292C2222213D3D652E73796E634974656D2626282473';
wwv_flow_api.g_varchar2_table(32) := '28652E73796E634974656D2C6F292C6A6B3634706C7567696E5F726566726573684D6170286529297D297D7D66756E6374696F6E206A6B3634706C7567696E5F7573657250696E28652C692C6E297B6966286E756C6C213D3D6926266E756C6C213D3D6E';
wwv_flow_api.g_varchar2_table(33) := '297B766172206F3D652E7573657270696E3F652E7573657270696E2E676574506F736974696F6E28293A6E657720676F6F676C652E6D6170732E4C61744C6E6728302C30293B696628693D3D6F2E6C6174282926266E3D3D6F2E6C6E6728292961706578';
wwv_flow_api.g_varchar2_table(34) := '2E646562756728652E726567696F6E49642B22207573657270696E206E6F74206368616E67656422293B656C73657B76617220613D6E657720676F6F676C652E6D6170732E4C61744C6E6728692C6E293B652E7573657270696E3F28617065782E646562';
wwv_flow_api.g_varchar2_table(35) := '756728652E726567696F6E49642B22206D6F7665206578697374696E672070696E20746F206E657720706F736974696F6E206F6E206D617020222B692B222C222B6E292C652E7573657270696E2E7365744D617028652E6D6170292C652E757365727069';
wwv_flow_api.g_varchar2_table(36) := '6E2E736574506F736974696F6E2861292C6A6B3634706C7567696E5F736574436972636C6528652C6129293A28617065782E646562756728652E726567696F6E49642B2220637265617465207573657270696E20222B692B222C222B6E292C652E757365';
wwv_flow_api.g_varchar2_table(37) := '7270696E3D6E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A652E6D61702C706F736974696F6E3A612C69636F6E3A652E69636F6E7D292C6A6B3634706C7567696E5F736574436972636C6528652C6129297D7D656C736520652E75';
wwv_flow_api.g_varchar2_table(38) := '73657270696E262628617065782E646562756728652E726567696F6E49642B22206D6F7665206578697374696E672070696E206F666620746865206D617022292C652E7573657270696E2E7365744D6170286E756C6C292C652E64697374636972636C65';
wwv_flow_api.g_varchar2_table(39) := '262628617065782E646562756728652E726567696F6E49642B22206D6F76652064697374636972636C65206F666620746865206D617022292C652E64697374636972636C652E7365744D6170286E756C6C2929297D66756E6374696F6E206A6B3634706C';
wwv_flow_api.g_varchar2_table(40) := '7567696E5F6765744164647265737328652C692C6E297B766172206F3D7B6C61743A692C6C6E673A6E7D3B652E67656F636F6465722E67656F636F6465287B6C6F636174696F6E3A6F7D2C66756E6374696F6E28692C6E297B6E3D3D3D676F6F676C652E';
wwv_flow_api.g_varchar2_table(41) := '6D6170732E47656F636F6465725374617475732E4F4B3F695B315D3F247328652E616464726573734974656D2C695B305D2E666F726D61747465645F61646472657373293A77696E646F772E616C65727428224E6F20726573756C747320666F756E6422';
wwv_flow_api.g_varchar2_table(42) := '293A77696E646F772E616C657274282247656F636F646572206661696C65642064756520746F3A20222B6E297D297D66756E6374696F6E206A6B3634706C7567696E5F696E69744D61702865297B617065782E646562756728652E726567696F6E49642B';
wwv_flow_api.g_varchar2_table(43) := '2220696E69744D617022293B76617220693D7B7A6F6F6D3A312C63656E7465723A6E657720676F6F676C652E6D6170732E4C61744C6E6728652E6C61746C6E67292C6D61705479706549643A676F6F676C652E6D6170732E4D61705479706549642E524F';
wwv_flow_api.g_varchar2_table(44) := '41444D41507D3B696628652E6D61703D6E657720676F6F676C652E6D6170732E4D617028646F63756D656E742E676574456C656D656E744279496428652E636F6E7461696E6572292C69292C652E6D61707374796C652626652E6D61702E7365744F7074';
wwv_flow_api.g_varchar2_table(45) := '696F6E73287B7374796C65733A652E6D61707374796C657D292C652E6D61702E666974426F756E6473286E657720676F6F676C652E6D6170732E4C61744C6E67426F756E647328652E736F757468776573742C652E6E6F7274686561737429292C222221';
wwv_flow_api.g_varchar2_table(46) := '3D3D652E73796E634974656D297B766172206E3D247628652E73796E634974656D293B6966286E756C6C213D3D6E26266E2E696E6465784F6628222C22293E2D31297B766172206F3D6E2E73706C697428222C22293B617065782E646562756728652E72';
wwv_flow_api.g_varchar2_table(47) := '6567696F6E49642B2220696E69742066726F6D206974656D20222B6E293B76617220613D6E657720676F6F676C652E6D6170732E4C61744C6E67286F5B305D2C6F5B315D293B652E7573657270696E3D6E657720676F6F676C652E6D6170732E4D61726B';
wwv_flow_api.g_varchar2_table(48) := '6572287B6D61703A652E6D61702C706F736974696F6E3A612C69636F6E3A652E69636F6E7D292C6A6B3634706C7567696E5F736574436972636C6528652C61297D24282223222B652E73796E634974656D292E6368616E67652866756E6374696F6E2829';
wwv_flow_api.g_varchar2_table(49) := '7B76617220693D746869732E76616C75653B6966286E756C6C213D3D692626766F69642030213D3D692626692E696E6465784F6628222C22293E2D31297B617065782E646562756728652E726567696F6E49642B22206974656D206368616E6765642022';
wwv_flow_api.g_varchar2_table(50) := '2B69293B766172206E3D692E73706C697428222C22293B6A6B3634706C7567696E5F7573657250696E28652C6E5B305D2C6E5B315D297D7D297D6966282222213D652E646973744974656D262624282223222B652E646973744974656D292E6368616E67';
wwv_flow_api.g_varchar2_table(51) := '652866756E6374696F6E28297B696628746869732E76616C7565297B76617220693D3165332A7061727365466C6F617428746869732E76616C7565293B652E64697374636972636C652E6765745261646975732829213D3D69262628617065782E646562';
wwv_flow_api.g_varchar2_table(52) := '756728652E726567696F6E49642B2220646973746974656D206368616E67656420222B746869732E76616C7565292C652E64697374636972636C652E736574526164697573286929297D656C736520652E64697374636972636C65262628617065782E64';
wwv_flow_api.g_varchar2_table(53) := '6562756728652E726567696F6E49642B2220646973746974656D20636C656172656422292C652E64697374636972636C652E7365744D6170286E756C6C29297D292C6A6B3634706C7567696E5F72657050696E732865292C2222213D3D652E6164647265';
wwv_flow_api.g_varchar2_table(54) := '73734974656D262628652E67656F636F6465723D6E657720676F6F676C652E6D6170732E47656F636F646572292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228652E6D61702C22636C69636B222C66756E6374696F6E2869';
wwv_flow_api.g_varchar2_table(55) := '297B766172206E3D692E6C61744C6E672E6C617428292C6F3D692E6C61744C6E672E6C6E6728293B617065782E646562756728652E726567696F6E49642B22206D617020636C69636B656420222B6E2B222C222B6F292C282222213D3D652E73796E6349';
wwv_flow_api.g_varchar2_table(56) := '74656D7C7C2222213D3D652E616464726573734974656D2926266A6B3634706C7567696E5F7573657250696E28652C6E2C6F292C2222213D3D652E73796E634974656D3F28247328652E73796E634974656D2C6E2B222C222B6F292C6A6B3634706C7567';
wwv_flow_api.g_varchar2_table(57) := '696E5F726566726573684D6170286529293A652E6D61726B65725A6F6F6D262628617065782E646562756728652E726567696F6E49642B222070616E2B7A6F6F6D22292C652E6D61702E70616E546F28692E6C61744C6E67292C652E6D61702E7365745A';
wwv_flow_api.g_varchar2_table(58) := '6F6F6D28652E6D61726B65725A6F6F6D29292C2222213D3D652E616464726573734974656D26266A6B3634706C7567696E5F6765744164647265737328652C6E2C6F292C617065782E6A5175657279282223222B652E726567696F6E4964292E74726967';
wwv_flow_api.g_varchar2_table(59) := '67657228226D6170636C69636B222C7B6D61703A652E6D61702C6C61743A6E2C6C6E673A6F7D297D292C2222213D652E67656F636F64654974656D297B76617220743D6E657720676F6F676C652E6D6170732E47656F636F6465723B24282223222B652E';
wwv_flow_api.g_varchar2_table(60) := '67656F636F64654974656D292E6368616E67652866756E6374696F6E28297B6A6B3634706C7567696E5F67656F636F646528652C74297D297D652E67656F6C6F636174652626286E6176696761746F722E67656F6C6F636174696F6E3F28617065782E64';
wwv_flow_api.g_varchar2_table(61) := '6562756728652E726567696F6E49642B222067656F6C6F6361746522292C6E6176696761746F722E67656F6C6F636174696F6E2E67657443757272656E74506F736974696F6E2866756E6374696F6E2869297B766172206E3D7B6C61743A692E636F6F72';
wwv_flow_api.g_varchar2_table(62) := '64732E6C617469747564652C6C6E673A692E636F6F7264732E6C6F6E6769747564657D3B652E6D61702E70616E546F286E292C652E67656F6C6F636174655A6F6F6D2626652E6D61702E7365745A6F6F6D28652E67656F6C6F636174655A6F6F6D292C61';
wwv_flow_api.g_varchar2_table(63) := '7065782E6A5175657279282223222B652E726567696F6E4964292E74726967676572282267656F6C6F63617465222C7B6D61703A652E6D61702C6C61743A6E2E6C61742C6C6E673A6E2E6C6E677D297D29293A617065782E646562756728652E72656769';
wwv_flow_api.g_varchar2_table(64) := '6F6E49642B222062726F7773657220646F6573206E6F7420737570706F72742067656F6C6F636174696F6E2229292C617065782E646562756728652E726567696F6E49642B2220696E69744D61702066696E697368656422292C617065782E6A51756572';
wwv_flow_api.g_varchar2_table(65) := '79282223222B652E726567696F6E4964292E7472696767657228226D61706C6F61646564222C7B6D61703A652E6D61707D297D66756E6374696F6E206A6B3634706C7567696E5F726566726573684D61702865297B617065782E646562756728652E7265';
wwv_flow_api.g_varchar2_table(66) := '67696F6E49642B2220726566726573684D617022292C617065782E6A5175657279282223222B652E726567696F6E4964292E747269676765722822617065786265666F72657265667265736822292C617065782E7365727665722E706C7567696E28652E';
wwv_flow_api.g_varchar2_table(67) := '616A61784964656E7469666965722C7B706167654974656D733A652E616A61784974656D737D2C7B64617461547970653A226A736F6E222C737563636573733A66756E6374696F6E2869297B696628617065782E646562756728652E726567696F6E4964';
wwv_flow_api.g_varchar2_table(68) := '2B2220737563636573732070446174613D222B692E736F757468776573742E6C61742B222C222B692E736F757468776573742E6C6E672B2220222B692E6E6F727468656173742E6C61742B222C222B692E6E6F727468656173742E6C6E67292C652E6D61';
wwv_flow_api.g_varchar2_table(69) := '702E666974426F756E6473287B736F7574683A692E736F757468776573742E6C61742C776573743A692E736F757468776573742E6C6E672C6E6F7274683A692E6E6F727468656173742E6C61742C656173743A692E6E6F727468656173742E6C6E677D29';
wwv_flow_api.g_varchar2_table(70) := '2C652E69772626652E69772E636C6F736528292C652E72657070696E297B617065782E646562756728652E726567696F6E49642B222072656D6F766520616C6C207265706F72742070696E7322293B666F7228766172206E3D303B6E3C652E7265707069';
wwv_flow_api.g_varchar2_table(71) := '6E2E6C656E6774683B6E2B2B29652E72657070696E5B6E5D2E6D61726B65722E7365744D6170286E756C6C293B652E72657070696E5B2264656C657465225D7D696628652E636972636C6573297B617065782E646562756728652E726567696F6E49642B';
wwv_flow_api.g_varchar2_table(72) := '222072656D6F766520616C6C20636972636C657322293B666F7228766172206E3D303B6E3C652E636972636C65732E6C656E6774683B6E2B2B29652E636972636C65735B6E5D2E636972632E7365744D6170286E756C6C293B652E636972636C65735B22';
wwv_flow_api.g_varchar2_table(73) := '64656C657465225D7D696628617065782E646562756728652E726567696F6E49642B222070446174612E6D6170646174612E6C656E6774683D222B692E6D6170646174612E6C656E677468292C652E6D6170646174613D692E6D6170646174612C6A6B36';
wwv_flow_api.g_varchar2_table(74) := '34706C7567696E5F72657050696E732865292C2222213D3D652E73796E634974656D297B766172206F3D247628652E73796E634974656D293B6966286E756C6C213D3D6F26266F2E696E6465784F6628222C22293E2D31297B76617220613D6F2E73706C';
wwv_flow_api.g_varchar2_table(75) := '697428222C22293B617065782E646562756728652E726567696F6E49642B2220696E69742066726F6D206974656D20222B6F292C6A6B3634706C7567696E5F7573657250696E28652C615B305D2C615B315D297D7D617065782E6A517565727928222322';
wwv_flow_api.g_varchar2_table(76) := '2B652E726567696F6E4964292E7472696767657228226170657861667465727265667265736822297D7D292C617065782E646562756728652E726567696F6E49642B2220726566726573684D61702066696E697368656422297D';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(82061414472126369)
,p_plugin_id=>wwv_flow_api.id(369361923639784586)
,p_file_name=>'jk64plugin.min.js'
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
