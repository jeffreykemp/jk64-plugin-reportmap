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
,p_release=>'5.0.4.00.12'
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
 p_id=>wwv_flow_api.id(695618245428938360)
,p_plugin_type=>'REGION TYPE'
,p_name=>'COM.JK64.REPORT_GOOGLE_MAP'
,p_display_name=>'JK64 Report Google Map'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_plsql_code=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'-- jk64 ReportMap v0.9',
'g_num_format constant varchar2(100) := ''99999999999999.999999999999999999999999999999'';',
'g_tochar_format constant varchar2(100) := ''fm99999999999990.099999999999999999999999999999'';',
'',
'g_attr1_label constant varchar2(10) := ''LABEL'';',
'',
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
'      || TO_CHAR(lat, g_tochar_format)',
'      || '',"lng":''',
'      || TO_CHAR(lng, g_tochar_format);',
'END latlng2ch;',
'',
'FUNCTION get_markers',
'    (p_region     IN APEX_PLUGIN.t_region',
'    ,p_lat_min    IN OUT NUMBER',
'    ,p_lat_max    IN OUT NUMBER',
'    ,p_lng_min    IN OUT NUMBER',
'    ,p_lng_max    IN OUT NUMBER',
'    ,p_attribute1 IN VARCHAR2',
'    ) RETURN APEX_APPLICATION_GLOBAL.VC_ARR2 IS',
'    ',
'    l_data           APEX_APPLICATION_GLOBAL.VC_ARR2;',
'    l_lat            NUMBER;',
'    l_lng            NUMBER;',
'    l_info           VARCHAR2(4000);',
'    l_icon           VARCHAR2(4000);',
'    l_radius_km      NUMBER;',
'    l_circle_color   VARCHAR2(100);',
'    l_circle_transp  NUMBER;',
'    l_flex_fields    VARCHAR2(32767);',
'    l_marker_label   VARCHAR2(1);',
'     ',
'    l_column_value_list  APEX_PLUGIN_UTIL.t_column_value_list;',
'',
'BEGIN',
'',
'    l_column_value_list := APEX_PLUGIN_UTIL.get_data',
'        (p_sql_statement  => p_region.source',
'        ,p_min_columns    => 4',
'        ,p_max_columns    => 19',
'        ,p_component_name => p_region.name',
'        ,p_max_rows       => p_region.fetched_rows);',
'    ',
'    FOR i IN 1..l_column_value_list(1).count LOOP',
'    ',
'        IF NOT l_column_value_list.EXISTS(1)',
'        OR NOT l_column_value_list.EXISTS(2)',
'        OR NOT l_column_value_list.EXISTS(3)',
'        OR NOT l_column_value_list.EXISTS(4) THEN',
'          RAISE_APPLICATION_ERROR(-20000, ''Report Map Query must have at least 4 columns (lat, lng, name, id)'');',
'        END IF;',
'  ',
'        l_lat  := TO_NUMBER(l_column_value_list(1)(i),g_num_format);',
'        l_lng  := TO_NUMBER(l_column_value_list(2)(i),g_num_format);',
'        ',
'        -- default values if not supplied in query',
'        l_icon          := NULL;',
'        l_radius_km     := NULL;',
'        l_circle_color  := ''#0000cc'';',
'        l_circle_transp := 0.3;',
'        l_flex_fields   := NULL;',
'        l_marker_label  := NULL;',
'        ',
'        IF l_column_value_list.EXISTS(5) THEN',
'          l_info := l_column_value_list(5)(i);',
'        IF l_column_value_list.EXISTS(6) THEN',
'          l_icon := l_column_value_list(6)(i);',
'        IF l_column_value_list.EXISTS(7) THEN',
'          l_radius_km := TO_NUMBER(l_column_value_list(7)(i),g_num_format);',
'        IF l_column_value_list.EXISTS(8) THEN',
'          l_circle_color := l_column_value_list(8)(i);',
'        IF l_column_value_list.EXISTS(9) THEN',
'          l_circle_transp := TO_NUMBER(l_column_value_list(9)(i),g_num_format);',
'        END IF; END IF; END IF; END IF; END IF;',
'        ',
'        -- The remaining columns are up to 10 "flex" fields.',
'        -- If one of them is equal to a special attribute ("label"), the very next',
'        -- field is interpreted as the label.',
'        FOR j IN 10..19 LOOP',
'          IF l_column_value_list.EXISTS(j) THEN',
'',
'            if j = 10 and UPPER(p_attribute1) = g_attr1_label then',
'',
'              l_marker_label := substr(l_column_value_list(j)(i), 1, 1);',
'',
'            else',
'',
'              l_flex_fields := l_flex_fields',
'                            || '',"attr''',
'                            || TO_CHAR(j-9,''fm00'')',
'                            || ''":''',
'                            || APEX_ESCAPE.js_literal(l_column_value_list(j)(i),''"'');',
'',
'            end if;',
'',
'          END IF;',
'        END LOOP;',
'		',
'        l_data(NVL(l_data.LAST,0)+1) :=',
'             ''{"id":''  || APEX_ESCAPE.js_literal(l_column_value_list(4)(i),''"'')',
'          || '',"name":''|| APEX_ESCAPE.js_literal(l_column_value_list(3)(i),''"'')',
'          || '',''       || latlng2ch(l_lat,l_lng)',
'          || CASE WHEN l_info IS NOT NULL THEN',
'             '',"info":''|| APEX_ESCAPE.js_literal(l_info,''"'')',
'             END',
'          || '',"icon":''|| APEX_ESCAPE.js_literal(l_icon,''"'')',
'          || '',"label":''|| APEX_ESCAPE.js_literal(l_marker_label,''"'') ',
'          || CASE WHEN l_radius_km IS NOT NULL THEN',
'             '',"rad":'' || TO_CHAR(l_radius_km,g_tochar_format)',
'		      || '',"col":'' || APEX_ESCAPE.js_literal(l_circle_color,''"'')',
'		      ||   CASE WHEN l_circle_transp IS NOT NULL THEN',
'             '',"trns":''|| TO_CHAR(l_circle_transp,''fm990.099'')',
'               END',
'             END',
'          || l_flex_fields',
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
'    l_js_params    varchar2(1000);',
'    l_zoom_enabled varchar2(1000) := ''true'';',
'    l_pan_enabled  varchar2(1000) := ''true'';',
'',
'    -- Plugin attributes (application level)',
'    l_api_key       plugin_attr := p_plugin.attribute_01;',
'',
'    -- Component attributes',
'    l_map_height        plugin_attr := p_region.attribute_01;',
'    l_id_item           plugin_attr := p_region.attribute_02;',
'    l_click_zoom        plugin_attr := p_region.attribute_03;    ',
'    l_sync_item         plugin_attr := p_region.attribute_04;',
'    l_markericon        plugin_attr := p_region.attribute_05;',
'    l_latlong           plugin_attr := p_region.attribute_06;',
'    l_dist_item         plugin_attr := p_region.attribute_07;',
'    --l_unused            plugin_attr := p_region.attribute_08; --attribute not used in this version',
'    l_geocode_item      plugin_attr := p_region.attribute_09;',
'    l_country           plugin_attr := p_region.attribute_10;',
'    l_mapstyle          plugin_attr := p_region.attribute_11;',
'    l_address_item      plugin_attr := p_region.attribute_12;',
'    l_geolocate         plugin_attr := p_region.attribute_13;',
'    l_geoloc_zoom       plugin_attr := p_region.attribute_14;',
'    l_directions        plugin_attr := p_region.attribute_15;',
'    l_origin_item       plugin_attr := p_region.attribute_16;',
'    l_dest_item         plugin_attr := p_region.attribute_17;',
'    l_dirdist_item      plugin_attr := p_region.attribute_18;',
'    l_dirdur_item       plugin_attr := p_region.attribute_19;',
'    l_attribute1        plugin_attr := p_region.attribute_20;',
'    l_optimizewaypoints plugin_attr := p_region.attribute_21;',
'    l_maptype           plugin_attr := p_region.attribute_22;',
'    l_zoom_expr         plugin_attr := p_region.attribute_23;',
'    l_pan_expr          plugin_attr := p_region.attribute_24;',
'    l_gesture_handling  plugin_attr := p_region.attribute_25;',
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
'        l_geocode_item := NULL;',
'        l_country      := NULL;',
'        l_address_item := NULL;',
'        l_directions   := NULL;',
'        l_origin_item  := NULL;',
'        l_dest_item    := NULL;',
'        l_dirdist_item := NULL;',
'        l_dirdur_item  := NULL;',
'    ELSE',
'        l_js_params := ''?key='' || l_api_key;',
'    END IF;',
'    ',
'    if l_zoom_expr is not null then',
'      l_zoom_enabled := apex_plugin_util.get_plsql_expression_result (',
'        ''case when ('' || l_zoom_expr',
'        || '') then ''''true'''' else ''''false'''' end'');',
'      if l_zoom_enabled not in (''true'',''false'') then',
'        raise_application_error(-20000, ''Zoom attribute must evaluate to true or false.'');',
'      end if;',
'    end if;',
'',
'    if l_pan_expr is not null then',
'      l_pan_enabled := apex_plugin_util.get_plsql_expression_result (',
'        ''case when ('' || l_pan_expr',
'        || '') then ''''true'''' else ''''false'''' end'');',
'      if l_pan_enabled not in (''true'',''false'') then',
'        raise_application_error(-20000, ''Pan attribute must evaluate to true or false.'');',
'      end if;',
'    end if;',
'',
'    APEX_JAVASCRIPT.add_library',
'      (p_name           => ''js'' || l_js_params',
'      ,p_directory      => ''https://maps.googleapis.com/maps/api/''',
'      ,p_skip_extension => true);',
'',
'    APEX_JAVASCRIPT.add_library',
'      (p_name                  => ''jk64reportmap''',
'      ,p_directory             => p_plugin.file_prefix',
'      ,p_check_to_add_minified => TRUE);',
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
'        (p_region     => p_region',
'        ,p_lat_min    => l_lat_min',
'        ,p_lat_max    => l_lat_max',
'        ,p_lng_min    => l_lng_min',
'        ,p_lng_max    => l_lng_max',
'        ,p_attribute1 => l_attribute1',
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
'      l_lat := TO_NUMBER(SUBSTR(l_latlong,1,INSTR(l_latlong,'','')-1),g_num_format);',
'      l_lng := TO_NUMBER(SUBSTR(l_latlong,INSTR(l_latlong,'','')+1),g_num_format);',
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
'      l_lat_min := GREATEST(l_lat - 10, -80);',
'      l_lat_max := LEAST(l_lat + 10, 80);',
'      l_lng_min := GREATEST(l_lng - 10, -180);',
'      l_lng_max := LEAST(l_lng + 10, 180);',
'',
'    -- show entire map if no points to show',
'    ELSIF l_data.COUNT = 0 THEN',
'      l_latlong := ''0,0'';',
'      l_lat_min := -90;',
'      l_lat_max := 90;',
'      l_lng_min := -180;',
'      l_lng_max := 180;',
'',
'    END IF;',
'        ',
'    l_script := ''<script>',
'var opt_#REGION#=',
'{container:"map_#REGION#_container"',
',regionId:"#REGION#"',
',ajaxIdentifier:"''||APEX_PLUGIN.get_ajax_identifier||''"',
',ajaxItems:"''||APEX_PLUGIN_UTIL.page_item_names_to_jquery(p_region.ajax_items_to_submit)||''"',
',maptype:"''||lower(l_maptype)||''"',
',latlng:"''||l_latlong||''"',
',markerZoom:''||NVL(l_click_zoom,''null'')||''',
',icon:"''||l_markericon||''"',
',idItem:"''||l_id_item||''"',
',syncItem:"''||l_sync_item||''"',
',distItem:"''||l_dist_item||''"',
',geocodeItem:"''||l_geocode_item||''"',
',country:"''||l_country||''"',
',southwest:{''||latlng2ch(l_lat_min,l_lng_min)||''}',
',northeast:{''||latlng2ch(l_lat_max,l_lng_max)||''}''||',
'  CASE WHEN l_mapstyle IS NOT NULL THEN ''',
',mapstyle:''||l_mapstyle END || ''',
',addressItem:"''||l_address_item||''"''||',
'  CASE WHEN l_geolocate = ''Y'' THEN ''',
',geolocate:true'' ||',
'    CASE WHEN l_geoloc_zoom IS NOT NULL THEN ''',
',geolocateZoom:''||l_geoloc_zoom',
'    END',
'  END || ''',
',noDataMessage:"''||p_region.no_data_found_message||''"''||',
'  CASE WHEN p_region.source IS NOT NULL THEN ''',
',expectData:true''',
'  END ||',
'  CASE WHEN l_directions IS NOT NULL THEN ''',
',directions:"'' || l_directions || ''"'' ||',
'    CASE WHEN l_origin_item IS NOT NULL THEN ''',
',originItem:"'' || l_origin_item || ''"''',
'    END ||',
'    CASE WHEN l_dest_item IS NOT NULL THEN ''',
',destItem:"'' || l_dest_item || ''"''',
'    END ||',
'    CASE WHEN l_dirdist_item IS NOT NULL THEN ''',
',dirdistItem:"'' || l_dirdist_item || ''"''',
'    END ||',
'    CASE WHEN l_dirdur_item IS NOT NULL THEN ''',
',dirdurItem:"'' || l_dirdur_item || ''"''',
'    END || ''',
',optimizeWaypoints:'' || case when l_optimizewaypoints = ''Y'' then ''true'' else ''false'' end',
'  END || ''',
'  ,zoom: ''||l_zoom_enabled||''',
'  ,pan: ''||l_pan_enabled||''',
'  ,gestureHandling: "''||nvl(l_gesture_handling,''auto'')||''"',
'};',
'function click_#REGION#(id){jk64reportmap_click(opt_#REGION#,id);}',
'function r_#REGION#(f){/in/.test(document.readyState)?setTimeout("r_#REGION#("+f+")",9):f()}',
'r_#REGION#(function(){',
'opt_#REGION#.mapdata = ['';',
'    sys.htp.p(REPLACE(l_script,''#REGION#'',l_region));',
'    htp_arr(l_data);',
'    l_script := ''];',
'jk64reportmap_initMap(opt_#REGION#);',
'apex.jQuery("##REGION#").bind("apexrefresh", function(){jk64reportmap_refreshMap(opt_#REGION#);});',
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
'    l_attribute1    plugin_attr := p_region.attribute_20;',
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
'        (p_region     => p_region',
'        ,p_lat_min    => l_lat_min',
'        ,p_lat_max    => l_lat_max',
'        ,p_lng_min    => l_lng_min',
'        ,p_lng_max    => l_lng_max',
'        ,p_attribute1 => l_attribute1',
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
'      l_lat := TO_NUMBER(SUBSTR(l_latlong,1,INSTR(l_latlong,'','')-1),g_num_format);',
'      l_lng := TO_NUMBER(SUBSTR(l_latlong,INSTR(l_latlong,'','')+1),g_num_format);',
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
'      l_lat_min := GREATEST(l_lat - 10, -180);',
'      l_lat_max := LEAST(l_lat + 10, 80);',
'      l_lng_min := GREATEST(l_lng - 10, -180);',
'      l_lng_max := LEAST(l_lng + 10, 180);',
'',
'    -- show entire map if no points to show',
'    ELSIF l_data.COUNT = 0 THEN',
'      l_lat_min := -90;',
'      l_lat_max := 90;',
'      l_lng_min := -180;',
'      l_lng_max := 180;',
'',
'    END IF;',
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
,p_sql_max_column_count=>19
,p_sql_examples=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'<p>',
'<pre>SELECT lat, lng, name, id FROM mydata;</pre>',
'</p><p>',
'<em>Show a popup info window when a marker is clicked:</em>',
'</p><p>',
'<pre>SELECT lat, lng, name, id, info FROM mydata;</pre>',
'</p><p>',
'<em>Show each point with a selected icon:</em>',
'</p><p>',
'<pre>SELECT lat, lng, name, id, info, icon FROM mydata;</pre>',
'</p><p>',
'<em>Get only the data within a certain distance from a chosen point:</em>',
'</p><p>',
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
'</p><p>',
'<em>Population map (show circles instead of pins):</em>',
'</p><p>',
'<pre>',
'SELECT lat, lng, name, id, '''' AS info, '''' AS icon,',
'       radius_km, ''#cc0000'' AS color, ''0.05'' as transparency',
'FROM mydata;',
'</pre>',
'</p><p>',
'<em>Marker labels:</em>',
'</p><p>',
'<pre>',
'SELECT lat, lng, name, id, '''' AS info, '''' AS icon,',
'       '''' as radius_km, '''' AS color, '''' as transparency, label as label',
'FROM mydata;',
'</pre>',
'</p><p>',
'<em>Up to 10 additional flex fields may be added:</em>',
'</p><p>',
'<pre>',
'SELECT lat, lng, name, id, '''' AS info, '''' AS icon, '''' AS radius_km, '''' AS color, '''' as transparency,',
'       col1, col2, col3, ... col10',
'FROM mydata;',
'</pre>',
'The extra columns will be accessible from Dynamic Actions, e.g. <code>this.data.attr01</code>',
'</p>'))
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
,p_version_identifier=>'0.9'
,p_about_url=>'https://github.com/jeffreykemp/jk64-plugin-reportmap'
,p_files_version=>70
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(552233187829593382)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
 p_id=>wwv_flow_api.id(695619037641945884)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
 p_id=>wwv_flow_api.id(695619382512949445)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
 p_id=>wwv_flow_api.id(695619719685954630)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
 p_id=>wwv_flow_api.id(700704145135356064)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
 p_id=>wwv_flow_api.id(700707457147402519)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
 p_id=>wwv_flow_api.id(700714078537191576)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
 p_id=>wwv_flow_api.id(700716441847891870)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Circle Radius Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(700704145135356064)
