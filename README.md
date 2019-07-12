# Report Map (Google Maps) ![APEX Plugin](https://cdn.rawgit.com/Dani3lSun/apex-github-badges/b7e95341/badges/apex-plugin-badge.svg) ![APEX 5.0](https://cdn.rawgit.com/jeffreykemp/apex-github-badges/master/badges/apex-5.0-badge.svg)

**A Region plugin for Oracle Application Express**

This allows you to add a Google Map region to any page, showing a number of markers (pins) based on a query you specify. 

![plugin-reportmap-preview.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/master/src/plugin-reportmap-preview.png)

The user can click any marker to see a popup info window for it. You can have the region synchronize the map with an item you nominate - if so, the corresponding ID for the marker they click will be copied to the item.

**Warning:** if you are upgrading to v0.10 from v0.9.1 or earlier, make sure to review the [Release Notes](https://github.com/jeffreykemp/jk64-plugin-reportmap/releases/tag/v0.10) first.

**NOTICE**

*Version 1.0 of this plugin is currently in development. It will not be a drop-in replacement for v0.10 of the plugin which is no longer being supported. In particular, it will be upgraded to support Oracle Application Express 18.1 or later, and a number of attributes will be deprecated, changed or removed entirely.*

## DEMO ##

[https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64](https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64)

## PRE-REQUISITES ##

* Oracle Application Express 5.0.4 or later
* You need a [Google Maps API Key](https://developers.google.com/maps/documentation/javascript/get-api-key#get-an-api-key)

## INSTALLATION INSTRUCTIONS ##

1. Download the [latest release](https://github.com/jeffreykemp/jk64-plugin-reportmap/releases/latest)
2. Install the plugin to your application - **region_type_plugin_com_jk64_report_google_map.sql**
3. Supply your **Google API Key** (Component Settings)
4. Add a region to the page, select type **JK64 Report Google Map [Plug-In]**
5. For **SQL Source**, enter a query with at least 4 columns (see example below)
6. Update the **Number of Rows** to a reasonable upper limit (default is 15, you probably want a higher limit)

**Sample query**

```sql
SELECT lat, lng, name, id FROM mydata
```

For more info including sample queries, plugin attributes and triggers, refer to the [WIKI](https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki).
