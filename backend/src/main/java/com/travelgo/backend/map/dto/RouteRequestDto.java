package com.travelgo.backend.map.dto;

import java.util.List;

public class RouteRequestDto {
    private List<LatLngDto> waypoints;

    public List<LatLngDto> getWaypoints() { return waypoints; }
    public void setWaypoints(List<LatLngDto> waypoints) { this.waypoints = waypoints; }
}