,p_depending_on_condition_type=>'NOT_NULL'
,p_help_text=>'Set to an item which contains the distance (in Kilometres) to draw a circle around the click point. Leave blank to not draw a circle. If the item is changed, the circle will be updated. If you set this attribute, you must also set Synchronize with It'
||'em.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(552243892268321398)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
 p_id=>wwv_flow_api.id(552245124042491968)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>10
,p_display_sequence=>100
,p_prompt=>'Restrict to Country code'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_display_length=>10
,p_max_length=>40
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(552243892268321398)
,p_depending_on_condition_type=>'NOT_NULL'
,p_text_case=>'UPPER'
,p_examples=>'AU'
,p_help_text=>'Leave blank to allow geocoding to find any place on earth. Set to 2-character country code (see https://developers.google.com/public-data/docs/canonical/countries_csv for valid values) to restrict geocoder to that country. You can set this to a subst'
||'ition variable (e.g. &P1_COUNTRY.) but note that this will only apply if the page is refreshed.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(401737003648504535)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
end;
/
begin
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(401799414845207075)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
 p_id=>wwv_flow_api.id(408303156827139571)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
 p_id=>wwv_flow_api.id(408305211441144923)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
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
,p_depending_on_attribute_id=>wwv_flow_api.id(408303156827139571)
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'Y'
,p_help_text=>'If Geolocate is Yes, if the map is able to determine the user''s location it will zoom to this level.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(408341161949450763)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>15
,p_display_sequence=>150
,p_prompt=>'Directions'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>false
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_null_text=>'(none)'
,p_help_text=>'Show travel directions. The locations can be simple - between two locations according to two items on the page - or via the route indicated by waypoints from the report query. Google API Key required.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(110615602578839776)
,p_plugin_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_display_sequence=>10
,p_display_value=>'Driving (route)'
,p_return_value=>'DRIVING-ROUTE'
,p_help_text=>'Get driving directions for a route defined by the report query.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(110623189555845903)
,p_plugin_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_display_sequence=>20
,p_display_value=>'Walking (route)'
,p_return_value=>'WALKING-ROUTE'
,p_help_text=>'Get walking directions for a route defined by the report query.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(110623572078847312)
,p_plugin_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_display_sequence=>30
,p_display_value=>'Bicycling (route)'
,p_return_value=>'BICYCLING-ROUTE'
,p_help_text=>'Get bicycling directions for a route defined by the report query.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(110623957276848926)
,p_plugin_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_display_sequence=>40
,p_display_value=>'Transit (route)'
,p_return_value=>'TRANSIT-ROUTE'
,p_help_text=>'Get public transit directions for a route defined by the report query.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(408343511246452112)
,p_plugin_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_display_sequence=>50
,p_display_value=>'Driving (simple)'
,p_return_value=>'DRIVING'
,p_is_quick_pick=>true
,p_help_text=>'Get driving directions between two locations.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(408343903857452886)
,p_plugin_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_display_sequence=>60
,p_display_value=>'Walking (simple)'
,p_return_value=>'WALKING'
,p_help_text=>'Get walking directions between two locations.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(408344274749454055)
,p_plugin_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_display_sequence=>70
,p_display_value=>'Bicycling (simple)'
,p_return_value=>'BICYCLING'
,p_help_text=>'Get bicycling directions between two locations.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(408344673504455133)
,p_plugin_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_display_sequence=>80
,p_display_value=>'Transit (simple)'
,p_return_value=>'TRANSIT'
,p_is_quick_pick=>true
,p_help_text=>'Get public transit directions between two locations.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(408347319551480868)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>16
,p_display_sequence=>160
,p_prompt=>'Directions Origin Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_depending_on_condition_type=>'IN_LIST'
,p_depending_on_expression=>'DRIVING,WALKING,BICYCLING,TRANSIT'
,p_help_text=>'Item that describes the origin location for directions. May be expressed as a lat,lng pair or as an address or place name.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(408349551929485206)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>17
,p_display_sequence=>170
,p_prompt=>'Directions Destination Item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_depending_on_condition_type=>'IN_LIST'
,p_depending_on_expression=>'DRIVING,WALKING,BICYCLING,TRANSIT'
,p_help_text=>'Item that describes the destination location for directions. May be expressed as a lat,lng pair or as an address or place name.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(408364542977842284)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>18
,p_display_sequence=>180
,p_prompt=>'Show Calculated Distance'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_depending_on_condition_type=>'NOT_NULL'
,p_help_text=>'Item to set the calculated Distance, in metres.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(408367340866848133)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>19
,p_display_sequence=>190
,p_prompt=>'Show Calculated Duration'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_depending_on_condition_type=>'NOT_NULL'
,p_help_text=>'Show calculated travel journey duration, in seconds.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(110223113117218913)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>20
,p_display_sequence=>200
,p_prompt=>'Attribute1'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>false
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Normally, all flex fields are added as data items attached to each pin. Set Attribute1 to an alternative to change the way it is used by the plugin.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(110226683711224247)
,p_plugin_attribute_id=>wwv_flow_api.id(110223113117218913)
,p_display_sequence=>10
,p_display_value=>'Label'
,p_return_value=>'LABEL'
,p_help_text=>'Set to "Label" if flex field #1 should be rendered as a 1-character label on each pin.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(110662362457177916)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>21
,p_display_sequence=>210
,p_prompt=>'Optimize Waypoints'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_is_common=>false
,p_show_in_wizard=>false
,p_default_value=>'N'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(408341161949450763)
,p_depending_on_condition_type=>'IN_LIST'
,p_depending_on_expression=>'DRIVING-ROUTE,WALKING-ROUTE,BICYCLING-ROUTE,TRANSIT-ROUTE'
,p_help_text=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'If set to true, the Directions service will attempt to re-order the supplied intermediate waypoints to minimize overall cost of the route.',
'',
'Note: the first and last points supplied by the report query are always used as the starting and ending points for the journey.'))
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(110673904463352644)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>22
,p_display_sequence=>220
,p_prompt=>'Default Map Type'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_is_common=>false
,p_default_value=>'ROADMAP'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Default map type to show on page load. The user may change the map type if they wish to show a different type.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(110677760335354802)
,p_plugin_attribute_id=>wwv_flow_api.id(110673904463352644)
,p_display_sequence=>10
,p_display_value=>'Roadmap'
,p_return_value=>'ROADMAP'
,p_is_quick_pick=>true
,p_help_text=>'(default) This map type displays a normal street map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(110678115463356148)
,p_plugin_attribute_id=>wwv_flow_api.id(110673904463352644)
,p_display_sequence=>20
,p_display_value=>'Satellite'
,p_return_value=>'SATELLITE'
,p_help_text=>'This map type displays satellite images.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(110678517271357513)
,p_plugin_attribute_id=>wwv_flow_api.id(110673904463352644)
,p_display_sequence=>30
,p_display_value=>'Hybrid'
,p_return_value=>'HYBRID'
,p_help_text=>'This map type displays a transparent layer of major streets on satellite images.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(110678995361358687)
,p_plugin_attribute_id=>wwv_flow_api.id(110673904463352644)
,p_display_sequence=>40
,p_display_value=>'Terrain'
,p_return_value=>'TERRAIN'
,p_help_text=>'This map type displays maps with physical features such as terrain and vegetation.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(136958740484370292)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>23
,p_display_sequence=>230
,p_prompt=>'Zoom enabled'
,p_attribute_type=>'PLSQL EXPRESSION BOOLEAN'
,p_is_required=>false
,p_show_in_wizard=>false
,p_is_translatable=>false
,p_examples=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'<code>true</code>',
'<p>',
'<code>:P1_ITEM IS NOT NULL</code>'))
,p_help_text=>'If this evaluates to true, the Zoom controls will be enabled. If no expression is supplied, the default is true (enabled).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(136962548389373477)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>24
,p_display_sequence=>240
,p_prompt=>'Pan enabled'
,p_attribute_type=>'PLSQL EXPRESSION BOOLEAN'
,p_is_required=>false
,p_show_in_wizard=>false
,p_is_translatable=>false
,p_examples=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'<code>true</code>',
'<p>',
'<code>:P1_ITEM IS NOT NULL</code>'))
,p_help_text=>'If this evaluates to true, the Pan controls will be enabled. If no expression is supplied, the default is true (enabled).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(136966324455376368)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>25
,p_display_sequence=>250
,p_prompt=>'Gesture Handling'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'auto'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'This attribute allows you to select how the map responds to touch gestures on a mobile device. Mobile web users often get frustrated when trying to scroll the page, but an embedded map captures their swipe and pans the map instead. This can even lead'
||' to users getting stuck on the map and having to reload the page in order to get back to the rest of the page. This option allows you to make scrolling more intuitive and less frustrating map interaction experience on mobile browsers.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(136970037787378259)
,p_plugin_attribute_id=>wwv_flow_api.id(136966324455376368)
,p_display_sequence=>10
,p_display_value=>'cooperative'
,p_return_value=>'cooperative'
,p_help_text=>wwv_flow_utilities.join(wwv_flow_t_varchar2(
'Scroll events and one-finger touch gestures scroll the page, and do not zoom or pan the map. Two-finger touch gestures pan and zoom the map. Scroll events with a ctrl key or ⌘ key pressed zoom the map.',
'In this mode the map cooperates with the page.'))
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(136970432541379062)
,p_plugin_attribute_id=>wwv_flow_api.id(136966324455376368)
,p_display_sequence=>20
,p_display_value=>'greedy'
,p_return_value=>'greedy'
,p_help_text=>'All touch gestures and scroll events pan or zoom the map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(136970892701379919)
,p_plugin_attribute_id=>wwv_flow_api.id(136966324455376368)
,p_display_sequence=>30
,p_display_value=>'none'
,p_return_value=>'none'
,p_help_text=>'The map cannot be panned or zoomed by user gestures.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(136971221574380713)
,p_plugin_attribute_id=>wwv_flow_api.id(136966324455376368)
,p_display_sequence=>40
,p_display_value=>'auto'
,p_return_value=>'auto'
,p_help_text=>'(default) Gesture handling is either cooperative or greedy, depending on whether the page is scrollable.'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(326259892619170397)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_name=>'addressfound'
,p_display_name=>'addressFound'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(408307666529160388)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_name=>'geolocate'
,p_display_name=>'geolocate'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(695618562000941643)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_name=>'mapclick'
,p_display_name=>'mapClick'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(552237804637963289)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_name=>'maploaded'
,p_display_name=>'mapLoaded'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(702335141278957759)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_name=>'markerclick'
,p_display_name=>'markerClick'
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2F2F6A6B3634205265706F72744D61702076302E390D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F70617273654C61744C6E67287629207B0D0A2020617065782E646562756728226A6B36347265706F72746D61705F70617273654C';
wwv_flow_api.g_varchar2_table(2) := '61744C6E6720222B76293B0D0A202076617220706F733B0D0A2020696620287620213D3D206E756C6C202626207620213D3D20756E646566696E656420262620762E696E6465784F6628222C2229203E202D3129207B0D0A202020202076617220617272';
wwv_flow_api.g_varchar2_table(3) := '203D20762E73706C697428222C22293B0D0A2020202020617065782E6465627567282270617273656420222B6172725B305D2B2220222B6172725B315D293B0D0A2020202020706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E672861';
wwv_flow_api.g_varchar2_table(4) := '72725B305D2C6172725B315D293B0D0A20207D0D0A202072657475726E20706F733B0D0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F67656F636F6465286F70742C67656F636F64657229207B0D0A202067656F636F6465722E';
wwv_flow_api.g_varchar2_table(5) := '67656F636F6465280D0A202020207B616464726573733A202476286F70742E67656F636F64654974656D290D0A202020202C636F6D706F6E656E745265737472696374696F6E733A206F70742E636F756E747279213D3D22223F7B636F756E7472793A6F';
wwv_flow_api.g_varchar2_table(6) := '70742E636F756E7472797D3A7B7D0D0A20207D2C2066756E6374696F6E28726573756C74732C2073746174757329207B0D0A2020202069662028737461747573203D3D3D20676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B2920';
wwv_flow_api.g_varchar2_table(7) := '7B0D0A20202020202076617220706F73203D20726573756C74735B305D2E67656F6D657472792E6C6F636174696F6E3B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B222067656F636F6465206F6B22293B0D0A202020';
wwv_flow_api.g_varchar2_table(8) := '2020206F70742E6D61702E73657443656E74657228706F73293B0D0A2020202020206F70742E6D61702E70616E546F28706F73293B0D0A202020202020696620286F70742E6D61726B65725A6F6F6D29207B0D0A20202020202020206F70742E6D61702E';
wwv_flow_api.g_varchar2_table(9) := '7365745A6F6F6D286F70742E6D61726B65725A6F6F6D293B0D0A2020202020207D0D0A2020202020206A6B36347265706F72746D61705F7573657250696E286F70742C706F732E6C617428292C20706F732E6C6E672829293B0D0A202020202020696620';
wwv_flow_api.g_varchar2_table(10) := '286F70742E616464726573734974656D29207B0D0A20202020202020202473286F70742E616464726573734974656D2C726573756C74735B305D2E666F726D61747465645F61646472657373293B0D0A2020202020207D0D0A202020202020617065782E';
wwv_flow_api.g_varchar2_table(11) := '6465627567286F70742E726567696F6E49642B222061646472657373666F756E642027222B726573756C74735B305D2E666F726D61747465645F616464726573732B222722293B0D0A202020202020617065782E6A5175657279282223222B6F70742E72';
wwv_flow_api.g_varchar2_table(12) := '6567696F6E4964292E74726967676572282261646472657373666F756E64222C207B0D0A20202020202020206D61703A6F70742E6D61702C0D0A20202020202020206C61743A706F732E6C617428292C0D0A20202020202020206C6E673A706F732E6C6E';
wwv_flow_api.g_varchar2_table(13) := '6728292C0D0A2020202020202020666F726D61747465645F616464726573733A726573756C74735B305D2E666F726D61747465645F616464726573730D0A2020202020207D293B0D0A202020207D20656C7365207B0D0A202020202020617065782E6465';
wwv_flow_api.g_varchar2_table(14) := '627567286F70742E726567696F6E49642B222067656F636F64652077617320756E7375636365737366756C20666F722074686520666F6C6C6F77696E6720726561736F6E3A20222B737461747573293B0D0A202020207D0D0A20207D293B0D0A7D0D0A0D';
wwv_flow_api.g_varchar2_table(15) := '0A66756E6374696F6E206A6B36347265706F72746D61705F6D61726B6572636C69636B286F70742C704461746129207B0D0A09696620286F70742E69644974656D213D3D222229207B0D0A09092473286F70742E69644974656D2C70446174612E696429';
wwv_flow_api.g_varchar2_table(16) := '3B0D0A097D0D0A09617065782E6A5175657279282223222B6F70742E726567696F6E4964292E7472696767657228226D61726B6572636C69636B222C207B0D0A09096D61703A6F70742E6D61702C0D0A090969643A70446174612E69642C0D0A09096E61';
wwv_flow_api.g_varchar2_table(17) := '6D653A70446174612E6E616D652C0D0A09096C61743A70446174612E6C61742C0D0A09096C6E673A70446174612E6C6E672C0D0A09097261643A70446174612E7261642C0D0A09096174747230313A70446174612E6174747230312C0D0A090961747472';
wwv_flow_api.g_varchar2_table(18) := '30323A70446174612E6174747230322C0D0A09096174747230333A70446174612E6174747230332C0D0A09096174747230343A70446174612E6174747230342C0D0A09096174747230353A70446174612E6174747230352C0D0A09096174747230363A70';
wwv_flow_api.g_varchar2_table(19) := '446174612E6174747230362C0D0A09096174747230373A70446174612E6174747230372C0D0A09096174747230383A70446174612E6174747230382C0D0A09096174747230393A70446174612E6174747230392C0D0A09096174747231303A7044617461';
wwv_flow_api.g_varchar2_table(20) := '2E6174747231300D0A097D293B090D0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F72657050696E286F70742C704461746129207B0D0A0976617220706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E672870';
wwv_flow_api.g_varchar2_table(21) := '446174612E6C61742C2070446174612E6C6E67293B0D0A096966202870446174612E72616429207B0D0A09097661722063697263203D206E657720676F6F676C652E6D6170732E436972636C65287B0D0A202020202020202020207374726F6B65436F6C';
wwv_flow_api.g_varchar2_table(22) := '6F723A2070446174612E636F6C2C0D0A202020202020202020207374726F6B654F7061636974793A20312E302C0D0A202020202020202020207374726F6B655765696768743A20312C0D0A2020202020202020202066696C6C436F6C6F723A2070446174';
wwv_flow_api.g_varchar2_table(23) := '612E636F6C2C0D0A2020202020202020202066696C6C4F7061636974793A2070446174612E74726E732C0D0A20202020202020202020636C69636B61626C653A20747275652C0D0A202020202020202020206D61703A206F70742E6D61702C0D0A202020';
wwv_flow_api.g_varchar2_table(24) := '2020202020202063656E7465723A20706F732C0D0A202020202020202020207261646975733A2070446174612E7261642A313030300D0A09097D293B0D0A0909676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228636972632C20';
wwv_flow_api.g_varchar2_table(25) := '22636C69636B222C2066756E6374696F6E202829207B0D0A090909617065782E6465627567286F70742E726567696F6E49642B2220636972636C6520636C69636B656420222B70446174612E6964293B0D0A0909096A6B36347265706F72746D61705F6D';
wwv_flow_api.g_varchar2_table(26) := '61726B6572636C69636B286F70742C7044617461293B0D0A09097D293B0D0A090969662028216F70742E636972636C657329207B206F70742E636972636C65733D5B5D3B207D0D0A09096F70742E636972636C65732E70757368287B226964223A704461';
wwv_flow_api.g_varchar2_table(27) := '74612E69642C2263697263223A636972637D293B0D0A097D20656C7365207B0D0A09097661722072657070696E203D206E657720676F6F676C652E6D6170732E4D61726B6572287B0D0A0909090909206D61703A206F70742E6D61702C0D0A0909090909';
wwv_flow_api.g_varchar2_table(28) := '20706F736974696F6E3A20706F732C0D0A0909090909207469746C653A2070446174612E6E616D652C0D0A09090909092069636F6E3A2070446174612E69636F6E2C0D0A0909090909206C6162656C3A2070446174612E6C6162656C2020202020202020';
wwv_flow_api.g_varchar2_table(29) := '20202020202020202020202020202020202020202020202020202020202020200D0A090909092020207D293B0D0A0909676F6F676C652E6D6170732E6576656E742E6164644C697374656E65722872657070696E2C2022636C69636B222C2066756E6374';
wwv_flow_api.g_varchar2_table(30) := '696F6E202829207B0D0A090909617065782E6465627567286F70742E726567696F6E49642B222072657050696E20636C69636B656420222B70446174612E6964293B0D0A0909096966202870446174612E696E666F29207B0D0A09090909696620286F70';
wwv_flow_api.g_varchar2_table(31) := '742E697729207B0D0A09090909096F70742E69772E636C6F736528293B0D0A090909097D20656C7365207B0D0A09090909096F70742E6977203D206E657720676F6F676C652E6D6170732E496E666F57696E646F7728293B0D0A090909097D0D0A090909';
wwv_flow_api.g_varchar2_table(32) := '096F70742E69772E7365744F7074696F6E73287B0D0A09090909202020636F6E74656E743A2070446174612E696E666F0D0A0909090920207D293B0D0A090909096F70742E69772E6F70656E286F70742E6D61702C2074686973293B0D0A0909097D0D0A';
wwv_flow_api.g_varchar2_table(33) := '0909096F70742E6D61702E70616E546F28746869732E676574506F736974696F6E2829293B0D0A090909696620286F70742E6D61726B65725A6F6F6D29207B0D0A090909096F70742E6D61702E7365745A6F6F6D286F70742E6D61726B65725A6F6F6D29';
wwv_flow_api.g_varchar2_table(34) := '3B0D0A0909097D0D0A0909096A6B36347265706F72746D61705F6D61726B6572636C69636B286F70742C7044617461293B0D0A09097D293B0D0A090969662028216F70742E72657070696E29207B206F70742E72657070696E3D5B5D3B207D0D0A09096F';
wwv_flow_api.g_varchar2_table(35) := '70742E72657070696E2E70757368287B226964223A70446174612E69642C226D61726B6572223A72657070696E7D293B0D0A097D0D0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F72657050696E73286F707429207B0D0A0969';
wwv_flow_api.g_varchar2_table(36) := '6620286F70742E6D6170646174612E6C656E6774683E3029207B0D0A0909696620286F70742E696E666F4E6F44617461466F756E6429207B0D0A090909617065782E6465627567286F70742E726567696F6E49642B222068696465204E6F204461746120';
wwv_flow_api.g_varchar2_table(37) := '466F756E6420696E666F77696E646F7722293B0D0A0909096F70742E696E666F4E6F44617461466F756E642E636C6F736528293B0D0A09097D0D0A0909666F7220287661722069203D20303B2069203C206F70742E6D6170646174612E6C656E6774683B';
wwv_flow_api.g_varchar2_table(38) := '20692B2B29207B0D0A0909096A6B36347265706F72746D61705F72657050696E286F70742C6F70742E6D6170646174615B695D293B0D0A09097D0D0A097D20656C7365207B0D0A0909696620286F70742E6E6F446174614D65737361676520213D3D2022';
wwv_flow_api.g_varchar2_table(39) := '2229207B0D0A090909617065782E6465627567286F70742E726567696F6E49642B222073686F77204E6F204461746120466F756E6420696E666F77696E646F7722293B0D0A090909696620286F70742E696E666F4E6F44617461466F756E6429207B0D0A';
wwv_flow_api.g_varchar2_table(40) := '090909096F70742E696E666F4E6F44617461466F756E642E636C6F736528293B0D0A0909097D20656C7365207B0D0A090909096F70742E696E666F4E6F44617461466F756E64203D206E657720676F6F676C652E6D6170732E496E666F57696E646F7728';
wwv_flow_api.g_varchar2_table(41) := '0D0A09090909097B0D0A090909090909636F6E74656E743A206F70742E6E6F446174614D6573736167652C0D0A090909090909706F736974696F6E3A206A6B36347265706F72746D61705F70617273654C61744C6E67286F70742E6C61746C6E67290D0A';
wwv_flow_api.g_varchar2_table(42) := '09090909097D293B0D0A0909097D0D0A0909096F70742E696E666F4E6F44617461466F756E642E6F70656E286F70742E6D6170293B0D0A09097D0D0A097D0D0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F636C69636B286F70';
wwv_flow_api.g_varchar2_table(43) := '742C696429207B0D0A202076617220666F756E64203D2066616C73653B0D0A2020666F7220287661722069203D20303B2069203C206F70742E72657070696E2E6C656E6774683B20692B2B29207B0D0A20202020696620286F70742E72657070696E5B69';
wwv_flow_api.g_varchar2_table(44) := '5D2E69643D3D696429207B0D0A2020202020206E657720676F6F676C652E6D6170732E6576656E742E74726967676572286F70742E72657070696E5B695D2E6D61726B65722C22636C69636B22293B0D0A202020202020666F756E64203D20747275653B';
wwv_flow_api.g_varchar2_table(45) := '0D0A202020202020627265616B3B0D0A202020207D0D0A20207D0D0A20206966202821666F756E6429207B0D0A20202020617065782E6465627567286F70742E726567696F6E49642B22206964206E6F7420666F756E643A222B6964293B0D0A20207D0D';
wwv_flow_api.g_varchar2_table(46) := '0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F736574436972636C65286F70742C706F7329207B0D0A2020696620286F70742E646973744974656D213D3D222229207B0D0A20202020696620286F70742E64697374636972636C';
wwv_flow_api.g_varchar2_table(47) := '6529207B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B22206D6F766520636972636C6522293B0D0A2020202020206F70742E64697374636972636C652E73657443656E74657228706F73293B0D0A2020202020206F70';
wwv_flow_api.g_varchar2_table(48) := '742E64697374636972636C652E7365744D6170286F70742E6D6170293B0D0A202020207D20656C7365207B0D0A202020202020766172207261646975735F6B6D203D207061727365466C6F6174282476286F70742E646973744974656D29293B0D0A2020';
wwv_flow_api.g_varchar2_table(49) := '20202020617065782E6465627567286F70742E726567696F6E49642B222063726561746520636972636C65207261646975733D222B7261646975735F6B6D293B0D0A2020202020206F70742E64697374636972636C65203D206E657720676F6F676C652E';
wwv_flow_api.g_varchar2_table(50) := '6D6170732E436972636C65287B0D0A202020202020202020207374726F6B65436F6C6F723A202223353035304646222C0D0A202020202020202020207374726F6B654F7061636974793A20302E352C0D0A202020202020202020207374726F6B65576569';
wwv_flow_api.g_varchar2_table(51) := '6768743A20322C0D0A2020202020202020202066696C6C436F6C6F723A202223303030304646222C0D0A2020202020202020202066696C6C4F7061636974793A20302E30352C0D0A20202020202020202020636C69636B61626C653A2066616C73652C0D';
wwv_flow_api.g_varchar2_table(52) := '0A202020202020202020206564697461626C653A20747275652C0D0A202020202020202020206D61703A206F70742E6D61702C0D0A2020202020202020202063656E7465723A20706F732C0D0A202020202020202020207261646975733A207261646975';
wwv_flow_api.g_varchar2_table(53) := '735F6B6D2A313030300D0A20202020202020207D293B0D0A202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286F70742E64697374636972636C652C20227261646975735F6368616E676564222C2066756E637469';
wwv_flow_api.g_varchar2_table(54) := '6F6E20286576656E7429207B0D0A2020202020202020766172207261646975735F6B6D203D206F70742E64697374636972636C652E67657452616469757328292F313030303B0D0A2020202020202020617065782E6465627567286F70742E726567696F';
wwv_flow_api.g_varchar2_table(55) := '6E49642B2220636972636C6520726164697573206368616E67656420222B7261646975735F6B6D293B0D0A20202020202020202473286F70742E646973744974656D2C207261646975735F6B6D293B0D0A20202020202020206A6B36347265706F72746D';
wwv_flow_api.g_varchar2_table(56) := '61705F726566726573684D6170286F7074293B0D0A2020202020207D293B0D0A202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286F70742E64697374636972636C652C202263656E7465725F6368616E67656422';
wwv_flow_api.g_varchar2_table(57) := '2C2066756E6374696F6E20286576656E7429207B0D0A202020202020202076617220637472203D206F70742E64697374636972636C652E67657443656E74657228290D0A20202020202020202020202C6C61746C6E67203D206374722E6C617428292B22';
wwv_flow_api.g_varchar2_table(58) := '2C222B6374722E6C6E6728293B0D0A2020202020202020617065782E6465627567286F70742E726567696F6E49642B2220636972636C652063656E746572206368616E67656420222B6C61746C6E67293B0D0A2020202020202020696620286F70742E73';
wwv_flow_api.g_varchar2_table(59) := '796E634974656D213D3D222229207B0D0A202020202020202020202473286F70742E73796E634974656D2C6C61746C6E67293B0D0A202020202020202020206A6B36347265706F72746D61705F726566726573684D6170286F7074293B0D0A2020202020';
wwv_flow_api.g_varchar2_table(60) := '2020207D0D0A2020202020207D293B0D0A202020207D0D0A20207D0D0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F7573657250696E286F70742C6C61742C6C6E6729207B0D0A2020696620286C6174213D3D6E756C6C202626';
wwv_flow_api.g_varchar2_table(61) := '206C6E67213D3D6E756C6C29207B0D0A20202020766172206F6C64706F73203D206F70742E7573657270696E3F6F70742E7573657270696E2E676574506F736974696F6E28293A6E657720676F6F676C652E6D6170732E4C61744C6E6728302C30293B0D';
wwv_flow_api.g_varchar2_table(62) := '0A20202020696620286C61743D3D6F6C64706F732E6C61742829202626206C6E673D3D6F6C64706F732E6C6E67282929207B0D0A202020202020617065782E6465627567286F70742E726567696F6E49642B22207573657270696E206E6F74206368616E';
wwv_flow_api.g_varchar2_table(63) := '67656422293B0D0A202020207D20656C7365207B0D0A20202020202076617220706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E67286C61742C6C6E67293B0D0A202020202020696620286F70742E7573657270696E29207B0D0A2020';
wwv_flow_api.g_varchar2_table(64) := '202020202020617065782E6465627567286F70742E726567696F6E49642B22206D6F7665206578697374696E672070696E20746F206E657720706F736974696F6E206F6E206D617020222B6C61742B222C222B6C6E67293B0D0A20202020202020206F70';
wwv_flow_api.g_varchar2_table(65) := '742E7573657270696E2E7365744D6170286F70742E6D6170293B0D0A20202020202020206F70742E7573657270696E2E736574506F736974696F6E28706F73293B0D0A20202020202020206A6B36347265706F72746D61705F736574436972636C65286F';
wwv_flow_api.g_varchar2_table(66) := '70742C706F73293B0D0A2020202020207D20656C7365207B0D0A2020202020202020617065782E6465627567286F70742E726567696F6E49642B2220637265617465207573657270696E20222B6C61742B222C222B6C6E67293B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(67) := '6F70742E7573657270696E203D206E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A206F70742E6D61702C20706F736974696F6E3A20706F732C2069636F6E3A206F70742E69636F6E7D293B0D0A20202020202020206A6B36347265';
wwv_flow_api.g_varchar2_table(68) := '706F72746D61705F736574436972636C65286F70742C706F73293B0D0A2020202020207D0D0A202020207D0D0A20207D20656C736520696620286F70742E7573657270696E29207B0D0A20202020617065782E6465627567286F70742E726567696F6E49';
wwv_flow_api.g_varchar2_table(69) := '642B22206D6F7665206578697374696E672070696E206F666620746865206D617022293B0D0A202020206F70742E7573657270696E2E7365744D6170286E756C6C293B0D0A20202020696620286F70742E64697374636972636C6529207B0D0A20202020';
wwv_flow_api.g_varchar2_table(70) := '2020617065782E6465627567286F70742E726567696F6E49642B22206D6F76652064697374636972636C65206F666620746865206D617022293B0D0A2020202020206F70742E64697374636972636C652E7365744D6170286E756C6C293B0D0A20202020';
wwv_flow_api.g_varchar2_table(71) := '7D0D0A20207D0D0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F67657441646472657373286F70742C6C61742C6C6E6729207B0D0A09766172206C61746C6E67203D207B6C61743A206C61742C206C6E673A206C6E677D3B0D0A';
wwv_flow_api.g_varchar2_table(72) := '096F70742E67656F636F6465722E67656F636F6465287B276C6F636174696F6E273A206C61746C6E677D2C2066756E6374696F6E28726573756C74732C2073746174757329207B0D0A090969662028737461747573203D3D3D20676F6F676C652E6D6170';
wwv_flow_api.g_varchar2_table(73) := '732E47656F636F6465725374617475732E4F4B29207B0D0A09090969662028726573756C74735B315D29207B0D0A090909092473286F70742E616464726573734974656D2C726573756C74735B305D2E666F726D61747465645F61646472657373293B0D';
wwv_flow_api.g_varchar2_table(74) := '0A2020202020202020617065782E6465627567286F70742E726567696F6E49642B222061646472657373666F756E642027222B726573756C74735B305D2E666F726D61747465645F616464726573732B222722293B0D0A2020202020202020617065782E';
wwv_flow_api.g_varchar2_table(75) := '6A5175657279282223222B6F70742E726567696F6E4964292E74726967676572282261646472657373666F756E64222C207B0D0A202020202020202020206D61703A6F70742E6D61702C0D0A202020202020202020206C61743A6C61742C0D0A20202020';
wwv_flow_api.g_varchar2_table(76) := '2020202020206C6E673A6C6E672C0D0A20202020202020202020666F726D61747465645F616464726573733A726573756C74735B305D2E666F726D61747465645F616464726573730D0A20202020202020207D293B0D0A0909097D20656C7365207B0D0A';
wwv_flow_api.g_varchar2_table(77) := '0909090977696E646F772E616C65727428274E6F20726573756C747320666F756E6427293B0D0A0909097D0D0A09097D20656C7365207B0D0A09090977696E646F772E616C657274282747656F636F646572206661696C65642064756520746F3A202720';
wwv_flow_api.g_varchar2_table(78) := '2B20737461747573293B0D0A09097D0D0A097D293B0D0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F67656F6C6F63617465286F707429207B0D0A09696620286E6176696761746F722E67656F6C6F636174696F6E29207B0D0A';
wwv_flow_api.g_varchar2_table(79) := '0909617065782E6465627567286F70742E726567696F6E49642B222067656F6C6F6361746522293B0D0A09096E6176696761746F722E67656F6C6F636174696F6E2E67657443757272656E74506F736974696F6E2866756E6374696F6E28706F73697469';
wwv_flow_api.g_varchar2_table(80) := '6F6E29207B0D0A09090976617220706F73203D207B0D0A090909096C61743A20706F736974696F6E2E636F6F7264732E6C617469747564652C0D0A090909096C6E673A20706F736974696F6E2E636F6F7264732E6C6F6E6769747564650D0A0909097D3B';
wwv_flow_api.g_varchar2_table(81) := '0D0A0909096F70742E6D61702E70616E546F28706F73293B0D0A090909696620286F70742E67656F6C6F636174655A6F6F6D29207B0D0A09090920206F70742E6D61702E7365745A6F6F6D286F70742E67656F6C6F636174655A6F6F6D293B0D0A090909';
wwv_flow_api.g_varchar2_table(82) := '7D0D0A090909617065782E6A5175657279282223222B6F70742E726567696F6E4964292E74726967676572282267656F6C6F63617465222C207B6D61703A6F70742E6D61702C206C61743A706F732E6C61742C206C6E673A706F732E6C6E677D293B0D0A';
wwv_flow_api.g_varchar2_table(83) := '09097D293B0D0A097D20656C7365207B0D0A0909617065782E6465627567286F70742E726567696F6E49642B222062726F7773657220646F6573206E6F7420737570706F72742067656F6C6F636174696F6E22293B0D0A097D0D0A7D0D0A0D0A66756E63';
wwv_flow_api.g_varchar2_table(84) := '74696F6E206A6B36347265706F72746D61705F636F6E766572744C61744C6E672873747229207B0D0A092F2F207365652069662074686520737472696E672063616E20626520696E7465727072657465642061732061206C61742C6C6E6720706169723B';
wwv_flow_api.g_varchar2_table(85) := '206F74686572776973652C0D0A092F2F2077652077696C6C20617373756D65206974277320616E2061646472657373206F72206C6F636174696F6E206E616D650D0A0976617220617272203D207374722E73706C697428222C22293B0D0A096966202828';
wwv_flow_api.g_varchar2_table(86) := '6172722E6C656E677468213D3229207C7C2069734E614E286172725B305D29207C7C2069734E614E286172725B315D2929207B0D0A090972657475726E207374723B0D0A097D20656C7365207B0D0A090972657475726E207B6C61743A20706172736546';
wwv_flow_api.g_varchar2_table(87) := '6C6F6174286172725B305D292C206C6E673A207061727365466C6F6174286172725B315D297D3B0D0A097D0D0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F646972656374696F6E737265737028726573706F6E73652C737461';
wwv_flow_api.g_varchar2_table(88) := '7475732C6F707429207B0D0A202069662028737461747573203D3D20676F6F676C652E6D6170732E446972656374696F6E735374617475732E4F4B29207B0D0A202020206F70742E646972656374696F6E73446973706C61792E73657444697265637469';
wwv_flow_api.g_varchar2_table(89) := '6F6E7328726573706F6E7365293B0D0A2020202069662028286F70742E646972646973744974656D20213D3D20222229207C7C20286F70742E6469726475724974656D20213D3D2022222929207B0D0A20202020202076617220746F74616C4469737461';
wwv_flow_api.g_varchar2_table(90) := '6E6365203D20302C20746F74616C4475726174696F6E203D20303B0D0A202020202020666F72202876617220693D303B2069203C20726573706F6E73652E726F757465732E6C656E6774683B20692B2B29207B0D0A2020202020202020666F7220287661';
wwv_flow_api.g_varchar2_table(91) := '72206A3D303B206A203C20726573706F6E73652E726F757465735B695D2E6C6567732E6C656E6774683B206A2B2B29207B0D0A20202020202020202020766172206C6567203D20726573706F6E73652E726F757465735B695D2E6C6567735B6A5D3B0D0A';
wwv_flow_api.g_varchar2_table(92) := '20202020202020202020746F74616C44697374616E6365203D20746F74616C44697374616E6365202B206C65672E64697374616E63652E76616C75653B0D0A20202020202020202020746F74616C4475726174696F6E203D20746F74616C447572617469';
wwv_flow_api.g_varchar2_table(93) := '6F6E202B206C65672E6475726174696F6E2E76616C75653B0D0A20202020202020207D0D0A2020202020207D0D0A202020202020696620286F70742E646972646973744974656D20213D3D20222229207B0D0A20202020202020202473286F70742E6469';
wwv_flow_api.g_varchar2_table(94) := '72646973744974656D2C20746F74616C44697374616E6365293B0D0A2020202020207D0D0A202020202020696620286F70742E6469726475724974656D20213D3D20222229207B0D0A20202020202020202473286F70742E6469726475724974656D2C20';
wwv_flow_api.g_varchar2_table(95) := '746F74616C4475726174696F6E293B0D0A2020202020207D0D0A202020207D0D0A20207D20656C7365207B0D0A2020202077696E646F772E616C6572742827446972656374696F6E732072657175657374206661696C65642064756520746F2027202B20';
wwv_flow_api.g_varchar2_table(96) := '737461747573293B0D0A20207D0D0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F646972656374696F6E73286F707429207B0D0A09617065782E6465627567286F70742E726567696F6E49642B2220646972656374696F6E7320';
wwv_flow_api.g_varchar2_table(97) := '222B6F70742E646972656374696F6E73293B0D0A09766172206F726967696E0D0A092020202C646573740D0A20202020202C726F757465696E646578203D206F70742E646972656374696F6E732E696E6465784F6628222D524F55544522290D0A202020';
wwv_flow_api.g_varchar2_table(98) := '20202C74726176656C6D6F64653B0D0A0969662028726F757465696E6465783C3029207B0D0A202020202F2F73696D706C6520646972656374696F6E73206265747765656E2074776F206974656D730D0A202020206F726967696E203D206A6B36347265';
wwv_flow_api.g_varchar2_table(99) := '706F72746D61705F636F6E766572744C61744C6E67282476286F70742E6F726967696E4974656D29293B0D0A20202020646573742020203D206A6B36347265706F72746D61705F636F6E766572744C61744C6E67282476286F70742E646573744974656D';
wwv_flow_api.g_varchar2_table(100) := '29293B0D0A20202020696620286F726967696E20213D3D202222202626206465737420213D3D20222229207B0D0A20202020202074726176656C6D6F6465203D206F70742E646972656374696F6E733B0D0A092020096F70742E646972656374696F6E73';
wwv_flow_api.g_varchar2_table(101) := '536572766963652E726F757465287B0D0A09092020096F726967696E3A6F726967696E2C0D0A090909202064657374696E6174696F6E3A646573742C0D0A090909202074726176656C4D6F64653A676F6F676C652E6D6170732E54726176656C4D6F6465';
wwv_flow_api.g_varchar2_table(102) := '5B74726176656C6D6F64655D0D0A090920207D2C2066756E6374696F6E28726573706F6E73652C737461747573297B6A6B36347265706F72746D61705F646972656374696F6E737265737028726573706F6E73652C7374617475732C6F7074297D293B0D';
wwv_flow_api.g_varchar2_table(103) := '0A202020207D0D0A20207D20656C7365207B0D0A202020202F2F726F7574652076696120776179706F696E74730D0A2020202074726176656C6D6F6465203D206F70742E646972656374696F6E732E736C69636528302C726F757465696E646578293B0D';
wwv_flow_api.g_varchar2_table(104) := '0A20202020617065782E6465627567286F70742E726567696F6E49642B2220726F7574652076696120222B74726176656C6D6F64652B22207769746820222B6F70742E6D6170646174612E6C656E6774682B2220776179706F696E747322293B0D0A2020';
wwv_flow_api.g_varchar2_table(105) := '202076617220776179706F696E7473203D205B5D3B0D0A200909666F7220287661722069203D20303B2069203C206F70742E6D6170646174612E6C656E6774683B20692B2B29207B0D0A2020202020206966202869203D3D203029207B0D0A2020202020';
wwv_flow_api.g_varchar2_table(106) := '2020206F726967696E203D206E657720676F6F676C652E6D6170732E4C61744C6E67286F70742E6D6170646174615B695D2E6C61742C206F70742E6D6170646174615B695D2E6C6E67293B0D0A2020202020207D20656C7365206966202869203D3D206F';
wwv_flow_api.g_varchar2_table(107) := '70742E6D6170646174612E6C656E6774682D3129207B0D0A202020202020202064657374203D206E657720676F6F676C652E6D6170732E4C61744C6E67286F70742E6D6170646174615B695D2E6C61742C206F70742E6D6170646174615B695D2E6C6E67';
wwv_flow_api.g_varchar2_table(108) := '293B0D0A2020202020207D20656C7365207B0D0A2020202020202020776179706F696E74732E70757368287B0D0A202020202020202020206C6F636174696F6E3A206E657720676F6F676C652E6D6170732E4C61744C6E67286F70742E6D617064617461';
wwv_flow_api.g_varchar2_table(109) := '5B695D2E6C61742C206F70742E6D6170646174615B695D2E6C6E67292C0D0A2020202020202020202073746F706F7665723A20747275650D0A20202020202020207D293B0D0A2020202020207D0D0A09097D0D0A20202020617065782E6465627567286F';
wwv_flow_api.g_varchar2_table(110) := '70742E726567696F6E49642B22206F726967696E3D222B6F726967696E293B0D0A20202020617065782E6465627567286F70742E726567696F6E49642B2220646573743D222B64657374293B0D0A20202020617065782E6465627567286F70742E726567';
wwv_flow_api.g_varchar2_table(111) := '696F6E49642B2220776179706F696E74733A222B776179706F696E74732E6C656E677468293B0D0A09096F70742E646972656374696F6E73536572766963652E726F757465287B0D0A0909096F726967696E3A6F726967696E2C0D0A0909096465737469';
wwv_flow_api.g_varchar2_table(112) := '6E6174696F6E3A646573742C0D0A202020202020776179706F696E74733A776179706F696E74732C0D0A2020202020206F7074696D697A65576179706F696E74733A6F70742E6F7074696D697A65576179706F696E74732C0D0A09090974726176656C4D';
wwv_flow_api.g_varchar2_table(113) := '6F64653A676F6F676C652E6D6170732E54726176656C4D6F64655B74726176656C6D6F64655D0D0A09097D2C2066756E6374696F6E28726573706F6E73652C737461747573297B6A6B36347265706F72746D61705F646972656374696F6E737265737028';
wwv_flow_api.g_varchar2_table(114) := '726573706F6E73652C7374617475732C6F7074297D293B0D0A097D0D0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F696E69744D6170286F707429207B0D0A09617065782E6465627567286F70742E726567696F6E49642B2220';
wwv_flow_api.g_varchar2_table(115) := '696E69744D617020222B6F70742E6D617074797065293B0D0A09766172206D794F7074696F6E73203D207B0D0A09097A6F6F6D3A20312C0D0A090963656E7465723A206A6B36347265706F72746D61705F70617273654C61744C6E67286F70742E6C6174';
wwv_flow_api.g_varchar2_table(116) := '6C6E67292C0D0A09096D61705479706549643A206F70742E6D6170747970650D0A097D3B0D0A096F70742E6D6170203D206E657720676F6F676C652E6D6170732E4D617028646F63756D656E742E676574456C656D656E7442794964286F70742E636F6E';
wwv_flow_api.g_varchar2_table(117) := '7461696E6572292C6D794F7074696F6E73293B0D0A20206F70742E6D61702E7365744F7074696F6E73287B0D0A20202020202020647261676761626C653A206F70742E70616E0D0A2020202020202C7A6F6F6D436F6E74726F6C3A206F70742E7A6F6F6D';
wwv_flow_api.g_varchar2_table(118) := '0D0A2020202020202C7363726F6C6C776865656C3A206F70742E7A6F6F6D0D0A2020202020202C64697361626C65446F75626C65436C69636B5A6F6F6D3A2021286F70742E7A6F6F6D290D0A2020202020202C6765737475726548616E646C696E673A20';
wwv_flow_api.g_varchar2_table(119) := '6F70742E6765737475726548616E646C696E670D0A202020207D293B0D0A09696620286F70742E6D61707374796C6529207B0D0A09096F70742E6D61702E7365744F7074696F6E73287B7374796C65733A206F70742E6D61707374796C657D293B0D0A09';
wwv_flow_api.g_varchar2_table(120) := '7D0D0A096F70742E6D61702E666974426F756E6473286E657720676F6F676C652E6D6170732E4C61744C6E67426F756E6473286F70742E736F757468776573742C6F70742E6E6F7274686561737429293B0D0A09696620286F70742E73796E634974656D';
wwv_flow_api.g_varchar2_table(121) := '213D3D222229207B0D0A09097661722076616C203D202476286F70742E73796E634974656D293B0D0A09096966202876616C20213D3D206E756C6C29207B0D0A0909096F70742E7573657270696E203D206E657720676F6F676C652E6D6170732E4D6172';
wwv_flow_api.g_varchar2_table(122) := '6B6572287B6D61703A206F70742E6D61702C20706F736974696F6E3A206A6B36347265706F72746D61705F70617273654C61744C6E672876616C292C2069636F6E3A206F70742E69636F6E7D293B0D0A0909096A6B36347265706F72746D61705F736574';
wwv_flow_api.g_varchar2_table(123) := '436972636C65286F70742C706F73293B0D0A09097D0D0A09092F2F696620746865206C61742F6C6F6E67206974656D206973206368616E6765642C206D6F7665207468652070696E0D0A090924282223222B6F70742E73796E634974656D292E6368616E';
wwv_flow_api.g_varchar2_table(124) := '67652866756E6374696F6E28297B200D0A090909766172206C61746C6E67203D20746869732E76616C75653B0D0A090909696620286C61746C6E6720213D3D206E756C6C202626206C61746C6E6720213D3D20756E646566696E6564202626206C61746C';
wwv_flow_api.g_varchar2_table(125) := '6E672E696E6465784F6628222C2229203E202D3129207B0D0A0909090976617220617272203D206C61746C6E672E73706C697428222C22293B0D0A09090909617065782E6465627567286F70742E726567696F6E49642B22206974656D206368616E6765';
wwv_flow_api.g_varchar2_table(126) := '6420222B6172725B305D2B2220222B6172725B315D293B0D0A090909096A6B36347265706F72746D61705F7573657250696E286F70742C6172725B305D2C6172725B315D293B0D0A0909097D0D0A09097D293B0D0A097D0D0A09696620286F70742E6469';
wwv_flow_api.g_varchar2_table(127) := '73744974656D213D222229207B0D0A09092F2F6966207468652064697374616E6365206974656D206973206368616E6765642C207265647261772074686520636972636C650D0A090924282223222B6F70742E646973744974656D292E6368616E676528';
wwv_flow_api.g_varchar2_table(128) := '66756E6374696F6E28297B0D0A09090969662028746869732E76616C756529207B0D0A09090909766172207261646975735F6D6574726573203D207061727365466C6F617428746869732E76616C7565292A313030303B0D0A09090909696620286F7074';
wwv_flow_api.g_varchar2_table(129) := '2E64697374636972636C652E676574526164697573282920213D3D207261646975735F6D657472657329207B0D0A0909090909617065782E6465627567286F70742E726567696F6E49642B2220646973746974656D206368616E67656420222B72616469';
wwv_flow_api.g_varchar2_table(130) := '75735F6D6574726573293B0D0A09090909096F70742E64697374636972636C652E736574526164697573287261646975735F6D6574726573293B0D0A090909097D0D0A0909097D20656C7365207B0D0A09090909696620286F70742E6469737463697263';
wwv_flow_api.g_varchar2_table(131) := '6C6529207B0D0A0909090909617065782E6465627567286F70742E726567696F6E49642B2220646973746974656D20636C656172656422293B0D0A09090909096F70742E64697374636972636C652E7365744D6170286E756C6C293B0D0A090909097D0D';
wwv_flow_api.g_varchar2_table(132) := '0A0909097D0D0A09097D293B0D0A097D0D0A09696620286F70742E6578706563744461746129207B0D0A09096A6B36347265706F72746D61705F72657050696E73286F7074293B0D0A097D0D0A09696620286F70742E616464726573734974656D213D3D';
wwv_flow_api.g_varchar2_table(133) := '222229207B0D0A09096F70742E67656F636F646572203D206E657720676F6F676C652E6D6170732E47656F636F6465723B0D0A097D0D0A09696620286F70742E646972656374696F6E7329207B0D0A09096F70742E646972656374696F6E73446973706C';
wwv_flow_api.g_varchar2_table(134) := '6179203D206E657720676F6F676C652E6D6170732E446972656374696F6E7352656E64657265723B0D0A202020206F70742E646972656374696F6E7353657276696365203D206E657720676F6F676C652E6D6170732E446972656374696F6E7353657276';
wwv_flow_api.g_varchar2_table(135) := '6963653B0D0A09096F70742E646972656374696F6E73446973706C61792E7365744D6170286F70742E6D6170293B0D0A09096A6B36347265706F72746D61705F646972656374696F6E73286F7074293B0D0A09092F2F696620746865206F726967696E20';
wwv_flow_api.g_varchar2_table(136) := '6F722064657374206974656D206973206368616E67656420666F722073696D706C6520646972656374696F6E732C20726563616C632074686520646972656374696F6E730D0A20202020696620286F70742E646972656374696F6E732E696E6465784F66';
wwv_flow_api.g_varchar2_table(137) := '28222D524F55544522293C3029207B0D0A2020090924282223222B6F70742E6F726967696E4974656D292E6368616E67652866756E6374696F6E28297B0D0A09202009096A6B36347265706F72746D61705F646972656374696F6E73286F7074293B0D0A';
wwv_flow_api.g_varchar2_table(138) := '090920207D293B0D0A0909202024282223222B6F70742E646573744974656D292E6368616E67652866756E6374696F6E28297B0D0A09090920206A6B36347265706F72746D61705F646972656374696F6E73286F7074293B0D0A092020097D293B0D0A20';
wwv_flow_api.g_varchar2_table(139) := '2020207D0D0A097D0D0A09676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286F70742E6D61702C2022636C69636B222C2066756E6374696F6E20286576656E7429207B0D0A0909766172206C6174203D206576656E742E6C6174';
wwv_flow_api.g_varchar2_table(140) := '4C6E672E6C617428290D0A09092020202C6C6E67203D206576656E742E6C61744C6E672E6C6E6728293B0D0A0909617065782E6465627567286F70742E726567696F6E49642B22206D617020636C69636B656420222B6C61742B222C222B6C6E67293B0D';
wwv_flow_api.g_varchar2_table(141) := '0A090969662028286F70742E73796E634974656D213D3D222229207C7C20286F70742E616464726573734974656D213D3D22222929207B0D0A0909096A6B36347265706F72746D61705F7573657250696E286F70742C6C61742C6C6E67293B0D0A09097D';
wwv_flow_api.g_varchar2_table(142) := '0D0A0909696620286F70742E73796E634974656D213D3D222229207B0D0A0909092473286F70742E73796E634974656D2C6C61742B222C222B6C6E67293B0D0A0909096A6B36347265706F72746D61705F726566726573684D6170286F7074293B0D0A09';
wwv_flow_api.g_varchar2_table(143) := '097D20656C736520696620286F70742E6D61726B65725A6F6F6D29207B0D0A090909617065782E6465627567286F70742E726567696F6E49642B222070616E2B7A6F6F6D22293B0D0A0909096F70742E6D61702E70616E546F286576656E742E6C61744C';
wwv_flow_api.g_varchar2_table(144) := '6E67293B0D0A0909096F70742E6D61702E7365745A6F6F6D286F70742E6D61726B65725A6F6F6D293B0D0A09097D0D0A0909696620286F70742E616464726573734974656D213D3D222229207B0D0A0909096A6B36347265706F72746D61705F67657441';
wwv_flow_api.g_varchar2_table(145) := '646472657373286F70742C6C61742C6C6E67293B0D0A09097D0D0A0909617065782E6A5175657279282223222B6F70742E726567696F6E4964292E7472696767657228226D6170636C69636B222C207B6D61703A6F70742E6D61702C206C61743A6C6174';
wwv_flow_api.g_varchar2_table(146) := '2C206C6E673A6C6E677D293B0D0A097D293B0D0A09696620286F70742E67656F636F64654974656D213D222229207B0D0A09097661722067656F636F646572203D206E657720676F6F676C652E6D6170732E47656F636F64657228293B0D0A0909242822';
wwv_flow_api.g_varchar2_table(147) := '23222B6F70742E67656F636F64654974656D292E6368616E67652866756E6374696F6E28297B0D0A0909096A6B36347265706F72746D61705F67656F636F6465286F70742C67656F636F646572293B0D0A09097D293B0D0A0920207D0D0A09696620286F';
wwv_flow_api.g_varchar2_table(148) := '70742E67656F6C6F6361746529207B0D0A09096A6B36347265706F72746D61705F67656F6C6F63617465286F7074293B0D0A097D0D0A09617065782E6465627567286F70742E726567696F6E49642B2220696E69744D61702066696E697368656422293B';
wwv_flow_api.g_varchar2_table(149) := '0D0A09617065782E6A5175657279282223222B6F70742E726567696F6E4964292E7472696767657228226D61706C6F61646564222C207B6D61703A6F70742E6D61707D293B0D0A7D0D0A0D0A66756E6374696F6E206A6B36347265706F72746D61705F72';
wwv_flow_api.g_varchar2_table(150) := '6566726573684D6170286F707429207B0D0A09617065782E6465627567286F70742E726567696F6E49642B2220726566726573684D617022293B0D0A09617065782E6A5175657279282223222B6F70742E726567696F6E4964292E747269676765722822';
wwv_flow_api.g_varchar2_table(151) := '617065786265666F72657265667265736822293B0D0A09617065782E7365727665722E706C7567696E0D0A0909286F70742E616A61784964656E7469666965720D0A09092C7B20706167654974656D733A206F70742E616A61784974656D73207D0D0A09';
wwv_flow_api.g_varchar2_table(152) := '092C7B2064617461547970653A20226A736F6E220D0A0909092C737563636573733A2066756E6374696F6E282070446174612029207B0D0A09090909617065782E6465627567286F70742E726567696F6E49642B2220737563636573732070446174613D';
wwv_flow_api.g_varchar2_table(153) := '222B70446174612E736F757468776573742E6C61742B222C222B70446174612E736F757468776573742E6C6E672B2220222B70446174612E6E6F727468656173742E6C61742B222C222B70446174612E6E6F727468656173742E6C6E67293B0D0A090909';
wwv_flow_api.g_varchar2_table(154) := '096F70742E6D61702E666974426F756E6473280D0A09090909097B736F7574683A70446174612E736F757468776573742E6C61740D0A09090909092C776573743A2070446174612E736F757468776573742E6C6E670D0A09090909092C6E6F7274683A70';
wwv_flow_api.g_varchar2_table(155) := '446174612E6E6F727468656173742E6C61740D0A09090909092C656173743A2070446174612E6E6F727468656173742E6C6E677D293B0D0A09090909696620286F70742E697729207B0D0A09090909096F70742E69772E636C6F736528293B0D0A090909';
wwv_flow_api.g_varchar2_table(156) := '097D0D0A09090909696620286F70742E72657070696E29207B0D0A0909090909617065782E6465627567286F70742E726567696F6E49642B222072656D6F766520616C6C207265706F72742070696E7322293B0D0A0909090909666F7220287661722069';
wwv_flow_api.g_varchar2_table(157) := '203D20303B2069203C206F70742E72657070696E2E6C656E6774683B20692B2B29207B0D0A0909090909096F70742E72657070696E5B695D2E6D61726B65722E7365744D6170286E756C6C293B0D0A09090909097D0D0A09090909096F70742E72657070';
wwv_flow_api.g_varchar2_table(158) := '696E2E64656C6574653B0D0A090909097D0D0A09090909696620286F70742E636972636C657329207B0D0A0909090909617065782E6465627567286F70742E726567696F6E49642B222072656D6F766520616C6C20636972636C657322293B0D0A090909';
wwv_flow_api.g_varchar2_table(159) := '0909666F7220287661722069203D20303B2069203C206F70742E636972636C65732E6C656E6774683B20692B2B29207B0D0A09090909096F70742E636972636C65735B695D2E636972632E7365744D6170286E756C6C293B0D0A09090909097D0D0A0909';
wwv_flow_api.g_varchar2_table(160) := '0909096F70742E636972636C65732E64656C6574653B0D0A090909097D0D0A09090909617065782E6465627567286F70742E726567696F6E49642B222070446174612E6D6170646174612E6C656E6774683D222B70446174612E6D6170646174612E6C65';
wwv_flow_api.g_varchar2_table(161) := '6E677468293B0D0A090909096F70742E6D617064617461203D2070446174612E6D6170646174613B0D0A09090909696620286F70742E6578706563744461746129207B0D0A09090909096A6B36347265706F72746D61705F72657050696E73286F707429';
wwv_flow_api.g_varchar2_table(162) := '3B0D0A090909097D0D0A09090909696620286F70742E73796E634974656D213D3D222229207B0D0A09090909097661722076616C203D202476286F70742E73796E634974656D293B0D0A09090909096966202876616C213D3D6E756C6C2026262076616C';
wwv_flow_api.g_varchar2_table(163) := '2E696E6465784F6628222C2229203E202D3129207B0D0A09090909090976617220617272203D2076616C2E73706C697428222C22293B0D0A090909090909617065782E6465627567286F70742E726567696F6E49642B2220696E69742066726F6D206974';
wwv_flow_api.g_varchar2_table(164) := '656D20222B6172725B305D2B2220222B6172725B315D293B0D0A0909090909096A6B36347265706F72746D61705F7573657250696E286F70742C6172725B305D2C6172725B315D293B0D0A09090909097D0D0A090909097D0D0A09090909617065782E6A';
wwv_flow_api.g_varchar2_table(165) := '5175657279282223222B6F70742E726567696F6E4964292E7472696767657228226170657861667465727265667265736822293B0D0A0909097D0D0A09097D20293B0D0A09617065782E6465627567286F70742E726567696F6E49642B22207265667265';
wwv_flow_api.g_varchar2_table(166) := '73684D61702066696E697368656422293B0D0A7D0D0A';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(110666213583226283)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_file_name=>'jk64reportmap.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '66756E6374696F6E206A6B36347265706F72746D61705F70617273654C61744C6E672865297B76617220613B696628617065782E646562756728226A6B36347265706F72746D61705F70617273654C61744C6E6720222B65292C6E756C6C213D65262665';
wwv_flow_api.g_varchar2_table(2) := '2E696E6465784F6628222C22293E2D31297B76617220743D652E73706C697428222C22293B617065782E6465627567282270617273656420222B745B305D2B2220222B745B315D292C613D6E657720676F6F676C652E6D6170732E4C61744C6E6728745B';
wwv_flow_api.g_varchar2_table(3) := '305D2C745B315D297D72657475726E20617D66756E6374696F6E206A6B36347265706F72746D61705F67656F636F646528652C61297B612E67656F636F6465287B616464726573733A247628652E67656F636F64654974656D292C636F6D706F6E656E74';
wwv_flow_api.g_varchar2_table(4) := '5265737472696374696F6E733A2222213D3D652E636F756E7472793F7B636F756E7472793A652E636F756E7472797D3A7B7D7D2C66756E6374696F6E28612C74297B696628743D3D3D676F6F676C652E6D6170732E47656F636F6465725374617475732E';
wwv_flow_api.g_varchar2_table(5) := '4F4B297B76617220723D615B305D2E67656F6D657472792E6C6F636174696F6E3B617065782E646562756728652E726567696F6E49642B222067656F636F6465206F6B22292C652E6D61702E73657443656E7465722872292C652E6D61702E70616E546F';
wwv_flow_api.g_varchar2_table(6) := '2872292C652E6D61726B65725A6F6F6D2626652E6D61702E7365745A6F6F6D28652E6D61726B65725A6F6F6D292C6A6B36347265706F72746D61705F7573657250696E28652C722E6C617428292C722E6C6E672829292C652E616464726573734974656D';
wwv_flow_api.g_varchar2_table(7) := '2626247328652E616464726573734974656D2C615B305D2E666F726D61747465645F61646472657373292C617065782E646562756728652E726567696F6E49642B222061646472657373666F756E642027222B615B305D2E666F726D61747465645F6164';
wwv_flow_api.g_varchar2_table(8) := '64726573732B222722292C617065782E6A5175657279282223222B652E726567696F6E4964292E74726967676572282261646472657373666F756E64222C7B6D61703A652E6D61702C6C61743A722E6C617428292C6C6E673A722E6C6E6728292C666F72';
wwv_flow_api.g_varchar2_table(9) := '6D61747465645F616464726573733A615B305D2E666F726D61747465645F616464726573737D297D656C736520617065782E646562756728652E726567696F6E49642B222067656F636F64652077617320756E7375636365737366756C20666F72207468';
wwv_flow_api.g_varchar2_table(10) := '6520666F6C6C6F77696E6720726561736F6E3A20222B74297D297D66756E6374696F6E206A6B36347265706F72746D61705F6D61726B6572636C69636B28652C61297B2222213D3D652E69644974656D2626247328652E69644974656D2C612E6964292C';
wwv_flow_api.g_varchar2_table(11) := '617065782E6A5175657279282223222B652E726567696F6E4964292E7472696767657228226D61726B6572636C69636B222C7B6D61703A652E6D61702C69643A612E69642C6E616D653A612E6E616D652C6C61743A612E6C61742C6C6E673A612E6C6E67';
wwv_flow_api.g_varchar2_table(12) := '2C7261643A612E7261642C6174747230313A612E6174747230312C6174747230323A612E6174747230322C6174747230333A612E6174747230332C6174747230343A612E6174747230342C6174747230353A612E6174747230352C6174747230363A612E';
wwv_flow_api.g_varchar2_table(13) := '6174747230362C6174747230373A612E6174747230372C6174747230383A612E6174747230382C6174747230393A612E6174747230392C6174747231303A612E6174747231307D297D66756E6374696F6E206A6B36347265706F72746D61705F72657050';
wwv_flow_api.g_varchar2_table(14) := '696E28652C61297B76617220743D6E657720676F6F676C652E6D6170732E4C61744C6E6728612E6C61742C612E6C6E67293B696628612E726164297B76617220723D6E657720676F6F676C652E6D6170732E436972636C65287B7374726F6B65436F6C6F';
wwv_flow_api.g_varchar2_table(15) := '723A612E636F6C2C7374726F6B654F7061636974793A312C7374726F6B655765696768743A312C66696C6C436F6C6F723A612E636F6C2C66696C6C4F7061636974793A612E74726E732C636C69636B61626C653A21302C6D61703A652E6D61702C63656E';
wwv_flow_api.g_varchar2_table(16) := '7465723A742C7261646975733A3165332A612E7261647D293B676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228722C22636C69636B222C66756E6374696F6E28297B617065782E646562756728652E726567696F6E49642B2220';
wwv_flow_api.g_varchar2_table(17) := '636972636C6520636C69636B656420222B612E6964292C6A6B36347265706F72746D61705F6D61726B6572636C69636B28652C61297D292C652E636972636C65737C7C28652E636972636C65733D5B5D292C652E636972636C65732E70757368287B6964';
wwv_flow_api.g_varchar2_table(18) := '3A612E69642C636972633A727D297D656C73657B766172206F3D6E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A652E6D61702C706F736974696F6E3A742C7469746C653A612E6E616D652C69636F6E3A612E69636F6E2C6C616265';
wwv_flow_api.g_varchar2_table(19) := '6C3A612E6C6162656C7D293B676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286F2C22636C69636B222C66756E6374696F6E28297B617065782E646562756728652E726567696F6E49642B222072657050696E20636C69636B65';
wwv_flow_api.g_varchar2_table(20) := '6420222B612E6964292C612E696E666F262628652E69773F652E69772E636C6F736528293A652E69773D6E657720676F6F676C652E6D6170732E496E666F57696E646F772C652E69772E7365744F7074696F6E73287B636F6E74656E743A612E696E666F';
wwv_flow_api.g_varchar2_table(21) := '7D292C652E69772E6F70656E28652E6D61702C7468697329292C652E6D61702E70616E546F28746869732E676574506F736974696F6E2829292C652E6D61726B65725A6F6F6D2626652E6D61702E7365745A6F6F6D28652E6D61726B65725A6F6F6D292C';
wwv_flow_api.g_varchar2_table(22) := '6A6B36347265706F72746D61705F6D61726B6572636C69636B28652C61297D292C652E72657070696E7C7C28652E72657070696E3D5B5D292C652E72657070696E2E70757368287B69643A612E69642C6D61726B65723A6F7D297D7D66756E6374696F6E';
wwv_flow_api.g_varchar2_table(23) := '206A6B36347265706F72746D61705F72657050696E732865297B696628652E6D6170646174612E6C656E6774683E30297B652E696E666F4E6F44617461466F756E64262628617065782E646562756728652E726567696F6E49642B222068696465204E6F';
wwv_flow_api.g_varchar2_table(24) := '204461746120466F756E6420696E666F77696E646F7722292C652E696E666F4E6F44617461466F756E642E636C6F73652829293B666F722876617220613D303B613C652E6D6170646174612E6C656E6774683B612B2B296A6B36347265706F72746D6170';
wwv_flow_api.g_varchar2_table(25) := '5F72657050696E28652C652E6D6170646174615B615D297D656C73652222213D3D652E6E6F446174614D657373616765262628617065782E646562756728652E726567696F6E49642B222073686F77204E6F204461746120466F756E6420696E666F7769';
wwv_flow_api.g_varchar2_table(26) := '6E646F7722292C652E696E666F4E6F44617461466F756E643F652E696E666F4E6F44617461466F756E642E636C6F736528293A652E696E666F4E6F44617461466F756E643D6E657720676F6F676C652E6D6170732E496E666F57696E646F77287B636F6E';
wwv_flow_api.g_varchar2_table(27) := '74656E743A652E6E6F446174614D6573736167652C706F736974696F6E3A6A6B36347265706F72746D61705F70617273654C61744C6E6728652E6C61746C6E67297D292C652E696E666F4E6F44617461466F756E642E6F70656E28652E6D617029297D66';
wwv_flow_api.g_varchar2_table(28) := '756E6374696F6E206A6B36347265706F72746D61705F636C69636B28652C61297B666F722876617220743D21312C723D303B723C652E72657070696E2E6C656E6774683B722B2B29696628652E72657070696E5B725D2E69643D3D61297B6E657720676F';
wwv_flow_api.g_varchar2_table(29) := '6F676C652E6D6170732E6576656E742E7472696767657228652E72657070696E5B725D2E6D61726B65722C22636C69636B22292C743D21303B627265616B7D747C7C617065782E646562756728652E726567696F6E49642B22206964206E6F7420666F75';
wwv_flow_api.g_varchar2_table(30) := '6E643A222B61297D66756E6374696F6E206A6B36347265706F72746D61705F736574436972636C6528652C61297B6966282222213D3D652E646973744974656D29696628652E64697374636972636C6529617065782E646562756728652E726567696F6E';
wwv_flow_api.g_varchar2_table(31) := '49642B22206D6F766520636972636C6522292C652E64697374636972636C652E73657443656E7465722861292C652E64697374636972636C652E7365744D617028652E6D6170293B656C73657B76617220743D7061727365466C6F617428247628652E64';
wwv_flow_api.g_varchar2_table(32) := '6973744974656D29293B617065782E646562756728652E726567696F6E49642B222063726561746520636972636C65207261646975733D222B74292C652E64697374636972636C653D6E657720676F6F676C652E6D6170732E436972636C65287B737472';
wwv_flow_api.g_varchar2_table(33) := '6F6B65436F6C6F723A2223353035304646222C7374726F6B654F7061636974793A2E352C7374726F6B655765696768743A322C66696C6C436F6C6F723A2223303030304646222C66696C6C4F7061636974793A2E30352C636C69636B61626C653A21312C';
wwv_flow_api.g_varchar2_table(34) := '6564697461626C653A21302C6D61703A652E6D61702C63656E7465723A612C7261646975733A3165332A747D292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228652E64697374636972636C652C227261646975735F636861';
wwv_flow_api.g_varchar2_table(35) := '6E676564222C66756E6374696F6E2861297B76617220743D652E64697374636972636C652E67657452616469757328292F3165333B617065782E646562756728652E726567696F6E49642B2220636972636C6520726164697573206368616E6765642022';
wwv_flow_api.g_varchar2_table(36) := '2B74292C247328652E646973744974656D2C74292C6A6B36347265706F72746D61705F726566726573684D61702865297D292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228652E64697374636972636C652C2263656E7465';
wwv_flow_api.g_varchar2_table(37) := '725F6368616E676564222C66756E6374696F6E2861297B76617220743D652E64697374636972636C652E67657443656E74657228292C723D742E6C617428292B222C222B742E6C6E6728293B617065782E646562756728652E726567696F6E49642B2220';
wwv_flow_api.g_varchar2_table(38) := '636972636C652063656E746572206368616E67656420222B72292C2222213D3D652E73796E634974656D262628247328652E73796E634974656D2C72292C6A6B36347265706F72746D61705F726566726573684D6170286529297D297D7D66756E637469';
wwv_flow_api.g_varchar2_table(39) := '6F6E206A6B36347265706F72746D61705F7573657250696E28652C612C74297B6966286E756C6C213D3D6126266E756C6C213D3D74297B76617220723D652E7573657270696E3F652E7573657270696E2E676574506F736974696F6E28293A6E65772067';
wwv_flow_api.g_varchar2_table(40) := '6F6F676C652E6D6170732E4C61744C6E6728302C30293B696628613D3D722E6C617428292626743D3D722E6C6E67282929617065782E646562756728652E726567696F6E49642B22207573657270696E206E6F74206368616E67656422293B656C73657B';
wwv_flow_api.g_varchar2_table(41) := '766172206F3D6E657720676F6F676C652E6D6170732E4C61744C6E6728612C74293B652E7573657270696E3F28617065782E646562756728652E726567696F6E49642B22206D6F7665206578697374696E672070696E20746F206E657720706F73697469';
wwv_flow_api.g_varchar2_table(42) := '6F6E206F6E206D617020222B612B222C222B74292C652E7573657270696E2E7365744D617028652E6D6170292C652E7573657270696E2E736574506F736974696F6E286F292C6A6B36347265706F72746D61705F736574436972636C6528652C6F29293A';
wwv_flow_api.g_varchar2_table(43) := '28617065782E646562756728652E726567696F6E49642B2220637265617465207573657270696E20222B612B222C222B74292C652E7573657270696E3D6E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A652E6D61702C706F736974';
wwv_flow_api.g_varchar2_table(44) := '696F6E3A6F2C69636F6E3A652E69636F6E7D292C6A6B36347265706F72746D61705F736574436972636C6528652C6F29297D7D656C736520652E7573657270696E262628617065782E646562756728652E726567696F6E49642B22206D6F766520657869';
wwv_flow_api.g_varchar2_table(45) := '7374696E672070696E206F666620746865206D617022292C652E7573657270696E2E7365744D6170286E756C6C292C652E64697374636972636C65262628617065782E646562756728652E726567696F6E49642B22206D6F76652064697374636972636C';
wwv_flow_api.g_varchar2_table(46) := '65206F666620746865206D617022292C652E64697374636972636C652E7365744D6170286E756C6C2929297D66756E6374696F6E206A6B36347265706F72746D61705F6765744164647265737328652C612C74297B76617220723D7B6C61743A612C6C6E';
wwv_flow_api.g_varchar2_table(47) := '673A747D3B652E67656F636F6465722E67656F636F6465287B6C6F636174696F6E3A727D2C66756E6374696F6E28722C6F297B6F3D3D3D676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B3F725B315D3F28247328652E61646472';
wwv_flow_api.g_varchar2_table(48) := '6573734974656D2C725B305D2E666F726D61747465645F61646472657373292C617065782E646562756728652E726567696F6E49642B222061646472657373666F756E642027222B725B305D2E666F726D61747465645F616464726573732B222722292C';
wwv_flow_api.g_varchar2_table(49) := '617065782E6A5175657279282223222B652E726567696F6E4964292E74726967676572282261646472657373666F756E64222C7B6D61703A652E6D61702C6C61743A612C6C6E673A742C666F726D61747465645F616464726573733A725B305D2E666F72';
wwv_flow_api.g_varchar2_table(50) := '6D61747465645F616464726573737D29293A77696E646F772E616C65727428224E6F20726573756C747320666F756E6422293A77696E646F772E616C657274282247656F636F646572206661696C65642064756520746F3A20222B6F297D297D66756E63';
wwv_flow_api.g_varchar2_table(51) := '74696F6E206A6B36347265706F72746D61705F67656F6C6F636174652865297B6E6176696761746F722E67656F6C6F636174696F6E3F28617065782E646562756728652E726567696F6E49642B222067656F6C6F6361746522292C6E6176696761746F72';
wwv_flow_api.g_varchar2_table(52) := '2E67656F6C6F636174696F6E2E67657443757272656E74506F736974696F6E2866756E6374696F6E2861297B76617220743D7B6C61743A612E636F6F7264732E6C617469747564652C6C6E673A612E636F6F7264732E6C6F6E6769747564657D3B652E6D';
wwv_flow_api.g_varchar2_table(53) := '61702E70616E546F2874292C652E67656F6C6F636174655A6F6F6D2626652E6D61702E7365745A6F6F6D28652E67656F6C6F636174655A6F6F6D292C617065782E6A5175657279282223222B652E726567696F6E4964292E74726967676572282267656F';
wwv_flow_api.g_varchar2_table(54) := '6C6F63617465222C7B6D61703A652E6D61702C6C61743A742E6C61742C6C6E673A742E6C6E677D297D29293A617065782E646562756728652E726567696F6E49642B222062726F7773657220646F6573206E6F7420737570706F72742067656F6C6F6361';
wwv_flow_api.g_varchar2_table(55) := '74696F6E22297D66756E6374696F6E206A6B36347265706F72746D61705F636F6E766572744C61744C6E672865297B76617220613D652E73706C697428222C22293B72657475726E2032213D612E6C656E6774687C7C69734E614E28615B305D297C7C69';
wwv_flow_api.g_varchar2_table(56) := '734E614E28615B315D293F653A7B6C61743A7061727365466C6F617428615B305D292C6C6E673A7061727365466C6F617428615B315D297D7D66756E6374696F6E206A6B36347265706F72746D61705F646972656374696F6E737265737028652C612C74';
wwv_flow_api.g_varchar2_table(57) := '297B696628613D3D676F6F676C652E6D6170732E446972656374696F6E735374617475732E4F4B297B696628742E646972656374696F6E73446973706C61792E736574446972656374696F6E732865292C2222213D3D742E646972646973744974656D7C';
wwv_flow_api.g_varchar2_table(58) := '7C2222213D3D742E6469726475724974656D297B666F722876617220723D302C6F3D302C693D303B693C652E726F757465732E6C656E6774683B692B2B29666F7228766172206E3D303B6E3C652E726F757465735B695D2E6C6567732E6C656E6774683B';
wwv_flow_api.g_varchar2_table(59) := '6E2B2B297B76617220703D652E726F757465735B695D2E6C6567735B6E5D3B722B3D702E64697374616E63652E76616C75652C6F2B3D702E6475726174696F6E2E76616C75657D2222213D3D742E646972646973744974656D2626247328742E64697264';
wwv_flow_api.g_varchar2_table(60) := '6973744974656D2C72292C2222213D3D742E6469726475724974656D2626247328742E6469726475724974656D2C6F297D7D656C73652077696E646F772E616C6572742822446972656374696F6E732072657175657374206661696C6564206475652074';
wwv_flow_api.g_varchar2_table(61) := '6F20222B61297D66756E6374696F6E206A6B36347265706F72746D61705F646972656374696F6E732865297B617065782E646562756728652E726567696F6E49642B2220646972656374696F6E7320222B652E646972656374696F6E73293B7661722061';
wwv_flow_api.g_varchar2_table(62) := '2C742C722C6F3D652E646972656374696F6E732E696E6465784F6628222D524F55544522293B6966286F3C3029613D6A6B36347265706F72746D61705F636F6E766572744C61744C6E6728247628652E6F726967696E4974656D29292C743D6A6B363472';
wwv_flow_api.g_varchar2_table(63) := '65706F72746D61705F636F6E766572744C61744C6E6728247628652E646573744974656D29292C2222213D3D6126262222213D3D74262628723D652E646972656374696F6E732C652E646972656374696F6E73536572766963652E726F757465287B6F72';
wwv_flow_api.g_varchar2_table(64) := '6967696E3A612C64657374696E6174696F6E3A742C74726176656C4D6F64653A676F6F676C652E6D6170732E54726176656C4D6F64655B725D7D2C66756E6374696F6E28612C74297B6A6B36347265706F72746D61705F646972656374696F6E73726573';
wwv_flow_api.g_varchar2_table(65) := '7028612C742C65297D29293B656C73657B723D652E646972656374696F6E732E736C69636528302C6F292C617065782E646562756728652E726567696F6E49642B2220726F7574652076696120222B722B22207769746820222B652E6D6170646174612E';
wwv_flow_api.g_varchar2_table(66) := '6C656E6774682B2220776179706F696E747322293B666F722876617220693D5B5D2C6E3D303B6E3C652E6D6170646174612E6C656E6774683B6E2B2B29303D3D6E3F613D6E657720676F6F676C652E6D6170732E4C61744C6E6728652E6D617064617461';
wwv_flow_api.g_varchar2_table(67) := '5B6E5D2E6C61742C652E6D6170646174615B6E5D2E6C6E67293A6E3D3D652E6D6170646174612E6C656E6774682D313F743D6E657720676F6F676C652E6D6170732E4C61744C6E6728652E6D6170646174615B6E5D2E6C61742C652E6D6170646174615B';
wwv_flow_api.g_varchar2_table(68) := '6E5D2E6C6E67293A692E70757368287B6C6F636174696F6E3A6E657720676F6F676C652E6D6170732E4C61744C6E6728652E6D6170646174615B6E5D2E6C61742C652E6D6170646174615B6E5D2E6C6E67292C73746F706F7665723A21307D293B617065';
wwv_flow_api.g_varchar2_table(69) := '782E646562756728652E726567696F6E49642B22206F726967696E3D222B61292C617065782E646562756728652E726567696F6E49642B2220646573743D222B74292C617065782E646562756728652E726567696F6E49642B2220776179706F696E7473';
wwv_flow_api.g_varchar2_table(70) := '3A222B692E6C656E677468292C652E646972656374696F6E73536572766963652E726F757465287B6F726967696E3A612C64657374696E6174696F6E3A742C776179706F696E74733A692C6F7074696D697A65576179706F696E74733A652E6F7074696D';
wwv_flow_api.g_varchar2_table(71) := '697A65576179706F696E74732C74726176656C4D6F64653A676F6F676C652E6D6170732E54726176656C4D6F64655B725D7D2C66756E6374696F6E28612C74297B6A6B36347265706F72746D61705F646972656374696F6E737265737028612C742C6529';
wwv_flow_api.g_varchar2_table(72) := '7D297D7D66756E6374696F6E206A6B36347265706F72746D61705F696E69744D61702865297B617065782E646562756728652E726567696F6E49642B2220696E69744D617020222B652E6D617074797065293B76617220613D7B7A6F6F6D3A312C63656E';
wwv_flow_api.g_varchar2_table(73) := '7465723A6A6B36347265706F72746D61705F70617273654C61744C6E6728652E6C61746C6E67292C6D61705479706549643A652E6D6170747970657D3B696628652E6D61703D6E657720676F6F676C652E6D6170732E4D617028646F63756D656E742E67';
wwv_flow_api.g_varchar2_table(74) := '6574456C656D656E744279496428652E636F6E7461696E6572292C61292C652E6D61702E7365744F7074696F6E73287B647261676761626C653A652E70616E2C7A6F6F6D436F6E74726F6C3A652E7A6F6F6D2C7363726F6C6C776865656C3A652E7A6F6F';
wwv_flow_api.g_varchar2_table(75) := '6D2C64697361626C65446F75626C65436C69636B5A6F6F6D3A21652E7A6F6F6D2C6765737475726548616E646C696E673A652E6765737475726548616E646C696E677D292C652E6D61707374796C652626652E6D61702E7365744F7074696F6E73287B73';
wwv_flow_api.g_varchar2_table(76) := '74796C65733A652E6D61707374796C657D292C652E6D61702E666974426F756E6473286E657720676F6F676C652E6D6170732E4C61744C6E67426F756E647328652E736F757468776573742C652E6E6F7274686561737429292C2222213D3D652E73796E';
wwv_flow_api.g_varchar2_table(77) := '634974656D297B76617220743D247628652E73796E634974656D293B6E756C6C213D3D74262628652E7573657270696E3D6E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A652E6D61702C706F736974696F6E3A6A6B36347265706F';
wwv_flow_api.g_varchar2_table(78) := '72746D61705F70617273654C61744C6E672874292C69636F6E3A652E69636F6E7D292C6A6B36347265706F72746D61705F736574436972636C6528652C706F7329292C24282223222B652E73796E634974656D292E6368616E67652866756E6374696F6E';
wwv_flow_api.g_varchar2_table(79) := '28297B76617220613D746869732E76616C75653B6966286E756C6C213D612626612E696E6465784F6628222C22293E2D31297B76617220743D612E73706C697428222C22293B617065782E646562756728652E726567696F6E49642B22206974656D2063';
wwv_flow_api.g_varchar2_table(80) := '68616E67656420222B745B305D2B2220222B745B315D292C6A6B36347265706F72746D61705F7573657250696E28652C745B305D2C745B315D297D7D297D6966282222213D652E646973744974656D262624282223222B652E646973744974656D292E63';
wwv_flow_api.g_varchar2_table(81) := '68616E67652866756E6374696F6E28297B696628746869732E76616C7565297B76617220613D3165332A7061727365466C6F617428746869732E76616C7565293B652E64697374636972636C652E6765745261646975732829213D3D6126262861706578';
wwv_flow_api.g_varchar2_table(82) := '2E646562756728652E726567696F6E49642B2220646973746974656D206368616E67656420222B61292C652E64697374636972636C652E736574526164697573286129297D656C736520652E64697374636972636C65262628617065782E646562756728';
wwv_flow_api.g_varchar2_table(83) := '652E726567696F6E49642B2220646973746974656D20636C656172656422292C652E64697374636972636C652E7365744D6170286E756C6C29297D292C652E6578706563744461746126266A6B36347265706F72746D61705F72657050696E732865292C';
wwv_flow_api.g_varchar2_table(84) := '2222213D3D652E616464726573734974656D262628652E67656F636F6465723D6E657720676F6F676C652E6D6170732E47656F636F646572292C652E646972656374696F6E73262628652E646972656374696F6E73446973706C61793D6E657720676F6F';
wwv_flow_api.g_varchar2_table(85) := '676C652E6D6170732E446972656374696F6E7352656E64657265722C652E646972656374696F6E73536572766963653D6E657720676F6F676C652E6D6170732E446972656374696F6E73536572766963652C652E646972656374696F6E73446973706C61';
wwv_flow_api.g_varchar2_table(86) := '792E7365744D617028652E6D6170292C6A6B36347265706F72746D61705F646972656374696F6E732865292C652E646972656374696F6E732E696E6465784F6628222D524F55544522293C3026262824282223222B652E6F726967696E4974656D292E63';
wwv_flow_api.g_varchar2_table(87) := '68616E67652866756E6374696F6E28297B6A6B36347265706F72746D61705F646972656374696F6E732865297D292C24282223222B652E646573744974656D292E6368616E67652866756E6374696F6E28297B6A6B36347265706F72746D61705F646972';
wwv_flow_api.g_varchar2_table(88) := '656374696F6E732865297D2929292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228652E6D61702C22636C69636B222C66756E6374696F6E2861297B76617220743D612E6C61744C6E672E6C617428292C723D612E6C61744C';
wwv_flow_api.g_varchar2_table(89) := '6E672E6C6E6728293B617065782E646562756728652E726567696F6E49642B22206D617020636C69636B656420222B742B222C222B72292C22223D3D3D652E73796E634974656D262622223D3D3D652E616464726573734974656D7C7C6A6B3634726570';
wwv_flow_api.g_varchar2_table(90) := '6F72746D61705F7573657250696E28652C742C72292C2222213D3D652E73796E634974656D3F28247328652E73796E634974656D2C742B222C222B72292C6A6B36347265706F72746D61705F726566726573684D6170286529293A652E6D61726B65725A';
wwv_flow_api.g_varchar2_table(91) := '6F6F6D262628617065782E646562756728652E726567696F6E49642B222070616E2B7A6F6F6D22292C652E6D61702E70616E546F28612E6C61744C6E67292C652E6D61702E7365745A6F6F6D28652E6D61726B65725A6F6F6D29292C2222213D3D652E61';
wwv_flow_api.g_varchar2_table(92) := '6464726573734974656D26266A6B36347265706F72746D61705F6765744164647265737328652C742C72292C617065782E6A5175657279282223222B652E726567696F6E4964292E7472696767657228226D6170636C69636B222C7B6D61703A652E6D61';
wwv_flow_api.g_varchar2_table(93) := '702C6C61743A742C6C6E673A727D297D292C2222213D652E67656F636F64654974656D297B76617220723D6E657720676F6F676C652E6D6170732E47656F636F6465723B24282223222B652E67656F636F64654974656D292E6368616E67652866756E63';
wwv_flow_api.g_varchar2_table(94) := '74696F6E28297B6A6B36347265706F72746D61705F67656F636F646528652C72297D297D652E67656F6C6F6361746526266A6B36347265706F72746D61705F67656F6C6F636174652865292C617065782E646562756728652E726567696F6E49642B2220';
wwv_flow_api.g_varchar2_table(95) := '696E69744D61702066696E697368656422292C617065782E6A5175657279282223222B652E726567696F6E4964292E7472696767657228226D61706C6F61646564222C7B6D61703A652E6D61707D297D66756E6374696F6E206A6B36347265706F72746D';
wwv_flow_api.g_varchar2_table(96) := '61705F726566726573684D61702865297B617065782E646562756728652E726567696F6E49642B2220726566726573684D617022292C617065782E6A5175657279282223222B652E726567696F6E4964292E747269676765722822617065786265666F72';
wwv_flow_api.g_varchar2_table(97) := '657265667265736822292C617065782E7365727665722E706C7567696E28652E616A61784964656E7469666965722C7B706167654974656D733A652E616A61784974656D737D2C7B64617461547970653A226A736F6E222C737563636573733A66756E63';
wwv_flow_api.g_varchar2_table(98) := '74696F6E2861297B696628617065782E646562756728652E726567696F6E49642B2220737563636573732070446174613D222B612E736F757468776573742E6C61742B222C222B612E736F757468776573742E6C6E672B2220222B612E6E6F7274686561';
wwv_flow_api.g_varchar2_table(99) := '73742E6C61742B222C222B612E6E6F727468656173742E6C6E67292C652E6D61702E666974426F756E6473287B736F7574683A612E736F757468776573742E6C61742C776573743A612E736F757468776573742E6C6E672C6E6F7274683A612E6E6F7274';
wwv_flow_api.g_varchar2_table(100) := '68656173742E6C61742C656173743A612E6E6F727468656173742E6C6E677D292C652E69772626652E69772E636C6F736528292C652E72657070696E297B617065782E646562756728652E726567696F6E49642B222072656D6F766520616C6C20726570';
wwv_flow_api.g_varchar2_table(101) := '6F72742070696E7322293B666F722876617220743D303B743C652E72657070696E2E6C656E6774683B742B2B29652E72657070696E5B745D2E6D61726B65722E7365744D6170286E756C6C293B652E72657070696E2E64656C6574657D696628652E6369';
wwv_flow_api.g_varchar2_table(102) := '72636C6573297B617065782E646562756728652E726567696F6E49642B222072656D6F766520616C6C20636972636C657322293B666F7228743D303B743C652E636972636C65732E6C656E6774683B742B2B29652E636972636C65735B745D2E63697263';
wwv_flow_api.g_varchar2_table(103) := '2E7365744D6170286E756C6C293B652E636972636C65732E64656C6574657D696628617065782E646562756728652E726567696F6E49642B222070446174612E6D6170646174612E6C656E6774683D222B612E6D6170646174612E6C656E677468292C65';
wwv_flow_api.g_varchar2_table(104) := '2E6D6170646174613D612E6D6170646174612C652E6578706563744461746126266A6B36347265706F72746D61705F72657050696E732865292C2222213D3D652E73796E634974656D297B76617220723D247628652E73796E634974656D293B6966286E';
wwv_flow_api.g_varchar2_table(105) := '756C6C213D3D722626722E696E6465784F6628222C22293E2D31297B766172206F3D722E73706C697428222C22293B617065782E646562756728652E726567696F6E49642B2220696E69742066726F6D206974656D20222B6F5B305D2B2220222B6F5B31';
wwv_flow_api.g_varchar2_table(106) := '5D292C6A6B36347265706F72746D61705F7573657250696E28652C6F5B305D2C6F5B315D297D7D617065782E6A5175657279282223222B652E726567696F6E4964292E7472696767657228226170657861667465727265667265736822297D7D292C6170';
wwv_flow_api.g_varchar2_table(107) := '65782E646562756728652E726567696F6E49642B2220726566726573684D61702066696E697368656422297D';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(110684772994424757)
,p_plugin_id=>wwv_flow_api.id(695618245428938360)
,p_file_name=>'jk64reportmap.min.js'
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
