prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- ORACLE Application Express (APEX) export file
--
-- You should run the script connected to SQL*Plus as the Oracle user
-- APEX_180200 or as the owner (parsing schema) of the application.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_api.import_begin (
 p_version_yyyy_mm_dd=>'2018.05.24'
,p_release=>'18.2.0.00.12'
,p_default_workspace_id=>20749515040658038
,p_default_application_id=>15181
,p_default_owner=>'SAMPLE'
);
end;
/
prompt --application/shared_components/plugins/region_type/com_jk64_report_google_map_r1
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(184856223301707224)
,p_plugin_type=>'REGION TYPE'
,p_name=>'COM.JK64.REPORT_GOOGLE_MAP_R1'
,p_display_name=>'JK64 Report Google Map R1'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_javascript_file_urls=>'#PLUGIN_FILES#jk64reportmap_r1#MIN#.js'
,p_css_file_urls=>'#PLUGIN_FILES#jk64reportmap_r1#MIN#.css'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'-- jk64 ReportMap v1.5 Jan 2021',
'',
'-- format to use to convert a lat/lng number to string for passing via javascript',
'-- 0.0000001 is enough precision for the practical limit of commercial surveying, error up to +/- 11.132 mm at the equator',
'g_tochar_format                constant varchar2(100) := ''fm990.0999999'';',
'g_coord_precision              constant number := 6;',
'',
'-- if only one row is returned by the query, add this +/- to the latitude extents so it',
'-- shows the neighbourhood instead of zooming to the max',
'g_single_row_lat_margin        constant number := 0.005;',
'',
'g_visualisation_pins           constant varchar2(10) := ''PINS'';               -- default',
'g_visualisation_infolayer      constant varchar2(10) := ''INFOLAYER'';',
'g_visualisation_cluster        constant varchar2(10) := ''CLUSTER'';',
'g_visualisation_spiderfier     constant varchar2(10) := ''SPIDERFIER'';',
'g_visualisation_heatmap        constant varchar2(10) := ''HEATMAP'';',
'g_visualisation_directions     constant varchar2(10) := ''DIRECTIONS'';',
'g_visualisation_geojson        constant varchar2(10) := ''GEOJSON'';',
'',
'g_maptype_roadmap              constant varchar2(10) := ''ROADMAP'';            -- default',
'g_maptype_satellite	           constant varchar2(10) := ''SATELLITE'';',
'g_maptype_hybrid               constant varchar2(10) := ''HYBRID'';',
'g_maptype_terrain              constant varchar2(10) := ''TERRAIN'';',
'',
'g_travelmode_driving           constant varchar2(10) := ''DRIVING'';            -- default',
'g_travelmode_walking           constant varchar2(10) := ''WALKING'';',
'g_travelmode_bicycling         constant varchar2(10) := ''BICYCLING'';',
'g_travelmode_transit           constant varchar2(10) := ''TRANSIT'';',
'',
'g_option_pan_on_click          constant varchar2(30) := '':PAN_ON_CLICK:'';     -- default',
'g_option_draggable             constant varchar2(30) := '':DRAGGABLE:'';',
'g_option_pan_allowed           constant varchar2(30) := '':PAN_ALLOWED:'';      -- default',
'g_option_zoom_allowed          constant varchar2(30) := '':ZOOM_ALLOWED:'';     -- default',
'g_option_drag_drop_geojson     constant varchar2(30) := '':GEOJSON_DRAGDROP:'';',
'g_option_disable_autofit       constant varchar2(30) := '':DISABLEFITBOUNDS:'';',
'g_option_spinner               constant varchar2(30) := '':SPINNER:'';          -- default',
'g_option_suppress_ndf          constant varchar2(30) := '':SUPPRESS_NDF:'';',
'g_option_detailed_mouse        constant varchar2(30) := '':DETAILED_MOUSE_EVENTS:'';',
'',
'g_unitsystem_metric            constant varchar2(30) := ''METRIC'';             -- default',
'g_unitsystem_imperial          constant varchar2(30) := ''IMPERIAL'';',
'',
'subtype plugin_attr is varchar2(32767);',
'',
'function latlng_literal (lat in number, lng in number) return varchar2 is',
'begin',
'    return case when lat is not null and lng is not null then',
'        ''{''',
'        || apex_javascript.add_attribute(''lat'', round(lat,g_coord_precision))',
'        || apex_javascript.add_attribute(''lng'', round(lng,g_coord_precision)',
'           , false, false)',
'        || ''}''',
'        end;',
'end latlng_literal;',
'',
'function bounds_literal (south in number, west in number, north in number, east in number) return varchar2 is',
'begin',
'    return case when south is not null and west is not null and north is not null and east is not null then',
'        ''{''',
'        || apex_javascript.add_attribute(''south'', round(south, g_coord_precision))',
'        || apex_javascript.add_attribute(''west'',  round(west,  g_coord_precision))',
'        || apex_javascript.add_attribute(''north'', round(north, g_coord_precision))',
'        || apex_javascript.add_attribute(''east'',  round(east,  g_coord_precision)',
'           , false, false)',
'        || ''}''',
'        end;',
'end bounds_literal;',
'',
'procedure parse_latlng (p_val in varchar2, p_label in varchar2, p_lat out number, p_lng out number) is',
'    delim_pos number;',
'begin',
'    -- allow space as the delimiter; this should be used in locales which use comma (,) as decimal separator',
'    if instr(trim(p_val),'' '') > 0 then',
'        delim_pos := instr(p_val,'' '');',
'    else',
'        delim_pos := instr(p_val,'','');',
'    end if;',
'    p_lat := apex_plugin_util.get_attribute_as_number(substr(p_val,1,delim_pos-1), p_label || '' latitude'');',
'    p_lng := apex_plugin_util.get_attribute_as_number(substr(p_val,delim_pos+1),   p_label || '' longitude'');',
'end parse_latlng;',
'',
'function valid_zoom_level (p_attr in varchar2, p_label in varchar2) return number is',
'    n number;',
'begin',
'    n := apex_plugin_util.get_attribute_as_number(p_attr, p_label);',
'    -- note: this validation is not perfect because not all map areas necessarily have coverage at high zoom',
'    -- levels; the map will only zoom as far as it can',
'    if not n between 0 and 23 then',
'        raise_application_error(-20000, p_label || '': must be in range 0..23 ("'' || p_attr || ''")'');',
'    end if;',
'    return n;',
'end valid_zoom_level;',
'',
'function get_source (p_region in apex_plugin.t_region) return varchar2 is',
'    l_region                apex_application_page_regions%rowtype;',
'    l_visualisation         plugin_attr := p_region.attribute_02;',
'    l_result                varchar2(32767);',
'begin',
'    select r.*',
'    into   l_region',
'    from   apex_application_page_regions r',
'    where  r.region_id = p_region.id;',
'',
'    apex_debug.message(''source type: '' || l_region.query_type_code || '' ('' || l_region.location || '' - '' || l_region.query_type || '')'');',
'',
'    if l_region.query_type is not null then',
'',
'        if l_region.location_code = ''LOCAL'' then',
'',
'            l_result := case l_region.query_type_code',
'                        when ''SQL''',
'                            then p_region.source',
'                        when ''FUNC_BODY_RETURNING_SQL''',
'                            then apex_plugin_util.get_plsql_function_result(p_region.source)',
'                        when ''TABLE''',
'                            then ''select ''',
'                              || case l_visualisation',
'                                 when g_visualisation_heatmap then ''lat,lng,weight''',
'                                 when g_visualisation_geojson then ''geojson''',
'                                 else case when l_region.include_rowid_column = ''Yes''',
'                                      then ''lat,lng,name,rowid as id''',
'                                      else ''lat,lng,name,id''',
'                                      end',
'                                 end',
'                              || '' from ''',
'                              || case when l_region.table_owner is not null then ''"'' || l_region.table_owner || ''".'' end',
'                              || ''"'' || l_region.table_name || ''" "'' || l_region.table_name || ''"''',
'                              || case when l_region.where_clause is not null then '' where ('' || l_region.where_clause || '')'' end',
'                              || case when l_region.order_by_clause is not null then '' order by '' || l_region.order_by_clause end',
'                        end;',
'',
'            if l_result is null then',
'                raise_application_error(-20001, ''Unsupported region source ('' || l_region.query_type || ''); must be Table/View, SQL Query or PL/SQL Function Body returning SQL'');',
'            end if;',
'',
'        elsif l_region.location is not null then',
'            raise_application_error(-20001, ''Unsupported source location ('' || l_region.location || ''); must be Local Database'');',
'        end if;',
'',
'    end if;',
'',
'    apex_debug.message(''source: '' || l_result);',
'',
'    return l_result;',
'end get_source;',
'',
'procedure prn_mapdata (p_region in apex_plugin.t_region) is',
'',
'    l_source                varchar2(32767);',
'    l_flex                  varchar2(32767);',
'    l_buf                   varchar2(32767);',
'    l_column_list           apex_plugin_util.t_column_value_list2;',
'    l_visualisation         plugin_attr := p_region.attribute_02;',
'    l_escape_special_chars  plugin_attr := p_region.attribute_24;',
'    l_first_row             number;',
'    l_max_rows              number;',
'    l_geojson_clob          clob;',
'    l_chunk_size            number := 32767;',
'    l_rows_emitted          number := 0;',
'',
'    function varchar2_field (attr_no in number, i in number) return varchar2 is',
'        r varchar2(4000);',
'    begin',
'        if l_column_list.exists(attr_no) then',
'            -- whatever data type was in the original source, get it as a string',
'            r := sys.htf.escape_sc(',
'                apex_plugin_util.get_value_as_varchar2 (',
'                    p_data_type => l_column_list(attr_no).data_type,',
'                    p_value     => l_column_list(attr_no).value_list(i)',
'                    ));',
'        end if;',
'        return r;',
'    end varchar2_field;',
'',
'    function number_field (attr_no in number, i in number) return number is',
'        r number;',
'    begin',
'        if l_column_list(attr_no).data_type = apex_plugin_util.c_data_type_number then',
'            r := l_column_list(attr_no).value_list(i).number_value;',
'        else',
'            r := to_number(varchar2_field(attr_no, i));',
'        end if;',
'        return r;',
'    exception',
'        when value_error then',
'            raise_application_error(-20000, ''Unable to convert data to number ['' || varchar2_field(attr_no, i) || '']'');',
'    end number_field;',
'',
'    -- return a latitude or longitude as a number formatted as a string suitable for embedding in json',
'    function lat_or_lng_field (attr_no in number, i in number) return varchar2 is',
'        r number;',
'    begin',
'        if l_column_list(attr_no).data_type = apex_plugin_util.c_data_type_number then',
'            r := l_column_list(attr_no).value_list(i).number_value;',
'        else',
'            r := to_number(varchar2_field(attr_no, i));',
'        end if;',
'        return nvl(to_char(r, g_tochar_format),''null'');',
'    exception',
'        when value_error then',
'            raise_application_error(-20000, ''Unable to convert data to ''',
'                || case attr_no when 1 then ''latitude'' when 2 then ''longitude'' else ''lat/lng'' end',
'                || '' ['' || varchar2_field(attr_no, i) || '']'');',
'    end lat_or_lng_field;',
'',
'    function flex_field (attr_no in number, i in number, offset in number) return varchar2 is',
'      d varchar2(4000);',
'    begin',
'        if l_column_list.exists(attr_no+offset) then',
'            d := apex_plugin_util.get_value_as_varchar2 (',
'                p_data_type => l_column_list(attr_no+offset).data_type,',
'                p_value     => l_column_list(attr_no+offset).value_list(i)',
'                );',
'            if l_escape_special_chars=''Y'' then',
'                d := sys.htf.escape_sc(d);',
'            end if;',
'        end if;',
'        return apex_javascript.add_attribute(''a''||attr_no,d);',
'    end flex_field;',
'',
'begin',
'    apex_debug.message(''reportmap x01 (first row): '' || apex_application.g_x01);',
'    apex_debug.message(''reportmap x02 (max rows): '' || apex_application.g_x02);',
'',
'    l_first_row := to_number(apex_application.g_x01);',
'    l_max_rows := to_number(apex_application.g_x02);',
'',
'    l_source := get_source(p_region);',
'',
'    if l_source is not null then',
'',
'        case',
'        when l_visualisation = g_visualisation_heatmap then',
'',
'            l_column_list := apex_plugin_util.get_data2',
'                (p_sql_statement  => l_source',
'                ,p_min_columns    => 3',
'                ,p_max_columns    => 3',
'                ,p_component_name => p_region.name',
'                ,p_max_rows       => l_max_rows);',
'',
'            for i in 1 .. l_column_list(1).value_list.count loop',
'',
'                -- minimise size of data to be sent by encoding it as an array of arrays',
'                l_buf := ''['' || lat_or_lng_field(1,i)',
'                      || '','' || lat_or_lng_field(2,i)',
'                      || '','' || greatest( nvl( round( number_field(3,i) ), 1), 1)',
'                      || '']'';',
'',
'                if i < 8 /*don''t send the whole dataset to debug log*/ then',
'                    apex_debug.message(''#'' || i || '': '' || l_buf);',
'                end if;',
'',
'                if i>1 then',
'                    sys.htp.prn('','');',
'                end if;',
'',
'                sys.htp.prn(l_buf);',
'',
'                l_rows_emitted := l_rows_emitted + 1;',
'',
'            end loop;',
'',
'        when l_visualisation = g_visualisation_geojson then',
'',
'            l_column_list := apex_plugin_util.get_data2',
'                (p_sql_statement  => l_source',
'                ,p_min_columns    => 1',
'                ,p_max_columns    => 12',
'                ,p_component_name => p_region.name',
'                ,p_first_row      => l_first_row',
'                ,p_max_rows       => l_max_rows',
'                );',
'',
'            for i in 1 .. l_column_list(1).value_list.count loop',
'',
'                if i>1 then',
'                    sys.htp.prn('','');',
'                end if;',
'',
'                sys.htp.prn(''{"geojson":'');',
'',
'                if l_column_list(1).data_type = apex_plugin_util.c_data_type_clob then',
'',
'                    l_geojson_clob := l_column_list(1).value_list(i).clob_value;',
'',
'                    -- send the clob down in chunks',
'',
'                    for j in 0 .. floor(length(l_geojson_clob)/l_chunk_size) loop',
'',
'                        l_buf := substr(l_geojson_clob, j * l_chunk_size + 1, l_chunk_size);',
'',
'                        if i < 8 and j = 0 /*don''t send the whole dataset to debug log*/ then',
'                            apex_debug.message(''#'' || i || '': '' || substr(l_buf,1,1000));',
'                        end if;',
'',
'                        sys.htp.prn(l_buf);',
'',
'                    end loop;',
'',
'                else',
'',
'                    l_buf := varchar2_field(1,i);',
'',
'                    if i < 8 /*don''t send the whole dataset to debug log*/ then',
'                        apex_debug.message(''#'' || i || '': '' || substr(l_buf,1,1000));',
'                    end if;',
'',
'                    sys.htp.prn(l_buf);',
'',
'                end if;',
'',
'                -- get flex fields, if any',
'                l_flex := null;',
'                for attr_no in 1..10 loop',
'                    l_flex := l_flex || flex_field(attr_no, i, offset => 3);',
'                end loop;',
'',
'                l_buf := '',''',
'                      || apex_javascript.add_attribute(''n'',varchar2_field(2,i)) /*name*/',
'                      || apex_javascript.add_attribute(''d'',varchar2_field(3,i)) /*id*/',
'                      || case when l_flex is not null then',
'                           ''"f":{'' || rtrim(l_flex,'','') || ''}''',
'                         end;',
'',
'                l_buf := rtrim(l_buf, '','');',
'',
'                sys.htp.prn(l_buf || ''}'');',
'',
'                l_rows_emitted := l_rows_emitted + 1;',
'',
'            end loop;',
'',
'        else',
'            -- "pin" type visualisations',
'',
'            l_column_list := apex_plugin_util.get_data2',
'                (p_sql_statement  => l_source',
'                ,p_min_columns    => 4',
'                ,p_max_columns    => 17',
'                ,p_component_name => p_region.name',
'                ,p_first_row      => l_first_row',
'                ,p_max_rows       => l_max_rows);',
'',
'            for i in 1..l_column_list(1).value_list.count loop',
'',
'                -- get flex fields, if any',
'                l_flex := null;',
'                for attr_no in 1..10 loop',
'                    l_flex := l_flex || flex_field(attr_no, i, offset => 7);',
'                end loop;',
'',
'                l_buf := ''"x":'' || lat_or_lng_field(1,i) || '','' /*lat*/',
'                      || ''"y":'' || lat_or_lng_field(2,i) || '','' /*lng*/',
'                      || apex_javascript.add_attribute(''n'',varchar2_field(3,i)) /*name*/',
'                      || apex_javascript.add_attribute(''d'',varchar2_field(4,i)) /*id*/',
'                      || apex_javascript.add_attribute(''i'',varchar2_field(5,i)) /*info*/',
'                      || apex_javascript.add_attribute(''c'',varchar2_field(6,i)) /*icon*/',
'                      || apex_javascript.add_attribute(''l'',substr(varchar2_field(7,i),1,1)) /*label*/',
'                      || case when l_flex is not null then',
'                           ''"f":{'' || rtrim(l_flex,'','') || ''}''',
'                         end;',
'',
'                l_buf := ''{'' || rtrim(l_buf,'','') || ''}'';',
'',
'                if i < 8 /*don''t send the whole dataset to debug log*/ then',
'                    apex_debug.message(''#'' || i || '': '' || substr(l_buf,1,1000));',
'                end if;',
'',
'                if i>1 then',
'                    sys.htp.prn('','');',
'                end if;',
'',
'                sys.htp.prn(l_buf);',
'',
'                l_rows_emitted := l_rows_emitted + 1;',
'',
'            end loop;',
'',
'        end case;',
'',
'    end if;',
'',
'exception',
'    when others then',
'        apex_debug.error(sqlerrm);',
'        apex_debug.message(dbms_utility.format_error_stack);',
'        apex_debug.message(dbms_utility.format_call_stack);',
'        sys.htp.p(case when l_rows_emitted>0 then '','' end',
'            || ''{"error":'' || apex_escape.js_literal(sqlerrm,''"'') || ''}'');',
'end prn_mapdata;',
'',
'function render',
'    (p_region in apex_plugin.t_region',
'    ,p_plugin in apex_plugin.t_plugin',
'    ,p_is_printer_friendly in boolean',
'    ) return apex_plugin.t_region_render_result is',
'',
'    l_result                       apex_plugin.t_region_render_result;',
'',
'    -- Component settings',
'    l_api_key                      plugin_attr := p_plugin.attribute_01;',
'    l_no_address_results_msg       plugin_attr := p_plugin.attribute_02;',
'    l_directions_not_found_msg     plugin_attr := p_plugin.attribute_03;',
'    l_directions_zero_results_msg  plugin_attr := p_plugin.attribute_04;',
'    l_min_zoom                     number;      --attribute_05',
'    l_max_zoom                     number;      --attribute_06',
'    l_max_rows                     number;      --attribute_07',
'    l_unit_system                  plugin_attr := p_plugin.attribute_08;',
'    l_plugin_resource_path         plugin_attr := p_plugin.attribute_09;',
'',
'    -- Plugin attributes',
'    l_map_height                   plugin_attr := p_region.attribute_01;',
'    l_visualisation                plugin_attr := p_region.attribute_02;',
'    l_click_zoom_level             number;      --attribute_03',
'    l_options                      plugin_attr := p_region.attribute_04;',
'    l_initial_zoom_level           number;      --attribute_05',
'    l_initial_center               plugin_attr := p_region.attribute_06;',
'    l_rows_per_batch               number;      --attribute_07',
'    l_language                     plugin_attr := p_region.attribute_08;',
'    l_region                       plugin_attr := p_region.attribute_09;',
'    l_restrict_country             plugin_attr := p_region.attribute_10;',
'    l_mapstyle                     plugin_attr := p_region.attribute_11;',
'    l_heatmap_dissipating          plugin_attr := p_region.attribute_12;',
'    l_heatmap_opacity              number;      --attribute_13',
'    l_heatmap_radius               number;      --attribute_14',
'    l_travel_mode                  plugin_attr := p_region.attribute_15;',
'    l_drawing_modes                plugin_attr := p_region.attribute_16;',
'    l_optimizewaypoints            plugin_attr := p_region.attribute_21;',
'    l_maptype                      plugin_attr := p_region.attribute_22;',
'    l_gesture_handling             plugin_attr := p_region.attribute_25;',
'',
'    l_source                       varchar2(32767);',
'    l_region_id                    varchar2(100);',
'    l_lat                          number;',
'    l_lng                          number;',
'    l_opt                          varchar2(32767);',
'    l_js_options                   varchar2(1000);',
'    l_dragdrop_geojson             boolean;',
'    l_init_js_code                 plugin_attr;',
'',
'begin',
'    if apex_application.g_debug then',
'        apex_plugin_util.debug_region',
'            (p_plugin => p_plugin',
'            ,p_region => p_region',
'            ,p_is_printer_friendly => p_is_printer_friendly);',
'    end if;',
'',
'    if l_api_key is null or instr(l_api_key,''('') > 0 then',
'      raise_application_error(-20000, ''Google Maps API Key is required (set in Component Settings)'');',
'    end if;',
'',
'    l_region_id := case',
'                   when p_region.static_id is not null',
'                   then p_region.static_id',
'                   else ''R''||p_region.id',
'                   end;',
'    apex_debug.message(''map region: '' || l_region_id);',
'',
'    l_source := get_source(p_region);',
'    l_init_js_code := p_region.init_javascript_code;',
'',
'    -- Component settings',
'    l_min_zoom           := valid_zoom_level(p_plugin.attribute_05, ''Min. Zoom'');',
'    l_max_zoom           := valid_zoom_level(p_plugin.attribute_06, ''Max. Zoom'');',
'    l_max_rows           := apex_plugin_util.get_attribute_as_number(p_plugin.attribute_07, ''Maximum Records'');',
'',
'    -- Plugin attributes',
'    l_click_zoom_level   := valid_zoom_level(p_region.attribute_03, ''Zoom Level on Click'');',
'    l_initial_zoom_level := valid_zoom_level(p_region.attribute_05, ''Initial Zoom Level'');',
'    l_heatmap_opacity    := apex_plugin_util.get_attribute_as_number(p_region.attribute_13, ''Heatmap Opacity'');',
'    l_heatmap_radius     := apex_plugin_util.get_attribute_as_number(p_region.attribute_14, ''Heatmap Radius'');',
'    l_dragdrop_geojson   := instr('':''||l_options||'':'',g_option_drag_drop_geojson)>0;',
'',
'    if l_initial_center is not null then',
'        parse_latlng(l_initial_center, p_label=>''Initial Map Center'', p_lat=>l_lat, p_lng=>l_lng);',
'    end if;',
'',
'    if l_visualisation not in (g_visualisation_heatmap, g_visualisation_directions) then',
'        l_rows_per_batch := apex_plugin_util.get_attribute_as_number(p_region.attribute_07, ''Rows per Batch'');',
'    end if;',
'',
'    if l_drawing_modes is not null then',
'        -- convert colon-delimited list "marker:polygon:polyline:rectangle:circle"',
'        -- to a javascript array "''marker'',''polygon'',''polyline'',''rectangle'',''circle''"',
'        l_drawing_modes := '''''''' || replace(l_drawing_modes,'':'','''''','''''') || '''''''';',
'    end if;',
'',
'    if l_visualisation = g_visualisation_heatmap then',
'',
'        l_js_options := l_js_options || ''&libraries=visualization'';',
'',
'    elsif l_drawing_modes is not null then',
'',
'        l_js_options := l_js_options || ''&libraries=drawing'';',
'',
'    end if;',
'',
'    if l_language is not null then',
'        l_js_options := l_js_options || ''&language='' || l_language;',
'    end if;',
'',
'    if l_region is not null then',
'        l_js_options := l_js_options || ''&region='' || l_region;',
'    end if;',
'',
'    apex_javascript.add_library',
'        (p_name           => ''js?key='' || l_api_key || l_js_options',
'        ,p_directory      => ''https://maps.googleapis.com/maps/api/''',
'        ,p_skip_extension => true',
'        ,p_key            => ''https://maps.googleapis.com/maps/api/js'' -- don''t load multiple google maps APIs on same page',
'        );',
'',
'    if l_visualisation = g_visualisation_cluster then',
'',
'        -- MarkerClustererPlus for Google Maps V3',
'        apex_javascript.add_library',
'            (p_name      => ''markerclusterer.min''',
'            ,p_directory => p_plugin.file_prefix);',
'',
'    elsif l_visualisation = g_visualisation_spiderfier then',
'',
'        -- OverlappingMarkerSpiderfier',
'        apex_javascript.add_library',
'            (p_name      => ''oms.min''',
'            ,p_directory => p_plugin.file_prefix);',
'',
'    end if;',
'',
'    -- use nullif to convert default values to null; this can reduce the footprint of the generated code',
'    l_opt := ''{''',
'      || apex_javascript.add_attribute(''regionId'', l_region_id)',
'      || apex_javascript.add_attribute(''expectData'', nullif(l_source is not null,true))',
'      || apex_javascript.add_attribute(''maximumRows'', l_max_rows)',
'      || apex_javascript.add_attribute(''rowsPerBatch'', l_rows_per_batch)',
'      || apex_javascript.add_attribute(''visualisation'', lower(nullif(l_visualisation,g_visualisation_pins)))',
'      || apex_javascript.add_attribute(''mapType'', lower(nullif(l_maptype,g_maptype_roadmap)))',
'      || apex_javascript.add_attribute(''minZoom'', nullif(l_min_zoom,1))',
'      || apex_javascript.add_attribute(''maxZoom'', l_max_zoom)',
'      || apex_javascript.add_attribute(''initialZoom'', nullif(l_initial_zoom_level,2))',
'      || case when l_lat!=0 or l_lng!=0 then',
'            ''"initialCenter":'' || latlng_literal(l_lat,l_lng) || '',''',
'         end',
'      || apex_javascript.add_attribute(''clickZoomLevel'', l_click_zoom_level)',
'      || apex_javascript.add_attribute(''isDraggable'', nullif(instr('':''||l_options||'':'',g_option_draggable)>0,false))',
'      || case when l_visualisation = g_visualisation_heatmap then',
'            apex_javascript.add_attribute(''heatmapDissipating'', nullif(l_heatmap_dissipating=''Y'',false))',
'         || apex_javascript.add_attribute(''heatmapOpacity'', nullif(l_heatmap_opacity,0.6))',
'         || apex_javascript.add_attribute(''heatmapRadius'', nullif(l_heatmap_radius,5))',
'         end',
'      || apex_javascript.add_attribute(''panOnClick'', nullif(instr('':''||l_options||'':'',g_option_pan_on_click)>0,true))',
'      || apex_javascript.add_attribute(''restrictCountry'', l_restrict_country)',
'      || case when l_mapstyle is not null then',
'         ''"mapStyle":'' || l_mapstyle || '',''',
'         end',
'      || case when l_visualisation = g_visualisation_directions then',
'            apex_javascript.add_attribute(''travelMode'', nullif(l_travel_mode,g_travelmode_driving))',
'         || apex_javascript.add_attribute(''optimizeWaypoints'', nullif(l_optimizewaypoints=''Y'',false))',
'         end',
'      || apex_javascript.add_attribute(''unitSystem'', nullif(l_unit_system,g_unitsystem_metric))',
'      || apex_javascript.add_attribute(''allowZoom'', nullif(instr('':''||l_options||'':'',g_option_zoom_allowed)>0,true))',
'      || apex_javascript.add_attribute(''allowPan'', nullif(instr('':''||l_options||'':'',g_option_pan_allowed)>0,true))',
'      || apex_javascript.add_attribute(''gestureHandling'', nullif(l_gesture_handling,''auto''))',
'      || case when l_init_js_code is not null then',
'         ''"initFn":function(){''',
'            || chr(13)',
'            || l_init_js_code',
'            || chr(13) /* this handles the case if developer ends their javascript with a line comment // */',
'            || ''},''',
'         end',
'      || case when l_drawing_modes is not null then',
'         ''"drawingModes":['' || l_drawing_modes || ''],''',
'         end',
'      || apex_javascript.add_attribute(''dragDropGeoJSON'', nullif(l_dragdrop_geojson,false))',
'	  || apex_javascript.add_attribute(''autoFitBounds'', nullif(instr('':''||l_options||'':'',g_option_disable_autofit)=0,true)) --reverse meaning of option',
'      || apex_javascript.add_attribute(''showSpinner'', nullif(instr('':''||l_options||'':'',g_option_spinner)>0,true))',
'      || apex_javascript.add_attribute(''detailedMouseEvents'', nullif(instr('':''||l_options||'':'',g_option_detailed_mouse)>0,false))',
'      || apex_javascript.add_attribute(''noDataMessage'', case when instr('':''||l_options||'':'',g_option_suppress_ndf)=0 -- set to null if message suppressed',
'                                                        then p_region.no_data_found_message',
'                                                        end)',
'      || apex_javascript.add_attribute(''noAddressResults'', l_no_address_results_msg)',
'      || apex_javascript.add_attribute(''directionsNotFound'', l_directions_not_found_msg)',
'      || apex_javascript.add_attribute(''directionsZeroResults'', l_directions_zero_results_msg)',
'      || apex_javascript.add_attribute(''ajaxIdentifier'', apex_plugin.get_ajax_identifier)',
'      || apex_javascript.add_attribute(''ajaxItems'', apex_plugin_util.page_item_names_to_jquery(p_region.ajax_items_to_submit))',
'      || apex_javascript.add_attribute(''pluginResourcePath'', l_plugin_resource_path)',
'      || apex_javascript.add_attribute(''pluginFilePrefix'', p_plugin.file_prefix',
'         ,false,false)',
'      || ''}'';',
'',
'    apex_debug.message(''map options: '' || l_opt);',
'',
'    apex_javascript.add_onload_code(p_code =>',
'      ''$("#map_'' || l_region_id || ''").reportmap('' || l_opt || '');''',
'      );',
'',
'    sys.htp.p(''<div id="map_'' || l_region_id || ''" class="reportmap" style="min-height:'' || l_map_height || ''px"></div>'');',
'',
'    if l_dragdrop_geojson then',
'        sys.htp.p(''<div id="drop_'' || l_region_id || ''" class="reportmap-drop-container"><div class="reportmap-drop-silhouette"></div></div>'');',
'    end if;',
'',
'    return l_result;',
'exception',
'    when others then',
'        apex_debug.error(sqlerrm);',
'        apex_debug.message(dbms_utility.format_error_stack);',
'        apex_debug.message(dbms_utility.format_call_stack);',
'        raise;',
'end render;',
'',
'function ajax',
'    (p_region in apex_plugin.t_region',
'    ,p_plugin in apex_plugin.t_plugin',
'    ) return apex_plugin.t_region_ajax_result is',
'',
'    l_result apex_plugin.t_region_ajax_result;',
'',
'begin',
'    if apex_application.g_debug then',
'        apex_plugin_util.debug_region',
'            (p_plugin => p_plugin',
'            ,p_region => p_region);',
'    end if;',
'    apex_debug.message(''ajax'');',
'',
'    sys.owa_util.mime_header(''text/plain'', false);',
'    sys.htp.p(''Cache-Control: no-cache'');',
'    sys.htp.p(''Pragma: no-cache'');',
'    sys.owa_util.http_header_close;',
'',
'    sys.htp.p(''{"mapdata":['');',
'',
'    prn_mapdata(p_region => p_region);',
'',
'    sys.htp.p('']}'');',
'',
'    apex_debug.message(''ajax finished'');',
'    return l_result;',
'exception',
'    when others then',
'        apex_debug.error(sqlerrm);',
'        apex_debug.message(dbms_utility.format_error_stack);',
'        apex_debug.message(dbms_utility.format_call_stack);',
'        raise;',
'end ajax;'))
,p_api_version=>1
,p_render_function=>'render'
,p_ajax_function=>'ajax'
,p_standard_attributes=>'SOURCE_LOCATION:AJAX_ITEMS_TO_SUBMIT:NO_DATA_FOUND_MESSAGE:INIT_JAVASCRIPT_CODE'
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>false
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>',
'This plugin renders a Google Map, showing a number of pins based on a query you supply with Latitude, Longitude, Name (pin hovertext), id, and Info.',
'</p><p>',
'Refer to the wiki for documentation and examples: <strong>https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki</strong>.',
'</p><p>',
'Please raise any bugs or enhancements on GitHub: <strong>https://github.com/jeffreykemp/jk64-plugin-reportmap/issues</strong>.',
'</p>'))
,p_version_identifier=>'1.5'
,p_about_url=>'https://jeffreykemp.github.io/jk64-plugin-reportmap/'
,p_plugin_comment=>wwv_flow_string.join(wwv_flow_t_varchar2(
'Copyright (c) 2016 - 2021 Jeffrey Kemp',
'Released under the MIT licence: http://opensource.org/licenses/mit-license'))
,p_files_version=>870
);
end;
/
begin
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196436287268656050)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Google API Key'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_display_length=>60
,p_is_translatable=>false
,p_help_text=>'A Google Maps API Key is required. Refer: https://developers.google.com/maps/documentation/javascript/get-api-key#get-an-api-key'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196436714805656049)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'No Address Results message'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>true
,p_help_text=>'Leave blank for default: "Address not found"'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196437117407656049)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'Directions Not Found message'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>true
,p_help_text=>'Leave blank for default: "At least one of the origin, destination, or waypoints could not be geocoded."'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196437540290656049)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'Directions Zero Results message'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>true
,p_help_text=>'Leave blank for default: "No route could be found between the origin and destination."'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196437906399656048)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_prompt=>'Min. Zoom'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_default_value=>'1'
,p_unit=>'0 .. 23'
,p_is_translatable=>false
,p_help_text=>'Minimum Zoom Level - must be 0 to 23. Set to 0 to allow zooming out to entire world map.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196438321239656048)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'Max. Zoom'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_unit=>'0 .. 23'
,p_is_translatable=>false
,p_help_text=>'Maximum Zoom Level - 0 to 23. Set to blank to allow zooming in to show maximum detail.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196438684803656048)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Maximum Records'
,p_attribute_type=>'INTEGER'
,p_is_required=>true
,p_default_value=>'10000'
,p_unit=>'rows'
,p_is_translatable=>false
,p_help_text=>'Maximum number of records to fetch from the SQL Query. Note that datasets that are very large (e.g. 10,000+) may perform poorly on the client''s machine. The Heatmap option is leaner and can support larger datasets.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(84401048685750914)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>8
,p_display_sequence=>80
,p_prompt=>'Directions Unit System'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'METRIC'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Unit system to use when using the Directions service.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(84411716230750227)
,p_plugin_attribute_id=>wwv_flow_api.id(84401048685750914)
,p_display_sequence=>10
,p_display_value=>'Metric'
,p_return_value=>'METRIC'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(84412130136749429)
,p_plugin_attribute_id=>wwv_flow_api.id(84401048685750914)
,p_display_sequence=>20
,p_display_value=>'Imperial'
,p_return_value=>'IMPERIAL'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(85316358723190558)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>9
,p_display_sequence=>90
,p_prompt=>'Plugin URL Path'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>false
,p_examples=>wwv_flow_string.join(wwv_flow_t_varchar2(
'https://xyzmyprefixxyz.adb.eu-frankfurt-1.oraclecloudapps.com/ords',
'https://apex.oracle.com/pls/apex'))
,p_help_text=>'Normally, this may be left blank (i.e. auto-detect). Set this to override the automatic detection of the window origin+path for downloading plugin image icons. Don''t include a trailing slash (/). The plugin will append the plugin path prefix and the '
||'file name at run time.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196439145228656047)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Min. Map Height'
,p_attribute_type=>'NUMBER'
,p_is_required=>true
,p_show_in_wizard=>false
,p_default_value=>'400'
,p_unit=>'pixels'
,p_is_translatable=>false
,p_help_text=>'Desired height (in pixels) of the map region. Note: the width will adjust according to the available area of the containing window.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196439489513656047)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'Visualisation'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'PINS'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Select how to represent the data retrieved from the query on the map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196439877093656047)
,p_plugin_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_display_sequence=>10
,p_display_value=>'Pins'
,p_return_value=>'PINS'
,p_help_text=>'Show a pin for every data point. The pin may optionally use an alternative icon, or show a single-character label. Each pin can also have an information window showing text (most HTML allowed) when the user selects the pin.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(84901479713322267)
,p_plugin_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_display_sequence=>15
,p_display_value=>'Info Layer'
,p_return_value=>'INFOLAYER'
,p_help_text=>'Show the Info (as HTML rendered within a div) directly on the map instead of pins.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196440429855656047)
,p_plugin_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_display_sequence=>20
,p_display_value=>'Marker Clustering'
,p_return_value=>'CLUSTER'
,p_help_text=>'Show a pin for every data point. Cluster pins where many pins are very close together. When the user clicks a cluster, the map zooms in to show the pins.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(108971242187567164)
,p_plugin_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_display_sequence=>25
,p_display_value=>'Spiderfier'
,p_return_value=>'SPIDERFIER'
,p_help_text=>'Show a pin for every data point. If the user clicks on a group of pins that are close to each other or overlapping, the spiderfier shifts the pins out in a spiral with lines pointing to where they were.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196440921401656046)
,p_plugin_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_display_sequence=>30
,p_display_value=>'Heatmap'
,p_return_value=>'HEATMAP'
,p_help_text=>'Show the data as a heat map. Suitable for larger volume of data points. Note: a different query structure is required (i.e. no pin labels or icons are used).'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196441374095656046)
,p_plugin_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_display_sequence=>40
,p_display_value=>'Directions'
,p_return_value=>'DIRECTIONS'
,p_help_text=>'Show a route using the data points from the query. Directions can be shown for Driving, Walking, Bicycling or Public Transport. A pin will also be shown at each point.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(109740019544017974)
,p_plugin_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_display_sequence=>50
,p_display_value=>'GeoJson'
,p_return_value=>'GEOJSON'
,p_help_text=>'Render one or more features represented in GeoJson format. Query only requires one column, the GeoJson document (VARCHAR2 or CLOB).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196441895836656046)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'Zoom Level on Click'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'13'
,p_unit=>'0 .. 23'
,p_is_translatable=>false
,p_help_text=>'When the user clicks on a map marker, or adds a new marker, zoom the map to this level. Set to blank to not zoom on click.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196442290547656045)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'Options'
,p_attribute_type=>'CHECKBOXES'
,p_is_required=>false
,p_default_value=>'PAN_ON_CLICK:PAN_ALLOWED:ZOOM_ALLOWED:SPINNER'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196443113749656044)
,p_plugin_attribute_id=>wwv_flow_api.id(196442290547656045)
,p_display_sequence=>10
,p_display_value=>'Pan on click'
,p_return_value=>'PAN_ON_CLICK'
,p_help_text=>'When the user clicks a point on the map, pan the map to that location.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196443628094656044)
,p_plugin_attribute_id=>wwv_flow_api.id(196442290547656045)
,p_display_sequence=>20
,p_display_value=>'Draggable'
,p_return_value=>'DRAGGABLE'
,p_help_text=>'Allow user to move pins to new locations on the map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196444071794656044)
,p_plugin_attribute_id=>wwv_flow_api.id(196442290547656045)
,p_display_sequence=>30
,p_display_value=>'Pan allowed'
,p_return_value=>'PAN_ALLOWED'
,p_help_text=>'Allow user to pan the map. If unset, the map will be fixed at one location.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196444600766656043)
,p_plugin_attribute_id=>wwv_flow_api.id(196442290547656045)
,p_display_sequence=>40
,p_display_value=>'Zoom Allowed'
,p_return_value=>'ZOOM_ALLOWED'
,p_help_text=>'Allow user to zoom in or out. If unset, the map scale will remain constant.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196442580346656044)
,p_plugin_attribute_id=>wwv_flow_api.id(196442290547656045)
,p_display_sequence=>50
,p_display_value=>'Drag & Drop GeoJSON'
,p_return_value=>'GEOJSON_DRAGDROP'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'Allow user to drag and drop a GeoJSON file onto the map. The features in the GeoJSON will be rendered into a data layer on the map.',
'<p>',
'If you also enable Drawing Mode, the user will also be able to edit these features, and add and remove features.',
'<p>',
'You can get the resulting set of features as a new GeoJSON document using code like this:',
'<pre>',
'var map = $("#map_mymap").reportmap("instance").map;',
'map.data.toGeoJson(function(o){',
'    $s("P1_GEOJSON", JSON.stringify(o));',
'});',
'</pre>'))
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(200131438751839886)
,p_plugin_attribute_id=>wwv_flow_api.id(196442290547656045)
,p_display_sequence=>60
,p_display_value=>'Disable Auto Fit Bounds'
,p_return_value=>'DISABLEFITBOUNDS'
,p_help_text=>'Whenever the map data is refreshed, the map will be automatically panned/zoomed to fit the bounds of all the pins. Set this option to stop the map from automatically fitting the bounds.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(109171389675559380)
,p_plugin_attribute_id=>wwv_flow_api.id(196442290547656045)
,p_display_sequence=>70
,p_display_value=>'Show Spinner'
,p_return_value=>'SPINNER'
,p_help_text=>'Show APEX "waiting" spinner while data is loading or refreshing.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(84465918073993084)
,p_plugin_attribute_id=>wwv_flow_api.id(196442290547656045)
,p_display_sequence=>80
,p_display_value=>'Suppress No Data Found message'
,p_return_value=>'SUPPRESS_NDF'
,p_help_text=>'If set, the "No Data Found" message will not be displayed if the query returns no rows.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(84489826204378828)
,p_plugin_attribute_id=>wwv_flow_api.id(196442290547656045)
,p_display_sequence=>90
,p_display_value=>'Detailed Mouse Events'
,p_return_value=>'DETAILED_MOUSE_EVENTS'
,p_help_text=>'Add a listener for detailed mouse events (contextmenu, drag, dragend, dragstart, mouse over, mouse move, mouse out, double click). Required if you need a dynamic action to respond to any of these events. Note: a listener for the click event is always'
||' added.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196445149876656043)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_prompt=>'Initial Zoom Level'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_show_in_wizard=>false
,p_unit=>'0 .. 23'
,p_is_translatable=>false
,p_help_text=>'Initial zoom level (0..23) if no data is loaded. Default is 2. If data is loaded, this attribute has no effect.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196445490654656043)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'Initial Map Center'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_show_in_wizard=>false
,p_unit=>'lat,long'
,p_is_translatable=>false
,p_help_text=>'Set the latitude and longitude as a pair of numbers to be used to position the map on page load, if no data is loaded. Default is 0,0. If data is loaded, this attribute has no effect. NOTE: the numeric values must use the dot (.) as the decimal separ'
||'ator, and comma (,) as the delimiter between the lat and lng values.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(109255450317697664)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Rows Per Batch'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_is_common=>false
,p_show_in_wizard=>false
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'NOT_IN_LIST'
,p_depending_on_expression=>'HEATMAP,DIRECTIONS'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'Load the pins in multiple ajax calls, with this number of rows per batch. Setting this attribute increases the overall time required to load all the data, but allows the map to start showing some pins earlier, making it more user-friendly.',
'<p>',
'As each batch is received, the map will expand the bounds (pan & zoom) to show the new pins.',
'<p>',
'Leave blank to cause all the pin data to be loaded in a single ajax call. The map will wait until the entire data set is downloaded before rendering the pins. This is the fastest way, although for large data sets the user might get impatient.',
'<p>',
'This attribute is not applicable for the Heatmap visualisation, which needs to load all the data before it can be rendered visually.'))
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(108874223599896900)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>8
,p_display_sequence=>80
,p_prompt=>'Language'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_common=>false
,p_show_in_wizard=>false
,p_max_length=>50
,p_is_translatable=>false
,p_examples=>'ja'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'By default, the map uses the user''s preferred language setting as specified in the browser, when displaying textual information such as the names for controls, copyright notices, driving directions and labels on maps. In most cases, it''s preferable t'
||'o respect the browser setting and leave this attribute blank.',
'<p>',
'To override the user''s preferred language, set the language code; e.g. "ja" for Japanese. The list of supported languages may be found here: https://developers.google.com/maps/faq#languagesupport',
'<p>',
'Substitution syntax allowed, e.g. <code>&P1_LANGUAGE.</code> Note that the page must be reloaded if the language is changed.'))
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(108914812821029628)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>9
,p_display_sequence=>90
,p_prompt=>'Region'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_show_in_wizard=>false
,p_max_length=>50
,p_is_translatable=>false
,p_examples=>'uk'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'When you load the map it applies a default bias for application behavior towards the United States. If you want to serve different map tiles or bias the application (such as biasing geocoding results towards the region), you can override this default'
||' behavior by setting the Region attribute.',
'<p>',
'The region parameter accepts Unicode region subtag identifiers [http://www.unicode.org/reports/tr35/#Unicode_Language_and_Locale_Identifiers] which (generally) have a one-to-one mapping to country code Top-Level Domains (ccTLDs). Most Unicode region '
||'identifiers are identical to ISO 3166-1 codes, with some notable exceptions. For example, Great Britain''s ccTLD is "uk" (corresponding to the domain .co.uk) while its region identifier is "GB." Try this demo [https://developers.google.com/maps/docume'
||'ntation/javascript/demos/localization] to experiment with the changes on the map when you update the region parameter.',
'<p>',
'As the developer of an application using Google Maps it is your responsibility to ensure that your application complies with local laws by ensuring that the correct region localization is applied for the country in which the application is hosted.'))
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196445950624656043)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>10
,p_display_sequence=>100
,p_prompt=>'Restrict to Country code'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_show_in_wizard=>false
,p_display_length=>10
,p_max_length=>40
,p_is_translatable=>false
,p_text_case=>'UPPER'
,p_examples=>'AU'
,p_help_text=>'Leave blank to allow geocoding to find any place on earth. Set to 2-character country code (see https://developers.google.com/public-data/docs/canonical/countries_csv for valid values) to restrict geocoder to that country. You can set this to a subst'
||'ition variable (e.g. &P1_COUNTRY.) but note that this will only apply if the page is refreshed.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196446699220656042)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>11
,p_display_sequence=>110
,p_prompt=>'Map Style'
,p_attribute_type=>'TEXTAREA'
,p_is_required=>false
,p_show_in_wizard=>false
,p_is_translatable=>false
,p_examples=>wwv_flow_string.join(wwv_flow_t_varchar2(
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
 p_id=>wwv_flow_api.id(196447157678656042)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>12
,p_display_sequence=>120
,p_prompt=>'Dissipating'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'N'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'HEATMAP'
,p_help_text=>'Specifies whether heatmaps dissipate on zoom. Yes means the radius of influence of a data point is specified by the radius option only. When dissipating is disabled, the radius option is interpreted as a radius at zoom level 0.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196447532331656041)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>13
,p_display_sequence=>130
,p_prompt=>'Opacity'
,p_attribute_type=>'NUMBER'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'0.6'
,p_display_length=>5
,p_unit=>'0 .. 1'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'HEATMAP'
,p_help_text=>'The opacity of the heatmap, expressed as a number between 0 and 1.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196446346569656042)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>14
,p_display_sequence=>140
,p_prompt=>'Radius'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'5'
,p_display_length=>5
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'HEATMAP'
,p_help_text=>'The radius of influence for each data point, in pixels.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196447930018656041)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>15
,p_display_sequence=>150
,p_prompt=>'Travel Mode'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>false
,p_show_in_wizard=>false
,p_default_value=>'DRIVING'
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'DIRECTIONS'
,p_lov_type=>'STATIC'
,p_help_text=>'Type of travel directions to calculate. The locations can be simple - between two locations according to two items on the page - or via the route indicated by waypoints from the report query. Google API Key required.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196448294114656041)
,p_plugin_attribute_id=>wwv_flow_api.id(196447930018656041)
,p_display_sequence=>10
,p_display_value=>'Driving'
,p_return_value=>'DRIVING'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196448835920656041)
,p_plugin_attribute_id=>wwv_flow_api.id(196447930018656041)
,p_display_sequence=>20
,p_display_value=>'Walking'
,p_return_value=>'WALKING'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196449342646656041)
,p_plugin_attribute_id=>wwv_flow_api.id(196447930018656041)
,p_display_sequence=>30
,p_display_value=>'Bicycling'
,p_return_value=>'BICYCLING'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196449789393656040)
,p_plugin_attribute_id=>wwv_flow_api.id(196447930018656041)
,p_display_sequence=>40
,p_display_value=>'Transit'
,p_return_value=>'TRANSIT'
,p_help_text=>'Public transport'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196450287347656040)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>16
,p_display_sequence=>160
,p_prompt=>'Drawing Mode'
,p_attribute_type=>'CHECKBOXES'
,p_is_required=>false
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'Select one or more Drawing Modes to enable the Google Maps Drawing Library. A button will be added to the top of the map for each shape, allowing the user to select a shape to draw.',
'<p>',
'The shapes the user has drawn can then be retrieved from the plugin as a geoJson document, which can later be re-loaded onto the map.',
'<p>',
'Note: the shapes drawn, loaded or retrieved are independent of the data that might be shown in the map derived from the report query.'))
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196452191151656039)
,p_plugin_attribute_id=>wwv_flow_api.id(196450287347656040)
,p_display_sequence=>10
,p_display_value=>'marker'
,p_return_value=>'marker'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196452687921656039)
,p_plugin_attribute_id=>wwv_flow_api.id(196450287347656040)
,p_display_sequence=>20
,p_display_value=>'polygon'
,p_return_value=>'polygon'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196450676999656040)
,p_plugin_attribute_id=>wwv_flow_api.id(196450287347656040)
,p_display_sequence=>30
,p_display_value=>'polyline'
,p_return_value=>'polyline'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196451183693656040)
,p_plugin_attribute_id=>wwv_flow_api.id(196450287347656040)
,p_display_sequence=>40
,p_display_value=>'rectangle'
,p_return_value=>'rectangle'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196451718127656040)
,p_plugin_attribute_id=>wwv_flow_api.id(196450287347656040)
,p_display_sequence=>50
,p_display_value=>'circle'
,p_return_value=>'circle'
,p_help_text=>'Note: when drawn, a circle is currently rendered as just a point (at the circle''s center) with a "radius" property (not shown).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196453188171656039)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
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
,p_depending_on_attribute_id=>wwv_flow_api.id(196439489513656047)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'DIRECTIONS'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'If set to true, the Directions service will attempt to re-order the supplied intermediate waypoints to minimize overall cost of the route.',
'',
'Note: the first and last points supplied by the report query are always used as the starting and ending points for the journey.'))
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196453590558656039)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>22
,p_display_sequence=>220
,p_prompt=>'Default Map Type'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'ROADMAP'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Default map type to show on page load. The user may change the map type if they wish to show a different type.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196453995577656038)
,p_plugin_attribute_id=>wwv_flow_api.id(196453590558656039)
,p_display_sequence=>10
,p_display_value=>'Roadmap'
,p_return_value=>'ROADMAP'
,p_help_text=>'(default) This map type displays a normal street map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196454497090656038)
,p_plugin_attribute_id=>wwv_flow_api.id(196453590558656039)
,p_display_sequence=>20
,p_display_value=>'Satellite'
,p_return_value=>'SATELLITE'
,p_help_text=>'This map type displays satellite images.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196454997803656038)
,p_plugin_attribute_id=>wwv_flow_api.id(196453590558656039)
,p_display_sequence=>30
,p_display_value=>'Hybrid'
,p_return_value=>'HYBRID'
,p_help_text=>'This map type displays a transparent layer of major streets on satellite images.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196455480379656038)
,p_plugin_attribute_id=>wwv_flow_api.id(196453590558656039)
,p_display_sequence=>40
,p_display_value=>'Terrain'
,p_return_value=>'TERRAIN'
,p_help_text=>'This map type displays maps with physical features such as terrain and vegetation.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196455986894656037)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>24
,p_display_sequence=>240
,p_prompt=>'Escape special characters'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_is_common=>false
,p_show_in_wizard=>false
,p_default_value=>'Y'
,p_is_translatable=>false
,p_help_text=>'This is relevant only to the "flex fields", if supplied in the SQL Query. By default any special characters (such as < and >) will be escaped prior to sending to the client, in order to protect against XSS attacks and to allow the original data to be'
||' rendered exactly as entered. To disable this escaping, set this attribute to No.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(196456404623656037)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
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
 p_id=>wwv_flow_api.id(196456787299656037)
,p_plugin_attribute_id=>wwv_flow_api.id(196456404623656037)
,p_display_sequence=>10
,p_display_value=>'cooperative'
,p_return_value=>'cooperative'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
unistr('Scroll events and one-finger touch gestures scroll the page, and do not zoom or pan the map. Two-finger touch gestures pan and zoom the map. Scroll events with a ctrl key or \2318 key pressed zoom the map.'),
'In this mode the map cooperates with the page.'))
);
end;
/
begin
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196457329148656036)
,p_plugin_attribute_id=>wwv_flow_api.id(196456404623656037)
,p_display_sequence=>20
,p_display_value=>'greedy'
,p_return_value=>'greedy'
,p_help_text=>'All touch gestures and scroll events pan or zoom the map.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196457793257656036)
,p_plugin_attribute_id=>wwv_flow_api.id(196456404623656037)
,p_display_sequence=>30
,p_display_value=>'none'
,p_return_value=>'none'
,p_help_text=>'The map cannot be panned or zoomed by user gestures.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(196458301536656036)
,p_plugin_attribute_id=>wwv_flow_api.id(196456404623656037)
,p_display_sequence=>40
,p_display_value=>'auto'
,p_return_value=>'auto'
,p_help_text=>'(default) Gesture handling is either cooperative or greedy, depending on whether the page is scrollable.'
);
wwv_flow_api.create_plugin_std_attribute(
 p_id=>wwv_flow_api.id(196467103371656022)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'INIT_JAVASCRIPT_CODE'
,p_is_required=>false
);
wwv_flow_api.create_plugin_std_attribute(
 p_id=>wwv_flow_api.id(196467566534656022)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'SOURCE_LOCATION'
,p_is_required=>false
,p_depending_on_has_to_exist=>true
,p_examples=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<em>Pin visualisations (including Route Map, Marker Clustering, Spiderfier):</em>',
'<pre>SELECT lat, lng, name, id FROM mydata;</pre>',
'<p>',
'<em>Show a popup info window when a pin is clicked:</em>',
'<p>',
'<pre>SELECT lat, lng, name, id, info FROM mydata;</pre>',
'<p>',
'<em>Show each pin with a selected icon:</em>',
'<p>',
'<pre>SELECT lat, lng, name, id, info, icon FROM mydata;</pre>',
'<p>',
'<em>Show marker labels on the pins:</em>',
'<p>',
'<pre>',
'SELECT lat, lng, name, id, '''' AS info, '''' AS icon, label as lbl FROM mydata;',
'</pre>',
'<p>',
'<em>Heatmap visualisation:</em>',
'<p>',
'<pre>',
'SELECT lat, lng, count(*) as weight FROM mydata GROUP BY lat, lng;',
'</pre>',
'<p>',
'<em>GeoJson visualisation:</em>',
'<p>',
'<pre>',
'SELECT geojson FROM mydata;',
'</pre>',
'<p>',
'Refer also to <b>https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki/SQL-Query-Examples</b>'))
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'Optional.',
'<p>',
'If source data is used, Source Type must be Table / View, SQL Query or PL/SQL Function Body returning SQL.',
'<p>',
'If Source Type is <b>Table / View</b>, it must provide the columns required by the chosen Visualisation. They don''t need to appear in any particular order but do need to be named exactly as indicated below:',
'<ul><li>',
'For the Heatmap visualisation, the source must provide the columns LAT, LNG, and WEIGHT.',
'</li><li>',
'For the GeoJson visualisation, the source must provide the column GEOJSON.',
'</li><li>',
'For the other Pin-type visualisations, the source must provide the columns LAT, LNG, NAME, ID. If the source has no ID column, you may instead set <b>Include ROWID Column</b> to Yes to use ROWID as a unique identifier.',
'</li></ul>',
'Any other columns in the source table or view are ignored.',
'<p><p>',
'If Source Type is <b>SQL Query</b> or <b>PL/SQL Function returning SQL Query</b>, the query must provide the columns in the right order (refer to examples). The column names are not important, however.'))
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196474822729656016)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'addfeature'
,p_display_name=>'addFeature'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196471591708656018)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'addressfound'
,p_display_name=>'addressFound'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(109287348796009874)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'batchloaded'
,p_display_name=>'batchLoaded'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196472004540656018)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'directions'
,p_display_name=>'directions'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196472442551656018)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'geolocate'
,p_display_name=>'geolocate'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196474388657656017)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'loadedgeojson'
,p_display_name=>'loadedGeoJson'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84511184692316752)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapbounds_changed'
,p_display_name=>'mapBoundsChanged'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84511418818316749)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapcenter_changed'
,p_display_name=>'mapCenterChanged'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196472830908656018)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapclick'
,p_display_name=>'mapClick'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84515867219310062)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapcontextmenu'
,p_display_name=>'mapContextMenu'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84516176445310062)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapdblclick'
,p_display_name=>'mapDoubleClick'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84514615621316746)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapdrag'
,p_display_name=>'mapDrag'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84515010900316745)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapdragend'
,p_display_name=>'mapDragEnd'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84515453957316745)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapdragstart'
,p_display_name=>'mapDragStart'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84511853214316748)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapheading_changed'
,p_display_name=>'mapHeadingChanged'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84512221423316748)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapidle'
,p_display_name=>'mapIdle'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196473191036656017)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'maploaded'
,p_display_name=>'mapLoaded'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84512668064316748)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapmaptypeid_changed'
,p_display_name=>'mapTypeChanged'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84516555087310061)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapmousemove'
,p_display_name=>'mapMouseMove'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84516956128310061)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapmouseout'
,p_display_name=>'mapMouseOut'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84517306526310060)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapmouseover'
,p_display_name=>'mapMouseOver'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84513003731316747)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapprojection_changed'
,p_display_name=>'mapProjectionChanged'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(103533718560893040)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'maprefreshed'
,p_display_name=>'mapRefreshed'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84513459962316747)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'maptilesloaded'
,p_display_name=>'mapTilesLoaded'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84513841360316746)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'maptilt_changed'
,p_display_name=>'mapTiltChanged'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(84514260345316746)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mapzoom_changed'
,p_display_name=>'mapZoomChanged'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(151885973297333354)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'markeradded'
,p_display_name=>'markerAdded'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196473608565656017)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'markerclick'
,p_display_name=>'markerClick'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196473992057656017)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'markerdrag'
,p_display_name=>'markerDrag'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(110039195355770297)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mouseoutfeature'
,p_display_name=>'mouseoutFeature'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(110038801809770295)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'mouseoverfeature'
,p_display_name=>'mouseoverFeature'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196469986052656019)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'removefeature'
,p_display_name=>'removeFeature'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196470790652656019)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'selectfeature'
,p_display_name=>'selectFeature'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196470432588656019)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'setgeometry'
,p_display_name=>'setGeometry'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(109011021034813005)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'spiderfy'
,p_display_name=>'spiderfy'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(196471236990656018)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'unselectfeature'
,p_display_name=>'unselectFeature'
);
wwv_flow_api.create_plugin_event(
 p_id=>wwv_flow_api.id(109011340960814554)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_name=>'unspiderfy'
,p_display_name=>'unspiderfy'
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D4948445200000016000000280803000000CD1AFAD400000009704859730000001C0000001C000F01B98F0000012F504C5445000000B73830BB3C34B73C30B73830B73830DB4848B73C30BB3C30BB3C30B73C30BF3C38BB3C';
wwv_flow_api.g_varchar2_table(2) := '34BF4034D35454B73830BB3830DB5C48C74838BB3C30B73830CB5440BB3830B73C30BB3C30C34438BF3C34C33C30BB3C30C34C3CB73830C34038C74840C74030B73830B73C34B73830F760545C1410F7685CF76458F75C50F35048DF544CFB7064BB3C30';
wwv_flow_api.g_varchar2_table(3) := '681C18DF5C54B73830F76C60F75C54F34C44CB4C40CB4034FB7468C7443C80282493302CAB4038F3483CF34840A33C34DB4C40BB3830CF584CD7544CC34034D34840D34034CB4038F7584CF75448D75448E34438F7544CF75850F76058DB5044E74C40E3';
wwv_flow_api.g_varchar2_table(4) := '4C40E74840F35044E34840E74438D35048CB5448DB544CDB4C44DF443CCB5048D34C40D3483CDB4438CB4840CB3C34C73C30C33C34C33C30C34438C74038C3443CF43138D20000002574524E5300EF70B7FBE30AF79360D32480400EC7A31014FBDB1880';
wwv_flow_api.g_varchar2_table(5) := 'CBCB383C2C801CF32224249393D38BDEF3750000016D4944415478DAEDFD559AA3401486611C9C687BC7A38D63F1787C7C7C7CAC6DFF6BE850451E740BDFD57FDE4B8A0500EE8AA4089A2628F20ABCB22DAE6749BA2E593DAE953D6A3DD96B0FDCDA7F6F';
wwv_flow_api.g_varchar2_table(6) := 'EA582BCC7AE06BCD541C65F32FF4405FF2EC81C9473DD43D09705695C32C57CF20316CE3A4D54A72E730019486E7575314CD9F787FA3801024274B4459E81008A065B4E698E7E89069B0318F318F31DBC009B2D304F3041D0207490DAD8EE9A8D9418796';
wwv_flow_api.g_varchar2_table(7) := '04FED71B943612C59186F796878221B829CA71190580DC5B21D4F7DCE19B640CA513483132CE27A4B64AA0DF14FADE294E7DED4BE552F81DD20FCF7C6DD2EEA3B1970B4F1797ECF1318B17EA2B37F5A2E83D3DBF7FEEB6E77D7FC439F10EEB7BE2DCC740';
wwv_flow_api.g_varchar2_table(8) := '6E54D42DE95760990F1F0F7D62D80043B9DF3DD42F07156AB4C3742DC470F2A3DBFD73125620FBB3D93F32C2A5E574BA2C451898CF2F99A8C2E96E771AC389FF7789186ED87623868120E214282A969BCD58BEBEF6F613156A5DBB5535A3440000000049';
wwv_flow_api.g_varchar2_table(9) := '454E44AE426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(85389484048410250)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'images/spotlight-poi.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D4948445200000016000000280803000000CD1AFAD400000009704859730000001C0000001C000F01B98F000000B7504C544500000043731B3F731B43771B6B932343771B4F872343771B43771B43731B3F731B43771B4373';
wwv_flow_api.g_varchar2_table(2) := '1B477F1F538F2B47771F6B962B5B933747771F47771B43731B4B831F5F8B2B3F731B43731B43731B4B7F1F53872B4B831F43731B4B83233F731B6FBA336BB62F4B831F67A62F43771B4F871F83C7437BC33F77BF3B5793275FA62B5B9E2763A62B4F8323';
wwv_flow_api.g_varchar2_table(3) := '538F2387CB4773BF375F9E2F4F872363A22F5F9A2B578F27538B2783CB437FC7437FC73F7BC33B77BF376BBA338E7058F50000002074524E5300FCBAF00A73237B93CBEC83DC43145F0E10678FD43718E8E89E3F1F1F9323DC840826B600000125494441';
wwv_flow_api.g_varchar2_table(4) := '5478DAEDFD5792EA400C4051489D1CC964C23892C9F0DEA4FDAF6BDAC4B6E52DDC2FD7294A5D25B100B8D7958C237226BBF0AEDEC26BBC98CD16F1155BF5A72AFFDF7CFF68FECF57771DF58F7BA3637F94A9702EFF735D1CA1D9DACE0A6D2D80060F3E0B';
wwv_flow_api.g_varchar2_table(5) := '05BC01CDD31769DB04769E93CE0C78F04D0A38E082F20135D3320E7E4821423B3E90E236D84BCA3B1B3A49404A3A00CEBAA86B47EFA452FC799854B215B2659E77ECB6EF29C6A6C638BDDFC18B4C8EBCC7D1846FBCBAFE10CF630E93F0F51E0EDFA7B7D3';
wwv_flow_api.g_varchar2_table(6) := '27A7B6F18FA8BA9BDF5B2BB76A30C8E8CE91341584BB09752B57E418BC53C6A997571863C6382EB0DE5818DE76944FA67A8624AC123D431186DE66D5A30A83E56E50C2B528AA95B0C2B2D1009C97293056CA9349295BD6FBFB0FD3A44CF9FE9EE52F0000';
wwv_flow_api.g_varchar2_table(7) := '000049454E44AE426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(85389700870410249)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'images/spotlight-waypoint-a.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D4948445200000016000000280803000000CD1AFAD400000009704859730000001C0000001C000F01B98F00000123504C5445000000306CB7306CBB306CB74893DB3470BF306CB7306CBB306CBB3874C3306CBB306CB7346C';
wwv_flow_api.g_varchar2_table(2) := 'BB306CBB346CBB4880DB3870C7346CBB3068B73068B7306CBB4080CB5480D3306CB7306CBB306CB7306CBB346CB73074C33070C73C78C33874C33068B73068B73874BF4078C73068B7306CB75493EB3068B7589BF75C9FF710305C306CBB488FF33474CB';
wwv_flow_api.g_varchar2_table(3) := '548FDF183868407CCB64A3FB5497F74C8BDF407CD3448BF34C87D768A7FB5097F74C93F7244880408BF33464A3408BEF4087F33C87F33C78C73470C34C87CF4880CB4483DB4083DB3478D33874CB64A7FB60A3F7549BF74883D34893F74087E7488FF744';
wwv_flow_api.g_varchar2_table(4) := '8FF33C80DF3880E73880E33070C34087E34083E74083E33474C33070C73874C34C8BDB2C58932C54933C7CD3387CDB3C74C33874C774C6E0A60000002674524E5300F774B70A40D3EB802293E38060EB101064EBE39F180EE7CBCB978F2C242038DB9724';
wwv_flow_api.g_varchar2_table(5) := '24F3C7F31147BE0000016E4944415478DAEDFD55B2E3301445515C498670381C4ECCE170388F9A9B9B1BE63F8A8E25BB623B9EC2FE3A5AE52FC9030056169318423182B3702D5746C3BE321A29FD212AE76C6D0B437561A50E8536D35A78BE70340FD74C';
wwv_flow_api.g_varchar2_table(6) := 'E50AF367AE5E16B80BE3BF234FDF3140BC237959EAC421797CCE52CF67D59AC72490099B77034D1BDCB1FD838028A9667D8DD6A707490459A16BCB784B0F8A0C321DEA4FC6BF6C469262667F4D0F120261C2D6C0D401FB66224068AAB0B9D6B435FB4499';
wwv_flow_api.g_varchar2_table(7) := '86A0AE8F5FB024C91A63BD0E50BC1F7BBA2F5EEE84D7976E5DE9BC798564BA74F59BD0FB6E21C3A9066AB17788FC5B39FA1AB11E8D6B3C5CF5A1C1D98FC9CB86AD86CC5F9FBEF4F4CAEAA9E4F82312A9D76F689F520907033E19B413762A70F9CF6F2F7D';
wwv_flow_api.g_varchar2_table(8) := 'C9732E86406F76A917702B04D16E36DBA1A087A1FB6EB3F9D3F52AE0DE7EDFC3375CD10F07B972C3907EFF217DAB90797CCCF870F4DBC7A80F5765B9EAC3208A7E0A84F872B3E9CB01C785FC073A8A63026F9F3DC30000000049454E44AE426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(85390162914410236)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'images/spotlight-waypoint-blue.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2F2A0A204F7665726C617070696E674D61726B6572537069646572666965720A68747470733A2F2F6769746875622E636F6D2F6A61776A2F4F7665726C617070696E674D61726B6572537069646572666965720A436F7079726967687420286329203230';
wwv_flow_api.g_varchar2_table(2) := '3131202D20323031372047656F726765204D61634B6572726F6E0A52656C656173656420756E64657220746865204D4954206C6963656E63653A20687474703A2F2F6F70656E736F757263652E6F72672F6C6963656E7365732F6D69742D6C6963656E73';
wwv_flow_api.g_varchar2_table(3) := '650A4E6F74653A2054686520476F6F676C65204D61707320415049207633206D75737420626520696E636C75646564202A6265666F72652A207468697320636F64650A2A2F0A2866756E6374696F6E28297B766172206D2C742C772C792C752C7A3D7B7D';
wwv_flow_api.g_varchar2_table(4) := '2E6861734F776E50726F70657274792C413D5B5D2E736C6963653B746869732E4F7665726C617070696E674D61726B6572537069646572666965723D66756E6374696F6E28297B66756E6374696F6E207228612C64297B76617220622C662C653B746869';
wwv_flow_api.g_varchar2_table(5) := '732E6D61703D613B6E756C6C3D3D64262628643D7B7D293B6E756C6C3D3D746869732E636F6E7374727563746F722E4E262628746869732E636F6E7374727563746F722E4E3D21302C683D676F6F676C652E6D6170732C6C3D682E6576656E742C703D68';
wwv_flow_api.g_varchar2_table(6) := '2E4D61705479706549642C632E6B656570537069646572666965643D21312C632E69676E6F72654D6170436C69636B3D21312C632E6D61726B657273576F6E74486964653D21312C632E6D61726B657273576F6E744D6F76653D21312C632E6261736963';
wwv_flow_api.g_varchar2_table(7) := '466F726D61744576656E74733D21312C632E6E656172627944697374616E63653D32302C632E636972636C6553706972616C5377697463686F7665723D392C632E636972636C65466F6F7453657061726174696F6E3D32332C632E636972636C65537461';
wwv_flow_api.g_varchar2_table(8) := '7274416E676C653D782F31322C632E73706972616C466F6F7453657061726174696F6E3D32362C632E73706972616C4C656E67746853746172743D31312C632E73706972616C4C656E677468466163746F723D0A342C632E737069646572666965645A49';
wwv_flow_api.g_varchar2_table(9) := '6E6465783D682E4D61726B65722E4D41585F5A494E4445582B3245342C632E686967686C6967687465644C65675A496E6465783D682E4D61726B65722E4D41585F5A494E4445582B3145342C632E757375616C4C65675A496E6465783D682E4D61726B65';
wwv_flow_api.g_varchar2_table(10) := '722E4D41585F5A494E4445582B312C632E6C65675765696768743D312E352C632E6C6567436F6C6F72733D7B757375616C3A7B7D2C686967686C6967687465643A7B7D7D2C653D632E6C6567436F6C6F72732E757375616C2C663D632E6C6567436F6C6F';
wwv_flow_api.g_varchar2_table(11) := '72732E686967686C6967687465642C655B702E4859425249445D3D655B702E534154454C4C4954455D3D2223666666222C665B702E4859425249445D3D665B702E534154454C4C4954455D3D2223663030222C655B702E5445525241494E5D3D655B702E';
wwv_flow_api.g_varchar2_table(12) := '524F41444D41505D3D2223343434222C665B702E5445525241494E5D3D665B702E524F41444D41505D3D2223663030222C746869732E636F6E7374727563746F722E6A3D66756E6374696F6E2861297B72657475726E20746869732E7365744D61702861';
wwv_flow_api.g_varchar2_table(13) := '297D2C746869732E636F6E7374727563746F722E6A2E70726F746F747970653D6E657720682E4F7665726C6179566965772C746869732E636F6E7374727563746F722E6A2E70726F746F747970652E647261773D66756E6374696F6E28297B7D293B0A66';
wwv_flow_api.g_varchar2_table(14) := '6F72286220696E2064297A2E63616C6C28642C6229262628663D645B625D2C746869735B625D3D66293B746869732E673D6E657720746869732E636F6E7374727563746F722E6A28746869732E6D6170293B746869732E4328293B746869732E633D7B7D';
wwv_flow_api.g_varchar2_table(15) := '3B746869732E423D746869732E6C3D6E756C6C3B746869732E6164644C697374656E65722822636C69636B222C66756E6374696F6E28612C62297B72657475726E206C2E7472696767657228612C227370696465725F636C69636B222C62297D293B7468';
wwv_flow_api.g_varchar2_table(16) := '69732E6164644C697374656E65722822666F726D6174222C66756E6374696F6E28612C62297B72657475726E206C2E7472696767657228612C227370696465725F666F726D6174222C62297D293B746869732E69676E6F72654D6170436C69636B7C7C6C';
wwv_flow_api.g_varchar2_table(17) := '2E6164644C697374656E657228746869732E6D61702C22636C69636B222C66756E6374696F6E2861297B72657475726E2066756E6374696F6E28297B72657475726E20612E756E737069646572667928297D7D287468697329293B6C2E6164644C697374';
wwv_flow_api.g_varchar2_table(18) := '656E657228746869732E6D61702C226D61707479706569645F6368616E676564222C66756E6374696F6E2861297B72657475726E2066756E6374696F6E28297B72657475726E20612E756E737069646572667928297D7D287468697329293B6C2E616464';
wwv_flow_api.g_varchar2_table(19) := '4C697374656E657228746869732E6D61702C0A227A6F6F6D5F6368616E676564222C66756E6374696F6E2861297B72657475726E2066756E6374696F6E28297B612E756E737069646572667928293B69662821612E6261736963466F726D61744576656E';
wwv_flow_api.g_varchar2_table(20) := '74732972657475726E20612E6828297D7D287468697329297D766172206C2C682C6D2C762C702C632C742C782C753B633D722E70726F746F747970653B743D5B722C635D3B6D3D303B666F7228763D742E6C656E6774683B6D3C763B6D2B2B29753D745B';
wwv_flow_api.g_varchar2_table(21) := '6D5D2C752E56455253494F4E3D22312E302E33223B783D322A4D6174682E50493B683D6C3D703D6E756C6C3B722E6D61726B65725374617475733D7B535049444552464945443A2253504944455246494544222C535049444552464941424C453A225350';
wwv_flow_api.g_varchar2_table(22) := '49444552464941424C45222C554E535049444552464941424C453A22554E535049444552464941424C45222C554E535049444552464945443A22554E53504944455246494544227D3B632E433D66756E6374696F6E28297B746869732E613D5B5D3B7468';
wwv_flow_api.g_varchar2_table(23) := '69732E733D5B5D7D3B632E6164644D61726B65723D66756E6374696F6E28612C64297B612E7365744D617028746869732E6D6170293B72657475726E20746869732E747261636B4D61726B657228612C64297D3B632E747261636B4D61726B65723D6675';
wwv_flow_api.g_varchar2_table(24) := '6E6374696F6E28612C64297B76617220623B6966286E756C6C213D0A612E5F6F6D732972657475726E20746869733B612E5F6F6D733D21303B623D5B6C2E6164644C697374656E657228612C22636C69636B222C66756E6374696F6E2862297B72657475';
wwv_flow_api.g_varchar2_table(25) := '726E2066756E6374696F6E2864297B72657475726E20622E5628612C64297D7D287468697329295D3B746869732E6D61726B657273576F6E74486964657C7C622E70757368286C2E6164644C697374656E657228612C2276697369626C655F6368616E67';
wwv_flow_api.g_varchar2_table(26) := '6564222C66756E6374696F6E2862297B72657475726E2066756E6374696F6E28297B72657475726E20622E4428612C2131297D7D28746869732929293B746869732E6D61726B657273576F6E744D6F76657C7C622E70757368286C2E6164644C69737465';
wwv_flow_api.g_varchar2_table(27) := '6E657228612C22706F736974696F6E5F6368616E676564222C66756E6374696F6E2862297B72657475726E2066756E6374696F6E28297B72657475726E20622E4428612C2130297D7D28746869732929293B6E756C6C213D642626622E70757368286C2E';
wwv_flow_api.g_varchar2_table(28) := '6164644C697374656E657228612C227370696465725F636C69636B222C6429293B746869732E732E707573682862293B746869732E612E707573682861293B746869732E6261736963466F726D61744576656E74733F746869732E747269676765722822';
wwv_flow_api.g_varchar2_table(29) := '666F726D6174222C612C746869732E636F6E7374727563746F722E6D61726B65725374617475732E554E53504944455246494544293A0A28746869732E747269676765722822666F726D6174222C612C746869732E636F6E7374727563746F722E6D6172';
wwv_flow_api.g_varchar2_table(30) := '6B65725374617475732E554E535049444552464941424C45292C746869732E682829293B72657475726E20746869737D3B632E443D66756E6374696F6E28612C64297B69662821746869732E4A262621746869732E4B2972657475726E206E756C6C3D3D';
wwv_flow_api.g_varchar2_table(31) := '612E5F6F6D73446174617C7C21642626612E67657456697369626C6528297C7C746869732E756E737069646572667928643F613A6E756C6C292C746869732E6828297D3B632E6765744D61726B6572733D66756E6374696F6E28297B72657475726E2074';
wwv_flow_api.g_varchar2_table(32) := '6869732E612E736C6963652830297D3B632E72656D6F76654D61726B65723D66756E6374696F6E2861297B746869732E666F726765744D61726B65722861293B72657475726E20612E7365744D6170286E756C6C297D3B632E666F726765744D61726B65';
wwv_flow_api.g_varchar2_table(33) := '723D66756E6374696F6E2861297B76617220642C622C662C652C673B6E756C6C213D612E5F6F6D73446174612626746869732E756E737069646572667928293B643D746869732E4128746869732E612C61293B696628303E642972657475726E20746869';
wwv_flow_api.g_varchar2_table(34) := '733B673D746869732E732E73706C69636528642C31295B305D3B623D303B666F7228663D672E6C656E6774683B623C663B622B2B29653D675B625D2C0A6C2E72656D6F76654C697374656E65722865293B64656C65746520612E5F6F6D733B746869732E';
wwv_flow_api.g_varchar2_table(35) := '612E73706C69636528642C31293B746869732E6828293B72657475726E20746869737D3B632E72656D6F7665416C6C4D61726B6572733D632E636C6561724D61726B6572733D66756E6374696F6E28297B76617220612C642C622C663B663D746869732E';
wwv_flow_api.g_varchar2_table(36) := '6765744D61726B65727328293B746869732E666F72676574416C6C4D61726B65727328293B613D303B666F7228643D662E6C656E6774683B613C643B612B2B29623D665B615D2C622E7365744D6170286E756C6C293B72657475726E20746869737D3B63';
wwv_flow_api.g_varchar2_table(37) := '2E666F72676574416C6C4D61726B6572733D66756E6374696F6E28297B76617220612C642C622C662C652C672C632C713B746869732E756E737069646572667928293B713D746869732E613B613D643D303B666F7228623D712E6C656E6774683B643C62';
wwv_flow_api.g_varchar2_table(38) := '3B613D2B2B64297B673D715B615D3B653D746869732E735B615D3B633D303B666F7228613D652E6C656E6774683B633C613B632B2B29663D655B635D2C6C2E72656D6F76654C697374656E65722866293B64656C65746520672E5F6F6D737D746869732E';
wwv_flow_api.g_varchar2_table(39) := '4328293B72657475726E20746869737D3B632E6164644C697374656E65723D66756E6374696F6E28612C64297B76617220623B286E756C6C213D28623D746869732E63295B615D3F0A625B615D3A625B615D3D5B5D292E707573682864293B7265747572';
wwv_flow_api.g_varchar2_table(40) := '6E20746869737D3B632E72656D6F76654C697374656E65723D66756E6374696F6E28612C64297B76617220623B623D746869732E4128746869732E635B615D2C64293B303E627C7C746869732E635B615D2E73706C69636528622C31293B72657475726E';
wwv_flow_api.g_varchar2_table(41) := '20746869737D3B632E636C6561724C697374656E6572733D66756E6374696F6E2861297B746869732E635B615D3D5B5D3B72657475726E20746869737D3B632E747269676765723D66756E6374696F6E28297B76617220612C642C622C662C652C673B64';
wwv_flow_api.g_varchar2_table(42) := '3D617267756D656E74735B305D3B613D323C3D617267756D656E74732E6C656E6774683F412E63616C6C28617267756D656E74732C31293A5B5D3B643D6E756C6C213D28623D746869732E635B645D293F623A5B5D3B673D5B5D3B663D303B666F722865';
wwv_flow_api.g_varchar2_table(43) := '3D642E6C656E6774683B663C653B662B2B29623D645B665D2C672E7075736828622E6170706C79286E756C6C2C6129293B72657475726E20677D3B632E4C3D66756E6374696F6E28612C64297B76617220622C662C652C672C633B673D746869732E6369';
wwv_flow_api.g_varchar2_table(44) := '72636C65466F6F7453657061726174696F6E2A28322B61292F783B663D782F613B633D5B5D3B666F7228623D653D303B303C3D613F653C613A653E613B623D303C3D613F2B2B653A2D2D6529623D0A746869732E636972636C655374617274416E676C65';
wwv_flow_api.g_varchar2_table(45) := '2B622A662C632E70757368286E657720682E506F696E7428642E782B672A4D6174682E636F732862292C642E792B672A4D6174682E73696E28622929293B72657475726E20637D3B632E4D3D66756E6374696F6E28612C64297B76617220622C662C652C';
wwv_flow_api.g_varchar2_table(46) := '632C6B3B633D746869732E73706972616C4C656E67746853746172743B623D303B6B3D5B5D3B666F7228663D653D303B303C3D613F653C613A653E613B663D303C3D613F2B2B653A2D2D6529622B3D746869732E73706972616C466F6F74536570617261';
wwv_flow_api.g_varchar2_table(47) := '74696F6E2F632B35452D342A662C663D6E657720682E506F696E7428642E782B632A4D6174682E636F732862292C642E792B632A4D6174682E73696E286229292C632B3D782A746869732E73706972616C4C656E677468466163746F722F622C6B2E7075';
wwv_flow_api.g_varchar2_table(48) := '73682866293B72657475726E206B7D3B632E563D66756E6374696F6E28612C64297B76617220622C662C652C632C6B2C712C6E2C6C2C683B28713D6E756C6C213D612E5F6F6D7344617461292626746869732E6B656570537069646572666965647C7C74';
wwv_flow_api.g_varchar2_table(49) := '6869732E756E737069646572667928293B696628717C7C746869732E6D61702E6765745374726565745669657728292E67657456697369626C6528297C7C22476F6F676C654561727468415049223D3D3D0A746869732E6D61702E6765744D6170547970';
wwv_flow_api.g_varchar2_table(50) := '65496428292972657475726E20746869732E747269676765722822636C69636B222C612C64293B713D5B5D3B6E3D5B5D3B623D746869732E6E656172627944697374616E63653B6C3D622A623B6B3D746869732E6628612E706F736974696F6E293B683D';
wwv_flow_api.g_varchar2_table(51) := '746869732E613B623D303B666F7228663D682E6C656E6774683B623C663B622B2B29653D685B625D2C6E756C6C213D652E6D61702626652E67657456697369626C652829262628633D746869732E6628652E706F736974696F6E292C746869732E692863';
wwv_flow_api.g_varchar2_table(52) := '2C6B293C6C3F712E70757368287B523A652C473A637D293A6E2E70757368286529293B72657475726E20313D3D3D712E6C656E6774683F746869732E747269676765722822636C69636B222C612C64293A746869732E5728712C6E297D3B632E6D61726B';
wwv_flow_api.g_varchar2_table(53) := '6572734E6561724D61726B65723D66756E6374696F6E28612C64297B76617220622C662C652C632C6B2C712C6E2C6C2C682C6D3B6E756C6C3D3D64262628643D2131293B6966286E756C6C3D3D746869732E672E67657450726F6A656374696F6E282929';
wwv_flow_api.g_varchar2_table(54) := '7468726F77224D757374207761697420666F72202769646C6527206576656E74206F6E206D6170206265666F72652063616C6C696E67206D61726B6572734E6561724D61726B6572223B623D746869732E6E656172627944697374616E63653B0A6E3D62';
wwv_flow_api.g_varchar2_table(55) := '2A623B6B3D746869732E6628612E706F736974696F6E293B713D5B5D3B6C3D746869732E613B623D303B666F7228663D6C2E6C656E6774683B623C6626262128653D6C5B625D2C65213D3D6126266E756C6C213D652E6D61702626652E67657456697369';
wwv_flow_api.g_varchar2_table(56) := '626C652829262628633D746869732E66286E756C6C213D28683D6E756C6C213D286D3D652E5F6F6D7344617461293F6D2E763A766F69642030293F683A652E706F736974696F6E292C746869732E6928632C6B293C6E262628712E707573682865292C64';
wwv_flow_api.g_varchar2_table(57) := '2929293B622B2B293B72657475726E20717D3B632E463D66756E6374696F6E28297B76617220612C642C622C662C652C632C6B2C6C2C6E2C682C6D3B6966286E756C6C3D3D746869732E672E67657450726F6A656374696F6E2829297468726F77224D75';
wwv_flow_api.g_varchar2_table(58) := '7374207761697420666F72202769646C6527206576656E74206F6E206D6170206265666F72652063616C6C696E67206D61726B6572734E656172416E794F746865724D61726B6572223B6E3D746869732E6E656172627944697374616E63653B6E2A3D6E';
wwv_flow_api.g_varchar2_table(59) := '3B76617220703B653D746869732E613B703D5B5D3B683D303B666F7228643D652E6C656E6774683B683C643B682B2B29663D655B685D2C702E70757368287B483A746869732E66286E756C6C213D28613D6E756C6C213D28623D662E5F6F6D7344617461';
wwv_flow_api.g_varchar2_table(60) := '293F0A622E763A766F69642030293F613A662E706F736974696F6E292C623A21317D293B683D746869732E613B613D623D303B666F7228663D682E6C656E6774683B623C663B613D2B2B6229696628643D685B615D2C6E756C6C213D642E6765744D6170';
wwv_flow_api.g_varchar2_table(61) := '28292626642E67657456697369626C652829262628633D705B615D2C21632E622929666F72286D3D746869732E612C643D6C3D302C653D6D2E6C656E6774683B6C3C653B643D2B2B6C296966286B3D6D5B645D2C64213D3D6126266E756C6C213D6B2E67';
wwv_flow_api.g_varchar2_table(62) := '65744D6170282926266B2E67657456697369626C6528292626286B3D705B645D2C282128643C61297C7C6B2E62292626746869732E6928632E482C6B2E48293C6E29297B632E623D6B2E623D21303B627265616B7D72657475726E20707D3B632E6D6172';
wwv_flow_api.g_varchar2_table(63) := '6B6572734E656172416E794F746865724D61726B65723D66756E6374696F6E28297B76617220612C642C622C632C652C672C6B3B653D746869732E4628293B673D746869732E613B6B3D5B5D3B613D643D303B666F7228623D672E6C656E6774683B643C';
wwv_flow_api.g_varchar2_table(64) := '623B613D2B2B6429633D675B615D2C655B615D2E6226266B2E707573682863293B72657475726E206B7D3B632E736574496D6D6564696174653D66756E6374696F6E2861297B72657475726E2077696E646F772E73657454696D656F757428612C30297D';
wwv_flow_api.g_varchar2_table(65) := '3B632E683D0A66756E6374696F6E28297B69662821746869732E6261736963466F726D61744576656E747326266E756C6C3D3D746869732E6C2972657475726E20746869732E6C3D746869732E736574496D6D6564696174652866756E6374696F6E2861';
wwv_flow_api.g_varchar2_table(66) := '297B72657475726E2066756E6374696F6E28297B612E6C3D6E756C6C3B72657475726E206E756C6C213D612E672E67657450726F6A656374696F6E28293F612E7728293A6E756C6C213D612E423F766F696420303A612E423D6C2E6164644C697374656E';
wwv_flow_api.g_varchar2_table(67) := '65724F6E636528612E6D61702C2269646C65222C66756E6374696F6E28297B72657475726E20612E7728297D297D7D287468697329297D3B632E773D66756E6374696F6E28297B76617220612C642C622C632C652C672C6B3B696628746869732E626173';
wwv_flow_api.g_varchar2_table(68) := '6963466F726D61744576656E7473297B653D5B5D3B643D303B666F7228623D6D61726B6572732E6C656E6774683B643C623B642B2B29633D6D61726B6572735B645D2C613D6E756C6C213D632E5F6F6D73446174613F2253504944455246494544223A22';
wwv_flow_api.g_varchar2_table(69) := '554E53504944455246494544222C652E7075736828746869732E747269676765722822666F726D6174222C632C746869732E636F6E7374727563746F722E6D61726B65725374617475735B615D29293B72657475726E20657D653D746869732E4628293B';
wwv_flow_api.g_varchar2_table(70) := '673D746869732E613B0A6B3D5B5D3B613D623D303B666F7228643D672E6C656E6774683B623C643B613D2B2B6229633D675B615D2C613D6E756C6C213D632E5F6F6D73446174613F2253504944455246494544223A655B615D2E623F2253504944455246';
wwv_flow_api.g_varchar2_table(71) := '4941424C45223A22554E535049444552464941424C45222C6B2E7075736828746869732E747269676765722822666F726D6174222C632C746869732E636F6E7374727563746F722E6D61726B65725374617475735B615D29293B72657475726E206B7D3B';
wwv_flow_api.g_varchar2_table(72) := '632E503D66756E6374696F6E2861297B72657475726E7B6D3A66756E6374696F6E2864297B72657475726E2066756E6374696F6E28297B72657475726E20612E5F6F6D73446174612E6F2E7365744F7074696F6E73287B7374726F6B65436F6C6F723A64';
wwv_flow_api.g_varchar2_table(73) := '2E6C6567436F6C6F72732E686967686C6967687465645B642E6D61702E6D61705479706549645D2C7A496E6465783A642E686967686C6967687465644C65675A496E6465787D297D7D2874686973292C753A66756E6374696F6E2864297B72657475726E';
wwv_flow_api.g_varchar2_table(74) := '2066756E6374696F6E28297B72657475726E20612E5F6F6D73446174612E6F2E7365744F7074696F6E73287B7374726F6B65436F6C6F723A642E6C6567436F6C6F72732E757375616C5B642E6D61702E6D61705479706549645D2C7A496E6465783A642E';
wwv_flow_api.g_varchar2_table(75) := '757375616C4C65675A496E6465787D297D7D2874686973297D7D3B0A632E573D66756E6374696F6E28612C64297B76617220622C632C652C672C6B2C712C6E2C6D2C702C723B746869732E4A3D21303B723D612E6C656E6774683B623D746869732E5428';
wwv_flow_api.g_varchar2_table(76) := '66756E6374696F6E28297B76617220622C642C633B633D5B5D3B623D303B666F7228643D612E6C656E6774683B623C643B622B2B296D3D615B625D2C632E70757368286D2E47293B72657475726E20637D2829293B673D723E3D746869732E636972636C';
wwv_flow_api.g_varchar2_table(77) := '6553706972616C5377697463686F7665723F746869732E4D28722C62292E7265766572736528293A746869732E4C28722C62293B623D66756E6374696F6E28297B76617220622C642C663B663D5B5D3B623D303B666F7228643D672E6C656E6774683B62';
wwv_flow_api.g_varchar2_table(78) := '3C643B622B2B29653D675B625D2C633D746869732E552865292C703D746869732E5328612C66756E6374696F6E2861297B72657475726E2066756E6374696F6E2862297B72657475726E20612E6928622E472C65297D7D287468697329292C6E3D702E52';
wwv_flow_api.g_varchar2_table(79) := '2C713D6E657720682E506F6C796C696E65287B6D61703A746869732E6D61702C706174683A5B6E2E706F736974696F6E2C635D2C7374726F6B65436F6C6F723A746869732E6C6567436F6C6F72732E757375616C5B746869732E6D61702E6D6170547970';
wwv_flow_api.g_varchar2_table(80) := '6549645D2C7374726F6B655765696768743A746869732E6C65675765696768742C0A7A496E6465783A746869732E757375616C4C65675A496E6465787D292C6E2E5F6F6D73446174613D7B763A6E2E676574506F736974696F6E28292C583A6E2E676574';
wwv_flow_api.g_varchar2_table(81) := '5A496E64657828292C6F3A717D2C746869732E6C6567436F6C6F72732E686967686C6967687465645B746869732E6D61702E6D61705479706549645D213D3D746869732E6C6567436F6C6F72732E757375616C5B746869732E6D61702E6D617054797065';
wwv_flow_api.g_varchar2_table(82) := '49645D2626286B3D746869732E50286E292C6E2E5F6F6D73446174612E4F3D7B6D3A6C2E6164644C697374656E6572286E2C226D6F7573656F766572222C6B2E6D292C753A6C2E6164644C697374656E6572286E2C226D6F7573656F7574222C6B2E7529';
wwv_flow_api.g_varchar2_table(83) := '7D292C746869732E747269676765722822666F726D6174222C6E2C746869732E636F6E7374727563746F722E6D61726B65725374617475732E53504944455246494544292C6E2E736574506F736974696F6E2863292C6E2E7365745A496E646578284D61';
wwv_flow_api.g_varchar2_table(84) := '74682E726F756E6428746869732E737069646572666965645A496E6465782B652E7929292C662E70757368286E293B72657475726E20667D2E63616C6C2874686973293B64656C65746520746869732E4A3B746869732E493D21303B72657475726E2074';
wwv_flow_api.g_varchar2_table(85) := '6869732E7472696767657228227370696465726679222C622C64297D3B632E756E73706964657266793D0A66756E6374696F6E2861297B76617220642C622C632C652C672C6B2C683B6E756C6C3D3D61262628613D6E756C6C293B6966286E756C6C3D3D';
wwv_flow_api.g_varchar2_table(86) := '746869732E492972657475726E20746869733B746869732E4B3D21303B683D5B5D3B673D5B5D3B6B3D746869732E613B643D303B666F7228623D6B2E6C656E6774683B643C623B642B2B29653D6B5B645D2C6E756C6C213D652E5F6F6D73446174613F28';
wwv_flow_api.g_varchar2_table(87) := '652E5F6F6D73446174612E6F2E7365744D6170286E756C6C292C65213D3D612626652E736574506F736974696F6E28652E5F6F6D73446174612E76292C652E7365745A496E64657828652E5F6F6D73446174612E58292C633D652E5F6F6D73446174612E';
wwv_flow_api.g_varchar2_table(88) := '4F2C6E756C6C213D632626286C2E72656D6F76654C697374656E657228632E6D292C6C2E72656D6F76654C697374656E657228632E7529292C64656C65746520652E5F6F6D73446174612C65213D3D61262628633D746869732E6261736963466F726D61';
wwv_flow_api.g_varchar2_table(89) := '744576656E74733F22554E53504944455246494544223A22535049444552464941424C45222C746869732E747269676765722822666F726D6174222C652C746869732E636F6E7374727563746F722E6D61726B65725374617475735B635D29292C682E70';
wwv_flow_api.g_varchar2_table(90) := '757368286529293A672E707573682865293B64656C65746520746869732E4B3B64656C65746520746869732E493B0A746869732E747269676765722822756E7370696465726679222C682C67293B72657475726E20746869737D3B632E693D66756E6374';
wwv_flow_api.g_varchar2_table(91) := '696F6E28612C64297B76617220622C633B623D612E782D642E783B633D612E792D642E793B72657475726E20622A622B632A637D3B632E543D66756E6374696F6E2861297B76617220632C622C662C652C673B633D653D673D303B666F7228623D612E6C';
wwv_flow_api.g_varchar2_table(92) := '656E6774683B633C623B632B2B29663D615B635D2C652B3D662E782C672B3D662E793B613D612E6C656E6774683B72657475726E206E657720682E506F696E7428652F612C672F61297D3B632E663D66756E6374696F6E2861297B72657475726E207468';
wwv_flow_api.g_varchar2_table(93) := '69732E672E67657450726F6A656374696F6E28292E66726F6D4C61744C6E67546F446976506978656C2861297D3B632E553D66756E6374696F6E2861297B72657475726E20746869732E672E67657450726F6A656374696F6E28292E66726F6D44697650';
wwv_flow_api.g_varchar2_table(94) := '6978656C546F4C61744C6E672861297D3B632E533D66756E6374696F6E28612C63297B76617220622C642C652C672C6B2C683B653D6B3D303B666F7228683D612E6C656E6774683B6B3C683B653D2B2B6B29696628673D615B655D2C673D632867292C22';
wwv_flow_api.g_varchar2_table(95) := '756E646566696E6564223D3D3D747970656F6620627C7C6E756C6C3D3D3D627C7C673C6429643D672C623D653B72657475726E20612E73706C69636528622C0A31295B305D7D3B632E413D66756E6374696F6E28612C63297B76617220622C642C652C67';
wwv_flow_api.g_varchar2_table(96) := '3B6966286E756C6C213D612E696E6465784F662972657475726E20612E696E6465784F662863293B623D643D303B666F7228653D612E6C656E6774683B643C653B623D2B2B6429696628673D615B625D2C673D3D3D632972657475726E20623B72657475';
wwv_flow_api.g_varchar2_table(97) := '726E2D317D3B72657475726E20727D28293B743D2F285C3F2E2A28267C26616D703B297C5C3F29737069646572666965725F63616C6C6261636B3D285C772B292F3B6D3D646F63756D656E742E63757272656E745363726970743B6E756C6C3D3D6D2626';
wwv_flow_api.g_varchar2_table(98) := '286D3D66756E6374696F6E28297B766172206D2C6C2C682C772C763B683D646F63756D656E742E676574456C656D656E747342795461674E616D65282273637269707422293B763D5B5D3B6D3D303B666F72286C3D682E6C656E6774683B6D3C6C3B6D2B';
wwv_flow_api.g_varchar2_table(99) := '2B29753D685B6D5D2C6E756C6C213D28773D752E67657441747472696275746528227372632229292626772E6D617463682874292626762E707573682875293B72657475726E20767D28295B305D293B6966286E756C6C213D6D2626286D3D6E756C6C21';
wwv_flow_api.g_varchar2_table(100) := '3D28773D6D2E67657441747472696275746528227372632229293F6E756C6C213D28793D772E6D61746368287429293F795B335D3A766F696420303A766F696420302926260A2266756E6374696F6E223D3D3D747970656F662077696E646F775B6D5D29';
wwv_flow_api.g_varchar2_table(101) := '77696E646F775B6D5D28293B2266756E6374696F6E223D3D3D747970656F662077696E646F772E737069646572666965725F63616C6C6261636B262677696E646F772E737069646572666965725F63616C6C6261636B28297D292E63616C6C2874686973';
wwv_flow_api.g_varchar2_table(102) := '293B0A2F2A20546875203131204D617920323031372030383A34303A353720425354202A2F0A';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(108957226694998971)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'oms.min.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '24282866756E6374696F6E28297B242E77696467657428226A6B36342E7265706F72746D6170222C7B6F7074696F6E733A7B726567696F6E49643A22222C616A61784964656E7469666965723A22222C616A61784974656D733A22222C706C7567696E52';
wwv_flow_api.g_varchar2_table(2) := '65736F75726365506174683A22222C706C7567696E46696C655072656669783A22222C657870656374446174613A21302C6D6178696D756D526F77733A6E756C6C2C726F777350657242617463683A6E756C6C2C696E697469616C43656E7465723A7B6C';
wwv_flow_api.g_varchar2_table(3) := '61743A302C6C6E673A307D2C6D696E5A6F6F6D3A312C6D61785A6F6F6D3A6E756C6C2C696E697469616C5A6F6F6D3A322C76697375616C69736174696F6E3A2270696E73222C6D6170547970653A22726F61646D6170222C636C69636B5A6F6F6D4C6576';
wwv_flow_api.g_varchar2_table(4) := '656C3A6E756C6C2C6973447261676761626C653A21312C686561746D61704469737369706174696E673A21312C686561746D61704F7061636974793A2E362C686561746D61705261646975733A352C70616E4F6E436C69636B3A21302C72657374726963';
wwv_flow_api.g_varchar2_table(5) := '74436F756E7472793A22222C6D61705374796C653A22222C74726176656C4D6F64653A2244524956494E47222C756E697453797374656D3A224D4554524943222C6F7074696D697A65576179706F696E74733A21312C616C6C6F775A6F6F6D3A21302C61';
wwv_flow_api.g_varchar2_table(6) := '6C6C6F7750616E3A21302C6765737475726548616E646C696E673A226175746F222C696E6974466E3A6E756C6C2C6D61726B6572466F726D6174466E3A6E756C6C2C64726177696E674D6F6465733A6E756C6C2C66656174757265436F6C6F723A222363';
wwv_flow_api.g_varchar2_table(7) := '6336366666222C66656174757265436F6C6F7253656C65637465643A2223666636363030222C6665617475726553656C65637461626C653A21302C66656174757265486F76657261626C653A21302C666561747572655374796C65466E3A6E756C6C2C64';
wwv_flow_api.g_varchar2_table(8) := '72616744726F7047656F4A534F4E3A21312C6175746F466974426F756E64733A21302C646972656374696F6E7350616E656C3A6E756C6C2C737069646572666965723A7B7D2C7370696465726679466F726D6174466E3A6E756C6C2C73686F7750696E73';
wwv_flow_api.g_varchar2_table(9) := '3A21302C73686F77496E666F506F707570733A21302C73686F77496E666F4C617965723A21312C696E666F4C61796572466F726D6174466E3A6E756C6C2C73686F775370696E6E65723A21302C64657461696C65644D6F7573654576656E74733A21312C';
wwv_flow_api.g_varchar2_table(10) := '69636F6E42617365506174683A22222C6E6F446174614D6573736167653A22222C6E6F41646472657373526573756C74733A2241646472657373206E6F7420666F756E64222C646972656374696F6E734E6F74466F756E643A224174206C65617374206F';
wwv_flow_api.g_varchar2_table(11) := '6E65206F6620746865206F726967696E2C2064657374696E6174696F6E2C206F7220776179706F696E747320636F756C64206E6F742062652067656F636F6465642E222C646972656374696F6E735A65726F526573756C74733A224E6F20726F75746520';
wwv_flow_api.g_varchar2_table(12) := '636F756C6420626520666F756E64206265747765656E20746865206F726967696E20616E642064657374696E6174696F6E2E222C6164644F7665726C61793A6E756C6C2C636C69636B3A6E756C6C2C64656C657465416C6C46656174757265733A6E756C';
wwv_flow_api.g_varchar2_table(13) := '6C2C64656C65746553656C656374656446656174757265733A6E756C6C2C666974426F756E64733A6E756C6C2C67656F6C6F636174653A6E756C6C2C676574416464726573734279506F733A6E756C6C2C676F746F416464726573733A6E756C6C2C676F';
wwv_flow_api.g_varchar2_table(14) := '746F506F733A6E756C6C2C676F746F506F734279537472696E673A6E756C6C2C686964654D6573736167653A6E756C6C2C6C6F616447656F4A736F6E537472696E673A6E756C6C2C70616E546F3A6E756C6C2C70616E546F4279537472696E673A6E756C';
wwv_flow_api.g_varchar2_table(15) := '6C2C70617273654C61744C6E673A6E756C6C2C726566726573683A6E756C6C2C73686F77446972656374696F6E733A6E756C6C2C73686F77496E666F57696E646F773A6E756C6C2C73686F774D6573736167653A6E756C6C7D2C70617273654C61744C6E';
wwv_flow_api.g_varchar2_table(16) := '673A66756E6374696F6E2865297B76617220742C6F3B28617065782E646562756728227265706F72746D61702E70617273654C61744C6E67222C65292C6E756C6C213D6529262628652E6861734F776E50726F706572747928226C617422292626652E68';
wwv_flow_api.g_varchar2_table(17) := '61734F776E50726F706572747928226C6E6722293F743D6E657720676F6F676C652E6D6170732E4C61744C6E672865293A28652E696E6465784F6628223B22293E2D313F6F3D652E73706C697428223B22293A652E696E6465784F6628222022293E2D31';
wwv_flow_api.g_varchar2_table(18) := '3F6F3D652E73706C697428222022293A652E696E6465784F6628222C22293E2D312626286F3D652E73706C697428222C2229292C6F2626323D3D6F2E6C656E6774683F286F5B305D3D6F5B305D2E7265706C616365282F2C2F672C222E22292C6F5B315D';
wwv_flow_api.g_varchar2_table(19) := '3D6F5B315D2E7265706C616365282F2C2F672C222E22292C617065782E64656275672822706172736564222C6F292C743D6E657720676F6F676C652E6D6170732E4C61744C6E67287061727365466C6F6174286F5B305D292C7061727365466C6F617428';
wwv_flow_api.g_varchar2_table(20) := '6F5B315D2929293A617065782E646562756728226E6F204C61744C6E6720666F756E64222C652929293B72657475726E20747D2C6164644F7665726C61793A66756E6374696F6E28742C6F297B617065782E646562756728226164644F7665726C617922';
wwv_flow_api.g_varchar2_table(21) := '2C742C6F293B76617220693D242E657874656E64287B626F756E64733A6E756C6C2C706F733A6E756C6C2C686F72697A6F6E74616C416C69676E3A2263656E746572222C766572746963616C416C69676E3A226D6964646C65222C686F72697A6F6E7461';
wwv_flow_api.g_varchar2_table(22) := '6C4F66667365743A302C766572746963616C4F66667365743A302C6D696E5A6F6F6D3A302C6D61785A6F6F6D3A39392C6F6E436C69636B48616E646C65723A6E756C6C7D2C6F292C733D6E6577206528742C69293B72657475726E20732E7365744D6170';
wwv_flow_api.g_varchar2_table(23) := '28746869732E6D6170292C737D2C73686F774D6573736167653A66756E6374696F6E2865297B617065782E646562756728227265706F72746D61702E73686F774D657373616765222C65292C746869732E686964654D65737361676528292C746869732E';
wwv_flow_api.g_varchar2_table(24) := '6D73674469763D646F63756D656E742E637265617465456C656D656E74282264697622293B76617220743D646F63756D656E742E637265617465456C656D656E74282264697622293B742E636C6173734E616D653D227265706F72746D61702D6D657373';
wwv_flow_api.g_varchar2_table(25) := '6167655549222C746869732E6D73674469762E617070656E644368696C642874293B766172206F3D646F63756D656E742E637265617465456C656D656E74282264697622293B72657475726E206F2E636C6173734E616D653D227265706F72746D61702D';
wwv_flow_api.g_varchar2_table(26) := '6D657373616765496E6E6572222C6F2E696E6E657248544D4C3D652C742E617070656E644368696C64286F292C746869732E6D73674469762E6164644576656E744C697374656E65722822636C69636B222C2866756E6374696F6E28297B617065782E64';
wwv_flow_api.g_varchar2_table(27) := '6562756728226F6E20636C69636B202D2068696465206D65737361676522292C746869732E72656D6F766528297D29292C746869732E6D61702E636F6E74726F6C735B676F6F676C652E6D6170732E436F6E74726F6C506F736974696F6E2E4C4546545F';
wwv_flow_api.g_varchar2_table(28) := '43454E5445525D2E7075736828746869732E6D7367446976292C746869732E6D73674469767D2C686964654D6573736167653A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E686964654D65737361676522292C7468';
wwv_flow_api.g_varchar2_table(29) := '69732E6D73674469762626746869732E6D73674469762E72656D6F766528297D2C5F6576656E7450696E446174613A66756E6374696F6E2865297B76617220743D7B6D61703A746869732E6D61702C6C61743A652E706F736974696F6E2E6C617428292C';
wwv_flow_api.g_varchar2_table(30) := '6C6E673A652E706F736974696F6E2E6C6E6728292C6D61726B65723A657D3B72657475726E20652E6F7665726C61792626652E6F7665726C61792E646976262628742E696E666F4469763D652E6F7665726C61792E646976292C242E657874656E642874';
wwv_flow_api.g_varchar2_table(31) := '2C652E64617461292C747D2C5F756E657363617065496E666F3A66756E6374696F6E2865297B72657475726E286E657720444F4D506172736572292E706172736546726F6D537472696E6728652C22746578742F68746D6C22292E646F63756D656E7445';
wwv_flow_api.g_varchar2_table(32) := '6C656D656E742E74657874436F6E74656E747D2C73686F77496E666F57696E646F773A66756E6374696F6E2865297B72657475726E20617065782E646562756728227265706F72746D61702E73686F77496E666F57696E646F77222C65292C746869732E';
wwv_flow_api.g_varchar2_table(33) := '696E666F57696E646F777C7C28746869732E696E666F57696E646F773D6E657720676F6F676C652E6D6170732E496E666F57696E646F77292C746869732E696E666F57696E646F772E736574436F6E74656E7428746869732E5F756E657363617065496E';
wwv_flow_api.g_varchar2_table(34) := '666F28652E646174612E696E666F29292C746869732E696E666F57696E646F772E6F70656E28746869732E6D61702C65292C746869732E696E666F57696E646F777D2C5F6E65774D61726B65723A66756E6374696F6E2865297B76617220743D74686973';
wwv_flow_api.g_varchar2_table(35) := '2C6F3D6E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A746869732E6D61702C706F736974696F6E3A6E657720676F6F676C652E6D6170732E4C61744C6E6728652E782C652E79292C7469746C653A652E6E2C69636F6E3A652E633F';
wwv_flow_api.g_varchar2_table(36) := '746869732E6F7074696F6E732E69636F6E42617365506174682B652E633A6E756C6C2C6C6162656C3A652E6C2C647261676761626C653A746869732E6F7074696F6E732E6973447261676761626C657D293B6F2E646174613D7B69643A652E642C696E66';
wwv_flow_api.g_varchar2_table(37) := '6F3A652E692C6E616D653A652E6E7D3B666F722876617220693D313B693C3D31303B692B2B29652E662626652E665B2261222B695D2626286F2E646174615B2261747472222B282230222B69292E736C696365282D32295D3D652E665B2261222B695D29';
wwv_flow_api.g_varchar2_table(38) := '3B72657475726E20746869732E6F7074696F6E732E73686F7750696E737C7C6F2E73657456697369626C65282131292C746869732E6F7074696F6E732E6D61726B6572466F726D6174466E2626746869732E6F7074696F6E732E6D61726B6572466F726D';
wwv_flow_api.g_varchar2_table(39) := '6174466E286F292C6F2E646174612E696E666F2626746869732E6F7074696F6E732E73686F77496E666F4C617965722626286F2E6F7665726C61793D746869732E6164644F7665726C617928746869732E5F756E657363617065496E666F286F2E646174';
wwv_flow_api.g_varchar2_table(40) := '612E696E666F292C7B706F733A6F2E706F736974696F6E2C6F6E436C69636B48616E646C65723A66756E6374696F6E28297B617065782E64656275672822696E666F4C6179657220636C69636B6564222C6F2E646174612E6964292C742E6F7074696F6E';
wwv_flow_api.g_varchar2_table(41) := '732E70616E4F6E436C69636B2626742E6D61702E70616E546F286F2E706F736974696F6E292C742E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C2626742E6D61702E7365745A6F6F6D28742E6F7074696F6E732E636C69636B5A6F6F6D4C6576';
wwv_flow_api.g_varchar2_table(42) := '656C292C617065782E6A5175657279282223222B742E6F7074696F6E732E726567696F6E4964292E7472696767657228226D61726B6572636C69636B222C742E5F6576656E7450696E44617461286F29297D7D292C746869732E6F7074696F6E732E696E';
wwv_flow_api.g_varchar2_table(43) := '666F4C61796572466F726D6174466E2626746869732E6F7074696F6E732E696E666F4C61796572466F726D6174466E286F2E6F7665726C61792C6F29292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286F2C227370696465';
wwv_flow_api.g_varchar2_table(44) := '7266696572223D3D746869732E6F7074696F6E732E76697375616C69736174696F6E3F227370696465725F636C69636B223A22636C69636B222C2866756E6374696F6E28297B617065782E646562756728226D61726B657220636C69636B6564222C6F2E';
wwv_flow_api.g_varchar2_table(45) := '646174612E6964293B76617220653D746869732E676574506F736974696F6E28293B6F2E646174612E696E666F2626742E6F7074696F6E732E73686F77496E666F506F707570732626742E73686F77496E666F57696E646F772874686973292C742E6F70';
wwv_flow_api.g_varchar2_table(46) := '74696F6E732E70616E4F6E436C69636B2626742E6D61702E70616E546F2865292C742E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C2626742E6D61702E7365745A6F6F6D28742E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C292C61';
wwv_flow_api.g_varchar2_table(47) := '7065782E6A5175657279282223222B742E6F7074696F6E732E726567696F6E4964292E7472696767657228226D61726B6572636C69636B222C742E5F6576656E7450696E44617461286F29297D29292C676F6F676C652E6D6170732E6576656E742E6164';
wwv_flow_api.g_varchar2_table(48) := '644C697374656E6572286F2C2264726167656E64222C2866756E6374696F6E28297B76617220653D746869732E676574506F736974696F6E28293B617065782E646562756728226D61726B6572206D6F766564222C6F2E646174612E69642C4A534F4E2E';
wwv_flow_api.g_varchar2_table(49) := '737472696E67696679286529292C617065782E6A5175657279282223222B742E6F7074696F6E732E726567696F6E4964292E7472696767657228226D61726B657264726167222C742E5F6576656E7450696E44617461286F29297D29292C5B2270696E73';
wwv_flow_api.g_varchar2_table(50) := '222C22696E666F6C61796572222C22636C7573746572222C2273706964657266696572225D2E696E6465784F6628746869732E6F7074696F6E732E76697375616C69736174696F6E293E2D31262628746869732E69644D61702626746869732E69644D61';
wwv_flow_api.g_varchar2_table(51) := '702E686173286F2E646174612E6964297C7C617065782E6A5175657279282223222B742E6F7074696F6E732E726567696F6E4964292E7472696767657228226D61726B65726164646564222C742E5F6576656E7450696E44617461286F2929292C6F7D2C';
wwv_flow_api.g_varchar2_table(52) := '5F73706964657266793A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E5F737069646572667922293B76617220653D746869732C743D7B6B656570537069646572666965643A21302C6261736963466F726D61744576';
wwv_flow_api.g_varchar2_table(53) := '656E74733A21302C6D61726B657273576F6E744D6F76653A21746869732E6F7074696F6E732E6973447261676761626C652C6D61726B657273576F6E74486964653A21307D3B242E657874656E6428742C746869732E6F7074696F6E732E737069646572';
wwv_flow_api.g_varchar2_table(54) := '66696572292C746869732E6F6D733D6E6577204F7665726C617070696E674D61726B65725370696465726669657228746869732E6D61702C74292C746869732E6F6D732E6164644C697374656E65722822666F726D6174222C746869732E6F7074696F6E';
wwv_flow_api.g_varchar2_table(55) := '732E7370696465726679466F726D6174466E7C7C66756E6374696F6E28742C6F297B76617220693D652E5F67657457696E646F775061746828292B222F222B652E6F7074696F6E732E706C7567696E46696C655072656669782B286F3D3D4F7665726C61';
wwv_flow_api.g_varchar2_table(56) := '7070696E674D61726B6572537069646572666965722E6D61726B65725374617475732E535049444552464945443F22696D616765732F73706F746C696768742D776179706F696E742D626C75652E706E67223A6F3D3D4F7665726C617070696E674D6172';
wwv_flow_api.g_varchar2_table(57) := '6B6572537069646572666965722E6D61726B65725374617475732E535049444552464941424C453F22696D616765732F73706F746C696768742D776179706F696E742D612E706E67223A22696D616765732F73706F746C696768742D706F692E706E6722';
wwv_flow_api.g_varchar2_table(58) := '293B742E73657449636F6E287B75726C3A697D297D293B666F7228766172206F3D303B6F3C746869732E6D61726B6572732E6C656E6774683B6F2B2B29746869732E6F6D732E6164644D61726B657228746869732E6D61726B6572735B6F5D293B726574';
wwv_flow_api.g_varchar2_table(59) := '75726E20746869732E6F6D732E6164644C697374656E657228227370696465726679222C2866756E6374696F6E2874297B617065782E646562756728227370696465726679222C74292C617065782E6A5175657279282223222B652E6F7074696F6E732E';
wwv_flow_api.g_varchar2_table(60) := '726567696F6E4964292E7472696767657228227370696465726679222C7B6D61703A652E6D61702C6D61726B6572733A747D297D29292C746869732E6F6D732E6164644C697374656E65722822756E7370696465726679222C2866756E6374696F6E2874';
wwv_flow_api.g_varchar2_table(61) := '297B617065782E64656275672822756E7370696465726679222C74292C617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E747269676765722822756E7370696465726679222C7B6D61703A652E6D61702C6D6172';
wwv_flow_api.g_varchar2_table(62) := '6B6572733A747D297D29292C746869732E6F6D737D2C5F72656D6F76654D61726B6572733A66756E6374696F6E28297B696628617065782E646562756728227265706F72746D61702E5F72656D6F76654D61726B65727322292C746869732E746F74616C';
wwv_flow_api.g_varchar2_table(63) := '526F77733D302C746869732E626F756E64732626746869732E626F756E64732E64656C6574652C746869732E6D61726B657273297B666F722876617220653D303B653C746869732E6D61726B6572732E6C656E6774683B652B2B29746869732E6D61726B';
wwv_flow_api.g_varchar2_table(64) := '6572735B655D2E7365744D6170286E756C6C293B746869732E6D61726B6572732E64656C6574657D7D2C636C69636B3A66756E6374696F6E2865297B617065782E646562756728227265706F72746D61702E636C69636B22293B76617220743D74686973';
wwv_flow_api.g_varchar2_table(65) := '2E6D61726B6572732E66696E64282866756E6374696F6E2874297B72657475726E20742E646174612E69643D3D657D29293B72657475726E20743F6E657720676F6F676C652E6D6170732E6576656E742E7472696767657228742C22636C69636B22293A';
wwv_flow_api.g_varchar2_table(66) := '617065782E646562756728226964206E6F7420666F756E64222C65292C747D2C676F746F506F733A66756E6374696F6E28652C74297B696628617065782E646562756728227265706F72746D61702E676F746F506F73222C652C74292C6E756C6C213D3D';
wwv_flow_api.g_varchar2_table(67) := '6526266E756C6C213D3D74297B766172206F3D746869732E7573657270696E3F746869732E7573657270696E2E676574506F736974696F6E28293A6E657720676F6F676C652E6D6170732E4C61744C6E6728302C30293B6966286F2626653D3D6F2E6C61';
wwv_flow_api.g_varchar2_table(68) := '7428292626743D3D6F2E6C6E67282929617065782E646562756728227573657270696E206E6F74206368616E67656422293B656C73657B76617220693D6E657720676F6F676C652E6D6170732E4C61744C6E6728652C74293B696628746869732E757365';
wwv_flow_api.g_varchar2_table(69) := '7270696E29617065782E646562756728226D6F7665206578697374696E672070696E20746F206E657720706F736974696F6E206F6E206D6170222C69292C746869732E7573657270696E2E7365744D617028746869732E6D6170292C746869732E757365';
wwv_flow_api.g_varchar2_table(70) := '7270696E2E736574506F736974696F6E2869293B656C73657B617065782E64656275672822637265617465207573657270696E222C69292C746869732E7573657270696E3D6E657720676F6F676C652E6D6170732E4D61726B6572287B6D61703A746869';
wwv_flow_api.g_varchar2_table(71) := '732E6D61702C706F736974696F6E3A692C647261676761626C653A746869732E6F7074696F6E732E6973447261676761626C657D293B76617220733D746869733B676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228746869732E';
wwv_flow_api.g_varchar2_table(72) := '7573657270696E2C2264726167656E64222C2866756E6374696F6E28297B76617220653D746869732E676574506F736974696F6E28293B617065782E646562756728227573657270696E206D6F766564222C4A534F4E2E737472696E6769667928652929';
wwv_flow_api.g_varchar2_table(73) := '2C617065782E6A5175657279282223222B732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D61726B657264726167222C7B6D61703A732E6D61702C6C61743A652E6C617428292C6C6E673A652E6C6E6728292C6D61726B65723A';
wwv_flow_api.g_varchar2_table(74) := '746869737D297D29297D7D7D656C736520746869732E7573657270696E262628617065782E646562756728226D6F7665206578697374696E672070696E206F666620746865206D617022292C746869732E7573657270696E2E7365744D6170286E756C6C';
wwv_flow_api.g_varchar2_table(75) := '29297D2C676F746F506F734279537472696E673A66756E6374696F6E2865297B617065782E646562756728227265706F72746D61702E676F746F506F734279537472696E67222C65293B76617220743D746869732E70617273654C61744C6E672865293B';
wwv_flow_api.g_varchar2_table(76) := '72657475726E20742626746869732E676F746F506F7328742E6C617428292C742E6C6E672829292C747D2C70616E546F3A66756E6374696F6E28652C74297B766172206F3B72657475726E20617065782E646562756728227265706F72746D61702E7061';
wwv_flow_api.g_varchar2_table(77) := '6E546F222C652C74292C6E756C6C213D3D6526266E756C6C213D3D742626286F3D6E657720676F6F676C652E6D6170732E4C61744C6E6728652C74292C746869732E6D61702E70616E546F286F29292C6F7D2C70616E546F4279537472696E673A66756E';
wwv_flow_api.g_varchar2_table(78) := '6374696F6E2865297B617065782E646562756728227265706F72746D61702E70616E546F4279537472696E67222C65293B76617220743D746869732E70617273654C61744C6E672865293B72657475726E20742626746869732E70616E546F28742E6C61';
wwv_flow_api.g_varchar2_table(79) := '7428292C742E6C6E672829292C747D2C666974426F756E64733A66756E6374696F6E2865297B76617220743B72657475726E20617065782E646562756728227265706F72746D61702E666974426F756E6473222C65292C6E756C6C213D65262628743D65';
wwv_flow_api.g_varchar2_table(80) := '2E6861734F776E50726F706572747928226561737422292626652E6861734F776E50726F706572747928226E6F72746822292626652E6861734F776E50726F70657274792822736F75746822292626652E6861734F776E50726F70657274792822776573';
wwv_flow_api.g_varchar2_table(81) := '7422293F6E657720676F6F676C652E6D6170732E4C61744C6E67426F756E64734C69746572616C2865293A4A534F4E2E7061727365286529292626746869732E6D61702E666974426F756E64732874292C747D2C676F746F416464726573733A66756E63';
wwv_flow_api.g_varchar2_table(82) := '74696F6E2865297B617065782E646562756728227265706F72746D61702E676F746F41646472657373222C65293B76617220743D6E657720676F6F676C652E6D6170732E47656F636F6465723B746869732E686964654D65737361676528293B76617220';
wwv_flow_api.g_varchar2_table(83) := '6F3D746869733B742E67656F636F6465287B616464726573733A652C636F6D706F6E656E745265737472696374696F6E733A2222213D3D6F2E6F7074696F6E732E7265737472696374436F756E7472793F7B636F756E7472793A6F2E6F7074696F6E732E';
wwv_flow_api.g_varchar2_table(84) := '7265737472696374436F756E7472797D3A7B7D7D2C2866756E6374696F6E28652C74297B696628743D3D3D676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B297B76617220693D655B305D2E67656F6D657472792E6C6F63617469';
wwv_flow_api.g_varchar2_table(85) := '6F6E3B617065782E6465627567282267656F636F6465206F6B222C69292C6F2E6D61702E73657443656E7465722869292C6F2E6D61702E70616E546F2869292C6F2E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C26266F2E6D61702E7365745A';
wwv_flow_api.g_varchar2_table(86) := '6F6F6D286F2E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C292C6F2E676F746F506F7328692E6C617428292C692E6C6E672829292C617065782E6465627567282261646472657373666F756E64222C65292C617065782E6A5175657279282223';
wwv_flow_api.g_varchar2_table(87) := '222B6F2E6F7074696F6E732E726567696F6E4964292E74726967676572282261646472657373666F756E64222C7B6D61703A6F2E6D61702C6C61743A692E6C617428292C6C6E673A692E6C6E6728292C726573756C743A655B305D7D297D656C73652074';
wwv_flow_api.g_varchar2_table(88) := '3D3D3D676F6F676C652E6D6170732E47656F636F6465725374617475732E5A45524F5F524553554C54533F28617065782E64656275672822676574416464726573734279506F733A205A45524F5F524553554C545322292C6F2E73686F774D6573736167';
wwv_flow_api.g_varchar2_table(89) := '65286F2E6F7074696F6E732E6E6F41646472657373526573756C747329293A617065782E6465627567282247656F636F646572206661696C6564222C74297D29297D2C676574416464726573734279506F733A66756E6374696F6E28652C74297B617065';
wwv_flow_api.g_varchar2_table(90) := '782E646562756728227265706F72746D61702E676574416464726573734279506F73222C652C74293B766172206F3D6E657720676F6F676C652E6D6170732E47656F636F6465723B746869732E686964654D65737361676528293B76617220693D746869';
wwv_flow_api.g_varchar2_table(91) := '733B6F2E67656F636F6465287B6C6F636174696F6E3A7B6C61743A652C6C6E673A747D7D2C2866756E6374696F6E286F2C73297B733D3D3D676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B3F6F5B305D3F28617065782E646562';
wwv_flow_api.g_varchar2_table(92) := '7567282261646472657373666F756E64222C6F292C617065782E6A5175657279282223222B692E6F7074696F6E732E726567696F6E4964292E74726967676572282261646472657373666F756E64222C7B6D61703A692E6D61702C6C61743A652C6C6E67';
wwv_flow_api.g_varchar2_table(93) := '3A742C726573756C743A6F5B305D7D29293A28617065782E64656275672822676574416464726573734279506F733A204E6F20726573756C74732072657475726E656422292C692E73686F774D65737361676528692E6F7074696F6E732E6E6F41646472';
wwv_flow_api.g_varchar2_table(94) := '657373526573756C747329293A733D3D3D676F6F676C652E6D6170732E47656F636F6465725374617475732E5A45524F5F524553554C54533F28617065782E64656275672822676574416464726573734279506F733A205A45524F5F524553554C545322';
wwv_flow_api.g_varchar2_table(95) := '292C692E73686F774D65737361676528692E6F7074696F6E732E6E6F41646472657373526573756C747329293A617065782E6465627567282247656F636F646572206661696C6564222C73297D29297D2C67656F6C6F636174653A66756E6374696F6E28';
wwv_flow_api.g_varchar2_table(96) := '297B696628617065782E646562756728227265706F72746D61702E67656F6C6F6361746522292C6E6176696761746F722E67656F6C6F636174696F6E297B76617220653D746869733B6E6176696761746F722E67656F6C6F636174696F6E2E6765744375';
wwv_flow_api.g_varchar2_table(97) := '7272656E74506F736974696F6E282866756E6374696F6E2874297B766172206F3D7B6C61743A742E636F6F7264732E6C617469747564652C6C6E673A742E636F6F7264732E6C6F6E6769747564657D3B652E6D61702E70616E546F286F292C652E6F7074';
wwv_flow_api.g_varchar2_table(98) := '696F6E732E636C69636B5A6F6F6D4C6576656C2626652E6D61702E7365745A6F6F6D28652E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C292C617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E747269';
wwv_flow_api.g_varchar2_table(99) := '67676572282267656F6C6F63617465222C7B6D61703A652E6D61702C6C61743A6F2E6C61742C6C6E673A6F2E6C6E677D297D29297D656C736520617065782E6465627567282262726F7773657220646F6573206E6F7420737570706F72742067656F6C6F';
wwv_flow_api.g_varchar2_table(100) := '636174696F6E22297D2C5F646972656374696F6E73526573706F6E73653A66756E6374696F6E28652C74297B73776974636828617065782E646562756728227265706F72746D61702E5F646972656374696F6E73526573706F6E7365222C652C74292C74';
wwv_flow_api.g_varchar2_table(101) := '297B6361736520676F6F676C652E6D6170732E446972656374696F6E735374617475732E4F4B3A746869732E646972656374696F6E73446973706C61792E736574446972656374696F6E732865293B666F7228766172206F3D302C693D302C733D302C61';
wwv_flow_api.g_varchar2_table(102) := '3D226D6574657273222C6E3D303B6E3C652E726F757465732E6C656E6774683B6E2B2B297B732B3D652E726F757465735B6E5D2E6C6567732E6C656E6774683B666F722876617220723D303B723C652E726F757465735B6E5D2E6C6567732E6C656E6774';
wwv_flow_api.g_varchar2_table(103) := '683B722B2B297B76617220703D652E726F757465735B6E5D2E6C6567735B725D3B6F2B3D702E64697374616E63652E76616C75652C692B3D702E6475726174696F6E2E76616C75657D7D22494D50455249414C223D3D3D746869732E6F7074696F6E732E';
wwv_flow_api.g_varchar2_table(104) := '756E697453797374656D2626286F2A3D2E30303036323133373131393232342C613D226D696C657322293B617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E747269676765722822646972656374696F6E';
wwv_flow_api.g_varchar2_table(105) := '73222C7B6D61703A746869732E6D61702C64697374616E63653A6F2C756E6974733A612C6475726174696F6E3A692C6C6567733A732C646972656374696F6E733A657D293B627265616B3B6361736520676F6F676C652E6D6170732E446972656374696F';
wwv_flow_api.g_varchar2_table(106) := '6E735374617475732E4E4F545F464F554E443A746869732E73686F774D65737361676528746869732E6F7074696F6E732E646972656374696F6E734E6F74466F756E64293B627265616B3B6361736520676F6F676C652E6D6170732E446972656374696F';
wwv_flow_api.g_varchar2_table(107) := '6E735374617475732E5A45524F5F524553554C54533A746869732E73686F774D65737361676528746869732E6F7074696F6E732E646972656374696F6E735A65726F526573756C7473293B627265616B3B64656661756C743A617065782E646562756728';
wwv_flow_api.g_varchar2_table(108) := '22446972656374696F6E732072657175657374206661696C6564222C74297D7D2C73686F77446972656374696F6E733A66756E6374696F6E28652C742C6F297B696628617065782E646562756728227265706F72746D61702E73686F7744697265637469';
wwv_flow_api.g_varchar2_table(109) := '6F6E73222C652C742C6F292C746869732E6F726967696E3D652C746869732E64657374696E6174696F6E3D742C746869732E686964654D65737361676528292C746869732E6F726967696E2626746869732E64657374696E6174696F6E29696628746869';
wwv_flow_api.g_varchar2_table(110) := '732E646972656374696F6E73446973706C61797C7C28746869732E646972656374696F6E73446973706C61793D6E657720676F6F676C652E6D6170732E446972656374696F6E7352656E64657265722C746869732E646972656374696F6E735365727669';
wwv_flow_api.g_varchar2_table(111) := '63653D6E657720676F6F676C652E6D6170732E446972656374696F6E73536572766963652C746869732E646972656374696F6E73446973706C61792E7365744D617028746869732E6D6170292C746869732E6F7074696F6E732E646972656374696F6E73';
wwv_flow_api.g_varchar2_table(112) := '50616E656C2626746869732E646972656374696F6E73446973706C61792E73657450616E656C28646F63756D656E742E676574456C656D656E744279496428746869732E6F7074696F6E732E646972656374696F6E7350616E656C2929292C746869732E';
wwv_flow_api.g_varchar2_table(113) := '6F726967696E3D746869732E70617273654C61744C6E6728746869732E6F726967696E297C7C746869732E6F726967696E2C746869732E64657374696E6174696F6E3D746869732E70617273654C61744C6E6728746869732E64657374696E6174696F6E';
wwv_flow_api.g_varchar2_table(114) := '297C7C746869732E64657374696E6174696F6E2C2222213D3D746869732E6F726967696E26262222213D3D746869732E64657374696E6174696F6E297B76617220693D746869733B746869732E646972656374696F6E73536572766963652E726F757465';
wwv_flow_api.g_varchar2_table(115) := '287B6F726967696E3A746869732E6F726967696E2C64657374696E6174696F6E3A746869732E64657374696E6174696F6E2C74726176656C4D6F64653A676F6F676C652E6D6170732E54726176656C4D6F64655B6F7C7C746869732E6F7074696F6E732E';
wwv_flow_api.g_varchar2_table(116) := '74726176656C4D6F64655D2C756E697453797374656D3A676F6F676C652E6D6170732E556E697453797374656D5B746869732E6F7074696F6E732E756E697453797374656D5D7D2C2866756E6374696F6E28652C74297B692E5F646972656374696F6E73';
wwv_flow_api.g_varchar2_table(117) := '526573706F6E736528652C74297D29297D656C736520617065782E646562756728224E6F20646972656374696F6E7320746F2073686F77202D206E65656420626F7468206F726967696E20616E642064657374696E6174696F6E206C6F636174696F6E22';
wwv_flow_api.g_varchar2_table(118) := '293B656C736520617065782E64656275672822556E61626C6520746F2073686F7720646972656374696F6E733A206E6F20646174612C206E6F206F726967696E2F64657374696E6174696F6E22297D2C5F646972656374696F6E733A66756E6374696F6E';
wwv_flow_api.g_varchar2_table(119) := '28297B696628617065782E646562756728227265706F72746D61702E5F646972656374696F6E7320222B746869732E6D61726B6572732E6C656E6774682B2220776179706F696E747322292C746869732E6D61726B6572732E6C656E6774683E31297B74';
wwv_flow_api.g_varchar2_table(120) := '6869732E646972656374696F6E73446973706C61797C7C28746869732E646972656374696F6E73446973706C61793D6E657720676F6F676C652E6D6170732E446972656374696F6E7352656E64657265722C746869732E646972656374696F6E73536572';
wwv_flow_api.g_varchar2_table(121) := '766963653D6E657720676F6F676C652E6D6170732E446972656374696F6E73536572766963652C746869732E646972656374696F6E73446973706C61792E7365744D617028746869732E6D6170292C746869732E6F7074696F6E732E646972656374696F';
wwv_flow_api.g_varchar2_table(122) := '6E7350616E656C2626746869732E646972656374696F6E73446973706C61792E73657450616E656C28646F63756D656E742E676574456C656D656E744279496428746869732E6F7074696F6E732E646972656374696F6E7350616E656C2929293B666F72';
wwv_flow_api.g_varchar2_table(123) := '2876617220653D746869732E6D61726B6572735B305D2E706F736974696F6E2C743D746869732E6D61726B6572735B746869732E6D61726B6572732E6C656E6774682D315D2E706F736974696F6E2C6F3D5B5D2C693D313B693C746869732E6D61726B65';
wwv_flow_api.g_varchar2_table(124) := '72732E6C656E6774682D313B692B2B296F2E70757368287B6C6F636174696F6E3A746869732E6D61726B6572735B695D2E706F736974696F6E2C73746F706F7665723A21307D293B617065782E646562756728652C742C6F2C746869732E6F7074696F6E';
wwv_flow_api.g_varchar2_table(125) := '732E74726176656C4D6F6465293B76617220733D746869733B746869732E646972656374696F6E73536572766963652E726F757465287B6F726967696E3A652C64657374696E6174696F6E3A742C776179706F696E74733A6F2C6F7074696D697A655761';
wwv_flow_api.g_varchar2_table(126) := '79706F696E74733A746869732E6F7074696F6E732E6F7074696D697A65576179706F696E74732C74726176656C4D6F64653A676F6F676C652E6D6170732E54726176656C4D6F64655B746869732E6F7074696F6E732E74726176656C4D6F64655D2C756E';
wwv_flow_api.g_varchar2_table(127) := '697453797374656D3A676F6F676C652E6D6170732E556E697453797374656D5B746869732E6F7074696F6E732E756E697453797374656D5D7D2C2866756E6374696F6E28652C74297B732E5F646972656374696F6E73526573706F6E736528652C74297D';
wwv_flow_api.g_varchar2_table(128) := '29297D656C736520617065782E646562756728226E6F7420656E6F75676820776179706F696E7473202D206E656564206174206C6561737420616E206F726967696E20616E6420612064657374696E6174696F6E20706F696E7422297D2C64656C657465';
wwv_flow_api.g_varchar2_table(129) := '53656C656374656446656174757265733A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E64656C65746553656C6563746564466561747572657322293B76617220653D746869732E6D61702E646174613B652E666F72';
wwv_flow_api.g_varchar2_table(130) := '45616368282866756E6374696F6E2874297B742E67657450726F70657274792822697353656C65637465642229262628617065782E6465627567282272656D6F7665222C74292C652E72656D6F7665287429297D29297D2C64656C657465416C6C466561';
wwv_flow_api.g_varchar2_table(131) := '74757265733A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E64656C657465416C6C466561747572657322293B76617220653D746869732E6D61702E646174613B652E666F7245616368282866756E6374696F6E2874';
wwv_flow_api.g_varchar2_table(132) := '297B617065782E6465627567282272656D6F7665222C74292C652E72656D6F76652874297D29297D2C5F616464436F6E74726F6C3A66756E6374696F6E28652C742C6F297B76617220693D646F63756D656E742E637265617465456C656D656E74282264';
wwv_flow_api.g_varchar2_table(133) := '697622292C733D646F63756D656E742E637265617465456C656D656E74282264697622293B732E636C6173734E616D653D227265706F72746D61702D636F6E74726F6C5549222C732E7469746C653D742C692E617070656E644368696C642873293B7661';
wwv_flow_api.g_varchar2_table(134) := '7220613D646F63756D656E742E637265617465456C656D656E74282264697622293B72657475726E20612E636C6173734E616D653D227265706F72746D61702D636F6E74726F6C496E6E6572222C612E7374796C652E6261636B67726F756E64496D6167';
wwv_flow_api.g_varchar2_table(135) := '653D652C732E617070656E644368696C642861292C732E6164644576656E744C697374656E65722822636C69636B222C6F292C746869732E6D61702E636F6E74726F6C735B676F6F676C652E6D6170732E436F6E74726F6C506F736974696F6E2E544F50';
wwv_flow_api.g_varchar2_table(136) := '5F43454E5445525D2E707573682869292C697D2C5F616464436865636B626F783A66756E6374696F6E28652C742C6F297B76617220693D646F63756D656E742E637265617465456C656D656E74282264697622292C733D646F63756D656E742E63726561';
wwv_flow_api.g_varchar2_table(137) := '7465456C656D656E74282264697622293B732E636C6173734E616D653D227265706F72746D61702D636F6E74726F6C5549222C732E7469746C653D6F2C692E617070656E644368696C642873293B76617220613D646F63756D656E742E63726561746545';
wwv_flow_api.g_varchar2_table(138) := '6C656D656E74282264697622293B612E636C6173734E616D653D227265706F72746D61702D636F6E74726F6C496E6E6572222C732E617070656E644368696C642861293B766172206E3D646F63756D656E742E637265617465456C656D656E742822696E';
wwv_flow_api.g_varchar2_table(139) := '70757422293B6E2E736574417474726962757465282274797065222C22636865636B626F7822292C6E2E73657441747472696275746528226964222C652B225F222B746869732E6F7074696F6E732E726567696F6E4964292C6E2E736574417474726962';
wwv_flow_api.g_varchar2_table(140) := '75746528226E616D65222C65292C6E2E736574417474726962757465282276616C7565222C225922292C6E2E636C6173734E616D653D227265706F72746D61702D636F6E74726F6C436865636B626F78222C6E2E636C6173734E616D653D227265706F72';
wwv_flow_api.g_varchar2_table(141) := '746D61702D636865636B626F78222C612E617070656E644368696C64286E293B76617220723D646F63756D656E742E637265617465456C656D656E7428226C6162656C22293B72657475726E20722E7365744174747269627574652822666F72222C652B';
wwv_flow_api.g_varchar2_table(142) := '225F222B746869732E6F7074696F6E732E726567696F6E4964292C722E696E6E657248544D4C3D742C722E636C6173734E616D653D227265706F72746D61702D636F6E74726F6C436865636B626F784C6162656C222C612E617070656E644368696C6428';
wwv_flow_api.g_varchar2_table(143) := '72292C746869732E6D61702E636F6E74726F6C735B676F6F676C652E6D6170732E436F6E74726F6C506F736974696F6E2E544F505F43454E5445525D2E707573682869292C697D2C5F616464506F696E743A66756E6374696F6E28652C74297B61706578';
wwv_flow_api.g_varchar2_table(144) := '2E646562756728227265706F72746D61702E5F616464506F696E74222C652C74293B766172206F3D6E657720676F6F676C652E6D6170732E446174612E46656174757265287B67656F6D657472793A6E657720676F6F676C652E6D6170732E446174612E';
wwv_flow_api.g_varchar2_table(145) := '506F696E742874297D293B72657475726E20652E616464286F292C6F7D2C5F616464506F6C79676F6E3A66756E6374696F6E28652C74297B617065782E646562756728227265706F72746D61702E5F616464506F6C79676F6E222C652C74292C24282223';
wwv_flow_api.g_varchar2_table(146) := '686F6C655F222B746869732E6F7074696F6E732E726567696F6E4964292E70726F702822636865636B656422293F652E666F7245616368282866756E6374696F6E2865297B696628652E67657450726F70657274792822697353656C6563746564222929';
wwv_flow_api.g_varchar2_table(147) := '7B766172206F3D652E67657447656F6D6574727928293B69662822506F6C79676F6E223D3D6F2E676574547970652829297B76617220693D6F2E676574417272617928293B692E70757368286E657720676F6F676C652E6D6170732E446174612E4C696E';
wwv_flow_api.g_varchar2_table(148) := '65617252696E67287429292C652E73657447656F6D65747279286E657720676F6F676C652E6D6170732E446174612E506F6C79676F6E286929297D7D7D29293A652E616464286E657720676F6F676C652E6D6170732E446174612E46656174757265287B';
wwv_flow_api.g_varchar2_table(149) := '67656F6D657472793A6E657720676F6F676C652E6D6170732E446174612E506F6C79676F6E285B745D297D29297D2C5F696E697446656174757265733A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E5F696E697446';
wwv_flow_api.g_varchar2_table(150) := '6561747572657322293B76617220653D746869732C743D746869732E6D61702E646174613B742E7365745374796C6528746869732E6F7074696F6E732E666561747572655374796C65466E7C7C66756E6374696F6E2874297B766172206F3D652E6F7074';
wwv_flow_api.g_varchar2_table(151) := '696F6E732E66656174757265436F6C6F723B72657475726E20742E67657450726F70657274792822697353656C656374656422292626286F3D652E6F7074696F6E732E66656174757265436F6C6F7253656C6563746564292C7B66696C6C436F6C6F723A';
wwv_flow_api.g_varchar2_table(152) := '6F2C7374726F6B65436F6C6F723A6F2C7374726F6B655765696768743A312C647261676761626C653A652E6F7074696F6E732E6973447261676761626C652C6564697461626C653A21317D7D292C746869732E6F7074696F6E732E666561747572655365';
wwv_flow_api.g_varchar2_table(153) := '6C65637461626C652626742E6164644C697374656E65722822636C69636B222C2866756E6374696F6E2874297B617065782E646562756728227265706F72746D61702E6D61702E64617461202D20636C69636B222C74292C742E666561747572652E6765';
wwv_flow_api.g_varchar2_table(154) := '7450726F70657274792822697353656C656374656422293F28617065782E64656275672822697353656C6563746564222C2266616C736522292C742E666561747572652E72656D6F766550726F70657274792822697353656C656374656422292C617065';
wwv_flow_api.g_varchar2_table(155) := '782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E747269676765722822756E73656C65637466656174757265222C7B6D61703A652E6D61702C666561747572653A742E666561747572657D29293A28617065782E646562';
wwv_flow_api.g_varchar2_table(156) := '75672822697353656C6563746564222C227472756522292C742E666561747572652E73657450726F70657274792822697353656C6563746564222C2130292C617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E74';
wwv_flow_api.g_varchar2_table(157) := '726967676572282273656C65637466656174757265222C7B6D61703A652E6D61702C666561747572653A742E666561747572657D29297D29292C746869732E6F7074696F6E732E66656174757265486F76657261626C65262628742E6164644C69737465';
wwv_flow_api.g_varchar2_table(158) := '6E657228226D6F7573656F766572222C2866756E6374696F6E286F297B617065782E646562756728227265706F72746D61702E6D61702E64617461222C226D6F7573656F766572222C6F292C742E7265766572745374796C6528292C742E6F7665727269';
wwv_flow_api.g_varchar2_table(159) := '64655374796C65286F2E666561747572652C7B7374726F6B655765696768743A347D292C617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6F7573656F76657266656174757265222C7B';
wwv_flow_api.g_varchar2_table(160) := '6D61703A652E6D61702C666561747572653A6F2E666561747572657D297D29292C742E6164644C697374656E657228226D6F7573656F7574222C2866756E6374696F6E286F297B617065782E646562756728227265706F72746D61702E6D61702E646174';
wwv_flow_api.g_varchar2_table(161) := '61222C226D6F7573656F7574222C6F292C742E7265766572745374796C6528292C617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6F7573656F757466656174757265222C7B6D61703A';
wwv_flow_api.g_varchar2_table(162) := '652E6D61702C666561747572653A6F2E666561747572657D297D2929297D2C5F696E697444726177696E673A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E5F696E697444726177696E67222C746869732E6F707469';
wwv_flow_api.g_varchar2_table(163) := '6F6E732E64726177696E674D6F646573293B76617220653D746869732C743D746869732E6D61702E646174613B746869732E6F7074696F6E732E64726177696E674D6F6465732E696E6465784F662822706F6C79676F6E22293E2D312626746869732E5F';
wwv_flow_api.g_varchar2_table(164) := '616464436865636B626F782822686F6C65222C22486F6C65222C22537562747261637420686F6C652066726F6D20706F6C79676F6E22292C746869732E5F616464436F6E74726F6C282275726C2827646174613A696D6167652F706E673B626173653634';
wwv_flow_api.g_varchar2_table(165) := '2C6956424F5277304B47676F414141414E53556845556741414142514141414155434159414141434E6952304E4141414135456C45515651346A63335550306F445152544838553955524753783941536577636F7A3541414C3972596578633454324668';
wwv_flow_api.g_varchar2_table(166) := '593667454530544D49515332564645484567435970664D553632637A2B3053492F4750627866722F35386D59596C6E58586F4D4576635A4430486E477861734E57426E61455935776C2F564D38343759726342393375456E36682B473130676A7A6A6D75';
wwv_flow_api.g_varchar2_table(167) := '5541773537414963353441616D45587A4264645433666F342F6A393554314E50593877745131517A6A714D65346A506F68466C776C6D566B4F43472F7833634F6B78702B455638332B47566A304152622F50654532766D7238542B7A30415A4A6365454E';
wwv_flow_api.g_varchar2_table(168) := '324A664331416449355732722F714D73324579346449364F6C624E33767138414A646975395458776E75512B6334373344414775674256376F5757476D766964634141414141456C46546B5375516D43432729222C2244656C6574652073656C65637465';
wwv_flow_api.g_varchar2_table(169) := '64206665617475726573222C2866756E6374696F6E2874297B652E64656C65746553656C6563746564466561747572657328297D29293B766172206F3D6E657720676F6F676C652E6D6170732E64726177696E672E44726177696E674D616E6167657228';
wwv_flow_api.g_varchar2_table(170) := '7B64726177696E67436F6E74726F6C4F7074696F6E733A7B706F736974696F6E3A676F6F676C652E6D6170732E436F6E74726F6C506F736974696F6E2E544F505F43454E5445522C64726177696E674D6F6465733A746869732E6F7074696F6E732E6472';
wwv_flow_api.g_varchar2_table(171) := '6177696E674D6F6465737D7D293B6F2E7365744D617028746869732E6D6170292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572286F2C226F7665726C6179636F6D706C657465222C2866756E6374696F6E286F297B73776974';
wwv_flow_api.g_varchar2_table(172) := '636828617065782E646562756728227265706F72746D61702E6F7665726C6179636F6D706C657465222C6F292C6F2E74797065297B6361736520676F6F676C652E6D6170732E64726177696E672E4F7665726C6179547970652E4D41524B45523A652E5F';
wwv_flow_api.g_varchar2_table(173) := '616464506F696E7428742C6F2E6F7665726C61792E676574506F736974696F6E2829293B627265616B3B6361736520676F6F676C652E6D6170732E64726177696E672E4F7665726C6179547970652E504F4C59474F4E3A76617220693D6F2E6F7665726C';
wwv_flow_api.g_varchar2_table(174) := '61792E6765745061746828292E676574417272617928293B652E5F616464506F6C79676F6E28742C69293B627265616B3B6361736520676F6F676C652E6D6170732E64726177696E672E4F7665726C6179547970652E52454354414E474C453A76617220';
wwv_flow_api.g_varchar2_table(175) := '733D6F2E6F7665726C61792E676574426F756E647328293B693D5B732E676574536F7574685765737428292C7B6C61743A732E676574536F7574685765737428292E6C617428292C6C6E673A732E6765744E6F7274684561737428292E6C6E6728297D2C';
wwv_flow_api.g_varchar2_table(176) := '732E6765744E6F7274684561737428292C7B6C6E673A732E676574536F7574685765737428292E6C6E6728292C6C61743A732E6765744E6F7274684561737428292E6C617428297D5D3B652E5F616464506F6C79676F6E28742C69293B627265616B3B63';
wwv_flow_api.g_varchar2_table(177) := '61736520676F6F676C652E6D6170732E64726177696E672E4F7665726C6179547970652E504F4C594C494E453A742E616464286E657720676F6F676C652E6D6170732E446174612E46656174757265287B67656F6D657472793A6E657720676F6F676C65';
wwv_flow_api.g_varchar2_table(178) := '2E6D6170732E446174612E4C696E65537472696E67286F2E6F7665726C61792E6765745061746828292E67657441727261792829297D29293B627265616B3B6361736520676F6F676C652E6D6170732E64726177696E672E4F7665726C6179547970652E';
wwv_flow_api.g_varchar2_table(179) := '434952434C453A742E616464286E657720676F6F676C652E6D6170732E446174612E46656174757265287B70726F706572746965733A7B7261646975733A6F2E6F7665726C61792E67657452616469757328297D2C67656F6D657472793A6E657720676F';
wwv_flow_api.g_varchar2_table(180) := '6F676C652E6D6170732E446174612E506F696E74286F2E6F7665726C61792E67657443656E7465722829297D29297D6F2E6F7665726C61792E7365744D6170286E756C6C297D29292C742E7365745374796C65282866756E6374696F6E2874297B766172';
wwv_flow_api.g_varchar2_table(181) := '206F2C693D652E6F7074696F6E732E66656174757265436F6C6F722C733D21313B72657475726E20742E67657450726F70657274792822697353656C65637465642229262628693D652E6F7074696F6E732E66656174757265436F6C6F7253656C656374';
wwv_flow_api.g_varchar2_table(182) := '65642C733D2124282223686F6C655F222B652E6F7074696F6E732E726567696F6E4964292E70726F702822636865636B65642229292C6F3D7B66696C6C436F6C6F723A692C7374726F6B65436F6C6F723A692C7374726F6B655765696768743A317D2C65';
wwv_flow_api.g_varchar2_table(183) := '2E6F7074696F6E732E666561747572655374796C65466E2626242E657874656E64286F2C652E6F7074696F6E732E666561747572655374796C65466E287429292C242E657874656E64286F2C7B647261676761626C653A732C6564697461626C653A737D';
wwv_flow_api.g_varchar2_table(184) := '297D29292C742E6164644C697374656E6572282261646466656174757265222C2866756E6374696F6E2874297B617065782E646562756728227265706F72746D61702E6D61702E64617461222C2261646466656174757265222C74292C617065782E6A51';
wwv_flow_api.g_varchar2_table(185) := '75657279282223222B652E6F7074696F6E732E726567696F6E4964292E74726967676572282261646466656174757265222C7B6D61703A652E6D61702C666561747572653A742E666561747572657D297D29292C742E6164644C697374656E6572282272';
wwv_flow_api.g_varchar2_table(186) := '656D6F766566656174757265222C2866756E6374696F6E2874297B617065782E646562756728227265706F72746D61702E6D61702E64617461222C2272656D6F766566656174757265222C74292C617065782E6A5175657279282223222B652E6F707469';
wwv_flow_api.g_varchar2_table(187) := '6F6E732E726567696F6E4964292E74726967676572282272656D6F766566656174757265222C7B6D61703A652E6D61702C666561747572653A742E666561747572657D297D29292C742E6164644C697374656E6572282273657467656F6D65747279222C';
wwv_flow_api.g_varchar2_table(188) := '2866756E6374696F6E2874297B617065782E646562756728227265706F72746D61702E6D61702E64617461222C2273657467656F6D65747279222C74292C617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E7472';
wwv_flow_api.g_varchar2_table(189) := '6967676572282273657467656F6D65747279222C7B6D61703A652E6D61702C666561747572653A742E666561747572652C6E657747656F6D657472793A742E6E657747656F6D657472792C6F6C6447656F6D657472793A742E6F6C6447656F6D65747279';
wwv_flow_api.g_varchar2_table(190) := '7D297D29292C646F63756D656E742E6164644576656E744C697374656E657228226B6579646F776E222C2866756E6374696F6E2874297B2244656C657465223D3D3D742E6B65792626652E64656C65746553656C6563746564466561747572657328297D';
wwv_flow_api.g_varchar2_table(191) := '29297D2C5F70726F63657373506F696E74733A66756E6374696F6E28652C742C6F297B76617220693D746869733B6520696E7374616E63656F6620676F6F676C652E6D6170732E4C61744C6E673F742E63616C6C286F2C65293A6520696E7374616E6365';
wwv_flow_api.g_varchar2_table(192) := '6F6620676F6F676C652E6D6170732E446174612E506F696E743F742E63616C6C286F2C652E6765742829293A652E676574417272617928292E666F7245616368282866756E6374696F6E2865297B692E5F70726F63657373506F696E747328652C742C6F';
wwv_flow_api.g_varchar2_table(193) := '297D29297D2C5F6C6F616447656F4A736F6E3A66756E6374696F6E28652C742C6F297B617065782E646562756728225F6C6F616447656F4A736F6E222C65293B6C657420693D746869732E6D61702E646174612E61646447656F4A736F6E28652C6F293B';
wwv_flow_api.g_varchar2_table(194) := '76617220733D746869733B746869732E6D61702E646174612E666F7245616368282866756E6374696F6E2865297B732E5F70726F63657373506F696E747328652E67657447656F6D6574727928292C732E626F756E64732E657874656E642C732E626F75';
wwv_flow_api.g_varchar2_table(195) := '6E6473297D29292C746869732E6F7074696F6E732E6175746F466974426F756E64732626746869732E6D61702E666974426F756E647328746869732E626F756E6473292C617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567';
wwv_flow_api.g_varchar2_table(196) := '696F6E4964292E7472696767657228226C6F6164656467656F6A736F6E222C7B6D61703A746869732E6D61702C67656F4A736F6E3A652C66656174757265733A692C66696C656E616D653A747D297D2C6C6F616447656F4A736F6E537472696E673A6675';
wwv_flow_api.g_varchar2_table(197) := '6E6374696F6E28652C74297B696628617065782E646562756728227265706F72746D61702E6C6F616447656F4A736F6E537472696E67222C652C74292C65297B766172206F3D4A534F4E2E70617273652865293B746869732E626F756E64733D6E657720';
wwv_flow_api.g_varchar2_table(198) := '676F6F676C652E6D6170732E4C61744C6E67426F756E64732C746869732E5F6C6F616447656F4A736F6E286F2C74297D7D2C5F696E69744472616744726F7047656F4A534F4E3A66756E6374696F6E28297B617065782E646562756728227265706F7274';
wwv_flow_api.g_varchar2_table(199) := '6D61702E5F696E69744472616744726F7047656F4A534F4E22293B76617220653D746869732C743D646F63756D656E742E676574456C656D656E744279496428226D61705F222B746869732E6F7074696F6E732E726567696F6E4964292C6F3D646F6375';
wwv_flow_api.g_varchar2_table(200) := '6D656E742E676574456C656D656E7442794964282264726F705F222B746869732E6F7074696F6E732E726567696F6E4964292C693D66756E6374696F6E2865297B72657475726E20652E73746F7050726F7061676174696F6E28292C652E70726576656E';
wwv_flow_api.g_varchar2_table(201) := '7444656661756C7428292C6F2E7374796C652E646973706C61793D22626C6F636B222C21317D3B742E6164644576656E744C697374656E6572282264726167656E746572222C692C2131292C6F2E6164644576656E744C697374656E6572282264726167';
wwv_flow_api.g_varchar2_table(202) := '6F766572222C692C2131292C6F2E6164644576656E744C697374656E65722822647261676C65617665222C2866756E6374696F6E28297B6F2E7374796C652E646973706C61793D226E6F6E65227D292C2131292C6F2E6164644576656E744C697374656E';
wwv_flow_api.g_varchar2_table(203) := '6572282264726F70222C2866756E6374696F6E2874297B617065782E646562756728227265706F72746D61702E64726F70222C74292C742E70726576656E7444656661756C7428292C742E73746F7050726F7061676174696F6E28292C6F2E7374796C65';
wwv_flow_api.g_varchar2_table(204) := '2E646973706C61793D226E6F6E65223B76617220693D742E646174615472616E736665722E66696C65733B696628692E6C656E67746829666F722876617220732C613D303B733D695B615D3B612B2B297B766172206E3D6E65772046696C655265616465';
wwv_flow_api.g_varchar2_table(205) := '722C723D732E6E616D653B6E2E6F6E6C6F61643D66756E6374696F6E2874297B652E6C6F616447656F4A736F6E537472696E6728742E7461726765742E726573756C742C72297D2C6E2E6F6E6572726F723D66756E6374696F6E2865297B617065782E65';
wwv_flow_api.g_varchar2_table(206) := '72726F72282272656164696E67206661696C656422297D2C6E2E726561644173546578742873297D656C73657B76617220703D742E646174615472616E736665722E676574446174612822746578742F706C61696E22293B702626652E6C6F616447656F';
wwv_flow_api.g_varchar2_table(207) := '4A736F6E537472696E672870297D72657475726E21317D292C2131297D2C5F696E697444656275673A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E5F696E6974446562756722293B76617220653D746869732C743D';
wwv_flow_api.g_varchar2_table(208) := '646F63756D656E742E637265617465456C656D656E74282264697622293B742E636C6173734E616D653D227265706F72746D61702D646562756750616E656C222C742E696E6E657248544D4C3D225B6465627567206D6F64655D222C746869732E6D6170';
wwv_flow_api.g_varchar2_table(209) := '2E636F6E74726F6C735B676F6F676C652E6D6170732E436F6E74726F6C506F736974696F6E2E424F54544F4D5F4C4546545D2E707573682874292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228746869732E6D61702C226D';
wwv_flow_api.g_varchar2_table(210) := '6F7573656D6F7665222C2866756E6374696F6E2865297B742E696E6E657248544D4C3D226D6F75736520706F736974696F6E20222B4A534F4E2E737472696E6769667928652E6C61744C6E67297D29292C676F6F676C652E6D6170732E6576656E742E61';
wwv_flow_api.g_varchar2_table(211) := '64644C697374656E657228746869732E6D61702C22626F756E64735F6368616E676564222C2866756E6374696F6E286F297B742E696E6E657248544D4C3D226D617020626F756E647320222B4A534F4E2E737472696E6769667928652E6D61702E676574';
wwv_flow_api.g_varchar2_table(212) := '426F756E64732829297D29297D2C5F67657457696E646F77506174683A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E5F67657457696E646F775061746822293B76617220653D746869732E6F7074696F6E732E706C';
wwv_flow_api.g_varchar2_table(213) := '7567696E5265736F75726365506174683B72657475726E2222213D3D653F617065782E646562756728225573696E6720737570706C69656420706C7567696E207265736F75726365207061746822293A28653D77696E646F772E6C6F636174696F6E2E6F';
wwv_flow_api.g_varchar2_table(214) := '726967696E2B77696E646F772E6C6F636174696F6E2E706174686E616D65292E696E6465784F6628222F6F7264732F722F22293E2D313F28617065782E64656275672822467269656E646C792055524C2064657465637465642028686F7374656420636C';
wwv_flow_api.g_varchar2_table(215) := '6F756429222C65292C653D652E737562737472696E6728302C652E6C617374496E6465784F6628222F722F222929293A652E696E6465784F6628222F722F22293E2D313F28617065782E64656275672822467269656E646C792055524C20646574656374';
wwv_flow_api.g_varchar2_table(216) := '6564222C65292C653D28653D652E737562737472696E6728302C652E6C617374496E6465784F6628222F722F222929292E737562737472696E6728302C652E6C617374496E6465784F6628222F222929293A28617065782E646562756728224C65676163';
wwv_flow_api.g_varchar2_table(217) := '792055524C206465746563746564222C65292C653D652E737562737472696E6728302C652E6C617374496E6465784F6628222F222929292C617065782E6465627567282270617468222C65292C657D2C5F696E69744D61704576656E74733A66756E6374';
wwv_flow_api.g_varchar2_table(218) := '696F6E28297B76617220653D746869733B5B22626F756E64735F6368616E676564222C2263656E7465725F6368616E676564222C2268656164696E675F6368616E676564222C2269646C65222C226D61707479706569645F6368616E676564222C227072';
wwv_flow_api.g_varchar2_table(219) := '6F6A656374696F6E5F6368616E676564222C2274696C65736C6F61646564222C2274696C745F6368616E676564222C227A6F6F6D5F6368616E676564225D2E666F7245616368282866756E6374696F6E2874297B617065782E6465627567282261646420';
wwv_flow_api.g_varchar2_table(220) := '6C697374656E657220666F72206D617020222B74292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228652E6D61702C742C2866756E6374696F6E28297B617065782E646562756728226D617020222B74293B766172206F3D65';
wwv_flow_api.g_varchar2_table(221) := '2E6D61702E676574426F756E647328293B617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6170222B742C7B6D61703A652E6D61702C63656E7465723A652E6D61702E67657443656E74';
wwv_flow_api.g_varchar2_table(222) := '657228292E746F4A534F4E28292C736F757468776573743A6F2E676574536F7574685765737428292E746F4A534F4E28292C6E6F727468656173743A6F2E6765744E6F7274684561737428292E746F4A534F4E28292C7A6F6F6D3A652E6D61702E676574';
wwv_flow_api.g_varchar2_table(223) := '5A6F6F6D28292C68656164696E673A652E6D61702E67657448656164696E6728292C74696C743A652E6D61702E67657454696C7428292C6D6170547970653A652E6D61702E6765744D617054797065496428297D297D29297D29292C746869732E6F7074';
wwv_flow_api.g_varchar2_table(224) := '696F6E732E64657461696C65644D6F7573654576656E74732626285B2264726167222C2264726167656E64222C22647261677374617274225D2E666F7245616368282866756E6374696F6E2874297B617065782E64656275672822616464206C69737465';
wwv_flow_api.g_varchar2_table(225) := '6E657220666F72206D617020222B74292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228652E6D61702C742C2866756E6374696F6E28297B617065782E646562756728226D617020222B74293B766172206F3D652E6D61702E';
wwv_flow_api.g_varchar2_table(226) := '676574426F756E647328293B617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6170222B742C7B6D61703A652E6D61702C63656E7465723A652E6D61702E67657443656E74657228292E';
wwv_flow_api.g_varchar2_table(227) := '746F4A534F4E28292C736F757468776573743A6F2E676574536F7574685765737428292E746F4A534F4E28292C6E6F727468656173743A6F2E6765744E6F7274684561737428292E746F4A534F4E28292C7A6F6F6D3A652E6D61702E6765745A6F6F6D28';
wwv_flow_api.g_varchar2_table(228) := '292C68656164696E673A652E6D61702E67657448656164696E6728292C74696C743A652E6D61702E67657454696C7428292C6D6170547970653A652E6D61702E6765744D617054797065496428297D297D29297D29292C5B22636F6E746578746D656E75';
wwv_flow_api.g_varchar2_table(229) := '222C2264626C636C69636B222C226D6F7573656D6F7665222C226D6F7573656F7574222C226D6F7573656F766572225D2E666F7245616368282866756E6374696F6E2874297B617065782E64656275672822616464206C697374656E657220666F72206D';
wwv_flow_api.g_varchar2_table(230) := '617020222B74292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228652E6D61702C742C2866756E6374696F6E286F297B617065782E646562756728226D617020222B742C6F2E6C61744C6E67292C617065782E6A5175657279';
wwv_flow_api.g_varchar2_table(231) := '282223222B652E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6170222B742C7B6D61703A652E6D61702C6C61743A6F2E6C61744C6E672E6C617428292C6C6E673A6F2E6C61744C6E672E6C6E6728297D297D29297D2929292C61';
wwv_flow_api.g_varchar2_table(232) := '7065782E64656275672822616464206C697374656E657220666F72206D617020636C69636B22292C676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228746869732E6D61702C22636C69636B222C2866756E6374696F6E2874297B';
wwv_flow_api.g_varchar2_table(233) := '617065782E646562756728226D617020636C69636B222C742E6C61744C6E67292C652E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C262628652E6F7074696F6E732E70616E4F6E436C69636B2626652E6D61702E70616E546F28742E6C61744C';
wwv_flow_api.g_varchar2_table(234) := '6E67292C652E6D61702E7365745A6F6F6D28652E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C29292C617065782E6A5175657279282223222B652E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6170636C69636B222C';
wwv_flow_api.g_varchar2_table(235) := '7B6D61703A652E6D61702C6C61743A742E6C61744C6E672E6C617428292C6C6E673A742E6C61744C6E672E6C6E6728297D297D29297D2C5F6372656174653A66756E6374696F6E28297B617065782E646562756728227265706F72746D61702E5F637265';
wwv_flow_api.g_varchar2_table(236) := '617465222C746869732E656C656D656E742E70726F70282269642229292C617065782E6465627567284A534F4E2E737472696E6769667928746869732E6F7074696F6E7329293B76617220653D746869733B746869732E696D6167655072656669783D74';
wwv_flow_api.g_varchar2_table(237) := '6869732E5F67657457696E646F775061746828292B222F222B746869732E6F7074696F6E732E706C7567696E46696C655072656669782B22696D616765732F6D222C617065782E64656275672822696D616765507265666978222C746869732E696D6167';
wwv_flow_api.g_varchar2_table(238) := '65507265666978293B76617220743D7B6D696E5A6F6F6D3A746869732E6F7074696F6E732E6D696E5A6F6F6D2C6D61785A6F6F6D3A746869732E6F7074696F6E732E6D61785A6F6F6D2C7A6F6F6D3A746869732E6F7074696F6E732E696E697469616C5A';
wwv_flow_api.g_varchar2_table(239) := '6F6F6D2C63656E7465723A746869732E6F7074696F6E732E696E697469616C43656E7465722C6D61705479706549643A746869732E6F7074696F6E732E6D6170547970652C647261676761626C653A746869732E6F7074696F6E732E616C6C6F7750616E';
wwv_flow_api.g_varchar2_table(240) := '2C7A6F6F6D436F6E74726F6C3A746869732E6F7074696F6E732E616C6C6F775A6F6F6D2C7363726F6C6C776865656C3A746869732E6F7074696F6E732E616C6C6F775A6F6F6D2C64697361626C65446F75626C65436C69636B5A6F6F6D3A21746869732E';
wwv_flow_api.g_varchar2_table(241) := '6F7074696F6E732E616C6C6F775A6F6F6D2C6765737475726548616E646C696E673A746869732E6F7074696F6E732E6765737475726548616E646C696E677D3B696628746869732E6F7074696F6E732E6D61705374796C65262628742E7374796C65733D';
wwv_flow_api.g_varchar2_table(242) := '746869732E6F7074696F6E732E6D61705374796C65292C746869732E6D61703D6E657720676F6F676C652E6D6170732E4D617028646F63756D656E742E676574456C656D656E744279496428746869732E656C656D656E742E70726F7028226964222929';
wwv_flow_api.g_varchar2_table(243) := '2C74292C22696E666F6C61796572223D3D746869732E6F7074696F6E732E76697375616C69736174696F6E262628746869732E6F7074696F6E732E73686F7750696E733D21312C746869732E6F7074696F6E732E73686F77496E666F506F707570733D21';
wwv_flow_api.g_varchar2_table(244) := '312C746869732E6F7074696F6E732E73686F77496E666F4C617965723D2130292C746869732E6F7074696F6E732E696E6974466E262628617065782E64656275672822696E69745F6A6176617363726970745F636F64652072756E6E696E672E2E2E2229';
wwv_flow_api.g_varchar2_table(245) := '2C746869732E696E69743D746869732E6F7074696F6E732E696E6974466E2C746869732E696E697428292C746869732E696E69742E64656C6574652C617065782E64656275672822696E69745F6A6176617363726970745F636F64652066696E69736865';
wwv_flow_api.g_varchar2_table(246) := '642E2229292C746869732E5F696E6974466561747572657328292C746869732E6F7074696F6E732E64726177696E674D6F6465732626746869732E5F696E697444726177696E6728292C746869732E6F7074696F6E732E6472616744726F7047656F4A53';
wwv_flow_api.g_varchar2_table(247) := '4F4E2626746869732E5F696E69744472616744726F7047656F4A534F4E28292C617065782E64656275672E6765744C6576656C28293E302626746869732E5F696E6974446562756728292C746869732E6F7074696F6E732E657870656374446174612626';
wwv_flow_api.g_varchar2_table(248) := '746869732E7265667265736828292C746869732E5F696E69744D61704576656E747328292C617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E62696E6428226170657872656672657368222C2866756E63';
wwv_flow_api.g_varchar2_table(249) := '74696F6E28297B242822236D61705F222B652E6F7074696F6E732E726567696F6E4964292E7265706F72746D617028227265667265736822297D29292C617065782E64656275672E6765744C6576656C28293E30297B766172206F3D27242822236D6170';
wwv_flow_api.g_varchar2_table(250) := '5F272B652E6F7074696F6E732E726567696F6E49642B2722292E7265706F72746D61702822696E7374616E636522292E6D6170273B617065782E6465627567282225635468616E6B20796F7520666F72207573696E6720746865206A6B3634205265706F';
wwv_flow_api.g_varchar2_table(251) := '7274204D617020706C7567696E215C6E546F206163636573732074686520476F6F676C65204D6170206F626A656374206F6E207468697320706167652C207573653A5C6E222B6F2B225C6E4D6F726520696E666F3A2068747470733A2F2F676974687562';
wwv_flow_api.g_varchar2_table(252) := '2E636F6D2F6A6566667265796B656D702F6A6B36342D706C7567696E2D7265706F72746D61702F77696B69222C22666F6E742D73697A653A313870783B6261636B67726F756E642D636F6C6F723A233030373666663B636F6C6F723A77686974653B6C69';
wwv_flow_api.g_varchar2_table(253) := '6E652D6865696768743A333070783B646973706C61793A626C6F636B3B70616464696E673A313070783B22297D617065782E646562756728227265706F72746D61702E5F6372656174652066696E697368656422297D2C5F616674657252656672657368';
wwv_flow_api.g_varchar2_table(254) := '3A66756E6374696F6E28297B617065782E646562756728225F61667465725265667265736822292C746869732E7370696E6E6572262628617065782E6465627567282272656D6F7665207370696E6E657222292C746869732E7370696E6E65722E72656D';
wwv_flow_api.g_varchar2_table(255) := '6F76652829292C617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226170657861667465727265667265736822292C746869732E5F7472696767657228226368616E676522297D2C5F';
wwv_flow_api.g_varchar2_table(256) := '72656E646572506167653A66756E6374696F6E28652C74297B696628617065782E646562756728225F72656E64657250616765222C74292C652E6D617064617461297B766172206F3B696628617065782E6465627567282270446174612E6D6170646174';
wwv_flow_api.g_varchar2_table(257) := '61206C656E6774683A222C652E6D6170646174612E6C656E677468292C652E6D6170646174612E6C656E6774683E30297B666F722876617220693D303B693C652E6D6170646174612E6C656E6774683B692B2B297B696628652E6D6170646174615B695D';
wwv_flow_api.g_varchar2_table(258) := '2E6572726F72297B6F3D652E6D6170646174615B695D2E6572726F723B627265616B7D76617220733D652E6D6170646174615B695D3B69662822686561746D6170223D3D746869732E6F7074696F6E732E76697375616C69736174696F6E29735B305D26';
wwv_flow_api.g_varchar2_table(259) := '26735B315D262628746869732E626F756E64732E657874656E64287B6C61743A735B305D2C6C6E673A735B315D7D292C746869732E77656967687465644C6F636174696F6E732E70757368287B6C6F636174696F6E3A6E657720676F6F676C652E6D6170';
wwv_flow_api.g_varchar2_table(260) := '732E4C61744C6E6728735B305D2C735B315D292C7765696768743A735B325D7D29293B656C7365206966282267656F6A736F6E223D3D746869732E6F7074696F6E732E76697375616C69736174696F6E297B76617220613D7B7D3B696628732E6E262628';
wwv_flow_api.g_varchar2_table(261) := '612E6E616D653D732E6E292C732E64262628612E69643D732E64292C732E6629666F7228766172206E3D313B6E3C3D31303B6E2B2B29732E665B2261222B6E5D262628615B2261747472222B282230222B6E292E736C696365282D32295D3D732E665B22';
wwv_flow_api.g_varchar2_table(262) := '61222B6E5D293B242E657874656E6428732E67656F6A736F6E2C7B70726F706572746965733A617D292C746869732E5F6C6F616447656F4A736F6E28732E67656F6A736F6E2C6E756C6C2C7B696450726F70657274794E616D653A226964227D297D656C';
wwv_flow_api.g_varchar2_table(263) := '736520696628732E782626732E79297B746869732E626F756E64732E657874656E64287B6C61743A732E782C6C6E673A732E797D293B76617220723D746869732E5F6E65774D61726B65722873293B746869732E6D61726B6572732E707573682872292C';
wwv_flow_api.g_varchar2_table(264) := '732E642626746869732E6E657749644D61702E73657428732E642C69297D7D746869732E6F7074696F6E732E6175746F466974426F756E6473262628617065782E64656275672822666974426F756E6473222C746869732E626F756E64732E676574536F';
wwv_flow_api.g_varchar2_table(265) := '7574685765737428292E746F4A534F4E28292C746869732E626F756E64732E6765744E6F7274684561737428292E746F4A534F4E2829292C746869732E6D61702E666974426F756E647328746869732E626F756E647329292C746869732E746F74616C52';
wwv_flow_api.g_varchar2_table(266) := '6F77732B3D652E6D6170646174612E6C656E6774687D6966286F29617065782E64656275672E6572726F72286F292C746869732E73686F774D657373616765286F292C64656C65746520746869732E6E657749644D61702C746869732E5F616674657252';
wwv_flow_api.g_varchar2_table(267) := '65667265736828293B656C736520696628746869732E746F74616C526F77733C746869732E6F7074696F6E732E6D6178696D756D526F77732626652E6D6170646174612E6C656E6774683D3D746869732E6F7074696F6E732E726F777350657242617463';
wwv_flow_api.g_varchar2_table(268) := '68297B617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E74726967676572282262617463686C6F61646564222C7B6D61703A746869732E6D61702C636F756E7450696E733A746869732E746F74616C526F';
wwv_flow_api.g_varchar2_table(269) := '77732C736F757468776573743A746869732E626F756E64732E676574536F7574685765737428292E746F4A534F4E28292C6E6F727468656173743A746869732E626F756E64732E6765744E6F7274684561737428292E746F4A534F4E28297D292C742B3D';
wwv_flow_api.g_varchar2_table(270) := '746869732E6F7074696F6E732E726F777350657242617463683B76617220703D746869732E6F7074696F6E732E726F777350657242617463683B746869732E746F74616C526F77732B703E746869732E6F7074696F6E732E6D6178696D756D526F777326';
wwv_flow_api.g_varchar2_table(271) := '2628703D746869732E6F7074696F6E732E6D6178696D756D526F77732D746869732E746F74616C526F7773293B76617220643D746869733B617065782E7365727665722E706C7567696E28746869732E6F7074696F6E732E616A61784964656E74696669';
wwv_flow_api.g_varchar2_table(272) := '65722C7B706167654974656D733A746869732E6F7074696F6E732E616A61784974656D732C7830313A742C7830323A707D2C7B64617461547970653A226A736F6E222C737563636573733A66756E6374696F6E2865297B617065782E646562756728226E';
wwv_flow_api.g_varchar2_table(273) := '65787420626174636820726563656976656422292C642E5F72656E6465725061676528652C74297D7D297D656C73657B696628303D3D746869732E746F74616C526F77732964656C65746520746869732E69644D61702C2222213D3D746869732E6F7074';
wwv_flow_api.g_varchar2_table(274) := '696F6E732E6E6F446174614D657373616765262628617065782E6465627567282273686F77204E6F204461746120466F756E6420696E666F77696E646F7722292C746869732E73686F774D65737361676528746869732E6F7074696F6E732E6E6F446174';
wwv_flow_api.g_varchar2_table(275) := '614D65737361676529293B656C73652073776974636828746869732E6F7074696F6E732E76697375616C69736174696F6E297B6361736522646972656374696F6E73223A746869732E5F646972656374696F6E7328293B627265616B3B6361736522636C';
wwv_flow_api.g_varchar2_table(276) := '7573746572223A746869732E6D61726B6572436C75737465726572262628617065782E646562756728226D61726B6572436C757374657265722E636C6561724D61726B65727322292C746869732E6D61726B6572436C757374657265722E636C6561724D';
wwv_flow_api.g_varchar2_table(277) := '61726B6572732829292C617065782E64656275672822637265617465206D61726B6572436C7573746572657222292C746869732E6D61726B6572436C757374657265723D6E6577204D61726B6572436C7573746572657228746869732E6D61702C746869';
wwv_flow_api.g_varchar2_table(278) := '732E6D61726B6572732C7B696D616765506174683A746869732E696D6167655072656669787D293B627265616B3B636173652273706964657266696572223A746869732E5F737069646572667928293B627265616B3B6361736522686561746D6170223A';
wwv_flow_api.g_varchar2_table(279) := '746869732E686561746D61704C61796572262628617065782E6465627567282272656D6F766520686561746D61704C6179657222292C746869732E686561746D61704C617965722E7365744D6170286E756C6C292C746869732E686561746D61704C6179';
wwv_flow_api.g_varchar2_table(280) := '65722E64656C657465292C746869732E686561746D61704C617965723D6E657720676F6F676C652E6D6170732E76697375616C697A6174696F6E2E486561746D61704C61796572287B646174613A746869732E77656967687465644C6F636174696F6E73';
wwv_flow_api.g_varchar2_table(281) := '2C6D61703A746869732E6D61702C6469737369706174696E673A746869732E6F7074696F6E732E686561746D61704469737369706174696E672C6F7061636974793A746869732E6F7074696F6E732E686561746D61704F7061636974792C726164697573';
wwv_flow_api.g_varchar2_table(282) := '3A746869732E6F7074696F6E732E686561746D61705261646975737D292C746869732E77656967687465644C6F636174696F6E732E64656C6574657D617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E74';
wwv_flow_api.g_varchar2_table(283) := '72696767657228746869732E6D61706C6F616465643F226D6170726566726573686564223A226D61706C6F61646564222C7B6D61703A746869732E6D61702C636F756E7450696E733A746869732E746F74616C526F77732C736F757468776573743A7468';
wwv_flow_api.g_varchar2_table(284) := '69732E626F756E64732E676574536F7574685765737428292E746F4A534F4E28292C6E6F727468656173743A746869732E626F756E64732E6765744E6F7274684561737428292E746F4A534F4E28297D292C746869732E6D61706C6F616465643D21302C';
wwv_flow_api.g_varchar2_table(285) := '746869732E69644D61703D746869732E6E657749644D61702C64656C65746520746869732E6E657749644D61702C746869732E5F61667465725265667265736828297D7D656C736520746869732E5F61667465725265667265736828297D2C7265667265';
wwv_flow_api.g_varchar2_table(286) := '73683A66756E6374696F6E28297B696628617065782E646562756728227265706F72746D61702E7265667265736822292C746869732E686964654D65737361676528292C746869732E6F7074696F6E732E65787065637444617461297B617065782E6A51';
wwv_flow_api.g_varchar2_table(287) := '75657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E747269676765722822617065786265666F72657265667265736822292C746869732E6F7074696F6E732E73686F775370696E6E6572262628746869732E7370696E6E6572';
wwv_flow_api.g_varchar2_table(288) := '2626746869732E7370696E6E65722E72656D6F766528292C617065782E6465627567282273686F77207370696E6E657222292C746869732E7370696E6E65723D617065782E7574696C2E73686F775370696E6E65722824282223222B746869732E6F7074';
wwv_flow_api.g_varchar2_table(289) := '696F6E732E726567696F6E49642929293B76617220653D746869732C743D746869732E6F7074696F6E732E726F777350657242617463683B746869732E6F7074696F6E732E6D6178696D756D526F77733C74262628743D746869732E6F7074696F6E732E';
wwv_flow_api.g_varchar2_table(290) := '6D6178696D756D526F7773292C617065782E7365727665722E706C7567696E28746869732E6F7074696F6E732E616A61784964656E7469666965722C7B706167654974656D733A746869732E6F7074696F6E732E616A61784974656D732C7830313A312C';
wwv_flow_api.g_varchar2_table(291) := '7830323A747D2C7B64617461547970653A226A736F6E222C737563636573733A66756E6374696F6E2874297B617065782E64656275672822666972737420626174636820726563656976656422292C652E5F72656D6F76654D61726B65727328292C652E';
wwv_flow_api.g_varchar2_table(292) := '77656967687465644C6F636174696F6E733D5B5D2C652E6D61726B6572733D5B5D2C652E626F756E64733D6E657720676F6F676C652E6D6170732E4C61744C6E67426F756E64732C652E6E657749644D61703D6E6577204D61702C742E6D617064617461';
wwv_flow_api.g_varchar2_table(293) := '2626742E6D6170646174615B305D2626742E6D6170646174615B305D2E6572726F723F28652E73686F774D65737361676528742E6D6170646174615B305D2E6572726F72292C652E5F6166746572526566726573682829293A652E5F72656E6465725061';
wwv_flow_api.g_varchar2_table(294) := '676528742C31297D7D297D656C736520746869732E5F61667465725265667265736828297D2C5F64657374726F793A66756E6374696F6E28297B746869732E686561746D61704C617965722626746869732E686561746D61704C617965722E72656D6F76';
wwv_flow_api.g_varchar2_table(295) := '6528292C746869732E7573657270696E262664656C65746520746869732E7573657270696E2C746869732E646972656374696F6E73446973706C6179262664656C65746520746869732E646972656374696F6E73446973706C61792C746869732E646972';
wwv_flow_api.g_varchar2_table(296) := '656374696F6E7353657276696365262664656C65746520746869732E646972656374696F6E73536572766963652C746869732E5F72656D6F76654D61726B65727328292C746869732E686964654D65737361676528292C746869732E6D61702E72656D6F';
wwv_flow_api.g_varchar2_table(297) := '766528297D2C5F7365744F7074696F6E733A66756E6374696F6E28297B746869732E5F73757065724170706C7928617267756D656E7473297D2C5F7365744F7074696F6E3A66756E6374696F6E28652C74297B73776974636828617065782E6465627567';
wwv_flow_api.g_varchar2_table(298) := '28652C74292C65297B6361736522636C69636B61626C6549636F6E73223A746869732E6D61702E7365744F7074696F6E73287B636C69636B61626C6549636F6E733A742B22223D3D2274727565227D293B627265616B3B636173652264697361626C6544';
wwv_flow_api.g_varchar2_table(299) := '656661756C745549223A746869732E6D61702E7365744F7074696F6E73287B64697361626C6544656661756C7455493A742B22223D3D2274727565227D293B627265616B3B636173652266756C6C73637265656E436F6E74726F6C223A746869732E6D61';
wwv_flow_api.g_varchar2_table(300) := '702E7365744F7074696F6E73287B66756C6C73637265656E436F6E74726F6C3A742B22223D3D2274727565227D293B627265616B3B636173652268656164696E67223A746869732E6D61702E7365744F7074696F6E73287B68656164696E673A70617273';
wwv_flow_api.g_varchar2_table(301) := '65496E742874297D293B627265616B3B63617365226B6579626F61726453686F727463757473223A746869732E6D61702E7365744F7074696F6E73287B6B6579626F61726453686F7274637574733A742B22223D3D2274727565227D293B627265616B3B';
wwv_flow_api.g_varchar2_table(302) := '63617365226D617054797065223A746869732E6D61702E7365744D617054797065496428742E746F4C6F776572436173652829292C746869732E5F737570657228652C74293B627265616B3B63617365226D617054797065436F6E74726F6C223A746869';
wwv_flow_api.g_varchar2_table(303) := '732E6D61702E7365744F7074696F6E73287B6D617054797065436F6E74726F6C3A742B22223D3D2274727565227D293B627265616B3B63617365226D61785A6F6F6D223A746869732E6D61702E7365744F7074696F6E73287B6D61785A6F6F6D3A706172';
wwv_flow_api.g_varchar2_table(304) := '7365496E742874297D292C746869732E5F737570657228652C74293B627265616B3B63617365226D696E5A6F6F6D223A746869732E6D61702E7365744F7074696F6E73287B6D696E5A6F6F6D3A7061727365496E742874297D292C746869732E5F737570';
wwv_flow_api.g_varchar2_table(305) := '657228652C74293B627265616B3B6361736522726F74617465436F6E74726F6C223A746869732E6D61702E7365744F7074696F6E73287B726F74617465436F6E74726F6C3A742B22223D3D2274727565227D293B627265616B3B63617365227363616C65';
wwv_flow_api.g_varchar2_table(306) := '436F6E74726F6C223A746869732E6D61702E7365744F7074696F6E73287B7363616C65436F6E74726F6C3A742B22223D3D2274727565227D293B627265616B3B636173652273747265657456696577436F6E74726F6C223A746869732E6D61702E736574';
wwv_flow_api.g_varchar2_table(307) := '4F7074696F6E73287B73747265657456696577436F6E74726F6C3A742B22223D3D2274727565227D293B627265616B3B63617365227374796C6573223A746869732E6D61702E7365744F7074696F6E73287B7374796C65733A747D292C746869732E5F73';
wwv_flow_api.g_varchar2_table(308) := '7570657228226D61705374796C65222C74293B627265616B3B63617365227A6F6F6D436F6E74726F6C223A746869732E6D61702E7365744F7074696F6E73287B7A6F6F6D436F6E74726F6C3A742B22223D3D2274727565227D293B627265616B3B636173';
wwv_flow_api.g_varchar2_table(309) := '652274696C74223A746869732E6D61702E73657454696C74287061727365496E74287429293B627265616B3B63617365227A6F6F6D223A746869732E6D61702E7365745A6F6F6D287061727365496E74287429293B627265616B3B64656661756C743A74';
wwv_flow_api.g_varchar2_table(310) := '6869732E5F737570657228652C74297D7D7D293B636C617373206520657874656E647320676F6F676C652E6D6170732E4F7665726C6179566965777B636F6E7374727563746F7228652C74297B737570657228292C746869732E5F636F6E74656E743D65';
wwv_flow_api.g_varchar2_table(311) := '2C746869732E5F6F7074696F6E733D747D676574206F7074696F6E7328297B72657475726E20746869732E5F6F7074696F6E737D736574206F7074696F6E732865297B746869732E5F6F7074696F6E733D657D67657420636F6E74656E7428297B726574';
wwv_flow_api.g_varchar2_table(312) := '75726E20746869732E5F636F6E74656E747D73657420636F6E74656E742865297B746869732E5F636F6E74656E743D657D67657420706F7328297B72657475726E20746869732E5F6F7074696F6E732E706F737D73657420706F732865297B746869732E';
wwv_flow_api.g_varchar2_table(313) := '5F6F7074696F6E732E706F733D657D67657420626F756E647328297B72657475726E20746869732E5F6F7074696F6E732E626F756E64737D73657420626F756E64732865297B746869732E5F6F7074696F6E732E626F756E64733D657D67657420646976';
wwv_flow_api.g_varchar2_table(314) := '28297B72657475726E20746869732E5F6469767D6F6E41646428297B746869732E5F6469763D646F63756D656E742E637265617465456C656D656E74282264697622292C746869732E5F6469762E7374796C652E626F726465725374796C653D226E6F6E';
wwv_flow_api.g_varchar2_table(315) := '65222C746869732E5F6469762E7374796C652E626F7264657257696474683D22307078222C746869732E5F6469762E7374796C652E706F736974696F6E3D226162736F6C757465222C746869732E5F6469762E696E6E657248544D4C3D746869732E5F63';
wwv_flow_api.g_varchar2_table(316) := '6F6E74656E743B636F6E737420653D746869732E67657450616E657328293B746869732E5F6F7074696F6E732E6F6E436C69636B48616E646C65723F28652E6F7665726C61794D6F7573655461726765742E617070656E644368696C6428746869732E5F';
wwv_flow_api.g_varchar2_table(317) := '646976292C676F6F676C652E6D6170732E4F7665726C6179566965772E70726576656E744D61704869747346726F6D28746869732E5F646976292C617065782E64656275672822616464206C697374656E657220666F72206F7665726C617920636C6963';
wwv_flow_api.g_varchar2_table(318) := '6B22292C676F6F676C652E6D6170732E6576656E742E616464446F6D4C697374656E657228746869732E5F6469762C22636C69636B222C746869732E5F6F7074696F6E732E6F6E436C69636B48616E646C657229293A652E6F7665726C61794C61796572';
wwv_flow_api.g_varchar2_table(319) := '2E617070656E644368696C6428746869732E5F646976297D6472617728297B696628746869732E5F646976297B636F6E7374206F3D746869732E67657450726F6A656374696F6E28292C693D746869732E6765744D617028292E6765745A6F6F6D28293B';
wwv_flow_api.g_varchar2_table(320) := '696628693E3D28746869732E5F6F7074696F6E732E6D696E5A6F6F6D7C7C30292626693C3D28746869732E5F6F7074696F6E732E6D61785A6F6F6D7C7C39392929696628746869732E5F6F7074696F6E732E626F756E6473297B636F6E737420653D6F2E';
wwv_flow_api.g_varchar2_table(321) := '66726F6D4C61744C6E67546F446976506978656C28746869732E5F6F7074696F6E732E626F756E64732E676574536F757468576573742829292C743D6F2E66726F6D4C61744C6E67546F446976506978656C28746869732E5F6F7074696F6E732E626F75';
wwv_flow_api.g_varchar2_table(322) := '6E64732E6765744E6F727468456173742829293B746869732E5F646976262628746869732E5F6469762E7374796C652E6C6566743D652E782B227078222C746869732E5F6469762E7374796C652E746F703D742E792B227078222C746869732E5F646976';
wwv_flow_api.g_varchar2_table(323) := '2E7374796C652E77696474683D742E782D652E782B227078222C746869732E5F6469762E7374796C652E6865696768743D652E792D742E792B22707822297D656C736520696628746869732E5F6F7074696F6E732E706F73297B636F6E737420693D6F2E';
wwv_flow_api.g_varchar2_table(324) := '66726F6D4C61744C6E67546F446976506978656C28746869732E5F6F7074696F6E732E706F73293B76617220652C743B73776974636828746869732E5F6F7074696F6E732E686F72697A6F6E74616C416C69676E2E746F4C6F776572436173652829297B';
wwv_flow_api.g_varchar2_table(325) := '636173652263656E746572223A653D2D746869732E5F6469762E6F666673657457696474682F323B627265616B3B63617365227269676874223A653D2D746869732E5F6469762E6F666673657457696474683B627265616B3B64656661756C743A653D30';
wwv_flow_api.g_varchar2_table(326) := '7D73776974636828746869732E5F6F7074696F6E732E766572746963616C416C69676E2E746F4C6F776572436173652829297B6361736522626F74746F6D223A743D2D746869732E5F6469762E6F66667365744865696768743B627265616B3B63617365';
wwv_flow_api.g_varchar2_table(327) := '226D6964646C65223A743D2D746869732E5F6469762E6F66667365744865696768742F323B627265616B3B64656661756C743A743D307D652B3D746869732E5F6F7074696F6E732E686F72697A6F6E74616C4F66667365747C7C302C742B3D746869732E';
wwv_flow_api.g_varchar2_table(328) := '5F6F7074696F6E732E766572746963616C4F66667365747C7C302C746869732E5F6469762E7374796C652E6C6566743D692E782B652B227078222C746869732E5F6469762E7374796C652E746F703D692E792B742B227078227D656C736520617065782E';
wwv_flow_api.g_varchar2_table(329) := '646562756728226572726F723A20756E61626C6520746F2073686F77206F7665726C617920286E6F20706F73206F7220626F756E647320646566696E65642922297D7D6F6E52656D6F766528297B746869732E5F646976262628746869732E5F6469762E';
wwv_flow_api.g_varchar2_table(330) := '706172656E744E6F64652E72656D6F76654368696C6428746869732E5F646976292C64656C65746520746869732E5F646976297D6869646528297B746869732E5F646976262628746869732E5F6469762E7374796C652E7669736962696C6974793D2268';
wwv_flow_api.g_varchar2_table(331) := '696464656E22297D73686F7728297B746869732E5F646976262628746869732E5F6469762E7374796C652E7669736962696C6974793D2276697369626C6522297D746F67676C6528297B746869732E5F6469762626282268696464656E223D3D3D746869';
wwv_flow_api.g_varchar2_table(332) := '732E5F6469762E7374796C652E7669736962696C6974793F746869732E73686F7728293A746869732E686964652829297D746F67676C65444F4D2865297B746869732E6765744D617028293F746869732E7365744D6170286E756C6C293A746869732E73';
wwv_flow_api.g_varchar2_table(333) := '65744D61702865297D7D7D29293B0A2F2F2320736F757263654D617070696E6755524C3D6A6B36347265706F72746D61705F72312E6A732E6D6170';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(109770202399551938)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'jk64reportmap_r1.min.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '7B2276657273696F6E223A332C22736F7572636573223A5B226A6B36347265706F72746D61705F72312E6A73225D2C226E616D6573223A5B2224222C22776964676574222C226F7074696F6E73222C22726567696F6E4964222C22616A61784964656E74';
wwv_flow_api.g_varchar2_table(2) := '6966696572222C22616A61784974656D73222C22706C7567696E5265736F7572636550617468222C22706C7567696E46696C65507265666978222C2265787065637444617461222C226D6178696D756D526F7773222C22726F7773506572426174636822';
wwv_flow_api.g_varchar2_table(3) := '2C22696E697469616C43656E746572222C226C6174222C226C6E67222C226D696E5A6F6F6D222C226D61785A6F6F6D222C22696E697469616C5A6F6F6D222C2276697375616C69736174696F6E222C226D617054797065222C22636C69636B5A6F6F6D4C';
wwv_flow_api.g_varchar2_table(4) := '6576656C222C226973447261676761626C65222C22686561746D61704469737369706174696E67222C22686561746D61704F706163697479222C22686561746D6170526164697573222C2270616E4F6E436C69636B222C227265737472696374436F756E';
wwv_flow_api.g_varchar2_table(5) := '747279222C226D61705374796C65222C2274726176656C4D6F6465222C22756E697453797374656D222C226F7074696D697A65576179706F696E7473222C22616C6C6F775A6F6F6D222C22616C6C6F7750616E222C226765737475726548616E646C696E';
wwv_flow_api.g_varchar2_table(6) := '67222C22696E6974466E222C226D61726B6572466F726D6174466E222C2264726177696E674D6F646573222C2266656174757265436F6C6F72222C2266656174757265436F6C6F7253656C6563746564222C226665617475726553656C65637461626C65';
wwv_flow_api.g_varchar2_table(7) := '222C2266656174757265486F76657261626C65222C22666561747572655374796C65466E222C226472616744726F7047656F4A534F4E222C226175746F466974426F756E6473222C22646972656374696F6E7350616E656C222C22737069646572666965';
wwv_flow_api.g_varchar2_table(8) := '72222C227370696465726679466F726D6174466E222C2273686F7750696E73222C2273686F77496E666F506F70757073222C2273686F77496E666F4C61796572222C22696E666F4C61796572466F726D6174466E222C2273686F775370696E6E6572222C';
wwv_flow_api.g_varchar2_table(9) := '2264657461696C65644D6F7573654576656E7473222C2269636F6E4261736550617468222C226E6F446174614D657373616765222C226E6F41646472657373526573756C7473222C22646972656374696F6E734E6F74466F756E64222C22646972656374';
wwv_flow_api.g_varchar2_table(10) := '696F6E735A65726F526573756C7473222C226164644F7665726C6179222C22636C69636B222C2264656C657465416C6C4665617475726573222C2264656C65746553656C65637465644665617475726573222C22666974426F756E6473222C2267656F6C';
wwv_flow_api.g_varchar2_table(11) := '6F63617465222C22676574416464726573734279506F73222C22676F746F41646472657373222C22676F746F506F73222C22676F746F506F734279537472696E67222C22686964654D657373616765222C226C6F616447656F4A736F6E537472696E6722';
wwv_flow_api.g_varchar2_table(12) := '2C2270616E546F222C2270616E546F4279537472696E67222C2270617273654C61744C6E67222C2272656672657368222C2273686F77446972656374696F6E73222C2273686F77496E666F57696E646F77222C2273686F774D657373616765222C227622';
wwv_flow_api.g_varchar2_table(13) := '2C22706F73222C22617272222C2261706578222C226465627567222C226861734F776E50726F7065727479222C22676F6F676C65222C226D617073222C224C61744C6E67222C22696E6465784F66222C2273706C6974222C226C656E677468222C227265';
wwv_flow_api.g_varchar2_table(14) := '706C616365222C227061727365466C6F6174222C22636F6E74656E74222C226F7665726C61794F7074696F6E73222C22657874656E64222C22626F756E6473222C22686F72697A6F6E74616C416C69676E222C22766572746963616C416C69676E222C22';
wwv_flow_api.g_varchar2_table(15) := '686F72697A6F6E74616C4F6666736574222C22766572746963616C4F6666736574222C226F6E436C69636B48616E646C6572222C226F7665726C6179222C224D61704F7665726C6179222C227365744D6170222C2274686973222C226D6170222C226D73';
wwv_flow_api.g_varchar2_table(16) := '67222C226D7367446976222C22646F63756D656E74222C22637265617465456C656D656E74222C226D6573736167655549222C22636C6173734E616D65222C22617070656E644368696C64222C226D657373616765496E6E6572222C22696E6E65724854';
wwv_flow_api.g_varchar2_table(17) := '4D4C222C226164644576656E744C697374656E6572222C2272656D6F7665222C22636F6E74726F6C73222C22436F6E74726F6C506F736974696F6E222C224C4546545F43454E544552222C2270757368222C225F6576656E7450696E44617461222C226D';
wwv_flow_api.g_varchar2_table(18) := '61726B6572222C2264222C22706F736974696F6E222C22646976222C22696E666F446976222C2264617461222C225F756E657363617065496E666F222C22696E666F222C22444F4D506172736572222C22706172736546726F6D537472696E67222C2264';
wwv_flow_api.g_varchar2_table(19) := '6F63756D656E74456C656D656E74222C2274657874436F6E74656E74222C22696E666F57696E646F77222C22496E666F57696E646F77222C22736574436F6E74656E74222C226F70656E222C225F6E65774D61726B6572222C2270696E44617461222C22';
wwv_flow_api.g_varchar2_table(20) := '5F74686973222C224D61726B6572222C2278222C2279222C227469746C65222C226E222C2269636F6E222C2263222C226C6162656C222C226C222C22647261676761626C65222C226964222C2269222C226E616D65222C2266222C22736C696365222C22';
wwv_flow_api.g_varchar2_table(21) := '73657456697369626C65222C227365745A6F6F6D222C226A5175657279222C2274726967676572222C226576656E74222C226164644C697374656E6572222C22676574506F736974696F6E222C224A534F4E222C22737472696E67696679222C2269644D';
wwv_flow_api.g_varchar2_table(22) := '6170222C22686173222C225F7370696465726679222C226F7074222C226B65657053706964657266696564222C226261736963466F726D61744576656E7473222C226D61726B657273576F6E744D6F7665222C226D61726B657273576F6E744869646522';
wwv_flow_api.g_varchar2_table(23) := '2C226F6D73222C224F7665726C617070696E674D61726B657253706964657266696572222C22737461747573222C2269636F6E55524C222C225F67657457696E646F7750617468222C226D61726B6572537461747573222C225350494445524649454422';
wwv_flow_api.g_varchar2_table(24) := '2C22535049444552464941424C45222C2273657449636F6E222C2275726C222C226D61726B657273222C226164644D61726B6572222C225F72656D6F76654D61726B657273222C22746F74616C526F7773222C2264656C657465222C2266696E64222C22';
wwv_flow_api.g_varchar2_table(25) := '70222C226F6C64706F73222C227573657270696E222C22736574506F736974696F6E222C226C61746C6E67222C224C61744C6E67426F756E64734C69746572616C222C227061727365222C226164647265737354657874222C2267656F636F646572222C';
wwv_flow_api.g_varchar2_table(26) := '2247656F636F646572222C2267656F636F6465222C2261646472657373222C22636F6D706F6E656E745265737472696374696F6E73222C22636F756E747279222C22726573756C7473222C2247656F636F646572537461747573222C224F4B222C226765';
wwv_flow_api.g_varchar2_table(27) := '6F6D65747279222C226C6F636174696F6E222C2273657443656E746572222C22726573756C74222C225A45524F5F524553554C5453222C226E6176696761746F72222C2267656F6C6F636174696F6E222C2267657443757272656E74506F736974696F6E';
wwv_flow_api.g_varchar2_table(28) := '222C22636F6F726473222C226C61746974756465222C226C6F6E676974756465222C225F646972656374696F6E73526573706F6E7365222C22726573706F6E7365222C22446972656374696F6E73537461747573222C22646972656374696F6E73446973';
wwv_flow_api.g_varchar2_table(29) := '706C6179222C22736574446972656374696F6E73222C22746F74616C44697374616E6365222C22746F74616C4475726174696F6E222C226C6567436F756E74222C22756E697473222C22726F75746573222C226C656773222C226A222C226C6567222C22';
wwv_flow_api.g_varchar2_table(30) := '64697374616E6365222C2276616C7565222C226475726174696F6E222C22646972656374696F6E73222C224E4F545F464F554E44222C226F726967696E222C2264657374696E6174696F6E222C22446972656374696F6E7352656E6465726572222C2264';
wwv_flow_api.g_varchar2_table(31) := '6972656374696F6E7353657276696365222C22446972656374696F6E7353657276696365222C2273657450616E656C222C22676574456C656D656E7442794964222C22726F757465222C2254726176656C4D6F6465222C22556E697453797374656D222C';
wwv_flow_api.g_varchar2_table(32) := '225F646972656374696F6E73222C2264657374222C22776179706F696E7473222C2273746F706F766572222C22646174614C61796572222C22666F7245616368222C2266656174757265222C2267657450726F7065727479222C225F616464436F6E7472';
wwv_flow_api.g_varchar2_table(33) := '6F6C222C2268696E74222C2263616C6C6261636B222C22636F6E74726F6C446976222C22636F6E74726F6C5549222C22636F6E74726F6C496E6E6572222C227374796C65222C226261636B67726F756E64496D616765222C22544F505F43454E54455222';
wwv_flow_api.g_varchar2_table(34) := '2C225F616464436865636B626F78222C22636F6E74726F6C436865636B626F78222C22736574417474726962757465222C22636F6E74726F6C4C6162656C222C225F616464506F696E74222C2244617461222C2246656174757265222C22506F696E7422';
wwv_flow_api.g_varchar2_table(35) := '2C22616464222C225F616464506F6C79676F6E222C2270726F70222C2267656F6D222C2267657447656F6D65747279222C2267657454797065222C22706F6C79222C226765744172726179222C224C696E65617252696E67222C2273657447656F6D6574';
wwv_flow_api.g_varchar2_table(36) := '7279222C22506F6C79676F6E222C225F696E69744665617475726573222C227365745374796C65222C22636F6C6F72222C2266696C6C436F6C6F72222C227374726F6B65436F6C6F72222C227374726F6B65576569676874222C226564697461626C6522';
wwv_flow_api.g_varchar2_table(37) := '2C2272656D6F766550726F7065727479222C2273657450726F7065727479222C227265766572745374796C65222C226F766572726964655374796C65222C225F696E697444726177696E67222C2265222C2264726177696E674D616E61676572222C2264';
wwv_flow_api.g_varchar2_table(38) := '726177696E67222C2244726177696E674D616E61676572222C2264726177696E67436F6E74726F6C4F7074696F6E73222C2274797065222C224F7665726C617954797065222C224D41524B4552222C22504F4C59474F4E222C2267657450617468222C22';
wwv_flow_api.g_varchar2_table(39) := '52454354414E474C45222C2262222C22676574426F756E6473222C22676574536F75746857657374222C226765744E6F72746845617374222C22504F4C594C494E45222C224C696E65537472696E67222C22434952434C45222C2270726F706572746965';
wwv_flow_api.g_varchar2_table(40) := '73222C22726164697573222C22676574526164697573222C2267657443656E746572222C227374796C654F7074696F6E73222C226E657747656F6D65747279222C226F6C6447656F6D65747279222C226B6579222C225F70726F63657373506F696E7473';
wwv_flow_api.g_varchar2_table(41) := '222C2274686973417267222C2263616C6C222C22676574222C2267222C225F6C6F616447656F4A736F6E222C2267656F6A736F6E222C2266696C656E616D65222C226665617475726573222C2261646447656F4A736F6E222C2267656F4A736F6E222C22';
wwv_flow_api.g_varchar2_table(42) := '67656F537472696E67222C224C61744C6E67426F756E6473222C225F696E69744472616744726F7047656F4A534F4E222C226D6170436F6E7461696E6572222C2264726F70436F6E7461696E6572222C2273686F7750616E656C222C2273746F7050726F';
wwv_flow_api.g_varchar2_table(43) := '7061676174696F6E222C2270726576656E7444656661756C74222C22646973706C6179222C2266696C6573222C22646174615472616E73666572222C2266696C65222C22726561646572222C2246696C65526561646572222C226F6E6C6F6164222C2274';
wwv_flow_api.g_varchar2_table(44) := '6172676574222C226F6E6572726F72222C226572726F72222C2272656164417354657874222C22706C61696E54657874222C2267657444617461222C225F696E69744465627567222C22424F54544F4D5F4C454654222C226C61744C6E67222C22706174';
wwv_flow_api.g_varchar2_table(45) := '68222C2277696E646F77222C22706174686E616D65222C22737562737472696E67222C226C617374496E6465784F66222C225F696E69744D61704576656E7473222C226576656E744E616D65222C2263656E746572222C22746F4A534F4E222C22736F75';
wwv_flow_api.g_varchar2_table(46) := '746877657374222C226E6F72746865617374222C227A6F6F6D222C226765745A6F6F6D222C2268656164696E67222C2267657448656164696E67222C2274696C74222C2267657454696C74222C226765744D6170547970654964222C226D61704D6F7573';
wwv_flow_api.g_varchar2_table(47) := '654576656E74222C225F637265617465222C22656C656D656E74222C22696D616765507265666978222C226D61704F7074696F6E73222C226D6170547970654964222C227A6F6F6D436F6E74726F6C222C227363726F6C6C776865656C222C2264697361';
wwv_flow_api.g_varchar2_table(48) := '626C65446F75626C65436C69636B5A6F6F6D222C227374796C6573222C224D6170222C22696E6974222C226765744C6576656C222C2262696E64222C227265706F72746D6170222C2273616D706C655F636F6465222C225F616674657252656672657368';
wwv_flow_api.g_varchar2_table(49) := '222C227370696E6E6572222C225F74726967676572222C225F72656E64657250616765222C227044617461222C227374617274526F77222C226D617064617461222C226572726F724D7367222C22726F77222C2277656967687465644C6F636174696F6E';
wwv_flow_api.g_varchar2_table(50) := '73222C22776569676874222C22696450726F70657274794E616D65222C226E657749644D6170222C22736574222C22636F756E7450696E73222C22626174636853697A65222C22736572766572222C22706C7567696E222C22706167654974656D73222C';
wwv_flow_api.g_varchar2_table(51) := '22783031222C22783032222C226461746154797065222C2273756363657373222C226D61726B6572436C75737465726572222C22636C6561724D61726B657273222C224D61726B6572436C75737465726572222C22696D61676550617468222C22686561';
wwv_flow_api.g_varchar2_table(52) := '746D61704C61796572222C2276697375616C697A6174696F6E222C22486561746D61704C61796572222C226469737369706174696E67222C226F706163697479222C226D61706C6F61646564222C227574696C222C225F64657374726F79222C225F7365';
wwv_flow_api.g_varchar2_table(53) := '744F7074696F6E73222C225F73757065724170706C79222C22617267756D656E7473222C225F7365744F7074696F6E222C227365744F7074696F6E73222C22636C69636B61626C6549636F6E73222C2264697361626C6544656661756C745549222C2266';
wwv_flow_api.g_varchar2_table(54) := '756C6C73637265656E436F6E74726F6C222C227061727365496E74222C226B6579626F61726453686F727463757473222C227365744D6170547970654964222C22746F4C6F77657243617365222C225F7375706572222C226D617054797065436F6E7472';
wwv_flow_api.g_varchar2_table(55) := '6F6C222C22726F74617465436F6E74726F6C222C227363616C65436F6E74726F6C222C2273747265657456696577436F6E74726F6C222C2273657454696C74222C224F7665726C617956696577222C225B6F626A656374204F626A6563745D222C227375';
wwv_flow_api.g_varchar2_table(56) := '706572222C225F636F6E74656E74222C225F6F7074696F6E73222C226F222C225F646976222C22626F726465725374796C65222C22626F726465725769647468222C2270616E6573222C2267657450616E6573222C226F7665726C61794D6F7573655461';
wwv_flow_api.g_varchar2_table(57) := '72676574222C2270726576656E744D61704869747346726F6D222C22616464446F6D4C697374656E6572222C226F7665726C61794C61796572222C226F7665726C617950726F6A656374696F6E222C2267657450726F6A656374696F6E222C226765744D';
wwv_flow_api.g_varchar2_table(58) := '6170222C227377222C2266726F6D4C61744C6E67546F446976506978656C222C226E65222C226C656674222C22746F70222C227769647468222C22686569676874222C2270726F6A506F73222C226F666673657458222C226F666673657459222C226F66';
wwv_flow_api.g_varchar2_table(59) := '667365745769647468222C226F6666736574486569676874222C22706172656E744E6F6465222C2272656D6F76654368696C64222C227669736962696C697479222C2273686F77222C2268696465225D2C226D617070696E6773223A2241414F41412C47';
wwv_flow_api.g_varchar2_table(60) := '4141472C57414344412C45414145432C4F4141512C694241416B422C4341473142432C514141532C4341434C432C53414179422C4741437A42432C65414179422C4741437A42432C55414179422C4741437A42432C6D42414179422C4741437A42432C69';
wwv_flow_api.g_varchar2_table(61) := '42414179422C4741437A42432C59414179422C4541437A42432C59414179422C4B41437A42432C61414179422C4B41437A42432C63414179422C43414143432C494141492C45414145432C494141492C4741437043432C51414179422C4541437A42432C';
wwv_flow_api.g_varchar2_table(62) := '51414179422C4B41437A42432C59414179422C4541437A42432C63414179422C4F41437A42432C51414179422C5541437A42432C65414179422C4B41437A42432C61414179422C4541437A42432C6F42414179422C4541437A42432C65414179422C4741';
wwv_flow_api.g_varchar2_table(63) := '437A42432C63414179422C4541437A42432C59414179422C4541437A42432C6742414179422C4741437A42432C53414179422C4741437A42432C57414179422C5541437A42432C57414179422C5341437A42432C6D42414179422C4541437A42432C5741';
wwv_flow_api.g_varchar2_table(64) := '4179422C4541437A42432C55414179422C4541437A42432C6742414179422C4F41437A42432C4F414179422C4B41437A42432C65414179422C4B41437A42432C61414179422C4B41437A42432C61414179422C5541437A42432C7142414179422C554143';
wwv_flow_api.g_varchar2_table(65) := '7A42432C6D42414179422C4541437A42432C6B42414179422C4541437A42432C65414179422C4B41437A42432C6942414179422C4541432F42432C65414179422C4541436E42432C6742414179422C4B41437A42432C57414179422C4741437A42432C69';
wwv_flow_api.g_varchar2_table(66) := '42414179422C4B41437A42432C55414179422C4541437A42432C6742414179422C4541437A42432C65414179422C4541437A42432C6B42414179422C4B41437A42432C61414179422C4541437A42432C7142414179422C4541437A42432C61414179422C';
wwv_flow_api.g_varchar2_table(67) := '4741437A42432C63414179422C4741437A42432C6942414179422C6F4241437A42432C6D42414179422C2B4541437A42432C7342414179422C384441477A42432C57414179422C4B41437A42432C4D414179422C4B41437A42432C6B42414179422C4B41';
wwv_flow_api.g_varchar2_table(68) := '437A42432C7542414179422C4B41437A42432C55414179422C4B41437A42432C55414179422C4B41437A42432C6742414179422C4B41437A42432C59414179422C4B41437A42432C51414179422C4B41437A42432C6742414179422C4B41437A42432C59';
wwv_flow_api.g_varchar2_table(69) := '414179422C4B41437A42432C6B42414179422C4B41437A42432C4D414179422C4B41437A42432C63414179422C4B41437A42432C59414179422C4B41437A42432C51414179422C4B41437A42432C65414179422C4B41432F42432C65414179422C4B4143';
wwv_flow_api.g_varchar2_table(70) := '6E42432C59414179422C4D416337424A2C594141612C534141554B2C4741456E422C49414149432C45414D51432C4741505A432C4B41414B432C4D41414D2C7742414179424A2C4741456843412C4D414141412C4B414349412C454141454B2C65414165';
wwv_flow_api.g_varchar2_table(71) := '2C514141514C2C454141454B2C654141652C4F414531434A2C4541414D2C494141494B2C4F41414F432C4B41414B432C4F41414F522C4941477A42412C45414145532C514141512C4D41414D2C4541436842502C4541414D462C45414145552C4D41414D';
wwv_flow_api.g_varchar2_table(72) := '2C4B414350562C45414145532C514141512C4D41414D2C4541437642502C4541414D462C45414145552C4D41414D2C4B414350562C45414145532C514141512C4D41414D2C4941437642502C4541414D462C45414145552C4D41414D2C4D414564522C47';
wwv_flow_api.g_varchar2_table(73) := '41416D422C4741415A412C45414149532C51414558542C454141492C4741414B412C454141492C47414147552C514141512C4B41414D2C4B41433942562C454141492C4741414B412C454141492C47414147552C514141512C4B41414D2C4B4143394254';
wwv_flow_api.g_varchar2_table(74) := '2C4B41414B432C4D41414D2C53414155462C4741437242442C4541414D2C494141494B2C4F41414F432C4B41414B432C4F41414F4B2C57414157582C454141492C49414149572C57414157582C454141492C4D41452F44432C4B41414B432C4D41414D2C';
wwv_flow_api.g_varchar2_table(75) := '6B4241416D424A2C4B414931432C4F41414F432C4741515870422C574141592C5341415569432C4541415378462C474143334236452C4B41414B432C4D41414D2C61414163552C4541415378462C4741436C432C4941414979462C454141694233462C45';
wwv_flow_api.g_varchar2_table(76) := '41414534462C4F41414F2C4341457442432C4F41416D422C4B41436E4268422C4941416D422C4B41436E4269422C674241416D422C5341436E42432C6341416D422C5341436E42432C694241416D422C4541436E42432C6541416D422C4541436E426E46';
wwv_flow_api.g_varchar2_table(77) := '2C5141416D422C4541436E42432C5141416D422C4741436E426D462C6541416D422C4D4143704268472C4741434869472C454141552C49414149432C45414157562C45414153432C47414574432C4F414441512C45414151452C4F41414F432C4B41414B';
wwv_flow_api.g_varchar2_table(78) := '432C4B4143624A2C4741515878422C594141612C5341415536422C4741436E427A422C4B41414B432C4D41414D2C77424141794277422C4741457043462C4B41414B6E432C6341454C6D432C4B41414B472C4F414153432C53414153432C634141632C4F';
wwv_flow_api.g_varchar2_table(79) := '414572432C49414149432C45414159462C53414153432C634141632C4F41437643432C45414155432C554141592C734241437442502C4B41414B472C4F41414F4B2C59414159462C47414578422C49414149472C454141654C2C53414153432C63414163';
wwv_flow_api.g_varchar2_table(80) := '2C4F415731432C4F415641492C45414161462C554141592C794241437A42452C45414161432C55414159522C4541437A42492C45414155452C59414159432C4741457442542C4B41414B472C4F41414F512C6942414169422C534141532C5741436C436C';
wwv_flow_api.g_varchar2_table(81) := '432C4B41414B432C4D41414D2C324241435873422C4B41414B592C594147545A2C4B41414B432C49414149592C534141536A432C4F41414F432C4B41414B69432C674241416742432C61414161432C4B41414B68422C4B41414B472C5141433944482C4B';
wwv_flow_api.g_varchar2_table(82) := '41414B472C514147684274432C594141612C57414354592C4B41414B432C4D41414D2C794241435073422C4B41414B472C5141434C482C4B41414B472C4F41414F532C55415570424B2C634141652C53414155432C47414572422C49414149432C454141';
wwv_flow_api.g_varchar2_table(83) := '492C4341434A6C422C49414153442C4B41414B432C4941436433462C4941415334472C4541414F452C5341415339472C4D41437A42432C4941415332472C4541414F452C5341415337472C4D41436C4332472C4F414153412C47414D4A2C4F414A49412C';
wwv_flow_api.g_varchar2_table(84) := '4541414F72422C5341415371422C4541414F72422C5141415177422C4D41432F42462C45414145472C514141554A2C4541414F72422C5141415177422C4B41452F4233482C4541414534462C4F41414F36422C45414147442C4541414F4B2C4D41435A4A';
wwv_flow_api.g_varchar2_table(85) := '2C474147584B2C634141652C53414153432C47414731422C4F4144532C49414149432C57414159432C674241416742462C4541414D2C6141437243472C674241416742432C61414933427A442C65414167422C5341415538432C4741536E422C4F41524E';
wwv_flow_api.g_varchar2_table(86) := '7A432C4B41414B432C4D41414D2C32424141344277432C4741456C436C422C4B41414B38422C6141435439422C4B41414B38422C574141612C494141496C442C4F41414F432C4B41414B6B442C5941456E432F422C4B41414B38422C57414157452C5741';
wwv_flow_api.g_varchar2_table(87) := '415768432C4B41414B77422C634141634E2C4541414F4B2C4B41414B452C4F414531447A422C4B41414B38422C57414157472C4B41414B6A432C4B41414B432C4941414B69422C4741436C426C422C4B41414B38422C5941496842492C574141592C5341';
wwv_flow_api.g_varchar2_table(88) := '4155432C4741436C422C49414149432C4541415170432C4B4143526B422C454141532C4941414974432C4F41414F432C4B41414B77442C4F41414F2C434143394270432C49414159442C4B41414B432C4941436A426D422C534141592C4941414978432C';
wwv_flow_api.g_varchar2_table(89) := '4F41414F432C4B41414B432C4F41414F71442C45414151472C45414147482C45414151492C4741437444432C4D4141594C2C454141514D2C4541437042432C4B414161502C45414151512C4541414733432C4B41414B70472C514141516B442C61414165';
wwv_flow_api.g_varchar2_table(90) := '71462C45414151512C454141472C4B41432F44432C4D414159542C45414151552C4541437042432C5541415939432C4B41414B70472C514141516B422C6341492F426F472C4541414F4B2C4B41414F2C4341435677422C4741414F5A2C4541415168422C';
wwv_flow_api.g_varchar2_table(91) := '454143664D2C4B41414F552C45414151612C45414366432C4B41414F642C454141514D2C4741456E422C4941414B2C494141494F2C454141492C45414147412C4741414B2C47414149412C4941436A42622C45414151652C47414147662C45414151652C';
wwv_flow_api.g_varchar2_table(92) := '454141452C49414149462C4B41457A4239422C4541414F4B2C4B41414B2C514141512C4941414979422C47414147472C4F41414F2C4941414D68422C45414151652C454141452C49414149462C4941364439442C4F417A444B68442C4B41414B70472C51';
wwv_flow_api.g_varchar2_table(93) := '41415134432C5541436430452C4541414F6B432C594141572C4741496C4270442C4B41414B70472C5141415167432C67424143626F452C4B41414B70472C5141415167432C6541416573462C4741473542412C4541414F4B2C4B41414B452C4D4141517A';
wwv_flow_api.g_varchar2_table(94) := '422C4B41414B70472C5141415138432C674241436A4377452C4541414F72422C51414155472C4B41414B37432C5741415736432C4B41414B77422C634141634E2C4541414F4B2C4B41414B452C4D41414F2C4341436E456C442C494141694232432C4541';
wwv_flow_api.g_varchar2_table(95) := '414F452C534143784278422C65414169422C574143626E422C4B41414B432C4D41414D2C6F424141714277432C4541414F4B2C4B41414B77422C4941437843582C4541414D78492C5141415173422C594143646B482C4541414D6E432C494141496C432C';
wwv_flow_api.g_varchar2_table(96) := '4D41414D6D442C4541414F452C554145764267422C4541414D78492C5141415169422C674241436475482C4541414D6E432C494141496F442C514141516A422C4541414D78492C5141415169422C67424145704334442C4B41414B36452C4F41414F2C49';
wwv_flow_api.g_varchar2_table(97) := '4141496C422C4541414D78492C51414151432C55414155304A2C514141512C634141656E422C4541414D6E422C63414163432C4F414776466C422C4B41414B70472C514141512B432C6D4241436271442C4B41414B70472C514141512B432C6B4241416B';
wwv_flow_api.g_varchar2_table(98) := '4275452C4541414F72422C5141415371422C494149764474432C4F41414F432C4B41414B32452C4D41414D432C5941415976432C454143472C63414135426C422C4B41414B70472C51414151652C63414134422C654141652C5341437A442C5741434938';
wwv_flow_api.g_varchar2_table(99) := '442C4B41414B432C4D41414D2C694241416B4277432C4541414F4B2C4B41414B77422C4941437A432C4941414978452C4541414D79422C4B41414B30442C6341435878432C4541414F4B2C4B41414B452C4D414151572C4541414D78492C514141513643';
wwv_flow_api.g_varchar2_table(100) := '2C674241436C4332462C4541414D68452C6541416534422C4D414572426F432C4541414D78492C5141415173422C594143646B482C4541414D6E432C494141496C432C4D41414D512C474145684236442C4541414D78492C5141415169422C6742414364';
wwv_flow_api.g_varchar2_table(101) := '75482C4541414D6E432C494141496F442C514141516A422C4541414D78492C5141415169422C67424145704334442C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C634141656E422C4541';
wwv_flow_api.g_varchar2_table(102) := '414D6E422C63414163432C4F4147334674432C4F41414F432C4B41414B32452C4D41414D432C5941415976432C454141512C574141572C57414337432C4941414933432C4541414D79422C4B41414B30442C634143666A462C4B41414B432C4D41414D2C';
wwv_flow_api.g_varchar2_table(103) := '654141674277432C4541414F4B2C4B41414B77422C47414149592C4B41414B432C5541415572462C4941433144452C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C614141636E422C4541';
wwv_flow_api.g_varchar2_table(104) := '414D6E422C63414163432C4F414778462C434141432C4F41414F2C594141592C554141552C634141636E432C5141415169422C4B41414B70472C51414151652C674241416B422C4941456A4671462C4B41414B36442C4F41415137442C4B41414B36442C';
wwv_flow_api.g_varchar2_table(105) := '4D41414D432C4941414935432C4541414F4B2C4B41414B77422C4B4143354374452C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C634141656E422C4541414D6E422C63414163432C4B41';
wwv_flow_api.g_varchar2_table(106) := '477845412C4741495836432C554141572C5741435074462C4B41414B432C4D41414D2C75424147582C4941414930442C4541415170432C4B41435267452C4541414D2C43414346432C674241416F422C4541437042432C6D4241416F422C454143704243';
wwv_flow_api.g_varchar2_table(107) := '2C6942414171426E452C4B41414B70472C514141516B422C5941436C43734A2C694241416F422C4741493542314B2C4541414534462C4F41414F30452C4541414B68452C4B41414B70472C5141415130432C594145334230442C4B41414B71452C494141';
wwv_flow_api.g_varchar2_table(108) := '4D2C49414149432C34424141344274452C4B41414B432C4941414B2B442C474149724468452C4B41414B71452C494141495A2C594141592C5341436A427A442C4B41414B70472C5141415132432C6B424143542C5341415332452C4541415171442C4741';
wwv_flow_api.g_varchar2_table(109) := '47622C49414149432C4541415570432C4541414D71432C694241416D422C4941414D72432C4541414D78492C514141514B2C6B4241437444734B2C47414155442C344241413442492C61414161432C5741437A432C71434143564A2C47414155442C3442';
wwv_flow_api.g_varchar2_table(110) := '41413442492C61414161452C6141437A432C6B434143412C344241456631442C4541414F32442C514141512C43414143432C4941414B4E2C4D41496A432C4941414B2C4941414978422C454141492C45414147412C4541414968442C4B41414B2B452C51';
wwv_flow_api.g_varchar2_table(111) := '41415139462C4F4141512B442C494143724368442C4B41414B71452C49414149572C5541415568462C4B41414B2B452C514141512F422C49416170432C4F41564168442C4B41414B71452C494141495A2C594141592C594141592C5341415373422C4741';
wwv_flow_api.g_varchar2_table(112) := '43744374472C4B41414B432C4D41414D2C5741415971472C474143684374472C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C574141592C4341414574442C494141496D432C4541414D6E';
wwv_flow_api.g_varchar2_table(113) := '432C4941414B38452C51414151412C4F414768462F452C4B41414B71452C494141495A2C594141592C634141632C5341415373422C474143784374472C4B41414B432C4D41414D2C6141416371472C4741436C4374472C4B41414B36452C4F41414F2C49';
wwv_flow_api.g_varchar2_table(114) := '4141496C422C4541414D78492C51414151432C55414155304A2C514141512C614141632C4341414574442C494141496D432C4541414D6E432C4941414B38452C51414151412C4F414733452F452C4B41414B71452C4B41476842592C65414167422C5741';
wwv_flow_api.g_varchar2_table(115) := '495A2C4741484178472C4B41414B432C4D41414D2C344241435873422C4B41414B6B462C554141592C454143626C462C4B41414B542C51414155532C4B41414B542C4F41414F34462C4F414333426E462C4B41414B2B452C514141532C434143642C4941';
wwv_flow_api.g_varchar2_table(116) := '414B2C494141492F422C454141492C45414147412C4541414968442C4B41414B2B452C5141415139462C4F4141512B442C494143724368442C4B41414B2B452C514141512F422C474141476A442C4F41414F2C4D41453342432C4B41414B2B452C514141';
wwv_flow_api.g_varchar2_table(117) := '51492C53414D72422F482C4D41414F2C5341415532462C4741436274452C4B41414B432C4D41414D2C6D424143582C4941414977432C454141536C422C4B41414B2B452C514141514B2C4D41414D2C53414153432C474141492C4F41414F412C45414145';
wwv_flow_api.g_varchar2_table(118) := '39442C4B41414B77422C49414149412C4B414D2F442C4F414C4937422C454143412C4941414974432C4F41414F432C4B41414B32452C4D41414D442C5141415172432C4541414F2C53414572437A432C4B41414B432C4D41414D2C654141674271452C47';
wwv_flow_api.g_varchar2_table(119) := '4145784237422C4741555876442C514141532C5341415572442C45414149432C4741456E422C474144416B452C4B41414B432C4D41414D2C6F4241416F4270452C45414149432C4741437A422C4F41414E442C4741416F422C4F41414E432C454141592C';
wwv_flow_api.g_varchar2_table(120) := '43414331422C494141492B4B2C4541415374462C4B41414B75462C5141415176462C4B41414B75462C5141415137422C634141632C4941414B39452C4F41414F432C4B41414B432C4F41414F2C454141452C4741432F452C4741414977472C4741415568';
wwv_flow_api.g_varchar2_table(121) := '4C2C4741414B674C2C4541414F684C2C4F414153432C4741414B2B4B2C4541414F2F4B2C4D414333436B452C4B41414B432C4D41414D2C32424143522C434143482C49414149482C4541414D2C494141494B2C4F41414F432C4B41414B432C4F41414F78';
wwv_flow_api.g_varchar2_table(122) := '452C45414149432C47414372432C4741414979462C4B41414B75462C5141434C39472C4B41414B432C4D41414D2C324341413243482C474143744479422C4B41414B75462C5141415178462C4F41414F432C4B41414B432C4B41437A42442C4B41414B75';
wwv_flow_api.g_varchar2_table(123) := '462C51414151432C594141596A482C4F414374422C43414348452C4B41414B432C4D41414D2C694241416942482C474143354279422C4B41414B75462C514141552C4941414933472C4F41414F432C4B41414B77442C4F41414F2C4341436C4370432C49';
wwv_flow_api.g_varchar2_table(124) := '414159442C4B41414B432C4941436A426D422C5341415937432C4541435A75452C5541415939432C4B41414B70472C514141516B422C63414537422C4941414973482C4541415170432C4B41435A70422C4F41414F432C4B41414B32452C4D41414D432C';
wwv_flow_api.g_varchar2_table(125) := '594141597A442C4B41414B75462C514141532C574141572C5741436E442C4941414968482C4541414D79422C4B41414B30442C634143666A462C4B41414B432C4D41414D2C67424141694269462C4B41414B432C5541415572462C4941433343452C4B41';
wwv_flow_api.g_varchar2_table(126) := '414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C614141612C4341437A4474442C494141536D432C4541414D6E432C4941436633462C4941415369452C454141496A452C4D414362432C49414153';
wwv_flow_api.g_varchar2_table(127) := '67452C4541414968452C4D41436232472C4F4141536C422C6942414B6C42412C4B41414B75462C5541435A39472C4B41414B432C4D41414D2C694341435873422C4B41414B75462C5141415178462C4F41414F2C51414B35426E432C6742414169422C53';
wwv_flow_api.g_varchar2_table(128) := '414155552C4741437642472C4B41414B432C4D41414D2C3442414136424A2C47414378432C494141496D482C454141537A462C4B41414B2F422C594141594B2C47414939422C4F4148496D482C474143417A462C4B41414B72432C5141415138482C4541';
wwv_flow_api.g_varchar2_table(129) := '414F6E4C2C4D41414D6D4C2C4541414F6C4C2C4F414539426B4C2C4741495831482C4D41414F2C534141557A442C45414149432C4741456A422C4941414967452C45414B4A2C4F414E41452C4B41414B432C4D41414D2C6B4241416B4270452C45414149';
wwv_flow_api.g_varchar2_table(130) := '432C47414576422C4F41414E442C4741416F422C4F41414E432C4941436467452C4541414D2C494141494B2C4F41414F432C4B41414B432C4F41414F78452C45414149432C4741436A4379462C4B41414B432C494141496C432C4D41414D512C4941455A';
wwv_flow_api.g_varchar2_table(131) := '412C47414958502C634141652C534141554D2C4741437242472C4B41414B432C4D41414D2C3042414132424A2C47414374432C494141496D482C454141537A462C4B41414B2F422C594141594B2C47414939422C4F4148496D482C474143417A462C4B41';
wwv_flow_api.g_varchar2_table(132) := '414B6A432C4D41414D30482C4541414F6E4C2C4D41414D6D4C2C4541414F6C4C2C4F414535426B4C2C474149586C492C554141572C53414155652C4741456A422C4941414969422C4541614A2C4F416441642C4B41414B432C4D41414D2C734241417542';
wwv_flow_api.g_varchar2_table(133) := '4A2C4741453942412C4D414141412C4941474969422C454146416A422C454141454B2C654141652C534141534C2C454141454B2C654141652C554141554C2C454141454B2C654141652C554141554C2C454141454B2C654141652C51414578462C494141';
wwv_flow_api.g_varchar2_table(134) := '49432C4F41414F432C4B41414B36472C6F4241416F4270482C474145704371462C4B41414B67432C4D41414D72482C4B4149704230422C4B41414B432C4941414931432C5541415567432C4741477042412C4741555837422C594141612C534141556B49';
wwv_flow_api.g_varchar2_table(135) := '2C4741436E426E482C4B41414B432C4D41414D2C7742414179426B482C47414370432C49414149432C454141572C494141496A482C4F41414F432C4B41414B69482C5341432F4239462C4B41414B6E432C6341434C2C4941414975452C4541415170432C';
wwv_flow_api.g_varchar2_table(136) := '4B41435A36462C45414153452C514141512C43414362432C51414177424A2C45414378424B2C7342414177442C4B4141684337442C4541414D78492C5141415175422C6742414171422C434141432B4B2C5141415139442C4541414D78492C5141415175';
wwv_flow_api.g_varchar2_table(137) := '422C6942414169422C4B414370472C53414153674C2C4541415335422C4741436A422C47414149412C4941415733462C4F41414F432C4B41414B75482C65414165432C474141492C43414331432C4941414939482C4541414D34482C454141512C474141';
wwv_flow_api.g_varchar2_table(138) := '47472C53414153432C534143394239482C4B41414B432C4D41414D2C61414163482C4741437A4236442C4541414D6E432C4941414975472C554141556A492C474143704236442C4541414D6E432C494141496C432C4D41414D512C4741435A36442C4541';
wwv_flow_api.g_varchar2_table(139) := '414D78492C5141415169422C674241436475482C4541414D6E432C494141496F442C514141516A422C4541414D78492C5141415169422C67424145704375482C4541414D7A452C51414151592C454141496A452C4D41414F69452C4541414968452C4F41';
wwv_flow_api.g_varchar2_table(140) := '4337426B452C4B41414B432C4D41414D2C654141674279482C474143334231482C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C65414167422C434143354474442C494141536D432C4541';
wwv_flow_api.g_varchar2_table(141) := '414D6E432C4941436633462C4941415369452C454141496A452C4D414362432C4941415367452C4541414968452C4D4143626B4D2C4F4141534E2C454141512C5541456435422C4941415733462C4F41414F432C4B41414B75482C654141654D2C634143';
wwv_flow_api.g_varchar2_table(142) := '37436A492C4B41414B432C4D41414D2C694341435830442C4541414D2F442C594141592B442C4541414D78492C514141516F442C6D424145684379422C4B41414B432C4D41414D2C6B4241416D4236462C4F414D314339472C6742414169422C53414155';
wwv_flow_api.g_varchar2_table(143) := '6E442C45414149432C47414333426B452C4B41414B432C4D41414D2C34424141364270452C45414149432C47414335432C49414149734C2C454141572C494141496A482C4F41414F432C4B41414B69482C5341432F4239462C4B41414B6E432C6341434C';
wwv_flow_api.g_varchar2_table(144) := '2C4941414975452C4541415170432C4B41435A36462C45414153452C514141512C43414143512C534141592C434141436A4D2C4941414B412C4541414B432C4941414B412C4B41414F2C53414153344C2C4541415335422C4741432F44412C4941415733';
wwv_flow_api.g_varchar2_table(145) := '462C4F41414F432C4B41414B75482C65414165432C4741436C43462C454141512C4941435631482C4B41414B432C4D41414D2C654141674279482C474143334231482C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55';
wwv_flow_api.g_varchar2_table(146) := '414155304A2C514141512C65414167422C434143354474442C494141536D432C4541414D6E432C4941436633462C49414153412C45414354432C49414153412C454143546B4D2C4F4141534E2C454141512C4F41476E4231482C4B41414B432C4D41414D';
wwv_flow_api.g_varchar2_table(147) := '2C774341435830442C4541414D2F442C594141592B442C4541414D78492C514141516F442C6D424145374275482C4941415733462C4F41414F432C4B41414B75482C654141654D2C63414337436A492C4B41414B432C4D41414D2C694341435830442C45';
wwv_flow_api.g_varchar2_table(148) := '41414D2F442C594141592B442C4541414D78492C514141516F442C6D424145684379422C4B41414B432C4D41414D2C6B4241416D4236462C4F414D31432F472C554141572C574145502C4741444169422C4B41414B432C4D41414D2C754241435069492C';
wwv_flow_api.g_varchar2_table(149) := '55414155432C594141612C43414376422C4941414978452C4541415170432C4B41435A32472C55414155432C59414159432C6F4241416D422C534141537A462C47414339432C4941414937432C4541414D2C4341434E6A452C4941414D38472C45414153';
wwv_flow_api.g_varchar2_table(150) := '30462C4F41414F432C5341437442784D2C4941414D36472C4541415330462C4F41414F452C574145314235452C4541414D6E432C494141496C432C4D41414D512C4741435A36442C4541414D78492C5141415169422C674241436475482C4541414D6E43';
wwv_flow_api.g_varchar2_table(151) := '2C494141496F442C514141516A422C4541414D78492C5141415169422C67424145704334442C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C594141612C4341414374442C494141496D43';
wwv_flow_api.g_varchar2_table(152) := '2C4541414D6E432C4941414B33462C4941414969452C454141496A452C4941414B432C4941414967452C4541414968452C63414774476B452C4B41414B432C4D41414D2C794341576E4275492C6F42414171422C53414155432C4541415333432C474145';
wwv_flow_api.g_varchar2_table(153) := '70432C4F41444139462C4B41414B432C4D41414D2C67434141674377492C4541415333432C4741433743412C474143502C4B41414B33462C4F41414F432C4B41414B73492C694241416942642C474143394272472C4B41414B6F482C6B4241416B42432C';
wwv_flow_api.g_varchar2_table(154) := '63414163482C47414572432C494144412C49414149492C45414167422C45414147432C45414167422C45414147432C454141572C45414147432C454141512C53414376447A452C454141452C45414147412C454141496B452C45414153512C4F41414F7A';
wwv_flow_api.g_varchar2_table(155) := '492C4F4141512B442C4941414B2C434143334377452C47414173424E2C45414153512C4F41414F31452C4741414732452C4B41414B31492C4F414339432C4941414B2C4941414932492C454141452C45414147412C45414149562C45414153512C4F4141';
wwv_flow_api.g_varchar2_table(156) := '4F31452C4741414732452C4B41414B31492C4F41415132492C4941414B2C4341436E442C49414149432C4541414D582C45414153512C4F41414F31452C4741414732452C4B41414B432C4741436C434E2C47414167434F2C45414149432C53414153432C';
wwv_flow_api.g_varchar2_table(157) := '4D41433743522C47414167434D2C45414149472C53414153442C4F414772422C61414135422F482C4B41414B70472C5141415130422C61414562674D2C47414169422C674241436A42472C454141512C5341475A684A2C4B41414B36452C4F41414F2C49';
wwv_flow_api.g_varchar2_table(158) := '41414974442C4B41414B70472C51414151432C55414155304A2C514141512C614141612C434143784474442C49414651442C4B414557432C4941436E4236482C53414161522C45414362472C4D414161412C454143624F2C53414161542C45414362492C';
wwv_flow_api.g_varchar2_table(159) := '4B414161482C45414362532C57414161662C4941456A422C4D41434A2C4B41414B74492C4F41414F432C4B41414B73492C694241416942652C55414339426C492C4B41414B33422C5941415932422C4B41414B70472C5141415171442C6F42414339422C';
wwv_flow_api.g_varchar2_table(160) := '4D41434A2C4B41414B32422C4F41414F432C4B41414B73492C694241416942542C614143394231472C4B41414B33422C5941415932422C4B41414B70472C5141415173442C7542414339422C4D41434A2C5141434975422C4B41414B432C4D41414D2C34';
wwv_flow_api.g_varchar2_table(161) := '424141364236462C4B414B684470472C65414167422C53414155674B2C45414151432C454141612F4D2C47414B33432C47414A416F442C4B41414B432C4D41414D2C324241413442794A2C45414151432C454141612F4D2C474143354432452C4B41414B';
wwv_flow_api.g_varchar2_table(162) := '6D492C4F414153412C454143646E492C4B41414B6F492C59414163412C4541436E4270492C4B41414B6E432C634143446D432C4B41414B6D492C514141516E492C4B41414B6F492C5941596C422C4741584B70492C4B41414B6F482C6F4241434E70482C';
wwv_flow_api.g_varchar2_table(163) := '4B41414B6F482C6B4241416F422C4941414978492C4F41414F432C4B41414B774A2C6D4241437A4372492C4B41414B73492C6B4241416F422C49414149314A2C4F41414F432C4B41414B304A2C6B4241437A4376492C4B41414B6F482C6B4241416B4272';
wwv_flow_api.g_varchar2_table(164) := '482C4F41414F432C4B41414B432C4B41432F42442C4B41414B70472C5141415179432C694241436232442C4B41414B6F482C6B4241416B426F422C5341415370492C5341415371492C654141657A492C4B41414B70472C5141415179432C6D4241493745';
wwv_flow_api.g_varchar2_table(165) := '32442C4B41414B6D492C4F4141536E492C4B41414B2F422C594141592B422C4B41414B6D492C534141536E492C4B41414B6D492C4F41436C446E492C4B41414B6F492C5941416370492C4B41414B2F422C594141592B422C4B41414B6F492C6341416370';
wwv_flow_api.g_varchar2_table(166) := '492C4B41414B6F492C59414378432C4B4141684270492C4B41414B6D492C51414173432C4B414172426E492C4B41414B6F492C5941416F422C4341432F432C4941414968472C4541415170432C4B41435A412C4B41414B73492C6B4241416B42492C4D41';
wwv_flow_api.g_varchar2_table(167) := '414D2C4341437A42502C4F4141636E492C4B41414B6D492C4F41436E42432C5941416370492C4B41414B6F492C5941436E422F4D2C5741416375442C4F41414F432C4B41414B384A2C57414157744E2C474141734232452C4B41414B70472C5141415179';
wwv_flow_api.g_varchar2_table(168) := '422C5941437845432C5741416373442C4F41414F432C4B41414B2B4A2C5741415735492C4B41414B70472C5141415130422C6341436E442C53414153344C2C4541415333432C4741436A426E432C4541414D36452C6F4241416F42432C4541415333432C';
wwv_flow_api.g_varchar2_table(169) := '574147764339462C4B41414B432C4D41414D2C3045414766442C4B41414B432C4D41414D2C3844414B6E426D4B2C594141612C574145542C47414441704B2C4B41414B432C4D41414D2C79424141794273422C4B41414B2B452C5141415139462C4F4141';
wwv_flow_api.g_varchar2_table(170) := '4F2C6341437044652C4B41414B2B452C5141415139462C4F41414F2C454141472C4341436C42652C4B41414B6F482C6F4241434E70482C4B41414B6F482C6B4241416F422C4941414978492C4F41414F432C4B41414B774A2C6D4241437A4372492C4B41';
wwv_flow_api.g_varchar2_table(171) := '414B73492C6B4241416F422C49414149314A2C4F41414F432C4B41414B304A2C6B4241437A4376492C4B41414B6F482C6B4241416B4272482C4F41414F432C4B41414B432C4B41432F42442C4B41414B70472C5141415179432C694241436232442C4B41';
wwv_flow_api.g_varchar2_table(172) := '414B6F482C6B4241416B426F422C5341415370492C5341415371492C654141657A492C4B41414B70472C5141415179432C6D42414D37452C494148412C49414149384C2C454141536E492C4B41414B2B452C514141512C4741414733442C5341437A4230';
wwv_flow_api.g_varchar2_table(173) := '482C4541414F39492C4B41414B2B452C514141512F452C4B41414B2B452C5141415139462C4F41414F2C474141476D432C534143334332482C454141592C474143502F462C454141492C45414147412C4541414968442C4B41414B2B452C514141513946';
wwv_flow_api.g_varchar2_table(174) := '2C4F41414F2C454141472B442C49414376432B462C454141552F482C4B41414B2C4341435875462C5341415776472C4B41414B2B452C514141512F422C4741414735422C534143334234482C554141572C4941476E42764B2C4B41414B432C4D41414D79';
wwv_flow_api.g_varchar2_table(175) := '4A2C45414151572C4541414D432C454141572F492C4B41414B70472C5141415179422C5941436A442C494141492B472C4541415170432C4B41435A412C4B41414B73492C6B4241416B42492C4D41414D2C4341437A42502C4F41416F42412C4541437042';
wwv_flow_api.g_varchar2_table(176) := '432C5941416F42552C4541437042432C5541416F42412C4541437042784E2C6B4241416F4279452C4B41414B70472C5141415132422C6B4241436A43462C5741416F4275442C4F41414F432C4B41414B384A2C5741415733492C4B41414B70472C514141';
wwv_flow_api.g_varchar2_table(177) := '5179422C5941437844432C5741416F4273442C4F41414F432C4B41414B2B4A2C5741415735492C4B41414B70472C5141415130422C6341437A442C53414153344C2C4541415333432C4741436A426E432C4541414D36452C6F4241416F42432C45414153';
wwv_flow_api.g_varchar2_table(178) := '33432C574147764339462C4B41414B432C4D41414D2C324541556E4270422C7542414177422C57414370426D422C4B41414B432C4D41414D2C6F434143582C49414149754B2C454141596A4A2C4B41414B432C4941414973422C4B41437A4230482C4541';
wwv_flow_api.g_varchar2_table(179) := '4155432C534141512C53414153432C4741436E42412C45414151432C594141592C674241437042334B2C4B41414B432C4D41414D2C53414153794B2C4741437042462C4541415572492C4F41414F75492C51414B3742394C2C6B4241416D422C57414366';
wwv_flow_api.g_varchar2_table(180) := '6F422C4B41414B432C4D41414D2C2B424143582C49414149754B2C454141596A4A2C4B41414B432C4941414973422C4B41437A4230482C45414155432C534141512C53414153432C4741437642314B2C4B41414B432C4D41414D2C53414153794B2C4741';
wwv_flow_api.g_varchar2_table(181) := '437042462C4541415572492C4F41414F75492C4F41497A42452C594141612C5341415333472C4541414D34472C4541414D432C47414539422C49414149432C45414161704A2C53414153432C634141632C4F414770436F4A2C45414159724A2C53414153';
wwv_flow_api.g_varchar2_table(182) := '432C634141632C4F414376436F4A2C454141556C4A2C554141592C7342414374426B4A2C454141556A482C4D41415138472C4541436C42452C45414157684A2C59414159694A2C47414776422C49414149432C45414165744A2C53414153432C63414163';
wwv_flow_api.g_varchar2_table(183) := '2C4F415731432C4F415641714A2C454141616E4A2C554141592C794241437A426D4A2C45414161432C4D41414D432C674241416B426C482C45414572432B472C454141556A4A2C594141596B4A2C4741477442442C4541415539492C6942414169422C51';
wwv_flow_api.g_varchar2_table(184) := '41415334492C4741457043764A2C4B41414B432C49414149592C534141536A432C4F41414F432C4B41414B69432C6742414167422B492C5941415937492C4B41414B77492C4741457844412C474147584D2C614141632C5341415337472C4541414D4C2C';
wwv_flow_api.g_varchar2_table(185) := '4541414F30472C47414568432C49414149452C45414161704A2C53414153432C634141632C4F414770436F4A2C45414159724A2C53414153432C634141632C4F414376436F4A2C454141556C4A2C554141592C7342414374426B4A2C454141556A482C4D';
wwv_flow_api.g_varchar2_table(186) := '41415138472C4541436C42452C45414157684A2C59414159694A2C47414776422C49414149432C45414165744A2C53414153432C634141632C4F41433143714A2C454141616E4A2C554141592C794241457A426B4A2C454141556A4A2C594141596B4A2C';
wwv_flow_api.g_varchar2_table(187) := '47414574422C494141494B2C4541416B42334A2C53414153432C634141632C5341433743304A2C4541416742432C614141612C4F4141512C5941437243442C4541416742432C614141612C4B41414D2F472C4541414B2C494141496A442C4B41414B7047';
wwv_flow_api.g_varchar2_table(188) := '2C51414151432C5541437A446B512C4541416742432C614141612C4F4141512F472C474143724338472C4541416742432C614141612C514141532C4B41437443442C4541416742784A2C554141592C344241453542774A2C4541416742784A2C55414159';
wwv_flow_api.g_varchar2_table(189) := '2C7142414535426D4A2C454141616C4A2C59414159754A2C4741457A422C49414149452C45414165374A2C53414153432C634141632C53415331432C4F415241344A2C45414161442C614141612C4D41414D2F472C4541414B2C494141496A442C4B4141';
wwv_flow_api.g_varchar2_table(190) := '4B70472C51414151432C55414374446F512C45414161764A2C554141596B432C4541437A4271482C45414161314A2C554141592C694341457A426D4A2C454141616C4A2C59414159794A2C4741457A426A4B2C4B41414B432C49414149592C534141536A';
wwv_flow_api.g_varchar2_table(191) := '432C4F41414F432C4B41414B69432C6742414167422B492C5941415937492C4B41414B77492C4741457844412C47414758552C554141572C534141536A422C45414157314B2C4741433342452C4B41414B432C4D41414D2C734241417342754B2C454141';
wwv_flow_api.g_varchar2_table(192) := '55314B2C47414333432C49414149344B2C454141552C49414149764B2C4F41414F432C4B41414B734C2C4B41414B432C514141512C434143764339442C534141552C4941414931482C4F41414F432C4B41414B734C2C4B41414B452C4D41414D394C2C4B';
wwv_flow_api.g_varchar2_table(193) := '41477A432C4F414441304B2C4541415571422C494141496E422C47414350412C474147586F422C594141612C5341415374422C454141577A4B2C4741433742432C4B41414B432C4D41414D2C774241417742754B2C454141557A4B2C4741457A4339452C';
wwv_flow_api.g_varchar2_table(194) := '454141452C5341415373472C4B41414B70472C51414151432C5541415532512C4B41414B2C574143764376422C45414155432C534141512C53414153432C47414376422C47414149412C45414151432C594141592C634141652C4341436E432C49414149';
wwv_flow_api.g_varchar2_table(195) := '71422C4541414F74422C4541415175422C6341436E422C47414173422C5741416C42442C4541414B452C55414177422C43414537422C49414149432C4541414F482C4541414B492C5741456842442C4541414B354A2C4B41414B2C4941414970432C4F41';
wwv_flow_api.g_varchar2_table(196) := '414F432C4B41414B734C2C4B41414B572C57414157744D2C4941433143324B2C4541415134422C594141592C494141496E4D2C4F41414F432C4B41414B734C2C4B41414B612C514141514A2C53414B374433422C4541415571422C494141492C49414149';
wwv_flow_api.g_varchar2_table(197) := '314C2C4F41414F432C4B41414B734C2C4B41414B432C514141512C434143764339442C534141552C4941414931482C4F41414F432C4B41414B734C2C4B41414B612C514141512C43414143784D2C51414D7044794D2C634141652C57414358784D2C4B41';
wwv_flow_api.g_varchar2_table(198) := '414B432C4D41414D2C32424145582C4941414930442C4541415170432C4B414352694A2C454141596A4A2C4B41414B432C4941414973422C4B41477A4230482C4541415569432C534141536C4C2C4B41414B70472C5141415173432C6742414167422C53';
wwv_flow_api.g_varchar2_table(199) := '414153694E2C47414372442C4941414967432C454141512F492C4541414D78492C514141516B432C61414931422C4F414849714E2C45414151432C594141592C6742414370422B422C454141512F492C4541414D78492C514141516D432C734241453042';
wwv_flow_api.g_varchar2_table(200) := '2C434143684471502C55414165442C45414366452C59414165462C45414366472C614141652C4541436678492C55414165562C4541414D78492C514141516B422C594143374279512C554141652C4B41496E42764C2C4B41414B70472C514141516F432C';
wwv_flow_api.g_varchar2_table(201) := '6D42414562694E2C4541415578462C594141592C534141532C53414153442C47414370432F452C4B41414B432C4D41414D2C36424141364238452C4741437043412C4541414D32462C51414151432C594141592C6541433142334B2C4B41414B432C4D41';
wwv_flow_api.g_varchar2_table(202) := '414D2C614141612C534143784238452C4541414D32462C5141415171432C654141652C63414337422F4D2C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C6B4241416D422C434141437444';
wwv_flow_api.g_varchar2_table(203) := '2C494141496D432C4541414D6E432C4941414B6B4A2C5141415133462C4541414D32462C5941456A47314B2C4B41414B432C4D41414D2C614141612C514143784238452C4541414D32462C5141415173432C594141592C634141632C4741437843684E2C';
wwv_flow_api.g_varchar2_table(204) := '4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C6742414169422C4341414374442C494141496D432C4541414D6E432C4941414B6B4A2C5141415133462C4541414D32462C63414B76476E4A';
wwv_flow_api.g_varchar2_table(205) := '2C4B41414B70472C5141415171432C6D42414D62674E2C4541415578462C594141592C614141612C53414153442C47414378432F452C4B41414B432C4D41414D2C7142414171422C5941415938452C474143354379462C4541415579432C634143567A43';
wwv_flow_api.g_varchar2_table(206) := '2C4541415530432C634141636E492C4541414D32462C514141532C434141436D432C614141632C4941437444374D2C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C6D4241416F422C4341';
wwv_flow_api.g_varchar2_table(207) := '414374442C494141496D432C4541414D6E432C4941414B6B4A2C5141415133462C4541414D32462C6141477447462C4541415578462C594141592C594141592C53414153442C47414376432F452C4B41414B432C4D41414D2C7142414171422C57414157';
wwv_flow_api.g_varchar2_table(208) := '38452C474143334379462C4541415579432C634143566A4E2C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C6B4241416D422C4341414374442C494141496D432C4541414D6E432C494141';
wwv_flow_api.g_varchar2_table(209) := '4B6B4A2C5141415133462C4541414D32462C65414F374779432C614141632C574143566E4E2C4B41414B432C4D41414D2C79424141794273422C4B41414B70472C5141415169432C6341436A442C4941414975472C4541415170432C4B414352694A2C45';
wwv_flow_api.g_varchar2_table(210) := '4141596A4A2C4B41414B432C4941414973422C4B4145724276422C4B41414B70472C5141415169432C614141616B442C514141512C594141592C474143394369422C4B41414B384A2C614143442C4F4143412C4F4143412C3842414952394A2C4B41414B';
wwv_flow_api.g_varchar2_table(211) := '714A2C594145442C345A4143412C34424143412C5341415377432C4741434C7A4A2C4541414D39452C3442414B642C49414149774F2C45414169422C494141496C4E2C4F41414F432C4B41414B6B4E2C51414151432C654141652C4341437844432C7342';
wwv_flow_api.g_varchar2_table(212) := '414175422C4341457242374B2C5341416578432C4F41414F432C4B41414B69432C6742414167422B492C5741433343684F2C614141656D452C4B41414B70472C5141415169432C674241476C4369512C454141652F4C2C4F41414F432C4B41414B432C4B';
wwv_flow_api.g_varchar2_table(213) := '4149334272422C4F41414F432C4B41414B32452C4D41414D432C5941415971492C45414167422C6D4241416D422C5341415374492C47414574452C4F4144412F452C4B41414B432C4D41414D2C34424141344238452C4741432F42412C4541414D30492C';
wwv_flow_api.g_varchar2_table(214) := '4D4143642C4B41414B744E2C4F41414F432C4B41414B6B4E2C51414151492C59414159432C4F41436A43684B2C4541414D38482C554141556A422C454141577A462C4541414D33442C5141415136442C6541437A432C4D41434A2C4B41414B39452C4F41';
wwv_flow_api.g_varchar2_table(215) := '414F432C4B41414B6B4E2C51414151492C59414159452C5141436A432C4941414968482C4541414937422C4541414D33442C51414151794D2C554141557A422C57414368437A492C4541414D6D492C5941415974422C4541415735442C47414337422C4D';
wwv_flow_api.g_varchar2_table(216) := '41434A2C4B41414B7A472C4F41414F432C4B41414B6B4E2C51414151492C59414159492C5541436A432C49414149432C45414149684A2C4541414D33442C51414151344D2C5941436C4270482C454141492C434141436D482C45414145452C654143462C';
wwv_flow_api.g_varchar2_table(217) := '4341414370532C4941414D6B532C45414145452C6541416570532C4D41437642432C4941414D69532C45414145472C6541416570532C4F4145784269532C45414145472C654143462C4341414370532C4941414D69532C45414145452C654141656E532C';
wwv_flow_api.g_varchar2_table(218) := '4D41437642442C4941414D6B532C45414145472C6541416572532C5141456A4338482C4541414D6D492C5941415974422C4541415735442C47414337422C4D41434A2C4B41414B7A472C4F41414F432C4B41414B6B4E2C51414151492C59414159532C53';
wwv_flow_api.g_varchar2_table(219) := '41436A4333442C4541415571422C494141492C49414149314C2C4F41414F432C4B41414B734C2C4B41414B432C514141512C434143764339442C534141552C4941414931482C4F41414F432C4B41414B734C2C4B41414B30432C57414157724A2C454141';
wwv_flow_api.g_varchar2_table(220) := '4D33442C51414151794D2C554141557A422C65414574452C4D41434A2C4B41414B6A4D2C4F41414F432C4B41414B6B4E2C51414151492C59414159572C4F41456A4337442C4541415571422C494141492C49414149314C2C4F41414F432C4B41414B734C';
wwv_flow_api.g_varchar2_table(221) := '2C4B41414B432C514141512C434143764332432C574141592C43414352432C4F414151784A2C4541414D33442C514141516F4E2C614145314233472C534141552C4941414931482C4F41414F432C4B41414B734C2C4B41414B452C4D41414D37472C4541';
wwv_flow_api.g_varchar2_table(222) := '414D33442C51414151714E2C674241493344314A2C4541414D33442C51414151452C4F41414F2C5341497A426B4A2C4541415569432C554141532C534141532F422C47414378422C4941454967452C4541464168432C454141512F492C4541414D78492C';
wwv_flow_api.g_varchar2_table(223) := '514141516B432C614143744279502C474141572C454165662C4F41624970432C45414151432C594141592C6742414370422B422C454141512F492C4541414D78492C514141516D432C71424145744277502C4741416137522C454141452C534141533049';
wwv_flow_api.g_varchar2_table(224) := '2C4541414D78492C51414151432C5541415532512C4B41414B2C5941457A4432432C45414134442C43414378442F422C55414165442C45414366452C59414165462C45414366472C614141652C474145666C4A2C4541414D78492C5141415173432C6742';
wwv_flow_api.g_varchar2_table(225) := '41436478432C4541414534462C4F41414F364E2C454141632F4B2C4541414D78492C5141415173432C65414165694E2C4941456A447A502C4541414534462C4F41414F364E2C454141632C43414143724B2C5541415579492C45414155412C5341415341';
wwv_flow_api.g_varchar2_table(226) := '2C4F4147684574432C4541415578462C594141592C634141632C53414153442C4741437A432F452C4B41414B432C4D41414D2C7142414171422C6141416138452C47414337432F452C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51';
wwv_flow_api.g_varchar2_table(227) := '414151432C55414155304A2C514141512C614141632C4341414374442C494141496D432C4541414D6E432C4941414B6B4A2C5141415133462C4541414D32462C6141476847462C4541415578462C594141592C6942414169422C53414153442C47414335';
wwv_flow_api.g_varchar2_table(228) := '432F452C4B41414B432C4D41414D2C7142414171422C67424141674238452C47414368442F452C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C6742414169422C4341414374442C494141';
wwv_flow_api.g_varchar2_table(229) := '496D432C4541414D6E432C4941414B6B4A2C5141415133462C4541414D32462C6141476E47462C4541415578462C594141592C654141652C53414153442C47414331432F452C4B41414B432C4D41414D2C7142414171422C6341416338452C4741433943';
wwv_flow_api.g_varchar2_table(230) := '2F452C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C634141652C434143764574442C494141636D432C4541414D6E432C49414370426B4A2C5141416333462C4541414D32462C51414370';
wwv_flow_api.g_varchar2_table(231) := '4269452C59414163354A2C4541414D344A2C5941437042432C59414163374A2C4541414D364A2C6942414968426A4E2C534141534F2C6942414169422C574141572C5341415336432C47414378422C57414164412C4541414D384A2C4B41434E6C4C2C45';
wwv_flow_api.g_varchar2_table(232) := '41414D39452C3642416D426C4269512C65414169422C534141556A482C4541415569442C4541415569452C47414333432C49414149704C2C4541415170432C4B41435273472C6141416F4231482C4F41414F432C4B41414B432C4F41436843794B2C4541';
wwv_flow_api.g_varchar2_table(233) := '41536B452C4B41414B442C454141536C482C4741436842412C6141416F4231482C4F41414F432C4B41414B734C2C4B41414B452C4D41433543642C454141536B452C4B41414B442C454141536C482C454141536F482C4F4145684370482C454141537545';
wwv_flow_api.g_varchar2_table(234) := '2C5741415733422C534141512C5341415379452C4741436A43764C2C4541414D6D4C2C65414165492C4541414770452C4541415569452C4F414B3943492C614141652C53414155432C45414153432C454141556C552C474143784336452C4B41414B432C';
wwv_flow_api.g_varchar2_table(235) := '4D41414D2C65414167426D502C47414733422C49414149452C454141572F4E2C4B41414B432C4941414973422C4B41414B794D2C57414157482C454141536A552C4741476A442C4941414977492C4541415170432C4B41435A412C4B41414B432C494141';
wwv_flow_api.g_varchar2_table(236) := '4973422C4B41414B32482C534141512C53414153432C47414333422F472C4541414D6D4C2C6541416570452C4541415175422C6341416574492C4541414D37432C4F41414F442C4F41415138432C4541414D37432C5741457645532C4B41414B70472C51';
wwv_flow_api.g_varchar2_table(237) := '41415177432C6541436234442C4B41414B432C4941414931432C5541415579432C4B41414B542C5141473542642C4B41414B36452C4F41414F2C4941414974442C4B41414B70472C51414151432C55414155304A2C514141512C6742414169422C434143';
wwv_flow_api.g_varchar2_table(238) := '354474442C49414157442C4B41414B432C4941436842674F2C514141574A2C45414358452C53414157412C45414358442C53414157412C4B41496E4268512C6B4241416F422C534141556F512C454141574A2C47414572432C4741444172502C4B41414B';
wwv_flow_api.g_varchar2_table(239) := '432C4D41414D2C384241412B4277502C454141574A2C4741436A44492C454141572C434143582C494141494C2C454141556C4B2C4B41414B67432C4D41414D75492C4741437A426C4F2C4B41414B542C4F4141532C49414149582C4F41414F432C4B4141';
wwv_flow_api.g_varchar2_table(240) := '4B73502C61414339426E4F2C4B41414B344E2C61414161432C45414153432C4B41496E434D2C7142414175422C5741436E4233502C4B41414B432C4D41414D2C6B434143582C4941414930442C4541415170432C4B414552714F2C454141656A4F2C5341';
wwv_flow_api.g_varchar2_table(241) := '415371492C654141652C4F41414F7A492C4B41414B70472C51414151432C554143334479552C45414167426C4F2C5341415371492C654141652C514141517A492C4B41414B70472C51414151432C554145374430552C454141592C5341415531432C4741';
wwv_flow_api.g_varchar2_table(242) := '496C422C4F414841412C4541414532432C6B4241434633432C4541414534432C6942414346482C4541416333452C4D41414D2B452C514141552C53414376422C474149664C2C45414161314E2C6942414169422C59414161344E2C474141572C47414774';
wwv_flow_api.g_varchar2_table(243) := '44442C45414163334E2C6942414169422C57414159344E2C474141572C4741457444442C45414163334E2C6942414169422C614141612C5741437843324E2C4541416333452C4D41414D2B452C514141552C5541432F422C474145484A2C45414163334E';
wwv_flow_api.g_varchar2_table(244) := '2C6942414169422C514141512C534141536B4C2C4741433543704E2C4B41414B432C4D41414D2C6942414169426D4E2C4741433542412C4541414534432C694241434635432C4541414532432C6B42414346462C4541416333452C4D41414D2B452C5141';
wwv_flow_api.g_varchar2_table(245) := '41552C4F414539422C49414149432C4541415139432C454141452B432C61414161442C4D414333422C47414149412C4541414D31502C4F41474E2C4941414B2C4941415734502C45414150374C2C454141492C45414153364C2C4541414F462C4541414D';
wwv_flow_api.g_varchar2_table(246) := '334C2C47414149412C4941414B2C43414378432C49414149384C2C454141532C49414149432C574143626A422C45414157652C4541414B354C2C4B41437042364C2C4541414F452C4F4141532C534141536E442C47414372427A4A2C4541414D74452C6B';
wwv_flow_api.g_varchar2_table(247) := '4241416B422B4E2C454141456F442C4F41414F78492C4F41415171482C494145374367422C4541414F492C514141552C5341415372442C4741437442704E2C4B41414B30512C4D41414D2C6D424145664C2C4541414F4D2C57414157502C4F41456E422C';
wwv_flow_api.g_varchar2_table(248) := '434147482C49414149512C4541415978442C454141452B432C61414161552C514141512C6341436E43442C474143416A4E2C4541414D74452C6B4241416B4275522C47414B68432C4F41414F2C4B4143522C49415356452C574141592C5741434C39512C';
wwv_flow_api.g_varchar2_table(249) := '4B41414B432C4D41414D2C77424143582C4941414930442C4541415170432C4B414552794A2C45414159724A2C53414153432C634141632C4F414376436F4A2C454141556C4A2C554141592C7542414374426B4A2C454141552F492C554141592C654143';
wwv_flow_api.g_varchar2_table(250) := '7442562C4B41414B432C49414149592C534141536A432C4F41414F432C4B41414B69432C674241416742304F2C61414161784F2C4B41414B79492C4741476845374B2C4F41414F432C4B41414B32452C4D41414D432C594141597A442C4B41414B432C49';
wwv_flow_api.g_varchar2_table(251) := '41414B2C614141612C5341415575442C474143334469472C454141552F492C554141592C6B4241416F4269442C4B41414B432C554141554A2C4541414D694D2C5741496E4537512C4F41414F432C4B41414B32452C4D41414D432C594141597A442C4B41';
wwv_flow_api.g_varchar2_table(252) := '414B432C4941414B2C6B4241416B422C5341415575442C474143684569472C454141552F492C554141592C634141674269442C4B41414B432C5541415578422C4541414D6E432C49414149774D2C69424149764568492C65414167422C5741435A68472C';
wwv_flow_api.g_varchar2_table(253) := '4B41414B432C4D41414D2C34424145582C4941414967522C4541414F31502C4B41414B70472C51414151492C6D4241714478422C4D416E44612C4B41415430562C454143416A522C4B41414B432C4D41414D2C774341475867522C4541414F432C4F4141';
wwv_flow_api.g_varchar2_table(254) := '4F704A2C5341415334422C4F41415377482C4F41414F704A2C53414153714A2C554145764337512C514141512C614141652C47414535424E2C4B41414B432C4D41414D2C75434141774367522C47414B6E44412C4541414F412C4541414B472C55414155';
wwv_flow_api.g_varchar2_table(255) := '2C45414147482C4541414B492C594141592C53414B6E434A2C4541414B33512C514141512C514141552C47414539424E2C4B41414B432C4D41414D2C77424141794267522C4741577043412C47414E41412C4541414F412C4541414B472C554141552C45';
wwv_flow_api.g_varchar2_table(256) := '414147482C4541414B492C594141592C53414D3942442C554141552C45414147482C4541414B492C594141592C51414D314372522C4B41414B432C4D41414D2C73424141754267522C47414B6C43412C4541414F412C4541414B472C554141552C454141';
wwv_flow_api.g_varchar2_table(257) := '47482C4541414B492C594141592C4F414F6C4472522C4B41414B432C4D41414D2C4F41415167522C4741455A412C474149584B2C65414167422C5741435A2C49414149334E2C4541415170432C4B41455A2C434141432C69424143412C69424143412C6B';
wwv_flow_api.g_varchar2_table(258) := '424143412C4F4143412C6F424143412C71424143412C634143412C654143412C67424143436B4A2C534141512C5341415338472C4741436676522C4B41414B432C4D41414D2C77424141774273522C4741436E4370522C4F41414F432C4B41414B32452C';
wwv_flow_api.g_varchar2_table(259) := '4D41414D432C5941415972422C4541414D6E432C4941414B2B502C474141572C574143684476522C4B41414B432C4D41414D2C4F41414F73522C4741436C422C494141497A512C4541415336432C4541414D6E432C49414149774D2C5941437642684F2C';
wwv_flow_api.g_varchar2_table(260) := '4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C4D41414D794D2C454141572C43414337442F502C494141596D432C4541414D6E432C4941436C4267512C4F414159374E2C4541414D6E432C';
wwv_flow_api.g_varchar2_table(261) := '49414149694E2C5941415967442C5341436C43432C5541415935512C4541414F6D4E2C6541416577442C5341436C43452C5541415937512C4541414F6F4E2C6541416575442C5341436C43472C4B4141596A4F2C4541414D6E432C4941414971512C5541';
wwv_flow_api.g_varchar2_table(262) := '437442432C514141596E4F2C4541414D6E432C4941414975512C6141437442432C4B414159724F2C4541414D6E432C4941414979512C554143744239562C5141415977482C4541414D6E432C4941414930512C7542414B2F4233512C4B41414B70472C51';
wwv_flow_api.g_varchar2_table(263) := '41415169442C734241455A2C434141432C4F4143412C554143412C61414343714D2C534141512C5341415338472C4741436676522C4B41414B432C4D41414D2C77424141774273522C4741436E4370522C4F41414F432C4B41414B32452C4D41414D432C';
wwv_flow_api.g_varchar2_table(264) := '5941415972422C4541414D6E432C4941414B2B502C474141572C574143684476522C4B41414B432C4D41414D2C4F41414F73522C4741436C422C494141497A512C4541415336432C4541414D6E432C49414149774D2C5941437642684F2C4B41414B3645';
wwv_flow_api.g_varchar2_table(265) := '2C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C4D41414D794D2C454141572C43414337442F502C494141596D432C4541414D6E432C4941436C4267512C4F414159374E2C4541414D6E432C49414149694E';
wwv_flow_api.g_varchar2_table(266) := '2C5941415967442C5341436C43432C5541415935512C4541414F6D4E2C6541416577442C5341436C43452C5541415937512C4541414F6F4E2C6541416575442C5341436C43472C4B4141596A4F2C4541414D6E432C4941414971512C5541437442432C51';
wwv_flow_api.g_varchar2_table(267) := '4141596E4F2C4541414D6E432C4941414975512C6141437442432C4B414159724F2C4541414D6E432C4941414979512C554143744239562C5141415977482C4541414D6E432C4941414930512C7542414D6C432C434141432C634143412C574143412C59';
wwv_flow_api.g_varchar2_table(268) := '4143412C574143412C614143437A482C534141512C5341415338472C4741436676522C4B41414B432C4D41414D2C77424141774273522C4741436E4370522C4F41414F432C4B41414B32452C4D41414D432C5941415972422C4541414D6E432C4941414B';
wwv_flow_api.g_varchar2_table(269) := '2B502C474141572C53414153592C4741437A446E532C4B41414B432C4D41414D2C4F41414F73522C45414157592C454141636E422C514143334368522C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C';
wwv_flow_api.g_varchar2_table(270) := '514141512C4D41414D794D2C454141572C43414337442F502C4941414D6D432C4541414D6E432C4941435A33462C4941414D73572C454141636E422C4F41414F6E562C4D41433342432C4941414D71572C454141636E422C4F41414F6C562C65414F3343';
wwv_flow_api.g_varchar2_table(271) := '6B452C4B41414B432C4D41414D2C3842414358452C4F41414F432C4B41414B32452C4D41414D432C594141597A442C4B41414B432C4941414B2C534141532C5341415532512C47414376446E532C4B41414B432C4D41414D2C594141616B532C45414163';
wwv_flow_api.g_varchar2_table(272) := '6E422C5141436C43724E2C4541414D78492C5141415169422C694241435675482C4541414D78492C5141415173422C594143646B482C4541414D6E432C494141496C432C4D41414D36532C454141636E422C5141456C43724E2C4541414D6E432C494141';
wwv_flow_api.g_varchar2_table(273) := '496F442C514141516A422C4541414D78492C5141415169422C69424145704334442C4B41414B36452C4F41414F2C494141496C422C4541414D78492C51414151432C55414155304A2C514141512C574141592C434143704574442C4941414D6D432C4541';
wwv_flow_api.g_varchar2_table(274) := '414D6E432C4941435A33462C4941414D73572C454141636E422C4F41414F6E562C4D41433342432C4941414D71572C454141636E422C4F41414F6C562C594161334273572C514141532C5741434C70532C4B41414B432C4D41414D2C6F42414171427342';
wwv_flow_api.g_varchar2_table(275) := '2C4B41414B38512C5141415174472C4B41414B2C4F41436C442F4C2C4B41414B432C4D41414D69462C4B41414B432C5541415535442C4B41414B70472C5541432F422C4941414977492C4541415170432C4B41475A412C4B41414B2B512C594141632F51';
wwv_flow_api.g_varchar2_table(276) := '2C4B41414B79452C694241416D422C4941414D7A452C4B41414B70472C514141514B2C694241416D422C5741436A4677452C4B41414B432C4D41414D2C6341416573422C4B41414B2B512C6141452F422C49414149432C454141612C4341436278572C51';
wwv_flow_api.g_varchar2_table(277) := '4141794277462C4B41414B70472C51414151592C5141437443432C514141794275462C4B41414B70472C51414151612C514143744334562C4B4141794272512C4B41414B70472C51414151632C594143744375562C4F414179426A512C4B41414B70472C';
wwv_flow_api.g_varchar2_table(278) := '51414151532C634143744334572C55414179426A522C4B41414B70472C5141415167422C51414374436B492C554141794239432C4B41414B70472C5141415136422C534143744379562C59414179426C522C4B41414B70472C5141415134422C55414374';
wwv_flow_api.g_varchar2_table(279) := '4332562C59414179426E522C4B41414B70472C5141415134422C554143744334562C77424141324270522C4B41414B70472C51414169422C5541436A4438422C67424141794273452C4B41414B70472C5141415138422C694241694431432C4741394349';
wwv_flow_api.g_varchar2_table(280) := '73452C4B41414B70472C5141415177422C5741436234562C454141574B2C4F41415372522C4B41414B70472C5141415177422C554147724334452C4B41414B432C4941414D2C4941414972422C4F41414F432C4B41414B79532C494141496C522C534141';
wwv_flow_api.g_varchar2_table(281) := '5371492C654141657A492C4B41414B38512C5141415174472C4B41414B2C4F41414F77472C47414568442C614141354268522C4B41414B70472C51414151652C674241436271462C4B41414B70472C5141415134432C554141572C454143784277442C4B';
wwv_flow_api.g_varchar2_table(282) := '41414B70472C5141415136432C6742414169422C454143394275442C4B41414B70472C5141415138432C65414167422C474147374273442C4B41414B70472C514141512B422C5341436238432C4B41414B432C4D41414D2C6D4341455873422C4B41414B';
wwv_flow_api.g_varchar2_table(283) := '75522C4B41414B76522C4B41414B70472C514141512B422C4F4143764271452C4B41414B75522C4F41434C76522C4B41414B75522C4B41414B704D2C4F41435631472C4B41414B432C4D41414D2C6D4341476673422C4B41414B694C2C67424145446A4C';
wwv_flow_api.g_varchar2_table(284) := '2C4B41414B70472C5141415169432C634143626D452C4B41414B344C2C6541474C354C2C4B41414B70472C5141415175432C694241436236442C4B41414B6F4F2C754241474C33502C4B41414B432C4D41414D38532C574141572C474143744278522C4B';
wwv_flow_api.g_varchar2_table(285) := '41414B75502C6141474C76502C4B41414B70472C514141514D2C5941436238462C4B41414B39422C5541475438422C4B41414B2B502C694241454C74522C4B41414B36452C4F41414F2C4941414974442C4B41414B70472C51414151432C554141553458';
wwv_flow_api.g_varchar2_table(286) := '2C4B41414B2C654141632C57414374442F582C454141452C5141415130492C4541414D78492C51414151432C5541415536582C554141552C63414935436A542C4B41414B432C4D41414D38532C574141572C454141472C4341477A422C49414349472C45';
wwv_flow_api.g_varchar2_table(287) := '4141632C5741416176502C4541414D78492C51414151432C534141572C2B424145784434452C4B41414B432C4D41414D2C304741454C69542C4541464B2C794541484F2C6F47415774426C542C4B41414B432C4D41414D2C2B424147666B542C63414165';
wwv_flow_api.g_varchar2_table(288) := '2C574143586E542C4B41414B432C4D41414D2C694241455073422C4B41414B36522C5541434C70542C4B41414B432C4D41414D2C6B4241435873422C4B41414B36522C514141516A522C5541476A426E432C4B41414B36452C4F41414F2C494141497444';
wwv_flow_api.g_varchar2_table(289) := '2C4B41414B70472C51414151432C55414155304A2C514141512C6F4241472F4376442C4B41414B38522C534141552C5741476E42432C594141612C53414153432C4541414F432C4741477A422C4741464178542C4B41414B432C4D41414D2C6341416575';
wwv_flow_api.g_varchar2_table(290) := '542C4741457442442C4541414D452C514141532C434147662C49414149432C4541474A2C47414C4131542C4B41414B432C4D41414D2C77424141794273542C4541414D452C514141516A542C51414B39432B532C4541414D452C514141516A542C4F4141';
wwv_flow_api.g_varchar2_table(291) := '4F2C454141472C43414578422C4941414B2C494141492B442C454141492C45414147412C4541414967502C4541414D452C514141516A542C4F4141512B442C4941414B2C43414533432C4741414967502C4541414D452C514141516C502C474141476D4D';
wwv_flow_api.g_varchar2_table(292) := '2C4D41414F2C434143784267442C45414157482C4541414D452C514141516C502C474141476D4D2C4D414335422C4D41474A2C4941414969442C4541414D4A2C4541414D452C514141516C502C47414578422C47414167432C574141354268442C4B4141';
wwv_flow_api.g_varchar2_table(293) := '4B70472C51414151652C6341475679582C454141492C49414149412C454141492C4B41435870532C4B41414B542C4F41414F442C4F41414F2C4341414368462C4941414938582C454141492C4741414737582C4941414936582C454141492C4B41457643';
wwv_flow_api.g_varchar2_table(294) := '70532C4B41414B71532C6B4241416B4272522C4B41414B2C434143784275462C534141532C4941414933482C4F41414F432C4B41414B432C4F41414F73542C454141492C47414149412C454141492C4941433543452C4F41414F462C454141492C574149';
wwv_flow_api.g_varchar2_table(295) := '68422C47414167432C574141354270532C4B41414B70472C51414151652C63414130422C43414B39432C494141496F532C454141612C4741556A422C4741524971462C4541414933502C4941434A734B2C45414157394A2C4B41414F6D502C4541414933';
wwv_flow_api.g_varchar2_table(296) := '502C474147744232502C454141496A522C4941434A344C2C45414157684B2C4741414B71502C454141496A522C474147704269522C454141496C502C4541434A2C4941414B2C4941414930452C454141492C45414147412C4741414B2C47414149412C49';
wwv_flow_api.g_varchar2_table(297) := '41436A42774B2C454141496C502C454141452C4941414930452C4B4145566D462C454141572C514141512C494141496E462C474141477A452C4F41414F2C4941414D69502C454141496C502C454141452C4941414930452C49414B37446C4F2C45414145';
wwv_flow_api.g_varchar2_table(298) := '34462C4F41414F38532C4541414976452C514141532C43414143642C57414161412C49414570432F4D2C4B41414B344E2C6141416177452C4541414976452C514141532C4B41414D2C4341414330452C65414169422C59414B76442C47414147482C4541';
wwv_flow_api.g_varchar2_table(299) := '414939502C4741414738502C4541414937502C454141472C4341436276432C4B41414B542C4F41414F442C4F41414F2C4341414368462C4941414938582C4541414939502C454141452F482C4941414936582C4541414937502C49414574432C49414149';
wwv_flow_api.g_varchar2_table(300) := '72422C454141536C422C4B41414B6B432C574141576B512C474147374270532C4B41414B2B452C514141512F442C4B41414B452C474145646B522C454141496A522C4741454A6E422C4B41414B77532C53414153432C494141494C2C454141496A522C45';
wwv_flow_api.g_varchar2_table(301) := '41414736422C49414D724368442C4B41414B70472C5141415177432C674241456271432C4B41414B432C4D41414D2C5941435073422C4B41414B542C4F41414F6D4E2C6541416577442C53414333426C512C4B41414B542C4F41414F6F4E2C6541416575';
wwv_flow_api.g_varchar2_table(302) := '442C5541452F426C512C4B41414B432C4941414931432C5541415579432C4B41414B542C5341493542532C4B41414B6B462C57414161384D2C4541414D452C514141516A542C4F414970432C474141496B542C4541454131542C4B41414B432C4D41414D';
wwv_flow_api.g_varchar2_table(303) := '79512C4D41414D67442C4741436A426E532C4B41414B33422C5941415938542C554145566E532C4B41414B77532C5341435A78532C4B41414B34522C71424145462C4741414B35522C4B41414B6B462C554141596C462C4B41414B70472C514141514F2C';
wwv_flow_api.g_varchar2_table(304) := '6141436C4336582C4541414D452C514141516A542C51414155652C4B41414B70472C51414151512C614141652C434147784471452C4B41414B36452C4F41414F2C4941414974442C4B41414B70472C51414151432C55414155304A2C5141436E432C6341';
wwv_flow_api.g_varchar2_table(305) := '41652C4341436674442C49414159442C4B41414B432C4941436A4279532C5541415931532C4B41414B6B462C5541436A42694C2C554141596E512C4B41414B542C4F41414F6D4E2C6541416577442C5341437643452C5541415970512C4B41414B542C4F';
wwv_flow_api.g_varchar2_table(306) := '41414F6F4E2C6541416575442C57414733432B422C474141596A532C4B41414B70472C51414151512C6141457A422C4941414975592C4541415933532C4B41414B70472C51414151512C6141477A4234462C4B41414B6B462C55414159794E2C45414159';
wwv_flow_api.g_varchar2_table(307) := '33532C4B41414B70472C514141514F2C634143314377592C4541415933532C4B41414B70472C514141514F2C5941416336462C4B41414B6B462C57414768442C4941414939432C4541415170432C4B41455A76422C4B41414B6D552C4F41414F432C4F41';
wwv_flow_api.g_varchar2_table(308) := '435237532C4B41414B70472C51414151452C654143622C43414145675A2C5541415939532C4B41414B70472C51414151472C5541437A42675A2C49414159642C4541435A652C494141594C2C474145642C434141454D2C534141572C4F414358432C5141';
wwv_flow_api.g_varchar2_table(309) := '41532C534141536C422C4741436476542C4B41414B432C4D41414D2C754241435830442C4541414D32502C59414159432C4541414F432C55414968432C434147482C47414173422C4741416C426A532C4B41414B6B462C69424145456C462C4B41414B36';
wwv_flow_api.g_varchar2_table(310) := '442C4D414575422C4B41412F4237442C4B41414B70472C514141516D442C674241436230422C4B41414B432C4D41414D2C694341435873422C4B41414B33422C5941415932422C4B41414B70472C514141516D442C7142414B6C432C4F41415169442C4B';
wwv_flow_api.g_varchar2_table(311) := '41414B70472C51414151652C65414372422C4941414B2C6141434471462C4B41414B36492C6341454C2C4D41434A2C4941414B2C5541474737492C4B41414B6D542C6B4241434C31552C4B41414B432C4D41414D2C674341435873422C4B41414B6D542C';
wwv_flow_api.g_varchar2_table(312) := '674241416742432C674241477A4233552C4B41414B432C4D41414D2C304241435873422C4B41414B6D542C674241416B422C49414149452C67424141674272542C4B41414B432C4941414B442C4B41414B2B452C514141532C43414143754F2C55414155';
wwv_flow_api.g_varchar2_table(313) := '74542C4B41414B2B512C6341456E462C4D41434A2C4941414B2C614143442F512C4B41414B2B442C5941454C2C4D41434A2C4941414B2C554145472F442C4B41414B75542C6541434C39552C4B41414B432C4D41414D2C754241435873422C4B41414B75';
wwv_flow_api.g_varchar2_table(314) := '542C6141416178542C4F41414F2C4D41437A42432C4B41414B75542C61414161704F2C51414774426E462C4B41414B75542C614141652C4941414933552C4F41414F432C4B41414B32552C63414163432C614141612C43414333446C532C4B4141637642';
wwv_flow_api.g_varchar2_table(315) := '2C4B41414B71532C6B4241436E4270532C49414163442C4B41414B432C4941436E4279542C5941416331542C4B41414B70472C514141516D422C6D424143334234592C5141416333542C4B41414B70472C514141516F422C654143334267532C4F414163';
wwv_flow_api.g_varchar2_table(316) := '684E2C4B41414B70472C5141415171422C674241472F422B452C4B41414B71532C6B4241416B426C4E2C4F414F2F4231472C4B41414B36452C4F41414F2C4941414974442C4B41414B70472C51414151432C55414155304A2C5141436C4376442C4B4141';
wwv_flow_api.g_varchar2_table(317) := '4B34542C554141552C654141652C594141632C434143374333542C49414159442C4B41414B432C4941436A4279532C5541415931532C4B41414B6B462C5541436A42694C2C554141596E512C4B41414B542C4F41414F6D4E2C6541416577442C53414376';
wwv_flow_api.g_varchar2_table(318) := '43452C5541415970512C4B41414B542C4F41414F6F4E2C6541416575442C57414733436C512C4B41414B34542C574141592C4541476A4235542C4B41414B36442C4D41415137442C4B41414B77532C674241435878532C4B41414B77532C5341455A7853';
wwv_flow_api.g_varchar2_table(319) := '2C4B41414B34522C734241495435522C4B41414B34522C6942414D6231542C514141532C5741474C2C474146414F2C4B41414B432C4D41414D2C714241435873422C4B41414B6E432C634143446D432C4B41414B70472C514141514D2C574141592C4341';
wwv_flow_api.g_varchar2_table(320) := '437A4275452C4B41414B36452C4F41414F2C4941414974442C4B41414B70472C51414151432C55414155304A2C514141512C71424145334376442C4B41414B70472C5141415167442C634143546F442C4B41414B36522C5341434C37522C4B41414B3652';
wwv_flow_api.g_varchar2_table(321) := '2C514141516A522C5341456A426E432C4B41414B432C4D41414D2C674241435873422C4B41414B36522C5141415570542C4B41414B6F562C4B41414B6A582C594141596C442C454141452C4941414973472C4B41414B70472C51414151432C5941473544';
wwv_flow_api.g_varchar2_table(322) := '2C4941414975492C4541415170432C4B41435232532C4541415933532C4B41414B70472C51414151512C6141457A4234462C4B41414B70472C514141514F2C5941416377592C4941433342412C4541415933532C4B41414B70472C514141514F2C614147';
wwv_flow_api.g_varchar2_table(323) := '374273452C4B41414B6D552C4F41414F432C4F41435237532C4B41414B70472C51414151452C654143622C43414145675A2C5541415939532C4B41414B70472C51414151472C5541437A42675A2C494141592C4541435A432C494141594C2C474145642C';
wwv_flow_api.g_varchar2_table(324) := '434141454D2C534141572C4F414358432C514141532C534141536C422C4741436476542C4B41414B432C4D41414D2C774241455830442C4541414D36432C694241454E37432C4541414D69512C6B4241416F422C47414331426A512C4541414D32432C51';
wwv_flow_api.g_varchar2_table(325) := '4141552C474143684233432C4541414D37432C4F4141532C49414149582C4F41414F432C4B41414B73502C6141472F422F4C2C4541414D6F512C534141572C494141496C422C49414566552C4541414D452C53414153462C4541414D452C514141512C49';
wwv_flow_api.g_varchar2_table(326) := '414149462C4541414D452C514141512C474141472F432C4F41456C442F4D2C4541414D2F442C5941415932542C4541414D452C514141512C474141472F432C4F41436E432F4D2C4541414D77502C694241494E78502C4541414D32502C59414159432C45';
wwv_flow_api.g_varchar2_table(327) := '41414F2C57414D7A4368532C4B41414B34522C6942414D626B432C534141552C5741454639542C4B41414B75542C634141674276542C4B41414B75542C6141416133532C53414376435A2C4B41414B75462C674241416B4276462C4B41414B75462C5141';
wwv_flow_api.g_varchar2_table(328) := '43354276462C4B41414B6F482C30424141344270482C4B41414B6F482C6B424143744370482C4B41414B73492C30424141344274492C4B41414B73492C6B424143314374492C4B41414B69462C694241434C6A462C4B41414B6E432C6341434C6D432C4B';
wwv_flow_api.g_varchar2_table(329) := '41414B432C49414149572C55414B626D542C594141612C574145542F542C4B41414B67552C59414161432C5941497442432C574141592C5341415535472C4541414B76462C47414B76422C4F414A41744A2C4B41414B432C4D41414D344F2C4541414B76';
wwv_flow_api.g_varchar2_table(330) := '462C4741495275462C474143522C4941414B2C6942414344744E2C4B41414B432C494141496B552C574141572C43414143432C6541416742724D2C4541414D2C494141492C5341452F432C4D41434A2C4941414B2C6D424143442F482C4B41414B432C49';
wwv_flow_api.g_varchar2_table(331) := '4141496B552C574141572C43414143452C694241416B42744D2C4541414D2C494141492C5341456A442C4D41434A2C4941414B2C6F424143442F482C4B41414B432C494141496B552C574141572C43414143472C6B4241416D42764D2C4541414D2C4941';
wwv_flow_api.g_varchar2_table(332) := '41492C5341456C442C4D41434A2C4941414B2C554143442F482C4B41414B432C494141496B552C574141572C4341414335442C5141415167452C53414153784D2C4B414574432C4D41434A2C4941414B2C6F424143442F482C4B41414B432C494141496B';
wwv_flow_api.g_varchar2_table(333) := '552C574141572C434141434B2C6B4241416D427A4D2C4541414D2C494141492C5341456C442C4D41434A2C4941414B2C554143442F482C4B41414B432C4941414977552C61414161314D2C4541414D324D2C654143354231552C4B41414B32552C4F4141';
wwv_flow_api.g_varchar2_table(334) := '5172482C4541414B76462C4741456C422C4D41434A2C4941414B2C69424143442F482C4B41414B432C494141496B552C574141572C43414143532C6541416742374D2C4541414D2C494141492C5341452F432C4D41434A2C4941414B2C554143442F482C';
wwv_flow_api.g_varchar2_table(335) := '4B41414B432C494141496B552C574141572C43414143315A2C51414151385A2C53414153784D2C4B414374432F482C4B41414B32552C4F41415172482C4541414B76462C4741456C422C4D41434A2C4941414B2C554143442F482C4B41414B432C494141';
wwv_flow_api.g_varchar2_table(336) := '496B552C574141572C43414143335A2C514141512B5A2C53414153784D2C4B414374432F482C4B41414B32552C4F41415172482C4541414B76462C4741456C422C4D41434A2C4941414B2C67424143442F482C4B41414B432C494141496B552C57414157';
wwv_flow_api.g_varchar2_table(337) := '2C43414143552C63414165394D2C4541414D2C494141492C53414539432C4D41434A2C4941414B2C654143442F482C4B41414B432C494141496B552C574141572C43414143572C614141632F4D2C4541414D2C494141492C53414537432C4D41434A2C49';
wwv_flow_api.g_varchar2_table(338) := '41414B2C6F424143442F482C4B41414B432C494141496B552C574141572C43414143592C6B4241416D42684E2C4541414D2C494141492C5341456C442C4D41434A2C4941414B2C534143442F482C4B41414B432C494141496B552C574141572C43414143';
wwv_flow_api.g_varchar2_table(339) := '39432C4F41414F744A2C49414335422F482C4B41414B32552C4F4141512C57414159354D2C4741457A422C4D41434A2C4941414B2C634143442F482C4B41414B432C494141496B552C574141572C434141436A442C594141616E4A2C4541414D2C494141';
wwv_flow_api.g_varchar2_table(340) := '492C53414535432C4D41434A2C4941414B2C4F4143442F482C4B41414B432C494141492B552C51414151542C53414153784D2C49414531422C4D41434A2C4941414B2C4F4143442F482C4B41414B432C494141496F442C514141516B522C53414153784D';
wwv_flow_api.g_varchar2_table(341) := '2C49414531422C4D41434A2C514143492F482C4B41414B32552C4F41415172482C4541414B76462C4F414D31422C4D41414D6A492C5541416D426C422C4F41414F432C4B41414B6F572C5941436A43432C5941415939562C4541415378462C4741436A42';
wwv_flow_api.g_varchar2_table(342) := '75622C514143416E562C4B41414B6F562C5341415768572C4541436842592C4B41414B71562C534141577A622C4541457042412C63414167422C4F41414F6F472C4B41414B71562C53414335427A622C5941415930622C4741414B74562C4B41414B7156';
wwv_flow_api.g_varchar2_table(343) := '2C53414157432C4541436A436C572C63414167422C4F41414F592C4B41414B6F562C534143354268572C5941415975442C4741414B33432C4B41414B6F562C534141577A532C4541436A4370452C554141592C4F41414F79422C4B41414B71562C534141';
wwv_flow_api.g_varchar2_table(344) := '5339572C4941436A43412C5141415138472C4741414B72462C4B41414B71562C5341415339572C4941414D38472C4541436A4339462C614141652C4F41414F532C4B41414B71562C5341415339562C4F41437043412C57414157694E2C4741414B784D2C';
wwv_flow_api.g_varchar2_table(345) := '4B41414B71562C5341415339562C4F414153694E2C45414376436E4C2C554141592C4F41414F72422C4B41414B75562C4B414378424C2C514145496C562C4B41414B75562C4B41414F6E562C53414153432C634141632C4F41436E434C2C4B41414B7556';
wwv_flow_api.g_varchar2_table(346) := '2C4B41414B354C2C4D41414D364C2C594141632C4F4143394278562C4B41414B75562C4B41414B354C2C4D41414D384C2C594141632C4D414339427A562C4B41414B75562C4B41414B354C2C4D41414D76492C534141572C574143334270422C4B41414B';
wwv_flow_api.g_varchar2_table(347) := '75562C4B41414B37552C55414159562C4B41414B6F562C53414533422C4D41414D4D2C4541415131562C4B41414B32562C5741436633562C4B41414B71562C534141537A562C674241476438562C4541414D452C6D4241416D4270562C59414159522C4B';
wwv_flow_api.g_varchar2_table(348) := '41414B75562C4D4143314333572C4F41414F432C4B41414B6F572C59414159592C6D4241416D4237562C4B41414B75562C4D4143684439572C4B41414B432C4D41414D2C6B43414358452C4F41414F432C4B41414B32452C4D41414D73532C6541416539';
wwv_flow_api.g_varchar2_table(349) := '562C4B41414B75562C4B41414D2C5141415376562C4B41414B71562C534141537A562C694241476E4538562C4541414D4B2C6141416176562C59414159522C4B41414B75562C4D414735434C2C4F4143492C474141496C562C4B41414B75562C4B41414D';
wwv_flow_api.g_varchar2_table(350) := '2C434143582C4D41414D532C4541416F4268572C4B41414B69572C674241457A4235462C4541444D72512C4B41414B6B572C5341434135462C5541436A422C4741414B442C4941415372512C4B41414B71562C5341415337612C534141532C4941415136';
wwv_flow_api.g_varchar2_table(351) := '562C4941415372512C4B41414B71562C5341415335612C534141532C4941437A452C4741414975462C4B41414B71562C5341415339562C4F4141512C43414374422C4D41414D34572C4541414B482C4541416B42492C714241437A4270572C4B41414B71';
wwv_flow_api.g_varchar2_table(352) := '562C5341415339562C4F41414F6D4E2C674241456E42324A2C4541414B4C2C4541416B42492C714241437A4270572C4B41414B71562C5341415339562C4F41414F6F4E2C674241477242334D2C4B41414B75562C4F41434C76562C4B41414B75562C4B41';
wwv_flow_api.g_varchar2_table(353) := '414B354C2C4D41414D324D2C4B41414F482C4541414737542C454141492C4B4143394274432C4B41414B75562C4B41414B354C2C4D41414D344D2C4941414D462C4541414739542C454141492C4B4143374276432C4B41414B75562C4B41414B354C2C4D';
wwv_flow_api.g_varchar2_table(354) := '41414D364D2C4D414153482C454141472F542C4541414936542C4541414737542C4541414B2C4B4143784374432C4B41414B75562C4B41414B354C2C4D41414D384D2C4F4141554E2C4541414735542C4541414938542C4541414739542C4541414B2C57';
wwv_flow_api.g_varchar2_table(355) := '414531432C4741414976432C4B41414B71562C5341415339572C4941414B2C43414331422C4D41414D6D592C45414155562C4541416B42492C71424141714270572C4B41414B71562C5341415339572C4B414372452C494141496F592C45414153432C45';
wwv_flow_api.g_varchar2_table(356) := '4143622C4F41414F35572C4B41414B71562C5341415337562C6742414167426B562C65414372432C4941414B2C5341434469432C4741415733572C4B41414B75562C4B41414B73422C594141592C4541436A432C4D41434A2C4941414B2C51414344462C';
wwv_flow_api.g_varchar2_table(357) := '4741415733572C4B41414B75562C4B41414B73422C59414372422C4D41434A2C51414349462C454141552C454145642C4F41414F33572C4B41414B71562C5341415335562C6341416369562C6541436E432C4941414B2C534143446B432C474141573557';
wwv_flow_api.g_varchar2_table(358) := '2C4B41414B75562C4B41414B75422C61414372422C4D41434A2C4941414B2C53414344462C4741415735572C4B41414B75562C4B41414B75422C614141612C4541436C432C4D41434A2C51414349462C454141552C45414564442C4741415733572C4B41';
wwv_flow_api.g_varchar2_table(359) := '414B71562C5341415333562C6B4241416B422C45414333436B582C4741415735572C4B41414B71562C5341415331562C6742414167422C4541437A434B2C4B41414B75562C4B41414B354C2C4D41414D324D2C4B414151492C4541415170552C45414149';
wwv_flow_api.g_varchar2_table(360) := '71552C454141572C4B41432F4333572C4B41414B75562C4B41414B354C2C4D41414D344D2C4941414F472C454141516E552C4541414971552C454141572C55414539436E592C4B41414B432C4D41414D2C3644414B334277572C574143516C562C4B4141';
wwv_flow_api.g_varchar2_table(361) := '4B75562C4F41434C76562C4B41414B75562C4B41414B77422C57414157432C5941415968582C4B41414B75562C6141432F4276562C4B41414B75562C4D414770424C2C4F4143516C562C4B41414B75562C4F41434C76562C4B41414B75562C4B41414B35';
wwv_flow_api.g_varchar2_table(362) := '4C2C4D41414D734E2C574141612C55414772432F422C4F4143516C562C4B41414B75562C4F41434C76562C4B41414B75562C4B41414B354C2C4D41414D734E2C574141612C57414772432F422C534143516C562C4B41414B75562C4F414338422C574141';
wwv_flow_api.g_varchar2_table(363) := '2F4276562C4B41414B75562C4B41414B354C2C4D41414D734E2C57414368426A582C4B41414B6B582C4F41454C6C582C4B41414B6D582C5141496A426A432C554141556A562C47414346442C4B41414B6B572C5341434C6C572C4B41414B442C4F41414F';
wwv_flow_api.g_varchar2_table(364) := '2C4D41455A432C4B41414B442C4F41414F45222C2266696C65223A226A6B36347265706F72746D61705F72312E6A73227D';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(110134322311139104)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'jk64reportmap_r1.js.map'
,p_mime_type=>'application/json'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2E7265706F72746D61702D64726F702D636F6E7461696E65727B646973706C61793A6E6F6E653B6865696768743A313030253B77696474683A313030253B706F736974696F6E3A6162736F6C7574653B7A2D696E6465783A313B746F703A303B6C656674';
wwv_flow_api.g_varchar2_table(2) := '3A303B6261636B67726F756E642D636F6C6F723A72676261283130302C3130302C3130302C2E35297D2E7265706F72746D61702D64726F702D73696C686F75657474657B636F6C6F723A236666663B626F726465723A2366666620646173686564203870';
wwv_flow_api.g_varchar2_table(3) := '783B6865696768743A63616C632831303025202D2031357078293B77696474683A63616C632831303025202D2031357078293B6261636B67726F756E642D696D6167653A75726C28646174613A696D6167652F706E673B6261736536342C6956424F5277';
wwv_flow_api.g_varchar2_table(4) := '304B47676F414141414E5355684555674141414751414141426B4341594141414277347056554141414141584E5352304941727334633651414141415A6953306445414751415A41426B6B5043735477414141416C7753466C7A4141414C457741414378';
wwv_flow_api.g_varchar2_table(5) := '4D42414A71634741414141416430535531464239304C4841497649435764734B77414141415A6445565964454E766257316C626E514151334A6C5958526C5A4342336158526F4945644A545642586751345841414143646B6C4551565234327533637355';
wwv_flow_api.g_varchar2_table(6) := '376963427A413858703347424D536552495448384A484D593763524D766D566D586F45395441634A7562686A443441706F696F706771444D57414B4167496353416943667875776877524F564A626B504439725032336F623876705A43514B676F414141';
wwv_flow_api.g_varchar2_table(7) := '4141414141414150445979694B2F654E4D3035624E7472362B76536A676358694878444D6B453157705646764763667043564943414951554151676F41674241464243414B436743414541554549416F4951424151684341674367684145424345494345';
wwv_flow_api.g_varchar2_table(8) := '4951454951674941674951684151684341674345464145494B414943414951554151676F4167424146424344497A686D46494E426F392F4B364430585664646E64335A616E654459376A53437156636E3353666A79654B524B4A624A32646E596C6C5762';
wwv_flow_api.g_varchar2_table(9) := '4B556C326935584A61586C78644A4A42497937794448783866793976596D365852364F574D4D33642F6669346849715653535743776D737735796348416772565A4C5245544F7A382B584F385A5170564A35483259366E525A4E302F623944714C727568';
wwv_flow_api.g_varchar2_table(10) := '534C786664394D706B4D4D54364C307576314A4A6C4D696839426876654A7757447776763769346F4959347A77385049774D74743175537A776546362B43484230645362666248566D627A57614A4D636E6A342B4F4841642F6433636E65337036344457';
wwv_flow_api.g_varchar2_table(11) := '4B61706A772F5033395964336C3553597870564B765673594F324C4574555664325A4E6F6975362B49347A746731563164587850416953712F586B354F546B306B39704E567179656E7036636839346C2B3558493459627452714E664861396658317434';
wwv_flow_api.g_varchar2_table(12) := '3378637747612F4E6E6333507764444159394F5A68743238724778675A507650364B5343537939665430394F557277375A74507161386A464B7631313348754C6D3549596258564658646352506C39766157474835476154516155386649352F5045384A';
wwv_flow_api.g_varchar2_table(13) := '756D6166764E5A764F2F4D517146416A466D4A52714E486B364B73716778357672317A7A414D326437656472332F36757171737261324E6E5A6270394E522B76322B36324F48517147357A4F625850494D454167466C665833646C324E373962746C3176';
wwv_flow_api.g_varchar2_table(14) := '69544130464145494B41494151424141414141414141734D7A2B4169316255676F3665626D384141414141456C46546B5375516D4343293B6261636B67726F756E642D7265706561743A6E6F2D7265706561743B6261636B67726F756E642D706F736974';
wwv_flow_api.g_varchar2_table(15) := '696F6E3A63656E7465727D2E7265706F72746D61702D636F6E74726F6C55497B6261636B67726F756E642D636F6C6F723A236666663B626F726465723A32707820736F6C696420236666663B626F726465722D7261646975733A303B626F782D73686164';
wwv_flow_api.g_varchar2_table(16) := '6F773A302032707820347078207267626128302C302C302C2E33293B637572736F723A706F696E7465723B6D617267696E2D746F703A3570783B6D617267696E2D626F74746F6D3A3570783B6D617267696E2D6C6566743A3270783B746578742D616C69';
wwv_flow_api.g_varchar2_table(17) := '676E3A63656E7465723B6865696768743A323870787D2E7265706F72746D61702D636F6E74726F6C496E6E65727B636F6C6F723A233139313931393B666F6E742D66616D696C793A526F626F746F2C417269616C2C73616E732D73657269663B666F6E74';
wwv_flow_api.g_varchar2_table(18) := '2D73697A653A313270783B6D696E2D77696474683A323470783B6D696E2D6865696768743A323470783B6C696E652D6865696768743A323470783B70616464696E672D6C6566743A3570783B70616464696E672D72696768743A3570783B6261636B6772';
wwv_flow_api.g_varchar2_table(19) := '6F756E642D7265706561743A6E6F2D7265706561743B6261636B67726F756E642D706F736974696F6E3A63656E7465727D2E7265706F72746D61702D6D65737361676555497B6261636B67726F756E642D636F6C6F723A236666663861363B626F726465';
wwv_flow_api.g_varchar2_table(20) := '722D7261646975733A3270783B626F782D736861646F773A347078203470782036707820317078207267626128302C302C302C2E33293B6D617267696E3A313070783B746578742D616C69676E3A63656E7465723B6D696E2D6865696768743A33367078';
wwv_flow_api.g_varchar2_table(21) := '7D2E7265706F72746D61702D6D657373616765496E6E65727B636F6C6F723A233730373037303B666F6E742D66616D696C793A526F626F746F2C417269616C2C73616E732D73657269663B666F6E742D73697A653A313670783B6D696E2D77696474683A';
wwv_flow_api.g_varchar2_table(22) := '323470783B6D696E2D6865696768743A323470783B6C696E652D6865696768743A323470783B70616464696E673A37707820313270783B6261636B67726F756E642D7265706561743A6E6F2D7265706561743B6261636B67726F756E642D706F73697469';
wwv_flow_api.g_varchar2_table(23) := '6F6E3A63656E7465727D2E7265706F72746D61702D646562756750616E656C7B6261636B67726F756E642D636F6C6F723A2366336633663337643B6D617267696E2D746F703A3270783B6D617267696E2D626F74746F6D3A303B6D617267696E2D6C6566';
wwv_flow_api.g_varchar2_table(24) := '743A3270783B746578742D616C69676E3A63656E7465727D0A2F2A2320736F757263654D617070696E6755524C3D6A6B36347265706F72746D61705F72312E6373732E6D61702A2F';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(110135202227153116)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'jk64reportmap_r1.min.css'
,p_mime_type=>'text/css'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '7B2276657273696F6E223A332C22736F7572636573223A5B226A6B36347265706F72746D61705F72312E637373225D2C226E616D6573223A5B5D2C226D617070696E6773223A22414141412C79422C434143492C592C434143412C572C434143412C552C';
wwv_flow_api.g_varchar2_table(2) := '434143412C69422C434143412C532C434143412C4B2C434143412C4D2C434143412C71432C4341454A2C30422C434143492C552C434143412C73422C434143412C77422C434143412C75422C434143412C676C432C434143412C32422C434143412C3042';
wwv_flow_api.g_varchar2_table(3) := '2C4341454A2C6F422C434143492C71422C434143412C71422C434143412C652C434143412C6D432C434143412C632C434143412C632C434143412C69422C434143412C652C434143412C69422C434143412C572C4341454A2C75422C434143492C612C43';
wwv_flow_api.g_varchar2_table(4) := '4143412C6D432C434143412C632C434143412C632C434143412C652C434143412C67422C434143412C67422C434143412C69422C434143412C32422C434143412C30422C43414D4A2C6F422C434143492C77422C434143412C69422C434143412C79432C';
wwv_flow_api.g_varchar2_table(5) := '434143412C572C434143412C69422C434143412C652C4341454A2C75422C434143492C612C434143412C6D432C434143412C632C434143412C632C434143412C652C434143412C67422C434143412C67422C434143412C32422C434143412C30422C4341';
wwv_flow_api.g_varchar2_table(6) := '454A2C71422C434143492C30422C434143412C632C434143412C652C434143412C652C434143412C6942222C2266696C65223A226A6B36347265706F72746D61705F72312E637373222C22736F7572636573436F6E74656E74223A5B222E7265706F7274';
wwv_flow_api.g_varchar2_table(7) := '6D61702D64726F702D636F6E7461696E6572207B5C725C6E20202020646973706C61793A206E6F6E653B5C725C6E202020206865696768743A20313030253B5C725C6E2020202077696474683A20313030253B5C725C6E20202020706F736974696F6E3A';
wwv_flow_api.g_varchar2_table(8) := '206162736F6C7574653B5C725C6E202020207A2D696E6465783A20313B5C725C6E20202020746F703A203070783B5C725C6E202020206C6566743A203070783B5C725C6E202020206261636B67726F756E642D636F6C6F723A2072676261283130302C20';
wwv_flow_api.g_varchar2_table(9) := '3130302C203130302C20302E35293B5C725C6E7D5C725C6E2E7265706F72746D61702D64726F702D73696C686F7565747465207B5C725C6E20202020636F6C6F723A2077686974653B5C725C6E20202020626F726465723A207768697465206461736865';
wwv_flow_api.g_varchar2_table(10) := '64203870783B5C725C6E202020206865696768743A2063616C632831303025202D2031357078293B5C725C6E2020202077696474683A2063616C632831303025202D2031357078293B5C725C6E202020206261636B67726F756E642D696D6167653A2075';
wwv_flow_api.g_varchar2_table(11) := '726C2827646174613A696D6167652F706E673B6261736536342C6956424F5277304B47676F414141414E5355684555674141414751414141426B4341594141414277347056554141414141584E5352304941727334633651414141415A69533064454147';
wwv_flow_api.g_varchar2_table(12) := '51415A41426B6B5043735477414141416C7753466C7A4141414C4577414143784D42414A71634741414141416430535531464239304C4841497649435764734B77414141415A6445565964454E766257316C626E514151334A6C5958526C5A4342336158';
wwv_flow_api.g_varchar2_table(13) := '526F4945644A545642586751345841414143646B6C4551565234327533637355376963427A413858703347424D536552495448384A484D593763524D766D566D586F45395441634A7562686A443441706F696F706771444D57414B416749635341694366';
wwv_flow_api.g_varchar2_table(14) := '7875776877524F564A626B504439725032336F623876705A43514B676F4141414141414141414150445979694B2F654E4D3035624E7472362B76536A676358694878444D6B453157705646764763667043564943414951554151676F4167424146424341';
wwv_flow_api.g_varchar2_table(15) := '4B436743414541554549416F49514241516843416743676841454243454943454951454951674941674951684151684341674345464145494B414943414951554151676F4167424146424344497A686D46494E426F392F4B364430585664646E64335A61';
wwv_flow_api.g_varchar2_table(16) := '6E654459376A53437156636E3353666A79654B524B4A624A32646E596C6C57624B556C326935584A61586C78644A4A42497937794448783866793976596D365852364F574D4D33642F6669346849715653535743776D737735796348416772565A4C5245';
wwv_flow_api.g_varchar2_table(17) := '544F7A382B584F385A5170564A35483259366E525A4E302F623944714C727568534C786664394D706B4D4D54364C307576314A4A6C4D696839426876654A7757447776763769346F4959347A77385049774D74743175537A776546362B43484230645362';
wwv_flow_api.g_varchar2_table(18) := '666248566D627A57614A4D636E6A342B4F4841642F6433636E653370363444574B61706A772F5033395964336C3553597870564B765673594F324C4574555664325A4E6F6975362B49347A746731563164587850416953712F586B354F546B306B39704E';
wwv_flow_api.g_varchar2_table(19) := '567179656E7036636839346C2B3558493459627452714E6648613966583174343378637747612F4E6E6333507764444159394F5A68743238724778675A507650364B5343537939665430394F557277375A74507161386A464B7631313348754C6D354959';
wwv_flow_api.g_varchar2_table(20) := '6258564658646352506C39766157474835476154516155386649352F5045384A756D6166764E5A764F2F4D517146416A466D4A52714E486B364B73716778357672317A7A414D326437656472332F36757171737261324E6E5A6270394E522B76322B3632';
wwv_flow_api.g_varchar2_table(21) := '4F48517147357A4F625850494D454167466C665833646C324E373962746C317669544130464145494B41494151424141414141414141734D7A2B4169316255676F3665626D384141414141456C46546B5375516D434327293B5C725C6E20202020626163';
wwv_flow_api.g_varchar2_table(22) := '6B67726F756E642D7265706561743A206E6F2D7265706561743B5C725C6E202020206261636B67726F756E642D706F736974696F6E3A2063656E7465723B5C725C6E7D5C725C6E2E7265706F72746D61702D636F6E74726F6C5549207B5C725C6E202020';
wwv_flow_api.g_varchar2_table(23) := '206261636B67726F756E642D636F6C6F723A20236666663B5C725C6E20202020626F726465723A2032707820736F6C696420236666663B5C725C6E20202020626F726465722D7261646975733A203070783B5C725C6E20202020626F782D736861646F77';
wwv_flow_api.g_varchar2_table(24) := '3A20302032707820347078207267626128302C302C302C2E33293B5C725C6E20202020637572736F723A20706F696E7465723B5C725C6E202020206D617267696E2D746F703A203570783B5C725C6E202020206D617267696E2D626F74746F6D3A203570';
wwv_flow_api.g_varchar2_table(25) := '783B5C725C6E202020206D617267696E2D6C6566743A203270783B5C725C6E20202020746578742D616C69676E3A2063656E7465723B5C725C6E202020206865696768743A20323870783B5C725C6E7D5C725C6E2E7265706F72746D61702D636F6E7472';
wwv_flow_api.g_varchar2_table(26) := '6F6C496E6E6572207B5C725C6E20202020636F6C6F723A207267622832352C32352C3235293B5C725C6E20202020666F6E742D66616D696C793A20526F626F746F2C417269616C2C73616E732D73657269663B5C725C6E20202020666F6E742D73697A65';
wwv_flow_api.g_varchar2_table(27) := '3A20313270783B5C725C6E202020206D696E2D77696474683A20323470783B5C725C6E202020206D696E2D6865696768743A20323470783B5C725C6E202020206C696E652D6865696768743A20323470783B5C725C6E2020202070616464696E672D6C65';
wwv_flow_api.g_varchar2_table(28) := '66743A203570783B5C725C6E2020202070616464696E672D72696768743A203570783B5C725C6E202020206261636B67726F756E642D7265706561743A206E6F2D7265706561743B5C725C6E202020206261636B67726F756E642D706F736974696F6E3A';
wwv_flow_api.g_varchar2_table(29) := '2063656E7465723B5C725C6E7D5C725C6E2E7265706F72746D61702D636F6E74726F6C436865636B626F78207B5C725C6E7D5C725C6E2E7265706F72746D61702D636F6E74726F6C436865636B626F784C6162656C207B5C725C6E7D5C725C6E2E726570';
wwv_flow_api.g_varchar2_table(30) := '6F72746D61702D6D6573736167655549207B5C725C6E202020206261636B67726F756E642D636F6C6F723A20236666663861363B5C725C6E20202020626F726465722D7261646975733A203270783B5C725C6E20202020626F782D736861646F773A2034';
wwv_flow_api.g_varchar2_table(31) := '7078203470782036707820317078207267626128302C302C302C2E33293B5C725C6E202020206D617267696E3A20313070783B5C725C6E20202020746578742D616C69676E3A2063656E7465723B5C725C6E202020206D696E2D6865696768743A203336';
wwv_flow_api.g_varchar2_table(32) := '70783B5C725C6E7D5C725C6E2E7265706F72746D61702D6D657373616765496E6E6572207B5C725C6E20202020636F6C6F723A20233730373037303B5C725C6E20202020666F6E742D66616D696C793A20526F626F746F2C417269616C2C73616E732D73';
wwv_flow_api.g_varchar2_table(33) := '657269663B5C725C6E20202020666F6E742D73697A653A20313670783B5C725C6E202020206D696E2D77696474683A20323470783B5C725C6E202020206D696E2D6865696768743A20323470783B5C725C6E202020206C696E652D6865696768743A2032';
wwv_flow_api.g_varchar2_table(34) := '3470783B5C725C6E2020202070616464696E673A2037707820313270782037707820313270783B5C725C6E202020206261636B67726F756E642D7265706561743A206E6F2D7265706561743B5C725C6E202020206261636B67726F756E642D706F736974';
wwv_flow_api.g_varchar2_table(35) := '696F6E3A2063656E7465723B5C725C6E7D5C725C6E2E7265706F72746D61702D646562756750616E656C207B5C725C6E202020206261636B67726F756E642D636F6C6F723A202366336633663337643B5C725C6E202020206D617267696E2D746F703A20';
wwv_flow_api.g_varchar2_table(36) := '3270783B5C725C6E202020206D617267696E2D626F74746F6D3A203070783B5C725C6E202020206D617267696E2D6C6566743A203270783B5C725C6E20202020746578742D616C69676E3A2063656E7465723B5C725C6E7D5C725C6E225D7D';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(110135602131153117)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'jk64reportmap_r1.css.map'
,p_mime_type=>'application/json'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '6576616C2866756E6374696F6E28702C612C632C6B2C652C72297B653D66756E6374696F6E2863297B72657475726E28633C613F27273A65287061727365496E7428632F612929292B2828633D632561293E33353F537472696E672E66726F6D43686172';
wwv_flow_api.g_varchar2_table(2) := '436F646528632B3239293A632E746F537472696E6728333629297D3B6966282127272E7265706C616365282F5E2F2C537472696E6729297B7768696C6528632D2D29725B652863295D3D6B5B635D7C7C652863293B6B3D5B66756E6374696F6E2865297B';
wwv_flow_api.g_varchar2_table(3) := '72657475726E20725B655D7D5D3B653D66756E6374696F6E28297B72657475726E275C5C772B277D3B633D317D3B7768696C6528632D2D296966286B5B635D29703D702E7265706C616365286E65772052656745787028275C5C62272B652863292B275C';
wwv_flow_api.g_varchar2_table(4) := '5C62272C276727292C6B5B635D293B72657475726E20707D282735204728622C61297B622E4E28292E5628472C6E2E6F2E325A293B342E493D623B342E32453D622E4E28292E327928293B342E4D3D613B342E433D743B342E713D743B342E31363D743B';
wwv_flow_api.g_varchar2_table(5) := '342E316F3D773B342E4B28622E762829297D472E362E32463D3528297B3720643D343B3720673B3720663B342E713D33412E33752822315922293B342E712E35703D342E32453B3928342E316F297B342E326128297D342E344F28292E34482E34422834';
wwv_flow_api.g_varchar2_table(6) := '2E71293B342E32583D6E2E6F2E752E314728342E7628292C223462222C3528297B663D677D293B6E2E6F2E752E314528342E712C223432222C3528297B673D483B663D777D293B6E2E6F2E752E314528342E712C22324D222C352865297B673D773B3928';
wwv_flow_api.g_varchar2_table(7) := '2166297B3720633B3720623B3720613D642E492E4E28293B6E2E6F2E752E5828612C22324D222C642E49293B6E2E6F2E752E5828612C223356222C642E49293B3928612E32422829297B623D612E317928293B633D642E492E317328293B612E7628292E';
wwv_flow_api.g_varchar2_table(8) := '31562863293B3155283528297B612E7628292E31562863293B392862213D3D74262628612E7628292E313728293E6229297B612E7628292E334628622B31297D7D2C337A297D652E33773D483B3928652E326A297B652E326A28297D7D7D293B6E2E6F2E';
wwv_flow_api.g_varchar2_table(9) := '752E314528342E712C223255222C3528297B3720613D642E492E4E28293B6E2E6F2E752E5828612C223255222C642E49297D293B6E2E6F2E752E314528342E712C22324C222C3528297B3720613D642E492E4E28293B6E2E6F2E752E5828612C22324C22';
wwv_flow_api.g_varchar2_table(10) := '2C642E49297D297D3B472E362E32513D3528297B3928342E712626342E712E3365297B342E314628293B6E2E6F2E752E336228342E3258293B6E2E6F2E752E353728342E71293B342E712E33652E345A28342E71293B342E713D747D7D3B472E362E3338';
wwv_flow_api.g_varchar2_table(11) := '3D3528297B3928342E316F297B3720613D342E323828342E43293B342E712E552E314A3D612E792B227A223B342E712E552E31483D612E782B227A227D7D3B472E362E31463D3528297B3928342E71297B342E712E552E33363D223256227D342E316F3D';
wwv_flow_api.g_varchar2_table(12) := '777D3B472E362E32613D3528297B3928342E71297B3720653D22223B3720633D342E33672E346A28222022293B3720623D313228635B305D2E314E28292C3130293B3720643D313228635B315D2E314E28292C3130293B3720613D342E323828342E4329';
wwv_flow_api.g_varchar2_table(13) := '3B342E712E552E34333D342E32502861293B653D223C343120335A3D5C27222B342E324F2B225C2720553D5C2732303A20315A3B20314A3A20222B642B227A3B2031483A20222B622B227A3B20223B392821342E492E4E28292E316C297B652B3D223359';
wwv_flow_api.g_varchar2_table(14) := '3A20335828222B282D312A64292B227A2C20222B28282D312A62292B342E3172292B227A2C20222B28282D312A64292B342E316B292B227A2C20222B282D312A62292B227A293B227D652B3D225C273E223B342E712E33573D652B223C315920553D5C27';
wwv_flow_api.g_varchar2_table(15) := '222B2232303A20315A3B222B22314A3A20222B342E31585B305D2B227A3B222B2231483A20222B342E31585B315D2B227A3B222B2233543A20222B342E32442B223B222B22314F2D31663A20222B342E327A2B227A3B222B22314F2D33503A20222B342E';
wwv_flow_api.g_varchar2_table(16) := '32762B223B222B22314F2D334E3A20222B342E32742B223B222B22314F2D553A20222B342E32732B223B222B2231772D33493A20222B342E326F2B223B222B2231772D33453A2031683B222B2231783A20222B342E31722B227A3B222B2233422D31753A';
wwv_flow_api.g_varchar2_table(17) := '222B342E316B2B227A3B222B225C273E222B342E31362E31772B223C2F31593E223B3928315120342E31362E31343D3D3D223135227C7C342E31362E31343D3D3D2222297B342E712E31343D342E492E4E28292E324728297D4C7B342E712E31343D342E';
wwv_flow_api.g_varchar2_table(18) := '31362E31347D342E712E552E33363D22227D342E316F3D487D3B472E362E33693D352861297B342E31363D613B3720623D412E337028302C612E32542D31293B623D412E323228342E4D2E702D312C62293B3720633D342E4D5B625D3B342E324F3D632E';
wwv_flow_api.g_varchar2_table(19) := '33663B342E316B3D632E31753B342E31723D632E31783B342E31583D632E356D7C7C5B302C305D3B342E32633D632E35677C7C5B313228342E316B2F322C3130292C313228342E31722F322C3130295D3B342E32443D632E35627C7C223535223B342E32';
wwv_flow_api.g_varchar2_table(20) := '7A3D632E35317C7C31313B342E326F3D632E34567C7C223256223B342E32743D632E34547C7C223452223B342E32733D632E344E7C7C22344B223B342E32763D632E344A7C7C2234492C34472D3446223B342E33673D632E34447C7C22302030227D3B47';
wwv_flow_api.g_varchar2_table(21) := '2E362E33683D352861297B342E433D617D3B472E362E32503D352862297B3720613D5B5D3B612E59282234413A2034793B22293B612E59282232303A20315A3B20314A3A20222B622E792B227A3B2031483A20222B622E782B227A3B22293B612E592822';
wwv_flow_api.g_varchar2_table(22) := '31783A20222B342E31722B227A3B2031753A20222B342E316B2B227A3B22293B6A20612E3476282222297D3B472E362E32383D352862297B3720613D342E333728292E31502862293B612E782D3D342E32635B315D3B612E792D3D342E32635B305D3B61';
wwv_flow_api.g_varchar2_table(23) := '2E783D313228612E782C3130293B612E793D313228612E792C3130293B6A20617D3B3520442861297B342E573D613B342E513D612E7628293B342E543D612E336328293B342E31333D612E325328293B342E31383D612E336128293B342E6B3D5B5D3B34';
wwv_flow_api.g_varchar2_table(24) := '2E433D743B342E32653D743B342E5A3D46204728342C612E32332829297D442E362E34353D3528297B6A20342E6B2E707D3B442E362E31443D3528297B6A20342E6B7D3B442E362E32523D3528297B6A20342E437D3B442E362E763D3528297B6A20342E';
wwv_flow_api.g_varchar2_table(25) := '517D3B442E362E4E3D3528297B6A20342E577D3B442E362E31733D3528297B3720693B3720623D46206E2E6F2E316D28342E432C342E43293B3720613D342E314428293B4228693D303B693C612E703B692B2B297B622E5628615B695D2E532829297D6A';
wwv_flow_api.g_varchar2_table(26) := '20627D3B442E362E31433D3528297B342E5A2E4B2874293B342E6B3D5B5D3B323120342E6B7D3B442E362E31423D352865297B3720693B3720633B3720623B3928342E324E286529297B6A20777D392821342E43297B342E433D652E5328293B342E3235';
wwv_flow_api.g_varchar2_table(27) := '28297D4C7B3928342E3138297B37206C3D342E6B2E702B313B3720613D28342E432E4F28292A286C2D31292B652E5328292E4F2829292F6C3B3720643D28342E432E313928292A286C2D31292B652E5328292E31392829292F6C3B342E433D46206E2E6F';
wwv_flow_api.g_varchar2_table(28) := '2E317128612C64293B342E323528297D7D652E31703D483B342E6B2E592865293B633D342E6B2E703B623D342E572E317928293B392862213D3D742626342E512E313728293E62297B3928652E762829213D3D342E51297B652E4B28342E51297D7D4C20';
wwv_flow_api.g_varchar2_table(29) := '3928633C342E3133297B3928652E762829213D3D342E51297B652E4B28342E51297D7D4C203928633D3D3D342E3133297B4228693D303B693C633B692B2B297B342E6B5B695D2E4B2874297D7D4C7B652E4B2874297D342E324B28293B6A20487D3B442E';
wwv_flow_api.g_varchar2_table(30) := '362E324A3D352861297B6A20342E32652E324928612E532829297D3B442E362E32353D3528297B3720613D46206E2E6F2E316D28342E432C342E43293B342E32653D342E572E32662861297D3B442E362E324B3D3528297B3720633D342E6B2E703B3720';
wwv_flow_api.g_varchar2_table(31) := '613D342E572E317928293B392861213D3D742626342E512E313728293E61297B342E5A2E314628293B6A7D3928633C342E3133297B342E5A2E314628293B6A7D3720623D342E572E323328292E703B3720643D342E572E3248282928342E6B2C62293B34';
wwv_flow_api.g_varchar2_table(32) := '2E5A2E336828342E43293B342E5A2E33692864293B342E5A2E326128297D3B442E362E324E3D352861297B3720693B3928342E6B2E3164297B6A20342E6B2E3164286129213D3D2D317D4C7B4228693D303B693C342E6B2E703B692B2B297B3928613D3D';
wwv_flow_api.g_varchar2_table(33) := '3D342E6B5B695D297B6A20487D7D7D6A20777D3B35203828612C632C62297B342E5628382C6E2E6F2E325A293B633D637C7C5B5D3B623D627C7C7B7D3B342E6B3D5B5D3B342E453D5B5D3B342E316A3D5B5D3B342E31653D743B342E31693D773B342E54';
wwv_flow_api.g_varchar2_table(34) := '3D622E33557C7C33533B342E31333D622E33527C7C323B342E31573D622E32437C7C743B342E4D3D622E33517C7C5B5D3B342E32643D622E31347C7C22223B342E317A3D483B3928622E3241213D3D3135297B342E317A3D622E32417D342E31383D773B';
wwv_flow_api.g_varchar2_table(35) := '3928622E326B213D3D3135297B342E31383D622E326B7D342E31613D773B3928622E3278213D3D3135297B342E31613D622E32787D342E316C3D773B3928622E3277213D3D3135297B342E316C3D622E32777D342E31493D622E334F7C7C382E32753B34';
wwv_flow_api.g_varchar2_table(36) := '2E31743D622E334C7C7C382E32673B342E31633D622E334A7C7C382E32723B342E31543D622E33487C7C382E32703B342E31523D622E33477C7C382E326E3B342E31763D622E33447C7C382E326D3B342E31533D622E33437C7C2250223B3928334B2E33';
wwv_flow_api.g_varchar2_table(37) := '792E334D28292E3164282233782229213D3D2D31297B342E31523D342E31767D342E327128293B342E326C28632C48293B342E4B2861297D382E362E32463D3528297B3720613D343B342E31653D342E7628293B342E31693D483B342E316228293B342E';
wwv_flow_api.g_varchar2_table(38) := '316A3D5B6E2E6F2E752E314728342E7628292C223376222C3528297B612E31412877293B3928342E313728293D3D3D28342E32692822337422297C7C30297C7C342E313728293D3D3D342E3269282232432229297B6E2E6F2E752E5828342C2232682229';
wwv_flow_api.g_varchar2_table(39) := '7D7D292C6E2E6F2E752E314728342E7628292C223268222C3528297B612E316E28297D295D7D3B382E362E32513D3528297B3720693B4228693D303B693C342E6B2E703B692B2B297B3928342E6B5B695D2E762829213D3D342E3165297B342E6B5B695D';
wwv_flow_api.g_varchar2_table(40) := '2E4B28342E3165297D7D4228693D303B693C342E452E703B692B2B297B342E455B695D2E314328297D342E453D5B5D3B4228693D303B693C342E316A2E703B692B2B297B6E2E6F2E752E336228342E316A5B695D297D342E316A3D5B5D3B342E31653D74';
wwv_flow_api.g_varchar2_table(41) := '3B342E31693D777D3B382E362E33383D3528297B7D3B382E362E32713D3528297B3720692C31663B3928342E4D2E703E30297B6A7D4228693D303B693C342E31632E703B692B2B297B31663D342E31635B695D3B342E4D2E59287B33663A342E31492B28';
wwv_flow_api.g_varchar2_table(42) := '692B31292B222E222B342E31742C31753A31662C31783A31667D297D7D3B382E362E33733D3528297B3720693B3720613D342E314428293B3720623D46206E2E6F2E316D28293B4228693D303B693C612E703B692B2B297B622E5628615B695D2E532829';
wwv_flow_api.g_varchar2_table(43) := '297D342E7628292E31562862297D3B382E362E33633D3528297B6A20342E547D3B382E362E33723D352861297B342E543D617D3B382E362E32533D3528297B6A20342E31337D3B382E362E33713D352861297B342E31333D617D3B382E362E31793D3528';
wwv_flow_api.g_varchar2_table(44) := '297B6A20342E31577D3B382E362E34303D352861297B342E31573D617D3B382E362E32333D3528297B6A20342E4D7D3B382E362E336F3D352861297B342E4D3D617D3B382E362E32473D3528297B6A20342E32647D3B382E362E336E3D352861297B342E';
wwv_flow_api.g_varchar2_table(45) := '32643D617D3B382E362E32423D3528297B6A20342E317A7D3B382E362E336D3D352861297B342E317A3D617D3B382E362E33613D3528297B6A20342E31387D3B382E362E34343D352861297B342E31383D617D3B382E362E336C3D3528297B6A20342E31';
wwv_flow_api.g_varchar2_table(46) := '617D3B382E362E336B3D352861297B342E31613D617D3B382E362E336A3D3528297B6A20342E316C7D3B382E362E34383D352861297B342E316C3D617D3B382E362E356F3D3528297B6A20342E31747D3B382E362E356E3D352861297B342E31743D617D';
wwv_flow_api.g_varchar2_table(47) := '3B382E362E356C3D3528297B6A20342E31497D3B382E362E356B3D352861297B342E31493D617D3B382E362E35693D3528297B6A20342E31637D3B382E362E35683D352861297B342E31633D617D3B382E362E32483D3528297B6A20342E31547D3B382E';
wwv_flow_api.g_varchar2_table(48) := '362E35663D352861297B342E31543D617D3B382E362E35653D3528297B6A20342E31767D3B382E362E35643D352861297B342E31763D617D3B382E362E32793D3528297B6A20342E31537D3B382E362E35633D352861297B342E31533D617D3B382E362E';
wwv_flow_api.g_varchar2_table(49) := '31443D3528297B6A20342E6B7D3B382E362E35613D3528297B6A20342E6B2E707D3B382E362E35393D3528297B6A20342E457D3B382E362E35343D3528297B6A20342E452E707D3B382E362E31423D3528622C61297B342E32622862293B39282161297B';
wwv_flow_api.g_varchar2_table(50) := '342E316E28297D7D3B382E362E326C3D3528622C61297B3720633B4228632033392062297B3928622E3530286329297B342E326228625B635D297D7D39282161297B342E316E28297D7D3B382E362E32623D352862297B3928622E34582829297B372061';
wwv_flow_api.g_varchar2_table(51) := '3D343B6E2E6F2E752E314728622C223457222C3528297B3928612E3169297B342E31703D773B612E316228297D7D297D622E31703D773B342E6B2E592862297D3B382E362E34553D3528632C61297B3720623D342E32392863293B39282161262662297B';
wwv_flow_api.g_varchar2_table(52) := '342E316228297D6A20627D3B382E362E34533D3528612C63297B3720692C723B3720623D773B4228693D303B693C612E703B692B2B297B723D342E323928615B695D293B623D627C7C727D39282163262662297B342E316228297D6A20627D3B382E362E';
wwv_flow_api.g_varchar2_table(53) := '32393D352862297B3720693B3720613D2D313B3928342E6B2E3164297B613D342E6B2E31642862297D4C7B4228693D303B693C342E6B2E703B692B2B297B3928623D3D3D342E6B5B695D297B613D693B34517D7D7D3928613D3D3D2D31297B6A20777D62';
wwv_flow_api.g_varchar2_table(54) := '2E4B2874293B342E6B2E345028612C31293B6A20487D3B382E362E344D3D3528297B342E31412848293B342E6B3D5B5D7D3B382E362E31623D3528297B3720613D342E452E344C28293B342E453D5B5D3B342E31412877293B342E316E28293B31552835';
wwv_flow_api.g_varchar2_table(55) := '28297B3720693B4228693D303B693C612E703B692B2B297B615B695D2E314328297D7D2C30297D3B382E362E32663D352864297B3720663D342E333728293B3720633D46206E2E6F2E317128642E323728292E4F28292C642E323728292E31392829293B';
wwv_flow_api.g_varchar2_table(56) := '3720613D46206E2E6F2E317128642E323428292E4F28292C642E323428292E31392829293B3720653D662E31502863293B652E782B3D342E543B652E792D3D342E543B3720673D662E31502861293B672E782D3D342E543B672E792B3D342E543B372062';
wwv_flow_api.g_varchar2_table(57) := '3D662E33322865293B3720683D662E33322867293B642E562862293B642E562868293B6A20647D3B382E362E316E3D3528297B342E32362830297D3B382E362E31413D352861297B3720692C4A3B4228693D303B693C342E452E703B692B2B297B342E45';
wwv_flow_api.g_varchar2_table(58) := '5B695D2E314328297D342E453D5B5D3B4228693D303B693C342E6B2E703B692B2B297B4A3D342E6B5B695D3B4A2E31703D773B392861297B4A2E4B2874297D7D7D3B382E362E33303D3528622C65297B3720523D34453B3720673D28652E4F28292D622E';
wwv_flow_api.g_varchar2_table(59) := '4F2829292A412E314B2F314D3B3720663D28652E313928292D622E31392829292A412E314B2F314D3B3720613D412E314C28672F32292A412E314C28672F32292B412E333128622E4F28292A412E314B2F314D292A412E333128652E4F28292A412E314B';
wwv_flow_api.g_varchar2_table(60) := '2F314D292A412E314C28662F32292A412E314C28662F32293B3720633D322A412E344328412E32592861292C412E325928312D6129293B3720643D522A633B6A20647D3B382E362E33353D3528622C61297B6A20612E324928622E532829297D3B382E36';
wwv_flow_api.g_varchar2_table(61) := '2E33333D352863297B3720692C642C502C31683B3720613D347A3B3720623D743B4228693D303B693C342E452E703B692B2B297B503D342E455B695D3B31683D502E325228293B39283168297B643D342E33302831682C632E532829293B3928643C6129';
wwv_flow_api.g_varchar2_table(62) := '7B613D643B623D507D7D7D3928622626622E324A286329297B622E31422863297D4C7B503D4620442834293B502E31422863293B342E452E592850297D7D3B382E362E32363D352865297B3720692C4A3B3720643B3720633D343B392821342E3169297B';
wwv_flow_api.g_varchar2_table(63) := '6A7D3928653D3D3D30297B6E2E6F2E752E5828342C223478222C34293B3928315120342E3167213D3D22313522297B347728342E3167293B323120342E31677D7D3928342E7628292E313728293E33297B643D46206E2E6F2E316D28342E7628292E3173';
wwv_flow_api.g_varchar2_table(64) := '28292E323428292C342E7628292E317328292E32372829297D4C7B643D46206E2E6F2E316D2846206E2E6F2E31712833342E34752C2D32572E3474292C46206E2E6F2E3171282D33342E34732C32572E347229297D3720613D342E32662864293B372062';
wwv_flow_api.g_varchar2_table(65) := '3D412E323228652B342E31522C342E6B2E70293B4228693D653B693C623B692B2B297B4A3D342E6B5B695D3B3928214A2E31702626342E3335284A2C6129297B392821342E31617C7C28342E316126264A2E3471282929297B342E3333284A297D7D7D39';
wwv_flow_api.g_varchar2_table(66) := '28623C342E6B2E70297B342E31673D3155283528297B632E32362862297D2C30297D4C7B323120342E31673B6E2E6F2E752E5828342C223459222C34297D7D3B382E362E563D3528642C63297B6A28352862297B3720613B42286120333920622E36297B';
wwv_flow_api.g_varchar2_table(67) := '342E365B615D3D622E365B615D7D6A20347D292E347028642C5B635D297D3B382E32703D3528612C63297B3720663D303B3720623D22223B3720643D612E702E346F28293B3720653D643B346E2865213D3D30297B653D313228652F31302C3130293B66';
wwv_flow_api.g_varchar2_table(68) := '2B2B7D663D412E323228662C63293B6A7B31773A642C32543A662C31343A627D7D3B382E326E3D35323B382E326D3D346D3B382E32753D22346C3A2F2F6E2D6F2D346B2D35382D34692E34682E34672F34662F34652F34642F34632F6D223B382E32673D';
wwv_flow_api.g_varchar2_table(69) := '223461223B382E32723D5B35332C35362C356A2C34392C34375D3B392831512033642E362E314E213D3D5C27355C27297B33642E362E314E3D3528297B6A20342E3436282F5E5C5C732B7C5C5C732B242F672C5C275C27297D7D272C36322C3333362C27';
wwv_flow_api.g_varchar2_table(70) := '7C7C7C7C746869737C66756E6374696F6E7C70726F746F747970657C7661727C4D61726B6572436C757374657265727C69667C7C7C7C7C7C7C7C7C7C72657475726E7C6D61726B6572735F7C7C7C676F6F676C657C6D6170737C6C656E6774687C646976';
wwv_flow_api.g_varchar2_table(71) := '5F7C7C7C6E756C6C7C6576656E747C6765744D61707C66616C73657C7C7C70787C4D6174687C666F727C63656E7465725F7C436C75737465727C636C7573746572735F7C6E65777C436C757374657249636F6E7C747275657C636C75737465725F7C6D61';
wwv_flow_api.g_varchar2_table(72) := '726B65727C7365744D61707C656C73657C7374796C65735F7C6765744D61726B6572436C757374657265727C6C61747C636C75737465727C6D61705F7C7C676574506F736974696F6E7C6772696453697A655F7C7374796C657C657874656E647C6D6172';
wwv_flow_api.g_varchar2_table(73) := '6B6572436C757374657265725F7C747269676765727C707573687C636C757374657249636F6E5F7C7C7C7061727365496E747C6D696E436C757374657253697A655F7C7469746C657C756E646566696E65647C73756D735F7C6765745A6F6F6D7C617665';
wwv_flow_api.g_varchar2_table(74) := '7261676543656E7465725F7C6C6E677C69676E6F726548696464656E5F7C72657061696E747C696D61676553697A65735F7C696E6465784F667C6163746976654D61705F7C73697A657C74696D65725265665374617469637C63656E7465727C72656164';
wwv_flow_api.g_varchar2_table(75) := '795F7C6C697374656E6572735F7C6865696768745F7C656E61626C65526574696E6149636F6E735F7C4C61744C6E67426F756E64737C7265647261775F7C76697369626C655F7C697341646465647C4C61744C6E677C77696474685F7C676574426F756E';
wwv_flow_api.g_varchar2_table(76) := '64737C696D616765457874656E73696F6E5F7C6865696768747C626174636853697A6549455F7C746578747C77696474687C6765744D61785A6F6F6D7C7A6F6F6D4F6E436C69636B5F7C726573657456696577706F72745F7C6164644D61726B65727C72';
wwv_flow_api.g_varchar2_table(77) := '656D6F76657C6765744D61726B6572737C616464446F6D4C697374656E65727C686964657C6164644C697374656E65727C6C6566747C696D616765506174685F7C746F707C50497C73696E7C3138307C7472696D7C666F6E747C66726F6D4C61744C6E67';
wwv_flow_api.g_varchar2_table(78) := '546F446976506978656C7C747970656F667C626174636853697A655F7C636C7573746572436C6173735F7C63616C63756C61746F725F7C73657454696D656F75747C666974426F756E64737C6D61785A6F6F6D5F7C616E63686F72546578745F7C646976';
wwv_flow_api.g_varchar2_table(79) := '7C6162736F6C7574657C706F736974696F6E7C64656C6574657C6D696E7C6765745374796C65737C676574536F757468576573747C63616C63756C617465426F756E64735F7C637265617465436C7573746572735F7C6765744E6F727468456173747C67';
wwv_flow_api.g_varchar2_table(80) := '6574506F7346726F6D4C61744C6E675F7C72656D6F76654D61726B65725F7C73686F777C707573684D61726B6572546F5F7C616E63686F7249636F6E5F7C7469746C655F7C626F756E64735F7C676574457874656E646564426F756E64737C494D414745';
wwv_flow_api.g_varchar2_table(81) := '5F455854454E53494F4E7C69646C657C6765747C73746F7050726F7061676174696F6E7C6176657261676543656E7465727C6164644D61726B6572737C42415443485F53495A455F49457C42415443485F53495A457C746578744465636F726174696F6E';
wwv_flow_api.g_varchar2_table(82) := '5F7C43414C43554C41544F527C73657475705374796C65735F7C494D4147455F53495A45537C666F6E745374796C655F7C666F6E745765696768745F7C494D4147455F504154487C666F6E7446616D696C795F7C656E61626C65526574696E6149636F6E';
wwv_flow_api.g_varchar2_table(83) := '737C69676E6F726548696464656E7C676574436C7573746572436C6173737C7465787453697A655F7C7A6F6F6D4F6E436C69636B7C6765745A6F6F6D4F6E436C69636B7C6D61785A6F6F6D7C74657874436F6C6F725F7C636C6173734E616D655F7C6F6E';
wwv_flow_api.g_varchar2_table(84) := '4164647C6765745469746C657C67657443616C63756C61746F727C636F6E7461696E737C69734D61726B6572496E436C7573746572426F756E64737C75706461746549636F6E5F7C6D6F7573656F75747C636C69636B7C69734D61726B6572416C726561';
wwv_flow_api.g_varchar2_table(85) := '647941646465645F7C75726C5F7C6372656174654373737C6F6E52656D6F76657C67657443656E7465727C6765744D696E696D756D436C757374657253697A657C696E6465787C6D6F7573656F7665727C6E6F6E657C3137387C626F756E64734368616E';
wwv_flow_api.g_varchar2_table(86) := '6765644C697374656E65725F7C737172747C4F7665726C6179566965777C64697374616E63654265747765656E506F696E74735F7C636F737C66726F6D446976506978656C546F4C61744C6E677C616464546F436C6F73657374436C75737465725F7C38';
wwv_flow_api.g_varchar2_table(87) := '357C69734D61726B6572496E426F756E64735F7C646973706C61797C67657450726F6A656374696F6E7C647261777C696E7C6765744176657261676543656E7465727C72656D6F76654C697374656E65727C6765744772696453697A657C537472696E67';
wwv_flow_api.g_varchar2_table(88) := '7C706172656E744E6F64657C75726C7C6261636B67726F756E64506F736974696F6E5F7C73657443656E7465727C7573655374796C657C676574456E61626C65526574696E6149636F6E737C73657449676E6F726548696464656E7C67657449676E6F72';
wwv_flow_api.g_varchar2_table(89) := '6548696464656E7C7365745A6F6F6D4F6E436C69636B7C7365745469746C657C7365745374796C65737C6D61787C7365744D696E696D756D436C757374657253697A657C7365744772696453697A657C6669744D6170546F4D61726B6572737C6D696E5A';
wwv_flow_api.g_varchar2_table(90) := '6F6F6D7C637265617465456C656D656E747C7A6F6F6D5F6368616E6765647C63616E63656C427562626C657C6D7369657C757365724167656E747C3130307C646F63756D656E747C6C696E657C636C7573746572436C6173737C626174636853697A6549';
wwv_flow_api.g_varchar2_table(91) := '457C616C69676E7C7365745A6F6F6D7C626174636853697A657C63616C63756C61746F727C6465636F726174696F6E7C696D61676553697A65737C6E6176696761746F727C696D616765457874656E73696F6E7C746F4C6F776572436173657C77656967';
wwv_flow_api.g_varchar2_table(92) := '68747C696D616765506174687C66616D696C797C7374796C65737C6D696E696D756D436C757374657253697A657C36307C636F6C6F727C6772696453697A657C636C7573746572636C69636B7C696E6E657248544D4C7C726563747C636C69707C737263';
wwv_flow_api.g_varchar2_table(93) := '7C7365744D61785A6F6F6D7C696D677C6D6F757365646F776E7C637373546578747C7365744176657261676543656E7465727C67657453697A657C7265706C6163657C39307C736574456E61626C65526574696E6149636F6E737C37387C706E677C626F';
wwv_flow_api.g_varchar2_table(94) := '756E64735F6368616E6765647C696D616765737C6D61726B6572636C75737465726572706C75737C7472756E6B7C73766E7C636F6D7C676F6F676C65636F64657C76337C73706C69747C7574696C6974797C687474707C3530307C7768696C657C746F53';
wwv_flow_api.g_varchar2_table(95) := '7472696E677C6170706C797C67657456697369626C657C30303034383836353632357C30383133363434343338343534347C34383338383433343337357C30323037303737313734333437327C6A6F696E7C636C65617254696D656F75747C636C757374';
wwv_flow_api.g_varchar2_table(96) := '6572696E67626567696E7C706F696E7465727C34303030307C637572736F727C617070656E644368696C647C6174616E327C6261636B67726F756E64506F736974696F6E7C363337317C73657269667C73616E737C6F7665726C61794D6F757365546172';
wwv_flow_api.g_varchar2_table(97) := '6765747C417269616C7C666F6E7446616D696C797C6E6F726D616C7C736C6963657C636C6561724D61726B6572737C666F6E745374796C657C67657450616E65737C73706C6963657C627265616B7C626F6C647C72656D6F76654D61726B6572737C666F';
wwv_flow_api.g_varchar2_table(98) := '6E745765696768747C72656D6F76654D61726B65727C746578744465636F726174696F6E7C64726167656E647C676574447261676761626C657C636C7573746572696E67656E647C72656D6F76654368696C647C6861734F776E50726F70657274797C74';
wwv_flow_api.g_varchar2_table(99) := '65787453697A657C323030307C7C676574546F74616C436C7573746572737C626C61636B7C7C636C656172496E7374616E63654C697374656E6572737C6C6962726172797C676574436C7573746572737C676574546F74616C4D61726B6572737C746578';
wwv_flow_api.g_varchar2_table(100) := '74436F6C6F727C736574436C7573746572436C6173737C736574426174636853697A6549457C676574426174636853697A6549457C73657443616C63756C61746F727C616E63686F7249636F6E7C736574496D61676553697A65737C676574496D616765';
wwv_flow_api.g_varchar2_table(101) := '53697A65737C36367C736574496D616765506174687C676574496D616765506174687C616E63686F72546578747C736574496D616765457874656E73696F6E7C676574496D616765457874656E73696F6E7C636C6173734E616D65272E73706C69742827';
wwv_flow_api.g_varchar2_table(102) := '7C27292C302C7B7D2929';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(196478312956656012)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'markerclusterer.min.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D49484452000000350000003408060000002ABA70D5000000017352474200AECE1CE900000006624B474400FF00FF00FFA0BDA793000000097048597300000B1300000B1301009A9C180000000774494D4507D90418082A11';
wwv_flow_api.g_varchar2_table(2) := '9200839500000B3B4944415468DEBD9A5B8C5D6775C77FFF7D66C6638FC7F6C471629C40139AA4A913053058DCA14A0BA9DA7011E181B6525111F040E005CE163C70111709C139028907505504A87988902A352A8990824AA526A14004283121C56E48D2';
wwv_flow_api.g_varchar2_table(3) := '38C4E3D8E3198FE77ECEFEF3B0D7DEE79BE3DB991B5B1A9D3997FDED6F7D6B7DFFF55FFFF589CDBEDA06C800010DA0810DD2087681D4018C5DBE967F0579D6BBBFA90D4D61FD77B70AEA8994EF478151A4A1302443CAC280789A0803C1165281DD45EA62';
wwv_flow_api.g_varchar2_table(4) := 'AF202DD0D4CA46D755EBF24453A55120A43160671801B691CA716DD7CF888F6A03E1C2BF8315E02CB0542F5AFF026EAA513D8332A49DD83BC21B9531E998D5843B6154119FA90ECDD240275E74F2FD32D21C4DCDAF352CB5E6706B15DB91760359845215';
wwv_flow_api.g_varchar2_table(5) := '5E95478C3D07CC23752E3A91B6C1DE86B4037B7B6F468971E55805D2699AEA0C6A98D6E41DD8036C078AFAFED23B1DEC05A479EC21A41DC06EEC09A49DC0484C9408B905ECB3C0196016691E10F64E605B004DB540D562CD60CF916797F59A0634681869';
wwv_flow_api.g_varchar2_table(6) := '2226ECFADE7215A7696A91B60F00D70363D8233131AF0288D5FF5793ED602F214D631F25CF66697B1CD8152093EECB25EC29F2CC1BF354AB1806F6F581808145601AB80AB82D8CE9D6007021C4AB21C2AC1AAF37F1216012783CBCBE1769B80F4C9681D3';
wwv_flow_api.g_varchar2_table(7) := '97326CE8B2FB48DA960041E91D3889B40BFBF5617001746AA8B61B113A33C01CD26CED357B18691C7B2CBCD1058A307A05FB4AA4B7623F8FF464A0EA15C9020D233580CEFA8C92A0A97309DA75C9B349DABE1EFBD6F855374251E1A559E029ECE30988EC';
wwv_flow_api.g_varchar2_table(8) := '077647481E8D9C64EC21E0E5C00D013C8A9013F052ECAB8047C27BFBE2795334D5D968F8119B7307F622702B705D1F581461C431601CFB16A45B819701FBEBB02CAF46E4A2E3C0B348478027B187819B90AE8EB19D24E8234827B121CF162F97B7B44638';
wwv_flow_api.g_varchar2_table(9) := 'BF0EE995B5EBED0C3887F410F63EA47F0AAF8C24FBA79764D33D95C2B7B488FD38D23D1192AF0DE31D51B0023C4C9E9D1B04D6B58EC4FBE7112E203D0D1CC3BE03E91DB199530F6611722BD8CBF1BCED492E2A12841C06CE62DF83F4247018988850FD25';
wwv_flow_api.g_varchar2_table(10) := '4D9DD81A46D10BC59BB1678105E06EA4EB2257556032823403FC1C780CFB45603E567F0CB81638041C0E033B754E9232ECFF21CFBE43AB38089C20CFA6D64295D6CEFD526601AD586127407106F837E017D83723DD8E7D6320DA09A4A78087B0FF1B7811';
wwv_flow_api.g_varchar2_table(11) := '7837F0C6E090156D1A029EA7A9CFFDF1587A158A6DDF09BC33F6C802D2BDC073C0DDD8770137AD42D2D5390AA48781EFC422DC81FDF63A074ADFA2A9FF5D2B99DD58E9D1F3DC5DC09B903E07BC01FBDF91B625F4E6FC7B7ADCAE028DE7915E8FBD1FE983';
wwv_flow_api.g_varchar2_table(12) := 'D86DF2ECD87A0CDAB8513DF09840BA1BF8621242838E5D21DC39A4F761FF883C5BDE48B19845A55AD547EBBD3E80FDC5241769CD0B5B12DFFB915EB5394562C9EF8CD4A5299FE7894B87DFBB80FB56157DEBBD4AF4EC60DF449E3DB3A668594593CABA66';
wwv_flow_api.g_varchar2_table(13) := '77A0589756B114546784A6162F5ABE97031E00FE65D3F667B928C3489F07DE3FD0A2BA8EB491E0A92BA2ED2C7855237E34170FF80B602ED0EC77A125B8F664B9189F406A6FBA7853F1C59267AE36AC12764A627B2D4D3D45DBFB826681B428DA6E44F9A0';
wwv_flow_api.g_varchar2_table(14) := '487E2F06E5794D30F221A4FB81F744E1F734F024D271EC27900E6EB2415518DF4B537F1F5E1803FE3418FF4C943ABBA2BE7B200ACB1D91268A4ACACA924DBE8C7455F2FE2C4DAD60DF06BC06E9BD487F89BD1B38B8E95EEAD5627F17067D01F82AD24781';
wwv_flow_api.g_varchar2_table(15) := 'BFC65E8AF2BF8BB4827D1576A7961620CB80E1A400EB86AB4792C754E1784D02BF4F037FCB565D55FE6A15B72035A27E2A906E413A57F3CBD290B160FD751AC912C98AA4901B0B342B9942DB63D80DEC8A0E9D45FA3324B6D4B072AF4F4535A078FE7812';
wwv_flow_api.g_varchar2_table(16) := '450EADD1E95CB28B0CE8C4D82EB01FA988585F024E614FF42D085B148A937DC83A7441F44BE6925D1685CA81CF25030F03E35147B1C59783D5BB0FF62FE6D9306AB572AA0B1471DBC8B3C9245433605B283B5B6C920BE01AA0A8EBAFA64EAF527DABFDB7';
wwv_flow_api.g_varchar2_table(17) := 'CA53E58DAB3D57C2A6C2533BE2BB3331888183D8F7C682784B3C544EF208D2B6F04E86344DDBA3C9E22BC49D067D467491149315AD62089849DC391EAF47631023DD081C8B22515BE02121FD3654AAD158E806F058CCA75AFC0CE9546C890A48C8C2B59D';
wwv_flow_api.g_varchar2_table(18) := '989C23919D4924E5115AC504F6D15A0A861B817DD8DFDE42E4FB08F6A1C8490E95F767C0DE2497197B1669B8D6F1A5E52CE0B09B0CB91D7B3EC44AC57737004FD49F9512F3FB81EF024BB5A4BC799E3A42533F46FA9BA4AA3E419E3D075C9D183E459E15';
wwv_flow_api.g_varchar2_table(19) := 'E1A9EADEE58CA68CDDAD2D2F63B88382CC967BEE00D2E98072A29F7403308DFD40A2DA6EC65EEA223569156F03AE8C7133E047B48A5DC0DE24D11EA7550CD739B43474B182F4A5042E8DBD0D7BB286F43244AF05EE431A4D90E61F80BB809F6C786FF558';
wwv_flow_api.g_varchar2_table(20) := 'CDD7B17F83745768EC20CD613F9AC8738AD749A4F1883605D3E85446CD27C0606007702C949DCA832F23CF1EC3FE75A2C95D177AC45FC5E7E904D78674E53EF932D2A7800FD77D2ABB01FC2C26BD07BB8839CD00F3C99E23F4C1A2AC7CCB3A6931C95143';
wwv_flow_api.g_varchar2_table(21) := '756C43230CDE49ABB815F867A4D9BA8523BD1AF847E076ECFF48988007F04EDA0EFA2CF035EC8FD53CB3E47DBFA3A97BB16FABD38FD4C07E0A18AFD94F39D622794696D42AD34902167005F00CD2D9785F20BD3C14D4EF2774651938141AC5FBB0EF0C20';
wwv_flow_api.g_varchar2_table(22) := 'D1459373AF5705F02BE000F677913E19CCBFEAFBCE00DFA4551C44DA55C3384C926727A257E63A25E5D95C8F41B46BFE34110A6AB5394F47ADF58A244C8CFD20F056E0BD492AC80240EE41FA05F6BB810F21EDC7DEB3AAAF0527B18F856E7804FB0EE03D';
wwv_flow_api.g_varchar2_table(23) := '484B09302C607F2B9A72AF4D14DE0ED283D83B6BADB05CA3B3952CADBEF27C047B6FF2F0AA6D7308FB9ABAC35186EA7F221DC6FE501853A9B3024E01CF02FF1A4973CF2A51C69E42BA05781D707D30EF22599C59ECAFC6FBC3B5D7CBD7C7914E007B9348';
wwv_flow_api.g_varchar2_table(24) := '5889E216F22C31AA27505E813D5A330C58A4A929DABEBD8F5C36B0FF2B7A4D1F8F560FC97D0BC09768EAD405C49AD108B5037D0A94B19F05BE11E17F285845B5182F90678FD2F64BFAF8E919F26CF17C96DEAC89ED541CE0A868C7286DEFC27E28126DB5';
wwv_flow_api.g_varchar2_table(25) := '570AE0CDD8DB913E8D7D1F700E188D8D7B328E0E9C7FE5D922F6EF1382BC1DFB24F6F780AF0037221D8AC4EF78E62479F628ADE2CA045C84BD941A747EE9512946F699BECDBC3338D88F91166A83CB50B919FB4DC0C34879C8C873C0FFD3D4F225A8D06F';
wwv_flow_api.g_varchar2_table(26) := 'C3DB2F002DF2EC3321F2DC89746D5FF7641AE9E7B4BD2F4ECE1061DE05A6FA754B5D42CF1B43DA13CDEA8A64CE44E3ED30D2D5D14CAB1EDC08C6712C3A7FA3FD2BD837FE7854ADA7A26B783DD244D2F6ACC8F3B334758456B1374A9EB4803D459EADF42B';
wwv_flow_api.g_varchar2_table(27) := '4E97EBCE8F63EF4A0E76187B29CA903F015E594B6795765E1D0469EA81015A426FC11E8BA33FA4E24918F44834CBF7D57DE45EB3EF1479B674213D32BB8CF2391BFB244DA6A348FB80E7B01F449A0A6F2A49BCD3AB52C5F97B8ABA464BCF5894CFE900CF';
wwv_flow_api.g_varchar2_table(28) := '91673F8830DE9F34C6ABFD5C1AD4230EEB381C5282C11554A7BECA507420DC4C68702F8DE6DB28F64FC9B3E3038C3D01DC1E7B6309380ABC1039694FBD7F7A0D3947237BE9521D916C202A93670BD8A78277A50BB103FB40FCFF044DDD0F3C8274FCA25E';
wwv_flow_api.g_varchar2_table(29) := '4A43D09EC6FE3FEC9FD0D40F8167229D5C1D325D7ADEA924B097316870FDBBD7B26900BB90B6AF3A2CD583D825600E7B71E0BE52AB688464305AD745FD87B7CA56EC39F2CC83E8EB833DB93A0A9767DDD80753C10555F32EC7012A181958652ABDB9137B';
wwv_flow_api.g_varchar2_table(30) := '1C7B385928D55D797B126976508336D6F32D273516A472B88EF9BEEC3E8061D5E1ACF414DA12D27CDD7559634771EDBDC7B2895D79702EF6DA8BD1FEE9240C7BD06B393CB41CDAC8C90083F210C83A5AA47F00FF136947614E93120000000049454E44AE';
wwv_flow_api.g_varchar2_table(31) := '426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(196478708837656011)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'images/m1.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D494844520000003800000037080600000059D089CB000000017352474200AECE1CE900000006624B474400FF00FF00FFA0BDA793000000097048597300000B1300000B1301009A9C180000000774494D4507D90418082935';
wwv_flow_api.g_varchar2_table(2) := '852E348700000C3B4944415468DEC59A5B6CA56775869FF7F7F6611C7B0E9E49C2E41C8610483230A401955605F68F202861B8E024B800120909B50855AAE0A612EA454F522BA4F682AA055A21AE68AB5E1444C221DA3B4224402003219310C221936486';
wwv_flow_api.g_varchar2_table(3) := 'C499B13D3E8FB7F7FEDF5E787D7B3EEFD81E7BEC497FC9DAD63EFCFFB7BEF5AE77ADF5AE4F5C82AB6A80846C14AF3540127D40CD6659A2B2A9243A3696B08D8B72E51E6E82EADB5F8BB6F3E3DE45B8493F301846F4037D127DF6F9AF481086AFBCB1F259';
wwv_flow_api.g_varchar2_table(4) := '47A20D2C03CB36ADA2A4BD139BADED7829DBED619BCB805ABA6F18928C5AF73936A4EF86D1066CB30CCC1625ADED7854DBF09E8021600F50AC654CB6F8E443AF588FE233F518E858537A15D0B299065A45B9754375317074935DC065368369C7B3852BFE';
wwv_flow_api.g_varchar2_table(5) := '6F014B01BBB64D959C0F14E1AD1AD06733203100F4A7CDC8BC990C5DB4992D4A96DD5CD99084A06D1BD863DC98CD5016538A4549A203CCDA2C1425540DFA81FDC05E8991148BE1B10A989598B4992A4AAAAA81244663F394DD9F0C01F345C9CC8E793019';
wwv_flow_api.g_varchar2_table(6) := '5735A849EC8F1DEF7A2C1EDAB69909B218B1B956E24A6034BEEB4430397C9377029A5336A724C681057B0525595C3B5BF3A2C4B4EA541782AC364324558341605F40CBB1B80268494CD9141237D8BC0AD81BF7ADB4097C24EF67C6B66D2681DF4B9C0CD8';
wwv_flow_api.g_varchar2_table(7) := 'EE8DE7395B735B6242753A39E16DD983E1B92B33AF394865A628997593EB6D6E8994A01EB2E92E28C566F7C119F964E4B2DA76B328F15360DA66BFD48DF9F4DDCA66BC28F1457930B9DF4D76032319494C0654DF2071D0A6139ECD21B768B32031613323';
wwv_flow_api.g_varchar2_table(8) := '712620970CEB84B7F7488C01BB805D91FC73CFF649FC1A780A180646527C02678B92C58D60BA9518DC2D310C9CB1392071D866382A124B1461F4EF257E034C01076D0E495C673328B1373C83C4B4CD69E045E0D7C09CC4E5C06BC3F04E0F7C27258EC566';
wwv_flow_api.g_varchar2_table(9) := 'EEB3395B949CDB560CF61A1AD7419B3B12B4125948CC01C75467DA4DFEC4E6BDC0EE0CB679F2EF85A880DFD97CB32879D24DAEB1391C0493183A114D0358484475A154A1AD562E55835B240E6595C7B2CD33C033127F68F34189DD402BE0AC0C9645C688';
wwv_flow_api.g_varchar2_table(10) := 'DDA2203EEB03FA8113C07F4AFCC6E636E09A8CAC3AC0E3AAF3FC6613FE962A99AAD1FDF77512AF05CE013F005E65F37189AB028229252858B02651441A6847AC5D198CD906DA59CE2B806589A76DBE0A0C4BBC390A864755677C23D6DC76A99679F2F512';
wwv_flow_api.g_varchar2_table(11) := 'BF058ED8DC9B41304FD00BC0F781478B92E7A2CB48E9A1267173C0FD2D40ADB77EB59902FE213C3752949C7A456AD164A49B5C0FFC6556471661E093120FD89C02EE08E8FE01B01BB819F889C402F088CD0F259E026E07FED8E686F0B2A3239901FEA228';
wwv_flow_api.g_varchar2_table(12) := 'F1C514DCDB29B653B23F6A7334D8741EF832F012F07989BB6D5E9DC5DAAA3C18EF2D49FC0AF80AF06FC03B800FA4CF802F1525C75FF16EA207AE1F0E4FFDBDCD1B25EE07863222DA70AF32223A01BC0D18033E05FC7B51F2E8FF5BC3DB63E498C43D365F';
wwv_flow_api.g_varchar2_table(13) := '482960A33E70AD922DE26E02F898C483AAB3B8154259EB2A3266BCB81D52F7F5A3365FC8DED716EF93C869BFC47DC0E11DEBE8AB46B78836ACDEB1CD60DF4DEA368D756ACA8B0AF158CBA1A2E4C4C54A28008AE6711F3024D18AC09E03068B92A50BDDA0';
wwv_flow_api.g_varchar2_table(14) := '6A70204AB33D3B295C05217D03F890446BBD4DEE857020B2167FED5AD07A2DF03F081445C95CD5E0AD55830EF092C429D599CB9ADEDCD0CF02BBB71A739B84EDDD36B7A9CEB1F50C8BF8AF05319D01C642E82A80C56458DFAAD26B456F198B326C9FCD55';
wwv_flow_api.g_varchar2_table(15) := '5583E3126FB779C466DC4DDAD1C2DC9DAB643BE9C428DF3E03DC9BA5A61AD0A73A4B55839B81AB254623DD7CCFA62F7E0730504B2D49F456925806AE486D4BC4D50470ADCDBB81A3D1E47E5D6209B8ED1218970B52F700F7560D0ED91C91B8D666C44DFE';
wwv_flow_api.g_varchar2_table(16) := '29CABDD14CEF198CF5A622BE560B517695FC106A595722880EFB884415F5E758B4436FED51C376DA48074FDC6A7308B82B64917EE0B2D073F6455A2A422B6A45FDBA92267AE3C6A613FD9E53272E311B5A8B6C1C12C5D3C0BB772A9F5E204FBF1738191B';
wwv_flow_api.g_varchar2_table(17) := 'EC88AFFEA8559569B1C39963BAA5D6CBF25A32AE47BE1B8DCF243163770BE657E2EA0073F68A081C65E18DD175AC5A67EF7A8ACDD075DAB18CBEA7E36683F6A5B72EC2A01DFD259974D2FBBD97895DC53A06D1B3F076E4C69484AF8BDFCEF00A5D218FF4';
wwv_flow_api.g_varchar2_table(18) := '676F2DAF151AE18CEE55CBCBAD8C6C167AE87A97CD7C826840E600F0FCA586686CF4B3A1C9D662B3FB8067437725AB7D97D78AC1F6AACA6685559732099E50A6CF6474DCB17903F04078FB520135D1FDFDC00D59E73119296A4FE28B283597ECD5615304';
wwv_flow_api.g_varchar2_table(19) := '969D61BD1F180F952CC90F63A1BB24A5AB1D5DF8D3129397824583AD25F1A4EACC01372545CE66C26631D25562D60A98EF9D6C1571A37676E39AEA2CC45427699C23C078E49804D19BC2E0072F497E5077A17F5D35B809B826F3E80B12B5986124D5AD15';
wwv_flow_api.g_varchar2_table(20) := '445464AA5DAB90707C9052C440183A1EF1966AD4C15099FBB2B1D69DC0BFC66CE252C0F469E07EE05E9B56128C6D9EB0B92A1853919F5F4A93E4ECF7AD4275B0594EB164D3E72603122F24468ADDBADAE63BF92C4FE208F088C437B3B9DE4EC1139B7F94';
wwv_flow_api.g_varchar2_table(21) := '38045C918C913807FC4CE2BA282F53A83D2BB12B1F15489C4B062C27252B20396AF3524C795202BDA12899001E90E88FF787A38B7F3FF050AA7476805814C8F82FE02312ED20BB41E0BBC1EA435915365394CC45899920DE063A45587B2E49F0A9688DE0';
wwv_flow_api.g_varchar2_table(22) := '1D4F1EB319A81A1C06BE132C963C7618B847E23D123FDF26E12462F967E0CF243E09ECCDBC745275BE1D9A6C9109C68FC7F9803C4F2ED9544557025C69379405F288C4898086A3C87D4D7CFEDD0C4AED108A8E0277493C9C687A93558EB302A302BE188A';
wwv_flow_api.g_varchar2_table(23) := 'DC4781374657A34801FFE226076DAE8E1091C47474377B393FDF37B054942BCD6D72E94C960B6DB3CB66C6E6C5C44C61CC11A069F30B89C1804E2BE4BEF7D9BC0BF884CD64260D7AA3541031FD338952E2AF804FDBBC33C66744717F7F54536F8A3E356D';
wwv_flow_api.g_varchar2_table(24) := 'CE099B3E8981D474675DCFF9B246F5155D3355069107478163D994C721DEDE56947CD1E6F1D45CC6036F97F83BE03870C0E6E331C8D40642D33189B7A9CEEDC1907F0BE70BE928E87FA83AF78584DF97B5670BAAF38CC49E342E08242CA81E48ECD1328A';
wwv_flow_api.g_varchar2_table(25) := '183DE742EDE948F46F4E10B619001E937816F8D380522793DCFB259E0C283F15315DE693A5186AFE28D2D2AD364781AB80A56CD608D004BE2E7187CDC1EC1915D08899C7EEAC49EE14E5F9F945ADA72DAA80799B91EC46FB43973961736378B76573ABCD';
wwv_flow_api.g_varchar2_table(26) := 'A8C4576C4A890F453B53492CDBDC2C710BF02DD5F91FE07FD750C16E04FE3C9ED7855540AE63F33589476DFE28F5A809D2C0B1088D2BF2830A1267D76C9754EF0A49B3590275ECD098EA1C074EA7F9834415F2C1EDC07D01ADA9CCF3954DDBE6890DF2DD';
wwv_flow_api.g_varchar2_table(27) := '7336C35119A58A44C0499BCF493C06BC3D0AED2A8BBBDF4ABC10D24AD2538961CF929BE795B6620D59D0210574094762A06AB0BB28F951285709DE963800DC293127F179E0BF635658C5DFAFD6D3308B924E24E8A13839F194CD7F48FC4DC4F03B02DEC9';
wwv_flow_api.g_varchar2_table(28) := 'F8023809FC12B83C0B19C5E4773673D4DA524336391A8E9315CE14B705E0ACCD9B80EBE25C4C7EC0E06CB450A76281D716258F6C241E570DDE22B1CBE60989D9A898AE0F32ABB25011F073E079607FC46E1EAB678A9256AF4EAA0B0C3AF784B8938C1470';
wwv_flow_api.g_varchar2_table(29) := '4E7526DDE4269BD7AD354489EF3F27F184EA2B9B7081F9FF5EE0FA388AD27B08211D19790C78C1E672895A566413F3FA853595ED0B0C5624B12F4E4054D9ACBD15796E8FCDEBE3F040D53329AA497C632303B3CDBC2BDAB44E827ED4C1551C52381E461E';
wwv_flow_api.g_varchar2_table(30) := 'C82A98B49619D5995B6F48536CB4BB458943329CCF15B8385B764524FE1F030F4712EECF5879DC5E39A4B389E1CD8B3D9B33009C917828F2E4506C62911D5CE803A6A3575C7702B5AE81C9D512A8CED9605727D52D987454E280CD94EA346D1EB2391B39';
wwv_flow_api.g_varchar2_table(31) := 'EAB474E1D157407F222BFB2624BE57943C0C2C025706D3929FB8B099284AE6B3D31F3B72086138E4C324F5E7877F9680F998E90D019DA2647993F7DD15709F9658B4B94C623890E26C76989E33A3FACB09E5A20DEC39FCDA67B327A89DAC444A3BDB8944';
wwv_flow_api.g_varchar2_table(32) := '3FB5D111AB35E270248C2A221CE8893542C59B4F65D8A606A09BFA52B90ABA9DA26432A0D8C98E8B74072636DAAC71591C0E459D5964C27362E5659BD3AA33B7D57EB3E022AEF0E8421C7D9C8E122B49FAA9BBA06A6E6968B91C8545D2361D2731A654E7';
wwv_flow_api.g_varchar2_table(33) := '743A08BBD571F64E9DD926BA8A74A0EEEC66E32F337430EADE561C0B5BA96BEB9B9F34AF75FD1F0AC219E5F22D72070000000049454E44AE426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(196479090461656011)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'images/m2.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2E7265706F72746D61702D64726F702D636F6E7461696E6572207B0D0A20202020646973706C61793A206E6F6E653B0D0A202020206865696768743A20313030253B0D0A2020202077696474683A20313030253B0D0A20202020706F736974696F6E3A20';
wwv_flow_api.g_varchar2_table(2) := '6162736F6C7574653B0D0A202020207A2D696E6465783A20313B0D0A20202020746F703A203070783B0D0A202020206C6566743A203070783B0D0A202020206261636B67726F756E642D636F6C6F723A2072676261283130302C203130302C203130302C';
wwv_flow_api.g_varchar2_table(3) := '20302E35293B0D0A7D0D0A2E7265706F72746D61702D64726F702D73696C686F7565747465207B0D0A20202020636F6C6F723A2077686974653B0D0A20202020626F726465723A20776869746520646173686564203870783B0D0A202020206865696768';
wwv_flow_api.g_varchar2_table(4) := '743A2063616C632831303025202D2031357078293B0D0A2020202077696474683A2063616C632831303025202D2031357078293B0D0A202020206261636B67726F756E642D696D6167653A2075726C2827646174613A696D6167652F706E673B62617365';
wwv_flow_api.g_varchar2_table(5) := '36342C6956424F5277304B47676F414141414E5355684555674141414751414141426B4341594141414277347056554141414141584E5352304941727334633651414141415A6953306445414751415A41426B6B5043735477414141416C7753466C7A41';
wwv_flow_api.g_varchar2_table(6) := '41414C4577414143784D42414A71634741414141416430535531464239304C4841497649435764734B77414141415A6445565964454E766257316C626E514151334A6C5958526C5A4342336158526F4945644A545642586751345841414143646B6C4551';
wwv_flow_api.g_varchar2_table(7) := '565234327533637355376963427A413858703347424D536552495448384A484D593763524D766D566D586F45395441634A7562686A443441706F696F706771444D57414B4167496353416943667875776877524F564A626B504439725032336F62387670';
wwv_flow_api.g_varchar2_table(8) := '5A43514B676F4141414141414141414150445979694B2F654E4D3035624E7472362B76536A676358694878444D6B453157705646764763667043564943414951554151676F41674241464243414B436743414541554549416F4951424151684341674367';
wwv_flow_api.g_varchar2_table(9) := '6841454243454943454951454951674941674951684151684341674345464145494B414943414951554151676F4167424146424344497A686D46494E426F392F4B364430585664646E64335A616E654459376A53437156636E3353666A79654B524B4A62';
wwv_flow_api.g_varchar2_table(10) := '4A32646E596C6C57624B556C326935584A61586C78644A4A42497937794448783866793976596D365852364F574D4D33642F6669346849715653535743776D737735796348416772565A4C5245544F7A382B584F385A5170564A35483259366E525A4E30';
wwv_flow_api.g_varchar2_table(11) := '2F623944714C727568534C786664394D706B4D4D54364C307576314A4A6C4D696839426876654A7757447776763769346F4959347A77385049774D74743175537A776546362B43484230645362666248566D627A57614A4D636E6A342B4F4841642F6433';
wwv_flow_api.g_varchar2_table(12) := '636E653370363444574B61706A772F5033395964336C3553597870564B765673594F324C4574555664325A4E6F6975362B49347A746731563164587850416953712F586B354F546B306B39704E567179656E7036636839346C2B3558493459627452714E';
wwv_flow_api.g_varchar2_table(13) := '6648613966583174343378637747612F4E6E6333507764444159394F5A68743238724778675A507650364B5343537939665430394F557277375A74507161386A464B7631313348754C6D3549596258564658646352506C39766157474835476154516155';
wwv_flow_api.g_varchar2_table(14) := '386649352F5045384A756D6166764E5A764F2F4D517146416A466D4A52714E486B364B73716778357672317A7A414D326437656472332F36757171737261324E6E5A6270394E522B76322B36324F48517147357A4F625850494D454167466C665833646C';
wwv_flow_api.g_varchar2_table(15) := '324E373962746C317669544130464145494B41494151424141414141414141734D7A2B4169316255676F3665626D384141414141456C46546B5375516D434327293B0D0A202020206261636B67726F756E642D7265706561743A206E6F2D726570656174';
wwv_flow_api.g_varchar2_table(16) := '3B0D0A202020206261636B67726F756E642D706F736974696F6E3A2063656E7465723B0D0A7D0D0A2E7265706F72746D61702D636F6E74726F6C5549207B0D0A202020206261636B67726F756E642D636F6C6F723A20236666663B0D0A20202020626F72';
wwv_flow_api.g_varchar2_table(17) := '6465723A2032707820736F6C696420236666663B0D0A20202020626F726465722D7261646975733A203070783B0D0A20202020626F782D736861646F773A20302032707820347078207267626128302C302C302C2E33293B0D0A20202020637572736F72';
wwv_flow_api.g_varchar2_table(18) := '3A20706F696E7465723B0D0A202020206D617267696E2D746F703A203570783B0D0A202020206D617267696E2D626F74746F6D3A203570783B0D0A202020206D617267696E2D6C6566743A203270783B0D0A20202020746578742D616C69676E3A206365';
wwv_flow_api.g_varchar2_table(19) := '6E7465723B0D0A202020206865696768743A20323870783B0D0A7D0D0A2E7265706F72746D61702D636F6E74726F6C496E6E6572207B0D0A20202020636F6C6F723A207267622832352C32352C3235293B0D0A20202020666F6E742D66616D696C793A20';
wwv_flow_api.g_varchar2_table(20) := '526F626F746F2C417269616C2C73616E732D73657269663B0D0A20202020666F6E742D73697A653A20313270783B0D0A202020206D696E2D77696474683A20323470783B0D0A202020206D696E2D6865696768743A20323470783B0D0A202020206C696E';
wwv_flow_api.g_varchar2_table(21) := '652D6865696768743A20323470783B0D0A2020202070616464696E672D6C6566743A203570783B0D0A2020202070616464696E672D72696768743A203570783B0D0A202020206261636B67726F756E642D7265706561743A206E6F2D7265706561743B0D';
wwv_flow_api.g_varchar2_table(22) := '0A202020206261636B67726F756E642D706F736974696F6E3A2063656E7465723B0D0A7D0D0A2E7265706F72746D61702D636F6E74726F6C436865636B626F78207B0D0A7D0D0A2E7265706F72746D61702D636F6E74726F6C436865636B626F784C6162';
wwv_flow_api.g_varchar2_table(23) := '656C207B0D0A7D0D0A2E7265706F72746D61702D6D6573736167655549207B0D0A202020206261636B67726F756E642D636F6C6F723A20236666663861363B0D0A20202020626F726465722D7261646975733A203270783B0D0A20202020626F782D7368';
wwv_flow_api.g_varchar2_table(24) := '61646F773A20347078203470782036707820317078207267626128302C302C302C2E33293B0D0A202020206D617267696E3A20313070783B0D0A20202020746578742D616C69676E3A2063656E7465723B0D0A202020206D696E2D6865696768743A2033';
wwv_flow_api.g_varchar2_table(25) := '3670783B0D0A7D0D0A2E7265706F72746D61702D6D657373616765496E6E6572207B0D0A20202020636F6C6F723A20233730373037303B0D0A20202020666F6E742D66616D696C793A20526F626F746F2C417269616C2C73616E732D73657269663B0D0A';
wwv_flow_api.g_varchar2_table(26) := '20202020666F6E742D73697A653A20313670783B0D0A202020206D696E2D77696474683A20323470783B0D0A202020206D696E2D6865696768743A20323470783B0D0A202020206C696E652D6865696768743A20323470783B0D0A202020207061646469';
wwv_flow_api.g_varchar2_table(27) := '6E673A2037707820313270782037707820313270783B0D0A202020206261636B67726F756E642D7265706561743A206E6F2D7265706561743B0D0A202020206261636B67726F756E642D706F736974696F6E3A2063656E7465723B0D0A7D0D0A2E726570';
wwv_flow_api.g_varchar2_table(28) := '6F72746D61702D646562756750616E656C207B0D0A202020206261636B67726F756E642D636F6C6F723A202366336633663337643B0D0A202020206D617267696E2D746F703A203270783B0D0A202020206D617267696E2D626F74746F6D3A203070783B';
wwv_flow_api.g_varchar2_table(29) := '0D0A202020206D617267696E2D6C6566743A203270783B0D0A20202020746578742D616C69676E3A2063656E7465723B0D0A7D0D0A';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(196479559923656011)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'jk64reportmap_r1.css'
,p_mime_type=>'text/css'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D494844520000004200000041080600000065C07246000000017352474200AECE1CE900000006624B474400FF00FF00FFA0BDA793000000097048597300000B1300000B1301009A9C180000000774494D4507D90418082A2C';
wwv_flow_api.g_varchar2_table(2) := 'CA68CF8400000EF44944415478DAC59CDD8F9CF755C73FE799D937DBBBB6E3B7244E53DB4993344E4A04729B3608FA1A540A52ABB6820615F5861BDA72C32552051217FC05880B0A2D15A5481429424254A4081252A212540A4EE2247662BB49ECC4217E';
wwv_flow_api.g_varchar2_table(3) := 'DBD7999DE77071BEBF7DCE3C1EC7BBEB5D7B246B7667679EE7F73BBF73BEE77BBEE78C8D4D78D440D5FA3D3F0CBA7A8B011D8FDF970D96F59681C3C000D70BF97AAE0F6EE4C33671F366600E95C1B8C3043066309637547EB42BD7E240DFA10F2C59FC5C';
wwv_flow_api.g_varchar2_table(4) := '5BFCDB70A3D8461BC0A172E81A4C3A4C188CE77DAF72E14E1831AFD30D7A0E4BC02230A892B3B5D771D33CC2A1034C12273F214F706DFC8AFD9717BCB59851EFF7E4311E9E3670E8591864D16490EBF10EBB5E4FA8E3225B812DC8ED7DD8DD5D8BC7753F';
wwv_flow_api.g_varchar2_table(5) := 'DDB49F363D9021CBDFC7B579F4F995EB79CB600A9DF90AE6AFC718B68E93C71B238C1B6C27C0CEDAA7A91FCABA8B4B2F39D4D595189A71A312884E10E135A1EBBB35619371A506961D2E54F1BCB2C64D31448EC31AB61B6C29A79DBD3D9DFCA2C3AC851B';
wwv_flow_api.g_varchar2_table(6) := '97F0D9EEB083F0A2C9143EE5020BC09CC305834B06B58C33096CF578F6EC71691FB5C35C0597D78A1BB65A2FB06130BC8500C1E2BED60A8779E092507E9BC37E83BD1EC6AB92BB6357C78D82051780378033F2A80E3063309541D5860F62D1C290BE5A83';
wwv_flow_api.g_varchar2_table(7) := 'D81ABD60DCE234BB05C4F269140FD02676017713CF7893F6561BC665936661FCDAE02DE084C379197C5A99C9DA3802F450A8ACC618B6DA90A06584D6692C217774B815B8CB608748917BB3C06C04B356E2F01654643CA0E1251DE06DE015833745C6A60B';
wwv_flow_api.g_varchar2_table(8) := '505B139AA6755D1059DB98D000B60133DEF2620B032C38EC060E19EC957BD69640CDE3402A2D6ED1E3C416ACD9BF035D61C038CD732D9CC8E0583CE42CF08AF064ABC71AB33100DEB10895EB3344D9B198E2B4C3565B7989F31ED6BE17B8D3C36BBC95F7';
wwv_flow_api.g_varchar2_table(9) := 'BB0458BE4D9CE0450BC32D2AF3ECD1662B8373757C6E92C0809DC296DD40479891E1A5121E9D3478599FD991B2CA6587D96AA34223839847BA9C927B8E197CC06333852B1437AE082678C2E0B4C1620DB703F718BCC7E176196B3285CC820CF9B20C77CC';
wwv_flow_api.g_varchar2_table(10) := 'E09C47763A208FEB685F859F9878C859E07FF4FB2DCA56B3B64A50B27512A84AA7F68872BD25172FA7711C7849EEFE61835F0276897E7784FEB430A2187399C0971A78DDE1DF801FAB58BBCFE160F2BC7CCF39871F898A7BB58614BA6642950C72BF4556';
wwv_flow_api.g_varchar2_table(11) := 'F0C41D4CE0F4ACE8EFA30E9F9607798B6C79F2A29C9E3316E453BF0C3C6EF0A40710FF3CB0AD182461D63183E3F56612AA11A1F220E1B265D12780970C0E393C6670403581B74E3C33CE41CA40DD16AD26112EF308C5171DBE6B70D6E1307047BAD67183';
wwv_flow_api.g_varchar2_table(12) := '63EB29C0D65D6B24107D8088F7173CF2FC27812F28650D686A8C4AAB9D15885D06E688D8EE5984DA6D0E5302E51965823A9D3A16A1B66CF03D87A765EC43C0AB15BCB4DE2A7423CAF08A00D009835F073EE802331A03546287CF014745886A6D7A4660FB';
wwv_flow_api.g_varchar2_table(13) := '86E8F5BC0727D86D61E4C30E7B64D4629012FE4F02FF0474AAC838EB2EC5AFCB10ADD8FE65E031B97F2D2FE81239FE09871F1314FB51870F0177101BDCA68DBEA1C2ECAC479679DAE10981E6871D3E21AF59F646E55A04FECCE0E84D1766125E8C3B7CD6';
wwv_flow_api.g_varchar2_table(14) := 'E0E33246D7E1A7443CCF005F7778D4E0A007780E554C23F489590BCC791CF85319F5CB0467E9A9FCFE07831F5A639C9BFBF0E19F7FB386BFACE1F37518E3B71C4ED7B158AFC53A5D6E7EAD7F75E816271C3EA5EBFD760DDF74F8D551F7BFE98F7AD818F7';
wwv_flow_api.g_varchar2_table(15) := '3A580D7FA00DD575B3B1D51AA11EF1F3EFE85E775F4D18DE90D3AC37F65AFFB8C68D5FCB33CA75BE73433DC1AFCF08DFD848238CF08CAF6EB831543F54356CAD61CC1BEABB2E4F71F8CA5A71608D9EE11E45DBAF6DE8017B6C74CAE18E1AF679D403DBF4';
wwv_flow_api.g_varchar2_table(16) := 'FA967A446AAEAF7271874335BC526F82015A8670877F97F671CD83AA47EFBBF250DBB7D630566913137A7F87A61F8105857ED8E17E877DB57A1455CB00894B7C0DB873B3A356F73DE2F045AE42A2F2E6C5BEBA75A3964DAB00DC2132B8A570FB2EC379BC';
wwv_flow_api.g_varchar2_table(17) := 'A70FECD5F34EA2E27BAE0E29EE5EE0398B02AB18E17D0E1FB7509F37ED91A4B871834F3BFC9DC19936ABD4E6670C6EF560A953F2A47F2DDDB754C78C75C500278A102B632C7990209222E40E730677015F7478AC0E91E53F3C98E347817B36B13D398AC7';
wwv_flow_api.g_varchar2_table(18) := 'FDA20ABF335523133EE070A7C1531EC4EBEE54F2F7A59CF75B171BEBDA7047A9D4D2CB2E374AAC6FD1A30ED8AF365EC742397AC4E03F1DEE4356B74D267949FF9C060ED421D1FD8937CAF622C14A8FAAF8EBD0E8283B09B12787B555A4A6AC1ECBDA4CC7';
wwv_flow_api.g_varchar2_table(19) := '866FBC64A120DD562CACC5CCEAFD07AD29AF37FD614DEFE4B06A90BEC5BF6542D1BADDC28307AD501D27DE3324E85649032CA7EF5584C1CE96A7F4D54099CC8EE271F3310FCDF266D0FBFB24F12D26F5DAB5A6DA87376C6A125DD177ADAE9663EDCAACB3';
wwv_flow_api.g_varchar2_table(20) := '2CB49D2827A216FD3BF2AAEA26D8019D78479A25C953A709A1B96ED5423ECA65D7B278B748AB9DC41B6AC5DBF88810BB91C64022CFA836EDA8C10B6FA3F95A65BD39854279A1237579410075B3AA5F37D8612D00CCCDE851F8F2AE1E91C891B5B0634C0A';
wwv_flow_api.g_varchar2_table(21) := '52CF87BB51A50973C3F5006B74D0DA615F56C33D42F6624A9D2B3DD551D7AAACC510453D4D7D857CD371356BE61956A3B70A345FF4263E6F8817E846FFA5A653B74560066A14775BE17D39ABE7D923FAA931E334835E2D8981096218E4B48849B9E914A1';
wwv_flow_api.g_varchar2_table(22) := '3E9FE406A6CFB2198317D4D0C9C5E265839F69BD9DD68296D46BE95AD38A5869D1D729A69C483DE77C38CB4CCAF2AFA6E937F4DA218F06CC3B7E03A48284FCAF7918E2FD96CA04F562DFF41086C792A7963665373586CC6270A5A92D32E9A82237F7BC61';
wwv_flow_api.g_varchar2_table(23) := '71952C7FDA1B602C9E7298A0DA476D83B4D0D5902987270C5ED5FD3B89DBCC5ACC536C974714B6BB2C8F18F3E18CD2AB1207B7D6E600CE59D369AA094A3D071C4F54BA060E48A0FD7B0F627323AACF0B068F7BF452F77A03F0038353F2F299D660DA3BD6';
wwv_flow_api.g_varchar2_table(24) := '007CF6B07E25ABF46CD8A5C7D4C63FA7E732AAB303B8C5E029D2EB2AD03E61F04D83176C13432365B37F71F881C1C36A2996BF2F024F19ECD5E17802D63302FCB1DC5204964AD628F4D9D270C614F01A4D8FA2B8D24183172DBCA292DB0D805F203A4E5F';
wwv_flow_api.g_varchar2_table(25) := 'DA4C49515678D3E1AB16F7BCBF74C374CFB70C4EA96B96874C065518622A570E161ED44F53412CA5D6BF132A55AD967E5598A4C37E0F34FEBE0855F958E56184D755A6DB461A249DEA82C19754517ED68707D8DCE06FEB98F1BA2D4DE99A3A6D289378A2';
wwv_flow_api.g_varchar2_table(26) := '9E2B9DF3D2685DF4E1719E2E21659D482E59BCE5418B5EC33342EB129BFB1CBEAEC6CBE7054E763DFC22819A5988429F019E01BEE23148525BD35A7CD662A4E89E96EB1BF07C1DD8D72DF85606DF8C106D5706404B3BAD184745CB9C0777E824A2B25FBA';
wwv_flow_api.g_varchar2_table(27) := 'C4F7E4A6A52CEF499CF97DE09F812F38BCDE9EBC5BAB01F48113C0673C08D49705927DFDAD63F086C3B7EB6825EE47E5B73CE735AD6DBA855FCB051FABAAD9F8B2661A72CB7E52D4FAA4526C61647D8707B5D8EF286F1706B7E470B7C3D7D4F2FB14F037';
wwv_flow_api.g_varchar2_table(28) := '3493B1B64A63AC203DF0E7C450CAEBC0EF490C5AA0E981CE397CDBA2A9FC402903B48F9EC1319AC1D5CC8AE7955D564E1203FE30363AE10D6B43D3F4E70983EC4E75458728749E17937B9F744497BBEE32F880C19B32D6534A790745C246EA79C942A765';
wwv_flow_api.g_varchar2_table(29) := '803F36F81670C4E0370839AE64B9AE0766FC35319DF3417971F1A63111AE7316B851A519CE1AB85CA94CB7562317C5DD547ADD1D2E697147949BCB10B85920F1B3C0270D3EA7D45BE2D6248C9C72785AD2D91E0BA1F72183875C33147A7414FF3F2562FD';
wwv_flow_api.g_varchar2_table(30) := '82DEF7B0D4F10ECDC23B04AE7DDF623CE088C3BEB4B6AE0EE159A5D76D0C4FDBCD0297D238549336F4E2A4F842950CB42CFABC97104BC75BF63B59C1D11A3E6621B177FCCA21F29E98EAF3553471C7BC71D5CC18171D0E021F15759FD6C9E698AA3499F7';
wwv_flow_api.g_varchar2_table(31) := '5D0BC31D21AACF3CA3BDE4F01379E1AE34166D3473DBBDB2EFEE88BA7C512AF6648AD52E30530520ED02DE9B66B00DB8AB8EF73F49E0C9EF223293AE516627F7D1487FFDAB00E57B808F4827B5E499E5E4CE007F61C1733EE4419E48C6AF09EA7D4EE15C';
wwv_flow_api.g_varchar2_table(32) := '25D0718D36F646EA11AD2F9F5C4C6929175DD306FF4B6402F726BF0F08B4FE0831E8F10D83673C55A9C55DE5AAD7CA18C744D6CC8775D325E2BA7FE4F0B6C323C0AD9686D4658C37AA98BBDC21F58C942DFA366268BD3BAA4354451BFFA2C1CE1661D9A6';
wwv_flow_api.g_varchar2_table(33) := '30F98972F2EE64AC6502903EA609966F19FCD0E157E4E23BE4D22F5CAB3D67F07F9AC7DA2D0275419EF603E1CD7BC528C76930A684F91987FF96C43FD5E2130520AF90EAECDDBA2775B87719E15B79BF406CDEE07EA2E153DC314FBF9D11193B2F807CC8';
wwv_flow_api.g_varchar2_table(34) := 'E3F4FE8A6BCC466B86EA7344EBE04581E75BC2A8031683ABBD54805512714F11735A5B54791631A6A4ED4B55B41FAED8B8ADA253BE5DC6A887852C2E297F1F22BA495BCA0675A3D22A384FA0F759B9E535E7A235EE3C237DD4D4A3D843E05355324D6A57';
wwv_flow_api.g_varchar2_table(35) := 'CE39BC5CC1498F89BC698671A552FFE5E2D58650ED5A3D352D6AA726E0EA94875D39FCA2748AC30A8D810D7F79A5143E038BA9D80BAB6496931E45D514716F4B2A5A594357C079CC631D3BCBB77D523D51118D9E8B362224B81A46B42DA478BAA8DFA748';
wwv_flow_api.g_varchar2_table(36) := '73D0FA7D8CF8FB8FA468DF57327141F024A40CD6506354D20DB690A6FD6986D1FBE225A72415EE49EC367BC21CF14D20AFDFE5E4BBABE9B41A0C049E268BE7543566E111732ACD4F03EF2706416B9AEF7EBE25D45FEDA3A779CC99CC79B4A657C5249794';
wwv_flow_api.g_varchar2_table(37) := 'C9B62421DA93C1E6850BF5B57A176B9ACED76A768A0F58EB2B03A5EB74BE8A4D4C7800DB1D2ADB5FB298BA5FF5004E1D1EF6732AAEFA063F73385EC1B278CB4C52AFF357235CD9E65DC361CD8668F7F9954DA64A45EA099953C3781601631D75C782C1FC';
wwv_flow_api.g_varchar2_table(38) := '6AA663EBE1F986DB24B19D13404CAA9D37DEEA6695E50DF405B759D8A4E9FC9631262D72F578AB2E59E93249ED5ED0E9F4D7732FED7442730D93454F60D8F805177A1605606FAD431AEB529BD38955C0160D8F77D314BE33CCED178878F7B51AA3A4EFC4';
wwv_flow_api.g_varchar2_table(39) := '098626FD53477E4E228BD7EBE86776D76388948B6BE5E7256BBE97D9498B2E94B7B71E415761E5AD382FB4DBF4059759C98CCB6B09850D3144CB1818F46B7D3559AD806D4AAB45D8EDAFD55553C62AFF4B4095C2AE5F3088F4BF075CCFBCD2BA0D41D6F3';
wwv_flow_api.g_varchar2_table(40) := '9B5318D4618C791962ABFEB4BCD6384C9BEB2BD3B88641E6CA107AD5EAFF5F4F57E9FF011B99B0508E2564630000000049454E44AE426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(196479906449656011)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'images/m3.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D494844520000004E0000004D0806000000083E52B3000000097048597300000B1300000B1301009A9C18000001396943435050686F746F73686F70204943432070726F66696C65000078DAAD91B14AC3501486BF1B45C5A1';
wwv_flow_api.g_varchar2_table(2) := '5608E2E0702751506CD5C18C495B8A2058AB4392AD494395D224DCDCAA7D0847B70E2EEE3E8193A3E0A0F804BE81E2D4C121487012C16FFACECFE170E007A362D79D86518641AC55BBE948D7F3E5EC13334C014027CC52BBD53A00889338E227023E5F11';
wwv_flow_api.g_varchar2_table(3) := '00CF9B76DD69F037E6C3546960026C77A32C045101FA173AD520C68019F4530DE20E30D549BB06E20128F5727F014A41EE6F4049B99E0FE203307BAEE78331079841EE2B80A9A34B0D504BD2913AEB9D6A59B52C4BDADD2488E4F128D3D12093FB7198A8';
wwv_flow_api.g_varchar2_table(4) := '34511D1D7581FC3F0016F3C576D3916B55CBDA5BE79F713D5FE6F67E8400C4D2639115844375FEDD85B1F3FB5CDC182FC3E12D4C4F8A6CF70A6E3660E1BAC856AB50DE82FBF117C2B34FFE1C09B327000000206348524D00007A25000080830000F9FF00';
wwv_flow_api.g_varchar2_table(5) := '0080E8000052080001155800003A970000176FD75A1F900000148A4944415478DAD49C596C5CE775C77FE7CE0C878B286ADF65CB966DC5CD66174DDA38B0EB382D9A3A05D2026E80224F7D2D50A02D52146881E6A54F7DEB73D087BC1445DBD4DDEC2E40';
wwv_flow_api.g_varchar2_table(6) := '5C277613C349E3C6756CC79257598B29D1A21672389C997BFA30FF431E5E8D280E458AE90508519C3BF77EDFFF3BEBFF9CEFB3928BACE7320CC7AFFBDBA02BEECBDFA9FE0ED4800230FD5B385E077A867501D74F0F28F3736F349E3C26C76F38E6F86C98';
wwv_flow_api.g_varchar2_table(7) := 'ABCED65C053002343486BA00B30488A589FB8A75E8FF74F5D3D14FEF764EE076015718D670BC615823A4CBB090AC22AF78FADD97FEB4123873BC21C92B81D2F19E611DC703C8F2FF2B7085006A1816D2554BD2E5E9A7ACAA7402CC07485CDC50ABCCA12B';
wwv_flow_api.g_varchar2_table(8) := 'C9EBA49FEE668058DF44C046933AD61C37C3DCF112700B4D044BBF2F8124104B01192A6CF17BA8B09E17F7D480BA61238E07806DFDF43612C08D042E6CD4B8406BEAFFA5E32155019EC920BB3E73C34C4EA0179FE9BBE6789116A5E1B80780F15EC7CB8A';
wwv_flow_api.g_varchar2_table(9) := '3D2C621C8E2F020BFAE95524784B8133013519AA98008949065861CF7A40DBB045605112B2422DAB9E50DF2B0CAB393E028CC80CD4652B5D8067E9B574CF38701568FD34005703260D1B4D463E4B048E874A761D9F07E6816EB265A3C01430A1DF1B15B5';
wwv_flow_api.g_varchar2_table(10) := '32D9AA1630EFF835C3E61C9F13A875C3C60D1B13A05EF1B21E218E61538E378139A9F2960037AAC98E840D936459F2A66ED88206DA967A8E030781ED8E8F1B3622AF5B4FF19C57622B971A4718B2A867CE02171DBF62D81549FE846163152F1CEA5FD367';
wwv_flow_api.g_varchar2_table(11) := '851671E1760267C0A861DBE40008239D62B052D2D1923A16C05E60A7613B816D8E8F498D004A4DCC6F14C44A6A2D05C98B86CD03571CBF0CCC1A76C9F15949E7986C5CCDB0321C8E9E11E099C0F3CD06AED04BB7E9FB4BB19606514AB216808EE375C7F7';
wwv_flow_api.g_varchar2_table(12) := '1BB60BD80FEC90542DC6BDE9B9D9C90C9A4859F9B726BBBA4BAA7919B8005C94245ED3F3C7A4FE85BEEBC92ED7F5F7D6305ED7864CB942D2A63468AF00570AB096FEBED3F123C041D99FAE3C6729D52E3CFB02425C57489E6B418A14BF594AA50288701A';
wwv_flow_api.g_varchar2_table(13) := '4DD9D073869D062EC92B87A7AFA550A608DB0B5CD1F7D606843333ACB44D48CD8AB44226633F072C38BE0D380A1C366C02E80AD4F0B608B488C91681760A1B3A52A79C398CC8F03704C04884375A0892432A34BE79C3CE00EFCBA18C686C8DF0F8E1B804';
wwv_flow_api.g_varchar2_table(14) := 'DCDC5AA5CED691E4D70C0BFB54D34BDBC0ACE31DC38E02773A3E15AB1BA049424235160CBB08CC387ED9B079196BD7777629C1AF397E450EC192E79D326C37B0C7F131D9AE6E2C4CB2835DA9ED19E05D8D79879E512A849977FCDA30F9EE7A804393D926';
wwv_flow_api.g_varchar2_table(15) := '3BB7005C1248C71D3F086C531E1A91BD458EEAF80CF08E6167259D93C07EC3F639BE071817C8E302A106CC19D603E61C3F27C93E2B296902871DBF03D8ABFB22902E34AE9E1CD579E094616D6037302A49BCA63892A155D587702A9288BAC0E868F54E68';
wwv_flow_api.g_varchar2_table(16) := 'E2A3A13EE18014DFCD00EF02E704C85D861D07F63ABE5B76732ABC744EEC937AB7057CCBB04BC0078E9F02DE91A41E04EE707CAFECD86204DDB2C18B864D3BFE2670D5B0A6E36DC37A3E6432712B715CC4534DE06EE0B854368C75A8F17CA88954E11EE0';
wwv_flow_api.g_varchar2_table(17) := '23C0FDC09DB237A4EF79D5AB26DBD814B84BE108F01EF063E024F0B63CEA51E00EA975E4A8A645B95BCF7E751867B0199943C449AD64C76A1AEC65017606D803FC82E38F0287A4A66DC3DAE97B395ECB04A34BED57504E52C57B0DFB28300D3C07BC60D8';
wwv_flow_api.g_varchar2_table(18) := '9BB259C781ED32113DBD6341EF6B0E13FCE660DCF1C1AA7A2336F546ACA9E34DC34E004722B673FC0349C182610F3AFEB861772AF26F07239258931C8A8434075332225B6595142E7FAFE1F88861671D7FDAB017B5A8F7C9F6157ADE19E00D79D01B32C3';
wwv_flow_api.g_varchar2_table(19) := 'AB31DBAB02B79ADD1B001CB2172714829C017EE2F876E071E0730A31CA0446E48E26299893F19F97D1BFA8EF3480DD8EEF90FD9C707C4271A1CBF0673B5893FD7D0E78CAF14B86DDEFF821C5762703B4B5003788525F3770AB5C6372F52D8525BF087C5C';
wwv_flow_api.g_varchar2_table(20) := '6C6D27D9AF5149CF34F026F0AAE367059E8B296E2AA4B92C2FD8D567DB8003867D440E69AFA4AF9582E578DF2BC077642EA6800B4AD1580B70ABD5508602EE66229DECD351E0D7814F295B68EB7BA3405312F95DC75F92541D72FC2EE080D2A71D866D77';
wwv_flow_api.g_varchar2_table(21) := '7C9F61D3B2955794CC5F30EC1DC7DF13ADF400F090E347054A5B608CC981BC04FCB5E3172A8CCC2D01B7190CB0CB5B5DD4BF4D0D62DCF136F03DE079017102F838F069E06744026C537CD548CF0CCE2E54F80DE04581F203E07549F7838A03C3E8CF2977';
wwv_flow_api.g_varchar2_table(22) := '6D4962378EB51D56E26EA6C2E99EBDC063863D2AEAE892E3CFCBF3ED30EC09E009C74FC85E0DB4A1555B9AEEE94A15FF1EF83B01F430F01070405EF5DBC03392DA35ACB86F9EAA0E011C4A8BBEE4F827807F03BE63D867813F013E5F016750456B4D1395';
wwv_flow_api.g_varchar2_table(23) := '23F89AE3CF19F690E3BF2A27F08F8ECFDCAC66BA5ACD75AB80C3B0A6C294B71CFFB2617FA620D8158A50A921ACD51C58E5F773C01F027FABCCE1AA78BAD501A848F796035779510DF873C3BEACB0A018B672BE06E973A9E493C09F4A75D72C69C302576C';
wwv_flow_api.g_varchar2_table(24) := 'A8C11CFCA21AF05B867DC5F123A958C306BFDB44947E05F84D79F04D2D1AE709D636F8F923C01765D3F6731B2EB12DBFA770A8BED9C00541992B4D1BF1D24F005F5552CF6648DA0DAE7B81DF017E6E13F0AA0156975E370C1B17CBDA8C9AA762AD49494E';
wwv_flow_api.g_varchar2_table(25) := '2BE590E51A8A1B93C06F38FE305B737D06784221CBB575963D7B09AC5AA2BC16EB49A53CDD686A627191848705DC25B1A9B3621642847A55830B3CECF8E35B005878EB3AF088E39F35ECDF2B631B544B596A2F8BEA9852C231604C0EAE264C8A7AF0FFA1';
wwv_flow_api.g_varchar2_table(26) := 'B6111E44B15636634A4CC394D2965322148FE8BE9315091C71FC41E0F81AD3B40D7512E97D7718F669E0D9544D1B748D033BC50A4771FDAA523C0CAB8B720F6AAB1EED0A23A9081C74CD22FD0A793DEBB7E38847DB2175B84775CC0B22147FE8F8BDB22F';
wwv_flow_api.g_varchar2_table(27) := 'DB06C45DB7C747F4DFB707F88CE3478153E9F3C3B283358DB9E6F89DCA688A44923612A313E46AE178BD9EBB861C5F220BD56BB643897499CA7F8B6A3DB8DBB043625B0F1A760CD867D8DB8E1F17BB6BEB086E374AEA82853E2AE2F434F045999D4949D8';
wwv_flow_api.g_varchar2_table(28) := '8C72DF69A961239528EB2241AF44B13D39B8A27E03EF1974F3680A514C7F5F50DFC66E79E068A18AEA514380EE5C2735B5D1D736C38E39FE8AF2D8BB92DAD6C5C0BC2D9B5D263B58930ACFCA218E54DD6BC1F51D8FD16A359298D3B07F8BA282266538C3';
wwv_flow_api.g_varchar2_table(29) := '207781CBEA883C20BBC8ED96B64A401CDEFD84C0F8D0B019C3AE88E31B91542DD2EF3AF08AC3C84E73452F4B916F968A86940469584FACADAB7619ADA4355656DC3B2A34EF767C7CABA54D131D73FC80E8FA6B3247E1084BEB87646186AA7D77A3B99931';
wwv_flow_api.g_varchar2_table(30) := 'CFA758857140B474B58DB494A48DB2DCE06C86750D9B1D20C15B76692ED11B5C73FC430158482D0B39B089289C677052B3E22D57B9A259B029FB6049853B865DD0609A831665ABA54FF58CEE00D3E4AB10144B1DA359888AA1DFDFBFDAA2C497F45E55A6';
wwv_flow_api.g_varchar2_table(31) := 'BD2C7720F57E9A8093CD1E95B465558E7E3C146A0DB29556B17F2B81AB767D47374F65D56AF240517C8E55AB2BB62B653BCCB65863656E0A157F7A8A0446356E936A5E13C5BFA2102E2C8AB5B02383AE6836B6747F5D2F5EACDA04967BD0AEB2CE4EC74D';
wwv_flow_api.g_varchar2_table(32) := 'B81615AB452F5D8C3FE634AF7B6A153C227B1AE8E10A650979854C52656A0DEDA495B0B46761AE92AF9A5A541B8E9F767C46A2EF5BA49AAEF7CF023F562DB69654D20DEBD0EFEA1C57E89155A454B93252D2EBBC6A37C04B935CEAC3ADAC0032FC134AB1';
wwv_flow_api.g_varchar2_table(33) := '66B35ACB698C8989BDB495715CF2F8570D7B1FD8A5D432E65D02970C3B27D01A118E254159543A560F218B7C35B762556398BAE3B30A6803C442C9FEB861D3924892C48D1976875AB1DECE31E1ED96B604C27B8E9F038EA9D6EA29D49AD31CC71C1F71BC';
wwv_flow_api.g_varchar2_table(34) := '90A446D07B253A4753CB068695D14ADAAD24E24BD570754B9224B20E4C397E510DCBB968D2A4DF85F49EE33F50E334B73BAE4B01EB8CE32F18761EB84FF1E7927D73FCAAB46342397980BA945EB2DC601DA6CA816E18C36EC560A2071186DEB05AF292BB';
wwv_flow_api.g_varchar2_table(35) := 'F4D0F38E5FAB6C623B26957D897E6BC3EDCE57B3CD7EDDB0EF2B1F3DAC46EE58C805C32E3ABEA07CB69E84A62B1BEE4AFC7338E28E778A6042B8BEA33BECC1ACE3AD947AB912F809FA7D1FA7E5E2A3177707F029FAD5F627B7285B404EED5BC0FFD2EF14';
wwv_flow_api.g_varchar2_table(36) := 'D89608CB1A705E639C346C7BD83DA96B5BCC49E4AB45254CE984C4452751953A1E113B30274F1B117613386AD819C37EC2F575CE87B4D3E549C3BE6BB75B53FBD7B7E917A4A3BFA4965329F59E9C14933391A4AA90365D64793F6D8E494B60B1902A952C';
wwv_flow_api.g_varchar2_table(37) := '7703851EA3F0A2A51C34723B57FE7758BFBF66D8BB1AA08B75D8073C269EEB8FC3C3DEC6C4FEB2E37FE1F849C3BE00EC53DE590AC00F8177C5E8EC4B1898E6102D67C1FE9429BDEC1AD6CB015F47A189254730A62F5C32ECC3B0038EF7D4157E10780BF8';
wwv_flow_api.g_varchar2_table(38) := '9EFA3F6259E61C7F40859A17813F922D59911B6E46DCA6C97DCDB0E7D56EF129BD3B5AC0460D7BC9B0FF11C1B95B60B9428F39014B22323CCDBB03CBDB19717C511F1429A1AD895AF9D0F16905B7247B764C0FFF91E36FCA901652FD86618F38FE08F00D';
wwv_flow_api.g_varchar2_table(39) := 'C37E5792B7B493F05683E3143A90B66DFE01F075E0238E3F16E956B4AF1A76CEF197E5F18FB1DC26EBFA7C867ED7661019514EA84962DBD54A7E6C8CF54ACE3AAE174F2B0A0FBA7DD1B0BD6254A70DFB67A561D134BDE0F84EE097804780BF02BEEAF8C9';
wwv_flow_api.g_varchar2_table(40) := 'C4B2DA7AE2BC0C567AC6FBC0EF3BFE75C78F38FECB861D326C419FD714E83F0DBC266AFF00FDCD2B68D15B0AB3BA413555AEAE611DC3964008A3D711131A7F2F15F08ED26FEE3BAB2207DA54E6E2F4670DFB21700C7854F72F28F2DEE7F8AFE959FF2235';
wwv_flow_api.g_varchar2_table(41) := 'F86DE0F332CAB1F37998A24EBEA7053C03FCA5E3CF011FD3621DD7FB4BA58905F09C612FC8C3DE93174199C35BA159868DA610CDA4A2EDB0FF553E2EF6B1D7933D0AEEFD8A1A93F76BC2411F8DAAD2D552FD7227F000CB5DDD0BA2D19FD067FF65D83BAA';
wwv_flow_api.g_varchar2_table(42) := '2E7D4E25C6230300B9D9759E7E7BFEB3C0DF28347A58A0ED5773E1A2C6D1035E77FC29D9E98F2AE16FC921D415AF9ED6DF7609E85E1AD7622E3156F772C5D6F0EDD9BBEAEF57A5DF7719766FCAF7220AFFD0B01F39BEC7B02F3AFE49A9F5628A0B0BE065';
wwv_flow_api.g_varchar2_table(43) := 'C5571FA823FC670DFB82E3F728D91E93872E2B2C4E4744E41CFD9EDE6F69115ED1441FA7DF6F5C931971BDB374FC9461DF74FC7D49E491A0BF64D36B8EBF264757D7B6D0B07BA10D5744410D042E2A3F3B621F69DA5CD6D6171BF4DB4F77EBEF652A034E';
wwv_flow_api.g_varchar2_table(44) := '3BFE7DFABB66BE44BF77A493F672C5FEFA6B86BDAE7BDF943D3924203F69D85105A124EF7616F8BEEAA31F187659B5D09F37EC7E49752F55AAA26DE194E3FF64D8AB02F688C0E9453AA53D652F4BA2A612E011302FD06F0759DA513D682F9769229329A9';
wwv_flow_api.g_varchar2_table(45) := '8D54A3A582C77EFAFDBB93ACDCFFD993B8FF98FECE96270C7B10B816DE29EF18D43EAA964881A714AD4FCA46F6526C56136FD65371F9634AA176699CCD743842388231E015C7BF69D82949DA41DD1B315B08C46BF45BF9C78089E41C4DF3BE1A29D86A35';
wwv_flow_api.g_varchar2_table(46) := '0717C2B98139FA2A9AF22CE7B432B107BE2370EBF4770E16928C6F48527E25D134A1DE4D967BD8261DFF0FD9A5D508D009C3EEA6DF65DE485B375D6A67E94098FF049E567871BFE38745EF07DD5F53A9F32C70561A3616417EA2CBE2080E5F4BB1A62B69';
wwv_flow_api.g_varchar2_table(47) := '984AA94A3023E37AD03B12F93B754FA995AC2B44A9033F01FEC1F10FD49B7B97EEEDA4ADE835FA6DA8ED3584215DA9F91EB5E6775399B321BB36EDF8B3C00BF28227443C2040C2E19569435CA179D5D32663538634C7808EF5FA4D68F31179D0BCA9B72E';
wwv_flow_api.g_varchar2_table(48) := '699B9154D5E8EFD8ABB17CD6D188E2A431FAADF4CF089C8F4BC5F7B3DC8357977D995D83276D036F3B3E27E92992779F51D2FE3AF0DF32230F387E508EA69B6CB803E7A5C2AD20392BA0798A0A7CA8F2A006584B221C06B329CF7309382986748FC43DE2';
wwv_flow_api.g_varchar2_table(49) := 'C142004D19F6A612EA371CFF68B251079402BDCB1ACE02099ACBF1D3B2572D05DF67E8774CBDECF8BC3282FBD46915C7041529C498D6B867E5919B49AB22A05EA4BF4F766070BE968DBEA30A189BE9240593019ED74A37244977A4155D6A5E51403D2346';
wwv_flow_api.g_varchar2_table(50) := 'E28C067FC4B0138E4F19F6AFF25A37ACB8A56B3BFDCD20FB05C06B0A4F4A79CCC3861D483675A962A54A57D04957133D968F2D2A64D72EB3BC596F5DC00578DB456EE6A0D0B4EA572489C7A4A2DB128BB214D268027302FB820687F6619537E0D5AED312';
wwv_flow_api.g_varchar2_table(51) := '6D57EAAA423F497F77E02E9990A2B27021692D49EA5BE21FA7C47EC4DEFCF0DE5DCD67FE4645EA6180331561A61430966915A35438AF01ED76FC1E494430AD964E5C70399F0EFD0D6EAF565DFDCDC0D306B9BBB540E3CAA7EBC9E605704D4D7C5AB631DA';
wwv_flow_api.g_varchar2_table(52) := 'B92652409E9D544F19D2FCCDF2E7B5B64084A12C74484B2D3124B9E5619E7E47D0CBDACF70A7D4A19D292BE582630A0986EE74D7C6E2DD2935F2C4B785F76F481D63A3F1BC4E81989007B6142C87EDBBC6F2D11F6C047091F0C74A4CA630A564E5C14F2D';
wwv_flow_api.g_varchar2_table(53) := '0DF89454F110FDCEC849964F1A8CBC7845343EE45842BD8B54340F2F7D4DF1D9FB0A4F4A2DF84405E8DCC31C15FD351D9F316CD34D299544E29EF9B9603926E4DAAFAA98332D06E58018E568465E30EC927259BF49FDE0BAEABC36F0EE93B44717D56565';
wwv_flow_api.g_varchar2_table(54) := '37D392B205D9E7E89CF7B4ABDA52B6331468EB012E400A9B34216661A90A14AA48BF117941937957F4FA5E71FC7B1D6FEBBC91DE3A25EEAA16B1D078E2488D33690CBB649B23650C523252A98E2477E876FEA1CE1D19B00D72E9342F960F20F054888E16';
wwv_flow_api.g_varchar2_table(55) := '8BB60C6E50D8A332E8AB9EA67593B2E2B8C28E52EA38AFF746A741A6BDBDD255E092DA3939AF817BD93613B8B02B63A284724BBB57272FE98A4EA71E37393DF026C0E5F396EA897CAC0FE8BAB2C438F7B460F371D8DF7A80BBD56D47D1D1532A611E53E9';
wwv_flow_api.g_varchar2_table(56) := 'B0915A4383658DD357EB92D08139E090EF8EAD54CDF4FC2520227E1419D0356C41A0DDF2F1B71BB5492CA4A72BA6240E8DCA9E3778BB380074238AAD11D6D463A152AE191D463D05D8C1E0763662C21BBDBB2E5A071624054D5153F56C0313457FAB5799';
wwv_flow_api.g_varchar2_table(57) := 'F2D025C0F48E38D5B02D5274430E15DD2CE04285BAA2805A02704CEF8AFE93EE5A54650DB626DED3D0A20438DD748E5DB919BD2B9B7DF27404AAADC4E58DB0C63379D730E15EEA8CEFA914D8DA28755CEDFABF0100A16F6D639814B0B40000000049454E';
wwv_flow_api.g_varchar2_table(58) := '44AE426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(196480326877656011)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'images/m4.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '89504E470D0A1A0A0000000D494844520000005A000000590806000000BE3C33AC000000097048597300000B1300000B1301009A9C18000001396943435050686F746F73686F70204943432070726F66696C65000078DAAD91B14AC3501486BF1B45C5A1';
wwv_flow_api.g_varchar2_table(2) := '5608E2E0702751506CD5C18C495B8A2058AB4392AD494395D224DCDCAA7D0847B70E2EEE3E8193A3E0A0F804BE81E2D4C121487012C16FFACECFE170E007A362D79D86518641AC55BBE948D7F3E5EC13334C014027CC52BBD53A00889338E227023E5F11';
wwv_flow_api.g_varchar2_table(3) := '00CF9B76DD69F037E6C3546960026C77A32C045101FA173AD520C68019F4530DE20E30D549BB06E20128F5727F014A41EE6F4049B99E0FE203307BAEE78331079841EE2B80A9A34B0D504BD2913AEB9D6A59B52C4BDADD2488E4F128D3D12093FB7198A8';
wwv_flow_api.g_varchar2_table(4) := '34511D1D7581FC3F0016F3C576D3916B55CBDA5BE79F713D5FE6F67E8400C4D2639115844375FEDD85B1F3FB5CDC182FC3E12D4C4F8A6CF70A6E3660E1BAC856AB50DE82FBF117C2B34FFE1C09B327000000206348524D00007A25000080830000F9FF00';
wwv_flow_api.g_varchar2_table(5) := '0080E8000052080001155800003A970000176FD75A1F90000018F84944415478DADC9D498C65E755C77FE7BEF7EAD5D05DD5F3E06EBB1D3B6DE221267642200E843823442890054220162C4062074B9691B262838412C48288880D20764880022603716C';
wwv_flow_api.g_varchar2_table(6) := '4C12EC38B6E3D84E3A3DB8BBDDF354E39B0E8BEFFFDD7BDEAD57DD55D5D5D5159EF454F5AADE9DCE3DDFFFFCCF78EDCB0CB8BD97E9A7AFF0F7512F1FB1AD8DFA5F0134C23FF5D91BC000E8810DC2867DFDFD26C7E126E7E9B7B81EBFC575ADFC6AB2755E';
wwv_flow_api.g_varchar2_table(7) := '0D9D4FB326E0225C78F86C48A85122F9F34042EFE9677F05296FDAEB6E09DA24C82CD0464DD0F9F34ACB21ABD64AEAD5AF09BA17847F5704BFD9822EF46E828D81B78031B046A591E5D2ED0F2F6D5B097F46E084136E56A1CF7DB02E7817E800DD0037FF';
wwv_flow_api.g_varchar2_table(8) := '6F045D002D1D6F4C422EC0243D77301F06C19B6267F86023B07868DB818E633A8716D87812B47725F0CE30B6FFEC09BA4882654C17D908C6CC83E40612A604E20116CC93C1F320751B54DFF1BC8FA2D25EF361CC767DB622C05643E7D44F822E85DEFB59';
wwv_flow_api.g_varchar2_table(9) := '1274C6DE36302E4117015F0735EDCDC2F59A41F38A5D94F09E977B5119461CAC19AE271B4D0BC78DF81EAF5FAB8C2EB0A47777A335BC7987843C0E4C69FF1696B057822DB5519F8D4ABB2C63683F6D57C7631F450D25542B84FD19FF5BE11C324459D0F8';
wwv_flow_api.g_varchar2_table(10) := '7CB3F38A9B00E681B98D14F6460BBA0D36912ED09B12A8B4C802707A164A4FCB762109D6BA35BA37A90BCFF013C96CFC99717621EDCBE6830237924D6002AC2DD8AA6BB70F5347269381F625607123184A7303B5B82DA18C0701D40C5CB98CB3C62EEA77';
wwv_flow_api.g_varchar2_table(11) := 'D7F6DBD3F69E6FD884FEDE0AFCDA4778113D19B7452DFD85F0735EC759D4CD6A079B518315CF2BAB19E866A16DFB775BD08504B23D50A94158CE56FB5B172C5FB849D3A6C17702BB8069ED2F636F36667E13AFD36AD88C6EE035E02AF8C5F4BB75805909';
wwv_flow_api.g_varchar2_table(12) := '7A429A6E354E1E94C3C6B4020ADDB0C17AB5FB7605DD10164FCAA25359788F17DF4F17E9F3D2B406D8147050EF2919447DDF3AC34BDA56110218FA3DEF6B066C06FC3E09EA02D859F0ABE9066481FBB8A0CC8351CE70D74CE7E70DE17677B305DD0ACBBB';
wwv_flow_api.g_varchar2_table(13) := '114E2E5F68A138C4BC967057C73B00EC4D9AEB53092AAC118CE540372B6A5A318CF143863152B940FF4C8AE01660A00DBE5B9A7E01FC0AD88D84E93E093E11D84A64460D9D27BA9ECE66093A63F2A4F6E123D4AA13B0B2007600BB25E89DD2A6413064A3';
wwv_flow_api.g_varchar2_table(14) := '82483948547F53838A48E51AB5D84776C14DF6635A10B523099B0BC07509B057A3A383C04CB2711E04977E2D82B6F50A3A50A66546AF23CBDF9171DB9F046CBB6584BA620756C18C051A086220326EDE1703E809A2225E3786E91C63E063D52AB3E8D4F4';
wwv_flow_api.g_varchar2_table(15) := 'C4742C09DAA7817DC069B077C0E7F4FFA96490DD2A8FD5A3576AEBD0E875617B3F69AB1515749461CDF9A421DE03DB0B1C06DBA38B37D1B948F71AD579D83CD815E00AF88D64B86C41372E9FEF36617E43376121ACCE4C07A7C176A695E3533A46E6E535';
wwv_flow_api.g_varchar2_table(16) := 'C5F06DC0FDD2F4B3E067D27E6D46FB8B4E91E8E3DAF9F57AA12353AA397D9E1216CE0AFF9A60F782DF03EC91E3E00A140DAAC0124D69ED05B08B5AC6F3D2D029B07D32B6E301AEA62430099A3969ED6CBAC1D605CE0327C52C7682EF4DE7E1DAD67254CF';
wwv_flow_api.g_varchar2_table(17) := '12DFCF1068E3328C6F2783697D609B8EBD108CA16F36EB88C22E801B12C661E0BE8AF2952EB4070C5ED48DB908BC23A18D8985ECD7CF03C2F51D15165B1196700E7936C27E668133090EB8029CD3FFF6A7B74D49EB9BC3F86D4D1D6B4AE77152ABD3C24A';
wwv_flow_api.g_varchar2_table(18) := 'EDAC5750CDE551B27509FB5A08D83C003CA8252A63B2CCF55E4ACB949F4A0B27C11F023E0076549AD51073292AEA182376435E266087C10F06589A4FFBF7578197811F839D06EE15DDDB2E56E4215C9A237C0F806D4BDBDAF5ADE682BBA0E24012942D55';
wwv_flow_api.g_varchar2_table(19) := '58E6456027A7813704313B814F823F9E382F3389621935973D1A3F1BB6BB96FF5F84B8368284871384F161E075E03BC09B60A78087C08F48D90601BFADA28176489ABDB4BEDC46259A8D8E752C68B94E869B9859C23509F994B0EFBDC013C0E309264CAE';
wwv_flow_api.g_varchar2_table(20) := 'B9F7A495D1F12846049B7D44D685101635C1C00E9D4B86A4578057811F09EA0EC968B6C44A9A3A8FCB8221BF831A6DEB8112072E8520FA41615D1FEC2AF82961E70CF00BE0BF0C7644DB860BB2422BA00E3D99737743425654AE8496BC6DA16BE88067C6';
wwv_flow_api.g_varchar2_table(21) := '3203FE11B0C7C09F039E4D50E28B8292DDDA8F8CA91D13B6737BDABC2AE8B075DC509B058E093B0F825D03DE022E03EF023E0DFE8160483DB8BE720CCC92805024CEB3E3734DFBE90926661237F79C3599AAA27458151675D76A430CE653C011E019E035';
wwv_flow_api.g_varchar2_table(22) := 'B03941C95E29CB31B04B1B21E00DC2681FF1BBBB96E43105743AD2B00F021F041E117EF645F7144FB00919A44B895ED931F0B7139FB6AE1C99CC3AA6AA489D351214794BAB65AF78F103E2EF4DC54E3AE13C9B32D80DD1BED780E3F2102F2A0EE21B25E4';
wwv_flow_api.g_varchar2_table(23) := '3B9DCABA2E48D806BC0FF8B80490F93621BBD113ACBC958C1557F5B7B63CB771ED675A98BB47DF392F9A7823C454DE064E08871FD02ABA4776A31356D238F01EDD9806F06D6DB7B84552596BC2EF81824F7BE4F20EE4E55985A5DC90907F9096B1CF25C1';
wwv_flow_api.g_varchar2_table(24) := 'D82FA555E00F80EF908027F59E49C120AE4B70D7B5128E83BD02FE8298CD71B0FBC1DF0F1C4D59142B741E5D19E569DDB8B6BCD1AD969C5D0D7E1BD2BCEF816F077B52466949DCF93AF03CF07569F907C17E03FC3169A2045052B71C1544AEF3A430F8A0';
wwv_flow_api.g_varchar2_table(25) := '6EEA13E04F83FD36F0A230F8BFC05E063EA255B54B02EE2786C32B60DF4D6C6935E1D87511854D2937E88BD6FDA796EED3D2EE9F005F4D9A6CF700BF0FFE6BC063C2D6C668ECB3C0A7A97F675C387D04FC68A290F6ABC03F005F4BCCC73E09FE648208FB';
wwv_flow_api.g_varchar2_table(26) := '1EF837C08F4BF8ABB0495BBB242C0BFB5961F26109FE07C0A3C01F039F53F87294B55DCFD5ED067E45EF23C05FE9F88BC2F3422BE9CDCD10807D792473B8995BBE16977D6411CCB43CC2536999F367609F088CC582B7C7CA01FF35ABDDABC017807F1543';
wwv_flow_api.g_varchar2_table(27) := '195768F416F7D26B50B9BEA2CE4D2C09B3C0467C11F813B0DF13DD63B9DB6D76BB07AA09EBE7C03E2F3BF025D1B97543C116828E152F600CF804F087E08FDC36F8AD5ECB5B29F6C17EC1D897C57836E5558C480BDDC90B6E0B33FF14ECE1108DBBC36A65';
wwv_flow_api.g_varchar2_table(28) := '31C1BB2B195E3E2BAAB8E9826ECA6AC71AE58D7E1D05FE4034CB96C3C566BC1C39507F043CA96BDE0C41BB62BA3EAEF4CD4CC551CBCC866D80E0C7C07F0BFC3377E826AE55C11E077E47C1AF3BF16A100A753246B718AEDE69C901E8289833296E9B6306';
wwv_flow_api.g_varchar2_table(29) := 'B92268B505DD6DE029E0332328DCDD7AED047E5D31EA0B212CB01E63D490875A2FA66F4A8E4BCD001BF9CBC80B2B946075390147B5D1825CDE6B7AC7744F2D0D5F52A3FDE09F03DEBD0504EC212B7308FC63F20EBFBF0AEA1E4B1AF2CF6DBAE60B525615';
wwv_flow_api.g_varchar2_table(30) := '77BA29ECDA0FACC3623D3255857C5995D3566ABEA3E4E54E795627C12FE8607B4499AE8D38C1FB138DB3E9F5B8AF1B6F183D2C6F7B544AF4FD556C9C3DCF9D49A0D656D1CD8514F52B333DCD50D36D600D95D57AB3828BD240B98AB395DAC95A9EA1C549';
wwv_flow_api.g_varchar2_table(31) := '614ECB51B0F72B207443073EA168DC76F02752BC97F626D1B9D53A354A77F913C037180EF4B7A992C4F3A2842DC555F6D560E28642BD3EBCA2CB92866633007751FB52CE68E4B2AF88C7FD109EDCAE00D0233A39D709FF4811B53D72B3F7B0F55EA6D5F8';
wwv_flow_api.g_varchar2_table(32) := '6E52C6FDAAAEE5806CC97E52AAEB84647123846C63665FF579CC53257987985D33D02BAF61546E61C8E9F9DC2FA2BA3453F18A1F4C6EB52DC950160AE2DF0FA6F0A6EFA72AD6F1CDA774A3E06308C26624D809E037810F29AB930DDC8214EABC8C66B796';
wwv_flow_api.g_varchar2_table(33) := 'D96F4AF8DA6639CE17A33973CC0AD7AB5A4DC58BAEF25B9B142D0CFBF05EBABBBEA4F0E8EECA69B8DB421EE9BDEE4A86D1DAD2DC055D5B57D73593CA8AAD9BB235E6A1B6241642BAAE7D5047C62294D7C6837BD5D2E093A90E6D59F4492556B4A4093140';
wwv_flow_api.g_varchar2_table(34) := 'EDA2827D05EC0FDC654CBED56BBF12B4B9763B9F7B5F2BBB2558EC2705F3FAAA544B860B7ECD47117767648F48F9B75C711FA0C507CAD3A95FC49B23C2A24BD2E2A9A4D5BE95053DA5A8624F38DC513CDC2ABB656A1719D99B987D0F5B29B259AC1C16CC';
wwv_flow_api.g_varchar2_table(35) := 'DA6DFD90DE271C7C40D54E5154D86BA625769DAA04CCD9D22FEB49711ACAFACC32D4E4E4A180D21AB5763CAAEF99AFB4706FA7C85177397B9365EF8EEAEA2CF3CA71B656CFF94DD89E114A1BAC1688AE5F3BB756D28D0B93F65670C39B622B16BEF333F2';
wwv_flow_api.g_varchar2_table(36) := 'B2DC741AD8D71023587741F97A02CB39D0B4A84A9F7E500017BDCB0670813BD48D7A07E8DE40583D5983CB5CA6DC0B4EC80AA2B2B50ABAA4D7B934200A32975E65377D30DC6483D5B225C5D6251D868CBAAAFB3DF7D6E402CD8698C65519CA5C265C878C';
wwv_flow_api.g_varchar2_table(37) := '9BC6F28BCAF75F364424CFC5C855F7D1B1913F5FC247AF8667856222CD1480F273322A0C5786DE756CCE7CF84272B1BD95B874AE4AF59A925876BB036E7BEE3ACB9D001678F690468FC2D818A1CABCB2DE67969B2373346F50DB3E37DD5C2115C86C65E6';
wwv_flow_api.g_varchar2_table(38) := '71466E762E42AF53D579BDF335DB88EF2C325C683F4AD09996786CFA2942FC6354F3756E73B82ED7741078B6C9CB92FF6F6793D66F35CFB0CCF29C576BC72E45E3E2AB93623676410CAB5D6D476CBD93327A4B6DD1A157C633FF75AF751C05B7D2675323';
wwv_flow_api.g_varchar2_table(39) := 'E65029AD2617F884FAF42ED5661B156A33BE47058A6F2508F2BA33749721237B707E4AFCF9905A2F621CA30FCCA57231578F8B376A7E5E2F71EF324C9A0D662E9AF7309D651933C8C1122D8BCC91CB03B464A16F90FA44EAFCB2ADA85847598CD3A1D172';
wwv_flow_api.g_varchar2_table(40) := '0B0495CA057A1CEC2595173FA8E0513FB08B01F835B0CB82C389400AF2B564E860D841339302F68A8031FDE5068F963E2F52D51767CF504D9ADE4BC17FBF5EDB47416A189A027E02FEA2C2905BE9B544AAFD7B53D1B7C31264B437F3B233F354430022F4';
wwv_flow_api.g_varchar2_table(41) := 'F6249F4115A01B5AB003A01B053D1881C32DA1C97CCA9C58B6C259ADB7EBC0578193A1163A43CC7412B6B58067C17F3A32B4B2E96E60790E17C19E5394F13D6A100A096B1CEC5CD266579A2ABBE025CCCE53D687587344C8C1C1FB458867F4C28A8E1988';
wwv_flow_api.g_varchar2_table(42) := 'DCCF371B703CD39829A575E6C15E13A71EAB0CA8B7D2057010EC5FD277EC2E234719DCEA264DF6AF2B00F6684D5B051BBC995889ED4A3722275CDD65B7E69212960810E6817821DC1ED2E85E2DF09F9746A6701729CB664B2EDC003B207EF95AE2A3DE0F';
wwv_flow_api.g_varchar2_table(43) := 'ADBD3DC1C77B75B3BE027C6B8BC0C61BE05F4AF6C58E0A9F2DD891CC248E91DA39F68900445FA010EBBA21056B8E58AE7D093A6FE8FD5A4C225BE409EDF8B204EE21BCDA2355CCEF1205FA81C8BF8A52AC239AF710A942E95BC0979261BCABC1FE8BC03F';
wwv_flow_api.g_varchar2_table(44) := '01FF0CF610F08B0916CAB1427915BF2567AB4D6AC128828C34EEC2AEA7D511475194DE71468A7E51977CA026B9C946135BBC27BC5A1416E9E6F8A49A6CC680EF821D4FB18E72892EA6D8817F545AF30CF0976A291E1DBCBD6374AE5CADFF08F677AACB7E';
wwv_flow_api.g_varchar2_table(45) := '0AFC906689A814C1C792A6DA37A95AE4A6057B83D0057659184D706462DC3E17BB5313B47782DB69E1EEB6854BA775A75B810F0F124EFBBD4953FCB5C442CA61509AE8657BC13FAB9BF237AAEC3C1DF0907073374AB83E4CE7AC0F7C11F80B09F053A975';
wwv_flow_api.g_varchar2_table(46) := '83A6B42F0B6C5ECD4A6F26A5B1039510DD159F2E8053C2E77615F1730FDDBE6AD7F32141674C1AD5B9AF1D714577B11340BFA3A0F811FD7C85D478D30F71811CF57A225D1CD3C0DF26CDE6F55B440A6F1B27F43A0DFCB5847C1AF890DEDBA87ABCF33CBC';
wwv_flow_api.g_varchar2_table(47) := '1F2696445F946F3755B37D6615B9ACA22F0A6B2382D3B9396959F44E46D1FB61990D0415E30A969C5357A9FA014B0632931C14BB0AF6ED6444BCA3A26F57FF779FD402F7BB12F6571266E79EEB4C9BFC362065488B5D81FC933AD69F27E7C33F01FE4979';
wwv_flow_api.g_varchar2_table(48) := 'B68A97E7D4959D057B3E79B31C4A8C290F2274D470349F9888676C1EAF4DA20CB3419263D3F82C9F8F31ED1CDED4B2B7E8BC8812D992E2CDBB2A0B5D364D6E97C1BCA026C9C33296FD603C8BE01C5C065E005ED252CBABA2AE94B6362D8E45EFFC37D817';
wwv_flow_api.g_varchar2_table(49) := '80BF079F013E4DEA0DDFA5889B667F98860CFA33C0F7D4CFFEB0B4B517C23DAD74DEF696B47C4A4544815BDB400D51D99161545235B78535C3CE5D146E8AAABF6F0FA91E42BEBE29A2E747B4645E151B51CCC317A43D5D41D1512DC3EF8A427D11FC7952';
wwv_flow_api.g_varchar2_table(50) := 'F7D4A3603F5FD98251F347B9892DF5B792B0780EEC3BC2D207C19ED214851D551C9D86E2CF57F4DD17648F1E9601B4A0206D79C067925F617996880F0F4BC42927E7AC9CCAD2D0BFA1ACAE87D0678BAA813ECFB98B746F17A9D6EE0DE07FF4BF8FCBB1D1';
wwv_flow_api.g_varchar2_table(51) := '981F7AFAFD11E1DF8BA4C6A1AF09E31F107E3EA6FD6DD34D6DB17CA6924B73AF6A859C506CE565C5603AA47AE80F8BD30FC4847A9403ADB8A61BF38C1C907709360621AC90057E863417A4A5D5D7A8D1E2D0B35E69C02841E7F94563D55CB878B77C5294';
wwv_flow_api.g_varchar2_table(52) := 'E6BC66D5A90ECD625C7BB7B8F38B2996E0E3499BD8A995A211C3F4C4583E02F638D8EBE02F01FF01FECD542A6CF782DFAF65BC43E716CFBF27EFED7561F1150588F6AB91539E2913F20007A14D390F687911F8A69C9787D2F1B27D2A4BBE06F215CE6A9B';
wwv_flow_api.g_varchar2_table(53) := '999ABB9D6791E4A15DFD7A1295D1C2A6CBB25A85928174D50C7F461ABDAB96CA6A80EF92B07F027C5D3CFC63299768D7C3A8887E0850BD37E1B4CD2683EBDF017B16EC7F55CDDA5A9E60B041D266B7245C9ED4CFBD82882919E47E68EECF1EEF523A065F';
wwv_flow_api.g_varchar2_table(54) := '4D3E020F91BA76759C3801D896C0CF4AE3958971AB452DB5AA7DD938A095B2E02A80A11D8A6362FC635C277E4ECB674A243F0EE61B937133F013F20A2F031F2535ED7443863CEF77A7B03FC3C19BE03F9461BD700B1BB85390F3948C9E0262B9D8874135';
wwv_flow_api.g_varchar2_table(55) := 'A0C55AA49EF11784CB9713ACF87D326C5ECD9DF646821F3BAF98479EB3D4A8C90539274BA3B2FECD95235CE5DCBA51B3ED7289D815E1D5840C5E8BE1B9A4E3F20627B4B49FA32C12649F584A5E9683E1E46EE9EEAFF6D5D4FE0E53CD3DAD976D0D74D3CE';
wwv_flow_api.g_varchar2_table(56) := 'CA7E3CAF9BFDA062E78DE0845908A05DD4BC9105CA5115CB58CE80E159ABAB12B436F439DDFDE608D3DF1617BE26D630A6D919ED9012EB504D7F992295F2BE9CC643D8D36A15DE5BCBA2E77AC0B7A475AB8B7CA6F8C5891046F0E161BA0C344BE438F8BF';
wwv_flow_api.g_varchar2_table(57) := '09D26692C13555BB5A48325B9EF7713D9D875F4A37D227AB04ACD579F38AA515B72AA019A41880E5D4D5A096FD9D9051BBA168D823AAE76854CBB5C4E0E944DB98067B1BF87735C3BF2F35D9DB2E41900A26EDDCADE162886B6B85F9BC8EA55977E5E0D7';
wwv_flow_api.g_varchar2_table(58) := '3792D1F31312DEA1C48E7C87667A0C6ADA2F1EEE3F167B916352AEEE88F7B902B57FB3E5B69A2C4478B244596D9A738ADBA52DD74993B896648C26187E524443542D4F8A3999B48B2BA46961FB6408EF13DE9FE2A6B33346FA3037B4CFC33AEF538289B3';
wwv_flow_api.g_varchar2_table(59) := '49DBFD8236BC5FF6637B758E4303B07A8961704AD058E8BB2D96C792731A6B919B0C1E6CAE6E5DFA6230828D1A8C8CC9BACF2A939C677CDE433902C2558169F35A19EF5690E9ACF8F8F7351B495AC684F8EA08C1DE14B66753FE8FB793D0ED98847C59FB';
wwv_flow_api.g_varchar2_table(60) := 'BC373092A6B4D043014C8EDD5C94017F47D7375305D696B54E2C8EA273EB11746621AAB0F4891A6FCEDAAAC08ACF26CDA6A3E539139C190B64BE2DADDA2F67E37A9A7ECB0B2145742B5C1EA1D1F692AC7F27C5687CA7C2A13BD4AC54840727E442FB50C3';
wwv_flow_api.g_varchar2_table(61) := 'E2EF68855DD34C91A98A565AAD5AC0960455DDD5586AD6266C33C59773E57FCCB64C5631683BAEA57C44AD156DB9A4DD30814637C8DAA2647B152739C98AF57A371DC8928773EF93C3D2D68D9E5478A011E02C7ABB3D19D333C263C5D0990CCF081884AC';
wwv_flow_api.g_varchar2_table(62) := '0A8A65CCC906F8460A3ABBE7735423826BF57625C56A6805BCA38B9FA79A76DE0E61D37E8D9AEDD5FFCFB3BE67A364E1E501E0F1A9158370DC6244B8F3B47039873DB7D5B685E1D1F973AC61FEFF7ACA7665C5AD9E5588F56693FA9F668FDA3505FCDF25';
wwv_flow_api.g_varchar2_table(63) := 'A7246B6751656ACC64C016B5F4D79900F022C09ACA0186667F844824F33278D9F0B635417D2CDCB8903129CF7196350EB95A6F7D7457B4AF503C24543C9513181B60B2D43EAF21249785C94794836B5404DF0B31168D5FBB99A0FD56E736ABB8C614C355';
wwv_flow_api.g_varchar2_table(64) := 'E60D51B96B12EE19552121DAD966685E6BD9AB12878FE7F1F96C86A01506C4A96636DBF27205CFCF35694803E6D205FAAC3467A78CD476393A735A2DB7534F9DFB5096640809C1A3F3E2DA7AC8429EF06B1315A3F21846880FE2E94A9397D8E4B1C651D8';
wwv_flow_api.g_varchar2_table(65) := '1EA8DCA80713E60B694B0897F49E9286CF08BF73EA7E709BE7958B5A26757397A88A312FD5ECC24490C388A76378BF82B4B25A8BCD1474C4ECCC3EC62A777D682E52AEF51076E707C9D882DC77246CD3DF6E3741BB94846AB3D2DC2BD2C81CEC9A0C3E81';
wwv_flow_api.g_varchar2_table(66) := '57E3EE4B1C8FB1650D035FFFECE88D12745EAE7ABE4916660E6196A4245F501E1BDCD277F57C2A9B1FE110DC8EA0CF85D595D367AD44D73C385D16A71D50955AD009CF8BB9ED1E9C8DEC96EA0737349786C512A9410D4E5AD543106C3C2CCD8D2837F070';
wwv_flow_api.g_varchar2_table(67) := '0EE3D5B9E447FB9541A7DA00F1F2DCF33C920D7B38D946B7A5E56C774754695CCE88FA3BCA87E244CD6D04B77E231F73175DE7F864B941B8D9B1A155017B5B0A6D121BF6BA53FD7F1EF2724BD2D876E83CB560D97390BDC3C6766FE5F84ABF2AA21F1AFE';
wwv_flow_api.g_varchar2_table(68) := '6D0126F26ACA89880D7F88E49D6EB4EC5569315FA41A29D466F86944D16B5B6D587495828E8FD6F3E8DD75AB890CDE5DDBF1B79EA0431E2D6B37632121D0AC321F6B7F5ACFAD63E9CBBAC5E2C37EF3138D36A50772B35B87072176DB0CDC7AC09A9EACB6';
wwv_flow_api.g_varchar2_table(69) := 'EA91CA828E5C2A606A40BDB3DA3BEAF57F0300BFB046A4513C75FF0000000049454E44AE426082';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(196480709738656010)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'images/m5.png'
,p_mime_type=>'image/png'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2F2A0D0A6A6B3634205265706F72744D61702076312E35204A616E20323032310D0A68747470733A2F2F6769746875622E636F6D2F6A6566667265796B656D702F6A6B36342D706C7567696E2D7265706F72746D61700D0A436F70797269676874202863';
wwv_flow_api.g_varchar2_table(2) := '292032303136202D2032303231204A656666726579204B656D700D0A52656C656173656420756E64657220746865204D4954206C6963656E63653A20687474703A2F2F6F70656E736F757263652E6F72672F6C6963656E7365732F6D69742D6C6963656E';
wwv_flow_api.g_varchar2_table(3) := '73650D0A2A2F0D0A0D0A24282066756E6374696F6E2829207B0D0A2020242E7769646765742820226A6B36342E7265706F72746D6170222C207B0D0A0D0A202020202F2F2064656661756C74206F7074696F6E730D0A202020206F7074696F6E733A207B';
wwv_flow_api.g_varchar2_table(4) := '0D0A2020202020202020726567696F6E49642020202020202020202020202020203A2022222C0D0A2020202020202020616A61784964656E7469666965722020202020202020203A2022222C0D0A2020202020202020616A61784974656D732020202020';
wwv_flow_api.g_varchar2_table(5) := '2020202020202020203A2022222C0D0A2020202020202020706C7567696E5265736F757263655061746820202020203A2022222C0D0A2020202020202020706C7567696E46696C65507265666978202020202020203A2022222C0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(6) := '65787065637444617461202020202020202020202020203A20747275652C0D0A20202020202020206D6178696D756D526F77732020202020202020202020203A206E756C6C2C0D0A2020202020202020726F777350657242617463682020202020202020';
wwv_flow_api.g_varchar2_table(7) := '2020203A206E756C6C2C0D0A2020202020202020696E697469616C43656E746572202020202020202020203A207B6C61743A302C6C6E673A307D2C0D0A20202020202020206D696E5A6F6F6D202020202020202020202020202020203A20312C0D0A2020';
wwv_flow_api.g_varchar2_table(8) := '2020202020206D61785A6F6F6D202020202020202020202020202020203A206E756C6C2C0D0A2020202020202020696E697469616C5A6F6F6D2020202020202020202020203A20322C0D0A202020202020202076697375616C69736174696F6E20202020';
wwv_flow_api.g_varchar2_table(9) := '2020202020203A202270696E73222C0D0A20202020202020206D617054797065202020202020202020202020202020203A2022726F61646D6170222C202F2F676F6F676C652E6D6170732E4D61705479706549640D0A2020202020202020636C69636B5A';
wwv_flow_api.g_varchar2_table(10) := '6F6F6D4C6576656C2020202020202020203A206E756C6C2C0D0A20202020202020206973447261676761626C652020202020202020202020203A2066616C73652C0D0A2020202020202020686561746D61704469737369706174696E6720202020203A20';
wwv_flow_api.g_varchar2_table(11) := '66616C73652C0D0A2020202020202020686561746D61704F7061636974792020202020202020203A20302E362C0D0A2020202020202020686561746D6170526164697573202020202020202020203A20352C0D0A202020202020202070616E4F6E436C69';
wwv_flow_api.g_varchar2_table(12) := '636B202020202020202020202020203A20747275652C0D0A20202020202020207265737472696374436F756E74727920202020202020203A2022222C0D0A20202020202020206D61705374796C652020202020202020202020202020203A2022222C0D0A';
wwv_flow_api.g_varchar2_table(13) := '202020202020202074726176656C4D6F6465202020202020202020202020203A202244524956494E47222C202F2F676F6F676C652E6D6170732E54726176656C4D6F64650D0A2020202020202020756E697453797374656D202020202020202020202020';
wwv_flow_api.g_varchar2_table(14) := '203A20224D4554524943222C202F2F676F6F676C652E6D6170732E556E697453797374656D0D0A20202020202020206F7074696D697A65576179706F696E74732020202020203A2066616C73652C0D0A2020202020202020616C6C6F775A6F6F6D202020';
wwv_flow_api.g_varchar2_table(15) := '20202020202020202020203A20747275652C0D0A2020202020202020616C6C6F7750616E2020202020202020202020202020203A20747275652C0D0A20202020202020206765737475726548616E646C696E6720202020202020203A20226175746F222C';
wwv_flow_api.g_varchar2_table(16) := '0D0A2020202020202020696E6974466E20202020202020202020202020202020203A206E756C6C2C0D0A20202020202020206D61726B6572466F726D6174466E2020202020202020203A206E756C6C2C0D0A202020202020202064726177696E674D6F64';
wwv_flow_api.g_varchar2_table(17) := '657320202020202020202020203A206E756C6C2C0D0A202020202020202066656174757265436F6C6F7220202020202020202020203A202723636336366666272C0D0A202020202020202066656174757265436F6C6F7253656C65637465642020203A20';
wwv_flow_api.g_varchar2_table(18) := '2723666636363030272C0D0A20202020202020206665617475726553656C65637461626C652020202020203A20747275652C0D0A202020202020202066656174757265486F76657261626C65202020202020203A20747275652C0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(19) := '666561747572655374796C65466E2020202020202020203A206E756C6C2C0D0A20202020202020206472616744726F7047656F4A534F4E20202020202020203A2066616C73652C0D0A09096175746F466974426F756E6473202020202020202020203A20';
wwv_flow_api.g_varchar2_table(20) := '747275652C0D0A2020202020202020646972656374696F6E7350616E656C20202020202020203A206E756C6C2C0D0A202020202020202073706964657266696572202020202020202020202020203A207B7D2C0D0A202020202020202073706964657266';
wwv_flow_api.g_varchar2_table(21) := '79466F726D6174466E202020202020203A206E756C6C2C0D0A202020202020202073686F7750696E732020202020202020202020202020203A20747275652C20202F2F73686F77207468652050696E73202870696E20747970652076697375616C697361';
wwv_flow_api.g_varchar2_table(22) := '74696F6E73206F6E6C79290D0A202020202020202073686F77496E666F506F707570732020202020202020203A20747275652C20202F2F73686F772074686520496E666F20706F707570207768656E2070696E20697320636C69636B65640D0A20202020';
wwv_flow_api.g_varchar2_table(23) := '2020202073686F77496E666F4C61796572202020202020202020203A2066616C73652C202F2F73686F772074686520496E666F206C61796572202870696E20747970652076697375616C69736174696F6E73206F6E6C79290D0A2020202020202020696E';
wwv_flow_api.g_varchar2_table(24) := '666F4C61796572466F726D6174466E2020202020203A206E756C6C2C0D0A202020202020202073686F775370696E6E65722020202020202020202020203A20747275652C0D0A202020202020202064657461696C65644D6F7573654576656E7473202020';
wwv_flow_api.g_varchar2_table(25) := '203A2066616C73652C0D0A202020202020202069636F6E426173655061746820202020202020202020203A2022222C0D0A20202020202020206E6F446174614D657373616765202020202020202020203A2022222C0D0A20202020202020206E6F416464';
wwv_flow_api.g_varchar2_table(26) := '72657373526573756C7473202020202020203A202241646472657373206E6F7420666F756E64222C0D0A2020202020202020646972656374696F6E734E6F74466F756E6420202020203A20224174206C65617374206F6E65206F6620746865206F726967';
wwv_flow_api.g_varchar2_table(27) := '696E2C2064657374696E6174696F6E2C206F7220776179706F696E747320636F756C64206E6F742062652067656F636F6465642E222C0D0A2020202020202020646972656374696F6E735A65726F526573756C747320203A20224E6F20726F7574652063';
wwv_flow_api.g_varchar2_table(28) := '6F756C6420626520666F756E64206265747765656E20746865206F726967696E20616E642064657374696E6174696F6E2E222C0D0A0D0A20202020202020202F2F2043616C6C6261636B730D0A20202020202020206164644F7665726C61792020202020';
wwv_flow_api.g_varchar2_table(29) := '20202020202020203A206E756C6C2C202F2F61646420616E206F7665726C61792028652E672E206D6170206F7220696E666F20626F7829206F6E20746F70206F6620746865206D61700D0A2020202020202020636C69636B202020202020202020202020';
wwv_flow_api.g_varchar2_table(30) := '2020202020203A206E756C6C2C202F2F73696D756C617465206120636C69636B206F6E2061206D61726B65720D0A202020202020202064656C657465416C6C46656174757265732020202020203A206E756C6C2C202F2F64656C65746520616C6C206665';
wwv_flow_api.g_varchar2_table(31) := '617475726573202864726177696E67206D616E61676572290D0A202020202020202064656C65746553656C65637465644665617475726573203A206E756C6C2C202F2F64656C6574652073656C6563746564206665617475726573202864726177696E67';
wwv_flow_api.g_varchar2_table(32) := '206D616E61676572290D0A2020202020202020666974426F756E647320202020202020202020202020203A206E756C6C2C202F2F70616E2F7A6F6F6D20746865206D617020746F2074686520676976656E20626F756E64730D0A20202020202020206765';
wwv_flow_api.g_varchar2_table(33) := '6F6C6F6361746520202020202020202020202020203A206E756C6C2C202F2F66696E64207468652075736572277320646576696365206C6F636174696F6E0D0A2020202020202020676574416464726573734279506F7320202020202020203A206E756C';
wwv_flow_api.g_varchar2_table(34) := '6C2C202F2F67657420636C6F73657374206164647265737320746F2074686520676976656E206C6F636174696F6E0D0A2020202020202020676F746F416464726573732020202020202020202020203A206E756C6C2C202F2F7365617263682062792061';
wwv_flow_api.g_varchar2_table(35) := '64647265737320616E6420706C616365207468652070696E2074686572650D0A2020202020202020676F746F506F73202020202020202020202020202020203A206E756C6C2C202F2F706C616365207468652070696E206174206120676976656E20706F';
wwv_flow_api.g_varchar2_table(36) := '736974696F6E207B6C61742C6C6E677D0D0A2020202020202020676F746F506F734279537472696E6720202020202020203A206E756C6C2C202F2F706C616365207468652070696E206174206120676976656E20706F736974696F6E20286C61742C6C6E';
wwv_flow_api.g_varchar2_table(37) := '672070726F7669646564206173206120737472696E67206F72204C61744C6E674C69746572616C290D0A2020202020202020686964654D6573736167652020202020202020202020203A206E756C6C2C202F2F6869646520746865207761726E696E672F';
wwv_flow_api.g_varchar2_table(38) := '6572726F72206D6573736167650D0A20202020202020206C6F616447656F4A736F6E537472696E672020202020203A206E756C6C2C202F2F6C6F61642066656174757265732066726F6D20612047656F4A534F4E20646F63756D656E740D0A2020202020';
wwv_flow_api.g_varchar2_table(39) := '20202070616E546F2020202020202020202020202020202020203A206E756C6C2C202F2F70616E206D617020746F20676976656E206C6F636174696F6E20286C61742C6C6E67290D0A202020202020202070616E546F4279537472696E67202020202020';
wwv_flow_api.g_varchar2_table(40) := '202020203A206E756C6C2C202F2F70616E206D617020746F20676976656E20706F736974696F6E20286C61742C6C6E672070726F7669646564206173206120737472696E67206F72204C61744C6E674C69746572616C290D0A2020202020202020706172';
wwv_flow_api.g_varchar2_table(41) := '73654C61744C6E672020202020202020202020203A206E756C6C2C202F2F70617273652061206C61742C6C6E6720737472696E6720696E746F206120676F6F676C652E6D6170732E4C61744C6E670D0A2020202020202020726566726573682020202020';
wwv_flow_api.g_varchar2_table(42) := '20202020202020202020203A206E756C6C2C202F2F7265667265736820746865206D6170202872652D72756E20746865207175657279290D0A202020202020202073686F77446972656374696F6E732020202020202020203A206E756C6C2C202F2F7368';
wwv_flow_api.g_varchar2_table(43) := '6F7720726F757465206265747765656E2074776F206C6F636174696F6E730D0A090973686F77496E666F57696E646F772020202020202020203A206E756C6C2C202F2F73657420616E642073686F7720696E666F2077696E646F772028706F7075702920';
wwv_flow_api.g_varchar2_table(44) := '666F7220612070696E0D0A202020202020202073686F774D6573736167652020202020202020202020203A206E756C6C20202F2F73686F772061207761726E696E672F6572726F72206D6573736167650D0A202020207D2C0D0A0D0A202020202F2F7265';
wwv_flow_api.g_varchar2_table(45) := '7475726E20676F6F676C65206D617073204C61744C6E67206261736564206F6E2070617273696E672074686520676976656E20737472696E670D0A202020202F2F7468652064656C696D69746572206D6179206265206120737061636520282029206F72';
wwv_flow_api.g_varchar2_table(46) := '20612073656D69636F6C6F6E20283B29206F72206120636F6D6D6120282C292077697468206F6E6520657863657074696F6E3A0D0A202020202F2F69662074686520646563696D616C20706F696E7420697320696E64696361746564206279206120636F';
wwv_flow_api.g_varchar2_table(47) := '6D6D6120282C292074686520736570617261746F72206D757374206265206120737061636520282029206F722073656D69636F6C6F6E20283B290D0A202020202F2F652E672E3A0D0A202020202F2F202020202D31372E39363039203132322E32313232';
wwv_flow_api.g_varchar2_table(48) := '0D0A202020202F2F202020202D31372E393630392C3132322E323132320D0A202020202F2F202020202D31372E393630393B3132322E323132320D0A202020202F2F202020202D31372C39363039203132322C323132320D0A202020202F2F202020202D';
wwv_flow_api.g_varchar2_table(49) := '31372C393630393B3132322C323132320D0A202020202F2F416C736F206163636570747320616E64207061727365732061204C61744C6E674C69746572616C2C20652E672E0D0A202020202F2F202020207B226C6174223A2D31372E393630392C20226C';
wwv_flow_api.g_varchar2_table(50) := '6E67223A3132322E323132327D0D0A2020202070617273654C61744C6E673A2066756E6374696F6E20287629207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E70617273654C61744C6E67222C2076293B0D0A202020';
wwv_flow_api.g_varchar2_table(51) := '202020202076617220706F733B0D0A2020202020202020696620287620213D3D206E756C6C202626207620213D3D20756E646566696E656429207B0D0A20202020202020202020202069662028762E6861734F776E50726F706572747928226C61742229';
wwv_flow_api.g_varchar2_table(52) := '2626762E6861734F776E50726F706572747928226C6E67222929207B0D0A202020202020202020202020202020202F2F20706172736520617320676F6F676C652E6D6170732E4C61744C6E674C69746572616C0D0A202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(53) := '20706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E672876293B0D0A2020202020202020202020207D20656C7365207B0D0A20202020202020202020202020202020766172206172723B0D0A2020202020202020202020202020202069';
wwv_flow_api.g_varchar2_table(54) := '662028762E696E6465784F6628223B22293E2D3129207B0D0A2020202020202020202020202020202020202020617272203D20762E73706C697428223B22293B0D0A202020202020202020202020202020207D20656C73652069662028762E696E646578';
wwv_flow_api.g_varchar2_table(55) := '4F6628222022293E2D3129207B0D0A2020202020202020202020202020202020202020617272203D20762E73706C697428222022293B0D0A202020202020202020202020202020207D20656C73652069662028762E696E6465784F6628222C22293E2D31';
wwv_flow_api.g_varchar2_table(56) := '29207B0D0A2020202020202020202020202020202020202020617272203D20762E73706C697428222C22293B0D0A202020202020202020202020202020207D0D0A2020202020202020202020202020202069662028617272202626206172722E6C656E67';
wwv_flow_api.g_varchar2_table(57) := '74683D3D3229207B0D0A20202020202020202020202020202020202020202F2F636F6E7665727420746F2075736520706572696F6420282E2920666F7220646563696D616C20706F696E740D0A2020202020202020202020202020202020202020617272';
wwv_flow_api.g_varchar2_table(58) := '5B305D203D206172725B305D2E7265706C616365282F2C2F672C20222E22293B0D0A20202020202020202020202020202020202020206172725B315D203D206172725B315D2E7265706C616365282F2C2F672C20222E22293B0D0A202020202020202020';
wwv_flow_api.g_varchar2_table(59) := '2020202020202020202020617065782E64656275672822706172736564222C20617272293B0D0A2020202020202020202020202020202020202020706F73203D206E657720676F6F676C652E6D6170732E4C61744C6E67287061727365466C6F61742861';
wwv_flow_api.g_varchar2_table(60) := '72725B305D292C7061727365466C6F6174286172725B315D29293B0D0A202020202020202020202020202020207D20656C7365207B0D0A2020202020202020202020202020202020202020617065782E646562756728276E6F204C61744C6E6720666F75';
wwv_flow_api.g_varchar2_table(61) := '6E64272C2076293B0D0A202020202020202020202020202020207D0D0A2020202020202020202020207D0D0A20202020202020207D0D0A202020202020202072657475726E20706F733B0D0A202020207D2C0D0A202020200D0A202020202F2A0D0A2020';
wwv_flow_api.g_varchar2_table(62) := '2020202A0D0A20202020202A204D6170204F7665726C61790D0A20202020202A0D0A20202020202A2F0D0A202020206164644F7665726C61793A2066756E6374696F6E2028636F6E74656E742C206F7074696F6E7329207B0D0A20202020202020206170';
wwv_flow_api.g_varchar2_table(63) := '65782E646562756728226164644F7665726C6179222C20636F6E74656E742C206F7074696F6E73293B0D0A2020202020202020766172206F7665726C61794F7074696F6E73203D20242E657874656E64287B0D0A20202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(64) := '2F2F64656661756C74206F7074696F6E730D0A20202020202020202020202020202020626F756E647320202020202020202020203A206E756C6C2C20202020202F2F207363616C6520746865206F626A65637420746F206D617463682074686973207261';
wwv_flow_api.g_varchar2_table(65) := '6E6765206F66206C61742C6C6F6E6720636F6F7264696E617465732028652E672E20746F2073686F772061206D617020696D616765206F6E20746F70206F6620746865206D6170290D0A20202020202020202020202020202020706F7320202020202020';
wwv_flow_api.g_varchar2_table(66) := '202020202020203A206E756C6C2C20202020202F2F2028706F73206F6E6C792920706F736974696F6E20746865206F626A656374206174207468697320706F696E742028646F6E2774207363616C65206974290D0A202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(67) := '20686F72697A6F6E74616C416C69676E20203A202263656E746572222C202F2F2028706F73206F6E6C7929206C6566742C2063656E7465722C2072696768740D0A20202020202020202020202020202020766572746963616C416C69676E202020203A20';
wwv_flow_api.g_varchar2_table(68) := '226D6964646C65222C202F2F2028706F73206F6E6C792920746F702C206D6964646C652C20626F74746F6D0D0A20202020202020202020202020202020686F72697A6F6E74616C4F6666736574203A20302C20202020202020202F2F2028706F73206F6E';
wwv_flow_api.g_varchar2_table(69) := '6C792920706978656C206F6666736574202878290D0A20202020202020202020202020202020766572746963616C4F66667365742020203A20302C20202020202020202F2F2028706F73206F6E6C792920706978656C206F6666736574202879290D0A20';
wwv_flow_api.g_varchar2_table(70) := '2020202020202020202020202020206D696E5A6F6F6D202020202020202020203A20302C20202020202020202F2F2068696465206966207A6F6F6D6564206F757420706173742074686973206C6576656C0D0A202020202020202020202020202020206D';
wwv_flow_api.g_varchar2_table(71) := '61785A6F6F6D202020202020202020203A2039392C202020202020202F2F2068696465206966207A6F6F6D656420696E20706173742074686973206C6576656C0D0A202020202020202020202020202020206F6E436C69636B48616E646C65722020203A';
wwv_flow_api.g_varchar2_table(72) := '206E756C6C2020202020202F2F2066756E6374696F6E20746F2063616C6C206966206F7665726C617920636C69636B656420286E756C6C20746F206D616B65206E6F7420636C69636B61626C65290D0A2020202020202020202020207D2C206F7074696F';
wwv_flow_api.g_varchar2_table(73) := '6E73293B0D0A2020202020202020766172206F7665726C6179203D206E6577204D61704F7665726C617928636F6E74656E742C206F7665726C61794F7074696F6E73293B0D0A20202020202020206F7665726C61792E7365744D617028746869732E6D61';
wwv_flow_api.g_varchar2_table(74) := '70293B0D0A202020202020202072657475726E206F7665726C61793B0D0A202020207D2C0D0A0D0A092F2A0D0A09202A0D0A09202A204D45535341474520504F5055500D0A09202A0D0A09202A2F0D0A2020202073686F774D6573736167653A2066756E';
wwv_flow_api.g_varchar2_table(75) := '6374696F6E20286D736729207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E73686F774D657373616765222C206D7367293B0D0A0D0A2020202020202020746869732E686964654D65737361676528293B0D0A0D0A20';
wwv_flow_api.g_varchar2_table(76) := '20202020202020746869732E6D7367446976203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0D0A0D0A2020202020202020766172206D6573736167655549203D20646F63756D656E742E637265617465456C656D656E';
wwv_flow_api.g_varchar2_table(77) := '74282764697627293B0D0A20202020202020206D65737361676555492E636C6173734E616D65203D20277265706F72746D61702D6D6573736167655549273B0D0A2020202020202020746869732E6D73674469762E617070656E644368696C64286D6573';
wwv_flow_api.g_varchar2_table(78) := '736167655549293B0D0A0D0A2020202020202020766172206D657373616765496E6E6572203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0D0A20202020202020206D657373616765496E6E65722E636C6173734E616D';
wwv_flow_api.g_varchar2_table(79) := '65203D20277265706F72746D61702D6D657373616765496E6E6572273B0D0A20202020202020206D657373616765496E6E65722E696E6E657248544D4C203D206D73673B0D0A20202020202020206D65737361676555492E617070656E644368696C6428';
wwv_flow_api.g_varchar2_table(80) := '6D657373616765496E6E6572293B0D0A0D0A2020202020202020746869732E6D73674469762E6164644576656E744C697374656E65722827636C69636B272C2066756E6374696F6E2829207B0D0A202020202020202020202020617065782E6465627567';
wwv_flow_api.g_varchar2_table(81) := '28226F6E20636C69636B202D2068696465206D65737361676522293B0D0A202020202020202020202020746869732E72656D6F766528293B0D0A20202020202020207D293B0D0A0D0A2020202020202020746869732E6D61702E636F6E74726F6C735B67';
wwv_flow_api.g_varchar2_table(82) := '6F6F676C652E6D6170732E436F6E74726F6C506F736974696F6E2E4C4546545F43454E5445525D2E7075736828746869732E6D7367446976293B0D0A202020202020202072657475726E20746869732E6D73674469763B0D0A202020207D2C0D0A0D0A20';
wwv_flow_api.g_varchar2_table(83) := '202020686964654D6573736167653A2066756E6374696F6E2829207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E686964654D65737361676522293B0D0A202020202020202069662028746869732E6D736744697629';
wwv_flow_api.g_varchar2_table(84) := '207B0D0A202020202020202020202020746869732E6D73674469762E72656D6F766528293B0D0A20202020202020207D0D0A202020207D2C0D0A0D0A092F2A0D0A09202A0D0A09202A205245504F52542050494E530D0A09202A0D0A09202A2F0D0A0D0A';
wwv_flow_api.g_varchar2_table(85) := '202020205F6576656E7450696E446174613A2066756E6374696F6E20286D61726B657229207B0D0A20202020202020202F2F6765742070696E206461746120666F722070617373696E6720746F20616E206576656E742068616E646C65720D0A20202020';
wwv_flow_api.g_varchar2_table(86) := '202020207661722064203D207B0D0A2020202020202020202020206D6170202020203A20746869732E6D61702C0D0A2020202020202020202020206C6174202020203A206D61726B65722E706F736974696F6E2E6C617428292C0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(87) := '202020206C6E67202020203A206D61726B65722E706F736974696F6E2E6C6E6728292C0D0A0909096D61726B6572203A206D61726B65720D0A20202020202020207D3B0D0A2020202020202020696620286D61726B65722E6F7665726C617926266D6172';
wwv_flow_api.g_varchar2_table(88) := '6B65722E6F7665726C61792E64697629207B0D0A202020202020202020202020642E696E666F446976203D206D61726B65722E6F7665726C61792E6469763B0D0A20202020202020207D0D0A2020202020202020242E657874656E6428642C206D61726B';
wwv_flow_api.g_varchar2_table(89) := '65722E64617461293B0D0A202020202020202072657475726E20643B0D0A202020207D2C0D0A0D0A202020205F756E657363617065496E666F3A2066756E6374696F6E28696E666F29207B0D0A09092F2F756E657363617065207468652068746D6C2066';
wwv_flow_api.g_varchar2_table(90) := '6F722074686520696E666F2077696E646F7720636F6E74656E74730D0A0909766172206874203D206E657720444F4D50617273657228292E706172736546726F6D537472696E6728696E666F2C2022746578742F68746D6C22293B0D0A09097265747572';
wwv_flow_api.g_varchar2_table(91) := '6E2068742E646F63756D656E74456C656D656E742E74657874436F6E74656E743B0D0A202020207D2C0D0A0D0A092F2F73686F772074686520696E666F2077696E646F7720666F7220612070696E3B207365742074686520636F6E74656E7420666F7220';
wwv_flow_api.g_varchar2_table(92) := '69740D0A0973686F77496E666F57696E646F773A2066756E6374696F6E20286D61726B657229207B0D0A0909617065782E646562756728227265706F72746D61702E73686F77496E666F57696E646F77222C206D61726B6572293B0D0A09092F2F73686F';
wwv_flow_api.g_varchar2_table(93) := '7720696E666F2077696E646F7720666F7220746869732070696E0D0A09096966202821746869732E696E666F57696E646F7729207B0D0A090909746869732E696E666F57696E646F77203D206E657720676F6F676C652E6D6170732E496E666F57696E64';
wwv_flow_api.g_varchar2_table(94) := '6F7728293B0D0A09097D0D0A0909746869732E696E666F57696E646F772E736574436F6E74656E7428746869732E5F756E657363617065496E666F286D61726B65722E646174612E696E666F29293B0D0A09092F2F6173736F6369617465207468652069';
wwv_flow_api.g_varchar2_table(95) := '6E666F2077696E646F77207769746820746865206D61726B657220616E642073686F77206F6E20746865206D61700D0A0909746869732E696E666F57696E646F772E6F70656E28746869732E6D61702C206D61726B6572293B0D0A202020202020202072';
wwv_flow_api.g_varchar2_table(96) := '657475726E20746869732E696E666F57696E646F773B0D0A097D2C0D0A0D0A202020202F2F706C6163652061207265706F72742070696E206F6E20746865206D61700D0A202020205F6E65774D61726B65723A2066756E6374696F6E202870696E446174';
wwv_flow_api.g_varchar2_table(97) := '6129207B0D0A2020202020202020766172205F74686973203D20746869732C0D0A2020202020202020202020206D61726B6572203D206E657720676F6F676C652E6D6170732E4D61726B6572287B0D0A20202020202020202020202020206D6170202020';
wwv_flow_api.g_varchar2_table(98) := '202020203A20746869732E6D61702C0D0A2020202020202020202020202020706F736974696F6E20203A206E657720676F6F676C652E6D6170732E4C61744C6E672870696E446174612E782C2070696E446174612E79292C0D0A20202020202020202020';
wwv_flow_api.g_varchar2_table(99) := '202020207469746C6520202020203A2070696E446174612E6E2C0D0A202020202020202020202020202069636F6E2020202020203A202870696E446174612E633F28746869732E6F7074696F6E732E69636F6E4261736550617468202B2070696E446174';
wwv_flow_api.g_varchar2_table(100) := '612E63293A6E756C6C292C0D0A20202020202020202020202020206C6162656C20202020203A2070696E446174612E6C2C0D0A2020202020202020202020202020647261676761626C65203A20746869732E6F7074696F6E732E6973447261676761626C';
wwv_flow_api.g_varchar2_table(101) := '650D0A2020202020202020202020207D293B0D0A0D0A20202020202020202F2F6C6F6164206F7572206F776E206461746120696E746F20746865206D61726B65720D0A20202020202020206D61726B65722E64617461203D207B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(102) := '2020202069642020203A2070696E446174612E642C0D0A202020202020202020202020696E666F203A2070696E446174612E692C0D0A2020202020202020202020206E616D65203A2070696E446174612E6E0D0A09097D3B0D0A2020202020202020666F';
wwv_flow_api.g_varchar2_table(103) := '7220287661722069203D20313B2069203C3D2031303B20692B2B29207B0D0A2020202020202020202020206966202870696E446174612E66262670696E446174612E665B2261222B695D29207B0D0A202020202020202020202020202020202F2F662E61';
wwv_flow_api.g_varchar2_table(104) := '312C20662E61322C202E2E2E20662E61313020636F6E76657274656420746F206D61726B65722E646174612E6174747230312C206D61726B65722E646174612E6174747230322C202E2E2E206D61726B65722E646174612E6174747231300D0A20202020';
wwv_flow_api.g_varchar2_table(105) := '2020202020202020202020206D61726B65722E646174615B2261747472222B282730272B69292E736C696365282D32295D203D2070696E446174612E665B2261222B695D3B0D0A2020202020202020202020207D0D0A20202020202020207D0D0A0D0A20';
wwv_flow_api.g_varchar2_table(106) := '202020202020206966202821746869732E6F7074696F6E732E73686F7750696E7329207B0D0A2020202020202020202020206D61726B65722E73657456697369626C652866616C7365293B0D0A20202020202020207D0D0A0D0A20202020202020202F2F';
wwv_flow_api.g_varchar2_table(107) := '69662061206D61726B657220666F726D617474696E672066756E6374696F6E20686173206265656E20737570706C6965642C2063616C6C2069740D0A202020202020202069662028746869732E6F7074696F6E732E6D61726B6572466F726D6174466E29';
wwv_flow_api.g_varchar2_table(108) := '207B0D0A202020202020202020202020746869732E6F7074696F6E732E6D61726B6572466F726D6174466E286D61726B6572293B0D0A20202020202020207D0D0A0D0A2020202020202020696620286D61726B65722E646174612E696E666F2026262074';
wwv_flow_api.g_varchar2_table(109) := '6869732E6F7074696F6E732E73686F77496E666F4C6179657229207B0D0A2020202020202020202020206D61726B65722E6F7665726C6179203D20746869732E6164644F7665726C617928746869732E5F756E657363617065496E666F286D61726B6572';
wwv_flow_api.g_varchar2_table(110) := '2E646174612E696E666F292C207B0D0A20202020202020202020202020202020706F732020202020202020202020203A206D61726B65722E706F736974696F6E2C0D0A202020202020202020202020202020206F6E436C69636B48616E646C6572203A20';
wwv_flow_api.g_varchar2_table(111) := '66756E6374696F6E202829207B0D0A2020202020202020202020202020202020202020617065782E64656275672822696E666F4C6179657220636C69636B6564222C206D61726B65722E646174612E6964293B0D0A202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(112) := '2020202020696620285F746869732E6F7074696F6E732E70616E4F6E436C69636B29207B0D0A2020202020202020202020202020202020202020202020205F746869732E6D61702E70616E546F286D61726B65722E706F736974696F6E293B0D0A202020';
wwv_flow_api.g_varchar2_table(113) := '20202020202020202020202020202020207D0D0A2020202020202020202020202020202020202020696620285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C29207B0D0A2020202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(114) := '205F746869732E6D61702E7365745A6F6F6D285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C293B0D0A20202020202020202020202020202020202020207D0D0A2020202020202020202020202020202020202020617065782E6A';
wwv_flow_api.g_varchar2_table(115) := '5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D61726B6572636C69636B222C205F746869732E5F6576656E7450696E44617461286D61726B657229293B0D0A202020202020202020202020';
wwv_flow_api.g_varchar2_table(116) := '202020207D0D0A2020202020202020202020207D293B0D0A20202020202020202020202069662028746869732E6F7074696F6E732E696E666F4C61796572466F726D6174466E29207B0D0A20202020202020202020202020202020746869732E6F707469';
wwv_flow_api.g_varchar2_table(117) := '6F6E732E696E666F4C61796572466F726D6174466E286D61726B65722E6F7665726C61792C206D61726B6572293B0D0A2020202020202020202020207D0D0A20202020202020207D0D0A0D0A2020202020202020676F6F676C652E6D6170732E6576656E';
wwv_flow_api.g_varchar2_table(118) := '742E6164644C697374656E6572286D61726B65722C0D0A20202020202020202020202028746869732E6F7074696F6E732E76697375616C69736174696F6E3D3D2273706964657266696572223F227370696465725F636C69636B223A22636C69636B2229';
wwv_flow_api.g_varchar2_table(119) := '2C0D0A20202020202020202020202066756E6374696F6E202829207B0D0A20202020202020202020202020202020617065782E646562756728226D61726B657220636C69636B6564222C206D61726B65722E646174612E6964293B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(120) := '20202020202020202076617220706F73203D20746869732E676574506F736974696F6E28293B0D0A20202020202020202020202020202020696620286D61726B65722E646174612E696E666F202626205F746869732E6F7074696F6E732E73686F77496E';
wwv_flow_api.g_varchar2_table(121) := '666F506F7075707329207B0D0A20202020202020202020202020202020202020205F746869732E73686F77496E666F57696E646F772874686973293B0D0A202020202020202020202020202020207D0D0A20202020202020202020202020202020696620';
wwv_flow_api.g_varchar2_table(122) := '285F746869732E6F7074696F6E732E70616E4F6E436C69636B29207B0D0A20202020202020202020202020202020202020205F746869732E6D61702E70616E546F28706F73293B0D0A202020202020202020202020202020207D0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(123) := '2020202020202020696620285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C29207B0D0A20202020202020202020202020202020202020205F746869732E6D61702E7365745A6F6F6D285F746869732E6F7074696F6E732E636C69';
wwv_flow_api.g_varchar2_table(124) := '636B5A6F6F6D4C6576656C293B0D0A202020202020202020202020202020207D0D0A20202020202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D';
wwv_flow_api.g_varchar2_table(125) := '61726B6572636C69636B222C205F746869732E5F6576656E7450696E44617461286D61726B657229293B0D0A2020202020202020202020207D293B0D0A0D0A2020202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572';
wwv_flow_api.g_varchar2_table(126) := '286D61726B65722C202264726167656E64222C2066756E6374696F6E202829207B0D0A20202020202020202020202076617220706F73203D20746869732E676574506F736974696F6E28293B0D0A202020202020202020202020617065782E6465627567';
wwv_flow_api.g_varchar2_table(127) := '28226D61726B6572206D6F766564222C206D61726B65722E646174612E69642C204A534F4E2E737472696E6769667928706F7329293B0D0A202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E7265';
wwv_flow_api.g_varchar2_table(128) := '67696F6E4964292E7472696767657228226D61726B657264726167222C205F746869732E5F6576656E7450696E44617461286D61726B657229293B0D0A20202020202020207D293B0D0A0D0A0909696620285B2270696E73222C22696E666F6C61796572';
wwv_flow_api.g_varchar2_table(129) := '222C22636C7573746572222C2273706964657266696572225D2E696E6465784F6628746869732E6F7074696F6E732E76697375616C69736174696F6E29203E202D3129207B0D0A0909092F2F20696620746865206D61726B657220776173206E6F742070';
wwv_flow_api.g_varchar2_table(130) := '726576696F75736C792073686F776E20696E20746865206C61737420726566726573682C20726169736520746865206D61726B6572206164646564206576656E740D0A0909096966202821746869732E69644D61707C7C21746869732E69644D61702E68';
wwv_flow_api.g_varchar2_table(131) := '6173286D61726B65722E646174612E69642929207B0D0A09090909617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D61726B65726164646564222C205F746869732E5F657665';
wwv_flow_api.g_varchar2_table(132) := '6E7450696E44617461286D61726B657229293B0D0A0909097D0D0A09097D0D0A202020202020202072657475726E206D61726B65723B0D0A202020207D2C0D0A0D0A202020202F2F20736574207570207468652053706964657266696572207669737561';
wwv_flow_api.g_varchar2_table(133) := '6C69736174696F6E0D0A202020205F73706964657266793A2066756E6374696F6E2829207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E5F737069646572667922293B0D0A20202020202020202F2F20726566657220';
wwv_flow_api.g_varchar2_table(134) := '746F3A2068747470733A2F2F6769746875622E636F6D2F6A61776A2F4F7665726C617070696E674D61726B6572537069646572666965720D0A0D0A2020202020202020766172205F74686973203D20746869732C0D0A2020202020202020202020206F70';
wwv_flow_api.g_varchar2_table(135) := '74203D207B0D0A202020202020202020202020202020206B65657053706964657266696564202020203A20747275652C0D0A202020202020202020202020202020206261736963466F726D61744576656E7473203A20747275652C0D0A20202020202020';
wwv_flow_api.g_varchar2_table(136) := '2020202020202020206D61726B657273576F6E744D6F76652020203A2021746869732E6F7074696F6E732E6973447261676761626C652C0D0A202020202020202020202020202020206D61726B657273576F6E74486964652020203A20747275650D0A20';
wwv_flow_api.g_varchar2_table(137) := '20202020202020202020207D3B0D0A0D0A20202020202020202F2F20616C6C6F772074686520646576656C6F70657220746F20736574202F206F76657272696465207370696465726679206F7074696F6E730D0A2020202020202020242E657874656E64';
wwv_flow_api.g_varchar2_table(138) := '286F70742C20746869732E6F7074696F6E732E73706964657266696572293B0D0A0D0A2020202020202020746869732E6F6D73203D206E6577204F7665726C617070696E674D61726B65725370696465726669657228746869732E6D61702C206F707429';
wwv_flow_api.g_varchar2_table(139) := '3B0D0A0D0A20202020202020202F2F20666F726D617420746865206D61726B657273207573696E67207468652070726F766964656420666F726D61742066756E6374696F6E20286F7074696F6E732E7370696465726679466F726D6174466E292C0D0A20';
wwv_flow_api.g_varchar2_table(140) := '202020202020202F2F206F72206966206E6F74207370656369666965642C2070726F7669646520612064656661756C742066756E6374696F6E0D0A2020202020202020746869732E6F6D732E6164644C697374656E65722827666F726D6174272C0D0A20';
wwv_flow_api.g_varchar2_table(141) := '2020202020202020202020746869732E6F7074696F6E732E7370696465726679466F726D6174466E0D0A2020202020202020202020207C7C202066756E6374696F6E286D61726B65722C2073746174757329207B0D0A2020202020202020202020202020';
wwv_flow_api.g_varchar2_table(142) := '2020202020202F2F206966206261736963466F726D61744576656E7473203D20747275652C207374617475732077696C6C20626520535049444552464945442C20535049444552464941424C452C206F7220554E535049444552464941424C450D0A2020';
wwv_flow_api.g_varchar2_table(143) := '2020202020202020202020202020202020202F2F206966206261736963466F726D61744576656E7473203D2066616C73652C207374617475732077696C6C2062652053504944455246494544206F7220554E535049444552464945440D0A202020202020';
wwv_flow_api.g_varchar2_table(144) := '20202020202020202020202020207661722069636F6E55524C203D205F746869732E5F67657457696E646F77506174682829202B20222F22202B205F746869732E6F7074696F6E732E706C7567696E46696C65507265666978202B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(145) := '202020202020202020202020202020202028737461747573203D3D204F7665726C617070696E674D61726B6572537069646572666965722E6D61726B65725374617475732E53504944455246494544203F0D0A2020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(146) := '20202020202020202020202020202020202027696D616765732F73706F746C696768742D776179706F696E742D626C75652E706E6727203A0D0A20202020202020202020202020202020202020202020202020737461747573203D3D204F7665726C6170';
wwv_flow_api.g_varchar2_table(147) := '70696E674D61726B6572537069646572666965722E6D61726B65725374617475732E535049444552464941424C45203F0D0A202020202020202020202020202020202020202020202020202020202020202020202027696D616765732F73706F746C6967';
wwv_flow_api.g_varchar2_table(148) := '68742D776179706F696E742D612E706E6727203A0D0A202020202020202020202020202020202020202020202020202020202020202020202027696D616765732F73706F746C696768742D706F692E706E6727293B0D0A20202020202020202020202020';
wwv_flow_api.g_varchar2_table(149) := '202020202020202F2F617065782E6465627567282273706964657266792E666F726D6174222C206D61726B65722C207374617475732C2069636F6E55524C293B0D0A20202020202020202020202020202020202020206D61726B65722E73657449636F6E';
wwv_flow_api.g_varchar2_table(150) := '287B75726C3A2069636F6E55524C7D293B0D0A202020202020202020202020202020207D293B0D0A0D0A20202020202020202F2F20726567697374657220746865206D61726B657273207769746820746865204F7665726C617070696E674D61726B6572';
wwv_flow_api.g_varchar2_table(151) := '537069646572666965720D0A2020202020202020666F7220287661722069203D20303B2069203C20746869732E6D61726B6572732E6C656E6774683B20692B2B29207B0D0A202020202020202020202020746869732E6F6D732E6164644D61726B657228';
wwv_flow_api.g_varchar2_table(152) := '746869732E6D61726B6572735B695D293B0D0A20202020202020207D0D0A0D0A2020202020202020746869732E6F6D732E6164644C697374656E657228277370696465726679272C2066756E6374696F6E286D61726B65727329207B0D0A202020202020';
wwv_flow_api.g_varchar2_table(153) := '202020202020617065782E646562756728227370696465726679222C206D61726B657273293B0D0A090909617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228227370696465726679';
wwv_flow_api.g_varchar2_table(154) := '222C207B206D61703A5F746869732E6D61702C206D61726B6572733A6D61726B657273207D293B0D0A20202020202020207D293B0D0A0D0A2020202020202020746869732E6F6D732E6164644C697374656E65722827756E7370696465726679272C2066';
wwv_flow_api.g_varchar2_table(155) := '756E6374696F6E286D61726B65727329207B0D0A202020202020202020202020617065782E64656275672822756E7370696465726679222C206D61726B657273293B0D0A090909617065782E6A5175657279282223222B5F746869732E6F7074696F6E73';
wwv_flow_api.g_varchar2_table(156) := '2E726567696F6E4964292E747269676765722822756E7370696465726679222C207B206D61703A5F746869732E6D61702C206D61726B6572733A6D61726B657273207D293B0D0A20202020202020207D293B0D0A0D0A202020202020202072657475726E';
wwv_flow_api.g_varchar2_table(157) := '20746869732E6F6D733B0D0A202020207D2C0D0A0D0A202020205F72656D6F76654D61726B6572733A2066756E6374696F6E2829207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E5F72656D6F76654D61726B657273';
wwv_flow_api.g_varchar2_table(158) := '22293B0D0A2020202020202020746869732E746F74616C526F7773203D20303B0D0A202020202020202069662028746869732E626F756E647329207B20746869732E626F756E64732E64656C6574653B207D0D0A20202020202020206966202874686973';
wwv_flow_api.g_varchar2_table(159) := '2E6D61726B65727329207B0D0A202020202020202020202020666F7220287661722069203D20303B2069203C20746869732E6D61726B6572732E6C656E6774683B20692B2B29207B0D0A20202020202020202020202020202020746869732E6D61726B65';
wwv_flow_api.g_varchar2_table(160) := '72735B695D2E7365744D6170286E756C6C293B0D0A2020202020202020202020207D0D0A202020202020202020202020746869732E6D61726B6572732E64656C6574653B0D0A20202020202020207D0D0A202020207D2C0D0A0D0A202020202F2F63616C';
wwv_flow_api.g_varchar2_table(161) := '6C207468697320746F2073696D756C6174652061206D6F75736520636C69636B206F6E20746865206D61726B657220666F722074686520676976656E2069642076616C75650D0A202020202F2F652E672E20746869732077696C6C2073686F7720746865';
wwv_flow_api.g_varchar2_table(162) := '20696E666F2077696E646F7720666F722074686520676976656E206D61726B657220616E64207472696767657220746865206D61726B6572636C69636B206576656E740D0A20202020636C69636B3A2066756E6374696F6E2028696429207B0D0A202020';
wwv_flow_api.g_varchar2_table(163) := '2020202020617065782E646562756728227265706F72746D61702E636C69636B22293B0D0A2020202020202020766172206D61726B6572203D20746869732E6D61726B6572732E66696E64282066756E6374696F6E2870297B2072657475726E20702E64';
wwv_flow_api.g_varchar2_table(164) := '6174612E69643D3D69643B207D293B0D0A2020202020202020696620286D61726B657229207B0D0A2020202020202020202020206E657720676F6F676C652E6D6170732E6576656E742E74726967676572286D61726B65722C22636C69636B22293B0D0A';
wwv_flow_api.g_varchar2_table(165) := '20202020202020207D20656C7365207B0D0A202020202020202020202020617065782E646562756728226964206E6F7420666F756E64222C206964293B0D0A20202020202020207D0D0A202020202020202072657475726E206D61726B65723B0D0A2020';
wwv_flow_api.g_varchar2_table(166) := '20207D2C0D0A0D0A092F2A0D0A09202A0D0A09202A20555345522050494E0D0A09202A0D0A09202A2F0D0A0D0A202020202F2F706C616365206F72206D6F76652074686520757365722070696E20746F2074686520676976656E206C6F636174696F6E0D';
wwv_flow_api.g_varchar2_table(167) := '0A20202020676F746F506F733A2066756E6374696F6E20286C61742C6C6E6729207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E676F746F506F73222C6C61742C6C6E67293B0D0A2020202020202020696620286C61';
wwv_flow_api.g_varchar2_table(168) := '74213D3D6E756C6C202626206C6E67213D3D6E756C6C29207B0D0A202020202020202020202020766172206F6C64706F73203D20746869732E7573657270696E3F746869732E7573657270696E2E676574506F736974696F6E28293A286E657720676F6F';
wwv_flow_api.g_varchar2_table(169) := '676C652E6D6170732E4C61744C6E6728302C3029293B0D0A202020202020202020202020696620286F6C64706F73202626206C61743D3D6F6C64706F732E6C61742829202626206C6E673D3D6F6C64706F732E6C6E67282929207B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(170) := '202020202020202020617065782E646562756728227573657270696E206E6F74206368616E67656422293B0D0A2020202020202020202020207D20656C7365207B0D0A2020202020202020202020202020202076617220706F73203D206E657720676F6F';
wwv_flow_api.g_varchar2_table(171) := '676C652E6D6170732E4C61744C6E67286C61742C6C6E67293B0D0A2020202020202020202020202020202069662028746869732E7573657270696E29207B0D0A2020202020202020202020202020202020202020617065782E646562756728226D6F7665';
wwv_flow_api.g_varchar2_table(172) := '206578697374696E672070696E20746F206E657720706F736974696F6E206F6E206D6170222C706F73293B0D0A2020202020202020202020202020202020202020746869732E7573657270696E2E7365744D617028746869732E6D6170293B0D0A202020';
wwv_flow_api.g_varchar2_table(173) := '2020202020202020202020202020202020746869732E7573657270696E2E736574506F736974696F6E28706F73293B0D0A202020202020202020202020202020207D20656C7365207B0D0A2020202020202020202020202020202020202020617065782E';
wwv_flow_api.g_varchar2_table(174) := '64656275672822637265617465207573657270696E222C706F73293B0D0A2020202020202020202020202020202020202020746869732E7573657270696E203D206E657720676F6F676C652E6D6170732E4D61726B6572287B0D0A202020202020202020';
wwv_flow_api.g_varchar2_table(175) := '2020202020202020202020202020206D6170202020202020203A20746869732E6D61702C0D0A202020202020202020202020202020202020202020202020706F736974696F6E20203A20706F732C0D0A2020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(176) := '20202020647261676761626C65203A20746869732E6F7074696F6E732E6973447261676761626C650D0A20202020202020202020202020202020202020207D293B0D0A2020202020202020202020202020202020202020766172205F74686973203D2074';
wwv_flow_api.g_varchar2_table(177) := '6869733B0D0A2020202020202020202020202020202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228746869732E7573657270696E2C202264726167656E64222C2066756E6374696F6E202829207B0D0A20202020';
wwv_flow_api.g_varchar2_table(178) := '202020202020202020202020202020202020202076617220706F73203D20746869732E676574506F736974696F6E28293B0D0A202020202020202020202020202020202020202020202020617065782E646562756728227573657270696E206D6F766564';
wwv_flow_api.g_varchar2_table(179) := '222C204A534F4E2E737472696E6769667928706F7329293B0D0A202020202020202020202020202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D';
wwv_flow_api.g_varchar2_table(180) := '61726B657264726167222C7B0D0A202020202020202020202020202020202020202020202020202020206D6170202020203A205F746869732E6D61702C0D0A202020202020202020202020202020202020202020202020202020206C6174202020203A20';
wwv_flow_api.g_varchar2_table(181) := '706F732E6C617428292C0D0A202020202020202020202020202020202020202020202020202020206C6E67202020203A20706F732E6C6E6728292C0D0A202020202020202020202020202020202020202020202020202020206D61726B6572203A207468';
wwv_flow_api.g_varchar2_table(182) := '69730D0A2020202020202020202020202020202020202020202020207D290D0A20202020202020202020202020202020202020207D293B0D0A202020202020202020202020202020207D0D0A2020202020202020202020207D0D0A20202020202020207D';
wwv_flow_api.g_varchar2_table(183) := '20656C73652069662028746869732E7573657270696E29207B0D0A202020202020202020202020617065782E646562756728226D6F7665206578697374696E672070696E206F666620746865206D617022293B0D0A202020202020202020202020746869';
wwv_flow_api.g_varchar2_table(184) := '732E7573657270696E2E7365744D6170286E756C6C293B0D0A20202020202020207D0D0A202020207D2C0D0A0D0A202020202F2F70617273652074686520676976656E20737472696E672061732061206C61742C6C6F6E6720706169722C207075742061';
wwv_flow_api.g_varchar2_table(185) := '2070696E2061742074686174206C6F636174696F6E0D0A20202020676F746F506F734279537472696E673A2066756E6374696F6E20287629207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E676F746F506F73427953';
wwv_flow_api.g_varchar2_table(186) := '7472696E67222C2076293B0D0A2020202020202020766172206C61746C6E67203D20746869732E70617273654C61744C6E672876293B0D0A2020202020202020696620286C61746C6E6729207B0D0A202020202020202020202020746869732E676F746F';
wwv_flow_api.g_varchar2_table(187) := '506F73286C61746C6E672E6C617428292C6C61746C6E672E6C6E672829293B0D0A20202020202020207D0D0A202020202020202072657475726E206C61746C6E673B0D0A202020207D2C0D0A0D0A202020202F2F706C616365206F72206D6F7665207468';
wwv_flow_api.g_varchar2_table(188) := '6520757365722070696E20746F2074686520676976656E206C6F636174696F6E0D0A2020202070616E546F3A2066756E6374696F6E20286C61742C6C6E6729207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E70616E';
wwv_flow_api.g_varchar2_table(189) := '546F222C6C61742C6C6E67293B0D0A202020202020202076617220706F733B0D0A2020202020202020696620286C6174213D3D6E756C6C202626206C6E67213D3D6E756C6C29207B0D0A202020202020202020202020706F73203D206E657720676F6F67';
wwv_flow_api.g_varchar2_table(190) := '6C652E6D6170732E4C61744C6E67286C61742C6C6E67293B0D0A202020202020202020202020746869732E6D61702E70616E546F28706F73293B0D0A20202020202020207D0D0A202020202020202072657475726E20706F733B0D0A202020207D2C0D0A';
wwv_flow_api.g_varchar2_table(191) := '0D0A202020202F2F70617273652074686520676976656E20737472696E672061732061206C61742C6C6F6E6720706169722C2070616E20746F2074686174206C6F636174696F6E0D0A2020202070616E546F4279537472696E673A2066756E6374696F6E';
wwv_flow_api.g_varchar2_table(192) := '20287629207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E70616E546F4279537472696E67222C2076293B0D0A2020202020202020766172206C61746C6E67203D20746869732E70617273654C61744C6E672876293B';
wwv_flow_api.g_varchar2_table(193) := '0D0A2020202020202020696620286C61746C6E6729207B0D0A202020202020202020202020746869732E70616E546F286C61746C6E672E6C617428292C6C61746C6E672E6C6E672829293B0D0A20202020202020207D0D0A202020202020202072657475';
wwv_flow_api.g_varchar2_table(194) := '726E206C61746C6E673B0D0A202020207D2C0D0A0D0A202020202F2F70616E2F7A6F6F6D20746865206D617020746F2074686520676976656E20626F756E64730D0A20202020666974426F756E64733A2066756E6374696F6E20287629207B0D0A202020';
wwv_flow_api.g_varchar2_table(195) := '2020202020617065782E646562756728227265706F72746D61702E666974426F756E6473222C2076293B0D0A202020202020202076617220626F756E64733B0D0A2020202020202020696620287620213D3D206E756C6C202626207620213D3D20756E64';
wwv_flow_api.g_varchar2_table(196) := '6566696E656429207B0D0A20202020202020202020202069662028762E6861734F776E50726F706572747928226561737422292626762E6861734F776E50726F706572747928226E6F72746822292626762E6861734F776E50726F70657274792822736F';
wwv_flow_api.g_varchar2_table(197) := '75746822292626762E6861734F776E50726F7065727479282277657374222929207B0D0A202020202020202020202020202020202F2F20706172736520617320676F6F676C652E6D6170732E4C61744C6E67426F756E64734C69746572616C0D0A202020';
wwv_flow_api.g_varchar2_table(198) := '20202020202020202020202020626F756E6473203D206E657720676F6F676C652E6D6170732E4C61744C6E67426F756E64734C69746572616C2876293B0D0A2020202020202020202020207D20656C7365207B0D0A202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(199) := '20626F756E6473203D204A534F4E2E70617273652876293B0D0A2020202020202020202020207D0D0A0D0A20202020202020202020202069662028626F756E647329207B0D0A20202020202020202020202020202020746869732E6D61702E666974426F';
wwv_flow_api.g_varchar2_table(200) := '756E647328626F756E6473293B0D0A2020202020202020202020207D0D0A20202020202020207D0D0A202020202020202072657475726E20626F756E64733B0D0A202020207D2C0D0A0D0A092F2A0D0A09202A0D0A09202A2047454F434F44494E470D0A';
wwv_flow_api.g_varchar2_table(201) := '09202A0D0A09202A2F0D0A0D0A202020202F2F73656172636820746865206D617020666F7220616E20616464726573733B20696620666F756E642C2070757420612070696E2061742074686174206C6F636174696F6E20616E6420726169736520616464';
wwv_flow_api.g_varchar2_table(202) := '72657373666F756E6420747269676765720D0A20202020676F746F416464726573733A2066756E6374696F6E2028616464726573735465787429207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E676F746F41646472';
wwv_flow_api.g_varchar2_table(203) := '657373222C206164647265737354657874293B0D0A20202020202020207661722067656F636F646572203D206E657720676F6F676C652E6D6170732E47656F636F6465723B0D0A2020202020202020746869732E686964654D65737361676528293B0D0A';
wwv_flow_api.g_varchar2_table(204) := '2020202020202020766172205F74686973203D20746869733B0D0A202020202020202067656F636F6465722E67656F636F6465287B0D0A202020202020202020202020616464726573732020202020202020202020202020203A20616464726573735465';
wwv_flow_api.g_varchar2_table(205) := '78742C0D0A202020202020202020202020636F6D706F6E656E745265737472696374696F6E73203A205F746869732E6F7074696F6E732E7265737472696374436F756E747279213D3D22223F7B636F756E7472793A5F746869732E6F7074696F6E732E72';
wwv_flow_api.g_varchar2_table(206) := '65737472696374436F756E7472797D3A7B7D0D0A20202020202020207D2C2066756E6374696F6E28726573756C74732C2073746174757329207B0D0A20202020202020202020202069662028737461747573203D3D3D20676F6F676C652E6D6170732E47';
wwv_flow_api.g_varchar2_table(207) := '656F636F6465725374617475732E4F4B29207B0D0A2020202020202020202020202020202076617220706F73203D20726573756C74735B305D2E67656F6D657472792E6C6F636174696F6E3B0D0A20202020202020202020202020202020617065782E64';
wwv_flow_api.g_varchar2_table(208) := '65627567282267656F636F6465206F6B222C20706F73293B0D0A202020202020202020202020202020205F746869732E6D61702E73657443656E74657228706F73293B0D0A202020202020202020202020202020205F746869732E6D61702E70616E546F';
wwv_flow_api.g_varchar2_table(209) := '28706F73293B0D0A20202020202020202020202020202020696620285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C29207B0D0A20202020202020202020202020202020202020205F746869732E6D61702E7365745A6F6F6D285F';
wwv_flow_api.g_varchar2_table(210) := '746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C293B0D0A202020202020202020202020202020207D0D0A202020202020202020202020202020205F746869732E676F746F506F7328706F732E6C617428292C20706F732E6C6E672829';
wwv_flow_api.g_varchar2_table(211) := '293B0D0A20202020202020202020202020202020617065782E6465627567282261646472657373666F756E64222C20726573756C7473293B0D0A20202020202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F707469';
wwv_flow_api.g_varchar2_table(212) := '6F6E732E726567696F6E4964292E74726967676572282261646472657373666F756E64222C207B0D0A20202020202020202020202020202020202020206D6170202020203A205F746869732E6D61702C0D0A202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(213) := '20206C6174202020203A20706F732E6C617428292C0D0A20202020202020202020202020202020202020206C6E67202020203A20706F732E6C6E6728292C0D0A2020202020202020202020202020202020202020726573756C74203A20726573756C7473';
wwv_flow_api.g_varchar2_table(214) := '5B305D0D0A202020202020202020202020202020207D293B0D0A2020202020202020202020207D20656C73652069662028737461747573203D3D3D20676F6F676C652E6D6170732E47656F636F6465725374617475732E5A45524F5F524553554C545329';
wwv_flow_api.g_varchar2_table(215) := '207B0D0A20202020202020202020202020202020617065782E64656275672822676574416464726573734279506F733A205A45524F5F524553554C545322293B0D0A202020202020202020202020202020205F746869732E73686F774D65737361676528';
wwv_flow_api.g_varchar2_table(216) := '5F746869732E6F7074696F6E732E6E6F41646472657373526573756C7473293B0D0A2020202020202020202020207D20656C7365207B0D0A20202020202020202020202020202020617065782E6465627567282247656F636F646572206661696C656422';
wwv_flow_api.g_varchar2_table(217) := '2C20737461747573293B0D0A2020202020202020202020207D0D0A20202020202020207D293B0D0A202020207D2C0D0A0D0A202020202F2F6765742074686520636C6F73657374206164647265737320746F206120676976656E206C6F636174696F6E20';
wwv_flow_api.g_varchar2_table(218) := '6279206C61742F6C6F6E670D0A20202020676574416464726573734279506F733A2066756E6374696F6E20286C61742C6C6E6729207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E676574416464726573734279506F';
wwv_flow_api.g_varchar2_table(219) := '73222C206C61742C6C6E67293B0D0A20202020202020207661722067656F636F646572203D206E657720676F6F676C652E6D6170732E47656F636F6465723B0D0A2020202020202020746869732E686964654D65737361676528293B0D0A202020202020';
wwv_flow_api.g_varchar2_table(220) := '2020766172205F74686973203D20746869733B0D0A202020202020202067656F636F6465722E67656F636F6465287B276C6F636174696F6E273A207B6C61743A206C61742C206C6E673A206C6E677D7D2C2066756E6374696F6E28726573756C74732C20';
wwv_flow_api.g_varchar2_table(221) := '73746174757329207B0D0A20202020202020202020202069662028737461747573203D3D3D20676F6F676C652E6D6170732E47656F636F6465725374617475732E4F4B29207B0D0A2020202020202020202020202020202069662028726573756C74735B';
wwv_flow_api.g_varchar2_table(222) := '305D29207B0D0A202020202020202020202020202020202020617065782E6465627567282261646472657373666F756E64222C20726573756C7473293B0D0A202020202020202020202020202020202020617065782E6A5175657279282223222B5F7468';
wwv_flow_api.g_varchar2_table(223) := '69732E6F7074696F6E732E726567696F6E4964292E74726967676572282261646472657373666F756E64222C207B0D0A202020202020202020202020202020202020202020206D6170202020203A205F746869732E6D61702C0D0A202020202020202020';
wwv_flow_api.g_varchar2_table(224) := '202020202020202020202020206C6174202020203A206C61742C0D0A202020202020202020202020202020202020202020206C6E67202020203A206C6E672C0D0A20202020202020202020202020202020202020202020726573756C74203A2072657375';
wwv_flow_api.g_varchar2_table(225) := '6C74735B305D0D0A2020202020202020202020202020202020207D293B0D0A202020202020202020202020202020207D20656C7365207B0D0A2020202020202020202020202020202020202020617065782E646562756728226765744164647265737342';
wwv_flow_api.g_varchar2_table(226) := '79506F733A204E6F20726573756C74732072657475726E656422293B0D0A20202020202020202020202020202020202020205F746869732E73686F774D657373616765285F746869732E6F7074696F6E732E6E6F41646472657373526573756C7473293B';
wwv_flow_api.g_varchar2_table(227) := '0D0A202020202020202020202020202020207D0D0A2020202020202020202020207D20656C73652069662028737461747573203D3D3D20676F6F676C652E6D6170732E47656F636F6465725374617475732E5A45524F5F524553554C545329207B0D0A20';
wwv_flow_api.g_varchar2_table(228) := '202020202020202020202020202020617065782E64656275672822676574416464726573734279506F733A205A45524F5F524553554C545322293B0D0A202020202020202020202020202020205F746869732E73686F774D657373616765285F74686973';
wwv_flow_api.g_varchar2_table(229) := '2E6F7074696F6E732E6E6F41646472657373526573756C7473293B0D0A2020202020202020202020207D20656C7365207B0D0A20202020202020202020202020202020617065782E6465627567282247656F636F646572206661696C6564222C20737461';
wwv_flow_api.g_varchar2_table(230) := '747573293B0D0A2020202020202020202020207D0D0A20202020202020207D293B0D0A202020207D2C0D0A0D0A202020202F2F73656172636820666F72207468652075736572206465766963652773206C6F636174696F6E20696620706F737369626C65';
wwv_flow_api.g_varchar2_table(231) := '0D0A2020202067656F6C6F636174653A2066756E6374696F6E202829207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E67656F6C6F6361746522293B0D0A2020202020202020696620286E6176696761746F722E6765';
wwv_flow_api.g_varchar2_table(232) := '6F6C6F636174696F6E29207B0D0A202020202020202020202020766172205F74686973203D20746869733B0D0A2020202020202020202020206E6176696761746F722E67656F6C6F636174696F6E2E67657443757272656E74506F736974696F6E286675';
wwv_flow_api.g_varchar2_table(233) := '6E6374696F6E28706F736974696F6E29207B0D0A2020202020202020202020202020202076617220706F73203D207B0D0A20202020202020202020202020202020202020206C6174203A20706F736974696F6E2E636F6F7264732E6C617469747564652C';
wwv_flow_api.g_varchar2_table(234) := '0D0A20202020202020202020202020202020202020206C6E67203A20706F736974696F6E2E636F6F7264732E6C6F6E6769747564650D0A202020202020202020202020202020207D3B0D0A202020202020202020202020202020205F746869732E6D6170';
wwv_flow_api.g_varchar2_table(235) := '2E70616E546F28706F73293B0D0A20202020202020202020202020202020696620285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C29207B0D0A20202020202020202020202020202020202020205F746869732E6D61702E736574';
wwv_flow_api.g_varchar2_table(236) := '5A6F6F6D285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C293B0D0A202020202020202020202020202020207D0D0A20202020202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E';
wwv_flow_api.g_varchar2_table(237) := '732E726567696F6E4964292E74726967676572282267656F6C6F63617465222C207B6D61703A5F746869732E6D61702C206C61743A706F732E6C61742C206C6E673A706F732E6C6E677D293B0D0A2020202020202020202020207D293B0D0A2020202020';
wwv_flow_api.g_varchar2_table(238) := '2020207D20656C7365207B0D0A202020202020202020202020617065782E6465627567282262726F7773657220646F6573206E6F7420737570706F72742067656F6C6F636174696F6E22293B0D0A20202020202020207D0D0A202020207D2C0D0A0D0A09';
wwv_flow_api.g_varchar2_table(239) := '2F2A0D0A09202A0D0A09202A20444952454354494F4E530D0A09202A0D0A09202A2F0D0A0D0A09202F2F746869732069732063616C6C6564207768656E20646972656374696F6E7320617265207265717565737465640D0A202020205F64697265637469';
wwv_flow_api.g_varchar2_table(240) := '6F6E73526573706F6E73653A2066756E6374696F6E2028726573706F6E73652C73746174757329207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E5F646972656374696F6E73526573706F6E7365222C726573706F6E';
wwv_flow_api.g_varchar2_table(241) := '73652C737461747573293B0D0A20202020202020207377697463682873746174757329207B0D0A20202020202020206361736520676F6F676C652E6D6170732E446972656374696F6E735374617475732E4F4B3A0D0A2020202020202020202020207468';
wwv_flow_api.g_varchar2_table(242) := '69732E646972656374696F6E73446973706C61792E736574446972656374696F6E7328726573706F6E7365293B0D0A20202020202020202020202076617220746F74616C44697374616E6365203D20302C20746F74616C4475726174696F6E203D20302C';
wwv_flow_api.g_varchar2_table(243) := '206C6567436F756E74203D20302C20756E697473203D20226D6574657273223B0D0A202020202020202020202020666F72202876617220693D303B2069203C20726573706F6E73652E726F757465732E6C656E6774683B20692B2B29207B0D0A20202020';
wwv_flow_api.g_varchar2_table(244) := '2020202020202020202020206C6567436F756E74203D206C6567436F756E74202B20726573706F6E73652E726F757465735B695D2E6C6567732E6C656E6774683B0D0A20202020202020202020202020202020666F722028766172206A3D303B206A203C';
wwv_flow_api.g_varchar2_table(245) := '20726573706F6E73652E726F757465735B695D2E6C6567732E6C656E6774683B206A2B2B29207B0D0A2020202020202020202020202020202020202020766172206C6567203D20726573706F6E73652E726F757465735B695D2E6C6567735B6A5D3B0D0A';
wwv_flow_api.g_varchar2_table(246) := '2020202020202020202020202020202020202020746F74616C44697374616E6365203D20746F74616C44697374616E6365202B206C65672E64697374616E63652E76616C75653B0D0A2020202020202020202020202020202020202020746F74616C4475';
wwv_flow_api.g_varchar2_table(247) := '726174696F6E203D20746F74616C4475726174696F6E202B206C65672E6475726174696F6E2E76616C75653B0D0A202020202020202020202020202020207D0D0A2020202020202020202020207D0D0A2020202020202020202020206966202874686973';
wwv_flow_api.g_varchar2_table(248) := '2E6F7074696F6E732E756E697453797374656D203D3D3D2022494D50455249414C2229207B0D0A202020202020202020202020202020202F2F636F6E76657274206D657465727320746F206D696C65730D0A20202020202020202020202020202020746F';
wwv_flow_api.g_varchar2_table(249) := '74616C44697374616E6365202A3D20302E30303036323133373131393232343B0D0A20202020202020202020202020202020756E697473203D20226D696C6573223B0D0A2020202020202020202020207D0D0A202020202020202020202020766172205F';
wwv_flow_api.g_varchar2_table(250) := '74686973203D20746869733B0D0A202020202020202020202020617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E747269676765722822646972656374696F6E73222C7B0D0A2020202020202020202020';
wwv_flow_api.g_varchar2_table(251) := '20202020206D617020202020202020203A205F746869732E6D61702C0D0A2020202020202020202020202020202064697374616E63652020203A20746F74616C44697374616E63652C0D0A20202020202020202020202020202020756E69747320202020';
wwv_flow_api.g_varchar2_table(252) := '20203A20756E6974732C0D0A202020202020202020202020202020206475726174696F6E2020203A20746F74616C4475726174696F6E2C0D0A202020202020202020202020202020206C656773202020202020203A206C6567436F756E742C0D0A202020';
wwv_flow_api.g_varchar2_table(253) := '20202020202020202020202020646972656374696F6E73203A20726573706F6E73650D0A2020202020202020202020207D293B0D0A202020202020202020202020627265616B3B0D0A20202020202020206361736520676F6F676C652E6D6170732E4469';
wwv_flow_api.g_varchar2_table(254) := '72656374696F6E735374617475732E4E4F545F464F554E443A0D0A202020202020202020202020746869732E73686F774D65737361676528746869732E6F7074696F6E732E646972656374696F6E734E6F74466F756E64293B0D0A202020202020202020';
wwv_flow_api.g_varchar2_table(255) := '202020627265616B3B0D0A20202020202020206361736520676F6F676C652E6D6170732E446972656374696F6E735374617475732E5A45524F5F524553554C54533A0D0A202020202020202020202020746869732E73686F774D65737361676528746869';
wwv_flow_api.g_varchar2_table(256) := '732E6F7074696F6E732E646972656374696F6E735A65726F526573756C7473293B0D0A202020202020202020202020627265616B3B0D0A202020202020202064656661756C743A0D0A202020202020202020202020617065782E64656275672822446972';
wwv_flow_api.g_varchar2_table(257) := '656374696F6E732072657175657374206661696C6564222C20737461747573293B0D0A20202020202020207D0D0A202020207D2C0D0A0D0A202020202F2F73686F772073696D706C6520726F757465206265747765656E2074776F20706F696E74730D0A';
wwv_flow_api.g_varchar2_table(258) := '2020202073686F77446972656374696F6E733A2066756E6374696F6E20286F726967696E2C2064657374696E6174696F6E2C2074726176656C4D6F646529207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E73686F77';
wwv_flow_api.g_varchar2_table(259) := '446972656374696F6E73222C206F726967696E2C2064657374696E6174696F6E2C2074726176656C4D6F6465293B0D0A2020202020202020746869732E6F726967696E203D206F726967696E3B0D0A2020202020202020746869732E64657374696E6174';
wwv_flow_api.g_varchar2_table(260) := '696F6E203D2064657374696E6174696F6E3B0D0A2020202020202020746869732E686964654D65737361676528293B0D0A202020202020202069662028746869732E6F726967696E2626746869732E64657374696E6174696F6E29207B0D0A2020202020';
wwv_flow_api.g_varchar2_table(261) := '202020202020206966202821746869732E646972656374696F6E73446973706C617929207B0D0A20202020202020202020202020202020746869732E646972656374696F6E73446973706C6179203D206E657720676F6F676C652E6D6170732E44697265';
wwv_flow_api.g_varchar2_table(262) := '6374696F6E7352656E64657265723B0D0A20202020202020202020202020202020746869732E646972656374696F6E7353657276696365203D206E657720676F6F676C652E6D6170732E446972656374696F6E73536572766963653B0D0A202020202020';
wwv_flow_api.g_varchar2_table(263) := '20202020202020202020746869732E646972656374696F6E73446973706C61792E7365744D617028746869732E6D6170293B0D0A2020202020202020202020202020202069662028746869732E6F7074696F6E732E646972656374696F6E7350616E656C';
wwv_flow_api.g_varchar2_table(264) := '29207B0D0A2020202020202020202020202020202020202020746869732E646972656374696F6E73446973706C61792E73657450616E656C28646F63756D656E742E676574456C656D656E744279496428746869732E6F7074696F6E732E646972656374';
wwv_flow_api.g_varchar2_table(265) := '696F6E7350616E656C29293B0D0A202020202020202020202020202020207D0D0A2020202020202020202020207D0D0A2020202020202020202020202F2F73696D706C6520646972656374696F6E73206265747765656E2074776F206C6F636174696F6E';
wwv_flow_api.g_varchar2_table(266) := '730D0A202020202020202020202020746869732E6F726967696E203D20746869732E70617273654C61744C6E6728746869732E6F726967696E297C7C746869732E6F726967696E3B0D0A202020202020202020202020746869732E64657374696E617469';
wwv_flow_api.g_varchar2_table(267) := '6F6E203D20746869732E70617273654C61744C6E6728746869732E64657374696E6174696F6E297C7C746869732E64657374696E6174696F6E3B0D0A20202020202020202020202069662028746869732E6F726967696E20213D3D202222202626207468';
wwv_flow_api.g_varchar2_table(268) := '69732E64657374696E6174696F6E20213D3D20222229207B0D0A20202020202020202020202020202020766172205F74686973203D20746869733B0D0A20202020202020202020202020202020746869732E646972656374696F6E73536572766963652E';
wwv_flow_api.g_varchar2_table(269) := '726F757465287B0D0A20202020202020202020202020202020202020206F726967696E2020202020203A20746869732E6F726967696E2C0D0A202020202020202020202020202020202020202064657374696E6174696F6E203A20746869732E64657374';
wwv_flow_api.g_varchar2_table(270) := '696E6174696F6E2C0D0A202020202020202020202020202020202020202074726176656C4D6F646520203A20676F6F676C652E6D6170732E54726176656C4D6F64655B74726176656C4D6F64653F74726176656C4D6F64653A746869732E6F7074696F6E';
wwv_flow_api.g_varchar2_table(271) := '732E74726176656C4D6F64655D2C0D0A2020202020202020202020202020202020202020756E697453797374656D20203A20676F6F676C652E6D6170732E556E697453797374656D5B746869732E6F7074696F6E732E756E697453797374656D5D0D0A20';
wwv_flow_api.g_varchar2_table(272) := '2020202020202020202020202020207D2C2066756E6374696F6E28726573706F6E73652C737461747573297B0D0A20202020202020202020202020202020202020205F746869732E5F646972656374696F6E73526573706F6E736528726573706F6E7365';
wwv_flow_api.g_varchar2_table(273) := '2C737461747573290D0A202020202020202020202020202020207D293B0D0A2020202020202020202020207D20656C7365207B0D0A20202020202020202020202020202020617065782E646562756728224E6F20646972656374696F6E7320746F207368';
wwv_flow_api.g_varchar2_table(274) := '6F77202D206E65656420626F7468206F726967696E20616E642064657374696E6174696F6E206C6F636174696F6E22293B0D0A2020202020202020202020207D0D0A20202020202020207D20656C7365207B0D0A20202020202020202020202061706578';
wwv_flow_api.g_varchar2_table(275) := '2E64656275672822556E61626C6520746F2073686F7720646972656374696F6E733A206E6F20646174612C206E6F206F726967696E2F64657374696E6174696F6E22293B0D0A20202020202020207D0D0A202020207D2C0D0A0D0A202020202F2F646972';
wwv_flow_api.g_varchar2_table(276) := '656374696F6E732076697375616C69736174696F6E206261736564206F6E20717565727920646174610D0A202020205F646972656374696F6E733A2066756E6374696F6E202829207B0D0A2020202020202020617065782E646562756728227265706F72';
wwv_flow_api.g_varchar2_table(277) := '746D61702E5F646972656374696F6E7320222B746869732E6D61726B6572732E6C656E6774682B2220776179706F696E747322293B0D0A202020202020202069662028746869732E6D61726B6572732E6C656E6774683E3129207B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(278) := '20202020206966202821746869732E646972656374696F6E73446973706C617929207B0D0A20202020202020202020202020202020746869732E646972656374696F6E73446973706C6179203D206E657720676F6F676C652E6D6170732E446972656374';
wwv_flow_api.g_varchar2_table(279) := '696F6E7352656E64657265723B0D0A20202020202020202020202020202020746869732E646972656374696F6E7353657276696365203D206E657720676F6F676C652E6D6170732E446972656374696F6E73536572766963653B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(280) := '2020202020202020746869732E646972656374696F6E73446973706C61792E7365744D617028746869732E6D6170293B0D0A2020202020202020202020202020202069662028746869732E6F7074696F6E732E646972656374696F6E7350616E656C2920';
wwv_flow_api.g_varchar2_table(281) := '7B0D0A2020202020202020202020202020202020202020746869732E646972656374696F6E73446973706C61792E73657450616E656C28646F63756D656E742E676574456C656D656E744279496428746869732E6F7074696F6E732E646972656374696F';
wwv_flow_api.g_varchar2_table(282) := '6E7350616E656C29293B0D0A202020202020202020202020202020207D0D0A2020202020202020202020207D0D0A202020202020202020202020766172206F726967696E203D20746869732E6D61726B6572735B305D2E706F736974696F6E2C0D0A2020';
wwv_flow_api.g_varchar2_table(283) := '202020202020202020202020202064657374203D20746869732E6D61726B6572735B746869732E6D61726B6572732E6C656E6774682D315D2E706F736974696F6E2C0D0A20202020202020202020202020202020776179706F696E7473203D205B5D3B0D';
wwv_flow_api.g_varchar2_table(284) := '0A202020202020202020202020666F7220287661722069203D20313B2069203C20746869732E6D61726B6572732E6C656E6774682D313B20692B2B29207B0D0A20202020202020202020202020202020776179706F696E74732E70757368287B0D0A2020';
wwv_flow_api.g_varchar2_table(285) := '2020202020202020202020202020202020206C6F636174696F6E203A20746869732E6D61726B6572735B695D2E706F736974696F6E2C0D0A202020202020202020202020202020202020202073746F706F766572203A20747275650D0A20202020202020';
wwv_flow_api.g_varchar2_table(286) := '2020202020202020207D293B0D0A2020202020202020202020207D0D0A202020202020202020202020617065782E6465627567286F726967696E2C20646573742C20776179706F696E74732C20746869732E6F7074696F6E732E74726176656C4D6F6465';
wwv_flow_api.g_varchar2_table(287) := '293B0D0A202020202020202020202020766172205F74686973203D20746869733B0D0A202020202020202020202020746869732E646972656374696F6E73536572766963652E726F757465287B0D0A202020202020202020202020202020206F72696769';
wwv_flow_api.g_varchar2_table(288) := '6E2020202020202020202020203A206F726967696E2C0D0A2020202020202020202020202020202064657374696E6174696F6E202020202020203A20646573742C0D0A20202020202020202020202020202020776179706F696E74732020202020202020';
wwv_flow_api.g_varchar2_table(289) := '203A20776179706F696E74732C0D0A202020202020202020202020202020206F7074696D697A65576179706F696E7473203A20746869732E6F7074696F6E732E6F7074696D697A65576179706F696E74732C0D0A20202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(290) := '74726176656C4D6F646520202020202020203A20676F6F676C652E6D6170732E54726176656C4D6F64655B746869732E6F7074696F6E732E74726176656C4D6F64655D2C0D0A20202020202020202020202020202020756E697453797374656D20202020';
wwv_flow_api.g_varchar2_table(291) := '202020203A20676F6F676C652E6D6170732E556E697453797374656D5B746869732E6F7074696F6E732E756E697453797374656D5D0D0A2020202020202020202020207D2C2066756E6374696F6E28726573706F6E73652C737461747573297B0D0A2020';
wwv_flow_api.g_varchar2_table(292) := '20202020202020202020202020205F746869732E5F646972656374696F6E73526573706F6E736528726573706F6E73652C737461747573290D0A2020202020202020202020207D293B0D0A20202020202020207D20656C7365207B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(293) := '2020202020617065782E646562756728226E6F7420656E6F75676820776179706F696E7473202D206E656564206174206C6561737420616E206F726967696E20616E6420612064657374696E6174696F6E20706F696E7422293B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(294) := '7D0D0A202020207D2C0D0A0D0A092F2A0D0A09202A0D0A09202A2044524157494E47204C415945520D0A09202A0D0A09202A2F0D0A0D0A2020202064656C65746553656C656374656446656174757265733A2066756E6374696F6E2829207B0D0A202020';
wwv_flow_api.g_varchar2_table(295) := '2020202020617065782E646562756728227265706F72746D61702E64656C65746553656C6563746564466561747572657322293B0D0A202020202020202076617220646174614C61796572203D20746869732E6D61702E646174613B0D0A202020202020';
wwv_flow_api.g_varchar2_table(296) := '2020646174614C617965722E666F72456163682866756E6374696F6E286665617475726529207B0D0A20202020202020202020202069662028666561747572652E67657450726F70657274792827697353656C6563746564272929207B0D0A2020202020';
wwv_flow_api.g_varchar2_table(297) := '2020202020202020202020617065782E6465627567282272656D6F7665222C66656174757265293B0D0A20202020202020202020202020202020646174614C617965722E72656D6F76652866656174757265293B0D0A2020202020202020202020207D0D';
wwv_flow_api.g_varchar2_table(298) := '0A20202020202020207D293B0D0A202020207D2C0D0A0D0A2020202064656C657465416C6C46656174757265733A2066756E6374696F6E2829207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E64656C657465416C6C';
wwv_flow_api.g_varchar2_table(299) := '466561747572657322293B0D0A202020202020202076617220646174614C61796572203D20746869732E6D61702E646174613B0D0A2020202020202020646174614C617965722E666F72456163682866756E6374696F6E286665617475726529207B0D0A';
wwv_flow_api.g_varchar2_table(300) := '202020202020202020202020617065782E6465627567282272656D6F7665222C66656174757265293B0D0A202020202020202020202020646174614C617965722E72656D6F76652866656174757265293B0D0A20202020202020207D293B0D0A20202020';
wwv_flow_api.g_varchar2_table(301) := '7D2C0D0A0D0A202020205F616464436F6E74726F6C3A2066756E6374696F6E2869636F6E2C2068696E742C2063616C6C6261636B29207B0D0A0D0A202020202020202076617220636F6E74726F6C446976203D20646F63756D656E742E63726561746545';
wwv_flow_api.g_varchar2_table(302) := '6C656D656E74282764697627293B0D0A0D0A20202020202020202F2F205365742043535320666F722074686520636F6E74726F6C20626F726465722E0D0A202020202020202076617220636F6E74726F6C5549203D20646F63756D656E742E6372656174';
wwv_flow_api.g_varchar2_table(303) := '65456C656D656E74282764697627293B0D0A2020202020202020636F6E74726F6C55492E636C6173734E616D65203D20277265706F72746D61702D636F6E74726F6C5549273B0D0A2020202020202020636F6E74726F6C55492E7469746C65203D206869';
wwv_flow_api.g_varchar2_table(304) := '6E743B0D0A2020202020202020636F6E74726F6C4469762E617070656E644368696C6428636F6E74726F6C5549293B0D0A0D0A20202020202020202F2F205365742043535320666F722074686520636F6E74726F6C20696E746572696F722E0D0A202020';
wwv_flow_api.g_varchar2_table(305) := '202020202076617220636F6E74726F6C496E6E6572203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0D0A2020202020202020636F6E74726F6C496E6E65722E636C6173734E616D65203D20277265706F72746D61702D';
wwv_flow_api.g_varchar2_table(306) := '636F6E74726F6C496E6E6572273B0D0A2020202020202020636F6E74726F6C496E6E65722E7374796C652E6261636B67726F756E64496D616765203D2069636F6E3B0D0A0D0A2020202020202020636F6E74726F6C55492E617070656E644368696C6428';
wwv_flow_api.g_varchar2_table(307) := '636F6E74726F6C496E6E6572293B0D0A0D0A20202020202020202F2F2053657475702074686520636C69636B206576656E74206C697374656E65720D0A2020202020202020636F6E74726F6C55492E6164644576656E744C697374656E65722827636C69';
wwv_flow_api.g_varchar2_table(308) := '636B272C2063616C6C6261636B293B0D0A0D0A2020202020202020746869732E6D61702E636F6E74726F6C735B676F6F676C652E6D6170732E436F6E74726F6C506F736974696F6E2E544F505F43454E5445525D2E7075736828636F6E74726F6C446976';
wwv_flow_api.g_varchar2_table(309) := '293B0D0A0D0A202020202020202072657475726E20636F6E74726F6C4469763B0D0A202020207D2C0D0A0D0A202020205F616464436865636B626F783A2066756E6374696F6E286E616D652C206C6162656C2C2068696E7429207B0D0A0D0A2020202020';
wwv_flow_api.g_varchar2_table(310) := '20202076617220636F6E74726F6C446976203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0D0A0D0A20202020202020202F2F205365742043535320666F722074686520636F6E74726F6C20626F726465722E0D0A2020';
wwv_flow_api.g_varchar2_table(311) := '20202020202076617220636F6E74726F6C5549203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0D0A2020202020202020636F6E74726F6C55492E636C6173734E616D65203D20277265706F72746D61702D636F6E7472';
wwv_flow_api.g_varchar2_table(312) := '6F6C5549273B0D0A2020202020202020636F6E74726F6C55492E7469746C65203D2068696E743B0D0A2020202020202020636F6E74726F6C4469762E617070656E644368696C6428636F6E74726F6C5549293B0D0A0D0A20202020202020202F2F205365';
wwv_flow_api.g_varchar2_table(313) := '742043535320666F722074686520636F6E74726F6C20696E746572696F722E0D0A202020202020202076617220636F6E74726F6C496E6E6572203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(314) := '636F6E74726F6C496E6E65722E636C6173734E616D65203D20277265706F72746D61702D636F6E74726F6C496E6E6572273B0D0A0D0A2020202020202020636F6E74726F6C55492E617070656E644368696C6428636F6E74726F6C496E6E6572293B0D0A';
wwv_flow_api.g_varchar2_table(315) := '0D0A202020202020202076617220636F6E74726F6C436865636B626F78203D20646F63756D656E742E637265617465456C656D656E742827696E70757427293B0D0A2020202020202020636F6E74726F6C436865636B626F782E73657441747472696275';
wwv_flow_api.g_varchar2_table(316) := '7465282774797065272C2027636865636B626F7827293B0D0A2020202020202020636F6E74726F6C436865636B626F782E73657441747472696275746528276964272C206E616D652B275F272B746869732E6F7074696F6E732E726567696F6E4964293B';
wwv_flow_api.g_varchar2_table(317) := '0D0A2020202020202020636F6E74726F6C436865636B626F782E73657441747472696275746528276E616D65272C206E616D65293B0D0A2020202020202020636F6E74726F6C436865636B626F782E736574417474726962757465282776616C7565272C';
wwv_flow_api.g_varchar2_table(318) := '20275927293B0D0A2020202020202020636F6E74726F6C436865636B626F782E636C6173734E616D65203D20277265706F72746D61702D636F6E74726F6C436865636B626F78273B0D0A0D0A2020202020202020636F6E74726F6C436865636B626F782E';
wwv_flow_api.g_varchar2_table(319) := '636C6173734E616D65203D20277265706F72746D61702D636865636B626F78273B0D0A0D0A2020202020202020636F6E74726F6C496E6E65722E617070656E644368696C6428636F6E74726F6C436865636B626F78293B0D0A0D0A202020202020202076';
wwv_flow_api.g_varchar2_table(320) := '617220636F6E74726F6C4C6162656C203D20646F63756D656E742E637265617465456C656D656E7428276C6162656C27293B0D0A2020202020202020636F6E74726F6C4C6162656C2E7365744174747269627574652827666F72272C6E616D652B275F27';
wwv_flow_api.g_varchar2_table(321) := '2B746869732E6F7074696F6E732E726567696F6E4964293B0D0A2020202020202020636F6E74726F6C4C6162656C2E696E6E657248544D4C203D206C6162656C3B0D0A2020202020202020636F6E74726F6C4C6162656C2E636C6173734E616D65203D20';
wwv_flow_api.g_varchar2_table(322) := '277265706F72746D61702D636F6E74726F6C436865636B626F784C6162656C273B0D0A0D0A2020202020202020636F6E74726F6C496E6E65722E617070656E644368696C6428636F6E74726F6C4C6162656C293B0D0A0D0A202020202020202074686973';
wwv_flow_api.g_varchar2_table(323) := '2E6D61702E636F6E74726F6C735B676F6F676C652E6D6170732E436F6E74726F6C506F736974696F6E2E544F505F43454E5445525D2E7075736828636F6E74726F6C446976293B0D0A0D0A202020202020202072657475726E20636F6E74726F6C446976';
wwv_flow_api.g_varchar2_table(324) := '3B0D0A202020207D2C0D0A0D0A202020205F616464506F696E743A2066756E6374696F6E28646174614C617965722C20706F7329207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E5F616464506F696E74222C646174';
wwv_flow_api.g_varchar2_table(325) := '614C617965722C706F73293B0D0A20202020202020207661722066656174757265203D206E657720676F6F676C652E6D6170732E446174612E46656174757265287B0D0A20202020202020202020202067656F6D657472793A206E657720676F6F676C65';
wwv_flow_api.g_varchar2_table(326) := '2E6D6170732E446174612E506F696E7428706F73290D0A20202020202020207D293B0D0A2020202020202020646174614C617965722E6164642866656174757265293B0D0A202020202020202072657475726E20666561747572653B0D0A202020207D2C';
wwv_flow_api.g_varchar2_table(327) := '0D0A0D0A202020205F616464506F6C79676F6E3A2066756E6374696F6E28646174614C617965722C2061727229207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E5F616464506F6C79676F6E222C646174614C617965';
wwv_flow_api.g_varchar2_table(328) := '722C617272293B0D0A0D0A20202020202020206966202824282223686F6C655F222B746869732E6F7074696F6E732E726567696F6E4964292E70726F702822636865636B6564222929207B0D0A202020202020202020202020646174614C617965722E66';
wwv_flow_api.g_varchar2_table(329) := '6F72456163682866756E6374696F6E286665617475726529207B0D0A2020202020202020202020202020202069662028666561747572652E67657450726F70657274792827697353656C6563746564272929207B0D0A2020202020202020202020202020';
wwv_flow_api.g_varchar2_table(330) := '2020202020207661722067656F6D203D20666561747572652E67657447656F6D6574727928293B0D0A20202020202020202020202020202020202020206966202867656F6D2E676574547970652829203D3D2022506F6C79676F6E2229207B0D0A202020';
wwv_flow_api.g_varchar2_table(331) := '2020202020202020202020202020202020202020202F2F617070656E6420746865206E657720686F6C6520746F20746865206578697374696E6720706F6C79676F6E0D0A20202020202020202020202020202020202020202020202076617220706F6C79';
wwv_flow_api.g_varchar2_table(332) := '203D2067656F6D2E676574417272617928293B0D0A2020202020202020202020202020202020202020202020202F2F74686520706F6C79676F6E2077696C6C206E6F7720626520616E206172726179206F66204C696E65617252696E67730D0A20202020';
wwv_flow_api.g_varchar2_table(333) := '2020202020202020202020202020202020202020706F6C792E70757368286E657720676F6F676C652E6D6170732E446174612E4C696E65617252696E672861727229293B0D0A202020202020202020202020202020202020202020202020666561747572';
wwv_flow_api.g_varchar2_table(334) := '652E73657447656F6D65747279286E657720676F6F676C652E6D6170732E446174612E506F6C79676F6E28706F6C7929293B0D0A20202020202020202020202020202020202020207D0D0A202020202020202020202020202020207D0D0A202020202020';
wwv_flow_api.g_varchar2_table(335) := '2020202020207D293B0D0A20202020202020207D20656C7365207B0D0A202020202020202020202020646174614C617965722E616464286E657720676F6F676C652E6D6170732E446174612E46656174757265287B0D0A20202020202020202020202020';
wwv_flow_api.g_varchar2_table(336) := '20202067656F6D657472793A206E657720676F6F676C652E6D6170732E446174612E506F6C79676F6E285B6172725D290D0A2020202020202020202020207D29293B0D0A20202020202020207D0D0A202020207D2C0D0A0D0A202020202F2F20696E6974';
wwv_flow_api.g_varchar2_table(337) := '69616C69736174696F6E20666F722064617461206C61796572207768656E206E6F7420696E2064726177696E67206D6F64650D0A202020205F696E697446656174757265733A2066756E6374696F6E2829207B0D0A2020202020202020617065782E6465';
wwv_flow_api.g_varchar2_table(338) := '62756728227265706F72746D61702E5F696E6974466561747572657322293B0D0A0D0A2020202020202020766172205F74686973203D20746869732C0D0A202020202020202020202020646174614C61796572203D20746869732E6D61702E646174613B';
wwv_flow_api.g_varchar2_table(339) := '0D0A0D0A20202020202020202F2F204368616E67652074686520636F6C6F72207768656E2074686520697353656C65637465642070726F70657274792069732073657420746F20747275652E0D0A2020202020202020646174614C617965722E73657453';
wwv_flow_api.g_varchar2_table(340) := '74796C6528746869732E6F7074696F6E732E666561747572655374796C65466E7C7C66756E6374696F6E286665617475726529207B0D0A20202020202020202020202076617220636F6C6F72203D205F746869732E6F7074696F6E732E66656174757265';
wwv_flow_api.g_varchar2_table(341) := '436F6C6F723B0D0A20202020202020202020202069662028666561747572652E67657450726F70657274792827697353656C6563746564272929207B0D0A20202020202020202020202020202020636F6C6F72203D205F746869732E6F7074696F6E732E';
wwv_flow_api.g_varchar2_table(342) := '66656174757265436F6C6F7253656C65637465643B0D0A2020202020202020202020207D0D0A20202020202020202020202072657475726E202F2A2A204074797065207B21676F6F676C652E6D6170732E446174612E5374796C654F7074696F6E737D20';
wwv_flow_api.g_varchar2_table(343) := '2A2F287B0D0A2020202020202020202020202020202066696C6C436F6C6F72202020203A20636F6C6F722C0D0A202020202020202020202020202020207374726F6B65436F6C6F7220203A20636F6C6F722C0D0A20202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(344) := '7374726F6B65576569676874203A20312C0D0A20202020202020202020202020202020647261676761626C65202020203A205F746869732E6F7074696F6E732E6973447261676761626C652C0D0A20202020202020202020202020202020656469746162';
wwv_flow_api.g_varchar2_table(345) := '6C6520202020203A2066616C73650D0A2020202020202020202020207D293B0D0A20202020202020207D293B0D0A0D0A202020202020202069662028746869732E6F7074696F6E732E6665617475726553656C65637461626C6529207B0D0A2020202020';
wwv_flow_api.g_varchar2_table(346) := '202020202020202F2F205768656E20746865207573657220636C69636B732C207365742027697353656C6563746564272C206368616E67696E672074686520636F6C6F72206F66207468652073686170652E0D0A20202020202020202020202064617461';
wwv_flow_api.g_varchar2_table(347) := '4C617965722E6164644C697374656E65722827636C69636B272C2066756E6374696F6E286576656E7429207B0D0A20202020202020202020202020202020617065782E646562756728227265706F72746D61702E6D61702E64617461202D20636C69636B';
wwv_flow_api.g_varchar2_table(348) := '222C6576656E74293B0D0A20202020202020202020202020202020696620286576656E742E666561747572652E67657450726F70657274792827697353656C6563746564272929207B0D0A2020202020202020202020202020202020202020617065782E';
wwv_flow_api.g_varchar2_table(349) := '64656275672822697353656C6563746564222C2266616C736522293B0D0A20202020202020202020202020202020202020206576656E742E666561747572652E72656D6F766550726F70657274792827697353656C656374656427293B0D0A2020202020';
wwv_flow_api.g_varchar2_table(350) := '202020202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E747269676765722822756E73656C65637466656174757265222C207B6D61703A5F746869732E6D61702C206665';
wwv_flow_api.g_varchar2_table(351) := '61747572653A6576656E742E666561747572657D293B0D0A202020202020202020202020202020207D20656C7365207B0D0A2020202020202020202020202020202020202020617065782E64656275672822697353656C6563746564222C227472756522';
wwv_flow_api.g_varchar2_table(352) := '293B0D0A20202020202020202020202020202020202020206576656E742E666561747572652E73657450726F70657274792827697353656C6563746564272C2074727565293B0D0A2020202020202020202020202020202020202020617065782E6A5175';
wwv_flow_api.g_varchar2_table(353) := '657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E74726967676572282273656C65637466656174757265222C207B6D61703A5F746869732E6D61702C20666561747572653A6576656E742E666561747572657D293B0D0A20';
wwv_flow_api.g_varchar2_table(354) := '2020202020202020202020202020207D0D0A2020202020202020202020207D293B0D0A20202020202020207D0D0A0D0A202020202020202069662028746869732E6F7074696F6E732E66656174757265486F76657261626C6529207B0D0A0D0A20202020';
wwv_flow_api.g_varchar2_table(355) := '20202020202020202F2F205768656E20746865207573657220686F766572732C2074656D7074207468656D20746F20636C69636B206279206F75746C696E696E67207468652073686170652E0D0A2020202020202020202020202F2F2043616C6C207265';
wwv_flow_api.g_varchar2_table(356) := '766572745374796C65282920746F2072656D6F766520616C6C206F76657272696465732E20546869732077696C6C2075736520746865207374796C652072756C65730D0A2020202020202020202020202F2F20646566696E656420696E20746865206675';
wwv_flow_api.g_varchar2_table(357) := '6E6374696F6E2070617373656420746F207365745374796C6528290D0A0D0A202020202020202020202020646174614C617965722E6164644C697374656E657228276D6F7573656F766572272C2066756E6374696F6E286576656E7429207B0D0A202020';
wwv_flow_api.g_varchar2_table(358) := '20202020202020202020202020617065782E646562756728227265706F72746D61702E6D61702E64617461222C226D6F7573656F766572222C6576656E74293B0D0A20202020202020202020202020202020646174614C617965722E7265766572745374';
wwv_flow_api.g_varchar2_table(359) := '796C6528293B0D0A20202020202020202020202020202020646174614C617965722E6F766572726964655374796C65286576656E742E666561747572652C207B7374726F6B655765696768743A20347D293B0D0A20202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(360) := '617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6F7573656F76657266656174757265222C207B6D61703A5F746869732E6D61702C20666561747572653A6576656E742E6665';
wwv_flow_api.g_varchar2_table(361) := '61747572657D293B0D0A2020202020202020202020207D293B0D0A0D0A202020202020202020202020646174614C617965722E6164644C697374656E657228276D6F7573656F7574272C2066756E6374696F6E286576656E7429207B0D0A202020202020';
wwv_flow_api.g_varchar2_table(362) := '20202020202020202020617065782E646562756728227265706F72746D61702E6D61702E64617461222C226D6F7573656F7574222C6576656E74293B0D0A20202020202020202020202020202020646174614C617965722E7265766572745374796C6528';
wwv_flow_api.g_varchar2_table(363) := '293B0D0A20202020202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6F7573656F757466656174757265222C207B6D61703A5F746869732E6D61';
wwv_flow_api.g_varchar2_table(364) := '702C20666561747572653A6576656E742E666561747572657D293B0D0A2020202020202020202020207D293B0D0A20202020202020207D0D0A0D0A202020207D2C0D0A0D0A202020202F2F20696E697469616C69736174696F6E20666F72206461746120';
wwv_flow_api.g_varchar2_table(365) := '6C61796572207768656E20696E2064726177696E67206D6F64650D0A202020205F696E697444726177696E673A2066756E6374696F6E2829207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E5F696E69744472617769';
wwv_flow_api.g_varchar2_table(366) := '6E67222C746869732E6F7074696F6E732E64726177696E674D6F646573293B0D0A2020202020202020766172205F74686973203D20746869732C0D0A202020202020202020202020646174614C61796572203D20746869732E6D61702E646174613B0D0A';
wwv_flow_api.g_varchar2_table(367) := '0D0A202020202020202069662028746869732E6F7074696F6E732E64726177696E674D6F6465732E696E6465784F662822706F6C79676F6E22293E2D3129207B0D0A202020202020202020202020746869732E5F616464436865636B626F78280D0A2020';
wwv_flow_api.g_varchar2_table(368) := '202020202020202020202020202027686F6C65272C202F2F6E616D650D0A2020202020202020202020202020202027486F6C65272C202F2F6C6162656C0D0A2020202020202020202020202020202027537562747261637420686F6C652066726F6D2070';
wwv_flow_api.g_varchar2_table(369) := '6F6C79676F6E272C202F2F68696E740D0A202020202020202020202020293B0D0A20202020202020207D0D0A0D0A2020202020202020746869732E5F616464436F6E74726F6C280D0A0909092F2F747261736863616E2069636F6E0D0A20202020202020';
wwv_flow_api.g_varchar2_table(370) := '20202020202275726C2827646174613A696D6167652F706E673B6261736536342C6956424F5277304B47676F414141414E53556845556741414142514141414155434159414141434E6952304E4141414135456C45515651346A63335550306F44515254';
wwv_flow_api.g_varchar2_table(371) := '4838553955524753783941536577636F7A3541414C3972596578633454324668593667454530544D49515332564645484567435970664D553632637A2B3053492F4750627866722F35386D59596C6E58586F4D4576635A4430486E477861734E57426E61';
wwv_flow_api.g_varchar2_table(372) := '455935776C2F564D38343759726342393375456E36682B473130676A7A6A6D755541773537414963353441616D45587A4264645433666F342F6A393554314E50593877745131517A6A714D65346A506F68466C776C6D566B4F43472F7833634F6B78702B';
wwv_flow_api.g_varchar2_table(373) := '455638332B47566A304152622F50654532766D7238542B7A30415A4A6365454E324A664331416449355732722F714D73324579346449364F6C624E33767138414A646975395458776E75512B6334373344414775674256376F5757476D76696463414141';
wwv_flow_api.g_varchar2_table(374) := '4141456C46546B5375516D43432729222C0D0A2020202020202020202020202744656C6574652073656C6563746564206665617475726573272C202F2F68696E740D0A20202020202020202020202066756E6374696F6E286529207B0D0A202020202020';
wwv_flow_api.g_varchar2_table(375) := '202020202020202020205F746869732E64656C65746553656C6563746564466561747572657328293B0D0A2020202020202020202020207D293B0D0A0D0A20202020202020202F2F2066726F6D2068747470733A2F2F6A73666964646C652E6E65742F67';
wwv_flow_api.g_varchar2_table(376) := '656F636F64657A69702F657A666532774C672F35372F0D0A0D0A20202020202020207661722064726177696E674D616E61676572203D206E657720676F6F676C652E6D6170732E64726177696E672E44726177696E674D616E61676572287B0D0A202020';
wwv_flow_api.g_varchar2_table(377) := '20202020202020202064726177696E67436F6E74726F6C4F7074696F6E733A207B0D0A20202020202020202020202020202F2A68747470733A2F2F646576656C6F706572732E676F6F676C652E636F6D2F6D6170732F646F63756D656E746174696F6E2F';
wwv_flow_api.g_varchar2_table(378) := '6A6176617363726970742F7265666572656E63652F636F6E74726F6C23436F6E74726F6C506F736974696F6E2A2F0D0A2020202020202020202020202020706F736974696F6E20202020203A20676F6F676C652E6D6170732E436F6E74726F6C506F7369';
wwv_flow_api.g_varchar2_table(379) := '74696F6E2E544F505F43454E5445522C0D0A202020202020202020202020202064726177696E674D6F646573203A20746869732E6F7074696F6E732E64726177696E674D6F6465730D0A2020202020202020202020207D0D0A20202020202020207D293B';
wwv_flow_api.g_varchar2_table(380) := '0D0A202020202020202064726177696E674D616E616765722E7365744D617028746869732E6D6170293B0D0A0D0A20202020202020202F2F2066726F6D20687474703A2F2F737461636B6F766572666C6F772E636F6D2F7175657374696F6E732F323530';
wwv_flow_api.g_varchar2_table(381) := '37323036392F6578706F72742D67656F6A736F6E2D646174612D66726F6D2D676F6F676C652D6D6170730D0A20202020202020202F2F2066726F6D20687474703A2F2F6A73666964646C652E6E65742F646F6B746F726D6F6C6C652F35463838442F0D0A';
wwv_flow_api.g_varchar2_table(382) := '2020202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E65722864726177696E674D616E616765722C20276F7665726C6179636F6D706C657465272C2066756E6374696F6E286576656E7429207B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(383) := '20202020617065782E646562756728227265706F72746D61702E6F7665726C6179636F6D706C657465222C6576656E74293B0D0A20202020202020202020202073776974636820286576656E742E7479706529207B0D0A20202020202020202020202063';
wwv_flow_api.g_varchar2_table(384) := '61736520676F6F676C652E6D6170732E64726177696E672E4F7665726C6179547970652E4D41524B45523A0D0A202020202020202020202020202020205F746869732E5F616464506F696E7428646174614C617965722C206576656E742E6F7665726C61';
wwv_flow_api.g_varchar2_table(385) := '792E676574506F736974696F6E2829293B0D0A20202020202020202020202020202020627265616B3B0D0A2020202020202020202020206361736520676F6F676C652E6D6170732E64726177696E672E4F7665726C6179547970652E504F4C59474F4E3A';
wwv_flow_api.g_varchar2_table(386) := '0D0A202020202020202020202020202020207661722070203D206576656E742E6F7665726C61792E6765745061746828292E676574417272617928293B0D0A202020202020202020202020202020205F746869732E5F616464506F6C79676F6E28646174';
wwv_flow_api.g_varchar2_table(387) := '614C617965722C2070293B0D0A20202020202020202020202020202020627265616B3B0D0A2020202020202020202020206361736520676F6F676C652E6D6170732E64726177696E672E4F7665726C6179547970652E52454354414E474C453A0D0A2020';
wwv_flow_api.g_varchar2_table(388) := '20202020202020202020202020207661722062203D206576656E742E6F7665726C61792E676574426F756E647328292C0D0A202020202020202020202020202020202020202070203D205B622E676574536F7574685765737428292C0D0A202020202020';
wwv_flow_api.g_varchar2_table(389) := '202020202020202020202020202020202020207B6C6174203A20622E676574536F7574685765737428292E6C617428292C0D0A20202020202020202020202020202020202020202020202020206C6E67203A20622E6765744E6F7274684561737428292E';
wwv_flow_api.g_varchar2_table(390) := '6C6E6728290D0A202020202020202020202020202020202020202020202020207D2C0D0A20202020202020202020202020202020202020202020202020622E6765744E6F7274684561737428292C0D0A2020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(391) := '20202020207B6C6E67203A20622E676574536F7574685765737428292E6C6E6728292C0D0A20202020202020202020202020202020202020202020202020206C6174203A20622E6765744E6F7274684561737428292E6C617428290D0A20202020202020';
wwv_flow_api.g_varchar2_table(392) := '2020202020202020202020202020202020207D5D3B0D0A202020202020202020202020202020205F746869732E5F616464506F6C79676F6E28646174614C617965722C2070293B0D0A20202020202020202020202020202020627265616B3B0D0A202020';
wwv_flow_api.g_varchar2_table(393) := '2020202020202020206361736520676F6F676C652E6D6170732E64726177696E672E4F7665726C6179547970652E504F4C594C494E453A0D0A20202020202020202020202020202020646174614C617965722E616464286E657720676F6F676C652E6D61';
wwv_flow_api.g_varchar2_table(394) := '70732E446174612E46656174757265287B0D0A202020202020202020202020202020202020202067656F6D657472793A206E657720676F6F676C652E6D6170732E446174612E4C696E65537472696E67286576656E742E6F7665726C61792E6765745061';
wwv_flow_api.g_varchar2_table(395) := '746828292E67657441727261792829290D0A202020202020202020202020202020207D29293B0D0A20202020202020202020202020202020627265616B3B0D0A2020202020202020202020206361736520676F6F676C652E6D6170732E64726177696E67';
wwv_flow_api.g_varchar2_table(396) := '2E4F7665726C6179547970652E434952434C453A0D0A202020202020202020202020202020202F2F746F646F3A2066696E6420736F6D6520776179206F662073686F77696E672074686520636972636C652C20616C6F6E67207769746820656469746162';
wwv_flow_api.g_varchar2_table(397) := '6C65207261646975733F0D0A20202020202020202020202020202020646174614C617965722E616464286E657720676F6F676C652E6D6170732E446174612E46656174757265287B0D0A202020202020202020202020202020202020202070726F706572';
wwv_flow_api.g_varchar2_table(398) := '746965733A207B0D0A2020202020202020202020202020202020202020202020207261646975733A206576656E742E6F7665726C61792E67657452616469757328290D0A20202020202020202020202020202020202020207D2C0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(399) := '20202020202020202020202067656F6D657472793A206E657720676F6F676C652E6D6170732E446174612E506F696E74286576656E742E6F7665726C61792E67657443656E7465722829290D0A202020202020202020202020202020207D29293B0D0A20';
wwv_flow_api.g_varchar2_table(400) := '202020202020202020202020202020627265616B3B0D0A2020202020202020202020207D0D0A2020202020202020202020206576656E742E6F7665726C61792E7365744D6170286E756C6C293B0D0A20202020202020207D293B0D0A0D0A202020202020';
wwv_flow_api.g_varchar2_table(401) := '20202F2F204368616E67652074686520636F6C6F72207768656E2074686520697353656C65637465642070726F70657274792069732073657420746F20747275652E0D0A2020202020202020646174614C617965722E7365745374796C652866756E6374';
wwv_flow_api.g_varchar2_table(402) := '696F6E286665617475726529207B0D0A20202020202020202020202076617220636F6C6F72203D205F746869732E6F7074696F6E732E66656174757265436F6C6F722C0D0A202020202020202020202020202020206564697461626C65203D2066616C73';
wwv_flow_api.g_varchar2_table(403) := '652C0D0A202020202020202020202020202020207374796C654F7074696F6E733B0D0A20202020202020202020202069662028666561747572652E67657450726F70657274792827697353656C6563746564272929207B0D0A2020202020202020202020';
wwv_flow_api.g_varchar2_table(404) := '2020202020636F6C6F72203D205F746869732E6F7074696F6E732E66656174757265436F6C6F7253656C65637465643B0D0A202020202020202020202020202020202F2F2069662077652772652064726177696E67206120686F6C652C20776520646F6E';
wwv_flow_api.g_varchar2_table(405) := '27742077616E7420746F20647261672F6564697420746865206578697374696E6720666561747572650D0A202020202020202020202020202020206564697461626C65203D20212824282223686F6C655F222B5F746869732E6F7074696F6E732E726567';
wwv_flow_api.g_varchar2_table(406) := '696F6E4964292E70726F702822636865636B65642229293B0D0A2020202020202020202020207D0D0A2020202020202020202020207374796C654F7074696F6E73203D202F2A2A204074797065207B21676F6F676C652E6D6170732E446174612E537479';
wwv_flow_api.g_varchar2_table(407) := '6C654F7074696F6E737D202A2F7B0D0A2020202020202020202020202020202066696C6C436F6C6F72202020203A20636F6C6F722C0D0A202020202020202020202020202020207374726F6B65436F6C6F7220203A20636F6C6F722C0D0A202020202020';
wwv_flow_api.g_varchar2_table(408) := '202020202020202020207374726F6B65576569676874203A20310D0A2020202020202020202020207D3B0D0A202020202020202020202020696620285F746869732E6F7074696F6E732E666561747572655374796C65466E29207B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(409) := '202020202020202020242E657874656E64287374796C654F7074696F6E732C205F746869732E6F7074696F6E732E666561747572655374796C65466E286665617475726529293B0D0A2020202020202020202020207D0D0A202020202020202020202020';
wwv_flow_api.g_varchar2_table(410) := '72657475726E20242E657874656E64287374796C654F7074696F6E732C207B647261676761626C653A6564697461626C652C206564697461626C653A6564697461626C657D293B0D0A20202020202020207D293B0D0A0D0A202020202020202064617461';
wwv_flow_api.g_varchar2_table(411) := '4C617965722E6164644C697374656E6572282761646466656174757265272C2066756E6374696F6E286576656E7429207B0D0A202020202020202020202020617065782E646562756728227265706F72746D61702E6D61702E64617461222C2261646466';
wwv_flow_api.g_varchar2_table(412) := '656174757265222C6576656E74293B0D0A202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E74726967676572282261646466656174757265222C207B6D61703A5F746869';
wwv_flow_api.g_varchar2_table(413) := '732E6D61702C20666561747572653A6576656E742E666561747572657D293B0D0A20202020202020207D293B0D0A0D0A2020202020202020646174614C617965722E6164644C697374656E6572282772656D6F766566656174757265272C2066756E6374';
wwv_flow_api.g_varchar2_table(414) := '696F6E286576656E7429207B0D0A202020202020202020202020617065782E646562756728227265706F72746D61702E6D61702E64617461222C2272656D6F766566656174757265222C6576656E74293B0D0A202020202020202020202020617065782E';
wwv_flow_api.g_varchar2_table(415) := '6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E74726967676572282272656D6F766566656174757265222C207B6D61703A5F746869732E6D61702C20666561747572653A6576656E742E666561747572657D293B';
wwv_flow_api.g_varchar2_table(416) := '0D0A20202020202020207D293B0D0A0D0A2020202020202020646174614C617965722E6164644C697374656E6572282773657467656F6D65747279272C2066756E6374696F6E286576656E7429207B0D0A202020202020202020202020617065782E6465';
wwv_flow_api.g_varchar2_table(417) := '62756728227265706F72746D61702E6D61702E64617461222C2273657467656F6D65747279222C6576656E74293B0D0A202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E';
wwv_flow_api.g_varchar2_table(418) := '74726967676572282273657467656F6D65747279222C207B0D0A090909096D61702020202020202020203A205F746869732E6D61702C0D0A090909096665617475726520202020203A206576656E742E666561747572652C0D0A090909096E657747656F';
wwv_flow_api.g_varchar2_table(419) := '6D65747279203A206576656E742E6E657747656F6D657472792C0D0A090909096F6C6447656F6D65747279203A206576656E742E6F6C6447656F6D657472790D0A0909097D293B0D0A20202020202020207D293B0D0A0D0A2020202020202020646F6375';
wwv_flow_api.g_varchar2_table(420) := '6D656E742E6164644576656E744C697374656E657228276B6579646F776E272C2066756E6374696F6E286576656E7429207B0D0A202020202020202020202020696620286576656E742E6B6579203D3D3D202244656C6574652229207B0D0A2020202020';
wwv_flow_api.g_varchar2_table(421) := '20202020202020202020205F746869732E64656C65746553656C6563746564466561747572657328293B0D0A2020202020202020202020207D0D0A20202020202020207D293B0D0A0D0A202020207D2C0D0A0D0A092F2A0D0A09202A0D0A09202A204745';
wwv_flow_api.g_varchar2_table(422) := '4F4A534F4E0D0A09202A0D0A09202A2F0D0A0D0A202020202F2A2A0D0A20202020202A2050726F63657373206561636820706F696E7420696E20612047656F6D657472792C207265676172646C657373206F6620686F7720646565702074686520706F69';
wwv_flow_api.g_varchar2_table(423) := '6E7473206D6179206C69652E0D0A20202020202A2040706172616D207B676F6F676C652E6D6170732E446174612E47656F6D657472797D2067656F6D65747279202D2073747275637475726520746F2070726F636573730D0A20202020202A2040706172';
wwv_flow_api.g_varchar2_table(424) := '616D207B66756E6374696F6E28676F6F676C652E6D6170732E4C61744C6E67297D2063616C6C6261636B2066756E6374696F6E20746F2063616C6C206F6E20656163680D0A20202020202A20202020204C61744C6E6720706F696E7420656E636F756E74';
wwv_flow_api.g_varchar2_table(425) := '657265640D0A20202020202A2040706172616D207B4F626A6563747D2074686973417267202D2076616C7565206F66202774686973272061732070726F766964656420746F202763616C6C6261636B270D0A20202020202A2F0D0A202020205F70726F63';
wwv_flow_api.g_varchar2_table(426) := '657373506F696E7473203A2066756E6374696F6E202867656F6D657472792C2063616C6C6261636B2C207468697341726729207B0D0A2020202020202020766172205F74686973203D20746869733B0D0A20202020202020206966202867656F6D657472';
wwv_flow_api.g_varchar2_table(427) := '7920696E7374616E63656F6620676F6F676C652E6D6170732E4C61744C6E6729207B0D0A20202020202020202020202063616C6C6261636B2E63616C6C28746869734172672C2067656F6D65747279293B0D0A20202020202020207D20656C7365206966';
wwv_flow_api.g_varchar2_table(428) := '202867656F6D6574727920696E7374616E63656F6620676F6F676C652E6D6170732E446174612E506F696E7429207B0D0A20202020202020202020202063616C6C6261636B2E63616C6C28746869734172672C2067656F6D657472792E6765742829293B';
wwv_flow_api.g_varchar2_table(429) := '0D0A20202020202020207D20656C7365207B0D0A20202020202020202020202067656F6D657472792E676574417272617928292E666F72456163682866756E6374696F6E286729207B0D0A202020202020202020202020202020205F746869732E5F7072';
wwv_flow_api.g_varchar2_table(430) := '6F63657373506F696E747328672C2063616C6C6261636B2C2074686973417267293B0D0A2020202020202020202020207D293B0D0A20202020202020207D0D0A202020207D2C0D0A0D0A202020205F6C6F616447656F4A736F6E203A2066756E6374696F';
wwv_flow_api.g_varchar2_table(431) := '6E202867656F6A736F6E2C2066696C656E616D652C206F7074696F6E7329207B0D0A2020202020202020617065782E646562756728225F6C6F616447656F4A736F6E222C2067656F6A736F6E293B0D0A0D0A20202020202020202F2F2072656E64657220';
wwv_flow_api.g_varchar2_table(432) := '746865206665617475726573206F6E20746865206D61700D0A20202020202020206C6574206665617475726573203D20746869732E6D61702E646174612E61646447656F4A736F6E2867656F6A736F6E2C206F7074696F6E73293B0D0A0D0A2020202020';
wwv_flow_api.g_varchar2_table(433) := '2020202F2F5570646174652061206D617027732076696577706F727420746F2066697420656163682067656F6D6574727920696E206120646174617365740D0A2020202020202020766172205F74686973203D20746869733B0D0A202020202020202074';
wwv_flow_api.g_varchar2_table(434) := '6869732E6D61702E646174612E666F72456163682866756E6374696F6E286665617475726529207B0D0A2020202020202020202020205F746869732E5F70726F63657373506F696E747328666561747572652E67657447656F6D6574727928292C205F74';
wwv_flow_api.g_varchar2_table(435) := '6869732E626F756E64732E657874656E642C205F746869732E626F756E6473293B0D0A20202020202020207D293B0D0A202020202020202069662028746869732E6F7074696F6E732E6175746F466974426F756E647329207B0D0A202020202020202020';
wwv_flow_api.g_varchar2_table(436) := '202020746869732E6D61702E666974426F756E647328746869732E626F756E6473293B0D0A20202020202020207D0D0A0D0A2020202020202020617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E747269';
wwv_flow_api.g_varchar2_table(437) := '6767657228226C6F6164656467656F6A736F6E222C207B0D0A2020202020202020202020206D61702020202020203A20746869732E6D61702C0D0A20202020202020202020202067656F4A736F6E20203A2067656F6A736F6E2C0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(438) := '202020206665617475726573203A2066656174757265732C0D0A20202020202020202020202066696C656E616D65203A2066696C656E616D650D0A20202020202020207D293B0D0A202020207D2C0D0A0D0A202020206C6F616447656F4A736F6E537472';
wwv_flow_api.g_varchar2_table(439) := '696E67203A2066756E6374696F6E202867656F537472696E672C2066696C656E616D6529207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E6C6F616447656F4A736F6E537472696E67222C2067656F537472696E672C';
wwv_flow_api.g_varchar2_table(440) := '2066696C656E616D65293B0D0A20202020202020206966202867656F537472696E6729207B0D0A2020202020202020202020207661722067656F6A736F6E203D204A534F4E2E70617273652867656F537472696E67293B0D0A2020202020202020202020';
wwv_flow_api.g_varchar2_table(441) := '20746869732E626F756E6473203D206E657720676F6F676C652E6D6170732E4C61744C6E67426F756E64733B0D0A202020202020202020202020746869732E5F6C6F616447656F4A736F6E2867656F6A736F6E2C2066696C656E616D65293B0D0A202020';
wwv_flow_api.g_varchar2_table(442) := '20202020207D0D0A202020207D2C0D0A0D0A202020205F696E69744472616744726F7047656F4A534F4E203A2066756E6374696F6E202829207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E5F696E69744472616744';
wwv_flow_api.g_varchar2_table(443) := '726F7047656F4A534F4E22293B0D0A2020202020202020766172205F74686973203D20746869733B0D0A20202020202020202F2F2073657420757020746865206472616720262064726F70206576656E74730D0A2020202020202020766172206D617043';
wwv_flow_api.g_varchar2_table(444) := '6F6E7461696E6572203D20646F63756D656E742E676574456C656D656E744279496428276D61705F272B746869732E6F7074696F6E732E726567696F6E4964292C0D0A20202020202020202020202064726F70436F6E7461696E6572203D20646F63756D';
wwv_flow_api.g_varchar2_table(445) := '656E742E676574456C656D656E7442794964282764726F705F272B746869732E6F7074696F6E732E726567696F6E4964293B0D0A0D0A20202020202020207661722073686F7750616E656C203D2066756E6374696F6E20286529207B0D0A202020202020';
wwv_flow_api.g_varchar2_table(446) := '20202020202020202020652E73746F7050726F7061676174696F6E28293B0D0A20202020202020202020202020202020652E70726576656E7444656661756C7428293B0D0A2020202020202020202020202020202064726F70436F6E7461696E65722E73';
wwv_flow_api.g_varchar2_table(447) := '74796C652E646973706C6179203D2027626C6F636B273B0D0A2020202020202020202020202020202072657475726E2066616C73653B0D0A2020202020202020202020207D3B0D0A0D0A20202020202020202F2F206D61702D7370656369666963206576';
wwv_flow_api.g_varchar2_table(448) := '656E74730D0A20202020202020206D6170436F6E7461696E65722E6164644576656E744C697374656E6572282764726167656E746572272C2073686F7750616E656C2C2066616C7365293B0D0A0D0A20202020202020202F2F206F7665726C6179207370';
wwv_flow_api.g_varchar2_table(449) := '656369666963206576656E7473202873696E6365206974206F6E6C792061707065617273206F6E6365206472616720737461727473290D0A202020202020202064726F70436F6E7461696E65722E6164644576656E744C697374656E6572282764726167';
wwv_flow_api.g_varchar2_table(450) := '6F766572272C2073686F7750616E656C2C2066616C7365293B0D0A0D0A202020202020202064726F70436F6E7461696E65722E6164644576656E744C697374656E65722827647261676C65617665272C2066756E6374696F6E2829207B0D0A2020202020';
wwv_flow_api.g_varchar2_table(451) := '2020202020202064726F70436F6E7461696E65722E7374796C652E646973706C6179203D20276E6F6E65273B0D0A20202020202020207D2C2066616C7365293B0D0A0D0A202020202020202064726F70436F6E7461696E65722E6164644576656E744C69';
wwv_flow_api.g_varchar2_table(452) := '7374656E6572282764726F70272C2066756E6374696F6E286529207B0D0A202020202020202020202020617065782E646562756728227265706F72746D61702E64726F70222C65293B0D0A202020202020202020202020652E70726576656E7444656661';
wwv_flow_api.g_varchar2_table(453) := '756C7428293B0D0A202020202020202020202020652E73746F7050726F7061676174696F6E28293B0D0A20202020202020202020202064726F70436F6E7461696E65722E7374796C652E646973706C6179203D20276E6F6E65273B0D0A0D0A2020202020';
wwv_flow_api.g_varchar2_table(454) := '202020202020207661722066696C6573203D20652E646174615472616E736665722E66696C65733B0D0A2020202020202020202020206966202866696C65732E6C656E67746829207B0D0A202020202020202020202020202020202F2F2070726F636573';
wwv_flow_api.g_varchar2_table(455) := '732066696C65287329206265696E672064726F707065640D0A202020202020202020202020202020202F2F2067726162207468652066696C6520646174612066726F6D20656163682066696C650D0A20202020202020202020202020202020666F722028';
wwv_flow_api.g_varchar2_table(456) := '7661722069203D20302C2066696C653B2066696C65203D2066696C65735B695D3B20692B2B29207B0D0A202020202020202020202020202020202020202076617220726561646572203D206E65772046696C6552656164657228292C0D0A202020202020';
wwv_flow_api.g_varchar2_table(457) := '20202020202020202020202020202020202066696C656E616D65203D2066696C652E6E616D653B0D0A20202020202020202020202020202020202020207265616465722E6F6E6C6F6164203D2066756E6374696F6E286529207B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(458) := '202020202020202020202020202020205F746869732E6C6F616447656F4A736F6E537472696E6728652E7461726765742E726573756C742C2066696C656E616D65293B0D0A20202020202020202020202020202020202020207D3B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(459) := '202020202020202020202020207265616465722E6F6E6572726F72203D2066756E6374696F6E286529207B0D0A202020202020202020202020202020202020202020202020617065782E6572726F72282772656164696E67206661696C656427293B0D0A';
wwv_flow_api.g_varchar2_table(460) := '20202020202020202020202020202020202020207D3B0D0A20202020202020202020202020202020202020207265616465722E726561644173546578742866696C65293B0D0A202020202020202020202020202020207D0D0A2020202020202020202020';
wwv_flow_api.g_varchar2_table(461) := '207D20656C7365207B0D0A202020202020202020202020202020202F2F2070726F63657373206E6F6E2D66696C652028652E672E2074657874206F722068746D6C2920636F6E74656E74206265696E672064726F707065640D0A20202020202020202020';
wwv_flow_api.g_varchar2_table(462) := '2020202020202F2F20677261622074686520706C61696E20746578742076657273696F6E206F662074686520646174610D0A2020202020202020202020202020202076617220706C61696E54657874203D20652E646174615472616E736665722E676574';
wwv_flow_api.g_varchar2_table(463) := '446174612827746578742F706C61696E27293B0D0A2020202020202020202020202020202069662028706C61696E5465787429207B0D0A20202020202020202020202020202020202020205F746869732E6C6F616447656F4A736F6E537472696E672870';
wwv_flow_api.g_varchar2_table(464) := '6C61696E54657874293B0D0A202020202020202020202020202020207D0D0A2020202020202020202020207D0D0A0D0A2020202020202020202020202F2F2070726576656E742064726167206576656E742066726F6D20627562626C696E672066757274';
wwv_flow_api.g_varchar2_table(465) := '6865720D0A20202020202020202020202072657475726E2066616C73653B0D0A20202020202020207D2C2066616C7365293B0D0A202020207D2C0D0A0D0A092F2A0D0A09202A0D0A09202A205554494C49544945530D0A09202A0D0A09202A2F0D0A0D0A';
wwv_flow_api.g_varchar2_table(466) := '095F696E697444656275673A2066756E6374696F6E2829207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E5F696E6974446562756722293B0D0A2020202020202020766172205F74686973203D20746869733B0D0A0D';
wwv_flow_api.g_varchar2_table(467) := '0A202020202020202076617220636F6E74726F6C5549203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0D0A2020202020202020636F6E74726F6C55492E636C6173734E616D65203D20277265706F72746D61702D6465';
wwv_flow_api.g_varchar2_table(468) := '62756750616E656C273B0D0A2020202020202020636F6E74726F6C55492E696E6E657248544D4C203D20275B6465627567206D6F64655D273B0D0A2020202020202020746869732E6D61702E636F6E74726F6C735B676F6F676C652E6D6170732E436F6E';
wwv_flow_api.g_varchar2_table(469) := '74726F6C506F736974696F6E2E424F54544F4D5F4C4546545D2E7075736828636F6E74726F6C5549293B0D0A0D0A20202020202020202F2F206173206D6F757365206973206D6F766564206F76657220746865206D61702C2073686F7720746865206375';
wwv_flow_api.g_varchar2_table(470) := '7272656E7420636F6F7264696E6174657320696E207468652064656275672070616E656C0D0A2020202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228746869732E6D61702C20226D6F7573656D6F7665222C2066';
wwv_flow_api.g_varchar2_table(471) := '756E6374696F6E20286576656E7429207B0D0A202020202020202020202020636F6E74726F6C55492E696E6E657248544D4C203D20276D6F75736520706F736974696F6E2027202B204A534F4E2E737472696E67696679286576656E742E6C61744C6E67';
wwv_flow_api.g_varchar2_table(472) := '293B0D0A20202020202020207D293B0D0A0D0A20202020202020202F2F206173206D61702069732070616E6E6564206F72207A6F6F6D65642C2073686F77207468652063757272656E74206D617020626F756E647320696E207468652064656275672070';
wwv_flow_api.g_varchar2_table(473) := '616E656C0D0A2020202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228746869732E6D61702C2022626F756E64735F6368616E676564222C2066756E6374696F6E20286576656E7429207B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(474) := '20202020636F6E74726F6C55492E696E6E657248544D4C203D20276D617020626F756E64732027202B204A534F4E2E737472696E67696679285F746869732E6D61702E676574426F756E64732829293B0D0A20202020202020207D293B0D0A202020207D';
wwv_flow_api.g_varchar2_table(475) := '2C0D0A0D0A202020205F67657457696E646F77506174683A2066756E6374696F6E2829207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E5F67657457696E646F775061746822293B0D0A20202020202020200D0A2020';
wwv_flow_api.g_varchar2_table(476) := '2020202020207661722070617468203D20746869732E6F7074696F6E732E706C7567696E5265736F75726365506174683B0D0A20202020202020200D0A2020202020202020696620287061746820213D3D20222229207B0D0A2020202020202020202020';
wwv_flow_api.g_varchar2_table(477) := '20617065782E646562756728225573696E6720737570706C69656420706C7567696E207265736F75726365207061746822293B0D0A20202020202020207D20656C7365207B0D0A0D0A20202020202020202020202070617468203D2077696E646F772E6C';
wwv_flow_api.g_varchar2_table(478) := '6F636174696F6E2E6F726967696E202B2077696E646F772E6C6F636174696F6E2E706174686E616D653B0D0A0D0A20202020202020202020202069662028706174682E696E6465784F6628222F6F7264732F722F2229203E202D3129207B0D0A20202020';
wwv_flow_api.g_varchar2_table(479) := '2020202020202020202020202F2F206861636B20746F2068616E646C6520686F7374656420636C6F756420696E7374616E63652055524C3F0D0A20202020202020202020202020202020617065782E64656275672822467269656E646C792055524C2064';
wwv_flow_api.g_varchar2_table(480) := '657465637465642028686F7374656420636C6F756429222C2070617468293B0D0A0D0A202020202020202020202020202020202F2F2045787065637465643A2068747470733A2F2F7072656669782E6164622E65752D6672616E6B667572742D312E6F72';
wwv_flow_api.g_varchar2_table(481) := '61636C65636C6F7564617070732E636F6D2F6F7264732F722F686D735F666972652F617070616C6961732F70616765616C6961733F73657373696F6E3D31323334350D0A0D0A202020202020202020202020202020202F2F207374726970206F66662065';
wwv_flow_api.g_varchar2_table(482) := '766572797468696E6720696E636C7564696E6720616E642061667465722074686520222F722F22206269740D0A2020202020202020202020202020202070617468203D20706174682E737562737472696E6728302C20706174682E6C617374496E646578';
wwv_flow_api.g_varchar2_table(483) := '4F6628222F722F2229293B0D0A0D0A202020202020202020202020202020202F2F206E6F7720697420697320736F6D657468696E67206C696B653A0D0A202020202020202020202020202020202F2F2068747470733A2F2F7072656669782E6164622E65';
wwv_flow_api.g_varchar2_table(484) := '752D6672616E6B667572742D312E6F7261636C65636C6F7564617070732E636F6D2F6F7264730D0A0D0A2020202020202020202020207D20656C73652069662028706174682E696E6465784F6628222F722F2229203E202D3129207B0D0A202020202020';
wwv_flow_api.g_varchar2_table(485) := '202020202020202020202F2F20467269656E646C792055524C7320696E207573650D0A20202020202020202020202020202020617065782E64656275672822467269656E646C792055524C206465746563746564222C2070617468293B0D0A0D0A202020';
wwv_flow_api.g_varchar2_table(486) := '202020202020202020202020202F2F2045787065637465643A2068747470733A2F2F617065782E6F7261636C652E636F6D2F706C732F617065782F6A6B36342F722F6A6B36345F7265706F72745F6D61705F6465762F636C7573746572696E670D0A0D0A';
wwv_flow_api.g_varchar2_table(487) := '202020202020202020202020202020202F2F207374726970206F66662065766572797468696E6720696E636C7564696E6720616E642061667465722074686520222F722F22206269740D0A2020202020202020202020202020202070617468203D207061';
wwv_flow_api.g_varchar2_table(488) := '74682E737562737472696E6728302C20706174682E6C617374496E6465784F6628222F722F2229293B0D0A0D0A202020202020202020202020202020202F2F206E6F7720697420697320736F6D657468696E67206C696B653A0D0A202020202020202020';
wwv_flow_api.g_varchar2_table(489) := '202020202020202F2F2068747470733A2F2F617065782E6F7261636C652E636F6D2F706C732F617065782F6A6B36340D0A0D0A202020202020202020202020202020202F2F207374726970206F6666207468652070617468207072656669780D0A202020';
wwv_flow_api.g_varchar2_table(490) := '2020202020202020202020202070617468203D20706174682E737562737472696E6728302C20706174682E6C617374496E6465784F6628222F2229293B0D0A0D0A202020202020202020202020202020202F2F206E6F7720697420697320736F6D657468';
wwv_flow_api.g_varchar2_table(491) := '696E67206C696B653A0D0A202020202020202020202020202020202F2F2068747470733A2F2F617065782E6F7261636C652E636F6D2F706C732F617065780D0A2020202020202020202020207D20656C7365207B0D0A2020202020202020202020202020';
wwv_flow_api.g_varchar2_table(492) := '20202F2F204C65676163792055524C7320696E207573650D0A20202020202020202020202020202020617065782E646562756728224C65676163792055524C206465746563746564222C2070617468293B0D0A0D0A202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(493) := '202F2F2045787065637465643A2068747470733A2F2F617065782E6F7261636C652E636F6D2F706C732F617065782F660D0A0D0A202020202020202020202020202020202F2F207374726970206F66662074686520222F6622206269740D0A2020202020';
wwv_flow_api.g_varchar2_table(494) := '202020202020202020202070617468203D20706174682E737562737472696E6728302C20706174682E6C617374496E6465784F6628222F2229293B0D0A0D0A202020202020202020202020202020202F2F206E6F7720697420697320736F6D657468696E';
wwv_flow_api.g_varchar2_table(495) := '67206C696B653A0D0A202020202020202020202020202020202F2F2068747470733A2F2F617065782E6F7261636C652E636F6D2F706C732F617065780D0A2020202020202020202020207D0D0A20202020202020207D0D0A0D0A20202020202020206170';
wwv_flow_api.g_varchar2_table(496) := '65782E6465627567282270617468222C2070617468293B0D0A0D0A202020202020202072657475726E20706174683B0D0A202020207D2C0D0A0D0A202020202F2F206164642061206C697374656E657220666F722065616368204D6170206576656E7420';
wwv_flow_api.g_varchar2_table(497) := '7468617420726169736573206120706C7567696E206576656E740D0A202020205F696E69744D61704576656E74733A2066756E6374696F6E2829207B0D0A2020202020202020766172205F74686973203D20746869733B0D0A0D0A20202020202020205B';
wwv_flow_api.g_varchar2_table(498) := '22626F756E64735F6368616E676564220D0A20202020202020202C2263656E7465725F6368616E676564220D0A20202020202020202C2268656164696E675F6368616E676564220D0A20202020202020202C2269646C65220D0A20202020202020202C22';
wwv_flow_api.g_varchar2_table(499) := '6D61707479706569645F6368616E676564220D0A20202020202020202C2270726F6A656374696F6E5F6368616E676564220D0A20202020202020202C2274696C65736C6F61646564220D0A20202020202020202C2274696C745F6368616E676564220D0A';
wwv_flow_api.g_varchar2_table(500) := '20202020202020202C227A6F6F6D5F6368616E676564220D0A20202020202020205D2E666F72456163682866756E6374696F6E286576656E744E616D6529207B0D0A202020202020202020202020617065782E64656275672822616464206C697374656E';
wwv_flow_api.g_varchar2_table(501) := '657220666F72206D617020222B6576656E744E616D65293B0D0A202020202020202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572285F746869732E6D61702C206576656E744E616D652C2066756E6374696F6E2829';
wwv_flow_api.g_varchar2_table(502) := '207B0D0A20202020202020202020202020202020617065782E646562756728226D617020222B6576656E744E616D65293B0D0A2020202020202020202020202020202076617220626F756E6473203D205F746869732E6D61702E676574426F756E647328';
wwv_flow_api.g_varchar2_table(503) := '293B0D0A20202020202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6170222B6576656E744E616D652C207B0D0A202020202020202020202020';
wwv_flow_api.g_varchar2_table(504) := '20202020202020206D6170202020202020203A205F746869732E6D61702C0D0A202020202020202020202020202020202020202063656E746572202020203A205F746869732E6D61702E67657443656E74657228292E746F4A534F4E28292C0D0A202020';
wwv_flow_api.g_varchar2_table(505) := '2020202020202020202020202020202020736F75746877657374203A20626F756E64732E676574536F7574685765737428292E746F4A534F4E28292C0D0A20202020202020202020202020202020202020206E6F72746865617374203A20626F756E6473';
wwv_flow_api.g_varchar2_table(506) := '2E6765744E6F7274684561737428292E746F4A534F4E28292C0D0A20202020202020202020202020202020202020207A6F6F6D2020202020203A205F746869732E6D61702E6765745A6F6F6D28292C0D0A20202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(507) := '2068656164696E672020203A205F746869732E6D61702E67657448656164696E6728292C0D0A202020202020202020202020202020202020202074696C742020202020203A205F746869732E6D61702E67657454696C7428292C0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(508) := '2020202020202020202020206D6170547970652020203A205F746869732E6D61702E6765744D617054797065496428290D0A202020202020202020202020202020207D293B0D0A2020202020202020202020207D293B0D0A20202020202020207D293B0D';
wwv_flow_api.g_varchar2_table(509) := '0A0D0A2020202020202020696628746869732E6F7074696F6E732E64657461696C65644D6F7573654576656E747329207B0D0A0D0A2020202020202020202020205B2264726167220D0A2020202020202020202020202C2264726167656E64220D0A2020';
wwv_flow_api.g_varchar2_table(510) := '202020202020202020202C22647261677374617274220D0A2020202020202020202020205D2E666F72456163682866756E6374696F6E286576656E744E616D6529207B0D0A20202020202020202020202020202020617065782E64656275672822616464';
wwv_flow_api.g_varchar2_table(511) := '206C697374656E657220666F72206D617020222B6576656E744E616D65293B0D0A20202020202020202020202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E6572285F746869732E6D61702C206576656E744E616D652C';
wwv_flow_api.g_varchar2_table(512) := '2066756E6374696F6E2829207B0D0A2020202020202020202020202020202020202020617065782E646562756728226D617020222B6576656E744E616D65293B0D0A202020202020202020202020202020202020202076617220626F756E6473203D205F';
wwv_flow_api.g_varchar2_table(513) := '746869732E6D61702E676574426F756E647328293B0D0A2020202020202020202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6170222B657665';
wwv_flow_api.g_varchar2_table(514) := '6E744E616D652C207B0D0A2020202020202020202020202020202020202020202020206D6170202020202020203A205F746869732E6D61702C0D0A20202020202020202020202020202020202020202020202063656E746572202020203A205F74686973';
wwv_flow_api.g_varchar2_table(515) := '2E6D61702E67657443656E74657228292E746F4A534F4E28292C0D0A202020202020202020202020202020202020202020202020736F75746877657374203A20626F756E64732E676574536F7574685765737428292E746F4A534F4E28292C0D0A202020';
wwv_flow_api.g_varchar2_table(516) := '2020202020202020202020202020202020202020206E6F72746865617374203A20626F756E64732E6765744E6F7274684561737428292E746F4A534F4E28292C0D0A2020202020202020202020202020202020202020202020207A6F6F6D202020202020';
wwv_flow_api.g_varchar2_table(517) := '3A205F746869732E6D61702E6765745A6F6F6D28292C0D0A20202020202020202020202020202020202020202020202068656164696E672020203A205F746869732E6D61702E67657448656164696E6728292C0D0A202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(518) := '20202020202020202074696C742020202020203A205F746869732E6D61702E67657454696C7428292C0D0A2020202020202020202020202020202020202020202020206D6170547970652020203A205F746869732E6D61702E6765744D61705479706549';
wwv_flow_api.g_varchar2_table(519) := '6428290D0A20202020202020202020202020202020202020207D293B0D0A202020202020202020202020202020207D293B0D0A2020202020202020202020207D293B0D0A0D0A2020202020202020202020202F2F207468657365206576656E7473206765';
wwv_flow_api.g_varchar2_table(520) := '742061204D61704D6F7573654576656E74206F626A6563740D0A2020202020202020202020205B22636F6E746578746D656E75220D0A2020202020202020202020202C2264626C636C69636B220D0A2020202020202020202020202C226D6F7573656D6F';
wwv_flow_api.g_varchar2_table(521) := '7665220D0A2020202020202020202020202C226D6F7573656F7574220D0A2020202020202020202020202C226D6F7573656F766572220D0A2020202020202020202020205D2E666F72456163682866756E6374696F6E286576656E744E616D6529207B0D';
wwv_flow_api.g_varchar2_table(522) := '0A20202020202020202020202020202020617065782E64656275672822616464206C697374656E657220666F72206D617020222B6576656E744E616D65293B0D0A20202020202020202020202020202020676F6F676C652E6D6170732E6576656E742E61';
wwv_flow_api.g_varchar2_table(523) := '64644C697374656E6572285F746869732E6D61702C206576656E744E616D652C2066756E6374696F6E286D61704D6F7573654576656E7429207B0D0A2020202020202020202020202020202020202020617065782E646562756728226D617020222B6576';
wwv_flow_api.g_varchar2_table(524) := '656E744E616D652C206D61704D6F7573654576656E742E6C61744C6E67293B0D0A2020202020202020202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E74726967676572';
wwv_flow_api.g_varchar2_table(525) := '28226D6170222B6576656E744E616D652C207B0D0A2020202020202020202020202020202020202020202020206D6170203A205F746869732E6D61702C0D0A2020202020202020202020202020202020202020202020206C6174203A206D61704D6F7573';
wwv_flow_api.g_varchar2_table(526) := '654576656E742E6C61744C6E672E6C617428292C0D0A2020202020202020202020202020202020202020202020206C6E67203A206D61704D6F7573654576656E742E6C61744C6E672E6C6E6728290D0A2020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(527) := '7D293B0D0A202020202020202020202020202020207D293B0D0A2020202020202020202020207D293B0D0A0D0A20202020202020207D0D0A0D0A2020202020202020617065782E64656275672822616464206C697374656E657220666F72206D61702063';
wwv_flow_api.g_varchar2_table(528) := '6C69636B22293B0D0A2020202020202020676F6F676C652E6D6170732E6576656E742E6164644C697374656E657228746869732E6D61702C2022636C69636B222C2066756E6374696F6E20286D61704D6F7573654576656E7429207B0D0A202020202020';
wwv_flow_api.g_varchar2_table(529) := '202020202020617065782E646562756728226D617020636C69636B222C206D61704D6F7573654576656E742E6C61744C6E67293B0D0A202020202020202020202020696620285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C2920';
wwv_flow_api.g_varchar2_table(530) := '7B0D0A20202020202020202020202020202020696620285F746869732E6F7074696F6E732E70616E4F6E436C69636B29207B0D0A20202020202020202020202020202020202020205F746869732E6D61702E70616E546F286D61704D6F7573654576656E';
wwv_flow_api.g_varchar2_table(531) := '742E6C61744C6E67293B0D0A202020202020202020202020202020207D0D0A202020202020202020202020202020205F746869732E6D61702E7365745A6F6F6D285F746869732E6F7074696F6E732E636C69636B5A6F6F6D4C6576656C293B0D0A202020';
wwv_flow_api.g_varchar2_table(532) := '2020202020202020207D0D0A202020202020202020202020617065782E6A5175657279282223222B5F746869732E6F7074696F6E732E726567696F6E4964292E7472696767657228226D6170636C69636B222C207B0D0A090909096D6170203A205F7468';
wwv_flow_api.g_varchar2_table(533) := '69732E6D61702C0D0A090909096C6174203A206D61704D6F7573654576656E742E6C61744C6E672E6C617428292C0D0A090909096C6E67203A206D61704D6F7573654576656E742E6C61744C6E672E6C6E6728290D0A0909097D293B0D0A202020202020';
wwv_flow_api.g_varchar2_table(534) := '20207D293B0D0A0D0A202020207D2C0D0A0D0A092F2A0D0A09202A0D0A09202A204D41494E0D0A09202A0D0A09202A2F0D0A0D0A202020202F2F2054686520636F6E7374727563746F720D0A202020205F6372656174653A2066756E6374696F6E282920';
wwv_flow_api.g_varchar2_table(535) := '7B0D0A2020202020202020617065782E646562756728227265706F72746D61702E5F637265617465222C20746869732E656C656D656E742E70726F70282269642229293B0D0A2020202020202020617065782E6465627567284A534F4E2E737472696E67';
wwv_flow_api.g_varchar2_table(536) := '69667928746869732E6F7074696F6E7329293B0D0A2020202020202020766172205F74686973203D20746869733B0D0A0D0A20202020202020202F2F20676574206162736F6C7574652055524C20666F72207468697320736974652C20696E636C756469';
wwv_flow_api.g_varchar2_table(537) := '6E67202F617065782F206F72202F6F7264732F20287468697320697320726571756972656420627920736F6D6520676F6F676C65206D6170732041504973290D0A2020202020202020746869732E696D616765507265666978203D20746869732E5F6765';
wwv_flow_api.g_varchar2_table(538) := '7457696E646F77506174682829202B20222F22202B20746869732E6F7074696F6E732E706C7567696E46696C65507265666978202B2022696D616765732F6D223B0D0A2020202020202020617065782E64656275672827696D616765507265666978272C';
wwv_flow_api.g_varchar2_table(539) := '20746869732E696D616765507265666978293B0D0A0D0A2020202020202020766172206D61704F7074696F6E73203D207B0D0A2020202020202020202020206D696E5A6F6F6D202020202020202020202020202020203A20746869732E6F7074696F6E73';
wwv_flow_api.g_varchar2_table(540) := '2E6D696E5A6F6F6D2C0D0A2020202020202020202020206D61785A6F6F6D202020202020202020202020202020203A20746869732E6F7074696F6E732E6D61785A6F6F6D2C0D0A2020202020202020202020207A6F6F6D20202020202020202020202020';
wwv_flow_api.g_varchar2_table(541) := '2020202020203A20746869732E6F7074696F6E732E696E697469616C5A6F6F6D2C0D0A20202020202020202020202063656E74657220202020202020202020202020202020203A20746869732E6F7074696F6E732E696E697469616C43656E7465722C0D';
wwv_flow_api.g_varchar2_table(542) := '0A2020202020202020202020206D617054797065496420202020202020202020202020203A20746869732E6F7074696F6E732E6D6170547970652C0D0A202020202020202020202020647261676761626C6520202020202020202020202020203A207468';
wwv_flow_api.g_varchar2_table(543) := '69732E6F7074696F6E732E616C6C6F7750616E2C0D0A2020202020202020202020207A6F6F6D436F6E74726F6C2020202020202020202020203A20746869732E6F7074696F6E732E616C6C6F775A6F6F6D2C0D0A2020202020202020202020207363726F';
wwv_flow_api.g_varchar2_table(544) := '6C6C776865656C2020202020202020202020203A20746869732E6F7074696F6E732E616C6C6F775A6F6F6D2C0D0A20202020202020202020202064697361626C65446F75626C65436C69636B5A6F6F6D203A202128746869732E6F7074696F6E732E616C';
wwv_flow_api.g_varchar2_table(545) := '6C6F775A6F6F6D292C0D0A2020202020202020202020206765737475726548616E646C696E6720202020202020203A20746869732E6F7074696F6E732E6765737475726548616E646C696E670D0A20202020202020207D3B0D0A0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(546) := '69662028746869732E6F7074696F6E732E6D61705374796C6529207B0D0A2020202020202020202020206D61704F7074696F6E732E7374796C6573203D20746869732E6F7074696F6E732E6D61705374796C653B0D0A20202020202020207D0D0A0D0A20';
wwv_flow_api.g_varchar2_table(547) := '20202020202020746869732E6D6170203D206E657720676F6F676C652E6D6170732E4D617028646F63756D656E742E676574456C656D656E744279496428746869732E656C656D656E742E70726F70282269642229292C6D61704F7074696F6E73293B0D';
wwv_flow_api.g_varchar2_table(548) := '0A0D0A202020202020202069662028746869732E6F7074696F6E732E76697375616C69736174696F6E3D3D22696E666F6C617965722229207B0D0A202020202020202020202020746869732E6F7074696F6E732E73686F7750696E73203D2066616C7365';
wwv_flow_api.g_varchar2_table(549) := '3B0D0A202020202020202020202020746869732E6F7074696F6E732E73686F77496E666F506F70757073203D2066616C73653B0D0A202020202020202020202020746869732E6F7074696F6E732E73686F77496E666F4C61796572203D20747275653B0D';
wwv_flow_api.g_varchar2_table(550) := '0A20202020202020207D0D0A0D0A202020202020202069662028746869732E6F7074696F6E732E696E6974466E29207B0D0A202020202020202020202020617065782E64656275672822696E69745F6A6176617363726970745F636F64652072756E6E69';
wwv_flow_api.g_varchar2_table(551) := '6E672E2E2E22293B0D0A2020202020202020202020202F2F696E736964652074686520696E697428292066756E6374696F6E2077652077616E742022746869732220746F20726566657220746F20746869730D0A20202020202020202020202074686973';
wwv_flow_api.g_varchar2_table(552) := '2E696E69743D746869732E6F7074696F6E732E696E6974466E3B0D0A202020202020202020202020746869732E696E697428293B0D0A202020202020202020202020746869732E696E69742E64656C6574653B0D0A202020202020202020202020617065';
wwv_flow_api.g_varchar2_table(553) := '782E64656275672822696E69745F6A6176617363726970745F636F64652066696E69736865642E22293B0D0A20202020202020207D0D0A0D0A2020202020202020746869732E5F696E6974466561747572657328293B0D0A0D0A20202020202020206966';
wwv_flow_api.g_varchar2_table(554) := '2028746869732E6F7074696F6E732E64726177696E674D6F64657329207B0D0A202020202020202020202020746869732E5F696E697444726177696E6728293B0D0A20202020202020207D0D0A0D0A202020202020202069662028746869732E6F707469';
wwv_flow_api.g_varchar2_table(555) := '6F6E732E6472616744726F7047656F4A534F4E29207B0D0A202020202020202020202020746869732E5F696E69744472616744726F7047656F4A534F4E28293B0D0A20202020202020207D0D0A0D0A202020202020202069662028617065782E64656275';
wwv_flow_api.g_varchar2_table(556) := '672E6765744C6576656C28293E3029207B0D0A202020202020202020202020746869732E5F696E6974446562756728293B0D0A20202020202020207D0D0A0D0A202020202020202069662028746869732E6F7074696F6E732E6578706563744461746129';
wwv_flow_api.g_varchar2_table(557) := '207B0D0A202020202020202020202020746869732E7265667265736828293B0D0A20202020202020207D0D0A0D0A2020202020202020746869732E5F696E69744D61704576656E747328293B0D0A0D0A2020202020202020617065782E6A517565727928';
wwv_flow_api.g_varchar2_table(558) := '2223222B746869732E6F7074696F6E732E726567696F6E4964292E62696E6428226170657872656672657368222C66756E6374696F6E28297B0D0A202020202020202020202020242822236D61705F222B5F746869732E6F7074696F6E732E726567696F';
wwv_flow_api.g_varchar2_table(559) := '6E4964292E7265706F72746D617028227265667265736822293B0D0A20202020202020207D293B0D0A0D0A20202020202020202F2F2070757420736F6D652075736566756C20696E666F20696E2074686520636F6E736F6C65206C6F6720666F72206465';
wwv_flow_api.g_varchar2_table(560) := '76656C6F7065727320746F20686176652066756E20776974680D0A202020202020202069662028617065782E64656275672E6765744C6576656C28293E3029207B0D0A0D0A2020202020202020202020202F2F207072657474792069742075702028666F';
wwv_flow_api.g_varchar2_table(561) := '722062726F7773657273207468617420737570706F72742074686973290D0A20202020202020202020202076617220636F6E736F6C655F637373203D2027666F6E742D73697A653A313870783B6261636B67726F756E642D636F6C6F723A233030373666';
wwv_flow_api.g_varchar2_table(562) := '663B636F6C6F723A77686974653B6C696E652D6865696768743A333070783B646973706C61793A626C6F636B3B70616464696E673A313070783B270D0A2020202020202020202020202020202C73616D706C655F636F6465203D2027242822236D61705F';
wwv_flow_api.g_varchar2_table(563) := '27202B205F746869732E6F7074696F6E732E726567696F6E4964202B202722292E7265706F72746D61702822696E7374616E636522292E6D6170273B0D0A0D0A202020202020202020202020617065782E6465627567282225635468616E6B20796F7520';
wwv_flow_api.g_varchar2_table(564) := '666F72207573696E6720746865206A6B3634205265706F7274204D617020706C7567696E215C6E220D0A202020202020202020202020202020202B2022546F206163636573732074686520476F6F676C65204D6170206F626A656374206F6E2074686973';
wwv_flow_api.g_varchar2_table(565) := '20706167652C207573653A5C6E220D0A202020202020202020202020202020202B2073616D706C655F636F6465202B20225C6E220D0A202020202020202020202020202020202B20224D6F726520696E666F3A2068747470733A2F2F6769746875622E63';
wwv_flow_api.g_varchar2_table(566) := '6F6D2F6A6566667265796B656D702F6A6B36342D706C7567696E2D7265706F72746D61702F77696B69222C0D0A20202020202020202020202020202020636F6E736F6C655F637373293B0D0A0D0A20202020202020207D0D0A0D0A202020202020202061';
wwv_flow_api.g_varchar2_table(567) := '7065782E646562756728227265706F72746D61702E5F6372656174652066696E697368656422293B0D0A202020207D2C0D0A0D0A202020205F6166746572526566726573683A2066756E6374696F6E2829207B0D0A2020202020202020617065782E6465';
wwv_flow_api.g_varchar2_table(568) := '62756728225F61667465725265667265736822293B0D0A0D0A202020202020202069662028746869732E7370696E6E657229207B0D0A202020202020202020202020617065782E6465627567282272656D6F7665207370696E6E657222293B0D0A202020';
wwv_flow_api.g_varchar2_table(569) := '202020202020202020746869732E7370696E6E65722E72656D6F766528293B0D0A20202020202020207D0D0A0D0A2020202020202020617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E74726967676572';
wwv_flow_api.g_varchar2_table(570) := '28226170657861667465727265667265736822293B0D0A0D0A20202020202020202F2F205472696767657220612063616C6C6261636B2F6576656E740D0A2020202020202020746869732E5F747269676765722820226368616E67652220293B0D0A2020';
wwv_flow_api.g_varchar2_table(571) := '20207D2C0D0A0D0A202020205F72656E646572506167653A2066756E6374696F6E2870446174612C207374617274526F7729207B0D0A2020202020202020617065782E646562756728225F72656E64657250616765222C207374617274526F77293B0D0A';
wwv_flow_api.g_varchar2_table(572) := '0D0A20202020202020206966202870446174612E6D61706461746129207B0D0A202020202020202020202020617065782E6465627567282270446174612E6D617064617461206C656E6774683A222C2070446174612E6D6170646174612E6C656E677468';
wwv_flow_api.g_varchar2_table(573) := '293B0D0A0D0A202020202020202020202020766172206572726F724D73673B0D0A0D0A2020202020202020202020202F2F2072656E64657220746865206D617020646174610D0A2020202020202020202020206966202870446174612E6D617064617461';
wwv_flow_api.g_varchar2_table(574) := '2E6C656E6774683E3029207B0D0A0D0A20202020202020202020202020202020666F7220287661722069203D20303B2069203C2070446174612E6D6170646174612E6C656E6774683B20692B2B29207B0D0A0D0A20202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(575) := '202020206966202870446174612E6D6170646174615B695D2E6572726F7229207B0D0A2020202020202020202020202020202020202020202020206572726F724D7367203D2070446174612E6D6170646174615B695D2E6572726F723B0D0A2020202020';
wwv_flow_api.g_varchar2_table(576) := '20202020202020202020202020202020202020627265616B3B0D0A20202020202020202020202020202020202020207D0D0A0D0A202020202020202020202020202020202020202076617220726F77203D2070446174612E6D6170646174615B695D3B0D';
wwv_flow_api.g_varchar2_table(577) := '0A0D0A202020202020202020202020202020202020202069662028746869732E6F7074696F6E732E76697375616C69736174696F6E3D3D22686561746D61702229207B0D0A2020202020202020202020202020202020202020202020202F2F2065616368';
wwv_flow_api.g_varchar2_table(578) := '20726F7720697320616E206172726179205B782C792C7765696768745D0D0A0D0A202020202020202020202020202020202020202020202020696628726F775B305D2626726F775B315D29207B0D0A202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(579) := '20202020202020746869732E626F756E64732E657874656E64287B6C61743A726F775B305D2C6C6E673A726F775B315D7D293B0D0A0D0A20202020202020202020202020202020202020202020202020202020746869732E77656967687465644C6F6361';
wwv_flow_api.g_varchar2_table(580) := '74696F6E732E70757368287B0D0A20202020202020202020202020202020202020202020202020202020202020206C6F636174696F6E3A6E657720676F6F676C652E6D6170732E4C61744C6E6728726F775B305D2C20726F775B315D292C0D0A20202020';
wwv_flow_api.g_varchar2_table(581) := '202020202020202020202020202020202020202020202020202020207765696768743A726F775B325D0D0A202020202020202020202020202020202020202020202020202020207D293B0D0A202020202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(582) := '7D0D0A0D0A20202020202020202020202020202020202020207D20656C73652069662028746869732E6F7074696F6E732E76697375616C69736174696F6E3D3D2267656F6A736F6E2229207B0D0A20202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(583) := '20202F2F2074686520646174612073686F756C64206861766520612047656F4A736F6E20646F63756D656E742C20616C6F6E672077697468206F7074696F6E616C206E616D652C20696420616E6420666C6578206669656C64730D0A2020202020202020';
wwv_flow_api.g_varchar2_table(584) := '202020202020202020202020202020202F2F20746865206E616D652C20696420616E6420666C6578206669656C64732077696C6C20626520616464656420746F207468652067656F4A736F6E2070726F706572746965730D0A2020202020202020202020';
wwv_flow_api.g_varchar2_table(585) := '202020202020202020202020202F2F2028616C7465726E61746976656C792C207468652067656F6A736F6E206D6967687420616C72656164792068617665207468652070726F7065727469657320656D62656464656420696E206974290D0A0D0A202020';
wwv_flow_api.g_varchar2_table(586) := '2020202020202020202020202020202020202020207661722070726F70657274696573203D207B7D3B0D0A0D0A20202020202020202020202020202020202020202020202069662028726F772E6E29207B0D0A2020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(587) := '202020202020202020202070726F706572746965732E6E616D65203D20726F772E6E3B0D0A2020202020202020202020202020202020202020202020207D0D0A0D0A20202020202020202020202020202020202020202020202069662028726F772E6429';
wwv_flow_api.g_varchar2_table(588) := '207B0D0A2020202020202020202020202020202020202020202020202020202070726F706572746965732E6964203D20726F772E643B0D0A2020202020202020202020202020202020202020202020207D0D0A0D0A202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(589) := '20202020202020202069662028726F772E6629207B0D0A20202020202020202020202020202020202020202020202020202020666F722028766172206A203D20313B206A203C3D2031303B206A2B2B29207B0D0A20202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(590) := '2020202020202020202020202020202069662028726F772E665B2261222B6A5D29207B0D0A2020202020202020202020202020202020202020202020202020202020202020202020202F2F6174747230312E2E6174747231300D0A202020202020202020';
wwv_flow_api.g_varchar2_table(591) := '20202020202020202020202020202020202020202020202020202070726F706572746965735B2261747472222B282730272B6A292E736C696365282D32295D203D20726F772E665B2261222B6A5D3B0D0A20202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(592) := '202020202020202020202020207D0D0A202020202020202020202020202020202020202020202020202020207D0D0A2020202020202020202020202020202020202020202020207D0D0A0D0A202020202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(593) := '242E657874656E6428726F772E67656F6A736F6E2C207B2270726F70657274696573223A70726F706572746965737D293B0D0A0D0A202020202020202020202020202020202020202020202020746869732E5F6C6F616447656F4A736F6E28726F772E67';
wwv_flow_api.g_varchar2_table(594) := '656F6A736F6E2C206E756C6C2C207B22696450726F70657274794E616D65223A226964227D293B0D0A0D0A20202020202020202020202020202020202020207D20656C7365207B0D0A2020202020202020202020202020202020202020202020202F2F20';
wwv_flow_api.g_varchar2_table(595) := '6561636820726F7720697320612070696E20696E666F20737472756374757265207769746820782C20792C206574632E20617474726962757465730D0A0D0A202020202020202020202020202020202020202020202020696628726F772E782626726F77';
wwv_flow_api.g_varchar2_table(596) := '2E7929207B0D0A20202020202020202020202020202020202020202020202020202020746869732E626F756E64732E657874656E64287B6C61743A726F772E782C6C6E673A726F772E797D293B0D0A0D0A20202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(597) := '202020202020202020766172206D61726B6572203D20746869732E5F6E65774D61726B657228726F77293B0D0A0D0A202020202020202020202020202020202020202020202020202020202F2F2070757420746865206D61726B657220696E746F207468';
wwv_flow_api.g_varchar2_table(598) := '65206172726179206F66206D61726B6572730D0A20202020202020202020202020202020202020202020202020202020746869732E6D61726B6572732E70757368286D61726B6572293B0D0A0D0A20202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(599) := '20202020202069662028726F772E6429207B0D0A20202020202020202020202020202020202020202020202020202020202020202F2F20616C736F207075742074686520696420696E746F20746865204944204D61700D0A202020202020202020202020';
wwv_flow_api.g_varchar2_table(600) := '2020202020202020202020202020202020202020746869732E6E657749644D61702E73657428726F772E642C2069293B0D0A202020202020202020202020202020202020202020202020202020207D0D0A20202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(601) := '20202020207D0D0A20202020202020202020202020202020202020207D0D0A202020202020202020202020202020207D0D0A0D0A2020202020202020202020202020202069662028746869732E6F7074696F6E732E6175746F466974426F756E64732920';
wwv_flow_api.g_varchar2_table(602) := '7B0D0A0D0A2020202020202020202020202020202020202020617065782E64656275672822666974426F756E6473222C0D0A202020202020202020202020202020202020202020202020746869732E626F756E64732E676574536F757468576573742829';
wwv_flow_api.g_varchar2_table(603) := '2E746F4A534F4E28292C0D0A202020202020202020202020202020202020202020202020746869732E626F756E64732E6765744E6F7274684561737428292E746F4A534F4E2829293B0D0A0D0A2020202020202020202020202020202020202020746869';
wwv_flow_api.g_varchar2_table(604) := '732E6D61702E666974426F756E647328746869732E626F756E6473293B0D0A0D0A202020202020202020202020202020207D0D0A0D0A20202020202020202020202020202020746869732E746F74616C526F7773202B3D2070446174612E6D6170646174';
wwv_flow_api.g_varchar2_table(605) := '612E6C656E6774683B0D0A0D0A2020202020202020202020207D0D0A0D0A202020202020202020202020696620286572726F724D736729207B0D0A0D0A20202020202020202020202020202020617065782E64656275672E6572726F72286572726F724D';
wwv_flow_api.g_varchar2_table(606) := '7367293B0D0A20202020202020202020202020202020746869732E73686F774D657373616765286572726F724D7367293B0D0A0D0A2020202020202020202020202020202064656C65746520746869732E6E657749644D61703B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(607) := '2020202020202020746869732E5F61667465725265667265736828293B0D0A0D0A2020202020202020202020207D20656C7365206966202828746869732E746F74616C526F7773203C20746869732E6F7074696F6E732E6D6178696D756D526F7773290D';
wwv_flow_api.g_varchar2_table(608) := '0A202020202020202020202020202020202626202870446174612E6D6170646174612E6C656E677468203D3D20746869732E6F7074696F6E732E726F777350657242617463682929207B0D0A202020202020202020202020202020202F2F206765742074';
wwv_flow_api.g_varchar2_table(609) := '6865206E6578742070616765206F6620646174610D0A0D0A20202020202020202020202020202020617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E74726967676572280D0A2020202020202020202020';
wwv_flow_api.g_varchar2_table(610) := '2020202020202020202262617463686C6F61646564222C207B0D0A20202020202020202020202020202020202020206D6170202020202020203A20746869732E6D61702C0D0A2020202020202020202020202020202020202020636F756E7450696E7320';
wwv_flow_api.g_varchar2_table(611) := '3A20746869732E746F74616C526F77732C0D0A2020202020202020202020202020202020202020736F75746877657374203A20746869732E626F756E64732E676574536F7574685765737428292E746F4A534F4E28292C0D0A2020202020202020202020';
wwv_flow_api.g_varchar2_table(612) := '2020202020202020206E6F72746865617374203A20746869732E626F756E64732E6765744E6F7274684561737428292E746F4A534F4E28290D0A202020202020202020202020202020207D293B0D0A0D0A20202020202020202020202020202020737461';
wwv_flow_api.g_varchar2_table(613) := '7274526F77202B3D20746869732E6F7074696F6E732E726F777350657242617463683B0D0A0D0A2020202020202020202020202020202076617220626174636853697A65203D20746869732E6F7074696F6E732E726F777350657242617463683B0D0A0D';
wwv_flow_api.g_varchar2_table(614) := '0A202020202020202020202020202020202F2F20646F6E27742065786365656420746865206D6178696D756D20726F77730D0A2020202020202020202020202020202069662028746869732E746F74616C526F7773202B20626174636853697A65203E20';
wwv_flow_api.g_varchar2_table(615) := '746869732E6F7074696F6E732E6D6178696D756D526F777329207B0D0A2020202020202020202020202020202020202020626174636853697A65203D20746869732E6F7074696F6E732E6D6178696D756D526F7773202D20746869732E746F74616C526F';
wwv_flow_api.g_varchar2_table(616) := '77733B0D0A202020202020202020202020202020207D0D0A0D0A20202020202020202020202020202020766172205F74686973203D20746869733B0D0A0D0A20202020202020202020202020202020617065782E7365727665722E706C7567696E280D0A';
wwv_flow_api.g_varchar2_table(617) := '2020202020202020202020202020202020202020746869732E6F7074696F6E732E616A61784964656E7469666965722C0D0A20202020202020202020202020202020202020207B20706167654974656D73203A20746869732E6F7074696F6E732E616A61';
wwv_flow_api.g_varchar2_table(618) := '784974656D732C0D0A20202020202020202020202020202020202020202020783031202020202020203A207374617274526F772C0D0A20202020202020202020202020202020202020202020783032202020202020203A20626174636853697A650D0A20';
wwv_flow_api.g_varchar2_table(619) := '202020202020202020202020202020202020207D2C0D0A20202020202020202020202020202020202020207B206461746154797065203A20226A736F6E222C0D0A20202020202020202020202020202020202020202020737563636573733A2066756E63';
wwv_flow_api.g_varchar2_table(620) := '74696F6E28704461746129207B0D0A2020202020202020202020202020202020202020202020202020617065782E646562756728226E65787420626174636820726563656976656422293B0D0A2020202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(621) := '2020205F746869732E5F72656E646572506167652870446174612C207374617274526F77293B0D0A202020202020202020202020202020202020202020207D0D0A20202020202020202020202020202020202020207D293B0D0A0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(622) := '202020207D20656C7365207B0D0A202020202020202020202020202020202F2F206E6F206D6F7265206461746120746F2072656E6465722C2066696E6973682072656E646572696E670D0A0D0A2020202020202020202020202020202069662028746869';
wwv_flow_api.g_varchar2_table(623) := '732E746F74616C526F7773203D3D203029207B0D0A0D0A202020202020202020202020202020202020202064656C65746520746869732E69644D61703B0D0A0D0A202020202020202020202020202020202020202069662028746869732E6F7074696F6E';
wwv_flow_api.g_varchar2_table(624) := '732E6E6F446174614D65737361676520213D3D20222229207B0D0A202020202020202020202020202020202020202020202020617065782E6465627567282273686F77204E6F204461746120466F756E6420696E666F77696E646F7722293B0D0A202020';
wwv_flow_api.g_varchar2_table(625) := '202020202020202020202020202020202020202020746869732E73686F774D65737361676528746869732E6F7074696F6E732E6E6F446174614D657373616765293B0D0A20202020202020202020202020202020202020207D0D0A0D0A20202020202020';
wwv_flow_api.g_varchar2_table(626) := '2020202020202020207D20656C7365207B0D0A0D0A20202020202020202020202020202020202020207377697463682028746869732E6F7074696F6E732E76697375616C69736174696F6E29207B0D0A2020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(627) := '636173652022646972656374696F6E73223A0D0A202020202020202020202020202020202020202020202020746869732E5F646972656374696F6E7328293B0D0A0D0A202020202020202020202020202020202020202020202020627265616B3B0D0A20';
wwv_flow_api.g_varchar2_table(628) := '20202020202020202020202020202020202020636173652022636C7573746572223A0D0A2020202020202020202020202020202020202020202020202F2F204D6F726520696E666F3A2068747470733A2F2F646576656C6F706572732E676F6F676C652E';
wwv_flow_api.g_varchar2_table(629) := '636F6D2F6D6170732F646F63756D656E746174696F6E2F6A6176617363726970742F6D61726B65722D636C7573746572696E670D0A0D0A20202020202020202020202020202020202020202020202069662028746869732E6D61726B6572436C75737465';
wwv_flow_api.g_varchar2_table(630) := '72657229207B0D0A20202020202020202020202020202020202020202020202020202020617065782E646562756728226D61726B6572436C757374657265722E636C6561724D61726B65727322293B0D0A20202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(631) := '202020202020202020746869732E6D61726B6572436C757374657265722E636C6561724D61726B65727328293B0D0A2020202020202020202020202020202020202020202020207D0D0A0D0A202020202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(632) := '617065782E64656275672822637265617465206D61726B6572436C7573746572657222293B0D0A202020202020202020202020202020202020202020202020746869732E6D61726B6572436C75737465726572203D206E6577204D61726B6572436C7573';
wwv_flow_api.g_varchar2_table(633) := '746572657228746869732E6D61702C20746869732E6D61726B6572732C207B696D616765506174683A746869732E696D6167655072656669787D293B0D0A0D0A202020202020202020202020202020202020202020202020627265616B3B0D0A20202020';
wwv_flow_api.g_varchar2_table(634) := '2020202020202020202020202020202063617365202273706964657266696572223A0D0A202020202020202020202020202020202020202020202020746869732E5F737069646572667928293B0D0A0D0A20202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(635) := '2020202020627265616B3B0D0A2020202020202020202020202020202020202020636173652022686561746D6170223A0D0A0D0A20202020202020202020202020202020202020202020202069662028746869732E686561746D61704C6179657229207B';
wwv_flow_api.g_varchar2_table(636) := '0D0A20202020202020202020202020202020202020202020202020202020617065782E6465627567282272656D6F766520686561746D61704C6179657222293B0D0A20202020202020202020202020202020202020202020202020202020746869732E68';
wwv_flow_api.g_varchar2_table(637) := '6561746D61704C617965722E7365744D6170286E756C6C293B0D0A20202020202020202020202020202020202020202020202020202020746869732E686561746D61704C617965722E64656C6574653B0D0A202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(638) := '2020202020207D0D0A0D0A202020202020202020202020202020202020202020202020746869732E686561746D61704C61796572203D206E657720676F6F676C652E6D6170732E76697375616C697A6174696F6E2E486561746D61704C61796572287B0D';
wwv_flow_api.g_varchar2_table(639) := '0A202020202020202020202020202020202020202020202020202020206461746120202020202020203A20746869732E77656967687465644C6F636174696F6E732C0D0A202020202020202020202020202020202020202020202020202020206D617020';
wwv_flow_api.g_varchar2_table(640) := '20202020202020203A20746869732E6D61702C0D0A202020202020202020202020202020202020202020202020202020206469737369706174696E67203A20746869732E6F7074696F6E732E686561746D61704469737369706174696E672C0D0A202020';
wwv_flow_api.g_varchar2_table(641) := '202020202020202020202020202020202020202020202020206F70616369747920202020203A20746869732E6F7074696F6E732E686561746D61704F7061636974792C0D0A20202020202020202020202020202020202020202020202020202020726164';
wwv_flow_api.g_varchar2_table(642) := '6975732020202020203A20746869732E6F7074696F6E732E686561746D61705261646975730D0A2020202020202020202020202020202020202020202020207D293B0D0A0D0A202020202020202020202020202020202020202020202020746869732E77';
wwv_flow_api.g_varchar2_table(643) := '656967687465644C6F636174696F6E732E64656C6574653B0D0A0D0A202020202020202020202020202020202020202020202020627265616B3B0D0A20202020202020202020202020202020202020207D0D0A0D0A202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(644) := '207D0D0A0D0A20202020202020202020202020202020617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E74726967676572280D0A202020202020202020202020202020202020202028746869732E6D6170';
wwv_flow_api.g_varchar2_table(645) := '6C6F616465643F226D6170726566726573686564223A226D61706C6F6164656422292C207B0D0A20202020202020202020202020202020202020206D6170202020202020203A20746869732E6D61702C0D0A202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(646) := '2020636F756E7450696E73203A20746869732E746F74616C526F77732C0D0A2020202020202020202020202020202020202020736F75746877657374203A20746869732E626F756E64732E676574536F7574685765737428292E746F4A534F4E28292C0D';
wwv_flow_api.g_varchar2_table(647) := '0A20202020202020202020202020202020202020206E6F72746865617374203A20746869732E626F756E64732E6765744E6F7274684561737428292E746F4A534F4E28290D0A202020202020202020202020202020207D293B0D0A0D0A20202020202020';
wwv_flow_api.g_varchar2_table(648) := '202020202020202020746869732E6D61706C6F61646564203D20747275653B0D0A0D0A202020202020202020202020202020202F2F2072656D656D656D62657220746865204944204D617020666F7220746865206E65787420726566726573680D0A2020';
wwv_flow_api.g_varchar2_table(649) := '2020202020202020202020202020746869732E69644D6170203D20746869732E6E657749644D61703B0D0A2020202020202020202020202020202064656C65746520746869732E6E657749644D61703B0D0A0D0A20202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(650) := '746869732E5F61667465725265667265736828293B0D0A2020202020202020202020207D0D0A0D0A20202020202020207D20656C7365207B0D0A202020202020202020202020746869732E5F61667465725265667265736828293B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(651) := '207D0D0A0D0A202020207D2C0D0A0D0A202020202F2F2043616C6C6564207768656E20637265617465642C206F72206966207468652072656672657368206576656E742069732063616C6C65640D0A20202020726566726573683A2066756E6374696F6E';
wwv_flow_api.g_varchar2_table(652) := '2829207B0D0A2020202020202020617065782E646562756728227265706F72746D61702E7265667265736822293B0D0A2020202020202020746869732E686964654D65737361676528293B0D0A202020202020202069662028746869732E6F7074696F6E';
wwv_flow_api.g_varchar2_table(653) := '732E6578706563744461746129207B0D0A202020202020202020202020617065782E6A5175657279282223222B746869732E6F7074696F6E732E726567696F6E4964292E747269676765722822617065786265666F72657265667265736822293B0D0A0D';
wwv_flow_api.g_varchar2_table(654) := '0A20202020202020202020202069662028746869732E6F7074696F6E732E73686F775370696E6E657229207B0D0A2020202020202020202020202020202069662028746869732E7370696E6E657229207B0D0A2020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(655) := '202020746869732E7370696E6E65722E72656D6F766528293B0D0A202020202020202020202020202020207D0D0A20202020202020202020202020202020617065782E6465627567282273686F77207370696E6E657222293B0D0A202020202020202020';
wwv_flow_api.g_varchar2_table(656) := '20202020202020746869732E7370696E6E6572203D20617065782E7574696C2E73686F775370696E6E65722824282223222B746869732E6F7074696F6E732E726567696F6E496429293B0D0A2020202020202020202020207D0D0A0D0A20202020202020';
wwv_flow_api.g_varchar2_table(657) := '2020202020766172205F74686973203D20746869732C0D0A20202020202020202020202020202020626174636853697A65203D20746869732E6F7074696F6E732E726F777350657242617463683B0D0A0D0A202020202020202020202020696620287468';
wwv_flow_api.g_varchar2_table(658) := '69732E6F7074696F6E732E6D6178696D756D526F7773203C20626174636853697A6529207B0D0A20202020202020202020202020202020626174636853697A65203D20746869732E6F7074696F6E732E6D6178696D756D526F77733B0D0A202020202020';
wwv_flow_api.g_varchar2_table(659) := '2020202020207D0D0A0D0A202020202020202020202020617065782E7365727665722E706C7567696E280D0A20202020202020202020202020202020746869732E6F7074696F6E732E616A61784964656E7469666965722C0D0A20202020202020202020';
wwv_flow_api.g_varchar2_table(660) := '2020202020207B20706167654974656D73203A20746869732E6F7074696F6E732E616A61784974656D732C0D0A202020202020202020202020202020202020783031202020202020203A20312C0D0A202020202020202020202020202020202020783032';
wwv_flow_api.g_varchar2_table(661) := '202020202020203A20626174636853697A650D0A202020202020202020202020202020207D2C0D0A202020202020202020202020202020207B206461746154797065203A20226A736F6E222C0D0A20202020202020202020202020202020202073756363';
wwv_flow_api.g_varchar2_table(662) := '6573733A2066756E6374696F6E28704461746129207B0D0A20202020202020202020202020202020202020202020617065782E64656275672822666972737420626174636820726563656976656422293B0D0A0D0A202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(663) := '202020202020205F746869732E5F72656D6F76654D61726B65727328293B0D0A0D0A202020202020202020202020202020202020202020205F746869732E77656967687465644C6F636174696F6E73203D205B5D3B0D0A20202020202020202020202020';
wwv_flow_api.g_varchar2_table(664) := '2020202020202020205F746869732E6D61726B657273203D205B5D3B0D0A202020202020202020202020202020202020202020205F746869732E626F756E6473203D206E657720676F6F676C652E6D6170732E4C61744C6E67426F756E64733B0D0A0D0A';
wwv_flow_api.g_varchar2_table(665) := '202020202020202020202020202020202020202020202F2F2069644D617020697320612064617461206D6170206F6620696420746F20746865206461746120666F7220612070696E0D0A202020202020202020202020202020202020202020205F746869';
wwv_flow_api.g_varchar2_table(666) := '732E6E657749644D6170203D206E6577204D617028293B0D0A0D0A2020202020202020202020202020202020202020202020206966202870446174612E6D617064617461262670446174612E6D6170646174615B305D262670446174612E6D6170646174';
wwv_flow_api.g_varchar2_table(667) := '615B305D2E6572726F7229207B0D0A0D0A202020202020202020202020202020202020202020202020202020205F746869732E73686F774D6573736167652870446174612E6D6170646174615B305D2E6572726F72293B0D0A2020202020202020202020';
wwv_flow_api.g_varchar2_table(668) := '20202020202020202020202020202020205F746869732E5F61667465725265667265736828293B0D0A0D0A2020202020202020202020202020202020202020202020207D20656C7365207B0D0A0D0A202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(669) := '202020202020205F746869732E5F72656E646572506167652870446174612C2031293B0D0A0D0A2020202020202020202020202020202020202020202020207D0D0A2020202020202020202020202020202020207D0D0A20202020202020202020202020';
wwv_flow_api.g_varchar2_table(670) := '2020207D293B0D0A20202020202020207D20656C7365207B0D0A202020202020202020202020746869732E5F61667465725265667265736828293B0D0A20202020202020207D0D0A202020207D2C0D0A0D0A202020202F2F204576656E747320626F756E';
wwv_flow_api.g_varchar2_table(671) := '6420766961205F6F6E206172652072656D6F766564206175746F6D61746963616C6C790D0A202020202F2F20726576657274206F74686572206D6F64696669636174696F6E7320686572650D0A202020205F64657374726F793A2066756E6374696F6E28';
wwv_flow_api.g_varchar2_table(672) := '29207B0D0A20202020202020202F2F2072656D6F76652067656E65726174656420656C656D656E74730D0A202020202020202069662028746869732E686561746D61704C6179657229207B20746869732E686561746D61704C617965722E72656D6F7665';
wwv_flow_api.g_varchar2_table(673) := '28293B207D0D0A202020202020202069662028746869732E7573657270696E29207B2064656C65746520746869732E7573657270696E3B207D0D0A202020202020202069662028746869732E646972656374696F6E73446973706C617929207B2064656C';
wwv_flow_api.g_varchar2_table(674) := '65746520746869732E646972656374696F6E73446973706C61793B207D0D0A202020202020202069662028746869732E646972656374696F6E735365727669636529207B2064656C65746520746869732E646972656374696F6E73536572766963653B20';
wwv_flow_api.g_varchar2_table(675) := '7D0D0A2020202020202020746869732E5F72656D6F76654D61726B65727328293B0D0A2020202020202020746869732E686964654D65737361676528293B0D0A2020202020202020746869732E6D61702E72656D6F766528293B0D0A202020207D2C0D0A';
wwv_flow_api.g_varchar2_table(676) := '0D0A202020202F2F205F7365744F7074696F6E732069732063616C6C6564207769746820612068617368206F6620616C6C206F7074696F6E73207468617420617265206368616E67696E670D0A202020202F2F20616C7761797320726566726573682077';
wwv_flow_api.g_varchar2_table(677) := '68656E206368616E67696E67206F7074696F6E730D0A202020205F7365744F7074696F6E733A2066756E6374696F6E2829207B0D0A20202020202020202F2F205F737570657220616E64205F73757065724170706C792068616E646C65206B656570696E';
wwv_flow_api.g_varchar2_table(678) := '672074686520726967687420746869732D636F6E746578740D0A2020202020202020746869732E5F73757065724170706C792820617267756D656E747320293B0D0A202020207D2C0D0A0D0A202020202F2F205F7365744F7074696F6E2069732063616C';
wwv_flow_api.g_varchar2_table(679) := '6C656420666F72206561636820696E646976696475616C206F7074696F6E2074686174206973206368616E67696E670D0A202020205F7365744F7074696F6E3A2066756E6374696F6E28206B65792C2076616C75652029207B0D0A202020202020202061';
wwv_flow_api.g_varchar2_table(680) := '7065782E6465627567286B65792C2076616C7565293B0D0A0D0A20202020202020202F2F20646576206E6F74653A20746F20676574206120626F6F6C65616E2066726F6D20612076616C7565207768696368206D69676874206265206120737472696E67';
wwv_flow_api.g_varchar2_table(681) := '0D0A20202020202020202F2F2028227472756522206F72202266616C73652229206F7220616C7265616479206120626F6F6C65616E2C207765207573652076616C75652B27273D3D2774727565270D0A202020202020202073776974636820286B657929';
wwv_flow_api.g_varchar2_table(682) := '207B0D0A2020202020202020636173652022636C69636B61626C6549636F6E73223A0D0A202020202020202020202020746869732E6D61702E7365744F7074696F6E73287B636C69636B61626C6549636F6E733A2876616C75652B27273D3D2774727565';
wwv_flow_api.g_varchar2_table(683) := '27297D293B0D0A0D0A202020202020202020202020627265616B3B0D0A202020202020202063617365202264697361626C6544656661756C745549223A0D0A202020202020202020202020746869732E6D61702E7365744F7074696F6E73287B64697361';
wwv_flow_api.g_varchar2_table(684) := '626C6544656661756C7455493A2876616C75652B27273D3D277472756527297D293B0D0A0D0A202020202020202020202020627265616B3B0D0A202020202020202063617365202266756C6C73637265656E436F6E74726F6C223A0D0A20202020202020';
wwv_flow_api.g_varchar2_table(685) := '2020202020746869732E6D61702E7365744F7074696F6E73287B66756C6C73637265656E436F6E74726F6C3A2876616C75652B27273D3D277472756527297D293B0D0A0D0A202020202020202020202020627265616B3B0D0A2020202020202020636173';
wwv_flow_api.g_varchar2_table(686) := '65202268656164696E67223A0D0A202020202020202020202020746869732E6D61702E7365744F7074696F6E73287B68656164696E673A7061727365496E742876616C7565297D293B0D0A0D0A202020202020202020202020627265616B3B0D0A202020';
wwv_flow_api.g_varchar2_table(687) := '20202020206361736520226B6579626F61726453686F727463757473223A0D0A202020202020202020202020746869732E6D61702E7365744F7074696F6E73287B6B6579626F61726453686F7274637574733A2876616C75652B27273D3D277472756527';
wwv_flow_api.g_varchar2_table(688) := '297D293B0D0A0D0A202020202020202020202020627265616B3B0D0A20202020202020206361736520226D617054797065223A0D0A202020202020202020202020746869732E6D61702E7365744D61705479706549642876616C75652E746F4C6F776572';
wwv_flow_api.g_varchar2_table(689) := '436173652829293B0D0A202020202020202020202020746869732E5F737570657228206B65792C2076616C756520293B0D0A0D0A202020202020202020202020627265616B3B0D0A20202020202020206361736520226D617054797065436F6E74726F6C';
wwv_flow_api.g_varchar2_table(690) := '223A0D0A202020202020202020202020746869732E6D61702E7365744F7074696F6E73287B6D617054797065436F6E74726F6C3A2876616C75652B27273D3D277472756527297D293B0D0A0D0A202020202020202020202020627265616B3B0D0A202020';
wwv_flow_api.g_varchar2_table(691) := '20202020206361736520226D61785A6F6F6D223A0D0A202020202020202020202020746869732E6D61702E7365744F7074696F6E73287B6D61785A6F6F6D3A7061727365496E742876616C7565297D293B0D0A202020202020202020202020746869732E';
wwv_flow_api.g_varchar2_table(692) := '5F737570657228206B65792C2076616C756520293B0D0A0D0A202020202020202020202020627265616B3B0D0A20202020202020206361736520226D696E5A6F6F6D223A0D0A202020202020202020202020746869732E6D61702E7365744F7074696F6E';
wwv_flow_api.g_varchar2_table(693) := '73287B6D696E5A6F6F6D3A7061727365496E742876616C7565297D293B0D0A202020202020202020202020746869732E5F737570657228206B65792C2076616C756520293B0D0A0D0A202020202020202020202020627265616B3B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(694) := '20636173652022726F74617465436F6E74726F6C223A0D0A202020202020202020202020746869732E6D61702E7365744F7074696F6E73287B726F74617465436F6E74726F6C3A2876616C75652B27273D3D277472756527297D293B0D0A0D0A20202020';
wwv_flow_api.g_varchar2_table(695) := '2020202020202020627265616B3B0D0A20202020202020206361736520227363616C65436F6E74726F6C223A0D0A202020202020202020202020746869732E6D61702E7365744F7074696F6E73287B7363616C65436F6E74726F6C3A2876616C75652B27';
wwv_flow_api.g_varchar2_table(696) := '273D3D277472756527297D293B0D0A0D0A202020202020202020202020627265616B3B0D0A202020202020202063617365202273747265657456696577436F6E74726F6C223A0D0A202020202020202020202020746869732E6D61702E7365744F707469';
wwv_flow_api.g_varchar2_table(697) := '6F6E73287B73747265657456696577436F6E74726F6C3A2876616C75652B27273D3D277472756527297D293B0D0A0D0A202020202020202020202020627265616B3B0D0A20202020202020206361736520227374796C6573223A0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(698) := '20202020746869732E6D61702E7365744F7074696F6E73287B7374796C65733A76616C75657D293B0D0A202020202020202020202020746869732E5F73757065722820226D61705374796C65222C2076616C756520293B0D0A0D0A202020202020202020';
wwv_flow_api.g_varchar2_table(699) := '202020627265616B3B0D0A20202020202020206361736520227A6F6F6D436F6E74726F6C223A0D0A202020202020202020202020746869732E6D61702E7365744F7074696F6E73287B7A6F6F6D436F6E74726F6C3A2876616C75652B27273D3D27747275';
wwv_flow_api.g_varchar2_table(700) := '6527297D293B0D0A0D0A202020202020202020202020627265616B3B0D0A202020202020202063617365202274696C74223A0D0A202020202020202020202020746869732E6D61702E73657454696C74287061727365496E742876616C756529293B0D0A';
wwv_flow_api.g_varchar2_table(701) := '0D0A202020202020202020202020627265616B3B0D0A20202020202020206361736520227A6F6F6D223A0D0A202020202020202020202020746869732E6D61702E7365745A6F6F6D287061727365496E742876616C756529293B0D0A0D0A202020202020';
wwv_flow_api.g_varchar2_table(702) := '202020202020627265616B3B0D0A202020202020202064656661756C743A0D0A202020202020202020202020746869732E5F737570657228206B65792C2076616C756520293B0D0A20202020202020207D0D0A202020207D0D0A0D0A20207D293B0D0A0D';
wwv_flow_api.g_varchar2_table(703) := '0A20202020636C617373204D61704F7665726C617920657874656E647320676F6F676C652E6D6170732E4F7665726C617956696577207B0D0A2020202020202020636F6E7374727563746F7228636F6E74656E742C206F7074696F6E7329207B0D0A2020';
wwv_flow_api.g_varchar2_table(704) := '20202020202020202020737570657228293B0D0A202020202020202020202020746869732E5F636F6E74656E74203D20636F6E74656E743B0D0A202020202020202020202020746869732E5F6F7074696F6E73203D206F7074696F6E733B0D0A20202020';
wwv_flow_api.g_varchar2_table(705) := '202020207D0D0A2020202020202020676574206F7074696F6E732829207B2072657475726E20746869732E5F6F7074696F6E733B207D0D0A2020202020202020736574206F7074696F6E73286F29207B20746869732E5F6F7074696F6E73203D206F3B20';
wwv_flow_api.g_varchar2_table(706) := '7D0D0A202020202020202067657420636F6E74656E742829207B2072657475726E20746869732E5F636F6E74656E743B207D0D0A202020202020202073657420636F6E74656E74286329207B20746869732E5F636F6E74656E74203D20633B207D0D0A20';
wwv_flow_api.g_varchar2_table(707) := '2020202020202067657420706F732829207B2072657475726E20746869732E5F6F7074696F6E732E706F733B207D0D0A202020202020202073657420706F73287029207B20746869732E5F6F7074696F6E732E706F73203D20703B207D0D0A2020202020';
wwv_flow_api.g_varchar2_table(708) := '20202067657420626F756E64732829207B2072657475726E20746869732E5F6F7074696F6E732E626F756E64733B207D0D0A202020202020202073657420626F756E6473286229207B20746869732E5F6F7074696F6E732E626F756E6473203D20623B20';
wwv_flow_api.g_varchar2_table(709) := '7D0D0A2020202020202020676574206469762829207B2072657475726E20746869732E5F6469763B207D0D0A20202020202020206F6E4164642829207B0D0A2020202020202020202020202F2F20746869732069732063616C6C6564207768656E207468';
wwv_flow_api.g_varchar2_table(710) := '65206D617027732070616E65732061726520726561647920616E6420746865206F7665726C617920686173206265656E20616464656420746F20746865206D61702E0D0A202020202020202020202020746869732E5F646976203D20646F63756D656E74';
wwv_flow_api.g_varchar2_table(711) := '2E637265617465456C656D656E74282264697622293B0D0A202020202020202020202020746869732E5F6469762E7374796C652E626F726465725374796C65203D20226E6F6E65223B0D0A202020202020202020202020746869732E5F6469762E737479';
wwv_flow_api.g_varchar2_table(712) := '6C652E626F726465725769647468203D2022307078223B0D0A202020202020202020202020746869732E5F6469762E7374796C652E706F736974696F6E203D20226162736F6C757465223B0D0A202020202020202020202020746869732E5F6469762E69';
wwv_flow_api.g_varchar2_table(713) := '6E6E657248544D4C203D20746869732E5F636F6E74656E743B0D0A2020202020202020202020202F2F2074686572652061726520352070616E6573207765206D61792061646420636F6E74656E7420746F202D2072656665723A2068747470733A2F2F64';
wwv_flow_api.g_varchar2_table(714) := '6576656C6F706572732E676F6F676C652E636F6D2F6D6170732F646F63756D656E746174696F6E2F6A6176617363726970742F7265666572656E63652F6F7665726C61792D76696577234D617050616E65730D0A202020202020202020202020636F6E73';
wwv_flow_api.g_varchar2_table(715) := '742070616E6573203D20746869732E67657450616E657328293B0D0A20202020202020202020202069662028746869732E5F6F7074696F6E732E6F6E436C69636B48616E646C657229207B0D0A202020202020202020202020202020202F2F206F766572';
wwv_flow_api.g_varchar2_table(716) := '6C61794D6F757365546172676574202870616E652033293A206F7665726C6179732074686174207265636569766520444F4D206576656E74730D0A202020202020202020202020202020202F2F2068747470733A2F2F737461636B6F766572666C6F772E';
wwv_flow_api.g_varchar2_table(717) := '636F6D2F7175657374696F6E732F333336313832332F6D616B652D637573746F6D2D6F7665726C61792D636C69636B61626C652D676F6F676C652D6D6170732D6170692D76330D0A2020202020202020202020202020202070616E65732E6F7665726C61';
wwv_flow_api.g_varchar2_table(718) := '794D6F7573655461726765742E617070656E644368696C6428746869732E5F646976293B0D0A20202020202020202020202020202020676F6F676C652E6D6170732E4F7665726C6179566965772E70726576656E744D61704869747346726F6D28746869';
wwv_flow_api.g_varchar2_table(719) := '732E5F646976293B0D0A20202020202020202020202020202020617065782E64656275672822616464206C697374656E657220666F72206F7665726C617920636C69636B22293B0D0A20202020202020202020202020202020676F6F676C652E6D617073';
wwv_flow_api.g_varchar2_table(720) := '2E6576656E742E616464446F6D4C697374656E657228746869732E5F6469762C2022636C69636B222C20746869732E5F6F7074696F6E732E6F6E436C69636B48616E646C6572293B0D0A2020202020202020202020207D20656C7365207B0D0A20202020';
wwv_flow_api.g_varchar2_table(721) := '2020202020202020202020202F2F206F7665726C61794C61796572202870616E652031293A206F7665726C617973207468617420646F206E6F74207265636569766520444F4D206576656E74730D0A2020202020202020202020202020202070616E6573';
wwv_flow_api.g_varchar2_table(722) := '2E6F7665726C61794C617965722E617070656E644368696C6428746869732E5F646976293B0D0A2020202020202020202020207D0D0A20202020202020207D0D0A2020202020202020647261772829207B0D0A2020202020202020202020206966202874';
wwv_flow_api.g_varchar2_table(723) := '6869732E5F64697629207B0D0A20202020202020202020202020202020636F6E7374206F7665726C617950726F6A656374696F6E203D20746869732E67657450726F6A656374696F6E28292C0D0A20202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(724) := '6D6170203D20746869732E6765744D617028292C0D0A202020202020202020202020202020202020202020207A6F6F6D203D206D61702E6765745A6F6F6D28293B0D0A2020202020202020202020202020202069662028287A6F6F6D203E3D2028746869';
wwv_flow_api.g_varchar2_table(725) := '732E5F6F7074696F6E732E6D696E5A6F6F6D7C7C30292920262620287A6F6F6D203C3D2028746869732E5F6F7074696F6E732E6D61785A6F6F6D7C7C3939292929207B0D0A202020202020202020202020202020202020202069662028746869732E5F6F';
wwv_flow_api.g_varchar2_table(726) := '7074696F6E732E626F756E647329207B0D0A202020202020202020202020202020202020202020202020636F6E7374207377203D206F7665726C617950726F6A656374696F6E2E66726F6D4C61744C6E67546F446976506978656C280D0A202020202020';
wwv_flow_api.g_varchar2_table(727) := '20202020202020202020202020202020202020202020746869732E5F6F7074696F6E732E626F756E64732E676574536F7574685765737428290D0A202020202020202020202020202020202020202020202020293B0D0A20202020202020202020202020';
wwv_flow_api.g_varchar2_table(728) := '2020202020202020202020636F6E7374206E65203D206F7665726C617950726F6A656374696F6E2E66726F6D4C61744C6E67546F446976506978656C280D0A20202020202020202020202020202020202020202020202020202020746869732E5F6F7074';
wwv_flow_api.g_varchar2_table(729) := '696F6E732E626F756E64732E6765744E6F7274684561737428290D0A202020202020202020202020202020202020202020202020293B0D0A2020202020202020202020202020202020202020202020202F2F20526573697A65207468652064697620746F';
wwv_flow_api.g_varchar2_table(730) := '206669742074686520696E646963617465642064696D656E73696F6E732E0D0A20202020202020202020202020202020202020202020202069662028746869732E5F64697629207B0D0A2020202020202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(731) := '2020746869732E5F6469762E7374796C652E6C656674203D2073772E78202B20227078223B0D0A20202020202020202020202020202020202020202020202020202020746869732E5F6469762E7374796C652E746F70203D206E652E79202B2022707822';
wwv_flow_api.g_varchar2_table(732) := '3B0D0A20202020202020202020202020202020202020202020202020202020746869732E5F6469762E7374796C652E7769647468203D20286E652E78202D2073772E7829202B20227078223B0D0A20202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(733) := '202020202020746869732E5F6469762E7374796C652E686569676874203D202873772E79202D206E652E7929202B20227078223B0D0A2020202020202020202020202020202020202020202020207D0D0A20202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(734) := '207D20656C73652069662028746869732E5F6F7074696F6E732E706F7329207B0D0A202020202020202020202020202020202020202020202020636F6E73742070726F6A506F73203D206F7665726C617950726F6A656374696F6E2E66726F6D4C61744C';
wwv_flow_api.g_varchar2_table(735) := '6E67546F446976506978656C28746869732E5F6F7074696F6E732E706F73293B0D0A202020202020202020202020202020202020202020202020766172206F6666736574582C206F6666736574593B0D0A20202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(736) := '202020202073776974636828746869732E5F6F7074696F6E732E686F72697A6F6E74616C416C69676E2E746F4C6F77657243617365282929207B0D0A20202020202020202020202020202020202020202020202063617365202763656E746572273A0D0A';
wwv_flow_api.g_varchar2_table(737) := '202020202020202020202020202020202020202020202020202020206F666673657458203D202D746869732E5F6469762E6F666673657457696474682F323B0D0A20202020202020202020202020202020202020202020202020202020627265616B3B0D';
wwv_flow_api.g_varchar2_table(738) := '0A2020202020202020202020202020202020202020202020206361736520277269676874273A0D0A202020202020202020202020202020202020202020202020202020206F666673657458203D202D746869732E5F6469762E6F66667365745769647468';
wwv_flow_api.g_varchar2_table(739) := '3B0D0A20202020202020202020202020202020202020202020202020202020627265616B3B0D0A20202020202020202020202020202020202020202020202064656661756C743A202F2F6C6566740D0A2020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(740) := '20202020202020206F666673657458203D20303B0D0A2020202020202020202020202020202020202020202020207D0D0A20202020202020202020202020202020202020202020202073776974636828746869732E5F6F7074696F6E732E766572746963';
wwv_flow_api.g_varchar2_table(741) := '616C416C69676E2E746F4C6F77657243617365282929207B0D0A202020202020202020202020202020202020202020202020636173652027626F74746F6D273A0D0A202020202020202020202020202020202020202020202020202020206F6666736574';
wwv_flow_api.g_varchar2_table(742) := '59203D202D746869732E5F6469762E6F66667365744865696768743B0D0A20202020202020202020202020202020202020202020202020202020627265616B3B0D0A2020202020202020202020202020202020202020202020206361736520276D696464';
wwv_flow_api.g_varchar2_table(743) := '6C65273A0D0A202020202020202020202020202020202020202020202020202020206F666673657459203D202D746869732E5F6469762E6F66667365744865696768742F323B0D0A20202020202020202020202020202020202020202020202020202020';
wwv_flow_api.g_varchar2_table(744) := '627265616B3B0D0A20202020202020202020202020202020202020202020202064656661756C743A202F2F746F700D0A202020202020202020202020202020202020202020202020202020206F666673657459203D20303B0D0A20202020202020202020';
wwv_flow_api.g_varchar2_table(745) := '20202020202020202020202020207D0D0A2020202020202020202020202020202020202020202020206F666673657458202B3D20746869732E5F6F7074696F6E732E686F72697A6F6E74616C4F66667365747C7C303B0D0A202020202020202020202020';
wwv_flow_api.g_varchar2_table(746) := '2020202020202020202020206F666673657459202B3D20746869732E5F6F7074696F6E732E766572746963616C4F66667365747C7C303B0D0A202020202020202020202020202020202020202020202020746869732E5F6469762E7374796C652E6C6566';
wwv_flow_api.g_varchar2_table(747) := '74203D202870726F6A506F732E78202B206F66667365745829202B20227078223B0D0A202020202020202020202020202020202020202020202020746869732E5F6469762E7374796C652E746F70203D202870726F6A506F732E79202B206F6666736574';
wwv_flow_api.g_varchar2_table(748) := '5929202B20227078223B0D0A20202020202020202020202020202020202020207D20656C7365207B0D0A202020202020202020202020202020202020202020202020617065782E646562756728226572726F723A20756E61626C6520746F2073686F7720';
wwv_flow_api.g_varchar2_table(749) := '6F7665726C617920286E6F20706F73206F7220626F756E647320646566696E65642922293B0D0A20202020202020202020202020202020202020207D0D0A202020202020202020202020202020207D0D0A2020202020202020202020207D0D0A20202020';
wwv_flow_api.g_varchar2_table(750) := '202020207D0D0A20202020202020206F6E52656D6F76652829207B0D0A20202020202020202020202069662028746869732E5F64697629207B0D0A20202020202020202020202020202020746869732E5F6469762E706172656E744E6F64652E72656D6F';
wwv_flow_api.g_varchar2_table(751) := '76654368696C6428746869732E5F646976293B0D0A2020202020202020202020202020202064656C65746520746869732E5F6469763B0D0A2020202020202020202020207D0D0A20202020202020207D0D0A2020202020202020686964652829207B0D0A';
wwv_flow_api.g_varchar2_table(752) := '20202020202020202020202069662028746869732E5F64697629207B0D0A20202020202020202020202020202020746869732E5F6469762E7374796C652E7669736962696C697479203D202268696464656E223B0D0A2020202020202020202020207D0D';
wwv_flow_api.g_varchar2_table(753) := '0A20202020202020207D0D0A202020202020202073686F772829207B0D0A20202020202020202020202069662028746869732E5F64697629207B0D0A20202020202020202020202020202020746869732E5F6469762E7374796C652E7669736962696C69';
wwv_flow_api.g_varchar2_table(754) := '7479203D202276697369626C65223B0D0A2020202020202020202020207D0D0A20202020202020207D0D0A2020202020202020746F67676C652829207B0D0A20202020202020202020202069662028746869732E5F64697629207B0D0A20202020202020';
wwv_flow_api.g_varchar2_table(755) := '20202020202020202069662028746869732E5F6469762E7374796C652E7669736962696C697479203D3D3D202268696464656E2229207B0D0A2020202020202020202020202020202020202020746869732E73686F7728293B0D0A202020202020202020';
wwv_flow_api.g_varchar2_table(756) := '202020202020207D20656C7365207B0D0A2020202020202020202020202020202020202020746869732E6869646528293B0D0A202020202020202020202020202020207D0D0A2020202020202020202020207D0D0A20202020202020207D0D0A20202020';
wwv_flow_api.g_varchar2_table(757) := '20202020746F67676C65444F4D286D617029207B0D0A20202020202020202020202069662028746869732E6765744D6170282929207B0D0A20202020202020202020202020202020746869732E7365744D6170286E756C6C293B0D0A2020202020202020';
wwv_flow_api.g_varchar2_table(758) := '202020207D20656C7365207B0D0A20202020202020202020202020202020746869732E7365744D6170286D6170293B0D0A2020202020202020202020207D0D0A20202020202020207D0D0A202020207D0D0A0D0A7D293B';
null;
end;
/
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(196481127661656010)
,p_plugin_id=>wwv_flow_api.id(184856223301707224)
,p_file_name=>'jk64reportmap_r1.js'
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
