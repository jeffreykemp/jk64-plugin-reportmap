# Report Map (Google Maps) ![APEX Plugin](https://cdn.rawgit.com/Dani3lSun/apex-github-badges/b7e95341/badges/apex-plugin-badge.svg) ![APEX 5.0](https://cdn.rawgit.com/Dani3lSun/apex-github-badges/88f0a6ed/badges/apex-5_0-badge.svg) ![APEX 18.2](https://cdn.rawgit.com/Dani3lSun/apex-github-badges/2fee47b7/badges/apex-18_2-badge.svg)

### A region plugin for Oracle Application Express

**Leverage the power of Google Maps in your APEX application.** This plugin allows you to add one or more Google Map regions to any page, showing a number of markers (pins) retrieved from a query or other data source you specify.

The plugin provides a rich array of built-in declarative features, dynamic actions and associated API routines, and gives access to the underlying Google Maps object so you can customise it with any other behaviour you need.

![plugin-reportmap-markers.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/master/images/plugin-reportmap-markers.png)

The user can click any marker to see a popup info window for it.

### Visualisation: Marker Clustering

![plugin-reportmap-clustering.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/master/images/plugin-reportmap-clustering.png)

If many pins are too close together, Marker Clustering merges them into a single cluster; the number indicates how many pins are at that location. As the user zooms in or out, the clusters will split up or merge as needed.

### Visualisation: Heatmap

![plugin-reportmap-heatmap.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/master/images/plugin-reportmap-heatmap.png)

This is suitable for a large volume of data points. Each data point can have a "weight" which indicates the magnitude of some measure.

### Visualisation: Directions

![plugin-reportmap-route.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/master/images/plugin-reportmap-route.png)

Up to 10 points (origin, destination, plus up to 8 waypoints) may be supplied to derive a route. Google Maps can generate a route for Driving, Walking, Bicycling, or Transit (public transport). The plugin can also get the calculated total Distance and Time for the route.

## DEMO

[https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64](https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64)

## PRE-REQUISITES

* Oracle Application Express **5.0.3** or later
* Your **[Google Maps API Key](https://developers.google.com/maps/documentation/javascript/get-api-key)**

  > Google provides a free monthly credit which includes thresholds for some API requests (some are unlimited). You can use the platform to set daily quotas and email alerts to control your monthly costs. Refer to the pricing information page for details: https://cloud.google.com/maps-platform/pricing/.
  
  > Make sure to [restrict your API key](https://developers.google.com/maps/documentation/javascript/get-api-key#restrict_key) to your domain, especially if your website will be accessible on the internet.

## INSTALLATION INSTRUCTIONS

> **NOTE:** if you are upgrading to Release 1.0 from any prior version, some changes will be required to your application to support it as a number of attributes have been removed or changed.

1. Download the [latest release](https://github.com/jeffreykemp/jk64-plugin-reportmap/releases/latest)

2. Install the plugin to your application - choose your version from the list below:
   * If you are on APEX 18.2 or later: **`region_type_plugin_com_jk64_report_google_map_r1.sql`**
   * If you are on APEX 5.0.3 to 18.1: **`backport/region_type_plugin_com_jk64_report_google_map_r1_503.sql`**

3. Supply your public **Google API Key** (Component Settings)

4. Add a region to the page, select type **JK64 Report Google Map R1 [Plug-In]**

5. For **SQL Source**, enter a query with at least 4 columns, for example:

   ```sql
   SELECT lat, lng, name, id FROM mydata
   ```

**IF YOU ARE UPGRADING** from an earlier release, refer to the **[Upgrade Notes](https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki/Upgrading)**.

## SUPPORT

* In APEX, select any attribute and view the **Help** for more information and helpful tips.

* Refer to the **[WIKI](https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki)** for sample queries, plugin attributes, triggers, API references, and other tips & tricks.

* If you encounter a bug or have a great idea for enhancement, please raise an **[Issue](https://github.com/jeffreykemp/jk64-plugin-reportmap/issues)**. I will endeavour to respond to each issue as quickly as possible.
