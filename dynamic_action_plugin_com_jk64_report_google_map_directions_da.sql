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
prompt --application/shared_components/plugins/dynamic_action/com_jk64_report_google_map_directions_da
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(169463388112490541)
,p_plugin_type=>'DYNAMIC ACTION'
,p_name=>'COM.JK64.REPORT_GOOGLE_MAP_DIRECTIONS_DA'
,p_display_name=>'JK64 Report Google Map R1 Show Directions'
,p_category=>'EXECUTE'
,p_supported_ui_types=>'DESKTOP'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'-- jk64 ReportMap Show Directions v1.0 Jan 2021',
'-- https://github.com/jeffreykemp/jk64-plugin-reportmap',
'-- Copyright (c) 2020 Jeffrey Kemp',
'-- Released under the MIT licence: http://opensource.org/licenses/mit-license',
'',
'subtype plugin_attr is varchar2(32767);',
'',
'function render',
'    ( p_dynamic_action apex_plugin.t_dynamic_action',
'    , p_plugin         apex_plugin.t_plugin',
'    ) return apex_plugin.t_dynamic_action_render_result is',
'',
'    l_source_type         plugin_attr := p_dynamic_action.attribute_02;',
'    l_page_item_orig      plugin_attr := p_dynamic_action.attribute_03;',
'    l_selector_orig       plugin_attr := p_dynamic_action.attribute_04;',
'    l_static_value_orig   plugin_attr := p_dynamic_action.attribute_05;',
'    l_js_expression_orig  plugin_attr := p_dynamic_action.attribute_06;',
'    l_page_item_dest      plugin_attr := p_dynamic_action.attribute_07;',
'    l_selector_dest       plugin_attr := p_dynamic_action.attribute_08;',
'    l_static_value_dest   plugin_attr := p_dynamic_action.attribute_09;',
'    l_js_expression_dest  plugin_attr := p_dynamic_action.attribute_10;',
'    l_page_item_mode      plugin_attr := p_dynamic_action.attribute_11;',
'    l_selector_mode       plugin_attr := p_dynamic_action.attribute_12;',
'    l_static_value_mode   plugin_attr := p_dynamic_action.attribute_13;',
'    l_js_expression_mode  plugin_attr := p_dynamic_action.attribute_14;',
'',
'    l_val_js              varchar2(32767);',
'    l_result              apex_plugin.t_dynamic_action_render_result;',
'',
'begin',
'    if apex_application.g_debug then',
'        apex_plugin_util.debug_dynamic_action',
'            (p_plugin         => p_plugin',
'            ,p_dynamic_action => p_dynamic_action);',
'    end if;',
'',
'    l_val_js :=',
'        case l_source_type',
'        when ''pageItem'' then',
'            ''var orig=$v("'' || apex_javascript.escape(l_page_item_orig) || ''"),''',
'             || ''dest=$v("'' || apex_javascript.escape(l_page_item_dest) || ''"),''',
'             || ''mode=$v("'' || apex_javascript.escape(l_page_item_mode) || ''");''',
'        when ''jquerySelector'' then',
'            ''var orig=$("'' || apex_javascript.escape(l_selector_orig) || ''").val(),''',
'             || ''dest=$("'' || apex_javascript.escape(l_selector_dest) || ''").val(),''',
'             || ''mode=$("'' || apex_javascript.escape(l_selector_mode) || ''").val();''',
'        when ''javascriptExpression'' then',
'            ''var orig='' || l_js_expression_orig || '',''',
'             || ''dest='' || l_js_expression_dest || '',''',
'             || ''mode='' || l_js_expression_mode || '';''',
'        when ''static'' then',
'            ''var orig="'' || apex_javascript.escape(l_static_value_orig) || ''",''',
'             || ''dest="'' || apex_javascript.escape(l_static_value_dest) || ''",''',
'             || ''mode="'' || apex_javascript.escape(l_static_value_mode) || ''";''',
'        end;',
'',
'    if l_val_js is null then',
'        raise_application_error(-20000, ''Plugin error: unrecognised source type ('' || l_source_type || '')'');',
'    end if;',
'',
'    l_result.javascript_function',
'        := ''function(){''',
'        ||     ''apex.debug("ReportMap Show Directions");''',
'        ||     l_val_js',
'        ||     ''this.affectedElements.each(function(i,e){''',
'        ||         ''$("#map_"+e.id).reportmap("showDirections",orig,dest,mode);''',
'        ||     ''});''',
'        || ''}'';',
'',
'    return l_result;',
'exception',
'    when others then',
'        apex_debug.error(sqlerrm);',
'        apex_debug.message(dbms_utility.format_error_stack);',
'        apex_debug.message(dbms_utility.format_call_stack);',
'        raise;',
'end render;'))
,p_api_version=>2
,p_render_function=>'render'
,p_standard_attributes=>'REGION:REQUIRED'
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>',
'Use this to show Directions from one point to another point on a map region. This plugin is to be used in conjunction with a <strong>JK64 Report Google Map R1</strong> region on the page.',
'</p><p>',
'Refer to the wiki for documentation: <strong>https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki</strong>.',
'</p><p>',
'Please raise any bugs or enhancements on GitHub: <strong>https://github.com/jeffreykemp/jk64-plugin-reportmap/issues</strong>.',
'</p>'))
,p_version_identifier=>'1.0'
,p_about_url=>'https://jeffreykemp.github.io/jk64-plugin-reportmap/'
,p_plugin_comment=>wwv_flow_string.join(wwv_flow_t_varchar2(
'Copyright (c) 2021 Jeffrey Kemp',
'Released under the MIT licence: http://opensource.org/licenses/mit-license'))
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169471019044490493)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>30
,p_prompt=>'Source Type'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'pageItem'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'Determines how the parameters for the Directions are derived - whether to take the values from items on the page, or to base them on a JavaScript expression, or to take them from items based on jQuery selectors, or to specify the Values directly (i.e'
||'. static value or based on a substitution string).',
'<p>',
'All three parameters (Origin, Destination, and Travel Mode) must be provided using the same means - i.e. three page items, three expressions, etc.'))
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(169471926278490492)
,p_plugin_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_display_sequence=>30
,p_display_value=>'Page Item'
,p_return_value=>'pageItem'
,p_help_text=>'Specify an item on the page to provide the source value for the action.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(169472430667490491)
,p_plugin_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_display_sequence=>40
,p_display_value=>'jQuery Selector'
,p_return_value=>'jquerySelector'
,p_help_text=>'Specify a jQuery Selector to provide the source value for the action'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(169472871420490491)
,p_plugin_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_display_sequence=>50
,p_display_value=>'JavaScript Expression'
,p_return_value=>'javascriptExpression'
,p_help_text=>'Set the value using a JavaScript expression.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(169473374713490491)
,p_plugin_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_display_sequence=>60
,p_display_value=>'Static Value'
,p_return_value=>'static'
,p_help_text=>'Set a single static value.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169473854623490491)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>40
,p_prompt=>'Page Item - Origin'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'pageItem'
,p_help_text=>'Specify the page item to provide the Origin point. The value will be used to search for a location - they may be a Latitude,Longitude pair, or a street address.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169474279172490491)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>50
,p_prompt=>'jQuery Selector - Origin'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'jquerySelector'
,p_examples=>'#originItemId'
,p_help_text=>'Specify the jQuery selector to identify the Origin point. The value will be used to search for a location - they may be a Latitude,Longitude pair, or a street address.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169474645546490490)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>60
,p_prompt=>'Value - Origin'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'static'
,p_examples=>'-31.95883,115.85815'
,p_help_text=>'Enter the value to be used to find the Origin point. Substitution syntax allowed. The value will be used to search for a location - they may be a Latitude,Longitude pair, or a street address.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169475100591490490)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>70
,p_prompt=>'JavaScript Expression - Origin'
,p_attribute_type=>'JAVASCRIPT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'javascriptExpression'
,p_help_text=>'Specify the JavaScript expression to use to find the Origin point. The value will be used to search for a location - they may be a Latitude,Longitude pair, or a street address.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169505237267436111)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Page Item - Destination'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'pageItem'
,p_help_text=>'Specify the page item to provide the Destination point. The value will be used to search for a location - they may be a Latitude,Longitude pair, or a street address.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169505570065429118)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>8
,p_display_sequence=>80
,p_prompt=>'jQuery Selector - Destination'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'jquerySelector'
,p_examples=>'#destinationItemId'
,p_help_text=>'Specify the jQuery selector to identify the Destination point. The value will be used to search for a location - they may be a Latitude,Longitude pair, or a street address.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169505904162427320)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>9
,p_display_sequence=>90
,p_prompt=>'Value - Destination'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'static'
,p_examples=>'47 Cliff St, Fremantle WA 6160'
,p_help_text=>'Enter the value to be used to find the Destination point. Substitution syntax allowed. The value will be used to search for a location - they may be a Latitude,Longitude pair, or a street address.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169506175741423829)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>10
,p_display_sequence=>100
,p_prompt=>'JavaScript Expression - Destination'
,p_attribute_type=>'JAVASCRIPT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'javascriptExpression'
,p_help_text=>'Specify the JavaScript expression to use to find the Destination point. The value will be used to search for a location - they may be a Latitude,Longitude pair, or a street address.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169508176274339601)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>11
,p_display_sequence=>110
,p_prompt=>'Page Item - Travel Mode'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'pageItem'
,p_help_text=>'Specify the page item to specify the Travel Mode. The value must resolve to one of the following values (uppercase): DRIVING, WALKING, BICYCLING, or TRANSIT'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169508504998336670)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>12
,p_display_sequence=>120
,p_prompt=>'jQuery Selector - Travel Mode'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'jquerySelector'
,p_examples=>'#travelModeItemId'
,p_help_text=>'Specify the jQuery selector to specify the Travel Mode. The value must resolve to one of the following values (uppercase): DRIVING, WALKING, BICYCLING, or TRANSIT'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169508825490334595)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>13
,p_display_sequence=>130
,p_prompt=>'Value - Travel Mode'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'static'
,p_examples=>'DRIVING'
,p_help_text=>'Enter the value to be used to specify the Travel Mode. Substitution syntax allowed. The value must resolve to one of the following values (uppercase): DRIVING, WALKING, BICYCLING, or TRANSIT'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(169509095596332250)
,p_plugin_id=>wwv_flow_api.id(169463388112490541)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>14
,p_display_sequence=>140
,p_prompt=>'JavaScript Expression - Travel Mode'
,p_attribute_type=>'JAVASCRIPT'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_api.id(169471019044490493)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'javascriptExpression'
,p_help_text=>'Specify the JavaScript expression to use to specify the Travel Mode. The value must resolve to one of the following values (uppercase): DRIVING, WALKING, BICYCLING, or TRANSIT'
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
