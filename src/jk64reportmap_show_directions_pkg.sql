-- jk64 ReportMap Show Directions v1.0 Jan 2021
-- https://github.com/jeffreykemp/jk64-plugin-reportmap
-- Copyright (c) 2020 Jeffrey Kemp
-- Released under the MIT licence: http://opensource.org/licenses/mit-license

subtype plugin_attr is varchar2(32767);

function render
    ( p_dynamic_action apex_plugin.t_dynamic_action
    , p_plugin         apex_plugin.t_plugin
    ) return apex_plugin.t_dynamic_action_render_result is

    l_source_type         plugin_attr := p_dynamic_action.attribute_02;
    l_page_item_orig      plugin_attr := p_dynamic_action.attribute_03;
    l_selector_orig       plugin_attr := p_dynamic_action.attribute_04;
    l_static_value_orig   plugin_attr := p_dynamic_action.attribute_05;
    l_js_expression_orig  plugin_attr := p_dynamic_action.attribute_06;
    l_page_item_dest      plugin_attr := p_dynamic_action.attribute_07;
    l_selector_dest       plugin_attr := p_dynamic_action.attribute_08;
    l_static_value_dest   plugin_attr := p_dynamic_action.attribute_09;
    l_js_expression_dest  plugin_attr := p_dynamic_action.attribute_10;
    l_page_item_mode      plugin_attr := p_dynamic_action.attribute_11;
    l_selector_mode       plugin_attr := p_dynamic_action.attribute_12;
    l_static_value_mode   plugin_attr := p_dynamic_action.attribute_13;
    l_js_expression_mode  plugin_attr := p_dynamic_action.attribute_14;

    l_val_js              varchar2(32767);
    l_result              apex_plugin.t_dynamic_action_render_result;

begin
    if apex_application.g_debug then
        apex_plugin_util.debug_dynamic_action
            (p_plugin         => p_plugin
            ,p_dynamic_action => p_dynamic_action);
    end if;

    l_val_js :=
        case l_source_type
        when 'pageItem' then
            'var orig=$v("' || apex_javascript.escape(l_page_item_orig) || '"),'
             || 'dest=$v("' || apex_javascript.escape(l_page_item_dest) || '"),'
             || 'mode=$v("' || apex_javascript.escape(l_page_item_mode) || '");'
        when 'jquerySelector' then
            'var orig=$("' || apex_javascript.escape(l_selector_orig) || '").val(),'
             || 'dest=$("' || apex_javascript.escape(l_selector_dest) || '").val(),'
             || 'mode=$("' || apex_javascript.escape(l_selector_mode) || '").val();'
        when 'javascriptExpression' then
            'var orig=' || l_js_expression_orig || ','
             || 'dest=' || l_js_expression_dest || ','
             || 'mode=' || l_js_expression_mode || ';'
        when 'static' then
            'var orig="' || apex_javascript.escape(l_static_value_orig) || '",'
             || 'dest="' || apex_javascript.escape(l_static_value_dest) || '",'
             || 'mode="' || apex_javascript.escape(l_static_value_mode) || '";'
        end;

    if l_val_js is null then
        raise_application_error(-20000, 'Plugin error: unrecognised source type (' || l_source_type || ')');
    end if;

    l_result.javascript_function
        := 'function(){'
        ||     'apex.debug("ReportMap Show Directions");'
        ||     l_val_js
        ||     'this.affectedElements.each(function(i,e){'
        ||         '$("#map_"+e.id).reportmap("showDirections",orig,dest,mode);'
        ||     '});'
        || '}';

    return l_result;
exception
    when others then
        apex_debug.error(sqlerrm);
        apex_debug.message(dbms_utility.format_error_stack);
        apex_debug.message(dbms_utility.format_call_stack);
        raise;
end render;